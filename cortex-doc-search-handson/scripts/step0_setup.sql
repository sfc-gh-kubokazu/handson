-- ============================================================
-- step0_setup.sql — 土台をつくる
-- ============================================================
-- このハンズオンで使うデータベース・ステージ・構造化データ・
-- セマンティックビューを一括で用意します。
--
-- 【所要】約2分
-- 【後片付け】cleanup.sql を実行すれば全部消えます
-- ============================================================

-- ロールとウェアハウスは自分の環境に合わせて変更してください
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;

CREATE DATABASE IF NOT EXISTS DOC_SEARCH_HANDSON;
CREATE SCHEMA IF NOT EXISTS DOC_SEARCH_HANDSON.HANDSON;
USE SCHEMA DOC_SEARCH_HANDSON.HANDSON;


-- ============================================================
-- STEP 0-1: PDFを置くステージ
-- ============================================================
-- ★ AI_PARSE_DOCUMENT はサーバーサイド暗号化(SSE)が必須。
--   既定のクライアントサイド暗号化のままだと動きません。
--   この設定は後から ALTER で変えられないので、作るときに指定します。
--
-- ★ CREATE OR REPLACE にしていないのは、このスクリプトを再実行したときに
--   アップロード済みのPDFを消してしまうためです（実際にやりました）。
--   すでに SSE 無しで DOCS を作ってしまった場合だけ、
--   DROP STAGE DOCS; してから作り直してください。
CREATE STAGE IF NOT EXISTS DOCS
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = '添付文書PDF置き場（AI_PARSE_DOCUMENT用・SSE必須）';

-- 作られた設定を確認（type が SNOWFLAKE_SSE になっているか）
DESC STAGE DOCS;

-- 手順4の Streamlit アプリを snow CLI でデプロイする場合の置き場。
-- Snowsight の画面から作る場合は使いません。
CREATE STAGE IF NOT EXISTS STREAMLIT
    COMMENT = 'Streamlit in Snowflake のデプロイ先';


-- ============================================================
-- STEP 0-2: 構造化データ（架空の糖尿病領域データ）
-- ============================================================
-- 実在の製品・施設・医師とは無関係の架空データです。
-- 手順3（Agentに構造化＋非構造化の両方を持たせる）と
-- 手順6（名寄せ）で使います。

-- 製品マスタ
CREATE OR REPLACE TABLE M_PRODUCT (
    product_id      VARCHAR(10) PRIMARY KEY,
    product_name    VARCHAR(50),
    drug_class      VARCHAR(30),
    own_flag        BOOLEAN,
    price           NUMBER(10,2)
);

INSERT INTO M_PRODUCT VALUES
    ('P001','グルコリーブ','DPP-4阻害薬',       TRUE,  168),
    ('P002','メトグリプ',  'ビグアナイド薬',     TRUE,  142),
    ('P003','デュラグル',  'GLP-1受容体作動薬',  TRUE, 1890),
    ('P004','ダパリスト',  'SGLT2阻害薬',       FALSE,  175),
    ('P005','エンパグロン','SGLT2阻害薬',       FALSE,  183),
    ('P006','セマグリア',  'GLP-1受容体作動薬',  FALSE,  309),
    ('P007','イニグリプ',  'DPP-4阻害薬',       FALSE,  138),
    ('P008','メタグリア',  'ビグアナイド薬',     FALSE,  125);

-- 施設マスタ
CREATE OR REPLACE TABLE M_FACILITY (
    facility_id     VARCHAR(10) PRIMARY KEY,
    facility_name   VARCHAR(100),
    facility_type   VARCHAR(20),
    pref            VARCHAR(10)
);

INSERT INTO M_FACILITY VALUES
    ('F001','中央総合病院',       '病院',   '東京都'),
    ('F002','みなと大学医学部附属病院','大学病院','神奈川県'),
    ('F003','さくら内科クリニック','診療所', '東京都'),
    ('F004','北山記念病院',       '病院',   '大阪府'),
    ('F005','あおば糖尿病内科',   '診療所', '愛知県'),
    ('F006','西湖医療センター',   '病院',   '福岡県');

-- 医師マスタ（手順6の名寄せの「正解」側）
CREATE OR REPLACE TABLE M_DOCTOR (
    doctor_id        VARCHAR(10) PRIMARY KEY,
    doctor_name      VARCHAR(50),
    doctor_name_kana VARCHAR(50),
    facility_id      VARCHAR(10),
    department       VARCHAR(30)
);

INSERT INTO M_DOCTOR VALUES
    ('D001','齊藤 健太郎','サイトウ ケンタロウ','F001','糖尿病内科'),
    ('D002','渡邊 美咲',  'ワタナベ ミサキ',   'F002','内分泌内科'),
    ('D003','髙橋 淳',    'タカハシ ジュン',   'F003','内科'),
    ('D004','山﨑 里奈',  'ヤマザキ リナ',     'F004','糖尿病内科'),
    ('D005','小林 大輔',  'コバヤシ ダイスケ', 'F005','内科'),
    ('D006','中島 陽子',  'ナカジマ ヨウコ',   'F006','内分泌内科');

