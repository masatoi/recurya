;;;; tests/game/novel/eval.lisp
(defpackage #:recurya/tests/game/novel/eval
  (:use #:cl #:rove)
  (:import-from #:recurya/game/novel/eval #:eval-scene))

(in-package #:recurya/tests/game/novel/eval)

(defparameter *scene*
  "(list
     (if met-alice
         (list 'say \"アリス\" \"また会ったね。\")
         (list 'say \"アリス\" \"はじめまして。\"))
     (list 'set-flag 'met-alice))")

(deftest flag-false-branch
  (let ((dirs (eval-scene *scene* :flags '((:met-alice . nil)))))
    (ok (equal (first dirs) '(:say "アリス" "はじめまして。")))
    (ok (equal (second dirs) '(:set-flag :met-alice)))))

(deftest flag-true-branch
  (let ((dirs (eval-scene *scene* :flags '((:met-alice . t)))))
    (ok (equal (first dirs) '(:say "アリス" "また会ったね。")))))

(deftest prelude-helpers-available
  ;; prelude can define helpers the scene uses
  (let ((dirs (eval-scene "(list (greet \"アリス\"))"
                          :prelude "(define (greet name) (list 'say name \"やあ\"))")))
    (ok (equal (first dirs) '(:say "アリス" "やあ")))))

(deftest split-cells-prelude-and-scenes
  (multiple-value-bind (prelude scenes)
      (recurya/game/novel/eval:split-novel-cells
       '((:code-eval . "(define x 1)")
         (:scene . "(list (list 'narrate \"a\"))")
         (:code-eval . "(define y 2)")
         (:scene . "(list (list 'narrate \"b\"))")))
    (ok (search "(define x 1)" prelude))
    (ok (search "(define y 2)" prelude))
    (ok (= 2 (length scenes)))
    (ok (search "\"a\"" (first scenes)))))
