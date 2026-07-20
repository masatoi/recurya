# 本番デプロイ設計: さくらVPS 2GB / Docker / save-lisp-and-die / Caddy

- 日付: 2026-07-21
- 対象: Recurya を実クラウド(さくらのVPS 2GBプラン)へ本番デプロイする構成
- ステータス: 設計確定(ユーザー承認済み)、実装計画待ち

## 1. ゴールと非ゴール

### ゴール
- さくらのVPS 2GB(概ね 3 vCPU / 2GB RAM / SSD 100GB)1台に、Docker Compose で Recurya を本番運用できる構成を確立する。
- 固定費を月 ¥2,000 前後(VPS + ドメイン)に抑える。変動費(外部API課金)はゼロ。
- 開発用イメージ(swank / cl-mcp / ソース bind-mount / 毎起動 seed)を持ち込まず、本番専用のスリムな実行イメージを用意する。
- HTTPS・OAuth(Google/GitHub)・DB永続化・バックアップを本番水準で満たす。

### 非ゴール
- 水平スケール(複数 app インスタンス + ロードバランサ)。セッションが DB 永続化されているため将来コード無改修で移行可能だが、本スペックの対象外。
- Kubernetes / マネージド DB / CDN。この規模では過剰。
- ゼロダウンタイムデプロイ。単一VPSのため、デプロイ時は短時間の切り替えを許容する。

## 2. 全体構成

```
Internet ─80/443─▶ Caddy ─HTTP:13000─▶ recurya(実行コア) ─TCP:5432─▶ postgres
                    │(Let's Encrypt自動TLS)                              │
                  cert volume                                     pgdata volume
```

- VPS上の単一 `docker compose`(`docker-compose.prod.yml`)に **3コンテナ**: `caddy` / `recurya` / `postgres`。
- ホストにポート公開するのは **Caddy(80/443)のみ**。`recurya`(13000)と `postgres`(5432)は compose 内部ネットワーク限定でホストポート非公開 → 攻撃面を最小化。
- `restart: unless-stopped` を全コンテナに付与。

## 3. コンポーネント設計

### 3.1 本番イメージ(マルチステージ + save-lisp-and-die)

**builder ステージ** (`Dockerfile.prod`)
- ベース: `fukamachi/sbcl:2.5.10-debian`(開発と同一SBCL)。
- ビルド依存(git, libssl-dev, libffi-dev 等)を導入 → `qlot install` → ソースをコピー → `build.lisp` を実行。
- `build.lisp`: `(ql:quickload :recurya)` 後に
  `(sb-ext:save-lisp-and-die "/out/recurya" :executable t :toplevel #'recurya/web/server:recurya-main :save-runtime-options t)`。
  - SBCL がコア圧縮対応(`:sb-core-compression`)ならば `:compression t` を付与しイメージ縮小。非対応なら省略(実装時に判定)。
  - `:save-runtime-options t` により `--dynamic-space-size 1024` などのランタイムオプションを焼き込む。

**runtime ステージ**
- ベース: `debian:bookworm-slim`。
- ランタイム共有ライブラリのみ導入: `libssl3` `libffi8` `ca-certificates` `tzdata`。
  - **libpq は不要**(cl-dbi + postmodern/cl-postgres は純Lisp TCP接続)。
  - **libev は不要**(サーバは hunchentoot。現開発Dockerfileの `libev-dev`/`libpq-dev` はランタイム不要)。
- 非rootユーザで実行。実行コア `recurya` と、以下の**実行時ファイル依存**をコピー:
  - `resources/`(静的アセット、build-app が `system-relative-pathname :recurya "resources/static/"` で参照)
  - `docs/sicp/` と `docs/novel-lessons/`(seed が boot 毎に `system-relative-pathname :recurya` 経由で Markdown を読む。欠けると公式コースが seed されない)
  - builder / runtime の `WORKDIR` を `/app` に揃え、コアが記憶するパスを runtime でも一致させる。
- タイムゾーン Asia/Tokyo、外部フォーマット UTF-8。
- `CMD ["/app/recurya", "--dynamic-space-size", "1024"]`(コアが直接webサーバを起動、ヒープ上限1GiB)。

