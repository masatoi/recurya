# CSRF 保護 実装計画

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** `lack.middleware.csrf` を middleware stack に組み込み、すべての state-changing エンドポイント（POST/PUT/DELETE/PATCH）が CSRF token なしでは 400 を返すようにする。同時にすべての form と HTMX ボタンに token を埋め込む。`/learn/sync`（JSON fetch）のみ skip する。

**Architecture:** `web/server.lisp:build-app` の `:session` 直後に CSRF middleware を挟む。token 共有用の `<form id="csrf-form">` を `web/ui/layout.lisp:header` 内（または body 直下）で 1 度だけ出力し、全 HTMX button が `hx-include="#csrf-form"` で参照する。HTML form は `(csrf-input)` ヘルパで hidden input を埋め込む。`/learn/sync` は middleware ラッパで path 単位でスキップ。

**Tech Stack:** Common Lisp / SBCL + qlot, Mito ORM (touched only for tests), Ningle + Clack/Hunchentoot, Lack (`lack.middleware.csrf` + `lack.middleware.session`), Spinneret HTML, HTMX, Rove tests, **clack-test for integration**. 新規依存なし（lack は既に depends-on）。

**Reference:** 設計ドキュメント [`docs/plans/2026-05-04-csrf-protection-design.md`](./2026-05-04-csrf-protection-design.md) を必ず参照。

**Lispツール規約:** すべての `.lisp`/`.asd` 操作は cl-mcp ツール。Read/Edit/Write/Grep/Glob はLispファイルに使わない。Markdown/JS/SQL は通常の Write/Edit 可。

**初期セットアップ:** 各タスク冒頭で `mcp__cl-mcp__fs-set-project-root path=/home/wiz/recurya`。

**コミット方針:** 各タスクを「テスト→失敗確認→実装→成功確認→コミット」で 1 タスク 1 コミット。`feat:` `test:` `refactor:` プレフィックス + `Co-Authored-By:` 行。

**ブランチ:** `feat/csrf-protection` を `main` から切る。

---

## Phase 1: middleware 設置

### Task 1: csrf-failure UI ページ

**Files:**
- Modify: `web/ui/errors.lisp`

**Step 1:** `recurya/web/ui/errors` パッケージに `csrf-failure` 関数を追加（既存 `not-found` と同型）。HTML で「無効なリクエストです。ブラウザの戻るボタンで前のページに戻り、再度操作してください。」のようなメッセージを表示。

**Step 2: REPL で render 確認**

```
mcp__cl-mcp__repl-eval code="(recurya/web/ui/errors:csrf-failure)"
```

**Step 3: コミット**

```bash
git commit -am "feat: add csrf-failure error page"
```

---

### Task 2: middleware ラッパ + skip 設定

**Files:**
- Modify: `web/server.lisp`

**Step 1:** `web/server.lisp` の defpackage に `:import-from #:lack/middleware/csrf #:*lack-middleware-csrf*` 追加。

**Step 2:** `csrf-failure-handler` を定義:

```lisp
(defun csrf-failure-handler (env)
  (declare (ignore env))
  (list 400
        (list :content-type "text/html; charset=utf-8")
        (list (recurya/web/ui/errors:csrf-failure))))
```

**Step 3:** `csrf-with-skip` 関数を定義:

```lisp
(defparameter *csrf-skip-paths* '("/learn/sync")
  "Paths bypassed by the CSRF middleware (JSON endpoints with their
own protection).")

(defun csrf-with-skip (app)
  "Wrap APP in lack/middleware/csrf, but skip *csrf-skip-paths*."
  (let ((csrf-app
          (funcall lack/middleware/csrf:*lack-middleware-csrf*
                   app :block-app #'csrf-failure-handler)))
    (lambda (env)
      (if (member (getf env :path-info) *csrf-skip-paths* :test #'string=)
          (funcall app env)
          (funcall csrf-app env)))))
```

**Step 4:** `build-app` を修正して csrf middleware を挟む:

```lisp
(defun build-app ()
  (let ((app (make-recurya-app)))
    (setup-routes app)
    (lack/builder:builder
     (:static :path "/static/" :root ...)
     :session
     (:lambda #'csrf-with-skip)   ; ← 追加。lack.builder の :lambda 構文を要確認
     :backtrace
     app)))
```

**注意:** `lack.builder` の `:lambda` 構文の存在は要確認。動かなければ `funcall` で直接ラップする形に切替:

```lisp
(let ((app ...))
  (let ((middleware-stack (lack/builder:builder
                            (:static ...)
                            :session
                            :backtrace
                            app)))
    (csrf-with-skip middleware-stack)))
```

