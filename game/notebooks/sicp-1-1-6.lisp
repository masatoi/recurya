;;;; game/notebooks/sicp-1-1-6.lisp --- SICP 1.1.6 Conditional Expressions.

(defpackage #:recurya/game/notebooks/sicp-1-1-6
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-1-1-6-notebook))

(in-package #:recurya/game/notebooks/sicp-1-1-6)

(defun make-sicp-1-1-6-notebook ()
  "SICP 1.1.6 - Conditional Expressions and Predicates."
  (make-notebook
   :id :sicp-1-1-6
   :chapter "1.1.6"
   :title "条件式と述語"
   :summary "if / cond / and / or / not で値を場合分けする"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "条件式は、値を場合分けして返すための仕組みです。"
                           (:code "if") "・" (:code "cond")
                           "、論理演算子 " (:code "and") "・"
                           (:code "or") "・" (:code "not") " を使います。")
                       (:p (:strong "WardLisp の真偽値は ")
                           (:code "t") " と " (:code "nil")
                           " です。Scheme の "
                           (:code "#t") "・" (:code "#f")
                           " ではないので注意してください。")))
    (make-cell :id :if-example :kind :code-eval
               :body "(if (> 5 3) 'big 'small)")
    (make-cell :id :cond-prose :kind :prose
               :body '(:div
                       (:p (:code "cond")
                           " は複数の条件節から、最初に真になった節を選びます。"
                           "最後の節は " (:code "(t ...)")
                           " と書くと「それ以外すべて」を意味します。")
                       (:p "Scheme の " (:code "(else ...)")
                           " に相当する書き方が WardLisp では "
                           (:code "(t ...)") " になることに注意してください。")))
    (make-cell :id :sign :kind :code-eval
               :body "(define (sign x)
  (cond ((> x 0) 'positive)
        ((< x 0) 'negative)
        (t       'zero)))
(sign -3)")
    (make-cell :id :logic-prose :kind :prose
               :body '(:p (:code "and") " と " (:code "or") " は短絡評価です。"
                          (:code "not") " は真偽を反転します。"))
    (make-cell :id :logic :kind :code-eval
               :body "(list (and (> 5 3) (< 2 4))
      (or nil 7)
      (not (= 1 2)))")
    (make-cell :id :ex-abs :kind :code-exercise
               :description
               "if を使って絶対値を返す手続き abs-val を定義し、
最終式として (abs-val -7) を残してください。"
               :body "; (define (abs-val x) ...) を書く
; 最後に (abs-val -7)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "7"
                                     :description "|-7| = 7")))
    (make-cell :id :ex-ge :kind :code-exercise
               :description
               "(>= x y) と同じ意味の手続き my-ge? を、 < と not だけを使って定義してください。
最終式として (my-ge? 5 5) を残してください(t になるはずです)。"
               :body "; (define (my-ge? x y) ...) を書く
; 最後に (my-ge? 5 5)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "t"
                                     :description "5 >= 5 は真")))
    (make-cell :id :ex-largest-two :kind :code-exercise
               :description
               "3 つの数 a b c を引数に取り、大きい方 2 つの和を返す手続き
sum-of-two-largest を定義してください。最終式として
 (sum-of-two-largest 3 7 4) を残してください(7 + 4 = 11)。"
               :body "; (define (sum-of-two-largest a b c) ...) を書く
; 最後に (sum-of-two-largest 3 7 4)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "11"
                                     :description "7 と 4 の和"))))))
