;;;; game/notebooks/sicp-2-2-3.lisp --- SICP 2.2.3 Sequences as Conventional Interfaces.

(defpackage #:recurya/game/notebooks/sicp-2-2-3
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-2-2-3-notebook))

(in-package #:recurya/game/notebooks/sicp-2-2-3)

(defun make-sicp-2-2-3-notebook ()
  "SICP 2.2.3 - Sequences as Conventional Interfaces."
  (make-notebook
   :id :sicp-2-2-3
   :chapter "2.2.3"
   :title "系列を共通インタフェースに"
   :summary "map / filter / accumulate という共通パターンを高階手続きとして与え、問題をデータの流れとして組み立てる"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "リストに対する操作には共通のパターンがあります: "
                           "各要素に関数を適用する "
                           (:code "map")
                           " 、"
                           "条件を満たす要素だけ残す "
                           (:code "filter")
                           " 、"
                           "畳み込みで一つの値にまとめる "
                           (:code "accumulate")
                           " (= reduce) です。")
                       (:p "これらを高階手続きとして用意しておくと、"
                           "多くのリスト処理は「どう書くか」よりも "
                           (:strong "データの流れ")
                           " として簡潔に表現できるようになります。")))
    (make-cell :id :building-blocks-code :kind :code-eval
               :body "(define (my-map f xs)
  (if (null? xs)
      nil
      (cons (f (car xs)) (my-map f (cdr xs)))))
(define (my-filter p xs)
  (cond ((null? xs) nil)
        ((p (car xs)) (cons (car xs) (my-filter p (cdr xs))))
        (t (my-filter p (cdr xs)))))
(define (accumulate op init xs)
  (if (null? xs)
      init
      (op (car xs) (accumulate op init (cdr xs)))))
(list (my-map (lambda (x) (* x x)) (list 1 2 3 4))
      (my-filter (lambda (x) (> x 2)) (list 1 2 3 4 5))
      (accumulate + 0 (list 1 2 3 4 5)))")
    (make-cell :id :compose-prose :kind :prose
               :body '(:div
                       (:p "これら 3 つを組み合わせると、"
                           "「奇数だけを取り出し、それぞれを 2 乗して、和を取る」"
                           "というような問題が "
                           (:strong "1 行のパイプライン")
                           " で書けます。")
                       (:p "問題が "
                           (:code "filter")
                           " -> "
                           (:code "map")
                           " -> "
                           (:code "accumulate")
                           " のデータの流れに分解できる、というのが SICP 2.2.3 のキーアイデアです。")))
    (make-cell :id :compose-code :kind :code-eval
               :body "(define (my-map f xs)
  (if (null? xs)
      nil
      (cons (f (car xs)) (my-map f (cdr xs)))))
(define (my-filter p xs)
  (cond ((null? xs) nil)
        ((p (car xs)) (cons (car xs) (my-filter p (cdr xs))))
        (t (my-filter p (cdr xs)))))
(define (accumulate op init xs)
  (if (null? xs)
      init
      (op (car xs) (accumulate op init (cdr xs)))))
(define (sum-odd-squares xs)
  (accumulate + 0
    (my-map (lambda (x) (* x x))
      (my-filter (lambda (x) (= (mod x 2) 1)) xs))))
(sum-odd-squares (list 1 2 3 4 5 6 7))")
    (make-cell :id :enumerate-prose :kind :prose
               :body '(:div
                       (:p "木の上でも同じ系列インタフェースを使うには、"
                           "まず木を「葉のリスト」に平らに並べる "
                           (:code "enumerate-tree")
                           " を用意します。"
                           "こうすれば木の問題も "
                           (:code "filter / map / accumulate")
                           " のパイプラインに乗ります。")))
    (make-cell :id :enumerate-code :kind :code-eval
               :body "(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (enumerate-tree tr)
  (cond ((null? tr) nil)
        ((not (pair? tr)) (list tr))
        (t (append (enumerate-tree (car tr))
                   (enumerate-tree (cdr tr))))))
(enumerate-tree (list 1 (list 2 (list 3 4)) 5))")
    (make-cell :id :ex-product-list :kind :code-exercise
               :description
               "(product-list xs) を accumulate を使って書いてください。
リストの全要素の積を返します。
accumulate は事前にセル内で再定義しておく必要があります
(引数の順は (op init xs))。
最終式として (product-list (list 1 2 3 4 5)) を残してください。
結果は 120 です。"
               :body "; (define (accumulate op init xs) ...)
; (define (product-list xs) (accumulate ...))
; 最後に (product-list (list 1 2 3 4 5))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "120"
                                     :description "1*2*3*4*5 = 120")))
    (make-cell :id :ex-flatmap :kind :code-exercise
               :description
               "(flatmap f xs) を実装してください。
定義は次のとおりです: (flatmap f xs) = (accumulate append nil (map f xs))
つまり f を各要素に適用した結果のリスト達を、append で 1 本につなぎます。
my-map と accumulate も同じセル内に再定義してください。
最終式として
  (flatmap (lambda (x) (list x (* x x))) (list 1 2 3))
を残してください。結果は (1 1 2 4 3 9) になります。"
               :body "; (define (my-map f xs) ...)
; (define (accumulate op init xs) ...)
; (define (flatmap f xs) (accumulate append nil (my-map f xs)))
; 最後に (flatmap (lambda (x) (list x (* x x))) (list 1 2 3))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "(1 1 2 4 3 9)"
                                     :description "各 x について (x (* x x)) を作り全部つなぐ")))
    (make-cell :id :ex-list-length :kind :code-exercise
               :description
               "リストの長さを accumulate だけで実装してください。
ヒント: (my-length xs) = (accumulate (lambda (_ count) (+ count 1)) 0 xs)
要素そのものは使わず、走査するたびに count を 1 増やします。
accumulate は同じセル内に再定義してください。
最終式として (my-length (list 'a 'b 'c 'd 'e)) を残してください。
結果は 5 です。"
               :body "; (define (accumulate op init xs) ...)
; (define (my-length xs) (accumulate (lambda (_ count) (+ count 1)) 0 xs))
; 最後に (my-length (list 'a 'b 'c 'd 'e))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "5"
                                     :description "要素数 5"))))))
