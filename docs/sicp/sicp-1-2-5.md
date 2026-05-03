===prose===
`(gcd a b)` は 2 つの整数 `a` と `b` の **最大公約数** (Greatest Common Divisor) を返す手続きです。

ユークリッド (Euclid) の鋭い観察:

- `gcd(a, b) = gcd(b, a mod b)`
- `gcd(a, 0) = a`

この 2 つの規則を再帰的に適用するだけで、最大公約数が求まります。

===prose===
**WardLisp 注記**: SICP 原典では `remainder` を使いますが、WardLisp では `mod` を使います。正の引数の範囲ではどちらも同じ結果になります。

===eval===
(define (gcd a b)
  (if (= b 0)
      a
      (gcd b (mod a b))))
(gcd 206 40)

===prose===
**Lamé の定理**: ユークリッドの互除法が `k` ステップで終わるとき、`b ≥ Fib(k)` (フィボナッチ数列の k 番目以上) が成り立ちます。

フィボナッチ数列は指数的に増えるので、逆に言えば `gcd` のステップ数は入力 `b` の桁数 (= `log b`) に対して **Θ(log n)** で抑えられます。非常に高速です。

===exercise: (gcd 1071 462) を計算してください。 ユークリッドの互除法をそのまま定義し、最終式として (gcd 1071 462) を残します。 答え: 21===
; (define (gcd a b) ...)
; 最後に (gcd 1071 462)

===expect: gcd(1071, 462) = 21===
21

===solution: (gcd 1071 462) を計算してください。 ユークリッドの互除法をそのまま定義し、最終式として (gcd 1071 462) を残します。 答え: 21===
(define (gcd a b)
  (if (= b 0) a (gcd b (mod a b))))
(gcd 1071 462)

===exercise: 最小公倍数 lcm は (lcm a b) = (a * b) / (gcd a b) で求まります。 gcd を使って lcm を定義し、最終式として (lcm 12 18) を残してください。 答え: lcm(12, 18) = 36===
; (define (gcd a b) ...)
; (define (lcm a b) ...)
; 最後に (lcm 12 18)

===expect: lcm(12, 18) = 36===
36

===solution: 最小公倍数 lcm は (lcm a b) = (a * b) / (gcd a b) で求まります。 gcd を使って lcm を定義し、最終式として (lcm 12 18) を残してください。 答え: lcm(12, 18) = 36===
(define (gcd a b)
  (if (= b 0) a (gcd b (mod a b))))
(define (lcm a b) (/ (* a b) (gcd a b)))
(lcm 12 18)
