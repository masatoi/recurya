;;;; game/notebooks/sicp-2-5-1.lisp --- SICP 2.5.1 Generic arithmetic operations.

(defpackage #:recurya/game/notebooks/sicp-2-5-1
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-2-5-1-notebook))

(in-package #:recurya/game/notebooks/sicp-2-5-1)

(defun make-sicp-2-5-1-notebook ()
  "SICP 2.5.1 - Generic Arithmetic Operations."
  (make-notebook
   :id :sicp-2-5-1
   :chapter "2.5.1"
   :title "ジェネリック算術演算"
   :summary "add / sub / mul / div を整数・有理数・複素数のいずれにも同じ API で適用する。型タグ + 静的 op-table のディスパッチで型ごとの演算を呼び分ける"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:code "add")
                           " / "
                           (:code "sub")
                           " / "
                           (:code "mul")
                           " / "
                           (:code "div")
                           " を "
                           (:strong "どの数値型でも同じ API で")
                           " 呼べるようにしたい。"
                           (:code "(add 1 2)")
                           " でも "
                           (:code "(add (make-rat 1 2) (make-rat 1 3))")
                           " でも、呼び出し側のコードを変えずに動かせるのが目標です。")
                       (:p "本ノートでは整数 (int) と有理数 (rational) の 2 種類を例に、"
                           (:strong "ジェネリック算術演算 (generic arithmetic operations)")
                           " を構成します。")))
    (make-cell :id :design-prose :kind :prose
               :body '(:div
                       (:p (:strong "設計")
                           ": 各値に型タグ "
                           (:code "'int")
                           " または "
                           (:code "'rational")
                           " を付け、"
                           (:strong "静的な op-table")
                           " に登録した手続きを "
                           (:code "(op type1 type2)")
                           " のキーでディスパッチして呼び出します (2.4.3 と同じ要領)。")
                       (:p "ジェネリック関数 "
                           (:code "(add x y)")
                           " は内部で "
                           (:code "(apply-generic 'add x y)")
                           " を呼び、引数のタグに応じて "
                           (:code "add-int")
                           " か "
                           (:code "add-rat")
                           " を選択します。")))
    (make-cell :id :variadic-note :kind :prose
               :body '(:div
                       (:p (:strong "WardLisp 注記")
                           ": SICP 原典の "
                           (:code "apply-generic")
                           " は可変長引数 "
                           (:code "(apply-generic op . args)")
                           " で書かれていますが、WardLisp は "
                           (:strong "可変長 lambda をサポートしていない")
                           " ため、本ノートでは "
                           (:strong "2 引数固定版")
                           " "
                           (:code "(apply-generic op a b)")
                           " で記述します。")))
    (make-cell :id :int-rat-code :kind :code-eval
               :body "(define (pair? x) (and (not (null? x)) (not (atom? x))))
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
(list (add (make-int 3) (make-int 4)) (add (make-rat 1 2) (make-rat 1 3)))")
    (make-cell :id :additivity-prose :kind :prose
               :body '(:div
                       (:p "上のセルでは整数同士は "
                           (:code "add-int")
                           " で、有理数同士は "
                           (:code "add-rat")
                           " で計算されました。"
                           (:strong "呼び出し側コードは型を意識しません")
                           " ─ これが "
                           (:strong "ジェネリック演算")
                           " の威力です。")
                       (:p "新しい数値型 (例: complex) を追加するには、"
                           (:code "make-complex")
                           " / "
                           (:code "add-complex")
                           " / "
                           (:code "mul-complex")
                           " を実装し、"
                           (:code "op-table")
                           " に行を追加するだけで済みます。次節 2.5.2 では "
                           (:strong "異なる型同士")
                           " の演算を扱います。")))
    (make-cell :id :ex-int-add :kind :code-exercise
               :description
               "整数のジェネリック加算を確かめます。
上のセルと同じ構成 (pair? / attach-tag / type-tag / contents /
make-int / add-int / mul-int / make-rat / numer / denom / add-rat / mul-rat /
op-table / assoc-pair / get / apply-generic / add / mul) を組み立て、
最終式として
  (add (make-int 5) (make-int 7))
を残してください。期待値は (int . 12) という形式の値です。"
               :body "; (define (pair? x) ...)
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
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "(int . 12)"
                                     :description "(make-int 5) + (make-int 7) = (int . 12)")))
    (make-cell :id :ex-rat-mul :kind :code-exercise
               :description
               "有理数のジェネリック乗算を確かめます。
上のセルと同じ構成を組み立て、最終式として
  (mul (make-rat 2 3) (make-rat 3 4))
を残してください。 (2/3) * (3/4) = 6/12 = 1/2。
make-rat は gcd で約分するため、結果は (rational 1 . 2) になります。"
               :body "; (define (pair? x) ...)
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
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "(rational 1 . 2)"
                                     :description "(2/3) * (3/4) = 1/2")))
    (make-cell :id :wrap-prose :kind :prose
               :body '(:div
                       (:p "これで "
                           (:code "add")
                           " / "
                           (:code "mul")
                           " の呼び出し側コードは "
                           (:strong "型を意識せずに")
                           " 書けるようになりました。次節では "
                           (:code "(add (make-int 3) (make-rat 1 2))")
                           " のように "
                           (:strong "異なる型を混ぜた")
                           " 演算を、型の自動変換 (coercion) で実現する方法を見ます。"))))))
