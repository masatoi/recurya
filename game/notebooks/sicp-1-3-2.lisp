;;;; game/notebooks/sicp-1-3-2.lisp --- SICP 1.3.2 Lambda + let.

(defpackage #:recurya/game/notebooks/sicp-1-3-2
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-1-3-2-notebook))

(in-package #:recurya/game/notebooks/sicp-1-3-2)

(defun make-sicp-1-3-2-notebook ()
  "SICP 1.3.2 - Lambda expressions and let."
  (make-notebook
   :id :sicp-1-3-2
   :chapter "1.3.2"
   :title "lambda で手続きを構成する"
   :summary "lambda による無名手続きの作成と、let / let* による局所束縛の糖衣構文を学ぶ"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:code "define") " で手続きに名前を付ける必要が"
                           "ない場面では、" (:strong "lambda 式")
                           " で名前を付けずに手続きそのものを作って渡せます。")
                       (:p (:code "(lambda (引数...) 本体...)")
                           " は「引数を受け取って本体を計算する手続き」を返します。"
                           "そのまま関数位置に置けば呼び出せます。")))
    (make-cell :id :lambda-call :kind :code-eval
               :body "((lambda (x) (* x x x)) 4)")
    (make-cell :id :lambda-as-arg :kind :prose
               :body '(:div
                       (:p "前節 1.3.1 の汎用 " (:code "sum")
                           " に渡す項手続きや次手続きも、"
                           (:code "define") " で先に名前を付ける必要はなく、"
                           (:code "lambda") " で直接書けます。")
                       (:p "「平方を 1 から 5 まで足す」だけのために "
                           (:code "square") " と " (:code "inc")
                           " を最上位で定義する必要は必ずしもありません。")))
    (make-cell :id :sum-with-lambda :kind :code-eval
               :body "(define (sum f a next b)
  (if (> a b) 0 (+ (f a) (sum f (next a) next b))))
(sum (lambda (x) (* x x)) 1 (lambda (x) (+ x 1)) 5)")
    (make-cell :id :let-prose :kind :prose
               :body '(:div
                       (:p (:strong "let") " は局所変数を束縛するための式です。"
                           "ですが、これは新しい仕組みではなく、"
                           "実は " (:code "lambda") " の "
                           (:strong "糖衣構文 (syntactic sugar)") " です。")
                       (:p (:code "(let ((x 5) (y 7)) (* x y))")
                           " は内部的には")
                       (:pre "((lambda (x y) (* x y)) 5 7)")
                       (:p "と等価です。"
                           "「先に値を名前に束縛してから本体を評価する」気持ちを、"
                           "より読みやすい構文で書ける、という位置付けです。")))
    (make-cell :id :let-basic :kind :code-eval
               :body "(let ((x 5) (y 7)) (* x y))")
    (make-cell :id :let-star-prose :kind :prose
               :body '(:div
                       (:p "通常の " (:code "let") " では各束縛は "
                           (:strong "並列") " に評価され、"
                           "後の束縛が前の束縛を参照することはできません。")
                       (:p "それに対し " (:code "let*") " は "
                           (:strong "順次束縛") " で、"
                           "前で導入した名前を後の束縛の右辺で使えます。"
                           "中間結果を一段ずつ名前付けしながら計算したい時に便利です。")))
    (make-cell :id :let-star-basic :kind :code-eval
               :body "(let* ((x 5) (y (* x 2)) (z (+ x y))) z)")
    (make-cell :id :ex-lambda-call :kind :code-exercise
               :description
               "lambda 式を直接呼び出す形で、a^2 + b^2 + c^2 を計算してください。
具体的には ((lambda (a b c) ...) 1 2 3) を最終式として残し、答えが
1*1 + 2*2 + 3*3 = 14 となるようにします。define は使わなくて構いません。"
               :body "; ((lambda (a b c) ...) 1 2 3)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "14"
                                     :description "1+4+9 = 14")))
    (make-cell :id :ex-let-quad :kind :code-exercise
               :description
               "f(x, y) = x^2 + 2*x*y + y^2 + x + y を let* を使って計算する手続き
(quadratic x y) を書いてください。中間結果 (x の二乗、y の二乗、2xy、x+y) を
let* で順番に名前付けしながら最終値を返す形にします。
最終式として (quadratic 3 4) を残してください。
答え: 9 + 24 + 16 + 3 + 4 = 56"
               :body "; (define (quadratic x y)
;   (let* ((sq-x ...)
;          (sq-y ...)
;          (cross ...)
;          (sum-xy ...))
;     (+ sq-x cross sq-y sum-xy)))
; 最後に (quadratic 3 4)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "56"
                                     :description "(quadratic 3 4) = 56"))))))
