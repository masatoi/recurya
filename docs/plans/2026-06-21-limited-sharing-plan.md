# 限定共有（unlisted visibility）実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Notebook と Course に `unlisted`（限定公開）可視性を追加し、URLを知る人は閲覧でき、公開一覧・プロフィール・検索には出ないようにする。

**Architecture:** `visibility` の第3値として `"unlisted"` を導入。閲覧可否（`can-view-*`）は published かつ visibility ∈ {public, unlisted} で許可し、一覧掲載（`publicly-listable-*` / DBクエリの `visibility="public"`）は public のみのまま据え置く。状態UIは3状態→4状態ドロップダウンに拡張。`visibility` は CHECK制約なしの `VARCHAR(32)` なので **DBマイグレーション・`deftable` 変更は不要**。

**Tech Stack:** Common Lisp / Mito ORM / Ningle / Spinneret / HTMX / Rove（テスト）。Lispファイルの読み書きは cl-mcp ツール（`lisp-read-file` / `lisp-edit-form` / `lisp-patch-form` / `run-tests`）を使用。

## 前提

- 作業ブランチ `feat/limited-sharing` 上で作業する（設計ドキュメント `docs/plans/2026-06-21-limited-sharing-design.md` はコミット済み）。
- PostgreSQL が起動し、テストDBにスキーマ適用済みであること。空DBなら:
  `psql postgresql://postgres:postgres@localhost:15434/recurya -f db/schema.sql`
- `fs-set-project-root {"path": "."}` を最初に実行。
- 各タスクのテストは cl-mcp の `run-tests` ツールで実行（例: `{"system":"recurya/tests/utils/access-control"}`）。最終タスクで全システム強制コンパイル + 全スイートを fresh プロセスで実行する。
- **テーブル変更なし**: `models/notebook.lisp` / `models/course.lisp` / `db/schema.sql` は変更しない。

## File Structure

| ファイル | 責務 | 変更種別 |
|---|---|---|
| `utils/access-control.lisp` | 閲覧可否判定に unlisted を許可 | Modify |
| `web/routes.lisp` | `%decode-state-token` 拡張 / create・update の visibility 検証 / 公開ページへ noindex 受け渡し | Modify |
| `web/ui/notebook-form.lisp` | visibility select に Unlisted 追加 | Modify |
| `web/ui/course-form.lisp` | visibility select に Unlisted 追加 | Modify |
| `web/ui/notebooks-dashboard.lisp` | 4状態ドロップダウン / Unlisted ピル色 / コピーリンク | Modify |
| `web/ui/courses.lisp` | 同上（Course側） | Modify |
| `web/ui/notebook.lisp` | 公開Notebookページ head に noindex（`:noindex` 引数） | Modify |
| `web/ui/course.lisp` | 公開Courseページ head に noindex（`:noindex` 引数→head-extras） | Modify |
| `tests/utils/access-control.lisp` | unlisted 閲覧可・非掲載のテスト | Modify |
| `tests/web/notebook-routes.lisp` | unlisted の状態遷移・閲覧・非掲載・コピーリンク・noindex | Modify |
| `tests/web/course-routes.lisp` | 同上（Course側） | Modify |

---

### Task 1: アクセス制御 — unlisted を URL閲覧可にする（一覧は非掲載のまま）

**Files:**
- Modify: `utils/access-control.lisp`（`can-view-notebook-p`, `can-view-course-p`）
- Test: `tests/utils/access-control.lisp`

- [ ] **Step 1: 失敗するテストを追加**

`tests/utils/access-control.lisp` の末尾に以下4つの deftest を追加（既存ヘルパ `mk-notebook` / `mk-course` / `mk-user-plist` を利用）:

