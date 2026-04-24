;;;; tests/game/notebooks/sicp-1-1-1.lisp --- Smoke test for SICP 1.1.1.

(defpackage #:recurya/tests/game/notebooks/sicp-1-1-1
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-1-1
                #:make-sicp-1-1-1-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind))

(in-package #:recurya/tests/game/notebooks/sicp-1-1-1)

(deftest sicp-1-1-1-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-1-1-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))
