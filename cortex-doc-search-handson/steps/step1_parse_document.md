# 手順1: PDFをテキストにする（AI_PARSE_DOCUMENT）

**所要時間**: 15分
**スクリプト**: `scripts/step1_parse_document.sql`

## ゴール

PDFを、検索できる形（ページ単位 → チャンク単位）のテーブルにします。

```
PDF（ステージ） → AI_PARSE_DOCUMENT → DOC_PAGE → DOC_CHUNK
```

## 使う文書

PMDAが公開している4文書を使います。

| 文書 | 種別 | ページ数 | 薬効群 |
|---|---|---|---|
| ダパグリフロジン錠「サワイ」 | 電子添文 | 6 | SGLT2阻害薬 |
| ジャヌビア錠 | 電子添文 | 6 | DPP-4阻害薬 |
| マンジャロ皮下注アテオス | 電子添文 | 6 | GIP/GLP-1受容体作動薬 |
| フォシーガ錠 | 審議結果報告書 | 44 | SGLT2阻害薬 |

**短くて構造化された文書（電子添文）と、長い散文（審議結果報告書）の両方**を混ぜています。
チャンクの分かれ方や検索精度の違いが見えます。

## ★事前準備: PDFの用意

**このリポジトリにPDFは含めていません。** 各自でPMDAから取得してください。

### 取得時の注意

PMDAの「ご利用にあたっての注意事項」（<https://www.pmda.go.jp/searchhelp_005.html>）より。

- 電子添文の**著作権は製造販売業者が保有**している。再配布はしないこと
- **自動的に巡回ダウンロードするアプリケーションは認められていない**。
  今回のように数本を手で取得するのは問題ないが、
  業務で大量の文書を継続的に取り込む設計にする場合は取得方法を検討すること
- 改訂されると最新版に差し替えられるため、**URLは将来無効になる**

### 取得手順

1. <https://www.pmda.go.jp/PmdaSearch/iyakuSearch/> を開く
2. 販売名（例: `ジャヌビア`）で検索する
3. 検索結果の「電子添文」のPDFリンクを開く
4. PDFを保存する

参考として、この資料の作成時点（2026年8月）のURLを載せます。
**改訂されると無効になります**（版番号が末尾に付いているため）。
`システムエラー URLに誤りがあります` が出たら、検索画面から現行リンクを取り直してください。

| ファイル名 | URL |
|---|---|
| `dapagliflozin_tenbun.pdf` | `https://www.pmda.go.jp/PmdaSearch/iyakuDetail/ResultDataSetPDF/300119_3969019F1043_1_01` |
| `januvia_tenbun.pdf` | `https://www.pmda.go.jp/PmdaSearch/iyakuDetail/ResultDataSetPDF/170050_3969010F1034_2_36` |
| `mounjaro_tenbun.pdf` | `https://www.pmda.go.jp/PmdaSearch/iyakuDetail/ResultDataSetPDF/530471_2499422G1024_1_10` |
| `forxiga_shinsa.pdf` | `https://www.pmda.go.jp/drugs/2021/P20210812001/670227000_22600AMX00528_A100_2.pdf` |

### アップロード

Snowsight の画面（Data » Databases » DOC_SEARCH_HANDSON » HANDSON » Stages » DOCS）から
ドラッグ＆ドロップでもできます。その場合はパスに `tenbun/` `shinsa/` を指定してください。

CLIの場合:

```bash
snow sql -q "PUT file:///path/to/dapagliflozin_tenbun.pdf @DOC_SEARCH_HANDSON.HANDSON.DOCS/tenbun/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
snow sql -q "PUT file:///path/to/januvia_tenbun.pdf      @DOC_SEARCH_HANDSON.HANDSON.DOCS/tenbun/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
snow sql -q "PUT file:///path/to/mounjaro_tenbun.pdf     @DOC_SEARCH_HANDSON.HANDSON.DOCS/tenbun/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
snow sql -q "PUT file:///path/to/forxiga_shinsa.pdf      @DOC_SEARCH_HANDSON.HANDSON.DOCS/shinsa/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
```

**`AUTO_COMPRESS=FALSE` は必須です。** gz圧縮されると `AI_PARSE_DOCUMENT` が読めません。

## 手順

### 1-1. ステージの中身を見る

```sql
ALTER STAGE DOCS REFRESH;
SELECT relative_path, size, last_modified FROM DIRECTORY(@DOCS) ORDER BY relative_path;
```