```lisp
(deftest can-view-notebook-published-unlisted
  (testing "published+unlisted notebooks are viewable by anyone with the URL"
    (with-test-db
      (let* ((owner-dao (create-test-user :email-prefix "owner"))
             (other-dao (create-test-user :email-prefix "other"))
             (owner (mk-user-plist owner-dao))
             (other (mk-user-plist other-dao))
             (nb (mk-notebook owner-dao
                              :status "published"
                              :visibility "unlisted")))
        (ok (can-view-notebook-p owner nb) "owner can view")
        (ok (can-view-notebook-p other nb) "other user can view")
        (ok (can-view-notebook-p nil nb)   "anonymous can view")))))

(deftest unlisted-notebook-not-publicly-listable
  (testing "unlisted notebooks are excluded from public listings"
    (with-test-db
      (let* ((owner-dao (create-test-user :email-prefix "owner"))
             (nb (mk-notebook owner-dao
                              :status "published"
                              :visibility "unlisted")))
        (ng (publicly-listable-notebook-p nb))))))

(deftest can-view-course-published-unlisted
  (testing "published+unlisted courses are viewable by anyone with the URL"
    (with-test-db
      (let* ((owner-dao (create-test-user :email-prefix "owner"))
             (other-dao (create-test-user :email-prefix "other"))
             (owner (mk-user-plist owner-dao))
             (other (mk-user-plist other-dao))
             (c (mk-course owner-dao
                           :status "published"
                           :visibility "unlisted")))
        (ok (can-view-course-p owner c) "owner can view")
        (ok (can-view-course-p other c) "other user can view")
        (ok (can-view-course-p nil c)   "anonymous can view")))))

(deftest unlisted-course-not-publicly-listable
  (testing "unlisted courses are excluded from public listings"
    (with-test-db
      (let* ((owner-dao (create-test-user :email-prefix "owner"))
             (c (mk-course owner-dao
                           :status "published"
                           :visibility "unlisted")))
        (ng (publicly-listable-course-p c))))))
```

- [ ] **Step 2: テストが失敗することを確認**

`run-tests {"system":"recurya/tests/utils/access-control"}`
Expected: `can-view-notebook-published-unlisted` と `can-view-course-published-unlisted` が FAIL（unlisted がまだ閲覧不可）。`unlisted-*-not-publicly-listable` は PASS（既に public のみ掲載）。

- [ ] **Step 3: `can-view-notebook-p` に unlisted 分岐を追加**

`utils/access-control.lisp` の `can-view-notebook-p` の `cond` 内 visibility 判定を以下に置換:

```lisp
    (t (let ((vis (notebook-visibility notebook)))
         (cond
           ((string= vis "public") t)
           ((string= vis "unlisted") t)
           ((string= vis "private") nil)
           (t nil))))))
```

- [ ] **Step 4: `can-view-course-p` に unlisted 分岐を追加**

同ファイルの `can-view-course-p` の `cond` 内 visibility 判定を以下に置換:

```lisp
    (t (let ((vis (course-visibility course)))
         (cond
           ((string= vis "public") t)
           ((string= vis "unlisted") t)
           ((string= vis "private") nil)
           (t nil))))))
```

`publicly-listable-notebook-p` / `publicly-listable-course-p` は **変更しない**（public のみのまま）。

- [ ] **Step 5: テストが通ることを確認**

`run-tests {"system":"recurya/tests/utils/access-control"}`
Expected: 全 PASS。

- [ ] **Step 6: コミット**

```bash
git add utils/access-control.lisp tests/utils/access-control.lisp
git commit -m "feat: allow unlisted notebooks/courses to be viewed by URL"
```

---

### Task 2: 状態トークン `published-unlisted` のデコード

**Files:**
- Modify: `web/routes.lisp`（`%decode-state-token`）
- Test: `tests/web/notebook-routes.lisp`

- [ ] **Step 1: 失敗するテストを追加**

`tests/web/notebook-routes.lisp` の末尾に追加（内部関数なので `::` で参照）:

```lisp
(deftest decode-state-token-published-unlisted
  (testing "%decode-state-token maps published-unlisted to (published, unlisted)"
    (multiple-value-bind (status vis)
        (recurya/web/routes::%decode-state-token "published-unlisted")
      (ok (string= status "published"))
      (ok (string= vis "unlisted")))))
```

- [ ] **Step 2: テストが失敗することを確認**

`run-tests {"system":"recurya/tests/web/notebook-routes"}`
Expected: `decode-state-token-published-unlisted` が FAIL（`vis` が nil）。

- [ ] **Step 3: `%decode-state-token` に published-unlisted を追加**

`web/routes.lisp` の `%decode-state-token` を以下に置換:

```lisp
(defun %decode-state-token (token)
  "Decode the new pill state TOKEN into (values STATUS VISIBILITY) or
NIL if invalid.

Tokens are:
  \"draft\"               -> (\"draft\" nil)         ; visibility unchanged
  \"published-private\"   -> (\"published\" \"private\")
  \"published-unlisted\"  -> (\"published\" \"unlisted\")
  \"published-public\"    -> (\"published\" \"public\")"
  (cond ((equal token "draft") (values "draft" nil))
        ((equal token "published-private")
         (values "published" "private"))
        ((equal token "published-unlisted")
         (values "published" "unlisted"))
        ((equal token "published-public")
         (values "published" "public"))
        (t nil)))
```

- [ ] **Step 4: テストが通ることを確認**

