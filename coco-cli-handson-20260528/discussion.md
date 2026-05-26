# Cortex Code in Snowsight ハンズオン 設計ディスカッションまとめ

**日付:** 2026-05-26  
**担当:** 久保 Kazutaka

---

## 背景・目的

本ハンズオンは 2026-05-28 (水) 13:00-15:00 の2時間で実施する、Cortex Code に関するハンズオンである。

**ゴール:**
1. Snowflake でアプリ・AI が動くことを体験してもらう
2. Cortex Code の基本操作を Snowsight 上で習得してもらう
3. 業務活用のイメージを掴んでもらう

**参照コンテンツ:**
- スライド: https://docs.google.com/presentation/d/1vuUIEdqcQFvzKpOWpl4zFNKHDPF8XWsfiY4UVThRp7U
- GitHub: https://github.com/snow-jp-handson-org/coco-cli-handson-jp

---

## 重要な前提決定: Cortex Code in Snowsight で実施する

### 経緯
元のハンズオンコンテンツは **Cortex Code CLI（ターミナル）** を前提に設計されている。
参加者の環境を統一するため、**Cortex Code in Snowsight** での実施に変更することを決定。

### CLI vs Snowsight の違い

| 観点 | CLI | Snowsight |
|------|-----|-----------|
| 環境 | ターミナル / VS Code | ブラウザのみ |
| 参照先 | ローカルファイル・Git・dbt等 | Snowflakeのメタデータ・Workspace内ファイル |
| 主な用途 | エンドツーエンド開発・エージェント開発 | SQL開発・データ探索・管理タスク |

---

## 各ステップのSnowsight対応調査結果

元のハンズオンはStep 0〜10まであるが、Snowsightでの実施可否を公式ドキュメントを基に調査した。

| Step | 内容 | Snowsight可否 | 理由 |
|------|------|-------------|------|
| Step 0-1 | setup.sql実行・データ探索 | ✅ | SQL / Workspace で実行可能 |
| Step 2 | Dynamic Table | ✅ | SQL実行で対応可 |
| Step 3 | AGENTS.md | ✅ | Workspaceルートにファイル作成で対応 |
| Step 4 | Subagents / Custom Agent / Swarm | ❌ | CLI専用機能 |
| Step 5 | Hooks | ❌ | ローカルJSON（CLI専用） |
| Step 6 | Semantic View / Cortex Search / Cortex Agent | ✅ | SQL / Workspace で対応可 |
| Step 7 | Skills（カスタムスキル） | ✅ | WorkspaceのPersonal Skills機能で対応可 |
| Step 8 | Streamlit in Snowflake | ✅ | Snowsight SiS で対応 |
| Step 9 | draw.io MCP | ❌ | ローカルNode.js必要（CLI専用） |
| Step 10 | Profiles | ❌ | CLI専用 |

### AGENTS.md に関する調査

公式ドキュメント（cortex-code-snowsight）に以下の記載を確認:

> *"Create an AGENTS.md file to provide persistent instructions that Cortex Code will automatically include in every conversation. Copy it to the root directory of your workspace."*

→ **Workspace のルートに AGENTS.md を置けば Snowsight でも機能することを確認。**

### Personal Skills に関する調査

公式ドキュメントに以下を確認:

> *"You can create your own skills in a workspace to tailor Cortex Code to your specific workflows. To add a personal skill: Upload Skill File(s) / Upload Skill Folder(s) / + Create Skill"*
> *"Personal skills are stored in the .snowflake/cortex/skills directory of the workspace."*

→ **Workspace の UI からカスタムスキルを作成・呼び出しできることを確認。**  
→ ただし「Support for Agent Skills will be available soon」という記載あり。動作確認が必要。

---

## 採用するステップの決定

2時間の制約と Snowsight 対応可否を考慮し、以下の5ステップに絞ることを決定:

| Step | 内容 | 時間 |
|------|------|------|
| Step 0-1 | Workspace作成・setup.sql実行・データ探索 | 20分 |
| Step 3 | AGENTS.md でガバナンス体験 | 15分 |
| Step 6 | Semantic View / Cortex Search / Cortex Agent | 30分 |
| Step 7 | Personal Skills 作成・呼び出し | 20分 |
| Step 8 | Streamlit アプリ生成 | 15分 |

---

## ハンズオンシナリオ（元資料より継承）

**想定企業:** 株式会社スノーリテール（架空のリテール企業）  
**データ:**
- RETAIL_DATA（実店舗販売トランザクション、550件）
- EC_DATA（EC販売トランザクション、550件）
- PRODUCT_MASTER（商品マスタ、125件）
- SNOW_RETAIL_DOCUMENTS（社内ドキュメント、24件）
- CUSTOMER_REVIEWS（顧客レビュー、30件）

---

## 課題・懸念事項

1. **Step 7（Personal Skills）の動作未確認:** 「Agent Skills will be available soon」の記載があり、UI上での挙動確認が必要
2. **Step 3（AGENTS.md）の効果確認:** Snowsight Workspace上での AGENTS.md の有効範囲の確認が必要
3. **環境準備:** 参加者はSnowflakeのトライアルアカウントを使用予定。Cortex Code の利用権限設定が必要

---

## 更新履歴

| 日付 | 更新者 | 内容 |
|------|--------|------|
| 2026-05-26 | 久保 Kazutaka | 初版作成 |
