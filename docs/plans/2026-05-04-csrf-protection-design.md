# CSRF 保護 設計

- 起票: 2026-05-04
- ブランチ: `feat/csrf-protection`（新規）
- ステータス: ブレスト承認済み、実装計画作成へ
- 関連: `web/server.lisp` (lack/builder middleware stack)、`web/routes.lisp`、`web/ui/*.lisp`、`/static/js/learn.js`

## 1. 背景

現状 recurya は POST/PUT/DELETE/PATCH の状態変更エンドポイントが多数存在するが、CSRF 保護機構を持たない。攻撃者が用意した別オリジンページのフォームから、被害者のブラウザに保存された session cookie を伴って recurya に submit させると、被害者の権限で notebook 削除 / コース削除 / 状態変更 / cell 実行などができてしまう。

該当エンドポイント（POST 系のみ抜粋）:

```
/posts                 (create)
/posts/:id             (update)
/posts/:id/toggle-status, /posts/:id/delete
/notebooks             (create)
/notebooks/:id         (update)
/notebooks/:id/{toggle-status,state,confirm-delete,delete}
/courses               (create)
/courses/:id           (update)
/courses/:id/{toggle-status,state,delete,notebooks,notebooks/:cn-id/{up,down,remove}}
/n/:slug/cells/:i/run
/account, /account/delete, /logout
/learn/sync            (JSON, fetch from JS)
```

## 2. ゴール

`lack.middleware.csrf` を middleware stack に組み込み、上記すべての state-changing エンドポイントが CSRF token なしでは 400 を返すようにする。同時に、すべての form / HTMX ボタン / JS fetch に token を埋め込む。

## 3. lack.middleware.csrf の挙動（要約）

`.qlot/dists/lack/software/lack-ref-.../src/middleware/csrf.lisp` から読み取った仕様:

- POST / PUT / DELETE / PATCH のみ検査（GET / HEAD は素通り）
- session の `_csrf_token` キーと、request body の `_csrf_token` パラメータを `equal` で比較
- 一致しなければ `block-app` を呼ぶ（デフォルト `400 Bad Request: invalid CSRF token`）
- session 必須。`:lack.session` が ENV に無いとエラー
- 提供ヘルパ:
  - `(csrf-token session)` → トークン取得（無ければ生成して保存）
  - `(csrf-html-tag session)` → `<input type="hidden" name="_csrf_token" value="...">`
- オプション:
  - `:session-key` (default `"_csrf_token"`)
  - `:form-token` (default `"_csrf_token"`)
  - `:one-time` (default false。HTMX 連続 POST が壊れるので **使わない**)
  - `:block-app` (default = 400 を返す lambda)

## 4. アーキテクチャ

### 4.1 Middleware stack

`web/server.lisp:build-app`:

```lisp
(lack/builder:builder
 (:static :path "/static/" :root ...)
 :session
 :csrf            ; ← 新規。session の直後
 :backtrace
 app)
```

`:session` が先で `:csrf` がその直後である必要がある（csrf middleware は session を参照するため）。`:backtrace` より前に置く理由は、csrf 失敗を backtrace 化したくないため。

### 4.2 csrf-failure-handler

デフォルトの 400 plain text 応答ではユーザに不親切なので、HTML で 400 ページを返すカスタム `csrf-failure-handler` を作る:

```lisp
(defun csrf-failure-handler (env)
  (declare (ignore env))
  (list 400
        (list :content-type "text/html; charset=utf-8")
        (list (recurya/web/ui/errors:csrf-failure))))
```

`web/ui/errors.lisp` に `csrf-failure` を追加（既存 `not-found` と同型）。

### 4.3 token を取得するヘルパ

session を引数に取る lack 標準の `csrf-token` をそのまま使う:

```lisp
(defun current-csrf-token ()
  "Fetch (or lazily generate) the CSRF token for the current Ningle session."
  (when ningle/context:*session*
    (lack/middleware/csrf:csrf-token ningle/context:*session*)))
```

`web/routes.lisp` か `web/ui/layout.lisp` に置く。Spinneret の form ヘルパからも import-from で参照する。

### 4.4 form helper

`web/ui/layout.lisp` に Spinneret 用ヘルパを追加:

```lisp
(defun csrf-input ()
  "Emit a hidden CSRF token input. Use inside (with-html ...) bodies."
  (let ((tok (current-csrf-token)))
    (when tok
      (with-html
        (:input :type "hidden" :name "_csrf_token" :value tok)))))
```

