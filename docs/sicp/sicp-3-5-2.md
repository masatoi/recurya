===prose===
**SICP 3.5.2**: 無限ストリームは遅延評価の真骨頂です。

整数列 1, 2, 3, ... を生成する手続きを書いてみましょう。 thunk が再帰的に自分自身を呼ぶので、**見かけ上は無限**ですが、`stream-take` で取り出した部分しか実際には計算されません。

===eval===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (integers-from n)
  (stream-cons n (lambda () (integers-from (+ n 1)))))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(stream-take (integers-from 1) 5)
;; → (1 2 3 4 5)

===prose===
**Fibonacci ストリーム**: `(fibs-from a b)` は `a, b, a+b, b+(a+b), ...` を返します。

状態を引数 `(a b)` に持つことで、**代入なし**に Fibonacci 列が定義できる。

===eval===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (fibs-from a b)
  (stream-cons a (lambda () (fibs-from b (+ a b)))))
(define fibs (fibs-from 0 1))
(stream-take fibs 10)
;; → (0 1 1 2 3 5 8 13 21 34)

===prose===
**Eratosthenes の篩**: 素数の無限ストリーム。

整数列 2, 3, 4, ... から、**各素数 p の倍数を除外**していくと、残った先頭は次の素数になる。

ポイント: `stream-filter` も `stream-cons` も遅延を保つので、 `primes` 自体は無限ストリームのまま。`stream-take` で必要な分だけ計算します。

===eval===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (integers-from n) (stream-cons n (lambda () (integers-from (+ n 1)))))
(define (stream-filter p s)
  (cond ((null? s) nil)
        ((p (stream-car s)) (stream-cons (stream-car s) (lambda () (stream-filter p (stream-cdr s)))))
        (t (stream-filter p (stream-cdr s)))))
(define (sieve s)
  (stream-cons (stream-car s)
    (lambda ()
      (sieve (stream-filter
               (lambda (x) (not (= 0 (mod x (stream-car s)))))
               (stream-cdr s))))))
(define primes (sieve (integers-from 2)))
(stream-take primes 8)
;; → (2 3 5 7 11 13 17 19)

===exercise: fibs-from を上記の通り定義し、最初の 7 個の Fibonacci 数を返してください。 最終式: (stream-take (fibs-from 0 1) 7) → (0 1 1 2 3 5 8)===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
;; ここに (fibs-from a b) を書いてください
(stream-take (fibs-from 0 1) 7)

===expect: Fibonacci 先頭 7 個===
(0 1 1 2 3 5 8)

===solution: fibs-from を上記の通り定義し、最初の 7 個の Fibonacci 数を返してください。 最終式: (stream-take (fibs-from 0 1) 7) → (0 1 1 2 3 5 8)===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (fibs-from a b)
  (stream-cons a (lambda () (fibs-from b (+ a b)))))
(stream-take (fibs-from 0 1) 7)

===exercise: sieve / integers-from / stream-filter を定義し、最初の 5 つの素数を返してください。 最終式: (stream-take (sieve (integers-from 2)) 5) → (2 3 5 7 11)===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
;; ここに integers-from / stream-filter / sieve を書いてください
(stream-take (sieve (integers-from 2)) 5)

===expect: 素数先頭 5 個===
(2 3 5 7 11)

===solution: sieve / integers-from / stream-filter を定義し、最初の 5 つの素数を返してください。 最終式: (stream-take (sieve (integers-from 2)) 5) → (2 3 5 7 11)===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (integers-from n) (stream-cons n (lambda () (integers-from (+ n 1)))))
(define (stream-filter p s)
  (cond ((null? s) nil)
        ((p (stream-car s)) (stream-cons (stream-car s) (lambda () (stream-filter p (stream-cdr s)))))
        (t (stream-filter p (stream-cdr s)))))
(define (sieve s)
  (stream-cons (stream-car s)
    (lambda ()
      (sieve (stream-filter
               (lambda (x) (not (= 0 (mod x (stream-car s)))))
               (stream-cdr s))))))
(stream-take (sieve (integers-from 2)) 5)
