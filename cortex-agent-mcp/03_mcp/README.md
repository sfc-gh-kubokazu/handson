# 03. MCP連携（Snowflake-managed MCP Server + OAuth）

このステップでは、**Snowflake-managed MCP Server**（GA済み）を作成し、
**OAuth認証**で外部IDE（Kiro / Claude Desktop / Cursor等）から
ハンズオン2で作成した `TOAI_BRAZE_AGENT` を直接呼び出せるようにします。

## 所要時間
**約35分**

## ゴール
- Snowflake上にMCPサーバ（`MCP SERVER`オブジェクト）が作成済み
- OAuth Security Integrationが設定済み
- KiroにOAuth経由でMCP接続が完了
- Kiroのチャットから自然言語でCortex Agentを叩ける状態

## 前提
- [02_agent](../02_agent/README.md) が完了していること
- Kiro（または Claude Desktop / Cursor）がローカルにインストール済み
- ACCOUNTADMINまたはSecurity Integrationを作成可能なロール

---

## Step 1: 仕組みの整理（5分）

### Snowflake-managed MCP Server とは
- **Snowflakeが提供するマネージドMCPサーバ**（2025年11月GA）
- ローカルにMCPサーバを立ち上げる必要なし → **インフラ不要**
- Cortex Agent / Analyst / Search / SQL実行 / カスタムツールをツールとして公開
- **OAuth 2.0 ネイティブサポート**（推奨）／ PATも利用可
- RBACで細かく権限制御可能

### 全体像

```
┌──────────┐  自然言語   ┌──────────────────┐  MCP/HTTPS  ┌─────────────────────┐
│ User     │────────────▶│ Kiro             │────────────▶│ Snowflake-managed   │
│          │             │ (MCP Client)     │  OAuth      │ MCP Server          │
└──────────┘             └──────────────────┘             └──────────┬──────────┘
                                                                     │ RBAC
                                                                     ▼
                                                       ┌────────────────────────┐
                                                       │ TOAI_BRAZE_AGENT       │
                                                       │ (Cortex Agent)         │
                                                       └────────────────────────┘
```

### なぜ OAuth？
- 公式の推奨方式（PATはハードコードによる漏洩リスクあり）
- ユーザー単位の認可・トークン更新が標準的に管理可能
- 本番運用にそのまま乗せられる

### 接続URL形式
```
https://<account_URL>/api/v2/databases/{database}/schemas/{schema}/mcp-servers/{name}
```

> ⚠️ **重要**: アカウント識別子に `_` が含まれる場合、ホスト名では `-` に変換すること。
> 例: `acme_test_account` → `acme-test-account`

---

## Step 2: MCP Server オブジェクトを作成（10分）

CoCo Web UI または Snowsight Worksheet から実行します。

### 2-1. ハンズオン用ロールに必要権限付与

```sql
USE ROLE SECURITYADMIN;

-- 既存ロール（または使用ロール）にCortex関連権限を付与
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE R_HANDSON;

-- Agent利用権限
GRANT USAGE ON DATABASE HANDSON_CORTEX_AGENT TO ROLE R_HANDSON;
GRANT USAGE ON SCHEMA HANDSON_CORTEX_AGENT.BRAZE TO ROLE R_HANDSON;
GRANT USAGE ON AGENT HANDSON_CORTEX_AGENT.BRAZE.TOAI_BRAZE_AGENT TO ROLE R_HANDSON;

-- Semantic View（Cortex Analyst利用）
GRANT SELECT ON SEMANTIC VIEW HANDSON_CORTEX_AGENT.BRAZE.SEMANTIC_VIEW_BRAZE_CAMPAIGN TO ROLE R_HANDSON;
```

### 2-2. MCP Server を作成

```sql
USE ROLE SYSADMIN;
USE DATABASE HANDSON_CORTEX_AGENT;
USE SCHEMA BRAZE;

CREATE OR REPLACE MCP SERVER TOAI_MCP_SERVER
  FROM SPECIFICATION $$
tools:
  - name: "toai-braze-agent"
    type: "CORTEX_AGENT_RUN"
    identifier: "HANDSON_CORTEX_AGENT.BRAZE.TOAI_BRAZE_AGENT"
    description: "Brazeのメールキャンペーン分析エージェント。送信/開封/クリック/CV/収益を自然言語で分析できる。"
    title: "TOAI Braze Agent"

  - name: "braze-campaign-analyst"
    type: "CORTEX_ANALYST_MESSAGE"
    identifier: "HANDSON_CORTEX_AGENT.BRAZE.SEMANTIC_VIEW_BRAZE_CAMPAIGN"
    description: "Brazeメールキャンペーンのセマンティックビュー（直接Analyst呼び出し用）"
    title: "Braze Campaign Analyst"
$$;

-- 確認
SHOW MCP SERVERS IN SCHEMA HANDSON_CORTEX_AGENT.BRAZE;
DESC MCP SERVER TOAI_MCP_SERVER;
```

### 2-3. MCP Server へのアクセス権限付与

```sql
USE ROLE SECURITYADMIN;

-- 接続権限とツール検出
GRANT USAGE ON MCP SERVER HANDSON_CORTEX_AGENT.BRAZE.TOAI_MCP_SERVER TO ROLE R_HANDSON;
```

---

## Step 3: OAuth Security Integration 作成（10分）

OAuth認証で外部クライアント（Kiro等）からSnowflakeに接続できるようにします。

### 3-1. リダイレクトURI の確認

Kiro側のOAuth Callback URL を確認します。
- 一般的な値: `http://localhost:<port>/oauth/callback`
- Kiroのバージョン・設定により異なるため、Kiroの「Add MCP Server (OAuth)」設定画面で表示されるURIをコピー

### 3-2. Security Integration 作成

