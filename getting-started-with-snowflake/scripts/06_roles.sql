-- =============================================================
-- STEP 7: ロール管理とアクセス制御
-- 対応手順書: ../steps/07_roles.md
-- =============================================================
-- このファイルでは以下を実施します:
--   1. カスタムロールの作成
--   2. ロールへの権限付与
--   3. ロールの切り替えと権限確認
-- =============================================================

-- ⚠️ ここからは accountadmin ロールが必要です
USE ROLE accountadmin;

-- =============================================================
-- 1. カスタムロールの作成
-- =============================================================

-- junior_dba ロールを作成し、自分のユーザーに付与
-- ⚠️ YOUR_USERNAME_GOES_HERE を実際のユーザー名に変更してください
--   例: GRANT ROLE junior_dba TO USER TARO_YAMADA;
--   自分のユーザー名が不明な場合: SELECT CURRENT_USER();
CREATE OR REPLACE ROLE junior_dba;

GRANT ROLE junior_dba TO USER YOUR_USERNAME_GOES_HERE;

-- ユーザー名がわからない場合はこちらを使用:
-- GRANT ROLE junior_dba TO USER (SELECT CURRENT_USER());

-- =============================================================
-- 2. ロールを切り替えて権限を確認
-- =============================================================

-- junior_dba ロールに切り替え
USE ROLE junior_dba;

-- ⚠️ この状態でウェアハウスやデータベースにアクセスしようとするとエラーになる
-- まだ何の権限も付与されていないから
USE WAREHOUSE compute_wh;  -- エラーになる（確認用）

-- =============================================================
-- 3. ロールに権限を付与（accountadmin で実行）
-- =============================================================

-- accountadmin に戻って権限を付与していく
USE ROLE accountadmin;

-- ウェアハウスの使用権限を付与
GRANT USAGE ON WAREHOUSE compute_wh TO ROLE junior_dba;

-- junior_dba に切り替えて確認
USE ROLE junior_dba;
USE WAREHOUSE compute_wh;  -- 今度は成功する

-- accountadmin に戻ってデータベースの使用権限も付与
USE ROLE accountadmin;

GRANT USAGE ON DATABASE citibike TO ROLE junior_dba;
GRANT USAGE ON SCHEMA citibike.public TO ROLE junior_dba;
GRANT SELECT ON ALL TABLES IN SCHEMA citibike.public TO ROLE junior_dba;

GRANT USAGE ON DATABASE weather TO ROLE junior_dba;
GRANT USAGE ON SCHEMA weather.public TO ROLE junior_dba;
GRANT SELECT ON ALL TABLES IN SCHEMA weather.public TO ROLE junior_dba;

-- junior_dba でデータを参照できるか確認
USE ROLE junior_dba;
USE WAREHOUSE compute_wh;
SELECT COUNT(*) FROM citibike.public.trips;

-- =============================================================
-- 4. ロール階層の確認（accountadmin で実行）
-- =============================================================

USE ROLE accountadmin;

-- 自分に付与されているロール一覧
SHOW GRANTS TO USER YOUR_USERNAME_GOES_HERE;

-- ロールに付与されている権限一覧
SHOW GRANTS TO ROLE junior_dba;

-- ロール階層を確認（sysadmin の親ロール等）
SHOW ROLES;
