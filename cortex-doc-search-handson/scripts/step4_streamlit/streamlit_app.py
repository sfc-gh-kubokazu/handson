# ============================================================
# streamlit_app.py — 医薬品文書検索アプリ
# ============================================================
# Cortex Search で検索し、見つかった箇所だけを根拠に
# AI_COMPLETE に回答させる、いわゆる RAG のアプリです。
#
# 【動きの流れ】
#   利用者が質問を入力
#        ↓  search()      Cortex Search で該当箇所を取ってくる
#        ↓  summarize()   取れた箇所だけを渡して回答させる
#   回答 ＋ 根拠（該当箇所）を画面に出す
#
# 【実行環境】
#   コンテナランタイム（ワークスペースから作るとこちらになります）
#   依存パッケージは requirements.txt の `streamlit` 1行だけです。
#
# 【Streamlit の前提】
#   Streamlit はボタンを押すたび、入力を変えるたびに
#   **このファイルを上から下まで丸ごと再実行**します。
#   そのため「重い処理はキャッシュする」「不要なら早めに止める」が
#   基本の考え方になります。後述の @st.cache_data と st.stop() が
#   そのための道具です。
# ============================================================

import json

import streamlit as st

# ページ全体の設定。この関数は他の st.* より先に、1回だけ呼びます。
#   layout="wide"  … 画面幅いっぱいに広げる（検索結果が読みやすい）
st.set_page_config(
    page_title="医薬品文書検索",
    page_icon="🔎",
    layout="wide",
)

# 参照先をここにまとめておくと、別環境に持っていくときの修正が1箇所で済みます。
DB_SCHEMA = "DOC_SEARCH_HANDSON.HANDSON"
SEARCH_SERVICE = f"{DB_SCHEMA}.PMDA_DOC_SEARCH"

# ★ get_active_session() ではなく st.connection を使う理由
#   コンテナランタイムでは、1つの Streamlit サーバが
#   複数の閲覧者を同時に処理します。
#   get_active_session() はスレッドセーフでないため、
#   公式に st.connection("snowflake") を使うよう案内されています。
#
#   .session()  … Snowpark セッションを取り出す（session.sql が使える）
#   .query()    … 結果をキャッシュ付きで取得する別の方法もあります
session = st.connection("snowflake").session()


# ── ユーティリティ ───────────────────────────────────────────────────
def sql_literal(text: str) -> str:
    """文字列を SQL のリテラルに変換する。

    ★なぜ必要か
      SEARCH_PREVIEW は引数に「定数」しか受け取りません。
      バインド変数や列参照を渡すと
        「argument 2 ... needs to be constant」
      というエラーになります。
      そのため検索条件のJSONを文字列として組み立てる必要があり、
      利用者の入力をそのまま埋め込むと SQL インジェクションになります。
      ここで必ずエスケープしてください。

    ★やっていること
      SQL の文字列リテラルの中では、シングルクォートを2つ並べると
      1つのシングルクォートとして扱われます。
        入力  : それは'テスト'です
        変換後: 'それは''テスト''です'
      これで、入力の中にクォートが混ざっても文字列が途中で
      終わらなくなります。
    """
    return "'" + text.replace("'", "''") + "'"


# ★ @st.cache_data … 関数の戻り値をキャッシュするデコレータ
#   絞り込みの選択肢は滅多に変わらないのに、
#   Streamlit は再実行のたびにこの関数を呼びます。
#   キャッシュしないと、利用者がスライダーを動かすだけで
#   毎回 Snowflake にクエリが飛びます。
#     ttl=300           … 300秒（5分）でキャッシュを捨てる
#     show_spinner=False … 「実行中...」の表示を出さない（一瞬なので邪魔）
@st.cache_data(ttl=300, show_spinner=False)
def get_filter_options():
    """サイドバーの絞り込み候補を、実際のデータから取ってくる。

    ★候補を手で書かない理由
      Cortex Search の filter は**完全一致**です。
      「ジャヌビア」では引っかからず「ジャヌビア錠」でないとヒットしません。
      候補をコードに直書きすると、表記を1文字間違えただけで
      「絞り込むと0件になる」という原因の分かりにくい不具合になります。
      DBから取れば必ず一致します。
    """
    # 追加パッケージを不要にするため to_pandas() は使わない。
    # to_pandas() は pandas が必要で、コンテナランタイムで
    # パッケージを追加するには EAI が必要になります。
    # collect() なら戻り値は Row のリストで、標準機能だけで扱えます。
    rows = session.sql(f"""
        SELECT DISTINCT doc_type, product_name, drug_class
        FROM {DB_SCHEMA}.DOC_CHUNK
    """).collect()

    def uniq(col):
        # 集合内包表記で重複を除き、None を落として並べ替える
        return sorted({r[col] for r in rows if r[col] is not None})

    return uniq("DOC_TYPE"), uniq("PRODUCT_NAME"), uniq("DRUG_CLASS")


