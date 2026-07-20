# VPS 2GB Docker 本番デプロイ 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recurya をさくらのVPS 2GB(Docker Compose)へ本番デプロイできる構成一式(本番実行コア・イメージ・compose・TLS・バックアップ・手順書)を用意する。

**Architecture:** マルチステージ Docker で `save-lisp-and-die` により SBCL 実行コアを焼き込み、`debian:bookworm-slim` ランタイムで起動する。単一VPS上の `docker compose` に `caddy`(自動HTTPS)+ `recurya`(実行コア)+ `postgres` の3コンテナを載せ、ホット公開は Caddy の 80/443 のみ。イメージはローカル/CIでビルドし GHCR 経由で VPS が pull する。

**Tech Stack:** SBCL 2.5.10 / qlot / Hunchentoot(Clack)/ cl-dbi+postmodern(純Lisp TCP)/ cl+ssl(OAuth HTTPS)/ Docker / Docker Compose / Caddy 2 / PostgreSQL 16 / GHCR。

**Design spec:** `docs/superpowers/specs/2026-07-21-vps-docker-deployment-design.md`

---

## 重要ルール(この計画の全タスク共通)

- **`.lisp` / `.asd` の編集・閲覧は cl-mcp ツール限定**(`lisp-edit-form` / `lisp-patch-form` / `lisp-read-file` / `run-tests` / `load-system`)。`Read`/`Edit`/`Write`/`grep`/`sed` を Lisp ファイルに使わない(CLAUDE.md)。
- **非 Lisp ファイル**(`Dockerfile.prod`, `*.yml`, `Caddyfile`, `*.sh`, `*.md`, `build.lisp` は Lisp だが後述の通りツール併用)は通常の `Write`/`Edit` で可。
  - 例外: `build.lisp` は Lisp コードだが、既存フォームの編集ではなく**新規ファイル**なので `Write` で作成 → `lisp-check-parens` で検証、で可。
