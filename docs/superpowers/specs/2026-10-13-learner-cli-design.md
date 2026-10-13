# 学習者向け CLI クライアント (JSON API + 個人用アクセストークン) 設計

日付: 2026-10-13 / ブランチ: `feat/learner-cli`

## 背景と目的

Recurya の操作手段は Web UI (MPA + HTMX) だけで、全エンドポイントが HTML を返し、
認証は OAuth + セッション Cookie、POST は CSRF ミドルウェアを通る。
学習者が手元のエディタでノートブックの演習を書き、端末から実行・提出できるように、
トークン認証の JSON API と Common Lisp 製 CLI を追加する。

CLI での進捗 (保存コード・提出履歴・合格・解答解放) は Web UI と同じテーブルに入り、
両者で共有される。

## 範囲

- 対象: ノートブック (`/@handle/slug`) の閲覧・セル実行・保存。
- 範囲外 (v1): パズル、novel (scene/play)、コース、レート制限、OAuth device flow、
  トークンの有効期限・スコープ、ノートブックの作成・編集 (作者向け)。

## 1. 全体構成

```
CLI (cli/, recurya-cli)  --HTTPS, Authorization: Bearer rcy_...-->  /api/v1/*
                                                                     |
                     api-token-auth middleware (Bearer only, cookie session ignored)
                                                                     |
                     web/routes-api  ->  共有関数 (セル実行 + 保存)  <-  既存 notebook ルート
                                                                     |
                                       db/api-tokens, db/learn, game/notebook
```

- API は独立した `/api/v1/*` ルート群 (`web/routes-api.lisp`) とする。既存ルートの
  Accept 分岐や汎用 RPC は採らない (HTML/JSON とクッキー/トークンの混在を避ける)。
- セル実行と保存のロジックは既存ハンドラ (`/@h/slug/cells/:index/run` と
  `%maybe-persist-notebook-cell-run`) から共有関数に抽出し、Web と API の両方が呼ぶ。
  Web の振る舞いは変えない。

## 2. 認証: 個人用アクセストークン

### テーブル `api_token` (新規 deftable、ユーザー承認済み 2026-10-13)

| 列 | 型 | 備考 |
|---|---|---|
| `id` | uuid PK | 既存テーブルと同じ規約 |
| `user_id` | uuid FK → users | |
| `name` | varchar(64) | 利用者が付ける識別名 (例: "laptop") |
| `token_hash` | varchar(64) unique | 平文トークンの SHA-256 hex |
| `token_prefix` | varchar(12) | 表示用 (`rcy_` + 先頭数文字) |
| `last_used_at` | timestamptz null | 認証成功時に更新 |
| `revoked_at` | timestamptz null | 失効時刻。非 null なら無効 |
| `created_at` / `updated_at` | Mito 既定 | |

- トークン書式: `rcy_` + 32 バイト乱数 (ironclad の強乱数) の hex。
- 平文は保存しない。発行時に一度だけ画面に表示する。
- 1 ユーザーあたり有効 (未失効) トークンは最大 10 個。超過時の発行は拒否。
- マイグレーションは Mito CLI (`/mito-migrate`) で生成・適用し、`db/schema.sql` も更新する。

### DB 層 `db/api-tokens`

- `issue-api-token user-id name` → `(values plaintext token-row)`。上限超過は専用 condition。
- `authenticate-api-token plaintext` → 有効ならユーザー (セッションと同じ plist 形)、
  無効・失効・書式不正なら NIL。成功時に `last_used_at` を更新。
- `list-api-tokens user-id` → 表示用 (prefix, name, created/last-used, revoked)。
- `revoke-api-token user-id token-id` → 自分のトークンのみ失効可。

### ミドルウェア `api-token-auth`

- `/api/` 以下にのみ作用。`Authorization: Bearer <token>` を検証し、ユーザーを
  env (`:recurya.api-user`) に載せる。ヘッダ無し・不正は 401 JSON を返して打ち切る。
