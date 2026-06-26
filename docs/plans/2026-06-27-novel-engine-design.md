# ノベルゲーム基盤（Notebook × wardlisp）設計

> 作成日: 2026-06-27 / ブランチ: `feat/novel-engine`
> 関連: [wardlisp 拡張要件](./2026-06-27-wardlisp-extension-requirements.md)（前提条件・別セッションで実装）

## Goal

Recurya の Notebook をエディタとして使い、**wardlisp の S 式でシーン（テキスト＋演出）を記述する**ノベルゲーム基盤を作る。シーンはプレイヤー（読者）の**フラグ（状態）を参照して wardlisp の制御構造で会話を出し分け**できる。読者ごとの進行状態はセッションを跨いで保存・再開できる。

## 用語

- **著者(author)**: Notebook を書く人。
- **読者(reader/player)**: Notebook を「再生」して読む人。著者とは限らない。
- **シーン(scene)**: 1 つの `===scene===` セル。wardlisp 式で、評価すると**演出ディレクティブのリスト（データ）**を返す。
- **ディレクティブ(directive)**: `(say …)` `(narrate …)` `(bg …)` `(set-flag …)` 等、演出の最小単位（データ）。
- **ビート(beat)**: プレイヤーがクリックで送る 1 単位（1 つの台詞/地の文）。インタプリタがディレクティブ列を平坦化して生成。
- **フラグ(flag)**: 読者ごとの状態変数（例: `met-alice` = t）。ホストが管理し、評価時に wardlisp 環境へ注入する。

## 背景（既存資産）

- **セルモデル** `game/notebook`: `cell` struct（`kind`/`body`/`description`/`test-cases`）、`notebook` = セル列。`run-cell` は code セルを前方累積で wardlisp 評価。
- **パーサ** `game/notebook-parser`: `===KIND===` フェンスで body_md ⇄ セル列を round-trip。`parse-fence-header`/`render-cell` にフェンスを足せば新セル種別を追加できる（`===solution===` 追加と同型）。
- **wardlisp 評価**: `(wardlisp:evaluate code &key fuel max-cons max-depth max-output timeout)` → `(values 結果 metrics)`。サンドボックス（fuel/cons/depth/output/timeout）。**現状は文字列型が無い**（本設計の前提条件＝別途拡張）。結果のリストは `ocons`（`wardlisp/src/types` が `ocons-p/ocons-ocar/ocons-ocdr` を公開）。
- **読者オーバーレイ** `db/learn` + `learn_*`: `(user_id, notebook_id, cell_id)` 一意で読者ごとの保存コード/進捗/提出を持ち、ログインで DB 永続・匿名は localStorage→ログイン時マージ。**「読者ごと・跨セッション」の保存基盤は既存**で、本設計はこれを「ノベルの進行状態」へ一般化する。

## 確定した設計判断（ブレインストーミングの結論）

1. **シーン DSL = wardlisp の S 式を“評価”する**（宣言データではなく実行）。理由: フラグ参照＋制御構造で会話を出し分けたいため。
2. ⇒ **wardlisp に文字列型が必要**（会話本文のため）。これは**ハード依存**で、別セッションで先行実装（要件は別ドキュメント）。
3. **実行時はシーン単位の逐次評価**（全体の事前レンダリング不可）。後のシーンは前のフラグに依存するため。
4. **フラグ注入はホスト責務**（評価前に `(define <flag> <値>)` 前置 or `evaluate` への初期束縛）。`set-flag` は**ホストが解釈するディレクティブ**で状態更新（wardlisp 評価は副作用を持たない＝純粋なまま）。
5. **結果(ocons ツリー)の走査はホスト責務**（`ocons-*` で巡回しディレクティブ→ビートへ）。
6. **MVP は「フラグ＋ wardlisp 制御構造＋ set-flag」まで**。**選択肢/ラベルジャンプ(choice/jump)は次の増分**。アセット/立ち絵/音声/演出効果はさらに後。

## スコープ

