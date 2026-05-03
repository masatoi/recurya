===prose===
**SICP 3.1.2** は `set!` で乱数生成器の状態を隠蔽する例で、Monte Carlo 法による π の推定を扱います。原典は次のように書かれます:

```
(define rand
  (let ((x random-init))
    (lambda ()
      (set! x (rand-update x))   ;; ← 状態の更新
      x)))
```

`(rand)` を呼ぶたびに内部の `x` が `set!` で進められ、新しい値が返ります。これにより呼び出し側は **状態を意識せず** 「次の乱数」を取れる、という設計が SICP 3.1.2 のポイントです。

WardLisp v0.2.0 から `(random n)` が組み込みで使えます。SBCL のグローバル PRNG 状態を共有して進めるため、外見上は SICP の `(rand)` と同じく「呼ぶたびに新しい値が返る」形です。

===eval===
(list (random 100) (random 100) (random 100) (random 100))

===prose===
**Monte Carlo 法による π の推定**: [0, n) 区間の整数 (x, y) を 2 つ取り、原点からの距離が n 未満なら円内とカウント。`(円内 / 全試行) × 4 ≒ π`。n を大きくとるほど整数演算でも精度が上がります。

===eval===
(define (square x) (* x x))
(define (in-circle?-int n)
  ;; (random n) を 2 回取り x^2 + y^2 < n^2 で円内判定
  (let ((x (random n)) (y (random n)))
    (< (+ (square x) (square y)) (square n))))
(define (estimate-pi trials n)
  (define (iter k count)
    (cond ((= k 0) (/ (* 4 count) trials))
          ((in-circle?-int n) (iter (- k 1) (+ count 1)))
          (t (iter (- k 1) count))))
  (iter trials 0))
;; 100 試行 / n=1000 で粗い近似 (実行ごとに値は変動)
(estimate-pi 100 1000)

===prose===
**WardLisp 注記**: SICP 原典は `set!` で乱数の状態を隠蔽し `(rand)` を呼ぶたびに新しい値が出る形にします。WardLisp の `(random n)` は内部で SBCL のグローバル PRNG を進めるので、外見上は同じ振る舞いです。違いは「状態を隠蔽する仕組み」が言語の組み込みかユーザコードかです。

完全に純関数で書きたい場合は seed を明示的に持ち回せます。下のセルでは **線形合同法 (LCG)** を自作して、seed を引数として明示的にスレッドする例を示します。

===eval===
(define (lcg seed) (mod (+ (* 1103515245 seed) 12345) 2147483648))
(define (random-1 n seed) (mod seed n))
(define s0 42)
(define s1 (lcg s0))
(define s2 (lcg s1))
(define s3 (lcg s2))
(list (random-1 100 s1) (random-1 100 s2) (random-1 100 s3))

===prose===
**アプローチの比較**:

- **SICP 原典 (set! + 内部状態)**: 呼び出し側は seed を意識しない。状態は隠蔽される。同じ式 `(rand)` が呼ぶたびに違う値を返す ─ **参照透過性は失われる**。
- **WardLisp 組み込み (random n)**: 同じく状態は隠蔽される (SBCL の PRNG が裏にいる)。表面の API は SICP 原典に近い。
- **LCG + 明示的 seed-passing**: seed を引数として明示的に渡す。同じ seed なら **決定的に同じ結果** になる ─ 参照透過性が保たれる。テストの再現性、並列実行の安全性、デバッグの容易さが得られる。

===exercise: 線形合同法 (LCG) で seed を 3 回進めた値を返します。 (define (lcg seed) (mod (+ (* 1103515245 seed) 12345) 2147483648)) を定義し、最終式として (lcg (lcg (lcg 42))) を残してください。決定的なので何度実行しても同じ値になります。 答え: 1000676753 (SBCL での具体値; 任意の言語で同じ式を評価すれば同値)。===
; (define (lcg seed) (mod (+ (* 1103515245 seed) 12345) 2147483648))
; 最後に (lcg (lcg (lcg 42)))

===expect: LCG(42) を 3 回適用した決定的な値===
1000676753

===solution: 線形合同法 (LCG) で seed を 3 回進めた値を返します。 (define (lcg seed) (mod (+ (* 1103515245 seed) 12345) 2147483648)) を定義し、最終式として (lcg (lcg (lcg 42))) を残してください。決定的なので何度実行しても同じ値になります。 答え: 1000676753 (SBCL での具体値; 任意の言語で同じ式を評価すれば同値)。===
(define (lcg seed) (mod (+ (* 1103515245 seed) 12345) 2147483648))
(lcg (lcg (lcg 42)))
