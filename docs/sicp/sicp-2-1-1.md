===prose===
有理数 `n/d` を `cons` でペアとして表現します。**データ抽象** として `make-rat` / `numer` / `denom` を構成し、その上に `add-rat` / `sub-rat` / `mul-rat` / `div-rat` を組み立てます。

本節のポイントは、**「有理数とは何か」を 3 つの関数 (構築子と 2 つの選択子) だけで定義する** ことです。これがデータ抽象の最小単位です。

===eval===
(define (make-rat n d) (cons n d))
(define (numer x) (car x))
(define (denom x) (cdr x))
(define r (make-rat 3 4))
(list (numer r) (denom r))

===prose===
これだけだと `1/2` と `2/4` が別物に見えます。**最大公約数 (GCD)** で約分してから格納すれば、同じ値の有理数は同じ表現になります。

ユークリッドの互除法で `gcd` を定義し、`make-rat` の中で約分を済ませます。選択子 `numer`/`denom` は単なる `car`/`cdr` のままです。

===eval===
(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d)
  (let ((g (gcd n d)))
    (cons (quotient n g) (quotient d g))))
(define (numer x) (car x))
(define (denom x) (cdr x))
(make-rat 6 8)

===prose===
四則演算は分子分母の式で書けます。例えば加算:

```
 n1   n2     n1*d2 + n2*d1
 -- + -- = ---------------
 d1   d2        d1*d2
```

選択子 `numer` / `denom` と構築子 `make-rat` さえ使えば、内部表現に触れずに加算が書けます。

===eval===
(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d)
  (let ((g (gcd n d)))
    (cons (quotient n g) (quotient d g))))
(define (numer x) (car x))
(define (denom x) (cdr x))
(define (add-rat x y)
  (make-rat (+ (* (numer x) (denom y)) (* (numer y) (denom x)))
            (* (denom x) (denom y))))
(add-rat (make-rat 1 2) (make-rat 1 3))

===exercise: 乗算 mul-rat を書いてください。式は: (n1/d1) * (n2/d2) = (n1*n2) / (d1*d2) make-rat / numer / denom を使い、内部表現には触れないこと。 最終式として (mul-rat (make-rat 2 3) (make-rat 3 4)) を残してください。 make-rat が約分するので、結果は (1 . 2) になります。===
; gcd / make-rat / numer / denom は上で定義済みのものを再掲してから
; (define (mul-rat x y) ...)
; 最後に (mul-rat (make-rat 2 3) (make-rat 3 4))

===expect: (2/3) * (3/4) = 1/2===
(1 . 2)

===solution: 乗算 mul-rat を書いてください。式は: (n1/d1) * (n2/d2) = (n1*n2) / (d1*d2) make-rat / numer / denom を使い、内部表現には触れないこと。 最終式として (mul-rat (make-rat 2 3) (make-rat 3 4)) を残してください。 make-rat が約分するので、結果は (1 . 2) になります。===
(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d) (let ((g (gcd n d))) (cons (quotient n g) (quotient d g))))
(define (numer x) (car x))
(define (denom x) (cdr x))
(define (mul-rat x y) (make-rat (* (numer x) (numer y)) (* (denom x) (denom y))))
(mul-rat (make-rat 2 3) (make-rat 3 4))

===exercise: 有理数の等価判定 (equal-rat? x y) を書いてください。 内部表現に依存せず、numer / denom だけで判定します: n1*d2 = n2*d1 のとき等しい。 最終式として (equal-rat? (make-rat 2 4) (make-rat 1 2)) を残してください。 答えは t になります。===
; gcd / make-rat / numer / denom は上で定義済みのものを再掲してから
; (define (equal-rat? x y) ...)
; 最後に (equal-rat? (make-rat 2 4) (make-rat 1 2))

===expect: 2/4 と 1/2 は同じ有理数===
t

===solution: 有理数の等価判定 (equal-rat? x y) を書いてください。 内部表現に依存せず、numer / denom だけで判定します: n1*d2 = n2*d1 のとき等しい。 最終式として (equal-rat? (make-rat 2 4) (make-rat 1 2)) を残してください。 答えは t になります。===
(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d) (let ((g (gcd n d))) (cons (quotient n g) (quotient d g))))
(define (numer x) (car x))
(define (denom x) (cdr x))
(define (equal-rat? x y) (= (* (numer x) (denom y)) (* (numer y) (denom x))))
(equal-rat? (make-rat 2 4) (make-rat 1 2))
