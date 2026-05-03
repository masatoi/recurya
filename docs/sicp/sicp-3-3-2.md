===prose===
**SICP 3.3.2** は `set-car!` / `set-cdr!` を使って先頭ポインタと末尾ポインタの両方を更新できる **mutable queue** を実装します。`enqueue` と `dequeue` がどちらも O(1) です。

```
;; SICP 原典
(define (make-queue) (cons nil nil))  ;; (front . rear)
(define (enqueue! q x)
  (let ((cell (cons x nil)))
    (if (empty-queue? q)
        (begin (set-car! q cell) (set-cdr! q cell))
        (begin (set-cdr! (cdr q) cell)
               (set-cdr! q cell)))))
```

WardLisp では `set-car!` / `set-cdr!` がないので、毎回新しいキューを返す **関数型キュー** で代替します。

===prose===
**2 スタック法**: キューを 2 つのスタック `(front . back)` で表現します。`enqueue` は back の先頭に push、`dequeue` は front の先頭から pop。front が空のときは back を逆順にして front に移します。

イメージ:

```
  enqueue a → front=()    back=(a)
  enqueue b → front=()    back=(b a)
  enqueue c → front=()    back=(c b a)
  dequeue   → front を見たら空 → back を逆順 (a b c) にして
              先頭 a を取り出し front=(b c) back=()
  dequeue   → 先頭 b を取り出し front=(c) back=()
  dequeue   → 先頭 c を取り出し front=() back=()
```

===eval===
(define (make-queue) (cons nil nil))  ;; (front . back)
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
(list (car result) (front (cdr result)) (back (cdr result)))

===prose===
**計算量**: `enqueue` は常に O(1)、`dequeue` は **平均** で O(1) です。front が空のとき back を逆順にする O(n) の処理が時々起きますが、各要素は高々 1 回しか reverse の対象にならないので、**償却 (amortized)** 解析で O(1) と言えます。

つまり SICP の mutable 版と **同じ漸近計算量を純関数で達成** しています。しかも各 `enqueue` / `dequeue` は古いキューを変更しないので、履歴を保持したり並行に分岐させたりできるという余得もあります。

===exercise: 上の make-queue / enqueue / dequeue を定義し、a b c を順に enqueue したあと dequeue すると先頭は 'a' になることを確認してください。 最終式として (let* ((q (enqueue (enqueue (enqueue (make-queue) 'a) 'b) 'c)) (r (dequeue q))) (car r)) を残してください。期待値は a です。 スケルトン: (define (make-queue) (cons nil nil)) (define (front q) (car q)) (define (back q) (cdr q)) (define (queue-empty? q) (and (null? (front q)) (null? (back q)))) (define (enqueue q x) (cons (front q) (cons x (back q)))) (define (rev-iter xs acc) (if (null? xs) acc (rev-iter (cdr xs) (cons (car xs) acc)))) (define (rev xs) (rev-iter xs nil)) (define (dequeue q) (cond ((queue-empty? q) 'empty) ((null? (front q)) (let ((flipped (rev (back q)))) (cons (car flipped) (cons (cdr flipped) nil)))) (t (cons (car (front q)) (cons (cdr (front q)) (back q)))))) (let* ((q (enqueue (enqueue (enqueue (make-queue) 'a) 'b) 'c)) (r (dequeue q))) (car r))===
; (define (make-queue) ...)
; (define (enqueue q x) ...)
; (define (dequeue q) ...)
; (let* ((q ...)) (car (dequeue q)))

===expect: FIFO: 最初に enqueue した a が最初に dequeue される===
a

===solution: 上の make-queue / enqueue / dequeue を定義し、a b c を順に enqueue したあと dequeue すると先頭は 'a' になることを確認してください。 最終式として (let* ((q (enqueue (enqueue (enqueue (make-queue) 'a) 'b) 'c)) (r (dequeue q))) (car r)) を残してください。期待値は a です。 スケルトン: (define (make-queue) (cons nil nil)) (define (front q) (car q)) (define (back q) (cdr q)) (define (queue-empty? q) (and (null? (front q)) (null? (back q)))) (define (enqueue q x) (cons (front q) (cons x (back q)))) (define (rev-iter xs acc) (if (null? xs) acc (rev-iter (cdr xs) (cons (car xs) acc)))) (define (rev xs) (rev-iter xs nil)) (define (dequeue q) (cond ((queue-empty? q) 'empty) ((null? (front q)) (let ((flipped (rev (back q)))) (cons (car flipped) (cons (cdr flipped) nil)))) (t (cons (car (front q)) (cons (cdr (front q)) (back q)))))) (let* ((q (enqueue (enqueue (enqueue (make-queue) 'a) 'b) 'c)) (r (dequeue q))) (car r))===
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
  (car r))

===exercise: a b c を順に enqueue してから 3 回 dequeue すると 'a 'b 'c の順で取り出されます。 3 回 dequeue した結果のリスト (a b c) を返す手続き (three-deqs) を書いてください。 最終式として (three-deqs) を残してください。期待値は (a b c) です。 スケルトン (上の queue 関数群を再定義したうえで): (define (three-deqs) (let* ((q1 (enqueue (enqueue (enqueue (make-queue) 'a) 'b) 'c)) (r1 (dequeue q1)) (v1 (car r1)) (q2 (cdr r1)) (r2 (dequeue q2)) (v2 (car r2)) (q3 (cdr r2)) (r3 (dequeue q3)) (v3 (car r3))) (list v1 v2 v3))) (three-deqs)===
; (define (three-deqs) ...)
; (three-deqs)

===expect: 3 回 dequeue で (a b c) が順に取り出される===
(a b c)

===solution: a b c を順に enqueue してから 3 回 dequeue すると 'a 'b 'c の順で取り出されます。 3 回 dequeue した結果のリスト (a b c) を返す手続き (three-deqs) を書いてください。 最終式として (three-deqs) を残してください。期待値は (a b c) です。 スケルトン (上の queue 関数群を再定義したうえで): (define (three-deqs) (let* ((q1 (enqueue (enqueue (enqueue (make-queue) 'a) 'b) 'c)) (r1 (dequeue q1)) (v1 (car r1)) (q2 (cdr r1)) (r2 (dequeue q2)) (v2 (car r2)) (q3 (cdr r2)) (r3 (dequeue q3)) (v3 (car r3))) (list v1 v2 v3))) (three-deqs)===
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
(three-deqs)
