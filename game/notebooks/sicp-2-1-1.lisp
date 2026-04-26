;;;; game/notebooks/sicp-2-1-1.lisp --- SICP 2.1.1 Rational Numbers.

(defpackage #:recurya/game/notebooks/sicp-2-1-1
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-2-1-1-notebook))

(in-package #:recurya/game/notebooks/sicp-2-1-1)

(defun make-sicp-2-1-1-notebook ()
  "SICP 2.1.1 - Rational Numbers."
  (make-notebook
   :id :sicp-2-1-1
   :chapter "2.1.1"
   :title "有理数の演算"
   :summary "cons でペアとして有理数を表現し、データ抽象 make-rat / numer / denom の上に四則演算を積み上げる"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "有理数 " (:code "n/d") " を "
                           (:code "cons") " でペアとして表現します。"
                           (:strong "データ抽象")
                           " として "
                           (:code "make-rat") " / "
                           (:code "numer") " / "
                           (:code "denom")
                           " を構成し、その上に "
                           (:code "add-rat") " / "
                           (:code "sub-rat") " / "
                           (:code "mul-rat") " / "
                           (:code "div-rat")
                           " を組み立てます。")
                       (:p "本節のポイントは、"
                           (:strong "「有理数とは何か」を 3 つの関数 (構築子と 2 つの選択子) だけで定義する")
                           " ことです。これがデータ抽象の最小単位です。")))
    (make-cell :id :basic-rep :kind :code-eval
               :body "(define (make-rat n d) (cons n d))
(define (numer x) (car x))
(define (denom x) (cdr x))
(define r (make-rat 3 4))
(list (numer r) (denom r))")
    (make-cell :id :reduction-prose :kind :prose
               :body '(:div
                       (:p "これだけだと " (:code "1/2") " と "
                           (:code "2/4")
                           " が別物に見えます。"
                           (:strong "最大公約数 (GCD)")
                           " で約分してから格納すれば、"
                           "同じ値の有理数は同じ表現になります。")
                       (:p "ユークリッドの互除法で "
                           (:code "gcd") " を定義し、"
                           (:code "make-rat") " の中で約分を済ませます。"
                           "選択子 " (:code "numer") "/" (:code "denom")
                           " は単なる " (:code "car") "/" (:code "cdr")
                           " のままです。")))
    (make-cell :id :reduced-rep :kind :code-eval
               :body "(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d)
  (let ((g (gcd n d)))
    (cons (quotient n g) (quotient d g))))
(define (numer x) (car x))
(define (denom x) (cdr x))
(make-rat 6 8)")
    (make-cell :id :arith-prose :kind :prose
               :body '(:div
                       (:p "四則演算は分子分母の式で書けます。例えば加算:")
                       (:pre
                        " n1   n2     n1*d2 + n2*d1
 -- + -- = ---------------
 d1   d2        d1*d2")
                       (:p "選択子 " (:code "numer") " / "
                           (:code "denom")
                           " と構築子 "
                           (:code "make-rat") " さえ使えば、"
                           "内部表現に触れずに加算が書けます。")))
    (make-cell :id :add-rat :kind :code-eval
               :body "(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d)
  (let ((g (gcd n d)))
    (cons (quotient n g) (quotient d g))))
(define (numer x) (car x))
(define (denom x) (cdr x))
(define (add-rat x y)
  (make-rat (+ (* (numer x) (denom y)) (* (numer y) (denom x)))
            (* (denom x) (denom y))))
(add-rat (make-rat 1 2) (make-rat 1 3))")
    (make-cell :id :ex-mul-rat :kind :code-exercise
               :description
               "乗算 mul-rat を書いてください。式は:
  (n1/d1) * (n2/d2) = (n1*n2) / (d1*d2)
make-rat / numer / denom を使い、内部表現には触れないこと。
最終式として (mul-rat (make-rat 2 3) (make-rat 3 4)) を残してください。
make-rat が約分するので、結果は (1 . 2) になります。"
               :body "; gcd / make-rat / numer / denom は上で定義済みのものを再掲してから
; (define (mul-rat x y) ...)
; 最後に (mul-rat (make-rat 2 3) (make-rat 3 4))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "(1 . 2)"
                                     :description "(2/3) * (3/4) = 1/2")))
    (make-cell :id :ex-equal-rat :kind :code-exercise
               :description
               "有理数の等価判定 (equal-rat? x y) を書いてください。
内部表現に依存せず、numer / denom だけで判定します:
  n1*d2 = n2*d1 のとき等しい。
最終式として (equal-rat? (make-rat 2 4) (make-rat 1 2)) を残してください。
答えは t になります。"
               :body "; gcd / make-rat / numer / denom は上で定義済みのものを再掲してから
; (define (equal-rat? x y) ...)
; 最後に (equal-rat? (make-rat 2 4) (make-rat 1 2))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "t"
                                     :description "2/4 と 1/2 は同じ有理数"))))))
