# Step 5: Streamlit in Snowflake — ダッシュボード生成

**所要時間:** 15分  
**目的:** Cortex Code を使って Streamlit アプリを生成・デプロイし、ビジュアルダッシュボードを作る体験をする。

---

## Streamlit in Snowflake とは

> Python だけで書ける Web アプリを Snowflake の中で動かせる機能。  
> データがある場所でアプリが動くため、ETL不要・権限管理もSnowflakeのRBACをそのまま継承。

---

## 1. Cortex Code にアプリ生成を依頼する

Workspace で新しい Python ファイル（`.py`）を作成し、Cortex Code に以下を入力:

```
SNOWRETAIL_DB.SNOWRETAIL_SCHEMA のデータを使った売上ダッシュボードの
Streamlit アプリを作ってください。

含める内容:
- 月別売上推移グラフ（実店舗 vs EC）
- 商品カテゴリ別売上円グラフ
- 売上上位商品テーブル（トップ10）
- フィルター: 期間選択（月）、チャネル選択（全体/実店舗/EC）

シンプルで見やすいデザインにしてください。
```

---

## 2. 生成されたコードを確認する

Cortex Code が生成したコードを diff ビューで確認し、問題なければ **Accept** を押して適用。

---

## 3. Snowflake にデプロイする

1. Workspace のファイルを右クリック → **Deploy as Streamlit App**
2. または Cortex Code に依頼:

```
このStreamlitアプリをSnowflakeにデプロイして
データベース: SNOWRETAIL_DB
スキーマ: SNOWRETAIL_SCHEMA
アプリ名: SNOWRETAIL_DASHBOARD
```

---

## 4. アプリを確認する

1. 左ナビゲーション **Projects → Streamlit** を選択
2. `SNOWRETAIL_DASHBOARD` をクリックして起動
3. ダッシュボードが表示されることを確認

---

## 5. アプリを改善する（時間があれば）

Cortex Code に追加機能を依頼:

```
このダッシュボードに顧客レビューの感情分析結果を追加して。
CUSTOMER_REVIEWS テーブルの REVIEW_TEXT を AI_SENTIMENT で分析して
ポジティブ/ネガティブの比率を表示してください。
```

---

## ポイント

- Cortex Code は「Streamlit をゼロから書く」体験を劇的に短縮する
- デプロイまで自然言語で完結できる
- ビジネス部門へのデータ配布ツールとして即使える
- Python が書けなくても、Cortex Code があれば OK
