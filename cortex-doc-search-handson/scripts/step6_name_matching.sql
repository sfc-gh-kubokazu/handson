-- ============================================================
-- step6_name_matching.sql — AI関数で名寄せする
-- ============================================================
-- 講演会の参加者名簿（手入力）を、医師マスタに突き合わせます。
-- 実務でよくある「表記揺れ」を、SQLだけでどこまで処理できるか、
-- そしてAI関数を足すと何が変わるかを見ます。
--
-- 【前提】step0_setup.sql を実行済み
-- 【所要】約10分
-- ============================================================

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA DOC_SEARCH_HANDSON.HANDSON;


-- ============================================================
-- STEP 6-0: 突き合わせる2つのデータを見る
-- ============================================================
-- 名簿側（手入力。表記が揺れている）
SELECT * FROM T_EVENT_ATTENDEE_RAW ORDER BY row_no;

-- マスタ側（正しい表記）
SELECT d.doctor_id, d.doctor_name, f.facility_name, d.department
FROM M_DOCTOR d JOIN M_FACILITY f ON f.facility_id = d.facility_id
ORDER BY d.doctor_id;

-- ★揺れの種類は3つ
--   1. 姓の異体字      斉藤/齊藤、渡辺/渡邊、高橋/髙橋、山崎/山﨑、中嶋/中島
--   2. 空白            「小林大輔」「高橋　淳」（全角空白）
--   3. 施設名の略称    「みなと大学病院」→「みなと大学医学部附属病院」
--                      「北山記念病院 糖尿病内科」（診療科が付いている）
--
-- ★さらに7行目（佐藤 一郎／東京第一病院）はマスタに存在しません。
--   「無理に当てはめず、該当なしと言えるか」も見どころです。


-- ============================================================
-- STEP 6-1: まず素直に完全一致でJOINしてみる
-- ============================================================
SELECT
    r.row_no,
    r.attendee_name_input   AS "名簿の氏名",
    d.doctor_id             AS "特定できたID"
FROM T_EVENT_ATTENDEE_RAW r
LEFT JOIN M_DOCTOR d ON d.doctor_name = r.attendee_name_input
ORDER BY r.row_no;

-- → ほぼ全滅します。


-- ============================================================
-- STEP 6-2: 空白を除去して正規化してみる
-- ============================================================
-- 「前処理を頑張る」という発想。半角・全角の空白を潰します。
SELECT
    r.row_no,
    r.attendee_name_input   AS "名簿の氏名",
    d.doctor_id             AS "特定できたID"
FROM T_EVENT_ATTENDEE_RAW r
LEFT JOIN M_DOCTOR d
       ON REPLACE(REPLACE(d.doctor_name, ' ', ''), '　', '')
        = REPLACE(REPLACE(r.attendee_name_input, ' ', ''), '　', '')
ORDER BY r.row_no;

-- → 少しは当たりますが、異体字は依然として一致しません。
--   異体字の対応表を自前で持つ、という道もありますが、
--   「渡辺/渡邊/渡邉」…を網羅し続けるのは現実的ではありません。


-- ============================================================
-- STEP 6-3: AI_SIMILARITY で「近さ」を数値にする
-- ============================================================
-- AI_SIMILARITY は2つの文字列の意味的な近さを -1〜1 で返します。
-- 氏名だけでは同姓の取り違えが起きるため、
-- 「氏名 + 施設名」をひとまとめにして比べます。
CREATE OR REPLACE TABLE MATCH_CANDIDATE AS
WITH master AS (
    SELECT
        d.doctor_id,
        d.doctor_name,
        f.facility_name,
        d.doctor_name || ' ' || f.facility_name AS master_key
    FROM M_DOCTOR d
    JOIN M_FACILITY f ON f.facility_id = d.facility_id
)
SELECT
    r.row_no,
    r.attendee_name_input,
    r.facility_name_input,
    m.doctor_id,
    m.doctor_name,
    m.facility_name,
    AI_SIMILARITY(
        r.attendee_name_input || ' ' || r.facility_name_input,
        m.master_key
    ) AS similarity
FROM T_EVENT_ATTENDEE_RAW r
CROSS JOIN master m;

-- 各行の上位3候補を見る（スコアの開きを確認する）
SELECT
    row_no          AS "行",
    attendee_name_input AS "名簿の氏名",
    doctor_name     AS "候補",
    facility_name   AS "候補の施設",
    ROUND(similarity, 4) AS "類似度"
FROM MATCH_CANDIDATE
QUALIFY ROW_NUMBER() OVER (PARTITION BY row_no ORDER BY similarity DESC) <= 3
ORDER BY row_no, similarity DESC;


-- 1位だけを採用した結果
SELECT
    row_no              AS "行",
    attendee_name_input AS "名簿の氏名",
    doctor_id           AS "特定したID",
    doctor_name         AS "マスタの氏名",
    ROUND(similarity, 4) AS "類似度"
FROM MATCH_CANDIDATE
QUALIFY ROW_NUMBER() OVER (PARTITION BY row_no ORDER BY similarity DESC) = 1
ORDER BY row_no;

