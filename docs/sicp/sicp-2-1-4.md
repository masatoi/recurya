===prose===
測定値はしばしば誤差を伴います。抵抗値 6.8 オーム ± 10% のように、値が「ある範囲のどこか」にあることだけ分かっていて、正確な値は分からない、ということがよくあります。

そこで、各値を **区間 [lo, hi]** で表し、計算結果も区間として求めるしくみを作ります。これは **抽象データ** の良い実例で、前節までの「構築子と選択子で抽象化する」パターンがそのまま使えます。

===prose===
まず構築子と選択子を定義します。区間は単なる数のペアです。

===eval===
(define (make-interval lo hi) (cons lo hi))
(define (lower-bound i) (car i))
(define (upper-bound i) (cdr i))
(define i (make-interval 6.12 7.48))
(list (lower-bound i) (upper-bound i))

===prose===
**加算**: 区間 `[a, b]` と `[c, d]` の和は `[a+c, b+d]` 。両端をそれぞれ足すだけです。

===eval===
(define (make-interval lo hi) (cons lo hi))
(define (lower-bound i) (car i))
(define (upper-bound i) (cdr i))
(define (add-interval x y)
  (make-interval (+ (lower-bound x) (lower-bound y))
                 (+ (upper-bound x) (upper-bound y))))
(add-interval (make-interval 1.0 2.0) (make-interval 3.0 5.0))

===prose===
**乗算**: 端点同士の積は最大 4 通り考えられます (`lo*lo, lo*hi, hi*lo, hi*hi`)。負の数が混じる場合もあるので、結果の区間は **4 つの積の最小値と最大値** を取って作ります。

===eval===
(define (make-interval lo hi) (cons lo hi))
(define (lower-bound i) (car i))
(define (upper-bound i) (cdr i))
(define (my-min a b) (if (< a b) a b))
(define (my-max a b) (if (> a b) a b))
(define (mul-interval x y)
  (let ((p1 (* (lower-bound x) (lower-bound y)))
        (p2 (* (lower-bound x) (upper-bound y)))
        (p3 (* (upper-bound x) (lower-bound y)))
        (p4 (* (upper-bound x) (upper-bound y))))
    (make-interval (my-min (my-min p1 p2) (my-min p3 p4))
                   (my-max (my-max p1 p2) (my-max p3 p4)))))
(mul-interval (make-interval 2 3) (make-interval 4 5))

===exercise: 区間の幅 (width i) を返す手続きを書いてください。 幅は (上端 - 下端) / 2 と定義します (中心からの誤差幅)。 make-interval / lower-bound / upper-bound は自分でセル内に再定義し、 最終式として (width (make-interval 4 10)) を残してください。 答えは 3 になります。===
; (define (make-interval lo hi) ...)
; (define (lower-bound i) ...)
; (define (upper-bound i) ...)
; (define (width i) ...)
; 最後に (width (make-interval 4 10))

===expect: 区間 [4,10] の幅は (10-4)/2 = 3===
3

===solution: 区間の幅 (width i) を返す手続きを書いてください。 幅は (上端 - 下端) / 2 と定義します (中心からの誤差幅)。 make-interval / lower-bound / upper-bound は自分でセル内に再定義し、 最終式として (width (make-interval 4 10)) を残してください。 答えは 3 になります。===
(define (make-interval lo hi) (cons lo hi))
(define (lower-bound i) (car i))
(define (upper-bound i) (cdr i))
(define (width i) (/ (- (upper-bound i) (lower-bound i)) 2))
(width (make-interval 4 10))

===exercise: 区間の差 (sub-interval x y) を書いてください。 区間 [a, b] から区間 [c, d] を引いた結果は、 最小は a-d、最大は b-c なので [a-d, b-c] になります。 make-interval / lower-bound / upper-bound はセル内に再定義してください。 最終式として (sub-interval (make-interval 5 10) (make-interval 1 3)) を残してください。結果は (2 . 9) になります。===
; (define (make-interval lo hi) ...)
; (define (lower-bound i) ...)
; (define (upper-bound i) ...)
; (define (sub-interval x y) ...)
; 最後に (sub-interval (make-interval 5 10) (make-interval 1 3))

===expect: [5,10] - [1,3] = [2,9]===
(2 . 9)

===solution: 区間の差 (sub-interval x y) を書いてください。 区間 [a, b] から区間 [c, d] を引いた結果は、 最小は a-d、最大は b-c なので [a-d, b-c] になります。 make-interval / lower-bound / upper-bound はセル内に再定義してください。 最終式として (sub-interval (make-interval 5 10) (make-interval 1 3)) を残してください。結果は (2 . 9) になります。===
(define (make-interval lo hi) (cons lo hi))
(define (lower-bound i) (car i))
(define (upper-bound i) (cdr i))
(define (sub-interval x y)
  (make-interval (- (lower-bound x) (upper-bound y))
                 (- (upper-bound x) (lower-bound y))))
(sub-interval (make-interval 5 10) (make-interval 1 3))
