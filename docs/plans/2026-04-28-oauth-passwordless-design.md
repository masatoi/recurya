# OAuth Passwordless 認証 設計

- 日付: 2026-04-28
- 対象: recurya / 認証システム
- スコープ: メール+パスワードを廃止し、Google + GitHub OAuth に置換

## ゴール

メールサーバ不要(SMTP・メール検証フロー無し)で公開可能な認証を構築する。
ユーザは「Google でログイン」または「GitHub でログイン」ボタン 1 クリックでアカウント作成・ログイン可能。

## 確定要件

1. **Google + GitHub の 2 プロバイダをサポート**
2. **email+password は廃止**(admin もOAuth経由で管理)
3. **同じ email で Google ⇄ GitHub 切替可能**(email で同一ユーザに統合)
4. **管理者権限**は環境変数 `ADMIN_OAUTH_EMAIL`(複数可、カンマ区切り)で「OAuth でログインしたメール一致時に role=admin」とする
5. CSRF 対策: state パラメータ必須(暗号論的乱数 + セッション保存)

## アーキテクチャ

### 新規 / 変更ファイル

```
recurya/
├── models/users.lisp                [EDIT] provider/provider-uid 列追加, password 列を nullable
├── db/users.lisp                    [EDIT] create-user! / find-or-create-by-email を OAuth 対応に
├── db/migrations/[ts].sxql          [NEW]  schema 変更
├── web/
│   ├── auth.lisp                    [EDIT] verify-password 等を削除、register! も削除
│   ├── oauth.lisp                   [NEW]  プロバイダ定義 + flow 実装
│   ├── routes.lisp                  [EDIT] /login → OAuth start ボタン、/auth/:provider/* 追加
│   └── ui/login.lisp                [EDIT] Google/GitHub ボタンへ置換、signup 削除
└── tests/web/oauth.lisp             [NEW]  state 検証・URL 構築・stub 化テスト
```

### OAuth フロー

```
ユーザ → /login
  ├─ "Google でログイン" → /auth/google/start
  │     ├─ state を session に書き込み(乱数16バイト hex)
  │     └─ Google authorize URL へ 302
  │           ├─ ユーザ同意
  │           └─ /auth/google/callback?code=...&state=...
  │                 ├─ state 検証(session と一致するか)
  │                 ├─ POST /token: code → access_token
  │                 ├─ GET /userinfo: email, name, sub
  │                 ├─ db:find-or-create-oauth-user
  │                 │     ・ (provider, provider_uid) で検索
  │                 │     ・ なければ email で検索 → あれば紐付け、なければ新規
  │                 ├─ ADMIN_OAUTH_EMAIL に含まれていれば role=admin
  │                 ├─ session に user plist 保存
  │                 └─ /wardlisp/learn へ 302
  │
  └─ "GitHub でログイン" → 同じ流れ(URL とパラメータが違うだけ)
```

### スキーマ変更

```sql
ALTER TABLE users
  ADD COLUMN provider VARCHAR(16),
  ADD COLUMN provider_uid VARCHAR(64);

ALTER TABLE users
  ALTER COLUMN password_hash DROP NOT NULL,
  ALTER COLUMN password_salt DROP NOT NULL;

CREATE UNIQUE INDEX users_provider_uid_unique
  ON users (provider, provider_uid)
  WHERE provider IS NOT NULL;
```

`provider IS NOT NULL` の partial unique にして、レガシーで provider なしのユーザ(admin 等)が衝突しないようにする。

### 環境変数(本番運用)

| 変数 | 例 | 用途 |
|---|---|---|
| `OAUTH_GOOGLE_CLIENT_ID` | `123-abc.apps.googleusercontent.com` | Google Console で取得 |
| `OAUTH_GOOGLE_CLIENT_SECRET` | `GOCSPX-...` | Google Console で取得 |
| `OAUTH_GITHUB_CLIENT_ID` | `Iv1.abc...` | GitHub Settings → Developer settings → OAuth Apps |
| `OAUTH_GITHUB_CLIENT_SECRET` | `ghs_...` | 同上 |
| `OAUTH_REDIRECT_BASE` | `http://localhost:3000` (dev) / `https://recurya.example.com` (prod) | redirect URI のホスト部 |
| `ADMIN_OAUTH_EMAIL` | `me@example.com,you@example.com` | カンマ区切りの admin メールアドレス |

OAuth App 設定で登録する callback URL:
- `${OAUTH_REDIRECT_BASE}/auth/google/callback`
- `${OAUTH_REDIRECT_BASE}/auth/github/callback`

### 実装詳細

#### `web/oauth.lisp` の公開 API

```lisp
(defstruct oauth-provider
  name              ; "google" or "github"
  authorize-url     ; "https://accounts.google.com/o/oauth2/v2/auth"
  token-url         ; "https://oauth2.googleapis.com/token"
  userinfo-url      ; "https://www.googleapis.com/oauth2/v3/userinfo"
  scope             ; "openid email profile"
  client-id-env     ; "OAUTH_GOOGLE_CLIENT_ID"
  client-secret-env ; "OAUTH_GOOGLE_CLIENT_SECRET"
  email-fn          ; (lambda (userinfo) ...) extract email
  uid-fn            ; (lambda (userinfo) ...) extract stable uid
  name-fn)          ; (lambda (userinfo) ...) extract display name

(defparameter *providers*
  (list (cons "google" <google-provider>)
        (cons "github" <github-provider>)))

(defun authorize-url (provider state) → URL string)
(defun exchange-code (provider code) → access-token string)
(defun fetch-userinfo (provider access-token) → hash-table)
(defun generate-state () → random hex string)
```

