# 当日アジェンダ

**時間**: 60分
**形式**: 講師が上から実行していく。受講者は見るだけでも追える。試したい人は自分の環境で並走

## タイムテーブル

| 時刻 | 手順 | 内容 | 見せ場 |
|---|---|---|---|
| 0:00-0:07 | [0](steps/step0_recap.md) | 前回の4部品のふりかえり／今日のゴール | 「この薬は使えるのか」に答えられなかった話 |
| 0:07-0:20 | [1](steps/step1_parse_document.md) | AI_PARSE_DOCUMENT | **LAYOUTで表がMarkdownのまま残る** |
| 0:20-0:28 | [2](steps/step2_cortex_search.md) | Cortex Search | **症状の記述で「ケトアシドーシス」の項が出る** |
| 0:28-0:40 | [3](steps/step3_cortex_agent.md) | Cortex Agent | **売上1位→同じ薬効群の添文へ、を1回の質問で** |
| 0:40-0:47 | [4](steps/step4_streamlit.md) | Streamlit in Snowflake | 業務で配れる形になる |
| 0:47-0:54 | [5](steps/step5_skills.md) | Personal Skills | CoCoから自然文で呼ぶ（締め） |
| 0:54-1:00 | [6](steps/step6_name_matching.md) | AI関数で名寄せ | **1位と2位の差が0.04の行** |

時間が押したら削る順: 6 → 4 → 5。**1〜3は削らない**（今日の本筋）。

## 事前準備（前日まで）

### 1. 環境

```sql
-- scripts/step0_setup.sql を実行
```

```sql
SHOW PARAMETERS LIKE 'CORTEX_ENABLED_CROSS_REGION' IN ACCOUNT;
-- DISABLED なら ACCOUNTADMIN で
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
```

### 2. PDFのアップロード

4本を `@DOCS/tenbun/` と `@DOCS/shinsa/` に置き、`ALTER STAGE DOCS REFRESH;` する。
URLが無効になっていないか前日に確認する（版番号が変わると404になる）。

### 3. ★重い処理は前日に流しておく

| 処理 | 所要 | 当日の扱い |
|---|---|---|
| `DOC_PAGE` 作成（62ページのパース） | 数分 | **前日に実行済みにする。当日は1ファイルだけ実演** |
| `DOC_CHUNK` 作成 | 1分弱 | 当日実行してよい |
| Cortex Search サービス作成 | 数分 | **前日に作る。当日は `CREATE` を見せて、検索は既存サービスで** |
| エージェント作成 | 数秒 | 当日実行 |
| Streamlit デプロイ | 1分 | **前日にデプロイ済みにする** |

**当日にゼロから流すと間に合いません。** 「作るコマンドを見せる」と
「動いているものを触る」を分けてください。

### 4. 動作確認（前日）

```sql
-- 検索が返るか
SELECT doc_type, product_name, COUNT(*)
FROM TABLE(CORTEX_SEARCH_DATA_SCAN(SERVICE_NAME => 'PMDA_DOC_SEARCH')) GROUP BY ALL;

-- エージェントが両ツールを使うか（プレイグラウンドで）
-- 「2026年1月から3月で最も売れている製品はどれ？
--   その製品と同じ薬効群の薬について、腎機能障害のある患者への注意点を教えて」
```

### 5. CoCo のスキル配置

`scripts/step5_skills/pmda-doc-search/` をワークスペースの
`.snowflake/cortex/skills/` 配下にコピーし、`/skills` で認識されるか確認する。

## 開始前（5分前）

- ウェアハウスを起動しておく（`SELECT 1;`）
- Snowsight のタブを用意
  1. ワークスペース（スクリプト）
  2. AI & ML » Agents（プレイグラウンド）
  3. Streamlit アプリ
  4. CoCo チャット
- 画面共有の文字サイズを上げる

## 詰まったときのフォールバック

| 詰まった箇所 | 逃げ方 |
|---|---|
| パースが遅い | 前日実行済みの `DOC_PAGE` を見せる |
| 検索サービスが `ACTIVE` にならない | 前日作成のサービスに切り替える |
| エージェントが変なツールを呼ぶ | それ自体をネタにする（descriptionを直す実演） |
| Streamlit が落ちる | 前日のスクリーンショット／手順4は口頭で |
| 時間が無い | 手順6は「次回」に回す |

## 話す順序の要点

1. **前回できなかったことから始める。** 「この薬は腎機能障害の患者に使えるのか」
2. **表を見せる。** LAYOUTの効果は、崩れた表と保たれた表を並べると一撃で伝わる
3. **キーワード検索との違いを見せる。** 症状の記述がヒットするところ
4. **両ツールを跨ぐ質問で締める。** ここが「賢くなった」の実感
5. **答えられないことを答えられないと言えるか、を必ず見せる。**
   医薬品情報では精度そのもの
