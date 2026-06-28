-- =============================================================
-- 00: 環境リセット（クリーンアップ）
-- 対応手順書: ../steps/08_cleanup.md
-- =============================================================
-- ハンズオン終了後、作成したオブジェクトをすべて削除します
-- ⚠️ このファイルを実行するとハンズオン中に作成したデータがすべて消えます
-- =============================================================

USE ROLE accountadmin;

-- 共有（データシェア）を削除
-- プロバイダー側で作成した共有
DROP SHARE IF EXISTS citibike_share;

-- データベースを削除
DROP DATABASE IF EXISTS citibike;
DROP DATABASE IF EXISTS weather;
-- 隣の人から共有されて作成したデータベース（コンシューマー側）
DROP DATABASE IF EXISTS citibike_from_neighbor;

-- ウェアハウスを削除
DROP WAREHOUSE IF EXISTS analytics_wh;

-- ロールを削除
DROP ROLE IF EXISTS junior_dba;

-- compute_wh をデフォルトサイズに戻す（削除しない）
ALTER WAREHOUSE compute_wh SET WAREHOUSE_SIZE = 'small';

-- 削除されたか確認
SHOW DATABASES;
SHOW WAREHOUSES;
SHOW ROLES;
