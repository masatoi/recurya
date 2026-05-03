===prose===
データ抽象の目的は **使う側を表現の詳細から守る** ことです。`add-rat` などの上位手続きが `numer` / `denom` / `make-rat` を介してのみ有理数に触れていれば、**表現を差し替えても上位コードは無変更で動く** という強い性質が得られます。

本節ではこの性質を実演します。「いつ約分するか」という実装の選択を変えても、外側の演算 (`add-rat` / `mul-rat` など) は文字列レベルで一切手を入れる必要がない、ということを確認します。

===prose===
**実装 A: 構築時に約分する** (前節 2.1.1 と同じ)。`make-rat` の中で gcd 計算を済ませてしまい、選択子は素朴な `car` / `cdr` のままにします。

===eval===
(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d)
  (let ((g (gcd n d)))
    (cons (quotient n g) (quotient d g))))
(define (numer x) (car x))
(define (denom x) (cdr x))
(define r (make-rat 6 8))
(list (numer r) (denom r))

===prose===
**実装 B: 選択子で約分する**。`make-rat` はただ `cons` するだけにし、代わりに `numer` / `denom` を呼ぶたびに gcd で約分する。

これは実装 A とは **内部表現も計算タイミングも違う** のですが…

===eval===
(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d) (cons n d))
(define (numer x)
  (let ((g (gcd (car x) (cdr x))))
    (quotient (car x) g)))
(define (denom x)
  (let ((g (gcd (car x) (cdr x))))
    (quotient (cdr x) g)))
(define r (make-rat 6 8))
(list (numer r) (denom r))

===prose===
**重要**: `add-rat` の実装は実装 A でも実装 B でも **1 文字も変えなくてよい** 。表現の細部に依存しない設計のおかげです。これが **抽象化障壁 (abstraction barrier)** の威力です。

層 (layer) を分けて、上の層が下の層の **公開インターフェース** (選択子と構築子) のみに依存する設計を保てば、それぞれの層を独立に進化させられます。

下の練習問題では、別の素材 (2 次元の点と線分) で同じデータ抽象を組んでもらいます。「`cons` で組み立てる」「選択子で取り出す」という同じパターンで構築できることを体感してください。

===exercise: 2 次元の点と線分のデータ抽象を作り、線分の中点を求めてください。 ・点: (make-point x y) / (x-point p) / (y-point p) ・線分: (make-segment p1 p2) / (start-segment s) / (end-segment s) ・(midpoint-segment s) は始点と終点の x 座標どうしの平均、 y 座標どうしの平均を持つ点を返す。 最終式として (midpoint-segment (make-segment (make-point 0 0) (make-point 4 6))) を残してください。中点は (2, 3) で、結果は (2 . 3) になります。===
; (define (make-point x y) ...)
; (define (x-point p) ...)
; (define (y-point p) ...)
; (define (make-segment p1 p2) ...)
; (define (start-segment s) ...)
; (define (end-segment s) ...)
; (define (midpoint-segment s) ...)
; 最後に (midpoint-segment (make-segment (make-point 0 0) (make-point 4 6)))

===expect: (0,0) と (4,6) の中点は (2,3)===
(2 . 3)

===solution: 2 次元の点と線分のデータ抽象を作り、線分の中点を求めてください。 ・点: (make-point x y) / (x-point p) / (y-point p) ・線分: (make-segment p1 p2) / (start-segment s) / (end-segment s) ・(midpoint-segment s) は始点と終点の x 座標どうしの平均、 y 座標どうしの平均を持つ点を返す。 最終式として (midpoint-segment (make-segment (make-point 0 0) (make-point 4 6))) を残してください。中点は (2, 3) で、結果は (2 . 3) になります。===
(define (make-point x y) (cons x y))
(define (x-point p) (car p))
(define (y-point p) (cdr p))
(define (make-segment p1 p2) (cons p1 p2))
(define (start-segment s) (car s))
(define (end-segment s) (cdr s))
(define (midpoint-segment s)
  (make-point (/ (+ (x-point (start-segment s)) (x-point (end-segment s))) 2)
              (/ (+ (y-point (start-segment s)) (y-point (end-segment s))) 2)))
(midpoint-segment (make-segment (make-point 0 0) (make-point 4 6)))
