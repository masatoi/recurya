# Notebook統合設計

**日付**: 2026-05-09
**ステータス**: 承認済み（設計）

## 背景と目的

Recuryaは wardlisp を埋め込んだ Jupyter Notebook 風の学習教材投稿サイトを目指す。
現状ブログ投稿機能 (`post`) と Notebook機能 (`user-notebook`) が並走しているが、
Notebook 側が機能的にブログのスーパーセットになっており、二系統を維持する理由がない。

本設計はブログを Notebook に統合し、URL/データモデル/認可境界を整理する。

## 決定事項

### 1. ブログ機能の完全削除

- `post` モデル、テーブル、関連UI、ルート、テストをすべて削除
- 開発初期段階につき既存データはバックアップなしで破棄

### 2. user-notebook → notebook へリネーム

- `recurya/models/user-notebook` → `recurya/models/notebook`
- `user_notebook` テーブル → `notebook` テーブル
- 全 `user-notebook-*` シンボル → `notebook-*`
- `course-notebook` (中間テーブル) は名称そのまま、内部の参照のみ更新

### 3. ユーザーハンドルの導入

`users` テーブルに `handle` 列を追加:

- 必須 (NOT NULL)
- 一意 (UNIQUE)
- バリデーション: `^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$` (小文字英数とハイフン、先頭末尾はハイフン不可、3〜64文字)
- 予約語リスト: `notebooks`, `courses`, `c`, `dashboard`, `account`, `login`, `logout`,
  `auth`, `onboarding`, `api`, `static`, `admin`, `assets`, `learn`, `wardlisp`, `n`

### 4. slug一意性をユーザーごとに変更

- `notebook` の `(:unique-keys slug)` → `(:unique-keys (author_id slug))`
- `course` の `(:unique-keys slug)` → `(:unique-keys (author_id slug))`

異なる著者が同じ slug を取れる。
URLでは `/@handle/:slug` のように `(handle, slug)` で一意に解決する。

### 5. URLスキーム

#### 公開（認証不要、SEO対象）

| パス | 説明 |
|------|------|
| `GET /` | ハイブリッドホーム。未ログイン → `/notebooks`、ログイン → `/dashboard` |
| `GET /notebooks` | 公開Notebook一覧（全著者横断、最新順） |
| `GET /courses` | 公開Course一覧 |
| `GET /@:handle` | ユーザープロフィール（その人の公開Notebook + Course一覧） |
| `GET /@:handle/:slug` | 公開Notebook詳細 |
| `POST /@:handle/:slug/cells/:i/run` | セル実行（HTMX） |
| `GET /c/@:handle/:slug` | 公開Course詳細 |
| `GET /login` | ログイン画面 |
| `POST /logout` | ログアウト |
| `GET /auth/:provider/start` | OAuth開始 |
| `GET /auth/:provider/callback` | OAuthコールバック |

`@` プレフィックスはRFC 3986準拠でURLエンコード不要。
Medium / Observable / Mastodon と同様。
予約語衝突を回避し、ユーザー領域の視認性を確保する目的で採用。

#### 管理（要認証、ミドルウェアでガード、`noindex`）

