# 03. MCP連携（Snowflake-managed MCP Server + PAT）

このステップでは、**Snowflake-managed MCP Server**（GA済み）を作成し、
**PAT（Programmatic Access Token）認証** で外部IDE（Kiro / Cursor / Claude Desktop等）から
ハンズオン2で作成した `BRAZE_AGENT` を直接呼び出せるようにします。

## 所要時間
**約35分**

## ゴール
- Snowflake上にMCPサーバ（`MCP SERVER`オブジェクト）が作成済み
- PAT が R_HANDSON ロール制限付きで発行済み
- Kiro に PAT 経由で MCP 接続が完了
- Kiro のチャットから自然言語で Cortex Agent を叩ける状態

## 前提
- [02_agent](../02_agent/README.md) が完了していること
- Kiro（または Claude Desktop / Cursor）がローカルにインストール済み
- Node.js / `npx` が実行可能（`mcp-remote` を利用する場合）
- ACCOUNTADMIN または PAT を発行可能なロール

---

## Step 1: 仕組みの整理（5分）

### Model Context Protocol (MCP) とは？

![MCP Overview](../assets/screenshots/03_mcp/01_mcp_overview.png)

MCP は、AIアプリ（**MCP Host / Client**）と外部ツール・データソース（**MCP Server**）の間の通信を標準化するオープンプロトコル。Kiro / Claude Desktop / Cursor 等のIDEはすべて MCP Client として動作します。

### Snowflake-managed MCP Server のメリット

![Snowflake Managed MCP Benefits](../assets/screenshots/03_mcp/02_snowflake_managed_mcp_benefits.png)

- **相互運用性** — どのMCP Clientからでも接続可能
- **標準化されたインターフェース** — 統一されたツール公開
- **ガバナンス** — Snowflake RBAC・ネットワークポリシーがそのまま適用

### 公開できるツール

![Snowflake Managed MCP Tools](../assets/screenshots/03_mcp/03_snowflake_managed_mcp_tools.png)

Cortex Agents / Cortex Search / Cortex Analyst / SQL 実行 / カスタムUDF をMCPツールとしてClient側に公開できます。

---

### なぜ PAT？（OAuth ではない理由）

Kiro / Cursor / Claude Desktop など `mcp-remote` 系クライアントは、OAuth フローの初手で
**Dynamic Client Registration (RFC 7591)** を試みますが、Snowflake-managed MCP Server は
このエンドポイントを公開していないため、Custom OAuth では `Incompatible auth server: does not support dynamic client registration` で接続失敗します。

