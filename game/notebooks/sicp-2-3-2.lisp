;;;; game/notebooks/sicp-2-3-2.lisp --- SICP 2.3.2 Symbolic Differentiation.

(defpackage #:recurya/game/notebooks/sicp-2-3-2
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-2-3-2-notebook))

(in-package #:recurya/game/notebooks/sicp-2-3-2)

(defun make-sicp-2-3-2-notebook ()
  "SICP 2.3.2 - Symbolic Differentiation."
  (make-notebook
   :id :sicp-2-3-2
   :chapter "2.3.2"
   :title "記号微分"
   :summary "代数式の微分手続き deriv を実装する。場合分けで微分の規則を書き下し、make-sum / make-product を簡約版に置き換えることで読みやすい式が得られる"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "記号式の微分 "
                           (:code "(deriv expr var)")
                           " を実装します。微分の規則は場合分けで書けます: "
                           (:strong "定数は 0")
                           "、対象変数は 1、和の微分は微分の和、積の微分は積の規則 "
                           (:code "d(uv) = u dv + (du) v")
                           "。")
                       (:p "式は (+ a b) や (* a b) のような "
                           (:strong "リスト")
                           " で表します。")))
    (make-cell :id :basic-deriv-prose :kind :prose
               :body '(:div
                       (:p "まず簡約なしの単純な実装を見ます。")))
    (make-cell :id :basic-deriv-code :kind :code-eval
               :body "(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (variable? x) (atom? x))
(define (same-variable? v1 v2) (and (variable? v1) (variable? v2) (eq? v1 v2)))
(define (sum? e) (and (pair? e) (eq? (car e) '+)))
(define (addend e) (car (cdr e)))
(define (augend e) (car (cdr (cdr e))))
(define (product? e) (and (pair? e) (eq? (car e) '*)))
(define (multiplier e) (car (cdr e)))
(define (multiplicand e) (car (cdr (cdr e))))
(define (make-sum a b) (list '+ a b))
(define (make-product a b) (list '* a b))
(define (deriv expr var)
  (cond ((variable? expr) (if (same-variable? expr var) 1 0))
        ((sum? expr) (make-sum (deriv (addend expr) var) (deriv (augend expr) var)))
        ((product? expr) (make-sum (make-product (multiplier expr) (deriv (multiplicand expr) var))
                                    (make-product (deriv (multiplier expr) var) (multiplicand expr))))
        (t 0)))
(deriv '(+ x 3) 'x)")
    (make-cell :id :simplify-prose :kind :prose
               :body '(:div
                       (:p "上の結果は "
                           (:code "(+ 1 0)")
                           " のような未簡約式。"
                           (:code "make-sum")
                           " / "
                           (:code "make-product")
                           " を簡約版に置き換えると人間に読みやすくなります。"
                           (:strong "deriv のロジックは無変更")
                           " で動く点に注目: これが抽象化障壁の威力です。")))
    (make-cell :id :simplify-deriv-code :kind :code-eval
               :body "(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (variable? x) (atom? x))
(define (same-variable? v1 v2) (and (variable? v1) (variable? v2) (eq? v1 v2)))
(define (sum? e) (and (pair? e) (eq? (car e) '+)))
(define (addend e) (car (cdr e)))
(define (augend e) (car (cdr (cdr e))))
(define (product? e) (and (pair? e) (eq? (car e) '*)))
(define (multiplier e) (car (cdr e)))
(define (multiplicand e) (car (cdr (cdr e))))
(define (number-equal? n v) (and (number? n) (= n v)))
(define (make-sum a b)
  (cond ((number-equal? a 0) b)
        ((number-equal? b 0) a)
        ((and (number? a) (number? b)) (+ a b))
        (t (list '+ a b))))
(define (make-product a b)
  (cond ((or (number-equal? a 0) (number-equal? b 0)) 0)
        ((number-equal? a 1) b)
        ((number-equal? b 1) a)
        ((and (number? a) (number? b)) (* a b))
        (t (list '* a b))))
(define (deriv expr var)
  (cond ((variable? expr) (if (same-variable? expr var) 1 0))
        ((sum? expr) (make-sum (deriv (addend expr) var) (deriv (augend expr) var)))
        ((product? expr) (make-sum (make-product (multiplier expr) (deriv (multiplicand expr) var))
                                    (make-product (deriv (multiplier expr) var) (multiplicand expr))))
        (t 0)))
(deriv '(+ (* x 3) 2) 'x)")
    (make-cell :id :abstraction-prose :kind :prose
               :body '(:div
                       (:p (:strong "抽象化障壁の威力")
                           ": "
                           (:code "addend")
                           " / "
                           (:code "augend")
                           " / "
                           (:code "make-sum")
                           " の表現を変えれば、 "
                           (:code "deriv")
                           " のロジックは無変更で動きます。")))
    (make-cell :id :ex-deriv-x :kind :code-exercise
               :description
               "簡約付きの make-sum / make-product を備えた deriv を組み立て、
  (deriv '(* x x) 'x)
を最終式に。標準的な実装では結果は (+ x x) となります。"
               :body "; (define (pair? x) ...)
; (define (make-sum a b) ...)  ; 簡約付き
; (define (make-product a b) ...)  ; 簡約付き
; (define (deriv expr var) ...)
; 最後に (deriv '(* x x) 'x)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "(+ x x)"
                                     :description "(deriv '(* x x) 'x) は (+ x x)")))
    (make-cell :id :ex-deriv-poly :kind :code-exercise
               :description
               "同じ簡約付き deriv で
  (deriv '(+ (* 3 (* x x)) (* 2 x)) 'x)
を最終式に。標準的な実装では結果は (+ (* 3 (+ x x)) 2) となります。"
               :body "; (define (pair? x) ...)
; (define (make-sum a b) ...)
; (define (make-product a b) ...)
; (define (deriv expr var) ...)
; 最後に (deriv '(+ (* 3 (* x x)) (* 2 x)) 'x)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "(+ (* 3 (+ x x)) 2)"
                                     :description "簡約付き deriv で多項式を微分"))))))