### MVP（このプランの対象）
- `===scene===` セル種別の追加（パーサ round-trip 含む）。
- シーンの逐次評価ランタイム（フラグ注入 → wardlisp 評価 → ocons 結果走査 → ディレクティブ → ビート）。
- ディレクティブ語彙: `say` / `narrate` / `bg` / `set-flag`。制御は wardlisp の `if`/`cond` 等（著者が使う）。
- プレイヤー UI: 公開ノートブックの「Play」ビューで、ビートをクリック送り表示。bg は背景プレースホルダ（名前→CSS/ラベル）。
- 読者ごとの進行状態（フラグ＋現在位置）の保存・再開（`learn_*` パターンの一般化）。

### 非ゴール（次以降の増分）
- 選択肢 `choice` / ラベル `label` / ジャンプ `jump`（プレイヤー分岐）。
- キャラ登録（id→表示名/立ち絵）、背景画像、BGM/SE、トランジション、テキストアニメ。
- セーブスロット複数、既読/オートプレイ、エンディング管理。
- 編集体験（セル分割＋CodeMirror per-cell）、ストレージのセルテーブル化（別トピックとして保留）。

## アーキテクチャ / データフロー

```
著者: ===scene=== セル(wardlisp 式テキスト) [＋ ===eval=== の共有プレリュード(任意)]
   → notebook の cell(kind=:scene, body=wardlisp テキスト) として保持（既存パイプライン）

再生(読者ごと・逐次):
  現在位置のシーンを取得
   → [プレリュード defs] + [現在フラグの (define …)] + [シーン式] を wardlisp:evaluate（サンドボックス）
   → 返り値の ocons ツリーを [結果ウォーカ] で巡回し、ディレクティブ列(プレーンな Lisp データ)へ
   → [インタプリタ] ディレクティブ列を「ビート列」へ平坦化（say/narrate=ビート, bg=状態, set-flag=保留適用)
   → [プレイヤー] ビートをクリック送り表示
   → シーン終端で set-flag を読者状態へ適用し、次シーンへ（再評価）
```

各ユニットの責務・境界:
- **結果ウォーカ** (`game/novel/value`): wardlisp 結果(ocons/文字列/数値/シンボル) → ホスト側プレーンデータ(リスト/CL文字列/整数/キーワード)。入力: wardlisp 結果。依存: `wardlisp/src/types` の ocons API（または `:wardlisp` 公開 API、要件参照）。
- **インタプリタ** (`game/novel/interpreter`): プレーンなディレクティブ木 + 現在フラグ → `(values ビート列 状態変化)`。純関数。wardlisp 非依存。
- **ランタイム** (`db/novel` + `web` ハンドラ): 読者状態(フラグ＋位置)の読み書き、シーン評価のオーケストレーション。
- **プレイヤー UI** (`web/ui/novel`): ビート列 → HTML/JS。クリック送り。

## コンポーネント詳細

### 1. `===scene===` セル種別

`game/notebook`:
- `cell` の `kind` に `:scene` を追加（列挙箇所のみ）。body は wardlisp テキスト（code セルと同様、文字列としてそのまま保持。再生時に評価）。

`game/notebook-parser`:
- `parse-fence-header` に `===scene===`（説明なし）分岐を追加 → `(values :scene nil)`。
- `render-cell` の `ecase` に `:scene` → `===scene===` を追加（round-trip）。
- `cells->body-md` / 既存の cell-id 安定化（`take-matching-cell-id`）はそのまま機能。

（MVP は説明なしの `===scene===`。将来 choice/label を入れる際に `===scene: <label>===` でラベル付きへ拡張できる余地を残す。）

### 2. プレリュードとフラグ注入

- **プレリュード（共有定義）**: 著者が `===eval===` セルにヘルパ（例: キャラ定義のための関数や定数）を書ける。再生時、ホストはノートブックの `===eval===` セル群を連結したものを**各シーン評価の前に前置**する（前方累積ではなく「共有ライブラリ」として毎回前置）。
- **フラグ注入**: ホストは現在の読者フラグを `(define <flag-name> <value>)` の列に変換し、プレリュードの直後・シーン式の直前に前置する。
  - フラグ名は wardlisp シンボル（=文字列）。値は t/nil・整数・文字列（文字列型が前提）。
  - 望ましくは `wardlisp:evaluate` が**初期束縛 alist** を受け取れると綺麗（文字列前置より安全・高速）。これは wardlisp 要件の「あると良い」項目。無ければ前置で実現。

### 3. wardlisp 評価と結果走査