```sql
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE SECURITY INTEGRATION TOAI_MCP_OAUTH
  TYPE = OAUTH
  OAUTH_CLIENT = CUSTOM
  ENABLED = TRUE
  OAUTH_CLIENT_TYPE = 'CONFIDENTIAL'
  OAUTH_REDIRECT_URI = 'http://localhost:<port>/oauth/callback'
  OAUTH_ISSUE_REFRESH_TOKENS = TRUE
  OAUTH_REFRESH_TOKEN_VALIDITY = 7776000  -- 90日
  OAUTH_USE_SECONDARY_ROLES = NONE;

-- OAuthクライアントID と クライアントシークレットを取得
SELECT SYSTEM$SHOW_OAUTH_CLIENT_SECRETS('TOAI_MCP_OAUTH');
```

> 💡 `SYSTEM$SHOW_OAUTH_CLIENT_SECRETS` の引数は **大文字** で渡すこと。
> 返却JSONから `OAUTH_CLIENT_ID` と `OAUTH_CLIENT_SECRET` を控える。

---

## Step 4: Kiro に OAuth 設定（10分）

### 4-1. Kiro の MCP 設定画面を開く

KiroのMCP設定画面で「Add MCP Server (Streamable HTTP / OAuth)」を選択。
バージョンによりUIが異なります。

### 4-2. 設定値

| 項目 | 値 |
|---|---|
| Server URL | `https://<account_url>/api/v2/databases/HANDSON_CORTEX_AGENT/schemas/BRAZE/mcp-servers/TOAI_MCP_SERVER` |
| Auth Type | OAuth 2.0 |
| Client ID | Step 3-2で取得した OAUTH_CLIENT_ID |
| Client Secret | Step 3-2で取得した OAUTH_CLIENT_SECRET |
| Authorization URL | `https://<account_url>/oauth/authorize` |
| Token URL | `https://<account_url>/oauth/token-request` |
| Scope | `session:role:R_HANDSON` |

> ⚠️ `<account_url>` のアンダースコアは **ハイフン** に変換（例: `xy12345.us-east-1.snowflakecomputing.com`）。

### サンプル mcp.json（Kiro/Claude Desktop形式）

`./mcp.json.template` 参照。

```json
{
  "mcpServers": {
    "snowflake-toai": {
      "url": "https://<account_url>/api/v2/databases/HANDSON_CORTEX_AGENT/schemas/BRAZE/mcp-servers/TOAI_MCP_SERVER",
      "auth": {
        "type": "oauth2",
        "client_id": "<OAUTH_CLIENT_ID>",
        "client_secret": "<OAUTH_CLIENT_SECRET>",
        "authorization_url": "https://<account_url>/oauth/authorize",
        "token_url": "https://<account_url>/oauth/token-request",
        "scope": "session:role:R_HANDSON"
      }
    }
  }
}
```

### 4-3. 接続フロー

1. Kiroで保存
2. Kiro再起動
3. ツール一覧に `toai-braze-agent` が表示されたらクリックで初回認証フロー開始
4. ブラウザでSnowflakeログイン → Consent画面で **Allow**
5. Kiroに戻ると認証完了 → ツール利用可能

---

## Step 5: Kiro から動作確認（5分）

### サンプル質問集

```
@snowflake-toai TOAI_BRAZE_AGENT で「直近のメール開封率トップ10キャンペーンは？」
```

```
@snowflake-toai 「国別のクリック率を比較して」
```

```
@snowflake-toai 「月次のCV件数推移を教えて」
```

→ Kiroが MCP 経由で Cortex Agent を呼び出し、結果を返してくれればOK。

---

## トラブルシュート

| 症状 | 原因 / 対処 |
|---|---|
| 認証画面が出ない | OAUTH_REDIRECT_URI が Kiro の Callback URL と一致しているか |
| 401 / 403 | ロールにMCP SERVER USAGE / Agent USAGE / Semantic ViewへのSELECTが付与されているか |
| Tool not found | `DESC MCP SERVER` で tool 定義確認、識別子が完全修飾名か |
| ホスト名解決エラー | URLの `_` を `-` に変換 |
| Refresh tokenが切れる | OAUTH_REFRESH_TOKEN_VALIDITY を延長、再認証 |
| Cortex機能利用不可 | エディション・リージョン・`SNOWFLAKE.CORTEX_USER` ロール付与確認 |

---

## おまけ: PAT認証で代用する場合

OAuthではなくPATで動作確認したい場合は、以下手順で代替可能です。
（**本番では非推奨**、検証用途のみ）

1. Snowsight → Settings → Authentication → **Programmatic Access Tokens** から発行
2. **Role restrictions: R_HANDSON** で最小権限化
3. クライアント設定の `auth` を以下に変更:

```json
"auth": {
  "type": "bearer",
  "token": "<your_pat>"
}
```

---

## チェックポイント

✅ ここまでで以下が完了していればOKです：

- [ ] `MCP SERVER TOAI_MCP_SERVER` が作成済み
- [ ] OAuth Security Integration が有効
- [ ] Kiroに OAuth 経由で MCP サーバが認識されている
- [ ] Kiroチャットから `TOAI_BRAZE_AGENT` を呼び出して回答が返る

→ 余裕があれば **[04_advanced](../04_advanced/README.md)** で発展課題に挑戦してください。

## 参考リンク

- [Snowflake-managed MCP server (公式ドキュメント)](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp)
- [CREATE SECURITY INTEGRATION (Snowflake OAuth)](https://docs.snowflake.com/en/sql-reference/sql/create-security-integration-oauth-snowflake)
- [Resolving Cursor IDE and Claude Desktop Authentication Errors](https://community.snowflake.com/s/article/resolving-mcp-server-authentication-errors-cursor-claude)