`run-tests {"system":"recurya/tests/web/notebook-routes"}`
Expected: `decode-state-token-published-unlisted` PASS（他テストも従来どおり）。

- [ ] **Step 5: コミット**

```bash
git add web/routes.lisp tests/web/notebook-routes.lisp
git commit -m "feat: decode published-unlisted state token"
```

---

### Task 3: create/update ハンドラとフォームで unlisted を受け付ける

**Files:**
- Modify: `web/routes.lisp`（`notebook-create-handler`, `notebook-update-handler`, `course-create-handler`, `course-update-handler` の visibility 検証）
- Modify: `web/ui/notebook-form.lisp`, `web/ui/course-form.lisp`（visibility select）
- Test: `tests/web/notebook-routes.lisp`, `tests/web/course-routes.lisp`

- [ ] **Step 1: 失敗するテストを追加**

`tests/web/notebook-routes.lisp` に追加（既存 `create-handler-persists-visibility-public` を踏襲）:

```lisp
(deftest create-handler-persists-visibility-unlisted
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let ((params '(("title" . "Unlisted NB")
                        ("slug" . "")
                        ("summary" . "")
                        ("body" . "===prose===
hi")
                        ("status" . "published")
                        ("visibility" . "unlisted"))))
          (notebook-create-handler params)
          (let ((nb (get-notebook-by-slug "unlisted-nb")))
            (ok nb)
            (ok (string= "unlisted" (notebook-visibility nb)))))))))
```

`get-notebook-by-slug` と `notebook-visibility` は notebook-routes テストの defpackage に既に import 済み。

`tests/web/course-routes.lisp` に追加（既存 `course-create-handler-persists-visibility-public` を踏襲）:

```lisp
(deftest course-create-handler-persists-visibility-unlisted
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let ((params '(("title" . "Unlisted Course")
                        ("slug" . "")
                        ("summary" . "")
                        ("status" . "published")
                        ("visibility" . "unlisted"))))
          (course-create-handler params)
          (let ((c (get-course-by-slug "unlisted-course")))
            (ok c)
            (ok (string= "unlisted" (course-visibility c)))))))))
```

- [ ] **Step 2: テストが失敗することを確認**

`run-tests {"system":"recurya/tests/web/notebook-routes"}` と
`run-tests {"system":"recurya/tests/web/course-routes"}`
Expected: 新テストが FAIL（"unlisted" が member 検証で弾かれ "private" にフォールバック）。

- [ ] **Step 3: 4ハンドラの visibility member 検証に "unlisted" を追加**

`web/routes.lisp` の **`notebook-create-handler`** と **`course-create-handler`** の
```lisp
               (visibility
                 (if (member visibility-raw '("private" "public") :test #'equal)
                     visibility-raw
                     "private")))
```
を
```lisp
               (visibility
                 (if (member visibility-raw '("private" "unlisted" "public") :test #'equal)
                     visibility-raw
                     "private")))
```
に置換する（両ハンドラとも同一文字列なので各1箇所）。

`web/routes.lisp` の **`notebook-update-handler`** と **`course-update-handler`** の
```lisp
                      (cond
                        ((member visibility-raw '("private" "public")
                                 :test #'equal)
                         visibility-raw)
```
を
```lisp
                      (cond
                        ((member visibility-raw '("private" "unlisted" "public")
                                 :test #'equal)
                         visibility-raw)
```
に置換する（両ハンドラとも同一文字列なので各1箇所）。

- [ ] **Step 4: フォームの visibility select に Unlisted を追加**

`web/ui/notebook-form.lisp` の visibility select の private と public の間に挿入:

```lisp
                          (:option :value "private"
                            :selected (when (equal nb-visibility "private") "selected")
                            "Private (only you)")
                          (:option :value "unlisted"
                            :selected (when (equal nb-visibility "unlisted") "selected")
                            "Unlisted (anyone with the link)")
                          (:option :value "public"
                            :selected (when (equal nb-visibility "public") "selected")
                            "Public (anyone)")))
```

`web/ui/course-form.lisp` の visibility select も同様に（変数名は `c-visibility`）:

```lisp
               (:option :value "private"
                 :selected (when (equal c-visibility "private") "selected")
                 "Private (only you)")
               (:option :value "unlisted"
                 :selected (when (equal c-visibility "unlisted") "selected")
                 "Unlisted (anyone with the link)")
               (:option :value "public"
                 :selected (when (equal c-visibility "public") "selected")
                 "Public (anyone)")))
```

- [ ] **Step 5: テストが通ることを確認**

