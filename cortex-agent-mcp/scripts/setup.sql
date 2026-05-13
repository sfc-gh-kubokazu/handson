-- =============================================================================
-- Cortex Agent x MCP ハンズオン: 実行用SQLまとめ
-- =============================================================================
-- 本ファイルはハンズオン全工程で実行するSQLを上から順にまとめたものです。
-- 個別ステップの背景・スクショは各 README を参照。
--   01_setup/README.md  02_agent/README.md  03_mcp/README.md
-- 注意: <参加者ユーザー名> / <port> / <account_url> は環境に合わせて置換。
-- =============================================================================


-- =============================================================================
-- [01_setup] Step 1: Marketplace Get 後の確認
-- (※ Get 操作自体は Snowsight UI から実施)
-- =============================================================================
SHOW DATABASES LIKE 'BRAZE_USER_EVENT_DEMO_DATASET';

SELECT COUNT(*)
FROM BRAZE_USER_EVENT_DEMO_DATASET.INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'PUBLIC';   -- 62 が返れば成功


-- =============================================================================
-- [01_setup] Step 2: ロール / DB / スキーマ / ウェアハウス作成
-- =============================================================================
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS HANDSON_CORTEX_AGENT;
CREATE SCHEMA   IF NOT EXISTS HANDSON_CORTEX_AGENT.BRAZE;

CREATE WAREHOUSE IF NOT EXISTS WH_HANDSON
  WITH WAREHOUSE_SIZE  = 'XSMALL'
       AUTO_SUSPEND    = 60
       AUTO_RESUME     = TRUE
       INITIALLY_SUSPENDED = TRUE;

-- ロール作成（任意：参加者を分離する場合のみ）
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS R_HANDSON;

GRANT USAGE ON DATABASE HANDSON_CORTEX_AGENT TO ROLE R_HANDSON;
GRANT ALL   ON SCHEMA   HANDSON_CORTEX_AGENT.BRAZE TO ROLE R_HANDSON;
-- Marketplace（共有DB）には IMPORTED PRIVILEGES を使う
GRANT IMPORTED PRIVILEGES ON DATABASE BRAZE_USER_EVENT_DEMO_DATASET TO ROLE R_HANDSON;
GRANT USAGE ON WAREHOUSE WH_HANDSON TO ROLE R_HANDSON;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE R_HANDSON;

-- 参加者ユーザーへ付与（置換要）
GRANT ROLE R_HANDSON TO USER KKUBO;


-- =============================================================================
-- [01_setup] Step 3: ハンズオン用マートテーブル作成（サンプリング）
-- =============================================================================
USE ROLE SYSADMIN;
USE DATABASE  HANDSON_CORTEX_AGENT;
USE SCHEMA    BRAZE;
USE WAREHOUSE WH_HANDSON;

-- メール送信
CREATE OR REPLACE TABLE EMAIL_SENT AS
SELECT USER_ID, EXTERNAL_USER_ID, TIME AS SENT_AT,
       CAMPAIGN_ID, CAMPAIGN_API_ID, MESSAGE_VARIATION_ID,
       CANVAS_ID, CANVAS_API_ID,
       GENDER, COUNTRY, LANGUAGE, EMAIL_ADDRESS, IP_POOL
FROM BRAZE_USER_EVENT_DEMO_DATASET.PUBLIC.USERS_MESSAGES_EMAIL_SEND_VIEW
SAMPLE (100000 ROWS);

-- メール配信
CREATE OR REPLACE TABLE EMAIL_DELIVERY AS
SELECT USER_ID, EXTERNAL_USER_ID, TIME AS DELIVERED_AT,
       CAMPAIGN_ID, CAMPAIGN_API_ID, CANVAS_ID,
       COUNTRY, LANGUAGE, EMAIL_ADDRESS
FROM BRAZE_USER_EVENT_DEMO_DATASET.PUBLIC.USERS_MESSAGES_EMAIL_DELIVERY_VIEW
SAMPLE (100000 ROWS);

