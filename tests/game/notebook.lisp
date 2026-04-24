;;;; tests/game/notebook.lisp --- Tests for the notebook model and run-cell.

(defpackage #:recurya/tests/game/notebook
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebook
                #:make-notebook
                #:notebook-id
                #:notebook-cells
                #:make-cell
                #:cell-id
                #:cell-kind
                #:cell-body
                #:cell-test-cases
                #:run-cell))

(in-package #:recurya/tests/game/notebook)

(deftest notebook-struct-basic
  (testing "notebook holds id and cells"
    (let* ((c (make-cell :id :intro :kind :prose :body '(:p "hello")))
           (nb (make-notebook :id :demo :chapter "0" :title "Demo"
                              :summary "A demo" :cells (list c))))
      (ok (eq :demo (notebook-id nb)))
      (ok (= 1 (length (notebook-cells nb))))
      (ok (eq :intro (cell-id c)))
      (ok (eq :prose (cell-kind c)))
      (ok (equal '(:p "hello") (cell-body c))))))

(deftest cell-exercise-fields
  (testing "code-exercise cells carry description and test-cases"
    (let ((c (make-cell :id :ex :kind :code-exercise
                        :body "(define (f) 0)"
                        :description "trivial"
                        :test-cases nil)))
      (ok (eq :code-exercise (cell-kind c)))
      (ok (null (cell-test-cases c))))))

(deftest run-cell-prose-rejected
  (testing "prose cells cannot be executed"
    (let* ((nb (make-notebook
                :id :demo :chapter "0" :title "Demo" :summary ""
                :cells (list (make-cell :id :p :kind :prose :body '(:p "x"))))))
      (ok (signals (run-cell nb 0 '(""))
                   'error)))))
