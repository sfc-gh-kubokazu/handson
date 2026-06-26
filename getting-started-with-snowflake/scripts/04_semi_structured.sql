-- =============================================================
-- STEP 5: 半構造化データ（JSON）・ビュー・JOIN
-- 対応手順書: ../steps/05_semi_structured.md
-- =============================================================
-- このファイルでは以下を実施します:
--   1. JSON データ格納用のデータベース・テーブルを作成
--   2. S3 から JSON ファイルをロード
--   3. VARIANT 型のクエリ（JSONパス記法）
--   4. ビューを作成して半構造化データに構造を付与
--   5. citibike データと JOIN して天気との相関を分析
-- =============================================================

USE ROLE sysadmin;
USE WAREHOUSE analytics_wh;

-- =============================================================
-- 1. 天気データ用のデータベースとテーブルを作成
-- =============================================================

-- 新しいデータベースを作成
CREATE DATABASE weather;

USE ROLE sysadmin;
USE WAREHOUSE analytics_wh;
USE DATABASE weather;
USE SCHEMA public;

-- VARIANT 型のテーブルを作成
-- ⚠️ ポイント: VARIANT はJSON/XML/Avroなど半構造化データをそのまま格納できる型
-- スキーマを事前定義しなくてよいのが特徴（スキーマオンリード）
CREATE TABLE json_weather_data (v VARIANT);

-- =============================================================
-- 2. 外部ステージの作成と JSON データのロード
-- =============================================================

-- S3 上の気象データへのステージを作成
CREATE STAGE nyc_weather
    URL = 's3://snowflake-workshop-lab/zero-weather-nyc';

-- ステージ内のファイルを確認
LIST @nyc_weather;

-- JSON データをテーブルにロード
-- ⚠️ STRIP_OUTER_ARRAY = TRUE: JSONの最外層の配列を除いて各要素を1行として格納
COPY INTO json_weather_data
FROM @nyc_weather
FILE_FORMAT = (TYPE = json STRIP_OUTER_ARRAY = TRUE);

-- ロードされたデータを確認（JSON がそのまま格納されている）
SELECT * FROM json_weather_data LIMIT 10;

-- =============================================================
-- 3. VARIANT 型の操作（JSONパス記法）
-- =============================================================

-- コロン記法でJSONのフィールドを参照
SELECT
    v:time::TIMESTAMP AS observation_time,    -- タイムスタンプに型キャスト
    v:city:id::INT AS city_id,                -- ネストしたフィールドにアクセス
    v:city:name::STRING AS city_name,
    v:city:country::STRING AS country,
    v:city:coord:lat::FLOAT AS city_lat,
    v:city:coord:lon::FLOAT AS city_lon,
    v:clouds:all::INT AS clouds,
    (v:main:temp::FLOAT) - 273.15 AS temp_celsius,  -- ケルビン→摂氏変換
    v:weather[0]:main::STRING AS weather_conditions, -- 配列は [0] でアクセス
    v:weather[0]:description::STRING AS weather_desc
FROM json_weather_data
WHERE city_id = 5128638  -- New York City のID
LIMIT 20;

-- =============================================================
-- 4. ビューの作成（半構造化データに構造を付与）
-- =============================================================

-- ⚠️ ポイント: ビューを使うことでJSONのパース処理を隠蔽し、
--   通常のテーブルのように使えるようになります
CREATE OR REPLACE VIEW json_weather_data_view AS
SELECT
    v:time::TIMESTAMP AS observation_time,
    v:city:id::INT AS city_id,
    v:city:name::STRING AS city_name,
    v:city:country::STRING AS country,
    v:city:coord:lat::FLOAT AS city_lat,
    v:city:coord:lon::FLOAT AS city_lon,
    v:clouds:all::INT AS clouds,
    (v:main:temp::FLOAT) - 273.15 AS temp_celsius,
    v:weather[0]:main::STRING AS weather_conditions,
    v:weather[0]:description::STRING AS weather_desc
FROM json_weather_data
WHERE city_id = 5128638;

-- ビューが作成されたか確認
SELECT *
FROM json_weather_data_view
WHERE date_trunc('month', observation_time) = '2018-01-01'
LIMIT 20;

-- =============================================================
-- 5. citibike データと JOIN して天気との相関を分析
-- =============================================================

-- 天気条件別のトリップ数を集計（異なるデータベース間のJOIN）
SELECT
    weather_conditions AS conditions,
    COUNT(*) AS num_trips
FROM citibike.public.trips AS t
LEFT OUTER JOIN json_weather_data_view AS w
    ON date_trunc('hour', t.starttime) = w.observation_time
WHERE conditions IS NOT NULL
GROUP BY 1
ORDER BY 2 DESC;

-- ⚠️ ポイント: Snowflake では異なるデータベースをまたいで JOIN できます
--   書式: <データベース名>.<スキーマ名>.<テーブル名>