- 評価対象 = `<プレリュード>\n<フラグ defines>\n<シーン式>`。`evaluate` をサンドボックス既定（`*notebook-**` 同等の fuel 等）で呼ぶ。エラーは著者向けに表示（後述）。
- 返り値（最終式の値）を**結果ウォーカ**で巡回:
  - `ocons` → リスト（`ocons-ocar`/`ocons-ocdr` を辿る。循環/深さ上限あり）。
  - wardlisp 文字列 → CL 文字列（**要 wardlisp 文字列 API**: 文字列述語＋CL文字列取り出し。要件参照）。
  - 整数 → 整数。シンボル（=CL文字列）→ ディレクティブの**タグ**やフラグ名として扱う（キーワード化）。
  - 結果として `(:say "アリス" "やあ")` のようなプレーンなディレクティブ列を得る。

### 4. ディレクティブ語彙（MVP）

シーン式の返り値は「ディレクティブのリスト」。各ディレクティブはタグ付きリスト:
- `(scene <dir>…)` — グルーピング（任意。平坦化される）。
- `(bg <文字列>)` — 背景設定（以降ビートの背景になる状態）。
- `(narrate <文字列>)` — 地の文 1 ビート。
- `(say <話者:文字列> <本文:文字列>)` — 会話 1 ビート。
- `(set-flag <flag:シンボル> [<値>])` — 読者状態を更新（既定値 t）。ビートではなく**状態変化**として収集。

著者は wardlisp の `if`/`cond`/`let`/`define`/`list`/quote 等で、フラグに応じて返すディレクティブを切り替える。例:
```lisp
;; ===scene===
(list
  (list 'bg "classroom")
  (if met-alice
      (list 'say "アリス" "また会ったね。")
      (list 'say "アリス" "はじめまして。"))
  (list 'set-flag 'met-alice))
```
（将来 `say`/`scene` 等を返す**コンストラクタ関数**をプレリュードで提供すると `(say "アリス" "…")` と書けて綺麗。MVP は素の `list`/quote でも可。）

### 5. インタプリタ（ディレクティブ → ビート）

純関数 `(interpret directives flags) → (values beats state-changes)`:
- `current-bg` を保ちつつ、`say`/`narrate` を 1 ビートずつ emit（各ビートに現在 bg を付与）。
- `bg` は `current-bg` を更新（ビートではない）。
- `set-flag` は `state-changes` に集約（シーン終端でランタイムが読者状態へ適用）。
- `scene` は再帰的に平坦化。
- 出力ビート: `{type: "say"|"narrate", speaker?, text, bg}`。

### 6. ランタイム（逐次）と位置管理

- 読者状態 = `{flags: {…}, scene-index: N}`（MVP は `===scene===` セルの**順序インデックス**で位置を表す。選択肢導入時にラベルベースへ拡張）。
- 「再生開始」: index=0、flags=初期（空 or 著者既定）。当該シーンを評価 → ビート列を返す。
- 「次へ」: 現在シーンの set-flag を適用 → index+1 のシーンを新フラグで評価。最終シーンの後は終了。
- 評価の往復は既存 HTMX パターンを流用（例: `POST .../play/advance`）。1 シーン分のビートはまとめてクライアントへ返し、シーン内のクリック送りはクライアント処理、シーン境界でサーバ往復。

### 7. 読者ごとの進行状態の永続化（`learn_*` の一般化）

- 新テーブル `novel_state`（または `learn_*` 同様の per-user オーバーレイ）: `(user_id, notebook_id) → {flags(jsonb), scene_index}`、unique `(user_id, notebook_id)`。
- ログイン読者: DB 永続・再開。匿名: localStorage に保持し、`/learn/sync` 同様の仕組みでログイン時マージ（既存の `merge-localstorage` を参考に novel 用を用意、または汎用化）。
- 「最初から/続きから」を提供。

### 8. ルート / UI

- 公開ノートブックに「Play」入口（例 `GET /@:handle/:slug/play`）。novel として再生（`===scene===` セルを対象）。
- `POST /@:handle/:slug/play/advance`（HTMX）: 現在状態から次シーンのビートを返す。
- プレイヤー UI `web/ui/novel`: 背景レイヤ＋テキストボックス（話者名＋本文）＋クリック/キー送り。Spinneret + 小さな JS。
- 既存ビューア(`web/ui/notebook`)とは別ファイル（責務分離）。

