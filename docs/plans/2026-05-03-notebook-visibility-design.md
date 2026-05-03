# Notebook 公開範囲（state × visibility）設計

- 起票: 2026-05-03
- ブランチ: `feat/notebook-visibility`（新規）
- ステータス: ブレスト承認済み、実装計画作成へ
- 関連:
  - 直前のマージ [`docs/plans/2026-05-03-courses-and-sicp-migration-design.md`](./2026-05-03-courses-and-sicp-migration-design.md)
  - データ層 `models/user-notebook.lisp` `models/course.lisp` `db/user-notebooks.lisp` `db/courses.lisp`

## 1. 背景

現状 `user_notebook` と `course` は単一の `status VARCHAR(32)` 列だけで公開範囲を表している。値は `'draft'` / `'published'` の 2 値で、ハンドラは:

- `'draft'` → author のみ閲覧可（他人は 404）
- `'published'` → 全員に閲覧可

機能上は draft が「実質 private」として動いているが、意味論的に混在している:

- 「下書き（公開準備中）」と「自分専用ノート（永続的に非公開）」が同じ `'draft'` 値で表される
- ユーザは「いつか public にしないといけない draft」しか発信できない印象を受け、自分用の練習ノートを大量に作りにくい
- 将来「URL を知ってる人だけ閲覧可（unlisted）」「特定ユーザに招待」「組織内」「課金者限定」を足すとき、`status` 列の値で表現するのは無理がある（draft と直交しない）

## 2. ゴール

`status` を **2 軸モデル** に分割する:

```
state:      draft       (作業中)        / published (完成)
visibility: private     (自分だけ)      / public    (誰でも)
```

意味のある組み合わせは 3 つ。`draft` 中は visibility に関わらず author のみ閲覧可（4 つ目は実用性なし）:

| state    | visibility | 実態                     | 閲覧                         |
|----------|------------|--------------------------|------------------------------|
| draft    | (irrelevant) | 作業中ノート             | author のみ                   |
| published | private   | 完成した自分専用ノート     | author のみ                   |
| published | public    | 完成した公開ノート         | 全員                         |

加えて将来の拡張（unlisted / shared / organization / subscriber）を `visibility` 列の値追加 + 必要ならサブテーブルで段階的に積み上げられる構造にする。

## 3. スコープ

### このフェーズに含む

1. `user_notebook` と `course` に `visibility VARCHAR(32) NOT NULL DEFAULT 'private'` 列を追加する Mito マイグレーション
2. 既存 published 行を `visibility = 'public'` に UPDATE
3. アクセス判定の中央集約: `can-view-notebook-p` / `can-view-course-p` / `publicly-listable-p`（notebook + course 用）
4. ハンドラの更新: 公開単体ページ / 公開一覧 / Course attach 候補 / 公開コース / Course 内 Notebook 表示
5. UI 変更: form に visibility select 追加、status pill のラベル/色を 3 状態に
6. テスト: visibility ごとの可視性（published+public は全員 200、published+private は他人 404、draft は他人 404 のまま）

### このフェーズに含めない（将来）

- `unlisted` / `shared` / `organization` / `subscriber` の各値（次フェーズ以降）
- `notebook_share` 結合テーブル
- 既存 ACL 系の改修

## 4. データモデル

### 4.1 列追加

```sql
ALTER TABLE user_notebook
  ADD COLUMN visibility VARCHAR(32) NOT NULL DEFAULT 'private';

ALTER TABLE course
  ADD COLUMN visibility VARCHAR(32) NOT NULL DEFAULT 'private';

-- 既存 published 行は public 扱いに
UPDATE user_notebook SET visibility = 'public' WHERE status = 'published';
UPDATE course        SET visibility = 'public' WHERE status = 'published';
```

`status` 列は draft/published のまま残す。意味は「state（state-of-completion）」に明確化する（リネームはしない、互換性のため）。

CHECK 制約は付けない。将来 `unlisted` / `shared` 等を加えるとき migration が要らないようにするため。

### 4.2 deftable の更新

```lisp
;; models/user-notebook.lisp
(deftable user-notebook ()
  (...
   (status :col-type (:varchar 32) :initarg :status :initform "draft"
           :accessor user-notebook-status)
   (visibility :col-type (:varchar 32) :initarg :visibility
               :initform "private"
               :accessor user-notebook-visibility)
   ...))
```

`course` 側も同様。

## 5. アクセス制御の中央集約

### 5.1 関数

