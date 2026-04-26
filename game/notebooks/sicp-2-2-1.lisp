;;;; game/notebooks/sicp-2-2-1.lisp --- SICP 2.2.1 Representing Sequences.

(defpackage #:recurya/game/notebooks/sicp-2-2-1
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-2-2-1-notebook))

(in-package #:recurya/game/notebooks/sicp-2-2-1)

(defun make-sicp-2-2-1-notebook ()
  "SICP 2.2.1 - Representing Sequences."
  (make-notebook
   :id :sicp-2-2-1
   :chapter "2.2.1"
   :title "系列の表現"
   :summary "リストを cons の入れ子で表し、list-ref / length / append / reverse を再帰で組み立てる"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "系列 (sequence) を "
                           (:code "cons")
                           " で並べると "
                           (:code "(cons 1 (cons 2 (cons 3 nil)))")
                           " のような入れ子構造になります。"
                           "これがいわゆる "
                           (:strong "リスト")
                           " です。"
                           (:code "(list 1 2 3)")
                           " はこの cons の入れ子と同じ意味の構文糖です。")
                       (:p "リストの末尾は "
                           (:code "nil")
                           " (空リスト) で表し、"
                           "「これ以上要素がない」ことを示します。")))
    (make-cell :id :basic-code :kind :code-eval
               :body "(define xs (list 1 2 3 4 5))
xs")
    (make-cell :id :car-cdr-prose :kind :prose
               :body '(:div
                       (:p (:code "car")
                           " は先頭要素、"
                           (:code "cdr")
                           " は残りのリストを返します。"
                           "リストを舐める処理は、"
                           (:code "(null? items)")
                           " で空リストか判定し、"
                           "そうでなければ "
                           (:code "(car items)")
                           " と "
                           (:code "(cdr items)")
                           " で再帰する、というパターンになります。")))
    (make-cell :id :ref-length-code :kind :code-eval
               :body "(define (list-ref items n)
  (if (= n 0)
      (car items)
      (list-ref (cdr items) (- n 1))))
(define (my-length items)
  (if (null? items)
      0
      (+ 1 (my-length (cdr items)))))
(list (list-ref (list 'a 'b 'c 'd) 2)
      (my-length (list 1 2 3 4 5)))")
    (make-cell :id :iter-prose :kind :prose
               :body '(:div
                       (:p "再帰呼び出しが「結果に対して何もしない」末尾位置にあれば、"
                           (:strong "反復的プロセス")
                           " になり、空間 Θ(1) で動きます。"
                           (:code "length")
                           " を反復版で書き直してみましょう。")))
    (make-cell :id :length-iter-code :kind :code-eval
               :body "(define (length-iter items count)
  (if (null? items)
      count
      (length-iter (cdr items) (+ count 1))))
(define (my-length items) (length-iter items 0))
(my-length (list 1 2 3 4 5 6 7))")
    (make-cell :id :append-reverse-prose :kind :prose
               :body '(:div
                       (:p (:code "append")
                           " は最初のリストの末尾に 2 番目のリストを連結します。"
                           "再帰でリストを舐めながら、"
                           "空になったらもう一方をそのまま返します。")
                       (:p (:code "reverse")
                           " は先頭から要素を取り出し、"
                           "後ろから前にむかって新しい先頭に積んでいくことで実現できます。")))
    (make-cell :id :append-reverse-code :kind :code-eval
               :body "(define (my-append xs ys)
  (if (null? xs)
      ys
      (cons (car xs) (my-append (cdr xs) ys))))
(define (my-reverse xs)
  (if (null? xs)
      nil
      (my-append (my-reverse (cdr xs)) (list (car xs)))))
(list (my-append (list 1 2) (list 3 4))
      (my-reverse (list 1 2 3 4)))")
    (make-cell :id :ex-last-pair :kind :code-exercise
               :description
               "リストの末尾のペア (要素 1 個だけのリスト) を返す手続き
(last-pair items) を書いてください。
たとえば (last-pair (list 1 2 3)) は (3) (= 3 だけからなるリスト) を返します。
最終式として (last-pair (list 1 2 3)) を残してください。"
               :body "; (define (last-pair items) ...)
; 最後に (last-pair (list 1 2 3))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "(3)"
                                     :description "(last-pair (list 1 2 3)) は要素 1 個のリスト (3)")))
    (make-cell :id :ex-deep-reverse-flat :kind :code-exercise
               :description
               "フラットなリストを反復版で反転する手続き (reverse-iter items) を書いてください。
内部に補助手続き (iter xs acc) を定義し、acc にこれまで取り出した要素を
cons で積んでいくと、自然な反復プロセスになります。
最終式として (reverse-iter (list 1 2 3 4 5)) を残してください。
結果は (5 4 3 2 1) になります。"
               :body "; (define (reverse-iter items)
;   (define (iter xs acc) ...)
;   (iter items nil))
; 最後に (reverse-iter (list 1 2 3 4 5))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "(5 4 3 2 1)"
                                     :description "(reverse-iter (list 1 2 3 4 5)) は (5 4 3 2 1)"))))))
