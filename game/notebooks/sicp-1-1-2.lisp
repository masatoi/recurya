;;;; game/notebooks/sicp-1-1-2.lisp --- SICP 1.1.2 Naming and the Environment.

(defpackage #:recurya/game/notebooks/sicp-1-1-2
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:export #:make-sicp-1-1-2-notebook))

(in-package #:recurya/game/notebooks/sicp-1-1-2)

(defun make-sicp-1-1-2-notebook ()
  "SICP 1.1.2 - Naming and the Environment."
  (make-notebook
   :id :sicp-1-1-2
   :chapter "1.1.2"
   :title "命名と環境"
   :summary "define で値に名前をつけ、式の中で再利用する"
   :cells
   (list
    (make-cell :id :intro :kind :prose
               :body '(:p "プログラムの大事な側面の一つは、"
                          (:em "名前") "を使って計算対象を指すことです。"
                          (:code "define") "で名前に値を結びつけます。"))
    (make-cell :id :define-size :kind :code-eval
               :body "(define size 2)
(* 5 size)")
    (make-cell :id :env-prose :kind :prose
               :body '(:p (:strong "環境") "は、名前と値の対応を保持する文脈です。"
                          "後のセルは前のセルで定義した名前を参照できます。"))
    (make-cell :id :ex-circle-area :kind :code-exercise
               :description
               "半径 10 の円の面積を求めてください。円周率 pi を 3.14 としてよい。
半径 r の円の面積は pi × r × r です。手続き (circle-area r) を定義し、 (circle-area 10) を最終式として残してください。"
               :body "; 例: (define pi 3.14) など
; ここに定義と呼び出しを書く"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "314.0"
                                     :description "pi=3.14 で半径 10 の円の面積")))
    (make-cell :id :ex-sphere-volume :kind :code-exercise
               :description
               "半径 2 の球体の体積を求めてください。球の体積の公式は (4/3) × pi × r^3 です。
(define pi 3.14) のもと、最終式の値が体積になるようにしてください。"
               :body "; ここに書く"
               :test-cases
               (list (make-test-case :input ""
                                     :expected "33.49333333333333"
                                     :description "pi=3.14 で半径 2 の球体積"))))))
