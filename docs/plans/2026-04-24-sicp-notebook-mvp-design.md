# SICP ノートブック学習コース MVP 設計

- 日付: 2026-04-24
- 対象: recurya(Lisp 学習ゲーム Web サイト)
- スコープ: SICP の内容を WardLisp で学べる「ノートブック型」学習コースの最小実装

## 背景と目的

recurya には既に WardLisp の学習機能として以下が揃っている:

- `/wardlisp/puzzle/*` — 関数を書かせてテストケースで採点する単発演習(6 問)
- `/wardlisp/arena` — ゲーム盤面シミュレータ(AI を書かせる)
- `/wardlisp/playground` — 自由評価
- `/wardlisp/reference` — 言語リファレンス

この設計では、これらと並立する**ノートブック型**(説明文と問題が混在する縦方向のページ)を新たに追加し、SICP(Structure and Interpretation of Computer Programs)の内容を Scheme から WardLisp に置き換えて学べるようにする。

本 MVP の目的は、コース体験と実装構造のプロトタイプを最小限のコンテンツ(SICP 1.1.1〜1.1.3)で検証することである。

## 確定した要件

| 項目 | 決定 |
|------|-----|
| サイトの位置づけ | 公開学習サイト |
| コース型の種類 | ノートブック型のみ(MVP) |
| 他の既存型(Puzzle / Arena 等) | 触らない。独立して共存 |
| ノートブックの構造 | Jupyter 風のセル列。セル間で状態共有あり |
| セル間状態共有方式 | 再評価方式(サーバステートレス)。Run 時にそのセルまでのコードを連結して 1 回 `wardlisp:evaluate` |
| 学習管理 | 匿名。進捗は localStorage のみ。サーバには保存しない |
| コンテンツ定義 | Lisp ソース(既存 Puzzle と同じ流儀) |
| 演習セルの採点 | セルごとに選択可能(`test-case` を付けたセルだけ採点) |
| MVP コンテンツ範囲 | SICP 1.1.1〜1.1.3(3 ノートブック) |

## 非スコープ(MVP で **やらない**)

- Puzzle struct の変更 / 既存 URL への動線追加(`/wardlisp/` ホームはいっさい触らない)
- UI の共通化リファクタリング(`web/ui/puzzle.lisp` と `web/ui/notebook.lisp` の重複は当面許容)
- SICP 1.1.4 以降、1.2 節以降のコンテンツ
- Mito モデル追加、認証との統合、クロスデバイス同期
- 可視化型・クイズ型など別ノートブック種別
- セル単位のリセットエンドポイント(ページリロード/Ctrl+Z で代替)

## アーキテクチャ概要

既存の `game/puzzle.lisp` + `game/puzzles/` + `web/ui/puzzle.lisp` + `web/routes-wardlisp.lisp` の構造を鏡像にしたサブシステムを追加する。既存コードへの編集は `routes-wardlisp.lisp` と `recurya.asd` のみ(追記のみ)。

```
recurya/
├── game/
│   ├── notebook.lisp             [NEW] notebook/cell struct + run-cell
│   └── notebooks/
│       ├── sicp-1-1-1.lisp       [NEW] SICP 1.1.1 式
│       ├── sicp-1-1-2.lisp       [NEW] SICP 1.1.2 命名と環境
│       ├── sicp-1-1-3.lisp       [NEW] SICP 1.1.3 演算子の組合せ評価
│       └── registry.lisp         [NEW] 全ノートブック列挙
├── web/
│   ├── ui/
│   │   ├── learn-home.lisp       [NEW] コース一覧ページ
│   │   └── notebook.lisp         [NEW] ノートブック表示ページ + セル結果 HTMX fragment
│   └── routes-wardlisp.lisp      [EDIT] ルート 3 本追加(既存ハンドラは変更しない)
├── resources/
│   └── static/
│       └── js/
│           └── learn.js          [NEW] localStorage 進捗管理(~50 行)
└── recurya.asd                   [EDIT] ASDF 依存関係追記
```

### 処理の流れ(セル実行時)

```
[ブラウザ] ユーザがセル N の "Run" を押す
    │ HTMX POST /wardlisp/learn/:id/cells/:n/run
    │ form body: codes[] に全コードセルのコード文字列
    ▼
[Ningle] notebook-cell-run-handler
    │ notebooks/registry からノートブック取得
    │ index 以降の codes は捨て、1..N のみ使用
    │ セル kind により分岐
    ▼
[WardLisp] wardlisp:evaluate(連結コードを 1 回で)
    │ 演習セルなら各 test-case ごとに追加評価
    │ fuel/cons/timeout/max-depth は *notebook-*定数で共有
    ▼
[サーバ] notebook-cell-result → HTMX fragment を返す
    │ :pass なら HX-Trigger: cell-passed を付与
    ▼
[ブラウザ] 結果パネル書き換え → learn.js が localStorage 更新 + バッジ表示
```

