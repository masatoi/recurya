;;;; game/notebooks/sicp-2-4-3.lisp --- SICP 2.4.3 Data-Directed Programming (static dispatch).

(defpackage #:recurya/game/notebooks/sicp-2-4-3
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-2-4-3-notebook))

(in-package #:recurya/game/notebooks/sicp-2-4-3)

(defun make-sicp-2-4-3-notebook ()
  "SICP 2.4.3 - Data-Directed Programming."
  (make-notebook
   :id :sicp-2-4-3
   :chapter "2.4.3"
   :title "データ駆動プログラミング"
   :summary "(op type) → proc のテーブルを使い、汎用ディスパッチャ apply-generic から手続きを取り出して呼ぶ。表現を増やすときは表に行を追加するだけ"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "2.4.2 の "
                           (:code "cond")
                           " によるディスパッチは、表現の種類が増えるたびに "
                           (:code "real-part")
                           " / "
                           (:code "imag-part")
                           " / "
                           (:code "magnitude")
                           " それぞれを編集する必要がありました。")
                       (:p (:strong "データ駆動プログラミング")
                           " は、手続きを "
                           (:code "(op type)")
                           " → "
                           (:code "proc")
                           " のテーブルに登録し、汎用ディスパッチャ "
                           (:code "(apply-generic op . args)")
                           " から取り出して呼び出します。"
                           "ディスパッチのロジックを 1 箇所にまとめ、新しい型や操作の追加を「表への行追加」だけに局所化できます。")))
    (make-cell :id :wardlisp-note :kind :prose
               :body '(:div
                       (:p (:strong "WardLisp 注記")
                           ": SICP 原典は "
                           (:code "(put op type proc)")
                           " という副作用付きの操作で可変な表に逐次登録します。"
                           "WardLisp は副作用 (set! など) をサポートしていないため、本ノートでは "
                           (:strong "静的な association list")
                           " "
                           (:code "op-table")
                           " で同じ振る舞いを実現します。")
                       (:p "新しい型を追加するには "
                           (:code "op-table")
                           " の定義に行を 1 つ加えるだけです。"
                           (:strong "加法性 (additivity)")
                           " ─ ディスパッチロジック (apply-generic) は無変更で拡張できる ─ という概念は静的版でも保たれています。")))
    (make-cell :id :rect-only-prose :kind :prose
               :body '(:div
                       (:p "まずは直交座標表現だけを op-table に登録し、"
                           (:code "apply-generic")
                           " 経由で操作を呼び出してみます。")))
    (make-cell :id :rect-only-code :kind :code-eval
               :body "(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (square x) (* x x))
(define (sqrt-newton x)
  (define (good? g) (< (let ((d (- (square g) x))) (if (< d 0) (- 0 d) d)) 0.001))
  (define (improve g) (/ (+ g (/ x g)) 2))
  (define (iter g) (if (good? g) g (iter (improve g))))
  (iter 1.0))
(define (attach-tag tag x) (cons tag x))
(define (type-tag x) (car x))
(define (contents x) (cdr x))
;; rectangular package
(define (real-part-rect z) (car z))
(define (imag-part-rect z) (cdr z))
(define (magnitude-rect z) (sqrt-newton (+ (square (real-part-rect z)) (square (imag-part-rect z)))))
;; static op-table
(define op-table
  (list
    (list (list 'real-part 'rectangular) real-part-rect)
    (list (list 'imag-part 'rectangular) imag-part-rect)
    (list (list 'magnitude 'rectangular) magnitude-rect)))
(define (assoc-pair key alist)
  (cond ((null? alist) nil)
        ((equal? key (car (car alist))) (car alist))
        (t (assoc-pair key (cdr alist)))))
(define (get op type)
  (let ((entry (assoc-pair (list op type) op-table)))
    (if entry (car (cdr entry)) nil)))
(define (apply-generic op arg)
  (let ((proc (get op (type-tag arg))))
    (if proc (proc (contents arg)) 'no-method)))
(define (real-part z) (apply-generic 'real-part z))
(define (imag-part z) (apply-generic 'imag-part z))
(define (magnitude z) (apply-generic 'magnitude z))
(define z (attach-tag 'rectangular (cons 3.0 4.0)))
(list (real-part z) (imag-part z) (magnitude z))")
    (make-cell :id :additivity-prose :kind :prose
               :body '(:div
                       (:p (:strong "加法性 (additivity)")
                           ": 極座標表現の "
                           (:code "magnitude-polar")
                           " を新しく実装したい場合、SICP 原典では "
                           (:code "(put 'magnitude 'polar magnitude-polar)")
                           " を呼ぶだけで "
                           (:code "apply-generic")
                           " の挙動を拡張できます。")
                       (:p "WardLisp 静的版では、"
                           (:code "op-table")
                           " の定義に新しい行を 1 つ追加します。"
                           (:strong "ディスパッチロジック自体 ")
                           "("
                           (:code "apply-generic")
                           " / "
                           (:code "get")
                           " / "
                           (:code "assoc-pair")
                           ") は "
                           (:strong "無変更")
                           "。これが「データ駆動」の要諦です。")))
    (make-cell :id :both-types-code :kind :code-eval
               :body "(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (attach-tag tag x) (cons tag x))
(define (type-tag x) (car x))
(define (contents x) (cdr x))
;; rectangular package
(define (real-part-rect z) (car z))
(define (imag-part-rect z) (cdr z))
;; polar package
(define (magnitude-polar z) (car z))
(define (angle-polar z) (cdr z))
;; combined op-table (ここに行を追加するだけで型を増やせる)
(define op-table
  (list
    (list (list 'real-part 'rectangular) real-part-rect)
    (list (list 'imag-part 'rectangular) imag-part-rect)
    (list (list 'magnitude 'polar) magnitude-polar)
    (list (list 'angle 'polar) angle-polar)))
(define (assoc-pair key alist)
  (cond ((null? alist) nil)
        ((equal? key (car (car alist))) (car alist))
        (t (assoc-pair key (cdr alist)))))
(define (get op type)
  (let ((entry (assoc-pair (list op type) op-table)))
    (if entry (car (cdr entry)) nil)))
(define (apply-generic op arg)
  (let ((proc (get op (type-tag arg))))
    (if proc (proc (contents arg)) 'no-method)))
(define (real-part z) (apply-generic 'real-part z))
(define (magnitude z) (apply-generic 'magnitude z))
(define z-rect (attach-tag 'rectangular (cons 3 4)))
(define z-polar (attach-tag 'polar (cons 5 0.927)))
(list (real-part z-rect) (magnitude z-polar))")
    (make-cell :id :ex-data-directed :kind :code-exercise
               :description
               "上のセル (:both-types-code) と同じ構成 (pair? / attach-tag / type-tag / contents /
real-part-rect / imag-part-rect / magnitude-polar / angle-polar /
op-table / assoc-pair / get / apply-generic / real-part / magnitude) を組み立て、
最終式として
  (magnitude (attach-tag 'polar (cons 5 0.927)))
を残してください。op-table の (magnitude polar) が magnitude-polar を返し、
そのまま (cons 5 0.927) の car = 5 が結果になります。"
               :body "; (define (pair? x) ...)
; (define (attach-tag tag x) (cons tag x))
; (define (type-tag x) (car x))
; (define (contents x) (cdr x))
; (define (magnitude-polar z) (car z))
; (define op-table (list ...))
; (define (assoc-pair key alist) ...)
; (define (get op type) ...)
; (define (apply-generic op arg) ...)
; (define (magnitude z) (apply-generic 'magnitude z))
; 最後に (magnitude (attach-tag 'polar (cons 5 0.927)))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "5"
                                     :description "極座標 (5, 0.927) の magnitude は 5")))
    (make-cell :id :ex-dispatch-real :kind :code-exercise
               :description
               "同じ構成で、直交座標版 (rectangular) も op-table に入れたうえで
  (real-part (attach-tag 'rectangular (cons 7 24)))
を最終式に。op-table の (real-part rectangular) が real-part-rect を返し、
(cons 7 24) の car = 7 が結果になります。"
               :body "; (define (pair? x) ...)
; (define (attach-tag tag x) (cons tag x))
; (define (type-tag x) (car x))
; (define (contents x) (cdr x))
; (define (real-part-rect z) (car z))
; (define op-table (list ...))
; (define (assoc-pair key alist) ...)
; (define (get op type) ...)
; (define (apply-generic op arg) ...)
; (define (real-part z) (apply-generic 'real-part z))
; 最後に (real-part (attach-tag 'rectangular (cons 7 24)))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "7"
                                     :description "直交座標 (7, 24) の real-part = 7"))))))
