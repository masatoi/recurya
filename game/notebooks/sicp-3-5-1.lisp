;;;; game/notebooks/sicp-3-5-1.lisp --- SICP 3.5.1 Streams Are Delayed Lists.

(defpackage #:recurya/game/notebooks/sicp-3-5-1
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-3-5-1-notebook))

(in-package #:recurya/game/notebooks/sicp-3-5-1)

(defun make-sicp-3-5-1-notebook ()
  "SICP 3.5.1 - Streams Are Delayed Lists."
  (make-notebook
   :id :sicp-3-5-1
   :chapter "3.5.1"
   :title "ストリームは遅延リスト"
   :summary "ストリーム(遅延リスト)を導入する。WardLisp には cons-stream/delay/force がないため、明示的な lambda thunk でストリームを構築する。stream-car は通常の car、stream-cdr は thunk を強制評価する。"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:strong "SICP 3.5.1")
                           " はストリーム(遅延リスト)を導入します。原典では "
                           (:code "(cons-stream a b)")
                           " という特殊形式が言語に組み込まれており、 "
                           (:code "b")
                           " の評価を遅延します。")
                       (:pre
                        (:code
                         ";; SICP 原典 (WardLisp では動かない)
(define s (cons-stream 1 (cons-stream 2 (cons-stream 3 the-empty-stream))))"))
                       (:p "WardLisp には "
                           (:code "cons-stream")
                           " も "
                           (:code "delay")
                           " もないので、 "
                           (:strong "明示的に lambda thunk")
                           " を書きます:")
                       (:pre
                        (:code
                         "(define s (cons 1 (lambda () (cons 2 (lambda () (cons 3 (lambda () nil)))))))"))
                       (:p (:code "cdr")
                           " が thunk になっており、"
                           (:code "((cdr s))")
                           " で初めて次の要素が計算される。これが"
                           (:strong "遅延評価")
                           "の核心です。")))
    (make-cell :id :basic-stream :kind :code-eval
               :body "(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-null? s) (null? s))
(define the-empty-stream nil)
(define s (stream-cons 1 (lambda () (stream-cons 2 (lambda () (stream-cons 3 (lambda () the-empty-stream)))))))
(list (stream-car s) (stream-car (stream-cdr s)) (stream-car (stream-cdr (stream-cdr s))))
;; → (1 2 3)")
    (make-cell :id :why-delayed :kind :prose
               :body '(:div
                       (:p (:strong "重要な点")
                           ":")
                       (:ul
                        (:li (:code "s")
                             " を作る時点では "
                             (:code "2")
                             " も "
                             (:code "3")
                             " も "
                             (:strong "まだ評価されていない")
                             "(thunk の中)")
                        (:li (:code "stream-cdr s")
                             " を呼んで初めて thunk が実行され、次の要素が計算される")
                        (:li "これが"
                             (:strong "遅延評価")
                             "(lazy evaluation)の本質"))))
    (make-cell :id :helpers-prose :kind :prose
               :body '(:div
                       (:p (:strong "有限ストリームを構築するヘルパ")
                           ":")
                       (:pre
                        (:code
                         ";; リストからストリームを作る
(define (list->stream xs)
  (if (null? xs)
      the-empty-stream
      (stream-cons (car xs) (lambda () (list->stream (cdr xs))))))"))
                       (:p (:code "stream-take")
                           "(先頭 n 要素のリスト)と "
                           (:code "stream-ref")
                           "(n 番目の要素)もよく使います。")))
    (make-cell :id :helpers-eval :kind :code-eval
               :body "(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-null? s) (null? s))
(define the-empty-stream nil)
(define (list->stream xs)
  (if (null? xs)
      the-empty-stream
      (stream-cons (car xs) (lambda () (list->stream (cdr xs))))))
(define (stream-take s n)
  (if (or (= n 0) (stream-null? s))
      nil
      (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (stream-ref s n)
  (if (= n 0) (stream-car s) (stream-ref (stream-cdr s) (- n 1))))
(define s (list->stream (list 10 20 30 40 50)))
(list (stream-take s 3) (stream-ref s 2))
;; → ((10 20 30) 30)")
    (make-cell :id :merit :kind :prose
               :body '(:div
                       (:p (:strong "遅延評価のメリット")
                           ": 必要な部分だけ計算するので、"
                           (:strong "無限ストリーム")
                           "も扱えます(次節 3.5.2)。リストでは末尾まで全要素を保持しないと作れませんが、ストリームなら "
                           (:code "stream-take 5")
                           " などで先頭だけ取り出すことができます。")))
    (make-cell :id :ex-stream-sum :kind :code-exercise
               :description
               "ストリームの先頭 n 個の合計を返す手続き (stream-sum-take s n) を書いてください。
stream-cons / stream-car / stream-cdr / stream-null? / the-empty-stream / list->stream を上で定義しておきます。
最終式: (stream-sum-take (list->stream (list 1 2 3 4 5)) 4)
1+2+3+4 = 10 を期待します。"
               :body "(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-null? s) (null? s))
(define the-empty-stream nil)
(define (list->stream xs)
  (if (null? xs)
      the-empty-stream
      (stream-cons (car xs) (lambda () (list->stream (cdr xs))))))
;; ここに (stream-sum-take s n) を書いてください
(stream-sum-take (list->stream (list 1 2 3 4 5)) 4)"
               :test-cases
               (list (make-test-case
                      :input ""
                      :expected "10"
                      :description "1+2+3+4 = 10")))
    (make-cell :id :ex-stream-third :kind :code-exercise
               :description
               "ストリーム (a b c d e) の 3 番目の要素 (0-origin で index=2) を取得してください。
stream-ref を使えば 1 行で書けます。最終式: (stream-ref (list->stream (list 'a 'b 'c 'd 'e)) 2)"
               :body "(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-null? s) (null? s))
(define the-empty-stream nil)
(define (list->stream xs)
  (if (null? xs)
      the-empty-stream
      (stream-cons (car xs) (lambda () (list->stream (cdr xs))))))
(define (stream-ref s n)
  (if (= n 0) (stream-car s) (stream-ref (stream-cdr s) (- n 1))))
;; 最終式を書いてください
(stream-ref (list->stream (list 'a 'b 'c 'd 'e)) 2)"
               :test-cases
               (list (make-test-case
                      :input ""
                      :expected "c"
                      :description "3 番目の要素は c"))))))
