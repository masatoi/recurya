===prose===
**SICP 2.2.4 「絵言語」の概要 (本ノートでは概念紹介のみ): **絵を **「フレーム (平行四辺形領域) から描画への関数」** と定義します。つまり絵 `painter` は `frame -> 描画` という手続きです。`(beside p1 p2)` は二つの絵を左右に並べた **新しい絵** を返し、`(below p1 p2)` は上下に並べた絵を返す。`(flip-vert p)` は上下反転した絵を返す。すべて高階手続きの組合せで定義されます。

===prose===
**閉包性 (closure property): **`beside` / `below` / `flip-vert` の結果も絵なので、再帰的に組み立てられます。たとえば、絵を 4 等分タイル状に並べた `(square-of-four tl tr bl br)` は 4 つの絵から 1 つの絵を作る手続きで、それを `corner-split` のような自己参照定義に使うと、再帰的にフラクタル状の絵が生まれます。

===prose===
**SICP の意義: **絵言語の例題は、**データ抽象とプロシージャ抽象が連続体である** ことを示しています。そして、高階関数による組合せが **閉包性** (combine の結果も同じ型) を満たせば、どんどん複雑な構造を構築できる、というのが本節の核心メッセージです。

===prose===
**WardLisp 注記: **絵言語の完全実装は SVG / Canvas のような描画基盤が必要ですが、recurya の現状の UI は対応していません。本ノートでは概念紹介のみとし、実装は将来の課題とします。

ただし **結合手続きそのものは手続きの操作として書ける** ので、`painter` を `(frame) -> 出力なし` 型のダミー関数に置き換えれば、`beside` / `below` の組合せ規則自体は WardLisp で動かせます。

===eval===
(define (make-frame) 'frame-stub)
(define (painter-square frame) 'drew-square)
(define (painter-circle frame) 'drew-circle)
(define (beside p1 p2) (lambda (frame) (list (p1 frame) (p2 frame))))
(define (below p1 p2) (lambda (frame) (list (p1 frame) (p2 frame))))
(define combo (below (beside painter-square painter-circle) painter-square))
(combo (make-frame))

===prose===
上のように `painter` をスタブにすれば、組合せ手続き (`beside` / `below`) が高階関数として正しく動くことは確認できます。**実際の描画は別の課題** です。
