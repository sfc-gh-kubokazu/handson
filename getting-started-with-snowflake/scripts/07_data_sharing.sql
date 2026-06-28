-- =============================================================
-- STEP 8: データの安全な共有（隣の参加者とペアで相互共有）
-- 対応手順書: ../steps/08_sharing_and_cleanup.md
-- =============================================================
-- このファイルでは隣の席の参加者とペアになり、
--   1. 自分の citibike データを相手に共有する（プロバイダー側）
--   2. 相手から共有されたデータをクエリする（コンシューマー側）
-- を体験します。
--
-- ⚠️ 直接共有の前提条件: ペアの2アカウントが【同じリージョン】であること
--    （異なるリージョンの場合は直接共有できません → 手順書のFAQ参照）
-- =============================================================

USE ROLE accountadmin;

-- =============================================================
-- 0. 事前準備: 自分のアカウント識別子を確認して隣の人に伝える
-- =============================================================

-- 自分のアカウント識別子（<組織名>.<アカウント名>）を確認
-- ⚠️ この値を紙やチャットで【隣の人に伝えて】ください
SELECT CURRENT_ORGANIZATION_NAME() || '.' || CURRENT_ACCOUNT_NAME() AS my_account_identifier;

-- 自分のリージョンを確認（相手と同じであることがペアの条件）
SELECT CURRENT_REGION() AS my_region;

-- =============================================================
-- 1.【プロバイダー側】自分のデータを隣の人に共有する
-- =============================================================

-- 共有オブジェクトを作成
CREATE OR REPLACE SHARE citibike_share;

-- 共有にデータベース/スキーマ/テーブルへのアクセス権を付与
GRANT USAGE ON DATABASE citibike TO SHARE citibike_share;
GRANT USAGE ON SCHEMA citibike.public TO SHARE citibike_share;
GRANT SELECT ON TABLE citibike.public.trips TO SHARE citibike_share;

-- 隣の人のアカウントを共有先に追加
-- ⚠️ <NEIGHBOR_ACCOUNT> を【隣の人から聞いた識別子】に置き換えてください
--    例: ALTER SHARE citibike_share ADD ACCOUNTS = SFSEAPAC.TARO_TRIAL;
ALTER SHARE citibike_share ADD ACCOUNTS = <NEIGHBOR_ACCOUNT>;

-- 共有の状態を確認
SHOW SHARES;
DESC SHARE citibike_share;

-- =============================================================
-- 2.【コンシューマー側】隣の人から共有されたデータを使う
-- =============================================================

-- 受信した共有（INBOUND）を確認
-- kind=INBOUND の行が、隣の人から共有されたもの
SHOW SHARES;

-- 共有からデータベースを作成して自分のアカウントにマウント
-- ⚠️ <NEIGHBOR_ACCOUNT> を【隣の人の識別子】に置き換えてください
--    形式: <相手の組織名>.<相手のアカウント名>.<共有名(citibike_share)>
CREATE OR REPLACE DATABASE citibike_from_neighbor
    FROM SHARE <NEIGHBOR_ACCOUNT>.citibike_share;

-- 相手のデータをクエリ！（コピーではなくライブ参照）
SELECT COUNT(*) AS neighbor_trips FROM citibike_from_neighbor.public.trips;
SELECT * FROM citibike_from_neighbor.public.trips LIMIT 10;

-- ⚠️ ポイント: 相手がデータを更新すれば、こちらのクエリ結果も即座に変わります
--    （データのコピーは一切発生していません）

-- =============================================================
-- 3.（任意）共有を取り消す
-- =============================================================

-- プロバイダー側: 共有先から相手アカウントを外す
-- ALTER SHARE citibike_share REMOVE ACCOUNTS = <NEIGHBOR_ACCOUNT>;