-- 月次売上（8製品 × 3ヶ月 × 6施設 のうち一部）
CREATE OR REPLACE TABLE T_SALES (
    sales_id     VARCHAR(20) PRIMARY KEY,
    year_month   VARCHAR(7),
    product_id   VARCHAR(10),
    facility_id  VARCHAR(10),
    amount_jpy   NUMBER(12,0)
);

INSERT INTO T_SALES
SELECT
    'S' || LPAD(SEQ4(), 6, '0')                       AS sales_id,
    ym.year_month,
    p.product_id,
    f.facility_id,
    -- 製品単価と施設規模から擬似的に金額を作る（再現性のためHASHで固定）
    ROUND(p.price * (50 + MOD(ABS(HASH(p.product_id, f.facility_id, ym.year_month)), 150)))
FROM (SELECT '2026-01' AS year_month UNION ALL
      SELECT '2026-02' UNION ALL
      SELECT '2026-03') ym
CROSS JOIN M_PRODUCT p
CROSS JOIN M_FACILITY f;

-- 講演会の芳名帳（手順6の名寄せの「表記揺れ」側）
-- 旧字体・スペース有無・施設名の略称などが混在している状態を再現
CREATE OR REPLACE TABLE T_EVENT_ATTENDEE_RAW (
    row_no              NUMBER,
    attendee_name_input VARCHAR(100),
    facility_name_input VARCHAR(100)
);

INSERT INTO T_EVENT_ATTENDEE_RAW VALUES
    (1,'斉藤健太郎',   '中央総合病院'),
    (2,'渡辺 美咲',    'みなと大学病院'),
    (3,'高橋　淳',     'さくら内科'),
    (4,'山崎里奈',     '北山記念病院 糖尿病内科'),
    (5,'小林大輔',     'あおば糖尿病内科クリニック'),
    (6,'中嶋 陽子',    '西湖医療センター'),
    -- 7件目はマスタに存在しない医師。「該当なし」を返させるための行
    (7,'佐藤 一郎',    '東京第一病院');


-- ============================================================
-- STEP 0-3: セマンティックビュー（②-1 の復習）
-- ============================================================
-- ②-1 では Autopilot（UI）で作りました。DDLで書くとこれだけです。
-- 手順3で Cortex Agent のツールとして使います。
CREATE OR REPLACE SEMANTIC VIEW SV_SALES
    TABLES (
        sales      AS T_SALES    PRIMARY KEY (sales_id),
        products   AS M_PRODUCT  PRIMARY KEY (product_id),
        facilities AS M_FACILITY PRIMARY KEY (facility_id)
    )
    RELATIONSHIPS (
        sales_to_product  AS sales(product_id)  REFERENCES products,
        sales_to_facility AS sales(facility_id) REFERENCES facilities
    )
    DIMENSIONS (
        products.product_name AS product_name
            WITH SYNONYMS = ('製品名','薬剤名')
            COMMENT = '製品名（架空）',
        products.drug_class   AS drug_class
            WITH SYNONYMS = ('薬効群','クラス')
            COMMENT = 'SGLT2阻害薬 / DPP-4阻害薬 / GLP-1受容体作動薬 / ビグアナイド薬',
        products.own_flag     AS own_flag
            COMMENT = 'TRUE が自社製品',
        facilities.pref       AS pref
            WITH SYNONYMS = ('都道府県','県')
            COMMENT = '施設の所在都道府県',
        facilities.facility_name AS facility_name
            WITH SYNONYMS = ('施設名','病院名'),
        sales.year_month      AS year_month
            WITH SYNONYMS = ('年月','対象月')
            COMMENT = 'VARCHAR(7) の YYYY-MM 形式。2026-01〜2026-03 のみ'
    )
    METRICS (
        sales.total_amount AS SUM(sales.amount_jpy)
            WITH SYNONYMS = ('売上金額','金額')
            COMMENT = '売上金額の合計（円）'
    )
    COMMENT = '架空の糖尿病領域の月次売上。期間は2026-01〜2026-03のみ。数量データは無く金額のみ。';


-- ============================================================
-- STEP 0-4: 確認
-- ============================================================
SHOW TABLES IN SCHEMA DOC_SEARCH_HANDSON.HANDSON;

SELECT COUNT(*) AS "売上行数" FROM T_SALES;

-- セマンティックビュー経由で引けるか（②-1でやった検証と同じ形）
SELECT * FROM SEMANTIC_VIEW(
    SV_SALES
    DIMENSIONS products.product_name
    METRICS    sales.total_amount
    WHERE      sales.year_month = '2026-03' AND products.own_flag = TRUE
)
ORDER BY total_amount DESC;
