===prose===
複素数 `z = x + yi` は 2 つのデータで表せます: **直交座標** `(x, y)` または **極座標** `(r, θ)`。どちらの表現でも `real-part` / `imag-part` / `magnitude` / `angle` の 4 つの操作で扱えるようにしたい。

===prose===
**直交座標表現**: 内部は `(cons real imag)`。`real-part` と `imag-part` はそれぞれ `car` / `cdr` で取れます。`magnitude` は √(x² + y²)。

===eval===
(define (square x) (* x x))
(define (sqrt-newton x)
  (define (good? g) (< (let ((d (- (square g) x))) (if (< d 0) (- 0 d) d)) 0.001))
  (define (improve g) (/ (+ g (/ x g)) 2))
  (define (iter g) (if (good? g) g (iter (improve g))))
  (iter 1.0))
(define (make-from-real-imag x y) (cons x y))
(define (real-part z) (car z))
(define (imag-part z) (cdr z))
(define (magnitude z) (sqrt-newton (+ (square (real-part z)) (square (imag-part z)))))
(define z1 (make-from-real-imag 3.0 4.0))
(list (real-part z1) (imag-part z1) (magnitude z1))

===prose===
本来 `angle` は `atan(y / x)` で計算しますが、WardLisp に `atan` がないため、本ノートでは `magnitude` までを扱います (角度は概念として登場しますが、具体的計算は省略)。

===prose===
**極座標表現**: 内部は `(cons magnitude angle)`。`magnitude` と `angle` はそれぞれ `car` / `cdr` で取れます。本来 `real-part` は `r * cos(θ)` ですが、`cos` / `sin` もないので、ここでは内部表現を直接取り出すだけにとどめます。

===eval===
(define (make-from-mag-ang r a) (cons r a))
(define (magnitude-polar z) (car z))
(define (angle-polar z) (cdr z))
(define z2 (make-from-mag-ang 5.0 0.927))
(list (magnitude-polar z2) (angle-polar z2))

===prose===
「複素数」という同じ抽象を、**異なる内部表現** で実装できることが重要なポイントです。次節 2.4.2 ではタグ付きデータを使って両者を統一的に扱い、2.4.3 ではデータ駆動ディスパッチでそれを一般化します。

===exercise: 直交座標で z = (6, 8) の複素数を作り、magnitude を求めてください。 (square / sqrt-newton / make-from-real-imag / real-part / imag-part / magnitude を上の例と同じ形で定義し、) 最終式として (magnitude (make-from-real-imag 6.0 8.0)) を残します。結果は 10 近傍の浮動小数になります (sqrt-newton による近似)。===
; (define (square x) (* x x))
; (define (sqrt-newton x) ...)
; (define (make-from-real-imag x y) ...)
; (define (real-part z) ...)
; (define (imag-part z) ...)
; (define (magnitude z) ...)
; 最後に (magnitude (make-from-real-imag 6.0 8.0))

===expect: √(6² + 8²) = 10 を Newton 法で近似===
10.000000000139897

===solution: 直交座標で z = (6, 8) の複素数を作り、magnitude を求めてください。 (square / sqrt-newton / make-from-real-imag / real-part / imag-part / magnitude を上の例と同じ形で定義し、) 最終式として (magnitude (make-from-real-imag 6.0 8.0)) を残します。結果は 10 近傍の浮動小数になります (sqrt-newton による近似)。===
(define (square x) (* x x))
(define (sqrt-newton x)
  (define (good? g) (< (let ((d (- (square g) x))) (if (< d 0) (- 0 d) d)) 0.001))
  (define (improve g) (/ (+ g (/ x g)) 2))
  (define (iter g) (if (good? g) g (iter (improve g))))
  (iter 1.0))
(define (make-from-real-imag x y) (cons x y))
(define (real-part z) (car z))
(define (imag-part z) (cdr z))
(define (magnitude z) (sqrt-newton (+ (square (real-part z)) (square (imag-part z)))))
(define (add-complex z1 z2)
  (make-from-real-imag (+ (real-part z1) (real-part z2))
                       (+ (imag-part z1) (imag-part z2))))
(magnitude (make-from-real-imag 6.0 8.0))

===exercise: 直交座標表現で 2 つの複素数を足す add-complex を書いてください。 add-complex は (x1 + x2, y1 + y2) を返します。 最終式として (real-part (add-complex (make-from-real-imag 1 2) (make-from-real-imag 3 4))) を残します。1 + 3 = 4。===
; (define (make-from-real-imag x y) (cons x y))
; (define (real-part z) (car z))
; (define (imag-part z) (cdr z))
; (define (add-complex z1 z2) ...)
; 最後に (real-part (add-complex (make-from-real-imag 1 2) (make-from-real-imag 3 4)))

===expect: (1 + 2i) + (3 + 4i) の実部 = 4===
4

===solution: 直交座標表現で 2 つの複素数を足す add-complex を書いてください。 add-complex は (x1 + x2, y1 + y2) を返します。 最終式として (real-part (add-complex (make-from-real-imag 1 2) (make-from-real-imag 3 4))) を残します。1 + 3 = 4。===
(define (square x) (* x x))
(define (sqrt-newton x)
  (define (good? g) (< (let ((d (- (square g) x))) (if (< d 0) (- 0 d) d)) 0.001))
  (define (improve g) (/ (+ g (/ x g)) 2))
  (define (iter g) (if (good? g) g (iter (improve g))))
  (iter 1.0))
(define (make-from-real-imag x y) (cons x y))
(define (real-part z) (car z))
(define (imag-part z) (cdr z))
(define (magnitude z) (sqrt-newton (+ (square (real-part z)) (square (imag-part z)))))
(define (add-complex z1 z2)
  (make-from-real-imag (+ (real-part z1) (real-part z2))
                       (+ (imag-part z1) (imag-part z2))))
(real-part (add-complex (make-from-real-imag 1 2) (make-from-real-imag 3 4)))