`run-tests {"system":"recurya/tests/web/notebook-routes"}` と
`run-tests {"system":"recurya/tests/web/course-routes"}`
Expected: 新テスト PASS、既存テストも PASS。

- [ ] **Step 6: コミット**

```bash
git add web/routes.lisp web/ui/notebook-form.lisp web/ui/course-form.lisp \
        tests/web/notebook-routes.lisp tests/web/course-routes.lisp
git commit -m "feat: accept unlisted visibility in create/update forms and handlers"
```

---

### Task 4: 4状態ドロップダウン + Unlisted ピル

**Files:**
- Modify: `web/ui/notebooks-dashboard.lisp`（`render-notebook-state-dropdown` + `*page-styles*`）
- Modify: `web/ui/courses.lisp`（`render-course-state-dropdown` + `*page-styles*`）
- Test: `tests/web/notebook-routes.lisp`, `tests/web/course-routes.lisp`

- [ ] **Step 1: 失敗するテストを追加**

`tests/web/notebook-routes.lisp` に追加（既存の set-state テストを踏襲。notebook-routes には set-state テストが無いので新規に状態遷移を検証）:

```lisp
(deftest notebook-set-state-published-unlisted
  (testing "set-state published-unlisted persists unlisted and returns the
4-state dropdown with an Unlisted summary pill"
    (with-test-db
      (let* ((user (mk-user))
             (dao (get-user-by-id (getf user :id)))
             (nb (create-notebook!
                  :title "S" :body-md "===prose===
hi"
                  :cells '() :author dao
                  :status "draft" :visibility "private"))
             (id (princ-to-string (notebook-id nb))))
        (with-mock-session (make-session :user user)
          (let* ((res (notebook-set-state-handler
                       (list (cons :id id)
                             (cons "state" "published-unlisted"))))
                 (body (first (response-body res))))
            (ok (= 200 (response-status res)))
            (ok (search "status-unlisted" body))
            (ok (search "&quot;state&quot;:&quot;published-unlisted&quot;" body))
            (let ((after (get-notebook-by-id id)))
              (ok (string= "published" (notebook-status after)))
              (ok (string= "unlisted" (notebook-visibility after))))))))))
```

`notebook-set-state-handler` は notebook-routes テストの defpackage に既に import 済み。`notebook-status` も import 済み。

`tests/web/course-routes.lisp` に追加:

```lisp
(deftest course-set-state-published-unlisted
  (testing "set-state published-unlisted persists unlisted and returns the
4-state dropdown with an Unlisted summary pill"
    (with-test-db
      (let* ((user (mk-user))
             (dao (get-user-by-id (getf user :id)))
             (c (create-course! :title "S" :author dao
                                :status "draft" :visibility "private"))
             (id (princ-to-string (course-id c))))
        (with-mock-session (make-session :user user)
          (let* ((res (course-set-state-handler
                       (list (cons :id id)
                             (cons "state" "published-unlisted"))))
                 (body (first (response-body res))))
            (ok (= 200 (response-status res)))
            (ok (search "status-unlisted" body))
            (ok (search "&quot;state&quot;:&quot;published-unlisted&quot;" body))
            (let ((after (get-course-by-id id)))
              (ok (string= "published" (course-status after)))
              (ok (string= "unlisted" (course-visibility after))))))))))
```

- [ ] **Step 2: テストが失敗することを確認**

`run-tests {"system":"recurya/tests/web/notebook-routes"}` と
`run-tests {"system":"recurya/tests/web/course-routes"}`
Expected: 新テストが FAIL（`status-unlisted` クラスも `published-unlisted` ボタンも未生成）。

- [ ] **Step 3: `render-notebook-state-dropdown` を4状態化**

`web/ui/notebooks-dashboard.lisp` の `render-notebook-state-dropdown` 内
`state-class` と `label` の `let*` 束縛を以下に置換:

```lisp
         (state-class
          (cond ((equal status-lower "draft") "status-draft")
                ((equal visibility-lower "public") "status-public")
                ((equal visibility-lower "unlisted") "status-unlisted")
                (t "status-private")))
         (label
          (cond ((equal status-lower "draft") "Draft")
                ((equal visibility-lower "public") "Public")
                ((equal visibility-lower "unlisted") "Unlisted")
                (t "Private")))
```

同関数の `pill-menu` 内、Private ボタンと Public ボタンの間に Unlisted ボタンを挿入:

