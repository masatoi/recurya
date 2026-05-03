===prose===
これまで個々の式を評価してきました。次は**手続き**(procedure) を定義し、計算のパターンに名前を付けます。`(define (f x) ...)` の形で、引数を取って値を返す手続きを作れます。

===eval===
(define (square x) (* x x))
(square 5)

===prose===
一度定義した手続きは、他の手続きの中から呼び出してより複雑な計算を組み立てられます。

===eval===
(define (square x) (* x x))
(define (sum-of-squares x y) (+ (square x) (square y)))
(sum-of-squares 3 4)

===prose===
練習: 手続きを組み合わせて問題を解いてみましょう。

===exercise: 次の式を計算する手続き f を定義してください: (f a) = a × (1 + a) + (1 - a) そして (f 3) を最終式として残してください。===
; (define (f a) ...) を書く
; 最後に (f 3)

===expect: (f 3) = 3*4 + (-2) = 10===
10

===solution: 次の式を計算する手続き f を定義してください: (f a) = a × (1 + a) + (1 - a) そして (f 3) を最終式として残してください。===
(define (f a) (+ (* a (+ 1 a)) (- 1 a)))
(f 3)

===exercise: square を使って4乗を返す手続き power-fourth を定義してください。 たとえば (power-fourth 3) は 81 です。最終式として (power-fourth 3) を残してください。===
; (define (square x) ...) を書いてから
; (define (power-fourth x) ...) を square を使って書く
; 最後に (power-fourth 3)

===expect: 3 の 4 乗は 81===
81

===solution: square を使って4乗を返す手続き power-fourth を定義してください。 たとえば (power-fourth 3) は 81 です。最終式として (power-fourth 3) を残してください。===
(define (square x) (* x x))
(define (power-fourth x) (square (square x)))
(power-fourth 3)
