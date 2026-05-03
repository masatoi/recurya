===prose===
手続き `(define (f x) body)` を呼び出すとき、評価器は本体 `body` 中の `x` を引数の値で置き換え、その式を評価します。これを**置換モデル**と呼びます。

===eval===
(define (square x) (* x x))
(define (sum-of-squares x y) (+ (square x) (square y)))
(define (f a) (sum-of-squares (+ a 1) (* a 2)))
(f 5)

===prose===
上の (f 5) を置換で展開すると次のように評価が進みます:

```
(f 5)
(sum-of-squares (+ 5 1) (* 5 2))
(sum-of-squares 6 10)
(+ (square 6) (square 10))
(+ (* 6 6) (* 10 10))
(+ 36 100)
136
```

===prose===
**適用順序**(applicative order)では、引数を*先に評価して値にしてから*本体に代入します。

**通常順序**(normal order)では、引数の式を*そのまま*本体に代入し、必要になったときに展開します。

WardLisp は適用順序を採用しています。

===eval===
(define (p) (p))
(define (test x y) (if (= x 0) 0 y))

===prose===
もしここで `(test 0 (p))` を評価すると、適用順序では `(p)` を先に評価しようとして無限ループに陥ります。通常順序では `x = 0` のチェックが先に行われるので `(p)` は評価されません。(このセル自身は定義だけで止めています。)

===exercise: 次の手続きを定義して (a-plus-abs-b 3 -5) の値を求めてください。 (define (a-plus-abs-b a b) ((if (> b 0) + -) a b)) 最終式として (a-plus-abs-b 3 -5) を残してください。 (SICP の演習 1.4 と同じ。条件式が手続きの位置に来ています。)===
; ここに定義と呼び出しを書く

===expect: 3 + |-5| = 8===
8

===solution: 次の手続きを定義して (a-plus-abs-b 3 -5) の値を求めてください。 (define (a-plus-abs-b a b) ((if (> b 0) + -) a b)) 最終式として (a-plus-abs-b 3 -5) を残してください。 (SICP の演習 1.4 と同じ。条件式が手続きの位置に来ています。)===
(define (a-plus-abs-b a b) ((if (> b 0) + -) a b))
(a-plus-abs-b 3 -5)
