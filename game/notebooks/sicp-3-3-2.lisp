;;;; game/notebooks/sicp-3-3-2.lisp --- SICP 3.3.2 Queues (functional 2-stack version).

(defpackage #:recurya/game/notebooks/sicp-3-3-2
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-3-3-2-notebook))

(in-package #:recurya/game/notebooks/sicp-3-3-2)

(defun make-sicp-3-3-2-notebook ()
  "SICP 3.3.2 - Queues: functional 2-stack representation in WardLisp."
  (make-notebook
   :id :sicp-3-3-2
   :chapter "3.3.2"
   :title "待ち行列 (関数型 2 スタック版)"
   :summary "SICP 3.3.2 の mutable queue を、WardLisp で 2 つのスタックを使った関数型キューとして実装する。enqueue / dequeue は新しいキューを返し、償却 O(1) で動く。"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:strong "SICP 3.3.2")
                           " は "
                           (:code "set-car!")
                           " / "
                           (:code "set-cdr!")
                           " を使って先頭ポインタと末尾ポインタの両方を更新できる "
                           (:strong "mutable queue")
                           " を実装します。"
                           (:code "enqueue")
                           " と "
                           (:code "dequeue")
                           " がどちらも O(1) です。")
                       (:pre ";; SICP 原典
(define (make-queue) (cons nil nil))  ;; (front . rear)
(define (enqueue! q x)
  (let ((cell (cons x nil)))
    (if (empty-queue? q)
        (begin (set-car! q cell) (set-cdr! q cell))
        (begin (set-cdr! (cdr q) cell)
               (set-cdr! q cell)))))")
                       (:p "WardLisp では "
                           (:code "set-car!")
                           " / "
                           (:code "set-cdr!")
                           " がないので、毎回新しいキューを返す "
                           (:strong "関数型キュー")
                           " で代替します。")))
    (make-cell :id :two-stacks :kind :prose
               :body '(:div
                       (:p (:strong "2 スタック法")
                           ": キューを 2 つのスタック "
                           (:code "(front . back)")
                           " で表現します。"
                           (:code "enqueue")
                           " は back の先頭に push、"
                           (:code "dequeue")
                           " は front の先頭から pop。"
                           "front が空のときは back を逆順にして front に移します。")
                       (:p "イメージ:")
                       (:pre "  enqueue a → front=()    back=(a)
  enqueue b → front=()    back=(b a)
  enqueue c → front=()    back=(c b a)
  dequeue   → front を見たら空 → back を逆順 (a b c) にして
              先頭 a を取り出し front=(b c) back=()
  dequeue   → 先頭 b を取り出し front=(c) back=()
  dequeue   → 先頭 c を取り出し front=() back=()")))
    (make-cell :id :queue-eval :kind :code-eval
               :body "(define (make-queue) (cons nil nil))  ;; (front . back)
(define (front q) (car q))
(define (back q) (cdr q))
(define (queue-empty? q) (and (null? (front q)) (null? (back q))))
(define (enqueue q x) (cons (front q) (cons x (back q))))
(define (rev-iter xs acc) (if (null? xs) acc (rev-iter (cdr xs) (cons (car xs) acc))))
(define (rev xs) (rev-iter xs nil))
(define (dequeue q)
  (cond ((queue-empty? q) 'empty)
        ((null? (front q))
         ;; back を逆順にして front に移し、先頭を取り出す
         (let ((flipped (rev (back q))))
           (cons (car flipped) (cons (cdr flipped) nil))))
        (t (cons (car (front q)) (cons (cdr (front q)) (back q))))))
(define q0 (make-queue))
(define q1 (enqueue q0 'a))
(define q2 (enqueue q1 'b))
(define q3 (enqueue q2 'c))
(define result (dequeue q3))
(list (car result) (front (cdr result)) (back (cdr result)))")
    (make-cell :id :complexity :kind :prose
               :body '(:div
                       (:p (:strong "計算量")
                           ": "
                           (:code "enqueue")
                           " は常に O(1)、"
                           (:code "dequeue")
                           " は "
                           (:strong "平均")
                           " で O(1) です。"
                           "front が空のとき back を逆順にする O(n) の処理が時々起きますが、"
                           "各要素は高々 1 回しか reverse の対象にならないので、"
                           (:strong "償却 (amortized)")
                           " 解析で O(1) と言えます。")
                       (:p "つまり SICP の mutable 版と "
                           (:strong "同じ漸近計算量を純関数で達成")
                           " しています。"
                           "しかも各 "
                           (:code "enqueue")
                           " / "
                           (:code "dequeue")
                           " は古いキューを変更しないので、"
                           "履歴を保持したり並行に分岐させたりできるという余得もあります。")))
    (make-cell :id :ex-fifo :kind :code-exercise
               :description
               "上の make-queue / enqueue / dequeue を定義し、a b c を順に enqueue したあと
dequeue すると先頭は 'a' になることを確認してください。
最終式として
  (let* ((q (enqueue (enqueue (enqueue (make-queue) 'a) 'b) 'c))
         (r (dequeue q)))
    (car r))
を残してください。期待値は a です。
スケルトン:
  (define (make-queue) (cons nil nil))
  (define (front q) (car q))
  (define (back q) (cdr q))
  (define (queue-empty? q) (and (null? (front q)) (null? (back q))))
  (define (enqueue q x) (cons (front q) (cons x (back q))))
  (define (rev-iter xs acc) (if (null? xs) acc (rev-iter (cdr xs) (cons (car xs) acc))))
  (define (rev xs) (rev-iter xs nil))
  (define (dequeue q)
    (cond ((queue-empty? q) 'empty)
          ((null? (front q))
           (let ((flipped (rev (back q))))
             (cons (car flipped) (cons (cdr flipped) nil))))
          (t (cons (car (front q)) (cons (cdr (front q)) (back q))))))
  (let* ((q (enqueue (enqueue (enqueue (make-queue) 'a) 'b) 'c))
         (r (dequeue q)))
    (car r))"
               :body "; (define (make-queue) ...)
; (define (enqueue q x) ...)
; (define (dequeue q) ...)
; (let* ((q ...)) (car (dequeue q)))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "a"
                                     :description "FIFO: 最初に enqueue した a が最初に dequeue される")))
    (make-cell :id :ex-three-deqs :kind :code-exercise
               :description
               "a b c を順に enqueue してから 3 回 dequeue すると 'a 'b 'c の順で取り出されます。
3 回 dequeue した結果のリスト (a b c) を返す手続き (three-deqs) を書いてください。
最終式として (three-deqs) を残してください。期待値は (a b c) です。
スケルトン (上の queue 関数群を再定義したうえで):
  (define (three-deqs)
    (let* ((q1 (enqueue (enqueue (enqueue (make-queue) 'a) 'b) 'c))
           (r1 (dequeue q1))
           (v1 (car r1))
           (q2 (cdr r1))
           (r2 (dequeue q2))
           (v2 (car r2))
           (q3 (cdr r2))
           (r3 (dequeue q3))
           (v3 (car r3)))
      (list v1 v2 v3)))
  (three-deqs)"
               :body "; (define (three-deqs) ...)
; (three-deqs)
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "(a b c)"
                                     :description "3 回 dequeue で (a b c) が順に取り出される"))))))
