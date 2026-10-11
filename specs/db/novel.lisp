;;;; specs/db/novel.lisp --- cl-spec contracts for per-reader novel state.
;;;;
;;;; Flags written to the novel_state JSON come back unchanged and, injected
;;;; into the next scene, equal their values (no database); upserts keep one
;;;; row per (reader, notebook) with the last flags and scene index given
;;;; (inside WITH-TEST-DB, recurya_test only).  Design doc:
;;;; docs/superpowers/specs/2026-10-11-cl-spec-db-rest-design.md

(defpackage #:recurya/specs/db/novel
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defproperty
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/specs/db/domain
                #:fresh-user-id
                #:set-equal-p)
  (:import-from #:recurya/specs/game/novel
                #:random-flags)
  (:import-from #:recurya/tests/support/db
                #:with-test-db)
  (:import-from #:recurya/db/core
                #:execute-one)
  (:import-from #:recurya/db/novel
                #:get-novel-state
                #:upsert-novel-state
                #:novel-state-flags-alist
                ;; Internal helper under contract.
                #:%flags->json)
  (:import-from #:recurya/models/novel-state
                #:novel-state
                #:novel-state-scene-index)
  (:import-from #:recurya/game/novel/eval
                #:eval-scene))
(in-package #:recurya/specs/db/novel)

;;; Stored flags drive the next scene (no database)

(defgenerator stored-flags ()
  "1-4 flags with distinct names and values in the flag-value domain."
  (random-flags 1 4))

(defspec stored-flags list (:generator stored-flags))

(defun wardlisp-literal (value)
  "VALUE as a wardlisp literal: t, nil, a decimal integer, a string literal
with backslash and double quote escaped, or a quoted lower-case symbol."
  (cond ((eq value t) "t")
        ((null value) "nil")
        ((integerp value) (format nil "~D" value))
        ((stringp value)
         (with-output-to-string (out)
           (write-char #\" out)
           (loop for ch across value
                 do (when (member ch '(#\" #\\)) (write-char #\\ out))
                    (write-char ch out))
           (write-char #\" out)))
        (t (format nil "'~(~A~)" (symbol-name value)))))

(defun probe-scene (flags)
  "A scene that, for each flag, says yes when the injected flag is EQUAL? to
its value's literal and no otherwise; the speaker is the flag's name."
  (format nil "(list ~{~A~^ ~})"
          (loop for (name . value) in flags
                collect (format nil "(list 'say \"~(~A~)\" (if (equal? ~(~A~) ~A) \"yes\" \"no\"))"
                                (symbol-name name) (symbol-name name)
                                (wardlisp-literal value)))))

(defproperty persisted-flags-drive-next-scene ((flags stored-flags))
  "Flags written as the novel_state JSON and read back are the same flags, and
injected into a scene each one is EQUAL? to its value's literal: a flag set in
one scene drives the branches of the next.  No database access."
  (:about novel-state-flags-alist eval-scene)
  (:kind :roundtrip)
  (:trials (:smoke 30 :normal 200))
  (let ((read-back (novel-state-flags-alist
                    (make-instance 'novel-state :flags (%flags->json flags)))))
    (and (set-equal-p read-back flags)
         (= (length read-back) (length flags))
         (equal (eval-scene (probe-scene read-back) :flags read-back)
                (loop for (name) in read-back
                      collect (list :say (string-downcase (symbol-name name)) "yes"))))))

;;; Round trip through the table

(defgenerator novel-state-plan ()
  "(FLAGS SCENE-INDEX): 0-5 flags and a scene index 0-20."
  (list (random-flags 0 5) (random 21)))

(defspec novel-state-plan list (:generator novel-state-plan))

(defproperty novel-state-roundtrip ((plan novel-state-plan))
  "A reader's first upsert reads back with the same scene index and flags."
  (:about upsert-novel-state get-novel-state novel-state-flags-alist)
  (:kind :roundtrip)
  (:trials (:smoke 20 :normal 100))
  (destructuring-bind (flags scene-index) plan
    (with-test-db
      (let ((user (fresh-user-id)))
        (upsert-novel-state user "nb-0" :flags flags :scene-index scene-index)
        (let ((row (get-novel-state user "nb-0")))
          (and row
               (= (novel-state-scene-index row) scene-index)
               (set-equal-p (novel-state-flags-alist row) flags)
               (= (length (novel-state-flags-alist row)) (length flags))))))))

;;; Upsert sequences

(defgenerator novel-upsert-ops ()
  "1-8 upserts (USER NOTEBOOK FLAGS SCENE-INDEX): USER and NOTEBOOK are indices
0-1, FLAGS is NIL (keep) or 1-3 flags, SCENE-INDEX is NIL (keep) or 0-20."
  (loop repeat (1+ (random 8))
        collect (list (random 2) (random 2)
                      (if (zerop (random 3)) nil (random-flags 1 3))
                      (if (zerop (random 3)) nil (random 21)))))

(defspec novel-upsert-ops list (:generator novel-upsert-ops))

(defun last-given (ops u n key)
  "The last non-NIL value at KEY (2 = flags, 3 = scene index) among OPS for
user U and notebook N, or NIL."
  (let ((found nil))
    (loop for op in ops
          when (and (= (first op) u) (= (second op) n) (nth key op))
            do (setf found (nth key op)))
    found))

(defproperty novel-state-upsert-sequence ((ops novel-upsert-ops))
  "After a sequence of upserts each (reader, notebook) that was upserted has
exactly one row, whose flags are the last non-NIL flags given (none if never
given) and whose scene index is the last non-NIL index given (0 if never)."
  (:about upsert-novel-state get-novel-state)
  (:kind :invariant)
  (:trials (:smoke 20 :normal 100))
  (with-test-db
    (let ((users (vector (fresh-user-id) (fresh-user-id)))
          (notebooks #("nb-0" "nb-1")))
      (loop for (u n flags scene-index) in ops
            do (upsert-novel-state (aref users u) (aref notebooks n)
                                   :flags flags :scene-index scene-index))
      (and (= (second (execute-one "SELECT count(*) AS n FROM novel_state"))
              (length (remove-duplicates (mapcar (lambda (op) (list (first op) (second op)))
                                                 ops)
                                         :test #'equal)))
           (loop for u below 2
                 always (loop for n below 2
                              always (let ((row (get-novel-state (aref users u)
                                                                 (aref notebooks n)))
                                           (touched (find-if (lambda (op)
                                                               (and (= (first op) u)
                                                                    (= (second op) n)))
                                                             ops)))
                                       (if touched
                                           (and row
                                                (set-equal-p (novel-state-flags-alist row)
                                                             (last-given ops u n 2))
                                                (= (novel-state-scene-index row)
                                                   (or (last-given ops u n 3) 0)))
                                           (null row)))))))))
