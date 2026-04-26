;;;; game/notebooks/sicp-2-4-2.lisp --- SICP 2.4.2 Tagged Data.

(defpackage #:recurya/game/notebooks/sicp-2-4-2
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-2-4-2-notebook))

(in-package #:recurya/game/notebooks/sicp-2-4-2)

(defun make-sicp-2-4-2-notebook ()
  "SICP 2.4.2 - Tagged Data."
  (make-notebook
   :id :sicp-2-4-2
   :chapter "2.4.2"
   :title "タグ付きデータ"
   :summary "値の先頭に「型タグ」を付けて、どの内部表現を使っているかを区別する。タグで cond ディスパッチして、複数表現を統一的に扱う"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "2.4.1 で見たように、複素数には 2 つの内部表現 (直交座標 / 極座標) があります。"
                           "両方を "
                           (:strong "同時にサポート")
                           " するためには、各値が「どちらの表現を使っているか」を区別する必要があります。"
                           "そのために値の先頭に "
                           (:strong "型タグ")
                           " を付けます。")))
    (make-cell :id :tag-ops :kind :prose
               :body '(:div
                       (:p "型タグを扱う 3 つの操作:")
                       (:ul
                        (:li (:code "(attach-tag tag x)")
                             " — 値 x に型タグ tag を付ける")
                        (:li (:code "(type-tag tagged)")
                             " — タグ部分を取り出す")
                        (:li (:code "(contents tagged)")
                             " — 中身 (タグを除いた部分) を取り出す"))))
    (make-cell :id :tag-code :kind :code-eval
               :body "(define (attach-tag tag x) (cons tag x))
(define (type-tag x) (car x))
(define (contents x) (cdr x))
(define z (attach-tag 'rectangular (cons 3.0 4.0)))
(list (type-tag z) (contents z))")
    (make-cell :id :dispatch-prose :kind :prose
               :body '(:div
                       (:p (:code "real-part")
                           " などの操作は、タグを見て「どの実装を呼ぶか」を "
                           (:code "cond")
                           " で分岐します。")
                       (:p "下のセルでは "
                           (:code "rectangular?")
                           " 判定を入れて直交座標版だけを実装し、極座標版はタグ違いとして "
                           (:code "'unknown")
                           " を返すようにしています。実装を増やせば "
                           (:code "cond")
                           " の節を増やします。")))
    (make-cell :id :dispatch-code :kind :code-eval
               :body "(define (square x) (* x x))
(define (sqrt-newton x)
  (define (good? g) (< (let ((d (- (square g) x))) (if (< d 0) (- 0 d) d)) 0.001))
  (define (improve g) (/ (+ g (/ x g)) 2))
  (define (iter g) (if (good? g) g (iter (improve g))))
  (iter 1.0))
(define (attach-tag tag x) (cons tag x))
(define (type-tag x) (car x))
(define (contents x) (cdr x))
(define (rectangular? z) (eq? (type-tag z) 'rectangular))
(define (polar? z) (eq? (type-tag z) 'polar))
(define (real-part-rect z) (car (contents z)))
(define (imag-part-rect z) (cdr (contents z)))
(define (magnitude-rect z) (sqrt-newton (+ (square (real-part-rect z)) (square (imag-part-rect z)))))
(define (real-part z) (cond ((rectangular? z) (real-part-rect z)) (t 'unknown)))
(define (imag-part z) (cond ((rectangular? z) (imag-part-rect z)) (t 'unknown)))
(define (magnitude z) (cond ((rectangular? z) (magnitude-rect z)) (t 'unknown)))
(define z1 (attach-tag 'rectangular (cons 3.0 4.0)))
(list (real-part z1) (imag-part z1) (magnitude z1))")
    (make-cell :id :limitation-prose :kind :prose
               :body '(:div
                       (:p (:strong "問題点")
                           ": 表現を増やすたびに "
                           (:code "real-part")
                           " / "
                           (:code "imag-part")
                           " / "
                           (:code "magnitude")
                           " それぞれの "
                           (:code "cond")
                           " を編集しなくてはなりません。新しい操作を増やすときも、すべての表現について場合分けを書き足します。")
                       (:p "この「ディスパッチ表を全関数に分散させる」設計は、表現や操作の数が増えると保守が困難に。これを解消するのが次節 "
                           (:strong "2.4.3 データ駆動プログラミング")
                           " です。")))
    (make-cell :id :ex-dispatch :kind :code-exercise
               :description
               "上のセル (:dispatch-code) と同じ抽象 (square / sqrt-newton / attach-tag / type-tag / contents /
rectangular? / real-part-rect / imag-part-rect / magnitude-rect / real-part / imag-part / magnitude) を組み立て、
さらに make-from-real-imag-tagged を
  (define (make-from-real-imag-tagged x y) (attach-tag 'rectangular (cons x y)))
で定義したうえで、最終式として
  (magnitude (make-from-real-imag-tagged 6 8))
を残してください。結果は 10 近傍の浮動小数になります。"
               :body "; (define (square x) (* x x))
; (define (sqrt-newton x) ...)
; (define (attach-tag ...) ...)
; (define (type-tag ...) ...)
; (define (contents ...) ...)
; (define (rectangular? z) ...)
; (define (real-part-rect z) ...)
; (define (imag-part-rect z) ...)
; (define (magnitude-rect z) ...)
; (define (magnitude z) (cond ((rectangular? z) (magnitude-rect z)) (t 'unknown)))
; (define (make-from-real-imag-tagged x y) (attach-tag 'rectangular (cons x y)))
; 最後に (magnitude (make-from-real-imag-tagged 6 8))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "10.000000000139897"
                                     :description "タグ付きデータに対する magnitude")))
    (make-cell :id :ex-tag-only :kind :code-exercise
               :description
               "型タグの取り出しだけを確かめます。
最終式として
  (type-tag (attach-tag 'polar (cons 5 0.5)))
を残してください。結果は polar になります。"
               :body "; (define (attach-tag tag x) (cons tag x))
; (define (type-tag x) (car x))
; 最後に (type-tag (attach-tag 'polar (cons 5 0.5)))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "polar"
                                     :description "タグの取り出し"))))))