| パス | 説明 |
|------|------|
| `GET /dashboard` | = `/dashboard/notebooks` |
| `GET /dashboard/notebooks` | 自分のNotebook一覧 |
| `GET /dashboard/notebooks/new` | 新規Notebookフォーム |
| `POST /dashboard/notebooks` | Notebook作成 |
| `GET /dashboard/notebooks/:id/edit` | Notebook編集フォーム |
| `POST /dashboard/notebooks/:id` | Notebook更新 |
| `POST /dashboard/notebooks/:id/state` | 公開状態変更 |
| `POST /dashboard/notebooks/:id/toggle-status` | 旧2状態トグル |
| `GET /dashboard/notebooks/:id/confirm-delete` | 削除確認モーダル |
| `POST /dashboard/notebooks/:id/delete` | Notebook削除 |
| `GET /dashboard/courses` | 自分のCourse一覧 |
| `GET /dashboard/courses/new` | 新規Courseフォーム |
| `POST /dashboard/courses` | Course作成 |
| `GET /dashboard/courses/:id/edit` | Course編集フォーム |
| `POST /dashboard/courses/:id` | Course更新 |
| `POST /dashboard/courses/:id/state` | 公開状態変更 |
| `POST /dashboard/courses/:id/toggle-status` | 旧2状態トグル |
| `GET /dashboard/courses/:id/confirm-delete` | 削除確認モーダル |
| `POST /dashboard/courses/:id/delete` | Course削除 |
| `POST /dashboard/courses/:id/notebooks` | Notebook追加 |
| `POST /dashboard/courses/:id/notebooks/:cn-id/up` | 順序↑ |
| `POST /dashboard/courses/:id/notebooks/:cn-id/down` | 順序↓ |
| `POST /dashboard/courses/:id/notebooks/:cn-id/remove` | 切り離し |
| `GET /onboarding/handle` | ハンドル設定フォーム |
| `POST /onboarding/handle` | ハンドル保存 |
| `GET /account` | アカウント設定（既存） |
| `POST /account` | アカウント更新 |
| `GET /account/confirm-delete` | アカウント削除確認 |
| `POST /account/delete` | アカウント削除 |

#### 削除されるパス

- `/posts/*` 全ハンドラ
- `/blog`, `/blog/:slug`
- `/notebooks/me`, `/notebooks/new`, `/notebooks/:id/...` (旧管理パス)
- `/courses/me`, `/courses/new`, `/courses/:id/...` (旧管理パス)
- `/n/:slug`, `/c/:slug` (slug非一意となるため曖昧)

開発初期段階につき外部参照ゼロを前提に、サイレント削除（404）。

#### 維持されるリダイレクト

- `/wardlisp/learn` → `/c/@<seed-author>/sicp` (リダイレクト先のslugを更新)
- `/wardlisp/learn/:id` → `/@<seed-author>/:slug` (同上)
- `/wardlisp/learn/sync` → `/learn/sync`

### 6. 認可境界

`/dashboard/*` 配下を Lack ミドルウェアで一括認証ガード:

- 未認証 → `/login` へリダイレクト
- 認証済みだが `handle` 未設定 → `/onboarding/handle` へ強制リダイレクト

オーナーシップチェック（自分のNotebook以外を編集不可）は個別ハンドラで継続。

### 7. オンボーディング導線

OAuth初回ログイン後:

```
OAuth認証成功
  → users.handle が NULL なら /onboarding/handle へリダイレクト
  → ハンドル入力（リアルタイム重複チェック・予約語チェック・正規表現チェック）
  → 確定保存
  → /dashboard へ
```

## マイグレーション戦略

開発初期段階につき、既存ユーザー含めDB全データを破棄してクリーンに再構築する。

### 実装順序

#### Step 1 — モデル層整備

1. `models/users.lisp` に `handle` 列追加（NOT NULL UNIQUE）
2. `utils/handle.lisp` 新規作成（`validate-handle`, `reserved-handle-p`）
3. `models/post.lisp` 削除、`recurya.asd` 更新
4. `models/user-notebook.lisp` → `models/notebook.lisp` リネーム + シンボル変更
5. `models/course-notebook.lisp` の参照更新
6. `notebook` と `course` の `:unique-keys` を `(author_id slug)` に変更

#### Step 2 — DBマイグレーション (Mito CLI)

1. `TRUNCATE users CASCADE` で全データ削除
2. `mito generate-migrations` 実行
3. 生成SQLを目視レビュー (DROP TABLE post, RENAME, 制約変更, ADD COLUMN handle)
4. `mito migrate` 実行

`/mito-migrate` スキルを使用する。

#### Step 3 — オンボーディング導線

1. `web/ui/onboarding.lisp` 新規（ハンドル入力フォーム）
2. `web/auth.lisp` に「ハンドル未設定時 `/onboarding/handle` 強制リダイレクト」を追加
3. `web/routes.lisp` に `GET/POST /onboarding/handle` ハンドラ追加

#### Step 4 — ルート再構築

