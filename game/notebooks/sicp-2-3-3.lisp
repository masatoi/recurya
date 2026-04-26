;;;; game/notebooks/sicp-2-3-3.lisp --- SICP 2.3.3 Representing Sets.

(defpackage #:recurya/game/notebooks/sicp-2-3-3
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-2-3-3-notebook))

(in-package #:recurya/game/notebooks/sicp-2-3-3)

(defun make-sicp-2-3-3-notebook ()
  "SICP 2.3.3 - Representing Sets."
  (make-notebook
   :id :sicp-2-3-3
   :chapter "2.3.3"
   :title "集合の表現"
   :summary "集合を順序なしリスト・順序付きリスト・二分木の 3 通りで表現し、element-of-set? / adjoin-set / union-set / intersection-set の計算量を比較する"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "集合は "
                           (:code "element-of-set?")
                           " / "
                           (:code "adjoin-set")
                           " / "
                           (:code "union-set")
                           " / "
                           (:code "intersection-set")
                           " の 4 操作で表現の差を吸収できます。"
                           "同じ操作集合を 3 通りに実装し、計算量を比較します。")))
    (make-cell :id :unordered-prose :kind :prose
               :body '(:div
                       (:p (:strong "順序なしリスト")
                           ": 重複なし、線形検索。"
                           (:code "element-of-set?")
                           " は Θ(n)、"
                           (:code "adjoin-set")
                           " も Θ(n)。")))
    (make-cell :id :unordered-code :kind :code-eval
               :body "(define (element-of-set? x s)
  (cond ((null? s) nil)
        ((equal? x (car s)) t)
        (t (element-of-set? x (cdr s)))))
(define (adjoin-set x s) (if (element-of-set? x s) s (cons x s)))
(list (element-of-set? 'a '(a b c)) (adjoin-set 'd '(a b c)))")
    (make-cell :id :ordered-prose :kind :prose
               :body '(:div
                       (:p (:strong "順序付きリスト")
                           ": ソート済を保つ。"
                           (:code "element-of-set?")
                           " は Θ(n) だが平均的には早く打ち切れる。"
                           (:code "adjoin-set")
                           " はソートを壊さない位置に挿入。")))
    (make-cell :id :ordered-code :kind :code-eval
               :body "(define (element-of-set?-ordered x s)
  (cond ((null? s) nil)
        ((= x (car s)) t)
        ((< x (car s)) nil)
        (t (element-of-set?-ordered x (cdr s)))))
(list (element-of-set?-ordered 3 (list 1 3 5 7))
      (element-of-set?-ordered 4 (list 1 3 5 7)))")
    (make-cell :id :tree-prose :kind :prose
               :body '(:div
                       (:p (:strong "二分木")
                           ": 各ノード "
                           (:code "(value left right)")
                           "。"
                           (:code "element-of-set?")
                           " は Θ(log n) (バランスしていれば)。")))
    (make-cell :id :tree-code :kind :code-eval
               :body "(define (entry tr) (car tr))
(define (left-branch tr) (car (cdr tr)))
(define (right-branch tr) (car (cdr (cdr tr))))
(define (make-tree entry left right) (list entry left right))
(define (element-of-set?-tree x s)
  (cond ((null? s) nil)
        ((= x (entry s)) t)
        ((< x (entry s)) (element-of-set?-tree x (left-branch s)))
        (t (element-of-set?-tree x (right-branch s)))))
(define sample (make-tree 5 (make-tree 3 nil nil) (make-tree 7 nil nil)))
(list (element-of-set?-tree 3 sample) (element-of-set?-tree 9 sample))")
    (make-cell :id :ex-intersection :kind :code-exercise
               :description
               "順序なしリスト版の (intersection-set s1 s2) を element-of-set? を使って書いてください。
s1 を走査し、s2 にも含まれる要素のみを集める素直な再帰で書けます。
最終式として
  (intersection-set '(a b c d) '(b d e f))
を残してください。s1 の出現順に拾うので結果は (b d) になります。"
               :body "; (define (element-of-set? x s) ...)
; (define (intersection-set s1 s2) ...)
; 最後に (intersection-set '(a b c d) '(b d e f))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "(b d)"
                                     :description "両方に共通する要素のみ")))
    (make-cell :id :ex-union-ordered :kind :code-exercise
               :description
               "順序付きリスト版の (union-set-ordered s1 s2) を merge sort 方式で書いてください。
両方とも昇順ソート済の数値リストとし、結果も昇順・重複なしになるようにします。
最終式として
  (union-set-ordered (list 1 3 5) (list 2 3 4 6))
を残してください。結果は (1 2 3 4 5 6) になります。"
               :body "; (define (union-set-ordered s1 s2) ...)
; 最後に (union-set-ordered (list 1 3 5) (list 2 3 4 6))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "(1 2 3 4 5 6)"
                                     :description "merge 方式で重複を除いて昇順合併"))))))
