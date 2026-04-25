# Learn Account Sync 設計(匿名 + 任意ログイン)

- 日付: 2026-04-25
- 対象: recurya / SICP ノートブック学習コース
- スコープ: ログインユーザに対して進捗・コード・提出履歴を DB に永続化する。匿名運用の既存挙動は維持しつつ、ログイン時に自動同期する任意機能として実装。

## 背景

`feat/sicp-notebook-mvp` で SICP ノートブック学習コースが完成。MVP では「匿名 + localStorage」を選び、進捗保存はブラウザ内に閉じていた。複数デバイス・長期保管・履歴振り返りのニーズが出たため、既存の `web/auth.lisp` を活用してログインユーザにのみ DB 永続化を提供する。

## 確定要件(ブレインストーミングで合意)

| 項目 | 決定 |
|------|-----|
| デフォルト動作 | 匿名(localStorage)を維持 — 既存挙動を壊さない |
| ログイン後に保存するもの | (a) 各セルの合格状態 (b) 各演習セルで最後に Run したコード (c) 演習セルの提出履歴(コード+結果+時刻) |
| 履歴の対象 | `:code-exercise` セルのみ。`code-eval`/`prose` の Run は履歴対象外 |
| 書き込みタイミング | 毎 Run 即時(ハンドラ内で session を見て書く) |
| マージ規則(初回ログイン時) | 自動。passed は OR、code は **DB 優先(DB に行があれば触らない)** |
| 別デバイスでの初期表示 | DB の最新コードをサーバ側で textarea に埋め込み |
| 認証 UI | 既存 `web/auth.lisp` + `/login`/`/signup` をそのまま利用 |
| ログアウト時の localStorage | 消さない(MVP) |

## 非スコープ(MVP で **やらない**)

- 履歴閲覧 UI(履歴は DB に蓄積するが UI は別タスク)
- ローカル進捗のエクスポート/インポート
- 進捗のサーバ側削除エンドポイント
- ログアウト時の localStorage 自動削除
- 複数アカウント切替時の分離
- 履歴エントリ数の上限制御
- ログイン強制リダイレクト
- 論理削除フラグ
- per-cell timestamp による厳密な「新しい方優先」コードマージ(退化規則: DB 優先)

## アーキテクチャ概要

```
recurya/
├── models/
│   ├── learn-progress.lisp           [NEW] 合格状態(deftable)
│   ├── learn-cell-code.lisp          [NEW] 最新コード(deftable)
│   └── learn-submission.lisp         [NEW] 提出履歴(deftable)
├── db/
│   └── learn.lisp                    [NEW] CRUD + マージロジック
├── web/
│   ├── routes-wardlisp.lisp          [EDIT] /sync 追加、既存 2 ハンドラ拡張
│   └── ui/notebook.lisp              [EDIT] DB コードを初期値、ユーザバナー、SSR 合格バッジ
│   └── ui/learn-home.lisp            [EDIT] N/M 完了バッジ、ユーザバナー
├── resources/
│   ├── migrations/                   [NEW] 3 テーブルの create migration
│   └── static/js/learn.js            [EDIT] ログイン検知 + 自動 sync
└── recurya.asd                       [EDIT] 新モジュール登録
```

### 主要フロー

**ログイン後の Run**:

```
[ブラウザ] Run クリック → POST /wardlisp/learn/:id/cells/:n/run (cookie 付き)
[Ningle]   notebook-cell-run-handler
   ├─ run-cell で評価 → result(既存)
   ├─ session.user-id があれば DB 書き込み:
   │    upsert learn-cell-code (user, notebook, cell, code)        [code セル全般]
   │    insert learn-progress  (user, notebook, cell, passed-at)   [:pass のみ]
   │    insert learn-submission (user, notebook, cell, code, status)[:code-exercise のみ]
   └─ HTML fragment + HX-Trigger を返す(既存)
```

**ログイン後のページロード**:

```
GET /wardlisp/learn/:id (cookie あり)
   ├─ session.user-id を取得
   ├─ DB から learn-cell-code, learn-progress を取得
   └─ render に渡す → 各演習セル textarea を DB コードで初期値、合格バッジを SSR
```

**匿名 → ログイン直後の同期**:

```
ログイン後の最初の /wardlisp/learn ページロードで:
   ├─ JS が body.dataset.loggedIn === 'true' かつ localStorage 残存 を検知
   ├─ POST /wardlisp/learn/sync { notebooks: [...] }
   ├─ サーバ側でマージ(passed は OR、code は DB 優先で挿入のみ)
   └─ 成功時 JS が localStorage の 'recurya:learn:v1' を削除
```

