===prose===
`b^n` (b の n 乗) を計算する素朴な再帰は次の漸化式に基づきます:

- `b^n = b * b^(n-1)`
- `b^0 = 1`

この定義をそのまま手続きにすると、**時間 Θ(n)**・**空間 Θ(n)** になります (再帰呼び出しがスタックに積まれるため)。

===eval===
(define (expt b n)
  (if (= n 0)
      1
      (* b (expt b (- n 1)))))
(expt 2 10)

===prose===
アキュムレータを 1 つ持ち回す反復版に書き直すと、スタックを使わない **時間 Θ(n)・空間 Θ(1)** の手続きになります。

考え方: `product` に途中までの積を貯めながら、`counter` を 0 まで減らします。

===eval===
(define (expt-iter b counter product)
  (if (= counter 0)
      product
      (expt-iter b (- counter 1) (* b product))))
(define (expt-fast b n) (expt-iter b n 1))
(expt-fast 2 10)

===prose===
**もっと速くできます**。次の事実に注目しましょう:

- `n` が偶数なら `b^n = (b^(n/2))^2`
- `n` が奇数なら `b^n = b * b^(n-1)`

偶数のステップで指数 `n` が一気に半分になるので、全体のステップ数は **Θ(log n)** に抑えられます。

たとえば `2^16` は `2^16 = (2^8)^2 = ((2^4)^2)^2 = (((2^2)^2)^2)^2` と 4 回の二乗で計算できます。

===prose===
**WardLisp 注記**: `even?` は組み込みではないので、自分で定義します:

- `(define (even? n) (= (mod n 2) 0))`
- SICP 原典の `remainder` の代わりに `mod` を使います。正の引数では同じ結果になります。
- また `else` の代わりに `(t ...)` を使います。

===eval===
(define (even? n) (= (mod n 2) 0))
(define (square x) (* x x))
(define (fast-expt b n)
  (cond ((= n 0) 1)
        ((even? n) (square (fast-expt b (/ n 2))))
        (t (* b (fast-expt b (- n 1))))))
(fast-expt 2 16)

===exercise: 上で定義した fast-expt を使って (fast-expt 3 12) を計算してください。 even?, square, fast-expt の 3 つを定義してから、最終式に (fast-expt 3 12) を残します。 答え: 3^12 = 531441===
; (define (even? n) ...)
; (define (square x) ...)
; (define (fast-expt b n) ...)
; 最後に (fast-expt 3 12)

===expect: 3^12 = 531441===
531441

===solution: 上で定義した fast-expt を使って (fast-expt 3 12) を計算してください。 even?, square, fast-expt の 3 つを定義してから、最終式に (fast-expt 3 12) を残します。 答え: 3^12 = 531441===
(define (even? n) (= (mod n 2) 0))
(define (square x) (* x x))
(define (fast-expt b n)
  (cond ((= n 0) 1)
        ((even? n) (square (fast-expt b (/ n 2))))
        (t (* b (fast-expt b (- n 1))))))
(fast-expt 3 12)

===exercise: 乗算 * を使わず、加算 + の繰り返しだけで (my-mul a b) を線形反復で書いてください。 SICP 1.18 の簡略版です。a を b 回足し合わせる気持ちで、アキュムレータを使います。 最終式として (my-mul 7 9) を残してください。 答え: 7 * 9 = 63===
; (define (my-mul-iter a b acc) ...)
; (define (my-mul a b) ...)
; 最後に (my-mul 7 9)

===expect: 7 * 9 = 63 を加算反復で===
63

===solution: 乗算 * を使わず、加算 + の繰り返しだけで (my-mul a b) を線形反復で書いてください。 SICP 1.18 の簡略版です。a を b 回足し合わせる気持ちで、アキュムレータを使います。 最終式として (my-mul 7 9) を残してください。 答え: 7 * 9 = 63===
(define (my-mul-iter a b acc)
  (if (= b 0) acc (my-mul-iter a (- b 1) (+ acc a))))
(define (my-mul a b) (my-mul-iter a b 0))
(my-mul 7 9)
