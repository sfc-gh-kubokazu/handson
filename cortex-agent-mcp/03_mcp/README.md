# 03. MCP連携（Kiro / Claude Desktop から Snowflake Agent を呼び出す）

このステップでは、外部IDE（**Kiro**, Claude Desktop等）に
**Snowflake MCP サーバ** を設定し、ハンズオン2で作成した
`TOAI_BRAZE_AGENT` を直接呼び出せるようにします。

## 所要時間
**約35分**

## ゴール
- KiroにSnowflake MCPサーバが設定済み
- Kiroのチャットから自然言語でCortex Agentを叩ける状態
- 普段使いのIDEからSnowflake上のナレッジ・分析能力を利用できる体験を獲得

## 前提
- [02_agent](../02_agent/README.md) が完了していること
- [01_setup](../01_setup/README.md) で **PAT発行済み**
- Kiro（または Claude Desktop）がローカルにインストール済み
- ローカル環境で `uvx`（または `pipx`）が使える

---

## Step 1: 仕組みの整理（5分）

### MCP（Model Context Protocol）とは
- **AIアシスタント** ↔ **外部リソース** を繋ぐ標準プロトコル
- AIアシスタントが「使えるツール」を動的に増やせる
- KiroもMCPホストとして外部MCPサーバを呼び出せる

### Snowflake MCP サーバの役割
公式OSS [`mcp-server-snowflake`](https://github.com/Snowflake-Labs/mcp) が提供：
- **Cortex Agent** 呼び出し
- **Cortex Analyst** 呼び出し
- **Cortex Search** 呼び出し
- **SQL実行**

### 認証方式
- **PAT (Programmatic Access Token)** ベース
- 01_setupで発行済みのPATを利用

### 全体像

```
┌──────────┐  自然言語   ┌──────────────────┐  MCP   ┌────────────────┐
│ User     │────────────▶│ Kiro             │───────▶│ mcp-server-    │
│          │            │ (MCP Host/Client) │       │ snowflake       │
└──────────┘             └──────────────────┘        └────────┬───────┘
                                                              │ PAT
                                                              ▼
                                                  ┌────────────────────┐
                                                  │ TOAI_BRAZE_AGENT   │
                                                  │ (Cortex Agent)     │
                                                  └────────────────────┘
```

---

## Step 2: Snowflake 側 PAT・接続情報の確認（5分）

### 必要情報の確認

```sql
-- アカウント識別子
SELECT CURRENT_ACCOUNT() AS account_locator,
       CURRENT_REGION()  AS region;

-- ハンズオン用ユーザー・ロール・ウェアハウス
SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE();
```

控えておく情報：
- **ACCOUNT** （`<orgname>-<accountname>` 形式 / 公式ドキュメント参照）
- **USER**: 現ユーザー（参加者ごとに異なる）
- **ROLE**: `R_HANDSON` または使用ロール
- **WAREHOUSE**: `WH_HANDSON`
- **PAT**: 01_setup で発行したトークン

---

## Step 3: Kiro に MCP サーバ設定（15分）

### 設定ファイルの場所

Kiroの設定画面 → MCP Servers → 設定ファイル編集

> 💡 Kiroのバージョンによりパスや画面構成が異なります。最新の公式ドキュメントを参照してください。

### サンプル設定（`mcp.json`）

`./mcp.json.template` を参考に、自分の環境用に書き換えてください。

```json
{
  "mcpServers": {
    "snowflake": {
      "command": "uvx",
      "args": [
        "--from",
        "git+https://github.com/Snowflake-Labs/mcp",
        "mcp-server-snowflake",
        "--service-config-file",
        "/path/to/service_config.yaml"
      ],
      "env": {
        "SNOWFLAKE_ACCOUNT": "<orgname>-<accountname>",
        "SNOWFLAKE_USER": "<your_user>",
        "SNOWFLAKE_PAT": "<your_pat>",
        "SNOWFLAKE_ROLE": "R_HANDSON",
        "SNOWFLAKE_WAREHOUSE": "WH_HANDSON"
      }
    }
  }
}
```

### `service_config.yaml`（Cortex Agent公開設定）

呼び出したいCortex Agent / Analyst / Search を宣言します。

```yaml
# service_config.yaml
agent_services:
  - service_name: toai_braze_agent
    description: "Brazeメールキャンペーン分析エージェント。送信/開封/クリック/CV/収益を自然言語で分析できる"
    database_name: HANDSON_CORTEX_AGENT
    schema_name: BRAZE
    agent_name: TOAI_BRAZE_AGENT

# （任意）Cortex Analyst を直接公開する場合
# analyst_services:
#   - service_name: braze_campaign_analyst
#     semantic_view: HANDSON_CORTEX_AGENT.BRAZE.SEMANTIC_VIEW_BRAZE_CAMPAIGN
#     description: "Braze メールキャンペーンのセマンティックモデル"
```

> 💡 `mcp-server-snowflake` の最新仕様により設定キーが変わる可能性があります。
> [公式リポジトリ](https://github.com/Snowflake-Labs/mcp) を参照してください。

### 設定の反映

1. `mcp.json` を保存
2. Kiroを **再起動**（重要）
3. Kiroの「使用可能ツール」一覧に `snowflake` 関連のツールが表示されることを確認

---

## Step 4: Kiro から動作確認（10分）

### サンプル質問集

Kiroのチャット欄から：

```
@snowflake TOAI_BRAZE_AGENT に「直近のメール開封率トップ10キャンペーンは？」を聞いて
```

```
@snowflake TOAI_BRAZE_AGENT で「国別のクリック率を比較して」
```

```
@snowflake 月次の送信数とCV数の推移を分析して
```

→ Kiroが MCP 経由で Cortex Agent を呼び出し、結果を要約表示してくれればOK。

### 体験ポイント
- **普段のIDE** を離れずSnowflakeデータが触れる
- Kiroの **コード生成** と Snowflakeの **データ分析** が連携できる
  例:「このクエリ結果からダッシュボードのReactコンポーネントを書いて」
- 複数メンバーが同じAgentを叩ける = **ナレッジ共有**

---

## トラブルシュート

| 症状 | 原因 / 対処 |
|---|---|
| MCPサーバが起動しない | `uvx` が入っていない → `pip install pipx && pipx install uv` で導入 |
| 認証エラー (401) | PATが正しいか / Role/WHが指定されているか確認 |
| `SSE` 関連エラー | mcp.json で `"type": "sse"` → `"type": "http"` に変更 |
| Agentが見つからない | service_config.yaml のDB/Schema/Agent名と実体が一致しているか |
| ネットワーク到達不可 | 社内ネットワーク制約・プロキシ設定確認 |
| Cortex機能利用不可 | エディション・リージョン・`SNOWFLAKE.CORTEX_USER` ロール付与確認 |

---

## おまけ: Claude Desktop での設定例

ファイル:
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

設定内容は Kiro と同じ `mcpServers` 構造です。

---

## チェックポイント

✅ ここまでで以下が完了していればOKです：

- [ ] Kiroに `snowflake` MCP サーバが認識されている
- [ ] Kiroチャットから `TOAI_BRAZE_AGENT` を呼び出して回答が返る
- [ ] 普段使いのIDEからSnowflake分析を実行できる感覚を獲得

→ 余裕があれば **[04_advanced](../04_advanced/README.md)** で発展課題に挑戦してください。
