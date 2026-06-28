-- =============================================================
-- STEP 6: タイムトラベル
-- 対応手順書: ../steps/06_time_travel.md
-- =============================================================
-- このファイルでは以下を実施します:
--   1. テーブルの DROP / UNDROP（削除と復元）
--   2. 誤操作のロールバック（UPDATE で汚染されたデータを復元）
-- =============================================================

USE ROLE sysadmin;
USE WAREHOUSE analytics_wh;
USE DATABASE weather;
USE SCHEMA public;

-- =============================================================
-- 1. テーブルの DROP と UNDROP
-- =============================================================

-- テーブルを削除してみる
DROP TABLE json_weather_data;

-- 削除後にアクセスしようとするとエラーになる
-- ⚠️ 次のクエリはエラーになります（確認のため実行してみてください）
SELECT * FROM json_weather_data LIMIT 10;

-- UNDROP で復元できる！（デフォルト保持期間: Standard=1日, Enterprise=90日）
UNDROP TABLE json_weather_data;

-- 復元されたか確認
SELECT * FROM json_weather_data LIMIT 10;

-- =============================================================
-- 2. 誤操作のロールバック（タイムトラベルの実用例）
-- =============================================================

USE ROLE sysadmin;
USE WAREHOUSE analytics_wh;
USE DATABASE citibike;
USE SCHEMA public;

-- ---- 誤操作をシミュレーション ----
-- 全行の会員種別を "oops" に上書きしてしまう（WHERE句を忘れた！）
UPDATE trips SET membership_type = 'oops';

-- 被害を確認（全行が "oops" になっている）
SELECT
    membership_type AS membership,
    COUNT(*) AS rides
FROM trips
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;

-- ---- タイムトラベルで復元 ----

-- ステップ1: UPDATE 前のクエリIDを特定する
SET query_id = (
    SELECT query_id
    FROM TABLE(information_schema.query_history_by_session(result_limit => 5))
    WHERE query_text LIKE 'UPDATE%'
    ORDER BY start_time DESC
    LIMIT 1
);

-- 特定できたクエリIDを確認
SELECT $query_id;

-- ステップ2: UPDATE 実行前の状態にテーブルを戻す
-- BEFORE (statement => ...) でそのSQL実行前の状態を参照できる
CREATE OR REPLACE TABLE trips AS
(
    SELECT * FROM trips BEFORE (STATEMENT => $query_id)
);

-- 復元できたか確認（会員種別が元に戻っている）
SELECT
    membership_type AS membership,
    COUNT(*) AS rides
FROM trips
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;
