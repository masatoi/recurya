===prose===
**SICP 3.2.3** は `make-counter` のような状態を持つクロージャが、フレームのどこに値を保持しているかを論じます。

SICP 原典の例 (WardLisp では動かない):

```
;; SICP 原典 (WardLisp では set! がないので動かない)
(define (make-counter)
  (let ((count 0))
    (lambda ()
      (set! count (+ count 1))
      count)))
```

`(make-counter)` を呼ぶと let フレームが作られ、`count: 0` が束縛されます。返された lambda は **そのフレームを親** とします。`set!` で `count` を更新すると、let フレームの `count` の値が書き換わるので、次に lambda が呼ばれたときには更新後の値が見える、という仕組みです。

===prose===
**ASCII 図 (SICP set! 版)**:

```
  [global]
  └── make-counter: ...
  └── c: ─→ E1 (lambda)

  E1 [parent: E_let]      E_let [parent: global]
  body: (set! count ...)  └── count: 0  ← (set! count 1) で書き換え可能
                                          → 1 → 2 → 3 ...
```

lambda は E_let を親とするので、lambda 内で `count` を参照すると E_let の `count` 束縛が見える。`set!` はこの束縛の値スロットを破壊的に書き換える。

===prose===
**WardLisp では **`set!`** がない** ので、let フレームの値を後から書き換える手段はありません。代わりに、状態を持ちたい場合は **値を引数として持ち回る** 形 (関数型のスタイル) にする必要があります。

「次の状態に進む手続き」を毎回新しく返す形にすると、ある意味で同じ情報を別の表現で扱えます。

===eval===
; 関数型版: count を渡し続ける
(define (count-up count)
  (define new-count (+ count 1))
  (list new-count (lambda () (count-up new-count))))
(define c0 (count-up 0))
(define c1 ((car (cdr c0))))
(define c2 ((car (cdr c1))))
(list (car c0) (car c1) (car c2))

===prose===
**観察**: `set!` 版では同じクロージャが何度も状態を更新しますが、関数型版では「次の状態に進む手続き」を毎回新しく返します。**情報量は同じだが扱い方が違う** ─ ここに関数型と命令型の本質的な対比があります。

- **set! 版**: クロージャは *同一の存在* として残り、内部状態が時間とともに変化
- **関数型版**: 状態は *値そのもの* として外に出ていて、新しい状態は新しい値

===exercise: 上記の count-up を使って、初期値 10 から始めて 3 回進めた値を取り出してください。 count-up は本ノートブックのコードセルで定義されています: (define (count-up count) (define new-count (+ count 1)) (list new-count (lambda () (count-up new-count)))) 最終式として (let* ((c1 (count-up 10)) (c2 ((car (cdr c1)))) (c3 ((car (cdr c2))))) (car c3)) を残してください。期待値は 13 です。===
; (define (count-up count) ...) 上のセルと同じ
; 最後に (let* (...) (car c3))

===expect: count-up で 10 から 3 回進めて 13===
13

===solution: 上記の count-up を使って、初期値 10 から始めて 3 回進めた値を取り出してください。 count-up は本ノートブックのコードセルで定義されています: (define (count-up count) (define new-count (+ count 1)) (list new-count (lambda () (count-up new-count)))) 最終式として (let* ((c1 (count-up 10)) (c2 ((car (cdr c1)))) (c3 ((car (cdr c2))))) (car c3)) を残してください。期待値は 13 です。===
(let* ((c1 (count-up 10))
       (c2 ((car (cdr c1))))
       (c3 ((car (cdr c2)))))
  (car c3))
