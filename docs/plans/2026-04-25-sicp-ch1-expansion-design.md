# SICP 第1章拡張 設計

- 日付: 2026-04-25
- 対象: recurya / WardLisp 学習コース
- スコープ: SICP Chapter 1 を完全網羅(全 22 節中、現在 3 節 → 22 節へ +19 節)

## ゴール

SICP 第 1 章「Building Abstractions with Procedures」を WardLisp で学べるノートブック 19 本を追加する。既存の 3 本(1.1.1〜1.1.3)と同じテンプレート(`game/notebooks/registry.lisp` に登録、`make-cell` でセル列を構成、`code-exercise` セルは `make-test-case` で採点)。

## 確定事項

- 既存ノートブック型のまま、純粋なコンテンツ追加(フレームワーク変更なし)
- 言語: 日本語のプロセル/演習文 + WardLisp コード
- スパイク済 WardLisp 機能を前提に、原典 SICP の Scheme コードを WardLisp に変換

## WardLisp 方言ガイドライン(全ノートブックで統一)

スパイクで確認済みの方言差を、必要な節で簡潔に注記:

| Scheme | WardLisp |
|---|---|
| `#t` / `#f` | `t` / `nil` |
| `(else ...)` | `(t ...)`(cond の最終句) |
| `remainder` | `mod`(WardLisp の `mod` は SICP 例と同じ正の余りで動作) |
| `set!` | **存在しない**(WardLisp は純関数)。Ch1 範囲では使用箇所なし |
| `#?` (Scheme 真偽値) | `t`/`nil` を真偽値として扱う(SICP の Ch1 例ではほぼ問題なし) |
| `even?` / `odd?` / `pair?` | 必要な箇所で `(define (even? n) (= (mod n 2) 0))` 等を直前に定義 |
| `random` | **存在しない**。1.2.6 の Fermat テストは prose-only で「random 未対応のため概念のみ」と注記 |

ノートブックの prose セルの最初に「WardLisp の差分(該当箇所のみ)」を簡潔に書く方針。

## ノートブック一覧と要点

### 1.1 The Elements of Programming(残り 5 節)

#### `sicp-1-1-4` 複合手続き(Compound Procedures)
- `(define (f x) ...)` で関数を作り、合成する
- 演習: `square`、`sum-of-squares`、`f(a) = a(1+a) + (1-a)` の類問

#### `sicp-1-1-5` 置換モデル(Substitution Model)
- prose 中心。式の評価を数式の置き換えで表現
- 演習: 適用順 vs 通常順の評価過程を観察するテキスト演習(コード少なめ)

#### `sicp-1-1-6` 条件式と述語(Conditional Expressions and Predicates)
- `if`、`cond`、`and/or/not`
- **WardLisp 注記**: `(t ...)` を else 代替に / 真偽値は `t`/`nil`
- 演習: `abs`、`>=` を `<` で再定義、3つの大きい方2つの和

#### `sicp-1-1-7` Newton 法による平方根
- 既存の `sqrt2-newton` パズルの原典版を体系的に展開
- `sqrt-iter`、`improve`、`good-enough?`
- 演習: `cube-root` の Newton 法、収束判定の改善

#### `sicp-1-1-8` ブラックボックス抽象化
- 内部 `define`、レキシカルスコープ、ローカル名
- 演習: `sqrt` を `square`/`improve`/`good-enough?` を内部に閉じ込める形にリファクタ

### 1.2 Procedures and the Processes They Generate(全 6 節)

#### `sicp-1-2-1` 線形再帰と反復
- 階乗の再帰版 vs 反復版
- 演習: 反復版を完成させる空欄問題、Ackermann 簡易版

#### `sicp-1-2-2` 木再帰
- Fibonacci(再帰版)、count-change(両替問題)
- 演習: Fibonacci 反復版を書く、特定 n の値を答える

#### `sicp-1-2-3` 増加オーダ
- prose 中心:Θ 記法、再帰の時空間計算量
- 演習: 計算式を見て O 表記を選ぶ(コード量は少なめ)

#### `sicp-1-2-4` 累乗
- 通常の expt、`fast-expt`(対数時間)
- WardLisp 注記: `even?` を自前定義
- 演習: `fast-expt` を書く

#### `sicp-1-2-5` 最大公約数(GCD)
- ユークリッドの互除法
- WardLisp 注記: `remainder` → `mod` に置換
- 演習: `gcd` を書く、Lamé の定理に関する観察

#### `sicp-1-2-6` 素数判定
- 試し割り法(完全実装可)
- Fermat テスト: prose のみで「WardLisp に `random` がないため概念紹介に留める」と明記
- 演習: `prime?` 述語、最小の N 番目の素数を求める

### 1.3 Higher-Order Procedures(全 4 節)

#### `sicp-1-3-1` 手続きを引数として渡す
- `sum` の高階版、整数の和、平方の和、Simpson 積分
- 演習: `product`(積版)、`sum` 反復版

