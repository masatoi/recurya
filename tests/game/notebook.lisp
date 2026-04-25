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
                #:run-cell
                #:notebook-cell-result-status
                #:notebook-cell-result-value))

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

(deftest run-cell-code-eval-basic
  (testing "code-eval cell evaluates and returns value"
    (let* ((nb (make-notebook
                :id :demo :chapter "0" :title "Demo" :summary ""
                :cells (list (make-cell :id :c1 :kind :code-eval
                                        :body "(+ 1 2)"))))
           (r (run-cell nb 0 '("(+ 1 2)"))))
      (ok (eq :ok (recurya/game/notebook:notebook-cell-result-status r)))
      (ok (string= "3" (recurya/game/notebook:notebook-cell-result-value r))))))

(deftest run-cell-code-eval-shares-state-with-prior-cells
  (testing "a code cell sees defines from earlier cells"
    (let* ((nb (make-notebook
                :id :demo :chapter "0" :title "Demo" :summary ""
                :cells (list (make-cell :id :c1 :kind :code-eval
                                        :body "(define x 10)")
                             (make-cell :id :c2 :kind :code-eval
                                        :body "(* x 5)"))))
           (r (run-cell nb 1 '("(define x 10)" "(* x 5)"))))
      (ok (eq :ok (recurya/game/notebook:notebook-cell-result-status r)))
      (ok (string= "50" (recurya/game/notebook:notebook-cell-result-value r))))))

(deftest run-cell-exercise-pass
  (testing "exercise cell passes when expected matches"
    (let* ((tc (recurya/game/puzzle:make-test-case
                :input "(double 3)" :expected "6" :description "simple"))
           (nb (make-notebook
                :id :demo :chapter "0" :title "Demo" :summary ""
                :cells (list (make-cell :id :ex :kind :code-exercise
                                        :body "(define (double x) (* x 2))"
                                        :description "write double"
                                        :test-cases (list tc)))))
           (r (run-cell nb 0 '("(define (double x) (* x 2))"))))
      (ok (eq :pass (recurya/game/notebook:notebook-cell-result-status r))))))

(deftest run-cell-exercise-fail
  (testing "exercise cell fails when expected does not match"
    (let* ((tc (recurya/game/puzzle:make-test-case
                :input "(double 3)" :expected "6" :description "simple"))
           (nb (make-notebook
                :id :demo :chapter "0" :title "Demo" :summary ""
                :cells (list (make-cell :id :ex :kind :code-exercise
                                        :body "(define (double x) (+ x x x))"
                                        :description "wrong"
                                        :test-cases (list tc)))))
           (r (run-cell nb 0 '("(define (double x) (+ x x x))"))))
      (ok (eq :fail (recurya/game/notebook:notebook-cell-result-status r))))))

(deftest run-cell-fuel-exhaustion
  (testing "an infinite loop yields an error or limit status"
    (let* ((nb (make-notebook
                :id :demo :chapter "0" :title "Demo" :summary ""
                :cells (list (make-cell :id :c :kind :code-eval
                                        :body "(define (f) (f)) (f)"))))
           (r (run-cell nb 0 '("(define (f) (f)) (f)"))))
      (ok (member (recurya/game/notebook:notebook-cell-result-status r)
                  '(:error :limit-exceeded))))))

(deftest run-cell-tolerates-short-submitted-codes
  (testing "run-cell does not raise when submitted-codes is shorter than cell-index+1"
    (let* ((nb (make-notebook
                :id :demo :chapter "0" :title "Demo" :summary ""
                :cells (list (make-cell :id :a :kind :code-eval :body "1")
                             (make-cell :id :b :kind :code-eval :body "2")
                             (make-cell :id :c :kind :code-eval :body "3"))))
           (r (run-cell nb 2 '("(+ 10 20)")))) ; only 1 code for index 2
      (ok (eq :ok (recurya/game/notebook:notebook-cell-result-status r)))
      (ok (string= "30"
                   (recurya/game/notebook:notebook-cell-result-value r))))))
