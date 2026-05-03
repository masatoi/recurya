===prose===
前に `sqrt` を Newton 法で書きました。Newton 法は実は **不動点反復** と呼ばれる、より一般的な計算手法の特殊形です。

`f(x) = x` を満たす `x` を求めるのが不動点反復で、改善関数を上手く当てはめれば多くの問題に応用できます。本節では、こうした **汎用手法** を高階手続きとして表現する例を 2 つ見ます: **半区間法** と **不動点反復** です。

===prose===
**半区間法 (half-interval method)**: 連続関数 `f` について `f(a) < 0 < f(b)` となる `a` と `b` が分かっているとき、`f(x) = 0` を満たす根 `x` が `a` と `b` の間に存在します。

区間の中点 `m` で `f(m)` を評価し、符号で根を含む半区間を選び、区間を半分ずつ狭めて根に近付ける方法です。区間幅が十分小さくなったら中点を答えとして返します。

===eval===
(define (abs-val x) (if (< x 0) (- 0 x) x))
(define (close-enough? a b) (< (abs-val (- a b)) 0.001))
(define (search f neg-pt pos-pt)
  (let ((midpoint (/ (+ neg-pt pos-pt) 2)))
    (if (close-enough? neg-pt pos-pt)
        midpoint
        (let ((test-value (f midpoint)))
          (cond ((> test-value 0) (search f neg-pt midpoint))
                ((< test-value 0) (search f midpoint pos-pt))
                (t midpoint))))))
(define (half-interval-method f a b)
  (let ((a-value (f a)) (b-value (f b)))
    (cond ((and (< a-value 0) (> b-value 0)) (search f a b))
          ((and (< b-value 0) (> a-value 0)) (search f b a))
          (t 'error-no-root))))
;; x^3 - 2x - 5 = 0 の根を 2 と 3 の間で探す
(half-interval-method (lambda (x) (- (* x x x) (* 2 x) 5)) 2.0 3.0)

===prose===
**不動点 (fixed point)**: 関数 `f` について `f(x) = x` を満たす `x` のことを、`f` の不動点と呼びます。

不動点を求めるには、ある初期推測 `g` から始めて `g, f(g), f(f(g)), f(f(f(g))), ...` と繰り返し `f` を適用していき、値が変化しなくなった (連続する 2 値が十分近い) ところで止めます。

===eval===
(define (abs-val x) (if (< x 0) (- 0 x) x))
(define (close-enough? a b) (< (abs-val (- a b)) 0.0001))
(define (fixed-point f start)
  (define (try g) (let ((next (f g))) (if (close-enough? g next) next (try next))))
  (try start))
;; (lambda (x) (/ (+ x (/ 2 x)) 2)) の不動点は √2
(fixed-point (lambda (x) (/ (+ x (/ 2 x)) 2)) 1.0)

===prose===
`fixed-point` を使えば、`sqrt` も **不動点問題** として書き直せます。

`y/x` を `x` に写す関数の不動点は、`x = y/x` すなわち `x^2 = y` を満たす `x`、つまり `√y` です。ただし素朴に `(lambda (x) (/ y x))` を反復すると振動して収束しないので、前の値と平均を取る `(/ (+ x (/ y x)) 2)` のような形を使います (次節 1.3.4 で扱う**平均緩和**)。

===exercise: fixed-point を使って sqrt(2) を求める手続き my-sqrt-2 を書いてください。 本文の fixed-point と abs-val, close-enough? をそのまま使い、 最終式として (my-sqrt-2) を残します。 (define (my-sqrt-2) (fixed-point (lambda (x) (/ (+ x (/ 2 x)) 2)) 1.0)) 答え: 1.4142135623746899===
; (define (abs-val x) ...)
; (define (close-enough? a b) ...)
; (define (fixed-point f start) ...)
; (define (my-sqrt-2) ...)
; 最後に (my-sqrt-2)

===expect: fixed-point で sqrt(2)===
1.4142135623746899

===solution: fixed-point を使って sqrt(2) を求める手続き my-sqrt-2 を書いてください。 本文の fixed-point と abs-val, close-enough? をそのまま使い、 最終式として (my-sqrt-2) を残します。 (define (my-sqrt-2) (fixed-point (lambda (x) (/ (+ x (/ 2 x)) 2)) 1.0)) 答え: 1.4142135623746899===
(define (abs-val x) (if (< x 0) (- 0 x) x))
(define (close-enough? a b) (< (abs-val (- a b)) 0.0001))
(define (fixed-point f start)
  (define (try g) (let ((next (f g))) (if (close-enough? g next) next (try next))))
  (try start))
(define (my-sqrt-2)
  (fixed-point (lambda (x) (/ (+ x (/ 2 x)) 2)) 1.0))
(my-sqrt-2)

===exercise: 黄金比 φ は φ = 1 + 1/φ という不動点方程式を満たします。 fixed-point を使って (lambda (x) (+ 1 (/ 1 x))) の不動点として φ を求める式を書いてください。 最終式として (fixed-point (lambda (x) (+ 1 (/ 1 x))) 1.0) を残します。 答え: 1.6180555555555556 (黄金比 φ ≒ 1.618 の近似)===
; (define (abs-val x) ...)
; (define (close-enough? a b) ...)
; (define (fixed-point f start) ...)
; 最後に (fixed-point (lambda (x) (+ 1 (/ 1 x))) 1.0)

===expect: 黄金比 φ===
1.6180555555555556

===solution: 黄金比 φ は φ = 1 + 1/φ という不動点方程式を満たします。 fixed-point を使って (lambda (x) (+ 1 (/ 1 x))) の不動点として φ を求める式を書いてください。 最終式として (fixed-point (lambda (x) (+ 1 (/ 1 x))) 1.0) を残します。 答え: 1.6180555555555556 (黄金比 φ ≒ 1.618 の近似)===
(define (abs-val x) (if (< x 0) (- 0 x) x))
(define (close-enough? a b) (< (abs-val (- a b)) 0.0001))
(define (fixed-point f start)
  (define (try g) (let ((next (f g))) (if (close-enough? g next) next (try next))))
  (try start))
(fixed-point (lambda (x) (+ 1 (/ 1 x))) 1.0)
