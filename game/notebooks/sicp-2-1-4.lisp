;;;; game/notebooks/sicp-2-1-4.lisp --- SICP 2.1.4 Interval Arithmetic.

(defpackage #:recurya/game/notebooks/sicp-2-1-4
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-2-1-4-notebook))

(in-package #:recurya/game/notebooks/sicp-2-1-4)

(defun make-sicp-2-1-4-notebook ()
  "SICP 2.1.4 - Interval Arithmetic."
  (make-notebook
   :id :sicp-2-1-4
   :chapter "2.1.4"
   :title "区間算術"
   :summary "誤差を伴う値を区間 [lo, hi] として表し、加算・乗算・減算を区間として組み立てる"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "測定値はしばしば誤差を伴います。"
                           "抵抗値 6.8 オーム ± 10% のように、"
                           "値が「ある範囲のどこか」にあることだけ分かっていて、"
                           "正確な値は分からない、ということがよくあります。")
                       (:p "そこで、各値を "
                           (:strong "区間 [lo, hi]")
                           " で表し、計算結果も区間として求めるしくみを作ります。"
                           "これは "
                           (:strong "抽象データ")
                           " の良い実例で、"
                           "前節までの「構築子と選択子で抽象化する」"
                           "パターンがそのまま使えます。")))
    (make-cell :id :ctor-prose :kind :prose
               :body '(:div
                       (:p "まず構築子と選択子を定義します。"
                           "区間は単なる数のペアです。")))
    (make-cell :id :ctor-code :kind :code-eval
               :body "(define (make-interval lo hi) (cons lo hi))
(define (lower-bound i) (car i))
(define (upper-bound i) (cdr i))
(define i (make-interval 6.12 7.48))
(list (lower-bound i) (upper-bound i))")
    (make-cell :id :add-prose :kind :prose
               :body '(:div
                       (:p (:strong "加算")
                           ": 区間 " (:code "[a, b]") " と "
                           (:code "[c, d]") " の和は "
                           (:code "[a+c, b+d]")
                           " 。両端をそれぞれ足すだけです。")))
    (make-cell :id :add-code :kind :code-eval
               :body "(define (make-interval lo hi) (cons lo hi))
(define (lower-bound i) (car i))
(define (upper-bound i) (cdr i))
(define (add-interval x y)
  (make-interval (+ (lower-bound x) (lower-bound y))
                 (+ (upper-bound x) (upper-bound y))))
(add-interval (make-interval 1.0 2.0) (make-interval 3.0 5.0))")
    (make-cell :id :mul-prose :kind :prose
               :body '(:div
                       (:p (:strong "乗算")
                           ": 端点同士の積は最大 4 通り考えられます ("
                           (:code "lo*lo, lo*hi, hi*lo, hi*hi")
                           ")。負の数が混じる場合もあるので、"
                           "結果の区間は "
                           (:strong "4 つの積の最小値と最大値")
                           " を取って作ります。")))
    (make-cell :id :mul-code :kind :code-eval
               :body "(define (make-interval lo hi) (cons lo hi))
(define (lower-bound i) (car i))
(define (upper-bound i) (cdr i))
(define (my-min a b) (if (< a b) a b))
(define (my-max a b) (if (> a b) a b))
(define (mul-interval x y)
  (let ((p1 (* (lower-bound x) (lower-bound y)))
        (p2 (* (lower-bound x) (upper-bound y)))
        (p3 (* (upper-bound x) (lower-bound y)))
        (p4 (* (upper-bound x) (upper-bound y))))
    (make-interval (my-min (my-min p1 p2) (my-min p3 p4))
                   (my-max (my-max p1 p2) (my-max p3 p4)))))
(mul-interval (make-interval 2 3) (make-interval 4 5))")
    (make-cell :id :ex-width :kind :code-exercise
               :description
               "区間の幅 (width i) を返す手続きを書いてください。
幅は (上端 - 下端) / 2 と定義します (中心からの誤差幅)。
make-interval / lower-bound / upper-bound は自分でセル内に再定義し、
最終式として (width (make-interval 4 10)) を残してください。
答えは 3 になります。"
               :body "; (define (make-interval lo hi) ...)
; (define (lower-bound i) ...)
; (define (upper-bound i) ...)
; (define (width i) ...)
; 最後に (width (make-interval 4 10))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "3"
                                     :description "区間 [4,10] の幅は (10-4)/2 = 3")))
    (make-cell :id :ex-sub-interval :kind :code-exercise
               :description
               "区間の差 (sub-interval x y) を書いてください。
区間 [a, b] から区間 [c, d] を引いた結果は、
最小は a-d、最大は b-c なので [a-d, b-c] になります。
make-interval / lower-bound / upper-bound はセル内に再定義してください。
最終式として
  (sub-interval (make-interval 5 10) (make-interval 1 3))
を残してください。結果は (2 . 9) になります。"
               :body "; (define (make-interval lo hi) ...)
; (define (lower-bound i) ...)
; (define (upper-bound i) ...)
; (define (sub-interval x y) ...)
; 最後に (sub-interval (make-interval 5 10) (make-interval 1 3))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "(2 . 9)"
                                     :description "[5,10] - [1,3] = [2,9]"))))))
