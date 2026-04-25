;;;; game/notebooks/sicp-1-1-8.lisp --- SICP 1.1.8 Procedures as Black-Box Abstractions.

(defpackage #:recurya/game/notebooks/sicp-1-1-8
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-1-1-8-notebook))

(in-package #:recurya/game/notebooks/sicp-1-1-8)

(defun make-sicp-1-1-8-notebook ()
  "SICP 1.1.8 - Procedures as Black-Box Abstractions."
  (make-notebook
   :id :sicp-1-1-8
   :chapter "1.1.8"
   :title "ブラックボックス抽象"
   :summary "内部定義とレキシカルスコープで実装詳細を関数の中に閉じ込める"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "前節の " (:code "sqrt-y") " は "
                           (:code "square") "・" (:code "good-enough?")
                           "・" (:code "improve") "・" (:code "sqrt-iter")
                           " という 4 つの補助手続きを大域に晒していました。")
                       (:p "しかし、これらは "
                           (:code "sqrt-y") " の "
                           (:strong "実装詳細")
                           " であって、外から見えなくても何も困りません。"
                           (:strong "内部定義 (internal define)")
                           " で、これらを関数の中に閉じ込めましょう。")))
    (make-cell :id :internal-sqrt :kind :code-eval
               :body "(define (sqrt-y x)
  (define (square g) (* g g))
  (define (abs-val a) (if (< a 0) (- 0 a) a))
  (define (good-enough? guess)
    (< (abs-val (- (square guess) x)) 0.001))
  (define (improve guess) (/ (+ guess (/ x guess)) 2))
  (define (iter guess)
    (if (good-enough? guess) guess (iter (improve guess))))
  (iter 1.0))
(sqrt-y 9)")
    (make-cell :id :lexical-scope-prose :kind :prose
               :body '(:div
                       (:p (:strong "注目してください。")
                           " 内側の " (:code "good-enough?") " と "
                           (:code "improve")
                           " は、引数として " (:code "x") " を受け取っていません。")
                       (:p "それでも本体の中で " (:code "x")
                           " を使えるのは、これらが外側の "
                           (:code "sqrt-y") " の引数 "
                           (:code "x")
                           " を直接参照しているからです。"
                           "これを " (:strong "レキシカルスコープ")
                           " と呼びます。")))
    (make-cell :id :black-box-prose :kind :prose
               :body '(:div
                       (:p "内部定義のおかげで、外部に見える名前は "
                           (:code "sqrt-y") " ただ一つだけになりました。"
                           (:code "good-enough?") " や " (:code "iter")
                           " は他の関数と名前がぶつかる心配がありません。")
                       (:p "利用者から見ると "
                           (:code "sqrt-y") " は「数を入れたら平方根が出てくる箱」"
                           "でしかなく、中の仕組みを意識する必要はありません。"
                           "これが " (:strong "ブラックボックス抽象")
                           " の核心です。")))
    (make-cell :id :ex-internal :kind :code-exercise
               :description
               "立方根 cube-root を、内部定義のみ で書いてください。
square・abs-val・good-enough?・improve・iter をすべて
cube-root の内側に置き、外部 API は cube-root 一つだけ。
最終式として (cube-root 8) を残してください。"
               :body "; (define (cube-root x)
;   (define (square g) ...)
;   (define (abs-val a) ...)
;   (define (good-enough? guess) ...)   ; (* guess (square guess)) と x を比べる
;   (define (improve guess) ...)        ; (/ (+ (/ x (square guess)) (* 2 guess)) 3)
;   (define (iter guess) ...)
;   (iter 1.0))
; 最後に (cube-root 8)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "2.000004911675504"
                                     :description "8 の立方根を Newton 法で")))
    (make-cell :id :ex-mystery :kind :code-exercise
               :description
               "次の階乗手続きを、内部定義のみを使って factorial に書き換えてください。
反復用の補助手続き iter を factorial の内側に置き、外部 API は
factorial 一つだけ。最終式として (factorial 5) を残してください。"
               :body "; (define (factorial n)
;   (define (iter i acc) ...)            ; i が n を超えたら acc を返す
;   (iter 1 1))
; 最後に (factorial 5)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "120"
                                     :description "5! = 120"))))))
