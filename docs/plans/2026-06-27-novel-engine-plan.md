# ノベルゲーム基盤 実装プラン

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Notebook の `===scene===` セルに書いた wardlisp 式を、読者フラグを注入して評価し、返り値（演出ディレクティブ）をビート列に変換してクリック送りで再生する、読者状態を跨セッション保存するノベルゲーム基盤を作る。

**Architecture:** シーン式は wardlisp（サンドボックス）で評価し、返り値の ocons ツリーをホストが走査してプレーンなディレクティブ列にし、純関数インタプリタがビート列へ平坦化、HTMX で逐次再生する。読者状態（フラグ＋位置）は per-user オーバーレイ（`learn_*` の一般化）で保存。

**Tech Stack:** Common Lisp/SBCL + qlot、Mito ORM + cl-dbi(PostgreSQL)、Ningle/Clack、Spinneret + HTMX、wardlisp(サンドボックス評価)、Rove。新規依存なし。

**Reference:** 設計 [`2026-06-27-novel-engine-design.md`](./2026-06-27-novel-engine-design.md) / wardlisp 要件 [`2026-06-27-wardlisp-extension-requirements.md`](./2026-06-27-wardlisp-extension-requirements.md)。

---

## 規約・前提

- **Lispツール規約:** `.lisp`/`.asd` は cl-mcp ツール（`lisp-edit-form`/`lisp-patch-form`/`lisp-read-file`/`lisp-check-parens`/`repl-eval`/`load-system`/`run-tests`）。Read/Edit/Write/Grep/Glob を Lisp ファイルに使わない。Markdown/SQL/シェルは通常ツール可。`fs-write-file` は**新規ファイルのみ**（既存上書き不可。置換は `git rm`→`fs-write-file` か `lisp-edit-form`）。
- **初期セットアップ:** 各セッション冒頭で `mcp__cl-mcp__fs-set-project-root {"path":"."}`。
- **DB前提:** DB連動テストは PostgreSQL がローカル15434で起動していること（`docker compose up -d`、スキーマ適用済み）。`lisp-edit-form` は `delete`/`replace`/`insert_before`/`insert_after` を持ち、`content` は**1フォームのみ**。
- **ブランチ:** `feat/novel-engine`（作成済み）。
- **コミット方針:** 1タスク1コミット。プレフィックス `feat:`/`test:`/`refactor:`/`chore:`。末尾に `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` を付与（2つ目の `-m`）。

## フェーズと依存

- **P1（wardlisp 非依存・先行可）**: Task 1〜3。`===scene===` パーサ、ビートインタプリタ（純関数）、プレイヤーUI雛形。
- **P2（wardlisp 文字列拡張に依存）**: Task 4〜9。**前提:** [wardlisp 要件](./2026-06-27-wardlisp-extension-requirements.md) R1（文字列型）・R2（`string-append`/`number->string`）・R3（`:wardlisp` から `ocons-p/ocons-ocar/ocons-ocdr/string-value-p/string-value`）が masatoi/wardlisp に実装済みであること。R4（`evaluate` の `:bindings`）は任意で、無い場合は文字列前置にフォールバック（Task 5 に両対応を記載）。

## ファイル構成

| ファイル | 役割 | 区分 | フェーズ |
|---|---|---|---|
| `game/notebook-parser.lisp` | `===scene===` フェンスの parse/render | 変更 | P1 |
| `tests/game/notebook-parser.lisp` | scene round-trip テスト | 変更 | P1 |
| `game/novel/interpreter.lisp` | ディレクティブ列→ビート列（純関数） | 新規 | P1 |
| `tests/game/novel/interpreter.lisp` | インタプリタテスト | 新規 | P1 |
| `web/ui/novel.lisp` | プレイヤーUI（ビート列→HTML+JS） | 新規 | P1 |
| `game/novel/value.lisp` | wardlisp 結果(ocons)→プレーンデータ走査 | 新規 | P2 |
| `tests/game/novel/value.lisp` | 走査テスト | 新規 | P2 |
| `game/novel/eval.lisp` | プレリュード＋フラグ注入＋評価＋走査 | 新規 | P2 |
| `tests/game/novel/eval.lisp` | 評価テスト | 新規 | P2 |
| `models/novel-state.lisp` | 読者状態テーブル | 新規 | P2 |
| `db/novel.lisp` | 読者状態 CRUD | 新規 | P2 |
| `db/migrations/*-novel-state.*.sql` | マイグレーション | 新規 | P2 |
| `web/routes-novel.lisp` | Play/advance ハンドラ＋ルート登録 | 新規 | P2 |
| `tests/web/novel-routes.lisp` | ルートテスト | 新規 | P2 |
| `tests/integration/novel-sample.lisp` | サンプルnovel 通し | 新規 | P2 |
| `recurya.asd` | 新モジュール登録 | 変更 | P1/P2 |

## データ表現（全タスク共通の約束）

- **ディレクティブ（プレーンデータ）**: キーワード頭のリスト。`(:scene <dir>…)` `(:bg <文字列>)` `(:narrate <文字列>)` `(:say <話者文字列> <本文文字列>)` `(:set-flag <flag-keyword> [<値>])`。
- **ビート**: plist。`(:type :say :speaker "アリス" :text "やあ" :bg "classroom")` / `(:type :narrate :text "…" :bg "classroom")`。
- **set-flags**: `(cons flag-keyword 値)` のリスト。
- **走査(P2)** が wardlisp 結果を上記プレーンデータへ変換する（シンボル→キーワード、wardlisp文字列→CL文字列、ocons→CLリスト）。

---

# フェーズ P1（wardlisp 非依存）

## Task 1: `===scene===` セルのパーサ対応＋round-trip

**Files:** Modify `game/notebook-parser.lisp`, `tests/game/notebook-parser.lisp`

- [ ] **Step 1: round-trip 失敗テストを追加**

`lisp-edit-form file_path="tests/game/notebook-parser.lisp" form_type="deftest" form_name="<既存の最後のdeftest名>" operation="insert_after"` で挿入（既存ファイルの最後の deftest 名は `lisp-read-file collapsed=true` で確認してから指定）:

