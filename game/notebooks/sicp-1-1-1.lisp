;;;; game/notebooks/sicp-1-1-1.lisp --- SICP 1.1.1 Expressions.

(defpackage #:recurya/game/notebooks/sicp-1-1-1
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-1-1-1-notebook))

(in-package #:recurya/game/notebooks/sicp-1-1-1)

(defun make-sicp-1-1-1-notebook ()
  "SICP 1.1.1 - Expressions."
  (make-notebook
   :id :sicp-1-1-1
   :chapter "1.1.1"
   :title "式"
   :summary "数値リテラル、プレフィックス記法、入れ子の式を触れる"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:p "Lispプログラムは"
                          (:em "式") "を書いて評価することで動きます。"
                          "この節では最も基本的な式から始めます。"))
    (make-cell :id :num :kind :code-eval
               :body "486")
    (make-cell :id :prefix :kind :prose
               :body '(:p "関数呼び出しはすべて"
                          (:strong "プレフィックス記法")
                          "で書きます。演算子が先、引数が続きます。"))
    (make-cell :id :add :kind :code-eval
               :body "(+ 137 349)")
    (make-cell :id :more-arith :kind :code-eval
               :body "(- 1000 334)
(* 5 99)
(/ 10 5)")
    (make-cell :id :nested-prose :kind :prose
               :body '(:p "式は入れ子にできます。各括弧の内側から評価されます。"))
    (make-cell :id :nested :kind :code-eval
               :body "(+ (* 3 5) (- 10 6))")
    (make-cell :id :ex-sum3 :kind :code-exercise
               :description "137、349、22 の合計を求める式を書いてください。"
               :body "; ここに式を書く"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "508"
                                     :description "三項の和"))))))
