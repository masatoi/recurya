;;;; tests/game/notebooks/sicp-3-4-1.lisp --- Smoke tests for SICP 3.4.1.

(defpackage #:recurya/tests/game/notebooks/sicp-3-4-1
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-3-4-1
                #:make-sicp-3-4-1-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id))

(in-package #:recurya/tests/game/notebooks/sicp-3-4-1)

(deftest sicp-3-4-1-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-3-4-1-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 5))
      (ok (= (length ids) (length (remove-duplicates ids)))))))
