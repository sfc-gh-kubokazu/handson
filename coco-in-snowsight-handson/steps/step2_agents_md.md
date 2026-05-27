# Step 2: AGENTS.md — ソフトガバナンス体験

**所要時間:** 15分  
**目的:** AGENTS.md をWorkspaceに配置することで、Cortex Code の応答を制御できることを体験する。

---

## AGENTS.md とは

> AGENTS.md は Cortex Code への「永続的な指示書」です。  
> Workspace のルートに置くと、以降の全会話に自動的に適用されます。

| 比較 | AGENTS.md なし | AGENTS.md あり |
|------|--------------|--------------|
| SQLの品質 | 汎用的なSQL | ビジネス定義に沿ったSQL |
| 禁止操作 | 制御なし | 指定した操作をブロック |
| 用語の解釈 | LLMの判断 | 定義に基づいた正確な解釈 |

---

## 1. AGENTS.md なしで試す

まず AGENTS.md なしで以下を実行し、結果を確認する:

```
売上合計を計算して
```

> 「売上」の定義が曖昧なため、LLMが独自に解釈してSQLを生成します。

---

## 2. AGENTS.md を作成する

1. Workspace のファイル一覧から **+ New File → Blank File** を選択
2. ファイル名を **`AGENTS.md`** にする（ルートディレクトリに置くこと）
3. 以下の内容を貼り付けて保存:

```markdown
# スノーリテール データ分析エージェント

## プロジェクト概要
株式会社スノーリテールの売上データを分析するエージェントです。
対象データベース: SNOWRETAIL_DB.SNOWRETAIL_SCHEMA

## ビジネス定義
- **売上金額**: RETAIL_DATA.TOTAL_AMOUNT + EC_DATA.TOTAL_AMOUNT の合算
- **売上数量**: RETAIL_DATA.QUANTITY + EC_DATA.QUANTITY の合算
- **チャネル**: 「実店舗」= RETAIL_DATA、「EC」= EC_DATA
- **期間**: 特に指定がなければ直近3ヶ月

## SQL 規約
- 必ず SNOWRETAIL_DB.SNOWRETAIL_SCHEMA を明示的に指定すること
- GROUP BY には列名（エイリアス不可）を使用すること
- 売上分析には RETAIL_DATA と EC_DATA の両方を含めること

## 禁止事項
- DROP TABLE、DELETE、TRUNCATE は絶対に実行しないこと
- 本番環境への書き込みは禁止
- 個人情報（CUSTOMER_IDなど）を SELECT * で取得しないこと
```

---

## 3. AGENTS.md ありで同じプロンプトを試す

AGENTS.md を保存した後、同じプロンプトを実行:

```
売上合計を計算して
```

> 今度は「売上 = RETAIL_DATA + EC_DATA の合算」という定義に基づいたSQLが生成されます。

---

## 4. 禁止事項の確認

```
RETAIL_DATA テーブルを DROP して
```

> AGENTS.md の禁止事項が効いていれば、Cortex Code は実行を拒否または警告します。

---

## ポイント

- AGENTS.md はチームで共有できる「AIへのルールブック」
- ビジネス定義を書いておくことで、誰が使っても同じ基準で分析できる
- AGENTS.md があれば「毎回同じ説明をしなくて済む」という体験が重要
