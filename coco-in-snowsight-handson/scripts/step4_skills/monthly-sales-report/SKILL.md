---
name: monthly-sales-report
description: "MART_SALESデータから標準化された月次売上分析レポートを生成する。使用場面: 月次売上レポートの作成、売上トレンド分析、カテゴリ別売上サマリー生成。トリガー: 月次売上分析レポート, 月次レポート作成, MART_SALESのレポート, 売上分析レポート, 月次レポート, 月次売上を分析, 月次の売上, monthly sales report."
---

# 月次売上分析レポート生成

SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES テーブルのデータを使って、標準化された月次売上分析レポートをマークダウン形式で生成します。

## このSkillを使う場面

- 月次の売上分析レポートを定期的に生成したいとき
- カテゴリ別・商品別の売上サマリーが必要なとき
- 売上トレンドの把握と改善示唆を得たいとき

## ワークフロー

### Step 1: 対象月の確認

MART_SALES の最新月を取得する：

```sql
SELECT MAX(DATE_TRUNC('MONTH', TRANSACTION_DATE)) AS LATEST_MONTH
FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES;
```

### Step 2: 当月全体サマリーの取得

当月の総売上・総数量・前月との比較：

```sql
WITH monthly_summary AS (
    SELECT
        DATE_TRUNC('MONTH', TRANSACTION_DATE) AS SALE_MONTH,
        SUM(TOTAL_PRICE)   AS TOTAL_AMOUNT,
        SUM(QUANTITY) AS TOTAL_QUANTITY
    FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
    GROUP BY DATE_TRUNC('MONTH', TRANSACTION_DATE)
),
with_prev AS (
    SELECT
        SALE_MONTH,
        TOTAL_AMOUNT,
        TOTAL_QUANTITY,
        LAG(TOTAL_AMOUNT) OVER (ORDER BY SALE_MONTH) AS PREV_AMOUNT
    FROM monthly_summary
)
SELECT
    SALE_MONTH,
    TOTAL_AMOUNT,
    TOTAL_QUANTITY,
    PREV_AMOUNT,
    ROUND((TOTAL_AMOUNT - PREV_AMOUNT) / NULLIF(PREV_AMOUNT, 0) * 100, 1) AS MOM_PCT
FROM with_prev
WHERE SALE_MONTH = (SELECT MAX(DATE_TRUNC('MONTH', TRANSACTION_DATE)) FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES);
```

### Step 3: カテゴリ別売上集計

最新月のカテゴリ別売上・数量・平均単価を集計する：

```sql
SELECT
    CATEGORY,
    SUM(TOTAL_PRICE)                                              AS TOTAL_AMOUNT,
    SUM(QUANTITY)                                                 AS TOTAL_QUANTITY,
    ROUND(SUM(TOTAL_PRICE) / NULLIF(SUM(QUANTITY), 0), 0)        AS AVG_UNIT_PRICE
FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
WHERE DATE_TRUNC('MONTH', TRANSACTION_DATE) = (
    SELECT MAX(DATE_TRUNC('MONTH', TRANSACTION_DATE)) FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
)
GROUP BY CATEGORY
ORDER BY TOTAL_AMOUNT DESC;
```

### Step 4: 月次トレンドの取得

直近6ヶ月の月次推移を取得し、前月比を計算する：

```sql
WITH monthly AS (
    SELECT
        DATE_TRUNC('MONTH', TRANSACTION_DATE) AS SALE_MONTH,
        SUM(TOTAL_PRICE)   AS TOTAL_AMOUNT,
        SUM(QUANTITY) AS TOTAL_QUANTITY
    FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
    WHERE TRANSACTION_DATE >= DATEADD('MONTH', -5,
        (SELECT MAX(TRANSACTION_DATE) FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES))
    GROUP BY DATE_TRUNC('MONTH', TRANSACTION_DATE)
)
SELECT
    SALE_MONTH,
    TOTAL_AMOUNT,
    TOTAL_QUANTITY,
    LAG(TOTAL_AMOUNT) OVER (ORDER BY SALE_MONTH)    AS PREV_AMOUNT,
    ROUND(
        (TOTAL_AMOUNT - LAG(TOTAL_AMOUNT) OVER (ORDER BY SALE_MONTH))
        / NULLIF(LAG(TOTAL_AMOUNT) OVER (ORDER BY SALE_MONTH), 0) * 100
    , 1)                                            AS MOM_CHANGE_PCT
FROM monthly
ORDER BY SALE_MONTH;
```

### Step 5: レポートの生成

`@skills/monthly-sales-report/references/report_template.md` を参照してフォーマットを確認し、Step 1〜4で取得したデータを埋め込んでマークダウンレポートを生成する。

**レポート構成:**
1. エグゼクティブサマリー（当月総売上・総数量・前月比）
2. カテゴリ別売上ランキング（表形式、順位付き）
3. 月次売上トレンド（直近6ヶ月、表形式）
4. まとめ・示唆（3点程度、具体的な改善アクションを含む）

## よくあるエラーと対処法

### MART_SALES が存在しない場合

```
SQL compilation error: Object 'SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES' does not exist
```

→ Step 2 の Dynamic Table 作成が完了しているか確認してください。

```sql
SHOW DYNAMIC TABLES IN SCHEMA SNOWRETAIL_DB.SNOWRETAIL_SCHEMA;
```

### データが0件の場合

MART_SALES が作成直後で `INITIALIZE = ON_CREATE` のリフレッシュが未完了の可能性があります。
数分待ってから再実行してください。

```sql
SELECT CHANNEL, COUNT(*) FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES GROUP BY CHANNEL;
```

## カスタマイズポイント

このSkillは以下のようにカスタマイズできます。SKILL.mdを直接編集して再実行してください：

- **新セクションの追加**: 例）EC/実店舗チャネル比較、売上Top10商品ランキング
- **分析期間の変更**: Step 4 の `DATEADD` の値を変更（デフォルト: 直近6ヶ月）
- **対象カテゴリの絞り込み**: WHERE句にカテゴリ条件を追加
- **出力形式の変更**: マークダウン → CSVファイル保存、メール形式など

## 参照ファイル

- `skills/monthly-sales-report/references/report_template.md`: レポートのマークダウンテンプレート
- `skills/monthly-sales-report/references/report_queries.sql`: 本Skillで使用するSQLクエリ集（カスタマイズ用拡張クエリも含む）
