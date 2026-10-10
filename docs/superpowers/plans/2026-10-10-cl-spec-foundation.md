# cl-spec 基盤 + ドメイン契約 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** cl-spec の契約 (値域 Spec / Function Spec / Property) を `specs/` に置き、Rove から全契約を実行して CI で回帰を捕まえる基盤を作り、arena と notebook パーサのドメイン契約を載せる。

**Architecture:** 契約は本番 `recurya` が依存しない package-inferred サブシステム `recurya/specs/...` に置く。`recurya/tests/specs/contracts` (Rove) が `recurya/specs/all` をロードし、`RECURYA/` 配下の Function Spec と `RECURYA/SPECS/` 配下の Property を全件実行する。非公開関数は `defpackage` の `:import-from` で参照する (`::` も API 変更も不要)。

**Tech Stack:** SBCL, ASDF package-inferred-system, cl-spec (`cl-spec/check-it`), Rove, cl-mcp ツール。

**Spec:** `docs/superpowers/specs/2026-10-10-cl-spec-foundation-design.md`

## Global Constraints

- `.lisp` / `.asd` の読み書きは cl-mcp ツールのみ (`lisp-read-file`, `lisp-edit-form`, `lisp-patch-form`, 新規は `fs-write-file`)。シェルで Lisp ファイルを触らない。シェルは `git` / `mallet` のみ。
- 本番システム `recurya` の `:depends-on` に cl-spec を入れない。契約は `specs/` 配下だけ。
- 期待値は docstring・既存テスト・要件から導く。実装をコピーしない。
- 反例が出たら契約を弱めて緑にしない。実装バグか契約の誤りかを切り分けてユーザーに報告する。
- 実行開始時に `pool-kill-worker reset=true` でワーカーを作り直す (計画作成時の試作 `PROTO` / `PROTO-NB` パッケージが同じ関数名で Function Spec を登録済みのため)。
- テスト実行は `run-tests` ツール。ロードは `load-system`。
- コミットメッセージ末尾: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- cl-mcp / cl-spec 利用中に摩擦・不具合・改善案に遭遇したら、その都度 `docs/feedback/cl-mcp-cl-spec.md` に追記する (Task 1 で作成)。

## File Structure

| ファイル | 責務 |
|---|---|
| `docs/feedback/cl-mcp-cl-spec.md` (新規) | cl-mcp + cl-spec のフィードバック蓄積 (git 管理) |
| `CLAUDE.md` (変更) | 「cl-mcp Feedback」節の追記先を上記に変更 |
| `specs/domain.lisp` (新規) | 共有値域: `arena-action`, `grid-position`, `notebook-cell-kind`, `fence-kind` |
| `specs/game/arena.lisp` (新規) | arena の生成器・Function Spec・Property |
| `specs/game/notebook.lisp` (新規) | notebook セル / test-case の生成器 (正規形・非正規形) と比較用ビュー |
| `specs/game/notebook-parser.lisp` (新規) | パーサの Function Spec と往復 Property |
| `specs/all.lisp` (新規) | 全契約ファイルを `:import-from` する傘 |
| `tests/specs/contracts.lisp` (新規) | Rove ハーネス |
| `recurya.asd` (変更) | `recurya/tests` に `"cl-spec/check-it"` と `"recurya/tests/specs/contracts"` |
| `tests/all.lisp` (変更) | `*test-packages*` に `:recurya/tests/specs/contracts` |
| `.github/workflows/lint.yml` (変更) | mallet 対象に `specs/*.lisp specs/*/*.lisp` |
| `game/notebook-parser.lisp` (変更) | `cells->body-md` の docstring を実態 (正規形) に合わせる |

---

### Task 1: フィードバックファイル

