===prose===
条件式は、値を場合分けして返すための仕組みです。`if`・`cond`、論理演算子 `and`・`or`・`not` を使います。

**WardLisp の真偽値は **`t` と `nil` です。Scheme の `#t`・`#f` ではないので注意してください。

===eval===
(if (> 5 3) 'big 'small)

===prose===
`cond` は複数の条件節から、最初に真になった節を選びます。最後の節は `(t ...)` と書くと「それ以外すべて」を意味します。

Scheme の `(else ...)` に相当する書き方が WardLisp では `(t ...)` になることに注意してください。

===eval===
(define (sign x)
  (cond ((> x 0) 'positive)
        ((< x 0) 'negative)
        (t       'zero)))
(sign -3)

===prose===
`and` と `or` は短絡評価です。`not` は真偽を反転します。

===eval===
(list (and (> 5 3) (< 2 4))
      (or nil 7)
      (not (= 1 2)))

===exercise: if を使って絶対値を返す手続き abs-val を定義し、 最終式として (abs-val -7) を残してください。===
; (define (abs-val x) ...) を書く
; 最後に (abs-val -7)

===expect: |-7| = 7===
7

===solution: if を使って絶対値を返す手続き abs-val を定義し、 最終式として (abs-val -7) を残してください。===
(define (abs-val x) (if (< x 0) (- 0 x) x))
(abs-val -7)

===exercise: (>= x y) と同じ意味の手続き my-ge? を、 < と not だけを使って定義してください。 最終式として (my-ge? 5 5) を残してください(t になるはずです)。===
; (define (my-ge? x y) ...) を書く
; 最後に (my-ge? 5 5)

===expect: 5 >= 5 は真===
t

===solution: (>= x y) と同じ意味の手続き my-ge? を、 < と not だけを使って定義してください。 最終式として (my-ge? 5 5) を残してください(t になるはずです)。===
(define (my-ge? x y) (not (< x y)))
(my-ge? 5 5)

===exercise: 3 つの数 a b c を引数に取り、大きい方 2 つの和を返す手続き sum-of-two-largest を定義してください。最終式として (sum-of-two-largest 3 7 4) を残してください(7 + 4 = 11)。===
; (define (sum-of-two-largest a b c) ...) を書く
; 最後に (sum-of-two-largest 3 7 4)

===expect: 7 と 4 の和===
11

===solution: 3 つの数 a b c を引数に取り、大きい方 2 つの和を返す手続き sum-of-two-largest を定義してください。最終式として (sum-of-two-largest 3 7 4) を残してください(7 + 4 = 11)。===
(define (sum-of-two-largest a b c)
  (cond ((and (<= a b) (<= a c)) (+ b c))
        ((and (<= b a) (<= b c)) (+ a c))
        (t                       (+ a b))))
(sum-of-two-largest 3 7 4)
