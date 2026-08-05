# 手順2: 検索サービスを作る（Cortex Search）

**所要時間**: 10分
**スクリプト**: `scripts/step2_cortex_search.sql`

## 今回使うもの

| 名前 | これは何か |
|---|---|
| **Cortex Search** | ベクトル検索・キーワード検索・意味的リランキングを内部で組み合わせたマネージドの検索サービス。索引の構築、元データが変わったときの更新、精度チューニングまで Snowflake 側が持つ。RAGの検索層としても、アプリの検索窓としても使う |
| **埋め込みモデル**（`EMBEDDING_MODEL`） | テキストを「意味を表す数値ベクトル」に変換するモデル。既定は英語専用のため、日本語では多言語モデルを明示する。作成後は変更できない（作り直しになる） |
| **`ATTRIBUTES`** | 検索時に絞り込み条件（`filter`）として使える列の指定。ここに入れ忘れると後から絞り込めない |
| **`TARGET_LAG`** | 元テーブルの変更に索引が追いつく目標時間。この間隔で自動更新される |
| **`SEARCH_PREVIEW`** | SQLから検索を試すための動作確認用関数。引数は定数のみ、レスポンスは300KBまで。アプリからの利用は想定されていない |
| **`CORTEX_SEARCH_DATA_SCAN`** | 検索サービスの索引に入っているデータを直接のぞくテーブル関数。「ヒットしない」ときの切り分けに使う |

## ゴール

`DOC_CHUNK` を検索できるようにします。SQL 1本です。

## Cortex Search が中でやっていること

「ベクトル検索を作る」と聞くと、普通は次の作業が発生します。

- 埋め込みモデルを選んで、チャンクをベクトル化する
- ベクトルDBを立てる／インデックスを張る
- キーワード検索と組み合わせる
- 元データが変わったら作り直す
- 検索精度をチューニングする

Cortex Search はこれを1つのオブジェクトにまとめています。

- **ベクトル検索**（意味が近いものを探す）
- **キーワード検索**（語が一致するものを探す）
- **リランキング**（上位を並べ直す）

の3つを内部で組み合わせたハイブリッド検索です。

## 手順

### 2-1. サービスを作る

```sql
CREATE OR REPLACE CORTEX SEARCH SERVICE PMDA_DOC_SEARCH
    ON chunk_text
    ATTRIBUTES doc_type, product_name, generic_name, drug_class
    WAREHOUSE = COMPUTE_WH
    TARGET_LAG = '1 day'
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
AS ( SELECT ... FROM DOC_CHUNK );
```

**★ `EMBEDDING_MODEL` の指定を省略しないでください。**

| モデル | 言語 | コンテキスト |
|---|---|---|
| `snowflake-arctic-embed-m-v1.5` | **英語専用** | 512 |
| `snowflake-arctic-embed-l-v2.0` | 多言語 | 512 |
| `snowflake-arctic-embed-l-v2.0-8k` | 多言語 | 8000 |
| `voyage-multilingual-2` | 多言語 | 32000 |

**既定は `snowflake-arctic-embed-m-v1.5`（英語専用）です。**
日本語のまま指定せずに作ると、エラーは出ないまま精度が落ちます。
手順1でチャンクを512トークンに収めたのは、`l-v2.0` のウィンドウに合わせるためです。

`ATTRIBUTES` に挙げた列は、検索時の絞り込み条件に使えます。
ここに入れ忘れると後から `filter` できません（作り直しになります）。

状態を確認します。

```sql
SHOW CORTEX SEARCH SERVICES LIKE 'PMDA_DOC_SEARCH';
```

`INDEXING_STATE` と `SERVING_STATE` が `ACTIVE` になれば検索できます。

### 2-2. 検索する

```sql
SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'PMDA_DOC_SEARCH',
    '{"query": "ケトアシドーシスが起きたときの対応",
      "columns": ["product_name","doc_type","page_no","chunk_text"],
      "limit": 5}'
)
```

**注目してほしい点**: 「ケトアシドーシス」という語だけでなく、
悪心・嘔吐・意識障害といった**症状の説明**の箇所も拾ってきます。
キーワード一致だけの検索との違いはここです。

`SEARCH_PREVIEW` は動作確認用です。アプリからは Python API / REST API を使います
（手順4で触れます）。

### 2-3. 絞り込んで検索する

```sql
"filter": {"@eq": {"doc_type": "電子添文"}}
```

複数条件は `@and` でまとめます。

```sql
"filter": {"@and": [
    {"@eq": {"doc_type": "電子添文"}},
    {"@eq": {"drug_class": "SGLT2阻害薬"}}
]}
```

**絞り込みが要る理由**: 審議結果報告書は44ページあり、
チャンク数では全体の半分以上（171/302）を占めます。
放っておくと検索結果を埋めてしまうので、用途で切り分けられることが重要です。

### 2-4. 索引の中身を見る

「検索でヒットしない」ときは、まずデータが入っているか確認します。

```sql
SELECT doc_type, product_name, COUNT(*)
FROM TABLE(CORTEX_SEARCH_DATA_SCAN(SERVICE_NAME => 'PMDA_DOC_SEARCH'))
GROUP BY ALL;
```

## 自由に試す

`query` を書き換えてみてください。

- 妊婦への投与は可能か
- 低血糖のリスクと患者への説明
- 注射する部位について
- 審査の過程で問題になった点 ← 審議結果報告書側がヒットします

## つまずきどころ

| 症状 | 原因 | 対処 |
|---|---|---|
| `Your service has not yet been loaded` | 索引の構築中 | 数分待つ |
| 日本語の検索精度が悪い | `EMBEDDING_MODEL` 未指定 | 指定して作り直す |
| `filter` が効かない | `ATTRIBUTES` に入れていない | 作り直す |
| `filter` でヒットしない | 値が完全一致でない | `ジャヌビア` ではなく `ジャヌビア錠` |
| `needs to be constant` | 引数に列やバインド変数を渡した | リテラルで書く |

## 権限の注意

Cortex Search Service は**所有者の権限で検索します**。
サービスに `USAGE` を渡した相手は、元テーブルへの権限が無くても
索引されたデータを見られます。マスキングポリシーも回避されます。
誰に `USAGE` を渡すかは慎重に決めてください。

---

前: [手順1 PDFをテキストにする](step1_parse_document.md) ／ 次: [手順3 エージェントに文書を持たせる](step3_cortex_agent.md)
