# Recurya 本番デプロイ手順(さくらVPS 2GB / Docker)

## 構成概要

単一VPS上の `docker compose`(`docker-compose.prod.yml`)に3コンテナ:

```
Internet ─80/443─▶ caddy ─HTTP:13000─▶ recurya ─TCP:5432─▶ postgres
                    │(Let's Encrypt自動TLS)                    │
                  cert volume                            pgdata volume
```

- **caddy** (`caddy:2-alpine`): 80/443 をホスト公開、自動HTTPS、`recurya:13000` へ reverse_proxy。
- **recurya**: 本番イメージ。**ソースから起動する方式**(SBCL + qlot でコンテナ起動時に `recurya` をロード。dev と同じ実証済み経路で、swank/cl-mcp は含まない)。内部13000のみ、ホスト非公開。
- **postgres** (`postgres:16-alpine`): 内部5432のみ、ホスト非公開。

> **なぜ save-lisp-and-die 実行コアではないのか**: 当初は save-lisp-and-die の単一バイナリ(~128MB)を検討したが、その実行コアは **DB接続経路で hard SIGSEGV クラッシュ**した(SBCL のコンディション機構をバイパスする低レベル障害。env/`/etc/protocols`/ヒープサイズは実験で無関係と確認済み)。同一コードはソースからの実行では正常に動作するため、本番も「ソース起動」方式を採用している。イメージは ~1.2GB と大きいが、起動時 RSS は ~170MiB と軽量。

イメージは**ローカル/CIでビルドし GHCR 経由で VPS が pull** する(2GBのVPS上ではビルドしない)。

## 0. 前提

- VPS に Docker / Docker Compose plugin 導入済み。
- **2GB swapfile** 作成済み(未作成なら下記)。
- 取得済みドメインの A レコードを VPS の IP に向けてある。
- GHCR に push/pull できる(`docker login ghcr.io`)。

### swapfile 作成(初回)

```bash
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## 1. イメージのビルドと push(ローカル/CI、インターネット必須)

```bash
export TAG=$(git rev-parse --short HEAD)
docker build -f Dockerfile.prod \
  -t ghcr.io/masatoi/recurya:$TAG \
  -t ghcr.io/masatoi/recurya:latest .
echo "$GHCR_PAT" | docker login ghcr.io -u masatoi --password-stdin
docker push ghcr.io/masatoi/recurya:$TAG
docker push ghcr.io/masatoi/recurya:latest
```

- ビルドは `qlot install` + 全システムの事前コンパイルを行うため数分かかる。
- **2GB VPS 上ではビルドしない**(メモリ/ディスクを逼迫する)。CI(`.github/workflows/deploy.yml`)に任せるのが安全。

## 2. VPS 側の初期設定(初回のみ)

```bash
git clone <repo> /opt/recurya && cd /opt/recurya
cp .env.prod.example .env.prod
# .env.prod を実値で編集(下記)
```

`.env.prod` の必須項目:

| 変数 | 内容 |
|------|------|
| `DOMAIN` | 公開ドメイン(Caddy が TLS 取得) |
| `RECURYA_TAG` | pull するイメージタグ(例: `latest` または `<sha>`) |
| `POSTGRES_PASSWORD` | 強力なランダム文字列 |
| `OAUTH_REDIRECT_BASE` | `https://<DOMAIN>` |
| `OAUTH_GOOGLE_CLIENT_ID` / `_SECRET` | Google OAuth |
| `OAUTH_GITHUB_CLIENT_ID` / `_SECRET` | GitHub OAuth |
| `ADMIN_OAUTH_EMAIL` | 管理者メール(カンマ区切り) |

### OAuth 設定

- Google/GitHub コンソールで redirect URI を登録:
  - `https://<DOMAIN>/auth/google/callback`
  - `https://<DOMAIN>/auth/github/callback`
- `OAUTH_DEV_STUB` は**設定しない**(安全ゲートも非localhostを弾く)。

## 3. 初回スキーマ投入

アプリは auto-migrate しない。空DBに初期スキーマを投入する:

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d postgres
# postgres が healthy になるまで待ってから:
docker compose --env-file .env.prod -f docker-compose.prod.yml exec -T postgres \
  psql -U postgres -d recurya < db/schema.sql
```

## 4. 起動

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml pull
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d
docker compose --env-file .env.prod -f docker-compose.prod.yml ps
```

- `recurya` は起動時にソースをロード → DB接続 → 公式コンテンツ(SICP / ノベル)を seed → Hunchentoot 起動。ログに `recurya production core listening (PORT=13000)` が出れば準備完了(初回ロードに数秒)。
- `https://<DOMAIN>/` にアクセスし、Caddy の証明書取得後に表示されることを確認。OAuth ログインを1度ブラウザで確認する。

