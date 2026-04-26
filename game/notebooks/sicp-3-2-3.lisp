;;;; game/notebooks/sicp-3-2-3.lisp --- SICP 3.2.3 Frames as the Repository of Local State.

(defpackage #:recurya/game/notebooks/sicp-3-2-3
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-3-2-3-notebook))

(in-package #:recurya/game/notebooks/sicp-3-2-3)

(defun make-sicp-3-2-3-notebook ()
  "SICP 3.2.3 - Frames as the repository of local state."
  (make-notebook
   :id :sicp-3-2-3
   :chapter "3.2.3"
   :title "局所状態の格納庫としてのフレーム"
   :summary "状態を持つクロージャがフレームのどこに値を保持しているかを論じる。SICP 原典の set! 版 make-counter と、WardLisp の関数型版 (count-up) を対比する"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:strong "SICP 3.2.3")
                           " は "
                           (:code "make-counter")
                           " のような状態を持つクロージャが、"
                           "フレームのどこに値を保持しているかを論じます。")
                       (:p "SICP 原典の例 (WardLisp では動かない):")
                       (:pre ";; SICP 原典 (WardLisp では set! がないので動かない)
(define (make-counter)
  (let ((count 0))
    (lambda ()
      (set! count (+ count 1))
      count)))")
                       (:p (:code "(make-counter)")
                           " を呼ぶと let フレームが作られ、"
                           (:code "count: 0")
                           " が束縛されます。"
                           "返された lambda は "
                           (:strong "そのフレームを親")
                           " とします。"
                           (:code "set!")
                           " で "
                           (:code "count")
                           " を更新すると、let フレームの "
                           (:code "count")
                           " の値が書き換わるので、"
                           "次に lambda が呼ばれたときには更新後の値が見える、という仕組みです。")))
    (make-cell :id :ascii-frames :kind :prose
               :body '(:div
                       (:p (:strong "ASCII 図 (SICP set! 版)")
                           ":")
                       (:pre "  [global]
  └── make-counter: ...
  └── c: ─→ E1 (lambda)

  E1 [parent: E_let]      E_let [parent: global]
  body: (set! count ...)  └── count: 0  ← (set! count 1) で書き換え可能
                                          → 1 → 2 → 3 ...")
                       (:p "lambda は E_let を親とするので、"
                           "lambda 内で "
                           (:code "count")
                           " を参照すると E_let の "
                           (:code "count")
                           " 束縛が見える。"
                           (:code "set!")
                           " はこの束縛の値スロットを破壊的に書き換える。")))
    (make-cell :id :no-set-bang :kind :prose
               :body '(:div
                       (:p (:strong "WardLisp では ")
                           (:code "set!")
                           (:strong " がない")
                           " ので、let フレームの値を後から書き換える手段はありません。"
                           "代わりに、状態を持ちたい場合は "
                           (:strong "値を引数として持ち回る")
                           " 形 (関数型のスタイル) にする必要があります。")
                       (:p "「次の状態に進む手続き」を毎回新しく返す形にすると、"
                           "ある意味で同じ情報を別の表現で扱えます。")))
    (make-cell :id :functional-counter :kind :code-eval
               :body "; 関数型版: count を渡し続ける
(define (count-up count)
  (define new-count (+ count 1))
  (list new-count (lambda () (count-up new-count))))
(define c0 (count-up 0))
(define c1 ((car (cdr c0))))
(define c2 ((car (cdr c1))))
(list (car c0) (car c1) (car c2))")
    (make-cell :id :observation :kind :prose
               :body '(:div
                       (:p (:strong "観察")
                           ": "
                           (:code "set!")
                           " 版では同じクロージャが何度も状態を更新しますが、"
                           "関数型版では「次の状態に進む手続き」を毎回新しく返します。"
                           (:strong "情報量は同じだが扱い方が違う")
                           " ─ ここに関数型と命令型の本質的な対比があります。")
                       (:ul
                        (:li (:strong "set! 版")
                             ": クロージャは "
                             (:em "同一の存在")
                             " として残り、内部状態が時間とともに変化")
                        (:li (:strong "関数型版")
                             ": 状態は "
                             (:em "値そのもの")
                             " として外に出ていて、新しい状態は新しい値"))))
    (make-cell :id :ex-fresh-counter :kind :code-exercise
               :description
               "上記の count-up を使って、初期値 10 から始めて 3 回進めた値を取り出してください。
count-up は本ノートブックのコードセルで定義されています:
  (define (count-up count)
    (define new-count (+ count 1))
    (list new-count (lambda () (count-up new-count))))
最終式として
  (let* ((c1 (count-up 10))
         (c2 ((car (cdr c1))))
         (c3 ((car (cdr c2)))))
    (car c3))
を残してください。期待値は 13 です。"
               :body "; (define (count-up count) ...) 上のセルと同じ
; 最後に (let* (...) (car c3))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "13"
                                     :description "count-up で 10 から 3 回進めて 13"))))))
