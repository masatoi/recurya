;;;; game/notebooks/sicp-2-3-1.lisp --- SICP 2.3.1 Quotation.

(defpackage #:recurya/game/notebooks/sicp-2-3-1
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-2-3-1-notebook))

(in-package #:recurya/game/notebooks/sicp-2-3-1)

(defun make-sicp-2-3-1-notebook ()
  "SICP 2.3.1 - Quotation."
  (make-notebook
   :id :sicp-2-3-1
   :chapter "2.3.1"
   :title "引用"
   :summary "クォート ' によって式を評価せず記号として扱う。シンボルと eq?、memq によりリストを記号データとして扱えるようになる"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:code "(list 'a 'b)")
                           " のように "
                           (:code "'")
                           " をつけると、その式は "
                           (:strong "評価されず")
                           " そのまま記号として扱われます。"
                           (:code "'a")
                           " は "
                           (:strong "シンボル")
                           " "
                           (:code "a")
                           " を表す。これを "
                           (:strong "引用 (quotation)")
                           " と呼びます。")))
    (make-cell :id :quote-list-code :kind :code-eval
               :body "(list 'a 'b 'c)")
    (make-cell :id :symbol-eq-prose :kind :prose
               :body '(:div
                       (:p "シンボルはそれ自身の名前を値とする atomic な値です。"
                           (:code "eq?")
                           " でシンボル同士の "
                           (:strong "同一性")
                           " を判定できます。")))
    (make-cell :id :symbol-eq-code :kind :code-eval
               :body "(list (eq? 'apple 'apple) (eq? 'apple 'orange))")
    (make-cell :id :quote-whole-list-prose :kind :prose
               :body '(:div
                       (:p (:code "'(a b c)")
                           " のように直接引用してリストを作ることもできます。"
                           "これは "
                           (:code "(list 'a 'b 'c)")
                           " と同じです。")))
    (make-cell :id :quote-whole-list-code :kind :code-eval
               :body "'(a b c)")
    (make-cell :id :memq-prose :kind :prose
               :body '(:div
                       (:p (:code "memq")
                           " は、リスト中に等しい ("
                           (:code "eq?")
                           ") 要素があれば "
                           (:strong "その要素以降の sublist")
                           " を返し、なければ "
                           (:code "nil")
                           " を返します。")))
    (make-cell :id :memq-code :kind :code-eval
               :body "(define (memq item xs)
  (cond ((null? xs) nil)
        ((eq? item (car xs)) xs)
        (t (memq item (cdr xs)))))
(list (memq 'apple '(pear banana apple grape)) (memq 'fig '(pear banana apple)))")
    (make-cell :id :ex-equal :kind :code-exercise
               :description
               "自前の (my-equal? a b) を書いてください。
両方が atom なら eq? で比較、両方が pair なら car と cdr を再帰的に比較します。
どちらか一方だけが atom の場合は nil。
最終式として
  (my-equal? '(this is a list) '(this is a list))
を残してください。結果は t になります。"
               :body "; (define (my-equal? a b) ...)
; 最後に (my-equal? '(this is a list) '(this is a list))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "t"
                                     :description "同じ構造のリストは等しい")))
    (make-cell :id :ex-count-syms :kind :code-exercise
               :description
               "シンボルのフラットなリストの中に、特定のシンボルが何回現れるかを数える
(count-occurrences sym xs) を書いてください。
xs は入れ子のないシンボル列です。eq? で要素を比較し、再帰的に走査します。
最終式として
  (count-occurrences 'a '(a b a c a d a))
を残してください。結果は 4 になります。"
               :body "; (define (count-occurrences sym xs) ...)
; 最後に (count-occurrences 'a '(a b a c a d a))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "4"
                                     :description "'a が 4 回現れる"))))))
