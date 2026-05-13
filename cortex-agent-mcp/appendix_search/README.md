# Appendix: Cortex Search

> ⚠️ **本セクションは本編ハンズオンには含まれません。** 興味のある方向けの補足資料です。

Cortex Agent は構造化データ向けの **Cortex Analyst** と並んで、非構造化データ（ドキュメント・テキスト）を扱う **Cortex Search** をツールとして利用できます。本Appendixでは Cortex Search の概要を紹介します。

---

## Cortex Search とは

![Cortex Search Overview](../assets/screenshots/appendix_search/01_cortex_search_overview.png)

社内ドキュメント・PDF・チャット履歴等の非構造化テキストに対して、**ハイブリッド検索（ベクトル + キーワード）** をフルマネージドで提供するサービス。RAG（Retrieval-Augmented Generation）の検索基盤として利用できます。

## 仕組み

![Cortex Search Flow](../assets/screenshots/appendix_search/02_cortex_search_flow.png)

**Build フェーズ**: ソーステーブル/ステージのテキストを自動でチャンク化・埋め込み生成し、検索インデックスを構築。
**Serve フェーズ**: クエリに対してハイブリッド検索 → 関連チャンクを返却。Cortex Agent から呼び出すと Analyst の構造化結果と組み合わせた回答が可能です。

---

## 発展課題: BRAZE_AGENT に Cortex Search を追加してみる

例えば以下のような拡張が考えられます:

- **キャンペーン企画書のPDF** をステージにアップロード → Cortex Search Service を作成
- `BRAZE_AGENT` に Search ツールを追加
- 「Q1のキャンペーン目的とKPIを教えて」のような質問で、構造化データ（実績）と非構造化データ（企画書）を横断回答

---

## 簡単に試す: Snowflake 公式ドキュメント検索 (`CKE_SNOWFLAKE_DOCS_SERVICE`) を MCP に追加

自前で Cortex Search Service を作る前に、Snowflake が共有データとして提供している
**`SNOWFLAKE_DOCUMENTATION.SHARED.CKE_SNOWFLAKE_DOCS_SERVICE`** を MCP Server に追加すれば、
Kiro / Cursor / Claude Desktop から **Snowflake 公式ドキュメント検索** を即座に呼べるようになります。

### 1. 必要権限の付与

```sql
USE ROLE SECURITYADMIN;

-- 共有DBはまとめて IMPORTED PRIVILEGES
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_DOCUMENTATION TO ROLE R_HANDSON;
```

### 2. MCP Server に Search ツールを追加して再作成

`braze-agent` / `braze-campaign-analyst` に `snowflake-docs-search` を追加します。

```sql
USE ROLE SYSADMIN;
USE DATABASE HANDSON_CORTEX_AGENT;
USE SCHEMA   BRAZE;

CREATE OR REPLACE MCP SERVER BRAZE_MCP_SERVER
  FROM SPECIFICATION $$
tools:
  - name: "braze-agent"
    type: "CORTEX_AGENT_RUN"
    identifier: "HANDSON_CORTEX_AGENT.BRAZE.BRAZE_AGENT"
    description: "Brazeのメールキャンペーン分析エージェント。送信/開封/クリック/CV/収益を自然言語で分析できる。"
    title: "Braze Agent"

  - name: "braze-campaign-analyst"
    type: "CORTEX_ANALYST_MESSAGE"
    identifier: "HANDSON_CORTEX_AGENT.BRAZE.SEMANTIC_VIEW_BRAZE_CAMPAIGN"
    description: "Brazeメールキャンペーンのセマンティックビュー（直接Analyst呼び出し用）"
    title: "Braze Campaign Analyst"

  - name: "snowflake-docs-search"
    type: "CORTEX_SEARCH_SERVICE_QUERY"
    identifier: "SNOWFLAKE_DOCUMENTATION.SHARED.CKE_SNOWFLAKE_DOCS_SERVICE"
    description: "Snowflake公式ドキュメント（docs.snowflake.com）の全文検索。SQL構文・API・機能ガイド・ベストプラクティスを取得可能。"
    title: "Snowflake Docs Search"
$$;
```

### 3. MCP Server への USAGE を再付与（重要）

> ⚠️ **`CREATE OR REPLACE MCP SERVER` で再作成すると USAGE 権限は失われます。**
> 必ず再付与してください。

```sql
USE ROLE SECURITYADMIN;
GRANT USAGE ON MCP SERVER HANDSON_CORTEX_AGENT.BRAZE.BRAZE_MCP_SERVER TO ROLE R_HANDSON;
```

### 4. Kiro から動作確認

Kiro の MCP Servers タブで `snowflake-braze` を再接続するとツール一覧に
`snowflake-docs-search` が表示されます。

```
@snowflake-braze snowflake-docs-search で「semantic view の作り方」を検索
```
```
@snowflake-braze 「Cortex Analyst の使い方」を Snowflake 公式ドキュメントから探して
```

→ Kiro が公式ドキュメントの該当チャンクを返してくれれば成功です。

### 参考リンク

- [Cortex Search ドキュメント](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview)
- [Cortex Search Quickstart](https://quickstarts.snowflake.com/guide/cortex_search_tutorial_1_basic_chatbot/)
