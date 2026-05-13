# Cortex Code (CoCo) Web UI 用 サンプルプロンプト集

ハンズオン中・後にCoCoへ投げると効果的なプロンプトを段階別にまとめています。

---

## 🔍 環境確認

```
現在の接続情報（アカウント・ユーザー・ロール・ウェアハウス）を教えて
```

```
HANDSON_CORTEX_AGENT.BRAZE スキーマのテーブル一覧と件数を教えて
```

```
EMAIL_SENT テーブルのスキーマと先頭5件を表示して
```

---

## 📊 セマンティックビュー作成

```
HANDSON_CORTEX_AGENT.BRAZE スキーマの6テーブル（EMAIL_SENT, EMAIL_DELIVERY,
EMAIL_OPEN, EMAIL_CLICK, CAMPAIGN_CONVERSION, CAMPAIGN_REVENUE）から、
キャンペーン×期間×国別のメールエンゲージメント分析ができる
セマンティックビュー SEMANTIC_VIEW_BRAZE_CAMPAIGN を作成してください。

主要メトリクス: 送信数、開封数、クリック数、CV数、収益合計、開封率、クリック率、CV率
主要ディメンション: CAMPAIGN_ID, COUNTRY, LANGUAGE, GENDER, 月/週/日
```

---

## 🤖 Cortex Agent 作成

```
SEMANTIC_VIEW_BRAZE_CAMPAIGN を使った Cortex Agent
TOAI_BRAZE_AGENT を作成してください。

- DB.Schema: HANDSON_CORTEX_AGENT.BRAZE
- ツール: Cortex Analyst（上記セマンティックビュー）
- 動作: 日本語質問に対し、データ根拠ある回答のみ。推測しない。
- 数値は適切な単位で返す
```

---

## ✅ Agent 動作確認 / Snowflake Intelligence 用質問

### 基本

```
直近のメール開封率トップ10キャンペーンを教えて
```

```
国別のクリック率を高い順に並べて
```

```
月次の送信数とCV件数の推移を教えて
```

### 比較・分析

```
言語別の開封率の差を教えて。最も開封されやすい言語と最も少ない言語の差は？
```

```
性別ごとのCV率を比較して
```

```
直近1週間で送信数が多いキャンペーンTOP5と、その開封率・クリック率を教えて
```

### 深掘り

```
クリック率が10%を超えるキャンペーンの共通点を分析して
```

```
収益が多いキャンペーンの上位3件と、それぞれの送信数・開封数・CV数を教えて
```

```
直近30日と前30日でクリック率が改善したキャンペーンを教えて
```

---

## 🛠️ トラブルシュート用

```
直前のSQL生成結果のエラー内容を踏まえ、修正したSEMANTIC VIEWを再作成して
```

```
TOAI_BRAZE_AGENT の現在の定義を表示して
```

```
セマンティックビュー SEMANTIC_VIEW_BRAZE_CAMPAIGN のメトリクスとディメンション一覧を教えて
```

---

## 🔁 発展（応用）

```
TOAI_BRAZE_AGENT に Cortex Search Service DOCS_SEARCH_SVC を追加して、
ドキュメント検索もできるようにアップデートして
```

```
このセマンティックビューに対して、月次のメール開封率推移を表示する
Streamlit アプリのコードを書いて
```

```
TOAI_BRAZE_AGENT にユーザーセグメント別（カスタム属性活用）の
クリック率分析メトリクスを追加して
```
