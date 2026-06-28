# STEP 1: Snowflake UI（Snowsight）の操作体験

## このセクションでやること

Snowflake の Web UI「**Snowsight**」の主要な画面を一通り触れてみます。  
ここでは SQL を書かず、まず「何がどこにあるか」を把握することが目的です。

参考: [Snowsight navigation menu](https://docs.snowflake.com/en/user-guide/snowsight-navigation)

---

## 現在の Snowsight ナビゲーション構成

Snowsight の左メニューは以下のカテゴリに整理されています。  
今日のハンズオンで特に使うものを **★** でマークしています。

### Work with data

| メニュー | 内容 | 今日使う？ |
|---|---|---|
| **Projects** | Workspaces（SQL/Python/Notebooks）+ Databases | ★ 中心 |
| **Ingestion** | データ取込みコネクター / Snowpipe 設定 / ファイルアップロード | |
| **Transformation** | Dynamic Tables / Tasks によるパイプライン管理 | |
| **AI & ML** | Cortex AI・LLM 関数・ML モデル・エージェント | |
| **Monitoring** | クエリ履歴・Container Services・Task 実行履歴 | ★ キャッシュ確認で使う |
| **Apps** | Streamlit / Native Apps の管理・公開 | |
| **Marketplace** | 外部データ・アプリ・エージェント製品の検索・入手 | ★ STEP 8 で触る |

### Horizon Catalog

| メニュー | 内容 | 今日使う？ |
|---|---|---|
| **Catalog** | データベース・テーブル・ビューを一元閲覧 | ★ テーブル確認で使う |
| **Data sharing** | 他アカウントへのデータ共有・リスティング公開 | STEP 8 で触る |
| **Governance & security** | マスキングポリシー・行アクセスポリシー・タグ管理 | |

### Manage

| メニュー | 内容 | 今日使う？ |
|---|---|---|
| **Compute** | ウェアハウス・コンピュートプールの管理 | ★ ウェアハウス確認で使う |
| **Postgres** | Snowflake Postgres インスタンスの管理 | |
| **Admin** | ユーザー・ロール・請求・統合設定 | ★ STEP 7 で触る |

---

## 各メニューの詳細説明

### Projects ★ 最重要
**Projects を開くと「Workspaces」と「Databases」の2タブが表示されます。**

#### Workspaces タブ
SQL / Python / Notebooks をひとつの場所で管理・実行できる統合開発環境（IDE）です。  
**今日のハンズオンはここで SQL ファイルを作成して作業します。**

- **SQL ファイル**: SQL を書いて実行する（今日のメイン作業）
- **Notebooks（.ipynb）**: SQL / Python / Markdown を混在させたセル型開発環境
- **Python ファイル（.py）**: スクリプト形式で Python を実行
- 複数のファイルをフォルダ構造で整理できる
- 実行結果をグラフ化・テーブル表示できる

#### Databases タブ
アカウント内のデータベース・スキーマ・テーブル・ビューを階層表示できます。  
テーブルのプレビューやカラム定義もここで確認できます。

### Monitoring > Query History ★
- 実行したすべての SQL の履歴（失敗したものも含む）
- **実行時間・スキャンデータ量・結果キャッシュ利用の有無** を確認できる
- STEP 4 で「Result Reuse（結果キャッシュ）」を確認するときに使う

### Marketplace ★
- 外部プロバイダーが公開するデータ・アプリを取得できる
- 天気・地理・金融・医療など様々なカテゴリ
- 取得したデータはコピーせず直接クエリできる（Data Sharing の仕組み）
- **AI エージェント製品（Agentic products）も Marketplace に登場している**

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

### Apps
- **Streamlit in Snowflake**: Python で書いたデータアプリを Snowflake 上で動かせる
- **Native Apps**: Snowflake Marketplace で配布するアプリを開発・公開する

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
- [ ] 左メニューに「Projects」「Monitoring」「Apps」「Marketplace」「Catalog」「Compute」「Admin」が表示されている
- [ ] Projects を開き「Workspaces」タブで SQL ファイルを新規作成できた
- [ ] Manage > Compute > Warehouses に「compute_wh」が表示されている
- [ ] 右上（またはメニュー下部）のロール表示が「SYSADMIN」になっている
