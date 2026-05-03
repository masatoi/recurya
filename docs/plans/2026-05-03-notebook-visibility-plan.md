# Notebook 公開範囲（visibility）実装計画

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** `user_notebook` と `course` に `visibility` 列を追加し `state × visibility` の 2 軸モデルにする。MVP では `private` / `public` の 2 値。アクセス判定を中央集約 (`can-view-notebook-p` / `can-view-course-p` / `publicly-listable-*-p`) し、将来 `unlisted` / `shared` / `organization` / `subscriber` を追加するときに 1 関数の修正で済むようにする。

**Architecture:** マイグレーションで `visibility VARCHAR(32) NOT NULL DEFAULT 'private'` 列を `user_notebook` と `course` に追加し、既存 `published` 行を `visibility='public'` へ。アクセス判定関数を `utils/access-control.lisp` に集約し、各ハンドラはその関数を呼ぶだけにする。UI は form に visibility select を追加、status pill を 3 状態（Draft/Private/Public）に拡張。

**Tech Stack:** Common Lisp / SBCL + qlot, Mito ORM + cl-dbi (PostgreSQL), Ningle + Clack/Hunchentoot, Spinneret HTML, HTMX, Rove tests. 新規依存なし。

**Reference:** 設計ドキュメント [`docs/plans/2026-05-03-notebook-visibility-design.md`](./2026-05-03-notebook-visibility-design.md) を必ず参照。

**Lispツール規約:** すべての `.lisp`/`.asd` 操作は cl-mcp ツール（`lisp-edit-form`/`lisp-patch-form`/`lisp-read-file`/`repl-eval`/`load-system`/`run-tests` 等）。Read/Edit/Write/Grep/Glob はLispファイルに使わない。Markdown/SQL は通常の Write/Edit 可。

**初期セットアップ:** 各セッション冒頭で `mcp__cl-mcp__fs-set-project-root path=/home/wiz/recurya` を呼ぶ。

**コミット方針:** 各タスクを「テスト→失敗確認→実装→成功確認→コミット」で 1 タスク 1 コミット。コミットメッセージは `feat:` `test:` `refactor:` `chore:` プレフィックス + 既存スタイル（命令法、末尾 `Co-Authored-By:` 行）。

**ブランチ:** `feat/notebook-visibility` を `main` から切って作業。

---

## Phase 1: モデル + マイグレーション

### Task 1: deftable に visibility 列追加

**Files:**
- Modify: `models/user-notebook.lisp`
- Modify: `models/course.lisp`

**Step 1: スロット + accessor 追加**

`user-notebook` deftable のスロット定義に visibility を追加:

```lisp
(visibility :col-type (:varchar 32) :initarg :visibility
            :initform "private"
            :accessor user-notebook-visibility)
```

`:export` リストに `#:user-notebook-visibility` を追加。

**Step 2: course モデルにも同様の追加**

```lisp
(visibility :col-type (:varchar 32) :initarg :visibility
            :initform "private"
            :accessor course-visibility)
```

`:export` に `#:course-visibility` を追加。

**Step 3: load 確認**

```
mcp__cl-mcp__load-system system="recurya/models/user-notebook"
mcp__cl-mcp__load-system system="recurya/models/course"
```

**Step 4: コミット**

```bash
git commit -am "feat: add visibility column to user-notebook and course models"
```

---

### Task 2: Mito マイグレーション生成と適用

**Files:**
- Create: `db/migrations/<ts>-visibility.up.sql`
- Create: `db/migrations/<ts>-visibility.down.sql`
- Modify: `db/schema.sql`（自動更新）

**Step 1: マイグレーション生成**

```bash
.qlot/bin/mito generate-migrations -t postgres -H localhost -P 15434 \
  -d recurya -u postgres -p postgres -s recurya -D db/
```

期待: `ALTER TABLE user_notebook ADD COLUMN visibility VARCHAR(32) NOT NULL DEFAULT 'private'` と `course` 側の同等 SQL。

