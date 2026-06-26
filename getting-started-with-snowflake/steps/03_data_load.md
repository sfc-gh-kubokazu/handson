# STEP 3: データのロード

## このセクションでやること

S3 上の Citi Bike データを Snowflake に取り込みます。

- **実行ファイル**: `../scripts/02_data_load.sql`

---

## Snowflakeの概念: データロードの仕組み

### COPY INTO コマンド
ステージ上のファイルをテーブルに一括コピーするコマンドです。

```sql
COPY INTO <テーブル名>
FROM @<ステージ名>
FILE_FORMAT = <ファイルフォーマット名>
PATTERN = '.*csv.*';  -- ファイル名パターン（省略可）
```

**冪等性**: 一度ロード済みのファイルは再実行しても自動的にスキップされます。  
誤って 2 回実行してもデータが重複しません。

### ウェアハウスサイジング
データロード時はウェアハウスを大きくすることで高速化できます。

| サイズ | vCPU 相当 | クレジット/時間 |
|---|---|---|
| XS | 1 | 1 |
| S | 2 | 2 |
| M | 4 | 4 |
| **L** | **8** | **8** |
| XL | 16 | 16 |

- ウェアハウスのサイズ変更はその場で即時反映されます
- ロード完了後は必ず元のサイズに戻しましょう（コスト管理）

### ウェアハウスの分離（ベストプラクティス）
同じウェアハウスをデータロードとアナリティクスクエリで共用すると、  
お互いのリソースを食い合ってパフォーマンスが落ちます。  
→ **用途別にウェアハウスを分けること**が推奨です。

```
compute_wh      ← データロード用（Small）
analytics_wh    ← アナリティクスクエリ用（Large）
```

---

## 手順

1. `../scripts/02_data_load.sql` を実行
2. COPY INTO の実行には数分かかります（待ちましょう）

### 実行後の確認ポイント

**データがロードされた:**
```sql
SELECT COUNT(*) FROM citibike.public.trips;
-- 6,000,000 件前後が表示される
```

**COPY 結果の詳細を確認:**
```sql
SELECT *
FROM TABLE(information_schema.copy_history(
    TABLE_NAME => 'TRIPS',
    START_TIME => DATEADD(HOUR, -1, CURRENT_TIMESTAMP())
));
```

**アナリティクス用ウェアハウスが作成された:**
```sql
SHOW WAREHOUSES;  -- analytics_wh が表示される
```

---

## よくある質問

**Q: `COPY executed with 0 files processed.` と表示される**  
A: すでにロード済みのファイルはスキップされます。  
テーブルを `TRUNCATE TABLE trips;` してから再実行するとロードできます。

**Q: ウェアハウスがサスペンドしていてロードが遅い**  
A: `AUTO_RESUME = TRUE` なので初回アクセス時は起動に数秒かかります。正常です。

---

## チェックポイント

- [ ] `trips` テーブルに 600万件前後のデータが入っている
- [ ] `analytics_wh` ウェアハウスが作成されている
- [ ] `compute_wh` が Small サイズに戻っている