1. `/dashboard/*` 配下のハンドラを既存 `*-me` 系から派生（URL置換）
2. `/@:handle/:slug` 公開ルックアップ実装（handle → user → (user.id, slug) → notebook）
3. `/@:handle` ユーザープロフィール実装
4. `/c/@:handle/:slug` コース公開ページ実装
5. `/` ハイブリッドハンドラ実装
6. 旧 `/posts/*`, `/blog`, `/blog/:slug`, `/n/:slug`, `/c/:slug` 削除
7. `/wardlisp/learn` 系リダイレクト先を新URLスキームに更新

#### Step 5 — 認可ミドルウェア

1. `/dashboard/*` 配下を一括認証ガード
2. ハンドル未設定時の `/onboarding/handle` 強制リダイレクト追加

#### Step 6 — UI調整

1. `web/ui/layout.lisp` ナビゲーション再構成
2. 全ハンドラとUI内のリンク先URLを新スキームに置換（HTMX `hx-post` 含む）
3. 各 Notebook / Course カードに著者表示 (`@handle` 付きリンク)

#### Step 7 — シード調整

1. SICPの正規著者ユーザーを決める（例: 専用 `recurya` ハンドルの admin）
2. シードスクリプト更新
3. `/wardlisp/learn` リダイレクト先のハンドルを反映

## ファイル変更一覧

### 削除

- `models/post.lisp`
- `web/ui/blog.lisp`
- `web/ui/blog-post.lisp`
- `web/ui/posts.lisp`
- `web/ui/post-form.lisp`
- `tests/db/posts/` 系（存在すれば）
- `tests/web/blog-*.lisp`（存在すれば）

### リネーム

| 旧 | 新 |
|----|----|
| `models/user-notebook.lisp` | `models/notebook.lisp` |
| `web/ui/user-notebooks.lisp` | `web/ui/notebooks-dashboard.lisp` |
| `web/ui/user-notebook-form.lisp` | `web/ui/notebook-form.lisp` |
| `tests/db/user-notebooks.lisp` | `tests/db/notebooks.lisp` |

`web/ui/notebook.lisp` と `web/ui/notebook-list.lisp` は名称維持。

### 新規追加

- `utils/handle.lisp` — ハンドルバリデーション
- `web/ui/onboarding.lisp` — ハンドル設定UI
- `web/ui/profile.lisp` — `/@:handle` プロフィールページ
- `tests/utils/handle.lisp`
- `tests/web/onboarding.lisp`
- `tests/web/profile.lisp`
- `tests/web/dashboard.lisp`
- `tests/web/public-notebook.lisp`
- `tests/web/public-course.lisp`

### 修正範囲（大）

- `web/routes.lisp`
- `web/routes-wardlisp.lisp`
- `web/auth.lisp`
- `web/app.lisp`
- `web/ui/layout.lisp`
- `web/ui/login.lisp`
- `models/course-notebook.lisp`
- `recurya.asd`

## テスト戦略

### 重点テスト項目

- **高**: `/@:handle/:slug` ルックアップ。異なる著者で同 slug が共存しても正しく分離されること
- **高**: `/dashboard/*` 認証ガード。未認証時のリダイレクト
- **高**: ハンドルバリデーション。NOT NULL、UNIQUE、正規表現、予約語
- **中**: HTMXフラグメント（cell実行、status pill）
- **中**: course-notebook リレーション（rename後も動作）
- **低**: ナビゲーションリンク（手動確認）

### CI観点

- `(asdf:compile-system :recurya :force t)` で警告ゼロ
- 全テストgreenをマージ前提
- `run-tests` ツールで構造化結果を取得

## ロールバック方針

開発初期につき本番データ破棄OK。各 Step 終了時に手動動作確認 + テスト実行。
不可逆操作は `TRUNCATE` のみ。

## 未決事項

- SICPの正規著者ハンドル名（実装時に決定: `recurya`、`admin`、`sicp` などの候補）
- handle変更機能の有無（初期実装ではアカウント作成時のみ設定可、変更不可。将来 `/account` で対応）
- ユーザープロフィールページ `/@:handle` のデザイン詳細（Notebook/Courseのリストのみで開始）
