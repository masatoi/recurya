===prose===
**SICP 3.5.3**: ストリーム上の高階操作で、リストと同じパターン(`map` / `filter` / `accumulate`)を**遅延的に**適用できます。

ストリームは「無限のリスト」と思える抽象を提供します。ただし計算は必要な分しか走らないので、`(integers-from 1)` のような無限ストリームを map / filter してから `stream-take` で必要な数だけ取れます。

===eval===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (integers-from n) (stream-cons n (lambda () (integers-from (+ n 1)))))
(define (stream-map f s)
  (if (null? s)
      nil
      (stream-cons (f (stream-car s)) (lambda () (stream-map f (stream-cdr s))))))
(define squares (stream-map (lambda (x) (* x x)) (integers-from 1)))
(stream-take squares 5)
;; → (1 4 9 16 25)

===prose===
**組み合わせ**: 偶数の二乗。 `stream-filter` で偶数だけ残し、 `stream-map` で二乗。

リストの `(map sq (filter even? (range 1 ..)))` とまったく同じ形を、無限ストリームに対して書けます。

===eval===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (integers-from n) (stream-cons n (lambda () (integers-from (+ n 1)))))
(define (stream-map f s)
  (if (null? s) nil (stream-cons (f (stream-car s)) (lambda () (stream-map f (stream-cdr s))))))
(define (stream-filter p s)
  (cond ((null? s) nil)
        ((p (stream-car s)) (stream-cons (stream-car s) (lambda () (stream-filter p (stream-cdr s)))))
        (t (stream-filter p (stream-cdr s)))))
(define even-squares
  (stream-map (lambda (x) (* x x))
              (stream-filter (lambda (x) (= 0 (mod x 2))) (integers-from 1))))
(stream-take even-squares 5)
;; → (4 16 36 64 100)

===prose===
**遅延の利点**: `(integers-from 1)` は無限ストリームだが、 `stream-take 5` までしか実際には評価されない。

Haskell や他の遅延言語と同じパラダイムで、**無限を有限に絞り込む**プログラミングが自然にできる。

===exercise: (integers-from 1) の各要素を 3 乗にする cube-stream を作り、先頭 4 個を返してください。 stream-cons / stream-car / stream-cdr / stream-take / integers-from / stream-map を上で定義しておきます。 最終式: (stream-take cube-stream 4) → (1 8 27 64)===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (integers-from n) (stream-cons n (lambda () (integers-from (+ n 1)))))
(define (stream-map f s)
  (if (null? s) nil (stream-cons (f (stream-car s)) (lambda () (stream-map f (stream-cdr s))))))
;; ここで cube-stream を定義してください
(define cube-stream (stream-map (lambda (x) (* x x x)) (integers-from 1)))
(stream-take cube-stream 4)

===expect: 立方数 先頭 4 個===
(1 8 27 64)

===solution: (integers-from 1) の各要素を 3 乗にする cube-stream を作り、先頭 4 個を返してください。 stream-cons / stream-car / stream-cdr / stream-take / integers-from / stream-map を上で定義しておきます。 最終式: (stream-take cube-stream 4) → (1 8 27 64)===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (integers-from n) (stream-cons n (lambda () (integers-from (+ n 1)))))
(define (stream-map f s)
  (if (null? s) nil (stream-cons (f (stream-car s)) (lambda () (stream-map f (stream-cdr s))))))
(define cube-stream (stream-map (lambda (x) (* x x x)) (integers-from 1)))
(stream-take cube-stream 4)

===exercise: 奇数の二乗ストリームの先頭 5 個を返してください。 stream-filter で奇数だけ残し、stream-map で二乗します。 最終式: (stream-take (stream-map (lambda (x) (* x x)) (stream-filter (lambda (x) (= 1 (mod x 2))) (integers-from 1))) 5)===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (integers-from n) (stream-cons n (lambda () (integers-from (+ n 1)))))
(define (stream-map f s)
  (if (null? s) nil (stream-cons (f (stream-car s)) (lambda () (stream-map f (stream-cdr s))))))
(define (stream-filter p s)
  (cond ((null? s) nil)
        ((p (stream-car s)) (stream-cons (stream-car s) (lambda () (stream-filter p (stream-cdr s)))))
        (t (stream-filter p (stream-cdr s)))))
;; 最終式を書いてください
(stream-take (stream-map (lambda (x) (* x x)) (stream-filter (lambda (x) (= 1 (mod x 2))) (integers-from 1))) 5)

===expect: 奇数の二乗 先頭 5 個===
(1 9 25 49 81)

===solution: 奇数の二乗ストリームの先頭 5 個を返してください。 stream-filter で奇数だけ残し、stream-map で二乗します。 最終式: (stream-take (stream-map (lambda (x) (* x x)) (stream-filter (lambda (x) (= 1 (mod x 2))) (integers-from 1))) 5)===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (integers-from n) (stream-cons n (lambda () (integers-from (+ n 1)))))
(define (stream-map f s)
  (if (null? s) nil (stream-cons (f (stream-car s)) (lambda () (stream-map f (stream-cdr s))))))
(define (stream-filter p s)
  (cond ((null? s) nil)
        ((p (stream-car s)) (stream-cons (stream-car s) (lambda () (stream-filter p (stream-cdr s)))))
        (t (stream-filter p (stream-cdr s)))))
(stream-take (stream-map (lambda (x) (* x x)) (stream-filter (lambda (x) (= 1 (mod x 2))) (integers-from 1))) 5)
