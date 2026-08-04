-- ============================================================
-- step2_cortex_search.sql — 検索サービスをつくる
-- ============================================================
-- Cortex Search でチャンクを検索できるようにします。
-- ベクトル検索・キーワード検索・リランキングを内部で組み合わせた
-- ハイブリッド検索が、SQL 1本で立ち上がります。
--
-- 【前提】step1_parse_document.sql まで実行済み（DOC_CHUNK がある）
-- 【所要】約5分（サービス作成に数分かかります）
-- ============================================================

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA DOC_SEARCH_HANDSON.HANDSON;


-- ============================================================
-- STEP 2-1: 検索サービスを作る
-- ============================================================
-- ★ 日本語で使うなら EMBEDDING_MODEL の指定が必須です。
--   既定は snowflake-arctic-embed-m-v1.5 で「英語専用」。
--   指定しないまま日本語を入れると精度が落ちます。
--   ここでは多言語対応の snowflake-arctic-embed-l-v2.0 を使います。
--   （512トークンに収めたのはこのモデルのウィンドウに合わせたため）
--
-- ATTRIBUTES に挙げた列は、検索時の絞り込み条件に使えます。
CREATE OR REPLACE CORTEX SEARCH SERVICE PMDA_DOC_SEARCH
    ON chunk_text
    ATTRIBUTES doc_type, product_name, generic_name, drug_class
    WAREHOUSE = COMPUTE_WH
    TARGET_LAG = '1 day'
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
    COMMENT = 'PMDA公開文書（電子添文・審議結果報告書）の全文検索'
AS (
    SELECT
        chunk_text,
        relative_path,
        doc_type,
        product_name,
        generic_name,
        drug_class,
        page_no,
        chunk_no
    FROM DOC_CHUNK
);

-- 状態を確認（SERVING_STATE が ACTIVE になれば検索できます）
SHOW CORTEX SEARCH SERVICES LIKE 'PMDA_DOC_SEARCH';


-- ============================================================
-- STEP 2-2: 検索してみる
-- ============================================================
-- SEARCH_PREVIEW は動作確認用の関数です。
-- （アプリから使うときは Python API / REST API を使います）
SELECT
    r.value:product_name::VARCHAR   AS "製品",
    r.value:doc_type::VARCHAR       AS "文書種別",
    r.value:page_no::INT            AS "ページ",
    r.value:chunk_text::VARCHAR     AS "該当箇所"
FROM TABLE(FLATTEN(PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'PMDA_DOC_SEARCH',
        '{
           "query": "ケトアシドーシスが起きたときの対応",
           "columns": ["product_name","doc_type","page_no","chunk_text"],
           "limit": 5
         }'
    )
)['results'])) r;

-- ★ 注目してほしい点:
--   「ケトアシドーシス」という単語だけでなく、
--   悪心・嘔吐・意識障害といった"症状の説明"の箇所も拾えます。
--   キーワード一致だけの検索との違いがここです。


-- ============================================================
-- STEP 2-3: 絞り込んで検索する（ATTRIBUTES の出番）
-- ============================================================
-- 「電子添文だけ」に限定して検索する。
-- 審議結果報告書は分量が多く上位を占めがちなので、
-- 用途に応じて絞り込めることが重要です。
SELECT
    r.value:product_name::VARCHAR   AS "製品",
    r.value:page_no::INT            AS "ページ",
    r.value:chunk_text::VARCHAR     AS "該当箇所"
FROM TABLE(FLATTEN(PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'PMDA_DOC_SEARCH',
        '{
           "query": "腎機能障害のある患者への投与",
           "columns": ["product_name","page_no","chunk_text"],
           "filter": {"@eq": {"doc_type": "電子添文"}},
           "limit": 5
         }'
    )
)['results'])) r;


-- 薬効群で絞る（DPP-4阻害薬だけ）
SELECT
    r.value:product_name::VARCHAR   AS "製品",
    r.value:page_no::INT            AS "ページ",
    r.value:chunk_text::VARCHAR     AS "該当箇所"
FROM TABLE(FLATTEN(PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'PMDA_DOC_SEARCH',
        '{
           "query": "併用注意の薬剤",
           "columns": ["product_name","page_no","chunk_text"],
           "filter": {"@eq": {"drug_class": "DPP-4阻害薬"}},
           "limit": 3
         }'
    )
)['results'])) r;


-- ============================================================
-- STEP 2-4: 索引の中身を直接のぞく（デバッグ用）
-- ============================================================
-- 「検索でヒットしない」ときは、そもそもサービスにデータが
-- 入っているかを確認します。
SELECT doc_type, product_name, COUNT(*) AS "登録チャンク数"
FROM TABLE(CORTEX_SEARCH_DATA_SCAN(SERVICE_NAME => 'PMDA_DOC_SEARCH'))
GROUP BY ALL
ORDER BY doc_type, product_name;


-- ============================================================
-- （参考）自由に試す
-- ============================================================
-- query を書き換えて色々試してみてください。例:
--   「妊婦への投与は可能か」
--   「低血糖のリスクと患者への説明」
--   「注射する部位について」
--   「審査の過程で問題になった点」  ← 審議結果報告書側がヒットします
