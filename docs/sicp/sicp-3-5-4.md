===prose===
**SICP 3.5.4** はストリームによる**無限級数**の表現を扱います。π の Leibniz 級数 `π/4 = 1 - 1/3 + 1/5 - 1/7 + ...` を**項のストリーム**として書き、その**部分和ストリーム**を取って精度を上げていきます。

WardLisp は分数を持たないので、結果は浮動小数になります。しかし級数の構造そのもの ― 「次の項を遅延で計算する」「部分和を遅延で蓄積する」― は SICP 原典と同じ形で書けます。

===eval===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
;; pi の Leibniz 級数の項: 1, -1/3, 1/5, -1/7, ...
;; 第 n 項(0 始まり) = ((-1)^n) / (2n+1)
(define (pi-terms n)
  (stream-cons (/ (if (= 0 (mod n 2)) 1 -1) (+ 1 (* 2 n)))
               (lambda () (pi-terms (+ n 1)))))
(stream-take (pi-terms 0) 6)
;; → (1 -0.333... 0.2 -0.142... 0.111... -0.0909...)

===prose===
**部分和ストリーム**: 入力ストリーム `s` に対して、出力 `i` 番目 = `s[0]+s[1]+...+s[i]` を返す。

`partial-sums-helper` で「これまでの累積」`acc` を引数に取り、各位置で次の累積を遅延で計算します。これも完全に遅延評価で、必要な項までしか計算されません。

===eval===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (pi-terms n)
  (stream-cons (/ (if (= 0 (mod n 2)) 1 -1) (+ 1 (* 2 n)))
               (lambda () (pi-terms (+ n 1)))))
(define (partial-sums-helper s acc)
  (let ((next-acc (+ acc (stream-car s))))
    (stream-cons next-acc (lambda () (partial-sums-helper (stream-cdr s) next-acc)))))
(define (partial-sums s) (partial-sums-helper s 0))
;; π/4 の部分和(× 4 で π の近似)
(stream-take (partial-sums (pi-terms 0)) 4)
;; → 1, 1-1/3=0.666..., +1/5=0.866..., -1/7=0.723..., (π/4 ≒ 0.7854 に振動収束)

===prose===
**観察**: `(pi-terms 0)` は無限ストリームのままで、`stream-take 4` で 4 項目までしか実際には評価されない。

重要なのは、partial-sums のような**汎用ストリーム変換器**が、有限/無限を問わず同じ形で書けること。ストリームを「遅延された値の列」と見れば、リストと同じパターンで合成できます。

===exercise: 整数 1, 2, 3, ... の partial-sums(三角数 1, 1+2=3, 1+2+3=6, ...)の先頭 6 項を返してください。 stream-cons / stream-car / stream-cdr / stream-take / integers-from / partial-sums を上で定義しておきます。 最終式: (stream-take (partial-sums (integers-from 1)) 6) → (1 3 6 10 15 21)===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (integers-from n) (stream-cons n (lambda () (integers-from (+ n 1)))))
(define (partial-sums-helper s acc)
  (let ((next-acc (+ acc (stream-car s))))
    (stream-cons next-acc (lambda () (partial-sums-helper (stream-cdr s) next-acc)))))
(define (partial-sums s) (partial-sums-helper s 0))
;; 最終式を書いてください
(stream-take (partial-sums (integers-from 1)) 6)

===expect: 三角数 先頭 6 項===
(1 3 6 10 15 21)

===solution: 整数 1, 2, 3, ... の partial-sums(三角数 1, 1+2=3, 1+2+3=6, ...)の先頭 6 項を返してください。 stream-cons / stream-car / stream-cdr / stream-take / integers-from / partial-sums を上で定義しておきます。 最終式: (stream-take (partial-sums (integers-from 1)) 6) → (1 3 6 10 15 21)===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (integers-from n) (stream-cons n (lambda () (integers-from (+ n 1)))))
(define (partial-sums-helper s acc)
  (let ((next-acc (+ acc (stream-car s))))
    (stream-cons next-acc (lambda () (partial-sums-helper (stream-cdr s) next-acc)))))
(define (partial-sums s) (partial-sums-helper s 0))
(stream-take (partial-sums (integers-from 1)) 6)

===exercise: 整数 1, 2, 3, ... の二乗の累積和を計算してください。 (integers-from 1)、stream-map で二乗、partial-sums を組み合わせ、先頭 5 項を取り出します。 1, 1+4=5, 5+9=14, 14+16=30, 30+25=55。 最終式: (stream-take (partial-sums (stream-map (lambda (x) (* x x)) (integers-from 1))) 5)===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (integers-from n) (stream-cons n (lambda () (integers-from (+ n 1)))))
(define (stream-map f s)
  (if (null? s) nil (stream-cons (f (stream-car s)) (lambda () (stream-map f (stream-cdr s))))))
(define (partial-sums-helper s acc)
  (let ((next-acc (+ acc (stream-car s))))
    (stream-cons next-acc (lambda () (partial-sums-helper (stream-cdr s) next-acc)))))
(define (partial-sums s) (partial-sums-helper s 0))
;; 最終式を書いてください
(stream-take (partial-sums (stream-map (lambda (x) (* x x)) (integers-from 1))) 5)

===expect: 平方数の累積和 先頭 5 項===
(1 5 14 30 55)

===solution: 整数 1, 2, 3, ... の二乗の累積和を計算してください。 (integers-from 1)、stream-map で二乗、partial-sums を組み合わせ、先頭 5 項を取り出します。 1, 1+4=5, 5+9=14, 14+16=30, 30+25=55。 最終式: (stream-take (partial-sums (stream-map (lambda (x) (* x x)) (integers-from 1))) 5)===
(define (stream-cons a thunk) (cons a thunk))
(define (stream-car s) (car s))
(define (stream-cdr s) ((cdr s)))
(define (stream-take s n)
  (if (= n 0) nil (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))
(define (integers-from n) (stream-cons n (lambda () (integers-from (+ n 1)))))
(define (stream-map f s)
  (if (null? s) nil (stream-cons (f (stream-car s)) (lambda () (stream-map f (stream-cdr s))))))
(define (partial-sums-helper s acc)
  (let ((next-acc (+ acc (stream-car s))))
    (stream-cons next-acc (lambda () (partial-sums-helper (stream-cdr s) next-acc)))))
(define (partial-sums s) (partial-sums-helper s 0))
(stream-take (partial-sums (stream-map (lambda (x) (* x x)) (integers-from 1))) 5)
