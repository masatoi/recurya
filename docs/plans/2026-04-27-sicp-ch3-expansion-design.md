# SICP 第3章拡張 設計

- 日付: 2026-04-27
- 対象: recurya / WardLisp 学習コース
- スコープ: SICP Chapter 3「Modularity, Objects, and State」全 19 節

## ゴール

第 1〜2 章(36 ノート)に続いて Ch3 を完全網羅する 19 ノートブックを追加する。WardLisp に `set!`/`set-car!`/`set-cdr!` がないため、原典が状態の変更で表現する内容を **持続的データ構造** または **状態渡し** または **収束反復** で書き換える。各ノートに「SICP 原典の方法 ↔ WardLisp 関数型版」の対比 prose を入れて、両パラダイムの比較教材として機能させる。

## 共通方針

すべてのノートが共通フォーマット:
1. **何を扱うか**(prose)
2. **SICP 原典の `set!` 版**(コード断片を prose 内に表示、評価はしない)
3. **WardLisp 関数型版**(code-eval / code-exercise として実装)
4. **両者の比較**(prose で「失われたもの・得られたもの」を論じる)
5. 演習(可能な節のみ)

## 各節の書き換え方針

### 3.1 代入と局所状態(3 節)

#### 3.1.1 局所状態変数
- 原典: `(make-account balance)` が `set!` で残高を更新するクロージャを返す
- 書き換え: `(make-account balance)` は不変の account レコード `(cons 'account balance)` を返す。`(withdraw acc amount)` は **新しい account を返す関数**
- 演習: 関数型版 `withdraw`/`deposit` の実装、複数の連続操作

#### 3.1.2 代入導入のメリット
- 原典: 乱数状態を `set!` で隠蔽する `rand` クロージャ、Monte Carlo 法
- 書き換え: **seed を明示的に引数に渡す**(状態渡し)。WardLisp v0.2.0 の `random` を使った Monte Carlo
- 注: 「`set!` がないと状態が露出する」というメッセージは prose で論じる
- 演習: π を Monte Carlo で近似する純関数版

#### 3.1.3 代入導入のコスト
- 原典: 参照透過性の喪失、`same-account?` の問題
- 書き換え: **持続的版だと参照透過性が自然に保たれる**ことを示す。`set!` 導入時に何が起きるかは prose
- 演習: 関数型 account で `equal?` による等価判定は意味があるが、SICP の `set!` 版では「同一性 (identity)」と「等価性 (equality)」が分かれることを論じる

### 3.2 評価の環境モデル(4 節)— prose 中心

`set!` 不要。環境フレームを ASCII 図で表現、トレース演習。

- 3.2.1 評価規則
- 3.2.2 単純な手続きの適用
- 3.2.3 局所状態の格納庫としてのフレーム
- 3.2.4 内部定義

各節 4-6 セル、prose + 1〜2 個のコード演習(「次の式を環境モデルで辿るとどんな値になるか?」)。

### 3.3 可変データを用いたモデル化(5 節)

#### 3.3.1 可変リスト構造
- 原典: `set-car!`/`set-cdr!` で構造を変更、共有・サイクルを作る
- 書き換え: **共有**は cons で再現可、`eq?` で同一性を確認可。**サイクル**は唯一実装不可で、prose で「mutation でしか作れない」と明示
- 演習: 共有を `eq?` で検出する例

#### 3.3.2 待ち行列
- 原典: 双リンクで `enqueue`/`dequeue` を O(1) にする
- 書き換え: **2 スタック法(関数型キュー)**。`enqueue` は新キュー、`dequeue` は値と新キューを返す
- 演習: BFS で関数型キューを使う例

#### 3.3.3 表(table)
- 原典: 1次元 / 2次元 mutable table
- 書き換え: **persistent alist**。`(insert k v table)` は新 table を返す
- 演習: 順序付き table への複数挿入

#### 3.3.4 デジタル回路シミュレータ
- 原典: agenda(時間付きイベント)を mutate してシミュレート
- 書き換え: **状態遷移関数**: `(step state)` が次の状態を返し、停止条件まで `iterate`
- 演習: 簡単な and-gate / inverter のシミュレーション(ASCII 出力)

#### 3.3.5 制約の伝播
- 原典: connector ↔ constraint の双方向 mutation
- 書き換え: **不動点反復** — `(propagate network)` を変化が止まるまで繰り返す
- 演習: 摂氏 ↔ 華氏変換の小さなネットワーク

### 3.4 並行性(2 節)— prose 比較

WardLisp はシングルスレッドだが原典の問題提起は理解できる。

- 3.4.1 並行システムにおける時間
- 3.4.2 並行性の制御機構

各節は prose 中心で、「shared mutable state がない設計」「STM」「actor モデル」の関数型代替を比較する。コード演習は最小限(または無し)。

### 3.5 ストリーム(5 節)

#### 3.5.1 ストリームは遅延リスト
- WardLisp に `delay`/`force` がないので**自前定義**:
  ```
  ;; SICP の (cons-stream a b) を以下で代替:
  (define (stream-cons a thunk) (cons a thunk))
  (define (stream-car s) (car s))
  (define (stream-cdr s) ((cdr s)))
  ```
  ユーザは `(cons-stream a b)` の代わりに `(stream-cons a (lambda () b))` を書く
