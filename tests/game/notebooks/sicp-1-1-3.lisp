;;;; tests/game/notebooks/sicp-1-1-3.lisp --- Smoke test for SICP 1.1.3.

(defpackage #:recurya/tests/game/notebooks/sicp-1-1-3
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-1-3
                #:make-sicp-1-1-3-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind))

(in-package #:recurya/tests/game/notebooks/sicp-1-1-3)

(deftest sicp-1-1-3-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-1-3-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 3))
      (ok (= (length ids) (length (remove-duplicates ids)))))))
