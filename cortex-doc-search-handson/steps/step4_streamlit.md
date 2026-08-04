# 手順4: 検索アプリを作る（Streamlit in Snowflake）

**所要時間**: 10分
**ファイル**: `scripts/step4_streamlit/streamlit_app.py`

## ゴール

エージェントのプレイグラウンドではなく、
**業務で配れる形の検索アプリ**を Snowflake の中だけで作ります。

- データは外に出ません
- 別のサーバも要りません
- URLを共有すれば同僚が使えます

## 作るもの

```
┌──────────────────────────────────────────┐
│ 🔎 医薬品文書検索                        │
│ ┌──────────────────────────────────────┐ │
│ │ 腎機能障害のある患者への注意点        │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ 回答                                     │
│ ジャヌビア錠は腎機能障害の程度に応じて…  │
│ （ジャヌビア錠／電子添文／1ページ）      │
│                                          │
│ 該当箇所 5件                             │
│ ▼ 1. ジャヌビア錠（電子添文）4ページ     │
│ ▶ 2. ダパグリフロジン錠「サワイ」…       │
└──────────────────────────────────────────┘
  サイドバー: 文書種別 / 製品 / 薬効群 / 件数 / AI要約ON・OFF
```

## デプロイ

### Snowsight の画面から作る場合

1. **Projects » Streamlit** を開く
2. **+ Streamlit App**
3. データベース `DOC_SEARCH_HANDSON` / スキーマ `HANDSON` / ウェアハウス `COMPUTE_WH`
4. `scripts/step4_streamlit/streamlit_app.py` の中身を貼り付ける
5. Packages に `pandas` を追加
6. Run

### CLIから作る場合

```bash
cd scripts/step4_streamlit
snow streamlit deploy --replace
```

`snowflake.yml` にデプロイ先が書いてあります。
`DOC_SEARCH_HANDSON.HANDSON.STREAMLIT` ステージは手順0で作成済みです。

## コードの読みどころ

### ★1. `SEARCH_PREVIEW` は定数しか受け取らない

```python
def sql_literal(text: str) -> str:
    return "'" + text.replace("'", "''") + "'"
```

`SEARCH_PREVIEW` の引数にバインド変数や列参照を渡すと、こうなります。

```
argument 2 to function SYSTEM$CORTEX_SEARCH_QUERY needs to be constant
```

つまり**検索条件のJSONを文字列として組み立てるしかありません**。
ということは、**利用者の入力をそのまま埋め込むとSQLインジェクションになります**。

このアプリでは二段構えでエスケープしています。

```python
body = json.dumps(request, ensure_ascii=False)   # JSONとして正しくエスケープ
... f"{sql_literal(body)}"                        # SQLリテラルとしてエスケープ
```

**ここは絶対に省略しないでください。**
本番アプリでは `SEARCH_PREVIEW` ではなく
Python API（`snowflake.core`）や REST API を使ってください。
そちらはパラメータとして渡せるので、この問題自体が発生しません。
`SEARCH_PREVIEW` は動作確認用で、レスポンスも300KBまでという制限があります。

### 2. AI_COMPLETE はバインドできる

```python
session.sql("SELECT AI_COMPLETE('claude-4-sonnet', ?) AS ANSWER", params=[prompt])
```

`AI_COMPLETE` は定数でなくてよいので、こちらはバインド変数が使えます。
同じ画面の中で扱いが違うので、混同しないよう注意してください。

### 3. RAGの本体は10行程度

```python
context = "\n\n".join(f"[{r['PRODUCT_NAME']} / {r['DOC_TYPE']} / {r['PAGE_NO']}ページ]\n{r['CHUNK_TEXT']}" for r in rows)
prompt = ("以下の抜粋だけを根拠に、質問に日本語で簡潔に答えてください。"
          "抜粋に書かれていないことは推測せず「記載がありません」と答えてください。" ...)
```

「検索して、見つかった文だけを渡して、それだけを根拠に答えさせる」。
RAGと呼ばれているものの中身はこれだけです。

**`抜粋だけを根拠に` と `推測せず` の2つが効きます。**
これを書かないと、モデルが一般知識で補完してきます。
医薬品情報では致命的です。

### 4. `@st.cache_data` を使う場所

絞り込みの選択肢はほぼ変わらないのでキャッシュします。
検索結果はキャッシュしません（毎回聞き方が違うため）。

## 試すこと

1. 「腎機能障害のある患者に投与するときの注意点」で検索する
2. サイドバーで製品を1つに絞って、結果が変わるのを見る
3. 「AIで回答をまとめる」をOFFにして、生の検索結果だけを見る
   → 要約の前に何が渡っているかが分かります
4. **文書に無いことを聞く**（例: 「この薬の1錠あたりの薬価は？」）
   → 「記載がありません」と答えるか確認する

4番が重要です。**答えられないことを答えられないと言えるか**が、
業務で使えるかの分かれ目になります。

## つまずきどころ

| 症状 | 原因 | 対処 |
|---|---|---|
| `needs to be constant` | 検索条件をバインドしている | リテラルを組み立てる |
| 結果が0件 | `filter` の値が完全一致でない | サイドバーの値はDBから取得している |
| `pandas` が無い | Packages に追加していない | 追加して再起動 |
| 権限エラー | 検索サービスに `USAGE` が無い | 付与する |

---

前: [手順3 エージェントに文書を持たせる](step3_cortex_agent.md) ／ 次: [手順5 CoCoから呼べるようにする](step5_skills.md)
