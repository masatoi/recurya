;;;; tests/game/notebooks/sicp-3-4-2.lisp --- Smoke tests for SICP 3.4.2.

(defpackage #:recurya/tests/game/notebooks/sicp-3-4-2
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-4-2
                #:make-sicp-3-4-2-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id))

(in-package #:recurya/tests/game/notebooks/sicp-3-4-2)

(deftest sicp-3-4-2-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-4-2-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 5))
      (ok (= (length ids) (length (remove-duplicates ids)))))))
