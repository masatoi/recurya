# SICP 第2章拡張 設計

- 日付: 2026-04-26
- 対象: recurya / WardLisp 学習コース
- スコープ: SICP Chapter 2「Building Abstractions with Data」全 19 節

## ゴール

第 1 章(18 ノートブック)に続いて Ch2 を完全網羅する 19 ノートブックを追加する。WardLisp に `set!` がないため、SICP 原典が可変表 (`put`/`get`) を使う節は**静的 association list で書き換え**て副作用ゼロを保つ。絵言語(2.2.4)は描画基盤がないため**概念 prose のみ**として節は確保する。

## 確定事項

- 純粋関数のみで実装(`set!` は使わない)
- 2.2.4 は描画なしの概念紹介 prose に縮小
- 2.4.3〜2.5.3 の `put`/`get` は静的 alist で書き換え、各ノートに「副作用版との差分」を簡潔に注記

## 各節の対応

### 2.1 データ抽象入門(4 節、全実装)

- **2.1.1 有理数の演算**: `make-rat`/`numer`/`denom`、簡約として GCD 利用
- **2.1.2 抽象化障壁**: 表現の差し替え可能性を例で示す
- **2.1.3 データとは何か**: cons/car/cdr を関数だけで再構築(closure-based pair)
- **2.1.4 区間算術**: `make-interval`/`add-interval`/`mul-interval`、許容誤差表現

### 2.2 階層データと閉包性(4 節中 3 節実装、2.2.4 は prose)

- **2.2.1 系列の表現**: list-ref、length、append、reverse、last-pair を再帰版・反復版で実装
- **2.2.2 階層構造**: count-leaves、deep-reverse、tree-map
- **2.2.3 系列を共通インタフェースに**: map / filter / accumulate(reduce)を自前定義し、サンプル問題(squared-fibs、enumerate-tree など)を解く
- **2.2.4 絵言語(概念紹介のみ)**: 「絵を組み合わせる関数(beside, below, flip)が高階手続きで構成されること」を prose で説明、recurya UI 制約のため実装は**割愛**

### 2.3 記号データ(4 節、全実装)

- **2.3.1 引用**: `'`、`eq?`、シンボルの取り扱い、`memq`
- **2.3.2 記号微分**: `deriv`、`make-sum`/`make-product`、簡約付き表現
- **2.3.3 集合の表現**: 順序なしリスト / 順序付きリスト / 二分木 の 3 通りで `element-of-set?`/`adjoin-set`/`union-set` を実装し、計算量を比較
- **2.3.4 Huffman 符号木**: tree 構造、`encode`/`decode`、頻度から木を生成

### 2.4 抽象データの複数表現(3 節、全実装、ただし 2.4.3 は静的書き換え)

- **2.4.1 複素数**: 直交表現と極表現
- **2.4.2 タグ付きデータ**: `attach-tag`/`type-tag`/`contents`、選択子の dispatch
- **2.4.3 データ駆動プログラミング**: ⚠️ **書き換え版**
  - 原典の `(put op type proc)` 動的登録を、**静的 alist `op-table`** に置き換え
  - `(get op type)` は alist の lookup
  - 加法性(additivity)の概念は prose で説明:「新しい表現を追加するには `op-table` に行を増やす」
  - 注記: 「SICP 原典は可変表を前提とします。WardLisp は副作用を持たないため、本ノートでは静的 alist で同じ振る舞いを実現します」

### 2.5 ジェネリック演算系(3 節、全実装、すべて静的書き換え)

- **2.5.1 ジェネリック算術**: `add`/`sub`/`mul`/`div` で integer/rational/complex を統一。dispatch は静的 alist
- **2.5.2 異種データの統合**: 型強制(coercion)の static table、共通の上位型への昇格
- **2.5.3 記号代数**: 多項式の和差積、変数優先順、項リスト表現。演算の dispatch は static table

## WardLisp 方言注記(全ノート共通、必要箇所のみ)