- `/api/*` ではセッション Cookie を認証に使わない (CSRF 免除の安全性の前提)。
- CSRF スキップ一覧と `require-real-handle` の除外一覧に `/api/` プレフィックスを追加する。
  `/api/` 以外のパスの挙動は変えない。

### トークン管理 UI (`/account`)

- 一覧 (名前・prefix・作成日時・最終使用日時)、発行 (名前入力 → 平文を一度だけ表示)、
  失効。HTMX で一覧断片を差し替える。文言は i18n カタログ (en/ja) にキーを追加。

## 3. API

すべて JSON。エラーは `{"error": {"code": "...", "message": "..."}}`。

| メソッド | パス | 内容 |
|---|---|---|
| GET | `/api/v1/me` | `{handle, display_name}` |
| GET | `/api/v1/notebooks?page=N` | `/notebooks` と同条件の一覧: `{items:[{handle, slug, title, summary}], page, total}` |
| GET | `/api/v1/notebooks/:handle/:slug` | ノートブック + 全セル |
| POST | `/api/v1/notebooks/:handle/:slug/cells/:index/run` | セル実行 + 保存 |

### ノートブック取得

`{handle, slug, title, summary, cells:[...]}`。各セル:

```
{index, cell_id, kind, body, description, test_cases:[{input, expected, description}],
 gated, unlocked, saved_code, passed}
```

- `kind` は `prose` / `code-eval` / `code-exercise` / `code-solution` / `scene`。
- gated な `code-solution` は、直前の演習に合格済み (`unlocked: true`) のときだけ
  `body` を含み、未解放なら `body: null`。判定は Web UI の描画と同じ規則。
- `saved_code` は `learn-cell-code` の保存コード (無ければ null)、`passed` は `learn-progress`。
- 閲覧権限は `access-control:can-view-notebook-p` に従う。見られないノートブックは
  存在しない場合と同じ 404。

### セル実行

リクエスト `{"codes": [string, ...]}`: セル 0..N のコード (Web の `codes[]` と同じ意味。
prose は空文字)。レスポンス:

```
{status: "ok"|"error"|"pass"|"fail", value, output, error, error_cell_index,
 tests:[{input, description, expected, actual, passed, error}],
 metrics:{steps, cons, depth}, revealed_solutions:[{index, cell_id, body}]}
```

- 実行・保存は Web と同じ共有関数: 保存コード upsert、演習なら `learn-submission`
  追記、合格なら `learn-progress` 記録。合格で解放された gated 解答を
  `revealed_solutions` で返す。
- prose / solution セル、範囲外 index、`codes` の長さ不足は 422。

### ステータスコード

401 `unauthorized` (トークン無し・無効・失効)、404 `not_found`、422 `invalid_request`、
400 `bad_json`、500 `internal` (固定文言、バックトレースは出さない)。

## 4. CLI クライアント

### 配置と配布

- `cli/recurya-cli.asd` の独立 ASDF システム `recurya-cli`。サーバ系 (Mito/Postgres 等)
  には依存しない。依存は `dexador`, `com.inuoe.jzon`, `uiop` のみ。
- エントリ: `cli/roswell/recurya.ros`。学習者は `ros install masatoi/recurya` で導入する。
- 設定: `~/.config/recurya/config.json` (`server`, `token`、パーミッション 0600)。
  既定サーバは本番。`--server` / 環境変数 `RECURYA_SERVER` で上書き。

### コマンド

| コマンド | 動作 |
|---|---|
| `recurya login [--server URL]` | トークンを入力 → `/api/v1/me` で検証 → 設定に保存 |
| `recurya list [--page N]` | ノートブック一覧 (`@handle/slug  title`) |
| `recurya pull @h/slug [DIR]` | ノートブックをローカルディレクトリに展開 (DIR 既定は slug) |
| `recurya run NN` | カレントディレクトリのノートブックのセル NN を実行・結果表示・保存 |
| `recurya status` | 各コードセルの合格状況とローカル変更の有無 |

