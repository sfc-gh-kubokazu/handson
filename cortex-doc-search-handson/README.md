# Cortex Doc Search ハンズオン

構造化データしか扱えなかったところに**文書**を足して、
Snowflake の中だけで「エンタープライズ検索」を組み立てるハンズオンです。

`coco-in-snowsight-handson`（数値データ編）の続編として作っていますが、
**単独でも完結**します。

## 何ができるようになるか

```
PDF（電子添文・審査報告書）
   ↓  AI_PARSE_DOCUMENT       文書をテキストにする
   ↓  Cortex Search           検索できるようにする
   ↓  Cortex Agent            数値と文書の両方に1つの窓口で答える
   ↓  Streamlit in Snowflake  業務で配れる検索アプリにする
   ↓  Personal Skills         CoCoから自然文で呼ぶ
   ＋ AI関数                  表記揺れを名寄せする
```

すべて Snowflake の中で完結します。データは外に出ません。

## フォルダ構成

```
cortex-doc-search-handson/
├── README.md              # 本ファイル
├── agenda.md              # 当日のタイムテーブル・準備物
├── steps/                 # ステップ別手順書（説明はこちら）
│   ├── step0_recap.md
│   ├── step1_parse_document.md
│   ├── step2_cortex_search.md
│   ├── step3_cortex_agent.md
│   ├── step4_streamlit.md
│   ├── step5_skills.md
│   └── step6_name_matching.md
└── scripts/               # 実行するもの（上から順に流せます）
    ├── step0_setup.sql
    ├── step1_parse_document.sql
    ├── step2_cortex_search.sql
    ├── step3_cortex_agent.sql
    ├── step4_streamlit/       # Streamlit アプリ
    ├── step5_skills/          # CoCo の Personal Skills
    ├── step6_name_matching.sql
    └── cleanup.sql
```

## 進め方

`steps/step0_recap.md` から順に読み、対応する `scripts/` を実行してください。
**上から順に実行すれば完成します。**

| 手順 | 内容 | 目安 |
|---|---|---|
| [0](steps/step0_recap.md) | ふりかえりと環境準備 | 10分 |
| [1](steps/step1_parse_document.md) | PDFをテキストにする（AI_PARSE_DOCUMENT） | 15分 |
| [2](steps/step2_cortex_search.md) | 検索サービスを作る（Cortex Search） | 10分 |
| [3](steps/step3_cortex_agent.md) | エージェントに文書を持たせる（Cortex Agent） | 15分 |
| [4](steps/step4_streamlit.md) | 検索アプリを作る（Streamlit in Snowflake） | 10分 |
| [5](steps/step5_skills.md) | CoCoから呼べるようにする（Personal Skills） | 10分 |
| [6](steps/step6_name_matching.md) | 表記揺れを名寄せする（AI関数） | 10分 |

手順6は独立しています。前の手順を飛ばしても実行できます。

## 前提

| 項目 | 必要なもの |
|---|---|
| ロール | オブジェクト作成権限（`SYSADMIN` 相当） |
| データベースロール | `SNOWFLAKE.CORTEX_USER` |
| ウェアハウス | `COMPUTE_WH`（XSMALLで足ります） |
| アカウントパラメータ | `CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION'`（手順3で使用） |
| リージョン | Cortex Search と多言語埋め込みモデルが使えるリージョン |

## PDFについて

**このリポジトリにPDFは含めていません。** 各自でPMDAから取得してください。
電子添文の著作権は製造販売業者が保有しているため、再配布はしない方針です。

取得手順と現時点のURLは [手順1](steps/step1_parse_document.md) に記載しています。
URLは改訂されると無効になるので、その場合は検索画面から取り直してください。

## データについて

- **売上・製品・施設・医師はすべて架空**です。実在のものとは関係ありません
- **PDFはPMDAが公開している実際の文書**です
- 製品名は架空ですが、**薬効群（SGLT2阻害薬など）だけは実在の分類に合わせて**います。
  手順3で「架空の売上」と「実在の文書」をつなぐためです

## 後片付け

```sql
-- scripts/cleanup.sql
```

作ったものを全部消します。CoCo のスキルはワークスペース配下に残るので、
不要ならフォルダを削除してください。
