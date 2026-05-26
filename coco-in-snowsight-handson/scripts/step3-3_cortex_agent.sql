CREATE OR REPLACE AGENT SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.SNOWRETAIL_HANDSON_AGENT
FROM SPECIFICATION $$
{
  "models": {
    "orchestration": "auto"
  },
  "orchestration": {
    "budget": {
      "seconds": 900,
      "tokens": 400000
    }
  },
  "instructions": {
    "orchestration": "あなたはスノーリテールの分析アシスタントです。売上データの分析にはquery_sales_dataツールを、社内ドキュメント（マニュアル、ガイドライン等）の検索にはsearch_docsツールを使用してください。質問の内容に応じて適切なツールを選択し、日本語で回答してください。",
    "response": "回答は日本語で、簡潔かつわかりやすく行ってください。データに基づく分析結果には具体的な数値を含めてください。"
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "query_sales_data",
        "description": "MART_SALESとCUSTOMER_REVIEWSのデータを使って、売上分析やカテゴリ別集計、チャネル比較、顧客レビュー分析などを行うツール"
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "search_docs",
        "description": "スノーリテールの社内ドキュメント（店舗運営マニュアル、商品開発ガイドライン、販売戦略資料など）を検索するツール"
      }
    }
  ],
  "tool_resources": {
    "query_sales_data": {
      "execution_environment": {
        "query_timeout": 299,
        "type": "warehouse",
        "warehouse": ""
      },
      "semantic_view": "SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.SNOWRETAIL_SV"
    },
    "search_docs": {
      "execution_environment": {
        "query_timeout": 299,
        "type": "warehouse",
        "warehouse": ""
      },
      "search_service": "SNOWRETAIL_DB.SNOWRETAIL_SCHEMA.HANDSON_DOCS_SEARCH"
    }
  }
}
$$;
