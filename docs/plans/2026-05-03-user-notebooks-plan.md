# ユーザー作成ノートブック機能 実装計画

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** ユーザーがブログ記事のように自分のSICP風ノートブックを作成・公開し、他ユーザーが学習進捗連動で実行できるMVPを構築する。

**Architecture:** 既存ブログpost（`models/post.lisp` 他）の draft/published / slug / owner-check 構造を翻案。新規 `user_notebook` テーブル（cellsはJSONB、cell_idはUUIDで安定化）、Markdown区切り記号方式の単一テキストエリア編集、3bmdでprose→HTML+ホワイトリストサニタイザ、cell実行は既存の `run-cell`／`web/ui/notebook` を再利用、学習進捗は既存`learn_*`テーブル（`notebook_id` VARCHAR）にUUIDを入れて流用。

**Tech Stack:** Common Lisp / SBCL + qlot, ASDF package-inferred system, Mito ORM + cl-dbi (PostgreSQL), Ningle + Clack/Hunchentoot, Spinneret HTML, HTMX, Rove tests, **新規依存: 3bmd（Markdown）, Plump（HTMLパーサ／サニタイザ用）**.

**Reference:** 設計ドキュメント [`docs/plans/2026-05-03-user-notebooks-design.md`](./2026-05-03-user-notebooks-design.md) を必ず参照。

**Lispツール規約:** すべての `.lisp`/`.asd` 操作は cl-mcp ツール（`lisp-edit-form`/`lisp-patch-form`/`lisp-read-file`/`repl-eval`/`load-system`/`run-tests` 等）。Read/Edit/Write/Grep/Glob はLispファイルに使わない。Markdownや設定ファイル(`.md`/`.sql`/`.yml`/`qlfile`)は通常のWrite/Edit可。

**初期セットアップ:** 各タスクの最初に必ず `mcp__cl-mcp__fs-set-project-root path=/home/wiz/recurya` を呼ぶ（cl-mcpがworkerクラッシュ後に再接続した場合に必要）。

**コミット方針:** 各タスクを「テスト→失敗確認→実装→成功確認→コミット」で1タスク1コミット。コミットメッセージは `feat:` `test:` `chore:` プレフィックス + 既存スタイル（命令法、末尾に `Co-Authored-By:` 行）。

---

## Phase 1: 依存追加とサニタイザ・パーサ基礎（Lispのみ・DB不要）

### Task 1: 依存ライブラリ追加（3bmd, plump）

**Files:**
- Modify: `/home/wiz/recurya/qlfile`
- Modify: `/home/wiz/recurya/recurya.asd`（depends-on に `"3bmd"` と `"plump"` 追加）

**Step 1: qlfile に追加**

`qlfile` に以下2行を追加（ファイル末尾でよい）:
```
ql 3bmd :latest
ql plump :latest
```

**Step 2: `recurya.asd` の主システム depends-on に追加**

cl-mcp `lisp-patch-form` を使う:
```
form_type: defsystem
form_name: recurya
old_text: "wardlisp"
new_text: "wardlisp"
                ;; Markdown + HTML sanitizer for user-authored notebooks
                "3bmd"
                "plump"
```

（注: 既存の `"wardlisp"` 行の直後に挿入。`old_text` は既存ファイルで一意な箇所を確認してから書く。一意でなければ前後行を含めて拡張。）

**Step 3: コンテナで qlot install**

```bash
docker compose exec recurya bash -lc 'cd /home/wiz/recurya && qlot install'
```

期待: 3bmd と plump の解決ログ。エラーなし。

**Step 4: REPL で読み込み確認**

cl-mcp `repl-eval`:
```lisp
(asdf:load-system :3bmd) (asdf:load-system :plump)
(values (find-package :3bmd) (find-package :plump))
```
期待: 両パッケージが `#<PACKAGE ...>` で返る。

**Step 5: コミット**

```bash
git add qlfile qlfile.lock recurya.asd && git commit -m "$(cat <<'EOF'
chore: add 3bmd and plump for user notebook prose rendering

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: HTMLサニタイザのテストを書く（失敗させる）

**Files:**
- Create: `/home/wiz/recurya/utils/html-sanitize.lisp`（雛形のみ：パッケージ定義 + `(defun sanitize-html (html-string) (error "not implemented"))`）
- Create: `/home/wiz/recurya/tests/utils/html-sanitize.lisp`
- Modify: `/home/wiz/recurya/recurya.asd`（主システムに `"recurya/utils/html-sanitize"`、テストシステムに `"recurya/tests/utils/html-sanitize"`）
- Modify: `/home/wiz/recurya/tests/all.lisp`（`*test-packages*` に `:recurya/tests/utils/html-sanitize` 追加）

**Step 1: 雛形 `utils/html-sanitize.lisp` 作成**

cl-mcp `fs-write-file`（新規Lispファイルは最小雛形→`lisp-edit-form`で拡張のフロー）:
```lisp
;;;; utils/html-sanitize.lisp --- Allowlist HTML sanitizer.