各 form の中で `(csrf-input)` を呼ぶ。

### 4.5 HTMX 統合方針

3 通りある:

#### 方針 A: 各 hx-post に hx-vals で token を含める

```html
<button hx-post="/notebooks/123/state"
        hx-vals='{"state":"public", "_csrf_token":"abc..."}'
        hx-target="..." hx-swap="outerHTML">
  Public
</button>
```

token 文字列を JSON 内にエスケープして渡すので脆弱（` " ` など）。**非推奨**。

#### 方針 B: hx-include で form の hidden input を巻き込む

```html
<form id="csrf-form-123">
  <input type="hidden" name="_csrf_token" value="abc...">
  <button hx-post="/notebooks/123/state"
          hx-vals='{"state":"public"}'
          hx-include="#csrf-form-123"
          hx-target="..." hx-swap="outerHTML">
    Public
  </button>
</form>
```

button ごとに `hx-include` を書く。token はページ単位で共有する hidden input に集約。**ややボイラープレート**。

#### 方針 C: HTMX グローバルで `hx-headers` を設定（document level）

```html
<body hx-headers='{"X-CSRF-Token":"abc..."}'>
```

中身を共有 token として全 hx-post に header で送る。サーバ側で middleware を `header` 派生に変える必要があるが、Lack csrf は body parameter のみ見るので **不可**。

#### 推奨: 方針 D（B の改良）

ページ全体で 1 つの hidden form を `<body>` 直下に置き、全 HTMX button が `hx-include="#csrf-form"` で参照する:

```html
<body>
  <form id="csrf-form" style="display:none">
    <input type="hidden" name="_csrf_token" value="abc...">
  </form>
  ...
  <button hx-post="..." hx-vals='{...}' hx-include="#csrf-form" ...>...</button>
</body>
```

`web/ui/layout.lisp:header` の中（または body 直下）で 1 度だけ csrf-form を出力する関数 `csrf-form-block` を呼ぶ。各 HTMX button は `hx-include="#csrf-form"` を統一。

### 4.6 JS fetch (`/learn/sync`) の対応

`web/ui/layout.lisp`（または notebook viewer）の `<head>` に meta tag を追加:

```html
<meta name="csrf-token" content="abc...">
```

`/static/js/learn.js`（推測。実ファイルは確認）で fetch するときに body に token を含める:

```js
const csrf = document.querySelector('meta[name="csrf-token"]').content;
fetch('/learn/sync', {
  method: 'POST',
  body: JSON.stringify({ ..., _csrf_token: csrf })
})
```

ただし `/learn/sync` は JSON body を受け取って `%parse-sync-payload` で plist 化している。Lack csrf middleware は **request-body-parameters**（form-encoded body）を見るので、JSON body の場合は middleware が token を見つけられない。

#### 解決策

a) **JSON ではなく form-encoded で送る**: JS 側を変更し、`Content-Type: application/x-www-form-urlencoded` で `_csrf_token=...&payload=<json string>` のような形にする。サーバ側 `learn-sync-handler` も解読方法を変更。**変更が大きい**。

b) **/learn/sync は CSRF middleware の検査対象から外す**: Lack csrf middleware にエンドポイント除外機能はないので、`build-app` の middleware を 2 層に分けるか、独自の small wrapper で `/learn/sync` を素通しさせる。代わりに `/learn/sync` は JS 側で SameSite=Strict の cookie 確認 + Origin チェック + ログイン中限定 で守る。**最も実装が簡単**。

c) **request-body-parameters を見る前に、Custom JSON parser middleware で `_csrf_token` を form parameter に inject**: 複雑。

**推奨: (b)**。`/learn/sync` は JS 内蔵の同一オリジン制約 (`fetch('/learn/sync')` は同オリジンへの POST のみ実行可能) と SameSite=Lax cookie の組み合わせで実用十分。CSRF middleware の検査対象は HTML form 系のみに絞る。

具体的には: `lack/middleware/csrf` を modify して許可パスを設定する代わりに、middleware の上にラッパを書く:

```lisp
(defun build-csrf-middleware ()
  "Wrap lack/middleware/csrf to skip /learn/sync (JSON endpoint)."
  (let ((csrf (funcall lack/middleware/csrf:*lack-middleware-csrf*
                       (lambda (env) (funcall *next-app* env))
                       :block-app #'csrf-failure-handler)))
    (lambda (env)
      (if (or (eq :get  (getf env :request-method))
              (eq :head (getf env :request-method))
              (string= "/learn/sync" (getf env :path-info)))
          (funcall *next-app* env)
          (funcall csrf env)))))
```