### ローカル構成

```
sicp-1/
  README.md               prose・演習の説明・テストケースを順番に (コードは "→ 03-exercise.wl")
  01-eval.wl              コードセル (初期内容: 保存コード、無ければセル本文)
  03-exercise.wl
  04-solution.wl          解放済みの解答のみ
  .recurya/notebook.json  server, handle, slug, セルごとの index/cell_id/kind/ファイル名/pull 時ハッシュ
```

- ファイル名は `NN-<kind短縮>.wl` (`eval` / `exercise` / `solution`)、NN はセル index を
  ゼロ埋め (桁数は max(2, 最大 index の桁数) でノートブック内で揃える)。
  `scene` セルはファイルを作らず README に「CLI 非対応」と記す。`run` は `03` / `3` / ファイル名を受け付ける。
- 再 `pull`: README と manifest を更新。コードファイルは pull 時ハッシュと一致する
  (未編集) ものだけ上書きし、編集済みは残して一覧表示。`--force` で全上書き。
- `run NN`: セル 0..NN のコードを集めて送る。コードセルはローカルファイル内容
  (ファイルが無い未解放の解答は空文字)、prose は空文字。合格時は `revealed_solutions`
  を `NN-solution.wl` に書き出し、README・manifest を更新。
- 出力: ステータス (PASS/FAIL/ERROR/OK)、テストごとの表 (入力 / 期待 / 実際)、print 出力、
  エラー (エラーを出したセル番号付き)、資源使用量。
- 終了コード: 0 = pass/ok、1 = fail/error、2 = 使い方の誤り・通信失敗・認証失敗。

### エラー処理

- 401 → 「`recurya login` を実行してください」、通信失敗・5xx → 短い説明で終了コード 2。
- pull 済みディレクトリ外での `run`/`status`、ローカルファイル欠落は使い方エラー。

## 5. 検証

- **DB 層**: Rove + `with-test-db` で発行・認証・失効・last_used 更新・上限。
  cl-spec Property (既存 DB 契約と同じ方式): 平文が保存されない、発行したトークンだけが
  認証される、失効後は認証されない、他人のトークンは失効できない。
- **ミドルウェア**: Bearer で認証できる、`/api/*` で Cookie セッションだけでは 401、
  CSRF・onboarding 除外が効く、`/api/` 以外は従来どおり。
- **API ハンドラ**: テスト DB + トークンで JSON を assert。ゲーティング (合格前は解答 body
  が null、合格で `revealed_solutions`)、保存 (`learn-cell-code` / `learn-submission` /
  `learn-progress`)、Web のノートブックページ描画に同じ進捗が反映されること。
- **共有関数抽出**: 既存の notebook ルートテストが無変更で緑のまま。
- **トークン管理 UI**: ハンドラテスト + `scripts/request-test.sh` で HTMX 両側
  (`hx-target` と対応 `id`、差し替え断片)。
- **CLI**: 純粋部分 (ファイル名生成、manifest 往復、再 pull のハッシュ判定、結果整形) を
  Rove 単体テスト。dev サーバ相手に E2E: login → pull → 編集 → run (fail → pass) →
  解答ファイル出現 → Web 側 (request-test) で合格・解放を確認。
- 仕上げ: 全スイート、mallet、CI 緑。

## 6. 実装順

1. `api_token` deftable + マイグレーション + `db/api-tokens` + 契約・テスト
2. `api-token-auth` ミドルウェアと CSRF / onboarding 除外
3. セル実行・保存の共有関数抽出 (Web 振る舞い不変)
4. `/api/v1/*` ハンドラ
5. `/account` のトークン管理 UI (i18n en/ja)
6. CLI (`cli/`)
7. E2E、ドキュメント (README / `docs/DEVELOPMENT.md` / CLI の使い方)