```lisp
          (:button :type "button" :hx-post state-url
            :hx-vals "{\"state\":\"published-private\"}"
            :hx-target dropdown-target :hx-swap "outerHTML"
            :hx-include "#csrf-form"
            "Private")
          (:button :type "button" :hx-post state-url
            :hx-vals "{\"state\":\"published-unlisted\"}"
            :hx-target dropdown-target :hx-swap "outerHTML"
            :hx-include "#csrf-form"
            "Unlisted")
          (:button :type "button" :hx-post state-url
            :hx-vals "{\"state\":\"published-public\"}"
            :hx-target dropdown-target :hx-swap "outerHTML"
            :hx-include "#csrf-form"
            "Public"))))))
```

- [ ] **Step 4: `render-course-state-dropdown` を4状態化**

`web/ui/courses.lisp` の `render-course-state-dropdown` に対し Step 3 と同一の置換を行う（`state-class` / `label` / Unlisted ボタン挿入。`state-url` は courses 用のものがそのまま使われる）。

- [ ] **Step 5: Unlisted ピルの色を両ダッシュボードに追加**

`web/ui/notebooks-dashboard.lisp` の `*page-styles*` 内、
`.status-pill.status-public { ... }` の行の直後に追加:

```
.status-pill.status-unlisted { background: #1e40af; color: #dbeafe; }
```

`web/ui/courses.lisp` の `*page-styles*` にも同じ1行を同じ位置に追加。

- [ ] **Step 6: テストが通ることを確認**

`run-tests {"system":"recurya/tests/web/notebook-routes"}` と
`run-tests {"system":"recurya/tests/web/course-routes"}`
Expected: 新テスト PASS、既存の set-state / dropdown テストも PASS。

- [ ] **Step 7: コミット**

```bash
git add web/ui/notebooks-dashboard.lisp web/ui/courses.lisp \
        tests/web/notebook-routes.lisp tests/web/course-routes.lisp
git commit -m "feat: 4-state dropdown with Unlisted pill for notebooks and courses"
```

---

### Task 5: ダッシュボードに unlisted の共有リンクコピーを追加

**Files:**
- Modify: `web/ui/notebooks-dashboard.lisp`（`render` の actions-cell）
- Modify: `web/ui/courses.lisp`（`render` の actions-cell）
- Test: `tests/web/notebook-routes.lisp`, `tests/web/course-routes.lisp`

- [ ] **Step 1: 失敗するテストを追加**

`tests/web/notebook-routes.lisp` に追加（既存 `list-pill-renders-state-dropdown` を踏襲。`notebooks-handler` 経由で一覧をレンダリング）:

```lisp
(deftest dashboard-shows-copy-link-for-unlisted-only
  (testing "an unlisted notebook row exposes a copy-link affordance; a public
notebook row does not"
    (with-test-db
      (let* ((user (mk-user))
             (dao (get-user-by-id (getf user :id))))
        (create-notebook!
         :title "UnlistedRow" :slug "unlisted-row" :body-md "===prose===
hi"
         :cells '() :author dao :status "published" :visibility "unlisted"
         :published-at (local-time:now))
        (with-mock-session (make-session :user user)
          (let ((body (first (response-body (notebooks-handler nil)))))
            (ok (search "copy-link-btn" body)
                "unlisted row has a copy-link button")
            (ok (search (format nil "/@~A/unlisted-row" (users-handle dao))
                        body)
                "copy-link carries the share URL")))))))
```

`users-handle` は notebook-routes テストの defpackage に既に import 済み。

`tests/web/course-routes.lisp` に追加:

```lisp
(deftest dashboard-shows-copy-link-for-unlisted-course-only
  (testing "an unlisted course row exposes a copy-link affordance"
    (with-test-db
      (let* ((user (mk-user))
             (dao (get-user-by-id (getf user :id))))
        (create-course! :title "UnlistedC" :slug "unlisted-c"
                        :status "published" :visibility "unlisted"
                        :published-at (local-time:now) :author dao)
        (with-mock-session (make-session :user user)
          (let ((body (first (response-body (courses-me-handler nil)))))
            (ok (search "copy-link-btn" body))
            (ok (search (format nil "/c/@~A/unlisted-c" (users-handle dao))
                        body))))))))
```

`users-handle` は course-routes テストの defpackage に既に import 済み。

- [ ] **Step 2: テストが失敗することを確認**

`run-tests {"system":"recurya/tests/web/notebook-routes"}` と
`run-tests {"system":"recurya/tests/web/course-routes"}`
Expected: 新テストが FAIL（`copy-link-btn` 未生成）。

- [ ] **Step 3: Notebook ダッシュボードの actions-cell にコピーリンクを追加**

`web/ui/notebooks-dashboard.lisp` の `render` 内、actions-cell の Delete ボタンの直後に追加:

