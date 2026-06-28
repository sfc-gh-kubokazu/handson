# STEP 6: タイムトラベル

## このセクションでやること

「削除したテーブルの復元」と「誤 UPDATE のロールバック」を体験します。

- **実行ファイル**: `../scripts/05_time_travel.sql`

---

## Snowflakeの概念: タイムトラベル

Snowflake はデータの変更履歴を一定期間保持しており、  
**過去の任意の時点のデータを参照・復元**できます。

### 保持期間

| エディション | デフォルト | 最大 |
|---|---|---|
| Standard | 1日 | 1日 |
| Enterprise 以上 | 1日 | 90日 |

### 使い方

**1. 特定の時刻より前のデータを参照:**
```sql
SELECT * FROM trips AT (TIMESTAMP => '2018-01-01 12:00:00'::TIMESTAMP);
```

**2. N 分前のデータを参照:**
```sql
SELECT * FROM trips AT (OFFSET => -60*5);  -- 5分前
```

**3. 特定の SQL 実行前のデータを参照:**
```sql
SELECT * FROM trips BEFORE (STATEMENT => '<query_id>');
```

### UNDROP
削除したテーブル・スキーマ・データベースを復元できます。

```sql
DROP TABLE json_weather_data;

-- タイムトラベルの保持期間内なら復元可能
UNDROP TABLE json_weather_data;
```

---

## 今回やること

### 1. DROP / UNDROP の体験

```
1. json_weather_data テーブルを DROP
2. SELECT → エラーになることを確認
3. UNDROP で復元
4. SELECT → 復元されたことを確認
```

### 2. 誤 UPDATE のロールバック（よりリアルなシナリオ）

```
1. trips テーブル全体を UPDATE（WHERE 句なしで誤操作）
2. 被害を確認（全行が "oops" になっている）
3. クエリ履歴から UPDATE 前のクエリ ID を取得
4. BEFORE (STATEMENT => ...) でロールバック
```

---

## 手順

1. `../scripts/05_time_travel.sql` を上から順に実行
2. DROP 後の SELECT でエラーになることを確認してから UNDROP
3. ロールバックセクションは `SET query_id = ...` → ロールバック実行の順で

### タイムトラベルの確認方法（補足）

特定の時刻の状態をクエリするだけなら:

```sql
-- 1時間前の trips テーブルを参照
SELECT COUNT(*) FROM trips AT (OFFSET => -3600);
```

---

## よくある質問

**Q: `UNDROP TABLE` が失敗する**  
A: タイムトラベルの保持期間（Standard: 1日）を超えると復元できません。  
Enterprise エディションなら最大 90日 保持できます。

**Q: クエリ ID が見つからない**  
A: クエリ履歴（アクティビティ → クエリ履歴）から手動で確認できます。  
対象の UPDATE クエリをクリックし、ID をコピーしてください。

**Q: ロールバック後もデータが "oops" になっている**  
A: `CREATE OR REPLACE TABLE trips AS (SELECT * FROM trips BEFORE ...)` の  
`BEFORE` 部分で指定したクエリ ID が正しいか確認してください。

---

## チェックポイント

- [ ] `json_weather_data` を DROP して UNDROP で復元できた
- [ ] `trips` テーブルの全行を誤 UPDATE できた（意図的な誤操作）
- [ ] タイムトラベルで UPDATE 前の状態に戻せた
- [ ] 復元後の `membership_type` が正常な会員種別に戻っている
