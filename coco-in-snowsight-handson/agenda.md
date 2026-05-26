# アジェンダ — Cortex Code in Snowsight ハンズオン

**日時:** 2026-05-28 (水) 13:00-15:00（120分）  
**形式:** リモート / Zoom  
**環境:** Cortex Code in Snowsight（ブラウザのみ・インストール不要）

---

## タイムテーブル

| 時間 | 分 | 内容 | 担当 |
|------|----|------|------|
| 13:00-13:10 | 10分 | オープニング / Snowflake・Cortex Code概要デモ | AE / SE |
| 13:10-13:30 | 20分 | **Step 0-1:** Workspace作成・setup.sql実行・データ探索 | 全員 |
| 13:30-13:45 | 15分 | **Step 3:** AGENTS.md でガバナンス体験 | 全員 |
| 13:45-14:15 | 30分 | **Step 6:** Semantic View / Cortex Search / Cortex Agent | 全員 |
| 14:15-14:35 | 20分 | **Step 7:** Personal Skills 作成・呼び出し | 全員 |
| 14:35-14:50 | 15分 | **Step 8:** Streamlit アプリ生成・デプロイ | 全員 |
| 14:50-15:00 | 10分 | まとめ・Q&A・ネクストステップ紹介 | AE / SE |

---

## ハンズオン概要

### シナリオ

**架空企業: 株式会社スノーリテール（SnowRetail Inc.）**  
首都圏で150店舗を展開するリテール企業。ECも成長中。  
課題: 売上データのサイロ化・分析速度の遅さ・ビジネス部門のセルフサービス分析不足

### 使用データ

| ファイル | 件数 | 概要 |
|---------|------|------|
| RETAIL_DATA | 550 | 実店舗販売トランザクション |
| EC_DATA | 550 | EC販売トランザクション |
| PRODUCT_MASTER | 125 | 商品マスタ |
| SNOW_RETAIL_DOCUMENTS | 24 | 社内ドキュメント |
| CUSTOMER_REVIEWS | 30 | 顧客レビュー |

### ハンズオンアーキテクチャ

```
[Step 0-1] データ準備・探索
    ↓
[Step 3] AGENTS.md（AIへの指示書でガバナンス）
    ↓
[Step 6] Semantic View → Cortex Search → Cortex Agent
    ↓
[Step 7] カスタムスキルで定型業務を自動化
    ↓
[Step 8] Streamlit ダッシュボードで可視化・配布
```

---

## 参加者向け事前準備

- [ ] Snowflake トライアルアカウント作成（当日でも可）
  - Edition: **Enterprise**
  - クラウド: **AWS**
  - リージョン: **US West (Oregon)**（不可の場合は Asia Pacific Tokyo）
- [ ] Snowsight にブラウザからログイン確認

> インストール作業は一切不要です。ブラウザのみでご参加いただけます。

---

## 運営側チェックリスト

### 当日までに
- [ ] 参加者へ事前準備メール送付（トライアルアカウント作成手順）
- [ ] setup.sql の動作確認（トライアルアカウントで実行テスト）
- [ ] AGENTS.md サンプルの準備
- [ ] Step 7 用スキルファイルの準備
- [ ] Zoom URL 参加者に送付済み確認

### 当日
- [ ] 開始前に画面共有・音声確認
- [ ] 参加者のトライアルアカウント作成状況確認
- [ ] 各ステップ前に「詰まったら気軽に声をかけてください」を伝える

---

## コンテンツ参照先

- **スライド:** https://docs.google.com/presentation/d/1vuUIEdqcQFvzKpOWpl4zFNKHDPF8XWsfiY4UVThRp7U
- **GitHub（オリジナル）:** https://github.com/snow-jp-handson-org/coco-cli-handson-jp
- **公式ドキュメント:** https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-snowsight
