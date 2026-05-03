===prose===
ここまでの手続きはどれも **数を引数として受け取る** ものでした。Lisp では**手続き自体** も第一級の値なので、他の手続きの引数として渡したり、結果として返したりできます。

これが **高階手続き (higher-order procedure)** です。共通の繰り返し構造を 1 つの汎用手続きとして切り出すための強力な道具になります。

===prose===
次の 3 つの手続きを見比べてみましょう:

- `sum-ints a b` = `a + (a+1) + ... + b`
- `sum-squares a b` = `a^2 + (a+1)^2 + ... + b^2`
- `sum-cubes a b` = `a^3 + (a+1)^3 + ... + b^3`

どれも構造は同じで、違うのは **何を足すか** (項 `f(a)`) と **どう次に進むか** (次の `a` の作り方) だけです。この 2 つを引数化すると、1 つの汎用 `sum` で全部書けます。

===eval===
(define (sum f a next b)
  (if (> a b)
      0
      (+ (f a) (sum f (next a) next b))))
(define (inc x) (+ x 1))
(define (identity x) x)
(sum identity 1 inc 10)

===eval===
(define (sum f a next b)
  (if (> a b) 0 (+ (f a) (sum f (next a) next b))))
(define (inc x) (+ x 1))
(define (square x) (* x x))
(define (cube x) (* x x x))
(list (sum square 1 inc 5) (sum cube 1 inc 4))

===prose===
**手続きを引数として渡す** ことで、繰り返しの構造そのものをひとつの関数にまとめられます。`sum-ints`・`sum-squares`・`sum-cubes` を別々に書く必要はありません。

これは抽象化の一段上の階段です。「数の世界での足し算の繰り返し」を、「項生成と次への進み方をパラメータに取る計算」として見直したわけです。

===exercise: sum の積バージョンとして product を書いてください。 (product f a next b) は f(a) * f(next(a)) * ... * f(b) を返します。 基底ケースは 1 (積の単位元) です。 inc を補助手続きとして使い、最終式に (product (lambda (i) i) 1 inc 5) を残してください。 これは 5! = 120 を計算する式になります。===
; (define (inc x) ...)
; (define (product f a next b) ...)
; 最後に (product (lambda (i) i) 1 inc 5)

===expect: 5! = 120 を product で===
120

===solution: sum の積バージョンとして product を書いてください。 (product f a next b) は f(a) * f(next(a)) * ... * f(b) を返します。 基底ケースは 1 (積の単位元) です。 inc を補助手続きとして使い、最終式に (product (lambda (i) i) 1 inc 5) を残してください。 これは 5! = 120 を計算する式になります。===
(define (inc x) (+ x 1))
(define (product f a next b)
  (if (> a b) 1 (* (f a) (product f (next a) next b))))
(product (lambda (i) i) 1 inc 5)

===exercise: sum と cube と inc を定義し、(sum cube 1 inc 4) を最終式として残してください。 これは 1^3 + 2^3 + 3^3 + 4^3 を計算する式です。 答え: 1 + 8 + 27 + 64 = 100===
; (define (sum f a next b) ...)
; (define (cube x) ...)
; (define (inc x) ...)
; 最後に (sum cube 1 inc 4)

===expect: 1+8+27+64 = 100===
100

===solution: sum と cube と inc を定義し、(sum cube 1 inc 4) を最終式として残してください。 これは 1^3 + 2^3 + 3^3 + 4^3 を計算する式です。 答え: 1 + 8 + 27 + 64 = 100===
(define (sum f a next b)
  (if (> a b) 0 (+ (f a) (sum f (next a) next b))))
(define (cube x) (* x x x))
(define (inc x) (+ x 1))
(sum cube 1 inc 4)

===exercise: Leibniz の公式を有限項で打ち切った近似: pi/8 = 1/(1*3) + 1/(5*7) + 1/(9*11) + ... を計算する (pi-eighth-approx n) を sum を使って書いてください。 n は項の個数です。i 番目の項 (i は 1 から始まる) は 1 / ((4i - 3) * (4i - 1)) となります。 最終式として (pi-eighth-approx 100) を残してください。 答えは 0.39 程度の小数になります (pi/8 ≒ 0.3927)。===
; (define (sum f a next b) ...)
; (define (inc x) ...)
; (define (pi-term i) ...)
; (define (pi-eighth-approx n) ...)
; 最後に (pi-eighth-approx 100)

===expect: 100 項の Leibniz 近似===
0.3920740856048521

===solution: Leibniz の公式を有限項で打ち切った近似: pi/8 = 1/(1*3) + 1/(5*7) + 1/(9*11) + ... を計算する (pi-eighth-approx n) を sum を使って書いてください。 n は項の個数です。i 番目の項 (i は 1 から始まる) は 1 / ((4i - 3) * (4i - 1)) となります。 最終式として (pi-eighth-approx 100) を残してください。 答えは 0.39 程度の小数になります (pi/8 ≒ 0.3927)。===
(define (sum f a next b)
  (if (> a b) 0 (+ (f a) (sum f (next a) next b))))
(define (inc x) (+ x 1))
(define (pi-term i) (/ 1 (* (- (* 4 i) 3) (- (* 4 i) 1))))
(define (pi-eighth-approx n) (sum pi-term 1 inc n))
(pi-eighth-approx 100)