ただしこの場合 `:session` middleware が csrf より外側になり、session が csrf 検査時点で取得できないので動かない。session-csrf-backtrace-app の順序を保つには `:session` の直後に csrf を入れる必要がある。

最も確実な方法: `lack.builder` の **lambda 形式の middleware** はサポートされているはず。次の syntax で動く想定:

```lisp
(lack/builder:builder
 (:static :path "/static/" :root ...)
 :session
 (:lambda 'csrf-with-skip)
 :backtrace
 app)
```

`(:lambda ...)` を `lack.builder` がサポートしない場合のフォールバック:

```lisp
(funcall (lack.app:builder
          :session
          ...)
         (csrf-with-skip raw-app))
```

実装時に `lack.builder` のソースを確認する。

**Step 5:** REPL でサーバを起動して GET / の挙動を確認:

```
mcp__cl-mcp__repl-eval code="(recurya/web/server:start! :port 3001)"
```

別ターミナルで `curl http://localhost:3001/login` → 200 OK。
`curl -X POST http://localhost:3001/notebooks` → 400 (CSRF) または 401 (auth) のいずれか。

**Step 6:** stop! してコミット

```bash
git commit -am "feat: integrate lack.middleware.csrf with /learn/sync skip"
```

---

## Phase 2: ヘルパとテンプレート埋め込み

### Task 3: csrf token ヘルパ

**Files:**
- Create: `web/ui/csrf.lisp`
- Modify: `recurya.asd`

**Step 1:** 新規パッケージ `recurya/web/ui/csrf` を作る:

```lisp
(defpackage #:recurya/web/ui/csrf
  (:use #:cl)
  (:import-from #:spinneret #:with-html)
  (:import-from #:lack/middleware/csrf #:csrf-token)
  (:export #:current-csrf-token
           #:csrf-input
           #:csrf-form-block))

(in-package #:recurya/web/ui/csrf)

(defun current-csrf-token ()
  (when ningle/context:*session*
    (csrf-token ningle/context:*session*)))

(defun csrf-input ()
  (let ((tok (current-csrf-token)))
    (when tok
      (with-html
        (:input :type "hidden" :name "_csrf_token" :value tok)))))

(defun csrf-form-block ()
  "Hidden form holding the page-wide CSRF token. HTMX buttons reference
it via hx-include=\"#csrf-form\"."
  (let ((tok (current-csrf-token)))
    (when tok
      (with-html
        (:form :id "csrf-form" :style "display:none"
               (:input :type "hidden" :name "_csrf_token" :value tok))))))
```

**Step 2:** ASDF に追加（`web/ui/layout` の直前あたり）。

**Step 3:** load 確認、コミット:

```bash
git commit -am "feat: add csrf-input and csrf-form-block UI helpers"
```

---

### Task 4: layout.lisp に csrf-form-block を統合

**Files:**
- Modify: `web/ui/layout.lisp`

**Step 1:** `header` 関数 (またはその呼び出し元) で `(csrf-form-block)` を `<body>` 直下に出力する。または各 page-shell 系 render に直接埋め込む。最も簡単なのは:

`page-shell` がある場合:
```lisp
(:body
 (:raw (csrf-form-block))    ; ← 追加
 (:raw (header user))
 ...)
```

ただし recurya は `page-shell` を全 page で使っていない（独自 with-html-string が散在）。確実な方針: `header` 関数の出力に csrf-form を含める。

**Step 2:** `web/ui/layout.lisp:header` を修正:

```lisp
(defun header (user)
  (with-html-string
    (:raw (csrf-form-block))
    (:header :class "app-header" ...)))
```

`csrf-form-block` も `with-html-string` を返すので、`(:raw ...)` で文字列を埋め込む形でなく、関数の中で直接 HTML を構築するように内部化するか。ヘルパの実装次第。あるいは:

```lisp
(defun header-with-csrf (user)
  (concatenate 'string (csrf-form-block) (header user)))
```

を導入し、各ハンドラで `header` の代わりに `header-with-csrf` を呼ぶ。これは既存の `(header user)` 呼び出しを全置換する作業。

**最もシンプル:** `header` 自身に csrf-form-block を含める。各 page で `header` を呼ぶ箇所はそのまま動く。

**Step 3:** smoke test in REPL (login page を render して `csrf-form` が含まれるか確認)

**Step 4:** コミット

```bash
git commit -am "feat: include csrf-form-block in app header"
```

---

## Phase 3: 既存 form への csrf-input 追加

### Task 5: login form

**Files:**
- Modify: `web/ui/login.lisp`

**Step 1:** Form に `(csrf-input)` を追加。export に依存させて import-from を更新。