```lisp
(deftest scene-cell-roundtrip
  (let* ((body "===scene===
(list (list 'say \"アリス\" \"やあ\"))")
         (cells (parse-notebook-body body)))
    (ok (= 1 (length cells)))
    (ok (eq :scene (cell-kind (first cells))))
    (ok (search "(list 'say" (cell-body (first cells))))
    ;; render back and re-parse: kind/body stable
    (let* ((md (cells->body-md cells))
           (cells2 (parse-notebook-body md)))
      (ok (eq :scene (cell-kind (first cells2))))
      (ok (string= (cell-body (first cells)) (cell-body (first cells2)))))))
```

- [ ] **Step 2: テスト実行 — FAIL 確認**

`run-tests system="recurya/tests/game/notebook-parser" test="recurya/tests/game/notebook-parser::scene-cell-roundtrip"`
Expected: FAIL（`===scene===` が未知ヘッダ→セル化されない or render の ecase で落ちる）。

- [ ] **Step 3: `parse-fence-header` に scene 分岐を追加**

`lisp-patch-form file_path="game/notebook-parser.lisp" form_type="defun" form_name="parse-fence-header"`:
- old_text: `((string= line "===eval===")  (values :code-eval nil))`
- new_text:
```
((string= line "===eval===")  (values :code-eval nil))
    ((string= line "===scene===") (values :scene nil))
```

- [ ] **Step 4: `render-cell` の ecase に scene 分岐を追加**

`lisp-patch-form file_path="game/notebook-parser.lisp" form_type="defun" form_name="render-cell"`:
- old_text: `(:code-eval     (write-string "===eval===" stream))`
- new_text:
```
(:code-eval     (write-string "===eval===" stream))
      (:scene         (write-string "===scene===" stream))
```

- [ ] **Step 5: 再ロードしてテスト PASS**

`load-system system="recurya/game/notebook-parser" force=true` の後
`run-tests system="recurya/tests/game/notebook-parser"`
Expected: 全 PASS（既存＋ `scene-cell-roundtrip`）。

- [ ] **Step 6: コミット**

```bash
git add game/notebook-parser.lisp tests/game/notebook-parser.lisp
git commit -m "feat: parse and render ===scene=== notebook cells" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: ビートインタプリタ（純関数）

**Files:** Create `game/novel/interpreter.lisp`, `tests/game/novel/interpreter.lisp`; Modify `recurya.asd`, `tests/all.lisp`（テスト登録があれば）

- [ ] **Step 1: モジュール雛形を作成**

`fs-write-file path="game/novel/interpreter.lisp"`:
```lisp
;;;; game/novel/interpreter.lisp --- Flatten resolved novel directives into beats.
;;;;
;;;; Pure, wardlisp-independent. Input is "directive data" (keyword-headed
;;;; lists) already resolved by the scene evaluator (so conditionals are
;;;; gone). Output is an ordered beat list plus collected flag changes.