**Step 2: 既存 published を public 化する UPDATE を手動追加**

生成された `.up.sql` の末尾に以下を追加:

```sql
UPDATE "user_notebook" SET "visibility" = 'public' WHERE "status" = 'published';
UPDATE "course"        SET "visibility" = 'public' WHERE "status" = 'published';
```

`.down.sql` には対応する DROP COLUMN が入っているはず（Mito 自動）。

**Step 3: 適用**

```bash
.qlot/bin/mito migrate -t postgres -H localhost -P 15434 \
  -d recurya -u postgres -p postgres -s recurya -D db/
```

**Step 4: 確認**

```bash
PGPASSWORD=postgres psql -h localhost -p 15434 -U postgres -d recurya \
  -c '\d user_notebook' -c '\d course' \
  -c "SELECT status, visibility, COUNT(*) FROM user_notebook GROUP BY status, visibility;"
```

期待: visibility 列が両テーブルに存在、SICP 55 行が `published+public`、user-created notebook が `draft+private` または `published+public`。

**Step 5: コミット**

```bash
git add db/migrations/ db/schema.sql
git commit -m "feat: visibility column migration for user_notebook and course"
```

---

## Phase 2: アクセス制御関数の中央集約

### Task 3: utils/access-control.lisp 新規 + 失敗テスト

**Files:**
- Create: `utils/access-control.lisp`
- Create: `tests/utils/access-control.lisp`
- Modify: `recurya.asd`、`tests/all.lisp`

**Step 1: 雛形（stub）作成**

`utils/access-control.lisp`:

```lisp
;;;; utils/access-control.lisp --- Centralised viewability rules.

(defpackage #:recurya/utils/access-control
  (:use #:cl)
  (:import-from #:recurya/db/user-notebooks
                #:user-notebook-status #:user-notebook-visibility
                #:user-notebook-author-id)
  (:import-from #:recurya/db/courses
                #:course-status #:course-visibility #:course-author-id)
  (:export #:can-view-notebook-p
           #:can-view-course-p
           #:publicly-listable-notebook-p
           #:publicly-listable-course-p))

(in-package #:recurya/utils/access-control)

(defun can-view-notebook-p (user notebook)
  (declare (ignore user notebook))
  (error "not implemented"))

(defun can-view-course-p (user course)
  (declare (ignore user course))
  (error "not implemented"))

(defun publicly-listable-notebook-p (notebook)
  (declare (ignore notebook))
  (error "not implemented"))

(defun publicly-listable-course-p (course)
  (declare (ignore course))
  (error "not implemented"))
```

**Step 2: テスト（先に失敗）**

`tests/utils/access-control.lisp` で:

```lisp
(deftest can-view-notebook-published-public
  (with-test-db
    (let* ((u (create-test-user))
           (other (create-test-user :email-prefix "other"))
           (nb (create-user-notebook!
                :title "T" :body-md "===prose===
x" :cells '() :author u
                :status "published" :visibility "public")))
      (ok (can-view-notebook-p (user-plist u) nb))
      (ok (can-view-notebook-p (user-plist other) nb))
      (ok (can-view-notebook-p nil nb)))))

(deftest can-view-notebook-published-private
  ...)

(deftest can-view-notebook-draft-private
  ...)

(deftest can-view-notebook-draft-public
  ...)

(deftest publicly-listable-notebook-only-published-public
  ...)

(deftest can-view-course-published-public
  ...)
;; ...
```

**Step 3: ASDF 登録**

主システムに `"recurya/utils/access-control"`、テストシステムに `"recurya/tests/utils/access-control"`、`tests/all.lisp` に `:recurya/tests/utils/access-control`。

`db/user-notebooks.lisp` の `create-user-notebook!` に `:visibility` キーワード引数を追加（デフォルト nil → DAO の `initform "private"` が効く）。`db/courses.lisp` の `create-course!` も同様。

**Step 4: 失敗確認**

