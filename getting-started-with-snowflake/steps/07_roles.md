# STEP 7: ロール管理とアクセス制御

## このセクションでやること

Snowflake のアクセス制御の仕組みを理解し、カスタムロールを作って権限管理を体験します。

- **実行ファイル**: `../scripts/06_roles.sql`

---

## Snowflakeの概念: RBAC（ロールベースアクセス制御）

Snowflake では **ロール** を通じてオブジェクトへのアクセスを制御します。  
ユーザーに直接権限を付与するのではなく、**ロールに権限を付与 → ユーザーにロールを付与** という2段階の設計です。

### デフォルトロールの階層

```
ACCOUNTADMIN        ← 最上位。アカウント全体を管理（慎重に使う）
├── SYSADMIN        ← DBやウェアハウスを作成・管理
│   └── PUBLIC      ← すべてのユーザーが持つ最低限のロール
└── SECURITYADMIN   ← ユーザーとロールを管理
    └── USERADMIN   ← ユーザーとロールを作成できる
```

**カスタムロール**は `SYSADMIN` の下に作るのがベストプラクティスです。

### 権限の付与

```sql
-- ロールにオブジェクトの権限を付与
GRANT USAGE ON WAREHOUSE compute_wh TO ROLE junior_dba;
GRANT USAGE ON DATABASE citibike TO ROLE junior_dba;
GRANT SELECT ON ALL TABLES IN SCHEMA citibike.public TO ROLE junior_dba;

-- ユーザーにロールを付与
GRANT ROLE junior_dba TO USER taro_yamada;
```

### 最小権限の原則
アクセスが必要な範囲だけに権限を絞ることがセキュリティのベストプラクティスです。

| 必要な操作 | 必要な権限 |
|---|---|
| ウェアハウスで SQL を実行 | `USAGE ON WAREHOUSE` |
| データベースを見る | `USAGE ON DATABASE` |
| テーブルを参照 | `USAGE ON SCHEMA` + `SELECT ON TABLE` |
| テーブルを作成 | `CREATE TABLE ON SCHEMA` |

---

## 手順

1. `../scripts/06_roles.sql` を実行（`accountadmin` ロールが必要）
2. `YOUR_USERNAME_GOES_HERE` は自分のユーザー名に置き換える

### ユーザー名の確認方法
```sql
SELECT CURRENT_USER();
```

### 実行ステップ

| ステップ | 実行ロール | 内容 |
|---|---|---|
| ロール作成 | `accountadmin` | `junior_dba` ロールを作成 |
| ロール付与 | `accountadmin` | 自分のユーザーに `junior_dba` を付与 |
| ロール切り替え | — | `junior_dba` に切り替え |
| 権限なし確認 | `junior_dba` | ウェアハウスにアクセスできないことを確認 |
| 権限付与 | `accountadmin` | ウェアハウス → DB → スキーマ → テーブルの順で付与 |
| 権限あり確認 | `junior_dba` | データが参照できることを確認 |

---

## アカウント管理者 UI（Snowsight）

`accountadmin` ロールに切り替えると、左メニューに追加項目が表示されます:

- **管理 → コスト管理**: ウェアハウスのクレジット消費量をグラフで確認
- **管理 → セキュリティ**: ネットワークポリシーや認証ポリシー
- **管理 → 請求とサポート**: 使用量の詳細と支払い情報

---

## よくある質問

**Q: `junior_dba` に切り替えると他のデータベースが見えなくなる**  
A: 正常です。`USAGE ON DATABASE` を付与したデータベースしか見えません。  
これが最小権限の原則による設計です。

**Q: `GRANT ROLE` の後も `SHOW GRANTS TO USER` に表示されない**  
A: ページをリロードするか、Snowsight の接続を再接続してください。  
SQL での確認は即時反映されます。

**Q: `accountadmin` ロールはどういう時に使うべきか？**  
A: アカウント全体の管理作業（ユーザー作成、ネットワークポリシー設定など）のみ使用し、  
通常の作業は `sysadmin` で行うことが推奨です。

---

## チェックポイント

- [ ] `junior_dba` ロールが作成された
- [ ] `junior_dba` に切り替えるとウェアハウスにアクセスできない（権限なし確認）
- [ ] 権限付与後、`junior_dba` でも `citibike.public.trips` が参照できた
- [ ] `SHOW GRANTS TO ROLE junior_dba` で付与した権限が表示された
