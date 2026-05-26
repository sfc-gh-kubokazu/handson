-- ============================================================
-- cleanup.sql
-- ハンズオン環境の全削除
-- 実行: snow sql -f cleanup.sql
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- Cortex Agent
DROP CORTEX SEARCH SERVICE IF EXISTS SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.HANDSON_DOCS_SEARCH;

-- Database ごと全オブジェクト削除
-- (テーブル, Dynamic Table, Semantic View, Stage, Git Repository 等すべて含む)
DROP DATABASE IF EXISTS SNOWRETAIL_DB;

-- API Integration
DROP API INTEGRATION IF EXISTS git_api_integration;