```
mcp__cl-mcp__run-tests system="recurya/tests/utils/access-control"
```

期待: 全テスト「not implemented」FAIL。

**Step 5: コミット**

```bash
git add utils/access-control.lisp tests/utils/access-control.lisp recurya.asd tests/all.lisp db/user-notebooks.lisp db/courses.lisp
git commit -m "test: add failing tests for centralised access control"
```

---

### Task 4: アクセス制御関数を実装

**Files:**
- Modify: `utils/access-control.lisp`

**Step 1: 実装**

```lisp
(defun owner-of-notebook-p (user notebook)
  (and user notebook
       (equal (princ-to-string (user-notebook-author-id notebook))
              (princ-to-string (getf user :id)))))

(defun can-view-notebook-p (user notebook)
  (cond
    ((null notebook) nil)
    ((owner-of-notebook-p user notebook) t)
    ((string/= "published" (user-notebook-status notebook)) nil)
    (t (let ((vis (user-notebook-visibility notebook)))
         (cond
           ((string= vis "public") t)
           ((string= vis "private") nil)
           ;; 将来の visibility 値はここに追加
           (t nil))))))

(defun publicly-listable-notebook-p (notebook)
  (and notebook
       (string= "published" (user-notebook-status notebook))
       (string= "public" (user-notebook-visibility notebook))))

;; course 側も同型
(defun owner-of-course-p (user course)
  (and user course
       (equal (princ-to-string (course-author-id course))
              (princ-to-string (getf user :id)))))

(defun can-view-course-p (user course)
  (cond
    ((null course) nil)
    ((owner-of-course-p user course) t)
    ((string/= "published" (course-status course)) nil)
    (t (let ((vis (course-visibility course)))
         (cond
           ((string= vis "public") t)
           ((string= vis "private") nil)
           (t nil))))))

(defun publicly-listable-course-p (course)
  (and course
       (string= "published" (course-status course))
       (string= "public" (course-visibility course))))
```

**Step 2: テスト PASS**

期待: 全テスト PASS。

**Step 3: コミット**

```bash
git commit -am "feat: implement can-view-notebook-p / can-view-course-p"
```

---

## Phase 3: db 層に visibility フィルタ追加

### Task 5: list-user-notebooks / count-user-notebooks に :visibility 引数

**Files:**
- Modify: `db/user-notebooks.lisp`
- Modify: `tests/db/user-notebooks.lisp`

**Step 1: 失敗テスト追加**

```lisp
(deftest list-user-notebooks-filters-visibility
  (with-test-db
    (let ((u (create-test-user)))
      (create-user-notebook! :title "P" :body-md "..." :cells '() :author u
                              :status "published" :visibility "public")
      (create-user-notebook! :title "Q" :body-md "..." :cells '() :author u
                              :status "published" :visibility "private")
      (let ((pub (list-user-notebooks :status "published" :visibility "public"))
            (pri (list-user-notebooks :status "published" :visibility "private")))
        (ok (= 1 (length pub)))
        (ok (= 1 (length pri)))))))

(deftest count-user-notebooks-filters-visibility
  ...)
```

**Step 2-5: 失敗確認 → 実装 → 成功 → コミット**

実装は既存の `:author-id` 引数と同型で `:visibility` を追加。`(when visibility (push '... conditions))` のパターン。`list-user-notebooks` の sxql `where` にも追加。

```bash
git commit -am "feat: add :visibility filter to list/count-user-notebooks"
```

---

### Task 6: list-courses / count-courses に :visibility 引数

**Files:**
- Modify: `db/courses.lisp`
- Modify: `tests/db/courses.lisp`

Task 5 と同型。コミット:

```bash
git commit -am "feat: add :visibility filter to list/count-courses"
```

---

## Phase 4: ハンドラを access-control 経由に切り替え

### Task 7: public-user-notebook-handler を can-view-notebook-p で判定

**Files:**
- Modify: `web/routes.lisp`
- Modify: `tests/web/user-notebook-routes.lisp`