…ややこしいので、もっと素直に `lack.builder` の Lambda middleware として表現する:

```lisp
(:lambda (lambda (app)
           (let ((csrf-app (funcall lack/middleware/csrf:*lack-middleware-csrf*
                                    app :block-app #'csrf-failure-handler)))
             (lambda (env)
               (if (string= "/learn/sync" (getf env :path-info))
                   (funcall app env)
                   (funcall csrf-app env))))))
```

`lack/builder` の `:lambda` シンボルが lambda middleware を受け付けるかどうかは要確認。受け付けない場合は `funcall` で直接ラップ:

```lisp
(let* ((app (build-app-without-csrf))
       (app (csrf-with-skip app '("/learn/sync"))))
  app)
```

実装簡素化のため、後者で進める。

### 4.7 OAuth callback の取り扱い

`/auth/:provider/callback` は GET なので CSRF 検査対象外。state パラメータでの CSRF 等価防御は既存実装。OK。

### 4.8 logout

`<form method="post" action="/logout">` 内に `(csrf-input)` を追加。

## 5. テスト戦略

### 5.1 ハンドラ単体テスト（変更不要）

既存 `tests/web/*-routes.lisp` はハンドラを直接呼んでいるので middleware を通らない。CSRF 検査もスキップされる。**既存テストは無修正で動く**。

### 5.2 CSRF middleware の動作テスト

`tests/web/csrf.lisp` 新規。clack-test を使って実 HTTP リクエストを発行:

- GET は token 不要で 200
- token なしの POST は 400
- 正しい token の POST は 200 (実際には認証が必要なので 401/403、または OK 動作)
- 異なる token の POST は 400
- `/learn/sync` は token なしでも素通し
- `/auth/google/callback` は GET で素通し

### 5.3 E2E スモークテスト

手動:

1. ログイン → 各ページの form 送信が成功
2. ブラウザ DevTools で hidden input を削除して送信 → 400 が返る
3. 別オリジンから recurya への POST を試して 400 が返る（fetch with cookies）

## 6. 移行戦略

新規ブランチ `feat/csrf-protection` で実装。1 リリースで一括投入。既存 session を持つユーザでも、最初のページ表示時に `csrf-token` が自動生成され session に保存されるので、ユーザ作業は不要。

## 7. 実装コスト

| 部分 | コスト |
|------|--------|
| middleware ラッパ + skip 設定 | 30 分 |
| `csrf-input` / `csrf-form-block` ヘルパ | 30 分 |
| 既存 form 6-8 箇所への `(csrf-input)` 追加 | 30 分 |
| HTMX button への `hx-include="#csrf-form"` 追加 ~25 箇所 | 1.5 時間 |
| `csrf-failure` UI ページ + render | 30 分 |
| middleware 統合テスト (clack-test) | 1 時間 |
| 手動スモークテスト | 30 分 |

合計 **半日〜1日**。

## 8. 開かれた疑問

1. `/learn/sync` の skip 方式: middleware ラッパで path-info match で除外する方式で OK か。将来 path が増えた場合 skip リストの管理が散逸しないよう設計時に明確にする。
2. `:one-time` を採用しない方針で OK か。HTMX の連続 POST と相性悪いので不採用が妥当。
3. clack-test を実 HTTP で立てる際の port 競合（既に :3000 で開発サーバ動いている可能性）。テストは ephemeral port を使う。
4. SameSite cookie 設定の調整: 現状の `:session` middleware が cookie に SameSite を付けているか要確認。Lax 以上が望ましい。

## 9. 想定される反論と対応

- **「HTMX 全ボタンに hx-include を書くのは煩雑」**: 共通の `<form id="csrf-form">` を 1 つだけ body 直下に置くので token は 1 箇所のみ管理。各 button に追加するのは `hx-include="#csrf-form"` 文字列のみ。
- **「JSON エンドポイントが守られない」**: `/learn/sync` のみが該当し、ログイン中限定 + Origin 同一の fetch のみ呼べるので実用的リスクは低い。CSRF token 強制を将来追加する場合は `_csrf_token` を JSON body に含める JS と middleware ラッパの両方を変更する。
- **「テストヘルパが壊れる」**: 既存テストは middleware を通らない直呼び出し方式なので無修正。新規テストは clack-test で実 HTTP を打つので middleware を通る。
