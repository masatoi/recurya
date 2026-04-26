;;;; game/notebooks/sicp-2-2-4.lisp --- SICP 2.2.4 Picture Language (concept-only).

(defpackage #:recurya/game/notebooks/sicp-2-2-4
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-2-2-4-notebook))

(in-package #:recurya/game/notebooks/sicp-2-2-4)

(defun make-sicp-2-2-4-notebook ()
  "SICP 2.2.4 - Picture Language (concept-only)."
  (make-notebook
   :id :sicp-2-2-4
   :chapter "2.2.4"
   :title "絵言語 (概念紹介のみ)"
   :summary "絵を「フレームから描画への関数」とみなし、beside / below / flip-vert といった高階手続きで合成する。閉包性により再帰的に複雑な絵を構築できる"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:strong "SICP 2.2.4 「絵言語」の概要 (本ノートでは概念紹介のみ): ")
                           "絵を "
                           (:strong "「フレーム (平行四辺形領域) から描画への関数」")
                           " と定義します。"
                           "つまり絵 "
                           (:code "painter")
                           " は "
                           (:code "frame -> 描画")
                           " という手続きです。"
                           (:code "(beside p1 p2)")
                           " は二つの絵を左右に並べた "
                           (:strong "新しい絵")
                           " を返し、"
                           (:code "(below p1 p2)")
                           " は上下に並べた絵を返す。"
                           (:code "(flip-vert p)")
                           " は上下反転した絵を返す。"
                           "すべて高階手続きの組合せで定義されます。")))
    (make-cell :id :closure-prose :kind :prose
               :body '(:div
                       (:p (:strong "閉包性 (closure property): ")
                           (:code "beside")
                           " / "
                           (:code "below")
                           " / "
                           (:code "flip-vert")
                           " の結果も絵なので、再帰的に組み立てられます。"
                           "たとえば、絵を 4 等分タイル状に並べた "
                           (:code "(square-of-four tl tr bl br)")
                           " は 4 つの絵から 1 つの絵を作る手続きで、"
                           "それを "
                           (:code "corner-split")
                           " のような自己参照定義に使うと、"
                           "再帰的にフラクタル状の絵が生まれます。")))
    (make-cell :id :sicp-significance-prose :kind :prose
               :body '(:div
                       (:p (:strong "SICP の意義: ")
                           "絵言語の例題は、"
                           (:strong "データ抽象とプロシージャ抽象が連続体である")
                           " ことを示しています。"
                           "そして、高階関数による組合せが "
                           (:strong "閉包性")
                           " (combine の結果も同じ型) を満たせば、"
                           "どんどん複雑な構造を構築できる、というのが本節の核心メッセージです。")))
    (make-cell :id :wardlisp-note-prose :kind :prose
               :body '(:div
                       (:p (:strong "WardLisp 注記: ")
                           "絵言語の完全実装は SVG / Canvas のような描画基盤が必要ですが、"
                           "recurya の現状の UI は対応していません。"
                           "本ノートでは概念紹介のみとし、実装は将来の課題とします。")
                       (:p "ただし "
                           (:strong "結合手続きそのものは手続きの操作として書ける")
                           " ので、"
                           (:code "painter")
                           " を "
                           (:code "(frame) -> 出力なし")
                           " 型のダミー関数に置き換えれば、"
                           (:code "beside")
                           " / "
                           (:code "below")
                           " の組合せ規則自体は WardLisp で動かせます。")))
    (make-cell :id :combinator-stub-code :kind :code-eval
               :body "(define (make-frame) 'frame-stub)
(define (painter-square frame) 'drew-square)
(define (painter-circle frame) 'drew-circle)
(define (beside p1 p2) (lambda (frame) (list (p1 frame) (p2 frame))))
(define (below p1 p2) (lambda (frame) (list (p1 frame) (p2 frame))))
(define combo (below (beside painter-square painter-circle) painter-square))
(combo (make-frame))")
    (make-cell :id :outro-prose :kind :prose
               :body '(:div
                       (:p "上のように "
                           (:code "painter")
                           " をスタブにすれば、組合せ手続き ("
                           (:code "beside")
                           " / "
                           (:code "below")
                           ") が高階関数として正しく動くことは確認できます。"
                           (:strong "実際の描画は別の課題")
                           " です。"))))))
