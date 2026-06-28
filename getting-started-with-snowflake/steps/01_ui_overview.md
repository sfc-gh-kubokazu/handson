# STEP 1: Snowflake UI（Snowsight）の操作体験

## このセクションでやること

Snowflake の Web UI「**Snowsight**」の主要な画面を一通り触れてみます。  
ここでは SQL を書かず、まず「何がどこにあるか」を把握することが目的です。

参考: [Snowsight navigation menu](https://docs.snowflake.com/en/user-guide/snowsight-navigation)

---

## 現在の Snowsight ナビゲーション構成

Snowsight の左メニューは以下のカテゴリに整理されています（2025年更新済み）。  
今日のハンズオンで特に使うものを **★** でマークしています。

### Work with data

| メニュー | 内容 | 今日使う？ |
|---|---|---|
| **Projects** | Workspaces / Streamlit / Dashboards / Native Apps | ★ 中心 |
| **Ingestion** | データ取込みコネクター / Snowpipe 設定 / ファイルアップロード | |
| **Transformation** | Dynamic Tables / Tasks によるパイプライン管理 | |
| **AI & ML** | Cortex AI・LLM 関数・ML モデル・エージェント | |
| **Monitoring** | クエリ履歴・Container Services・Task 実行履歴 | ★ キャッシュ確認で使う |

### Discover & Collaborate

| メニュー | 内容 | 今日使う？ |
|---|---|---|
| **Marketplace** | 外部データ・アプリ・エージェント製品の検索・入手 | ★ STEP 8 で触る |
| **Catalog** | Database Explorer（テーブル/ビュー一覧）・Internal Marketplace | ★ テーブル確認で使う |
| **Data sharing** | 他アカウントへのデータ共有・リスティング公開 | STEP 8 で触る |
| **Governance & security** | マスキングポリシー・行アクセスポリシー・タグ管理 | |

### Manage

| メニュー | 内容 | 今日使う？ |
|---|---|---|
| **Compute** | ウェアハウス・コンピュートプールの管理 | ★ ウェアハウス確認で使う |
| **Admin** | ユーザー・ロール・請求・統合設定 | ★ STEP 7 で触る |

---

## 各メニューの詳細説明

### Projects > Workspaces ★ 最重要
**今日のハンズオンはここで作業します。**

Workspaces は Snowsight の統合開発環境（IDE）です。  
SQL ファイル・Python ファイル（.py）・Notebooks（.ipynb）をひとつの場所で管理・実行できます。

- **SQL ファイル**: SQL を書いて実行する。今日のハンズオンはこれを使います
- **Notebooks（.ipynb）**: SQL / Python / Markdown を混在させたセル型開発環境
- **Python ファイル（.py）**: スクリプト形式で Python を実行（Public Preview）
- 複数のファイルをフォルダ構造で整理できる
- 実行結果をグラフ化・テーブル表示できる

> **旧 Worksheets について**: 旧来の「Worksheets」インターフェースも引き続き利用可能ですが、  
> 現在は Workspaces が標準の開発環境です。

### Projects > Streamlit
- Python で書いたデータアプリを Snowflake 上でそのまま動かせる
- 外部サーバー不要・Snowflake の認証とデータへのアクセスをそのまま利用

### Monitoring > Query History ★
- 実行したすべての SQL の履歴（失敗したものも含む）
- **実行時間・スキャンデータ量・結果キャッシュ利用の有無** を確認できる
- STEP 4 で「Result Reuse（結果キャッシュ）」を確認するときに使う

### Catalog > Database Explorer ★
- アカウント内のデータベース・スキーマ・テーブル・ビューを階層表示
- テーブルのプレビュー（先頭 100 件）やカラム定義もここで確認できる

### Marketplace ★
- 外部プロバイダーが公開するデータ・アプリを取得できる
- 天気・地理・金融・医療など様々なカテゴリ
- 取得したデータはコピーせず直接クエリできる（Data Sharing の仕組み）
- **AIエージェント製品（Agentic products）も Marketplace に登場している**

### Manage > Compute（ウェアハウス）★
- コンピュートリソースを管理する画面
- XS / S / M / L / XL などのサイズ変更、自動停止・自動起動の設定
- **ウェアハウスが「サスペンド中」の間はクレジットが消費されない**

### AI & ML
今日は直接触れませんが、Snowflake の現在地を理解するために存在を知っておきましょう:
- **Cortex AI**: LLM（大規模言語モデル）を SQL から呼び出す（テキスト生成・要約・分類など）
- **Cortex Agents**: データを参照しながら自律的に動く AI エージェントを作れる
- **ML モデル管理**: scikit-learn / XGBoost 等のモデルを登録・デプロイ・推論
- これらはすべて「今日やるデータウェアハウスの基礎の上」に乗る機能

---

## ラボストーリー

このハンズオンでは **New York City の Citi Bike** データを使います。

- Citi Bike はニューヨーク市のシェアサイクルサービス
- 乗車記録（トリップデータ）が S3 に公開されている
- さらに **気象データ（JSON）** と組み合わせて「天気とトリップ数の相関」を分析します

```
[S3: Citibike CSV] → ロード → [Snowflake: citibike.public.trips]
[S3: 気象 JSON]   → ロード → [Snowflake: weather.public.json_weather_data]
                                         ↓
                               クロスデータベース JOIN で相関分析
```

---

## チェックポイント

- [ ] Snowsight にログインできた
- [ ] 左メニューに「Projects」「Monitoring」「Marketplace」「Catalog」「Manage」が表示されている
- [ ] Projects > Workspaces で SQL ファイルを新規作成できた
- [ ] Manage > Compute > Warehouses に「compute_wh」が表示されている
- [ ] 右上（またはメニュー下部）のロール表示が「SYSADMIN」になっている