```lisp
                      (:button :class "button-danger btn-sm" :hx-get
                       (format nil "/dashboard/notebooks/~A/confirm-delete"
                               id)
                       :hx-target "#modal-container" :hx-swap "innerHTML"
                       "Delete")
                      (when (and (string= visibility "unlisted")
                                 slug user-handle)
                        (:button :type "button" :class "link copy-link-btn"
                         :data-share-url (format nil "/@~A/~A" user-handle slug)
                         :onclick "navigator.clipboard.writeText(location.origin+this.dataset.shareUrl)"
                         "Copy link")))))))))
```

注: 既存コードでは actions-cell の `:div` は Delete ボタンで閉じている。Delete ボタンの後ろに `(when ...)` を追加し、`:div`（actions-cell）と各 `let*`/`dolist`/`tr` の閉じ括弧構成を保つこと。`lisp-edit-form` で `render` フォーム全体を置換するのが安全。

- [ ] **Step 4: Course ダッシュボードの actions-cell にコピーリンクを追加**

`web/ui/courses.lisp` の `render` 内、actions-cell の Delete ボタンの直後に追加:

```lisp
                      (:button :class "button-danger btn-sm" :hx-get
                       (format nil "/dashboard/courses/~A/confirm-delete" id)
                       :hx-target "#modal-container" :hx-swap "innerHTML"
                       "Delete")
                      (when (and (string= visibility "unlisted")
                                 slug user-handle)
                        (:button :type "button" :class "link copy-link-btn"
                         :data-share-url (format nil "/c/@~A/~A" user-handle slug)
                         :onclick "navigator.clipboard.writeText(location.origin+this.dataset.shareUrl)"
                         "Copy link")))))))))
```

- [ ] **Step 5: テストが通ることを確認**

`run-tests {"system":"recurya/tests/web/notebook-routes"}` と
`run-tests {"system":"recurya/tests/web/course-routes"}`
Expected: 新テスト PASS、既存テストも PASS。

- [ ] **Step 6: コミット**

```bash
git add web/ui/notebooks-dashboard.lisp web/ui/courses.lisp \
        tests/web/notebook-routes.lisp tests/web/course-routes.lisp
git commit -m "feat: copy-link affordance for unlisted notebooks/courses on dashboard"
```

---

### Task 6: 非公開ページに noindex メタを出力

**Files:**
- Modify: `web/ui/notebook.lisp`（`render` に `:noindex` 引数 + head に meta）
- Modify: `web/ui/course.lisp`（`render` に `:noindex` 引数 → page-shell の head-extras）
- Modify: `web/routes.lisp`（`%render-public-notebook-response`, `%render-public-course-response`）
- Test: `tests/web/notebook-routes.lisp`, `tests/web/course-routes.lisp`

- [ ] **Step 1: 失敗するテストを追加**

`tests/web/notebook-routes.lisp` に追加:

