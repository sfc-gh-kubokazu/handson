# STEP 8: データの安全な共有とマーケットプレイス

## このセクションでやること

Snowflake のデータ共有機能と Marketplace を体験します。  
このセクションは **主に UI 操作**です（SQL は補足のみ）。

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

### 共有の種類

| 種類 | 説明 |
|---|---|
| **直接共有（Direct Share）** | 特定の Snowflake アカウントと共有 |
| **Marketplace リスティング** | 公開 or プライベートリスティングとして公開 |
| **データエクスチェンジ** | 組織内や特定グループでの共有 |

---

## UI 操作: 既存の共有を確認

1. 左メニュー「データ製品」→「プライベート共有」
2. 送信中（Outbound）タブで自分が共有しているデータを確認
3. 受信中（Inbound）タブで他者から共有されたデータを確認

---

## UI 操作: アウトバウンド共有の作成

1. 「データ製品」→「プライベート共有」→「共有を作成」
2. 共有するデータベース・テーブルを選択
3. 共有する相手の Snowflake アカウント ID を指定
4. 作成完了 → 相手アカウントで「プライベート共有データ」に表示される

> **⚠️ 注意**: このハンズオン環境では実際の共有相手がいないため作成のみ体験します。

---

## UI 操作: Snowflake Marketplace

1. 左メニュー「データ製品」→「Marketplace」
2. 検索ボックスで例えば「weather」や「COVID」と検索
3. 気になるリスティングをクリックして詳細を確認
4. 「取得」ボタンで試用データを自アカウントに追加できる

**試してみよう**:
- 「Weather Source」の天気データを検索
- 取得するとすぐに `SELECT *` できる（コピーではなく参照）

---

## SQL: アウトバウンド共有の作成（参考）

```sql
-- accountadmin ロールが必要
USE ROLE accountadmin;

-- 共有オブジェクトを作成
CREATE SHARE zero_to_snowflake_shared_data;

-- 共有にデータベースの使用権限を付与
GRANT USAGE ON DATABASE citibike TO SHARE zero_to_snowflake_shared_data;
GRANT USAGE ON SCHEMA citibike.public TO SHARE zero_to_snowflake_shared_data;
GRANT SELECT ON TABLE citibike.public.trips TO SHARE zero_to_snowflake_shared_data;

-- 相手アカウントを追加（アカウント識別子の形式: <org>.<account>）
ALTER SHARE zero_to_snowflake_shared_data ADD ACCOUNTS = <相手アカウントID>;

-- 共有の確認
SHOW SHARES;
```

---

## よくある質問

**Q: Marketplace のデータはいつ更新されるか**  
A: プロバイダーによって異なります。リスティングの詳細ページに更新頻度が記載されています。

**Q: 共有を受け取った側のコスト負担は？**  
A: データ取得（ストレージ）は送り手のコスト。クエリ実行は受け手のウェアハウスコスト。

**Q: 共有したデータを取り消したい**  
A: `ALTER SHARE ... REMOVE ACCOUNTS = ...` で特定アカウントの権限を削除できます。

---

## チェックポイント

- [ ] 「プライベート共有」画面を確認した
- [ ] Marketplace で検索し、データリスティングを閲覧した
- [ ] （オプション）Marketplace からサンプルデータを取得した

---

# STEP 9: 環境リセット

ハンズオン終了後は作成したオブジェクトをクリーンアップします。

- **実行ファイル**: `../scripts/00_cleanup.sql`

削除されるオブジェクト:
- データベース: `citibike` / `weather`
- ウェアハウス: `analytics_wh`
- ロール: `junior_dba`
- 共有: `zero_to_snowflake_shared_data`（作成した場合）
