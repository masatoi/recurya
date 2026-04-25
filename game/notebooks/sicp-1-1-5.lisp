;;;; game/notebooks/sicp-1-1-5.lisp --- SICP 1.1.5 Substitution Model.

(defpackage #:recurya/game/notebooks/sicp-1-1-5
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-1-1-5-notebook))

(in-package #:recurya/game/notebooks/sicp-1-1-5)

(defun make-sicp-1-1-5-notebook ()
  "SICP 1.1.5 - Substitution Model for Procedure Application."
  (make-notebook
   :id :sicp-1-1-5
   :chapter "1.1.5"
   :title "手続き適用の置換モデル"
   :summary "手続き呼び出しを「引数の値で本体を置き換える」と考える"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:p "手続き " (:code "(define (f x) body)")
                          " を呼び出すとき、評価器は本体 "
                          (:code "body") " 中の "
                          (:code "x") " を引数の値で置き換え、その式を評価します。"
                          "これを" (:strong "置換モデル") "と呼びます。"))
    (make-cell :id :compute :kind :code-eval
               :body "(define (square x) (* x x))
(define (sum-of-squares x y) (+ (square x) (square y)))
(define (f a) (sum-of-squares (+ a 1) (* a 2)))
(f 5)")
    (make-cell :id :trace :kind :prose
               :body '(:div
                       (:p "上の (f 5) を置換で展開すると次のように評価が進みます:")
                       (:pre
"(f 5)
(sum-of-squares (+ 5 1) (* 5 2))
(sum-of-squares 6 10)
(+ (square 6) (square 10))
(+ (* 6 6) (* 10 10))
(+ 36 100)
136")))
    (make-cell :id :order-prose :kind :prose
               :body '(:div
                       (:p (:strong "適用順序") "(applicative order)では、引数を"
                           (:em "先に評価して値にしてから") "本体に代入します。")
                       (:p (:strong "通常順序") "(normal order)では、引数の式を"
                           (:em "そのまま") "本体に代入し、必要になったときに展開します。")
                       (:p "WardLisp は適用順序を採用しています。")))
    (make-cell :id :loop-defs :kind :code-eval
               :body "(define (p) (p))
(define (test x y) (if (= x 0) 0 y))")
    (make-cell :id :loop-discuss :kind :prose
               :body '(:p "もしここで " (:code "(test 0 (p))")
                          " を評価すると、適用順序では "
                          (:code "(p)") " を先に評価しようとして無限ループに陥ります。"
                          "通常順序では " (:code "x = 0")
                          " のチェックが先に行われるので "
                          (:code "(p)") " は評価されません。"
                          "(このセル自身は定義だけで止めています。)"))
    (make-cell :id :ex-trace :kind :code-exercise
               :description
               "次の手続きを定義して (a-plus-abs-b 3 -5) の値を求めてください。
  (define (a-plus-abs-b a b) ((if (> b 0) + -) a b))
最終式として (a-plus-abs-b 3 -5) を残してください。
(SICP の演習 1.4 と同じ。条件式が手続きの位置に来ています。)"
               :body "; ここに定義と呼び出しを書く
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "8"
                                     :description "3 + |-5| = 8"))))))