## データモデル

### `models/learn-progress.lisp` — 合格状態

```lisp
(deftable learn-progress ()
  ((user-id :col-type :uuid)
   (notebook-id :col-type (:varchar 64))
   (cell-id :col-type (:varchar 64))
   (passed-at :col-type :timestamptz))
  (:unique-keys (user-id notebook-id cell-id))
  (:keys (user-id notebook-id)))
```

- `user-id` 型を `:uuid` に変更(既存 `users` テーブルが UUID PK のため)
- 行が存在する = 合格済み
- 同じセルを再度合格させても upsert(初回 `passed-at` で固定、`INSERT IGNORE` 相当)

### `models/learn-cell-code.lisp` — 最新コード

```lisp
(deftable learn-cell-code ()
  ((user-id :col-type :uuid)
   (notebook-id :col-type (:varchar 64))
   (cell-id :col-type (:varchar 64))
   (code :col-type :text))
  (:unique-keys (user-id notebook-id cell-id))
  (:keys (user-id notebook-id)))
```

- Mito の `created-at`/`updated-at` で時刻管理
- 1 ユーザ × 1 セルにつき 1 行(upsert)
- `code-eval` セルでも保存(再訪時の復元用)

### `models/learn-submission.lisp` — 提出履歴

```lisp
(deftable learn-submission ()
  ((user-id :col-type :uuid)
   (notebook-id :col-type (:varchar 64))
   (cell-id :col-type (:varchar 64))
   (code :col-type :text)
   (status :col-type (:varchar 16)))
  (:keys (user-id notebook-id cell-id)))
```

- `:code-exercise` セルの Run のみ insert(append-only)
- `status` は `"pass"` / `"fail"` / `"error"`
- `created-at` が提出時刻

### マイグレーション

- `.qlot/bin/mito generate-migrations` で 3 テーブル create を生成
- Foreign key 制約は付けない(既存 `posts` テーブルと同方針)

## DB アクセス層 `db/learn.lisp`

### 公開 API

```lisp
;; progress
(mark-cell-passed user-id nb-id cell-id)        ; → progress-row(初回のみ insert)
(user-passed-cells user-id nb-id)               ; → list of cell-id strings

;; cell code
(upsert-cell-code user-id nb-id cell-id code)   ; → row
(user-cell-codes user-id nb-id)                  ; → alist (cell-id . code)

;; submissions
(record-submission user-id nb-id cell-id code status) ; → row
(cell-submissions user-id nb-id cell-id &key (limit 50)) ; → list

;; sync
(merge-localstorage user-id payload)             ; → summary plist
```

### `merge-localstorage` の規則

入力: `((:notebook-id "..." :passed (...) :codes (alist)) ...)`

1. 各 notebook について:
   - `passed` の各 cell-id → `mark-cell-passed`(既存なら no-op)
   - `codes` の各 (cell-id . code) → DB に既存行**がない場合のみ** insert(DB 優先)
2. 集計 `(:passed-merged N :codes-merged M :codes-skipped K)` を返す

トランザクションは MVP では張らない(部分失敗は再試行で吸収)。

## ハンドラとルート

### 既存ハンドラの拡張

**`notebook-cell-run-handler`**: run-cell 実行後、session.user-id があれば

- code セル全般 → `upsert-cell-code`
- `:pass` && `:code-exercise` → `mark-cell-passed`
- `:code-exercise` → `record-submission`(常に)

DB 書き込みは `handler-case` で包み、エラーは log のみ(Run の HTML 応答は壊さない)。

**`notebook-page-handler`**: session.user-id があれば `user-cell-codes` と `user-passed-cells` を取得し、`render` の新キーワード引数に渡す。

**`learn-home-handler`**: session.user-id があれば各 notebook の `user-passed-cells` を集めて N/M 表示用に `render` に渡す。

### 新規ハンドラ `learn-sync-handler`

```
POST /wardlisp/learn/sync   Content-Type: application/json   Auth: required (401 if not)
Body: { "notebooks": [{ "notebook_id": "...", "passed": [...], "codes": {cell: code} }, ...] }
Response: 200 + { passed_merged, codes_merged, codes_skipped }
```

JSON は `com.inuoe.jzon`(既存依存)で parse/serialize。

### ルート登録