def search(query: str, filters: list, limit: int):
    """Cortex Search を叩いて、該当箇所を取ってくる。"""
    # 検索条件を Python の辞書で組み立てます。
    #   query   … 検索したい内容。キーワードでなく文章でよい
    #   columns … 結果として返してほしい列。
    #             ★検索サービス作成時のソースクエリに含まれる列しか指定できません
    #   limit   … 最大件数（既定10、最大1000）
    request = {
        "query": query,
        "columns": [
            "chunk_text", "product_name", "generic_name",
            "doc_type", "drug_class", "page_no",
        ],
        "limit": limit,
    }

    # 絞り込み条件の組み立て。
    #   1つなら      → そのまま
    #   2つ以上なら  → {"@and": [...]} でまとめる
    #   0個なら      → filter を付けない（付けると全件外れることがある）
    # ★ filter に使えるのは、サービス作成時に ATTRIBUTES に挙げた列だけです
    if len(filters) == 1:
        request["filter"] = filters[0]
    elif len(filters) > 1:
        request["filter"] = {"@and": filters}

    # ★エスケープは二段構え
    #   1. json.dumps  … JSONとして正しい文字列にする
    #                    （引用符や改行、バックスラッシュを処理）
    #      ensure_ascii=False にすると日本語がそのまま入り、読みやすくなります
    #   2. sql_literal … それをSQLの文字列リテラルとして安全にする
    #   どちらか片方だけでは不十分です。
    body = json.dumps(request, ensure_ascii=False)

    # SEARCH_PREVIEW はJSON文字列を返すので、SQL側でほどいて表にします。
    #   PARSE_JSON        … 文字列 → VARIANT
    #   ['results']       … 結果の配列を取り出す
    #   FLATTEN           … 配列を1件1行に展開する
    #   r.value:列名      … 展開した各行から値を取り出す
    #   ::VARCHAR / ::INT … 型を確定させる（しないとVARIANTのまま扱いにくい）
    rows = session.sql(f"""
        SELECT
            r.value:product_name::VARCHAR AS PRODUCT_NAME,
            r.value:generic_name::VARCHAR AS GENERIC_NAME,
            r.value:doc_type::VARCHAR     AS DOC_TYPE,
            r.value:drug_class::VARCHAR   AS DRUG_CLASS,
            r.value:page_no::INT          AS PAGE_NO,
            r.value:chunk_text::VARCHAR   AS CHUNK_TEXT
        FROM TABLE(FLATTEN(PARSE_JSON(
            SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                '{SEARCH_SERVICE}',
                {sql_literal(body)}
            )
        )['results'])) r
    """).collect()
    return rows


def summarize(query: str, rows: list) -> str:
    """検索で取れた箇所だけを根拠に、回答を作らせる。

    ★これが RAG の本体です
      「検索して、見つかった文だけを渡して、それだけを根拠に答えさせる」。
      RAG（Retrieval-Augmented Generation）と呼ばれているものの
      中身はこれだけです。
    """
    # 検索結果を1つのテキストにまとめます。
    # ★出典（製品名・文書種別・ページ）を各抜粋の頭に付けておくのが要点。
    #   こうしておくと、モデルが回答の中で出典を引用できます。
    #   付けずに本文だけ渡すと、どこから来た記述か分からなくなります。
    context = "\n\n".join(
        f"[{r['PRODUCT_NAME']} / {r['DOC_TYPE']} / {r['PAGE_NO']}ページ]\n{r['CHUNK_TEXT']}"
        for r in rows
    )

    # ★プロンプトの2つの縛りが効きます
    #   「抜粋だけを根拠に」… 一般知識で補完させない
    #   「推測せず」        … 分からないときに作らせない
    #   これを書かないと、モデルは学習済みの知識で埋めてきます。
    #   医薬品情報では致命的です。
    prompt = (
        "以下の抜粋だけを根拠に、質問に日本語で簡潔に答えてください。"
        "抜粋に書かれていないことは推測せず「記載がありません」と答えてください。"
        "回答の該当箇所には (製品名/文書種別/ページ) の形式で出典を付けてください。\n\n"
        f"質問: {query}\n\n抜粋:\n{context}"
    )

    # ★ここは SEARCH_PREVIEW と違い、バインド変数（?）が使えます。
    #   AI_COMPLETE は引数が定数である必要がないためです。
    #   バインドできる場合は必ずバインドしてください。
    #   自分でエスケープする必要がなくなり、事故が減ります。
    #   同じアプリの中で扱いが違うので、混同しないよう注意。
    res = session.sql(
        "SELECT AI_COMPLETE('claude-4-sonnet', ?) AS ANSWER",
        params=[prompt],
    ).collect()
    return res[0]["ANSWER"]


