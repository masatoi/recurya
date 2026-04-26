;;;; game/notebooks/sicp-2-4-1.lisp --- SICP 2.4.1 Representations for Complex Numbers.

(defpackage #:recurya/game/notebooks/sicp-2-4-1
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-2-4-1-notebook))

(in-package #:recurya/game/notebooks/sicp-2-4-1)

(defun make-sicp-2-4-1-notebook ()
  "SICP 2.4.1 - Representations for Complex Numbers."
  (make-notebook
   :id :sicp-2-4-1
   :chapter "2.4.1"
   :title "複素数の複数表現"
   :summary "同じ複素数を直交座標 (x, y) と極座標 (r, θ) の 2 つの表現で扱う。同じ操作 (real-part / imag-part / magnitude / angle) を異なる内部表現に対して実装する"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "複素数 "
                           (:code "z = x + yi")
                           " は 2 つのデータで表せます: "
                           (:strong "直交座標")
                           " "
                           (:code "(x, y)")
                           " または "
                           (:strong "極座標")
                           " "
                           (:code "(r, θ)")
                           "。どちらの表現でも "
                           (:code "real-part")
                           " / "
                           (:code "imag-part")
                           " / "
                           (:code "magnitude")
                           " / "
                           (:code "angle")
                           " の 4 つの操作で扱えるようにしたい。")))
    (make-cell :id :rect-prose :kind :prose
               :body '(:div
                       (:p (:strong "直交座標表現")
                           ": 内部は "
                           (:code "(cons real imag)")
                           "。"
                           (:code "real-part")
                           " と "
                           (:code "imag-part")
                           " はそれぞれ "
                           (:code "car")
                           " / "
                           (:code "cdr")
                           " で取れます。"
                           (:code "magnitude")
                           " は √(x² + y²)。")))
    (make-cell :id :rect-code :kind :code-eval
               :body "(define (square x) (* x x))
(define (sqrt-newton x)
  (define (good? g) (< (let ((d (- (square g) x))) (if (< d 0) (- 0 d) d)) 0.001))
  (define (improve g) (/ (+ g (/ x g)) 2))
  (define (iter g) (if (good? g) g (iter (improve g))))
  (iter 1.0))
(define (make-from-real-imag x y) (cons x y))
(define (real-part z) (car z))
(define (imag-part z) (cdr z))
(define (magnitude z) (sqrt-newton (+ (square (real-part z)) (square (imag-part z)))))
(define z1 (make-from-real-imag 3.0 4.0))
(list (real-part z1) (imag-part z1) (magnitude z1))")
    (make-cell :id :angle-note :kind :prose
               :body '(:div
                       (:p "本来 "
                           (:code "angle")
                           " は "
                           (:code "atan(y / x)")
                           " で計算しますが、WardLisp に "
                           (:code "atan")
                           " がないため、本ノートでは "
                           (:code "magnitude")
                           " までを扱います (角度は概念として登場しますが、具体的計算は省略)。")))
    (make-cell :id :polar-prose :kind :prose
               :body '(:div
                       (:p (:strong "極座標表現")
                           ": 内部は "
                           (:code "(cons magnitude angle)")
                           "。"
                           (:code "magnitude")
                           " と "
                           (:code "angle")
                           " はそれぞれ "
                           (:code "car")
                           " / "
                           (:code "cdr")
                           " で取れます。本来 "
                           (:code "real-part")
                           " は "
                           (:code "r * cos(θ)")
                           " ですが、"
                           (:code "cos")
                           " / "
                           (:code "sin")
                           " もないので、ここでは内部表現を直接取り出すだけにとどめます。")))
    (make-cell :id :polar-code :kind :code-eval
               :body "(define (make-from-mag-ang r a) (cons r a))
(define (magnitude-polar z) (car z))
(define (angle-polar z) (cdr z))
(define z2 (make-from-mag-ang 5.0 0.927))
(list (magnitude-polar z2) (angle-polar z2))")
    (make-cell :id :two-rep-prose :kind :prose
               :body '(:div
                       (:p "「複素数」という同じ抽象を、"
                           (:strong "異なる内部表現")
                           " で実装できることが重要なポイントです。"
                           "次節 2.4.2 ではタグ付きデータを使って両者を統一的に扱い、2.4.3 ではデータ駆動ディスパッチでそれを一般化します。")))
    (make-cell :id :ex-magnitude :kind :code-exercise
               :description
               "直交座標で z = (6, 8) の複素数を作り、magnitude を求めてください。
(square / sqrt-newton / make-from-real-imag / real-part / imag-part / magnitude を上の例と同じ形で定義し、)
最終式として
  (magnitude (make-from-real-imag 6.0 8.0))
を残します。結果は 10 近傍の浮動小数になります (sqrt-newton による近似)。"
               :body "; (define (square x) (* x x))
; (define (sqrt-newton x) ...)
; (define (make-from-real-imag x y) ...)
; (define (real-part z) ...)
; (define (imag-part z) ...)
; (define (magnitude z) ...)
; 最後に (magnitude (make-from-real-imag 6.0 8.0))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "10.000000000139897"
                                     :description "√(6² + 8²) = 10 を Newton 法で近似")))
    (make-cell :id :ex-add-complex :kind :code-exercise
               :description
               "直交座標表現で 2 つの複素数を足す add-complex を書いてください。
add-complex は (x1 + x2, y1 + y2) を返します。
最終式として
  (real-part (add-complex (make-from-real-imag 1 2) (make-from-real-imag 3 4)))
を残します。1 + 3 = 4。"
               :body "; (define (make-from-real-imag x y) (cons x y))
; (define (real-part z) (car z))
; (define (imag-part z) (cdr z))
; (define (add-complex z1 z2) ...)
; 最後に (real-part (add-complex (make-from-real-imag 1 2) (make-from-real-imag 3 4)))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "4"
                                     :description "(1 + 2i) + (3 + 4i) の実部 = 4"))))))