### 9. バリデーション / エラー

- シーン評価が wardlisp エラー（パース/実行）→ **著者向けエラー**として表示（プレビュー/エディタ）。読者再生中は当該シーンをスキップ＋著者にのみ警告ログ。
- 返り値が想定外（ディレクティブとして解釈不能、未知タグ、引数型不一致）→ 著者向けエラー。読者には安全な既定（スキップ/空ビート）。
- fuel 等のサンドボックス超過 → 既存メトリクス経由でエラー表示。

## wardlisp への依存（要件は別ドキュメント）

本エンジンが wardlisp に求めるもの（詳細は [wardlisp 拡張要件](./2026-06-27-wardlisp-extension-requirements.md)）:
1. **文字列型**（リテラル/評価/印字/メモリ会計/等価）— 会話本文。
2. **最小の文字列操作**（動的テキスト用: `string-append`, `number->string` 等）。
3. **公開の値内省 API**（`ocons-p/ocar/ocdr`、文字列述語＋CL文字列取り出し、シンボル/数値述語）を `:wardlisp` から — 結果走査のため。
4. （あると良い）`evaluate` の**初期束縛**引数 — フラグ注入を文字列前置でなく直接行うため。

MVP の実装順序上、wardlisp 拡張が**先**に必要。ただし wardlisp 非依存で先行できる部分（`===scene===` パーサ、インタプリタの純関数、プレイヤー UI 雛形）もあり、プランで段階を分ける。

## テスト戦略

- **パーサ**: `===scene===` の round-trip、cell-id 安定化。
- **結果ウォーカ**: wardlisp 結果(ocons/文字列/数値/シンボル) → プレーンデータ（文字列型が入った後に実施）。
- **インタプリタ**（wardlisp 非依存・純関数）: ディレクティブ木 → ビート列、bg 状態、set-flag 収集、フラグ条件での出し分け。
- **ランタイム**（DB）: 読者状態の保存/再開、逐次評価、匿名→ログインのマージ。
- **プレイヤー**: スモーク（ビート列→DOM、クリック送り）。
- **統合**: 小さなサンプル novel（2〜3 シーン、フラグ条件 1 つ）が最初から最後まで通る。

## 段階化（フェーズ）

1. **P1（wardlisp 非依存で先行可）**: `===scene===` パーサ＋ round-trip、ディレクティブ→ビートのインタプリタ（プレーンデータ入力）、プレイヤー UI 雛形（固定ビート列で表示）。
2. **P2（wardlisp 文字列・依存）**: 結果ウォーカ、シーン評価（プレリュード＋フラグ注入＋ evaluate）、読者状態テーブルと逐次ランタイム、Play ルート。フラグ＋ wardlisp 制御＋ set-flag が通る。
3. **次増分（本プラン外）**: `choice`/`label`/`jump`、キャラ/アセット/音声、セーブスロット等。

## リスク / 留意

- **wardlisp 依存のタイミング**: P2 は wardlisp 文字列拡張の完了が前提。P1 を先行し、wardlisp 完了後に P2。
- **結果走査の安全性**: ocons ツリーの深さ/サイズ上限を設け、巨大/循環結果に備える（wardlisp 側 max-cons でも一次防御）。
- **状態モデルの将来拡張**: MVP は scene-index ベース。choice 導入時にラベルベースへ移行が要る（位置表現の変更点として明記）。
- **混在ノートブック**: `===scene===` と `===eval===`/`===exercise===` が同居しうる。Play は scene を対象、eval はプレリュード扱い、exercise は無視（学習ノートとノベルの併存ルールを実装時に確定）。

## 未解決の小さな論点（実装時に確定）

- プレリュード対象を「全 `===eval===` セル」とするか、専用フェンス（例 `===prelude===`）にするか。MVP は前者で開始、必要なら専用化。
- フラグの初期値/宣言（著者が初期フラグを宣言する手段）。MVP は「未定義フラグは nil 相当」で開始。
- コンストラクタ関数プレリュード（`say`/`scene` 等）を標準提供するか。MVP は素の `list`/quote、ergonomics 改善は後。
