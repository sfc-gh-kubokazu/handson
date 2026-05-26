-- ============================================================
-- setup.sql
-- SnowRetail ハンズオン セットアップスクリプト
-- ============================================================

-- Step1: ロール・ウェアハウスの指定
USE ROLE ACCOUNTADMIN;
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE;
USE WAREHOUSE COMPUTE_WH;

-- クロスリージョン推論を許可（Cortex AI機能を使うため）
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

-- Step2: 各種オブジェクトの作成
CREATE OR REPLACE DATABASE SNOWRETAIL_DB;
CREATE OR REPLACE SCHEMA SNOWRETAIL_DB.SNOWRETAIL_SCHEMA;
USE SCHEMA SNOWRETAIL_DB.SNOWRETAIL_SCHEMA;

-- ステージの作成（CSVデータ格納用）
CREATE OR REPLACE STAGE SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.FILE
  ENCRYPTION = (TYPE = 'snowflake_sse')
  DIRECTORY = (ENABLE = TRUE);

-- Step3: GitHub連携でデータを取得
-- Git API統合の作成
CREATE OR REPLACE API INTEGRATION git_api_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/snow-jp-handson-org/')
  ENABLED = TRUE;

-- GITリポジトリ統合の作成
CREATE OR REPLACE GIT REPOSITORY GIT_INTEGRATION_FOR_COCO_CLI_HANDSON
  API_INTEGRATION = git_api_integration
  ORIGIN = 'https://github.com/snow-jp-handson-org/coco-cli-handson-jp.git';

-- リポジトリ内容の確認
LS @GIT_INTEGRATION_FOR_COCO_CLI_HANDSON/branches/main;

-- GitHubからCSVファイルをステージにコピー
COPY FILES INTO @SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.FILE
  FROM @GIT_INTEGRATION_FOR_COCO_CLI_HANDSON/branches/main/data/
  PATTERN = '.*\.csv$';

-- ============================================================
-- Step4: テーブル作成
-- ============================================================

CREATE OR REPLACE TABLE EC_DATA (
    TRANSACTION_ID   VARCHAR,
    TRANSACTION_DATE DATE,
    PRODUCT_ID       VARCHAR,
    PRODUCT_NAME     VARCHAR,
    QUANTITY         NUMBER,
    UNIT_PRICE       NUMBER,
    TOTAL_PRICE      NUMBER
);

CREATE OR REPLACE TABLE RETAIL_DATA (
    TRANSACTION_ID   VARCHAR,
    TRANSACTION_DATE DATE,
    PRODUCT_ID       VARCHAR,
    PRODUCT_NAME     VARCHAR,
    QUANTITY         NUMBER,
    UNIT_PRICE       NUMBER,
    TOTAL_PRICE      NUMBER
);

CREATE OR REPLACE TABLE PRODUCT_MASTER (
    PRODUCT_ID   VARCHAR,
    PRODUCT_NAME VARCHAR,
    UNIT_PRICE   NUMBER
);

CREATE OR REPLACE TABLE SNOW_RETAIL_DOCUMENTS (
    DOCUMENT_ID   VARCHAR,
    TITLE         VARCHAR,
    CONTENT       VARCHAR,
    DOCUMENT_TYPE VARCHAR,
    DEPARTMENT    VARCHAR,
    CREATED_AT    TIMESTAMP_NTZ,
    UPDATED_AT    TIMESTAMP_NTZ,
    VERSION       NUMBER(38,1)
);

CREATE OR REPLACE TABLE CUSTOMER_REVIEWS (
    REVIEW_ID        VARCHAR,
    PRODUCT_ID       VARCHAR,
    CUSTOMER_ID      VARCHAR,
    RATING           NUMBER(38,1),
    REVIEW_TEXT      VARCHAR,
    REVIEW_DATE      TIMESTAMP_NTZ,
    PURCHASE_CHANNEL VARCHAR,
    HELPFUL_VOTES    NUMBER
);

-- ============================================================
-- Step5: データロード
-- ============================================================

CREATE OR REPLACE TEMP FILE FORMAT temp_ff TYPE = CSV SKIP_HEADER = 1;
CREATE OR REPLACE TEMP FILE FORMAT temp_ff_2 TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"';

COPY INTO EC_DATA             FROM @FILE FILE_FORMAT = (FORMAT_NAME = temp_ff)   FILES = ('ec_data.csv');
COPY INTO PRODUCT_MASTER      FROM @FILE FILE_FORMAT = (FORMAT_NAME = temp_ff)   FILES = ('product_master.csv');
COPY INTO RETAIL_DATA         FROM @FILE FILE_FORMAT = (FORMAT_NAME = temp_ff)   FILES = ('retail_data.csv');
COPY INTO CUSTOMER_REVIEWS    FROM @FILE FILE_FORMAT = (FORMAT_NAME = temp_ff)   FILES = ('customer_reviews.csv');
COPY INTO SNOW_RETAIL_DOCUMENTS FROM @FILE FILE_FORMAT = (FORMAT_NAME = temp_ff_2) FILES = ('snow_retail_documents.csv');

-- ============================================================
-- 確認クエリ
-- ============================================================
SELECT 'EC_DATA'              AS TABLE_NAME, COUNT(*) AS CNT FROM EC_DATA
UNION ALL
SELECT 'RETAIL_DATA'         , COUNT(*) FROM RETAIL_DATA
UNION ALL
SELECT 'PRODUCT_MASTER'      , COUNT(*) FROM PRODUCT_MASTER
UNION ALL
SELECT 'SNOW_RETAIL_DOCUMENTS', COUNT(*) FROM SNOW_RETAIL_DOCUMENTS
UNION ALL
SELECT 'CUSTOMER_REVIEWS'    , COUNT(*) FROM CUSTOMER_REVIEWS;