起動確認ログ例:
```
Database connection established
Hunchentoot server is started.
recurya production core listening (PORT=13000)
```

## 5. 更新デプロイ

> **新しいイメージがスキーマ変更を含む場合は、`up -d` より前にマイグレーションを適用すること。**
> 先に新イメージを起動すると、まだ無いテーブルへのアクセスで 500 になる。
>
> 学習者 CLI / JSON API を含むリリース(`api_token` テーブル)へ初めて更新するときは、
> `pull` の後・`up -d` の前に一度だけ次を実行する(リポジトリの checkout から、コンテナ内の psql へ流し込む):
>
> ```bash
> cd /opt/recurya
> docker compose --env-file .env.prod -f docker-compose.prod.yml exec -T postgres \
>   psql -U postgres -d recurya -v ON_ERROR_STOP=1 < db/migrations/20261013124402.up.sql
> ```
>
> (`POSTGRES_USER` / `POSTGRES_DB` を既定値から変えている場合は `-U` / `-d` を合わせる。
> 適用済みの DB で再実行すると `relation "api_token" already exists` で止まるだけで、データは変わらない。)
> 以後のスキーマ変更も同じ順序(マイグレーション → `up -d`)で行う(§6)。

```bash
# ローカル/CIで新イメージを push した後、VPS で:
cd /opt/recurya
export RECURYA_TAG=<新しいタグ>   # または latest
docker compose --env-file .env.prod -f docker-compose.prod.yml pull recurya
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d recurya
```

- 単一VPSのため切替時に数秒のダウンを許容。`recurya`(`tini` + `recurya/main:recurya-main`)は **SIGTERM で graceful stop**(`docker stop` は約2秒で完了、SIGKILL 待ちにならない)。

## 6. スキーマ変更(マイグレーション)

初回以降のスキーマ変更は Mito CLI。内部 postgres へ一時的にポート転送して実行:

```bash
# docker-compose.prod.yml の postgres に一時的に ports: ["15434:5432"] を追加して up、または
# 別途 SSH ポートフォワード経由で。実行後は一時ポートを閉じる。
.qlot/bin/mito migrate -t postgres -H localhost -P 15434 \
  -d recurya -u postgres -p "$POSTGRES_PASSWORD" -s recurya -D db/
```

> 詳細は `/mito-migrate` スキルおよび CLAUDE.md を参照。

> 注意: 本番 DB は `db/schema.sql` から作成されておりマイグレーション履歴が無いため、`mito migrate` は
> 既存の 7 件を「未適用」として確認してくる。CLI 用の `api_token` テーブルは
> §5 のコマンド(`exec -T postgres psql ... < db/migrations/20261013124402.up.sql`)で、
> 新イメージの `up -d` より前に直接適用する (詳細は `docs/DEVELOPMENT.md` の「JSON API / CLI」)。

## 7. バックアップ / リストア

日次 cron(初回設定):

```bash
crontab -e
# 0 4 * * * cd /opt/recurya && ./scripts/backup-db.sh >> backups/backup.log 2>&1
```

`scripts/backup-db.sh` は `pg_dump` を gzip 圧縮して `backups/` に保存、7世代ローテーション。

リストア:

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

## 9. リソースとチューニング

- **メモリ**: 起動時 RSS ~170MiB(idle)。compose の `mem_limit` は recurya=900m / postgres=400m / caddy=64m。OS+Docker(~380MB)+ swap で 2GB に十分収まる。
- **Postgres**: `max_connections=30` / `shared_buffers=128MB` / `work_mem=4MB`(compose の command で設定)。
- **SBCL ヒープ**: `ros dynamic-space-size=1024`(イメージ CMD)で 1GiB 上限。wardlisp 暴走時はコンテナのみ OOM-kill され `restart: unless-stopped` で復帰。

## 10. トラブルシュート

- ログ: `docker compose --env-file .env.prod -f docker-compose.prod.yml logs -f recurya`
- 起動失敗時: `recurya/main:recurya-main` は boot 失敗を `[boot] FATAL ...` + バックトレースで stderr に出力してから非ゼロ終了する(サイレント死しない)。ログを確認。
- メモリ: `docker stats --no-stream`
- 証明書取得失敗: DNS A レコードと 80/443 の到達性、`caddy` ログを確認。
- OAuth 失敗: `OAUTH_REDIRECT_BASE` と各コンソールの redirect URI 一致を確認。

## 参考: 固定費

- さくらVPS 2GB(約 ¥1,738/月〜)+ ドメイン(約 ¥125/月)= **約 ¥1,900/月**。変動費(外部API課金)なし。
