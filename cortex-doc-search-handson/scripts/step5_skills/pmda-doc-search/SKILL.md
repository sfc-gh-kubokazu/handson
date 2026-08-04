---
name: pmda-doc-search
description: "PMDA公開文書（電子添文・審議結果報告書）を Cortex Search で検索し、出典付きで回答する。製品横断の比較表も作れる。使用場面: 添付文書の記載を調べる、禁忌や用法用量の確認、副作用や相互作用の確認、複数製品の記載を比較する。トリガー: 添付文書, 電子添文, 添文, 禁忌, 効能, 用法用量, 副作用, 相互作用, 審査報告書, PMDA, 製品比較, この薬は."
---

# PMDA公開文書の検索と回答

`DOC_SEARCH_HANDSON.HANDSON.PMDA_DOC_SEARCH`（Cortex Search サービス）を使って、
医薬品の電子添文・審議結果報告書から根拠となる記載を探し、出典付きで回答します。

## このSkillを使う場面

- 「この薬は腎機能障害の患者に使えるか」のように、添付文書の記載を確認したいとき
- 複数製品の記載を並べて比較したいとき
- 回答に必ず出典（製品名・文書種別・ページ）を付けたいとき

## 絶対に守ること

1. **検索結果に書かれていないことは書かない。** 一般知識で補完しない。
   見つからなければ「検索対象の文書には記載がありません」と答える。
2. **回答の各記述に出典を付ける。** 形式は `（製品名／文書種別／Nページ）`。
3. **対象は下記4文書のみ。** これ以外の製品を聞かれたら、対象外であることを伝える。
   - ダパグリフロジン錠「サワイ」（電子添文／SGLT2阻害薬）
   - ジャヌビア錠（電子添文／DPP-4阻害薬）
   - マンジャロ皮下注アテオス（電子添文／GIP/GLP-1受容体作動薬）
   - フォシーガ錠（審議結果報告書／SGLT2阻害薬）
4. **医療上の判断や推奨はしない。** 文書の記載を伝えるにとどめる。

## ワークフロー

### Step 1: 検索する

`references/search_queries.sql` の「基本の検索」を使います。
`query` はキーワードではなく、聞かれた内容を文章のまま入れてください。
Cortex Search は意味で探すため、そのほうが当たります。

```sql
SELECT
    r.value:product_name::VARCHAR   AS PRODUCT_NAME,
    r.value:doc_type::VARCHAR       AS DOC_TYPE,
    r.value:page_no::INT            AS PAGE_NO,
    r.value:chunk_text::VARCHAR     AS CHUNK_TEXT
FROM TABLE(FLATTEN(PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'DOC_SEARCH_HANDSON.HANDSON.PMDA_DOC_SEARCH',
        '{
           "query": "<聞かれた内容をそのまま文章で>",
           "columns": ["product_name","doc_type","drug_class","page_no","chunk_text"],
           "limit": 8
         }'
    )
)['results'])) r;
```

**注意**: `SEARCH_PREVIEW` の引数は定数でなければなりません。
列参照やバインド変数を渡すと `needs to be constant` エラーになります。

### Step 2: 特定の製品・文書に絞る場合

製品名や文書種別が質問に含まれていれば `filter` を足します。
絞り込める列は `doc_type` / `product_name` / `generic_name` / `drug_class` の4つです。

```sql
"filter": {"@eq": {"product_name": "ジャヌビア錠"}}
```

複数条件は `@and` でまとめます。

```sql
"filter": {"@and": [
    {"@eq": {"doc_type": "電子添文"}},
    {"@eq": {"drug_class": "SGLT2阻害薬"}}
]}
```

### Step 3: 回答をまとめる

検索結果から回答を作ります。

- 結論を先に1〜2文で書く
- 根拠となる記載を箇条書きで並べ、各行に出典を付ける
- 検索結果に無い論点があれば「記載がありません」と明示する

出力例:

```markdown
ジャヌビア錠は腎機能障害の程度に応じて用量を調節します。

- 中等度腎機能障害では通常25mgを1日1回投与します（ジャヌビア錠／電子添文／1ページ）
- 重度腎機能障害および末期腎不全では12.5mgを1日1回投与します（ジャヌビア錠／電子添文／1ページ）

なお、透析のタイミングとの関係については検索対象の文書に記載がありません。
```

### Step 4: 比較を求められた場合

「3剤を比べて」のような依頼では、製品ごとに Step 1〜2 を実行し、表にまとめます。
1回の検索で全製品を均等に拾えるとは限らないため、**製品ごとに検索してください**。

`references/search_queries.sql` の「製品横断の比較」を使うと、
製品ごとの検索を1つのクエリでまとめて実行できます。

表の形式:

| 観点 | ダパグリフロジン錠「サワイ」 | ジャヌビア錠 | マンジャロ皮下注アテオス |
|---|---|---|---|
| 薬効群 | SGLT2阻害薬 | DPP-4阻害薬 | GIP/GLP-1受容体作動薬 |
| （聞かれた観点） | 記載＋ページ | 記載＋ページ | 記載＋ページ |

記載が見つからないセルは空欄にせず「記載なし」と書いてください。

## よくあるエラーと対処法

### サービスが存在しない

```
does not exist or not authorized: PMDA_DOC_SEARCH
```

→ `step2_cortex_search.sql` を実行済みか確認してください。

```sql
SHOW CORTEX SEARCH SERVICES IN SCHEMA DOC_SEARCH_HANDSON.HANDSON;
```

### 検索結果が0件

まず索引にデータが入っているかを確認します。

```sql
SELECT doc_type, product_name, COUNT(*)
FROM TABLE(CORTEX_SEARCH_DATA_SCAN(SERVICE_NAME => 'PMDA_DOC_SEARCH'))
GROUP BY ALL;
```

0件なら `step1_parse_document.sql` の `DOC_CHUNK` 作成まで戻ってください。
件数があるのにヒットしない場合は `filter` を外して試してください。
`filter` の値はマスタの表記と完全一致でなければヒットしません
（例: `ジャヌビア` ではなく `ジャヌビア錠`）。

### `needs to be constant` エラー

`SEARCH_PREVIEW` の引数に列やバインド変数を渡しています。
JSON文字列をリテラルとして直接書いてください。

## カスタマイズポイント

- **出典の形式を変える**: Step 3 の出力例を書き換える
- **件数を変える**: `limit` を調整する（既定8）
- **対象文書を増やす**: PDFをステージに追加 → `step1` → `step2` を再実行
- **回答の言語を変える**: Step 3 の指示を書き換える

## 参照ファイル

- `skills/pmda-doc-search/references/search_queries.sql`: 検索クエリ集
