===prose===
整数 `n` が素数かどうかを判定するもっとも素朴な方法は、**試し割り法** です。`2` から順に `√n` 以下の整数で割り、割り切れる数が見つかれば合成数、見つからなければ素数だと結論します。

`√n` まで調べれば十分なのは、もし `n = a * b` で `a ≤ b` なら必ず `a ≤ √n` が成り立つからです。

===eval===
(define (square x) (* x x))
(define (divides? a b) (= (mod b a) 0))
(define (find-divisor n test)
  (cond ((> (square test) n) n)
        ((divides? test n) test)
        (t (find-divisor n (+ test 1)))))
(define (smallest-divisor n) (find-divisor n 2))
(define (prime? n) (= (smallest-divisor n) n))
(list (prime? 7) (prime? 12) (smallest-divisor 199))

===prose===
`smallest-divisor` は最悪でも `√n` 回ループするので、ステップ数は **Θ(√n)** です。

実用速度の目安:

- `(prime? 1009)` — ほぼ瞬時
- `(prime? 1000003)` — 実用範囲で動作
- `(prime? 10000000019)` — 大きな素数になると重くなる

===prose===
**WardLisp 注記**: SICP 原典の `(remainder b a)` は WardLisp では `(mod b a)` と書きます。また `cond` の `else` 節は WardLisp では `(t ...)` と書きます。

===prose===
**Fermat テスト**: フェルマーの小定理は `n が素数なら、任意の a (1 ≤ a < n) について a^n ≡ a (mod n)` と主張します。

この性質を使い、ランダムに `a` を選んで合同式を検査することで、**確率的に** 素数判定する手法が Fermat テストです。1 回の試行は `Θ(log n)` で動きます。

**WardLisp 注記**: Fermat テストには乱数が必要ですが、WardLisp v0.2.0 から `(random n)` が使えるようになりました。`0` 以上 `n` 未満の整数を返します。

===eval===
(define (square x) (* x x))
(define (even? n) (= (mod n 2) 0))
(define (expmod base exp m)
  (cond ((= exp 0) 1)
        ((even? exp) (mod (square (expmod base (/ exp 2) m)) m))
        (t (mod (* base (expmod base (- exp 1) m)) m))))
(define (fermat-test n)
  (define a (+ 1 (random (- n 1))))
  (= (expmod a n n) a))
(define (fast-prime? n times)
  (cond ((= times 0) t)
        ((fermat-test n) (fast-prime? n (- times 1)))
        (t nil)))
;; 1009 は素数。5 回試行すれば事実上常に t になる
(list (fast-prime? 1009 5) (fast-prime? 100 5))

===exercise: 試し割り法で (prime? 1009) の値を求めてください。 square / divides? / find-divisor / smallest-divisor / prime? を順に定義し、 最終式として (prime? 1009) を残します。 答え: t (1009 は素数)===
; (define (square x) ...)
; (define (divides? a b) ...)
; (define (find-divisor n test) ...)
; (define (smallest-divisor n) ...)
; (define (prime? n) ...)
; 最後に (prime? 1009)

===expect: 1009 は素数===
t

===solution: 試し割り法で (prime? 1009) の値を求めてください。 square / divides? / find-divisor / smallest-divisor / prime? を順に定義し、 最終式として (prime? 1009) を残します。 答え: t (1009 は素数)===
(define (square x) (* x x))
(define (divides? a b) (= (mod b a) 0))
(define (find-divisor n test)
  (cond ((> (square test) n) n)
        ((divides? test n) test)
        (t (find-divisor n (+ test 1)))))
(define (smallest-divisor n) (find-divisor n 2))
(define (prime? n) (= (smallest-divisor n) n))
(prime? 1009)

===exercise: n 以上の最小の素数を返す (next-prime n) を書いてください。 prime? を再利用し、n が素数ならそのまま、そうでなければ (next-prime (+ n 1)) を呼びます。 最終式として (next-prime 100) を残します。 答え: 101===
; (define (square x) ...)
; (define (divides? a b) ...)
; (define (find-divisor n test) ...)
; (define (smallest-divisor n) ...)
; (define (prime? n) ...)
; (define (next-prime n) ...)
; 最後に (next-prime 100)

===expect: 100 以上の最小の素数は 101===
101

===solution: n 以上の最小の素数を返す (next-prime n) を書いてください。 prime? を再利用し、n が素数ならそのまま、そうでなければ (next-prime (+ n 1)) を呼びます。 最終式として (next-prime 100) を残します。 答え: 101===
(define (square x) (* x x))
(define (divides? a b) (= (mod b a) 0))
(define (find-divisor n test)
  (cond ((> (square test) n) n)
        ((divides? test n) test)
        (t (find-divisor n (+ test 1)))))
(define (smallest-divisor n) (find-divisor n 2))
(define (prime? n) (= (smallest-divisor n) n))
(define (next-prime n)
  (if (prime? n) n (next-prime (+ n 1))))
(next-prime 100)

===exercise: Fermat テストで素数判定する (fast-prime? n times) を書いてください。 square / even? / expmod / fermat-test / fast-prime? を上記 fermat-impl と同じに定義し、 最終式として (fast-prime? 1009 5) を残します。 答え: t (1009 は素数なので Fermat テストは決定的に t を返す)===
; (define (square x) ...)
; (define (even? n) ...)
; (define (expmod base exp m) ...)
; (define (fermat-test n) ...)
; (define (fast-prime? n times) ...)
; 最後に (fast-prime? 1009 5)

===expect: 1009 を Fermat テストで判定===
t

===solution: Fermat テストで素数判定する (fast-prime? n times) を書いてください。 square / even? / expmod / fermat-test / fast-prime? を上記 fermat-impl と同じに定義し、 最終式として (fast-prime? 1009 5) を残します。 答え: t (1009 は素数なので Fermat テストは決定的に t を返す)===
(define (square x) (* x x))
(define (even? n) (= (mod n 2) 0))
(define (expmod base exp m)
  (cond ((= exp 0) 1)
        ((even? exp) (mod (square (expmod base (/ exp 2) m)) m))
        (t (mod (* base (expmod base (- exp 1) m)) m))))
(define (fermat-test n)
  (define a (+ 1 (random (- n 1))))
  (= (expmod a n n) a))
(define (fast-prime? n times)
  (cond ((= times 0) t)
        ((fermat-test n) (fast-prime? n (- times 1)))
        (t nil)))
(fast-prime? 1009 5)
