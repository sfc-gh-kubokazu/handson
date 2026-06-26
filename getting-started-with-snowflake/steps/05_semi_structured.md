# STEP 5: 半構造化データ・ビュー・JOIN

## このセクションでやること

JSON 形式の気象データをロードし、Citi Bike データと組み合わせて  
「天気条件ごとのトリップ数」を分析します。

- **実行ファイル**: `../scripts/04_semi_structured.sql`

---

## Snowflakeの概念

### VARIANT 型（半構造化データ）
通常のリレーショナルDBではスキーマを事前に定義する必要がありますが、  
Snowflake の **VARIANT 型** は JSON / Avro / Parquet などをそのまま格納できます。

```sql
-- 1列だけのテーブルで JSON を格納
CREATE TABLE json_weather_data (v VARIANT);
```

**メリット**:
- スキーマ変更なしで新しいフィールドを追加可能
- ネストした構造もそのまま保持

**アクセス方法**（コロン記法）:
```sql
-- JSON: {"city": {"name": "New York", "coord": {"lat": 40.7}}}
v:city:name::STRING        -- "New York"（STRINGにキャスト）
v:city:coord:lat::FLOAT    -- 40.7
v:weather[0]:main::STRING  -- 配列の先頭要素
```

### ビュー（View）
テーブルに対する「名前付きクエリ」です。  
JSON のパース処理をビューに隠蔽すると、利用者は通常のテーブルのように使えます。

```sql
CREATE OR REPLACE VIEW json_weather_data_view AS
SELECT
    v:time::TIMESTAMP AS observation_time,
    v:weather[0]:main::STRING AS weather_conditions
    ...
FROM json_weather_data;
```

これにより:
```sql
-- ビュー経由では普通のクエリが使える
SELECT * FROM json_weather_data_view WHERE ...;
```

### クロスデータベース JOIN
Snowflake では同一アカウント内であれば、  
**異なるデータベースをまたいで JOIN** できます。

```sql
FROM citibike.public.trips AS t   -- データベース: citibike
LEFT JOIN weather.public.json_weather_data_view AS w  -- データベース: weather
    ON date_trunc('hour', t.starttime) = w.observation_time
```

書式: `<データベース>.<スキーマ>.<テーブル名>`

---

## 手順

1. `../scripts/04_semi_structured.sql` をセクションごとに実行
2. 各セクションの実行結果を確認しながら進める

### 実行ステップ

| ステップ | 内容 |
|---|---|
| データベース・テーブル作成 | `weather` DB と `json_weather_data` テーブル |
| ステージ作成 | `@nyc_weather` (S3) |
| LIST @nyc_weather | ファイルが見えることを確認 |
| COPY INTO | JSON ファイルをロード |
| SELECT * | VARIANT 型のデータを確認 |
| コロン記法 | JSON フィールドを個別に取り出す |
| ビュー作成 | 半構造化データに構造を付与 |
| JOIN クエリ | 天気とトリップ数の相関を分析 |

---

## よくある質問

**Q: `v:city:id` の値が NULL になる**  
A: JSON のキーは大文字小文字を区別します。  
`SELECT * FROM json_weather_data LIMIT 1;` で実際のキー名を確認してください。

**Q: JOIN の結果が少ない / NULL が多い**  
A: Citi Bike データは 2013〜2018 年、気象データは 2016〜2019 年です。  
期間が重なる部分でのみ JOIN できます（`date_trunc` による時間の粒度も確認）。

**Q: 気温がマイナスの大きな値になる**  
A: JSON の気温はケルビン（K）単位です。摂氏に変換: `temp_kelvin - 273.15`

---

## チェックポイント

- [ ] `json_weather_data` テーブルに JSON データがロードされている
- [ ] コロン記法で JSON フィールドを取り出せた
- [ ] `json_weather_data_view` ビューが作成された
- [ ] 天気条件別のトリップ数が集計できた（`Clear` が最多のはず）
