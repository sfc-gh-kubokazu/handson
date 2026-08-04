-- ============================================================
-- step3_cortex_agent.sql — 構造化と非構造化の両方に答えるエージェント
-- ============================================================
-- ②-1 で作ったのは「セマンティックビューだけを持つエージェント」でした。
-- ここに Cortex Search を足すと、
--   ・数字の集計（売上）        → セマンティックビュー
--   ・文書の中身（禁忌・用法）  → Cortex Search
-- を1つの窓口で聞けるようになります。
--
-- 【前提】step2 まで実行済み（SV_SALES と PMDA_DOC_SEARCH がある）
-- 【所要】約5分
-- ============================================================

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA DOC_SEARCH_HANDSON.HANDSON;


-- ============================================================
-- STEP 3-0: 前提の確認
-- ============================================================
-- ★ models.orchestration に auto を使うには、アカウントで
--   クロスリージョン推論が有効になっている必要があります。
--   DISABLED の場合は ACCOUNTADMIN で下のコマンドを実行してください。
SHOW PARAMETERS LIKE 'CORTEX_ENABLED_CROSS_REGION' IN ACCOUNT;

-- ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';


-- ============================================================
-- STEP 3-1: エージェントを作る
-- ============================================================
-- ★ ポイント4つ
--   1. models.orchestration は auto。公式に推奨されている指定で、
--      新しいモデルが出れば自動で品質が上がります。
--   2. tool の description は「何ができるか」だけでなく
--      「いつ使わないか」まで書く。ここが曖昧だとツール選択を誤ります。
--   3. instructions に「データの範囲」を明記する。
--      範囲外を聞かれたときに推測させないための歯止めです。
--   4. ★Analystツールには execution_environment（ウェアハウス）を
--      明示する。省略すると実行時にこのエラーになります:
--        「The Analyst tool ... is missing an execution environment.」
--      呼び出し元にデフォルトウェアハウスがあれば通ってしまうため、
--      作った本人の環境でだけ動く、という事故が起きやすい箇所です。
CREATE OR REPLACE AGENT PMDA_DOC_AGENT
    COMMENT = '糖尿病領域の売上データとPMDA公開文書の両方に答えるエージェント'
    PROFILE = '{"display_name": "医薬品情報アシスタント", "color": "blue"}'
    FROM SPECIFICATION
$$
models:
  orchestration: auto

orchestration:
  budget:
    seconds: 60
    tokens: 32000

instructions:
  response: |
    必ず日本語で回答してください。
    文書を根拠にした回答では、製品名・文書種別・ページ番号を出典として必ず添えてください。
    わからないことは推測せず「データにありません」と答えてください。
  orchestration: |
    売上金額・都道府県別・製品別・月別といった数値の集計は SalesAnalyst を使ってください。
    禁忌・効能・用法用量・副作用・相互作用・患者への注意など、
    添付文書や審査資料の記載内容に関する質問は DocSearch を使ってください。
    両方が必要な質問では、両方のツールを使ってから回答してください。
    グラフにすると分かりやすい場合は data_to_chart を使ってください。
  sample_questions:
    - question: "2026年3月の自社製品の売上金額を製品名別に多い順で見せて"
    - question: "SGLT2阻害薬でケトアシドーシスが疑われたときの対応を教えて"
    - question: "売上1位の製品と同じ薬効群の薬で、腎機能障害の患者に対する注意点は？"

tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "SalesAnalyst"
      description: |
        架空の糖尿病領域の月次売上データを問い合わせる。
        製品名・薬効群・自社/競合・都道府県・施設名・年月で集計できる。
        期間は 2026-01 から 2026-03 まで。金額のみで数量データは無い。
        添付文書の記載内容には答えられないので、その場合は使わないこと。
  - tool_spec:
      type: "cortex_search"
      name: "DocSearch"
      description: |
        PMDAが公開している電子添文と審議結果報告書を全文検索する。
        禁忌・効能又は効果・用法及び用量・副作用・相互作用・
        特定の背景を有する患者に関する注意などの記載を探せる。
        対象はダパグリフロジン(SGLT2阻害薬)、シタグリプチン/ジャヌビア(DPP-4阻害薬)、
        チルゼパチド/マンジャロ(GIP/GLP-1受容体作動薬)の3剤と、
        フォシーガの審議結果報告書。
        売上金額の集計には使えないので、その場合は使わないこと。
  - tool_spec:
      type: "data_to_chart"
      name: "data_to_chart"
      description: "取得したデータをグラフにする"

tool_resources:
  SalesAnalyst:
    semantic_view: "DOC_SEARCH_HANDSON.HANDSON.SV_SALES"
    execution_environment:
      type: "warehouse"
      warehouse: "COMPUTE_WH"
      query_timeout: 60
  DocSearch:
    name: "DOC_SEARCH_HANDSON.HANDSON.PMDA_DOC_SEARCH"
    max_results: "5"
    title_column: "product_name"
    id_column: "relative_path"
    columns_and_descriptions:
      chunk_text:
        description: "文書本文の一部。禁忌・用法用量・副作用などの記載が入る"
        type: "string"
        searchable: true
        filterable: false
      doc_type:
        description: "文書種別。値は 電子添文 または 審議結果報告書"
        type: "string"
        searchable: false
        filterable: true
      product_name:
        description: "製品名。値は ダパグリフロジン錠「サワイ」 / ジャヌビア錠 / マンジャロ皮下注アテオス / フォシーガ錠"
        type: "string"
        searchable: false
        filterable: true
      drug_class:
        description: "薬効群。値は SGLT2阻害薬 / DPP-4阻害薬 / GIP/GLP-1受容体作動薬"
        type: "string"
        searchable: false
        filterable: true
      page_no:
        description: "文書内のページ番号。出典表示に使う"
        type: "string"
        searchable: false
        filterable: false
$$;


-- 作成できたか確認
SHOW AGENTS LIKE 'PMDA_DOC_AGENT';
DESCRIBE AGENT PMDA_DOC_AGENT;


-- ============================================================
-- STEP 3-2: 試す
-- ============================================================
-- Snowsight の AI & ML » Agents から「医薬品情報アシスタント」を開き、
-- プレイグラウンドで以下を順に聞いてみてください。
--
-- (1) 構造化データだけで答えられる質問
--     → SalesAnalyst が呼ばれる
--     「2026年3月の自社製品の売上金額を製品名別に多い順で見せて」
--
-- (2) 文書だけで答えられる質問
--     → DocSearch が呼ばれる
--     「マンジャロの投与を忘れた場合はどうすればいい？」
--
-- (3) ★両方が必要な質問（ここが今日の山場）
--     → SalesAnalyst で1位の製品を特定 → DocSearch でその薬効群を調べる
--     「2026年1月から3月で最も売れている製品はどれ？
--       その製品と同じ薬効群の薬について、腎機能障害のある患者への
--       注意点を教えて」
--
-- (4) 範囲外の質問（推測させない歯止めの確認）
--     「2025年の売上を見せて」        → データが無いと答えるはず
--     「この薬の薬価はいくら？」      → 添付文書に無いと答えるはず
--
-- ★ 各回答で「どのツールが呼ばれたか」を必ず確認してください。
--   意図と違うツールが呼ばれていたら、直すのは instructions.orchestration
--   と tool の description です。モデルではありません。
