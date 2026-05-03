===prose===
記号式の微分 `(deriv expr var)` を実装します。微分の規則は場合分けで書けます: **定数は 0**、対象変数は 1、和の微分は微分の和、積の微分は積の規則 `d(uv) = u dv + (du) v`。

式は (+ a b) や (* a b) のような **リスト** で表します。

===prose===
まず簡約なしの単純な実装を見ます。

===eval===
(define (pair? x) (and (not (null? x)) (not (atom? x))))
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
(deriv '(+ x 3) 'x)

===prose===
上の結果は `(+ 1 0)` のような未簡約式。`make-sum` / `make-product` を簡約版に置き換えると人間に読みやすくなります。**deriv のロジックは無変更** で動く点に注目: これが抽象化障壁の威力です。

===eval===
(define (pair? x) (and (not (null? x)) (not (atom? x))))
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
(deriv '(+ (* x 3) 2) 'x)

===prose===
**抽象化障壁の威力**: `addend` / `augend` / `make-sum` の表現を変えれば、 `deriv` のロジックは無変更で動きます。

===exercise: 簡約付きの make-sum / make-product を備えた deriv を組み立て、 (deriv '(* x x) 'x) を最終式に。標準的な実装では結果は (+ x x) となります。===
; (define (pair? x) ...)
; (define (make-sum a b) ...)  ; 簡約付き
; (define (make-product a b) ...)  ; 簡約付き
; (define (deriv expr var) ...)
; 最後に (deriv '(* x x) 'x)

===expect: (deriv '(* x x) 'x) は (+ x x)===
(+ x x)

===solution: 簡約付きの make-sum / make-product を備えた deriv を組み立て、 (deriv '(* x x) 'x) を最終式に。標準的な実装では結果は (+ x x) となります。===
(define (pair? x) (and (not (null? x)) (not (atom? x))))
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
(deriv '(* x x) 'x)

===exercise: 同じ簡約付き deriv で (deriv '(+ (* 3 (* x x)) (* 2 x)) 'x) を最終式に。標準的な実装では結果は (+ (* 3 (+ x x)) 2) となります。===
; (define (pair? x) ...)
; (define (make-sum a b) ...)
; (define (make-product a b) ...)
; (define (deriv expr var) ...)
; 最後に (deriv '(+ (* 3 (* x x)) (* 2 x)) 'x)

===expect: 簡約付き deriv で多項式を微分===
(+ (* 3 (+ x x)) 2)

===solution: 同じ簡約付き deriv で (deriv '(+ (* 3 (* x x)) (* 2 x)) 'x) を最終式に。標準的な実装では結果は (+ (* 3 (+ x x)) 2) となります。===
(define (pair? x) (and (not (null? x)) (not (atom? x))))
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
(deriv '(+ (* 3 (* x x)) (* 2 x)) 'x)