(defpackage #:recurya/game/novel/interpreter
  (:use #:cl)
  (:export #:interpret-directives))

(in-package #:recurya/game/novel/interpreter)

(defun interpret-directives (directives)
  (declare (ignore directives))
  (error "not implemented"))
```

- [ ] **Step 2: `.asd` 登録**

`lisp-patch-form file_path="recurya.asd" form_type="defsystem" form_name="recurya"`:
- old_text: `               "recurya/game/notebook-parser"`
- new_text:
```
               "recurya/game/notebook-parser"
               "recurya/game/novel/interpreter"
```

- [ ] **Step 3: 失敗テストを作成**

`fs-write-file path="tests/game/novel/interpreter.lisp"`:
```lisp
;;;; tests/game/novel/interpreter.lisp
(defpackage #:recurya/tests/game/novel/interpreter
  (:use #:cl #:rove)
  (:import-from #:recurya/game/novel/interpreter #:interpret-directives))

(in-package #:recurya/tests/game/novel/interpreter)

(deftest flattens-say-narrate-with-bg
  (multiple-value-bind (beats set-flags)
      (interpret-directives
       '((:bg "classroom")
         (:narrate "教室には誰もいない。")
         (:say "アリス" "おはよう！")
         (:set-flag :met-alice)))
    (ok (= 2 (length beats)))
    (ok (equal (first beats)
               '(:type :narrate :text "教室には誰もいない。" :bg "classroom")))
    (ok (equal (second beats)
               '(:type :say :speaker "アリス" :text "おはよう！" :bg "classroom")))
    (ok (equal set-flags '((:met-alice . t))))))

(deftest scene-grouping-and-bg-persists
  (multiple-value-bind (beats set-flags)
      (interpret-directives
       '((:scene (:bg "room") (:say "A" "1"))
         (:say "A" "2")
         (:set-flag :x 5)))
    (declare (ignore set-flags))
    (ok (= 2 (length beats)))
    ;; bg set inside scene persists to the following say
    (ok (string= "room" (getf (first beats) :bg)))
    (ok (string= "room" (getf (second beats) :bg)))))

(deftest unknown-directive-ignored
  (multiple-value-bind (beats set-flags)
      (interpret-directives '((:bogus 1 2) (:narrate "ok") "junk"))
    (declare (ignore set-flags))
    (ok (= 1 (length beats)))
    (ok (string= "ok" (getf (first beats) :text)))))
```

（テストランナー登録: `tests/all.lisp` と `recurya/tests` の depends-on に `recurya/tests/game/novel/interpreter` を足す必要があれば `lisp-patch-form` で追加。`run-tests system=` 単体指定なら不要。）

- [ ] **Step 4: テスト実行 — FAIL 確認**

`run-tests system="recurya/tests/game/novel/interpreter"`
Expected: 3件 FAIL（`not implemented`）。

- [ ] **Step 5: 実装で置換**

`lisp-edit-form file_path="game/novel/interpreter.lisp" form_type="defun" form_name="interpret-directives" operation="replace"`:
```lisp
(defun interpret-directives (directives)
  "DIRECTIVES: list of keyword-headed directive forms (already resolved).
   Returns (values BEATS SET-FLAGS).
   BEATS: list of plists (:type :say|:narrate ...).
   SET-FLAGS: list of (flag-keyword . value)."
  (let ((beats '()) (set-flags '()) (current-bg nil))
    (labels ((walk (dirs)
               (dolist (d dirs)
                 (when (consp d)
                   (case (first d)
                     (:scene (walk (rest d)))
                     (:bg (setf current-bg (second d)))
                     (:narrate
                      (push (list :type :narrate :text (second d) :bg current-bg)
                            beats))
                     (:say
                      (push (list :type :say :speaker (second d) :text (third d)
                                  :bg current-bg)
                            beats))
                     (:set-flag
                      (push (cons (second d) (if (cddr d) (third d) t)) set-flags))
                     (t nil))))))
      (walk directives))
    (values (nreverse beats) (nreverse set-flags))))
```

- [ ] **Step 6: 再ロードしてテスト PASS**

`load-system system="recurya/game/novel/interpreter" force=true` の後
`run-tests system="recurya/tests/game/novel/interpreter"`
Expected: 3件 PASS。

- [ ] **Step 7: コミット**

```bash
git add game/novel/interpreter.lisp tests/game/novel/interpreter.lisp recurya.asd
git commit -m "feat: novel directive interpreter (directives -> beats)" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: プレイヤーUI雛形（ビート列→HTML+JS）

**Files:** Create `web/ui/novel.lisp`; Modify `recurya.asd`

- [ ] **Step 1: モジュール作成（最小実装）**

`fs-write-file path="web/ui/novel.lisp"`:
```lisp
;;;; web/ui/novel.lisp --- Novel player view (renders beats, click-to-advance).
(defpackage #:recurya/web/ui/novel
  (:use #:cl)
  (:import-from #:spinneret #:with-html-string)
  (:import-from #:recurya/utils/common #:json->string)
  (:export #:render-player))

(in-package #:recurya/web/ui/novel)

(defun %beats->json (beats)
  "Serialize BEATS (list of plists) to a JSON array string for the client."
  (json->string
   (mapcar (lambda (b)
             (let ((h (make-hash-table :test 'equal)))
               (setf (gethash "type" h) (string-downcase (symbol-name (getf b :type)))
                     (gethash "speaker" h) (or (getf b :speaker) "")
                     (gethash "text" h) (or (getf b :text) "")
                     (gethash "bg" h) (or (getf b :bg) ""))
               h))
           beats)))

(defun render-player (&key title beats)
  "Render a minimal novel player page. BEATS is a list of beat plists."
  (with-html-string
    (:div :class "novel-player"
          :data-beats (%beats->json beats)
      (:div :class "novel-bg" :id "novel-bg")
      (:div :class "novel-box"
        (:div :class "novel-speaker" :id "novel-speaker")
        (:div :class "novel-text" :id "novel-text")
        (:button :type "button" :class "novel-next" :id "novel-next" "▶"))
      (:noscript (:p title))
      (:script :type "text/javascript"
        (:raw "(function(){
  var root=document.querySelector('.novel-player');
  var beats=JSON.parse(root.getAttribute('data-beats')||'[]');
  var i=-1;
  var bg=document.getElementById('novel-bg');
  var sp=document.getElementById('novel-speaker');
  var tx=document.getElementById('novel-text');
  function show(n){var b=beats[n]; if(!b){tx.textContent='— おわり —'; sp.textContent=''; return;}
    bg.setAttribute('data-bg', b.bg||'');
    sp.textContent=(b.type==='say')?(b.speaker||''):'';
    tx.textContent=b.text||'';}
  function next(){ if(i<beats.length-1){i++; show(i);} }
  document.getElementById('novel-next').addEventListener('click',next);
  document.addEventListener('keydown',function(e){if(e.key===' '||e.key==='Enter'){e.preventDefault();next();}});
  next();
})();")))))
```

- [ ] **Step 2: `.asd` 登録**

`lisp-patch-form file_path="recurya.asd" form_type="defsystem" form_name="recurya"`:
- old_text: `               "recurya/web/ui/notebook"`
- new_text:
```
               "recurya/web/ui/notebook"
               "recurya/web/ui/novel"
```

- [ ] **Step 3: ロード＋スモーク（repl-eval）**

`load-system system="recurya/web/ui/novel"` の後 `repl-eval package="CL-USER"`:
```lisp
(let ((html (recurya/web/ui/novel:render-player
             :title "Demo"
             :beats '((:type :narrate :text "始まり" :bg "room")
                      (:type :say :speaker "アリス" :text "やあ" :bg "room")))))
  (list :len (length html)
        :has-box (and (search "novel-box" html) t)
        :has-beats (and (search "data-beats" html) t)))
```
Expected: `:has-box T :has-beats T`、`:len` は正の数（エラーなく文字列が返る）。

- [ ] **Step 4: コミット**

```bash
git add web/ui/novel.lisp recurya.asd
git commit -m "feat: minimal novel player view (beats + click-to-advance JS)" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

> P1 完了。ここまでは wardlisp 非依存で、パース→ビート→表示の骨格が通る（ビートは手書きデータでも再生可能）。以降の P2 は **wardlisp 文字列拡張の完了後**に着手する。

---

# フェーズ P2（wardlisp 文字列拡張に依存）

> 前提（必須）: `:wardlisp` から `ocons-p` / `ocons-ocar` / `ocons-ocdr` / `string-value-p` / `string-value` が利用可能で、`"..."` リテラルが評価・印字でき、`string-append`/`number->string` がある（要件 R1〜R3）。未充足なら本フェーズは着手不可。

## Task 4: 結果ウォーカ（wardlisp 結果→プレーンデータ）

**Files:** Create `game/novel/value.lisp`, `tests/game/novel/value.lisp`; Modify `recurya.asd`

- [ ] **Step 1: モジュール雛形**

`fs-write-file path="game/novel/value.lisp"`:
```lisp
;;;; game/novel/value.lisp --- Convert wardlisp result values into plain
;;;; directive data (keyword-headed lists, CL strings, integers).
(defpackage #:recurya/game/novel/value
  (:use #:cl)
  (:import-from #:wardlisp
                #:ocons-p #:ocons-ocar #:ocons-ocdr
                #:string-value-p #:string-value)
  (:export #:ward->directives #:+max-walk-depth+))

(in-package #:recurya/game/novel/value)

(defparameter +max-walk-depth+ 200
  "Maximum nesting depth when walking a wardlisp result tree.")

(defun ward->directives (value)
  (declare (ignore value))
  (error "not implemented"))
```

- [ ] **Step 2: `.asd` 登録**

`lisp-patch-form file_path="recurya.asd" form_type="defsystem" form_name="recurya"`:
- old_text: `               "recurya/game/novel/interpreter"`
- new_text:
```
               "recurya/game/novel/interpreter"
               "recurya/game/novel/value"
```

- [ ] **Step 3: 失敗テスト（wardlisp 評価結果を走査）**

`fs-write-file path="tests/game/novel/value.lisp"`:
```lisp
;;;; tests/game/novel/value.lisp
(defpackage #:recurya/tests/game/novel/value
  (:use #:cl #:rove)
  (:import-from #:recurya/game/novel/value #:ward->directives))

(in-package #:recurya/tests/game/novel/value)

(defun eval-ward (code)
  (multiple-value-bind (r m) (wardlisp:evaluate code)
    (when (getf m :error-message) (error "ward error: ~A" (getf m :error-message)))
    r))

(deftest walks-list-of-directives
  ;; (list (list 'bg "room") (list 'say "アリス" "やあ"))
  (let* ((result (eval-ward "(list (list 'bg \"room\") (list 'say \"アリス\" \"やあ\"))"))
         (dirs (ward->directives result)))
    (ok (equal dirs '((:bg "room") (:say "アリス" "やあ"))))))

(deftest walks-numbers-and-symbols
  (let* ((result (eval-ward "(list (list 'set-flag 'met-alice) (list 'set-flag 'count 3))"))
         (dirs (ward->directives result)))
    (ok (equal dirs '((:set-flag :met-alice) (:set-flag :count 3))))))
```

- [ ] **Step 4: テスト実行 — FAIL 確認**

`run-tests system="recurya/tests/game/novel/value"`
Expected: FAIL（`not implemented`）。

- [ ] **Step 5: 実装で置換**

`lisp-edit-form file_path="game/novel/value.lisp" form_type="defun" form_name="ward->directives" operation="replace"`:
```lisp
(defun %sym->keyword (s)
  "Convert a wardlisp symbol (CL string) to an uppercased keyword tag."
  (intern (string-upcase s) :keyword))

(defun %value->data (v depth)
  "Convert a single wardlisp value V to plain Lisp data."
  (when (> depth +max-walk-depth+)
    (error "novel/value: result nesting exceeds ~D" +max-walk-depth+))
  (cond
    ((ocons-p v) (%list->data v depth))
    ((string-value-p v) (string-value v))   ; wardlisp string -> CL string
    ((integerp v) v)
    ((null v) nil)
    ((eq v t) t)
    ((stringp v) (%sym->keyword v))          ; wardlisp symbol -> keyword
    (t v)))

(defun %list->data (v depth)
  "Convert a wardlisp ocons chain V to a CL list of plain data."
  (loop while (ocons-p v)
        collect (%value->data (ocons-ocar v) (1+ depth))
        do (setf v (ocons-ocdr v))))

(defun ward->directives (value)
  "Convert a wardlisp result VALUE (an ocons list of directive forms) into
   a CL list of keyword-headed directive forms with CL-string text."
  (if (ocons-p value)
      (%list->data value 0)
      ;; A non-list result is treated as a single (possibly empty) program.
      (let ((d (%value->data value 0)))
        (if (consp d) (list d) nil))))
```
（`lisp-edit-form` は1フォームのみのため、`%sym->keyword`/`%value->data`/`%list->data` は `ward->directives` の **insert_before** で個別に1つずつ追加し、最後に `ward->directives` 本体を `replace` する。）

- [ ] **Step 6: 再ロードしてテスト PASS**

`load-system system="recurya/game/novel/value" force=true` の後 `run-tests system="recurya/tests/game/novel/value"`
Expected: 2件 PASS。

- [ ] **Step 7: コミット**

```bash
git add game/novel/value.lisp tests/game/novel/value.lisp recurya.asd
git commit -m "feat: walk wardlisp result tree into plain novel directives" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: シーン評価（プレリュード＋フラグ注入＋evaluate＋走査）

**Files:** Create `game/novel/eval.lisp`, `tests/game/novel/eval.lisp`; Modify `recurya.asd`

- [ ] **Step 1: モジュール雛形**

`fs-write-file path="game/novel/eval.lisp"`:
```lisp
;;;; game/novel/eval.lisp --- Evaluate one scene's wardlisp source with the
;;;; reader's flags injected, returning resolved directive data.
(defpackage #:recurya/game/novel/eval
  (:use #:cl)
  (:import-from #:wardlisp #:evaluate)
  (:import-from #:recurya/game/novel/value #:ward->directives)
  (:export #:eval-scene #:*novel-fuel* #:*novel-max-cons*
           #:*novel-max-depth* #:*novel-timeout*))

(in-package #:recurya/game/novel/eval)

(defparameter *novel-fuel* 200000)
(defparameter *novel-max-cons* 50000)
(defparameter *novel-max-depth* 300)
(defparameter *novel-timeout* 5)

(defun eval-scene (scene-source &key prelude flags)
  (declare (ignore scene-source prelude flags))
  (error "not implemented"))
```

- [ ] **Step 2: `.asd` 登録**

`lisp-patch-form file_path="recurya.asd" form_type="defsystem" form_name="recurya"`:
- old_text: `               "recurya/game/novel/value"`
- new_text:
```
               "recurya/game/novel/value"
               "recurya/game/novel/eval"
```

- [ ] **Step 3: 失敗テスト（フラグで会話が変わる）**

`fs-write-file path="tests/game/novel/eval.lisp"`:
```lisp
;;;; tests/game/novel/eval.lisp
(defpackage #:recurya/tests/game/novel/eval
  (:use #:cl #:rove)
  (:import-from #:recurya/game/novel/eval #:eval-scene))

(in-package #:recurya/tests/game/novel/eval)

(defparameter *scene*
  "(list
     (if met-alice
         (list 'say \"アリス\" \"また会ったね。\")
         (list 'say \"アリス\" \"はじめまして。\"))
     (list 'set-flag 'met-alice))")

(deftest flag-false-branch
  (let ((dirs (eval-scene *scene* :flags '((:met-alice . nil)))))
    (ok (equal (first dirs) '(:say "アリス" "はじめまして。")))
    (ok (equal (second dirs) '(:set-flag :met-alice)))))

(deftest flag-true-branch
  (let ((dirs (eval-scene *scene* :flags '((:met-alice . t)))))
    (ok (equal (first dirs) '(:say "アリス" "また会ったね。")))))

(deftest prelude-helpers-available
  ;; prelude can define helpers the scene uses
  (let ((dirs (eval-scene "(list (greet \"アリス\"))"
                          :prelude "(define (greet name) (list 'say name \"やあ\"))")))
    (ok (equal (first dirs) '(:say "アリス" "やあ")))))
```

- [ ] **Step 4: テスト実行 — FAIL 確認**

`run-tests system="recurya/tests/game/novel/eval"`
Expected: FAIL（`not implemented`）。

- [ ] **Step 5: 実装で置換**

フラグ注入は **R4（`evaluate` の `:bindings`）があればそれを使い、無ければ文字列前置にフォールバック**。本実装は文字列前置（追加wardlisp機能不要・確実）で書く:

`lisp-edit-form ... form_name="eval-scene" operation="replace"`:
```lisp
(defun %flag-value->source (v)
  "Render a flag value V as wardlisp source text."
  (cond ((null v) "nil")
        ((eq v t) "t")
        ((integerp v) (princ-to-string v))
        ((stringp v) (format nil "~S" v))   ; CL string -> "..." literal
        (t "nil")))

(defun %flag-name->source (k)
  "Render a flag keyword K as a wardlisp symbol token (lower-case)."
  (string-downcase (symbol-name k)))

(defun %flags->defines (flags)
  "Build a wardlisp source string of (define <flag> <value>) lines."
  (with-output-to-string (s)
    (dolist (pair flags)
      (format s "(define ~A ~A)~%"
              (%flag-name->source (car pair))
              (%flag-value->source (cdr pair))))))

(defun eval-scene (scene-source &key prelude flags)
  "Evaluate SCENE-SOURCE (wardlisp text) with PRELUDE (shared defs, text)
   and FLAGS (alist flag-keyword -> value) injected as defines.
   Returns resolved directive data (see recurya/game/novel/value)."
  (let* ((code (format nil "~@[~A~%~]~A~A"
                       prelude (%flags->defines flags) scene-source)))
    (multiple-value-bind (result metrics)
        (evaluate code
                  :fuel *novel-fuel* :max-cons *novel-max-cons*
                  :max-depth *novel-max-depth* :timeout *novel-timeout*)
      (let ((err (getf metrics :error-message)))
        (when err (error "novel scene error: ~A" err)))
      (ward->directives result))))
```
（補助関数 `%flag-value->source`/`%flag-name->source`/`%flags->defines` は `eval-scene` の前に individually `insert_before` で追加してから本体を `replace`。）

- [ ] **Step 6: 再ロードしてテスト PASS**

`load-system system="recurya/game/novel/eval" force=true` の後 `run-tests system="recurya/tests/game/novel/eval"`
Expected: 3件 PASS（フラグ偽/真で会話分岐、プレリュード関数利用）。

- [ ] **Step 7: コミット**

```bash
git add game/novel/eval.lisp tests/game/novel/eval.lisp recurya.asd
git commit -m "feat: evaluate novel scenes with prelude and reader flags" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: 読者状態モデル `novel_state` ＋ マイグレーション

**Files:** Create `models/novel-state.lisp`; Modify `recurya.asd`; Create migration SQL

- [ ] **Step 1: モデル作成**

`fs-write-file path="models/novel-state.lisp"`:
```lisp
;;;; models/novel-state.lisp --- Per-reader novel progress (flags + position).
(defpackage #:recurya/models/novel-state
  (:use #:cl #:mito)
  (:export #:novel-state
           #:novel-state-user-id
           #:novel-state-notebook-id
           #:novel-state-flags
           #:novel-state-scene-index
           #:novel-state-created-at
           #:novel-state-updated-at))

(in-package #:recurya/models/novel-state)

(deftable novel-state ()
  ((user-id :col-type :uuid :initarg :user-id :accessor novel-state-user-id)
   (notebook-id :col-type (:varchar 64) :initarg :notebook-id
                :accessor novel-state-notebook-id)
   (flags :col-type :text :initarg :flags :initform "{}"
          :accessor novel-state-flags)              ; JSON object string
   (scene-index :col-type :integer :initarg :scene-index :initform 0
                :accessor novel-state-scene-index))
  (:unique-keys (user-id notebook-id))
  (:keys (user-id notebook-id))
  (:documentation "Per-(user, notebook) novel playthrough state."))

(defun novel-state-created-at (row) (mito:object-created-at row))
(defun novel-state-updated-at (row) (mito:object-updated-at row))
```

- [ ] **Step 2: `.asd` 登録**

`lisp-patch-form file_path="recurya.asd" form_type="defsystem" form_name="recurya"`:
- old_text: `               "recurya/models/learn-submission"`
- new_text:
```
               "recurya/models/learn-submission"
               "recurya/models/novel-state"
```

- [ ] **Step 3: ロード確認**

`load-system system="recurya/models/novel-state"`
Expected: loaded successfully。

- [ ] **Step 4: マイグレーション生成・適用（/mito-migrate 手順）**

```bash
.qlot/bin/mito generate-migrations -t postgres -H localhost -P 15434 -d recurya -u postgres -p postgres -s recurya -D db/
.qlot/bin/mito migrate -t postgres -H localhost -P 15434 -d recurya -u postgres -p postgres -s recurya -D db/
```
Expected: `CREATE TABLE "novel_state"` を含む up SQL が生成され、適用される。`db/schema.sql` も更新。
確認: `PGPASSWORD=postgres psql -h localhost -p 15434 -U postgres -d recurya -c '\d novel_state'`。

- [ ] **Step 5: コミット**

```bash
git add models/novel-state.lisp recurya.asd db/migrations/ db/schema.sql
git commit -m "feat: add novel_state table for per-reader progress" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: 読者状態 CRUD `db/novel`

**Files:** Create `db/novel.lisp`, `tests/db/novel.lisp`; Modify `recurya.asd`、`tests/support/db.lisp`（cleanup）

- [ ] **Step 1: cleanup に novel_state を追加**

`lisp-patch-form file_path="tests/support/db.lisp" form_type="defun" form_name="cleanup-all-test-data"`:
- old_text: `    (execute! "DELETE FROM course_notebook")`
- new_text:
```
    (execute! "DELETE FROM novel_state")
    (execute! "DELETE FROM course_notebook")
```

- [ ] **Step 2: モジュール雛形＋.asd 登録**

`fs-write-file path="db/novel.lisp"`:
```lisp
;;;; db/novel.lisp --- CRUD for per-reader novel state.
(defpackage #:recurya/db/novel
  (:use #:cl)
  (:import-from #:mito #:find-dao #:insert-dao #:save-dao)
  (:import-from #:recurya/db/core #:ensure-uuid)
  (:import-from #:recurya/utils/common #:parse-json #:json->string)
  (:import-from #:recurya/models/novel-state
                #:novel-state #:novel-state-user-id #:novel-state-notebook-id
                #:novel-state-flags #:novel-state-scene-index)
  (:export #:get-novel-state #:upsert-novel-state
           #:novel-state-flags-alist))

(in-package #:recurya/db/novel)

(defun get-novel-state (user-id notebook-id)
  (declare (ignore user-id notebook-id))
  (error "not implemented"))

(defun upsert-novel-state (user-id notebook-id &key flags scene-index)
  (declare (ignore user-id notebook-id flags scene-index))
  (error "not implemented"))

(defun novel-state-flags-alist (row)
  (declare (ignore row))
  (error "not implemented"))
```
`.asd` (`lisp-patch-form` defsystem recurya): old `               "recurya/db/learn"` → 
```
               "recurya/db/learn"
               "recurya/db/novel"
```

- [ ] **Step 3: 失敗テスト**

`fs-write-file path="tests/db/novel.lisp"`:
```lisp
;;;; tests/db/novel.lisp
(defpackage #:recurya/tests/db/novel
  (:use #:cl #:rove)
  (:import-from #:recurya/tests/support/db #:with-test-db #:create-test-user)
  (:import-from #:recurya/models/users #:users-id)
  (:import-from #:recurya/db/novel
                #:get-novel-state #:upsert-novel-state #:novel-state-flags-alist)
  (:import-from #:recurya/models/novel-state
                #:novel-state-scene-index))

(in-package #:recurya/tests/db/novel)

(deftest upsert-and-get-roundtrip
  (with-test-db
    (let* ((u (create-test-user))
           (uid (users-id u))
           (nb "nb-123"))
      (ok (null (get-novel-state uid nb)) "no state initially")
      (upsert-novel-state uid nb :flags '((:met-alice . t) (:count . 3)) :scene-index 2)
      (let ((row (get-novel-state uid nb)))
        (ok row)
        (ok (= 2 (novel-state-scene-index row)))
        (let ((fl (novel-state-flags-alist row)))
          (ok (eq t (cdr (assoc :met-alice fl))))
          (ok (= 3 (cdr (assoc :count fl))))))
      ;; second upsert updates the same row (no duplicate)
      (upsert-novel-state uid nb :flags '((:met-alice . t)) :scene-index 5)
      (let ((row (get-novel-state uid nb)))
        (ok (= 5 (novel-state-scene-index row)))))))
```

- [ ] **Step 4: テスト実行 — FAIL 確認**

`run-tests system="recurya/tests/db/novel"`（PostgreSQL 必要）
Expected: FAIL（`not implemented`）。

- [ ] **Step 5: 実装で置換（3関数を順に replace）**

`get-novel-state`:
```lisp
(defun get-novel-state (user-id notebook-id)
  "Return the NOVEL-STATE row for (USER-ID, NOTEBOOK-ID), or NIL."
  (find-dao 'novel-state :user-id (ensure-uuid user-id) :notebook-id notebook-id))
```
`upsert-novel-state`:
```lisp
(defun upsert-novel-state (user-id notebook-id &key flags scene-index)
  "Insert or update the per-reader novel state. FLAGS is an alist
   (flag-keyword -> value) serialized to JSON. Returns the row."
  (let* ((uid (ensure-uuid user-id))
         (flags-json (json->string (%alist->ht flags)))
         (existing (find-dao 'novel-state :user-id uid :notebook-id notebook-id)))
    (if existing
        (progn
          (when flags (setf (novel-state-flags existing) flags-json))
          (when scene-index (setf (novel-state-scene-index existing) scene-index))
          (save-dao existing))
        (insert-dao (make-instance 'novel-state
                                   :user-id uid :notebook-id notebook-id
                                   :flags flags-json
                                   :scene-index (or scene-index 0))))))
```
`novel-state-flags-alist`:
```lisp
(defun novel-state-flags-alist (row)
  "Parse ROW's flags JSON back to an alist (flag-keyword -> value)."
  (let ((ht (parse-json (novel-state-flags row))))
    (when (hash-table-p ht)
      (loop for k being the hash-keys of ht using (hash-value v)
            collect (cons (intern (string-upcase k) :keyword) v)))))
```
補助 `%alist->ht`（`get-novel-state` の前に `insert_before`）:
```lisp
(defun %alist->ht (alist)
  "Convert an alist (flag-keyword -> value) to a string-keyed hash-table."
  (let ((h (make-hash-table :test 'equal)))
    (dolist (pair alist h)
      (setf (gethash (string-downcase (symbol-name (car pair))) h) (cdr pair)))))
```
（注: `parse-json`/`json->string` の戻り表現は `recurya/utils/common` 実装に合わせる。ハッシュtable・真偽値の表現が異なる場合は Step 6 で実値を確認して調整。`t`/`false`/`:null` の扱いは `db/jsonb`/`utils/common` の既存方針に従う。）

- [ ] **Step 6: 再ロードしてテスト PASS（実値で JSON 表現を確認）**

`load-system system="recurya/db/novel" force=true` の後 `run-tests system="recurya/tests/db/novel"`。
失敗時は `repl-eval` で `recurya/utils/common:parse-json`/`json->string` の往復表現（真偽値・整数・キー）を確認し、`%alist->ht`/`novel-state-flags-alist` を実装に合わせて修正（テストは弱めない）。

- [ ] **Step 7: コミット**

```bash
git add db/novel.lisp tests/db/novel.lisp tests/support/db.lisp recurya.asd
git commit -m "feat: per-reader novel state CRUD (flags + scene index)" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: 逐次ランタイム＋Play/advance ルート

**Files:** Create `web/routes-novel.lisp`, `tests/web/novel-routes.lisp`; Modify `recurya.asd`、ルート登録呼び出し箇所（`web/routes-wardlisp` の `setup-wardlisp-routes` 呼び出しと同じ場所）

> 設計上の責務: ハンドラは「notebook を取得 → `:scene` セル列と `:code-eval` プレリュードを抽出 → 読者状態(フラグ＋index)取得 → 当該シーンを `eval-scene` → `interpret-directives` でビート化 → set-flags を状態へ適用＆index 前進 → プレイヤーUIへ」。

- [ ] **Step 1: ヘルパ — notebook からシーン列とプレリュードを取り出す純関数を作る**

まず `game/novel/eval.lisp` に、cell 列からプレリュード文字列とシーン本文列を作るヘルパを追加（純関数・テスト容易）。`lisp-edit-form ... operation="insert_after" form_name="eval-scene"`:
```lisp
(defun split-novel-cells (cells)
  "Given a list of (kind . body) pairs (kind keyword, body string),
   return (values PRELUDE SCENE-BODIES) where PRELUDE is the concatenation
   of all :code-eval bodies and SCENE-BODIES is the ordered list of :scene
   bodies."
  (let ((prelude '()) (scenes '()))
    (dolist (c cells)
      (case (car c)
        (:code-eval (push (cdr c) prelude))
        (:scene (push (cdr c) scenes))))
    (values (format nil "~{~A~^~%~}" (nreverse prelude))
            (nreverse scenes))))
```
export に `#:split-novel-cells` を追加（`lisp-patch-form` で defpackage の `:export` に追記）。

- [ ] **Step 2: split-novel-cells の単体テスト（eval テストへ追記）→ FAIL→実装は既出なので PASS 確認**

`tests/game/novel/eval.lisp` に追記（`insert_after` で deftest を追加）:
```lisp
(deftest split-cells-prelude-and-scenes
  (multiple-value-bind (prelude scenes)
      (recurya/game/novel/eval:split-novel-cells
       '((:code-eval . "(define x 1)")
         (:scene . "(list (list 'narrate \"a\"))")
         (:code-eval . "(define y 2)")
         (:scene . "(list (list 'narrate \"b\"))")))
    (ok (search "(define x 1)" prelude))
    (ok (search "(define y 2)" prelude))
    (ok (= 2 (length scenes)))
    (ok (search "\"a\"" (first scenes)))))
```
`run-tests system="recurya/tests/game/novel/eval"` → PASS（Step 1 実装済みのため）。`git commit`（eval ヘルパ＋テスト）:
```bash
git add game/novel/eval.lisp tests/game/novel/eval.lisp
git commit -m "feat: split novel notebook cells into prelude and scenes" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 3: ルートファイル雛形＋登録**

`fs-write-file path="web/routes-novel.lisp"`:
```lisp
;;;; web/routes-novel.lisp --- Novel player routes (start/advance).
(defpackage #:recurya/web/routes-novel
  (:use #:cl)
  (:import-from #:recurya/db/notebooks
                #:find-notebook-by-handle-and-slug #:notebook-id
                #:notebook-title #:notebook-cells-parsed)
  (:import-from #:recurya/game/novel/eval #:split-novel-cells #:eval-scene)
  (:import-from #:recurya/game/novel/interpreter #:interpret-directives)
  (:import-from #:recurya/db/novel
                #:get-novel-state #:upsert-novel-state #:novel-state-flags-alist)
  (:import-from #:recurya/models/novel-state #:novel-state-scene-index)
  (:import-from #:recurya/web/ui/novel #:render-player)
  (:export #:setup-novel-routes
           #:novel-play-handler))

(in-package #:recurya/web/routes-novel)

(defun setup-novel-routes (app)
  (declare (ignore app))
  (error "not implemented"))
```
`.asd` (`lisp-patch-form` defsystem recurya): old `               "recurya/web/routes-wardlisp"` → 
```
               "recurya/web/routes-wardlisp"
               "recurya/web/routes-novel"
```

- [ ] **Step 4: 統合的ハンドラの失敗テスト（公開ノートブックを再生）**

`fs-write-file path="tests/web/novel-routes.lisp"` — `tests/web/notebook-routes.lisp` の様式（`with-test-db`/`with-mock-session`/`response-status`）を参照して、scene セルを持つ公開ノートブックを作り、play ハンドラが 200 でビートを含む HTML を返すこと、フラグに応じて2回目の表示が変わること（set-flag→次シーン）を検証するテストを書く。最低限:
```lisp
;;;; tests/web/novel-routes.lisp  (様式は tests/web/notebook-routes.lisp に倣う)
(defpackage #:recurya/tests/web/novel-routes
  (:use #:cl #:rove)
  (:import-from #:recurya/tests/support/db #:with-test-db #:create-test-user)
  ;; ... notebook-routes.lisp と同じ session/response ヘルパを import ...
  )
(in-package #:recurya/tests/web/novel-routes)

(deftest play-renders-first-scene-beats
  (with-test-db
    ;; 著者ユーザ＋ scene セルを持つ published/public notebook を作成
    ;; (recurya/db/notebooks:create-notebook! を使用。body_md は
    ;;  "===scene===\n(list (list 'say \"アリス\" \"やあ\"))" )
    ;; play ハンドラ呼び出し → status 200、HTML に "やあ" を含む
    (ok t "placeholder until session helpers wired")))
```
> 注: web ルートテストは既存 `tests/web/notebook-routes.lisp` のセッション/レスポンスヘルパ（`with-mock-session`/`make-session`/`response-status`）を再利用する。最初にそれらの import を notebook-routes.lisp から確認し、本テストに取り込む。プレースホルダ `ok t` は Step 6 実装後に実アサーションへ置換すること（緩めない）。

- [ ] **Step 5: ランタイム＆ハンドラ実装**

`setup-novel-routes` と `novel-play-handler` を実装する。要点:
- `novel-play-handler params`: regex ルート `^/@([\\w-]+)/([\\w-]+)/play/?$` の captures から handle/slug → `find-notebook-by-handle-and-slug`。公開可視性チェック（`recurya/utils/access-control` の既存述語を notebook-routes と同様に使用）。
- セル抽出: `notebook-cells-parsed` で JSONB セルを取り出し、`(kind . body)` ペア列へ変換（kind は文字列→キーワード化）。`split-novel-cells` でプレリュード＋シーン列。
- 読者状態: ログインユーザなら `get-novel-state`（無ければ index 0/空フラグ）。匿名は index 0/空フラグ（永続なし。localStorage 連携は次増分）。
- 現在シーン評価: `(eval-scene (nth index scenes) :prelude prelude :flags flags)` → `interpret-directives` → ビート＋set-flags。
- 状態更新: ログインユーザは set-flags を反映し index を据え置き（advance で前進）。`render-player` でHTML返却。
- `advance` ルート `^/@([\\w-]+)/([\\w-]+)/play/advance$` (POST): 現在 index の set-flags を適用→index+1→そのシーンを評価しビートを返す（HTMX フラグメント）。最終シーン超過で「おわり」。

実装は `lisp-edit-form replace`（`setup-novel-routes`）＋必要な内部関数を `insert_before` で順次追加。ルート登録は `web/routes-wardlisp:setup-wardlisp-routes` を呼んでいる箇所（`web/server` の `build-app` 付近）に `setup-novel-routes` 呼び出しを追加（`lisp-patch-form`）。

- [ ] **Step 6: テストを実アサーションに置換し PASS**

Step 4 のプレースホルダを、scene セル付き公開ノートブックを作って play ハンドラが 200＋本文文字列を返すアサーションに置換。`load-system system="recurya" force=true` → `run-tests system="recurya/tests/web/novel-routes"`。PASS まで根本原因を直す（テストは緩めない）。

- [ ] **Step 7: コミット**

```bash
git add web/routes-novel.lisp tests/web/novel-routes.lisp recurya.asd web/server.lisp
git commit -m "feat: novel play/advance routes with incremental scene evaluation" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: サンプル novel の通し統合テスト＋全スイート＋スモーク

**Files:** Create `tests/integration/novel-sample.lisp`; Modify `recurya.asd`/`tests/all.lisp`（登録）

- [ ] **Step 1: 通し統合テスト**

`fs-write-file path="tests/integration/novel-sample.lisp"`: 2〜3シーンのサンプル（1つはフラグ条件で会話が変わる）を `eval-scene`＋`interpret-directives` で逐次再生し、(a) 1シーン目のビート列、(b) set-flag 適用後の2シーン目が条件分岐後の会話になること、を検証（DB不要・純ロジックで完結する形にして高速化。DB往復は Task 8 のルートテストでカバー済み）。
```lisp
(defpackage #:recurya/tests/integration/novel-sample
  (:use #:cl #:rove)
  (:import-from #:recurya/game/novel/eval #:eval-scene)
  (:import-from #:recurya/game/novel/interpreter #:interpret-directives))
(in-package #:recurya/tests/integration/novel-sample)

(defparameter *prelude* "")
(defparameter *scene1* "(list (list 'narrate \"教室。\")
                              (list 'say \"アリス\" \"はじめまして。\")
                              (list 'set-flag 'met-alice))")
(defparameter *scene2* "(list (if met-alice
                                  (list 'say \"アリス\" \"また会ったね。\")
                                  (list 'say \"アリス\" \"…誰？\")))")

(deftest sample-two-scenes-flag-flow
  ;; scene1
  (multiple-value-bind (beats1 sf1)
      (interpret-directives (eval-scene *scene1* :prelude *prelude* :flags '()))
    (ok (= 2 (length beats1)))
    (ok (equal sf1 '((:met-alice . t))))
    ;; apply flags, then scene2
    (let* ((flags (list (cons :met-alice t)))
           (dirs2 (eval-scene *scene2* :prelude *prelude* :flags flags))
           (beats2 (interpret-directives dirs2)))
      (ok (string= "また会ったね。" (getf (first beats2) :text))))))
```
登録: `tests/all.lisp` と `recurya/tests` の depends-on に新テスト群（`recurya/tests/game/novel/interpreter`, `.../value`, `.../eval`, `recurya/tests/db/novel`, `recurya/tests/web/novel-routes`, `recurya/tests/integration/novel-sample`）を追加。

- [ ] **Step 2: テスト PASS**

`run-tests system="recurya/tests/integration/novel-sample"` → PASS。

- [ ] **Step 3: 全スイート＋警告チェック**

`repl-eval code="(asdf:compile-system :recurya :force t)" timeout_seconds=300`（警告ゼロ目標）の後
```bash
.qlot/bin/rove recurya.asd
```
Expected: 全 PASS、exit 0。

- [ ] **Step 4: 手動スモーク**

scene セルを持つ公開ノートブックを作り（既存の作成UI or repl で `create-notebook!`）、`GET /@<handle>/<slug>/play` を開く。1シーン目がクリック送りで表示され、フラグ分岐シーンが期待通り変わること、ログインで再訪時に位置/フラグが復元されることを確認。

- [ ] **Step 5: コミット**

```bash
git add tests/integration/novel-sample.lisp recurya.asd tests/all.lisp
git commit -m "test: end-to-end novel sample (flag-driven scene flow)" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 6: ブランチ完了処理**

REQUIRED SUB-SKILL: superpowers:finishing-a-development-branch でマージ/PR/クリーンアップを確認。

---

## 完了基準

- [ ] P1: `===scene===` パース round-trip、インタプリタ、プレイヤーUIが動作（wardlisp非依存）
- [ ] P2: wardlisp文字列拡張の上で、フラグ注入→評価→走査→ビート→逐次再生が通る
- [ ] フラグ＋ wardlisp 制御構造で会話が出し分けられる（統合テストで実証）
- [ ] 読者ごとの状態（フラグ＋位置）が跨セッションで保存・再開できる
- [ ] 全テスト PASS、`compile-system :force t` 警告なし

## 段階化・スコープ外（このプランの後）

- `choice`/`label`/`jump`（プレイヤー分岐）: 位置表現を index→ラベルへ拡張、選択肢UI＋advanceの分岐。
- キャラ登録・背景画像・BGM/SE・トランジション・テキストアニメ。
- 匿名読者の localStorage 永続＋ログイン時マージ（`merge-localstorage` 相当の novel 版）。
- コンストラクタ関数プレリュード（`say`/`scene` 等）標準提供、エディタ体験（セル分割＋CodeMirror）、ストレージのセルテーブル化。

## 自己レビュー（spec カバレッジ）

- 設計 §コンポーネント1（scene セル）→ Task 1 ✓
- §5 インタプリタ → Task 2 ✓
- §8 プレイヤーUI → Task 3 ✓
- §3 結果走査 → Task 4 ✓（wardlisp R3 依存を明記）
- §2/§3 プレリュード＋フラグ注入＋評価 → Task 5 ✓（R1/R2 依存、R4 はフォールバック実装）
- §7 読者状態 → Task 6/7 ✓
- §6/§8 逐次ランタイム＋ルート → Task 8 ✓
- §テスト戦略 → 各 Task の TDD ＋ Task 9 統合 ✓
- wardlisp 依存は P2 冒頭と Task 4/5 に明記。choice 等は「スコープ外」に明記。
