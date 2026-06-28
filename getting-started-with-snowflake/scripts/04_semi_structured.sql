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
-- ⚠️ このデータは気象観測所ごとのフラットなJSON構造です
--   （観測所: JFK空港 / Newark空港 / New York Wall Street の3地点）
SELECT
    v:obsTime::TIMESTAMP AS observation_time,   -- 観測日時（型キャスト）
    v:station::STRING AS station_id,            -- 観測所ID
    v:name::STRING AS station_name,             -- 観測所名
    v:region::STRING AS region,                 -- 州（NY / NJ）
    v:country::STRING AS country,
    v:latitude::FLOAT AS lat,
    v:longitude::FLOAT AS lon,
    v:temp::FLOAT AS temp_celsius,              -- 気温（このデータは摂氏で格納済み）
    v:rhum::INT AS humidity,                    -- 湿度(%)
    v:wspd::FLOAT AS wind_speed,                -- 風速
    v:weatherCondition::STRING AS weather_conditions  -- 天気（Fair/Rain等）
FROM json_weather_data
WHERE v:region::STRING = 'NY'   -- ニューヨーク州の観測所に絞る
LIMIT 20;

-- =============================================================
-- 4. ビューの作成（半構造化データに構造を付与）
-- =============================================================

-- ⚠️ ポイント: ビューを使うことでJSONのパース処理を隠蔽し、
--   通常のテーブルのように使えるようになります
CREATE OR REPLACE VIEW json_weather_data_view AS
SELECT
    v:obsTime::TIMESTAMP AS observation_time,
    v:station::STRING AS station_id,
    v:name::STRING AS station_name,
    v:region::STRING AS region,
    v:country::STRING AS country,
    v:latitude::FLOAT AS lat,
    v:longitude::FLOAT AS lon,
    v:temp::FLOAT AS temp_celsius,
    v:rhum::INT AS humidity,
    v:wspd::FLOAT AS wind_speed,
    v:weatherCondition::STRING AS weather_conditions
FROM json_weather_data
WHERE v:region::STRING = 'NY';

-- ビューが作成されたか確認（2018年1月のデータを表示）
SELECT *
FROM json_weather_data_view
WHERE date_trunc('month', observation_time) = '2018-01-01'
LIMIT 20;

-- =============================================================
-- 5. citibike データと JOIN して天気との相関を分析
-- =============================================================

-- 天気条件別のトリップ数を集計（異なるデータベース間のJOIN）
-- ⚠️ データの年が重ならないため（trips: 2020-2024年 / weather: 2016-2019年）、
--   ここでは「同じ月・日・時刻」の天気にトリップを対応付けて相関を見ます（デモ用）。
--   weather は代表として JFK空港(74486) の 2018年 を使用します。
WITH nyc_weather_2018 AS (
    SELECT
        MONTH(observation_time) AS m,
        DAY(observation_time)   AS d,
        HOUR(observation_time)  AS h,
        weather_conditions
    FROM json_weather_data_view
    WHERE station_id = '74486'                  -- JFK空港
      AND YEAR(observation_time) = 2018
      AND weather_conditions IS NOT NULL
      AND weather_conditions <> 'None'
)
SELECT
    w.weather_conditions AS conditions,
    COUNT(*) AS num_trips
FROM citibike.public.trips AS t
JOIN nyc_weather_2018 AS w
    ON  MONTH(t.starttime) = w.m
    AND DAY(t.starttime)   = w.d
    AND HOUR(t.starttime)  = w.h
GROUP BY 1
ORDER BY 2 DESC;

-- ⚠️ ポイント: Snowflake では異なるデータベースをまたいで JOIN できます
--   書式: <データベース名>.<スキーマ名>.<テーブル名>
