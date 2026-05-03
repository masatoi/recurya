===prose===
`add` / `sub` / `mul` / `div` を **どの数値型でも同じ API で** 呼べるようにしたい。`(add 1 2)` でも `(add (make-rat 1 2) (make-rat 1 3))` でも、呼び出し側のコードを変えずに動かせるのが目標です。

本ノートでは整数 (int) と有理数 (rational) の 2 種類を例に、**ジェネリック算術演算 (generic arithmetic operations)** を構成します。

===prose===
**設計**: 各値に型タグ `'int` または `'rational` を付け、**静的な op-table** に登録した手続きを `(op type1 type2)` のキーでディスパッチして呼び出します (2.4.3 と同じ要領)。

ジェネリック関数 `(add x y)` は内部で `(apply-generic 'add x y)` を呼び、引数のタグに応じて `add-int` か `add-rat` を選択します。

===prose===
**WardLisp 注記**: SICP 原典の `apply-generic` は可変長引数 `(apply-generic op . args)` で書かれていますが、WardLisp は **可変長 lambda をサポートしていない** ため、本ノートでは **2 引数固定版** `(apply-generic op a b)` で記述します。

===eval===
(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (attach-tag tag x) (cons tag x))
(define (type-tag x) (car x))
(define (contents x) (cdr x))
;; integer package
(define (make-int n) (attach-tag 'int n))
(define (add-int a b) (make-int (+ a b)))
(define (mul-int a b) (make-int (* a b)))
;; rational package
(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d) (let ((g (gcd n d))) (attach-tag 'rational (cons (quotient n g) (quotient d g)))))
(define (numer r) (car r))
(define (denom r) (cdr r))
(define (add-rat a b) (make-rat (+ (* (numer a) (denom b)) (* (numer b) (denom a))) (* (denom a) (denom b))))
(define (mul-rat a b) (make-rat (* (numer a) (numer b)) (* (denom a) (denom b))))
;; static dispatch table
(define op-table
  (list
    (list (list 'add 'int 'int) (lambda (a b) (add-int a b)))
    (list (list 'mul 'int 'int) (lambda (a b) (mul-int a b)))
    (list (list 'add 'rational 'rational) (lambda (a b) (add-rat a b)))
    (list (list 'mul 'rational 'rational) (lambda (a b) (mul-rat a b)))))
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
(define (mul x y) (apply-generic 'mul x y))
(list (add (make-int 3) (make-int 4)) (add (make-rat 1 2) (make-rat 1 3)))

===prose===
上のセルでは整数同士は `add-int` で、有理数同士は `add-rat` で計算されました。**呼び出し側コードは型を意識しません** ─ これが **ジェネリック演算** の威力です。

新しい数値型 (例: complex) を追加するには、`make-complex` / `add-complex` / `mul-complex` を実装し、`op-table` に行を追加するだけで済みます。次節 2.5.2 では **異なる型同士** の演算を扱います。

===exercise: 整数のジェネリック加算を確かめます。 上のセルと同じ構成 (pair? / attach-tag / type-tag / contents / make-int / add-int / mul-int / make-rat / numer / denom / add-rat / mul-rat / op-table / assoc-pair / get / apply-generic / add / mul) を組み立て、 最終式として (add (make-int 5) (make-int 7)) を残してください。期待値は (int . 12) という形式の値です。===
; (define (pair? x) ...)
; (define (attach-tag tag x) (cons tag x))
; (define (type-tag x) (car x))
; (define (contents x) (cdr x))
; (define (make-int n) (attach-tag 'int n))
; (define (add-int a b) (make-int (+ a b)))
; (define op-table (list ...))
; (define (assoc-pair key alist) ...)
; (define (get op types) ...)
; (define (apply-generic op a b) ...)
; (define (add x y) (apply-generic 'add x y))
; 最後に (add (make-int 5) (make-int 7))

===expect: (make-int 5) + (make-int 7) = (int . 12)===
(int . 12)

===solution: 整数のジェネリック加算を確かめます。 上のセルと同じ構成 (pair? / attach-tag / type-tag / contents / make-int / add-int / mul-int / make-rat / numer / denom / add-rat / mul-rat / op-table / assoc-pair / get / apply-generic / add / mul) を組み立て、 最終式として (add (make-int 5) (make-int 7)) を残してください。期待値は (int . 12) という形式の値です。===
(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (attach-tag tag x) (cons tag x))
(define (type-tag x) (car x))
(define (contents x) (cdr x))
(define (make-int n) (attach-tag 'int n))
(define (add-int a b) (make-int (+ a b)))
(define (mul-int a b) (make-int (* a b)))
(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d) (let ((g (gcd n d))) (attach-tag 'rational (cons (quotient n g) (quotient d g)))))
(define (numer r) (car r))
(define (denom r) (cdr r))
(define (add-rat a b) (make-rat (+ (* (numer a) (denom b)) (* (numer b) (denom a))) (* (denom a) (denom b))))
(define (mul-rat a b) (make-rat (* (numer a) (numer b)) (* (denom a) (denom b))))
(define op-table
  (list
    (list (list 'add 'int 'int) (lambda (a b) (add-int a b)))
    (list (list 'mul 'int 'int) (lambda (a b) (mul-int a b)))
    (list (list 'add 'rational 'rational) (lambda (a b) (add-rat a b)))
    (list (list 'mul 'rational 'rational) (lambda (a b) (mul-rat a b)))))
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
(define (mul x y) (apply-generic 'mul x y))
(add (make-int 5) (make-int 7))

===exercise: 有理数のジェネリック乗算を確かめます。 上のセルと同じ構成を組み立て、最終式として (mul (make-rat 2 3) (make-rat 3 4)) を残してください。 (2/3) * (3/4) = 6/12 = 1/2。 make-rat は gcd で約分するため、結果は (rational 1 . 2) になります。===
; (define (pair? x) ...)
; (define (attach-tag tag x) (cons tag x))
; (define (type-tag x) (car x))
; (define (contents x) (cdr x))
; (define (gcd a b) ...)
; (define (make-rat n d) ...)
; (define (numer r) ...)
; (define (denom r) ...)
; (define (mul-rat a b) ...)
; (define op-table (list ...))
; (define (assoc-pair key alist) ...)
; (define (get op types) ...)
; (define (apply-generic op a b) ...)
; (define (mul x y) (apply-generic 'mul x y))
; 最後に (mul (make-rat 2 3) (make-rat 3 4))

===expect: (2/3) * (3/4) = 1/2===
(rational 1 . 2)

===solution: 有理数のジェネリック乗算を確かめます。 上のセルと同じ構成を組み立て、最終式として (mul (make-rat 2 3) (make-rat 3 4)) を残してください。 (2/3) * (3/4) = 6/12 = 1/2。 make-rat は gcd で約分するため、結果は (rational 1 . 2) になります。===
(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (attach-tag tag x) (cons tag x))
(define (type-tag x) (car x))
(define (contents x) (cdr x))
(define (make-int n) (attach-tag 'int n))
(define (add-int a b) (make-int (+ a b)))
(define (mul-int a b) (make-int (* a b)))
(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d) (let ((g (gcd n d))) (attach-tag 'rational (cons (quotient n g) (quotient d g)))))
(define (numer r) (car r))
(define (denom r) (cdr r))
(define (add-rat a b) (make-rat (+ (* (numer a) (denom b)) (* (numer b) (denom a))) (* (denom a) (denom b))))
(define (mul-rat a b) (make-rat (* (numer a) (numer b)) (* (denom a) (denom b))))
(define op-table
  (list
    (list (list 'add 'int 'int) (lambda (a b) (add-int a b)))
    (list (list 'mul 'int 'int) (lambda (a b) (mul-int a b)))
    (list (list 'add 'rational 'rational) (lambda (a b) (add-rat a b)))
    (list (list 'mul 'rational 'rational) (lambda (a b) (mul-rat a b)))))
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
(define (mul x y) (apply-generic 'mul x y))
(mul (make-rat 2 3) (make-rat 3 4))

===prose===
これで `add` / `mul` の呼び出し側コードは **型を意識せずに** 書けるようになりました。次節では `(add (make-int 3) (make-rat 1 2))` のように **異なる型を混ぜた** 演算を、型の自動変換 (coercion) で実現する方法を見ます。
