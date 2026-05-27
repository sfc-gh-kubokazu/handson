# Step 3: Semantic View / Cortex Search / Cortex Agent

**所要時間:** 30分  
**目的:** 構造化データ・非構造化データへの自然言語アクセスと、それらを統合したエージェントを体験する。

---

## アーキテクチャ概要

```
Semantic View（構造化データの意味付け）
    +
Cortex Search（非構造化データの意味検索）
    ↓
Cortex Agent（両方を使いこなすエージェント）
```

---

## Step 3-1: Semantic View の作成

### Semantic View とは
テーブルにビジネスの意味（メトリクス・ディメンション）を付与し、自然言語でクエリできるようにするオブジェクト。

### 作成プロンプト

Cortex Code に以下を入力:

```
SNOWRETAIL_DB.SNOWRETAIL_SCHEMA の RETAIL_DATA と EC_DATA、PRODUCT_MASTER を
使って Semantic View を作成してください。

含めるメトリクス:
- 総売上金額（実店舗 + EC）
- 総売上数量（実店舗 + EC）
- チャネル別売上金額

含めるディメンション:
- 商品カテゴリ（PRODUCT_MASTER から取得）
- 販売チャネル（実店舗 / EC）
- 売上日（月単位で集計できるように）

Semantic View 名: SNOWRETAIL_SALES_SV
```

> 参考: `scripts/step3-1_semantic_view.yaml`

### 動作確認

作成後、Cortex Code で自然言語クエリを試す:

```
今月の商品カテゴリ別売上トップ3を教えて
```

```
実店舗とECの売上比率はどのくらい？
```

---

## Step 3-2: Cortex Search の作成

### Cortex Search とは
テキストデータに対するハイブリッド検索（セマンティック + キーワード）サービス。

### 作成プロンプト

```
SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.SNOW_RETAIL_DOCUMENTS テーブルの
CONTENT 列に対して Cortex Search Service を作成してください。

サービス名: SNOWRETAIL_DOCS_SEARCH
ウェアハウス: SNOW_RETAIL_WH
TARGET_LAG: '1 hour'
```

### 動作確認

```
返品ポリシーについて教えて
```

```
プロモーション施策に関するドキュメントを探して
```

---

## Step 3-3: Cortex Agent の構築

### Cortex Agent とは
Semantic View（構造化データ）と Cortex Search（非構造化データ）を組み合わせて、
複合的な質問に答えられるエージェント。

### 作成プロンプト

```
以下のツールを使う Cortex Agent を構築してください:
1. SNOWRETAIL_SALES_SV（売上の構造化データ分析）
2. SNOWRETAIL_DOCS_SEARCH（社内ドキュメント検索）

エージェント名: SNOWRETAIL_AGENT
モデル: claude-3-5-sonnet（もしくはデフォルト）
```

### 複合質問で動作確認

```
今月の売上が低いカテゴリはどれ？またその改善策として社内ドキュメントに何かヒントはある？
```

> このような質問に対して、売上データと社内ドキュメントを横断して回答してくれます。

---

## ポイント

- Semantic View があると「この列は何を意味するか」をAIが理解できる
- Cortex Search はベクトルDBを自分で構築しなくてもいい
- Cortex Agent は両方を束ねてワンストップで回答する
