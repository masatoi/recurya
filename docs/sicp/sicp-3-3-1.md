===prose===
**SICP 3.3.1** は `set-car!` と `set-cdr!` を導入し、リスト構造を後から変更できるようにします。これで **共有 (sharing)**、**同一性 (eq?)**、**サイクル** を表現できます。

```
;; SICP 原典 (WardLisp では動かない)
(define x (list 'a 'b))
(define z (cons x x))
(set-car! (cdr z) 'changed)  ;; z = ((a b) (changed b))
;; ↑ z の car と cdr が同じ x を共有しているので、
;;   片方を書き換えると両方に反映される
```

WardLisp は `set-car!` / `set-cdr!` を持たないので、共有の **観察** はできても **mutation 経由の挙動** は再現できません。代わりに `eq?` で共有を検出する例を扱います。

===eval===
(define x (list 1 2 3))
(define z1 (cons x x))      ;; car と cdr が同じ x を指す
(define z2 (cons x (list 1 2 3)))  ;; car と cdr が別物
(list (eq? (car z1) (cdr z1)) (eq? (car z2) (cdr z2)))

===prose===
**重要**: cons は元のリストを **コピーしない**。`(cons x x)` は同じ x への参照を 2 つ持つだけです。WardLisp で `set-car!` がなくても、**共有自体は普通に起きている** ことを `eq?` で確認できます。

上のセルの結果は `(t nil)`:

- `z1` は同一の x を指すので `(eq? (car z1) (cdr z1))` は t
- `z2` は (list 1 2 3) を 2 回別々に評価したので `(eq? (car z2) (cdr z2))` は nil

===prose===
**サイクル (循環構造)**: `set-cdr!` を使えば、`(define x (list 1 2 3))` から始めて `(set-cdr! (cddr x) x)` で循環構造を作れます。

```
;; SICP 原典 (WardLisp では不可能)
(define x (list 1 2 3))
(set-cdr! (cddr x) x)  ;; x の最後を x 自身に向け直す
;; → x はもはや有限のリストではなく、無限に巡回する構造
```

**WardLisp ではサイクルは作れません**。cons は常に新しいセルを作り、既存のセルの cdr を書き換える手段がないからです。「サイクルは mutation でしか作れない」 ─ これは WardLisp の制約であると同時に、**純粋な関数型データ構造の安全性** (停止性、共有メモ化) でもあります。

===exercise: リスト a と b の cdr が同じセルを共有しているかを eq? で検出する手続き (cdr-eq? a b) を書いてください。シンプルに (eq? (cdr a) (cdr b)) を返すだけで OK。 最終式として (let* ((c (list 1 2 3)) (a (cons 'x c)) (b (cons 'y c))) (cdr-eq? a b)) を残してください。期待値は t です。 スケルトン: (define (cdr-eq? a b) (eq? (cdr a) (cdr b))) (let* ((c (list 1 2 3)) (a (cons 'x c)) (b (cons 'y c))) (cdr-eq? a b))===
; (define (cdr-eq? a b) ...)
; (let* ((c (list 1 2 3)) (a (cons 'x c)) (b (cons 'y c))) (cdr-eq? a b))

===expect: cdr-eq? が共有された cdr を t と検出===
t

===solution: リスト a と b の cdr が同じセルを共有しているかを eq? で検出する手続き (cdr-eq? a b) を書いてください。シンプルに (eq? (cdr a) (cdr b)) を返すだけで OK。 最終式として (let* ((c (list 1 2 3)) (a (cons 'x c)) (b (cons 'y c))) (cdr-eq? a b)) を残してください。期待値は t です。 スケルトン: (define (cdr-eq? a b) (eq? (cdr a) (cdr b))) (let* ((c (list 1 2 3)) (a (cons 'x c)) (b (cons 'y c))) (cdr-eq? a b))===
(define (cdr-eq? a b) (eq? (cdr a) (cdr b)))
(let* ((c (list 1 2 3)) (a (cons 'x c)) (b (cons 'y c))) (cdr-eq? a b))

===exercise: (cons x x) が同じ x を 2 回参照することを確認する式を書いてください。 最終式として (let* ((x (list 1 2)) (z (cons x x))) (eq? (car z) (cdr z))) を残してください。期待値は t です。 スケルトン: (let* ((x (list 1 2)) (z (cons x x))) (eq? (car z) (cdr z)))===
; (let* ((x (list 1 2)) (z (cons x x))) (eq? (car z) (cdr z)))

===expect: (cons x x) の car と cdr が同一 x===
t

===solution: (cons x x) が同じ x を 2 回参照することを確認する式を書いてください。 最終式として (let* ((x (list 1 2)) (z (cons x x))) (eq? (car z) (cdr z))) を残してください。期待値は t です。 スケルトン: (let* ((x (list 1 2)) (z (cons x x))) (eq? (car z) (cdr z)))===
(let* ((x (list 1 2)) (z (cons x x))) (eq? (car z) (cdr z)))
