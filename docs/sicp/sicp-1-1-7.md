===prose===
平方根の数学的定義は、`x = sqrt(y)` ⟺ `x ≥ 0` かつ `x*x = y` です。これは **x が何であるか** を述べていますが、**y から x をどう計算するか** を直接は教えてくれません。

Newton 法は、推測 `g` を改善する反復で根に近づく方法です。改善ステップは `g <- (g + y/g)/2` で、これを十分よい近似が得られるまで繰り返します。

===prose===
まず近似誤差を判定する `good-enough?` と改善ステップ `improve` を書きます。

**WardLisp に組み込みの **`abs`** はないので、自分で **`abs-val`** を定義します。**

===eval===
(define (abs-val x) (if (< x 0) (- 0 x) x))
(define (square x) (* x x))
(define (good-enough? guess x)
  (< (abs-val (- (square guess) x)) 0.001))
(good-enough? 1.4 2)

===eval===
(define (improve guess x) (/ (+ guess (/ x guess)) 2))
(improve 1.0 2)

===prose===
これらの部品を組み合わせて、推測を更新し続ける `sqrt-iter` を作ります。判定が真になるまで自分自身を呼び続けるのがポイントです。

===eval===
(define (abs-val x) (if (< x 0) (- 0 x) x))
(define (square x) (* x x))
(define (good-enough? guess x)
  (< (abs-val (- (square guess) x)) 0.001))
(define (improve guess x) (/ (+ guess (/ x guess)) 2))
(define (sqrt-iter guess x)
  (if (good-enough? guess x)
      guess
      (sqrt-iter (improve guess x) x)))
(define (sqrt-y x) (sqrt-iter 1.0 x))
(sqrt-y 9)

===exercise: 上で定義した sqrt-y を使って sqrt(2) を計算してください。 最終式として (sqrt-y 2) を残してください。===
; 最後に (sqrt-y 2) を評価する

===expect: sqrt(2) の Newton 近似===
1.4142156862745097

===solution: 上で定義した sqrt-y を使って sqrt(2) を計算してください。 最終式として (sqrt-y 2) を残してください。===
(sqrt-y 2)

===exercise: 立方根 cbrt を Newton 法で書いてください。 立方根の改善ステップは g <- (x/g^2 + 2g)/3 です。 abs-val・square・cube・good-enough?・improve・cbrt-iter・cbrt を すべて定義し、最終式として (cbrt 27) を残してください。===
; (define (abs-val x) ...)
; (define (square x) ...)
; (define (cube x) ...)
; (define (good-enough? guess x) ...)   ; cube guess と x を比較する
; (define (improve guess x) ...)        ; (/ (+ (/ x (square guess)) (* 2 guess)) 3)
; (define (cbrt-iter guess x) ...)
; (define (cbrt x) (cbrt-iter 1.0 x))
; 最後に (cbrt 27)

===expect: 27 の立方根の Newton 近似===
3.0000005410641766

===solution: 立方根 cbrt を Newton 法で書いてください。 立方根の改善ステップは g <- (x/g^2 + 2g)/3 です。 abs-val・square・cube・good-enough?・improve・cbrt-iter・cbrt を すべて定義し、最終式として (cbrt 27) を残してください。===
(define (abs-val x) (if (< x 0) (- 0 x) x))
(define (square x) (* x x))
(define (cube x) (* x x x))
(define (good-enough? guess x)
  (< (abs-val (- (cube guess) x)) 0.001))
(define (improve guess x)
  (/ (+ (/ x (square guess)) (* 2 guess)) 3))
(define (cbrt-iter guess x)
  (if (good-enough? guess x)
      guess
      (cbrt-iter (improve guess x) x)))
(define (cbrt x) (cbrt-iter 1.0 x))
(cbrt 27)