## データモデル

既存 `game/puzzle.lisp` と同じ流儀(`defstruct` + 純関数コンストラクタ)で定義する。

```lisp
;; game/notebook.lisp

(defstruct notebook
  id           ; keyword, e.g. :sicp-1-1-1
  chapter      ; string, e.g. "1.1.1"
  title        ; string, e.g. "式"
  summary      ; string, 一覧表示用の短い要約
  cells)       ; list of cell structs(上から順に評価)

(defstruct cell
  id           ; keyword, ノートブック内で一意(localStorage キー)
  kind         ; :prose | :code-eval | :code-exercise
  body         ; prose: spinneret DSL(list)または plain string
               ; code-*: 初期コード(string)
  description  ; code-exercise のみ: 演習文
  test-cases)  ; code-exercise のみ: list of recurya/game/puzzle:test-case
```

### セル 3 種の挙動

| kind | UI | Run ボタン | 採点 | 進捗記録 |
|------|-----|-----------|------|---------|
| `:prose` | Spinneret 描画のみ | なし | なし | なし |
| `:code-eval` | CodeMirror + Run | あり | なし(評価値と print 出力を表示) | なし |
| `:code-exercise` | CodeMirror + 問題文 + Run | あり | `test-cases` で採点 | `:pass` 時のみ localStorage に記録 |

`test-case` は既存 `game/puzzle.lisp` の構造体をそのまま import して再利用する。ノートブック側で新しく定義しない。

### 結果構造体

```lisp
(defstruct notebook-cell-result
  cell-id        ; keyword
  kind           ; :code-eval | :code-exercise
  status         ; :ok | :error | :pass | :fail | :limit-exceeded
  value          ; wardlisp:print-value の結果(末尾式)
  print-output   ; stdout キャプチャ
  error-message  ; :error / :limit-exceeded 時のみ
  metrics        ; wardlisp:evaluate が返すメトリクス plist
  test-results)  ; exercise セルのみ: list of test-result
```

## 評価・採点フロー

```lisp
(defparameter *notebook-fuel*       20000)
(defparameter *notebook-max-cons*   10000)
(defparameter *notebook-max-depth*  200)
(defparameter *notebook-max-output* 4096)
(defparameter *notebook-timeout*    5)
```

- `run-cell (notebook cell-index submitted-codes)` が新設する中心関数
- `submitted-codes` はクライアントから送られたコードセルの文字列リスト(cell-index 以降は捨てる)
- セル 0..cell-index までを `#\Newline` で連結して `wardlisp:evaluate` を 1 回呼ぶ
- 演習セルの採点は、連結コードの末尾に各 `test-case.input` を追記してさらに 1 回ずつ evaluate し、`print-value` を `expected` 文字列と比較(既存 `run-puzzle` と同じ手法)
- fuel/cons/timeout は各 evaluate 呼び出しに独立して `*notebook-*` 定数を与える

### リクエスト / レスポンス

- **Request (form data)**: `codes[]` × N(上流 + 対象セルの現在コード)。cell-index はパスパラメータ
- **Response**: HTMX fragment(結果パネル 1 枚分)
  - `:pass` のとき HTTP ヘッダ `HX-Trigger: {"cell-passed": {"notebook": "sicp-1-1-1", "cell": "ex-nested"}}`

### バリデーション

- `cell-index` 範囲外 → 400
- `codes` 長さが `cell-index + 1` 未満 → 400
- セル kind が `:prose` → 404(Run 不可)
- 1 セルの codes 要素長が 4 KiB 超 → HTMX fragment でエラー表示

## URL / ルーティング

既存 `/wardlisp/` ホームには**リンクを張らない**。`/wardlisp/learn` は独立エントリ。

| Method | Path | Handler(新設) | 返却 |
|--------|------|--------------|------|
| GET | `/wardlisp/learn` | `learn-home-handler` | コース一覧 HTML |
| GET | `/wardlisp/learn/:id` | `notebook-page-handler` | ノートブックページ HTML |
| POST | `/wardlisp/learn/:id/cells/:index/run` | `notebook-cell-run-handler` | HTMX fragment |

