;;;; game/notebooks/sicp-2-5-3.lisp --- SICP 2.5.3 Symbolic algebra: polynomial arithmetic.

(defpackage #:recurya/game/notebooks/sicp-2-5-3
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-2-5-3-notebook))

(in-package #:recurya/game/notebooks/sicp-2-5-3)

(defun make-sicp-2-5-3-notebook ()
  "SICP 2.5.3 - Symbolic algebra: polynomial arithmetic."
  (make-notebook
   :id :sicp-2-5-3
   :chapter "2.5.3"
   :title "記号代数 - 多項式の演算"
   :summary "多項式 (variable と項リスト) を新しい型として op-table に登録し、add-terms で項リスト同士を併合する。同じ add API が int / rational / poly すべてに通用する"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "多項式 "
                           (:code "p(x) = 3x^2 + 2x + 5")
                           " のような "
                           (:strong "記号データ")
                           " も、ジェネリック演算の枠組みに乗せられます。")
                       (:p "本ノートでは多項式を ("
                           (:code "poly variable term-list")
                           ") の形で表し、項を "
                           (:code "(order coef)")
                           " のリストで保持します。"
                           (:code "add-terms")
                           " は降順に並んだ 2 つの項リストを併合します。")))
    (make-cell :id :design-prose :kind :prose
               :body '(:div
                       (:p (:strong "表現")
                           ": "
                           (:code "(make-poly 'x term-list)")
                           " は "
                           (:code "(poly . (x . term-list))")
                           " となり、型タグ "
                           (:code "'poly")
                           " を持ちます。"
                           (:code "term-list")
                           " は次数の降順で項 "
                           (:code "(order coef)")
                           " を並べたリスト。")
                       (:p (:strong "演算")
                           ": "
                           (:code "add-terms")
                           " は merge sort と同様に 2 つのリストの先頭を比較し、次数が大きい方を採用、同じならば係数を加算して合流させます。係数 0 になった項は "
                           (:code "adjoin-term")
                           " が自動的に除外します。")))
    (make-cell :id :poly-code :kind :code-eval
               :body "(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (attach-tag tag x) (cons tag x))
(define (type-tag x) (car x))
(define (contents x) (cdr x))
;; polynomial: (poly variable term-list)
;; term: (order coef)
(define (make-poly variable term-list) (attach-tag 'poly (cons variable term-list)))
(define (variable p) (car p))
(define (term-list p) (cdr p))
(define (make-term order coef) (list order coef))
(define (order term) (car term))
(define (coef term) (car (cdr term)))
(define (the-empty-term-list) nil)
(define (empty-term-list? l) (null? l))
(define (first-term l) (car l))
(define (rest-terms l) (cdr l))
(define (adjoin-term term term-list)
  (if (= 0 (coef term)) term-list (cons term term-list)))
(define (add-terms l1 l2)
  (cond ((empty-term-list? l1) l2)
        ((empty-term-list? l2) l1)
        (t
         (let ((t1 (first-term l1)) (t2 (first-term l2)))
           (cond ((> (order t1) (order t2))
                  (adjoin-term t1 (add-terms (rest-terms l1) l2)))
                 ((< (order t1) (order t2))
                  (adjoin-term t2 (add-terms l1 (rest-terms l2))))
                 (t (adjoin-term (make-term (order t1) (+ (coef t1) (coef t2)))
                                 (add-terms (rest-terms l1) (rest-terms l2)))))))))
(define (add-poly p1 p2)
  (if (eq? (variable p1) (variable p2))
      (make-poly (variable p1) (add-terms (term-list p1) (term-list p2)))
      'different-variables))
;; static op-table for polynomials
(define op-table
  (list
    (list (list 'add 'poly 'poly) (lambda (p1 p2) (add-poly p1 p2)))))
(define (assoc-pair key alist)
  (cond ((null? alist) nil)
        ((equal? key (car (car alist))) (car alist))
        (t (assoc-pair key (cdr alist)))))
(define (get op types)
  (let ((entry (assoc-pair (cons op types) op-table)))
    (if entry (car (cdr entry)) nil)))
(define (apply-generic op a b)
  (let ((proc (get op (list (type-tag a) (type-tag b)))))
    (if proc (proc (contents a) (contents b)) 'no-method)))
(define (add x y) (apply-generic 'add x y))
;; sample: (3x^2 + 2x + 5) + (x^2 + 4x + 1) = 4x^2 + 6x + 6
(define p1 (make-poly 'x (list (make-term 2 3) (make-term 1 2) (make-term 0 5))))
(define p2 (make-poly 'x (list (make-term 2 1) (make-term 1 4) (make-term 0 1))))
(add p1 p2)")
    (make-cell :id :merge-prose :kind :prose
               :body '(:div
                       (:p (:code "add-terms")
                           " は降順併合 (merge): 2 つの項リストの先頭を比べ、(1) 次数が大きい側を採って残りを再帰、(2) 次数が等しければ係数を足して残り同士を再帰、(3) どちらかが空ならもう一方を返す、というロジックで動きます。")
                       (:p "結果も降順に並びます。係数 0 の項は "
                           (:code "adjoin-term")
                           " で自動的に削除されるため、"
                           (:code "(3x^2) + (-3x^2) = 0")
                           " のような相殺もきれいに表現できます。")))
    (make-cell :id :additivity-prose :kind :prose
               :body '(:div
                       (:p (:strong "ジェネリックの威力")
                           ": "
                           (:code "add")
                           " の呼び出し側コードは int / rational / poly のどれを足すか意識しません。新しい型 (matrix, modular int, ...) を加えるには "
                           (:code "op-table")
                           " に新しい行 "
                           (:code "((add new-type new-type) proc)")
                           " を 1 つ追加するだけ。")
                       (:p "これが SICP 2 章の到達点である "
                           (:strong "加法性 (additivity)")
                           " ─ 既存コードに手を入れずに新しい型と操作を追加できる ─ という設計目標です。")))
    (make-cell :id :ex-poly-add :kind :code-exercise
               :description
               "多項式 (2x + 3) と (4x + 5) の和を計算します。
上のセル (:poly-code) と同じ構成 (pair? / attach-tag / type-tag / contents /
make-poly / variable / term-list / make-term / order / coef /
the-empty-term-list / empty-term-list? / first-term / rest-terms /
adjoin-term / add-terms / add-poly /
op-table / assoc-pair / get / apply-generic / add) を組み立て、最終式として
  (add (make-poly 'x (list (make-term 1 2) (make-term 0 3)))
       (make-poly 'x (list (make-term 1 4) (make-term 0 5))))
を残してください。 (2x + 3) + (4x + 5) = 6x + 8 となり、
表現は (poly x (1 6) (0 8)) になります。"
               :body "; (define (pair? x) ...)
; (define (attach-tag tag x) (cons tag x))
; (define (type-tag x) (car x))
; (define (contents x) (cdr x))
; (define (make-poly variable term-list) ...)
; (define (variable p) (car p))
; (define (term-list p) (cdr p))
; (define (make-term order coef) (list order coef))
; (define (order term) (car term))
; (define (coef term) (car (cdr term)))
; (define (the-empty-term-list) nil)
; (define (empty-term-list? l) (null? l))
; (define (first-term l) (car l))
; (define (rest-terms l) (cdr l))
; (define (adjoin-term term term-list) ...)
; (define (add-terms l1 l2) ...)
; (define (add-poly p1 p2) ...)
; (define op-table (list ...))
; (define (assoc-pair key alist) ...)
; (define (get op types) ...)
; (define (apply-generic op a b) ...)
; (define (add x y) (apply-generic 'add x y))
; 最後に (add (make-poly 'x (list (make-term 1 2) (make-term 0 3)))
;             (make-poly 'x (list (make-term 1 4) (make-term 0 5))))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "(poly x (1 6) (0 8))"
                                     :description "(2x + 3) + (4x + 5) = 6x + 8")))
    (make-cell :id :ex-poly-zero :kind :code-exercise
               :description
               "係数の相殺を確かめます。同じ構成で
  (add (make-poly 'x (list (make-term 2 3) (make-term 0 5)))
       (make-poly 'x (list (make-term 2 -3) (make-term 0 1))))
を最終式に残してください。 (3x^2 + 5) + (-3x^2 + 1) = 6 となり、
adjoin-term が係数 0 の x^2 項を除去するので、
表現は (poly x (0 6)) になります。"
               :body "; (define (pair? x) ...)
; (define (attach-tag tag x) (cons tag x))
; (define (type-tag x) (car x))
; (define (contents x) (cdr x))
; (define (make-poly ...) ...)
; (define (make-term ...) ...)
; (define (order term) ...)
; (define (coef term) ...)
; (define (adjoin-term term term-list)
;   (if (= 0 (coef term)) term-list (cons term term-list)))
; (define (add-terms l1 l2) ...)
; (define (add-poly p1 p2) ...)
; (define op-table (list ((add poly poly) ...)))
; (define (assoc-pair ...) ...)
; (define (get op types) ...)
; (define (apply-generic op a b) ...)
; (define (add x y) (apply-generic 'add x y))
; 最後に上の (add ...) 式
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "(poly x (0 6))"
                                     :description "x^2 項が相殺されて 6 のみ残る"))))))