公式 KB（[Resolving Cursor IDE and Claude Desktop Authentication Errors](https://community.snowflake.com/s/article/resolving-mcp-server-authentication-errors-cursor-claude)）でも、これらのクライアントには **PAT を Bearer として渡す方式** が「現状サポートされる経路」として明示されています。

> 💡 OAuth は Snowflake Intelligence など Snowflake 自身が制御するクライアント向け、
> または `--static-oauth-client-info` を扱える上級ユースケース向けです。

### 全体像

```
┌──────────┐  自然言語   ┌──────────────────┐  HTTPS + Bearer  ┌─────────────────────┐
│ User     │────────────▶│ Kiro             │─────────────────▶│ Snowflake-managed   │
│          │             │ (mcp-remote)     │     PAT          │ MCP Server          │
└──────────┘             └──────────────────┘                  └──────────┬──────────┘
                                                                          │ RBAC
                                                                          ▼
                                                            ┌────────────────────────┐
                                                            │ BRAZE_AGENT            │
                                                            │ (Cortex Agent)         │
                                                            └────────────────────────┘
```

### 接続URL形式
```
https://<account_url>/api/v2/databases/{database}/schemas/{schema}/mcp-servers/{name}
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
GRANT USAGE ON AGENT HANDSON_CORTEX_AGENT.BRAZE.BRAZE_AGENT TO ROLE R_HANDSON;

-- Semantic View（Cortex Analyst利用）
GRANT SELECT ON SEMANTIC VIEW HANDSON_CORTEX_AGENT.BRAZE.SEMANTIC_VIEW_BRAZE_CAMPAIGN TO ROLE R_HANDSON;
```

### 2-2. MCP Server を作成

```sql
USE ROLE SYSADMIN;
USE DATABASE HANDSON_CORTEX_AGENT;
USE SCHEMA BRAZE;

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

-- 確認
SHOW MCP SERVERS IN SCHEMA HANDSON_CORTEX_AGENT.BRAZE;
DESC MCP SERVER BRAZE_MCP_SERVER;
```

### 2-3. MCP Server へのアクセス権限付与

```sql
USE ROLE SECURITYADMIN;

-- 接続権限とツール検出
GRANT USAGE ON MCP SERVER HANDSON_CORTEX_AGENT.BRAZE.BRAZE_MCP_SERVER TO ROLE R_HANDSON;
```

---

## Step 3: PAT 発行（5分）

### 3-1. PAT を発行（SQL）

```sql
USE ROLE ACCOUNTADMIN;

ALTER USER IF EXISTS <参加者ユーザー名>
  ADD PROGRAMMATIC ACCESS TOKEN pat_handson_mcp
    ROLE_RESTRICTION = 'R_HANDSON'
    DAYS_TO_EXPIRY = 7
    COMMENT = 'Cortex Agent x MCP handson';
```

> ⚠️ コマンド出力に表示される `token_secret` は **二度と表示されません**。必ずコピーして安全な場所に保管してください。
> 万一控え忘れた場合は `ALTER USER ... ROTATE PROGRAMMATIC ACCESS TOKEN pat_handson_mcp` で再発行できます。

### 3-2. （任意）Snowsight UI からの発行

CLI ではなく Snowsight でも発行できます:
1. Snowsight 右上のユーザーメニュー → **Settings**
2. **Authentication** → **Programmatic Access Tokens**
3. **+ Generate new token** → Name: `pat_handson_mcp` / Role restriction: `R_HANDSON` / Expiration: 7日

---

## Step 4: Kiro に MCP を設定（10分）

### 4-1. mcp.json を直接編集

Kiro には MCP 用 GUI が無いため、`~/.kiro/settings/mcp.json` を編集します。
PAT を **Bearer トークン** として渡します（公式 KB が示す形式）。

```json
{
  "mcpServers": {
    "snowflake-braze": {
      "url": "https://<account_url>/api/v2/databases/HANDSON_CORTEX_AGENT/schemas/BRAZE/mcp-servers/BRAZE_MCP_SERVER",
      "headers": {
        "Authorization": "Bearer <YOUR_PAT>"
      },
      "disabled": false,
      "autoApprove": []
    }
  }
}
```

> ⚠️ `<account_url>` は `xy12345.us-east-1.snowflakecomputing.com` 形式。
> アンダースコアは **ハイフン** に変換してください。
> 詳細サンプルは `./mcp.json.template` を参照。

### 4-2. mcp-remote 経由で接続したい場合（任意）

直接URLでうまく繋がらない環境では、`mcp-remote` をプロキシとして挟めます:

```json
{
  "mcpServers": {
    "snowflake-braze": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://<account_url>/api/v2/databases/HANDSON_CORTEX_AGENT/schemas/BRAZE/mcp-servers/BRAZE_MCP_SERVER",
        "--header", "Authorization: Bearer <YOUR_PAT>"
      ],
      "disabled": false,
      "autoApprove": []
    }
  }
}
```

### 4-3. 接続フロー

1. `mcp.json` を保存
2. Kiro 左パネル → **MCP Servers** タブで `snowflake-braze` を再接続
   （または `Cmd+Shift+P` → "MCP" 検索 → 再接続コマンド）
3. ツール一覧に `braze-agent` / `braze-campaign-analyst` が表示されれば成功

---

## Step 5: Kiro から動作確認（5分）

### サンプル質問集

```
@snowflake-braze BRAZE_AGENT で「直近のメール開封率トップ10キャンペーンは？」
```

```
@snowflake-braze 「国別のクリック率を比較して」
```

```
@snowflake-braze 「月次のCV件数推移を教えて」
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

- [ ] `MCP SERVER BRAZE_MCP_SERVER` が作成済み
- [ ] OAuth Security Integration が有効
- [ ] Kiroに OAuth 経由で MCP サーバが認識されている
- [ ] Kiroチャットから `BRAZE_AGENT` を呼び出して回答が返る

→ 余裕があれば **[04_advanced](../04_advanced/README.md)** で発展課題に挑戦してください。

## 参考リンク

- [Snowflake-managed MCP server (公式ドキュメント)](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp)
- [CREATE SECURITY INTEGRATION (Snowflake OAuth)](https://docs.snowflake.com/en/sql-reference/sql/create-security-integration-oauth-snowflake)
- [Resolving Cursor IDE and Claude Desktop Authentication Errors](https://community.snowflake.com/s/article/resolving-mcp-server-authentication-errors-cursor-claude)