-- ★ここで必ず確認してほしいこと
--   1位のスコアと2位のスコアの差が小さい行は、危ない行です。
--   「1位を機械的に採用する」運用にすると、その行で間違えます。


-- ============================================================
-- STEP 6-4: AI_COMPLETE に判断させ、確信度と根拠も出させる
-- ============================================================
-- 類似度は「近さ」しか教えてくれません。
-- 「同一人物と断定してよいか」を判断させ、
-- 自信がなければ人間に回す、という形にします。
CREATE OR REPLACE TABLE MATCH_RESULT AS
WITH top3 AS (
    SELECT
        row_no,
        attendee_name_input,
        facility_name_input,
        doctor_id,
        doctor_name,
        facility_name,
        similarity
    FROM MATCH_CANDIDATE
    QUALIFY ROW_NUMBER() OVER (PARTITION BY row_no ORDER BY similarity DESC) <= 3
),
cand AS (
    SELECT
        row_no,
        attendee_name_input,
        facility_name_input,
        LISTAGG(doctor_id || ':' || doctor_name || '（' || facility_name || '）', ' / ')
            WITHIN GROUP (ORDER BY similarity DESC) AS candidates
    FROM top3
    GROUP BY ALL
)
SELECT
    row_no,
    attendee_name_input,
    facility_name_input,
    candidates,
    AI_COMPLETE(
        'claude-4-sonnet',
           '名簿の入力値と、医師マスタの候補を突き合わせて同一人物を1人選んでください。'
        || '日本人の姓には異体字（斉藤/齊藤、渡辺/渡邊、高橋/髙橋、山崎/山﨑、中嶋/中島など）があり、'
        || '施設名も略称や診療科付きで入力されることがあります。'
        || '氏名と施設名の両方を根拠に判断してください。'
        || '該当する候補が無い、または判断できない場合は doctor_id を NONE にしてください。'
        || 'confidence は 高 / 中 / 低 のいずれかで答えてください。'
        || CHR(10) || '入力氏名: ' || attendee_name_input
        || CHR(10) || '入力施設: ' || facility_name_input
        || CHR(10) || '候補: '     || candidates,
        {
          'response_format': {
            'type': 'json',
            'schema': {
              'type': 'object',
              'properties': {
                'doctor_id':  {'type': 'string'},
                'confidence': {'type': 'string'},
                'reason':     {'type': 'string'}
              },
              'required': ['doctor_id', 'confidence', 'reason']
            }
          }
        }
    ) AS judgement
FROM cand;

-- 結果を見る
SELECT
    m.row_no                                    AS "行",
    m.attendee_name_input                       AS "名簿の氏名",
    m.facility_name_input                       AS "名簿の施設",
    m.judgement:doctor_id::VARCHAR              AS "判定ID",
    d.doctor_name                               AS "マスタの氏名",
    m.judgement:confidence::VARCHAR             AS "確信度",
    m.judgement:reason::VARCHAR                 AS "根拠"
FROM MATCH_RESULT m
LEFT JOIN M_DOCTOR d ON d.doctor_id = m.judgement:doctor_id::VARCHAR
ORDER BY m.row_no;


-- ============================================================
-- STEP 6-5: 実務に落とすなら
-- ============================================================
-- 「確信度が高いものだけ自動反映、それ以外は人間が確認」に分ける。
-- 全件を人手で見るのと、危ない行だけ見るのでは工数が変わります。
--
-- ★注意したい点: 「該当なし」を確信度"高"で返してくる行があります。
--   判定としては正しいのですが、やることは自動反映ではなく
--   「マスタに登録するかどうかの判断」です。確信度だけで振り分けると
--   これを取りこぼすので、doctor_id を先に見ます。
SELECT
    CASE
        WHEN m.judgement:doctor_id::VARCHAR = 'NONE'
            THEN '該当なし（マスタ登録の要否を判断する）'
        WHEN m.judgement:confidence::VARCHAR = '高'
            THEN '自動反映してよい'
        ELSE '人間の確認が必要'
    END                                     AS "振り分け",
    COUNT(*)                                AS "件数"
FROM MATCH_RESULT m
GROUP BY ALL
ORDER BY 1;

-- 自動反映してよい行以外を出す（人間が見るべきリスト）
SELECT
    m.row_no                            AS "行",
    m.attendee_name_input               AS "名簿の氏名",
    m.facility_name_input               AS "名簿の施設",
    m.judgement:doctor_id::VARCHAR      AS "判定ID",
    m.judgement:confidence::VARCHAR     AS "確信度",
    m.judgement:reason::VARCHAR         AS "根拠"
FROM MATCH_RESULT m
WHERE m.judgement:doctor_id::VARCHAR = 'NONE'
   OR m.judgement:confidence::VARCHAR <> '高'
ORDER BY m.row_no;

-- ★注意
--   AI関数は毎回まったく同じ出力を返すとは限りません。
--   名寄せ結果をそのまま基幹データに書き戻す設計にはせず、
--   判定結果を別テーブルに残し、確信度で人間の確認を挟んでください。
