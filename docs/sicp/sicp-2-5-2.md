===prose===
`(add (make-int 3) (make-rat 1 2))` のように **異なる型** を混ぜて演算したい。素朴に書くと `(add 'int 'rational)` という組み合わせは `op-table` に登録されておらず `no-method` になってしまいます。

一般化された方法は **型強制 (coercion)**: 一方を他方の型に変換してから、既存の同型ディスパッチを使うことです。

===prose===
**設計**: 同型用の `op-table` と並んで `coercion-table` を別途用意し、`(from to)` のキーで変換手続きを登録します。今回は `int->rational` (整数を分母 1 の有理数に変換) を 1 つ追加します。

`apply-generic` は (1) まず op-table を引く、(2) 無ければ `a` を `b` の型に変換して再帰、(3) それも失敗なら逆方向 (`b` → `a`) を試す、という順で動きます。

===eval===
(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (attach-tag tag x) (cons tag x))
(define (type-tag x) (car x))
(define (contents x) (cdr x))
;; integer + rational packages
(define (make-int n) (attach-tag 'int n))
(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d) (let ((g (gcd n d))) (attach-tag 'rational (cons (quotient n g) (quotient d g)))))
(define (numer r) (car r))
(define (denom r) (cdr r))
(define (add-int a b) (make-int (+ a b)))
(define (add-rat a b) (make-rat (+ (* (numer a) (denom b)) (* (numer b) (denom a))) (* (denom a) (denom b))))
;; coercion: int -> rational
(define (int->rational n) (make-rat n 1))
(define coercion-table
  (list
    (list (list 'int 'rational) int->rational)))
(define (assoc-pair key alist)
  (cond ((null? alist) nil)
        ((equal? key (car (car alist))) (car alist))
        (t (assoc-pair key (cdr alist)))))
(define (get-coercion from to)
  (let ((entry (assoc-pair (list from to) coercion-table)))
    (if entry (car (cdr entry)) nil)))
;; same-type op-table
(define op-table
  (list
    (list (list 'add 'int 'int) (lambda (a b) (add-int a b)))
    (list (list 'add 'rational 'rational) (lambda (a b) (add-rat a b)))))
(define (get op types)
  (let ((entry (assoc-pair (cons op types) op-table)))
    (if entry (car (cdr entry)) nil)))
(define (apply-generic op a b)
  (let ((ta (type-tag a)) (tb (type-tag b)))
    (let ((proc (get op (list ta tb))))
      (if proc
          (proc (contents a) (contents b))
          (let ((a->b (get-coercion ta tb)))
            (if a->b
                (apply-generic op (a->b (contents a)) b)
                (let ((b->a (get-coercion tb ta)))
                  (if b->a (apply-generic op a (b->a (contents b))) 'no-method))))))))
(define (add x y) (apply-generic 'add x y))
(add (make-int 3) (make-rat 1 2))

===prose===
**型階層 (type tower)**: 数値の世界では `integer` ⊂ `rational` ⊂ `real` ⊂ `complex` のような自然な階層があります。

下の型を上の型に「持ち上げる (raise)」変換さえ用意すれば、任意の混合演算は持ち上げてからディスパッチで済む、という設計に発展できます。本ノートでは `int → rational` の 2 段の最小例を示しました。

===exercise: 型強制が働く混合加算を確かめます。 上のセル (:coerce-code) と同じ構成 (pair? / attach-tag / type-tag / contents / make-int / gcd / make-rat / numer / denom / add-int / add-rat / int->rational / coercion-table / assoc-pair / get-coercion / op-table / get / apply-generic / add) を組み立て、最終式として (add (make-int 5) (make-rat 1 3)) を残してください。 op-table に (add int rational) は無いので、a = make-int 5 を int->rational で (rational 5 . 1) に変換してから (add rational rational) が呼ばれ、 5 + 1/3 = 15/3 + 1/3 = 16/3 となります。===
; (define (pair? x) ...)
; (define (attach-tag tag x) (cons tag x))
; (define (type-tag x) (car x))
; (define (contents x) (cdr x))
; (define (make-int n) ...)
; (define (gcd a b) ...)
; (define (make-rat n d) ...)
; (define (numer r) ...)
; (define (denom r) ...)
; (define (add-int a b) ...)
; (define (add-rat a b) ...)
; (define (int->rational n) (make-rat n 1))
; (define coercion-table (list ...))
; (define (assoc-pair key alist) ...)
; (define (get-coercion from to) ...)
; (define op-table (list ...))
; (define (get op types) ...)
; (define (apply-generic op a b) ...)
; (define (add x y) (apply-generic 'add x y))
; 最後に (add (make-int 5) (make-rat 1 3))

===expect: 5 + 1/3 = 16/3 (int は rational に強制変換)===
(rational 16 . 3)

===solution: 型強制が働く混合加算を確かめます。 上のセル (:coerce-code) と同じ構成 (pair? / attach-tag / type-tag / contents / make-int / gcd / make-rat / numer / denom / add-int / add-rat / int->rational / coercion-table / assoc-pair / get-coercion / op-table / get / apply-generic / add) を組み立て、最終式として (add (make-int 5) (make-rat 1 3)) を残してください。 op-table に (add int rational) は無いので、a = make-int 5 を int->rational で (rational 5 . 1) に変換してから (add rational rational) が呼ばれ、 5 + 1/3 = 15/3 + 1/3 = 16/3 となります。===
(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (attach-tag tag x) (cons tag x))
(define (type-tag x) (car x))
(define (contents x) (cdr x))
(define (make-int n) (attach-tag 'int n))
(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d) (let ((g (gcd n d))) (attach-tag 'rational (cons (quotient n g) (quotient d g)))))
(define (numer r) (car r))
(define (denom r) (cdr r))
(define (add-int a b) (make-int (+ a b)))
(define (add-rat a b) (make-rat (+ (* (numer a) (denom b)) (* (numer b) (denom a))) (* (denom a) (denom b))))
(define (int->rational n) (make-rat n 1))
(define coercion-table
  (list
    (list (list 'int 'rational) int->rational)))
(define (assoc-pair key alist)
  (cond ((null? alist) nil)
        ((equal? key (car (car alist))) (car alist))
        (t (assoc-pair key (cdr alist)))))
(define (get-coercion from to)
  (let ((entry (assoc-pair (list from to) coercion-table)))
    (if entry (car (cdr entry)) nil)))
(define op-table
  (list
    (list (list 'add 'int 'int) (lambda (a b) (add-int a b)))
    (list (list 'add 'rational 'rational) (lambda (a b) (add-rat a b)))))
(define (get op types)
  (let ((entry (assoc-pair (cons op types) op-table)))
    (if entry (car (cdr entry)) nil)))
(define (apply-generic op a b)
  (let ((ta (type-tag a)) (tb (type-tag b)))
    (let ((proc (get op (list ta tb))))
      (if proc
          (proc (contents a) (contents b))
          (let ((a->b (get-coercion ta tb)))
            (if a->b
                (apply-generic op (a->b (contents a)) b)
                (let ((b->a (get-coercion tb ta)))
                  (if b->a (apply-generic op a (b->a (contents b))) 'no-method))))))))
(define (add x y) (apply-generic 'add x y))
(add (make-int 5) (make-rat 1 3))

===exercise: 型強制手続きそのものを確かめます。 make-rat と int->rational を定義して、最終式として (int->rational 7) を残してください。整数 7 を分母 1 の有理数に変換するので、 結果は (rational 7 . 1) になります。===
; (define (pair? x) ...)
; (define (attach-tag tag x) (cons tag x))
; (define (gcd a b) ...)
; (define (make-rat n d) ...)
; (define (int->rational n) (make-rat n 1))
; 最後に (int->rational 7)

===expect: 整数 7 → 有理数 7/1===
(rational 7 . 1)

===solution: 型強制手続きそのものを確かめます。 make-rat と int->rational を定義して、最終式として (int->rational 7) を残してください。整数 7 を分母 1 の有理数に変換するので、 結果は (rational 7 . 1) になります。===
(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (attach-tag tag x) (cons tag x))
(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d) (let ((g (gcd n d))) (attach-tag 'rational (cons (quotient n g) (quotient d g)))))
(define (int->rational n) (make-rat n 1))
(int->rational 7)

===prose===
型強制を導入したことで、`add` の呼び出し側コードは **同型・異型の区別すら意識する必要がなくなりました**。新しい型を加えるには (1) 同型用 `op-table` 行と (2) 既存型への `coercion-table` 行を追加するだけです。次節 2.5.3 では同じ枠組みを **記号代数 (多項式)** に拡張します。
