-- =============================================================
-- STEP 2: データロードの準備
-- 対応手順書: ../steps/02_data_load_prep.md
-- =============================================================
-- このファイルでは以下を作成します:
--   1. データベース (citibike)
--   2. テーブル (trips)
--   3. 外部ステージ (S3バケット)
--   4. ファイルフォーマット (CSV)
-- =============================================================

-- ロールとウェアハウスをセットアップ
USE ROLE sysadmin;
USE WAREHOUSE compute_wh;

-- =============================================================
-- 1. データベースとテーブルの作成
-- =============================================================

-- データベースを作成（既存の場合は置き換え）
CREATE OR REPLACE DATABASE citibike;

-- 作成されたデータベースのスキーマを使用
USE DATABASE citibike;
USE SCHEMA public;

-- Citibike のトリップデータを格納するテーブルを作成
-- ⚠️ 注意: 列の型はソースCSVの実際の構造に合わせて定義しています
CREATE OR REPLACE TABLE trips (
    trip_id             INTEGER,         -- トリップID
    starttime           TIMESTAMP,       -- 乗車開始日時
    stoptime            TIMESTAMP,       -- 乗車終了日時
    tripduration        INTEGER,         -- 乗車時間（分）
    start_station_id    INTEGER,         -- 出発駅ID
    end_station_id      INTEGER,         -- 到着駅ID
    bikeid              STRING,          -- 自転車ID（YYYY-NNN形式）
    biketype            STRING,          -- 自転車タイプ（classic/ebike）
    rider_id            INTEGER,         -- ライダーID
    rider_name          STRING,          -- ライダー名
    birth_date          DATE,            -- 生年月日
    gender              STRING,          -- 性別（male/female/not specified）
    membership_type     STRING,          -- 会員種別（annual member/single ride等）
    payment_method      STRING,          -- 支払方法（phone/ccard）
    payment_detail      STRING,          -- 支払詳細（iphone/android/visa等）
    extra               STRING           -- 予備列
);

-- テーブルが作成されたか確認
SHOW TABLES IN DATABASE citibike;

-- =============================================================
-- 2. 外部ステージの作成（S3バケットへの参照）
-- =============================================================

-- Snowflakeが管理するS3バケットへの外部ステージを作成
-- ステージ = データファイルの置き場所への参照（S3/Azure Blob/GCS等）
CREATE OR REPLACE STAGE citibike_trips
    URL = 's3://snowflake-workshop-lab/citibike-trips-csv/';

-- ステージ内のファイルを一覧表示して確認
-- ⚠️ ファイルが大量にある場合は時間がかかります（正常です）
LIST @citibike_trips;

-- =============================================================
-- 3. ファイルフォーマットの作成
-- =============================================================

-- CSVファイルのフォーマットを定義
-- Snowflakeはロード時にこの定義を使ってファイルを解析します
CREATE OR REPLACE FILE FORMAT csv
    TYPE = 'csv'
    COMPRESSION = 'auto'     -- 圧縮形式を自動検出（.gzなど）
    FIELD_DELIMITER = ','    -- 区切り文字はカンマ
    RECORD_DELIMITER = '\n'  -- 改行コードは \n
    SKIP_HEADER = 0          -- ヘッダー行なし（Citi Bikeデータの仕様）
    FIELD_OPTIONALLY_ENCLOSED_BY = '\042'  -- フィールドをダブルクォートで囲む場合あり
    TRIM_SPACE = FALSE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    ESCAPE = 'NONE'
    ESCAPE_UNENCLOSED_FIELD = '\134'
    DATE_FORMAT = 'AUTO'
    TIMESTAMP_FORMAT = 'AUTO';

-- ファイルフォーマットが作成されたか確認
SHOW FILE FORMATS IN DATABASE citibike;
