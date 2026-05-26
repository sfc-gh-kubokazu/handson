-- ================================================================
-- 月次売上分析レポート スキル用 SQLクエリ集
-- 対象: SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
-- カラム構成: TRANSACTION_ID, TRANSACTION_DATE, CHANNEL('EC'/'RETAIL'),
--            PRODUCT_ID, PRODUCT_NAME, CATEGORY, QUANTITY, UNIT_PRICE, TOTAL_PRICE
-- ================================================================

-- ----------------------------------------------------------------
-- Query 1: 最新月の確認
-- Step 1で使用
-- ----------------------------------------------------------------
SELECT MAX(DATE_TRUNC('MONTH', TRANSACTION_DATE)) AS LATEST_MONTH
FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES;


-- ----------------------------------------------------------------
-- Query 2: カテゴリ別売上集計（最新月）
-- Step 3で使用
-- ----------------------------------------------------------------
SELECT
    CATEGORY,
    SUM(TOTAL_PRICE)                                              AS TOTAL_AMOUNT,
    SUM(QUANTITY)                                                 AS TOTAL_QUANTITY,
    ROUND(SUM(TOTAL_PRICE) / NULLIF(SUM(QUANTITY), 0), 0)        AS AVG_UNIT_PRICE
FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
WHERE DATE_TRUNC('MONTH', TRANSACTION_DATE) = (
    SELECT MAX(DATE_TRUNC('MONTH', TRANSACTION_DATE))
    FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
)
GROUP BY CATEGORY
ORDER BY TOTAL_AMOUNT DESC;


-- ----------------------------------------------------------------
-- Query 3: 月次トレンド（直近6ヶ月）+ 前月比
-- Step 4で使用
-- ----------------------------------------------------------------
WITH monthly AS (
    SELECT
        DATE_TRUNC('MONTH', TRANSACTION_DATE) AS SALE_MONTH,
        SUM(TOTAL_PRICE)   AS TOTAL_AMOUNT,
        SUM(QUANTITY) AS TOTAL_QUANTITY
    FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
    WHERE TRANSACTION_DATE >= DATEADD('MONTH', -5,
        (SELECT MAX(TRANSACTION_DATE) FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES))
    GROUP BY DATE_TRUNC('MONTH', TRANSACTION_DATE)
)
SELECT
    SALE_MONTH,
    TOTAL_AMOUNT,
    TOTAL_QUANTITY,
    LAG(TOTAL_AMOUNT) OVER (ORDER BY SALE_MONTH)    AS PREV_AMOUNT,
    ROUND(
        (TOTAL_AMOUNT - LAG(TOTAL_AMOUNT) OVER (ORDER BY SALE_MONTH))
        / NULLIF(LAG(TOTAL_AMOUNT) OVER (ORDER BY SALE_MONTH), 0) * 100
    , 1)                                            AS MOM_CHANGE_PCT
FROM monthly
ORDER BY SALE_MONTH;


-- ================================================================
-- カスタマイズ用 拡張クエリ例
-- ================================================================

-- ----------------------------------------------------------------
-- Query EX-1: チャネル別売上比較（Step 7-3 カスタマイズ後に使用）
-- チャネル値: 'EC' または 'RETAIL'
-- ----------------------------------------------------------------
SELECT
    CHANNEL,
    SUM(TOTAL_PRICE)                                          AS TOTAL_AMOUNT,
    SUM(QUANTITY)                                             AS TOTAL_QUANTITY,
    ROUND(SUM(TOTAL_PRICE) * 100.0
        / SUM(SUM(TOTAL_PRICE)) OVER (), 1)                  AS AMOUNT_SHARE_PCT
FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
WHERE DATE_TRUNC('MONTH', TRANSACTION_DATE) = (
    SELECT MAX(DATE_TRUNC('MONTH', TRANSACTION_DATE))
    FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
)
GROUP BY CHANNEL
ORDER BY TOTAL_AMOUNT DESC;


-- ----------------------------------------------------------------
-- Query EX-2: 売上Top10商品（横棒グラフ用、直近1ヶ月）
-- ----------------------------------------------------------------
SELECT
    PRODUCT_NAME,
    SUM(TOTAL_PRICE)   AS TOTAL_AMOUNT,
    SUM(QUANTITY) AS TOTAL_QUANTITY
FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
WHERE TRANSACTION_DATE >= DATEADD('MONTH', -1,
    (SELECT MAX(TRANSACTION_DATE) FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES))
GROUP BY PRODUCT_NAME
ORDER BY TOTAL_AMOUNT DESC
LIMIT 10;
