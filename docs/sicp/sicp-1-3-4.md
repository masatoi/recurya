===prose===
手続きが **値を返す** ように、別の **手続きを返す** こともできます。これによって、処理を組み合わせるパターンそのものを抽象化できます。

本節では 2 つの典型例を見ます: **平均緩和 (average-damp)** と **反復改善 (iterative-improve)** です。どちらも「関数を受け取って関数を返す」高階手続きで、計算戦略そのものを再利用可能な部品にします。

===prose===
**平均緩和 (average-damp)**: 関数 `f` の代わりに、`x` と `f(x)` の **平均** を返す関数を使う変換です。

`(average-damp f)` は、`(lambda (x) (/ (+ x (f x)) 2))` という新しい関数を返します。これは反復したときに振動しがちな計算を緩めて収束しやすくする効果があります。

===eval===
(define (average-damp f)
  (lambda (x) (/ (+ x (f x)) 2)))
;; ((average-damp square) 10) = (10 + 100) / 2 = 55
((average-damp (lambda (x) (* x x))) 10)

===prose===
前節 1.3.3 で見たように、`y/x` を反復すると振動するので、そのままでは不動点に収束しません。そこで `average-damp` を噛ませて緩めます。

`(sqrt y) = (fixed-point (average-damp (lambda (x) (/ y x))) 1.0)` と書くだけで平方根が得られます。「不動点反復」と「平均緩和」という 2 つの汎用手法を合成しただけで具体的なアルゴリズムが立ち上がります。

===eval===
(define (abs-val x) (if (< x 0) (- 0 x) x))
(define (close-enough? a b) (< (abs-val (- a b)) 0.0001))
(define (fixed-point f start)
  (define (try g) (let ((next (f g))) (if (close-enough? g next) next (try next))))
  (try start))
(define (average-damp f) (lambda (x) (/ (+ x (f x)) 2)))
(define (my-sqrt y) (fixed-point (average-damp (lambda (x) (/ y x))) 1.0))
(my-sqrt 16)

===prose===
**反復改善 (iterative-improve)**: `good-enough?` 述語と `improve` 関数を受け取って、「初期推測から十分良い答えになるまで improve を繰り返し適用する手続き」を返す高階関数です。

Newton 法も sqrt も区分求積も、「良くなるまで改善を繰り返す」という形に収まります。そのパターンを 1 個の高階手続きとして抜き出すわけです。

===eval===
(define (abs-val x) (if (< x 0) (- 0 x) x))
(define (iterative-improve good-enough? improve)
  (lambda (guess)
    (define (iter g) (if (good-enough? g) g (iter (improve g))))
    (iter guess)))
;; sqrt: 改善は average-damp、十分良い? は g*g が y にほぼ等しいか
(define (sqrt-ii y)
  ((iterative-improve
    (lambda (g) (< (abs-val (- (* g g) y)) 0.001))
    (lambda (g) (/ (+ g (/ y g)) 2)))
   1.0))
(sqrt-ii 25)

===prose===
**WardLisp 注記**: SICP のこの節には、**状態を持つ手続き** (例えば内部カウンタを持つ `make-counter` や残高を更新する `make-account` など) を作る話題も含まれます。ですが本書 WardLisp には `set!` による代入が無いため、これらの「内部状態を書き換える」例はそのまま再現できません。

状態と代入は SICP 第 3 章で正面から扱う題材で、第 1 章の範囲では純粋関数だけで充分強力に抽象化できる、ということを確認できれば本節のエッセンスは押さえられます。そこで本ノートブックでは、状態を使わない例 (`compose` と `double`) に絞って練習問題を出します。

===exercise: 関数合成 compose を書いてください。 (compose f g) は新しい関数を返し、その関数は (f (g x)) を計算します。 具体的には: (define (compose f g) (lambda (x) (f (g x)))) 最終式として ((compose (lambda (x) (* x x)) (lambda (x) (+ x 1))) 4) を残してください。 4 → 5 → 25 と計算され、答えは 25 になります。===
; (define (compose f g) ...)
; 最後に ((compose (lambda (x) (* x x)) (lambda (x) (+ x 1))) 4)

===expect: (compose square inc) を 4 に適用===
25

===solution: 関数合成 compose を書いてください。 (compose f g) は新しい関数を返し、その関数は (f (g x)) を計算します。 具体的には: (define (compose f g) (lambda (x) (f (g x)))) 最終式として ((compose (lambda (x) (* x x)) (lambda (x) (+ x 1))) 4) を残してください。 4 → 5 → 25 と計算され、答えは 25 になります。===
(define (compose f g) (lambda (x) (f (g x))))
((compose (lambda (x) (* x x)) (lambda (x) (+ x 1))) 4)

===exercise: 高階手続き double を書いてください。 (double f) は新しい関数を返し、その関数は f を 2 回適用します: ((double f) x) = (f (f x)) 具体的には: (define (double f) (lambda (x) (f (f x)))) 最終式として ((double (lambda (x) (+ x 1))) 5) を残してください。 5 に 1 を足す関数を 2 回適用するので、答えは 7 になります。===
; (define (double f) ...)
; 最後に ((double (lambda (x) (+ x 1))) 5)

===expect: +1 を 2 回適用して 5 → 7===
7

===solution: 高階手続き double を書いてください。 (double f) は新しい関数を返し、その関数は f を 2 回適用します: ((double f) x) = (f (f x)) 具体的には: (define (double f) (lambda (x) (f (f x)))) 最終式として ((double (lambda (x) (+ x 1))) 5) を残してください。 5 に 1 を足す関数を 2 回適用するので、答えは 7 になります。===
(define (double f) (lambda (x) (f (f x))))
((double (lambda (x) (+ x 1))) 5)
