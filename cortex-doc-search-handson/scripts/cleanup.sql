-- ============================================================
-- cleanup.sql — 後片付け
-- ============================================================
-- このハンズオンで作ったものを全部消します。
-- データベースごと消すので、DOC_SEARCH_HANDSON に他のものを
-- 入れていないか確認してから実行してください。
-- ============================================================

USE ROLE SYSADMIN;

-- 依存関係の順に消していきます。
-- （DROP DATABASE だけでも消えますが、何が作られたかの確認も兼ねて）

-- 手順3で作ったエージェント
DROP AGENT IF EXISTS DOC_SEARCH_HANDSON.HANDSON.PMDA_DOC_AGENT;

-- 手順4で作った Streamlit アプリ
DROP STREAMLIT IF EXISTS DOC_SEARCH_HANDSON.HANDSON.PMDA_DOC_SEARCH_APP;

-- 手順2で作った検索サービス
DROP CORTEX SEARCH SERVICE IF EXISTS DOC_SEARCH_HANDSON.HANDSON.PMDA_DOC_SEARCH;

-- 残りをまとめて
DROP DATABASE IF EXISTS DOC_SEARCH_HANDSON;

-- 消えたか確認
SHOW DATABASES LIKE 'DOC_SEARCH_HANDSON';


-- ============================================================
-- 注意
-- ============================================================
-- CoCo の Personal Skills（手順5）はワークスペース配下の
--   .snowflake/cortex/skills/
-- に置いてあります。データベースを消しても残るので、
-- 不要ならワークスペースからフォルダを削除してください。