#### `sicp-1-3-2` lambda で手続きを構成
- 名前なし手続き、`let` の説明
- 演習: `lambda` を使った関数定義、`let` で局所変数

#### `sicp-1-3-3` 一般手法としての手続き
- 半区間法、不動点
- 演習: 黄金比を不動点として求める、`sqrt` を `fixed-point` で書き直す

#### `sicp-1-3-4` 手続きを値として返す
- `average-damp`、`iterative-improve`
- WardLisp 注記: `make-account` 等の状態カウンタは Ch3(本ノートでは扱わない)
- 演習: `compose`、`smooth`、二乗根を `iterative-improve` で再構築

## ファイル構成

各節につき 2 ファイル:
- `game/notebooks/sicp-1-X-Y.lisp` — `make-sicp-1-X-Y-notebook` を export
- `tests/game/notebooks/sicp-1-X-Y.lisp` — スモークテスト + 模範解答 pass テスト

合計 38 ファイル新規 + 4 ファイル編集(`recurya.asd`、`game/notebooks/registry.lisp`、`tests/all.lisp`、`web/ui/learn-home.lisp`(必要なら章見出し用))

## ASDF / registry 変更

`recurya.asd` の `recurya` システムに 19 行追加:
```
"recurya/game/notebooks/sicp-1-1-4"
...
"recurya/game/notebooks/sicp-1-3-4"
```

`recurya/tests` システムに 19 行追加。`tests/all.lisp` に 19 行追加。`game/notebooks/registry.lisp` の `:import-from` と `*notebooks*` を 19 ノートブックぶん拡張。

## テスト戦略

各ノートブックに 2 種テスト:
1. **構造スモークテスト**: セル数 ≥ N、cell-id ユニーク
2. **模範解答テスト**: 各 `code-exercise` セルの canonical solution を `run-cell` に投入し `:pass` を確認

各 expected 値は subagent が REPL で実機確認(printed value)してから埋める。

## 実装フロー(subagent 派遣)

各グループの subagent に対して、参考とすべき既存ノート(`sicp-1-1-1.lisp` 等)・WardLisp の差分・演習の expected 値計算手順を含む詳細プロンプトを渡す。**並列ではなく逐次**(共有 registry/ASDF 編集の競合を避けるため)。

| Group | 節 | 担当 subagent |
|---|---|---|
| G1 | 1.1.4 / 1.1.5 / 1.1.6 | 1 (compound + substitution + conditionals) |
| G2 | 1.1.7 / 1.1.8 | 1 (Newton + black-box) |
| G3 | 1.2.1 / 1.2.2 / 1.2.3 | 1 (linear/tree recursion + orders) |
| G4 | 1.2.4 / 1.2.5 / 1.2.6 | 1 (fast-expt + GCD + primality) |
| G5 | 1.3.1 / 1.3.2 | 1 (procs as args + lambda) |
| G6 | 1.3.3 / 1.3.4 | 1 (general methods + returning procs) |
| Final | registry / ASDF / tests/all まとめ + フルテスト + 学習ホーム見出し追加 | 1 |

各 subagent は **担当節のノートブックファイル + スモーク&模範解答テスト + ASDF/registry 個別追記** を完了し、`run-tests` で各テスト green を確認してコミット。

## 非対象(明示的にやらない)

- 章見出し階層 UI(コース一覧の見出しは `1.1.x`、`1.2.x` 等の表記でフィルタするのみ。ヘッダ追加は別タスク)
- SICP の Exercise 番号(1.1, 1.2 等)を全部実装するのは本タスクのスコープ外。各節 1〜2 個の代表的な演習を選ぶ
- 第 2 章以降
- 進捗バッジの章単位集計(現状の per-notebook 集計のまま)
- Fermat テストや Miller-Rabin の実装(`random` 不在のため概念紹介のみ)

## リスクと緩和

| リスク | 緩和 |
|---|---|
| 各 subagent が異なる expected 値推定をする | 各プロンプトに「REPL で `wardlisp:print-value` を確認してから expected を埋める」を明記 |
| 19 ノートブックを順次入れると ASDF/registry 編集が衝突気味 | Final タスクでまとめて `*notebooks*` 更新する案も併用 |
| 一部の節が SICP 原典に対し不適切に短い/長い | 構成は subagent に委ね、最後に通読時間を粗く揃える(任意) |
| WardLisp の差分注記が節ごとに微妙にずれる | この設計の「WardLisp 方言ガイドライン」表を各 subagent プロンプトに同梱 |

## 完了基準

- 22 ノートブックが registry に登録され `/wardlisp/learn` で全て表示される
- 各 `code-exercise` の模範解答が `run-cell` で `:pass` を返す
- フルテストが green(`asdf:test-system :recurya` → T)
- `/wardlisp/learn/sicp-1-1-4` 〜 `sicp-1-3-4` がブラウザで 200 を返し、最低限のスモーク確認が取れている
