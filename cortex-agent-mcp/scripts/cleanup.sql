-- =============================================================================
-- Cortex Agent x MCP ハンズオン: クリーンアップ用SQL
-- =============================================================================
-- ハンズオン後、作成したオブジェクトをすべて削除するためのスクリプトです。
-- 上から順に実行してください。
--
-- ⚠️  注意:
--   - HANDSON_CORTEX_AGENT データベース配下の全データが消えます
--   - WH_HANDSON ウェアハウスを共用している場合は DROP しないでください
--   - R_HANDSON ロールが他用途で使われていないか確認してから実行
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. PAT (Programmatic Access Token) を削除（必要に応じて）
--    ※ <参加者ユーザー名> は実ユーザー名に置換
-- -----------------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

ALTER USER IF EXISTS <参加者ユーザー名>
  REMOVE PROGRAMMATIC ACCESS TOKEN pat_handson_mcp;

-- 任意: 旧 OAuth Security Integration を作成していた場合のみ実行
-- DROP SECURITY INTEGRATION IF EXISTS BRAZE_MCP_OAUTH;


-- -----------------------------------------------------------------------------
-- 2. MCP Server を削除
-- -----------------------------------------------------------------------------
USE ROLE SYSADMIN;
USE DATABASE HANDSON_CORTEX_AGENT;
USE SCHEMA   BRAZE;

DROP MCP SERVER IF EXISTS HANDSON_CORTEX_AGENT.BRAZE.BRAZE_MCP_SERVER;


-- -----------------------------------------------------------------------------
-- 3. Cortex Agent を削除
-- -----------------------------------------------------------------------------
DROP AGENT IF EXISTS HANDSON_CORTEX_AGENT.BRAZE.BRAZE_AGENT;


-- -----------------------------------------------------------------------------
-- 4. セマンティックビューを削除
-- -----------------------------------------------------------------------------
DROP SEMANTIC VIEW IF EXISTS HANDSON_CORTEX_AGENT.BRAZE.SEMANTIC_VIEW_BRAZE_CAMPAIGN;


-- -----------------------------------------------------------------------------
-- 5. ハンズオン用マートテーブルを削除（DB ごと消すなら本ブロックはスキップ可）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS HANDSON_CORTEX_AGENT.BRAZE.EMAIL_SENT;
DROP TABLE IF EXISTS HANDSON_CORTEX_AGENT.BRAZE.EMAIL_DELIVERY;
DROP TABLE IF EXISTS HANDSON_CORTEX_AGENT.BRAZE.EMAIL_OPEN;
DROP TABLE IF EXISTS HANDSON_CORTEX_AGENT.BRAZE.EMAIL_CLICK;
DROP TABLE IF EXISTS HANDSON_CORTEX_AGENT.BRAZE.CAMPAIGN_CONVERSION;
DROP TABLE IF EXISTS HANDSON_CORTEX_AGENT.BRAZE.CAMPAIGN_REVENUE;


-- -----------------------------------------------------------------------------
-- 6. ハンズオン用 DB / ウェアハウス を削除
-- -----------------------------------------------------------------------------
USE ROLE SYSADMIN;

DROP DATABASE  IF EXISTS HANDSON_CORTEX_AGENT;
DROP WAREHOUSE IF EXISTS WH_HANDSON;


-- -----------------------------------------------------------------------------
-- 7. Marketplace から取得した共有DBを削除（任意）
--    ※ 他のハンズオン/業務でも参照中なら残してください
-- -----------------------------------------------------------------------------
DROP DATABASE IF EXISTS BRAZE_USER_EVENT_DEMO_DATASET;


-- -----------------------------------------------------------------------------
-- 8. ハンズオン用ロールを削除（任意）
--    ※ 他用途で利用していないか必ず確認してから実行
-- -----------------------------------------------------------------------------
USE ROLE SECURITYADMIN;

-- 個別のGRANT REVOKEを明示したい場合はこちらを使う（任意）
-- REVOKE ROLE R_HANDSON FROM USER <参加者ユーザー名>;

DROP ROLE IF EXISTS R_HANDSON;


-- =============================================================================
-- 動作確認: 残骸が無いかチェック
-- =============================================================================
SHOW DATABASES         LIKE 'HANDSON_CORTEX_AGENT';
SHOW DATABASES         LIKE 'BRAZE_USER_EVENT_DEMO_DATASET';
SHOW WAREHOUSES        LIKE 'WH_HANDSON';
SHOW ROLES             LIKE 'R_HANDSON';
SHOW INTEGRATIONS      LIKE 'BRAZE_MCP_OAUTH';  -- 旧OAuth残骸（通常は無し）
