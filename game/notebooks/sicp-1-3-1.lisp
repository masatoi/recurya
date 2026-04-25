;;;; game/notebooks/sicp-1-3-1.lisp --- SICP 1.3.1 Procedures as Arguments.

(defpackage #:recurya/game/notebooks/sicp-1-3-1
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-1-3-1-notebook))

(in-package #:recurya/game/notebooks/sicp-1-3-1)

(defun make-sicp-1-3-1-notebook ()
  "SICP 1.3.1 - Procedures as Arguments."
  (make-notebook
   :id :sicp-1-3-1
   :chapter "1.3.1"
   :title "手続きを引数として渡す"
   :summary "高階手続きの導入。汎用 sum を作り、整数・平方・立方・Leibniz 級数を統一的に表す"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "ここまでの手続きはどれも "
                           (:strong "数を引数として受け取る")
                           " ものでした。"
                           "Lisp では" (:strong "手続き自体")
                           " も第一級の値なので、"
                           "他の手続きの引数として渡したり、結果として返したりできます。")
                       (:p "これが " (:strong "高階手続き (higher-order procedure)")
                           " です。共通の繰り返し構造を 1 つの汎用手続きとして"
                           "切り出すための強力な道具になります。")))
    (make-cell :id :motivation :kind :prose
               :body '(:div
                       (:p "次の 3 つの手続きを見比べてみましょう:")
                       (:ul
                        (:li (:code "sum-ints a b") " = "
                             (:code "a + (a+1) + ... + b"))
                        (:li (:code "sum-squares a b") " = "
                             (:code "a^2 + (a+1)^2 + ... + b^2"))
                        (:li (:code "sum-cubes a b") " = "
                             (:code "a^3 + (a+1)^3 + ... + b^3")))
                       (:p "どれも構造は同じで、違うのは "
                           (:strong "何を足すか") " (項 "
                           (:code "f(a)") ") と "
                           (:strong "どう次に進むか") " (次の "
                           (:code "a") " の作り方) だけです。"
                           "この 2 つを引数化すると、"
                           "1 つの汎用 " (:code "sum") " で全部書けます。")))
    (make-cell :id :sum-defn :kind :code-eval
               :body "(define (sum f a next b)
  (if (> a b)
      0
      (+ (f a) (sum f (next a) next b))))
(define (inc x) (+ x 1))
(define (identity x) x)
(sum identity 1 inc 10)")
    (make-cell :id :sum-applications :kind :code-eval
               :body "(define (sum f a next b)
  (if (> a b) 0 (+ (f a) (sum f (next a) next b))))
(define (inc x) (+ x 1))
(define (square x) (* x x))
(define (cube x) (* x x x))
(list (sum square 1 inc 5) (sum cube 1 inc 4))")
    (make-cell :id :abstract-prose :kind :prose
               :body '(:div
                       (:p (:strong "手続きを引数として渡す")
                           " ことで、繰り返しの構造そのものを"
                           "ひとつの関数にまとめられます。"
                           (:code "sum-ints") "・"
                           (:code "sum-squares") "・"
                           (:code "sum-cubes") " を別々に書く必要はありません。")
                       (:p "これは抽象化の一段上の階段です。"
                           "「数の世界での足し算の繰り返し」を、"
                           "「項生成と次への進み方をパラメータに取る計算」として"
                           "見直したわけです。")))
    (make-cell :id :ex-product :kind :code-exercise
               :description
               "sum の積バージョンとして product を書いてください。
(product f a next b) は f(a) * f(next(a)) * ... * f(b) を返します。
基底ケースは 1 (積の単位元) です。
inc を補助手続きとして使い、最終式に (product (lambda (i) i) 1 inc 5) を残してください。
これは 5! = 120 を計算する式になります。"
               :body "; (define (inc x) ...)
; (define (product f a next b) ...)
; 最後に (product (lambda (i) i) 1 inc 5)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "120"
                                     :description "5! = 120 を product で")))
    (make-cell :id :ex-sum-cubes :kind :code-exercise
               :description
               "sum と cube と inc を定義し、(sum cube 1 inc 4) を最終式として残してください。
これは 1^3 + 2^3 + 3^3 + 4^3 を計算する式です。
答え: 1 + 8 + 27 + 64 = 100"
               :body "; (define (sum f a next b) ...)
; (define (cube x) ...)
; (define (inc x) ...)
; 最後に (sum cube 1 inc 4)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "100"
                                     :description "1+8+27+64 = 100")))
    (make-cell :id :ex-pi-eighth :kind :code-exercise
               :description
               "Leibniz の公式を有限項で打ち切った近似:
  pi/8 = 1/(1*3) + 1/(5*7) + 1/(9*11) + ...
を計算する (pi-eighth-approx n) を sum を使って書いてください。
n は項の個数です。i 番目の項 (i は 1 から始まる) は
  1 / ((4i - 3) * (4i - 1))
となります。
最終式として (pi-eighth-approx 100) を残してください。
答えは 0.39 程度の小数になります (pi/8 ≒ 0.3927)。"
               :body "; (define (sum f a next b) ...)
; (define (inc x) ...)
; (define (pi-term i) ...)
; (define (pi-eighth-approx n) ...)
; 最後に (pi-eighth-approx 100)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "0.3920740856048521"
                                     :description "100 項の Leibniz 近似"))))))
