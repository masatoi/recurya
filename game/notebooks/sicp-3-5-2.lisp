;;;; game/notebooks/sicp-3-5-2.lisp --- SICP 3.5.2 Infinite Streams.

(defpackage #:recurya/game/notebooks/sicp-3-5-2
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-3-5-2-notebook))

(in-package #:recurya/game/notebooks/sicp-3-5-2)

(defun make-sicp-3-5-2-notebook ()
  "SICP 3.5.2 - Infinite Streams."
  (make-notebook
   :id :sicp-3-5-2
   :chapter "3.5.2"
   :title "無限ストリーム"
   :summary "無限長のストリームを作る — integers-from / fibs / Eratosthenes の篩。遅延評価のおかげで「末尾を持たない列」を表現できる。stream-take などで先頭だけ取り出せる。"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:strong "SICP 3.5.2")
                           ": 無限ストリームは遅延評価の真骨頂です。")
                       (:p "整数列 1, 2, 3, ... を生成する手続きを書いてみましょう。"
                           " thunk が再帰的に自分自身を呼ぶので、"
                           (:strong "見かけ上は無限")
                           "ですが、"
                           (:code "stream-take")
                           " で取り出した部分しか実際には計算されません。")))
    (make-cell :id :integers-eval :kind :code-eval
               :body "(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (integers-from n)
  (stream-cons n (lambda () (integers-from (+ n 1)))))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(stream-take (integers-from 1) 5)
;; → (1 2 3 4 5)")
    (make-cell :id :fibs-prose :kind :prose
               :body '(:div
                       (:p (:strong "Fibonacci ストリーム")
                           ": "
                           (:code "(fibs-from a b)")
                           " は "
                           (:code "a, b, a+b, b+(a+b), ...")
                           " を返します。")
                       (:p "状態を引数 "
                           (:code "(a b)")
                           " に持つことで、"
                           (:strong "代入なし")
                           "に Fibonacci 列が定義できる。")))
    (make-cell :id :fibs-eval :kind :code-eval
               :body "(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (fibs-from a b)
  (stream-cons a (lambda () (fibs-from b (+ a b)))))
(define fibs (fibs-from 0 1))
(stream-take fibs 10)
;; → (0 1 1 2 3 5 8 13 21 34)")
    (make-cell :id :sieve-prose :kind :prose
               :body '(:div
                       (:p (:strong "Eratosthenes の篩")
                           ": 素数の無限ストリーム。")
                       (:p "整数列 2, 3, 4, ... から、"
                           (:strong "各素数 p の倍数を除外")
                           "していくと、残った先頭は次の素数になる。")
                       (:p "ポイント: "
                           (:code "stream-filter")
                           " も "
                           (:code "stream-cons")
                           " も遅延を保つので、 "
                           (:code "primes")
                           " 自体は無限ストリームのまま。"
                           (:code "stream-take")
                           " で必要な分だけ計算します。")))
    (make-cell :id :sieve-eval :kind :code-eval
               :body "(define (stream-cons a thunk) (cons a thunk))
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
;; → (2 3 5 7 11 13 17 19)")
    (make-cell :id :ex-fibs-take :kind :code-exercise
               :description
               "fibs-from を上記の通り定義し、最初の 7 個の Fibonacci 数を返してください。
最終式: (stream-take (fibs-from 0 1) 7) → (0 1 1 2 3 5 8)"
               :body "(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
;; ここに (fibs-from a b) を書いてください
(stream-take (fibs-from 0 1) 7)"
               :test-cases
               (list (make-test-case
                      :input ""
                      :expected "(0 1 1 2 3 5 8)"
                      :description "Fibonacci 先頭 7 個")))
    (make-cell :id :ex-primes-take :kind :code-exercise
               :description
               "sieve / integers-from / stream-filter を定義し、最初の 5 つの素数を返してください。
最終式: (stream-take (sieve (integers-from 2)) 5) → (2 3 5 7 11)"
               :body "(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
;; ここに integers-from / stream-filter / sieve を書いてください
(stream-take (sieve (integers-from 2)) 5)"
               :test-cases
               (list (make-test-case
                      :input ""
                      :expected "(2 3 5 7 11)"
                      :description "素数先頭 5 個"))))))
