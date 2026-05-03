# SICP Spinneret DSL Element Survey

- 対象: `game/notebooks/sicp-*.lisp` 全 56 ファイル
- 目的: SICP を markdown に移行する前に、prose body で使われている全 Spinneret DSL タグを把握し、markdown へ落とせない要素が無いことを確認する
- 集計日: 2026-05-03
- 集計方法: 全ファイルを `cl-ppcre` で `\\(:[a-zA-Z][a-zA-Z0-9-]*` を抽出し、tag ごとに件数をカウント。defpackage 由来の `:use` `:import-from` `:export` 等は除外。`:dispatch-code` 等の SICP 特殊トークンは cell-id (`:id :dispatch-code`) として使われており prose の DSL タグではないため除外。

## 出現タグと件数

| Spinneret タグ      | 件数 | 用途                              | Markdown 変換                    |
|---------------------|-----:|-----------------------------------|----------------------------------|
| `(:code ...)`       |  713 | インラインコード                   | `` `text` ``                     |
| `(:strong ...)`     |  367 | 太字                               | `**text**`                       |
| `(:p ...)`          |  349 | 段落                               | `text\n\n`                       |
| `(:div ...)`        |  195 | prose body のトップレベルラッパー | （透過、子要素のみ出力）         |
| `(:li ...)`         |   94 | リスト項目                         | `- text` or `1. text`            |
| `(:ul ...)`         |   30 | unordered list                     | `- ...` ブロック                 |
| `(:pre ...)`        |   24 | コードブロック                     | ` ```\ntext\n``` `               |
| `(:em ...)`         |   10 | イタリック                         | `*text*`                         |
| `(:ol ...)`         |    3 | ordered list                       | `1. ...` ブロック                |
| `(:blockquote ...)` |    1 | 引用                               | `> text`                         |

## 結論

**すべてのタグが標準 Markdown へ綺麗に落とせる**。以下は使われていない:

- `:img`（画像）
- `:a`（アンカー / リンク） — SICP は外部リンクを持たない
- `:h1`〜`:h6`（見出し） — タイトルは notebook 自体の `title` で十分のためか
- `:table` 系
- 数式（KaTeX 系のカスタムタグ）

`:div` はトップレベルラッパー（`:body '(:div ...)`）で、子要素を flat に出力すれば良い。

`:pre` 24 件は wardlisp ソースを表示する用途で、変換時はトリプルバッククオート fenced code block にする（言語タグ無し、または `lisp`）。

## 移行スクリプト `spinneret-tree->markdown` のマッピング表

```lisp
(case tag
  (:p          (format nil "~A~%~%" (children->md children)))
  (:strong     (format nil "**~A**" (children->md children)))
  (:em         (format nil "*~A*" (children->md children)))
  (:code       (format nil "`~A`" (children->md children)))
  (:pre        (format nil "```~%~A~%```~%~%" (children->md children)))
  (:ul         (format nil "~{- ~A~%~}~%" (mapcar #'children->md (li-items children))))
  (:ol         (format nil "~{~D. ~A~%~}~%" (numbered (li-items children))))
  (:li         (children->md children))
  (:blockquote (format nil "> ~A~%~%" (children->md children)))
  (:div        (children->md children))    ; transparent wrapper
  (otherwise   (error "Unknown tag in SICP prose: ~A" tag)))
```

`(otherwise (error ...))` で想定外タグが出た場合に検知できる（防御的）。

## SICP 専用 cell-id keyword（除外したもの、参考）

これらは prose の DSL タグではなく、`(make-cell :id :dispatch-code ...)` の形で cell-id として使われている keyword。grep で誤検出するので除外している:

- `:dispatch-code` (sicp-2-4-2)
- `:both-types-code` (sicp-2-4-3)
- `:coerce-code` (sicp-2-5-2)
- `:poly-code` (sicp-2-5-3)

これらは移行で UUID を新たに割り当てるか、cell-id 文字列としてそのまま `"dispatch-code"` で残すか判断する。現状 `cell-id` は `(or null keyword string)` 型なので文字列でも動く。**移行スクリプトでは keyword の `symbol-name` を kebab-case 文字列にするだけで良い**（学習進捗とのリンクは `learn_*` テーブルの `cell_id` カラムが文字列なのでこれで一貫する）。

## design への反映

design ドキュメント `2026-05-03-courses-and-sicp-migration-design.md` の §10 開かれた疑問 (1) "SICP の prose に DSL の特殊要素はないか" は **解消**: 標準 Markdown で十分。手動修正の対象になりそうな要素は無い。
