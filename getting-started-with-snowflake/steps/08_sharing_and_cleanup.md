# STEP 8: データの安全な共有（隣の参加者と相互共有）

## このセクションでやること

隣の席の参加者と **ペア** になり、Snowflake のデータ共有を相互に体験します。

- 自分の `citibike` データを相手に共有する（**プロバイダー**）
- 相手から共有されたデータをクエリする（**コンシューマー**）
- **実行ファイル**: `../scripts/07_data_sharing.sql`

> 💡 全員が別々のトライアルアカウントなので、本物のクロスアカウント共有を体験できます。

---

## Snowflakeの概念: Data Sharing（データ共有）

### 従来のデータ共有の課題

```
従来:
送り手 → CSV/ETL/API → 受け手
- コピーが増える・古くなる
- コスト・セキュリティリスク
```

### Snowflake のデータ共有

```
Snowflake Data Sharing:
送り手アカウント ← [ライブな参照] → 受け手アカウント
- データのコピーなし（リアルタイム）
- 送り手はデータを完全にコントロール
- 受け手はいつでもアクセス撤回可能
```

**ポイント**: データは「受け手のアカウントにコピーされる」のではなく、  
送り手のストレージを受け手が「参照できるようになる」仕組みです。

---

## ペア演習の流れ

```
[あなた]                          [隣の人]
   |  ①識別子を交換 (org.account)   |
   |  <--------------------------->  |
   |  ②自分の citibike を共有        |  ②自分の citibike を共有
   |  ----citibike_share---------->  |
   |  <---------citibike_share-----  |
   |  ③相手の共有からDB作成・クエリ   |  ③相手の共有からDB作成・クエリ
```

ペアの2人がそれぞれ「プロバイダー」かつ「コンシューマー」になります。

> **⚠️ 前提条件**: ペアの2アカウントが **同じリージョン** であること。  
> 異なるリージョン同士では直接共有できません（FAQ参照）。

---

## 手順

すべて `../scripts/07_data_sharing.sql` を上から順に実行します（`accountadmin` ロール）。

### STEP 0: 自分のアカウント識別子を交換

```sql
SELECT CURRENT_ORGANIZATION_NAME() || '.' || CURRENT_ACCOUNT_NAME() AS my_account_identifier;
SELECT CURRENT_REGION() AS my_region;
```
- 表示された識別子（例 `SFSEAPAC.TARO_TRIAL`）を **隣の人に伝える**
- リージョンが同じことをペアで確認する

### STEP 1: 自分のデータを共有（プロバイダー）

```sql
CREATE OR REPLACE SHARE citibike_share;
GRANT USAGE ON DATABASE citibike TO SHARE citibike_share;
GRANT USAGE ON SCHEMA citibike.public TO SHARE citibike_share;
GRANT SELECT ON TABLE citibike.public.trips TO SHARE citibike_share;

-- <NEIGHBOR_ACCOUNT> を隣の人の識別子に置き換える
ALTER SHARE citibike_share ADD ACCOUNTS = <NEIGHBOR_ACCOUNT>;
```

### STEP 2: 相手のデータを使う（コンシューマー）

```sql
-- <NEIGHBOR_ACCOUNT> を隣の人の識別子に置き換える
CREATE OR REPLACE DATABASE citibike_from_neighbor
    FROM SHARE <NEIGHBOR_ACCOUNT>.citibike_share;

SELECT COUNT(*) FROM citibike_from_neighbor.public.trips;
SELECT * FROM citibike_from_neighbor.public.trips LIMIT 10;
```

→ 相手のデータが **コピーなし** で見えれば成功です。

---

## UI でも確認してみよう

- 左メニュー「Horizon Catalog」→「Data sharing」
  - **Shared by your account**: 自分が共有しているもの（`citibike_share`）
  - **Shared with your account**: 相手から共有されたもの

---

## おまけ: Snowflake Marketplace

1. 左メニュー「Work with data」→「Marketplace」
2. 検索ボックスで「weather」などを検索
3. 気になるリスティングをクリックして詳細を確認
4. 「取得」ボタンで試用データを自アカウントに追加できる（コピーではなく参照）

---

## よくある質問

**Q: `ALTER SHARE ... ADD ACCOUNTS` でエラーになる**  
A: 多くの場合、ペアのアカウントが **別リージョン** です。  
直接共有は同一リージョン内のみ。異なる場合は「リスティング（組織内 / Marketplace）」を使うと  
クロスリージョン・クロスクラウドでも共有できます。

**Q: 相手の識別子の形式は？**  
A: `<組織名>.<アカウント名>`（例 `SFSEAPAC.TARO_TRIAL`）。  
`CURRENT_ACCOUNT()` が返すロケーター（ランダム文字列）とは別物なので注意。

**Q: 共有を受け取った側のコスト負担は？**  
A: データのストレージは送り手のコスト。クエリ実行は受け手のウェアハウスコスト。

**Q: 共有を取り消したい**  
A: プロバイダー側で `ALTER SHARE citibike_share REMOVE ACCOUNTS = <NEIGHBOR_ACCOUNT>;`

---

## チェックポイント

- [ ] 自分のアカウント識別子を確認し、隣の人と交換した
- [ ] `citibike_share` を作成し、隣の人のアカウントを追加した
- [ ] 隣の人の共有から `citibike_from_neighbor` を作成し、`trips` をクエリできた
- [ ] 「Horizon Catalog」→「Data sharing」で送受信を確認した

---

# STEP 9: 環境リセット

ハンズオン終了後は作成したオブジェクトをクリーンアップします。

- **実行ファイル**: `../scripts/00_cleanup.sql`

削除されるオブジェクト:
- データベース: `citibike` / `weather` / `citibike_from_neighbor`（共有受領時）
- ウェアハウス: `analytics_wh`
- ロール: `junior_dba`
- 共有: `citibike_share`（作成した場合）