```lisp
;; 新規 utils/access-control.lisp（または web/routes.lisp 内）

(defun owner-of-notebook-p (user notebook)
  (and user notebook
       (equal (princ-to-string (user-notebook-author-id notebook))
              (princ-to-string (getf user :id)))))

(defun can-view-notebook-p (user notebook)
  "Notebook の閲覧権限。false = 他人視点で 404。"
  (cond
    ((null notebook) nil)
    ((owner-of-notebook-p user notebook) t)
    ((string/= "published" (user-notebook-status notebook)) nil)
    (t (case-equal (user-notebook-visibility notebook)
         ("public" t)
         ("private" nil)
         ;; Phase 2: ("unlisted" t)
         ;; Phase 3: ("shared" (in-notebook-share-list-p user notebook))
         ;; Phase 4: ("organization" (same-org-p user notebook))
         ;; Phase 5: ("subscriber" (active-subscriber-p user))
         (t nil)))))

(defun publicly-listable-notebook-p (notebook)
  "公開一覧（/notebooks）と Course attach 候補に出るか。"
  (and notebook
       (string= "published" (user-notebook-status notebook))
       (member (user-notebook-visibility notebook)
               '("public") :test #'string=)))
```

`course` 側にも同型の `can-view-course-p` / `publicly-listable-course-p` を作る。

### 5.2 各ハンドラの呼び出し

| ハンドラ | 旧条件 | 新条件 |
|----------|--------|--------|
| `public-user-notebook-handler` (GET /n/:slug) | `(string= "draft" status) AND NOT owner` → 404 | `NOT (can-view-notebook-p user nb)` → 404 |
| `notebooks-public-handler` (GET /notebooks) | `list-user-notebooks :status "published"` | `list-user-notebooks :status "published" :visibility "public"` |
| `course-eligible-notebooks` | 自分の `:status "published"` を全部 | 自分の `published+public` のみ |
| `public-user-notebook-cell-run-handler` | 上記 404 と同じ | 同上 |
| `public-course-handler` (GET /c/:slug) | `(draft AND NOT owner)` → 404 | `NOT (can-view-course-p user c)` → 404 |
| `courses-public-handler` (GET /courses) | `list-courses :status "published"` | `list-courses :status "published" :visibility "public"` |
| `/c/:slug` 内 Notebook カード | リンクは notebook 単体ページに、各 notebook の閲覧権は別途 | カードに渡す前に `publicly-listable-notebook-p` で篩い、author のみ見える draft/private は表示しない |

### 5.3 db 層の関数拡張

`list-user-notebooks` `count-user-notebooks` `list-courses` `count-courses` に `:visibility` キーワード引数を追加。複数値指定（例: `"public" "unlisted"`）も将来対応するため `:visibility` をリストでも受け付けられる shape にしておく:

```lisp
(defun list-user-notebooks (&key status author-id visibility (limit 50) offset)
  ...)
```

実装は内部で `(or (listp visibility) (list visibility))` にして `IN (...)` SQL 句を組み立てる。MVP は単値だが拡張可能。

## 6. UI 変更

### 6.1 フォーム

`web/ui/user-notebook-form.lisp` と `web/ui/course-form.lisp` に visibility select を追加:

```html
<select name="visibility">
  <option value="private">Private (only you)</option>
  <option value="public">Public (anyone)</option>
</select>
```

draft 時に visibility を grayed out するのは UX 改善（必須ではない）。Status select は draft/published のまま。

### 6.2 一覧の status pill

3 状態を 3 色で表示:

| 表示 | state × visibility | 色 |
|------|---------------------|----|
| Draft | draft (visibility 無視) | 黄 |
| Private | published + private | 紫 |
| Public | published + public | 緑 |

`render-user-notebook-status-pill` と `render-course-status-pill` のラベル/色決定ロジックを `(state, visibility)` 入力に変更。

### 6.3 toggle-status の挙動

現状の `POST /notebooks/:id/toggle-status` は draft⇄published を反転している。3 状態だと反転先が曖昧（Public → Private？ Private → Draft？）。

提案: トグル UI は廃止し、**「Publish」ボタン** と **「Unpublish (back to draft)」ボタン** の 2 つに分ける。Visibility は form 経由のみで変更させる。

または、status pill のクリックで小さい dropdown（Draft / Private / Public）を出す。HTMX 化してモーダル無しでさっと切り替えられるようにする。

MVP では **「pill をクリック → Draft/Private/Public ドロップダウン → 選択で POST」** のシンプルな HTMX フローを推奨。

### 6.4 アイコン / ラベル提案

- Draft: 黄、ラベル `Draft`、アイコン `✏️`（編集中）
- Private: 紫、ラベル `Private`、アイコン `🔒`
- Public: 緑、ラベル `Public`、アイコン `🌐`

学習者が他人の notebook を眺めるとき、3 状態が一目で分かる。

## 7. 移行戦略

### 7.1 マイグレーション

1. Mito CLI で `generate-migrations` → `visibility` 列追加 SQL が生成される
2. 生成された SQL の末尾に `UPDATE user_notebook SET visibility = 'public' WHERE status = 'published';` を**手動で追加**（Mito は schema 変更しか生成しない）
3. 同様に `course` も
4. 適用

### 7.2 SICP コースの取り扱い

