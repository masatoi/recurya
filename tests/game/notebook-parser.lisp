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

(deftest single-solution-cell
  (let ((body "===solution: my-square===
(define (my-square x) (* x x))"))
    (multiple-value-bind (cells errors) (parse-notebook-body body)
      (ok (null errors))
      (ok (= 1 (length cells)))
      (let ((c (first cells)))
        (ok (eq :code-solution (cell-kind c)))
        (ok (string= "my-square" (cell-description c)))
        (ok (search "(* x x)" (cell-body c)))))))

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

(deftest roundtrip-prose
  (let ((body "===prose===
Hello world."))
    (let* ((cells1 (parse-notebook-body body))
           (md     (cells->body-md cells1))
           (cells2 (parse-notebook-body md)))
      (ok (= (length cells1) (length cells2)))
      (ok (string= (cell-body (first cells1)) (cell-body (first cells2)))))))

(deftest roundtrip-mixed
  (let* ((body "===prose===
Intro.

===eval===
(+ 1 2)

===exercise: sum===
; ?

===expect: sum===
3")
         (cells1 (parse-notebook-body body))
         (md     (cells->body-md cells1))
         (cells2 (parse-notebook-body md)))
    (ok (= (length cells1) (length cells2)))
    (loop for c1 in cells1 for c2 in cells2 do
          (ok (eq      (cell-kind c1) (cell-kind c2)))
          (ok (string= (cell-body c1) (cell-body c2))))))

(deftest roundtrip-with-solution
  (let* ((body "===exercise: square===
(define (square x) ???)

===expect: square===
4

===solution: square===
(define (square x) (* x x))")
         (cells1 (parse-notebook-body body))
         (md     (cells->body-md cells1))
         (cells2 (parse-notebook-body md)))
    (ok (= (length cells1) (length cells2)))
    (loop for c1 in cells1 for c2 in cells2 do
          (ok (eq      (cell-kind c1) (cell-kind c2)))
          (ok (string= (cell-body c1) (cell-body c2))))))

(deftest preserves-solution-cell-id
  (let* ((body "===solution: foo===
(define foo 1)")
         (existing (list (make-cell :id "STABLE-SOL" :kind :code-solution
                                    :body "(define foo 1)"
                                    :description "foo"))))
    (multiple-value-bind (cells errors) (parse-notebook-body body existing)
      (ok (null errors))
      (ok (string= "STABLE-SOL" (cell-id (first cells)))))))

(deftest renders-markdown-bold-and-strips-script
  (let ((html (render-cell-prose-html "**bold**

<script>x</script>")))
    (ok (search "<strong>bold</strong>" html))
    (ng (search "<script" html))))

(deftest scene-cell-roundtrip
  (let* ((body "===scene===
(list (list 'say \"アリス\" \"やあ\"))")
         (cells (parse-notebook-body body)))
    (ok (= 1 (length cells)))
    (ok (eq :scene (cell-kind (first cells))))
    (ok (search "(list 'say" (cell-body (first cells))))
    ;; render back and re-parse: kind/body stable
    (let* ((md (cells->body-md cells))
           (cells2 (parse-notebook-body md)))
      (ok (eq :scene (cell-kind (first cells2))))
      (ok (string= (cell-body (first cells)) (cell-body (first cells2)))))))
