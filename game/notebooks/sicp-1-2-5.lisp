;;;; game/notebooks/sicp-1-2-5.lisp --- SICP 1.2.5 Greatest Common Divisors.

(defpackage #:recurya/game/notebooks/sicp-1-2-5
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-1-2-5-notebook))

(in-package #:recurya/game/notebooks/sicp-1-2-5)

(defun make-sicp-1-2-5-notebook ()
  "SICP 1.2.5 - Greatest Common Divisors."
  (make-notebook
   :id :sicp-1-2-5
   :chapter "1.2.5"
   :title "最大公約数"
   :summary "ユークリッドの互除法による gcd と、その対数オーダな性質"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:code "(gcd a b)") " は 2 つの整数 "
                           (:code "a") " と " (:code "b")
                           " の " (:strong "最大公約数")
                           " (Greatest Common Divisor) を返す手続きです。")
                       (:p "ユークリッド (Euclid) の鋭い観察:")
                       (:ul
                        (:li (:code "gcd(a, b) = gcd(b, a mod b)"))
                        (:li (:code "gcd(a, 0) = a")))
                       (:p "この 2 つの規則を再帰的に適用するだけで、"
                           "最大公約数が求まります。")))
    (make-cell :id :ward-note :kind :prose
               :body '(:div
                       (:p (:strong "WardLisp 注記") ": "
                           "SICP 原典では " (:code "remainder") " を使いますが、"
                           "WardLisp では " (:code "mod") " を使います。"
                           "正の引数の範囲ではどちらも同じ結果になります。")))
    (make-cell :id :gcd-def :kind :code-eval
               :body "(define (gcd a b)
  (if (= b 0)
      a
      (gcd b (mod a b))))
(gcd 206 40)")
    (make-cell :id :lame-prose :kind :prose
               :body '(:div
                       (:p (:strong "Lamé の定理") ": "
                           "ユークリッドの互除法が " (:code "k") " ステップで終わるとき、"
                           (:code "b ≥ Fib(k)")
                           " (フィボナッチ数列の k 番目以上) が成り立ちます。")
                       (:p "フィボナッチ数列は指数的に増えるので、"
                           "逆に言えば " (:code "gcd")
                           " のステップ数は入力 " (:code "b")
                           " の桁数 (= " (:code "log b")
                           ") に対して " (:strong "Θ(log n)")
                           " で抑えられます。"
                           "非常に高速です。")))
    (make-cell :id :ex-gcd-large :kind :code-exercise
               :description
               "(gcd 1071 462) を計算してください。
ユークリッドの互除法をそのまま定義し、最終式として (gcd 1071 462) を残します。
答え: 21"
               :body "; (define (gcd a b) ...)
; 最後に (gcd 1071 462)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "21"
                                     :description "gcd(1071, 462) = 21")))
    (make-cell :id :ex-lcm :kind :code-exercise
               :description
               "最小公倍数 lcm は (lcm a b) = (a * b) / (gcd a b) で求まります。
gcd を使って lcm を定義し、最終式として (lcm 12 18) を残してください。
答え: lcm(12, 18) = 36"
               :body "; (define (gcd a b) ...)
; (define (lcm a b) ...)
; 最後に (lcm 12 18)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "36"
                                     :description "lcm(12, 18) = 36"))))))
