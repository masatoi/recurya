# 限定共有（unlisted visibility）設計

**日付**: 2026-06-21
**ステータス**: 承認済み（設計）

## 背景と目的

現在 Notebook / Course の公開設定は `visibility` が `private`（所有者のみ）/ `public`
（全世界・一覧掲載）の二択しかない。このため「URLを知っている人にだけ見せたい・
ただし公開一覧やプロフィールには載せたくない」という最も基本的な限定共有
（同僚へのレビュー依頼、下書きの限定配布など）が成立しない。

本設計は `visibility` に3つ目の値 `unlisted`（限定公開）を追加し、Notebook と
Course の両方でこのユースケースを満たす。

## 決定事項

### 1. 方式: unlisted を visibility の第3値として追加

共有トークンリンク方式ではなく、`visibility` に `unlisted` 値を追加する方式を採る。

- `visibility` は既に `VARCHAR(32)`・CHECK制約なしのため、**DBマイグレーション不要・
  `deftable` 変更不要**。新しい文字列値を扱うロジック/UI/テストの修正で完結する。
- URLは通常の slug URL（`/@handle/slug`、`/c/@handle/slug`）をそのまま使う。
- 弱点として slug が URL に出るため推測され得るが、限定共有の要件
  （「知っている人だけ」）には十分。推測耐性が必要な用途は将来の共有トークンで対応する
  （本設計のスコープ外）。

### 2. 適用範囲: Notebook と Course の両方

両者は既に同じ visibility モデル・同じ状態ドロップダウンUIを共有しているため、
一貫性のために両方へ同時に適用する。

### 3. アクセスモデル: 「閲覧可否」と「一覧掲載可否」を分離

| visibility | URL直アクセス (`can-view-*`) | 一覧 / プロフィール掲載 |
|---|---|---|
| private | 所有者のみ | 非掲載 |
| **unlisted（新）** | **published なら誰でも** | **非掲載** |
| public | published なら誰でも | 掲載 |

- `unlisted` と `public` は **閲覧可否は同じ**（published かつ URL を知れば誰でも閲覧可）。
  違いは **一覧掲載の有無のみ**。
- `private` は従来どおり所有者のみ閲覧可。

## 実装範囲

### A. アクセス制御 (`utils/access-control.lisp`)

`can-view-notebook-p` / `can-view-course-p` の非所有者分岐を変更:

- 変更前: `published かつ visibility = "public"` のとき閲覧可
- 変更後: `published かつ visibility ∈ {"public", "unlisted"}` のとき閲覧可

`publicly-listable-notebook-p` / `publicly-listable-course-p` は **変更しない**
（`visibility = "public"` のまま＝unlisted は掲載対象外）。

### B. 一覧・プロフィール（変更不要）

公開一覧（`notebooks-public-handler` / `courses-public-handler`）とプロフィール
（`profile-handler` → `list-public-notebooks-of` / `list-public-courses-of`）は、
既にDBクエリで `visibility = "public"` を抽出しているため、unlisted は自動的に
非掲載となる。**コード変更は発生しない**（テストで回帰を保証する）。

### C. 状態モデル & ダッシュボードUI（3状態→4状態）

状態ドロップダウンを `Draft / Private / Unlisted / Public` の4択に拡張。

- `%decode-state-token`（`web/routes.lisp`、notebook/course 共用）に
  `"published-unlisted" → (values "published" "unlisted")` を追加。
- `render-notebook-state-dropdown`（`web/ui/notebooks-dashboard.lisp`）/
  `render-course-state-dropdown`（`web/ui/courses.lisp`）に Unlisted ボタンを追加。
- create/update ハンドラ（`notebook-create-handler`, `notebook-update-handler`,
  `course-create-handler`, `course-update-handler`）の
  `(member visibility-raw '("private" "public") :test #'equal)` に `"unlisted"` を追加。
- `notebook-form` / `course-form` の visibility select に Unlisted オプションを追加
  （作成時に直接 unlisted 指定可能にする）。

### D. ピル表示（ダッシュボードの `*page-styles*`）