```lisp
(deftest unlisted-notebook-page-has-noindex
  (testing "an unlisted notebook page carries robots=noindex; a public one
does not"
    (with-test-db
      (let* ((dao (create-test-user :email-prefix "ix" :handle "ix-7b"))
             (handle (users-handle dao)))
        (create-notebook! :title "U" :slug "u-nb" :body-md "===prose===
hi"
                          :cells nil :author dao
                          :status "published" :visibility "unlisted"
                          :published-at (local-time:now))
        (create-notebook! :title "P" :slug "p-nb" :body-md "===prose===
hi"
                          :cells nil :author dao
                          :status "published" :visibility "public"
                          :published-at (local-time:now))
        (with-mock-session (make-session)
          (let ((u-body (first (response-body
                                (public-notebook-by-handle-handler
                                 `((:captures . (,handle "u-nb")))))))
                (p-body (first (response-body
                                (public-notebook-by-handle-handler
                                 `((:captures . (,handle "p-nb"))))))))
            (ok (search "noindex" u-body) "unlisted page is noindex")
            (ng (search "noindex" p-body) "public page is indexable")))))))
```

`tests/web/course-routes.lisp` に追加（既存の公開Course閲覧テストを踏襲。匿名で unlisted course を閲覧）:

```lisp
(deftest unlisted-course-page-has-noindex
  (testing "an unlisted course page carries robots=noindex; a public one does not"
    (with-test-db
      (let* ((dao (create-test-user :email-prefix "ix" :handle "ixc-7b"))
             (handle (users-handle dao)))
        (create-course! :title "U" :slug "u-c"
                        :status "published" :visibility "unlisted"
                        :published-at (local-time:now) :author dao)
        (create-course! :title "P" :slug "p-c"
                        :status "published" :visibility "public"
                        :published-at (local-time:now) :author dao)
        (with-mock-session (make-session)
          (let ((u-body (first (response-body
                                (public-course-by-handle-handler
                                 `((:captures . (,handle "u-c")))))))
                (p-body (first (response-body
                                (public-course-by-handle-handler
                                 `((:captures . (,handle "p-c"))))))))
            (ok (search "noindex" u-body))
            (ng (search "noindex" p-body))))))))
```

`public-course-by-handle-handler` と `users-handle` は course-routes テストの defpackage に既に import 済み。

- [ ] **Step 2: テストが失敗することを確認**

`run-tests {"system":"recurya/tests/web/notebook-routes"}` と
`run-tests {"system":"recurya/tests/web/course-routes"}`
Expected: 新テストが FAIL（`noindex` メタ未出力）。

- [ ] **Step 3: 公開Notebook render に `:noindex` 引数を追加**

`web/ui/notebook.lisp` の `render` のラムダリストに `noindex` を追加:

```lisp
(defun render (notebook
               &key user saved-codes passed-cells
                    (sidebar-notebooks nil) run-cell-base
                    course-title course-slug course-handle
                    breadcrumb course-prev-url course-next-url
                    noindex)
```

同関数の head 内、`(:title (notebook-title notebook))` の直後に追加:

```lisp
        (:title (notebook-title notebook))
        (when noindex (:meta :name "robots" :content "noindex"))
```

- [ ] **Step 4: 公開Course render に `:noindex` 引数を追加**

`web/ui/course.lisp` の `render` のラムダリストに `noindex` を追加:

```lisp
(defun render (&key course notebooks user passed-by-notebook noindex)
```

同関数の `page-shell` 呼び出しに `:head-extras` を追加（`:user user` の直後など、キーワード引数として）:

```lisp
     :user user
     :head-extras (when noindex
                    "<meta name=\"robots\" content=\"noindex\">")
```

- [ ] **Step 5: ハンドラから noindex を渡す**

`web/routes.lisp` の `%render-public-notebook-response` 内、`recurya/web/ui/notebook:render` を呼ぶ箇所が2つある（course-context 有/無）。両方の呼び出しに `:noindex` を追加する。判定値はローカルに束縛して使い回すのが安全。`let*` の束縛に追加:

```lisp
              (nb-noindex
               (not (string= (notebook-visibility nb-row) "public")))
```

そして2つの `(recurya/web/ui/notebook:render notebook ...)` 呼び出しそれぞれに
`:noindex nb-noindex` を追加する。

`%render-public-course-response` 内の `recurya/web/ui/course:render` 呼び出しに追加:

```lisp
          (recurya/web/ui/course:render
           :course (course->plist course-row)
           :notebooks notebooks
           :user user
           :passed-by-notebook nil
           :noindex (not (string= (course-visibility course-row) "public")))
```

- [ ] **Step 6: テストが通ることを確認**

`run-tests {"system":"recurya/tests/web/notebook-routes"}` と
`run-tests {"system":"recurya/tests/web/course-routes"}`
Expected: 新テスト PASS、既存の公開ページテストも PASS。

- [ ] **Step 7: コミット**

```bash
git add web/ui/notebook.lisp web/ui/course.lisp web/routes.lisp \
        tests/web/notebook-routes.lisp tests/web/course-routes.lisp
git commit -m "feat: emit robots=noindex on non-public notebook/course pages"
```

---

### Task 7: 回帰テスト — unlisted は一覧・プロフィールに出ない

**Files:**
- Test: `tests/web/notebook-routes.lisp`, `tests/web/course-routes.lisp`

このタスクはコード変更なし（Task 1 で据え置いた挙動の回帰ガード）。

- [ ] **Step 1: 回帰テストを追加**

`tests/web/notebook-routes.lisp` に追加（`notebooks-public-handler` と `profile-handler` を使う。`profile-handler` を import に追加する必要がある場合は defpackage の `:import-from #:recurya/web/routes` に `#:profile-handler` を追加）:

```lisp
(deftest unlisted-notebook-absent-from-public-listing-and-profile
  (testing "an unlisted notebook appears on neither /notebooks nor /@handle"
    (with-test-db
      (let* ((dao (create-test-user :email-prefix "hid" :handle "hid-7b"))
             (handle (users-handle dao)))
        (create-notebook! :title "HiddenList" :slug "hidden-list"
                          :body-md "===prose===
hi"
                          :cells nil :author dao
                          :status "published" :visibility "unlisted"
                          :published-at (local-time:now))
        (with-mock-session (make-session)
          (let ((listing (first (response-body (notebooks-public-handler nil))))
                (profile (first (response-body
                                 (profile-handler
                                  `((:captures . (,handle))))))))
            (ng (search "HiddenList" listing) "not in /notebooks")
            (ng (search "HiddenList" profile) "not on /@handle profile")))))))