**新 toplevel `recurya-main`**(`web/server.lisp` に追加、cl-mcp 経由で編集)
1. **foreign library の再ロード**(`cl+ssl:reload` 等)。save-lisp-and-die 後は FFI ライブラリのハンドルが無効化されるため、OAuth の HTTPS 通信(dexador → cl+ssl)前に必須。
2. env 読込(`PORT` / `POSTGRES_*`)→ `recurya/db/core:start!` → `ensure-sessions-table!`。
3. 公式コンテンツ seed を冪等ガード付きで一度だけ実行(既存 `seed-official-content!` を流用、失敗は警告のみ)。
4. `recurya/web/server:start!`(hunchentoot)を起動。
5. サーバスレッドを join してブロック。**SIGTERM ハンドラ**で `stop!` を呼び graceful shutdown(`docker stop` / デプロイ切替に対応)。

> 注: 開発では web サーバを cl-mcp ワーカー内(`start-worker-app`)で起動しているが、本番は cl-mcp を含まないため、`start!` を直接呼ぶ独立 toplevel `recurya-main` を新設する。既存の起動経路には手を加えない。

### 3.2 Compose サービス

| サービス | イメージ | 公開ポート | mem_limit | ボリューム |
|---------|---------|-----------|-----------|-----------|
| caddy | `caddy:2-alpine` | 80, 443(ホスト) | 64MB | `caddy_data`(cert), `caddy_config` |
| recurya | `ghcr.io/masatoi/recurya:<tag>` | なし(内部13000) | 900MB | なし |
| postgres | `postgres:16-alpine` | なし(内部5432) | 400MB | `pgdata` |

- 内部ネットワークで名前解決(`recurya`, `postgres`)。
- `recurya` は `depends_on: postgres`(healthcheck 条件付き)、`caddy` は `depends_on: recurya`。
- OS + Docker daemon(~380MB)を残し、mem_limit 合計は約1.36GB。2GB内に収まる。

### 3.3 設定・シークレット

- `.env.prod`(**非コミット**、`.env.prod.example` をコミット):
  - `DOMAIN`(取得済みドメイン)
  - `POSTGRES_DB=recurya` / `POSTGRES_USER=postgres` / `POSTGRES_PASSWORD=<強力なパスワード>`
  - `PORT=13000`
  - `OAUTH_GOOGLE_CLIENT_ID` / `OAUTH_GOOGLE_CLIENT_SECRET`
  - `OAUTH_GITHUB_CLIENT_ID` / `OAUTH_GITHUB_CLIENT_SECRET`
  - `OAUTH_REDIRECT_BASE=https://<DOMAIN>`
  - `ADMIN_OAUTH_EMAIL=<管理者メール>`
  - `OAUTH_DEV_STUB` は**未設定**(安全ゲートが非localhostを弾くが明示的に不使用)。
- Google / GitHub OAuth コンソールに redirect URI 登録:
  - `https://<DOMAIN>/auth/google/callback`
  - `https://<DOMAIN>/auth/github/callback`

### 3.4 Postgres チューニング + バックアップ + マイグレーション

- `postgres:16-alpine`、内部限定、`pgdata` ボリューム、healthcheck(`pg_isready`)。
- チューニング(command フラグまたは conf):
  - `max_connections=30`(短命セッションストア接続 + アプリのプールに十分)
  - `shared_buffers=128MB`
  - `work_mem=4MB`
  - `effective_cache_size=512MB`
- バックアップ: `scripts/backup-db.sh` が `pg_dump` を実行し日次で `backups/` に保存、7世代ローテーション。VPS の host cron から起動(例: 毎日 04:00 JST)。
- マイグレーション: auto-migrate 無効のまま。デプロイ時に `/mito-migrate`(Mito CLI)を手動適用。初回は `db/schema.sql` 相当の初期化を含む。

### 3.5 メモリ収容と安全弁(2GBに収める)

