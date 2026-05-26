# SnowRetail プロジェクトルール

## プロジェクト概要

EC（オンライン）と実店舗（リテール）の両チャネルを持つ SnowRetail のデータ分析プロジェクト。

データベース: `SNOWRETAIL_DB`、スキーマ: `SNOWRETAIL_SCHEMA`

## ビジネス定義

| 用語 | 定義 |
|------|------|
| 売上 | `TOTAL_PRICE` カラムの値（税込金額） |
| チャネル | EC（オンライン販売）または RETAIL（実店舗販売）。`CHANNEL` カラムで識別 |
| カテゴリ | 商品の大分類。`CATEGORY` カラムで識別 |
| 売上月 | `TRANSACTION_DATE` カラムを DATE_TRUNC('MONTH', ...) で処理して利用 |

## SQL規約

- チャネル横断の売上分析・集計には **必ず `MART_SALES`** を使用すること
- CTE（WITH句）を使用し、サブクエリのネストは避けること
- 日本語のカラムエイリアスを使用し、ダブルクォート（"）で囲むこと（例: `SUM(AMOUNT) AS "売上合計"`）
- ORDER BY には必ず明示的なソート方向（DESC / ASC）を付けること
- LIMIT を付けて結果件数を制御すること

## 禁止事項

- `EC_DATA` と `RETAIL_DATA` を直接 JOIN してはならない（`MART_SALES` を使うこと）
- 本番テーブルへの INSERT / UPDATE / DELETE は禁止
- DROP TABLE / TRUNCATE TABLE は禁止
- CTE 名やカラム参照での日本語使用は禁止

## テーブル構成

| テーブル名 | 説明 | 用途 |
|-----------|------|------|
| EC_DATA | EC チャネルの生トランザクション | 参照のみ（分析には MART_SALES を使う） |
| RETAIL_DATA | 実店舗チャネルの生トランザクション | 参照のみ（分析には MART_SALES を使う） |
| PRODUCT_MASTER | 商品マスタ（カテゴリ・商品名） | マスタ参照 |
| MART_SALES | EC + 実店舗を統合した分析用 Dynamic Table | **メインの分析対象** |
| CUSTOMER_REVIEWS | 商品レビューデータ | レビュー分析 |
| SNOW_RETAIL_DOCUMENTS | 社内ドキュメント（マニュアル・FAQ等） | ドキュメント検索 |

## ウェアハウス

- 分析クエリには `COMPUTE_WH` を使用すること
