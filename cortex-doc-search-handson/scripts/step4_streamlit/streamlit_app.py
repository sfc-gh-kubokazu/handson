import json

import streamlit as st

st.set_page_config(
    page_title="医薬品文書検索",
    page_icon="🔎",
    layout="wide",
)

DB_SCHEMA = "DOC_SEARCH_HANDSON.HANDSON"
SEARCH_SERVICE = f"{DB_SCHEMA}.PMDA_DOC_SEARCH"

# ★ get_active_session() ではなく st.connection を使う理由
#   コンテナランタイム（ワークスペースから作るとこちらになります）では、
#   1つの Streamlit サーバが複数の閲覧者を同時に処理します。
#   get_active_session() はスレッドセーフでないため、
#   公式に st.connection("snowflake") を使うよう案内されています。
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
    """
    return "'" + text.replace("'", "''") + "'"


@st.cache_data(ttl=300, show_spinner=False)
def get_filter_options():
    # 追加パッケージを不要にするため to_pandas() は使わない
    rows = session.sql(f"""
        SELECT DISTINCT doc_type, product_name, drug_class
        FROM {DB_SCHEMA}.DOC_CHUNK
    """).collect()
    def uniq(col):
        return sorted({r[col] for r in rows if r[col] is not None})
    return uniq("DOC_TYPE"), uniq("PRODUCT_NAME"), uniq("DRUG_CLASS")


def search(query: str, filters: list, limit: int):
    request = {
        "query": query,
        "columns": [
            "chunk_text", "product_name", "generic_name",
            "doc_type", "drug_class", "page_no",
        ],
        "limit": limit,
    }
    if len(filters) == 1:
        request["filter"] = filters[0]
    elif len(filters) > 1:
        request["filter"] = {"@and": filters}

    # json.dumps でJSONとして正しくエスケープし、
    # sql_literal でSQLリテラルとしてエスケープする（二段構え）
    body = json.dumps(request, ensure_ascii=False)
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
    context = "\n\n".join(
        f"[{r['PRODUCT_NAME']} / {r['DOC_TYPE']} / {r['PAGE_NO']}ページ]\n{r['CHUNK_TEXT']}"
        for r in rows
    )
    prompt = (
        "以下の抜粋だけを根拠に、質問に日本語で簡潔に答えてください。"
        "抜粋に書かれていないことは推測せず「記載がありません」と答えてください。"
        "回答の該当箇所には (製品名/文書種別/ページ) の形式で出典を付けてください。\n\n"
        f"質問: {query}\n\n抜粋:\n{context}"
    )
    # AI_COMPLETE は定数でなくてよいので、こちらはバインド変数を使える
    res = session.sql(
        "SELECT AI_COMPLETE('claude-4-sonnet', ?) AS ANSWER",
        params=[prompt],
    ).collect()
    return res[0]["ANSWER"]


# ── サイドバー ───────────────────────────────────────────────────────
doc_types, products, drug_classes = get_filter_options()

with st.sidebar:
    st.header("絞り込み")
    sel_doc_type = st.selectbox("文書種別", ["全て"] + doc_types)
    sel_product = st.selectbox("製品", ["全て"] + products)
    sel_class = st.selectbox("薬効群", ["全て"] + drug_classes)
    limit = st.slider("表示件数", 3, 20, 5)
    use_ai = st.toggle("AIで回答をまとめる", value=True)

    st.divider()
    st.caption(
        "出典: PMDA公開文書（電子添文・審議結果報告書）。"
        "売上等の数値データは架空のサンプルです。"
    )

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

query = st.text_input(
    "検索",
    placeholder="例: 腎機能障害のある患者に投与するときの注意点",
    label_visibility="collapsed",
)

if not query:
    st.info("検索したい内容を入力してください。")
    st.stop()

with st.spinner("検索中..."):
    rows = search(query, filters, limit)

if not rows:
    st.warning("該当する記載が見つかりませんでした。絞り込み条件を緩めてみてください。")
    st.stop()

if use_ai:
    with st.spinner("回答をまとめています..."):
        st.subheader("回答")
        st.markdown(summarize(query, rows))
    st.divider()

st.subheader(f"該当箇所 {len(rows)}件")
for i, r in enumerate(rows, start=1):
    label = (
        f"{i}. {r['PRODUCT_NAME']}（{r['DOC_TYPE']}） "
        f"{r['PAGE_NO']}ページ ／ {r['DRUG_CLASS']}"
    )
    with st.expander(label, expanded=(i == 1)):
        st.markdown(r["CHUNK_TEXT"])
        st.caption(f"一般名: {r['GENERIC_NAME']}")
