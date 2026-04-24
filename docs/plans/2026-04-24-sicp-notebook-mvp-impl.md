# SICP ノートブック学習コース MVP 実装計画

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** `docs/plans/2026-04-24-sicp-notebook-mvp-design.md` に沿って、`/wardlisp/learn/*` 配下のノートブック型学習コースを最小実装する(SICP 1.1.1〜1.1.3 の 3 ノートブック、localStorage 進捗、再評価方式の状態共有)。

**Architecture:** 既存 `game/puzzle.lisp` + `web/ui/puzzle.lisp` + `web/routes-wardlisp.lisp` の構造を鏡像にした独立サブシステム。既存 Puzzle/Arena/Playground のコード・URL・ホーム画面は一切触らない。

**Tech Stack:** Common Lisp / ASDF package-inferred-system / Ningle / Clack / Spinneret / HTMX / CodeMirror 6 / WardLisp(外部ライブラリ) / Rove。

---

## 作業前チェック

- ブランチは `main`(このプロジェクトは直接コミットする流儀)
- Lisp ファイルの操作はすべて cl-mcp ツール経由(`lisp-edit-form`, `lisp-patch-form`, `lisp-read-file`, `run-tests`, `repl-eval` 等)。`Read`/`Edit`/`Write`/`Grep` の Claude Code 組み込みを `.lisp`/`.asd` に使わないこと(`CLAUDE.md` の強制事項)
- 初回セットアップ: `fs-set-project-root` に `/home/wiz/recurya` を渡す
- 各タスクの最後に git commit(作業単位ごと)。コミットメッセージの末尾には `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` を付ける
- Docker コンテナ再起動は**最終手段**(cl-mcp が切れる)。新モジュール追加後は `(asdf:load-system :recurya :force t)` で再読込

## 既存参考ファイル

- `game/puzzle.lisp` — struct 定義・fuel/cons/depth/output 定数・`run-puzzle` の採点ロジック
- `game/puzzles/sqrt2-newton.lisp` — ノートブックファイルの雛形
- `game/puzzles/registry.lisp` — registry の書き方
- `web/ui/puzzle.lisp` — 結果パネル / HTMX fragment のスタイル
- `web/ui/wardlisp-home.lisp` — 一覧ページのスタイル
- `web/routes-wardlisp.lisp` — ハンドラ / `setup-wardlisp-routes` / `make-dynamic-handler`
- `tests/game/puzzle.lisp` — Rove テストの書き方

---

## Task 0: スパイク — WardLisp の `define` と数値の `print-value` を実機確認

**目的:** コード演習セルの `test-case.expected` は WardLisp の `print-value` 出力そのまま。実装前に実物を確認してから各演習の `expected` を確定する。

**Files:** (変更なし、情報収集のみ)

**Step 1: プロジェクト読込**

`repl-eval` で:

```lisp
(asdf:load-system :recurya)
```

Expected: エラーなく完了

**Step 2: `define` / 算術 / 除算を実機確認**

`repl-eval` で各ケースを個別に実行し、返り値の `print-value` 文字列を記録する:

```lisp
(wardlisp:print-value
 (wardlisp:evaluate "(+ 137 349)"))
;; 期待: "486"

(wardlisp:print-value
 (wardlisp:evaluate "(define size 2) (* 5 size)"))
;; 期待: "10" (最終式の値)

(wardlisp:print-value
 (wardlisp:evaluate "(define (square x) (* x x)) (square 21)"))
;; (define (f x) ...) 形が動くか確認

(wardlisp:print-value
 (wardlisp:evaluate "(/ 10 5)"))
;; 整数除算の表示

(wardlisp:print-value
 (wardlisp:evaluate "(/ 10 3)"))
;; 非割り切れの表示(分数? 浮動小数?)

(wardlisp:print-value
 (wardlisp:evaluate "(* 3.14 10 10)"))
;; 浮動小数点の表示

(wardlisp:print-value
 (wardlisp:evaluate
  "(define (f a b c d e) (/ (+ a (* b c)) (- d e))) (f 2 3 4 10 5)"))
;; SICP 1.1.3 演習の結果表示(整数除算 or 有理数 or 浮動)
```

**Step 3: スパイク結果を計画書に追記**

このファイル末尾の「スパイク結果メモ」セクションに結果を記載。

- `(define (f x) ...)` 形が使えるか
- `(/ 10 5)` の表示(`"2"` か `"2.0"` か)
- `(/ 10 3)` の表示(`"10/3"` か `"3.3333..."` か)
- 浮動小数のデフォルト表示桁数

**Step 4: コミットなし**(情報収集のみ)。以降のタスクで得られた値を `expected` に使う。

---

## Task 1: `game/notebook.lisp` のスケルトン作成

**Files:**
- Create: `game/notebook.lisp`

**Step 1: 最小スケルトンを `fs-write-file` で作成**

```lisp
;;;; game/notebook.lisp --- Notebook/cell model and run-cell evaluator.

(defpackage #:recurya/game/notebook
  (:use #:cl)
  (:import-from #:wardlisp
                #:evaluate
                #:print-value)
  (:import-from #:recurya/game/puzzle
                #:make-test-case
                #:test-case-input
                #:test-case-expected
                #:test-case-description)
  (:export #:notebook #:make-notebook
           #:notebook-id #:notebook-chapter #:notebook-title
           #:notebook-summary #:notebook-cells
           #:cell #:make-cell
           #:cell-id #:cell-kind #:cell-body
           #:cell-description #:cell-test-cases
           #:notebook-cell-result #:make-notebook-cell-result
           #:notebook-cell-result-cell-id
           #:notebook-cell-result-kind
           #:notebook-cell-result-status
           #:notebook-cell-result-value
           #:notebook-cell-result-print-output
           #:notebook-cell-result-error-message
           #:notebook-cell-result-metrics
           #:notebook-cell-result-test-results
           #:run-cell
           #:*notebook-fuel* #:*notebook-max-cons*
           #:*notebook-max-depth* #:*notebook-max-output*
           #:*notebook-timeout*))

(in-package #:recurya/game/notebook)

(defun __stub () nil)
```

**Step 2: `lisp-check-parens` で構文確認**

Run: `lisp-check-parens` で `game/notebook.lisp`
Expected: no issues

**Step 3: ASDF がモジュールを認識するか確認**

`repl-eval`:
```lisp
(asdf:load-system :recurya/game/notebook)
```
Expected: エラーなく完了

**Step 4: コミット**

```bash
git add game/notebook.lisp
git commit -m "$(cat <<'EOF'
Add notebook package skeleton for SICP learning course

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `notebook` / `cell` struct のテストと実装

**Files:**
- Modify: `game/notebook.lisp`
- Create: `tests/game/notebook.lisp`

**Step 1: 失敗するテストを `tests/game/notebook.lisp` に作成**

`fs-write-file` で:

```lisp
;;;; tests/game/notebook.lisp --- Tests for the notebook model and run-cell.

