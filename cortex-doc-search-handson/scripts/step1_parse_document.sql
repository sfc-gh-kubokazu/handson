-- ============================================================
-- step1_parse_document.sql — PDFをテキストにする
-- ============================================================
-- AI_PARSE_DOCUMENT で PDF（電子添文・審議結果報告書）を
-- テキスト化し、検索できる形（ページ単位 → チャンク単位）に
-- 整えます。
--
-- 【前提】step0_setup.sql を実行済み。ステージ @DOCS に PDF を
--         アップロード済み（手順は steps/step1_parse_document.md）
-- 【所要】約5分（審議結果報告書44ページ分のパースで少し待ちます）
-- ============================================================

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA DOC_SEARCH_HANDSON.HANDSON;


-- ============================================================
-- STEP 1-1: ステージに何が入っているか見る
-- ============================================================
-- DIRECTORY(@DOCS) はステージのファイル一覧をテーブルのように
-- 扱える仕組み。ファイルを追加したら REFRESH が必要です。
ALTER STAGE DOCS REFRESH;

SELECT relative_path, size, last_modified
FROM DIRECTORY(@DOCS)
ORDER BY relative_path;


-- ============================================================
-- STEP 1-2: まず1ファイルだけ試す
-- ============================================================
-- ★ ポイントは mode の指定。
--   OCR    … テキストだけ拾う。速い
--   LAYOUT … 見出し・箇条書き・"表" の構造をMarkdownで保つ
--
-- 電子添文は「組成・性状」などが表になっているため、
-- LAYOUT でないと数値と品名の対応が崩れます。
SELECT AI_PARSE_DOCUMENT(
           TO_FILE('@DOCS', 'tenbun/januvia_tenbun.pdf'),
           {'mode': 'LAYOUT'}
       ) AS parsed;

-- 返ってくるのは OBJECT。content にテキスト、metadata にページ数。
SELECT
    parsed:metadata:pageCount::INT      AS page_count,
    LENGTH(parsed:content::VARCHAR)     AS text_length,
    parsed:content::VARCHAR             AS body
FROM (
    SELECT AI_PARSE_DOCUMENT(
               TO_FILE('@DOCS', 'tenbun/januvia_tenbun.pdf'),
               {'mode': 'LAYOUT'}
           ) AS parsed
);

-- ★ 表が「| 品名 | ... |」というMarkdownの表として残っているか、
--   結果セルを開いて確認してみてください。ここがLAYOUTの効果です。


-- ============================================================
-- STEP 1-3: 文書マスタ（どのPDFが何なのかを持つ）
-- ============================================================
-- ファイル名だけだと検索結果が読みづらいので、
-- 「文書種別」「製品」「薬効群」を別テーブルで持たせます。
-- 後の Cortex Search でこれらを絞り込み条件に使います。
CREATE OR REPLACE TABLE M_DOCUMENT (
    relative_path   VARCHAR(200) PRIMARY KEY,
    doc_type        VARCHAR(30),
    product_name    VARCHAR(50),
    generic_name    VARCHAR(50),
    drug_class      VARCHAR(30),
    source_url      VARCHAR(300)
);

INSERT INTO M_DOCUMENT VALUES
    ('tenbun/dapagliflozin_tenbun.pdf', '電子添文', 'ダパグリフロジン錠「サワイ」', 'ダパグリフロジン', 'SGLT2阻害薬',
     'https://www.pmda.go.jp/PmdaSearch/iyakuDetail/ResultDataSetPDF/300119_3969019F1043_1_01'),
    ('tenbun/januvia_tenbun.pdf', '電子添文', 'ジャヌビア錠', 'シタグリプチンリン酸塩水和物', 'DPP-4阻害薬',
     'https://www.pmda.go.jp/PmdaSearch/iyakuDetail/ResultDataSetPDF/170050_3969010F1034_2_36'),
    ('tenbun/mounjaro_tenbun.pdf', '電子添文', 'マンジャロ皮下注アテオス', 'チルゼパチド', 'GIP/GLP-1受容体作動薬',
     'https://www.pmda.go.jp/PmdaSearch/iyakuDetail/ResultDataSetPDF/530471_2499422G1024_1_10'),
    ('shinsa/forxiga_shinsa.pdf', '審議結果報告書', 'フォシーガ錠', 'ダパグリフロジンプロピレングリコール水和物', 'SGLT2阻害薬',
     'https://www.pmda.go.jp/drugs/2021/P20210812001/670227000_22600AMX00528_A100_2.pdf');


