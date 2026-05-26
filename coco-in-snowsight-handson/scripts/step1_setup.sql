// Step1: テーブル作成 //

-- ロールの指定
USE ROLE ACCOUNTADMIN;
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE;
USE WAREHOUSE COMPUTE_WH;


// Step2: 各種オブジェクトの作成 //

-- データベースの作成
CREATE OR REPLACE DATABASE SNOWRETAIL_DB;
-- スキーマの作成
CREATE OR REPLACE SCHEMA SNOWRETAIL_DB.SNOWRETAIL_SCHEMA;
-- スキーマの指定
USE SCHEMA SNOWRETAIL_DB.SNOWRETAIL_SCHEMA;

-- ステージの作成
CREATE OR REPLACE STAGE SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.FILE encryption = (type = 'snowflake_sse') DIRECTORY = (ENABLE = TRUE);


// Step3: 公開されているGitからデータとスクリプトを取得 //

-- Git連携のため、API統合を作成する
CREATE OR REPLACE API INTEGRATION git_api_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/snow-jp-handson-org/')
  ENABLED = TRUE;

-- GIT統合の作成
CREATE OR REPLACE GIT REPOSITORY GIT_INTEGRATION_FOR_COCO_CLI_HANDSON
  API_INTEGRATION = git_api_integration
  ORIGIN = 'https://github.com/snow-jp-handson-org/coco-cli-handson-jp.git';

-- チェックする
ls @GIT_INTEGRATION_FOR_COCO_CLI_HANDSON/branches/main;

-- Githubからファイルを持ってくる
COPY FILES INTO @SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.FILE FROM @GIT_INTEGRATION_FOR_COCO_CLI_HANDSON/branches/main/data/ PATTERN ='.*\\.csv$';

-- ============================================================
-- 1. データの準備
-- この章では外部にある4種類のCSVファイルをSnowflake テーブルとして投入する
-- ============================================================

use role accountadmin;
alter account set CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

-- データベースの作成, スキーマの準備
use schema snowretail_db.snowretail_schema;

-- ファイルを確認
ls @file;

-- データの投入
-- Step1: テーブル作成
create or replace TABLE EC_DATA (
	TRANSACTION_ID VARCHAR(16777216),
	TRANSACTION_DATE DATE,
	PRODUCT_ID VARCHAR(16777216),
	PRODUCT_NAME VARCHAR(16777216),
	QUANTITY NUMBER(38,0),
	UNIT_PRICE NUMBER(38,0),
	TOTAL_PRICE NUMBER(38,0)
);

create or replace TABLE RETAIL_DATA (
	TRANSACTION_ID VARCHAR(16777216),
	TRANSACTION_DATE DATE,
	PRODUCT_ID VARCHAR(16777216),
	PRODUCT_NAME VARCHAR(16777216),
	QUANTITY NUMBER(38,0),
	UNIT_PRICE NUMBER(38,0),
	TOTAL_PRICE NUMBER(38,0)
);

create or replace TABLE PRODUCT_MASTER (
 	PRODUCT_ID VARCHAR(16777216),
	PRODUCT_NAME VARCHAR(16777216),
	UNIT_PRICE NUMBER(38,0)
);

create or replace TABLE SNOW_RETAIL_DOCUMENTS (
	DOCUMENT_ID VARCHAR(16777216),
	TITLE VARCHAR(16777216),
	CONTENT VARCHAR(16777216),
	DOCUMENT_TYPE VARCHAR(16777216),
	DEPARTMENT VARCHAR(16777216),
	CREATED_AT TIMESTAMP_NTZ(9),
	UPDATED_AT TIMESTAMP_NTZ(9),
	VERSION NUMBER(38,1)
);

create or replace TABLE CUSTOMER_REVIEWS (
	REVIEW_ID VARCHAR(16777216),
	PRODUCT_ID VARCHAR(16777216),
	CUSTOMER_ID VARCHAR(16777216),
	RATING NUMBER(38,1),
	REVIEW_TEXT VARCHAR(16777216),
	REVIEW_DATE TIMESTAMP_NTZ(9),
	PURCHASE_CHANNEL VARCHAR(16777216),
	HELPFUL_VOTES NUMBER(38,0)
);

-- Step2: データロード
create or replace temp file format temp_ff
    type = csv
    skip_header = 1
; 

create or replace temp file format temp_ff_2
	TYPE=CSV
    SKIP_HEADER=1
    FIELD_OPTIONALLY_ENCLOSED_BY='"'
; 

copy into EC_DATA
from @FILE
file_format = (format_name = temp_ff)
files = ('ec_data.csv');

copy into PRODUCT_MASTER
from @FILE
file_format = (format_name = temp_ff)
files = ('product_master.csv');

copy into RETAIL_DATA
from @FILE
file_format = (format_name = temp_ff)
files = ('retail_data.csv');

copy into CUSTOMER_REVIEWS
from @FILE
file_format = (format_name = temp_ff)
files = ('customer_reviews.csv');

copy into SNOW_RETAIL_DOCUMENTS
from @FILE
file_format = (format_name = temp_ff_2)
files = ('snow_retail_documents.csv');