(defpackage #:recurya/tests/game/notebook
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebook
                #:make-notebook
                #:notebook-id
                #:notebook-cells
                #:make-cell
                #:cell-id
                #:cell-kind
                #:cell-body
                #:cell-test-cases))

(in-package #:recurya/tests/game/notebook)

(deftest notebook-struct-basic
  (testing "notebook holds id and cells"
    (let* ((c (make-cell :id :intro :kind :prose :body '(:p "hello")))
           (nb (make-notebook :id :demo :chapter "0" :title "Demo"
                              :summary "A demo" :cells (list c))))
      (ok (eq :demo (notebook-id nb)))
      (ok (= 1 (length (notebook-cells nb))))
      (ok (eq :intro (cell-id c)))
      (ok (eq :prose (cell-kind c)))
      (ok (equal '(:p "hello") (cell-body c))))))

(deftest cell-exercise-fields
  (testing "code-exercise cells carry description and test-cases"
    (let ((c (make-cell :id :ex :kind :code-exercise
                        :body "(define (f) 0)"
                        :description "trivial"
                        :test-cases nil)))
      (ok (eq :code-exercise (cell-kind c)))
      (ok (null (cell-test-cases c))))))
```

**Step 2: テストを実行して失敗を確認**

Run via `run-tests`:
```
{"system": "recurya/tests/game/notebook"}
```
Expected: FAIL (notebook and cell structs not defined)

**Step 3: `game/notebook.lisp` に struct を `lisp-edit-form` で追加**

`__stub` 関数の位置に `replace` で:

```lisp
(defstruct notebook
  "A SICP-style notebook: a list of cells rendered top-down."
  id chapter title summary cells)

(defstruct cell
  "A single notebook cell. KIND is one of :prose, :code-eval, :code-exercise."
  id kind body description test-cases)

(defstruct notebook-cell-result
  "Result of running one cell."
  cell-id kind status value print-output error-message metrics test-results)
```

`__stub` を削除(`lisp-edit-form` で `operation: replace`)。

**Step 4: ASDF に `recurya/tests/game/notebook` を追加**

`recurya.asd` の `recurya/tests` システムの `:depends-on` リスト末尾付近(他のゲームテストの隣)に追記。`lisp-edit-form` で:

該当箇所の直後に `"recurya/tests/game/notebook"` を追加。

**Step 5: テスト再実行**

Run: `run-tests` `{"system": "recurya/tests/game/notebook"}`
Expected: PASS (all tests)

**Step 6: コミット**

```bash
git add game/notebook.lisp tests/game/notebook.lisp recurya.asd
git commit -m "$(cat <<'EOF'
Add notebook/cell/result structs with tests

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `*notebook-*` 実行上限定数を追加

**Files:**
- Modify: `game/notebook.lisp`

**Step 1: `lisp-edit-form` で struct 定義群の直後に `insert_after` で追加**

```lisp
(defparameter *notebook-fuel* 20000
  "Default fuel limit for a notebook cell evaluation.")

(defparameter *notebook-max-cons* 10000
  "Default cons allocation limit for a notebook cell evaluation.")

(defparameter *notebook-max-depth* 200
  "Default call-stack depth limit for a notebook cell evaluation.")

(defparameter *notebook-max-output* 4096
  "Default captured-output byte limit for a notebook cell evaluation.")

(defparameter *notebook-timeout* 5
  "Default wall-clock timeout (seconds) for a notebook cell evaluation.")
```

**Step 2: 読込確認**

`repl-eval`: `(asdf:load-system :recurya/game/notebook :force t)`
Expected: 成功

**Step 3: コミット**

```bash
git add game/notebook.lisp
git commit -m "$(cat <<'EOF'
Add execution limit parameters for notebook cells

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `run-cell` — prose セルは実行不可(TDD)

**Files:**
- Modify: `tests/game/notebook.lisp`
- Modify: `game/notebook.lisp`

**Step 1: 失敗するテストを追加(`lisp-edit-form` で `insert_after` 末尾)**

```lisp
(deftest run-cell-prose-rejected
  (testing "prose cells cannot be executed"
    (let* ((nb (make-notebook
                :id :demo :chapter "0" :title "Demo" :summary ""
                :cells (list (make-cell :id :p :kind :prose :body '(:p "x"))))))
      (ok (signals (recurya/game/notebook:run-cell nb 0 '("")))))))
```

`:import-from` に `#:run-cell` を追加。

**Step 2: テスト実行で失敗確認**

Run: `run-tests` `{"system": "recurya/tests/game/notebook", "test": "recurya/tests/game/notebook::run-cell-prose-rejected"}`
Expected: FAIL

**Step 3: `run-cell` の最小実装**

`game/notebook.lisp` に `lisp-edit-form` で追加:

```lisp
(defun run-cell (notebook cell-index submitted-codes)
  "Execute the cell at CELL-INDEX in NOTEBOOK using SUBMITTED-CODES
   (strings, one per code cell up to and including CELL-INDEX).
   Returns a NOTEBOOK-CELL-RESULT. Signals an error for :prose cells."
  (let* ((cells (notebook-cells notebook))
         (cell (nth cell-index cells)))
    (unless cell
      (error "Cell index ~A out of range for notebook ~A"
             cell-index (notebook-id notebook)))
    (when (eq (cell-kind cell) :prose)
      (error "Cannot run a prose cell (id=~A)" (cell-id cell)))
    ;; Placeholder: real behavior added in subsequent tasks.
    (declare (ignore submitted-codes))
    (make-notebook-cell-result
     :cell-id (cell-id cell)
     :kind (cell-kind cell)
     :status :ok
     :value ""
     :print-output ""
     :error-message nil
     :metrics nil
     :test-results nil)))
```

**Step 4: テスト再実行**

Expected: PASS

**Step 5: コミット**

```bash
git add game/notebook.lisp tests/game/notebook.lisp
git commit -m "$(cat <<'EOF'
Implement run-cell skeleton; reject prose cells

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `run-cell` — `:code-eval` の連結評価

**Files:**
- Modify: `tests/game/notebook.lisp`
- Modify: `game/notebook.lisp`

**Step 1: 失敗するテスト追加**

```lisp
(deftest run-cell-code-eval-basic
  (testing "code-eval cell evaluates and returns value"
    (let* ((nb (make-notebook
                :id :demo :chapter "0" :title "Demo" :summary ""
                :cells (list (make-cell :id :c1 :kind :code-eval
                                        :body "(+ 1 2)"))))
           (r (recurya/game/notebook:run-cell nb 0 '("(+ 1 2)"))))
      (ok (eq :ok (recurya/game/notebook:notebook-cell-result-status r)))
      (ok (string= "3" (recurya/game/notebook:notebook-cell-result-value r))))))

(deftest run-cell-code-eval-shares-state-with-prior-cells
  (testing "a code cell sees defines from earlier cells"
    (let* ((nb (make-notebook
                :id :demo :chapter "0" :title "Demo" :summary ""
                :cells (list (make-cell :id :c1 :kind :code-eval
                                        :body "(define x 10)")
                             (make-cell :id :c2 :kind :code-eval
                                        :body "(* x 5)"))))
           (r (recurya/game/notebook:run-cell
               nb 1 '("(define x 10)" "(* x 5)"))))
      (ok (eq :ok (recurya/game/notebook:notebook-cell-result-status r)))
      (ok (string= "50" (recurya/game/notebook:notebook-cell-result-value r))))))
```

`:import-from` に不足アクセサを追加(`notebook-cell-result-status`, `notebook-cell-result-value` など)。

**Step 2: テストが失敗することを確認**

Expected: FAIL

**Step 3: `run-cell` を連結評価対応に書き換える(`lisp-edit-form` で `replace`)**

```lisp
(defun run-cell (notebook cell-index submitted-codes)
  "Execute the cell at CELL-INDEX in NOTEBOOK by concatenating the first
   (CELL-INDEX + 1) entries of SUBMITTED-CODES and evaluating them once.
   Returns a NOTEBOOK-CELL-RESULT. Signals an error for :prose cells and
   out-of-range indices."
  (let* ((cells (notebook-cells notebook))
         (cell (nth cell-index cells)))
    (unless cell
      (error "Cell index ~A out of range for notebook ~A"
             cell-index (notebook-id notebook)))
    (when (eq (cell-kind cell) :prose)
      (error "Cannot run a prose cell (id=~A)" (cell-id cell)))
    (let* ((codes (subseq submitted-codes 0 (1+ cell-index)))
           (combined (format nil "~{~A~^~%~}" codes)))
      (multiple-value-bind (result metrics)
          (evaluate combined
                    :fuel *notebook-fuel*
                    :max-cons *notebook-max-cons*
                    :max-depth *notebook-max-depth*
                    :max-output *notebook-max-output*
                    :timeout *notebook-timeout*)
        (let ((err (getf metrics :error-message)))
          (cond
            (err
              (make-notebook-cell-result
               :cell-id (cell-id cell) :kind (cell-kind cell)
               :status (if (getf metrics :limit-exceeded) :limit-exceeded :error)
               :value nil
               :print-output (or (getf metrics :output) "")
               :error-message err
               :metrics metrics
               :test-results nil))
            (t
              (make-notebook-cell-result
               :cell-id (cell-id cell) :kind (cell-kind cell)
               :status :ok
               :value (print-value result)
               :print-output (or (getf metrics :output) "")
               :error-message nil
               :metrics metrics
               :test-results nil))))))))
```

**Step 4: テスト再実行**

Run: `run-tests` `{"system": "recurya/tests/game/notebook"}`
Expected: PASS (all)

**Step 5: コミット**

```bash
git add game/notebook.lisp tests/game/notebook.lisp
git commit -m "$(cat <<'EOF'
Implement run-cell concatenated evaluation for code-eval cells

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

**注記:** `metrics` の `:limit-exceeded` キー名は WardLisp の実装に依る。Task 0 スパイクまたは既存 `run-puzzle` の挙動から実名を確認し、必要なら差し替える。現実には `evaluate` は例外ではなく metrics に `error-message` を入れて返ってくる前提(`run-puzzle` と同じ)。

---

## Task 6: `run-cell` — `:code-exercise` の test-case 採点

**Files:**
- Modify: `tests/game/notebook.lisp`
- Modify: `game/notebook.lisp`

**Step 1: 失敗するテスト追加**

```lisp
(deftest run-cell-exercise-pass
  (testing "exercise cell passes when test-case expected matches"
    (let* ((tc (recurya/game/puzzle:make-test-case
                :input "(double 3)" :expected "6" :description "simple"))
           (nb (make-notebook
                :id :demo :chapter "0" :title "Demo" :summary ""
                :cells (list (make-cell :id :ex :kind :code-exercise
                                        :body "(define (double x) (* x 2))"
                                        :description "write double"
                                        :test-cases (list tc)))))
           (r (recurya/game/notebook:run-cell
               nb 0 '("(define (double x) (* x 2))"))))
      (ok (eq :pass (recurya/game/notebook:notebook-cell-result-status r))))))

(deftest run-cell-exercise-fail
  (testing "exercise cell fails when expected does not match"
    (let* ((tc (recurya/game/puzzle:make-test-case
                :input "(double 3)" :expected "6" :description "simple"))
           (nb (make-notebook
                :id :demo :chapter "0" :title "Demo" :summary ""
                :cells (list (make-cell :id :ex :kind :code-exercise
                                        :body "(define (double x) (+ x x x))"
                                        :description "wrong"
                                        :test-cases (list tc)))))
           (r (recurya/game/notebook:run-cell
               nb 0 '("(define (double x) (+ x x x))"))))
      (ok (eq :fail (recurya/game/notebook:notebook-cell-result-status r))))))
```

**Step 2: 失敗確認**

Expected: FAIL

**Step 3: 実装(`run-cell` の末尾 `cond` に exercise 分岐を追加)**

`lisp-edit-form` で `run-cell` を `replace`:

```lisp
(defun run-cell (notebook cell-index submitted-codes)
  "Execute the cell at CELL-INDEX in NOTEBOOK.
   For :code-eval cells, concatenate SUBMITTED-CODES[0..CELL-INDEX] and
   evaluate once. For :code-exercise cells with test-cases, evaluate the
   user's combined code and run each test-case by appending its input.
   Returns a NOTEBOOK-CELL-RESULT."
  (let* ((cells (notebook-cells notebook))
         (cell (nth cell-index cells)))
    (unless cell
      (error "Cell index ~A out of range for notebook ~A"
             cell-index (notebook-id notebook)))
    (when (eq (cell-kind cell) :prose)
      (error "Cannot run a prose cell (id=~A)" (cell-id cell)))
    (let* ((codes (subseq submitted-codes 0 (1+ cell-index)))
           (combined (format nil "~{~A~^~%~}" codes)))
      (cond
        ((eq (cell-kind cell) :code-exercise)
         (run-exercise-cell cell combined))
        (t
         (run-eval-cell cell combined))))))

(defun run-eval-cell (cell combined)
  (multiple-value-bind (result metrics)
      (evaluate combined
                :fuel *notebook-fuel* :max-cons *notebook-max-cons*
                :max-depth *notebook-max-depth* :max-output *notebook-max-output*
                :timeout *notebook-timeout*)
    (let ((err (getf metrics :error-message)))
      (if err
          (make-notebook-cell-result
           :cell-id (cell-id cell) :kind (cell-kind cell)
           :status :error :value nil
           :print-output (or (getf metrics :output) "")
           :error-message err :metrics metrics :test-results nil)
          (make-notebook-cell-result
           :cell-id (cell-id cell) :kind (cell-kind cell)
           :status :ok :value (print-value result)
           :print-output (or (getf metrics :output) "")
           :error-message nil :metrics metrics :test-results nil)))))

(defun run-exercise-cell (cell combined)
  (let ((test-results nil)
        (user-error nil)
        (user-metrics nil))
    ;; First: evaluate the user's combined code to surface syntax/runtime errors
    (multiple-value-bind (user-result metrics)
        (evaluate combined
                  :fuel *notebook-fuel* :max-cons *notebook-max-cons*
                  :max-depth *notebook-max-depth*
                  :max-output *notebook-max-output*
                  :timeout *notebook-timeout*)
      (declare (ignore user-result))
      (setf user-metrics metrics
            user-error (getf metrics :error-message)))
    (if user-error
        (make-notebook-cell-result
         :cell-id (cell-id cell) :kind :code-exercise
         :status :error :value nil
         :print-output (or (getf user-metrics :output) "")
         :error-message user-error :metrics user-metrics :test-results nil)
        (let ((all-pass t))
          (dolist (tc (cell-test-cases cell))
            (let ((full-code (format nil "~A~%~A" combined (test-case-input tc))))
              (multiple-value-bind (result metrics)
                  (evaluate full-code
                            :fuel *notebook-fuel* :max-cons *notebook-max-cons*
                            :max-depth *notebook-max-depth*
                            :max-output *notebook-max-output*
                            :timeout *notebook-timeout*)
                (let* ((terr (getf metrics :error-message))
                       (expected-str (test-case-expected tc))
                       (actual-str (unless terr (print-value result)))
                       (passed (and (not terr)
                                    (string= actual-str expected-str))))
                  (unless passed (setf all-pass nil))
                  (push (list :input (test-case-input tc)
                              :description (test-case-description tc)
                              :expected expected-str
                              :actual actual-str
                              :passed passed
                              :error terr)
                        test-results)))))
          (make-notebook-cell-result
           :cell-id (cell-id cell) :kind :code-exercise
           :status (if all-pass :pass :fail)
           :value nil
           :print-output (or (getf user-metrics :output) "")
           :error-message nil
           :metrics user-metrics
           :test-results (nreverse test-results))))))
```

**Step 4: テスト再実行**

Expected: PASS (6 tests)

**Step 5: コミット**

```bash
git add game/notebook.lisp tests/game/notebook.lisp
git commit -m "$(cat <<'EOF'
Implement test-case grading for code-exercise cells

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: `run-cell` — 無限ループで `:limit-exceeded` を返す

**Files:**
- Modify: `tests/game/notebook.lisp`

**Step 1: 失敗するテスト追加**

```lisp
(deftest run-cell-fuel-exhaustion
  (testing "an infinite loop yields an error or limit status"
    (let* ((nb (make-notebook
                :id :demo :chapter "0" :title "Demo" :summary ""
                :cells (list (make-cell :id :c :kind :code-eval
                                        :body "(define (f) (f)) (f)"))))
           (r (recurya/game/notebook:run-cell
               nb 0 '("(define (f) (f)) (f)"))))
      (ok (member (recurya/game/notebook:notebook-cell-result-status r)
                  '(:error :limit-exceeded))))))
```

**Step 2: 実行**

Expected: PASS(Task 5 の実装がすでに `error-message` を拾えるため通る可能性あり。通らない場合は `metrics` のキー名を確認して実装を調整)

**Step 3: 実装修正が必要な場合** — Task 5 の実装内の status 判定ロジックで、fuel/cons 由来のエラーなら `:limit-exceeded` を返す分岐を足す(WardLisp の `metrics` に判別可能なキーがある場合)。無ければ統一して `:error` を返して OK(UI 側でエラーメッセージ本文から判別する)。

**Step 4: コミット**

```bash
git add tests/game/notebook.lisp
git commit -m "$(cat <<'EOF'
Add fuel-exhaustion test for run-cell

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: SICP 1.1.1 ノートブック定義 + スモークテスト

**Files:**
- Create: `game/notebooks/sicp-1-1-1.lisp`
- Create: `tests/game/notebooks/sicp-1-1-1.lisp`

**Step 1: 失敗するスモークテスト作成(`fs-write-file`)**

```lisp
;;;; tests/game/notebooks/sicp-1-1-1.lisp --- Smoke test for SICP 1.1.1.

(defpackage #:recurya/tests/game/notebooks/sicp-1-1-1
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-1-1
                #:make-sicp-1-1-1-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind))

(in-package #:recurya/tests/game/notebooks/sicp-1-1-1)

(deftest sicp-1-1-1-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-1-1-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))
```

**Step 2: ノートブック本体を `fs-write-file` で作成(最小スケルトン)**

```lisp
;;;; game/notebooks/sicp-1-1-1.lisp --- SICP 1.1.1 Expressions.

(defpackage #:recurya/game/notebooks/sicp-1-1-1
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-1-1-1-notebook))

(in-package #:recurya/game/notebooks/sicp-1-1-1)

(defun make-sicp-1-1-1-notebook ()
  "SICP 1.1.1 - Expressions."
  (make-notebook
   :id :sicp-1-1-1
   :chapter "1.1.1"
   :title "式"
   :summary "数値リテラル、プレフィックス記法、入れ子の式を触れる"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:p "Lispプログラムは"
                          (:em "式") "を書いて評価することで動きます。"
                          "この節では最も基本的な式から始めます。"))
    (make-cell :id :num :kind :code-eval
               :body "486")
    (make-cell :id :prefix :kind :prose
               :body '(:p "関数呼び出しはすべて"
                          (:strong "プレフィックス記法")
                          "で書きます。演算子が先、引数が続きます。"))
    (make-cell :id :add :kind :code-eval
               :body "(+ 137 349)")
    (make-cell :id :more-arith :kind :code-eval
               :body "(- 1000 334)
(* 5 99)
(/ 10 5)")
    (make-cell :id :nested-prose :kind :prose
               :body '(:p "式は入れ子にできます。各括弧の内側から評価されます。"))
    (make-cell :id :nested :kind :code-eval
               :body "(+ (* 3 5) (- 10 6))")
    (make-cell :id :ex-sum3 :kind :code-exercise
               :description "137、349、22 の合計を求める式を書いてください。"
               :body "; ここに式を書く"
               :test-cases
               (list (make-test-case :input ""  ; 演習コード本体が最終式
                                     :expected "508"
                                     :description "三項の和"))))))
```

**注記:** `input` を空にすると `format nil "~A~%~A" combined ""` が `combined\n` となり、combined の末尾式の値が採点対象になる。ユーザが「137 + 349 + 22 を返す**式**」を書けば `(+ 137 349 22)` のような末尾式の値が "508" と一致する。Task 0 スパイクで `(+ 137 349 22)` の `print-value` が実際に `"508"` であることを確認する。違えば expected を合わせる。

**Step 3: ASDF に登録**

`recurya.asd` の `recurya` システムで、`recurya/game/puzzles/registry` の後あたりに:
```
"recurya/game/notebook"
"recurya/game/notebooks/sicp-1-1-1"
```
追加。`recurya/tests` システムにも同様に:
```
"recurya/tests/game/notebooks/sicp-1-1-1"
```
追加。

**Step 4: テスト実行**

Run: `run-tests` `{"system": "recurya/tests/game/notebooks/sicp-1-1-1"}`
Expected: PASS

**Step 5: 演習の模範解答で採点が通ることを `repl-eval` で手動確認**

```lisp
(let ((nb (recurya/game/notebooks/sicp-1-1-1:make-sicp-1-1-1-notebook)))
  (recurya/game/notebook:run-cell
   nb
   (1- (length (recurya/game/notebook:notebook-cells nb)))
   (list "" "486" "" "(+ 137 349)" "..." "" "..." "(+ 137 349 22)")))
```

期待: status `:pass`。ずれていれば `expected` の文字列を Task 0 スパイクの実値に合わせて修正。

**Step 6: コミット**

```bash
git add game/notebooks/sicp-1-1-1.lisp tests/game/notebooks/sicp-1-1-1.lisp recurya.asd
git commit -m "$(cat <<'EOF'
Add SICP 1.1.1 notebook (Expressions) with smoke test

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Notebook registry 作成

**Files:**
- Create: `game/notebooks/registry.lisp`

**Step 1: `fs-write-file` で作成**

```lisp
;;;; game/notebooks/registry.lisp --- List of all notebooks in display order.

(defpackage #:recurya/game/notebooks/registry
  (:use #:cl)
  (:import-from #:recurya/game/notebooks/sicp-1-1-1
                #:make-sicp-1-1-1-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-id)
  (:export #:all-notebooks #:get-notebook))

(in-package #:recurya/game/notebooks/registry)

(defparameter *notebooks*
  (list (make-sicp-1-1-1-notebook))
  "All available notebooks, in display order.")

(defun get-notebook (id)
  "Find notebook by keyword ID. Returns notebook struct or NIL."
  (find id *notebooks* :key #'notebook-id))

(defun all-notebooks ()
  "Return list of all notebooks in display order."
  *notebooks*)
```

**Step 2: ASDF に追加**

`recurya.asd` に `"recurya/game/notebooks/registry"` を 1.1.1 の直後に追加。

**Step 3: 読込確認**

```lisp
(asdf:load-system :recurya/game/notebooks/registry)
(length (recurya/game/notebooks/registry:all-notebooks))
;; => 1
```

**Step 4: コミット**

```bash
git add game/notebooks/registry.lisp recurya.asd
git commit -m "$(cat <<'EOF'
Add notebook registry

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: コース一覧ページ `web/ui/learn-home.lisp`

**Files:**
- Create: `web/ui/learn-home.lisp`

**Step 1: 既存の `web/ui/wardlisp-home.lisp` を参考にし、`fs-write-file` でスケルトン作成**

```lisp
;;;; web/ui/learn-home.lisp --- SICP course index page.

(defpackage #:recurya/web/ui/learn-home
  (:use #:cl)
  (:import-from #:spinneret #:with-html-string #:with-html)
  (:import-from #:recurya/game/notebook
                #:notebook-id #:notebook-chapter
                #:notebook-title #:notebook-summary
                #:notebook-cells)
  (:export #:render))

(in-package #:recurya/web/ui/learn-home)

(defparameter *styles*
  "body { font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
         margin: 0; background: #0f172a; color: #e2e8f0; line-height: 1.6; }
main { max-width: 760px; margin: 0 auto; padding: 3rem 1.5rem; }
h1 { font-size: 2rem; letter-spacing: -0.03em; text-align: center;
     color: #f8fafc; margin-bottom: 0.5rem; }
.subtitle { text-align: center; color: #94a3b8; margin-bottom: 2.5rem; }
.note { text-align: center; color: #64748b; font-size: 0.85rem;
        margin-bottom: 2rem; }
.nb-list { list-style: none; padding: 0; display: flex; flex-direction: column;
           gap: 1rem; }
.nb-card { background: #1e293b; border-radius: 12px; padding: 1.5rem;
           text-decoration: none; color: #e2e8f0; display: block;
           border: 1px solid #334155; transition: border-color 0.15s; }
.nb-card:hover { border-color: #38bdf8; }
.nb-card__ch { color: #38bdf8; font-family: monospace; font-size: 0.85rem; }
.nb-card__title { font-size: 1.2rem; font-weight: 700; margin: 0.25rem 0;
                  color: #f8fafc; }
.nb-card__summary { color: #94a3b8; font-size: 0.9rem; margin: 0; }
.nb-card__meta { color: #64748b; font-size: 0.8rem; margin-top: 0.75rem; }")

(defun render (notebooks)
  "Render the SICP course index page."
  (with-html-string
    (:doctype)
    (:html
     (:head
      (:meta :charset "utf-8")
      (:title "SICP コース — Recurya")
      (:style (:raw *styles*)))
     (:body
      (:main
       (:h1 "SICP で学ぶ WardLisp")
       (:p :class "subtitle" "Structure and Interpretation of Computer Programs")
       (:p :class "note" "進捗はこのブラウザ内にのみ保存されます。")
       (:ul :class "nb-list"
            (dolist (nb notebooks)
              (:li
               (:a :class "nb-card"
                   :href (format nil "/wardlisp/learn/~A"
                                 (string-downcase (symbol-name (notebook-id nb))))
                   (:div :class "nb-card__ch"
                         (notebook-chapter nb))
                   (:h3 :class "nb-card__title" (notebook-title nb))
                   (:p :class "nb-card__summary" (notebook-summary nb))
                   (:div :class "nb-card__meta"
                         (format nil "~A セル"
                                 (length (notebook-cells nb))))))))))
     (:script :src "/static/js/learn.js")))))
```

**Step 2: ASDF 追加**

`recurya.asd` の WardLisp UI セクション(既存 `wardlisp-home` の隣)に:
```
"recurya/web/ui/learn-home"
```

**Step 3: 読込確認**

```lisp
(asdf:load-system :recurya/web/ui/learn-home)
(recurya/web/ui/learn-home:render
 (recurya/game/notebooks/registry:all-notebooks))
;; 文字列が返ればOK
```

**Step 4: コミット**

```bash
git add web/ui/learn-home.lisp recurya.asd
git commit -m "$(cat <<'EOF'
Add SICP course index page UI

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: ノートブックページ `web/ui/notebook.lisp`(render)

**Files:**
- Create: `web/ui/notebook.lisp`

**Step 1: `fs-write-file` でスケルトン**

既存 `web/ui/puzzle.lisp` を参考に、`editor:render-editor` を使ってセルを並べる。

```lisp
;;;; web/ui/notebook.lisp --- Notebook page and cell result fragment.

(defpackage #:recurya/web/ui/notebook
  (:use #:cl)
  (:import-from #:spinneret #:with-html-string #:with-html)
  (:import-from #:recurya/game/notebook
                #:notebook-id #:notebook-chapter #:notebook-title
                #:notebook-summary #:notebook-cells
                #:cell-id #:cell-kind #:cell-body #:cell-description
                #:notebook-cell-result-cell-id
                #:notebook-cell-result-kind
                #:notebook-cell-result-status
                #:notebook-cell-result-value
                #:notebook-cell-result-print-output
                #:notebook-cell-result-error-message
                #:notebook-cell-result-metrics
                #:notebook-cell-result-test-results)
  (:export #:render #:render-cell-result))

(in-package #:recurya/web/ui/notebook)

(defparameter *styles*
  ;; 既存 web/ui/puzzle.lisp のトークンを踏襲
  "body { font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
         margin: 0; background: #0f172a; color: #e2e8f0; line-height: 1.6; }
main { max-width: 900px; margin: 0 auto; padding: 2rem 1.5rem; }
.breadcrumb { color: #64748b; font-size: 0.9rem; margin-bottom: 1rem; }
.breadcrumb a { color: #38bdf8; text-decoration: none; }
h1 { font-size: 1.6rem; letter-spacing: -0.02em; color: #f8fafc; }
.summary { color: #94a3b8; margin-bottom: 2rem; }
.cell { margin-bottom: 1.75rem; }
.cell--prose { background: #111827; border-left: 3px solid #334155;
               padding: 1rem 1.25rem; border-radius: 0 8px 8px 0; }
.cell--code { background: #1e293b; border-radius: 10px; padding: 1rem; }
.cell--exercise { border: 1px solid #f59e0b; }
.cell__desc { color: #fbbf24; font-size: 0.95rem; margin-bottom: 0.75rem; }
.btn-run { background: #2563eb; color: #fff; border: none;
           padding: 0.55rem 1.25rem; border-radius: 8px;
           font-weight: 600; cursor: pointer; font-size: 0.9rem;
           margin-top: 0.5rem; }
.btn-run:hover { background: #1d4ed8; }
.btn-run.htmx-request { opacity: 0.7; cursor: wait; }
.result-panel { min-height: 1.5rem; margin-top: 0.75rem; }
.result-ok { color: #4ade80; font-family: monospace; }
.result-fail { color: #f87171; font-family: monospace; }
.result-error { color: #f87171; background: #2d1b1b;
                padding: 0.5rem 0.75rem; border-radius: 6px;
                font-family: monospace; font-size: 0.85rem;
                white-space: pre-wrap; }
.result-line { padding: 0.25rem 0; font-size: 0.9rem; }
.metrics { color: #64748b; font-size: 0.8rem; margin-top: 0.5rem; }
.badge-pass { background: #16a34a; color: white;
              padding: 0.15rem 0.6rem; border-radius: 999px;
              font-size: 0.75rem; }")

(defun notebook-url-id (nb)
  (string-downcase (symbol-name (notebook-id nb))))

(defun render (notebook)
  "Render the full notebook page."
  (with-html-string
    (:doctype)
    (:html
     (:head
      (:meta :charset "utf-8")
      (:title (format nil "~A — SICP ~A"
                      (notebook-title notebook)
                      (notebook-chapter notebook)))
      (:style (:raw *styles*))
      (:script :src "https://unpkg.com/htmx.org@1.9.10"))
     (:body :data-notebook-id (notebook-url-id notebook)
      (:main
       (:div :class "breadcrumb"
             (:a :href "/wardlisp/" "WardLisp") " > "
             (:a :href "/wardlisp/learn" "SICPコース") " > "
             (notebook-chapter notebook))
       (:h1 (notebook-title notebook))
       (:p :class "summary" (notebook-summary notebook))
       (loop for cell in (notebook-cells notebook)
             for i from 0
             do (render-cell cell i (notebook-url-id notebook)))
       (:script :src "/static/js/learn.js"))))))

(defun render-cell (cell index nb-id)
  (ecase (cell-kind cell)
    (:prose (render-prose-cell cell))
    (:code-eval (render-code-cell cell index nb-id nil))
    (:code-exercise (render-code-cell cell index nb-id t))))

(defun render-prose-cell (cell)
  (with-html
    (:div :class "cell cell--prose"
          (let ((body (cell-body cell)))
            (cond
              ((stringp body) (:p body))
              ((and (listp body) (keywordp (first body)))
               ;; Inline spinneret DSL list like (:p "x" (:em "y"))
               (apply #'spinneret:interpret-html-tree (list body)))
              (t (princ body)))))))

(defun render-code-cell (cell index nb-id exercise-p)
  (let ((cell-dom (format nil "cell-~D" index))
        (textarea-id (format nil "code-~D" index))
        (result-id (format nil "cell-~D-result" index)))
    (with-html
      (:div :class (format nil "cell cell--code~:[~; cell--exercise~]" exercise-p)
            :id cell-dom
            :data-cell-id (symbol-name (cell-id cell))
            (when exercise-p
              (:div :class "cell__desc" (cell-description cell)))
            (:form :hx-post (format nil "/wardlisp/learn/~A/cells/~D/run"
                                    nb-id index)
                   :hx-target (format nil "#~A" result-id)
                   :hx-include ".notebook-code"
                   :hx-swap "innerHTML"
                   (:textarea :class "notebook-code"
                              :name "codes[]"
                              :id textarea-id
                              :rows 4
                              :style "width:100%;background:#0f172a;color:#e2e8f0;
                                      border:1px solid #334155;border-radius:6px;
                                      font-family:'SF Mono',monospace;padding:0.5rem;"
                              (cell-body cell))
                   (:button :type "submit" :class "btn-run" "Run"))
            (:div :class "result-panel" :id result-id)))))

(defun render-cell-result (result)
  "HTMX fragment: one cell's result panel."
  (with-html-string
    (ecase (notebook-cell-result-status result)
      (:ok
       (:div :class "result-ok"
             (:code "=> " (notebook-cell-result-value result))))
      (:pass
       (:div :class "result-ok"
             (:span :class "badge-pass" "PASS")
             " 全テスト合格"))
      (:fail
       (:div :class "result-fail"
             "一部のテストが失敗しました")
         (render-test-results (notebook-cell-result-test-results result)))
      (:error
       (:pre :class "result-error"
             (notebook-cell-result-error-message result)))
      (:limit-exceeded
       (:pre :class "result-error"
             "実行上限に達しました: "
             (notebook-cell-result-error-message result))))
    (when-let* ((print-output (notebook-cell-result-print-output result))
                (has-output (and print-output (plusp (length print-output)))))
      (:pre :class "result-ok" :style "background:#0f172a;padding:0.5rem;"
            print-output))))

(defun when-let* (bindings &body body)
  (declare (ignore bindings body))
  nil) ; placeholder — replace with alexandria:when-let* if needed

(defun render-test-results (results)
  (with-html
    (:ul :style "list-style:none;padding:0;"
         (dolist (tr results)
           (:li :class "result-line"
                (if (getf tr :passed)
                    (:span :class "result-ok" "✓")
                    (:span :class "result-fail" "✗"))
                " "
                (:code (getf tr :input))
                " — expected "
                (:code (getf tr :expected))
                " got "
                (:code (or (getf tr :actual) "<error>")))))))
```

**注記:** `when-let*` は alexandria にある。ファイル冒頭の `:import-from` に `#:alexandria #:when-let*` を追加し、自前実装は削る。spinneret は 2.x 系なら `:raw` や `:tag` で DSL を出力できる。prose セルの `body` は spinneret の DSL リストそのままを埋め込むため、`interpret-html-tree` 相当(spinneret の場合は `:tag` を `eval` で展開する手法も可)を使う。`:p` などのキーワードが渡されるので、spinneret のリテラルフォーム展開に適合する形に実装時に調整する。

**Step 2: ASDF 追加**

`recurya.asd` に `"recurya/web/ui/notebook"` を learn-home の直後に追加。

**Step 3: 読込確認**

```lisp
(asdf:load-system :recurya/web/ui/notebook)
(recurya/web/ui/notebook:render
 (first (recurya/game/notebooks/registry:all-notebooks)))
;; 長い HTML 文字列が返ればOK
```

**Step 4: コミット**

```bash
git add web/ui/notebook.lisp recurya.asd
git commit -m "$(cat <<'EOF'
Add notebook page UI (render and render-cell-result)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: ルート追加 `web/routes-wardlisp.lisp`

**Files:**
- Modify: `web/routes-wardlisp.lisp`

**Step 1: 現行 `defpackage` の `:import-from` に notebook 関連を追加**

`lisp-patch-form` で `defpackage` 内に:
```lisp
  (:import-from #:recurya/game/notebook
                #:run-cell
                #:notebook-id
                #:notebook-cells
                #:cell-kind)
  (:import-from #:recurya/game/notebooks/registry
                #:get-notebook
                #:all-notebooks)
```

**Step 2: 3 つのハンドラを `setup-wardlisp-routes` の直前に `lisp-edit-form` で `insert_before`**

```lisp
(defun learn-home-handler (params)
  "GET /wardlisp/learn - SICP course index."
  (declare (ignore params))
  (html-response (recurya/web/ui/learn-home:render (all-notebooks))))

(defun notebook-page-handler (params)
  "GET /wardlisp/learn/:id - Notebook page."
  (let* ((id (get-path-param params :id))
         (nb (and id (get-notebook id))))
    (if nb
        (html-response (recurya/web/ui/notebook:render nb))
        (html-response "<h1>404</h1>" :status 404))))

(defun notebook-cell-run-handler (params)
  "POST /wardlisp/learn/:id/cells/:index/run - HTMX fragment for one cell."
  (let* ((id (get-path-param params :id))
         (nb (and id (get-notebook id)))
         (index-str (get-path-param params :index))
         (index (and index-str (parse-integer index-str :junk-allowed t)))
         (codes (cdr (assoc "codes[]" params :test #'string=))))
    (cond
      ((not nb) (html-response "Notebook not found" :status 404))
      ((not index) (html-response "Invalid index" :status 400))
      ((or (< index 0) (>= index (length (notebook-cells nb))))
       (html-response "Index out of range" :status 400))
      ((eq (cell-kind (nth index (notebook-cells nb))) :prose)
       (html-response "Cannot run a prose cell" :status 400))
      (t
       (let* ((codes-list (cond ((listp codes) codes)
                                ((stringp codes) (list codes))
                                (t '())))
              (result (run-cell nb index codes-list))
              (body (recurya/web/ui/notebook:render-cell-result result))
              (response (html-response body)))
         (when (eq (recurya/game/notebook:notebook-cell-result-status result) :pass)
           (push (cons "HX-Trigger"
                       (format nil
                               "{\"cell-passed\":{\"notebook\":\"~A\",\"cell\":\"~A\"}}"
                               (string-downcase (symbol-name id))
                               (string-downcase
                                (symbol-name
                                 (recurya/game/notebook:notebook-cell-result-cell-id
                                  result)))))
                 (getf response :headers)))
         response)))))
```

**注記:** `html-response` のシグネチャ・戻り値 shape は既存実装に合わせる(`web/routes-wardlisp.lisp:33` 参照)。`HX-Trigger` ヘッダ挿入方法は Ningle/Clack のレスポンス表現に依存。既存ハンドラが ring-style list を返しているなら `(list status headers body)` を組み立てて返す書き方に合わせる。

**Step 3: `setup-wardlisp-routes` 内に 3 行追加**

`lisp-patch-form` で:
```
  (setf (ningle/app:route app "/wardlisp/playground")
```
の直前(または後ろ)に:
```lisp
  (setf (ningle/app:route app "/wardlisp/learn")
        (make-dynamic-handler 'learn-home-handler))
  (setf (ningle/app:route app "/wardlisp/learn/:id")
        (make-dynamic-handler 'notebook-page-handler))
  (setf (ningle/app:route app "/wardlisp/learn/:id/cells/:index/run" :method :post)
        (make-dynamic-handler 'notebook-cell-run-handler))
```

**Step 4: 読込 + 手動確認**

```lisp
(asdf:load-system :recurya/web/routes-wardlisp :force t)
;; 稼働中のアプリのルートを再セットアップ(存在する関数で)
```

コンテナが起動していれば http://localhost:3000/wardlisp/learn をブラウザで開ける。

**Step 5: コミット**

```bash
git add web/routes-wardlisp.lisp
git commit -m "$(cat <<'EOF'
Add /wardlisp/learn routes and handlers

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: 実機動作確認(手動)

**Files:** (変更なし)

**Step 1: コンテナ起動確認**

```bash
docker compose ps
```
`recurya` が Up でなければ `docker compose --profile app up -d` を実行。

**Step 2: ホットリロード**

```lisp
(asdf:load-system :recurya :force t)
```
`repl-eval` で実行。もし既存サーバに新ルートが反映されなければ `(recurya/web/routes-wardlisp:setup-wardlisp-routes recurya/web/app:*app*)` 相当を呼ぶ(実関数名は既存コードに合わせる)。

**Step 3: ブラウザで動作確認**

ユーザに依頼して以下をチェック:
- `http://localhost:3000/wardlisp/learn` でコース一覧が表示される
- `http://localhost:3000/wardlisp/learn/sicp-1-1-1` でセル列が表示される
- code-eval セルの Run で値が表示される
- code-exercise セルに `(+ 137 349 22)` と書いて Run → PASS
- 間違った式を書いて Run → FAIL
- 無限ループ `(define (f) (f)) (f)` を書いて Run → エラー

**Step 4: 見つかった不具合を Task N.x として追記して修正**

主な検証観点:
- prose セルの spinneret DSL が正しく展開されるか
- CodeMirror を組み込んでいないが素の textarea で動くか(MVPではまず textarea でOK)
- `HX-Trigger` ヘッダが送られているか(DevTools Network タブで確認)

**Step 5: コミットなし**(確認のみ)

---

## Task 14: CodeMirror 統合(既存コンポーネント利用)

**Files:**
- Modify: `web/ui/notebook.lisp`

**Step 1: `web/ui/editor.lisp` の公開 API を調査(`lisp-read-file`)**

関数名・使用方法を確認する。

**Step 2: `render-code-cell` の `:textarea` を editor コンポーネント呼び出しに差し替え**

既存 `web/ui/puzzle.lisp` の render で editor をどう呼んでいるかを参考に揃える。

**Step 3: 手動確認**

- ブラウザで編集できる
- `.notebook-code` クラスの textarea 内容が CodeMirror と同期される

**Step 4: コミット**

```bash
git add web/ui/notebook.lisp
git commit -m "$(cat <<'EOF'
Integrate CodeMirror editor into notebook cells

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: SICP 1.1.2 ノートブック追加

**Files:**
- Create: `game/notebooks/sicp-1-1-2.lisp`
- Create: `tests/game/notebooks/sicp-1-1-2.lisp`
- Modify: `game/notebooks/registry.lisp`
- Modify: `recurya.asd`

**Step 1: テスト先行作成**

`tests/game/notebooks/sicp-1-1-2.lisp`:
```lisp
(defpackage #:recurya/tests/game/notebooks/sicp-1-1-2
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-1-2
                #:make-sicp-1-1-2-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id))

(in-package #:recurya/tests/game/notebooks/sicp-1-1-2)

(deftest sicp-1-1-2-structure
  (testing "notebook has unique cell ids"
    (let* ((nb (make-sicp-1-1-2-notebook))
           (ids (mapcar #'cell-id (notebook-cells nb))))
      (ok (= (length ids) (length (remove-duplicates ids)))))))
```

**Step 2: ノートブック本体作成**

Design doc「`sicp-1-1-2.lisp` — 1.1.2 命名と環境」のセル表に従う。Task 0 スパイクの結果を元に `expected` を記入(円面積は `(* 3.14 10 10)` の `print-value`)。

**Step 3: ASDF と registry に追加**

`registry.lisp` の `*notebooks*` list と `:import-from` を更新:
```lisp
(:import-from #:recurya/game/notebooks/sicp-1-1-2 #:make-sicp-1-1-2-notebook)
...
(defparameter *notebooks*
  (list (make-sicp-1-1-1-notebook)
        (make-sicp-1-1-2-notebook)))
```

`recurya.asd` の `recurya` / `recurya/tests` 両方に新モジュールを登録。

**Step 4: テスト実行 + スモーク**

```lisp
(asdf:load-system :recurya :force t)
(rove:run :recurya/tests/game/notebooks/sicp-1-1-2)
```

模範解答でも run-cell が `:pass` を返すか `repl-eval` で確認。

**Step 5: ブラウザで表示確認**

`http://localhost:3000/wardlisp/learn/sicp-1-1-2`

**Step 6: コミット**

```bash
git add game/notebooks/sicp-1-1-2.lisp tests/game/notebooks/sicp-1-1-2.lisp \
        game/notebooks/registry.lisp recurya.asd
git commit -m "$(cat <<'EOF'
Add SICP 1.1.2 notebook (Naming and the Environment)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 16: SICP 1.1.3 ノートブック追加

**Files:**
- Create: `game/notebooks/sicp-1-1-3.lisp`
- Create: `tests/game/notebooks/sicp-1-1-3.lisp`
- Modify: `game/notebooks/registry.lisp`
- Modify: `recurya.asd`

Task 15 と同じ手順。Design doc「`sicp-1-1-3.lisp` — 1.1.3 演算子の組合せ評価」のセル表に従う。演習セルの `expected` は Task 0 スパイクの `(f 2 3 4 10 5)` 結果に合わせる(整数除算か有理数か浮動小数か)。

**Step 1-6: Task 15 と同じパターン**

**Step 7: コミット**

```bash
git add game/notebooks/sicp-1-1-3.lisp tests/game/notebooks/sicp-1-1-3.lisp \
        game/notebooks/registry.lisp recurya.asd
git commit -m "$(cat <<'EOF'
Add SICP 1.1.3 notebook (Evaluating Combinations)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 17: `learn.js` + localStorage 進捗管理

**Files:**
- Create: `resources/static/js/learn.js`

**Step 1: `fs-write-file` で作成**

```javascript
// resources/static/js/learn.js
// Progress tracking for SICP notebook course, local-only.

const STORAGE_KEY = 'recurya:learn:v1';

function loadProgress() {
  try { return JSON.parse(localStorage.getItem(STORAGE_KEY)) || {}; }
  catch (_) { return {}; }
}

function saveProgress(obj) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(obj));
}

function updateProgress(notebookId, cellId) {
  const p = loadProgress();
  if (!p[notebookId]) p[notebookId] = { passed: [], last_visited_at: null };
  if (!p[notebookId].passed.includes(cellId)) {
    p[notebookId].passed.push(cellId);
  }
  p[notebookId].last_visited_at = new Date().toISOString();
  saveProgress(p);
}

function markBadge(cellNode) {
  if (cellNode.querySelector('.progress-badge')) return;
  const b = document.createElement('span');
  b.className = 'progress-badge';
  b.textContent = '✓ done';
  b.style.cssText =
    'float:right;background:#16a34a;color:#fff;' +
    'padding:2px 8px;border-radius:999px;font-size:0.75rem;';
  cellNode.prepend(b);
}

function markCompletedCells(notebookId) {
  const p = loadProgress();
  const nb = p[notebookId];
  if (!nb) return;
  for (const cellId of nb.passed) {
    const cell = document.querySelector(
      `[data-cell-id="${CSS.escape(cellId.toUpperCase())}"]`);
    if (cell) markBadge(cell);
  }
}

document.addEventListener('DOMContentLoaded', () => {
  const nbId = document.body.dataset.notebookId;
  if (nbId) markCompletedCells(nbId);
});

document.body.addEventListener('cell-passed', (e) => {
  const detail = e.detail || {};
  const nb = detail.notebook;
  const cell = detail.cell;
  if (!nb || !cell) return;
  updateProgress(nb, cell);
  const node = document.querySelector(
    `[data-cell-id="${CSS.escape(cell.toUpperCase())}"]`);
  if (node) markBadge(node);
});
```

**Step 2: 静的ファイル配信パスの確認**

`web/app.lisp` で `resources/static/*` がどうマウントされているか `lisp-read-file` で確認。既存が `/static/*` → `resources/static/*` ならそのまま。マウントされていなければ Lack の `static` ミドルウェア追加が必要(別タスクに切り出す可能性あり)。

**Step 3: ブラウザで確認**

- 演習を通すと `✓ done` バッジが付く
- ページをリロードするとバッジが残る
- DevTools で `localStorage.getItem('recurya:learn:v1')` を読んで JSON が入っている

**Step 4: コミット**

```bash
git add resources/static/js/learn.js
git commit -m "$(cat <<'EOF'
Add learn.js for localStorage-based course progress

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 18: ルートテスト `tests/web/learn-routes.lisp`

**Files:**
- Create: `tests/web/learn-routes.lisp`
- Modify: `recurya.asd`

**Step 1: 既存の `tests/web/routes.lisp` のテスト構築方法を `lisp-read-file` で参考にする**

clack-test の使い方・authentication の扱い(このコースは未認証でアクセス可能)を確認。

**Step 2: `fs-write-file` で作成**

```lisp
;;;; tests/web/learn-routes.lisp --- HTTP-level tests for /wardlisp/learn routes.

(defpackage #:recurya/tests/web/learn-routes
  (:use #:cl #:rove)
  (:import-from #:clack.test #:testing-app #:http-request))

(in-package #:recurya/tests/web/learn-routes)

;; テスト用に app を立ち上げるヘルパは tests/web/routes.lisp の作法を踏襲する。
;; 以下は骨格。

(deftest learn-home-ok
  (testing "GET /wardlisp/learn returns 200"
    ;; (setup app), call http-request, check status
    (pass "TODO")))

(deftest notebook-page-ok
  (testing "GET /wardlisp/learn/sicp-1-1-1 returns 200"
    (pass "TODO")))

(deftest cell-run-exercise-pass
  (testing "POST .../cells/N/run returns fragment with PASS status"
    (pass "TODO")))

(deftest cell-run-index-out-of-range
  (testing "index out of range returns 400"
    (pass "TODO")))

(deftest cell-run-prose-rejected
  (testing "running a prose cell returns 400"
    (pass "TODO")))
```

実装時に `tests/web/routes.lisp` の具体的なセットアップを参考にテストを肉付けする。

**Step 3: ASDF 追記**

`recurya.asd` の `recurya/tests` に:
```
"recurya/tests/web/learn-routes"
```

**Step 4: 実行**

Run: `run-tests` `{"system": "recurya/tests/web/learn-routes"}`
Expected: PASS

**Step 5: フルテストスイート実行**

```lisp
(asdf:test-system :recurya)
```
既存テストに回帰がないことを確認。

**Step 6: コミット**

```bash
git add tests/web/learn-routes.lisp recurya.asd
git commit -m "$(cat <<'EOF'
Add route tests for /wardlisp/learn

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 19: 最終確認とドキュメント

**Files:**
- Modify(optional): `README.md` — コースのエントリポイント URL を記載

**Step 1: フルテスト**

```bash
docker compose exec recurya qlot exec ros run \
  -e '(ql:quickload :recurya/tests)' \
  -e '(asdf:test-system :recurya)' -q
```

すべて PASS することを確認。

**Step 2: ブラウザで 3 ノートブック通しで確認**

- `/wardlisp/learn` 一覧 → 3 コース表示、完了バッジが localStorage から反映
- 1.1.1 / 1.1.2 / 1.1.3 を通しで演習し、すべて PASS を出せる
- 他ページ(`/wardlisp/`, `/wardlisp/puzzle/*`, `/wardlisp/arena`, `/wardlisp/playground`, `/wardlisp/reference`)が壊れていないことを目視確認

**Step 3: README にリンク追記(任意)**

`README.md` に「SICP ノートブック `/wardlisp/learn`」のエントリを追加する場合は1行。

**Step 4: コミット**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
Link SICP course from README

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## スパイク結果メモ(Task 0 で記入)

Task 0 実行時にここに追記する:

- `(define (f x) ...)` — ☐ 動く / ☐ 動かない(動かない場合は `(define f (lambda (x) ...))` へ)
- `(/ 10 5)` → `"?"`
- `(/ 10 3)` → `"?"`
- `(* 3.14 10 10)` → `"?"`
- `(/ (+ 2 (* 3 4)) (- 10 5))` → `"?"`

以降の各演習の `expected` 値は上記の print-value に合わせる。

---

## 失敗時のリカバリ

- Lisp ファイル編集後にパッケージ不整合: `pool-kill-worker` で worker を kill し再起動
- モジュール未認識: `(asdf:clear-system :recurya)` → `(asdf:load-system :recurya :force t)`
- ホットリロードで route が更新されない: 開発中は `(ningle/app:clear-routing-rules ...)` 相当で一旦クリアするか、最終手段としてユーザに `docker compose restart recurya` を依頼(cl-mcp 再接続も伝える)

## 完了基準

- `docker compose exec recurya qlot exec ros run ... (asdf:test-system :recurya)` がグリーン
- ブラウザで 3 ノートブックすべてを通しで動作確認完了
- 既存 URL 空間(`/wardlisp/`、`/wardlisp/puzzle/*` 等)に回帰がない
- `docs/plans/2026-04-24-sicp-notebook-mvp-design.md` の「非対象」セクションに挙げた項目には手を付けていない