-- メール開封
CREATE OR REPLACE TABLE EMAIL_OPEN AS
SELECT USER_ID, EXTERNAL_USER_ID, TIME AS OPENED_AT,
       CAMPAIGN_ID, CAMPAIGN_API_ID, CANVAS_ID,
       COUNTRY, LANGUAGE, EMAIL_ADDRESS, USER_AGENT
FROM BRAZE_USER_EVENT_DEMO_DATASET.PUBLIC.USERS_MESSAGES_EMAIL_OPEN_VIEW
SAMPLE (50000 ROWS);

-- メールクリック
CREATE OR REPLACE TABLE EMAIL_CLICK AS
SELECT USER_ID, EXTERNAL_USER_ID, TIME AS CLICKED_AT,
       CAMPAIGN_ID, CAMPAIGN_API_ID, CANVAS_ID,
       URL, LINK_ALIAS, COUNTRY, LANGUAGE, EMAIL_ADDRESS
FROM BRAZE_USER_EVENT_DEMO_DATASET.PUBLIC.USERS_MESSAGES_EMAIL_CLICK_VIEW
SAMPLE (20000 ROWS);

-- キャンペーンCV
CREATE OR REPLACE TABLE CAMPAIGN_CONVERSION AS
SELECT USER_ID, EXTERNAL_USER_ID, TIME AS CONVERTED_AT,
       CAMPAIGN_ID, CAMPAIGN_API_ID, MESSAGE_VARIATION_ID,
       CONVERSION_BEHAVIOR_INDEX,
       GENDER, COUNTRY, LANGUAGE
FROM BRAZE_USER_EVENT_DEMO_DATASET.PUBLIC.USERS_CAMPAIGNS_CONVERSION_VIEW
SAMPLE (50000 ROWS);

-- キャンペーン収益
CREATE OR REPLACE TABLE CAMPAIGN_REVENUE AS
SELECT USER_ID, EXTERNAL_USER_ID, TIME AS REVENUE_AT,
       CAMPAIGN_ID, CAMPAIGN_API_ID, MESSAGE_VARIATION_ID,
       REVENUE, GENDER, COUNTRY, LANGUAGE
FROM BRAZE_USER_EVENT_DEMO_DATASET.PUBLIC.USERS_CAMPAIGNS_REVENUE_VIEW
SAMPLE (50000 ROWS);

-- 件数確認
SELECT 'EMAIL_SENT'         AS tbl, COUNT(*) FROM EMAIL_SENT          UNION ALL
SELECT 'EMAIL_DELIVERY'           , COUNT(*) FROM EMAIL_DELIVERY      UNION ALL
SELECT 'EMAIL_OPEN'                , COUNT(*) FROM EMAIL_OPEN          UNION ALL
SELECT 'EMAIL_CLICK'               , COUNT(*) FROM EMAIL_CLICK         UNION ALL
SELECT 'CAMPAIGN_CONVERSION'       , COUNT(*) FROM CAMPAIGN_CONVERSION UNION ALL
SELECT 'CAMPAIGN_REVENUE'          , COUNT(*) FROM CAMPAIGN_REVENUE;


-- =============================================================================
-- [02_agent] セマンティックビュー / Agent
-- 通常は CoCo (Cortex Code) Web UI が自動生成して実行します。
-- 確認用 SQL のみここに記載。
-- =============================================================================
SHOW SEMANTIC VIEWS IN SCHEMA HANDSON_CORTEX_AGENT.BRAZE;
DESC SEMANTIC VIEW   HANDSON_CORTEX_AGENT.BRAZE.SEMANTIC_VIEW_BRAZE_CAMPAIGN;

-- セマンティックビュー簡易動作確認（メトリクス/ディメンション名はCoCo提案で変動）
SELECT *
FROM SEMANTIC_VIEW(
  HANDSON_CORTEX_AGENT.BRAZE.SEMANTIC_VIEW_BRAZE_CAMPAIGN
  METRICS    total_sent, open_rate
  DIMENSIONS country
)
LIMIT 10;

-- Agent 確認
SHOW AGENTS IN SCHEMA HANDSON_CORTEX_AGENT.BRAZE;
DESC AGENT             HANDSON_CORTEX_AGENT.BRAZE.BRAZE_AGENT;