(defpackage #:recurya/utils/html-sanitize
  (:use #:cl)
  (:export #:sanitize-html))

(in-package #:recurya/utils/html-sanitize)

(defun sanitize-html (html-string)
  "Sanitize HTML-STRING via tag/attribute allowlist. Stub."
  (declare (ignore html-string))
  (error "not implemented"))
```

`lisp-check-parens` で確認後、ASDF登録に進む。

**Step 2: テストファイル作成**

```lisp
;;;; tests/utils/html-sanitize.lisp --- Tests for HTML sanitizer.

(defpackage #:recurya/tests/utils/html-sanitize
  (:use #:cl #:rove)
  (:import-from #:recurya/utils/html-sanitize #:sanitize-html))

(in-package #:recurya/tests/utils/html-sanitize)

(deftest passes-allowed-tags
  (testing "p, strong, em, code, a remain"
    (ok (search "<p>"        (sanitize-html "<p>hello</p>")))
    (ok (search "<strong>"   (sanitize-html "<strong>x</strong>")))
    (ok (search "<a href"    (sanitize-html "<a href=\"https://example.com\">x</a>")))))

(deftest strips-script-and-on-handlers
  (testing "<script> is removed"
    (ng (search "<script"    (sanitize-html "<p>ok</p><script>alert(1)</script>"))))
  (testing "onclick attribute is removed"
    (ng (search "onclick"    (sanitize-html "<a href=\"x\" onclick=\"a()\">x</a>")))))

(deftest strips-javascript-href
  (testing "javascript: scheme is removed from a@href"
    (let ((out (sanitize-html "<a href=\"javascript:alert(1)\">x</a>")))
      (ng (search "javascript:" out)))))

(deftest strips-iframe-and-style
  (ng (search "<iframe" (sanitize-html "<iframe src=\"x\"></iframe>")))
  (ng (search "<style"  (sanitize-html "<style>body{}</style>"))))
```

**Step 3: `recurya.asd` に登録**

`lisp-patch-form`:
- 主システム: `"recurya/utils/common"` の直後に `"recurya/utils/html-sanitize"` を追加
- テストシステム: `"recurya/tests/utils/common"` の直後に `"recurya/tests/utils/html-sanitize"` を追加

**Step 4: `tests/all.lisp` に登録**

`lisp-edit-form` で `*test-packages*` のリストに `:recurya/tests/utils/html-sanitize` を `:recurya/tests/utils/common` の直後へ追加。

**Step 5: テスト実行（失敗を確認）**

```lisp
(asdf:load-system :recurya/tests :force t)
```
→ load成功。次に
```
mcp__cl-mcp__run-tests system="recurya/tests/utils/html-sanitize"
```
期待: 4テスト全て FAIL（"not implemented" エラー）。これでテストが本当にコードを実行していることを確認できる。

**Step 6: コミット**

```bash
git add utils/html-sanitize.lisp tests/utils/html-sanitize.lisp recurya.asd tests/all.lisp
git commit -m "test: add failing tests for HTML sanitizer

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: HTMLサニタイザを実装してテストを通す

**Files:**
- Modify: `/home/wiz/recurya/utils/html-sanitize.lisp`

**Step 1: 設計**

許可タグ・許可属性の定数 + Plumpで HTML を parse → DOMを再帰的に走査 → 不許可ノード/属性を除去 → 文字列化、の構成。約50〜100行。

許可タグ:
```
p strong em code pre a ul ol li blockquote h1 h2 h3 h4 h5 h6 br hr img
```
許可属性:
```
a -> href     (http(s):/相対のみ。'javascript:'、'data:' は拒否)
img -> src    (http(s):/相対のみ)
img -> alt    (任意)
* -> class    (許可リストに該当する class 名のみ。MVPでは空でよい — class は全削除)
```

**Step 2: 実装**

`lisp-edit-form` で `sanitize-html` を replace。Plumpの `plump:parse` → `plump:traverse` でDOMを変更 → `plump:serialize` で文字列化。Plumpはエッジケース（不正タグ、self-closing）をうまく扱える。

実装スケルトン（Plumpの正確なAPIは `clhs-lookup` と `plump` パッケージのソースを参照しつつ書く）:

```lisp
(defparameter +allowed-tags+
  '("p" "strong" "em" "code" "pre" "a" "ul" "ol" "li" "blockquote"
    "h1" "h2" "h3" "h4" "h5" "h6" "br" "hr" "img"))

(defparameter +allowed-attrs+
  '(("a"   . ("href"))
    ("img" . ("src" "alt"))))

(defun safe-url-p (url)
  "URL must be relative or http(s) — reject javascript:, data:, etc."
  (or (zerop (length url))
      (alexandria:starts-with-subseq "/" url)
      (alexandria:starts-with-subseq "./" url)
      (alexandria:starts-with-subseq "../" url)
      (alexandria:starts-with-subseq "http://" url)
      (alexandria:starts-with-subseq "https://" url)
      (and (find #\: url) nil)        ;; reject other schemes outright
      t))

(defun sanitize-html (html-string)
  (let ((root (plump:parse html-string)))
    (plump:traverse
     root
     (lambda (node)
       (when (plump:element-p node)
         (let ((tag (string-downcase (plump:tag-name node))))
           (cond
             ((not (member tag +allowed-tags+ :test #'equal))
              ;; replace element with its children (or remove)
              (plump:remove-child node))
             (t
              (let ((allowed (cdr (assoc tag +allowed-attrs+ :test #'equal))))
                (loop for k being the hash-keys of (plump:attributes node)
                      using (hash-value v)
                      unless (member k allowed :test #'equal)
                        do (plump:remove-attribute node k)
                      when (and (member k '("href" "src") :test #'equal)
                                (not (safe-url-p v)))
                        do (plump:remove-attribute node k))))))))
     :test #'plump:element-p)
    (with-output-to-string (s) (plump:serialize root s))))
```

(Plumpの正確な関数名は実装中に `clhs-lookup`/Plumpソース調査で確認。`plump:traverse` の戻り値・破壊的変更の扱いに注意。)

**Step 3: REPLでスポット確認**

```lisp
(load-system :recurya/utils/html-sanitize :force t)
(recurya/utils/html-sanitize:sanitize-html "<p>ok</p><script>alert(1)</script>")
```
期待: `<p>ok</p>` のみ。

**Step 4: テスト実行**

```
mcp__cl-mcp__run-tests system="recurya/tests/utils/html-sanitize"
```
期待: 4テスト全PASS。

**Step 5: コミット**

```bash
git commit -am "feat: implement HTML sanitizer with tag/attribute allowlist

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: パーサ — proseのみのパースを実装（テストファースト）

**Files:**
- Create: `/home/wiz/recurya/game/notebook-parser.lisp`
- Create: `/home/wiz/recurya/tests/game/notebook-parser.lisp`
- Modify: `/home/wiz/recurya/recurya.asd`（主・テスト両方）
- Modify: `/home/wiz/recurya/tests/all.lisp`

**Step 1: パッケージ雛形**

`game/notebook-parser.lisp`:

```lisp
;;;; game/notebook-parser.lisp --- Markdown <-> cell list parser for user notebooks.

(defpackage #:recurya/game/notebook-parser
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:import-from #:uuid
                #:make-v4-uuid)
  (:export #:parse-notebook-body
           #:cells->body-md
           #:render-cell-prose-html))

(in-package #:recurya/game/notebook-parser)

(defun parse-notebook-body (body-md &optional existing-cells)
  "Parse BODY-MD into (values cells errors). Stub."
  (declare (ignore body-md existing-cells))
  (error "not implemented"))

(defun cells->body-md (cells)
  "Render CELLS list back into the canonical body-md string. Stub."
  (declare (ignore cells))
  (error "not implemented"))

(defun render-cell-prose-html (markdown-string)
  "Markdown -> sanitized HTML. Stub."
  (declare (ignore markdown-string))
  (error "not implemented"))
```

**Step 2: テストファイル — proseのみのケース**

```lisp
;;;; tests/game/notebook-parser.lisp

(defpackage #:recurya/tests/game/notebook-parser
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebook-parser
                #:parse-notebook-body
                #:cells->body-md
                #:render-cell-prose-html)
  (:import-from #:recurya/game/notebook
                #:cell-id #:cell-kind #:cell-body #:cell-description
                #:cell-test-cases))

(in-package #:recurya/tests/game/notebook-parser)

(deftest single-prose-cell
  (let ((body "===prose===
Lispは式を評価する言語です。"))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (ok (null errors))
      (ok (= 1 (length cells)))
      (let ((c (first cells)))
        (ok (eq :prose (cell-kind c)))
        (ok (search "Lispは式を評価する言語です。" (cell-body c)))
        (ok (stringp (cell-id c)))))))
```

**Step 3: ASDFとtests/all.lispへ登録**（Task 2と同手順）

**Step 4: 実行 — 失敗確認**
期待: `not implemented` エラーで FAIL。

**Step 5: 最小実装で通す**

`lisp-edit-form` で `parse-notebook-body` を実装:

```lisp
(defun parse-notebook-body (body-md &optional existing-cells)
  (declare (ignore existing-cells))
  (let ((errors '())
        (cells '())
        (current-kind nil)
        (current-desc nil)
        (current-buffer (make-array 0 :element-type 'character
                                      :fill-pointer 0 :adjustable t))
        (lines (split-lines body-md)))
    (flet ((flush ()
             (when current-kind
               (let ((body (string-trim '(#\Space #\Tab #\Newline #\Return)
                                        (coerce current-buffer 'string))))
                 (push (make-cell :id (princ-to-string (uuid:make-v4-uuid))
                                  :kind current-kind
                                  :body body
                                  :description (or current-desc ""))
                       cells))
               (setf (fill-pointer current-buffer) 0))))
      (dolist (line lines)
        (cond
          ((string= line "===prose===")
           (flush)
           (setf current-kind :prose
                 current-desc nil))
          (t
           (vector-push-extend #\Newline current-buffer)
           (loop for c across line do (vector-push-extend c current-buffer)))))
      (flush))
    (values (nreverse cells) (nreverse errors))))

(defun split-lines (s)
  "Split S into a list of lines (stripping a single trailing \r if any)."
  (let ((lines '())
        (start 0))
    (loop for i from 0 below (length s)
          when (char= (char s i) #\Newline)
          do (let ((line (subseq s start i)))
               (push (if (and (> (length line) 0)
                              (char= (char line (1- (length line))) #\Return))
                         (subseq line 0 (1- (length line)))
                         line)
                     lines)
               (setf start (1+ i))))
    (when (< start (length s))
      (push (subseq s start) lines))
    (nreverse lines)))
```

**Step 6: テスト実行 — 通る**

期待: `single-prose-cell` PASS。

**Step 7: コミット**

```bash
git commit -am "feat: parse single prose cell from notebook body markdown

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: パーサ — eval cell対応

**Files:**
- Modify: `/home/wiz/recurya/game/notebook-parser.lisp`
- Modify: `/home/wiz/recurya/tests/game/notebook-parser.lisp`

**Step 1: 失敗テスト追加**

```lisp
(deftest single-eval-cell
  (let ((body "===eval===
(+ 137 349)"))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (ok (null errors))
      (ok (= 1 (length cells)))
      (ok (eq :code-eval (cell-kind (first cells))))
      (ok (search "(+ 137 349)" (cell-body (first cells)))))))

(deftest prose-then-eval
  (let ((body "===prose===
Hello.

===eval===
(+ 1 2)"))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (ok (null errors))
      (ok (= 2 (length cells)))
      (ok (eq :prose      (cell-kind (first cells))))
      (ok (eq :code-eval  (cell-kind (second cells)))))))
```

**Step 2: 実行 — 失敗確認**

**Step 3: 実装拡張**

`parse-notebook-body` 内 `cond` に `===eval===` の分岐を追加（`:code-eval`）。

**Step 4: テスト実行 — 通る**

**Step 5: コミット**

---

### Task 6: パーサ — exercise + expect cell対応

**Files:** Task 5 と同じ2ファイル。

**Step 1: 失敗テスト追加**

```lisp
(deftest single-exercise-with-expect
  (let ((body "===exercise: 三項の和===
; ここに式を書く

===expect: 三項の和===
508"))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (ok (null errors))
      (ok (= 1 (length cells)))
      (let ((c (first cells)))
        (ok (eq :code-exercise (cell-kind c)))
        (ok (string= "三項の和" (cell-description c)))
        (ok (= 1 (length (cell-test-cases c))))))))

(deftest exercise-with-input-output-expect
  (let ((body "===exercise: zero?===
(define (zero? x) ???)

===expect===
input: (zero? 0)
output: t

===expect===
input: (zero? 5)
output: nil"))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (ok (null errors))
      (ok (= 2 (length (cell-test-cases (first cells))))))))
```

**Step 2: 実行 — 失敗確認**

**Step 3: 実装拡張**

`===exercise:` の正規表現マッチ → description抽出。`===expect===` 検出時は直前のexerciseに `:test-cases` を後付け（exercise cellを作るが、`flush` 前に保留する設計が要る）。

実装は状態機械を: `current-exercise-cell` を保持し、`===expect===` ヘッダの時に test-case をパース→そこに append。次の非expectヘッダかEOFで flush。

**Step 4: テスト実行 — 通る**

**Step 5: コミット**

---

### Task 7: パーサ — バリデーションエラー

**Files:** 同上。

**Step 1: テスト追加**

```lisp
(deftest expect-without-prior-exercise
  (let ((body "===expect===
1"))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (declare (ignore cells))
      (ok (find-if (lambda (e) (search "expect" (getf e :message)))
                   errors)))))

(deftest exercise-missing-description
  (let ((body "===exercise===
(foo)"))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (declare (ignore cells))
      (ok errors))))

(deftest unknown-header
  (let ((body "===banana===
peel"))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (declare (ignore cells))
      (ok errors))))

(deftest empty-body-zero-cells
  (multiple-value-bind (cells errors) (parse-notebook-body "")
    (declare (ignore cells))
    (ok (find-if (lambda (e) (search "no cell" (getf e :message)))
                 errors))))
```

**Step 2-5: 失敗 → 実装 → 成功 → コミット**

errorsは plist `(:line N :message "...")` の list。

---

### Task 8: パーサ — 既存cell-id引き継ぎ

**Files:** 同上。

**Step 1: テスト**

```lisp
(deftest preserves-cell-id-on-match
  (let* ((body "===prose===
Hello.")
         (existing (list (make-cell :id "STABLE-ID" :kind :prose
                                    :body "Hello." :description ""))))
    (multiple-value-bind (cells errors) (parse-notebook-body body existing)
      (ok (null errors))
      (ok (string= "STABLE-ID" (cell-id (first cells)))))))

(deftest assigns-new-uuid-when-no-match
  (let* ((body "===prose===
Different."))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (declare (ignore errors))
      (ok (stringp (cell-id (first cells))))
      (ok (not (string= "STABLE-ID" (cell-id (first cells))))))))
```

**Step 2-5: 失敗 → 実装 → 成功 → コミット**

実装: 各新規cellを作る前に `existing-cells` を順走査し、`(kind, body, description)` の三つ組一致でマッチした最初のcellの `cell-id` を流用。マッチしたcellは existing から取り除く（重複防止）。

---

### Task 9: cells→body-md 逆方向 + 往復テスト

**Files:** 同上。

**Step 1: テスト**

```lisp
(deftest roundtrip-prose
  (let ((body "===prose===
Hello world."))
    (let* ((cells1 (parse-notebook-body body))
           (md     (cells->body-md cells1))
           (cells2 (parse-notebook-body md)))
      (ok (= (length cells1) (length cells2)))
      (ok (string= (cell-body (first cells1)) (cell-body (first cells2)))))))

(deftest roundtrip-mixed
  (let* ((body "===prose===
Intro.

===eval===
(+ 1 2)

===exercise: sum===
; ?

===expect: sum===
3")
         (cells1 (parse-notebook-body body))
         (md     (cells->body-md cells1))
         (cells2 (parse-notebook-body md)))
    (ok (= (length cells1) (length cells2)))
    (loop for c1 in cells1 for c2 in cells2 do
          (ok (eq      (cell-kind c1) (cell-kind c2)))
          (ok (string= (cell-body c1) (cell-body c2))))))
```

**Step 2-5: 失敗 → 実装 → 成功 → コミット**

実装: `cells->body-md` で各 cell をヘッダ + 本文 + 空行 で出力。code-exercise は `===exercise: <desc>===` + body + 各 test-case の `===expect[: desc]===` + `input: ...` / `output: ...`。

---

### Task 10: パーサ — Markdown→HTML （prose描画）

**Files:** 同上。

**Step 1: テスト**

```lisp
(deftest renders-markdown-bold-and-strips-script
  (let ((html (render-cell-prose-html "**bold**

<script>x</script>")))
    (ok (search "<strong>bold</strong>" html))
    (ng (search "<script" html))))
```

**Step 2-5: 失敗 → 実装 → 成功 → コミット**

実装:
```lisp
(defun render-cell-prose-html (md)
  (let ((html (with-output-to-string (s)
                (3bmd:parse-string-and-print-to-stream md s))))
    (recurya/utils/html-sanitize:sanitize-html html)))
```

`recurya/utils/html-sanitize` を `notebook-parser` パッケージで `:import-from` する。

---

## Phase 2: データ層

### Task 11: Mitoマイグレーション生成と適用

**Files:**
- Create: `/home/wiz/recurya/models/user-notebook.lisp`
- Create: `/home/wiz/recurya/db/migrations/<timestamp>-user-notebooks.up.sql` (Mito CLI生成)
- Create: `/home/wiz/recurya/db/migrations/<timestamp>-user-notebooks.down.sql` (Mito CLI生成)
- Modify: `/home/wiz/recurya/recurya.asd`
- Modify: `/home/wiz/recurya/db/schema.sql`（Mitoが自動更新）

**Step 1: モデル定義**

`models/user-notebook.lisp`:

```lisp
;;;; models/user-notebook.lisp --- User-authored notebook table.

(defpackage #:recurya/models/user-notebook
  (:use #:cl #:mito)
  (:import-from #:recurya/models/users #:users #:users-id)
  (:export #:user-notebook
           #:user-notebook-id
           #:user-notebook-slug
           #:user-notebook-title
           #:user-notebook-summary
           #:user-notebook-body-md
           #:user-notebook-cells
           #:user-notebook-status
           #:user-notebook-published-at
           #:user-notebook-author
           #:user-notebook-author-id
           #:user-notebook-created-at
           #:user-notebook-updated-at))

(in-package #:recurya/models/user-notebook)

(deftable user-notebook ()
  ((id           :col-type :uuid :initarg :id :accessor %user-notebook-id :primary-key t)
   (slug         :col-type (:varchar 255) :initarg :slug    :accessor user-notebook-slug)
   (title        :col-type (:varchar 255) :initarg :title   :accessor user-notebook-title)
   (summary      :col-type (or (:varchar 500) :null) :initarg :summary :initform nil :accessor user-notebook-summary)
   (body-md      :col-type :text         :initarg :body-md :accessor user-notebook-body-md)
   (cells        :col-type :jsonb        :initarg :cells   :accessor user-notebook-cells)
   (status       :col-type (:varchar 32) :initarg :status :initform "draft" :accessor user-notebook-status)
   (published-at :col-type (or :timestamptz :null) :initarg :published-at :initform nil :accessor user-notebook-published-at)
   (author       :col-type users         :initarg :author  :accessor user-notebook-author))
  (:auto-pk nil)
  (:unique-keys slug)
  (:keys (status :created_at) (author_id :created_at))
  (:documentation "User-authored notebook with draft/published lifecycle."))

(defun user-notebook-id (nb) (%user-notebook-id nb))

(defun user-notebook-author-id (nb)
  (let ((u (user-notebook-author nb)))
    (when u (users-id u))))

(defun user-notebook-created-at (nb) (mito:object-created-at nb))
(defun user-notebook-updated-at (nb) (mito:object-updated-at nb))
```

**Step 2: ASDF登録**

`recurya.asd` 主システムの models セクションに `"recurya/models/user-notebook"` を `"recurya/models/post"` の直後に追加。

**Step 3: マイグレーション生成（mito-migrate skillの手順）**

```bash
docker compose exec recurya bash -lc 'cd /home/wiz/recurya && .qlot/bin/mito generate-migrations -t postgres -H postgres -P 5432 -d recurya -u postgres -p postgres -s recurya -D db/'
```

期待: `db/migrations/<timestamp>-...up.sql` が生成、CREATE TABLE文が入っている。

**Step 4: マイグレーション適用**

```bash
docker compose exec recurya bash -lc 'cd /home/wiz/recurya && .qlot/bin/mito migrate -t postgres -H postgres -P 5432 -d recurya -u postgres -p postgres -s recurya -D db/'
```

期待: 適用ログ。

**Step 5: スキーマ確認**

```bash
docker compose exec recurya-postgres psql -U postgres -d recurya -c '\d user_notebook'
```

期待: 全カラムと index `unique_user_notebook_slug` 等が見える。

**Step 6: コミット**

```bash
git add models/user-notebook.lisp recurya.asd db/migrations/ db/schema.sql
git commit -m "feat: add user_notebook table and Mito model

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: db CRUD - create / get-by-id / get-by-slug（テスト先行）

**Files:**
- Create: `/home/wiz/recurya/db/user-notebooks.lisp`
- Create: `/home/wiz/recurya/tests/db/user-notebooks.lisp`
- Modify: `recurya.asd`、`tests/all.lisp`

**Step 1: テスト雛形（既存 `tests/db/posts.lisp` を参考）**

最初のテスト:
```lisp
(deftest create-and-get-by-id
  (with-test-db
    (let* ((u (make-test-user))
           (nb (create-user-notebook!
                :title "T1" :body-md "===prose===\nx" :cells '() :author u))
           (id (user-notebook-id nb)))
      (let ((found (get-user-notebook-by-id id)))
        (ok found)
        (ok (string= "T1" (user-notebook-title found)))))))
```

`with-test-db` と `make-test-user` は既存テストヘルパ（`recurya/tests/support/db`）に存在するはず — 確認の上、なければ既存の `tests/db/posts.lisp` を見て同じヘルパを使う。

**Step 2: ASDFとtests/all.lispに登録**

**Step 3: 失敗確認**

**Step 4: 実装**

`db/user-notebooks.lisp`:

```lisp
(defpackage #:recurya/db/user-notebooks
  (:use #:cl #:mito #:sxql)
  (:import-from #:recurya/models/user-notebook #:user-notebook)
  (:import-from #:recurya/db/posts #:slugify #:generate-uuid #:ensure-uuid)
  (:export #:create-user-notebook!
           #:get-user-notebook-by-id
           #:get-user-notebook-by-slug
           #:update-user-notebook!
           #:delete-user-notebook!
           #:list-user-notebooks
           #:count-user-notebooks))

(in-package #:recurya/db/user-notebooks)

(defun create-user-notebook! (&key title body-md cells slug summary
                                   (status "draft") published-at author id)
  (let ((id (or id (generate-uuid)))
        (slug (or slug (slugify title))))
    (insert-dao
     (make-instance 'user-notebook
                    :id id :slug slug :title title :summary summary
                    :body-md body-md :cells cells
                    :status status :published-at published-at :author author))))

(defun get-user-notebook-by-id (id)
  (find-dao 'user-notebook :id (ensure-uuid id)))

(defun get-user-notebook-by-slug (slug)
  (find-dao 'user-notebook :slug slug))
```

(`generate-uuid` `ensure-uuid` `slugify` は既存の `recurya/db/posts` から再利用。エクスポート確認、未エクスポートなら `slugify` のみ移すなど整理 — 既存post実装が `generate-uuid` `ensure-uuid` を内部に持つ場合は、`recurya/db/core` か新規 `recurya/db/util-uuid` 等に切り出して両者で使う。)

**Step 5: テスト成功 → コミット**

---

### Task 13: db CRUD - update / delete

**Files:** 同上。

**Step 1: テスト追加** — `update-user-notebook!`（部分更新でcells JSONB更新）、`delete-user-notebook!`、削除後 `get` が nil 等。

**Step 2-5: 失敗 → 実装 → 成功 → コミット**

実装は `recurya/db/posts:update-post!` を参照しつつ翻案。

---

### Task 14: db CRUD - list / count

**Files:** 同上。

**Step 1: テスト追加** — status filter / author-id filter / limit-offset / count.

**Step 2-5: 失敗 → 実装 → 成功 → コミット**

実装は `recurya/db/posts:list-posts` `count-posts` を参照。

---

### Task 15: cells JSONB往復テスト

**Files:** `tests/db/user-notebooks.lisp`

**Step 1: テスト**

```lisp
(deftest cells-jsonb-roundtrip
  (with-test-db
    (let* ((cells '((:cell-id "abc" :kind "prose" :body-md "x")
                    (:cell-id "def" :kind "code-eval" :body "(+ 1 2)")))
           (u  (make-test-user))
           (nb (create-user-notebook! :title "x" :body-md "..." :cells cells :author u))
           (out (user-notebook-cells (get-user-notebook-by-id (user-notebook-id nb)))))
      (ok (= (length cells) (length out))))))
```

**Step 2-5:** Mitoの `(:col-type :jsonb)` と `recurya/db/jsonb` のシリアライズ層が plist of list と PostgreSQL JSONB を往復できることを確認。失敗するならシリアライザ側の調整。

---

## Phase 3: ID型緩和

### Task 16: notebook/cell defstructのid型を緩和

**Files:**
- Modify: `/home/wiz/recurya/game/notebook.lisp`

**Step 1: 修正前にSICPテストの基準パスを取得**

```
mcp__cl-mcp__run-tests system="recurya/tests/game/notebook"
```

期待: 全PASS（基準値）。

**Step 2: 型緩和**

`lisp-patch-form` で:
```
form_type: defstruct, form_name: notebook
old_text: (id nil :type keyword)
new_text: (id nil :type (or null keyword string))
```

cellも同様。

**Step 3: 影響範囲確認**

`run-cell` 内で `(notebook-id notebook)` がkeyword前提でないか確認:

```
clgrep-search pattern="notebook-id" form_types=["defun"]
```

`symbol-name` を使っている箇所 — keywordなら `(symbol-name :foo)` で `"FOO"`、stringならもう文字列。`(princ-to-string ...)` か `(string ...)` の方が両対応。`run-cell` 関連と `learn_*` テーブル書込み箇所の文字列化を `(string ...)` または `(princ-to-string ...)` に揃える。`(string :foo)` は `"FOO"`、`(string "foo")` は `"foo"` を返す（CL仕様）。

**Step 4: SICPテスト全PASS確認**

```
mcp__cl-mcp__run-tests system="recurya/tests/game/notebook"
```
+ 1サンプル: `recurya/tests/game/notebooks/sicp-1-1-1`

期待: 全PASS。

**Step 5: コミット**

```bash
git commit -am "refactor: relax notebook/cell id type to accept strings (UUIDs)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 4: 管理UI（admin）

### Task 17: フォームUI（new/edit）

**Files:**
- Create: `/home/wiz/recurya/web/ui/user-notebook-form.lisp`
- Modify: `recurya.asd`

**Step 1: `web/ui/post-form.lisp` を読む** で構造を把握、それを翻案。

**Step 2: 実装**

`render` 関数 keyword引数: `:user :notebook :message :errors`。
- title / slug / summary input
- body textarea (min-height 600px, monospace, line-wrap=on)
- status select
- 区切り記号チートシート（フォーム下部）
- バリデーションエラー（`errors` に `(:line N :message "...")` のlist）を行番号付きで表示

**Step 3: コンパイル確認** （テストは Task 19 でハンドラと一緒に書く）

```lisp
(asdf:load-system :recurya/web/ui/user-notebook-form :force t)
```

**Step 4: コミット**

---

### Task 18: 一覧UI（管理側 `/notebooks/me`）

**Files:**
- Create: `/home/wiz/recurya/web/ui/user-notebooks.lisp`
- Modify: `recurya.asd`

**Step 1: `web/ui/posts.lisp` をベースに翻案**

`render` keyword引数: `:user :notebooks :pagination :message :errors`。

テーブル列: Title / Status pill / Published / Created / Actions (Edit, Delete)。HTMX削除モーダル。

**Step 2: コンパイル確認**

**Step 3: コミット**

---

### Task 19: ハンドラ — new / create / edit / update + ルート登録

**Files:**
- Modify: `/home/wiz/recurya/web/routes.lisp`
- Create: `/home/wiz/recurya/tests/web/user-notebook-routes.lisp`
- Modify: `recurya.asd`、`tests/all.lisp`

**Step 1: 統合テスト**

```lisp
(deftest user-notebook-create-and-list
  (with-test-app
    (with-logged-in-user (u)
      (let* ((res (POST "/notebooks"
                        :title "My NB" :body "===prose===\nHi" :status "draft")))
        (ok (redirect-to-p res "/notebooks/me")))
      (let ((res (GET "/notebooks/me")))
        (ok (search "My NB" (response-body res)))))))
```

`with-test-app` `with-logged-in-user` は `tests/web/routes.lisp` の既存ヘルパを参考に必要なら追加。

**Step 2-3: 失敗確認 → 実装**

`web/routes.lisp` に以下を `lisp-edit-form insert_after` で `post-update-handler` の直後に追加:
- `user-notebooks-handler` (GET /notebooks/me)
- `user-notebook-new-handler` (GET /notebooks/new)
- `user-notebook-create-handler` (POST /notebooks)
- `user-notebook-edit-handler` (GET /notebooks/:id/edit)
- `user-notebook-update-handler` (POST /notebooks/:id)

各ハンドラは既存の post-* に対応。`create-user-notebook!` 内で `parse-notebook-body` を呼んで cells を組み立て、エラーがあればフォーム再表示。

`setup-routes` 内でルート登録を追加。

**Step 4: テスト全PASS**

**Step 5: コミット**

---

### Task 20: HTMX toggle-status

**Files:** 同上。

**Step 1: テスト追加** — published/draft切替で `published_at` がセット/維持される、非ownerは403。

**Step 2-5: 失敗 → 実装 → 成功 → コミット**

`user-notebook-toggle-status-handler` を post の `post-toggle-status-handler` をベースに実装。`render-status-pill` 相当を user-notebook 用に追加または共通化。

---

### Task 21: HTMX delete + confirm-delete

**Files:** 同上。

**Step 1-5:** 上記同様。post の `post-confirm-delete-handler` `post-delete-handler` を翻案。`render-confirm-modal` は既存のものを再利用可。

---

## Phase 5: 公開ページ

### Task 22: 公開一覧UI + `/notebooks` ルート

**Files:**
- Create: `/home/wiz/recurya/web/ui/notebook-list.lisp`
- Modify: `web/routes.lisp`、`recurya.asd`、`tests/web/user-notebook-routes.lisp`

**Step 1: テスト** — `/notebooks` がpublishedのみ返す、未ログインでも200。

**Step 2-5:** `web/ui/blog.lisp` ベースに翻案。

---

### Task 23: notebook render に :sidebar-notebooks 引数追加

**Files:**
- Modify: `/home/wiz/recurya/web/ui/notebook.lisp`

**Step 1: 既存呼び出し箇所を把握**

```
clgrep-search pattern="recurya/web/ui/notebook:render"
```

**Step 2: render関数 keyword引数追加**

```
&key user saved-codes passed-cells
       (sidebar-notebooks (recurya/game/notebooks/registry:all-notebooks))
```

`nil` を渡されたらサイドバーを描画しない条件分岐を `render` 内 / `render-sidebar` 呼び出し直前に追加。

**Step 3: SICP既存呼び出しが暗黙にデフォルト値を使うことを確認**

`web/routes-wardlisp.lisp` の SICP notebook handler を読み、引数追加が破壊的でないことを確認。

**Step 4: SICPテスト全PASS確認**

**Step 5: コミット**

---

### Task 24: `/n/:slug` 公開単体ハンドラ

**Files:**
- Modify: `web/routes.lisp`、`tests/web/user-notebook-routes.lisp`

**Step 1: テスト** — published のみ返す、draftは他人404、ownerは200、未ログインでも閲覧可。

**Step 2-5: 失敗 → 実装**

```lisp
(defun public-notebook-handler (params)
  (let* ((slug (get-path-param params :slug))
         (nb-row (get-user-notebook-by-slug slug)))
    (cond
      ((null nb-row)
       (html-response (recurya/web/ui/errors:not-found) :status 404))
      ((and (string= "draft" (user-notebook-status nb-row))
            (not (owner-p nb-row (get-current-user))))
       (html-response (recurya/web/ui/errors:not-found) :status 404))
      (t
       (let* ((notebook  (user-notebook-row->notebook-struct nb-row))
              (user      (get-current-user))
              (saved     (when user (load-saved-codes user (user-notebook-id nb-row))))
              (passed    (when user (load-passed-cells user (user-notebook-id nb-row)))))
         (html-response
          (recurya/web/ui/notebook:render
           notebook :user user :saved-codes saved :passed-cells passed
           :sidebar-notebooks nil)))))))
```

`user-notebook-row->notebook-struct` は cells JSONB → `defstruct cell` のリストに変換するヘルパ。

**Step 5: コミット**

---

### Task 25: `/n/:slug/run-cell` + 学習進捗連動

**Files:**
- Modify: `web/routes.lisp`、`tests/web/user-notebook-routes.lisp`

**Step 1: テスト**

公開NBでcellを実行 → `learn_cell_code` 保存・`learn_progress` 保存（exercise成功時）。
未ログインで実行 → 200だが保存スキップ。

**Step 2-5:** 既存SICPの run-cell ハンドラ（`web/routes-wardlisp.lisp` の対応関数）を翻案。`notebook-id` には UUID文字列を渡す。`learn_*` テーブルAPIはそのまま使える。

---

## Phase 6: 仕上げ

### Task 26: ヘッダーリンク追加

**Files:** `/home/wiz/recurya/web/ui/layout.lisp`

**Step 1-5:** `header` 関数内に `Notebooks` (公開一覧へ) を追加。ログイン時のみ `My Notebooks` を追加。Spinneret DSLで条件分岐は既存パターンを踏襲。

---

### Task 27: 全テスト通し + 手動スモークテスト

**Files:** なし（検証のみ）。

**Step 1: 全テスト実行**

```
mcp__cl-mcp__run-tests system="recurya/tests"
```

期待: 全PASS。

**Step 2: コンテナでブラウザフロー手動確認**

1. `/login` でログイン
2. `/notebooks/me` でEmpty状態確認
3. `/notebooks/new` で簡単なNB作成（prose/eval/exerciseを各1つ）→ 保存
4. `/notebooks/me` で1件表示・statusトグル → published
5. `/notebooks` 公開一覧に出る
6. `/n/:slug` で開いてcell実行（eval, exercise成功）
7. ログアウト → `/notebooks` で見える、`/n/:slug` で実行できる、保存はスキップ
8. 別ユーザーログイン → `/notebooks` で見える、`/n/:slug` で実行 → 進捗保存
9. 元の作者でログインし、cellを並び替え（Markdown編集）→ 別ユーザーの保存コードが残ることを確認

**Step 3: SICP既存フロー回帰確認**

`/learn` から既存SICPノートブックを開いて1つcellを実行 → 動作確認。サイドバーTOCが表示される。

**Step 4: コミット**

なくても良い（テストや手動検証のみ）。問題があればここで修正タスクを差し込む。

---

## 完了基準

- [ ] 全テスト（既存+新規）PASS
- [ ] 手動スモークテスト9項目PASS
- [ ] SICP既存56テスト全PASS
- [ ] PR作成可能な状態（feature branch）

## 注意事項

- **Lispファイルの編集は cl-mcp ツールのみ**。Read/Edit/Write/Grep/Globは `.lisp`/`.asd` に使わない
- 各タスク冒頭で `fs-set-project-root path=/home/wiz/recurya` を呼ぶ
- DBテストは PostgreSQL (`localhost:15434`) が稼働している前提
- Mito CLI実行は **コンテナ内**で。直接 `.qlot/bin/mito` を `localhost:15434` 向けに実行する場合は `-H localhost -P 15434` で
- HTMXの実装で迷ったら既存 `web/routes.lisp` の `post-toggle-status-handler` `post-delete-handler` を参照
- パッケージ間 import で `slugify` 等を再利用する場合は、既存の export を確認。していなければ exportを追加するパッチをそのファイルに当てる
- Plump APIの正確な関数名は実装中に `clhs-lookup` や Plump ソース（`~/.qlot/dists/quicklisp/software/plump-*/`）参照
