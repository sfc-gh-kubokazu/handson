# handson

Snowflakeのハンズオン資料を集約する**汎用リポジトリ**です。
顧客向けワークショップ・社内勉強会・自習用など、目的別にハンズオンを配下のフォルダで管理します。

## ディレクトリ構成

```
handson/
├── README.md                         # このファイル
├── cortex-agent-mcp/                 # Cortex Agent × MCP（Kiro/Claude Desktop連携）
│   ├── README.md
│   ├── 01_setup/                     # 環境準備（Marketplace Get / ロール / PAT発行）
│   ├── 02_agent/                     # Cortex Agent作成手順・SQL
│   ├── 03_mcp/                       # MCP設定テンプレ（Kiro / Claude Desktop）
│   ├── 04_advanced/                  # 発展課題
│   ├── prompts/                      # CoCo Web UI用プロンプト集
│   └── assets/                       # 画像・図解
└── （今後追加予定）
    ├── streamlit-cortex/             # Streamlit × Cortex
    ├── snowpark-ml/                  # Snowpark ML
    └── ...
```

## 各ハンズオンの一覧

| フォルダ | 内容 | 想定対象 | ステータス |
|---|---|---|---|
| `cortex-agent-mcp/` | Cortex Agent作成 + Kiro/Claude DesktopからのMCP接続 | データエンジニア・開発者 | 🚧 作成中 |

## このリポジトリの方針

- **顧客固有情報は含めない**（汎用化されたハンズオン手順のみ）
- 各ハンズオンフォルダは **独立して完結**（README → ステップ実行で完了）
- **公開可能な公式サンプルデータ**を使用（Marketplace等）
- 顧客向けに展開する際は、そのまま共有 or フォークして固有情報を追加

## 利用方法

1. 興味のあるハンズオンフォルダ配下の `README.md` を参照
2. `01_setup/` から順番に進める
3. 不明点はSlack（社内）またはイシューで質問

## 貢献ガイド

新しいハンズオンを追加する場合:
1. ルート直下に新しいフォルダを作成（例: `streamlit-cortex/`）
2. フォルダ内に独立した `README.md` を配置（前提・所要時間・ゴールを明記）
3. このルートREADMEの一覧表に追記