**`REFRESH` を忘れると `DIRECTORY()` が空のまま**です。
ファイルは入っているのに0件、という状態になります（実際にハマりました）。

### 1-2. 1ファイルだけ試す

```sql
SELECT AI_PARSE_DOCUMENT(
    TO_FILE('@DOCS', 'tenbun/januvia_tenbun.pdf'),
    {'mode': 'LAYOUT'}
) AS parsed;
```

`mode` が要点です。

| mode | 挙動 | 向く用途 |
|---|---|---|
| `OCR` | テキストだけ拾う。速い | 散文が中心の文書 |
| `LAYOUT` | 見出し・箇条書き・**表**の構造をMarkdownで保つ | 添付文書、帳票 |

電子添文の「組成・性状」「相互作用」は表です。
`LAYOUT` でないと、薬剤名と対処方法の対応が崩れます。

結果セルを開いて `| 薬剤名等 | 臨床症状・措置方法 |` のような
Markdownの表になっているか確認してください。ここが今日一番の見どころです。

### 1-3. 文書マスタを作る

ファイル名だけだと検索結果が読めません。
「文書種別」「製品名」「薬効群」を別テーブルで持ち、後の絞り込み条件に使います。

### 1-4. 全ファイルをまとめてパースする

`page_split: TRUE` にすると `pages` 配列が返るので、`FLATTEN` でページ1行ずつに展開します。
**ページ番号を残しておくと、後で出典を示せます。**

返ってくる構造:

```
{ "metadata": { "pageCount": 6 },
  "pages": [ { "index": 0, "content": "..." }, ... ] }
```

`index` は0始まりなので `+1` してページ番号にします。

実行後、62行（6+6+6+44）になるはずです。44ページの審議結果報告書があるので
少し時間がかかります。

### 1-5. チャンクに分割する

1ページ丸ごとだと、検索のヒット箇所がぼやけます。
`SPLIT_TEXT_RECURSIVE_CHARACTER` で分割します。

```sql
SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER(page_text, 'markdown', 700, 100)
```

`LAYOUT` の出力はMarkdownなので、`'markdown'` を指定すると見出しや表を壊しにくくなります。

### 1-6. ★チャンクのトークン数を測る

**ここは飛ばさないでください。**

次の手順で使う埋め込みモデルが扱える長さは **512トークン**です。
超えた分はベクトル検索のときに切り捨てられます。

```sql
SELECT
    COUNT(*),
    ROUND(AVG(SNOWFLAKE.CORTEX.COUNT_TOKENS('snowflake-arctic-embed-l-v2.0', chunk_text))),
    MAX(SNOWFLAKE.CORTEX.COUNT_TOKENS('snowflake-arctic-embed-l-v2.0', chunk_text)),
    SUM(IFF(SNOWFLAKE.CORTEX.COUNT_TOKENS('snowflake-arctic-embed-l-v2.0', chunk_text) > 512, 1, 0))
FROM DOC_CHUNK;
```

**日本語は「文字数 ≠ トークン数」です。** 実測で約0.57トークン/文字でした。

| チャンクサイズ | チャンク数 | 平均トークン | 最大トークン | 512超 |
|---|---|---|---|---|
| 1500文字 | 142 | 570 | 1005 | **90件** |
| 700文字 | 302 | 272 | 504 | 0件 |

最初は1500文字で作っていて、142チャンクのうち90件が512トークンを超えていました。
**エラーは出ません。黙って精度が落ちるだけです。**
感覚で決めず、必ず `COUNT_TOKENS` で測ってください。

## つまずきどころ

| 症状 | 原因 | 対処 |
|---|---|---|
| `DIRECTORY(@DOCS)` が0件 | `ALTER STAGE ... REFRESH` していない | REFRESHする |
| パースが失敗する | ステージがSSE暗号化でない | ステージを作り直す |
| パースが失敗する | `AUTO_COMPRESS=TRUE` でPUTした | `FALSE` で再PUT |
| 表がぐちゃぐちゃ | `mode` が `OCR` | `LAYOUT` にする |
| 検索精度が出ない | チャンクが512トークン超 | チャンクサイズを下げる |

---

前: [手順0 ふりかえり](step0_recap.md) ／ 次: [手順2 検索サービスを作る](step2_cortex_search.md)
