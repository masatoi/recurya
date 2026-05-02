;;;; tests/game/notebook-parser.lisp --- Tests for notebook-parser package.

(defpackage #:recurya/tests/game/notebook-parser
  (:use #:cl #:rove)
  (:import-from #:recurya/game/notebook-parser
                #:parse-notebook-body
                #:cells->body-md
                #:render-cell-prose-html)
  (:import-from #:recurya/game/notebook
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
