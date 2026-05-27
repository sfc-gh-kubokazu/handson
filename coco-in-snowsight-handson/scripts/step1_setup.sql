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

-- =============================================================================
-- MART_SALES: EC + 実店舗を統合した分析用 Dynamic Table
-- Step 3以降（Semantic View / Cortex Agent / Skills / Streamlit）で使用される
-- 統合テーブル。BRAND と CATEGORY を商品IDから自動付与する。
-- =============================================================================
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA SNOWRETAIL_DB.SNOWRETAIL_SCHEMA;

create or replace dynamic table SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES(
        TRANSACTION_ID,
        TRANSACTION_DATE,
        CHANNEL,
        PRODUCT_ID,
        PRODUCT_NAME,
        BRAND,
        CATEGORY,
        QUANTITY,
        UNIT_PRICE,
        TOTAL_PRICE
) target_lag = '7 days' refresh_mode = AUTO initialize = ON_CREATE warehouse = COMPUTE_WH
 as
    SELECT
      src.TRANSACTION_ID,
      src.TRANSACTION_DATE,
      src.SALES_CHANNEL,
      src.PRODUCT_ID,
      COALESCE(pm.PRODUCT_NAME, src.PRODUCT_NAME) AS PRODUCT_NAME,
      CASE
        WHEN pm.PRODUCT_NAME LIKE 'スノーテック%' THEN 'スノーテック'
        WHEN pm.PRODUCT_NAME LIKE 'フジヤマ電機%' THEN 'フジヤマ電機'
        WHEN pm.PRODUCT_NAME LIKE 'サクラ電器%' THEN 'サクラ電器'
        WHEN pm.PRODUCT_NAME LIKE 'アオゾラ電機%' THEN 'アオゾラ電機'
        WHEN pm.PRODUCT_NAME LIKE 'ミライ電機%' THEN 'ミライ電機'
        WHEN pm.PRODUCT_NAME LIKE 'ヤマトエアコン%' OR pm.PRODUCT_NAME LIKE 'ヤマト IH%' THEN 'ヤマト'
        WHEN pm.PRODUCT_NAME LIKE 'グローバルビジョン%' THEN 'グローバルビジョン'
        WHEN pm.PRODUCT_NAME LIKE 'グローバルゲーム%' THEN 'グローバルゲーム'
        WHEN pm.PRODUCT_NAME LIKE 'プリズム光学%' THEN 'プリズム光学'
        WHEN pm.PRODUCT_NAME LIKE 'クリスタルビジョン%' THEN 'クリスタルビジョン'
        WHEN pm.PRODUCT_NAME LIKE 'レンズマスター%' THEN 'レンズマスター'
        WHEN pm.PRODUCT_NAME LIKE 'ビジョンプロ%' THEN 'ビジョンプロ'
        WHEN pm.PRODUCT_NAME LIKE 'デジタルスカイ%' THEN 'デジタルスカイ'
        WHEN pm.PRODUCT_NAME LIKE 'テクノスフィア%' THEN 'テクノスフィア'
        WHEN pm.PRODUCT_NAME LIKE 'オフィスプロ%' THEN 'オフィスプロ'
        WHEN pm.PRODUCT_NAME LIKE 'プリントマスター%' THEN 'プリントマスター'
        WHEN pm.PRODUCT_NAME LIKE 'テクノセラミック%' THEN 'テクノセラミック'
        WHEN pm.PRODUCT_NAME LIKE 'ゆきだるま食品%' THEN 'ゆきだるま食品'
        WHEN pm.PRODUCT_NAME LIKE 'サファイア飲料%' THEN 'サファイア飲料'
        WHEN pm.PRODUCT_NAME LIKE 'サンシャイン製菓%' THEN 'サンシャイン製菓'
        WHEN pm.PRODUCT_NAME LIKE 'ハッピースイーツ%' THEN 'ハッピースイーツ'
        WHEN pm.PRODUCT_NAME LIKE 'ホームキッチン%' THEN 'ホームキッチン'
        WHEN pm.PRODUCT_NAME LIKE 'クリアウォーター%' THEN 'クリアウォーター'
        WHEN pm.PRODUCT_NAME LIKE 'ヘルシー乳業%' THEN 'ヘルシー乳業'
        WHEN pm.PRODUCT_NAME LIKE 'まるまる食品%' THEN 'まるまる食品'
        WHEN pm.PRODUCT_NAME LIKE 'スマイル製菓%' THEN 'スマイル製菓'
        WHEN pm.PRODUCT_NAME LIKE 'ドリーム製菓%' THEN 'ドリーム製菓'
        WHEN pm.PRODUCT_NAME LIKE 'クラシック食品%' THEN 'クラシック食品'
        WHEN pm.PRODUCT_NAME LIKE 'フレッシュベジ%' THEN 'フレッシュベジ'
        WHEN pm.PRODUCT_NAME LIKE 'ブルーウェーブ%' THEN 'ブルーウェーブ'
        WHEN pm.PRODUCT_NAME LIKE 'フレッシュケア%' THEN 'フレッシュケア'
        WHEN pm.PRODUCT_NAME LIKE 'ソフトケア%' THEN 'ソフトケア'
        WHEN pm.PRODUCT_NAME LIKE 'クリーンライフ%' THEN 'クリーンライフ'
        WHEN pm.PRODUCT_NAME LIKE 'ビューティーラボ%' THEN 'ビューティーラボ'
        WHEN pm.PRODUCT_NAME LIKE 'ヘルスケアプラス%' THEN 'ヘルスケアプラス'
        WHEN pm.PRODUCT_NAME LIKE 'ケアファーム%' THEN 'ケアファーム'
        WHEN pm.PRODUCT_NAME LIKE 'コスメラボ%' THEN 'コスメラボ'
        WHEN pm.PRODUCT_NAME LIKE 'シンプルウェア%' THEN 'シンプルウェア'
        WHEN pm.PRODUCT_NAME LIKE 'ナチュラルスタイル%' THEN 'ナチュラルスタイル'
        WHEN pm.PRODUCT_NAME LIKE 'ベーシックウェア%' THEN 'ベーシックウェア'
        WHEN pm.PRODUCT_NAME LIKE 'スカイライン文具%' THEN 'スカイライン文具'
        WHEN pm.PRODUCT_NAME LIKE 'ダイヤモンド文具%' THEN 'ダイヤモンド文具'
        WHEN pm.PRODUCT_NAME LIKE 'オフィスワーク%' THEN 'オフィスワーク'
        WHEN pm.PRODUCT_NAME LIKE 'カラーライン%' THEN 'カラーライン'
        WHEN pm.PRODUCT_NAME LIKE 'グリーンペンシル%' THEN 'グリーンペンシル'
        WHEN pm.PRODUCT_NAME LIKE 'ペンマスター%' THEN 'ペンマスター'
        WHEN pm.PRODUCT_NAME LIKE 'アート文具%' THEN 'アート文具'
        WHEN pm.PRODUCT_NAME LIKE 'オフィスプラス%' THEN 'オフィスプラス'
        WHEN pm.PRODUCT_NAME LIKE 'ワンダートイ%' THEN 'ワンダートイ'
        WHEN pm.PRODUCT_NAME LIKE 'ファンタジートイ%' THEN 'ファンタジートイ'
        WHEN pm.PRODUCT_NAME LIKE 'ゲームワールド%' THEN 'ゲームワールド'
        WHEN pm.PRODUCT_NAME LIKE 'スノーフレッシュ%' THEN 'スノーフレッシュ'
        WHEN pm.PRODUCT_NAME LIKE 'スノーセレクト%' THEN 'スノーセレクト'
        WHEN pm.PRODUCT_NAME LIKE 'スノーデリ%' THEN 'スノーデリ'
        ELSE 'その他'
      END AS BRAND,
      CASE
        WHEN src.PRODUCT_ID IN ('P001','P002','P003','P011','P016','P081','P082','P090') THEN 'テレビ・映像機器'
        WHEN src.PRODUCT_ID IN ('P024','P025','P028','P092','P093','P094','P095','P096') THEN 'カメラ'
        WHEN src.PRODUCT_ID IN ('P029','P030','P031','P032','P097','P098','P099','P100') THEN 'プリンター・OA機器'
        WHEN src.PRODUCT_ID IN ('P014','P018','P020','P021','P022','P023','P079','P083','P084','P085','P086') THEN '生活家電'
        WHEN src.PRODUCT_ID IN ('P017','P078','P080') THEN '映像・音響機器'
        WHEN src.PRODUCT_ID IN ('P019','P075','P076','P077','P087','P088','P089','P091') THEN 'デジタル・ゲーム'
        WHEN src.PRODUCT_ID IN ('P026','P027') THEN 'PC'
        WHEN src.PRODUCT_ID IN ('P004','P005','P012','P015','P033','P034','P035','P036','P037','P038','P039','P040','P041') THEN '食品・飲料'
        WHEN src.PRODUCT_ID IN ('P101','P102','P103','P104','P105','P106','P107','P108','P109','P110','P111','P112') THEN '生鮮・日配'
        WHEN src.PRODUCT_ID IN ('P113','P114','P115','P116','P117','P118') THEN '精肉・鮮魚・惣菜'
        WHEN src.PRODUCT_ID IN ('P119','P120','P121','P122','P123','P124','P125') THEN 'ミールキット'
        WHEN src.PRODUCT_ID IN ('P006','P013','P042','P043','P044','P045','P046','P047','P048') THEN '日用品・ヘルスケア'
        WHEN src.PRODUCT_ID IN ('P007','P008','P049','P050','P051','P052','P053','P054','P055') THEN '衣料品'
        WHEN src.PRODUCT_ID IN ('P009','P056','P057','P058','P059','P060','P061','P062','P063','P064','P065') THEN '文具'
        WHEN src.PRODUCT_ID IN ('P010','P066','P067','P068','P069','P070','P071','P072','P073','P074') THEN '玩具'
        ELSE 'その他'
      END AS CATEGORY,
      src.QUANTITY,
      src.UNIT_PRICE,
      src.TOTAL_PRICE
    FROM (
      SELECT *, 'EC' AS SALES_CHANNEL FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.EC_DATA
      UNION ALL
      SELECT *, 'RETAIL' AS SALES_CHANNEL FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.RETAIL_DATA
    ) src
    LEFT JOIN SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.PRODUCT_MASTER pm
      ON src.PRODUCT_ID = pm.PRODUCT_ID;
