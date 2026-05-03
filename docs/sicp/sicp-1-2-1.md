===prose===
`(factorial n)` は `n × (n-1) × … × 1` です。再帰的に書くと:

- `(factorial n) = n × (factorial (- n 1))`
- `(factorial 1) = 1`

===eval===
(define (factorial n)
  (if (= n 1)
      1
      (* n (factorial (- n 1)))))
(factorial 6)

===prose===
これは **線形再帰プロセス** です。`(factorial 6)` を計算するには `(* 6 (factorial 5))` の結果を待つ必要があり、未完了の積の連鎖がスタックに残り続けます。

計算過程はこうなります:

```
(factorial 6)
(* 6 (factorial 5))
(* 6 (* 5 (factorial 4)))
(* 6 (* 5 (* 4 (factorial 3))))
...
(* 6 (* 5 (* 4 (* 3 (* 2 1)))))
720
```

プロセスの形状は線形 — 必要な記憶量も計算ステップ数も `n` に比例します。

===prose===
同じ階乗を **反復プロセス** で書くこともできます。アキュムレータ `product` と現在の数 `counter` を引数として持ち回し、`counter` が `max` を超えたら結果を返します。

===eval===
(define (fact-iter product counter max)
  (if (> counter max)
      product
      (fact-iter (* counter product) (+ counter 1) max)))
(define (factorial-it n) (fact-iter 1 1 n))
(factorial-it 6)

===prose===
両者とも `define` の形は再帰呼び出しですが、反復版は **末尾呼び出し** になっており スタックに未完了の式を残しません。WardLisp は末尾呼び出しを最適化するので、大きな `n` でもスタックを消費しません。

重要なのは: **「手続きが再帰的」と「プロセスが再帰的」は別の話** ということです。`fact-iter` は手続き定義としては再帰ですが、走らせると反復プロセスになります。

===exercise: 1 から n までの和 (sum-up-to n) を反復プロセスで書いてください。 アキュムレータと現在値を持ち回す形にし、(sum-up-to 10) を最終式に 残してください。===
; (define (sum-iter total cur max) ...)
; (define (sum-up-to n) (sum-iter 0 1 n))
; 最後に (sum-up-to 10)

===expect: 1+2+...+10 = 55===
55

===solution: 1 から n までの和 (sum-up-to n) を反復プロセスで書いてください。 アキュムレータと現在値を持ち回す形にし、(sum-up-to 10) を最終式に 残してください。===
(define (sum-iter total cur max)
  (if (> cur max)
      total
      (sum-iter (+ total cur) (+ cur 1) max)))
(define (sum-up-to n) (sum-iter 0 1 n))
(sum-up-to 10)

===exercise: (power b n) = b^n を線形再帰プロセスで書いてください。 n が 0 のとき 1 を返し、そうでなければ b と (power b (- n 1)) の積を返します。 (power 2 10) を最終式に残してください。===
; (define (power b n) ...)
; 最後に (power 2 10)

===expect: 2^10 = 1024===
1024

===solution: (power b n) = b^n を線形再帰プロセスで書いてください。 n が 0 のとき 1 を返し、そうでなければ b と (power b (- n 1)) の積を返します。 (power 2 10) を最終式に残してください。===
(define (power b n)
  (if (= n 0)
      1
      (* b (power b (- n 1)))))
(power 2 10)
