;;;; tests/game/novel/interpreter.lisp
(defpackage #:recurya/tests/game/novel/interpreter
  (:use #:cl #:rove)
  (:import-from #:recurya/game/novel/interpreter #:interpret-directives))

(in-package #:recurya/tests/game/novel/interpreter)

(deftest flattens-say-narrate-with-bg
  (multiple-value-bind (beats set-flags)
      (interpret-directives
       '((:bg "classroom")
         (:narrate "教室には誰もいない。")
         (:say "アリス" "おはよう！")
         (:set-flag :met-alice)))
    (ok (= 2 (length beats)))
    (ok (equal (first beats)
               '(:type :narrate :text "教室には誰もいない。" :bg "classroom")))
    (ok (equal (second beats)
               '(:type :say :speaker "アリス" :text "おはよう！" :bg "classroom")))
    (ok (equal set-flags '((:met-alice . t))))))

(deftest scene-grouping-and-bg-persists
  (multiple-value-bind (beats set-flags)
      (interpret-directives
       '((:scene (:bg "room") (:say "A" "1"))
         (:say "A" "2")
         (:set-flag :x 5)))
    (declare (ignore set-flags))
    (ok (= 2 (length beats)))
    ;; bg set inside scene persists to the following say
    (ok (string= "room" (getf (first beats) :bg)))
    (ok (string= "room" (getf (second beats) :bg)))))

(deftest unknown-directive-ignored
  (multiple-value-bind (beats set-flags)
      (interpret-directives '((:bogus 1 2) (:narrate "ok") "junk"))
    (declare (ignore set-flags))
    (ok (= 1 (length beats)))
    (ok (string= "ok" (getf (first beats) :text)))))