**Step 1: テスト追加（先に失敗）**

```lisp
(deftest public-page-published-private-404-for-others
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user))
           (dao (get-user-by-id (getf owner :id))))
      (create-user-notebook! :title "X" :slug "priv" :body-md "===prose===
hi"
                              :cells '() :author dao
                              :status "published" :visibility "private"
                              :published-at (local-time:now))
      (with-mock-session (make-session :user other)
        (let ((res (public-user-notebook-handler '((:slug . "priv")))))
          (ok (= 404 (response-status res))))))))

(deftest public-page-published-private-200-for-owner
  ...)
```

**Step 2-5: 失敗確認 → 実装 → 成功 → コミット**

実装は条件式を `can-view-notebook-p` 呼び出しに置き換え:

```lisp
(cond
  ((null nb-row) (html-response (not-found) :status 404))
  ((not (recurya/utils/access-control:can-view-notebook-p user nb-row))
   (html-response (not-found) :status 404))
  (t ...))
```

```bash
git commit -am "refactor: route public-user-notebook-handler through can-view-notebook-p"
```

---

### Task 8: notebooks-public-handler を publicly-listable-* 経由に

**Files:**
- Modify: `web/routes.lisp`
- Modify: `tests/web/user-notebook-routes.lisp`

`list-user-notebooks :status "published"` を `:status "published" :visibility "public"` に変更。テストで private が一覧に出ないことを assert。

```bash
git commit -am "refactor: notebooks-public-handler shows only published+public"
```

---

### Task 9: course-eligible-notebooks も published+public のみ

**Files:**
- Modify: `web/routes.lisp`
- Modify: `tests/web/course-routes.lisp`

`course-eligible-notebooks` を `:status "published" :visibility "public"` で絞る。テスト追加。

```bash
git commit -am "refactor: course attach候補 to published+public only"
```

---

### Task 10: public-user-notebook-cell-run-handler も同じ判定に

**Files:**
- Modify: `web/routes.lisp`
- Modify: `tests/web/user-notebook-routes.lisp`

run-cell ハンドラの「draft AND NOT owner」分岐を `can-view-notebook-p` に置換。テスト追加（private notebook の run-cell が他人 404）。

```bash
git commit -am "refactor: run-cell handler uses can-view-notebook-p"
```

---

### Task 11: public-course-handler / courses-public-handler を同じ判定に

**Files:**
- Modify: `web/routes.lisp`
- Modify: `tests/web/course-routes.lisp`

`public-course-handler` の「draft AND NOT owner」を `can-view-course-p` に置換。`courses-public-handler` の `list-courses` を `:visibility "public"` で絞る。テスト追加。

```bash
git commit -am "refactor: course public handlers use can-view-course-p"
```

---

## Phase 5: UI 更新

### Task 12: フォームに visibility select を追加

**Files:**
- Modify: `web/ui/user-notebook-form.lisp`
- Modify: `web/ui/course-form.lisp`

Status select の直下に Visibility select を追加。draft 時は disabled でも良いが MVP は enable のまま。フォーム plist に `:visibility` を追加（デフォルト "private"）。

ハンドラ側 `course-create-handler` / `course-update-handler` / `user-notebook-create-handler` / `user-notebook-update-handler` で `(get-param params "visibility")` を読み取り、create/update 関数に渡す。

スモークテストで render の出力に `name="visibility"` が含まれること、edit 時に既存値が selected になることを確認。

```bash
git commit -am "feat: add visibility select to user-notebook and course forms"
```

---

### Task 13: status pill を 3 状態化

**Files:**
- Modify: `web/routes.lisp`（`render-user-notebook-status-pill` `render-course-status-pill`）
- Modify: `web/ui/user-notebooks.lisp` / `web/ui/courses.lisp`（CSS とラベル）
- Modify: `tests/web/*` の status pill 出力に依存していたテスト

