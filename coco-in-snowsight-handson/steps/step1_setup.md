# Step 1: Workspace作成・データ準備・データ探索

**所要時間:** 20分  
**目的:** Snowsight Workspace を作成し、ハンズオン用データを準備する。Cortex Code との最初の対話を体験する。

---

## 0. Workspace の作成

1. Snowsight にログイン
2. 左ナビゲーションから **Projects → Workspaces** を選択
3. **+ Workspace** ボタンをクリック
4. 名前を入力（例: `snowretail-handson`）して作成

> Workspace はファイルやノートブックを格納できるプロジェクト空間です。  
> Cortex Code はこの Workspace 内のファイルを参照して応答します。

---

## 1. setup.sql の実行

### 1-1. SQL ファイルの作成

1. Workspace 内で **+ New File → SQL** を選択
2. ファイル名を `setup.sql` にする
3. 以下の内容を貼り付けて実行する

```sql
-- setup.sql の内容は本リポジトリの scripts/step1_setup.sql をコピーして貼り付けてください
```

> `scripts/step1_setup.sql` の内容をコピーして貼り付けてください。  
> ウェアハウス・データベース・スキーマ・テーブルが作成されます。

### 1-2. 実行確認

SQL を全選択 → **Run** ボタンで実行。  
以下のオブジェクトが作成されていることを確認:

- Database: `SNOWRETAIL_DB`
- Schema: `SNOWRETAIL_SCHEMA`
- Tables: `RETAIL_DATA`, `EC_DATA`, `PRODUCT_MASTER`, `SNOW_RETAIL_DOCUMENTS`, `CUSTOMER_REVIEWS`

---

## 2. Cortex Code でデータを探索する

1. Workspace 右下の **Cortex Code アイコン** をクリック
2. 以下のプロンプトを入力して送信:

```
SNOWRETAIL_DB.SNOWRETAIL_SCHEMA にどんなテーブルがあるか教えて。
各テーブルの概要とレコード数を調べて。
```

3. Cortex Code の応答を確認する

### 追加プロンプト例

```
RETAIL_DATA と EC_DATA のデータ品質を確認して。
NULL値やデータの偏りがあれば教えて。
```

```
商品カテゴリ別の売上金額トップ5を教えて（実店舗とECの合算）
```

---

## ポイント

- Cortex Code は SQL を自動生成して実行します
- 「なぜこのSQLを使ったか」も説明してくれます
- 間違いがあれば「〇〇を修正して」と自然言語で追加指示できます
