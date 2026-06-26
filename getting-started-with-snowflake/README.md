# Snowflake Getting Started ハンズオン

**「Snowflake入門 - ゼロからはじめるSnowflake」** をベースにした、  
4時間で完結するハンズオン資材です。

- ベースコンテンツ: https://www.snowflake.com/ja/developers/guides/getting-started-with-snowflake-ja/
- 想定レベル: Snowflake 初心者〜入門者
- 所要時間: 約 4 時間

---

## はじめに: Snowflake とは何か

### Agentic Enterprise Data Cloud

Snowflake はデータウェアハウスとして誕生しましたが、今日では **データ・AI・アプリケーションが一体化したプラットフォーム**に進化しています。

```
データを蓄える → 分析する → AI で処理する → アプリとして動かす → エージェントが自律的に動く
        すべてが Snowflake の上で完結する
```

Snowflake が目指す姿は **「Agentic Enterprise」**、つまり AI エージェントが企業のデータを活用して自律的に動き、ビジネスを加速させる世界です。そのために必要な要素がすべて揃っています:

| レイヤー | Snowflake の機能 |
|---|---|
| **データ基盤** | データウェアハウス・データレイク・データシェアリング |
| **AI / ML** | Cortex AI（LLM・ML）、Document AI、Semantic Layer |
| **アプリケーション** | Streamlit in Snowflake、Native App、Snowpark Container Services |
| **エージェント** | Cortex Agents（AI エージェント）、Snowflake Intelligence |

### 今日のハンズオンの位置づけ

上記のどの機能も、**土台となるデータ基盤が正しく機能していることが前提**です。  
今日のハンズオンでは、その土台 ── **データウェアハウスとしての Snowflake の基礎** を体験します。

```
[今日やること]
データをロードする → クエリで分析する → 安全に管理する → 共有する
        ↑
  AI やアプリはこの上に乗る。まずここを理解する。
```

データのロード・クエリ・アクセス制御・タイムトラベル・データシェアリング ──  
これらは Snowflake を使うすべての人に共通する**最も重要な基礎スキル**です。

---

## 前提条件

- Snowflake アカウント（無料トライアル可）
  - サインアップ: https://trial.snowflake.com/
- ブラウザ（Chrome / Firefox / Edge 最新版推奨）
- SQL の基本的な読み書きができること

---

## ハンズオンでやること

| # | 内容 | SQL ファイル | 手順書 |
|---|---|---|---|
| 1 | Snowflake UI の操作体験 | なし（UI 操作のみ） | [steps/01_ui_overview.md](steps/01_ui_overview.md) |
| 2 | データベース・テーブル・ステージ・ファイルフォーマットの作成 | [scripts/01_data_load_prep.sql](scripts/01_data_load_prep.sql) | [steps/02_data_load_prep.md](steps/02_data_load_prep.md) |
| 3 | S3 から Snowflake へのデータロード | [scripts/02_data_load.sql](scripts/02_data_load.sql) | [steps/03_data_load.md](steps/03_data_load.md) |
| 4 | アナリティクスクエリ・結果キャッシュ・ゼロコピークローン | [scripts/03_analytics.sql](scripts/03_analytics.sql) | [steps/04_analytics.md](steps/04_analytics.md) |
| 5 | 半構造化データ（JSON）・ビュー・クロスDB JOIN | [scripts/04_semi_structured.sql](scripts/04_semi_structured.sql) | [steps/05_semi_structured.md](steps/05_semi_structured.md) |
| 6 | タイムトラベル（DROP/UNDROP・誤操作ロールバック） | [scripts/05_time_travel.sql](scripts/05_time_travel.sql) | [steps/06_time_travel.md](steps/06_time_travel.md) |
| 7 | ロール管理・アクセス制御 | [scripts/06_roles.sql](scripts/06_roles.sql) | [steps/07_roles.md](steps/07_roles.md) |
| 8 | データ共有・Marketplace（UI 中心） | なし（UI 操作） | [steps/08_sharing_and_cleanup.md](steps/08_sharing_and_cleanup.md) |
| — | 環境リセット | [scripts/00_cleanup.sql](scripts/00_cleanup.sql) | — |

---

## フォルダ構成

```
getting-started-with-snowflake/
├── README.md                      # このファイル
├── agenda.md                      # 当日アジェンダ
├── scripts/                       # 実行用 SQL（順番に実行）
│   ├── 00_cleanup.sql             # 環境リセット（終了後に実行）
│   ├── 01_data_load_prep.sql      # DB・テーブル・ステージ・フォーマット作成
│   ├── 02_data_load.sql           # データロード
│   ├── 03_analytics.sql           # クエリ・キャッシュ・クローン
│   ├── 04_semi_structured.sql     # JSON・ビュー・JOIN
│   ├── 05_time_travel.sql         # タイムトラベル
│   └── 06_roles.sql               # ロール管理
├── steps/                         # 概念説明 + 手順書（Markdown）
│   ├── 01_ui_overview.md
│   ├── 02_data_load_prep.md
│   ├── 03_data_load.md
│   ├── 04_analytics.md
│   ├── 05_semi_structured.md
│   ├── 06_time_travel.md
│   ├── 07_roles.md
│   └── 08_sharing_and_cleanup.md
└── images/                        # スクリーンショット置き場
```

---

## 進め方（参加者向け）

1. 各セクションの手順書（`steps/*.md`）を開いて **概念説明を読む**
2. 対応する SQL ファイル（`scripts/*.sql`）を Snowflake ワークシートに開く
3. **上から順番に実行**（Ctrl+Enter で1ブロックずつ実行推奨）
4. 手順書のチェックポイントを確認して次へ進む

---

## 使用データ

| データ | 形式 | 件数 | ソース |
|---|---|---|---|
| Citi Bike トリップデータ | CSV (.gz) | 約 600 万件 | `s3://snowflake-workshop-lab/citibike-trips-csv/` |
| NYC 気象データ | JSON | 約 75,000 件 | `s3://snowflake-workshop-lab/zero-weather-nyc` |

いずれも Snowflake が公開している教育用バケットです。

---

## このリポジトリの方針

- 顧客固有情報は含まない（そのままどの顧客にも展開可能）
- SQL はコメントで機能説明を付与（コピペで動くことを重視）
- 元コンテンツからの変更点: ロール付与の `YOUR_USERNAME_GOES_HERE` にコメント追加、各 SQL に日本語説明追加