**Step 2:** smoke test (login page render → "_csrf_token" hidden input が含まれる)

**Step 3:** コミット:

```bash
git commit -am "feat: add csrf input to login form"
```

---

### Task 6: post / user-notebook / course / account の各 form

**Files:**
- Modify: `web/ui/post-form.lisp`
- Modify: `web/ui/user-notebook-form.lisp`
- Modify: `web/ui/course-form.lisp`
- Modify: `web/ui/account.lisp`
- Modify: 各 confirm-modal が登場する箇所（render-confirm-modal 内に csrf-input。`web/routes.lisp`）

**Step 1:** 各 form の中に `(csrf-input)` を追加。

**Step 2:** logout form (`web/ui/layout.lisp:header` 内の `(:form :method "post" :action "/logout")` 内 + どこか別の logout button があれば全部) に `(csrf-input)` を追加。

**Step 3:** REPL で各 form を render して `_csrf_token` hidden input を確認

**Step 4:** コミット:

```bash
git commit -am "feat: add csrf input to post/notebook/course/account/logout forms"
```

---

### Task 7: render-confirm-modal の hx-post button に hx-include

**Files:**
- Modify: `web/routes.lisp` の `render-confirm-modal`

**Step 1:** `render-confirm-modal` の `<button hx-post=...>` に `hx-include="#csrf-form"` を追加。

**Step 2:** コミット

```bash
git commit -am "feat: confirm-modal HTMX delete buttons include csrf token"
```

---

## Phase 4: HTMX button への hx-include 追加

### Task 8: status pill / state dropdown / toggle-status

**Files:**
- Modify: `web/routes.lisp` (`render-user-notebook-status-pill`, `render-course-status-pill` etc.)
- Modify: `web/ui/user-notebooks.lisp` (`render-user-notebook-state-dropdown`)
- Modify: `web/ui/courses.lisp` (`render-course-state-dropdown`)

**Step 1:** 全 hx-post button に `hx-include="#csrf-form"` を追加。dropdown の 3 buttons (Draft/Private/Public) も対象。toggle-status の pill も対象。

**Step 2:** REPL で render して `hx-include="#csrf-form"` が含まれることを確認。

**Step 3:** コミット

```bash
git commit -am "feat: HTMX state pill and dropdown include csrf token"
```

---

### Task 9: course attach / move / remove HTMX

**Files:**
- Modify: `web/ui/course-form.lisp` (`render-course-notebooks-list` の up/down/remove buttons + add notebook form)

**Step 1:** 全 HTMX button に `hx-include="#csrf-form"`。

**Step 2:** add-notebook の form は普通の HTML form なので `(csrf-input)` を追加。

**Step 3:** コミット

```bash
git commit -am "feat: course-notebook attach/move/remove buttons include csrf"
```

---

### Task 10: cell run button (notebook page)

**Files:**
- Modify: `web/ui/notebook.lisp` (`render-code-cell` の Run button)

**Step 1:** `:hx-include` を `".notebook-code, #csrf-form"` のように複数指定で全コードと csrf を巻き込む。または Spinneret の `:hx-include` 構文を確認。HTMX は `,` 区切りで複数 selector 対応。

**Step 2:** notebook page 全体に `<form id="csrf-form">` が出力されている必要があるが、`render` の出力には現状 `header` を呼んでいない。`header` を呼ばないページは csrf-form-block を別途出力する必要がある。

`web/ui/notebook.lisp:render` を確認し、必要なら `(:raw (csrf-form-block))` を `<body>` 直下に追加。

**Step 3:** REPL で render して `csrf-form` が含まれるか + Run button の `hx-include` に `#csrf-form` が含まれるか確認

**Step 4:** コミット

```bash
git commit -am "feat: notebook cell Run button includes csrf token"
```

---

## Phase 5: JS / meta tag

### Task 11: /learn/sync の確認（skip 設定の動作）

**Files:** なし（検証のみ）

**Step 1:** Task 2 で `/learn/sync` を skip 設定に入れた。これが正しく動くことを確認:

```bash
docker compose exec recurya bash -lc 'curl -X POST -H "Content-Type: application/json" -d "{}" http://localhost:3000/learn/sync'
```

期待: `learn-sync-handler` が呼ばれ、auth check で 401 を返す（CSRF 400 ではない）。

**Step 2:** コミット不要（実装は Task 2 で完了済み）

---

## Phase 6: テスト

### Task 12: clack-test による CSRF middleware 統合テスト

**Files:**
- Create: `tests/web/csrf.lisp`
- Modify: `recurya.asd`、`tests/all.lisp`