3 状態:
- `draft + *` → `Draft` 黄
- `published + private` → `Private` 紫
- `published + public` → `Public` 緑

Pill のクリックで `/notebooks/:id/visibility` (or `/notebooks/:id/state`) に POST する HTMX を考えるのは Task 14 以降。Task 13 はラベル/色のみ。

```bash
git commit -am "feat: render 3-state status pill (Draft/Private/Public)"
```

---

### Task 14: pill ドロップダウンで state/visibility を切替

**Files:**
- Modify: `web/routes.lisp`
- Modify: `web/ui/user-notebooks.lisp` / `web/ui/courses.lisp`
- Modify: `tests/web/*`

Pill クリック → 小さいドロップダウン (`Draft / Private / Public`) → 選択で `POST /notebooks/:id/state`（仮）。state パラメータは `draft` / `published-private` / `published-public` の 3 値を受け取って (state, visibility) に分解。owner-only。

旧 `/notebooks/:id/toggle-status` は当面残し、旧クライアントが叩いても `published private ↔ draft+private` を切り替えるようにする（互換）。新 UI からは `/state` を叩く。

course 側も同型。テスト追加。

```bash
git commit -am "feat: HTMX dropdown to set state/visibility from status pill"
```

---

## Phase 6: 仕上げ

### Task 15: 全テスト + 既存テストのフィクスチャ調整

**Files:**
- Modify: `tests/web/user-notebook-routes.lisp`、`tests/web/course-routes.lisp`、`tests/integration/sicp-canonical-solutions.lisp` 等、既存テストで visibility が暗黙 private になって挙動が変わる箇所

**Step 1: 全テスト走らせる**

```bash
docker compose exec -e POSTGRES_HOST=postgres -e POSTGRES_PORT=5432 recurya bash -lc \
  '/home/app/.roswell/bin/qlot exec .qlot/bin/rove recurya.asd'
```

期待: 21+ system 全 PASS（visibility 関連の新テストが追加されている）。

**Step 2: 失敗があれば fixture 修正**

`create-user-notebook! :status "published"` で他人にも見えると assume している既存テストは `:visibility "public"` を渡すように修正。

**Step 3: 手動スモークテスト**

ブラウザで:
1. `/notebooks/me` で 3 状態の pill が見える
2. New notebook → Draft で作成 → 他人 404
3. Pill から Public へ切替 → `/notebooks` 一覧に出る、他人 200
4. Pill から Private へ切替 → 一覧から消える、他人 404、自分 200
5. Course `/c/sicp` の Notebook カードが全部表示（既存挙動変わらず）
6. Course を Private にする → 他人 404、自分 200

**Step 4: コミット**

```bash
git commit -am "test: adjust fixtures for visibility default and full pass"
```

---

### Task 16: 最終レビュー

**Files:** なし（検証のみ）。

- subagent code-reviewer に main..HEAD をかけて、`can-view-notebook-p` の使い漏れ箇所を含むレビュー
- 開発ブランチ手仕舞い（`superpowers:finishing-a-development-branch`）

---

## 完了基準

- [ ] 全テスト（既存 + 新規）PASS
- [ ] 手動スモークテスト 6 項目 PASS
- [ ] PR 作成可能な状態（`feat/notebook-visibility` ブランチ）
- [ ] 将来の visibility 拡張ポイントが `can-view-notebook-p` の `cond` 1 箇所に集約されている

## 注意事項

- **visibility 列に CHECK 制約を付けない**: 将来 `unlisted` `shared` 等を追加するとき migration を不要にするため
- **既存 toggle-status エンドポイントは互換性維持**: 旧クライアントから叩かれても `draft ↔ published+private` を切り替えるようにし、新 UI は `/state` ドロップダウン経由
- **DEFAULT 'private'**: 新規作成時に明示的に visibility を渡さなければ private になる。テスト fixture や create-handler で意識する
- **SICP コースの動作維持**: マイグレーションで全 published 行が public 化されるので、SICP は引き続き全員に見える状態を維持