**Files:**
- Create: `docs/feedback/cl-mcp-cl-spec.md`
- Modify: `CLAUDE.md` (「## cl-mcp Feedback」節)

**Interfaces:**
- Produces: 以降の全タスクが追記するファイル `docs/feedback/cl-mcp-cl-spec.md` とそのエントリ書式。

- [ ] **Step 1: フィードバックファイルを作成**

`docs/feedback/cl-mcp-cl-spec.md`:

```markdown
# cl-mcp + cl-spec フィードバックログ

Recurya で cl-mcp (Common Lisp MCP サーバ) と cl-spec (契約/プロパティテスト) を
使った AI エージェント開発で遭遇した不具合・摩擦・改善案を蓄積する。
上流 (cl-ai-project/cl-mcp, masatoi/cl-spec) への報告材料にする。

## 書式

新しいエントリは末尾に追記する。既存エントリは書き換えない (解決したら
「解決:」行を足す)。

    ## YYYY-MM-DD — <短い題>
    - **ツール/対象**: cl-mcp `<tool>` / cl-spec `<API>` / qlot など
    - **分類**: bug | UX | docs | idea
    - **状況**: 何をしようとしていたか
    - **起きたこと**: 実際の挙動 (エラーメッセージは短く原文で)
    - **期待**: どうあってほしいか
    - **回避策**: その場でどう凌いだか (なければ「なし」)

---

## 2026-10-10 — cl-spec/check-it の依存が qlot で自動導入されない
- **ツール/対象**: qlot / cl-mcp `load-system` / cl-spec `cl-spec/check-it`
- **分類**: docs
- **状況**: qlfile に `git cl-spec ...` を追加し、`MCP_ENABLE_TOOL_GROUPS=cl-spec` で spec-* ツールを有効化した直後に `load-system cl-spec/check-it`。
- **起きたこと**: `Component "check-it" not found`。qlfile に `ql check-it :latest` を足して `qlot install` しても、次は `Component :OPTIMA not found`。`load-system` は ASDF のみで Quicklisp の自動取得をしないため、推移依存が入っていないと止まる。
- **期待**: cl-mcp README の cl-spec 節か cl-spec の README に「qlot 環境では check-it (と optima 等) を事前に入れる必要がある」旨、または `cl-spec-not-loaded` 応答に依存導入の手順ヒント。
- **回避策**: ワーカーで `(ql:quickload "cl-spec/check-it")` を 1 回実行 (依存を .qlot にダウンロード)。恒久策としてテストシステムの `:depends-on` に `"cl-spec/check-it"` を明記。

## 2026-10-10 — HTTP 直叩きで initialize 直後の tools/list が Session expired
- **ツール/対象**: cl-mcp HTTP transport (`/mcp`)
- **分類**: UX
- **状況**: コンテナ再作成後、curl で `initialize` → `notifications/initialized` → `tools/list` を送り、cl-spec ツールが列挙されるか確認しようとした。
- **起きたこと**: `initialize` は 200 + `Mcp-Session-Id` を返すが、同じ ID での後続リクエストが `{"code":-32600,"message":"Session expired or invalid"}` (404)。原因未特定 (singleton ワーカーモードとの関係か、ヘッダ要件か)。
- **期待**: 無効と判断した理由がエラーメッセージに出ること (未知 ID / 期限切れ / プロトコルヘッダ不足 などの区別)。
- **回避策**: Claude Code から `/mcp` で再接続して確認。
```

- [ ] **Step 2: CLAUDE.md の「cl-mcp Feedback」節を書き換え**

`CLAUDE.md` の既存節:

```markdown
## cl-mcp Feedback

When you encounter issues, friction, or improvement ideas while using cl-mcp (Common Lisp MCP server), append them to `~/.claude/memory/cl-mcp-feedback.md`. Each entry should include date, context, and specific details. If the file already exists, always append to the end rather than overwriting.
```

を次で置き換える (Edit ツール。CLAUDE.md は Lisp ファイルではない):

```markdown
## cl-mcp / cl-spec Feedback

When you encounter issues, friction, or improvement ideas while using cl-mcp (Common Lisp MCP server) or cl-spec (contracts / property testing), append an entry to `docs/feedback/cl-mcp-cl-spec.md` (git-managed; follow the entry format at the top of that file). Always append to the end; never rewrite existing entries. Commit the entry together with the work that surfaced it. The older cross-project log `~/.claude/memory/cl-mcp-feedback.md` is an archive and is no longer appended to from this project.
```

- [ ] **Step 3: コミット**

```bash
git add docs/feedback/cl-mcp-cl-spec.md CLAUDE.md
git commit -m "docs: add git-managed cl-mcp/cl-spec feedback log

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: 値域 Spec と Rove ハーネス

**Files:**
- Create: `specs/domain.lisp`, `specs/all.lisp`, `tests/specs/contracts.lisp`
- Modify: `recurya.asd` (`recurya/tests` の `:depends-on`), `tests/all.lisp` (`*test-packages*`), `.github/workflows/lint.yml`

**Interfaces:**
- Produces (`recurya/specs/domain`, exported): spec `arena-action`, spec + generator `grid-position`, predicate `(grid-position-p value) → boolean`, spec `notebook-cell-kind`, spec `fence-kind`。
- Produces (`recurya/tests/specs/contracts`): 変数 `*expected-specs*`, `*expected-properties*`, `*expected-function-specs*` — 各要素は `("PACKAGE-NAME" . "SYMBOL-NAME")` (大文字)。後続タスクはここに追記してから契約を書く (TDD)。
- Produces: `specs/all.lisp` の `defpackage` に後続タスクが `(:import-from #:recurya/specs/game/...)` を足す。

- [ ] **Step 0: ワーカーを作り直す**

`pool-kill-worker` `{"reset": true}` → `load-system` `{"system": "cl-spec/check-it", "force": false}`。
失敗した場合 (`check-it`/`optima` 不在) は `repl-eval` `(ql:quickload "cl-spec/check-it" :silent t)` を 1 回実行してから再度 `load-system`。

- [ ] **Step 1: 失敗するハーネスを書く**

`fs-write-file` で `tests/specs/contracts.lisp`:

```lisp
;;;; tests/specs/contracts.lisp --- Run every project cl-spec contract under Rove.
;;;;
;;;; Loads RECURYA/SPECS/ALL, checks that the expected specs, properties and
;;;; function specs are registered, then runs each one: properties with the
;;;; :SMOKE profile, function specs with *FUNCTION-SPEC-TRIALS* trials.  A run
;;;; that never exercised its target (zero trials, or every input refused by
;;;; :PRE) fails: :SKIPPED is not :PASSED.  A failure message carries the name,
;;;; status, seed and counterexample so `spec-check' can replay it.

(defpackage #:recurya/tests/specs/contracts
  (:use #:cl #:rove)
  (:import-from #:recurya/specs/all)
  (:import-from #:cl-spec/main
                #:list-specs
                #:list-properties
                #:list-function-specs
                #:run-property
                #:check-function
                #:property-result-status
                #:property-result-trials
                #:property-result-seed
                #:property-result-counterexample
                #:function-check-result-rejected))
(in-package #:recurya/tests/specs/contracts)

(defparameter *function-spec-trials* 50
  "Trials per function spec when run under Rove.")

(defparameter *expected-specs*
  '(("RECURYA/SPECS/DOMAIN" . "ARENA-ACTION")
    ("RECURYA/SPECS/DOMAIN" . "GRID-POSITION")
    ("RECURYA/SPECS/DOMAIN" . "NOTEBOOK-CELL-KIND")
    ("RECURYA/SPECS/DOMAIN" . "FENCE-KIND"))
  "Named data specs that must be registered, as (PACKAGE . SYMBOL) names.")

(defparameter *expected-properties* '()
  "Properties that must be registered, as (PACKAGE . SYMBOL) names.")

(defparameter *expected-function-specs* '()
  "Function specs that must be registered, named by their target function.")

(defun resolve-name (entry)
  "Return the symbol named by ENTRY, a (PACKAGE-NAME . SYMBOL-NAME) pair, or NIL."
  (let ((package (find-package (car entry))))
    (and package (find-symbol (cdr entry) package))))

(defun home-package-prefix-p (symbol prefix)
  "True when SYMBOL's home package name starts with PREFIX."
  (let ((package (symbol-package symbol)))
    (and package
         (alexandria:starts-with-subseq prefix (package-name package)))))

(defun project-properties ()
  "Registered properties defined in a RECURYA/SPECS/ package."
  (remove-if-not (lambda (name) (home-package-prefix-p name "RECURYA/SPECS/"))
                 (list-properties)))

(defun project-function-specs ()
  "Registered function specs whose target lives in a RECURYA/ package."
  (remove-if-not (lambda (name) (home-package-prefix-p name "RECURYA/"))
                 (list-function-specs)))

(defun failure-report (name result)
  "Describe RESULT of checking NAME so the run can be replayed with spec-check."
  (format nil "~S: status=~S trials=~S seed=~A counterexample=~S"
          name
          (property-result-status result)
          (property-result-trials result)
          (property-result-seed result)
          (property-result-counterexample result)))

(defun property-passes-p (name)
  "Run property NAME at the :SMOKE profile.
Return (VALUES PASSED-P RESULT); PASSED-P needs :PASSED and at least one trial."
  (let ((result (run-property name :profile :smoke)))
    (values (and (eq (property-result-status result) :passed)
                 (plusp (property-result-trials result)))
            result)))

(defun function-spec-passes-p (name)
  "Check the function spec of NAME with *FUNCTION-SPEC-TRIALS* trials.
Return (VALUES PASSED-P RESULT); PASSED-P needs :PASSED and at least one trial
that :PRE admitted."
  (let* ((result (check-function name :trials *function-spec-trials*))
         (rejected (or (function-check-result-rejected result) 0)))
    (values (and (eq (property-result-status result) :passed)
                 (plusp (- (property-result-trials result) rejected)))
            result)))

(defun registered-p (entry registered)
  "True when ENTRY resolves to a symbol present in the REGISTERED name list."
  (let ((symbol (resolve-name entry)))
    (and symbol (member symbol registered) t)))

(deftest expected-contracts-registered
  (testing "named data specs"
    (let ((registered (list-specs)))
      (dolist (entry *expected-specs*)
        (ok (registered-p entry registered)
            (format nil "spec ~A::~A is registered" (car entry) (cdr entry))))))
  (testing "properties"
    (let ((registered (list-properties)))
      (dolist (entry *expected-properties*)
        (ok (registered-p entry registered)
            (format nil "property ~A::~A is registered" (car entry) (cdr entry))))))
  (testing "function specs"
    (let ((registered (list-function-specs)))
      (dolist (entry *expected-function-specs*)
        (ok (registered-p entry registered)
            (format nil "function spec ~A::~A is registered" (car entry) (cdr entry)))))))

(deftest project-properties-pass
  (dolist (name (project-properties))
    (multiple-value-bind (passed-p result) (property-passes-p name)
      (ok passed-p (failure-report name result)))))

(deftest project-function-specs-pass
  (dolist (name (project-function-specs))
    (multiple-value-bind (passed-p result) (function-spec-passes-p name)
      (ok passed-p (failure-report name result)))))
```

`fs-write-file` で `specs/all.lisp` (まだ何も import しない):

```lisp
;;;; specs/all.lisp --- Load every Recurya cl-spec contract file.
;;;;
;;;; An umbrella with no code of its own: each :IMPORT-FROM pulls in one
;;;; contract file so `load-system recurya/specs/all' registers them all.
;;;; The production system never depends on this.

(defpackage #:recurya/specs/all
  (:use #:cl))
(in-package #:recurya/specs/all)
```

`lisp-check-parens` を両ファイルに実行。

- [ ] **Step 2: 失敗を確認**

`load-system` `{"system": "recurya/tests/specs/contracts"}` → `run-tests` `{"system": "recurya/tests/specs/contracts"}`。
Expected: `expected-contracts-registered` の 4 件が FAIL (`RECURYA/SPECS/DOMAIN` パッケージが無く `resolve-name` が NIL)。

- [ ] **Step 3: 値域 Spec を実装**

`fs-write-file` で `specs/domain.lisp`:

```lisp
;;;; specs/domain.lisp --- Shared cl-spec value domains for Recurya contracts.
;;;;
;;;; Named specs reused across contract files.  Each enumeration is taken from
;;;; the docstring or dispatch table cited beside it, never guessed.  Not
;;;; loaded by the production system.

(defpackage #:recurya/specs/domain
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defgenerator)
  ;; A bare :import-from declares the check-it backend as an ASDF dependency.
  (:import-from #:cl-spec/src/backends/check-it)
  (:export #:arena-action
           #:grid-position
           #:grid-position-p
           #:notebook-cell-kind
           #:fence-kind))
(in-package #:recurya/specs/domain)

;;; Arena

;; recurya/game/arena:*valid-action-strings*, mapped to keywords by PARSE-ACTION.
(defspec arena-action
  (member :up :down :left :right :wait :pickup))

(defun grid-position-p (value)
  "True when VALUE is a (ROW . COL) cons of non-negative integers."
  (and (consp value)
       (typep (car value) '(integer 0))
       (typep (cdr value) '(integer 0))))

(defgenerator grid-position ()
  "A position on a board of at most 20x20 cells."
  (cons (random 20) (random 20)))

(defspec grid-position
  (satisfies grid-position-p)
  (:generator grid-position))

;;; Notebook

;; Docstring of recurya/game/notebook:cell and the ECASE in RENDER-CELL.
(defspec notebook-cell-kind
  (member :prose :code-eval :code-exercise :code-solution :scene))

;; Docstring of PARSE-FENCE-HEADER: cell kinds plus the two sentinel kinds that
;; the parser's state machine consumes without storing a cell.
(defspec fence-kind
  (or notebook-cell-kind (member :code-delim :expect)))
```

`lisp-check-parens` `{"path": "specs/domain.lisp"}`。

`lisp-edit-form` で `specs/all.lisp` の `defpackage` (form_name `recurya/specs/all`) を置換:

```lisp
(defpackage #:recurya/specs/all
  (:use #:cl)
  (:import-from #:recurya/specs/domain))
```

- [ ] **Step 4: 配線**

`lisp-patch-form` で `recurya.asd` の `defsystem` `"recurya/tests"`:
- old_text: `               "clack-test"\n               ;; Test support modules`
- new_text: `               "clack-test"\n               "cl-spec/check-it"\n               ;; Test support modules`

もう 1 回 `lisp-patch-form`:
- old_text: `               ;; WardLisp integration tests`
- new_text: `               ;; cl-spec contracts (specs/)\n               "recurya/tests/specs/contracts"\n               ;; WardLisp integration tests`

`lisp-read-file` `tests/all.lisp` `name_pattern="^\*test-packages\*$"` で現在のリストを読み、`lisp-patch-form` で `:recurya/tests/game/notebook-parser` の行の直後に `:recurya/tests/specs/contracts` を 1 行追加 (同じインデント)。

`.github/workflows/lint.yml` (Edit ツール):
- old: `            tests/*/*.lisp tests/*/*/*.lisp \`
- new: `            specs/*.lisp specs/*/*.lisp \` の行を `tests/*/*.lisp ...` の行の直前に追加。

- [ ] **Step 5: 緑を確認**

`load-system` `{"system": "recurya/tests/specs/contracts"}` → `run-tests` `{"system": "recurya/tests/specs/contracts"}`。
Expected: `expected-contracts-registered` 4 件 PASS。`project-*-pass` は対象 0 件 (ワーカー再作成済みなので試作の登録は無い)。

- [ ] **Step 6: lint**

```bash
mallet specs/*.lisp tests/specs/*.lisp
```
Expected: `No problems found`。警告があれば `lisp-patch-form` で修正。

- [ ] **Step 7: コミット**

```bash
git add specs/domain.lisp specs/all.lisp tests/specs/contracts.lisp recurya.asd tests/all.lisp .github/workflows/lint.yml
git commit -m "feat(specs): add cl-spec value domains and Rove contract harness

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: arena の契約

**Files:**
- Create: `specs/game/arena.lisp`
- Modify: `specs/all.lisp`, `tests/specs/contracts.lisp` (期待リスト)

**Interfaces:**
- Consumes: `recurya/specs/domain` の `arena-action`, `grid-position`, `grid-position-p`。ハーネスの `*expected-properties*` / `*expected-function-specs*`。
- Produces: Function Spec `parse-action`, `action->delta`, `apply-move` (すべて `RECURYA/GAME/ARENA` のシンボル)、Property `recurya/specs/game/arena::manhattan-distance-metric`, `copy-grid-independent`。

- [ ] **Step 1: 期待リストに追加 (失敗するテスト)**

`lisp-edit-form` で `tests/specs/contracts.lisp` の `defparameter` `*expected-properties*` を置換:

```lisp
(defparameter *expected-properties*
  '(("RECURYA/SPECS/GAME/ARENA" . "MANHATTAN-DISTANCE-METRIC")
    ("RECURYA/SPECS/GAME/ARENA" . "COPY-GRID-INDEPENDENT"))
  "Properties that must be registered, as (PACKAGE . SYMBOL) names.")
```

`defparameter` `*expected-function-specs*` を置換:

```lisp
(defparameter *expected-function-specs*
  '(("RECURYA/GAME/ARENA" . "PARSE-ACTION")
    ("RECURYA/GAME/ARENA" . "ACTION->DELTA")
    ("RECURYA/GAME/ARENA" . "APPLY-MOVE"))
  "Function specs that must be registered, named by their target function.")
```

- [ ] **Step 2: 失敗を確認**

`run-tests` `{"system": "recurya/tests/specs/contracts"}`。Expected: 新規 5 件が FAIL (未登録)。

- [ ] **Step 3: arena の契約を実装**

`fs-write-file` で `specs/game/arena.lisp`:

```lisp
;;;; specs/game/arena.lisp --- cl-spec contracts for the arena engine.
;;;;
;;;; Function specs for action parsing and movement, and properties of the
;;;; grid helpers.  Expected behaviour comes from the docstrings of
;;;; recurya/game/arena.  Internal helpers are imported, not reached with ::.

(defpackage #:recurya/specs/game/arena
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defspec-function
                #:defproperty
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:alexandria
                #:copy-array)
  (:import-from #:recurya/specs/domain
                #:arena-action
                #:grid-position
                #:grid-position-p)
  (:import-from #:recurya/game/arena
                #:make-grid
                #:grid-set!
                ;; Internal helpers under contract.
                #:*valid-action-strings*
                #:parse-action
                #:action->delta
                #:apply-move
                #:wall-p
                #:manhattan-distance
                #:copy-grid))
(in-package #:recurya/specs/game/arena)

;;; Helpers

(defun random-element (sequence)
  "Return a uniformly chosen element of the non-empty SEQUENCE."
  (elt sequence (random (length sequence))))

(defun random-mixed-case (string)
  "Return STRING with each character's case chosen at random."
  (map 'string
       (lambda (char)
         (if (zerop (random 2)) (char-upcase char) (char-downcase char)))
       string))

(defun valid-action-name-p (value)
  "True when VALUE is a string naming an action, ignoring case."
  (and (stringp value)
       (find value *valid-action-strings* :test #'string-equal)
       t))

(defun random-arena-grid ()
  "A fresh grid of 1..6 x 1..6 cells, about 30% of them walls."
  (let* ((rows (1+ (random 6)))
         (cols (1+ (random 6)))
         (grid (make-grid rows cols)))
    (dotimes (row rows grid)
      (dotimes (col cols)
        (when (< (random 10) 3)
          (grid-set! grid row col :wall))))))

(defun open-positions (grid)
  "Every in-bounds, non-wall (ROW . COL) of GRID."
  (let ((positions '()))
    (dotimes (row (array-dimension grid 0) positions)
      (dotimes (col (array-dimension grid 1))
        (unless (wall-p grid row col)
          (push (cons row col) positions))))))

(defun step-target (pos action)
  "The (ROW . COL) one ACTION step from POS, or NIL for a non-movement action."
  (let ((delta (action->delta action)))
    (and delta
         (cons (+ (car pos) (car delta)) (+ (cdr pos) (cdr delta))))))

(defun blocked-p (grid pos action)
  "True when ACTION from POS moves nowhere: a non-movement action, or a step
into a wall or off the board (APPLY-MOVE's docstring)."
  (let ((target (step-target pos action)))
    (or (null target)
        (wall-p grid (car target) (cdr target)))))

;;; Generators

(defgenerator action-input ()
  "A value WardLisp could hand PARSE-ACTION: action names in any case (about
40%), near-miss strings, and non-strings."
  (case (random 5)
    ((0 1) (random-mixed-case (random-element *valid-action-strings*)))
    (2 (random-element '("" "jump" "UPP" "wai" " up" "pick-up")))
    (3 (random-element '(nil 0 42 :up up)))
    (t (random-element '(#\u 1.5 ("up"))))))

(defspec action-input t (:generator action-input))

(defgenerator arena-grid ()
  "A fresh random grid per draw."
  (random-arena-grid))

(defspec arena-grid (satisfies arrayp) (:generator arena-grid))

(defgenerator apply-move-arguments ()
  "(GRID POS ACTION) with a fresh grid and POS on one of its open cells."
  (loop
    (let* ((grid (random-arena-grid))
           (open (open-positions grid)))
      (when open
        (return (list grid
                      (random-element open)
                      (random-element '(:up :down :left :right :wait :pickup))))))))

;;; Function specs

(defspec-function parse-action
  "A string naming an action (any case) becomes that action's keyword;
anything else becomes :WAIT."
  (:args (value action-input))
  (:cases
    (:action-name
      (:when (valid-action-name-p value))
      (:returns arena-action)
      (:post (string-equal (symbol-name result) value)))
    (:anything-else
      (:when (not (valid-action-name-p value)))
      (:returns (member :wait)))))

(defspec-function action->delta
  "Movement actions map to a one-cell step (DROW . DCOL); others to NIL."
  (:args (action arena-action))
  (:cases
    (:movement
      (:when (member action '(:up :down :left :right)))
      (:returns (satisfies consp))
      (:post (= 1 (+ (abs (car result)) (abs (cdr result))))))
    (:non-movement
      (:when (member action '(:wait :pickup)))
      (:returns null))))

(defspec-function apply-move
  "From an open cell, a move lands on the open in-bounds cell one step away;
a blocked move or a non-movement action leaves the position unchanged."
  (:args (grid arena-grid) (pos grid-position) (action arena-action))
  (:args-generator apply-move-arguments)
  (:pre (not (wall-p grid (car pos) (cdr pos))))
  (:cases
    (:moves
      (:when (not (blocked-p grid pos action)))
      (:returns grid-position)
      (:post (and (equal result (step-target pos action))
                  (not (wall-p grid (car result) (cdr result))))))
    (:stays
      (:when (blocked-p grid pos action))
      (:returns grid-position)
      (:post (equal result pos)))))

;;; Properties

(defproperty manhattan-distance-metric
    ((a grid-position) (b grid-position) (c grid-position))
  "Manhattan distance is a metric: non-negative, zero on the diagonal,
symmetric, and obeys the triangle inequality."
  (:about manhattan-distance)
  (:kind :invariant)
  (:trials (:smoke 50 :normal 300))
  (and (>= (manhattan-distance a b) 0)
       (zerop (manhattan-distance a a))
       (= (manhattan-distance a b) (manhattan-distance b a))
       (<= (manhattan-distance a c)
           (+ (manhattan-distance a b) (manhattan-distance b c)))))

(defproperty copy-grid-independent ((grid arena-grid))
  "A copy starts equal to its source, and writing every cell of the copy
leaves the source untouched."
  (:about copy-grid)
  (:kind :invariant)
  (:trials (:smoke 30 :normal 200))
  (let ((snapshot (copy-array grid))
        (copy (copy-grid grid)))
    (and (equalp copy grid)
         (progn
           (dotimes (row (array-dimension copy 0))
             (dotimes (col (array-dimension copy 1))
               (grid-set! copy row col :resource)))
           (equalp grid snapshot)))))
```

`lisp-check-parens` `{"path": "specs/game/arena.lisp"}`。

`lisp-edit-form` で `specs/all.lisp` の `defpackage` を置換:

```lisp
(defpackage #:recurya/specs/all
  (:use #:cl)
  (:import-from #:recurya/specs/domain)
  (:import-from #:recurya/specs/game/arena))
```

- [ ] **Step 4: 緑を確認**

`load-system` `{"system": "recurya/tests/specs/contracts"}` (警告ゼロを確認) → `run-tests` `{"system": "recurya/tests/specs/contracts"}`。
Expected: 全 PASS。加えて `spec-check` `{"function": "recurya/game/arena::apply-move", "trials": 200}` で `case_report` の `:moves` と `:stays` が両方 `called > 0` であることを確認 (未到達ケースが無い)。`parse-action`, `action->delta` も同様。

反例が出たら Global Constraints に従い停止して報告。

- [ ] **Step 5: lint とコミット**

```bash
mallet specs/game/*.lisp tests/specs/*.lisp
git add specs/game/arena.lisp specs/all.lisp tests/specs/contracts.lisp
git commit -m "feat(specs): arena contracts (parse-action, action->delta, apply-move, grid properties)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: notebook の生成器とパーサの契約

**Files:**
- Create: `specs/game/notebook.lisp`, `specs/game/notebook-parser.lisp`
- Modify: `specs/all.lisp`, `tests/specs/contracts.lisp` (期待リスト), `game/notebook-parser.lisp` (`cells->body-md` の docstring のみ)

**Interfaces:**
- Consumes: `recurya/specs/domain` の `notebook-cell-kind`, `fence-kind`。
- Produces (`recurya/specs/game/notebook`, exported): spec + generator `canonical-cells` (正規形 cell のリスト), spec + generator `loose-cells` (前後空白付き本文), `(cell-view cell) → (list kind body description test-case-views gated-p)`。
- Produces: Function Spec `recurya/game/notebook-parser::parse-fence-header`、Property `recurya/specs/game/notebook-parser::notebook-roundtrip`, `notebook-roundtrip-idempotent`。

正規形 (設計書 F-A1/F-A2):
- 本文: 1〜4 の非空行。前後空白なし。行間に単一の空行を挟んでよい。`===` で始まる行なし。
- test-case: input は `""` か 1 行、expected は非空 1 行、description は `""` か 1 行。前後空白なし。`input:` / `output:` を含まない (F-A2: 1 行形式の expected が `input:` で始まると input/output 形式と誤解釈されるため除外)。
- `:code-exercise` / `:code-solution` の description は非空 1 行。その他の kind は `""`。test-case は `:code-exercise` のみ 0〜3 件。gated-p は `:code-solution` のみランダム。

- [ ] **Step 1: 期待リストに追加 (失敗するテスト)**

`lisp-edit-form` で `*expected-properties*` を置換:

```lisp
(defparameter *expected-properties*
  '(("RECURYA/SPECS/GAME/ARENA" . "MANHATTAN-DISTANCE-METRIC")
    ("RECURYA/SPECS/GAME/ARENA" . "COPY-GRID-INDEPENDENT")
    ("RECURYA/SPECS/GAME/NOTEBOOK-PARSER" . "NOTEBOOK-ROUNDTRIP")
    ("RECURYA/SPECS/GAME/NOTEBOOK-PARSER" . "NOTEBOOK-ROUNDTRIP-IDEMPOTENT"))
  "Properties that must be registered, as (PACKAGE . SYMBOL) names.")
```

`*expected-function-specs*` を置換:

```lisp
(defparameter *expected-function-specs*
  '(("RECURYA/GAME/ARENA" . "PARSE-ACTION")
    ("RECURYA/GAME/ARENA" . "ACTION->DELTA")
    ("RECURYA/GAME/ARENA" . "APPLY-MOVE")
    ("RECURYA/GAME/NOTEBOOK-PARSER" . "PARSE-FENCE-HEADER"))
  "Function specs that must be registered, named by their target function.")
```

- [ ] **Step 2: 失敗を確認**

`run-tests` `{"system": "recurya/tests/specs/contracts"}`。Expected: 新規 3 件が FAIL。

- [ ] **Step 3: 生成器を実装**

`fs-write-file` で `specs/game/notebook.lisp`:

```lisp
;;;; specs/game/notebook.lisp --- cl-spec generators for notebook cells.
;;;;
;;;; Canonical cells are the fixed points of a render/parse round trip
;;;; (design doc F-A1/F-A2): bodies are 1-4 non-blank lines with no outer
;;;; whitespace, optionally separated by single blank lines, and no line
;;;; starts with ===; test-case fields are single trimmed lines without
;;;; "input:" or "output:".  Loose cells add outer whitespace to the body.

(defpackage #:recurya/specs/game/notebook
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/game/notebook
                #:make-cell
                #:cell-kind
                #:cell-body
                #:cell-description
                #:cell-test-cases
                #:cell-gated-p)
  (:import-from #:recurya/game/puzzle
                #:make-test-case
                #:test-case-input
                #:test-case-expected
                #:test-case-description)
  (:export #:canonical-cells
           #:loose-cells
           #:cell-view))
(in-package #:recurya/specs/game/notebook)

(defparameter *body-words*
  #("foo" "bar" "(+ 1 2)" "x" "define" "hello world" "# Title" "- item" "42"
    "λ" "a*b" "input: 1" "  (indented)")
  "Words for cell bodies, including Markdown, Lisp, non-ASCII, inner spacing
and an input: line that only matters inside an expect block.")

(defparameter *test-case-words*
  #("foo" "bar" "(+ 1 2)" "x" "define" "hello world" "42" "λ" "a*b")
  "Words for test-case fields: no input:/output: (design doc F-A2).")

(defparameter *cell-kinds*
  #(:prose :code-eval :code-exercise :code-solution :scene)
  "The kinds of NOTEBOOK-CELL-KIND, drawn by the cell generator.")

(defun random-element (sequence)
  "Return a uniformly chosen element of the non-empty SEQUENCE."
  (elt sequence (random (length sequence))))

(defun random-line (words)
  "One line of 1-3 WORDS joined by spaces, with no outer whitespace."
  (string-trim " " (format nil "~{~A~^ ~}"
                           (loop repeat (1+ (random 3))
                                 collect (random-element words)))))

(defun canonical-body ()
  "1-4 non-blank lines, optionally separated by single blank lines."
  (let ((lines '()))
    (dotimes (i (1+ (random 4)))
      (when (and (plusp i) (zerop (random 4)))
        (push "" lines))
      (push (random-line *body-words*) lines))
    (format nil "~{~A~^~%~}" (nreverse lines))))

(defun random-test-case ()
  "A canonical test case."
  (make-test-case
   :input (if (zerop (random 2)) "" (random-line *test-case-words*))
   :expected (random-line *test-case-words*)
   :description (if (zerop (random 2)) "" (random-line *test-case-words*))))

(defun random-canonical-cell ()
  "A canonical cell of a random kind."
  (let ((kind (random-element *cell-kinds*)))
    (make-cell :kind kind
               :body (canonical-body)
               :description (if (member kind '(:code-exercise :code-solution))
                                (random-line *test-case-words*)
                                "")
               :test-cases (when (eq kind :code-exercise)
                             (loop repeat (random 4) collect (random-test-case)))
               :gated-p (and (eq kind :code-solution) (zerop (random 2))))))

(defun loosen (cell)
  "Return CELL with outer whitespace added around its body."
  (setf (cell-body cell)
        (format nil "~A~A~A"
                (random-element (vector "" " " "  " (string #\Newline)))
                (cell-body cell)
                (random-element (vector "" " " (string #\Newline)
                                        (format nil "~%~%")))))
  cell)

(defgenerator canonical-cells ()
  "1-6 fresh canonical cells."
  (loop repeat (1+ (random 6)) collect (random-canonical-cell)))

(defspec canonical-cells list (:generator canonical-cells))

(defgenerator loose-cells ()
  "1-6 fresh cells whose bodies carry outer whitespace."
  (loop repeat (1+ (random 6)) collect (loosen (random-canonical-cell))))

(defspec loose-cells list (:generator loose-cells))

(defun test-case-view (test-case)
  "TEST-CASE as (INPUT EXPECTED DESCRIPTION), comparable with EQUAL."
  (list (test-case-input test-case)
        (test-case-expected test-case)
        (test-case-description test-case)))

(defun cell-view (cell)
  "CELL as (KIND BODY DESCRIPTION TEST-CASE-VIEWS GATED-P), comparable with
EQUAL.  The id is left out: the parser assigns fresh ids."
  (list (cell-kind cell)
        (cell-body cell)
        (cell-description cell)
        (mapcar #'test-case-view (cell-test-cases cell))
        (cell-gated-p cell)))
```

`lisp-check-parens` `{"path": "specs/game/notebook.lisp"}`。

- [ ] **Step 4: パーサの契約を実装**

`fs-write-file` で `specs/game/notebook-parser.lisp`:

```lisp
;;;; specs/game/notebook-parser.lisp --- cl-spec contracts for the notebook parser.
;;;;
;;;; PARSE-FENCE-HEADER's classification, and the render/parse round trip
;;;; that CELLS->BODY-MD's docstring promises for canonical cells.

(defpackage #:recurya/specs/game/notebook-parser
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defspec-function
                #:defproperty
                #:defgenerator
                #:validp)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/specs/domain
                #:notebook-cell-kind
                #:fence-kind)
  (:import-from #:recurya/specs/game/notebook
                #:canonical-cells
                #:loose-cells
                #:cell-view)
  (:import-from #:recurya/game/notebook-parser
                #:parse-notebook-body
                #:cells->body-md
                ;; Internal helper under contract.
                #:parse-fence-header))
(in-package #:recurya/specs/game/notebook-parser)

(defparameter *fence-shape* "^===.+===$"
  "Regex every fence header line matches (+GENERIC-HEADER-REGEX+'s pattern).")

(defun fence-shaped-p (line)
  "True when LINE has the ===...=== shape of a fence header."
  (and (cl-ppcre:scan *fence-shape* line) t))

(defun locked-solution-line-p (line)
  "True when LINE starts with the ===solution-locked: header prefix."
  (eql 0 (search "===solution-locked: " line)))

(defun random-element (sequence)
  "Return a uniformly chosen element of the non-empty SEQUENCE."
  (elt sequence (random (length sequence))))

(defgenerator fence-line ()
  "Exact headers, described headers, near-miss shapes and plain text, about a
quarter each."
  (let ((text (random-element '("" "desc" "a b" "x===y" "λ"))))
    (case (random 4)
      (0 (random-element '("===prose===" "===eval===" "===scene==="
                           "===exercise===" "===code===" "===expect===")))
      (1 (format nil "===~A: ~A==="
                 (random-element '("exercise" "solution" "solution-locked" "expect"))
                 text))
      (2 (format nil "~A===~A===~A"
                 (random-element '("" " " "x"))
                 (random-element '("prose" "foo" "" "eval "))
                 (random-element '("" " " "="))))
      (t text))))

(defspec fence-line string (:generator fence-line))

(defspec-function parse-fence-header
  "A line without the ===...=== shape is never a header.  A header's kind is a
fence kind; only ===solution-locked: ...=== is gated, and a line that is not
recognised carries no description or gate."
  (:args (line fence-line))
  (:cases
    (:not-fence-shaped
      (:when (not (fence-shaped-p line)))
      (:returns (values null null null)))
    (:fence-shaped
      (:when (fence-shaped-p line))
      (:returns (values (or null fence-kind) (or null string) t))
      (:post-values (kind description gated-p)
        (and (if gated-p (eq kind :code-solution) t)
             (if (null kind) (and (null description) (null gated-p)) t)
             (eq (and gated-p t) (locked-solution-line-p line)))))))

(defun round-trip (cells)
  "Render CELLS and parse the result.  Return (VALUES CELLS ERRORS)."
  (parse-notebook-body (cells->body-md cells)))

(defproperty notebook-roundtrip ((cells canonical-cells))
  "Rendering canonical cells and parsing the result gives back the same cells
(kind, body, description, test cases, gate) with no parse errors."
  (:about cells->body-md)
  (:kind :roundtrip)
  (:trials (:smoke 50 :normal 300))
  (multiple-value-bind (parsed errors) (round-trip cells)
    (and (null errors)
         (equal (mapcar #'cell-view parsed) (mapcar #'cell-view cells)))))

(defproperty notebook-roundtrip-idempotent ((cells loose-cells))
  "One render/parse round normalizes any cells; a second round changes
nothing, and every parsed cell has a notebook cell kind."
  (:about cells->body-md)
  (:kind :idempotence)
  (:trials (:smoke 50 :normal 300))
  (let* ((once (round-trip cells))
         (twice (round-trip once)))
    (and (equal (mapcar #'cell-view once) (mapcar #'cell-view twice))
         (every (lambda (cell)
                  (validp 'notebook-cell-kind (first (cell-view cell))))
                once))))
```

`lisp-check-parens` `{"path": "specs/game/notebook-parser.lisp"}`。

`lisp-edit-form` で `specs/all.lisp` の `defpackage` を置換:

```lisp
(defpackage #:recurya/specs/all
  (:use #:cl)
  (:import-from #:recurya/specs/domain)
  (:import-from #:recurya/specs/game/arena)
  (:import-from #:recurya/specs/game/notebook-parser))
```

- [ ] **Step 5: 緑を確認**

`load-system` `{"system": "recurya/tests/specs/contracts"}` (警告ゼロ) → `run-tests` `{"system": "recurya/tests/specs/contracts"}`。Expected: 全 PASS。
追加で `spec-check` `{"property": "recurya/specs/game/notebook-parser::notebook-roundtrip", "profile": "normal"}` と `notebook-roundtrip-idempotent` を `normal` (300 試行) で、`spec-check` `{"function": "recurya/game/notebook-parser::parse-fence-header", "trials": 300}` を実行し、両ケース到達・PASS を確認。

- [ ] **Step 6: `cells->body-md` の docstring を実態に合わせる (F-A1)**

`lisp-patch-form` `game/notebook-parser.lisp` `defun` `cells->body-md`:
- old_text:
```
   The result, when re-parsed by PARSE-NOTEBOOK-BODY, yields cells equal
   in (KIND BODY DESCRIPTION TEST-CASES) to the input. Cells are
   separated by exactly one blank line; no trailing newline is emitted.
```
- new_text:
```
   The result, when re-parsed by PARSE-NOTEBOOK-BODY, yields cells equal
   in (KIND BODY DESCRIPTION TEST-CASES GATED-P) to the input when the
   input is canonical: bodies and test-case fields carry no leading or
   trailing whitespace (the parser trims them), and no one-line expected
   value starts with `input:'.  Any cells become canonical after one
   round trip.  Cells are separated by exactly one blank line; no
   trailing newline is emitted.
```

同じ docstring の出力形式一覧で `:scene` が欠けているので、もう 1 回 `lisp-patch-form`:
- old_text: `     :code-eval      -> \`===eval===\\n<body>'`
- new_text: `     :code-eval      -> \`===eval===\\n<body>'\n     :scene          -> \`===scene===\\n<body>'`

(old_text はファイル上の実テキストと完全一致させること。`lisp-read-file` `name_pattern="^cells->body-md$"` の表示から写す。)

`load-system` `{"system": "recurya/game/notebook-parser"}` → `run-tests` `{"system": "recurya/tests/game/notebook-parser"}` で既存テストが緑のまま。

- [ ] **Step 7: lint とコミット**

```bash
mallet specs/game/*.lisp tests/specs/*.lisp game/notebook-parser.lisp
git add specs/game/notebook.lisp specs/game/notebook-parser.lisp specs/all.lisp tests/specs/contracts.lisp game/notebook-parser.lisp
git commit -m "feat(specs): notebook parser contracts (fence header, round trip, idempotence)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: 有効性確認・全体検証・記録

**Files:**
- Modify: `docs/feedback/cl-mcp-cl-spec.md` (実施中に遭遇した事項), `docs/superpowers/specs/2026-10-10-cl-spec-foundation-design.md` (実績の追記が必要な場合のみ)

- [ ] **Step 1: 契約が壊れた実装を捕まえることを確認 (ミューテーション)**

ファイルは変えず、ワーカー内だけで実装を壊す。1 件ずつ壊して確認し、確認後は元に戻す。

(a) `repl-eval` package `RECURYA/GAME/ARENA`:
```lisp
(defun apply-move (grid pos action)
  (let ((delta (action->delta action)))
    (if (null delta)
        pos
        (cons (+ (car pos) (car delta)) (+ (cdr pos) (cdr delta))))))
```
→ `run-tests` `{"system": "recurya/tests/specs/contracts"}`。Expected: `project-function-specs-pass` が `APPLY-MOVE` で FAIL。
→ `load-system` `{"system": "recurya/game/arena"}` で復元。

(b) `repl-eval` package `RECURYA/GAME/NOTEBOOK-PARSER` で `cells->body-md` を「セル間の空行を出さない」版に差し替える:
```lisp
(defun cells->body-md (cells)
  (with-output-to-string (s)
    (loop for cell in cells
          for first-p = t then nil
          do (unless first-p (write-char #\Newline s))
             (render-cell s cell))))
```
→ `run-tests`。Expected: `NOTEBOOK-ROUNDTRIP` が FAIL するか確認する。PASS した場合 (パーサが空行なしでも受理する場合) は「この変異は許容される」と記録し、代わりに `render-test-case` の 1 行形式で `expected` の代わりに `input` を書く変異で FAIL を確認する。
→ `load-system` `{"system": "recurya/game/notebook-parser"}` で復元。

- [ ] **Step 2: 全スイート**

`load-system` `{"system": "recurya/tests"}` → `run-tests` `{"system": "recurya/tests"}`。
DB テストは `recurya_test` を使う (memory: run-tests-wipes-dev-data は修正済み)。Expected: 既存件数 + 新規ハーネス分がすべて PASS。失敗があれば出力を添えて報告。

- [ ] **Step 3: 警告と lint**

`repl-eval` `(asdf:compile-system "recurya/tests/specs/contracts" :force t)` で警告ゼロ (STYLE-WARNING 含め確認)。

```bash
mallet *.lisp *.asd db/*.lisp models/*.lisp utils/*.lisp web/*.lisp web/*/*.lisp specs/*.lisp specs/*/*.lisp tests/*/*.lisp tests/*/*/*.lisp
```
Expected: `No problems found`。

- [ ] **Step 4: 登録件数を確認**

`spec-list` `{}`。Expected: Function Spec 4 (`parse-action`, `action->delta`, `apply-move`, `parse-fence-header`)、Property 4、Spec は値域 4 + 補助 (`action-input`, `arena-grid`, `canonical-cells`, `loose-cells`, `fence-line`)。

- [ ] **Step 5: フィードバックの追記とコミット**

Task 1〜5 で遭遇した cl-mcp / cl-spec の摩擦を `docs/feedback/cl-mcp-cl-spec.md` に追記 (無ければ追記なし)。計画作成時に判明済みで未記録の候補:
- `repl-eval` で `defpackage` と後続フォームを 1 回で送ると全フォームが先に読まれるため、新パッケージのシンボルが CL-USER に読まれる (仕様どおりだが、`defpackage` を含む入力で警告が欲しい)。分類 UX。
- `satisfies` / `symbol` など生成器の無い Spec を Property 引数に使うと `GENERATOR-UNAVAILABLE` (メッセージは明快)。`spec-check` 応答に「`(:generator ...)` を付ける」ヒントがあると良い。分類 idea。
- custom generator 由来の反例は縮小されない (shrinker 無し) ため、往復 Property の反例が大きい。`defgenerator` の `(:shrink ...)` の使い方の例が欲しい。分類 docs。

```bash
git add docs/feedback/cl-mcp-cl-spec.md
git commit -m "docs(feedback): record cl-mcp/cl-spec findings from contract work

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 6: ユーザーへ報告**

報告内容: 追加した契約一覧、全スイート結果 (件数)、ミューテーション確認結果、F-A2 (`input:` で始まる期待値の誤解釈) の修正要否の判断依頼、サブプロジェクト B/C への引き継ぎ事項。push と PR 作成はユーザー確認後。
