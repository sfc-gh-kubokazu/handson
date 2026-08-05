# 手順3: エージェントに文書を持たせる（Cortex Agent）

**所要時間**: 15分
**スクリプト**: `scripts/step3_cortex_agent.sql`

## 今回使うもの

| 名前 | これは何か |
|---|---|
| **Cortex Agent** | 質問を受けて「どのツールをどの順で使うか」を判断し、複数の結果をまとめて回答を作るオーケストレーター。ツール・指示・モデルをYAMLで定義する |
| **`cortex_analyst_text_to_sql`** | セマンティックビューに対し、自然文からSQLを生成して実行するツール。数値の集計を担当する |
| **`cortex_search`** | Cortex Search サービスを検索するツール。文書の記載を担当する |
| **`data_to_chart`** | 取得したデータをグラフにする組み込みツール。追加のリソース指定は不要 |
| **`models.orchestration: auto`** | オーケストレーション用モデルを自動選択する指定。公式に推奨されており、より良いモデルが出れば自動で追随する |
| **`instructions`** | エージェントの振る舞いの指示。`response`（回答の作り方）と `orchestration`（ツールの選び方）に分かれる |
| **`tool_resources`** | 各ツールが使うリソースの指定。セマンティックビュー名、検索サービス名、実行ウェアハウスなど |
| **`DATA_AGENT_RUN`** | SQLからエージェントを実行する関数。引数は**定数文字列のみ**受け付ける |
| **クロスリージョン推論** | 自リージョンに無いモデルを他リージョンで推論する設定。`auto` を使うには有効化が必要 |

## ゴール

②-1 のエージェントは「セマンティックビューだけ」を持っていました。
そこに Cortex Search を足して、**数字と文書の両方に1つの窓口で答えられる**ようにします。

| 質問 | 使われるツール |
|---|---|
| 2026年3月の自社製品の売上金額を製品名別に多い順で | セマンティックビュー |
| マンジャロの投与を忘れた場合はどうすればいい？ | Cortex Search |
| **最も売れている製品と同じ薬効群の薬の、腎機能障害患者への注意点は？** | **両方** |

3つ目が今日の山場です。

## 事前確認

`models.orchestration: auto` を使うには、クロスリージョン推論が有効である必要があります。

```sql
SHOW PARAMETERS LIKE 'CORTEX_ENABLED_CROSS_REGION' IN ACCOUNT;
```

`DISABLED` なら ACCOUNTADMIN で有効にします。

```sql
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
```

## 手順

### 3-1. エージェントを作る

要点は4つあります。

#### (1) `models.orchestration: auto`

公式に推奨されている指定です。モデル名を固定すると、
より良いモデルが出ても自分で書き換えないと反映されません。
`auto` にしておけば自動で追随します。

#### (2) tool の description に「使わない場面」も書く

```yaml
- tool_spec:
    type: "cortex_analyst_text_to_sql"
    name: "SalesAnalyst"
    description: |
      架空の糖尿病領域の月次売上データを問い合わせる。
      製品名・薬効群・自社/競合・都道府県・施設名・年月で集計できる。
      期間は 2026-01 から 2026-03 まで。金額のみで数量データは無い。
      添付文書の記載内容には答えられないので、その場合は使わないこと。
```

**最後の1行が効きます。** 「何ができるか」だけ書くと、
文書の質問に対しても Analyst を呼んで空振りすることがあります。

#### (3) instructions にデータの範囲を書く

```yaml
instructions:
  response: |
    必ず日本語で回答してください。
    文書を根拠にした回答では、製品名・文書種別・ページ番号を出典として必ず添えてください。
    わからないことは推測せず「データにありません」と答えてください。
```

範囲外を聞かれたときに推測させないための歯止めです。

**ここに書いてはいけないこと**: エージェントが実際に持っていないデータの説明。
「MR活動データは2024年8月まで」のようなことを、
ツールに入っていないのに書くと、無いものを探しに行きます。

#### (4) ★Analystツールにウェアハウスを明示する

