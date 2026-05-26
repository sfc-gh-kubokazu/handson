import streamlit as st
import plotly.express as px
from snowflake.snowpark.context import get_active_session

st.set_page_config(
    page_title="SnowRetail 売上ダッシュボード",
    page_icon="🏪",
    layout="wide",
)

session = get_active_session()

# ── サイドバー（Step 8-2 で追加: チャネルフィルター）─────────────────────────
with st.sidebar:
    st.header("フィルター")
    channel_options = ["全て", "EC", "RETAIL"]
    selected_channel = st.selectbox("チャネル", channel_options, index=0)

channel_filter = "" if selected_channel == "全て" else f"AND CHANNEL = '{selected_channel}'"
channel_label  = selected_channel if selected_channel != "全て" else "全チャネル"

# ── タイトル ──────────────────────────────────────────────────────────────────
st.title(f"🏪 SnowRetail 売上ダッシュボード — {channel_label}")
st.caption("データソース: SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES")

# ── KPI ──────────────────────────────────────────────────────────────────────
kpi_df = session.sql(f"""
    WITH monthly AS (
        SELECT
            DATE_TRUNC('MONTH', TRANSACTION_DATE) AS SALE_MONTH,
            SUM(TOTAL_PRICE)   AS TOTAL_AMOUNT,
            SUM(QUANTITY) AS TOTAL_QUANTITY
        FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
        WHERE 1=1 {channel_filter}
        GROUP BY DATE_TRUNC('MONTH', TRANSACTION_DATE)
    )
    SELECT
        SALE_MONTH,
        TOTAL_AMOUNT,
        TOTAL_QUANTITY,
        LAG(TOTAL_AMOUNT) OVER (ORDER BY SALE_MONTH) AS PREV_AMOUNT
    FROM monthly
    QUALIFY SALE_MONTH = MAX(SALE_MONTH) OVER ()
""").to_pandas()

latest_month = kpi_df["SALE_MONTH"].iloc[0].strftime("%Y年%m月")
total_amount = int(kpi_df["TOTAL_AMOUNT"].iloc[0])
total_qty    = int(kpi_df["TOTAL_QUANTITY"].iloc[0])
prev_amount  = kpi_df["PREV_AMOUNT"].iloc[0]
mom_delta    = round((total_amount - prev_amount) / prev_amount * 100, 1) if prev_amount else None

col1, col2, col3 = st.columns(3)
col1.metric("総売上（最新月）",   f"¥{total_amount:,.0f}", delta=f"{mom_delta:+.1f}% 前月比" if mom_delta else None)
col2.metric("総販売数（最新月）", f"{total_qty:,} 個")
col3.metric("集計対象月",        latest_month)

st.divider()

# ── カテゴリ別月次売上推移（Step 8-2 で追加: 折れ線グラフ）──────────────────
trend_df = session.sql(f"""
    SELECT
        DATE_TRUNC('MONTH', TRANSACTION_DATE) AS SALE_MONTH,
        CATEGORY,
        SUM(TOTAL_PRICE) AS TOTAL_AMOUNT
    FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
    WHERE 1=1 {channel_filter}
    GROUP BY DATE_TRUNC('MONTH', TRANSACTION_DATE), CATEGORY
    ORDER BY SALE_MONTH, CATEGORY
""").to_pandas()

fig_trend = px.line(
    trend_df,
    x="SALE_MONTH",
    y="TOTAL_AMOUNT",
    color="CATEGORY",
    markers=True,
    title=f"カテゴリ別月次売上推移（{channel_label}）",
    labels={"SALE_MONTH": "月", "TOTAL_AMOUNT": "売上金額（円）", "CATEGORY": "カテゴリ"},
)
fig_trend.update_layout(hovermode="x unified")
st.plotly_chart(fig_trend, use_container_width=True)

st.divider()

# ── 売上 Top10 商品（Step 8-2 で追加: 横棒グラフ）──────────────────────────
top10_df = session.sql(f"""
    SELECT
        PRODUCT_NAME,
        SUM(TOTAL_PRICE) AS TOTAL_AMOUNT
    FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
    WHERE TRANSACTION_DATE >= DATEADD('MONTH', -1,
          (SELECT MAX(TRANSACTION_DATE) FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES))
          {channel_filter}
    GROUP BY PRODUCT_NAME
    ORDER BY TOTAL_AMOUNT DESC
    LIMIT 10
""").to_pandas()
top10_df = top10_df.sort_values("TOTAL_AMOUNT", ascending=True)

fig_top10 = px.bar(
    top10_df,
    x="TOTAL_AMOUNT",
    y="PRODUCT_NAME",
    orientation="h",
    title=f"売上 Top 10 商品（直近1ヶ月 / {channel_label}）",
    labels={"PRODUCT_NAME": "商品名", "TOTAL_AMOUNT": "売上金額（円）"},
    color="TOTAL_AMOUNT",
    color_continuous_scale="Blues",
)
fig_top10.update_layout(coloraxis_showscale=False, yaxis_title=None)
st.plotly_chart(fig_top10, use_container_width=True)

st.divider()

# ── カテゴリ別サマリーテーブル ────────────────────────────────────────────────
cat_df = session.sql(f"""
    SELECT
        CATEGORY,
        SUM(TOTAL_PRICE)                                              AS TOTAL_AMOUNT,
        SUM(QUANTITY)                                            AS TOTAL_QUANTITY,
        ROUND(SUM(TOTAL_PRICE) / NULLIF(SUM(QUANTITY), 0), 0)        AS AVG_UNIT_PRICE
    FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
    WHERE 1=1 {channel_filter}
    GROUP BY CATEGORY
    ORDER BY TOTAL_AMOUNT DESC
""").to_pandas()

st.subheader("カテゴリ別サマリー")
st.dataframe(cat_df.rename(columns={
    "CATEGORY": "カテゴリ",
    "TOTAL_AMOUNT": "売上金額",
    "TOTAL_QUANTITY": "販売数量",
    "AVG_UNIT_PRICE": "平均単価",
}), use_container_width=True)
