;;;; tests/integration/novel-sample.lisp --- End-to-end novel sample flow.
;;;; Pure logic (no DB): evaluate scenes with reader flags and flatten to
;;;; beats, demonstrating that a flag set in scene 1 changes scene 2.
(defpackage #:recurya/tests/integration/novel-sample
  (:use #:cl #:rove)
  (:import-from #:recurya/game/novel/eval #:eval-scene)
  (:import-from #:recurya/game/novel/interpreter #:interpret-directives))
(in-package #:recurya/tests/integration/novel-sample)

(defparameter *prelude* "")
(defparameter *scene1* "(list (list 'narrate \"教室。\")
                              (list 'say \"アリス\" \"はじめまして。\")
                              (list 'set-flag 'met-alice))")
(defparameter *scene2* "(list (if met-alice
                                  (list 'say \"アリス\" \"また会ったね。\")
                                  (list 'say \"アリス\" \"…誰？\")))")

(deftest sample-two-scenes-flag-flow
  ;; scene1
  (multiple-value-bind (beats1 sf1)
      (interpret-directives (eval-scene *scene1* :prelude *prelude* :flags '()))
    (ok (= 2 (length beats1)))
    (ok (equal sf1 '((:met-alice . t))))
    ;; apply flags, then scene2
    (let* ((flags (list (cons :met-alice t)))
           (dirs2 (eval-scene *scene2* :prelude *prelude* :flags flags))
           (beats2 (interpret-directives dirs2)))
      (ok (string= "また会ったね。" (getf (first beats2) :text))))))