- ホストに **2GB swapfile** を作成(スパイク・OOM時の保険)。
- SBCL `--dynamic-space-size 1024`(MB)をコアに焼き込み。wardlisp 暴走・リーク時は当該コンテナのみ OOM-kill され、`restart: unless-stopped` で復帰。ホスト全体の swap 逼迫を防ぐ。
- `mem_limit` は 3.2 の表のとおり。

### 3.6 TLS / Caddy

- `Caddyfile`:
  ```
  {$DOMAIN} {
      reverse_proxy recurya:13000
  }
  ```
- Let's Encrypt で証明書を自動取得・更新、80→443 リダイレクトも自動。`caddy_data` に証明書永続化。
- アプリは Caddy 背後で平文 HTTP を待受。OAuth の公開オリジンは `OAUTH_REDIRECT_BASE`(https)を使用。

### 3.7 デプロイ手順(ローカル/CIビルド → GHCR → VPS pull)

- レジストリ: **GHCR**(`ghcr.io/masatoi/recurya`)。認証は PAT または GitHub Actions の `GITHUB_TOKEN`。
1. ローカル/CI: `docker build -f Dockerfile.prod -t ghcr.io/masatoi/recurya:<sha> .` → `docker push`。
2. VPS: `docker compose -f docker-compose.prod.yml pull` → Mito CLI でマイグレーション → `docker compose -f docker-compose.prod.yml up -d`。
3. (任意)`.github/workflows/deploy.yml`: main / タグ push で build + push を自動化。VPS への反映は手動 pull(または後日 webhook)。
- **VPS上ではビルドしない**(2GB では重い Lisp コンパイルがメモリ/ディスクを逼迫するため)。

### 3.8 検証(プロジェクト規約どおりサーバ側で)

- `up` 後 `curl -I https://<DOMAIN>/` が 200(ログインページ)を返すこと。
- `scripts/request-test.sh` を本番オリジンに向けて実行し、HTMX 認証フローをブラウザレスで再生・アサート。
- OAuth 往復のみ、実ブラウザで1度確認(Google/GitHub ログイン → コールバック → セッション確立)。
- `docker stop` で graceful shutdown し、再 `up` でセッションが DB から復元されること。

## 4. 追加・変更ファイル(すべて新規・非破壊)

新規:
- `Dockerfile.prod` — マルチステージ本番イメージ
- `build.lisp` — save-lisp-and-die スクリプト
- `docker-compose.prod.yml` — caddy + recurya + postgres
- `Caddyfile`
- `.env.prod.example`
- `scripts/backup-db.sh`
- `.github/workflows/deploy.yml`(任意)
- `docs/DEPLOYMENT.md` — 手順書

変更(cl-mcp 経由):
- `web/server.lisp` — 独立 toplevel `recurya-main` を追加(既存経路は不変)

## 5. リスクと対策

| リスク | 対策 |
|--------|------|
| save-lisp-and-die 後に cl+ssl の FFI が無効で OAuth が失敗 | `recurya-main` 冒頭で foreign library 再ロード。実装時に TDD で OAuth HTTPS 経路を検証 |
| SBCL がコア圧縮非対応でイメージが大きい | 圧縮は任意。非対応なら省略し、slim ランタイムで吸収 |
| 2GB でメモリ逼迫 | mem_limit + swap + dynamic-space-size 上限 + Postgres 接続数制限 |
| 一斉に大量ユーザが wardlisp 実行 | 現状の fuel/depth/cons/timeout 上限で1実行を制限。恒常的に高負荷化したら 4GB プランへ増強 |
| デプロイ時の短時間ダウン | 単一VPSのため許容。切替は数秒〜十数秒 |

## 6. 固定費見積もり

- さくらのVPS 2GB: 約 ¥1,738/月〜
- ドメイン: 約 ¥125/月(¥1,500/年)
- **合計: 約 ¥1,900/月**(変動費なし)

## 7. 増強トリガー

- 同時実行 wardlisp が恒常的に多い / ユーザ増でメモリ逼迫 → 4GB プランへ。
- 冗長化が必要 → app を複数インスタンス化(セッション DB 永続のため無改修可)+ 外部 LB。
