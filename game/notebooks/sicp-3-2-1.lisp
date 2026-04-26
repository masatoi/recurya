;;;; game/notebooks/sicp-3-2-1.lisp --- SICP 3.2.1 The Rules for Evaluation.

(defpackage #:recurya/game/notebooks/sicp-3-2-1
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-3-2-1-notebook))

(in-package #:recurya/game/notebooks/sicp-3-2-1)

(defun make-sicp-3-2-1-notebook ()
  "SICP 3.2.1 - The environment model: frames, bindings, lexical scope."
  (make-notebook
   :id :sicp-3-2-1
   :chapter "3.2.1"
   :title "評価規則 (環境モデルの基本)"
   :summary "環境モデル ─ 手続き呼び出しを正確に説明する仕組み。フレーム (frame)、束縛 (binding)、レキシカルスコープ (lexical scope) を導入し、クロージャがどのように環境を捕捉するかを観察する"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:strong "環境モデル (environment model)")
                           " は手続き呼び出しを正確に説明する仕組みです。")
                       (:p "「環境」とは "
                           (:strong "フレーム (frame) の列")
                           " のことで、各フレームは "
                           (:strong "名前から値への束縛 (binding)")
                           " を持ちます。"
                           "フレームは外側のフレーム (親) を指す矢印を持っていて、"
                           "名前を解決するときは内側のフレームから外側へ順に探します。")))
    (make-cell :id :define-and-lookup :kind :prose
               :body '(:div
                       (:p (:code "(define x 5)")
                           " は "
                           (:strong "現在のフレーム")
                           " に束縛 "
                           (:code "x → 5")
                           " を追加します。"
                           (:code "x")
                           " を参照すると、"
                           (:strong "現在のフレームから外側に向かって最初に見つかった束縛")
                           " が返ります。"
                           "これが "
                           (:strong "レキシカルスコープ (lexical scope)")
                           " です。")
                       (:p "「現在のフレーム」は手続き呼び出しのたびに作られる新しいフレームで、"
                           "その親は手続きが "
                           (:em "作られた")
                           " ときの環境 (定義環境) です。")))
    (make-cell :id :closure-capture :kind :code-eval
               :body "(define (make-adder n) (lambda (x) (+ x n)))
(define add3 (make-adder 3))
(define add10 (make-adder 10))
(list (add3 5) (add10 5))")
    (make-cell :id :closure-explanation :kind :prose
               :body '(:div
                       (:p (:strong "重要")
                           ": "
                           (:code "add3")
                           " と "
                           (:code "add10")
                           " はそれぞれ自分が作られた時のフレーム ("
                           (:code "n=3")
                           " または "
                           (:code "n=10")
                           ") を "
                           (:strong "捕捉")
                           " しています。"
                           "これが "
                           (:strong "クロージャ (closure)")
                           " です。"
                           (:code "(add3 5)")
                           " を呼ぶと "
                           (:code "n=3")
                           " のフレームを親とする新しいフレームが作られ、その中で "
                           (:code "x=5")
                           " が束縛されて "
                           (:code "(+ x n)")
                           " が評価されます。")))
    (make-cell :id :ascii-frames :kind :prose
               :body '(:div
                       (:p (:strong "ASCII で環境を絵にする例")
                           ":")
                       (:pre "  [global frame]
  ├── make-adder: (lambda (n) (lambda (x) (+ x n)))
  ├── add3: ─→ E1
  └── add10: ─→ E2

  E1 [parent: global]      E2 [parent: global]
  └── n: 3                 └── n: 10")
                       (:p (:code "add3")
                           " を呼ぶと新フレーム "
                           (:code "E3 [parent: E1]")
                           " が作られ、その中に "
                           (:code "x: 5")
                           " が入ります。"
                           (:code "(+ x n)")
                           " は "
                           (:code "E3 → E1 → global")
                           " の順に lookup されます ─ "
                           (:code "x")
                           " は E3 で見つかり、"
                           (:code "n")
                           " は E1 で見つかり、"
                           (:code "+")
                           " は global で見つかります。")))
    (make-cell :id :ex-trace :kind :code-exercise
               :description
               "クロージャが環境を捕捉することを観察する課題です。
WardLisp には set! がないので、let で束縛した値を後から書き換えることはできません。
したがって以下のような関数を考えると ─
  (define (make-counter) (lambda () 0))
make-counter を呼ぶたびに新しい lambda が作られますが、それを何度呼んでも常に同じ値 0 を返します。
最終式として
  (let ((cc (make-counter))) (list (cc) (cc) (cc)))
を残してください。 期待値は (0 0 0) です。"
               :body "; (define (make-counter) (lambda () 0))
; 最後に (let ((cc (make-counter))) (list (cc) (cc) (cc)))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "(0 0 0)"
                                     :description "make-counter を 3 回呼んで全て 0"))))))
