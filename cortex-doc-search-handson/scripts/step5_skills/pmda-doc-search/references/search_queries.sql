-- ============================================================
-- pmda-doc-search / 検索クエリ集
-- ============================================================
-- Cortex Search サービス:
--   DOC_SEARCH_HANDSON.HANDSON.PMDA_DOC_SEARCH
--
-- ★ SEARCH_PREVIEW の引数は「定数」でなければなりません。
--    列参照やバインド変数を渡すと needs to be constant エラーになります。
--    query 部分は毎回書き換えて使ってください。
-- ============================================================


-- ============================================================
-- 1. 基本の検索
-- ============================================================
SELECT
    r.value:product_name::VARCHAR   AS PRODUCT_NAME,
    r.value:doc_type::VARCHAR       AS DOC_TYPE,
    r.value:drug_class::VARCHAR     AS DRUG_CLASS,
    r.value:page_no::INT            AS PAGE_NO,
    r.value:chunk_text::VARCHAR     AS CHUNK_TEXT
FROM TABLE(FLATTEN(PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'DOC_SEARCH_HANDSON.HANDSON.PMDA_DOC_SEARCH',
        '{
           "query": "腎機能障害のある患者に投与するときの注意点",
           "columns": ["product_name","doc_type","drug_class","page_no","chunk_text"],
           "limit": 8
         }'
    )
)['results'])) r;


-- ============================================================
-- 2. 製品で絞る
-- ============================================================
SELECT
    r.value:product_name::VARCHAR   AS PRODUCT_NAME,
    r.value:page_no::INT            AS PAGE_NO,
    r.value:chunk_text::VARCHAR     AS CHUNK_TEXT
FROM TABLE(FLATTEN(PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'DOC_SEARCH_HANDSON.HANDSON.PMDA_DOC_SEARCH',
        '{
           "query": "投与を忘れた場合の対応",
           "columns": ["product_name","page_no","chunk_text"],
           "filter": {"@eq": {"product_name": "マンジャロ皮下注アテオス"}},
           "limit": 5
         }'
    )
)['results'])) r;


-- ============================================================
-- 3. 複数条件で絞る（文書種別 × 薬効群）
-- ============================================================
SELECT
    r.value:product_name::VARCHAR   AS PRODUCT_NAME,
    r.value:page_no::INT            AS PAGE_NO,
    r.value:chunk_text::VARCHAR     AS CHUNK_TEXT
FROM TABLE(FLATTEN(PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'DOC_SEARCH_HANDSON.HANDSON.PMDA_DOC_SEARCH',
        '{
           "query": "ケトアシドーシス",
           "columns": ["product_name","page_no","chunk_text"],
           "filter": {"@and": [
               {"@eq": {"doc_type": "電子添文"}},
               {"@eq": {"drug_class": "SGLT2阻害薬"}}
           ]},
           "limit": 5
         }'
    )
)['results'])) r;


-- ============================================================
-- 4. 製品横断の比較（製品ごとに検索して縦に積む）
-- ============================================================
-- 1回の検索だと分量の多い文書に上位を占められ、
-- 特定の製品が1件も出てこないことがあります。
-- 比較表を作るときは製品ごとに検索してください。
WITH q AS (
    SELECT 'ダパグリフロジン錠「サワイ」' AS product, SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'DOC_SEARCH_HANDSON.HANDSON.PMDA_DOC_SEARCH',
        '{"query":"高齢者への投与","columns":["product_name","page_no","chunk_text"],
          "filter":{"@eq":{"product_name":"ダパグリフロジン錠「サワイ」"}},"limit":2}') AS res
    UNION ALL
    SELECT 'ジャヌビア錠', SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'DOC_SEARCH_HANDSON.HANDSON.PMDA_DOC_SEARCH',
        '{"query":"高齢者への投与","columns":["product_name","page_no","chunk_text"],
          "filter":{"@eq":{"product_name":"ジャヌビア錠"}},"limit":2}')
    UNION ALL
    SELECT 'マンジャロ皮下注アテオス', SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'DOC_SEARCH_HANDSON.HANDSON.PMDA_DOC_SEARCH',
        '{"query":"高齢者への投与","columns":["product_name","page_no","chunk_text"],
          "filter":{"@eq":{"product_name":"マンジャロ皮下注アテオス"}},"limit":2}')
)
SELECT
    q.product                       AS PRODUCT,
    r.value:page_no::INT            AS PAGE_NO,
    r.value:chunk_text::VARCHAR     AS CHUNK_TEXT
FROM q,
     TABLE(FLATTEN(PARSE_JSON(q.res)['results'])) r
ORDER BY q.product, PAGE_NO;


-- ============================================================
-- 5. デバッグ用
-- ============================================================
-- サービスの状態（INDEXING_STATE / SERVING_STATE が ACTIVE か）
SHOW CORTEX SEARCH SERVICES IN SCHEMA DOC_SEARCH_HANDSON.HANDSON;

-- 索引に入っている件数
SELECT doc_type, product_name, COUNT(*) AS CHUNKS
FROM TABLE(CORTEX_SEARCH_DATA_SCAN(SERVICE_NAME => 'PMDA_DOC_SEARCH'))
GROUP BY ALL
ORDER BY doc_type, product_name;

-- filter に指定できる値の一覧（完全一致でないとヒットしません）
SELECT DISTINCT doc_type, product_name, generic_name, drug_class
FROM DOC_SEARCH_HANDSON.HANDSON.DOC_CHUNK
ORDER BY doc_type, product_name;
