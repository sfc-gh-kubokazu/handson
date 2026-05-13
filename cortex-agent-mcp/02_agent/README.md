# 02. Cortex Agent 作成（CoCo Web UI ハンズオン）

このステップでは、Snowsight 内蔵の **Cortex Code (CoCo) Web UI** を使って、
**自然言語の指示だけで** セマンティックビューと Cortex Agent を作成します。

## 所要時間
**約35分**

## ゴール
- CoCo Web UI で自然言語ベースの開発体験を理解
- Brazeマートに対するセマンティックビューが作成済み
- Cortex Agent (`TOAI_BRAZE_AGENT`) が動作する状態
- Snowflake Intelligence から Agent に質問して回答を得られる

## 前提
- [01_setup](../01_setup/README.md) が完了していること

---

## Step 1: CoCo Web UI を開く（5分）

### 手順
1. Snowsight ログイン
2. 左サイドメニュー → **AI & ML** → **Cortex Code** （または **Studio** → **Cortex Code**）
3. 新規セッションを開始

> 💡 メニュー位置は環境のリリース時期により異なる場合があります。

### 起動確認

CoCoのチャット欄に以下を入力して動作確認：

```
現在の接続情報（アカウント・ユーザー・ロール・ウェアハウス）を教えて
```

→ 接続情報がチャットに返ればOK。続けて：

```
HANDSON_CORTEX_AGENT.BRAZE スキーマのテーブル一覧と件数を教えて
```

→ 6テーブル（EMAIL_SENT, EMAIL_DELIVERY, EMAIL_OPEN, EMAIL_CLICK, CAMPAIGN_CONVERSION, CAMPAIGN_REVENUE）の件数が返ればOK。

---

## Step 2: セマンティックビュー作成（15分）

### コンテキスト設定

CoCoに対して、対象スキーマを指定します。

```
これから HANDSON_CORTEX_AGENT.BRAZE スキーマで作業します。
ウェアハウスは WH_HANDSON を使ってください。
```

### セマンティックビュー作成依頼

```
HANDSON_CORTEX_AGENT.BRAZE スキーマの以下6テーブルから、
キャンペーン×期間×国別のメールエンゲージメント分析が
できるセマンティックビューを作成してください。

【対象テーブル】
- EMAIL_SENT（送信履歴）
- EMAIL_DELIVERY（配信成功）
- EMAIL_OPEN（開封）
- EMAIL_CLICK（クリック）
- CAMPAIGN_CONVERSION（CV）
- CAMPAIGN_REVENUE（収益）

【共通キー】
- USER_ID, CAMPAIGN_ID

【欲しいメトリクス】
- 送信数 / 開封数 / クリック数 / CV数 / 収益合計
- 開封率（OPEN/SENT）, クリック率（CLICK/OPEN）, CV率（CV/CLICK）

【欲しいディメンション】
- CAMPAIGN_ID, COUNTRY, LANGUAGE, GENDER
- 送信日時の月・週・日

セマンティックビュー名は SEMANTIC_VIEW_BRAZE_CAMPAIGN にしてください。
```

→ CoCo が `semantic-view` スキルを起動し、テーブル構造調査 → リレーション提案 → SEMANTIC VIEW DDL 生成 → 実行 まで対話的に進めてくれます。

### 確認

```sql
SHOW SEMANTIC VIEWS IN SCHEMA HANDSON_CORTEX_AGENT.BRAZE;
DESC SEMANTIC VIEW HANDSON_CORTEX_AGENT.BRAZE.SEMANTIC_VIEW_BRAZE_CAMPAIGN;
```

簡易動作確認：

```sql
SELECT * FROM SEMANTIC_VIEW(
  HANDSON_CORTEX_AGENT.BRAZE.SEMANTIC_VIEW_BRAZE_CAMPAIGN
  METRICS total_sent, open_rate
  DIMENSIONS country
)
LIMIT 10;
```

> 💡 メトリクス名・ディメンション名はCoCoの提案によって変わります。`DESC SEMANTIC VIEW` で確認してください。

---

## Step 3: Cortex Agent 作成（10分）

### Agent 作成依頼

```
作成した SEMANTIC_VIEW_BRAZE_CAMPAIGN を使って、
Cortex Agent を作成してください。

【Agent名】 TOAI_BRAZE_AGENT
【DB.Schema】 HANDSON_CORTEX_AGENT.BRAZE
【ツール】 Cortex Analyst（上記セマンティックビューを参照）
【動作】
- 日本語の質問にも英語で同様の意味を理解して回答
- データに基づく回答のみ。推測しない
- 数値は適切な単位（円/件/%）で返答
- 結果が0件の場合はその旨を明示

【サンプル質問】
- 直近のメール開封率トップ10キャンペーンは？
- 国別のクリック率を比較して
- 月次のCV件数推移を教えて
```

→ CoCo が `cortex-agent` スキルを起動し、Agent定義作成 → CREATE AGENT実行まで進めます。

### Agent 作成確認

```sql
SHOW AGENTS IN SCHEMA HANDSON_CORTEX_AGENT.BRAZE;
DESC AGENT HANDSON_CORTEX_AGENT.BRAZE.TOAI_BRAZE_AGENT;
```

---

## Step 4: Snowflake Intelligence から動作確認（5分）

### 手順
1. Snowsight → **AI & ML** → **Snowflake Intelligence**
2. 上部のAgent選択ドロップダウンから `TOAI_BRAZE_AGENT` を選択
3. チャット欄から以下のような質問を投げる:

#### サンプル質問集
```
直近のメール開封率トップ10キャンペーンは？
```
```
国別のクリック率を高い順に教えて
```
```
月次の送信数とCV件数の推移を教えて
```
```
言語別の開封率の差は？
```

→ Cortex Analyst が SQL を生成し、結果を自然言語で返してくれればOK。

### 出力の見方
- **生成された SQL** が確認可能（クリックで展開）
- **データソース**（どのセマンティックビューを使ったか）が明示
- **結果の可視化**（テーブル/チャート）

---

## トラブルシュート

| 症状 | 原因 / 対処 |
|---|---|
| CoCoがテーブル見つけられない | コンテキスト（DB/Schema/Warehouse）を明示して再指示 |
| セマンティックビュー検証エラー | CoCoに「エラー内容を踏まえ修正して」と再依頼 |
| Agent動作しない | `DESC AGENT` で定義確認、ツール参照のセマンティックビュー名が一致しているか確認 |
| 「データがない」と返る | 期間絞り込みが厳しすぎる。SAMPLEデータの実日付範囲を確認 |
| Cortex機能が使えない | リージョン・エディション・`SNOWFLAKE.CORTEX_USER` ロール付与確認 |

---

## チェックポイント

✅ ここまでで以下が完了していればOKです：

- [ ] CoCo Web UI が動作することを確認
- [ ] `SEMANTIC_VIEW_BRAZE_CAMPAIGN` が作成済み
- [ ] `TOAI_BRAZE_AGENT` が作成済み
- [ ] Snowflake Intelligence から自然言語で質問→回答を確認

→ 続いて **[03_mcp](../03_mcp/README.md)** で外部IDE（Kiro/Claude Desktop）からこのAgentを呼び出します。
