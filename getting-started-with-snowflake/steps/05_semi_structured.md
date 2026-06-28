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
-- このデータは観測所ごとのフラットなJSON:
-- {"name":"John F. Kennedy Airport", "region":"NY", "temp":26.7, "weatherCondition":"Fair"}
v:name::STRING            -- "John F. Kennedy Airport"
v:region::STRING          -- "NY"（州）
v:temp::FLOAT             -- 26.7（摂氏で格納済み）
v:weatherCondition::STRING -- "Fair"
v:obsTime::TIMESTAMP      -- 観測日時
```

### ビュー（View）
テーブルに対する「名前付きクエリ」です。  
JSON のパース処理をビューに隠蔽すると、利用者は通常のテーブルのように使えます。

```sql
CREATE OR REPLACE VIEW json_weather_data_view AS
SELECT
    v:obsTime::TIMESTAMP AS observation_time,
    v:station::STRING AS station_id,
    v:weatherCondition::STRING AS weather_conditions
    ...
FROM json_weather_data
WHERE v:region::STRING = 'NY';
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
JOIN nyc_weather_2018 AS w        -- weather DB のビューを月日時で集約
    ON MONTH(t.starttime) = w.m
   AND DAY(t.starttime)   = w.d
   AND HOUR(t.starttime)  = w.h
```

> ⚠️ 本ハンズオンのデータは trips が 2020-2024年、weather が 2016-2019年で**年が重ならない**ため、
> 「同じ月・日・時刻」で対応付けています（weather は JFK空港 2018年を代表使用）。

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

**Q: `v:region` などの値が NULL になる**  
A: JSON のキーは大文字小文字を区別します。  
`SELECT v FROM json_weather_data LIMIT 1;` で実際のキー名を確認してください。  
（このデータは `v:city:id` のようなネスト構造ではなく、`v:name` / `v:region` / `v:temp` などのフラット構造です）

**Q: JOIN の結果が出ない / 少ない**  
A: trips は 2020-2024年、weather は 2016-2019年で**年が重なりません**。  
そのため絶対時刻ではなく「月・日・時刻」で対応付けています（スクリプト参照）。

**Q: 気温の単位は？**  
A: このデータの `v:temp` は**摂氏（℃）で格納済み**です。ケルビン変換は不要です。

---

## チェックポイント

- [ ] `json_weather_data` テーブルに JSON データがロードされている
- [ ] コロン記法で JSON フィールドを取り出せた
- [ ] `json_weather_data_view` ビューが作成された
- [ ] 天気条件別のトリップ数が集計できた（`Clear` が最多のはず）