- `.status-pill.status-{draft,private,public}` の色ルールは
  `web/ui/notebooks-dashboard.lisp` と `web/ui/courses.lisp` のそれぞれの
  `*page-styles*` 文字列内にある（`styles.lisp` ではない）。両方に
  `.status-pill.status-unlisted` を追加する。色は public(緑) / private(紫) /
  draft(黄) と区別できる青系。
- ドロップダウン summary ピルおよび一覧の3状態ピル計算で、
  `published かつ unlisted` のとき `status-unlisted` / ラベル "Unlisted" を出す。

### E. 共有URLコピー導線

ダッシュボードの各行で `visibility = "unlisted"` のとき、共有URLとコピーボタンを表示:

- Notebook: `/@<handle>/<slug>`、Course: `/c/@<handle>/<slug>`。
- handle はセッションユーザー（`:handle`）、slug は各行の plist から組み立てる。
- 最小の JS（`navigator.clipboard.writeText`）でコピー。

### F. noindex メタ（correctness 追加）

公開ページ（notebook / course）の `<head>` に、`visibility ≠ "public"`
（unlisted、および所有者が閲覧する private/draft）のとき
`<meta name="robots" content="noindex">` を出力する。unlisted URL が外部に漏れても
検索エンジンにインデックスされないようにする。

- 注入点（`page-shell` の `head-extras` か notebook/course の render 内 head か）は
  実装時にレンダラ構造を確認して決定する。

## テスト戦略

### アクセス制御 (`tests/utils/access-control.lisp`)
- unlisted notebook/course は URL 閲覧可（非所有者・匿名でも `can-view-*` が真）。
- unlisted は `publicly-listable-*` が偽（一覧掲載対象外）。

### 状態トークン (`tests/web/*-routes.lisp`)
- `%decode-state-token` が `"published-unlisted"` を `("published", "unlisted")` に
  デコードする。
- set-state ハンドラで `published-unlisted` を送ると visibility=unlisted が永続化され、
  ドロップダウン markup が返る。

### ルート挙動（notebook / course 各々）
- 匿名で unlisted の `/@handle/slug`（course は `/c/@handle/slug`）が **200**。
- unlisted は `/notebooks`（`/courses`）一覧に **出ない**。
- unlisted は `/@handle` プロフィールに **出ない**。
- ダッシュボード行に unlisted の共有URLが表示される。

### CI観点
- `(asdf:compile-system :recurya :force t)` で警告ゼロ。
- 全テスト green をマージ前提。

## マイグレーション / ロールバック

- **マイグレーション不要**。`visibility` は自由な `VARCHAR(32)` のため、新値 `unlisted`
  はスキーマ互換。`deftable` 変更も発生しない。
- 実装時に model（`models/notebook.lisp`, `models/course.lisp`）と `db/schema.sql` に
  CHECK制約 / enum が無いことを最終確認する。
- ロールバックはコード revert のみ（既存 unlisted データは public/private いずれにも
  寄せられるが、開発初期につき考慮不要）。

### G. 公開Courseページの非公開メンバー除外（発見面の保証）

公開（public）Courseページは検索・インデックス対象の発見面である。`list-course-notebooks`
は可視性で絞らないため、添付後に unlisted（または private/draft）へ降格された
メンバーnotebookのタイトル・要約・`/@handle/slug` リンクが露出し得る。これは unlisted の
「発見面に出さない」保証に反するため、`%render-public-course-response` で
**publicly-listable なメンバーのみ**に絞る（`publicly-listable-notebook-p`）。

- Course へ unlisted notebook を添付する経路（`course-eligible-notebooks`）は従来どおり
  **public のみ**に据え置く（YAGNI）。よって露出経路は「添付後に降格」のみで、上記の
  絞り込みがそれを塞ぐ。
- `?course=` サイドバーは unlisted Course も解決対象に含まれるようになる（`can-view-course-p`
  が unlisted を許可するため）。unlisted Course はリンク共有可なので、メンバーnotebookを
  既に閲覧している人にそのCourseのタイトル/兄弟slugを見せることは許容する（コメントを更新）。

## スコープ外（YAGNI）

- 共有トークンリンク（推測不能な秘密URL）。
- 有効期限付きリンク、パスワード保護。
- unlisted 専用の閲覧アクセスログ。
- 共有リンクの招待・通知フロー。