| Scheme | WardLisp |
|---|---|
| `#t`/`#f` | `t`/`nil` |
| `(else ...)` | `(t ...)`(cond の最終句) |
| `pair?` | `(define (pair? x) (and (not (null? x)) (not (atom? x))))` |
| `set!` | **存在しない** — 静的 alist や引数渡しで代替 |
| `error` | 存在しないので、SICP の `(error "msg")` は `(list 'error "msg")` を返すなどの簡素化 |

## ファイル構成

各節につき 2 ファイル + registry/ASDF/tests-all 更新。

```
game/notebooks/
  sicp-2-1-1.lisp .. sicp-2-5-3.lisp  (19ファイル新規)
tests/game/notebooks/
  sicp-2-1-1.lisp .. sicp-2-5-3.lisp  (19ファイル新規)
```

合計 38 ファイル新規 + 4 ファイル編集(`recurya.asd`、`game/notebooks/registry.lisp`、`tests/all.lisp`、必要なら `web/ui/learn-home.lisp`)。

## テスト戦略

各ノートに 2 種テスト:
1. **構造スモークテスト**: セル数 ≥ N、cell-id ユニーク
2. **模範解答テスト**: 各 `code-exercise` の canonical solution を `run-cell` に投入 → `:pass` を確認

各 expected 値は subagent が REPL で実機確認してから埋める。

## 実装フロー(subagent 派遣)

| Group | 節 | 担当 |
|---|---|---|
| G1 | 2.1.1 / 2.1.2 / 2.1.3 / 2.1.4 | 1 (有理数 + 区間) |
| G2 | 2.2.1 / 2.2.2 / 2.2.3 | 1 (系列 + 階層 + 共通IF) |
| G3 | 2.2.4 / 2.3.1 | 1 (絵言語prose + 引用) |
| G4 | 2.3.2 / 2.3.3 / 2.3.4 | 1 (記号微分 + 集合 + Huffman) |
| G5 | 2.4.1 / 2.4.2 / 2.4.3 | 1 (複素数 + タグ + 静的データ駆動) |
| G6 | 2.5.1 / 2.5.2 / 2.5.3 | 1 (ジェネリック算術) |
| Final | registry / ASDF まとめ + フルテスト + ブラウザ確認 | 1 |

逐次派遣(共有 registry/ASDF 編集の競合回避)。

## 非対象(明示的にやらない)

- 章見出し階層 UI(`/wardlisp/learn` 一覧は単純並びのまま)
- SICP の Exercise 番号(2.1〜2.84)を全部実装するのはスコープ外。各節 1〜2 個の代表演習を選ぶ
- `set!` 拡張依存の Ch3 系の前準備
- 2.2.4 の絵描画実装(将来別タスク)
- 全 dispatch テーブルを「真に拡張可能」にする抽象基盤(教育的にはそこまで踏み込まない)
- Ch3 以降

## リスクと緩和

| リスク | 緩和 |
|---|---|
| 静的 alist 化で SICP の意図(動的拡張性)が伝わらない | 各該当ノートの prose で明示し、加法性の概念は保つ |
| 2.4.3 以降の節が長くなりがち(SICP 原典でも複雑) | 各ノートのコード演習を 2 個程度に絞る |
| 模範解答の expected が長い list で print-value 一致が脆い | REPL で実機確認した print-value 文字列をそのまま使う(これまでの pattern) |
| 一部の演習が `*notebook-fuel*` (20000) を超える | サブセットの入力で済む例題に絞る、必要なら fuel を確認した上で expected を埋める |

## 完了基準

- 19 ノート(または 18 ノート + 2.2.4 のスタブ prose)が registry に登録され `/wardlisp/learn` で 36 件以上(Ch1 18 + Ch2 18 以上)が並ぶ
- 各 `code-exercise` の模範解答が `run-cell` で `:pass` を返す
- フルテストが green
- 2.4.3 以降の dispatch table が静的 alist で動作することを実装で示す
