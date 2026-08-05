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

### ★先に知っておくこと: ランタイムが2種類ある

Streamlit in Snowflake には実行環境が2種類あり、**依存関係の書き方とコードの書き方が変わります**。

| | コンテナランタイム | ウェアハウスランタイム |
|---|---|---|
| 実行基盤 | コンピュートプール | ウェアハウス |
| パッケージ管理 | `uv` | `conda` |
| 依存関係ファイル | **`pyproject.toml`** または `requirements.txt` | `environment.yml` |
| パッケージの入手元 | PyPI（**EAIが必要**） | Snowflake Anaconda Channel |
| セッション取得 | **`st.connection("snowflake").session()`** | `get_active_session()` でも可 |

**ワークスペースから作る場合はコンテナランタイム専用です。**
ウェアハウスランタイムは選べません。この手順書はコンテナランタイム前提で書いています。

### ワークスペースから作る（推奨）

1. ワークスペースを開く
2. **+ Add new » Streamlit app**
3. 次の4ファイルが自動生成される
   ```
   streamlit_app.py       # アプリ本体
   pyproject.toml         # 依存パッケージ
   snowflake.yml          # デプロイ設定
   .streamlit/config.toml # Streamlit設定
   ```
4. `scripts/step4_streamlit/streamlit_app.py` の中身を貼り付ける
5. `pyproject.toml` を `scripts/step4_streamlit/pyproject.toml` の内容にする
6. **Run** で自分だけが見えるプレビューを起動
7. 他のユーザーに公開するなら **Deploy**

### CLIから作る場合

```bash
cd scripts/step4_streamlit
# snowflake.yml の compute_pool を自分の環境の値に書き換えてから
snow streamlit deploy --replace
```

## コードの読みどころ

### ★0. 依存パッケージを最小にしている

```toml
[project]
name = "pmda-doc-search-app"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "streamlit[snowflake]"
]
```

ここは3点セットで理解してください。

**(1) `streamlit` の宣言は省略できない**

プリインストール済みなので書かなくてよさそうに見えますが、`dependencies = []` にすると
uv が作る環境に Streamlit が入らず、次のエラーで起動できません。

```
Failed to get the version of the Streamlit library.
Please check if the Streamlit library is installed and fulfills
the following version constraints: ">=1.48.0".
```

**(2) バージョンは指定しない**

コンテナランタイムは既定では PyPI にアクセスできません。
バージョン指定を書くと、条件を満たすために PyPI を見にいこうとするため
External Access Integration (EAI) が必要になります。
指定しなければランタイム同梱のものがそのまま使われます。

**(3) `[snowflake]` を付ける**

`snowflake-snowpark-python` が一緒に入ります。`st.connection("snowflake")` がこれを使います。

`pandas` や `plotly` を追加したくなったら EAI が必要です。
このアプリは追加パッケージ無しで動くように書いてあります
（選択肢の取得で `to_pandas()` を使わず `collect()` にしているのはそのためです）。

### ★1. `get_active_session()` を使わない

```python
session = st.connection("snowflake").session()
```

コンテナランタイムでは、1つのStreamlitサーバが複数の閲覧者を同時に処理します。
`get_active_session()` はスレッドセーフでないため、公式に
`st.connection("snowflake")` を使うよう案内されています。

### ★2. `SEARCH_PREVIEW` は定数しか受け取らない

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
| `Installing dependencies failed because the pyproject.toml file does not exist. Please create it.` | コンテナランタイムなのに依存関係ファイルが無い | `pyproject.toml` を `streamlit_app.py` と同じ場所に置く |
| `Failed to get the version of the Streamlit library.` | `dependencies` が空で Streamlit が入っていない | `streamlit[snowflake]` を宣言する（バージョン指定は付けない） |
| `environment.yml` を置いたのに無視される | コンテナランタイムは conda を使わない | `pyproject.toml` に書き換える |
| パッケージのインストールに失敗する | EAI が無いのに PyPI から取ろうとしている | パッケージを増やさない、または EAI を割り当てる |
| 閲覧者が増えると挙動がおかしい | `get_active_session()` を使っている | `st.connection("snowflake").session()` にする |
| `needs to be constant` | 検索条件をバインドしている | リテラルを組み立てる |
| 結果が0件 | `filter` の値が完全一致でない | サイドバーの値はDBから取得している |
| 権限エラー | 検索サービスに `USAGE` が無い | 付与する |

---

前: [手順3 エージェントに文書を持たせる](step3_cortex_agent.md) ／ 次: [手順5 CoCoから呼べるようにする](step5_skills.md)