GitHub は user info を 2 つの endpoint から取る必要がある場合あり(プライマリ email が private のとき `/user/emails` を見る)。実装で対応。

#### find-or-create-oauth-user

```lisp
(defun find-or-create-oauth-user (provider provider-uid email name)
  ;; 1. (provider, provider-uid) で検索 → あれば返す
  ;; 2. email で検索(provider 無視)→ あれば provider/provider-uid を更新して返す
  ;; 3. 新規作成、admin チェック
  )
```

#### Session への user plist 形式

既存形式維持: `(:id <uuid> :email "..." :name "..." :role "user|admin" :provider "google|github")`

### UI

`/login` を以下に置換:

```
┌─────────────────────────────────────────┐
│ Recurya にログイン                       │
│                                         │
│ [  Google でログイン  ]                 │
│ [  GitHub でログイン  ]                 │
│                                         │
│ ログインすると進捗・コードが端末を超え │
│ て保存されます。                        │
└─────────────────────────────────────────┘
```

`/signup` ルートは削除(OAuth で自動作成)。`/account` ページは display name 編集のみ残す(email は OAuth 側で管理)。

### マイグレーション(既存ユーザ対応)

開発環境の既存ユーザは admin (admin@recurya.dev) と test ユーザのみ。
- マイグレーション後: 既存ユーザは provider=NULL のまま残るが、ログイン手段が無くなる
- 対処: admin@recurya.dev は OAuth で再ログイン後 `ADMIN_OAUTH_EMAIL` で admin 復帰
- 開発時の test ユーザは `tests/support/db.lisp` で都度作成しているので影響なし

## テスト戦略

### `tests/web/oauth.lisp`(新規)

- `oauth-state-generation` — state が 16 バイト以上の hex 文字列
- `authorize-url-construction` — Google/GitHub 各々の URL に `client_id` / `redirect_uri` / `scope` / `state` が含まれる
- `find-or-create-oauth-user-new` — 新規 email で user 作成、provider 設定
- `find-or-create-oauth-user-existing-by-email` — 既存 email に provider 紐付け
- `find-or-create-oauth-user-existing-by-provider` — 既存 (provider, uid) 検索
- `admin-email-promotion` — `ADMIN_OAUTH_EMAIL` 環境変数の email は role=admin になる

実プロバイダへの HTTP は **stub**。`exchange-code` / `fetch-userinfo` を mockable に。

### 手動テスト

OAuth App を登録した後の手動 e2e:
1. `/login` を開く
2. Google でログイン → /wardlisp/learn にリダイレクト、user-banner に名前表示
3. ログアウト → 再ログイン → 同じユーザが復元
4. GitHub で同じメールでログイン → 同じユーザに統合される(provider が github に切替)
5. シークレットウィンドウで別ユーザを作成 → 別アカウント扱い

## 工数

| 段階 | 内容 | 時間 |
|---|---|---|
| 1 | DB スキーマ変更(モデル + マイグレーション) | 1 時間 |
| 2 | `db/users.lisp` の find-or-create-oauth-user 実装 + テスト | 2 時間 |
| 3 | `web/oauth.lisp`: provider 定義 + URL 生成 + コード交換 + userinfo 取得 + テスト | 4 時間 |
| 4 | ルート 4 本 + admin 昇格ロジック + 既存 auth 削除 | 2 時間 |
| 5 | UI 置換 + sign up ページ削除 | 1 時間 |
| 6 | フルテスト + 手動 e2e(OAuth App 登録は別途) | 1 時間 |
| **合計** | | **約 11 時間 / 1.5 日** |

## 非対象

- メール+パスワードのフォールバック(完全廃止)
- パスワードリセットフロー(passwordless なので不要)
- アカウント削除前の確認メール(SMTP なし方針のため、即時削除のまま)
- 2要素認証(将来)
- 他プロバイダ(Twitter, Apple, Microsoft 等。必要なら provider 追加で対応可能な構造)
- セッション失効時間の調整(既存 Lack session middleware の設定のまま)

## 完了基準

- email+password 関連コードがリポジトリから削除されている(`derive-password`/`verify-password`/`register!` 等)
- 環境変数 4 つ(GOOGLE/GITHUB の id+secret)+ `OAUTH_REDIRECT_BASE` + `ADMIN_OAUTH_EMAIL` を `.env.example` 等に明記
- 既存テスト(55 ノート + DB + ルート)が回帰なく green
- 新規テスト(oauth.lisp、state 検証 + find-or-create-oauth-user)が green
- 手動 e2e が動作(OAuth App 登録後)

## リスクと緩和

| リスク | 緩和 |
|---|---|
| OAuth App 登録忘れで開発が止まる | 環境変数未設定時はログイン画面に「未設定」エラー表示、stub 環境変数で起動可能に |
| email 統合の悪用(他人の Google を取って既存 GitHub アカウントを乗っ取る) | Google/GitHub の email は検証済前提。GitHub の primary email が verified=false の場合は拒否 |
| state パラメータの中間者攻撃 | `secure-random` で 16 バイト hex 生成、session に保存し callback で照合 |
| dexador / cl-jzon の依存追加 | dexador と jzon は既存依存(qlfile に既に含まれる)。確認 |
| OAuth プロバイダ障害時のログイン不能 | admin@recurya.dev のような固定アカウントは持たない設計だが、片方のプロバイダが落ちてももう片方で入れる(2 プロバイダ運用の利点) |
