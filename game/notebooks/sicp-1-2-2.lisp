;;;; game/notebooks/sicp-1-2-2.lisp --- SICP 1.2.2 Tree Recursion.

(defpackage #:recurya/game/notebooks/sicp-1-2-2
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-1-2-2-notebook))

(in-package #:recurya/game/notebooks/sicp-1-2-2)

(defun make-sicp-1-2-2-notebook ()
  "SICP 1.2.2 - Tree Recursion."
  (make-notebook
   :id :sicp-1-2-2
   :chapter "1.2.2"
   :title "木再帰"
   :summary "Fibonacci 数と count-change を題材に、木再帰がなぜ指数的になるのかを観察する"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "Fibonacci 数列は次のように定義されます:")
                       (:ul
                        (:li (:code "(fib 0) = 0"))
                        (:li (:code "(fib 1) = 1"))
                        (:li (:code "(fib n) = (fib (- n 1)) + (fib (- n 2))")))
                       (:p "素直に再帰へ写すと " (:strong "木再帰") " になります。")))
    (make-cell :id :naive-fib :kind :code-eval
               :body "(define (fib n)
  (if (< n 2)
      n
      (+ (fib (- n 1)) (fib (- n 2)))))
(fib 10)")
    (make-cell :id :tree-prose :kind :prose
               :body '(:div
                       (:p (:code "(fib 5)") " の評価は " (:code "(fib 4)")
                           " と " (:code "(fib 3)")
                           " に分岐し、それぞれがさらに分岐します。"
                           "計算木をなぞると、同じ部分問題を何度も繰り返し解いていることが分かります。")
                       (:p "結果として、計算ステップ数は "
                           (:code "n") " に対して指数的に増えます ("
                           (:strong "Θ(2^n) 程度") ")。"
                           (:code "(fib 30)") " ですらナイーブ実装では時間がかかります。")))
    (make-cell :id :iter-prose :kind :prose
               :body '(:div
                       (:p "同じ Fibonacci を " (:strong "反復プロセス") " で書けば、"
                           (:code "a, b") " を 1 ステップで更新するだけなので"
                           " 線形時間で済みます。")
                       (:p "更新規則は " (:code "(a, b) ← (a + b, a)") " を "
                           (:code "n") " 回繰り返すことです。"
                           "最終的に " (:code "b") " が " (:code "(fib n)") " になります。")))
    (make-cell :id :fast-fib :kind :code-eval
               :body "(define (fib-iter a b cnt)
  (if (= cnt 0)
      b
      (fib-iter (+ a b) a (- cnt 1))))
(define (fib-fast n) (fib-iter 1 0 n))
(fib-fast 30)")
    (make-cell :id :cc-prose :kind :prose
               :body '(:div
                       (:p (:strong "両替の数え上げ (count-change)") ": "
                           "ある金額を硬貨 (1, 5, 10, 25, 50 セント) で支払う"
                           "方法は何通りあるか?")
                       (:p "考え方: 「硬貨の種類が " (:code "kinds") " 種類のときに "
                           (:code "amount") " を作る方法の数」 を、")
                       (:ul
                        (:li (:code "amount = 0") " なら 1 通り (何も払わない)")
                        (:li (:code "amount < 0") " なら 0 通り")
                        (:li (:code "kinds = 0") " なら 0 通り")
                        (:li "それ以外は (一番大きい硬貨を使わない方法の数) + (一番大きい硬貨を 1 枚使った残りを作る方法の数)"))
                       (:p "これも素直に書くと木再帰になります。"
                           "ここでは fuel に収まる小さな入力で動かしてみましょう。")))
    (make-cell :id :cc-eval :kind :code-eval
               :body "(define (first-denomination kinds)
  (cond ((= kinds 1) 1)
        ((= kinds 2) 5)
        ((= kinds 3) 10)
        ((= kinds 4) 25)
        ((= kinds 5) 50)))
(define (cc amount kinds)
  (cond ((= amount 0) 1)
        ((< amount 0) 0)
        ((= kinds 0) 0)
        (t (+ (cc amount (- kinds 1))
              (cc (- amount (first-denomination kinds)) kinds)))))
(define (count-change amount) (cc amount 5))
(count-change 11)")
    (make-cell :id :ex-fib-iter :kind :code-exercise
               :description
               "反復版 fib-iter を内側に閉じ込めた fib-iter-call を書いてください。
内部的に fib-iter を呼ぶ形でも、トップレベルに fib-iter を置く形でも構いません。
最終式として (fib-iter-call 15) を残してください。"
               :body "; (define (fib-iter a b cnt) ...)
; (define (fib-iter-call n) (fib-iter 1 0 n))
; 最後に (fib-iter-call 15)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "610"
                                     :description "fib(15) = 610")))
    (make-cell :id :ex-cc-2 :kind :code-exercise
               :description
               "硬貨が 2 種類 (1 と 5) しかないとき、金額 n を作る方法の数を返す
cc-12 を木再帰で書いてください。
ヒント: 一般の cc を書いて (cc n 2) を呼ぶか、kinds 引数を畳み込んで
(cc-12 amount kinds) のような形にしてください。
最終式として (cc-12-amt 7) のように 7 セントの場合を返す形にし、
答えは 2 (= 7×1 または 1×5+2×1) になります。"
               :body "; 例: 一般化版を書いてから 2 種類で呼ぶ
; (define (cc-12 amount kinds) ...)
; (define (cc-12-amt n) (cc-12 n 2))
; 最後に (cc-12-amt 7)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "2"
                                     :description "1 と 5 で 7 を作る方法 = 2 通り"))))))
