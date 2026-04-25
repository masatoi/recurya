;;;; game/notebooks/sicp-1-1-4.lisp --- SICP 1.1.4 Compound Procedures.

(defpackage #:recurya/game/notebooks/sicp-1-1-4
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-1-1-4-notebook))

(in-package #:recurya/game/notebooks/sicp-1-1-4)

(defun make-sicp-1-1-4-notebook ()
  "SICP 1.1.4 - Compound Procedures."
  (make-notebook
   :id :sicp-1-1-4
   :chapter "1.1.4"
   :title "複合手続き"
   :summary "define で手続きに名前を付け、計算のパターンを再利用する"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:p "これまで個々の式を評価してきました。次は"
                          (:strong "手続き") "(procedure) を定義し、"
                          "計算のパターンに名前を付けます。"
                          (:code "(define (f x) ...)")
                          " の形で、引数を取って値を返す手続きを作れます。"))
    (make-cell :id :square :kind :code-eval
               :body "(define (square x) (* x x))
(square 5)")
    (make-cell :id :compose-prose :kind :prose
               :body '(:p "一度定義した手続きは、他の手続きの中から呼び出して"
                          "より複雑な計算を組み立てられます。"))
    (make-cell :id :sum-of-squares :kind :code-eval
               :body "(define (square x) (* x x))
(define (sum-of-squares x y) (+ (square x) (square y)))
(sum-of-squares 3 4)")
    (make-cell :id :ex-prose :kind :prose
               :body '(:p "練習: 手続きを組み合わせて問題を解いてみましょう。"))
    (make-cell :id :ex-f :kind :code-exercise
               :description
               "次の式を計算する手続き f を定義してください:
  (f a) = a × (1 + a) + (1 - a)
そして (f 3) を最終式として残してください。"
               :body "; (define (f a) ...) を書く
; 最後に (f 3)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "10"
                                     :description "(f 3) = 3*4 + (-2) = 10")))
    (make-cell :id :ex-power :kind :code-exercise
               :description
               "square を使って4乗を返す手続き power-fourth を定義してください。
たとえば (power-fourth 3) は 81 です。最終式として (power-fourth 3) を残してください。"
               :body "; (define (square x) ...) を書いてから
; (define (power-fourth x) ...) を square を使って書く
; 最後に (power-fourth 3)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "81"
                                     :description "3 の 4 乗は 81"))))))
