# 04. 発展課題（Advanced）

ハンズオン本編の応用編です。**自社環境への展開・追加機能の組み込み**に向けた課題集。
時間外（持ち帰り）でも取り組めるよう独立したお題で構成しています。

---

## 課題1: 自社の実Brazeデータに置き換える

ハンズオンで使ったマートテーブルを、**自社のBrazeデータ**に切り替えてみましょう。

### ステップ
1. 自社のBrazeデータがあるDB/Schemaを確認
2. `01_setup` のCTAS SQLを自社テーブルに対応するよう修正
3. CoCoに「同じ構造のセマンティックビューを `<自社DB.Schema>` で再作成して」と依頼
4. 既存の `BRAZE_AGENT` の参照先を切り替える、または新規Agent作成

### ヒント
- 自社のBrazeデータも `USERS_MESSAGES_EMAIL_SEND_VIEW` のような構造のはず（Marketplaceデモは実際のBraze CDIスキーマと同じ）
- カスタム属性（`STRING_CUSTOM_ATTRIBUTES` 等）を活用するとセグメント分析が深まる

---

## 課題2: Cortex Search を組み込む（社内ドキュメント検索）

Agentに **Cortex Search** を追加して、ドキュメント検索もできるようにしてみましょう。

### ステップ
1. テスト用ドキュメント（マニュアル、FAQ等）をステージにアップロード
2. CoCoに「`<ドキュメントステージ>` に Cortex Search Service を作成して」と依頼
3. 既存の `BRAZE_AGENT` に Search Service を追加
4. 「キャンペーン運用ガイドにある A/Bテストの方法は？」のような質問を試す

### 効果
- データ分析（Analyst） + ドキュメントQA（Search）の **ハイブリッドAgent** が完成
- 「数字の根拠 + 運用手順」を一気通貫で回答できる

---

## 課題3: SlackからAgentを呼び出す

Slackから直接Agentを叩ける環境を作ってみましょう。

### 構成案
- Slack App → Slash Command or Mention
- Snowflake External Function or REST API → Cortex Agent 呼び出し
- 結果をSlackに投稿

### 参考
- Cortex Agent の REST API ドキュメント
- Snowflake API Integration / External Access Integration

---

## 課題4: Streamlit で Agent UI を作る

Streamlit in Snowflake で、Agentと対話するUIを作成。

### 機能例
- チャットUI（`st.chat_message`, `st.chat_input`）
- 質問履歴の保存
- 生成されたSQLの可視化
- グラフ表示（`st.altair_chart` / `st.plotly_chart`）

---

## 課題5: 複数Agentの組み合わせ（Multi-Agent）

異なる専門性のAgentを複数用意し、上位のオーケストレータAgentが振り分ける構成。

### 例
- `EMAIL_AGENT`: メール分析専門
- `PURCHASE_AGENT`: 購買行動分析専門
- `OPS_AGENT`: 運用FAQ（Search） 専門
- `ROUTER_AGENT`: ユーザー質問を受けて適切なAgentに委譲

---

## 課題6: ガバナンス強化

本番展開を見据えた権限・コスト管理。

### 観点
- ロール別アクセス制御（誰がどのAgentを叩けるか）
- Resource Monitor / Budgetでコスト上限設定
- `SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY` でユーザー別利用量モニタリング
- Audit / Lineage（誰がいつどんな質問をしたか）

### 参考SQL（ユーザー別月間利用量）
```sql
SELECT
    user_name,
    COUNT(*) AS request_count,
    SUM(token_credits) AS total_token_credits,
    SUM(COALESCE(metadata:ai_functions_credits::FLOAT, 0)) AS total_ai_func_credits,
    SUM(token_credits) + SUM(COALESCE(metadata:ai_functions_credits::FLOAT, 0)) AS total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY
WHERE start_time >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY user_name
ORDER BY total_credits DESC;
```

---

## 完了！

ここまで取り組んだ方は、**Cortex Agent + MCP の活用パターンをほぼ網羅** しています。
社内展開の際は、`prompts/` ディレクトリのプロンプト集も活用してください。
