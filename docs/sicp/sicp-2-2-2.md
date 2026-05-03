===prose===
リストは要素として別のリストを含めることができます。これにより **木構造** を自然に表現できます。たとえば `(list (list 1 2) (list 3 4))` は 2 階層の木です。

外側のリストから見ると要素数は 2 ですが、「葉」 (leaf, リストでない値) は全部で 4 個あります。

===eval===
(define x (list (list 1 2) (list 3 4)))
(list x (length x))

===prose===
葉の総数を数える `count-leaves` を書きましょう。WardLisp には `pair?` が組み込まれていないので、「空リストでなく、原子でもない」値を pair として自前で定義します。なお WardLisp では真値 `t` は予約語のため、引数名には `tr` などを使います。

再帰の構造は次の 3 ケース: 空リストなら 0、リストでない (= 葉) なら 1、そうでなければ `(car tr)` と `(cdr tr)` の葉の数を足し合わせる、です。

===eval===
(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (count-leaves tr)
  (cond ((null? tr) 0)
        ((not (pair? tr)) 1)
        (t (+ (count-leaves (car tr))
              (count-leaves (cdr tr))))))
(count-leaves (list (list 1 2) (list 3 4) 5))

===prose===
木の操作は **car と cdr の両方を再帰** することで自然に書けます。葉に到達したらそこで具体的な操作 (今回は乗算) を行い、それ以外なら左右に分かれて再帰、という形です。

===eval===
(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (scale-tree tree factor)
  (cond ((null? tree) nil)
        ((not (pair? tree)) (* tree factor))
        (t (cons (scale-tree (car tree) factor)
                 (scale-tree (cdr tree) factor)))))
(scale-tree (list 1 (list 2 (list 3 4) 5) (list 6 7)) 10)

===exercise: (count-leaves tr) を書き、与えられた木の葉の総数を計算してください。 WardLisp には pair? が組み込まれていないので、 (define (pair? x) (and (not (null? x)) (not (atom? x)))) を最初に定義してください。 WardLisp では t は予約語なので、引数名には tr などを使ってください。 最終式として (count-leaves (list 1 (list 2 3) (list 4 (list 5 6)))) を残してください。結果は 6 になります。===
; (define (pair? x) (and (not (null? x)) (not (atom? x))))
; (define (count-leaves tr) ...)
; 最後に (count-leaves (list 1 (list 2 3) (list 4 (list 5 6))))

===expect: 葉は 1, 2, 3, 4, 5, 6 の 6 個===
6

===solution: (count-leaves tr) を書き、与えられた木の葉の総数を計算してください。 WardLisp には pair? が組み込まれていないので、 (define (pair? x) (and (not (null? x)) (not (atom? x)))) を最初に定義してください。 WardLisp では t は予約語なので、引数名には tr などを使ってください。 最終式として (count-leaves (list 1 (list 2 3) (list 4 (list 5 6)))) を残してください。結果は 6 になります。===
(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (count-leaves tr)
  (cond ((null? tr) 0)
        ((not (pair? tr)) 1)
        (t (+ (count-leaves (car tr)) (count-leaves (cdr tr))))))
(count-leaves (list 1 (list 2 3) (list 4 (list 5 6))))

===exercise: (tree-map f tree) を書いてください。 木のすべての葉に手続き f を適用し、形は元の木と同じものを返します。 pair? を自前で定義し、葉に到達したら (f tree) を返し、 そうでなければ car と cdr に再帰して cons で組み直します。 最終式として (tree-map (lambda (x) (* x x)) (list 1 (list 2 3) 4)) を残してください。結果は (1 (4 9) 16) になります。===
; (define (pair? x) (and (not (null? x)) (not (atom? x))))
; (define (tree-map f tree) ...)
; 最後に (tree-map (lambda (x) (* x x)) (list 1 (list 2 3) 4))

===expect: 各葉を 2 乗した形は元の木と同じ===
(1 (4 9) 16)

===solution: (tree-map f tree) を書いてください。 木のすべての葉に手続き f を適用し、形は元の木と同じものを返します。 pair? を自前で定義し、葉に到達したら (f tree) を返し、 そうでなければ car と cdr に再帰して cons で組み直します。 最終式として (tree-map (lambda (x) (* x x)) (list 1 (list 2 3) 4)) を残してください。結果は (1 (4 9) 16) になります。===
(define (pair? x) (and (not (null? x)) (not (atom? x))))
(define (tree-map f tree)
  (cond ((null? tree) nil)
        ((not (pair? tree)) (f tree))
        (t (cons (tree-map f (car tree)) (tree-map f (cdr tree))))))
(tree-map (lambda (x) (* x x)) (list 1 (list 2 3) 4))