```

`tests/web/course-routes.lisp` に追加（`courses-public-handler` を使う。`profile-handler` で course 非掲載も確認したい場合は notebook-routes 側にまとめる）:

```lisp
(deftest unlisted-course-absent-from-public-listing
  (testing "an unlisted course does not appear on /courses"
    (with-test-db
      (let* ((dao (create-test-user :email-prefix "hidc" :handle "hidc-7b")))
        (declare (ignore))
        (create-course! :title "HiddenCourse" :slug "hidden-course"
                        :status "published" :visibility "unlisted"
                        :published-at (local-time:now) :author dao)
        (with-mock-session (make-session)
          (let ((listing (first (response-body (courses-public-handler nil)))))
            (ng (search "HiddenCourse" listing))))))))
```

import 確認: notebook-routes の defpackage に `#:notebooks-public-handler` と
`#:profile-handler` を、course-routes の defpackage に `#:courses-public-handler` を
`:import-from #:recurya/web/routes` 配下へ追加（未 import の場合のみ）。

- [ ] **Step 2: テストを実行して通ることを確認**

`run-tests {"system":"recurya/tests/web/notebook-routes"}` と
`run-tests {"system":"recurya/tests/web/course-routes"}`
Expected: 新テスト PASS（Task 1 でロジックは既に正しいため、回帰ガードとして即 green）。

- [ ] **Step 3: コミット**

```bash
git add tests/web/notebook-routes.lisp tests/web/course-routes.lisp
git commit -m "test: guard that unlisted items stay out of listings and profile"
```

---

### Task 8: 全体検証 + マージ + push

**Files:** なし（検証とGit操作）

- [ ] **Step 1: テーブル無変更を確認**

`git diff --stat main..feat/limited-sharing` に
`models/notebook.lisp` / `models/course.lisp` / `db/schema.sql` /
`db/migrations/*` が **含まれないこと** を目視確認。

- [ ] **Step 2: 全システム強制コンパイル + 全スイートを fresh プロセスで実行**

```bash
docker compose exec -T recurya qlot exec ros run \
  -e '(handler-bind ((warning (lambda (w) (format t "~&;;WARN;; ~A~%" w)))) (asdf:compile-system :recurya :force t))' \
  -e '(ql:quickload :recurya/tests :silent t)' \
  -e '(uiop:quit (if (recurya/tests/all:run-all-tests) 0 1))'
```
Expected: 終了コード 0。`;;WARN;;` に undefined/unused/redefining 以外の新規警告が出ないこと。

- [ ] **Step 3: マージして push（プロジェクト慣例: --no-ff）**

```bash
git checkout main
git merge --no-ff feat/limited-sharing -m "Merge branch 'feat/limited-sharing' into main

Add unlisted visibility (limited sharing) for notebooks and courses:
viewable by URL, excluded from public listings/profile, noindex meta,
and a 4-state dashboard dropdown with copy-link. No migration."
git push origin main
```
Expected: push 成功、`main` と `origin/main` が同期。

---

## Self-Review

**Spec coverage（design セクション → タスク対応）:**
- §3 アクセスモデル（閲覧/掲載分離）→ Task 1
- §A can-view-* → Task 1
- §B 一覧変更不要 → Task 7（回帰ガード）
- §C 状態モデル & UI（4状態 / decode / create-update / forms）→ Task 2, 3, 4
- §D ピル表示 → Task 4
- §E 共有URLコピー → Task 5
- §F noindex → Task 6
- §マイグレーション不要 → Task 8 Step 1（無変更確認）
- すべてのセクションに対応タスクあり。ギャップなし。

**Placeholder scan:** "TBD"/"TODO"/曖昧指示なし。全コード手順に実コードを記載。noindex 注入点は確定済み（notebook=引数, course=head-extras）。

**Type consistency:** `visibility` 値は一貫して `"private"/"unlisted"/"public"`。状態トークンは `"published-unlisted"`。CSSクラスは `status-unlisted`。コピーボタンクラスは `copy-link-btn`。data属性は `data-share-url`。関数名・引数（`:noindex`, `notebook-visibility`, `course-visibility`, `%decode-state-token`）はタスク間で一致。
