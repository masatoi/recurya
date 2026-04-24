;;;; tests/game/notebooks/sicp-1-1-2.lisp --- Smoke test for SICP 1.1.2.

(defpackage #:recurya/tests/game/notebooks/sicp-1-1-2
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-1-1-2
                #:make-sicp-1-1-2-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id #:cell-kind))

(in-package #:recurya/tests/game/notebooks/sicp-1-1-2)

(deftest sicp-1-1-2-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-1-1-2-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))
