;;;; game/notebooks/sicp-2-1-2.lisp --- SICP 2.1.2 Abstraction Barriers.

(defpackage #:recurya/game/notebooks/sicp-2-1-2
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-2-1-2-notebook))

(in-package #:recurya/game/notebooks/sicp-2-1-2)

(defun make-sicp-2-1-2-notebook ()
  "SICP 2.1.2 - Abstraction Barriers."
  (make-notebook
   :id :sicp-2-1-2
   :chapter "2.1.2"
   :title "抽象化障壁"
   :summary "選択子と構築子を境界にして、表現の差し替えに対して上位コードを不変に保つ"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "データ抽象の目的は "
                           (:strong "使う側を表現の詳細から守る")
                           " ことです。"
                           (:code "add-rat") " などの上位手続きが "
                           (:code "numer") " / " (:code "denom") " / "
                           (:code "make-rat")
                           " を介してのみ有理数に触れていれば、"
                           (:strong "表現を差し替えても上位コードは無変更で動く")
                           " という強い性質が得られます。")
                       (:p "本節ではこの性質を実演します。"
                           "「いつ約分するか」という実装の選択を変えても、"
                           "外側の演算 ("
                           (:code "add-rat") " / " (:code "mul-rat")
                           " など) は文字列レベルで一切手を入れる必要がない、"
                           "ということを確認します。")))
    (make-cell :id :version-a-prose :kind :prose
               :body '(:div
                       (:p (:strong "実装 A: 構築時に約分する")
                           " (前節 2.1.1 と同じ)。"
                           (:code "make-rat")
                           " の中で gcd 計算を済ませてしまい、"
                           "選択子は素朴な " (:code "car") " / "
                           (:code "cdr") " のままにします。")))
    (make-cell :id :version-a-code :kind :code-eval
               :body "(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d)
  (let ((g (gcd n d)))
    (cons (quotient n g) (quotient d g))))
(define (numer x) (car x))
(define (denom x) (cdr x))
(define r (make-rat 6 8))
(list (numer r) (denom r))")
    (make-cell :id :version-b-prose :kind :prose
               :body '(:div
                       (:p (:strong "実装 B: 選択子で約分する")
                           "。" (:code "make-rat")
                           " はただ " (:code "cons") " するだけにし、"
                           "代わりに "
                           (:code "numer") " / " (:code "denom")
                           " を呼ぶたびに gcd で約分する。")
                       (:p "これは実装 A とは "
                           (:strong "内部表現も計算タイミングも違う")
                           " のですが…")))
    (make-cell :id :version-b-code :kind :code-eval
               :body "(define (gcd a b) (if (= b 0) a (gcd b (mod a b))))
(define (make-rat n d) (cons n d))
(define (numer x)
  (let ((g (gcd (car x) (cdr x))))
    (quotient (car x) g)))
(define (denom x)
  (let ((g (gcd (car x) (cdr x))))
    (quotient (cdr x) g)))
(define r (make-rat 6 8))
(list (numer r) (denom r))")
    (make-cell :id :invariance-prose :kind :prose
               :body '(:div
                       (:p (:strong "重要")
                           ": " (:code "add-rat")
                           " の実装は実装 A でも実装 B でも "
                           (:strong "1 文字も変えなくてよい")
                           " 。表現の細部に依存しない設計のおかげです。"
                           "これが "
                           (:strong "抽象化障壁 (abstraction barrier)")
                           " の威力です。")
                       (:p "層 (layer) を分けて、"
                           "上の層が下の層の "
                           (:strong "公開インターフェース")
                           " (選択子と構築子) のみに依存する設計を保てば、"
                           "それぞれの層を独立に進化させられます。")
                       (:p "下の練習問題では、"
                           "別の素材 (2 次元の点と線分) で同じデータ抽象を組んでもらいます。"
                           "「" (:code "cons") " で組み立てる」「選択子で取り出す」"
                           "という同じパターンで構築できることを体感してください。")))
    (make-cell :id :ex-line :kind :code-exercise
               :description
               "2 次元の点と線分のデータ抽象を作り、線分の中点を求めてください。

・点: (make-point x y) / (x-point p) / (y-point p)
・線分: (make-segment p1 p2) / (start-segment s) / (end-segment s)
・(midpoint-segment s) は始点と終点の x 座標どうしの平均、
  y 座標どうしの平均を持つ点を返す。

最終式として
  (midpoint-segment (make-segment (make-point 0 0) (make-point 4 6)))
を残してください。中点は (2, 3) で、結果は (2 . 3) になります。"
               :body "; (define (make-point x y) ...)
; (define (x-point p) ...)
; (define (y-point p) ...)
; (define (make-segment p1 p2) ...)
; (define (start-segment s) ...)
; (define (end-segment s) ...)
; (define (midpoint-segment s) ...)
; 最後に (midpoint-segment (make-segment (make-point 0 0) (make-point 4 6)))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "(2 . 3)"
                                     :description "(0,0) と (4,6) の中点は (2,3)"))))))
