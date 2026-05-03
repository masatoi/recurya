===prose===
`(define (square x) (* x x))` を呼ぶ `(square 5)` の評価を環境モデルで追ってみましょう:

1. 引数 `5` を評価する (既に値なのでそのまま)
2. 新フレーム `E1` を作り、親を **`square` の定義環境** (= global) に設定する
3. `E1` に `x: 5` を束縛する
4. body `(* x x)` を `E1` で評価 → `5 * 5 = 25`

===eval===
(define (square x) (* x x))
(square 5)

===prose===
**ネストした呼び出し**:

```
(define (square x) (* x x))
(define (sum-of-squares x y) (+ (square x) (square y)))
(sum-of-squares 3 4)
```

評価過程:

1. `sum-of-squares` の呼び出しで E1 が作られ、`x: 3, y: 4` が束縛される
2. body `(+ (square x) (square y))` を E1 で評価
3. `(square 3)` で E2 (parent: global, `x: 3`) が作られ、`(* x x)` を評価 → 9
4. `(square 4)` で E3 (parent: global, `x: 4`) が作られ、`(* x x)` を評価 → 16
5. `(+ 9 16)` → 25

**注意**: E2 と E3 の `x` は E1 の `x` とは別物。それぞれの呼び出しが独立したフレームを持つので互いに影響しません。

===eval===
(define (square x) (* x x))
(define (sum-of-squares x y) (+ (square x) (square y)))
(sum-of-squares 3 4)

===prose===
**フレーム親の決定**: 関数が **呼ばれた** ときの環境ではなく、関数が **作られた** ときの環境が親になります (= レキシカルスコープ)。

これが **動的スコープ (dynamic scope)** と区別される点です。動的スコープなら呼び出し時の環境を親にしますが、Scheme・WardLisp・Lisp 系のほとんどはレキシカルスコープを採用します。理由: コードを読むだけで変数の意味が決まるので推論しやすい。

ASCII 図:

```
  [global]
  └── square: (lambda (x) (* x x))   ← 定義時に global を捕捉

  square 呼び出し
    E1 [parent: global]
    └── x: 5
        body (* x x) を E1 で評価
```

===exercise: 次のコードの評価結果を予想してから実行してください。 (define x 100) (define (f y) (+ x y)) (define x 1) (f 5) WardLisp の define は再定義可能で、後の (define x 1) が前の x を上書きします。 そのあと (f 5) を呼ぶので、f の body 中の x は最新の 1、y は 5 になり、結果は 1 + 5 = 6 です。 最終式として (f 5) を残してください。期待値は 6 です。===
; (define x 100)
; (define (f y) (+ x y))
; (define x 1)
; (f 5)

===expect: x を 100 から 1 に再定義した後 (f 5) は 6===
6

===solution: 次のコードの評価結果を予想してから実行してください。 (define x 100) (define (f y) (+ x y)) (define x 1) (f 5) WardLisp の define は再定義可能で、後の (define x 1) が前の x を上書きします。 そのあと (f 5) を呼ぶので、f の body 中の x は最新の 1、y は 5 になり、結果は 1 + 5 = 6 です。 最終式として (f 5) を残してください。期待値は 6 です。===
(define x 100)
(define (f y) (+ x y))
(define x 1)
(f 5)