- `:id` は既存 `puzzle-page-handler` と同じく Ningle のキーワード化ルーティングでノートブック ID として受け取る
- `:index` は文字列パース(ゼロ始まり)
- `routes-wardlisp.lisp` の `setup-wardlisp-routes` に `setf` 3 行を追加。既存 `make-dynamic-handler` パターンを踏襲しホットリロード対応

## UI / HTMX

### コース一覧(`GET /wardlisp/learn`)

- 既存 `web/ui/wardlisp-home.lisp`(Puzzle 一覧)と同じカードレイアウト
- カード要素: 章番号 + タイトル + 要約 + セル数バッジ + 完了バッジ(JS が localStorage を見て後付け)
- 注記: 「進捗はこのブラウザ内にのみ保存されます」

### ノートブックページ(`GET /wardlisp/learn/:id`)

- パンくず: `WardLisp > SICPコース > 1.1.1 式`
- セル列を上から描画
  - `:prose` は背景の淡い区別のみ
  - `:code-eval` は CodeMirror + Run + 結果パネル
  - `:code-exercise` は黄色ボーダーの問題文 + CodeMirror + Run + テスト結果パネル + 合格バッジ(JS 後付け)
- ページ下部に「次のセクションへ →」リンク(MVP は hardcoded な次 ID)
- CodeMirror は既存 `web/ui/editor.lisp` の共有コンポーネントをそのまま使う

### セルの HTMX 動作

```html
<form hx-post="/wardlisp/learn/sicp-1-1-1/cells/3/run"
      hx-target="#cell-3-result"
      hx-include=".notebook-code"
      hx-swap="innerHTML">
  ...
</form>
```

- 各 CodeMirror は `<textarea class="notebook-code" name="codes[]">` と同期(既存 editor.lisp がすでにこの流儀)
- `hx-include=".notebook-code"` で全コードセルを同梱。サーバ側で `cell-index + 1` 個より後ろは捨てる
- 成功時は `HX-Trigger: cell-passed` を返し、`learn.js` が localStorage 更新 + バッジ表示

### スタイル

- 既存 `web/ui/puzzle.lisp` の配色(`#0f172a` 背景、`#1e293b` カード 等)を踏襲
- `web/ui/notebook.lisp` の `*styles*` はそのページ専用のルールだけ含める

## 進捗(localStorage)

- キー: `recurya:learn:v1`(スキーマ変更に備えてバージョン付き)
- 値(JSON):

```json
{
  "sicp-1-1-1": {
    "passed": ["ex-nested", "ex-square"],
    "last_visited_at": "2026-04-24T10:15:00Z"
  }
}
```

### クライアント JS(`resources/static/js/learn.js`)

約 50 行。以下の 3 関数:

- `markCompletedCells(notebookId)` — ページロード時に localStorage を読み、合格済みセルにバッジを付与
- `onCellPassed(event)` — HTMX の `cell-passed` カスタムイベント受信、localStorage 更新 + バッジ即時表示
- `updateProgress(notebookId, cellId)` — localStorage の JSON を読み書き

`layout.lisp` は変更せず、`web/ui/notebook.lisp` と `web/ui/learn-home.lisp` からのみ `<script src>` で読む。

### サーバ側責務

- 完全ステートレス
- `HX-Trigger` ヘッダを返すだけ(採点が `:pass` のとき)
- JS 無効環境でもページは動く(採点結果は見える、進捗だけ記録されない)

### プライバシー

- localStorage はドメイン内に留まり、サーバ送信ゼロ
- プライベートブラウジングでは消える前提を UI に明記

## SICP コンテンツ(MVP)

原典の構成に寄せ、WardLisp 方言の差分はそのページ内で注記する。

### `sicp-1-1-1.lisp` — 1.1.1 式

| # | kind | 内容 |
|---|------|-----|
| 1 | prose | 導入: Lisp の式とは |
| 2 | code-eval | `486`(数値リテラル) |
| 3 | prose | プレフィックス記法 |
| 4 | code-eval | `(+ 137 349)` |
| 5 | code-eval | `(- 1000 334)` / `(* 5 99)` / `(/ 10 5)` |
| 6 | prose | 入れ子の式 |
| 7 | code-eval | `(+ (* 3 5) (- 10 6))` |
| 8 | code-exercise | 137, 349, 22 を足す式を書く(期待値 508) |

### `sicp-1-1-2.lisp` — 1.1.2 命名と環境

| # | kind | 内容 |
|---|------|-----|
| 1 | prose | `define` の導入 |
| 2 | code-eval | `(define size 2)` + `(* 5 size)` |
| 3 | prose | 環境 |
| 4 | code-exercise | 半径 10 の円の面積(`3.14 * 100`) |
| 5 | code-exercise | 半径 2 の球体体積(expected は WardLisp の `print-value` に合わせる) |

