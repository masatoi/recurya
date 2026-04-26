;;;; game/notebooks/sicp-3-3-1.lisp --- SICP 3.3.1 Mutable List Structure (persistent rewrite).

(defpackage #:recurya/game/notebooks/sicp-3-3-1
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-3-3-1-notebook))

(in-package #:recurya/game/notebooks/sicp-3-3-1)

(defun make-sicp-3-3-1-notebook ()
  "SICP 3.3.1 - Mutable list structure: sharing and identity, observed without mutation."
  (make-notebook
   :id :sicp-3-3-1
   :chapter "3.3.1"
   :title "可変リスト構造 (持続的版)"
   :summary "SICP 3.3.1 の set-car! / set-cdr! が起こす共有 (sharing) と同一性 (eq?) を、WardLisp の cons-only 世界で観察する。サイクルは原理的に作れない点を明記。"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:div
                       (:p (:strong "SICP 3.3.1")
                           " は "
                           (:code "set-car!")
                           " と "
                           (:code "set-cdr!")
                           " を導入し、リスト構造を後から変更できるようにします。"
                           "これで "
                           (:strong "共有 (sharing)")
                           "、"
                           (:strong "同一性 (eq?)")
                           "、"
                           (:strong "サイクル")
                           " を表現できます。")
                       (:pre ";; SICP 原典 (WardLisp では動かない)
(define x (list 'a 'b))
(define z (cons x x))
(set-car! (cdr z) 'changed)  ;; z = ((a b) (changed b))
;; ↑ z の car と cdr が同じ x を共有しているので、
;;   片方を書き換えると両方に反映される")
                       (:p "WardLisp は "
                           (:code "set-car!")
                           " / "
                           (:code "set-cdr!")
                           " を持たないので、共有の "
                           (:strong "観察")
                           " はできても "
                           (:strong "mutation 経由の挙動")
                           " は再現できません。"
                           "代わりに "
                           (:code "eq?")
                           " で共有を検出する例を扱います。")))
    (make-cell :id :sharing-eval :kind :code-eval
               :body "(define x (list 1 2 3))
(define z1 (cons x x))      ;; car と cdr が同じ x を指す
(define z2 (cons x (list 1 2 3)))  ;; car と cdr が別物
(list (eq? (car z1) (cdr z1)) (eq? (car z2) (cdr z2)))")
    (make-cell :id :sharing-explained :kind :prose
               :body '(:div
                       (:p (:strong "重要")
                           ": cons は元のリストを "
                           (:strong "コピーしない")
                           "。"
                           (:code "(cons x x)")
                           " は同じ x への参照を 2 つ持つだけです。"
                           "WardLisp で "
                           (:code "set-car!")
                           " がなくても、"
                           (:strong "共有自体は普通に起きている")
                           " ことを "
                           (:code "eq?")
                           " で確認できます。")
                       (:p "上のセルの結果は "
                           (:code "(t nil)")
                           ":")
                       (:ul
                        (:li (:code "z1")
                             " は同一の x を指すので "
                             (:code "(eq? (car z1) (cdr z1))")
                             " は t")
                        (:li (:code "z2")
                             " は (list 1 2 3) を 2 回別々に評価したので "
                             (:code "(eq? (car z2) (cdr z2))")
                             " は nil"))))
    (make-cell :id :cycles-impossible :kind :prose
               :body '(:div
                       (:p (:strong "サイクル (循環構造)")
                           ": "
                           (:code "set-cdr!")
                           " を使えば、"
                           (:code "(define x (list 1 2 3))")
                           " から始めて "
                           (:code "(set-cdr! (cddr x) x)")
                           " で循環構造を作れます。")
                       (:pre ";; SICP 原典 (WardLisp では不可能)
(define x (list 1 2 3))
(set-cdr! (cddr x) x)  ;; x の最後を x 自身に向け直す
;; → x はもはや有限のリストではなく、無限に巡回する構造")
                       (:p (:strong "WardLisp ではサイクルは作れません")
                           "。"
                           "cons は常に新しいセルを作り、既存のセルの cdr を書き換える手段がないからです。"
                           "「サイクルは mutation でしか作れない」"
                           " ─ これは WardLisp の制約であると同時に、"
                           (:strong "純粋な関数型データ構造の安全性")
                           " (停止性、共有メモ化) でもあります。")))
    (make-cell :id :ex-shared-detect :kind :code-exercise
               :description
               "リスト a と b の cdr が同じセルを共有しているかを eq? で検出する手続き
(cdr-eq? a b) を書いてください。シンプルに (eq? (cdr a) (cdr b)) を返すだけで OK。
最終式として
  (let* ((c (list 1 2 3)) (a (cons 'x c)) (b (cons 'y c))) (cdr-eq? a b))
を残してください。期待値は t です。
スケルトン:
  (define (cdr-eq? a b) (eq? (cdr a) (cdr b)))
  (let* ((c (list 1 2 3)) (a (cons 'x c)) (b (cons 'y c))) (cdr-eq? a b))"
               :body "; (define (cdr-eq? a b) ...)
; (let* ((c (list 1 2 3)) (a (cons 'x c)) (b (cons 'y c))) (cdr-eq? a b))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "t"
                                     :description "cdr-eq? が共有された cdr を t と検出")))
    (make-cell :id :ex-cons-twice :kind :code-exercise
               :description
               "(cons x x) が同じ x を 2 回参照することを確認する式を書いてください。
最終式として
  (let* ((x (list 1 2)) (z (cons x x))) (eq? (car z) (cdr z)))
を残してください。期待値は t です。
スケルトン:
  (let* ((x (list 1 2)) (z (cons x x))) (eq? (car z) (cdr z)))"
               :body "; (let* ((x (list 1 2)) (z (cons x x))) (eq? (car z) (cdr z)))
"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "t"
                                     :description "(cons x x) の car と cdr が同一 x"))))))
