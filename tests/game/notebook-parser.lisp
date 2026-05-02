;;;; tests/game/notebook-parser.lisp --- Tests for notebook-parser package.

(defpackage #:recurya/tests/game/notebook-parser
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebook-parser
                #:parse-notebook-body
                #:cells->body-md
                #:render-cell-prose-html)
  (:import-from #:recurya/game/notebook
                #:make-cell
                #:cell-id
                #:cell-kind
                #:cell-body
                #:cell-description
                #:cell-test-cases))

(in-package #:recurya/tests/game/notebook-parser)

(deftest single-prose-cell
  (let ((body "===prose===
Lispは式を評価する言語です。"))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (ok (null errors))
      (ok (= 1 (length cells)))
      (let ((c (first cells)))
        (ok (eq :prose (cell-kind c)))
        (ok (search "Lispは式を評価する言語です。" (cell-body c)))
        (ok (stringp (cell-id c)))))))

(deftest single-eval-cell
  (let ((body "===eval===
(+ 137 349)"))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (ok (null errors))
      (ok (= 1 (length cells)))
      (ok (eq :code-eval (cell-kind (first cells))))
      (ok (search "(+ 137 349)" (cell-body (first cells)))))))

(deftest prose-then-eval
  (let ((body "===prose===
Hello.

===eval===
(+ 1 2)"))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (ok (null errors))
      (ok (= 2 (length cells)))
      (ok (eq :prose      (cell-kind (first cells))))
      (ok (eq :code-eval  (cell-kind (second cells)))))))

(deftest single-exercise-with-expect
  (let ((body "===exercise: 三項の和===
; ここに式を書く

===expect: 三項の和===
508"))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (ok (null errors))
      (ok (= 1 (length cells)))
      (let ((c (first cells)))
        (ok (eq :code-exercise (cell-kind c)))
        (ok (string= "三項の和" (cell-description c)))
        (ok (= 1 (length (cell-test-cases c))))))))

(deftest exercise-with-input-output-expect
  (let ((body "===exercise: zero?===
(define (zero? x) ???)

===expect===
input: (zero? 0)
output: t

===expect===
input: (zero? 5)
output: nil"))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (ok (null errors))
      (ok (= 2 (length (cell-test-cases (first cells))))))))

(deftest expect-without-prior-exercise
  (let ((body "===expect===
1"))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (declare (ignore cells))
      (ok (find-if (lambda (e) (search "expect" (getf e :message)))
                   errors)))))

(deftest exercise-missing-description
  (let ((body "===exercise===
(foo)"))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (declare (ignore cells))
      (ok errors))))

(deftest unknown-header
  (let ((body "===banana===
peel"))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (declare (ignore cells))
      (ok errors))))

(deftest empty-body-zero-cells
  (multiple-value-bind (cells errors) (parse-notebook-body "")
    (declare (ignore cells))
    (ok (find-if (lambda (e) (search "no cell" (getf e :message)))
                 errors))))

(deftest preserves-cell-id-on-match
  (let* ((body "===prose===
Hello.")
         (existing (list (make-cell :id "STABLE-ID" :kind :prose
                                    :body "Hello." :description ""))))
    (multiple-value-bind (cells errors) (parse-notebook-body body existing)
      (ok (null errors))
      (ok (string= "STABLE-ID" (cell-id (first cells)))))))

(deftest assigns-new-uuid-when-no-match
  (let ((body "===prose===
Different."))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (declare (ignore errors))
      (ok (stringp (cell-id (first cells))))
      (ok (not (string= "STABLE-ID" (cell-id (first cells))))))))