-- =============================================================================
-- [03_mcp] Step 2: MCP Server 作成
-- =============================================================================
-- 2-1. ロール権限（既に01で付与済みなら不要）
USE ROLE SECURITYADMIN;

GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE R_HANDSON;
GRANT USAGE ON DATABASE HANDSON_CORTEX_AGENT TO ROLE R_HANDSON;
GRANT USAGE ON SCHEMA   HANDSON_CORTEX_AGENT.BRAZE TO ROLE R_HANDSON;
GRANT USAGE ON AGENT    HANDSON_CORTEX_AGENT.BRAZE.BRAZE_AGENT TO ROLE R_HANDSON;
GRANT SELECT ON SEMANTIC VIEW HANDSON_CORTEX_AGENT.BRAZE.SEMANTIC_VIEW_BRAZE_CAMPAIGN TO ROLE R_HANDSON;

-- 2-2. MCP Server
USE ROLE SYSADMIN;
USE DATABASE HANDSON_CORTEX_AGENT;
USE SCHEMA   BRAZE;

CREATE OR REPLACE MCP SERVER BRAZE_MCP_SERVER
  FROM SPECIFICATION $$
tools:
  - name: "braze-agent"
    type: "CORTEX_AGENT_RUN"
    identifier: "HANDSON_CORTEX_AGENT.BRAZE.BRAZE_AGENT"
    description: "Brazeのメールキャンペーン分析エージェント。送信/開封/クリック/CV/収益を自然言語で分析できる。"
    title: "Braze Agent"

  - name: "braze-campaign-analyst"
    type: "CORTEX_ANALYST_MESSAGE"
    identifier: "HANDSON_CORTEX_AGENT.BRAZE.SEMANTIC_VIEW_BRAZE_CAMPAIGN"
    description: "Brazeメールキャンペーンのセマンティックビュー（直接Analyst呼び出し用）"
    title: "Braze Campaign Analyst"
$$;

SHOW MCP SERVERS IN SCHEMA HANDSON_CORTEX_AGENT.BRAZE;
DESC MCP SERVER BRAZE_MCP_SERVER;

-- 2-3. MCP Server アクセス権限
USE ROLE SECURITYADMIN;
GRANT USAGE ON MCP SERVER HANDSON_CORTEX_AGENT.BRAZE.BRAZE_MCP_SERVER TO ROLE R_HANDSON;


-- =============================================================================
-- [03_mcp] Step 3: OAuth Security Integration
-- Kiro は mcp-remote 経由で OAuth フローを処理し、Callback ポートは
-- 以下の10候補から選ばれます（Snowflake側はURI単一値のみ登録可）。
--   3128 / 4649 / 6588 / 8008 / 9091 / 49153 / 50153 / 51153 / 52153 / 53153
-- まず代表ポート(49153)で作成し、Kiro接続時に redirect_uri_mismatch が出たら
-- 末尾の ALTER で実際のポートに更新してください。
-- =============================================================================
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE SECURITY INTEGRATION BRAZE_MCP_OAUTH
  TYPE = OAUTH
  OAUTH_CLIENT = CUSTOM
  ENABLED = TRUE
  OAUTH_CLIENT_TYPE = 'CONFIDENTIAL'
  OAUTH_REDIRECT_URI = 'http://localhost:49153/oauth/callback'
  OAUTH_ISSUE_REFRESH_TOKENS = TRUE
  OAUTH_REFRESH_TOKEN_VALIDITY = 7776000  -- 90日
  OAUTH_USE_SECONDARY_ROLES = NONE;

-- クライアントID / シークレットの取得（控えておく）
SELECT SYSTEM$SHOW_OAUTH_CLIENT_SECRETS('BRAZE_MCP_OAUTH');

-- ★ Kiro 接続後に redirect_uri_mismatch が出た場合は、エラー画面に表示された
--   ポートで以下を実行して URI を上書き:
-- ALTER SECURITY INTEGRATION BRAZE_MCP_OAUTH
--   SET OAUTH_REDIRECT_URI = 'http://localhost:<実際のポート>/oauth/callback';


-- =============================================================================
-- [片付け]
-- ハンズオン後のクリーンアップは scripts/cleanup.sql を実行してください。
-- =============================================================================
