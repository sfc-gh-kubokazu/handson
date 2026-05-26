import streamlit as st
import plotly.express as px
from snowflake.snowpark.context import get_active_session

st.set_page_config(
    page_title="SnowRetail 売上ダッシュボード",
    page_icon="🏪",
    layout="wide",
)

session = get_active_session()

st.title("🏪 SnowRetail 売上ダッシュボード")
st.caption("データソース: SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES")

# ── KPI ──────────────────────────────────────────────────────────────────────
kpi_df = session.sql("""
    WITH monthly AS (
        SELECT
            DATE_TRUNC('MONTH', TRANSACTION_DATE) AS SALE_MONTH,
            SUM(TOTAL_PRICE)   AS TOTAL_AMOUNT,
            SUM(QUANTITY) AS TOTAL_QUANTITY
        FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
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

latest_month   = kpi_df["SALE_MONTH"].iloc[0].strftime("%Y年%m月")
total_amount   = int(kpi_df["TOTAL_AMOUNT"].iloc[0])
total_qty      = int(kpi_df["TOTAL_QUANTITY"].iloc[0])
prev_amount    = kpi_df["PREV_AMOUNT"].iloc[0]
mom_delta      = round((total_amount - prev_amount) / prev_amount * 100, 1) if prev_amount else None

col1, col2, col3 = st.columns(3)
col1.metric("総売上（最新月）",   f"¥{total_amount:,.0f}", delta=f"{mom_delta:+.1f}% 前月比" if mom_delta else None)
col2.metric("総販売数（最新月）", f"{total_qty:,} 個")
col3.metric("集計対象月",        latest_month)

st.divider()

# ── 月次売上推移（全体）───────────────────────────────────────────────────────
trend_df = session.sql("""
    SELECT
        DATE_TRUNC('MONTH', TRANSACTION_DATE) AS SALE_MONTH,
        SUM(TOTAL_PRICE) AS TOTAL_AMOUNT
    FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
    GROUP BY DATE_TRUNC('MONTH', TRANSACTION_DATE)
    ORDER BY SALE_MONTH
""").to_pandas()

fig_trend = px.line(
    trend_df,
    x="SALE_MONTH",
    y="TOTAL_AMOUNT",
    markers=True,
    title="月次売上推移（全チャネル合計）",
    labels={"SALE_MONTH": "月", "TOTAL_AMOUNT": "売上金額（円）"},
)
fig_trend.update_traces(line_color="#29B5E8", marker_color="#29B5E8")
fig_trend.update_layout(hovermode="x unified")
st.plotly_chart(fig_trend, use_container_width=True)

st.divider()

# ── カテゴリ別売上（棒グラフ）────────────────────────────────────────────────
broad_df = session.sql("""
    SELECT
        CASE
            WHEN CATEGORY IN ('AV・オーディオ','エアコン','カメラ','ゲーム','スマートデバイス',
                              'テレビ・ディスプレイ','パソコン','プリンター・複合機','プロジェクター',
                              '冷蔵庫','掃除機','洗濯機','空調・空気清浄','調理家電') THEN '家電'
            WHEN CATEGORY IN ('お菓子','ミールキット','生鮮・PB食品','精肉・鮮魚・惣菜',
                              '食品・インスタント','飲料・乳製品')                THEN '食品・飲料'
            WHEN CATEGORY = '日用品・ヘルスケア'                                  THEN '日用品'
            WHEN CATEGORY = '衣料品'                                              THEN 'ファッション'
            WHEN CATEGORY = '文具'                                                THEN '文具'
            WHEN CATEGORY = 'おもちゃ'                                            THEN 'おもちゃ'
            ELSE 'その他'
        END AS BROAD_CATEGORY,
        SUM(TOTAL_PRICE)                                      AS TOTAL_AMOUNT,
        SUM(QUANTITY)                                         AS TOTAL_QUANTITY
    FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
    GROUP BY BROAD_CATEGORY
    ORDER BY TOTAL_AMOUNT DESC
""").to_pandas()

fig_cat = px.bar(
    broad_df,
    x="BROAD_CATEGORY",
    y="TOTAL_AMOUNT",
    title="カテゴリ別売上合計（全期間）",
    labels={"BROAD_CATEGORY": "カテゴリ", "TOTAL_AMOUNT": "売上金額（円）"},
    color="TOTAL_AMOUNT",
    color_continuous_scale="Blues",
)
fig_cat.update_layout(coloraxis_showscale=False, showlegend=False)
st.plotly_chart(fig_cat, use_container_width=True)

# ── サマリーテーブル（詳細サブカテゴリ）────────────────────────────────────────
cat_df = session.sql("""
    SELECT
        CASE
            WHEN CATEGORY IN ('AV・オーディオ','エアコン','カメラ','ゲーム','スマートデバイス',
                              'テレビ・ディスプレイ','パソコン','プリンター・複合機','プロジェクター',
                              '冷蔵庫','掃除機','洗濯機','空調・空気清浄','調理家電') THEN '家電'
            WHEN CATEGORY IN ('お菓子','ミールキット','生鮮・PB食品','精肉・鮮魚・惣菜',
                              '食品・インスタント','飲料・乳製品')                THEN '食品・飲料'
            WHEN CATEGORY = '日用品・ヘルスケア'                                  THEN '日用品'
            WHEN CATEGORY = '衣料品'                                              THEN 'ファッション'
            WHEN CATEGORY = '文具'                                                THEN '文具'
            WHEN CATEGORY = 'おもちゃ'                                            THEN 'おもちゃ'
            ELSE 'その他'
        END AS CATEGORY,
        SUM(TOTAL_PRICE)                                              AS TOTAL_AMOUNT,
        SUM(QUANTITY)                                            AS TOTAL_QUANTITY,
        ROUND(SUM(TOTAL_PRICE) / NULLIF(SUM(QUANTITY), 0), 0)        AS AVG_UNIT_PRICE
    FROM SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.MART_SALES
    GROUP BY 1
    ORDER BY TOTAL_AMOUNT DESC
""").to_pandas()
st.subheader("カテゴリ別サマリー")
st.dataframe(cat_df.rename(columns={
    "CATEGORY": "カテゴリ",
    "TOTAL_AMOUNT": "売上金額",
    "TOTAL_QUANTITY": "販売数量",
    "AVG_UNIT_PRICE": "平均単価",
}), use_container_width=True)
