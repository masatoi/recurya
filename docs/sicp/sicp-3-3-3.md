===prose===
**SICP 3.3.3** は mutable な **association list** ベースの表を扱います。`(insert! key value table)` で table を破壊的に更新するイメージです。

```
;; SICP 原典
(define (insert! key value table)
  (let ((record (assoc key (cdr table))))
    (if record
        (set-cdr! record value)
        (set-cdr! table
                  (cons (cons key value) (cdr table))))))
```

WardLisp では各 `insert` が **新しい table を返す** 形に書き換えます。古い table はそのまま残るので、履歴的なバージョン管理にもなります。

===eval===
(define (make-table) nil)
(define (lookup key table)
  (cond ((null? table) nil)
        ((equal? key (car (car table))) (cdr (car table)))
        (t (lookup key (cdr table)))))
(define (insert key value table)
  ;; 既存キーがあれば更新、なければ追加 (新 table を返す)
  (cond ((null? table) (list (cons key value)))
        ((equal? key (car (car table)))
         (cons (cons key value) (cdr table)))
        (t (cons (car table) (insert key value (cdr table))))))
(define t0 (make-table))
(define t1 (insert 'a 1 t0))
(define t2 (insert 'b 2 t1))
(define t3 (insert 'a 99 t2))  ;; 既存キーの更新
(list (lookup 'a t3) (lookup 'b t3) (lookup 'c t3))

===prose===
**観察**: `insert` は元の table を変えず、新しい table を返します。`t1` を保持していれば後から元の状態を参照できます。これは **persistent data structure** の基本的な性質で、純粋関数型の世界では自然な振る舞いです。

計算量は SICP の mutable 版と同じく **lookup, insert ともに O(n)** (alist は線形探索)。もし高速化したければ tree や hash に置き換えますが、それは 3.3.3 の議論の主眼ではありません。

===eval===
(define (make-table) nil)
(define (lookup key table)
  (cond ((null? table) nil)
        ((equal? key (car (car table))) (cdr (car table)))
        (t (lookup key (cdr table)))))
(define (insert key value table)
  (cond ((null? table) (list (cons key value)))
        ((equal? key (car (car table)))
         (cons (cons key value) (cdr table)))
        (t (cons (car table) (insert key value (cdr table))))))
;; 2D: outer key → inner table
(define (lookup-2 k1 k2 table)
  (let ((inner (lookup k1 table)))
    (if (null? inner) nil (lookup k2 inner))))
(define (insert-2 k1 k2 value table)
  (let ((inner (lookup k1 table)))
    (insert k1 (insert k2 value inner) table)))
(define tbl (insert-2 'math 'pi 314 (insert-2 'math 'e 271 nil)))
(list (lookup-2 'math 'pi tbl) (lookup-2 'math 'e tbl))

===exercise: make-table / insert / lookup を上の通り定義し、a→1, b→2, c→3 を順に insert したあと (lookup 'b ...) を返してください。期待値は 2 です。 最終式は次の通り: (lookup 'b (insert 'c 3 (insert 'b 2 (insert 'a 1 (make-table))))) スケルトン: (define (make-table) nil) (define (lookup key table) (cond ((null? table) nil) ((equal? key (car (car table))) (cdr (car table))) (t (lookup key (cdr table))))) (define (insert key value table) (cond ((null? table) (list (cons key value))) ((equal? key (car (car table))) (cons (cons key value) (cdr table))) (t (cons (car table) (insert key value (cdr table)))))) (lookup 'b (insert 'c 3 (insert 'b 2 (insert 'a 1 (make-table)))))===
; (define (make-table) nil)
; (define (lookup key table) ...)
; (define (insert key value table) ...)
; (lookup 'b (insert 'c 3 (insert 'b 2 (insert 'a 1 (make-table)))))

===expect: 1D table: 'b → 2 が引ける===
2

===solution: make-table / insert / lookup を上の通り定義し、a→1, b→2, c→3 を順に insert したあと (lookup 'b ...) を返してください。期待値は 2 です。 最終式は次の通り: (lookup 'b (insert 'c 3 (insert 'b 2 (insert 'a 1 (make-table))))) スケルトン: (define (make-table) nil) (define (lookup key table) (cond ((null? table) nil) ((equal? key (car (car table))) (cdr (car table))) (t (lookup key (cdr table))))) (define (insert key value table) (cond ((null? table) (list (cons key value))) ((equal? key (car (car table))) (cons (cons key value) (cdr table))) (t (cons (car table) (insert key value (cdr table)))))) (lookup 'b (insert 'c 3 (insert 'b 2 (insert 'a 1 (make-table)))))===
(define (make-table) nil)
(define (lookup key table)
  (cond ((null? table) nil)
        ((equal? key (car (car table))) (cdr (car table)))
        (t (lookup key (cdr table)))))
(define (insert key value table)
  (cond ((null? table) (list (cons key value)))
        ((equal? key (car (car table)))
         (cons (cons key value) (cdr table)))
        (t (cons (car table) (insert key value (cdr table))))))
(lookup 'b (insert 'c 3 (insert 'b 2 (insert 'a 1 (make-table)))))

===exercise: 同じキーで insert を 2 回呼ぶと最後の値が見えることを確認してください。 'a→1 のあと 'a→99 を insert して (lookup 'a ...) を返します。期待値は 99 です。 最終式: (lookup 'a (insert 'a 99 (insert 'a 1 (make-table)))) スケルトン: (define (make-table) nil) (define (lookup key table) (cond ((null? table) nil) ((equal? key (car (car table))) (cdr (car table))) (t (lookup key (cdr table))))) (define (insert key value table) (cond ((null? table) (list (cons key value))) ((equal? key (car (car table))) (cons (cons key value) (cdr table))) (t (cons (car table) (insert key value (cdr table)))))) (lookup 'a (insert 'a 99 (insert 'a 1 (make-table))))===
; (define (make-table) nil)
; (define (lookup key table) ...)
; (define (insert key value table) ...)
; (lookup 'a (insert 'a 99 (insert 'a 1 (make-table))))

===expect: 同じキーの insert は最後の値で更新===
99

===solution: 同じキーで insert を 2 回呼ぶと最後の値が見えることを確認してください。 'a→1 のあと 'a→99 を insert して (lookup 'a ...) を返します。期待値は 99 です。 最終式: (lookup 'a (insert 'a 99 (insert 'a 1 (make-table)))) スケルトン: (define (make-table) nil) (define (lookup key table) (cond ((null? table) nil) ((equal? key (car (car table))) (cdr (car table))) (t (lookup key (cdr table))))) (define (insert key value table) (cond ((null? table) (list (cons key value))) ((equal? key (car (car table))) (cons (cons key value) (cdr table))) (t (cons (car table) (insert key value (cdr table)))))) (lookup 'a (insert 'a 99 (insert 'a 1 (make-table))))===
(define (make-table) nil)
(define (lookup key table)
  (cond ((null? table) nil)
        ((equal? key (car (car table))) (cdr (car table)))
        (t (lookup key (cdr table)))))
(define (insert key value table)
  (cond ((null? table) (list (cons key value)))
        ((equal? key (car (car table)))
         (cons (cons key value) (cdr table)))
        (t (cons (car table) (insert key value (cdr table))))))
(lookup 'a (insert 'a 99 (insert 'a 1 (make-table))))