- 初回のみ `fs-set-project-root` に `{"path": "."}`。
- **Docker のビルド/起動は許可されたユーザー要求コマンド**として実行してよい(`docker build` / `docker compose`)。
- コミットは各タスク末尾で。ブランチは既に `feat/vps-docker-deploy`。コミットメッセージ末尾に
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` を付与。

## ファイル構成(このプランで作成/変更)

| ファイル | 種別 | 責務 |
|---------|------|------|
| `main.lisp`(新規) | Lisp | 本番実行コアの toplevel。FFI再ロード→DB接続→seed→サーバ起動→SIGTERMまでブロック |
| `tests/main.lisp`(新規) | Lisp | `recurya/main` のエントリポイント存在/エクスポートの回帰テスト |
| `recurya.asd`(変更) | ASDF | umbrella `recurya` の depends-on に `recurya/main` を追加 |
| `web/server.lisp`(変更) | Lisp | `start!` のタイムゾーン読込を saved-core 環境向けに非致命化 |
| `build.lisp`(新規) | Lisp | `save-lisp-and-die` で `/app/recurya` 実行コアを生成 |
| `Dockerfile.prod`(新規) | Docker | builder(qlot+コア生成)→ runtime(slim+共有ライブラリ) |
| `docker-compose.prod.yml`(新規) | YAML | caddy + recurya + postgres、mem_limit・チューニング |
| `Caddyfile`(新規) | Caddy | `{$DOMAIN}` の自動HTTPS + reverse_proxy |
| `.env.prod.example`(新規) | env | 本番環境変数テンプレート |
| `scripts/backup-db.sh`(新規) | Bash | pg_dump 日次バックアップ + 7世代ローテ |
| `docs/DEPLOYMENT.md`(新規) | Docs | 本番デプロイ手順書(初回/更新/ロールバック/バックアップ) |
| `.github/workflows/deploy.yml`(任意・新規) | CI | main/タグ push で GHCR に build+push |

---

## Task 1: 本番実行 toplevel(`recurya/main`)と start! のタイムゾーン非致命化

**Files:**
- Create: `main.lisp`
- Create: `tests/main.lisp`
- Modify: `recurya.asd`(umbrella depends-on に `recurya/main` 追加)
- Modify: `web/server.lisp`(`start!` のタイムゾーン読込)

**背景:** 開発では web サーバを cl-mcp ワーカー内(`start-worker-app`)で起動している。本番は cl-mcp を含まないため、`recurya/db/core:start!`(グローバル datasource 接続)→ `recurya/web/server:start!`(hunchentoot、`:use-thread t` で即時 return)を直接呼ぶ独立 toplevel を新設する。`start!` は内部で `ensure-sessions-table!` と `local-time:reread-timezone-repository` を呼ぶため、saved-core でバンドル zoneinfo パスが欠落しても致命的にならないよう `start!` を1点だけ堅牢化する。

- [ ] **Step 1: 失敗するテストを書く**

`Write` で `tests/main.lisp` を作成(package-inferred でシステム名は `recurya/tests/main`、`./tests/main.lisp` にマップされる):

```lisp
;;;; tests/main.lisp --- Smoke test for the production executable entry point.
;;;; Importing the exported symbols forces recurya/main to load as a
;;;; dependency; if they are missing/unexported the test system fails to load
;;;; (a valid red state before main.lisp exists).
(defpackage #:recurya/tests/main
  (:use #:cl #:rove)
  (:import-from #:recurya/main
                #:recurya-main
                #:boot!))
(in-package #:recurya/tests/main)

(deftest production-entry-points-exist
  (testing "recurya/main exposes callable boot + toplevel entry points"
    (ok (fboundp 'recurya-main))
    (ok (fboundp 'boot!))))
```

- [ ] **Step 2: テストが失敗することを確認**

`run-tests` を `{"system": "recurya/tests/main"}` で実行。
Expected: システムロード段階で失敗(`recurya/main` システム/パッケージが未定義)。

- [ ] **Step 3: `main.lisp` を実装**

`Write` で `main.lisp` を作成:

```lisp
;;;; main.lisp --- Production executable entry point.
;;;;
;;;; Boot sequence for the save-lisp-and-die core: reload foreign libraries,
;;;; connect the database, seed official content, start the web server, then
;;;; block until SIGTERM/SIGINT for graceful shutdown. Kept separate from
;;;; web/server.lisp so the deploy bootstrap has one clear responsibility and
;;;; the dev/worker startup paths (start-worker-app) stay untouched.

(defpackage #:recurya/main
  (:use #:cl)
  (:import-from #:cl+ssl
                #:reload)
  (:import-from #:recurya/db/core
                #:connect-to-database)
  (:import-from #:recurya/web/server
                #:start!
                #:stop!)
  (:import-from #:recurya/seed/official-content
                #:seed-official-content!)
  (:export #:recurya-main
           #:boot!))

(in-package #:recurya/main)

(defvar *shutdown-requested* nil
  "Set by the SIGTERM/SIGINT handler so the main loop can stop the server in a
normal (non-signal) context.")

(defun reload-foreign-libraries! ()
  "Reload foreign libraries after a save-lisp-and-die restore.

A saved core loses its live foreign-library handles, so cl+ssl (used by
dexador for the OAuth HTTPS calls to Google/GitHub) must reopen libssl before
the first request. Failures are logged, not fatal, so the operator can still
reach the box even if the TLS stack is broken."
  (handler-case (cl+ssl:reload)
    (error (e)
      (format *error-output* "~&[boot] WARN: cl+ssl reload failed: ~A~%" e)
      (force-output *error-output*))))

(defun boot! ()
  "Run the production startup sequence and return once the web server thread is
listening. Non-blocking: START! uses clackup with :use-thread t."
  (reload-foreign-libraries!)
  (recurya/db/core:start!)
  (handler-case (seed-official-content!)
    (error (e)
      (format *error-output* "~&[boot] WARN: seed failed: ~A~%" e)
      (force-output *error-output*)))
  (start!)
  (values))

(defun recurya-main ()
  "Executable toplevel for the production core. Boots the app, installs signal
handlers, and blocks the main thread until SIGTERM/SIGINT; then stops the
server gracefully and exits 0."
  (setf *shutdown-requested* nil)
  (boot!)
  (flet ((request-shutdown (signo info context)
           (declare (ignore signo info context))
           (setf *shutdown-requested* t)))
    (sb-sys:enable-interrupt sb-unix:sigterm #'request-shutdown)
    (sb-sys:enable-interrupt sb-unix:sigint #'request-shutdown))
  (format t "~&recurya production core listening (PORT=~A)~%"
          (or (uiop:getenv "PORT") "13000"))
  (force-output)
  (loop until *shutdown-requested* do (sleep 1))
  (format t "~&[boot] shutdown requested; stopping server~%")
  (force-output)
  (ignore-errors (stop!))
  (sb-ext:exit :code 0))
```

- [ ] **Step 4: パース検証**

`lisp-check-parens` を `{"path": "main.lisp"}` で実行。Expected: balanced(エラーなし)。

- [ ] **Step 5: umbrella の depends-on に `recurya/main` を追加**

`lisp-patch-form` を `recurya.asd` に対して実行(`defsystem` "recurya")。まず `dry_run: true` で確認:
- `form_type`: `defsystem`
- `form_name`: `recurya`
- `old_text`: `"recurya/seed/official-content")`
- `new_text`: `"recurya/seed/official-content"\n   "recurya/main")`

`would_change: true` を確認してから `dry_run` を外して適用。

> 注: `"recurya/seed/official-content")` が depends-on リストの閉じ括弧を含む一意アンカー。マッチが複数/ゼロなら `lisp-read-file recurya.asd name_pattern="recurya"` で実際の字面を確認して `old_text` を調整。

- [ ] **Step 6: `start!` のタイムゾーン読込を非致命化**

`lisp-patch-form` を `web/server.lisp` の `start!` に対して実行:
- `form_type`: `defun`
- `form_name`: `start!`
- `old_text`:
```lisp
    (local-time:reread-timezone-repository)
    (log:info "Timezone repository loaded")
```
- `new_text`:
```lisp
    ;; In the saved-core production image the bundled zoneinfo path may be
    ;; absent, so keep this non-fatal: UTC/ISO-8601 timestamps work regardless
    ;; of the named-zone database.
    (handler-case
        (progn
          (local-time:reread-timezone-repository)
          (log:info "Timezone repository loaded"))
      (error (e)
        (log:warn "Timezone repository load skipped: ~A" e)))
```

- [ ] **Step 7: テストが通ることを確認**

`run-tests` を `{"system": "recurya/tests/main"}` で実行。Expected: 2 checks pass, 0 fail。

- [ ] **Step 8: 全体コンパイルの健全性確認**

`repl-eval` で `(asdf:compile-system :recurya :force t)` を実行。Expected: 致命的な error なし(既存の想定内 warning は可)。続けて `load-system` `{"system": "recurya", "force": true}`。

- [ ] **Step 9: コミット**

```bash
git add main.lisp tests/main.lisp recurya.asd web/server.lisp
git commit -m "feat(deploy): add recurya/main production entry point

Standalone save-lisp-and-die toplevel: reload FFI (cl+ssl), connect DB,
seed, start Hunchentoot, block until SIGTERM for graceful shutdown.
Harden start! timezone load for the saved-core runtime.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: save-lisp-and-die ビルドスクリプト(`build.lisp`)

**Files:**
- Create: `build.lisp`

**背景:** builder イメージ内で `qlot exec sbcl --load build.lisp` として実行し、`/app/recurya` に実行コアを生成する。ランタイムのヒープ上限は焼き込まず(`:save-runtime-options nil`)、コンテナ CMD で `--dynamic-space-size 1024` を渡す。これによりビルド時はヒープ制約を受けず、実行時のみ 1GB に制限できる。

- [ ] **Step 1: `build.lisp` を作成**

`Write` で `build.lisp` を作成:

```lisp
;;;; build.lisp --- Produce the standalone production executable core.
;;;;
;;;; Runs inside the builder stage of Dockerfile.prod:
;;;;   qlot exec sbcl --non-interactive --load build.lisp
;;;; Output: an executable SBCL core at $RECURYA_CORE_OUT (default /app/recurya)
;;;; whose toplevel is recurya/main:recurya-main.

(setf sb-impl::*default-external-format* :utf-8)

;; Load the project through Quicklisp/ASDF (qlot exec provides the local dist).
(ql:quickload :recurya)
(asdf:load-system "recurya/main")

(let ((out (or (uiop:getenv "RECURYA_CORE_OUT") "/app/recurya")))
  (format t "~&[build] saving executable core to ~A~%" out)
  (force-output)
  (sb-ext:save-lisp-and-die
   out
   :executable t
   :toplevel #'recurya/main:recurya-main
   :save-runtime-options nil
   #+sb-core-compression :compression #+sb-core-compression t))
```

> 注: `#+sb-core-compression` は SBCL がコア圧縮対応時のみ `:compression t` を付ける読み時条件化。fukamachi/sbcl イメージが非対応でも安全にスキップされる。

- [ ] **Step 2: パース検証**

`lisp-check-parens` を `{"path": "build.lisp"}` で実行。Expected: balanced。

- [ ] **Step 3: (ローカル簡易確認・任意)ロードだけ検証**

`repl-eval` で `(uiop:getenv "PORT")` 等が使えることは既知。`build.lisp` の実行そのものは `save-lisp-and-die` を呼ぶ破壊的操作なので、**ローカル REPL では実行しない**。実挙動は Task 3 の Docker ビルドで検証する。

- [ ] **Step 4: コミット**

```bash
git add build.lisp
git commit -m "feat(deploy): add save-lisp-and-die build script for production core

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 本番 Docker イメージ(`Dockerfile.prod`)

**Files:**
- Create: `Dockerfile.prod`

**背景:** builder は `fukamachi/sbcl:2.5.10-debian`(glibc)でコア生成。runtime は同じ glibc 系 `debian:bookworm-slim` に共有ライブラリ(`libssl3` `libffi8` `ca-certificates` `tzdata`)のみ。**builder と runtime の `WORKDIR` を揃えて `/app`** にすることで、コアが記憶する `asdf:system-relative-pathname :recurya "resources/static/"` = `/app/resources/static/` が runtime でも解決できる(コード変更不要)。libpq/libev はランタイム不要(cl-postgres は純Lisp、サーバは hunchentoot)。

> **実行時ファイル依存(重要):** コードベースで実行時に `system-relative-pathname :recurya` を使うのは2箇所のみ(全体検索で確認済み。他の2件はテスト専用):
> 1. `web/server.lisp` build-app → `resources/static/`(静的アセット)
> 2. `seed/official-content.lisp` → **`docs/sicp/` と `docs/novel-lessons/`** の Markdown を boot 毎に読む(`*official-courses*` の `content-dir`)。
>
> したがって runtime には `/app/resources` に加え **`/app/docs/sicp` と `/app/docs/novel-lessons` を必ずコピー**する。欠けても boot はクラッシュしない(`%content-markdown-files` が warn して skip)が、**公式コース(SICP / ノベル)が seed されない**機能欠落になる。

- [ ] **Step 1: `Dockerfile.prod` を作成**

`Write` で `Dockerfile.prod` を作成:

```dockerfile
# syntax=docker/dockerfile:1
# Production image for recurya: multi-stage save-lisp-and-die build.

ARG SBCL_VERSION=2.5.10
ARG QLOT_VERSION=1.7.5

# ---------------------------------------------------------------------------
# builder: qlot install + save-lisp-and-die -> /app/recurya (executable core)
# ---------------------------------------------------------------------------
FROM fukamachi/sbcl:${SBCL_VERSION}-debian AS builder
ARG QLOT_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
      git libssl-dev libffi-dev gcc libc6-dev ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN ros setup && \
    ros -e '(ql:update-dist "quicklisp" :prompt nil)' && \
    ros install "fukamachi/qlot/${QLOT_VERSION}"
ENV PATH="/root/.roswell/bin:${PATH}"

WORKDIR /app

# Dependency layer first for caching.
COPY qlfile qlfile.lock ./
RUN qlot install

# Project sources.
COPY . .

# Produce the executable core at /app/recurya.
RUN qlot exec sbcl --non-interactive \
      --eval '(setf sb-impl::*default-external-format* :utf-8)' \
      --load build.lisp && \
    test -x /app/recurya

# ---------------------------------------------------------------------------
# runtime: slim glibc image with only the shared libraries the core needs.
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
      libssl3 libffi8 ca-certificates tzdata && \
    rm -rf /var/lib/apt/lists/* && \
    ln -snf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

RUN groupadd -g 1000 app && \
    useradd -u 1000 -g app -m -s /usr/sbin/nologin app

WORKDIR /app
# Keep the same path the core baked in (system-relative-pathname :recurya).
COPY --from=builder /app/recurya /app/recurya
COPY --from=builder /app/resources /app/resources
# Seeding reads official-course markdown at boot via
# (asdf:system-relative-pathname :recurya "docs/<course>/") -> /app/docs/...
# Without these the app boots but seeds no official courses.
COPY --from=builder /app/docs/sicp /app/docs/sicp
COPY --from=builder /app/docs/novel-lessons /app/docs/novel-lessons
RUN chown -R app:app /app

USER app
ENV PORT=13000 \
    TZ=Asia/Tokyo
EXPOSE 13000

# --dynamic-space-size caps the heap at 1 GiB at runtime (see design spec 3.5).
CMD ["/app/recurya", "--dynamic-space-size", "1024"]
```

- [ ] **Step 2: `.dockerignore` に本番ビルド不要物が入らないか確認**

`Read` で `.dockerignore` を確認。`.qlot/` は builder が `qlot install` で再生成するため、除外されていてよい(むしろ推奨)。除外されていなければ追記:
```
.qlot
.git
.tmp
```
> **注意: `docs/` を丸ごと除外してはならない。** runtime は `docs/sicp` と `docs/novel-lessons` を builder からコピーする(seed の実行時依存)。ビルドコンテキストを絞るなら、これら2つは残しつつ `docs/superpowers`・`docs/plans`・`docs/sicp-migration-dsl-survey.md` 等のみを個別に除外する:
> ```
> docs/superpowers
> docs/plans
> ```
（`.dockerignore` は非 Lisp。`Edit`/`Write` で可。既に十分なら変更不要。）

- [ ] **Step 3: イメージをビルド**

Run:
```bash
docker build -f Dockerfile.prod -t ghcr.io/masatoi/recurya:dev-test .
```
Expected: builder が `qlot install` → `save-lisp-and-die` を完了し、`[build] saving executable core to /app/recurya` を出力。runtime ステージまで成功。最終行 `naming to ghcr.io/masatoi/recurya:dev-test`。

- [ ] **Step 4: コアが起動しヘルプ的に落ちないこと(DB無しでの起動失敗の仕方)を確認**

Run:
```bash
docker run --rm ghcr.io/masatoi/recurya:dev-test --dynamic-space-size 1024 || true
```
Expected: DB 未接続のため `boot!` の `recurya/db/core:start!` で接続エラー終了する(これは想定内)。**重要なのは「実行コアが起動し Lisp が動いている」こと**(SBCL のコンディション/バックトレースが出れば FFI ロードとコア展開は成功)。ネットワーク付き完全起動は Task 6。

- [ ] **Step 5: イメージサイズを記録**

Run:
```bash
docker images ghcr.io/masatoi/recurya:dev-test --format '{{.Size}}'
```
Expected: 数百 MB 台(slim runtime + コア)。`docs/DEPLOYMENT.md`(Task 7)に記録。

- [ ] **Step 6: コミット**

```bash
git add Dockerfile.prod .dockerignore
git commit -m "feat(deploy): add multi-stage production Dockerfile (save-lisp-and-die)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Compose スタック + Caddy + env テンプレート

**Files:**
- Create: `docker-compose.prod.yml`
- Create: `Caddyfile`
- Create: `.env.prod.example`

- [ ] **Step 1: `.env.prod.example` を作成**

`Write`:
```bash
# recurya 本番環境変数テンプレート。
# `cp .env.prod.example .env.prod` して実値を埋める。.env.prod はコミット禁止。

# --- 公開ドメイン(Caddy 自動HTTPS / OAuth リダイレクト先) ---
DOMAIN=recurya.example.com

# --- イメージタグ(GHCR) ---
RECURYA_TAG=latest

# --- PostgreSQL ---
POSTGRES_DB=recurya
POSTGRES_USER=postgres
# 十分に強いランダム文字列に置換すること。
POSTGRES_PASSWORD=CHANGE_ME_STRONG_PASSWORD

# --- OAuth 公開オリジン(必ず https の公開URL) ---
OAUTH_REDIRECT_BASE=https://recurya.example.com

# --- OAuth: Google (https://console.cloud.google.com/apis/credentials) ---
# 承認済みリダイレクトURI: ${OAUTH_REDIRECT_BASE}/auth/google/callback
OAUTH_GOOGLE_CLIENT_ID=
OAUTH_GOOGLE_CLIENT_SECRET=

# --- OAuth: GitHub (https://github.com/settings/developers) ---
# Authorization callback URL: ${OAUTH_REDIRECT_BASE}/auth/github/callback
OAUTH_GITHUB_CLIENT_ID=
OAUTH_GITHUB_CLIENT_SECRET=

# --- 管理者に role=admin を付与するメール(カンマ区切り) ---
ADMIN_OAUTH_EMAIL=

# 注意: OAUTH_DEV_STUB は本番では絶対に設定しないこと。
```

- [ ] **Step 2: `.env.prod` を gitignore へ**

`Read` で `.gitignore` を確認し、`.env.prod` が無ければ追記(`Edit`):
```
.env.prod
```
Expected: `.env.prod` が追跡対象外になる。

- [ ] **Step 3: `Caddyfile` を作成**

`Write`:
```
{$DOMAIN} {
	encode zstd gzip
	reverse_proxy recurya:13000
}
```

- [ ] **Step 4: `docker-compose.prod.yml` を作成**

`Write`:
```yaml
name: recurya-prod

services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-recurya}
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --locale=C"
    command:
      - "postgres"
      - "-c"
      - "max_connections=30"
      - "-c"
      - "shared_buffers=128MB"
      - "-c"
      - "work_mem=4MB"
      - "-c"
      - "effective_cache_size=512MB"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-postgres} -d ${POSTGRES_DB:-recurya}"]
      interval: 10s
      timeout: 5s
      retries: 5
    mem_limit: 400m

  recurya:
    image: ghcr.io/masatoi/recurya:${RECURYA_TAG:-latest}
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      PORT: "13000"
      POSTGRES_HOST: postgres
      POSTGRES_PORT: "5432"
      POSTGRES_DB: ${POSTGRES_DB:-recurya}
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}
      OAUTH_REDIRECT_BASE: ${OAUTH_REDIRECT_BASE:?OAUTH_REDIRECT_BASE is required}
      OAUTH_GOOGLE_CLIENT_ID: ${OAUTH_GOOGLE_CLIENT_ID:-}
      OAUTH_GOOGLE_CLIENT_SECRET: ${OAUTH_GOOGLE_CLIENT_SECRET:-}
      OAUTH_GITHUB_CLIENT_ID: ${OAUTH_GITHUB_CLIENT_ID:-}
      OAUTH_GITHUB_CLIENT_SECRET: ${OAUTH_GITHUB_CLIENT_SECRET:-}
      ADMIN_OAUTH_EMAIL: ${ADMIN_OAUTH_EMAIL:-}
      TZ: Asia/Tokyo
    expose:
      - "13000"
    mem_limit: 900m

  caddy:
    image: caddy:2-alpine
    restart: unless-stopped
    depends_on:
      - recurya
    ports:
      - "80:80"
      - "443:443"
    environment:
      DOMAIN: ${DOMAIN:?DOMAIN is required}
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    mem_limit: 64m

volumes:
  pgdata:
  caddy_data:
  caddy_config:
```

> `OAUTH_DEV_STUB` は意図的に未設定。`recurya`/`postgres` はホストにポート公開せず(`expose` のみ / 非公開)、Caddy だけが 80/443 を公開する。

- [ ] **Step 5: compose 設定の検証**

Run:
```bash
cp .env.prod.example .env.prod
docker compose --env-file .env.prod -f docker-compose.prod.yml config >/dev/null && echo "compose OK"
```
Expected: `compose OK`(必須変数の補間が通り、構文エラーなし)。検証後 `.env.prod` は実値に置換して使う(コミットしない)。

- [ ] **Step 6: コミット**

```bash
git add docker-compose.prod.yml Caddyfile .env.prod.example .gitignore
git commit -m "feat(deploy): add prod compose stack (caddy + recurya + postgres) and env template

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: DBバックアップスクリプト(`scripts/backup-db.sh`)

**Files:**
- Create: `scripts/backup-db.sh`

- [ ] **Step 1: `scripts/backup-db.sh` を作成**

`Write`:
```bash
#!/usr/bin/env bash
# Daily pg_dump backup with N-day rotation for the recurya production DB.
# Intended to run from the compose project directory via host cron, e.g.:
#   0 4 * * * cd /opt/recurya && ./scripts/backup-db.sh >> backups/backup.log 2>&1
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
ENV_FILE="${ENV_FILE:-.env.prod}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
KEEP_DAYS="${KEEP_DAYS:-7}"

# Pull DB/user from the env file if present (POSTGRES_DB / POSTGRES_USER).
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  set -a; . "$ENV_FILE"; set +a
fi
DB="${POSTGRES_DB:-recurya}"
USER="${POSTGRES_USER:-postgres}"

mkdir -p "$BACKUP_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$BACKUP_DIR/recurya-$STAMP.sql.gz"

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec -T postgres \
  pg_dump -U "$USER" -d "$DB" | gzip > "$OUT"

echo "backup written: $OUT"

# Rotate: delete dumps older than KEEP_DAYS.
find "$BACKUP_DIR" -name 'recurya-*.sql.gz' -type f -mtime +"$KEEP_DAYS" -delete
```

- [ ] **Step 2: 実行権限を付与**

Run:
```bash
chmod +x scripts/backup-db.sh && echo "chmod OK"
```
Expected: `chmod OK`。

- [ ] **Step 3: 構文チェック**

Run:
```bash
bash -n scripts/backup-db.sh && echo "syntax OK"
```
Expected: `syntax OK`。(実バックアップは Task 6 のスタック起動後に実行して検証。)

- [ ] **Step 4: コミット**

```bash
git add scripts/backup-db.sh
git commit -m "feat(deploy): add pg_dump backup script with rotation

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: エンドツーエンド スモークテスト(初回DB初期化含む)

**Files:** なし(検証タスク)。ローカルで本番スタックを起動し、初回スキーマ投入から HTTP 応答・graceful stop・バックアップまで通す。

**背景:** 初回のみ空の Postgres に **`db/schema.sql` を投入**してスキーマを作る(auto-migrate 無効のため)。以降のスキーマ変更は Mito CLI(後述 Task 7 の手順)。

- [ ] **Step 1: `.env.prod` をローカル検証値に用意**

`.env.prod` の `POSTGRES_PASSWORD` をランダム値に、`DOMAIN`/`OAUTH_REDIRECT_BASE` はローカル検証用にダミー(例 `localhost`)で可。OAuth 実往復はこのタスクでは行わない。

- [ ] **Step 2: postgres だけ先に起動**

Run:
```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d postgres
docker compose --env-file .env.prod -f docker-compose.prod.yml ps
```
Expected: `postgres` が `healthy`。

- [ ] **Step 3: 初回スキーマを投入**

Run:
```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml exec -T postgres \
  psql -U postgres -d recurya < db/schema.sql
```
Expected: `CREATE TABLE` 等が並び、エラーなく完了。

- [ ] **Step 4: Postgres チューニングが効いていることを確認**

Run:
```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml exec -T postgres \
  psql -U postgres -d recurya -c 'SHOW max_connections; SHOW shared_buffers;'
```
Expected: `max_connections = 30`, `shared_buffers = 128MB`。

- [ ] **Step 5: recurya + caddy を起動(ローカルビルドのイメージを使用)**

`RECURYA_TAG` をローカルビルドの `dev-test` に合わせるか、compose の `recurya.image` を一時的に `ghcr.io/masatoi/recurya:dev-test` に読み替えて:
```bash
RECURYA_TAG=dev-test docker compose --env-file .env.prod -f docker-compose.prod.yml up -d recurya
docker compose --env-file .env.prod -f docker-compose.prod.yml logs --tail=40 recurya
```
Expected: ログに `recurya production core listening (PORT=13000)`。DB 接続エラーが出ないこと。

- [ ] **Step 6: HTTP 応答を確認(app 内部ポート経由)**

Caddy 無しで app 単体を検証するため、一時的に app をホストに露出して確認:
```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml exec -T recurya \
  sh -c 'true' 2>/dev/null; \
CID=$(docker compose --env-file .env.prod -f docker-compose.prod.yml ps -q recurya); \
docker run --rm --network container:$CID curlimages/curl:latest -sS -o /dev/null -w '%{http_code}\n' http://localhost:13000/
```
Expected: `200`(ログインページ)。

> 代替(よりシンプル): 検証中だけ `docker-compose.prod.yml` の `recurya` に `ports: ["13000:13000"]` を一時追加して `curl -I http://localhost:13000/` で 200 を確認し、確認後に戻す。

- [ ] **Step 6b: 公式コンテンツが seed されたことを確認(runtime のファイル依存の検証)**

boot 時の seed が `/app/docs/sicp` `/app/docs/novel-lessons` を読めているかを DB で確認:
```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml exec -T postgres \
  psql -U postgres -d recurya -c "SELECT slug FROM course ORDER BY slug;"
```
Expected: `sicp` と `novel-lessons` の行が存在する。また `recurya` ログに `content directory ... does not exist; skipping` の **warn が出ていない**こと。warn が出ていれば Task 3 の docs コピーが漏れている。

- [ ] **Step 7: request-test によるHTMX認証フロー検証(任意だが推奨)**

`scripts/request-test.sh` を本番オリジン(ローカル検証中は app のポート)に向けて実行し、HTMX 断片・認証フローをブラウザレスで検証。Expected: 主要チェックが green。

- [ ] **Step 8: graceful stop とセッション永続の確認**

Run:
```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml stop recurya
docker compose --env-file .env.prod -f docker-compose.prod.yml logs --tail=10 recurya
```
Expected: ログに `[boot] shutdown requested; stopping server`(SIGTERM が graceful に処理され、`docker stop` がタイムアウト kill されない)。再 `up -d recurya` 後、`sessions` テーブルが残存しログイン状態が復元可能なこと(DB永続)。

- [ ] **Step 9: バックアップスクリプトの実挙動確認**

Run:
```bash
./scripts/backup-db.sh
ls -lh backups/
```
Expected: `recurya-YYYYmmdd-HHMMSS.sql.gz` が生成される。

- [ ] **Step 10: 後片付け**

Run:
```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml down
```
（データを消す場合のみ `-v`。検証データは保持で可。）一時的に加えた `ports` 露出を戻したか確認。

- [ ] **Step 11: コミット(なし)**

このタスクは検証のみ。設定調整が生じた場合のみ該当ファイルを対象タスクに戻して修正・コミット。

---

## Task 7: デプロイ手順書(`docs/DEPLOYMENT.md`)

**Files:**
- Create: `docs/DEPLOYMENT.md`

- [ ] **Step 1: `docs/DEPLOYMENT.md` を作成**

`Write` で以下を作成(実測イメージサイズ等は Task 3/6 の結果を反映):

````markdown
# Recurya 本番デプロイ手順(さくらVPS 2GB / Docker)

## 構成概要
- 単一VPS(2 vCPU+/2GB/SSD)上の `docker compose`(`docker-compose.prod.yml`)。
- サービス: `caddy`(80/443 公開・自動HTTPS)/ `recurya`(実行コア・内部13000)/ `postgres`(内部5432)。
- イメージはローカル/CIでビルドし **GHCR** へ push、VPS は pull。

## 0. 前提
- VPS に Docker / Docker Compose plugin 済み。
- **2GB swapfile** 作成済み(未作成なら下記)。
- 取得済みドメインの A レコードを VPS の IP に向けてある。
- GHCR に pull できる(private の場合 `docker login ghcr.io`)。

### swapfile 作成(初回)
```bash
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## 1. イメージのビルドと push(ローカル/CI)
```bash
export TAG=$(git rev-parse --short HEAD)
docker build -f Dockerfile.prod -t ghcr.io/masatoi/recurya:$TAG -t ghcr.io/masatoi/recurya:latest .
echo "$GHCR_PAT" | docker login ghcr.io -u masatoi --password-stdin
docker push ghcr.io/masatoi/recurya:$TAG
docker push ghcr.io/masatoi/recurya:latest
```
> 2GB VPS 上ではビルドしない(コンパイルがメモリ/ディスクを逼迫する)。

## 2. VPS 側の初期設定(初回のみ)
```bash
git clone <repo> /opt/recurya && cd /opt/recurya
cp .env.prod.example .env.prod
# .env.prod を実値で編集(POSTGRES_PASSWORD, DOMAIN, OAUTH_*, ADMIN_OAUTH_EMAIL)
```

### OAuth 設定
- Google/GitHub コンソールで redirect URI を登録:
  - `https://<DOMAIN>/auth/google/callback`
  - `https://<DOMAIN>/auth/github/callback`
- `OAUTH_REDIRECT_BASE=https://<DOMAIN>` を `.env.prod` に設定。
- `OAUTH_DEV_STUB` は設定しない。

## 3. 初回スキーマ投入
```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d postgres
docker compose --env-file .env.prod -f docker-compose.prod.yml exec -T postgres \
  psql -U postgres -d recurya < db/schema.sql
```

## 4. 起動
```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml pull
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d
docker compose --env-file .env.prod -f docker-compose.prod.yml ps
```
`https://<DOMAIN>/` にアクセスし、Caddy の証明書取得後にログインページが表示されることを確認。OAuth ログインを1度ブラウザで確認する。

## 5. 更新デプロイ
```bash
# ローカル/CIで新イメージを push した後、VPS で:
cd /opt/recurya
export RECURYA_TAG=<新しいタグ>   # または latest
docker compose --env-file .env.prod -f docker-compose.prod.yml pull recurya
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d recurya
```
- 短時間のダウンを許容(単一VPS)。`recurya-main` は SIGTERM で graceful stop する。

## 6. スキーマ変更(マイグレーション)
初回以降のスキーマ変更は Mito CLI。内部 postgres へ一時的にポート転送して実行:
```bash
# 別ターミナルで一時ポート転送
docker compose --env-file .env.prod -f docker-compose.prod.yml exec postgres \
  sh -c 'echo "use host port-forward"'   # もしくは compose に一時 ports: ["15434:5432"] を追加
# ローカルの mito でマイグレーション(-D db/)
.qlot/bin/mito migrate -t postgres -H localhost -P 15434 \
  -d recurya -u postgres -p "$POSTGRES_PASSWORD" -s recurya -D db/
```
> 詳細は `/mito-migrate` スキルおよび CLAUDE.md を参照。適用後は一時ポートを閉じる。

## 7. バックアップ / リストア
- 日次 cron(初回設定):
  ```bash
  crontab -e
  # 0 4 * * * cd /opt/recurya && ./scripts/backup-db.sh >> backups/backup.log 2>&1
  ```
- リストア:
  ```bash
  gunzip -c backups/recurya-<STAMP>.sql.gz | \
    docker compose --env-file .env.prod -f docker-compose.prod.yml exec -T postgres \
    psql -U postgres -d recurya
  ```

## 8. ロールバック
```bash
export RECURYA_TAG=<以前のタグ>
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d recurya
```
DB スキーマ非互換の場合はバックアップからリストア。

## 9. トラブルシュート
- ログ: `docker compose --env-file .env.prod -f docker-compose.prod.yml logs -f recurya`
- メモリ: `docker stats --no-stream`(recurya < 900m, postgres < 400m を確認)
- 証明書取得失敗: DNS A レコードと 80/443 の到達性、`caddy` ログを確認。
- OAuth 失敗: `OAUTH_REDIRECT_BASE` と各コンソールの redirect URI 一致、`ca-certificates` を確認。

## 参考: 固定費
- さくらVPS 2GB(約 ¥1,738/月〜)+ ドメイン(約 ¥125/月)= **約 ¥1,900/月**。変動費なし。
````

- [ ] **Step 2: コミット**

```bash
git add docs/DEPLOYMENT.md
git commit -m "docs(deploy): add production deployment runbook

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8(任意): CI で GHCR へ build + push

**Files:**
- Create: `.github/workflows/deploy.yml`

> ユーザーが「今回スコープに含める」と決めた場合のみ実施。VPS への反映は手動 pull のまま(自動 SSH デプロイは本計画のスコープ外)。

- [ ] **Step 1: `.github/workflows/deploy.yml` を作成**

`Write`:
```yaml
name: build-and-push

on:
  push:
    branches: [main]
    tags: ["v*"]

jobs:
  build-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/metadata-action@v5
        id: meta
        with:
          images: ghcr.io/masatoi/recurya
          tags: |
            type=sha,format=short
            type=ref,event=tag
            type=raw,value=latest,enable={{is_default_branch}}

      - uses: docker/build-push-action@v6
        with:
          context: .
          file: Dockerfile.prod
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

- [ ] **Step 2: ワークフロー構文の簡易確認**

Run:
```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/deploy.yml')); print('yaml OK')"
```
Expected: `yaml OK`。(実 push は GitHub 上で検証。)

- [ ] **Step 3: コミット**

```bash
git add .github/workflows/deploy.yml
git commit -m "ci(deploy): build and push prod image to GHCR on main/tags

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 完了条件(Definition of Done)

- [ ] `recurya/tests/main` が green、`(asdf:compile-system :recurya :force t)` が致命的 error なし。
- [ ] `docker build -f Dockerfile.prod` が成功し、実行コアが起動する(DB付きで完全起動を確認)。
- [ ] `docker compose -f docker-compose.prod.yml` で 3 コンテナが起動、`/` が 200、`docker stop` が graceful。
- [ ] Postgres チューニング(max_connections=30 等)が反映、`scripts/backup-db.sh` がダンプを生成。
- [ ] `docs/DEPLOYMENT.md` に初回/更新/マイグレーション/バックアップ/ロールバック手順が揃う。
- [ ] (任意)CI が GHCR へ push できる。
- [ ] 実VPSで `https://<DOMAIN>/` がログイン表示、OAuth 往復が1度成功(ブラウザ確認)。

## リスクと対処(実装時に注意)

- **cl+ssl の FFI 再ロード失敗** → OAuth の HTTPS が失敗。Task 6 で OAuth 経路まで踏む(実VPSで最終確認)。失敗時は `reload-foreign-libraries!` のログを確認、runtime の `libssl3`/`ca-certificates` を点検。
- **saved-core の `system-relative-pathname` パス不一致** → 静的アセット 404。builder/runtime の `WORKDIR /app` 一致と `/app/resources` コピーで解決済み。404 が出たら Task 3 のパス整合を再確認。
- **seed コンテンツ欠落** → boot はするが SICP/ノベルの公式コースが作られない。Task 3 で `/app/docs/sicp`・`/app/docs/novel-lessons` をコピー、Task 6 Step 6b で seed 結果を検証。`.dockerignore` で `docs/` を丸ごと除外しないこと。
- **build 時 OOM(2GB以外の非力な builder)** → CI/ローカルの builder は 2GB 超を推奨。VPS ではビルドしない。
- **SBCL コア圧縮非対応** → `#+sb-core-compression` で自動スキップ。イメージがやや大きくなるのみ。
- **一時的な `ports` 露出の戻し忘れ**(Task 6) → down 前に compose を確認。