# ── サイドバー ───────────────────────────────────────────────────────
# 絞り込みの候補をデータから取得（キャッシュ済みなので毎回は走りません）
doc_types, products, drug_classes = get_filter_options()

# with st.sidebar: の中に書いた要素は、左側のサイドバーに出ます。
with st.sidebar:
    st.header("絞り込み")
    # 先頭に "全て" を足して、既定では絞り込まない状態にしています
    sel_doc_type = st.selectbox("文書種別", ["全て"] + doc_types)
    sel_product = st.selectbox("製品", ["全て"] + products)
    sel_class = st.selectbox("薬効群", ["全て"] + drug_classes)
    limit = st.slider("表示件数", 3, 20, 5)      # (最小, 最大, 初期値)
    use_ai = st.toggle("AIで回答をまとめる", value=True)

    st.divider()
    # ★何のデータを見ているのかを画面に明示する。
    #   架空データと実在文書が混ざっているアプリでは特に重要です。
    st.caption(
        "出典: PMDA公開文書（電子添文・審議結果報告書）。"
        "売上等の数値データは架空のサンプルです。"
    )

# 選ばれた条件を Cortex Search の filter の形に変換します。
# "全て" のときは条件を足しません。
filters = []
if sel_doc_type != "全て":
    filters.append({"@eq": {"doc_type": sel_doc_type}})
if sel_product != "全て":
    filters.append({"@eq": {"product_name": sel_product}})
if sel_class != "全て":
    filters.append({"@eq": {"drug_class": sel_class}})


# ── 本体 ─────────────────────────────────────────────────────────────
st.title("🔎 医薬品文書検索")
st.caption("キーワードではなく、聞きたいことを文章で入力してください。")

# label_visibility="collapsed" でラベルを隠し、検索窓だけを見せています
query = st.text_input(
    "検索",
    placeholder="例: 腎機能障害のある患者に投与するときの注意点",
    label_visibility="collapsed",
)

# ★ st.stop() … ここで処理を打ち切る
#   Streamlit は上から下まで再実行するので、
#   入力が無いうちに検索まで進まないよう、早めに止めます。
#   if/else で深くネストするより読みやすくなります。
if not query:
    st.info("検索したい内容を入力してください。")
    st.stop()

# st.spinner … 処理中にくるくる回る表示を出す。
# 数秒かかる処理には付けておくと、固まったように見えません。
with st.spinner("検索中..."):
    rows = search(query, filters, limit)

# 0件のときの案内。
# ★「絞り込み条件を緩めて」と書いているのは、
#   0件の原因が絞り込みであることが多いためです。
if not rows:
    st.warning("該当する記載が見つかりませんでした。絞り込み条件を緩めてみてください。")
    st.stop()

# AI要約はOFFにもできます。
# ★OFFにすると「要約の前にモデルへ渡している素の情報」が見えます。
#   回答を検証したいときに効きます。
if use_ai:
    with st.spinner("回答をまとめています..."):
        st.subheader("回答")
        # st.markdown … 見出しや箇条書き、表を整形して表示する
        st.markdown(summarize(query, rows))
    st.divider()

# ── 根拠の表示 ───────────────────────────────────────────────────────
# ★回答だけでなく、必ず根拠も並べて出します。
#   利用者が自分で原文を確認できる状態にしておくことが、
#   業務で使えるかどうかの分かれ目になります。
st.subheader(f"該当箇所 {len(rows)}件")
for i, r in enumerate(rows, start=1):
    # 開く前から「どの製品の何ページか」が分かるようにラベルへ入れます
    label = (
        f"{i}. {r['PRODUCT_NAME']}（{r['DOC_TYPE']}） "
        f"{r['PAGE_NO']}ページ ／ {r['DRUG_CLASS']}"
    )
    # st.expander … 折りたたみ。1件目だけ開いた状態にしています
    with st.expander(label, expanded=(i == 1)):
        # ★ st.markdown で出すのが重要。
        #   AI_PARSE_DOCUMENT の LAYOUT モードは Markdown を返すため、
        #   電子添文の「相互作用」などの表が表として描画されます。
        #   st.text だと記号がそのまま出て読めません。
        st.markdown(r["CHUNK_TEXT"])
        st.caption(f"一般名: {r['GENERIC_NAME']}")
