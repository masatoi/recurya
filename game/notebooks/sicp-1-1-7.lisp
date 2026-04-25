;;;; game/notebooks/sicp-1-1-7.lisp --- SICP 1.1.7 Square Roots by Newton's Method.

(defpackage #:recurya/game/notebooks/sicp-1-1-7
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-1-1-7-notebook))

(in-package #:recurya/game/notebooks/sicp-1-1-7)

(defun make-sicp-1-1-7-notebook ()
  "SICP 1.1.7 - Square Roots by Newton's Method."
  (make-notebook
   :id :sicp-1-1-7
   :chapter "1.1.7"
   :title "Newton 法による平方根"
   :summary "推測を繰り返し改善して平方根を求める非自明な再帰を組み立てる"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "平方根の数学的定義は、"
                           (:code "x = sqrt(y)") " ⟺ "
                           (:code "x ≥ 0") " かつ " (:code "x*x = y")
                           " です。これは "
                           (:strong "x が何であるか") " を述べていますが、"
                           (:strong "y から x をどう計算するか")
                           " を直接は教えてくれません。")
                       (:p "Newton 法は、推測 " (:code "g") " を改善する反復で根に近づく方法です。"
                           "改善ステップは " (:code "g <- (g + y/g)/2")
                           " で、これを十分よい近似が得られるまで繰り返します。")))
    (make-cell :id :helpers-prose :kind :prose
               :body '(:div
                       (:p "まず近似誤差を判定する " (:code "good-enough?")
                           " と改善ステップ " (:code "improve") " を書きます。")
                       (:p (:strong "WardLisp に組み込みの ") (:code "abs")
                           (:strong " はないので、自分で ")
                           (:code "abs-val")
                           (:strong " を定義します。"))))
    (make-cell :id :good-enough-example :kind :code-eval
               :body "(define (abs-val x) (if (< x 0) (- 0 x) x))
(define (square x) (* x x))
(define (good-enough? guess x)
  (< (abs-val (- (square guess) x)) 0.001))
(good-enough? 1.4 2)")
    (make-cell :id :improve-example :kind :code-eval
               :body "(define (improve guess x) (/ (+ guess (/ x guess)) 2))
(improve 1.0 2)")
    (make-cell :id :sqrt-iter-prose :kind :prose
               :body '(:p "これらの部品を組み合わせて、推測を更新し続ける "
                          (:code "sqrt-iter") " を作ります。"
                          "判定が真になるまで自分自身を呼び続けるのがポイントです。"))
    (make-cell :id :sqrt-iter :kind :code-eval
               :body "(define (abs-val x) (if (< x 0) (- 0 x) x))
(define (square x) (* x x))
(define (good-enough? guess x)
  (< (abs-val (- (square guess) x)) 0.001))
(define (improve guess x) (/ (+ guess (/ x guess)) 2))
(define (sqrt-iter guess x)
  (if (good-enough? guess x)
      guess
      (sqrt-iter (improve guess x) x)))
(define (sqrt-y x) (sqrt-iter 1.0 x))
(sqrt-y 9)")
    (make-cell :id :ex-sqrt2 :kind :code-exercise
               :description
               "上で定義した sqrt-y を使って sqrt(2) を計算してください。
最終式として (sqrt-y 2) を残してください。"
               :body "; 最後に (sqrt-y 2) を評価する
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "1.4142156862745097"
                                     :description "sqrt(2) の Newton 近似")))
    (make-cell :id :ex-cube-root :kind :code-exercise
               :description
               "立方根 cbrt を Newton 法で書いてください。
立方根の改善ステップは g <- (x/g^2 + 2g)/3 です。
abs-val・square・cube・good-enough?・improve・cbrt-iter・cbrt を
すべて定義し、最終式として (cbrt 27) を残してください。"
               :body "; (define (abs-val x) ...)
; (define (square x) ...)
; (define (cube x) ...)
; (define (good-enough? guess x) ...)   ; cube guess と x を比較する
; (define (improve guess x) ...)        ; (/ (+ (/ x (square guess)) (* 2 guess)) 3)
; (define (cbrt-iter guess x) ...)
; (define (cbrt x) (cbrt-iter 1.0 x))
; 最後に (cbrt 27)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "3.0000005410641766"
                                     :description "27 の立方根の Newton 近似"))))))