### `sicp-1-1-3.lisp` — 1.1.3 演算子の組合せ評価

| # | kind | 内容 |
|---|------|-----|
| 1 | prose | 組合せの評価ルール |
| 2 | code-eval | `(+ (* 2 (+ 4 6)) (* 3 5 7))` |
| 3 | prose | 評価木(テキスト/ASCII アート) |
| 4 | code-exercise | `(a + b*c) / (d - e)` を a=2 b=3 c=4 d=10 e=5 で計算 |

### 実装フェーズ先頭のスパイクで検証する点

- WardLisp の `define` 構文形(`(define name value)` / `(define (f x) ...)` の両対応状況)
- 数値の型表示(特に整数除算)。`test-case.expected` は `wardlisp:print-value` の文字列そのまま
- 既存 `game/puzzles/sqrt2-newton.lisp` と `game/puzzles/registry.lisp` を参考の起点とする

## ASDF 変更

`recurya.asd` の `recurya` 依存関係に追記:

```
"recurya/game/notebook"
"recurya/game/notebooks/sicp-1-1-1"
"recurya/game/notebooks/sicp-1-1-2"
"recurya/game/notebooks/sicp-1-1-3"
"recurya/game/notebooks/registry"
"recurya/web/ui/learn-home"
"recurya/web/ui/notebook"
```

`recurya/tests` にも同様に注記のテスト 3 系統を追記。

## テスト戦略

DB 不要。既存 `utils/common` や `game/puzzle` テストと同じ流儀で動く。

### `tests/game/notebook.lisp`(新設)

- `run-cell` 単体
  - 連結評価が期待通り動く
  - `:prose` セルは Run 不可(エラー)
  - `test-case` 合否判定
  - fuel 超過時の `:limit-exceeded` 返却
- 演習セルが直前セルの `define` を参照(状態共有の検証)

### `tests/game/notebooks/sicp-1-1-1.lisp`(新設)

- ノートブック定義のスモーク
  - セル ID が一意
  - 各 `code-exercise` の模範解答(テスト内にハードコード)で全 test-case が pass

### `tests/web/learn-routes.lisp`(新設 — 既存 `tests/web/routes.lisp` に**追記しない**)

- `GET /wardlisp/learn` が 200 を返す
- `POST /wardlisp/learn/:id/cells/:n/run` が HTMX fragment を返す
- エラーケース: index 範囲外 / codes 長さ不一致 / prose セルへの Run

`recurya/tests` システム定義に以下を追記:

```
"recurya/tests/game/notebook"
"recurya/tests/game/notebooks/sicp-1-1-1"
"recurya/tests/web/learn-routes"
```

## エラー処理と UX 境界

- WardLisp 実行時例外 → `error-message` を赤ブロック表示(既存 Puzzle と同じ)
- fuel/cons/depth/output 超過 → `:limit-exceeded` + 「実行上限に達しました(fuel=XXXX)」
- 不正リクエスト(codes 長さ不一致 等)→ 400 + HTMX fragment でエラー表示
- サーバ内部例外 → 既存 Lack middleware の backtrace(本番は非表示)

## リスクと緩和

| リスク | 影響 | 緩和 |
|-------|------|-----|
| 再評価方式のコード量増加で遅くなる | レスポンスタイム | MVP では SICP 1.1 節範囲で問題なし。将来必要になれば差分キャッシュを追加 |
| `test-case.expected` が WardLisp `print-value` の表記差で fail する | コンテンツ不具合 | 実装スパイクで各式の `print-value` 実物を見てから expected を埋める |
| クライアント側で codes[] の順序がずれる | 採点誤動作 | form 内の `<textarea>` を DOM 順で送るのは HTMX のデフォルト。順序はサーバが信頼せず、index で切り詰めるのみ |
| localStorage スキーマの将来変更 | 進捗消失 | キー名に `v1` を含める。v2 で読む側で移行処理 |

## 実装順序の方針(詳細は writing-plans で)

1. スパイク: WardLisp で `define` / 整数除算の `print-value` を実物確認
2. `game/notebook.lisp` とテストを先に(TDD)
3. 最小ノートブック 1 本(`sicp-1-1-1`)+ registry + UI 2 ページ + ルート
4. 実機で動作確認後、`sicp-1-1-2` と `sicp-1-1-3` を追加
5. `learn.js` + localStorage 連携を最後に(サーバ単体で動く状態を先に作る)
6. `tests/web/learn-routes.lisp` で回帰カバレッジ