`setup-wardlisp-routes` に `/wardlisp/learn/sync` (POST) を追加。

## UI と JS

### `web/ui/notebook.lisp`

- `render (notebook &key user saved-codes passed-cells)` にシグネチャ拡張
- 動的特殊変数 `*saved-codes*` `*passed-cells*` `*user*` で render-cell に伝播
- `render-code-cell`: `(or (assoc cell-id saved-codes) (cell-body cell))` で初期値
- `:code-exercise` で `passed-cells` に含まれるセルは SSR で `<span class="badge-pass">✓ done</span>` 出力
- 上部に user-banner: ログイン中ならユーザ名 + ログアウトリンク、匿名なら「ログインで端末超え保存」案内

### `web/ui/learn-home.lisp`

- `render` に `:user :passed-counts` 追加
- 各 nb-card に `~D/~D 完了` バッジ(SSR)
- user-banner も同様

### `resources/static/js/learn.js`

新スキーマの localStorage:

```json
{
  "sicp-1-1-1": {
    "passed": ["ex-sum3"],
    "codes": {"ex-sum3": "(+ 137 349 22)"},
    "last_visited_at": "..."
  }
}
```

挙動分岐:

| body.dataset.loggedIn | localStorage `recurya:learn:v1` | 動作 |
|--|--|--|
| `false` | あり | 既存どおり読み書き、JS でバッジ後付け |
| `false` | なし | 既存どおり |
| `true` | あり | sync POST を試行 → 成功なら `removeItem` |
| `true` | なし | localStorage は読み書きしない |

ログイン時はバッジは SSR 済みなので JS の post-load マーキングは無効化。

Run 成功時(任意 status)の `htmx:afterRequest` で textarea 値を読み、匿名なら `codes` に保存(ログイン時はサーバ側保存)。

## テスト戦略

### DB テスト `tests/db/learn.lisp`(新規)

- `mark-cell-passed` の冪等性
- `user-passed-cells` の取得
- `upsert-cell-code` の insert/update 切替と `updated-at` 進行
- `user-cell-codes` の alist 形
- `record-submission` の append-only
- `cell-submissions` の order
- `merge-localstorage`: passed の OR、code 既存保護、code 新規 insert

`tests/support/db.lisp` の `with-test-db` を使い、テスト前に該当テーブル truncate。

### ルートテスト `tests/web/learn-routes.lisp`(拡張)

- 匿名 Run で DB 書き込みなし
- ログイン Run で `learn-cell-code` insert
- exercise の `:pass` で `learn-progress` insert
- exercise Run で `learn-submission` 積み上がり
- ページロードで DB コードが textarea 初期値
- 合格セルに `badge-pass` が SSR 出力
- `/sync` で 3 テーブル更新
- `/sync` 未ログインで 401

### 単体テスト

`tests/game/notebook.lisp` は既存。run-cell 自体は無変更のためテスト追加なし。

## 実装順序

1. モデル 3 つ + ASDF 登録
2. マイグレーション生成 + 適用 + テーブル存在確認
3. `db/learn.lisp` 単体実装(TDD)
4. `merge-localstorage` 実装(TDD)
5. `notebook-cell-run-handler` 拡張(認証時の DB 書き込み)
6. `notebook-page-handler` 拡張(DB コードを textarea 初期値)
7. UI 仕上げ(ユーザバナー + SSR 合格バッジ)
8. `/sync` ハンドラ + ルート登録
9. `learn.js` 拡張(codes 保存 + sync POST)
10. `learn-home-handler` 拡張(N/M バッジ)
11. 手動 E2E(匿名 → 進捗作成 → ログイン → 自動 sync → 別デバイス再現)

## リスクと緩和

| リスク | 緩和 |
|------|----|
| Mito の upsert API が直接ない | `select-dao` で existing 取得 → save-dao or insert-dao(既存 db/* と同じパターン) |
| 同時 2 タブの Run で upsert 競合 | ユニーク制約で守られる。両方 insert なら片方は handler-case で吸収 |
| sync 失敗で進捗喪失 | 失敗時は localStorage を消さない → 次回ロードで自動再試行 |
| マイグレーション漏れ | DB テストが CI で通れば schema 存在の証拠 |
| 同一ブラウザでアカウント切替 | MVP 範囲外として明記。次の sync で前ユーザの進捗が新ユーザに紛れる可能性あり |
| 履歴の無制限蓄積 | MVP では制限なし。将来必要なら append 時の上限実装 |
