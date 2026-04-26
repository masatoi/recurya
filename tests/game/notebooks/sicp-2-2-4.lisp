;;;; tests/game/notebooks/sicp-2-2-4.lisp --- Smoke test for SICP 2.2.4.

(defpackage #:recurya/tests/game/notebooks/sicp-2-2-4
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebooks/sicp-2-2-4
                #:make-sicp-2-2-4-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-cells #:cell-id))

(in-package #:recurya/tests/game/notebooks/sicp-2-2-4)

(deftest sicp-2-2-4-structure
  (testing "notebook has expected cells and unique ids"
    (let* ((nb (make-sicp-2-2-4-notebook))
           (cells (notebook-cells nb))
           (ids (mapcar #'cell-id cells)))
      (ok (>= (length cells) 4))
      (ok (= (length ids) (length (remove-duplicates ids)))))))
