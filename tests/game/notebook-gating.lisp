;;;; tests/game/notebook-gating.lisp --- Pure solution-unlock rules.

(defpackage #:recurya/tests/game/notebook-gating
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebook
                #:make-cell)
  (:import-from #:recurya/game/notebook-gating
                #:cell-id-string
                #:solution-unlocked-p
                #:gated-solution-indices))

(in-package #:recurya/tests/game/notebook-gating)

(defun cells (&rest specs)
  "Build cells from (KIND ID &optional GATED) specs."
  (loop for (kind id gated) in specs
        collect (make-cell :id id :kind kind :body "" :gated-p (and gated t))))

(defparameter *nb*
  (cells '(:prose "p") '(:code-exercise "e1") '(:code-solution "s1" t)
         '(:code-solution "s1open") '(:code-exercise "e2") '(:code-solution "s2" t)))

(deftest cell-id-string-normalises
  (ok (string= "" (cell-id-string nil)))
  (ok (string= "abc" (cell-id-string :abc)))
  (ok (string= "X-1" (cell-id-string "X-1"))))

(deftest gated-solution-needs-preceding-exercise-pass
  (ng (solution-unlocked-p *nb* 2 '()))
  (ok (solution-unlocked-p *nb* 2 '("e1")))
  (ng (solution-unlocked-p *nb* 2 '("e2")) "another exercise's pass does not unlock it")
  (ok (solution-unlocked-p *nb* 3 '()) "an ungated solution is always visible")
  (ng (solution-unlocked-p *nb* 5 '("e1")))
  (ok (solution-unlocked-p *nb* 5 '("e2"))))

(deftest gated-solution-without-exercise-stays-locked
  (ng (solution-unlocked-p (cells '(:prose "p") '(:code-solution "s" t)) 1 '("p"))))

(deftest gated-solution-indices-stop-at-next-exercise
  (ok (equal '(2) (gated-solution-indices *nb* 1)))
  (ok (equal '(5) (gated-solution-indices *nb* 4)))
  (ok (null (gated-solution-indices (cells '(:code-exercise "e")) 0))))