現在の SICP は `status='published'` で全員に見える状態。マイグレーションで `visibility='public'` になり、引き続き全員に見える。挙動は変わらない。

### 7.3 既存 draft 行

既存 draft 行はマイグレーション後 `visibility='private'`（DEFAULT）になる。draft 中は visibility 無視なので挙動は変わらない（author のみ閲覧可）。`published` 化するときに `visibility` を選び直してもらう設計にすれば自然。

ただし「以前 published だった notebook を draft に戻して再 publish したら visibility は前回の値が残る」と現状 visibility 列にも記憶される。これは UX 上望ましい動き（draft 中の visibility 値は publish 時の preset として機能する）。

## 8. テスト戦略

### 8.1 アクセス判定の単体テスト

`tests/utils/access-control.lisp` 新規:

```lisp
(deftest can-view-notebook-published-public
  ;; 全員閲覧可
  ...)
(deftest can-view-notebook-published-private
  ;; author のみ
  ...)
(deftest can-view-notebook-draft
  ;; visibility に関わらず author のみ
  ...)
(deftest publicly-listable-public
  ;; published+public のみ true
  ...)
```

course 側も同様。

### 8.2 ハンドラ統合テストの追加

`tests/web/user-notebook-routes.lisp` `tests/web/course-routes.lisp` に visibility 別の挙動テストを追加:

- `private notebook の他人アクセスは 404`
- `private notebook を author が見ると 200`
- `public notebook を匿名で見ると 200`
- `notebooks-public-handler は private を表示しない`
- `course-eligible-notebooks は private を候補に出さない`

### 8.3 既存テストの調整

既存テストで `:status "published"` で notebook を作っていた箇所は、新コードでは `published + private` がデフォルトになるので、明示的に `:visibility "public"` を渡す必要がある場合あり。テスト fixture を全件レビュー。

## 9. 将来の拡張パス

| Phase | 追加 visibility 値 | 必要な追加 | 用途 |
|-------|---------------------|-------|------|
| 1 (このフェーズ) | `private` / `public` | なし | MVP |
| 2 | `unlisted` | `can-view-notebook-p` に分岐追加（list には出さない、URL 知ってればOK） | リンク共有 |
| 3 | `shared` | `notebook_share (id, notebook_id, user_id, permission)` 結合テーブル | 個別招待 |
| 4 | `organization` | `notebook_organization` or `users.organization_id` | 組織内限定 |
| 5 | `subscriber` | 既存 subscription / billing 系と JOIN | 課金限定 |

各 phase で:

1. `visibility` 列に新値を追加（DB マイグレーション不要、CHECK 制約なし）
2. `can-view-notebook-p` の `case-equal` に分岐を追加
3. 必要ならサブテーブル新設 + ヘルパ関数（`in-notebook-share-list-p` など）
4. UI（form select、status pill、フィルタ）に新値を追加

中央集約された `can-view-notebook-p` の存在で、ハンドラ側のロジック変更は不要になる。

## 10. 開かれた疑問

1. **toggle-status の UX**: pill クリックで dropdown vs Publish/Unpublish ボタン。どちらが学習者・作者に親切か。MVP は dropdown を推奨だが要レビュー。
2. **draft + visibility の意味**: 現案では draft 中は visibility 無視。ただし「draft + 自分以外もコメントできる」のような将来要件があれば draft + visibility を全組み合わせ意味のある状態にする手もある。MVP は無視する設計。
3. **course の visibility は notebook と独立か**: 例えば「private course に public notebook が含まれる」場合、`/c/:slug` は author のみ、`/n/:slug` は誰でも。これでよいか。直感的には OK だが、Course 内ナビ（sidebar）で他人にコース構造が漏れる懸念は無い（course 単体ページが 404 のため）。
4. **URL 別経由のアクセス**: 例えば「published+private notebook」を author が誰かに直接リンクで送ったら、その人は 404。Phase 2 の `unlisted` を待たず Phase 1 で署名付き URL を発行できるようにすべきか。MVP は不要。

## 11. 想定される反論と対応

- **「複雑度が上がる」**: status 単一列で `private / draft / published` の 3 値にする案もあるが、それだと「private な published」が表現できず、将来 `unlisted` 等を足すときに draft と直交しない値になる。2 軸モデルは初期コストが少し高いが拡張に強い。
- **「既存テストが大量に壊れる」**: テスト fixture で `:status "published"` を使っているところは visibility が `private`（DEFAULT）になる。Phase 1 のテスト書き換えは数十件。負担はあるが現実的。
- **「toggle-status の互換」**: 旧 toggle-status エンドポイントを残し、内部でドロップダウン未指定時は `published private ⇔ draft` に倒すなど互換性を残せる。ただし `/notebooks/:id/toggle-status` の挙動は明確に「Publish/Unpublish 切り替え」を意味するように変える必要がある。