- 演習: 整数の累積和ストリーム

#### 3.5.2 無限ストリーム
- `(integers-from n)`、Fibonacci ストリーム、Eratosthenes の篩
- 演習: 整数の二乗ストリームの先頭 5 要素

#### 3.5.3 ストリームパラダイムの活用
- ストリーム上の `stream-map` / `stream-filter` / `stream-take`
- 演習: 偶数の二乗の先頭 N 要素

#### 3.5.4 ストリームと遅延評価
- ストリームによる「無限級数」の表現、π の Leibniz 級数
- 演習: 部分和ストリームの 50 項目を取得

#### 3.5.5 関数型プログラムのモジュール性 vs オブジェクトのモジュール性
- prose 中心: ストリームベース vs オブジェクトベースの並行設計の対比
- 演習: 関数型ストリーム合成で銀行口座シナリオを再現する小さな例

## ファイル構成

各節につき 2 ファイル。

```
game/notebooks/
  sicp-3-1-1.lisp .. sicp-3-5-5.lisp   (19ファイル新規)
tests/game/notebooks/
  sicp-3-1-1.lisp .. sicp-3-5-5.lisp   (19ファイル新規)
```

合計 38 ファイル新規 + 4 ファイル編集(`recurya.asd`、`game/notebooks/registry.lisp`、`tests/all.lisp`、必要なら `web/ui/learn-home.lisp`)。

## テスト戦略

各ノートに 2 種テスト:
1. **構造スモークテスト**: セル数 ≥ N、cell-id ユニーク
2. **模範解答テスト**: 各 `code-exercise` の canonical solution を `run-cell` に投入 → `:pass` を確認

各 expected 値は subagent が REPL で実機確認。

## 実装フロー(subagent 派遣)

| Group | 節 | 担当 |
|---|---|---|
| G1 | 3.1.1 / 3.1.2 / 3.1.3 | 1 (持続的状態) |
| G2 | 3.2.1 / 3.2.2 / 3.2.3 / 3.2.4 | 1 (環境モデル prose+トレース) |
| G3 | 3.3.1 / 3.3.2 / 3.3.3 | 1 (持続的リスト・キュー・表) |
| G4 | 3.3.4 / 3.3.5 | 1 (状態遷移シミュレータ) |
| G5 | 3.4.1 / 3.4.2 | 1 (並行性 prose) |
| G6 | 3.5.1 / 3.5.2 / 3.5.3 | 1 (ストリーム基礎) |
| G7 | 3.5.4 / 3.5.5 | 1 (遅延評価・モジュール性比較) |
| Final | registry / ASDF まとめ + フルテスト + ブラウザ確認 | 1 |

逐次派遣(共有 registry/ASDF 編集の競合回避)。

## WardLisp 方言注記(全ノート共通、必要箇所のみ)

| Scheme | WardLisp |
|---|---|
| `#t`/`#f` | `t`/`nil` |
| `(else ...)` | `(t ...)` |
| `pair?` | `(define (pair? x) (and (not (null? x)) (not (atom? x))))` |
| `set!`/`set-car!`/`set-cdr!` | **存在しない** — 持続的データ構造 / 状態渡し / 不動点反復で代替 |
| `cons-stream` | `(stream-cons a (lambda () b))` を自前定義し使用 |
| `delay`/`force` | 明示的 thunk(`(lambda () expr)` と `((thunk))`) |
| `t` を識別子に使う | NG(reserved)。`tr`/`tree` を使う |
| 文字列リテラル `"..."` | unsupported |
| `error` | unsupported |

## 非対象(明示的にやらない)

- `set!` の wardlisp 追加(別タスクとして残す)
- 真の循環データ構造の実装(prose で「mutation でしか作れない」と明記)
- 真のマルチスレッド並行性(シングルスレッドのみ)
- 各章ヘッダ階層 UI(coursehome は単純並びのまま)
- SICP の Exercise 番号(3.1〜3.82)を全部実装するのはスコープ外。各節 1〜2 個の代表演習

## リスクと緩和

| リスク | 緩和 |
|---|---|
| 関数型書き換えで SICP の意図(state-based モデル化)が伝わらない | 各ノート冒頭で原典コードを prose 内に提示、書き換えの動機と対比を明示 |
| 状態渡しが冗長で読みにくい | 小さな例題に絞る、ヘルパ関数で抽象化を示す |
| ストリームの `stream-cons (lambda () ...)` が冗長 | 1 度定義した後は短縮形を使うパターンを示す |
| 3.3.4/3.3.5 の状態遷移版が原典より複雑 | 入力規模を絞り、固定点までの遷移回数を小さく(default fuel 内に収める) |
| 3.4 のコード演習が不可能 | prose 中心で構わない(他ノートも同様の概念紹介ノートあり) |

## 完了基準

- 19 ノートが registry に登録され `/wardlisp/learn` で 55 件が並ぶ(Ch1: 18 + Ch2: 18 + Ch3: 19)
- 各 `code-exercise` の模範解答が `run-cell` で `:pass` を返す
- フルテストが green(`asdf:test-system :recurya` → T)
- 既存 36 ノートに回帰なし
