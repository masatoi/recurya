;;;; game/notebooks/sicp-1-1-3.lisp --- SICP 1.1.3 Evaluating Combinations.

(defpackage #:recurya/game/notebooks/sicp-1-1-3
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-1-1-3-notebook))

(in-package #:recurya/game/notebooks/sicp-1-1-3)

(defun make-sicp-1-1-3-notebook ()
  "SICP 1.1.3 - Evaluating Combinations."
  (make-notebook
   :id :sicp-1-1-3
   :chapter "1.1.3"
   :title "演算子の組合せ評価"
   :summary "組合せ (...) の評価ルールと、評価が木構造をなすこと"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:p "組合せ "
                          (:code "(演算子 引数1 引数2 ...)")
                          " の評価は次の二段階からなります:")
               )
    (make-cell :id :rule :kind :prose
               :body '(:ol
                       (:li "各部分式を評価する(演算子も、引数たちも)")
                       (:li "得られた値を用いて、演算子の値を引数の値に適用する")))
    (make-cell :id :combined-example :kind :code-eval
               :body "(+ (* 2 (+ 4 6)) (* 3 5 7))")
    (make-cell :id :tree-note :kind :prose
               :body '(:p "上の式を評価する過程は木の形をしています。"
                          "葉(数値)から値が伝播し、各ノードで演算子が適用されて上へ上へと評価が進みます。"))
    (make-cell :id :ex-fraction :kind :code-exercise
               :description
               "式 (a + b × c) / (d − e) を a=2, b=3, c=4, d=10, e=5 のもとで評価してください。
手続き (f a b c d e) を定義し、 (f 2 3 4 10 5) を最終式として残してください。"
               :body "; ここに書く"
               :test-cases
               (list (make-test-case
                      :input ""
                      :expected "2.8"
                      :description "(2 + 3*4) / (10 - 5) = 14/5 = 2.8"))))))