-- ============================================================
-- STEP 1-4: 全ファイルをまとめてパースする
-- ============================================================
-- page_split = TRUE にすると pages 配列が返るので、
-- FLATTEN でページ1行ずつに展開できます。
-- 「何ページに書いてあったか」を残せるので、後で出典を示せます。
CREATE OR REPLACE TABLE DOC_PAGE AS
WITH parsed AS (
    SELECT
        d.relative_path,
        AI_PARSE_DOCUMENT(
            TO_FILE('@DOCS', d.relative_path),
            {'mode': 'LAYOUT', 'page_split': TRUE}
        ) AS result
    FROM DIRECTORY(@DOCS) d
    WHERE d.relative_path ILIKE '%.pdf'
)
SELECT
    p.relative_path,
    m.doc_type,
    m.product_name,
    m.generic_name,
    m.drug_class,
    p.result:metadata:pageCount::INT    AS page_count,
    pg.value:index::INT + 1             AS page_no,
    pg.value:content::VARCHAR           AS page_text
FROM parsed p
LEFT JOIN M_DOCUMENT m ON m.relative_path = p.relative_path,
     LATERAL FLATTEN(input => p.result:pages) pg;

-- 結果を確認
SELECT product_name, doc_type, page_count, COUNT(*) AS "ページ行数"
FROM DOC_PAGE
GROUP BY ALL
ORDER BY doc_type, product_name;


-- ============================================================
-- STEP 1-5: 検索用にチャンクへ分割する
-- ============================================================
-- 1ページ丸ごとだと検索のヒット箇所がぼやけます。
-- LAYOUT の出力はMarkdownなので、'markdown' 指定で
-- 見出しや表を壊しにくい形に分割できます。
--   引数: (テキスト, フォーマット, チャンクサイズ, オーバーラップ)
--
-- ★ サイズを700文字にしている理由は STEP 1-6 で確認します。
CREATE OR REPLACE TABLE DOC_CHUNK AS
SELECT
    relative_path,
    doc_type,
    product_name,
    generic_name,
    drug_class,
    page_no,
    c.index + 1                 AS chunk_no,
    c.value::VARCHAR            AS chunk_text
FROM DOC_PAGE,
     LATERAL FLATTEN(
         input => SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER(
                      page_text, 'markdown', 700, 100)
     ) c
WHERE LENGTH(TRIM(page_text)) > 0;

-- チャンク数と長さの分布を確認
SELECT
    doc_type,
    product_name,
    COUNT(*)                    AS "チャンク数",
    ROUND(AVG(LENGTH(chunk_text))) AS "平均文字数",
    MAX(LENGTH(chunk_text))     AS "最大文字数"
FROM DOC_CHUNK
GROUP BY ALL
ORDER BY doc_type, product_name;

-- 中身を1件のぞく
SELECT product_name, page_no, chunk_no, chunk_text
FROM DOC_CHUNK
WHERE product_name = 'ジャヌビア錠' AND page_no = 1
ORDER BY chunk_no
LIMIT 3;


-- ============================================================
-- STEP 1-6: ★チャンクが大きすぎないかトークン数で確認する
-- ============================================================
-- 次のステップで使う埋め込みモデルは、扱える長さ（コンテキスト
-- ウィンドウ）が 512トークン。これを超えた分は
-- ベクトル検索の際に切り捨てられます。
--
-- ★日本語は「文字数 ≠ トークン数」。実測で約0.57トークン/文字
--   だったため、1500文字だと平均570トークンで大半が超過しました。
--   700文字にすると 512 に収まります。
--   感覚で決めず、必ず COUNT_TOKENS で測ってください。
SELECT
    COUNT(*)                                            AS "チャンク数",
    ROUND(AVG(SNOWFLAKE.CORTEX.COUNT_TOKENS(
        'snowflake-arctic-embed-l-v2.0', chunk_text)))   AS "平均トークン",
    MAX(SNOWFLAKE.CORTEX.COUNT_TOKENS(
        'snowflake-arctic-embed-l-v2.0', chunk_text))    AS "最大トークン",
    SUM(IFF(SNOWFLAKE.CORTEX.COUNT_TOKENS(
        'snowflake-arctic-embed-l-v2.0', chunk_text) > 512, 1, 0)) AS "512超の数"
FROM DOC_CHUNK;