```yaml
tool_resources:
  SalesAnalyst:
    semantic_view: "DOC_SEARCH_HANDSON.HANDSON.SV_SALES"
    execution_environment:
      type: "warehouse"
      warehouse: "COMPUTE_WH"
      query_timeout: 60
```

省略すると実行時にこうなります。

```
The Analyst tool SalesAnalyst is missing an execution environment.
Please specify a warehouse name in its tool_resources, or ensure that
you have a default warehouse set.
```

**呼び出し元にデフォルトウェアハウスがあると通ってしまう**ため、
「作った本人の環境でだけ動く」という事故が起きやすい箇所です。
アプリやAPIから呼ぶ段階で初めて壊れます。必ず書いてください。

#### Search側の設定

```yaml
DocSearch:
  name: "DOC_SEARCH_HANDSON.HANDSON.PMDA_DOC_SEARCH"
  max_results: "5"
  title_column: "product_name"
  id_column: "relative_path"
  columns_and_descriptions:
    doc_type:
      description: "文書種別。値は 電子添文 または 審議結果報告書"
      type: "string"
      searchable: false
      filterable: true
```

`columns_and_descriptions` に**取り得る値まで書く**のが要点です。
「値は 電子添文 または 審議結果報告書」と書いておくと、
エージェントが正しい値で絞り込めます。書かないと当てずっぽうになります。

### 3-2. 試す

Snowsight の **AI & ML » Agents** から「医薬品情報アシスタント」を開き、
プレイグラウンドで順に聞いてください。

**(1) 構造化データだけ**

> 2026年3月の自社製品の売上金額を製品名別に多い順で見せて

**(2) 文書だけ**

> マンジャロの投与を忘れた場合はどうすればいい？

出典（マンジャロ皮下注アテオス／電子添文／1ページ）が付くはずです。

**(3) 両方**

> 2026年1月から3月で最も売れている製品はどれ？
> その製品と同じ薬効群の薬について、腎機能障害のある患者への注意点を教えて

内部では次の順で動きます。

```
SalesAnalyst で売上1位を特定（デュラグル / GLP-1）
        ↓
その薬効群を手がかりに DocSearch で電子添文を検索
        ↓
出典付きで回答
```

架空の売上データと、実在の公開文書が、薬効群でつながります。
**「デュラグル自体の電子添文は検索対象に含まれていない」と自分で断りを入れる**のも
確認してください。

**(4) 範囲外（歯止めの確認）**

> 2025年の売上を見せて → データが無いと答えるはず
> この薬の薬価はいくら？ → 文書に無いと答えるはず

### ★毎回確認すること

回答が正しいかではなく、**どのツールが呼ばれたか**を見てください。

意図と違うツールが呼ばれていたら、直すのは

1. tool の `description`
2. `instructions.orchestration`

です。**モデルを変えるのは最後の手段**です。

## つまずきどころ

| 症状 | 原因 | 対処 |
|---|---|---|
| `missing an execution environment` | `execution_environment` 未指定 | 上記(4)を追加 |
| モデルが見つからない | クロスリージョン推論が無効 | `ANY_REGION` に設定 |
| 文書の質問にAnalystが呼ばれる | descriptionに「使わない場面」が無い | descriptionを直す |
| 絞り込みが的外れ | `columns_and_descriptions` に値の例が無い | 取り得る値を書く |
| 無いデータを探しに行く | instructionsに嘘が書いてある | 実際のツール構成と合わせる |

## SQLで動作確認したい場合

```sql
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'DOC_SEARCH_HANDSON.HANDSON.PMDA_DOC_AGENT',
  '{"messages":[{"role":"user","content":[{"type":"text","text":"質問をここに"}]}]}'
);
```

第2引数は**定数文字列**でなければなりません。
`TO_JSON({...})` やオブジェクトリテラルを渡すとエラーになります。

---

前: [手順2 検索サービスを作る](step2_cortex_search.md) ／ 次: [手順4 検索アプリを作る](step4_streamlit.md)
