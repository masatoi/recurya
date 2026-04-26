;;;; game/notebooks/sicp-2-2-2.lisp --- SICP 2.2.2 Hierarchical Structures.

(defpackage #:recurya/game/notebooks/sicp-2-2-2
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-2-2-2-notebook))

(in-package #:recurya/game/notebooks/sicp-2-2-2)

(defun make-sicp-2-2-2-notebook ()
  "SICP 2.2.2 - Hierarchical Structures."
  (make-notebook
   :id :sicp-2-2-2
   :chapter "2.2.2"
   :title "階層構造"
   :summary "リストの要素として別のリストを持たせると木構造が表現できる。count-leaves / scale-tree / tree-map で再帰的に走査する"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p "リストは要素として別のリストを含めることができます。"
                           "これにより "
                           (:strong "木構造")
                           " を自然に表現できます。"
                           "たとえば "
                           (:code "(list (list 1 2) (list 3 4))")
                           " は 2 階層の木です。")
                       (:p "外側のリストから見ると要素数は 2 ですが、"
                           "「葉」 (leaf, リストでない値) は全部で 4 個あります。")))
    (make-cell :id :basic-code :kind :code-eval
               :body "(define x (list (list 1 2) (list 3 4)))
(list x (length x))")
    (make-cell :id :count-leaves-prose :kind :prose
               :body '(:div
                       (:p "葉の総数を数える "
                           (:code "count-leaves")
                           " を書きましょう。"
                           "WardLisp には "
                           (:code "pair?")
                           " が組み込まれていないので、"
                           "「空リストでなく、原子でもない」値を pair として自前で定義します。"
                           "なお WardLisp では真値 "
                           (:code "t")
                           " は予約語のため、引数名には "
                           (:code "tr")
                           " などを使います。")
                       (:p "再帰の構造は次の 3 ケース: "
                           "空リストなら 0、"
                           "リストでない (= 葉) なら 1、"
                           "そうでなければ "
                           (:code "(car tr)")
                           " と "
                           (:code "(cdr tr)")
                           " の葉の数を足し合わせる、です。")))
    (make-cell :id :count-leaves-code :kind :code-eval
               :body "(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (count-leaves tr)
  (cond ((null? tr) 0)
        ((not (pair? tr)) 1)
        (t (+ (count-leaves (car tr))
              (count-leaves (cdr tr))))))
(count-leaves (list (list 1 2) (list 3 4) 5))")
    (make-cell :id :scale-tree-prose :kind :prose
               :body '(:div
                       (:p "木の操作は "
                           (:strong "car と cdr の両方を再帰")
                           " することで自然に書けます。"
                           "葉に到達したらそこで具体的な操作 (今回は乗算) を行い、"
                           "それ以外なら左右に分かれて再帰、という形です。")))
    (make-cell :id :scale-tree-code :kind :code-eval
               :body "(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (scale-tree tree factor)
  (cond ((null? tree) nil)
        ((not (pair? tree)) (* tree factor))
        (t (cons (scale-tree (car tree) factor)
                 (scale-tree (cdr tree) factor)))))
(scale-tree (list 1 (list 2 (list 3 4) 5) (list 6 7)) 10)")
    (make-cell :id :ex-count-leaves :kind :code-exercise
               :description
               "(count-leaves tr) を書き、与えられた木の葉の総数を計算してください。
WardLisp には pair? が組み込まれていないので、
(define (pair? x) (and (not (null? x)) (not (atom? x))))
を最初に定義してください。
WardLisp では t は予約語なので、引数名には tr などを使ってください。
最終式として
  (count-leaves (list 1 (list 2 3) (list 4 (list 5 6))))
を残してください。結果は 6 になります。"
               :body "; (define (pair? x) (and (not (null? x)) (not (atom? x))))
; (define (count-leaves tr) ...)
; 最後に (count-leaves (list 1 (list 2 3) (list 4 (list 5 6))))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "6"
                                     :description "葉は 1, 2, 3, 4, 5, 6 の 6 個")))
    (make-cell :id :ex-tree-map :kind :code-exercise
               :description
               "(tree-map f tree) を書いてください。
木のすべての葉に手続き f を適用し、形は元の木と同じものを返します。
pair? を自前で定義し、葉に到達したら (f tree) を返し、
そうでなければ car と cdr に再帰して cons で組み直します。
最終式として
  (tree-map (lambda (x) (* x x)) (list 1 (list 2 3) 4))
を残してください。結果は (1 (4 9) 16) になります。"
               :body "; (define (pair? x) (and (not (null? x)) (not (atom? x))))
; (define (tree-map f tree) ...)
; 最後に (tree-map (lambda (x) (* x x)) (list 1 (list 2 3) 4))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "(1 (4 9) 16)"
                                     :description "各葉を 2 乗した形は元の木と同じ"))))))
