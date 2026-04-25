;;;; game/notebooks/sicp-1-2-4.lisp --- SICP 1.2.4 Exponentiation.

(defpackage #:recurya/game/notebooks/sicp-1-2-4
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-1-2-4-notebook))

(in-package #:recurya/game/notebooks/sicp-1-2-4)

(defun make-sicp-1-2-4-notebook ()
  "SICP 1.2.4 - Exponentiation."
  (make-notebook
   :id :sicp-1-2-4
   :chapter "1.2.4"
   :title "累乗"
   :summary "線形再帰・線形反復・対数時間 fast-expt の 3 つの累乗実装を比較する"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:code "b^n") " (b の n 乗) を計算する素朴な再帰は次の漸化式に基づきます:")
                       (:ul
                        (:li (:code "b^n = b * b^(n-1)"))
                        (:li (:code "b^0 = 1")))
                       (:p "この定義をそのまま手続きにすると、"
                           (:strong "時間 Θ(n)")
                           "・"
                           (:strong "空間 Θ(n)")
                           " になります (再帰呼び出しがスタックに積まれるため)。")))
    (make-cell :id :linear-recursive :kind :code-eval
               :body "(define (expt b n)
  (if (= n 0)
      1
      (* b (expt b (- n 1)))))
(expt 2 10)")
    (make-cell :id :iter-prose :kind :prose
               :body '(:div
                       (:p "アキュムレータを 1 つ持ち回す反復版に書き直すと、"
                           "スタックを使わない " (:strong "時間 Θ(n)・空間 Θ(1)")
                           " の手続きになります。")
                       (:p "考え方: " (:code "product") " に途中までの積を貯めながら、"
                           (:code "counter") " を 0 まで減らします。")))
    (make-cell :id :linear-iter :kind :code-eval
               :body "(define (expt-iter b counter product)
  (if (= counter 0)
      product
      (expt-iter b (- counter 1) (* b product))))
(define (expt-fast b n) (expt-iter b n 1))
(expt-fast 2 10)")
    (make-cell :id :faster-prose :kind :prose
               :body '(:div
                       (:p (:strong "もっと速くできます") "。"
                           "次の事実に注目しましょう:")
                       (:ul
                        (:li (:code "n") " が偶数なら "
                             (:code "b^n = (b^(n/2))^2"))
                        (:li (:code "n") " が奇数なら "
                             (:code "b^n = b * b^(n-1)")))
                       (:p "偶数のステップで指数 " (:code "n")
                           " が一気に半分になるので、"
                           "全体のステップ数は " (:strong "Θ(log n)")
                           " に抑えられます。")
                       (:p "たとえば " (:code "2^16") " は "
                           (:code "2^16 = (2^8)^2 = ((2^4)^2)^2 = (((2^2)^2)^2)^2")
                           " と 4 回の二乗で計算できます。")))
    (make-cell :id :ward-note :kind :prose
               :body '(:div
                       (:p (:strong "WardLisp 注記") ": "
                           (:code "even?") " は組み込みではないので、"
                           "自分で定義します:")
                       (:ul
                        (:li (:code "(define (even? n) (= (mod n 2) 0))"))
                        (:li "SICP 原典の " (:code "remainder")
                             " の代わりに " (:code "mod") " を使います。"
                             "正の引数では同じ結果になります。")
                        (:li "また " (:code "else") " の代わりに "
                             (:code "(t ...)") " を使います。"))))
    (make-cell :id :fast-expt :kind :code-eval
               :body "(define (even? n) (= (mod n 2) 0))
(define (square x) (* x x))
(define (fast-expt b n)
  (cond ((= n 0) 1)
        ((even? n) (square (fast-expt b (/ n 2))))
        (t (* b (fast-expt b (- n 1))))))
(fast-expt 2 16)")
    (make-cell :id :ex-fast-expt :kind :code-exercise
               :description
               "上で定義した fast-expt を使って (fast-expt 3 12) を計算してください。
even?, square, fast-expt の 3 つを定義してから、最終式に (fast-expt 3 12) を残します。
答え: 3^12 = 531441"
               :body "; (define (even? n) ...)
; (define (square x) ...)
; (define (fast-expt b n) ...)
; 最後に (fast-expt 3 12)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "531441"
                                     :description "3^12 = 531441")))
    (make-cell :id :ex-expt-mul :kind :code-exercise
               :description
               "乗算 * を使わず、加算 + の繰り返しだけで (my-mul a b) を線形反復で書いてください。
SICP 1.18 の簡略版です。a を b 回足し合わせる気持ちで、アキュムレータを使います。
最終式として (my-mul 7 9) を残してください。
答え: 7 * 9 = 63"
               :body "; (define (my-mul-iter a b acc) ...)
; (define (my-mul a b) ...)
; 最後に (my-mul 7 9)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "63"
                                     :description "7 * 9 = 63 を加算反復で"))))))