**Step 1:** clack-test で実 HTTP リクエストを発行する統合テストを書く。

```lisp
(defpackage #:recurya/tests/web/csrf
  (:use #:cl #:rove)
  (:import-from #:clack-test #:testing-app #:request)
  (:import-from #:recurya/web/server #:build-app))

(in-package #:recurya/tests/web/csrf)

(deftest get-skips-csrf
  (testing-app (build-app)
    (let ((res (request "/" :method :get)))
      (ok (= 200 (response-status res))))))

(deftest post-without-token-returns-400
  (testing-app (build-app)
    (let ((res (request "/posts" :method :post :data '(("title" . "X")))))
      (ok (= 400 (response-status res))))))

(deftest post-with-valid-token-passes-csrf
  (testing-app (build-app)
    ;; First GET to obtain a session cookie + csrf token
    (let* ((get-res (request "/login" :method :get))
           (cookie (extract-cookie get-res))
           (token  (extract-csrf-token (response-body get-res))))
      ;; Then POST with the token (should not be a 400; auth might still 401/302)
      (let ((post-res (request "/posts" :method :post
                               :data `(("title" . "X")
                                       ("_csrf_token" . ,token))
                               :headers `(("Cookie" . ,cookie)))))
        (ng (= 400 (response-status post-res)))))))

(deftest learn-sync-skips-csrf
  (testing-app (build-app)
    (let ((res (request "/learn/sync" :method :post
                        :data "{}"
                        :headers '(("Content-Type" . "application/json")))))
      (ok (or (= 200 (response-status res))
              (= 401 (response-status res)))   ; not CSRF 400
          "learn-sync should be skipped by csrf middleware"))))
```

`extract-cookie` / `extract-csrf-token` は test ヘルパ。実装は cl-ppcre + クッキーパース。

**Step 2:** ASDF + tests/all.lisp 登録。

**Step 3:** docker でテスト実行、PASS 確認

**Step 4:** コミット

```bash
git commit -am "test: integration tests for CSRF middleware"
```

---

### Task 13: 全テスト + 手動スモークテスト

**Files:** なし（検証のみ）

**Step 1:** 全テストを docker で走らせる。期待: 23 systems 全 PASS（既存 22 + 新 csrf 1）。

```bash
docker compose exec -e POSTGRES_HOST=postgres -e POSTGRES_PORT=5432 recurya bash -lc \
  '/home/app/.roswell/bin/qlot exec ros run -e "(ql:quickload :recurya/tests :silent t)" -e "(unless (recurya/tests/all:run-all-tests) (uiop:quit 1))" -e "(uiop:quit 0)"'
```

**Step 2:** 手動 E2E:

1. ログイン → 各種 form submit が成功
2. DevTools で hidden input を削除して submit → 400 ページ
3. HTMX status dropdown 経由 → 200 / 期待動作
4. HTMX confirm-modal 経由 delete → 200 / 期待動作
5. cell run → 200
6. /learn/sync (DevTools fetch) → 200 / 期待動作
7. 別オリジン (`<form action="http://localhost:3000/posts" method="post">`) submit → 400 ページ

**Step 3:** 必要なら修正タスクを差し込む

---

## Phase 7: 仕上げ

### Task 14: 最終 review

`code-reviewer` subagent でレビューを 1 度回し、抜け漏れ（hx-include 忘れた button、form 内 csrf-input 忘れ）を確認。指摘あれば追加コミット。

---

## 完了基準

- [ ] 全テスト（既存 + 新規 CSRF）PASS
- [ ] 手動 E2E 全項目 PASS
- [ ] PR 作成可能な状態（`feat/csrf-protection` ブランチ）
- [ ] 全 form / HTMX button に csrf token が埋め込まれている

## 注意事項

- **lack.builder の :lambda 構文**: 動かない場合 fallback として `funcall` 直接ラップに切替
- **`/learn/sync` の skip**: パス文字列を `:path-info` で照合。クエリ文字列込みで来たらマッチしない可能性 → `(string= path "/learn/sync")` で OK だが、`/learn/sync?x=1` のような場合は `:query-string` を別途見る必要。Lack の `:path-info` はクエリを除いた path のみを返すので問題なし
- **header without csrf-form**: notebook viewer のように header を出さないページは別途 `csrf-form-block` を出力する必要。`render` の冒頭で確認
- **テスト fixture**: 既存ハンドラ単体テストは middleware 通らないので無修正。新規 CSRF テストのみ clack-test 経由
- **session middleware の SameSite cookie**: 現状の `:session` middleware が SameSite を設定しているか確認。設定していなければ Lax に変更（CSRF middleware と二重防御）
