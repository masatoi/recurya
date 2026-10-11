;;;; specs/db/domain.lisp --- Shared value domains and helpers for DB contracts.
;;;;
;;;; Column value domains taken from db/schema.sql and the route-level allow
;;;; lists, generators for in-domain values, and small helpers shared by the
;;;; DB contract files.  Not loaded by the production system.

(defpackage #:recurya/specs/db/domain
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:uuid
                #:make-v4-uuid)
  (:export #:*publication-statuses*
           #:*visibilities*
           #:*submission-statuses*
           #:submission-status
           #:submission-status-p
           #:publication-status
           #:publication-status-p
           #:visibility
           #:visibility-p
           #:varchar-255
           #:varchar-255-p
           #:summary-text
           #:summary-text-p
           #:random-element
           #:random-db-text
           #:random-summary
           #:id-string
           #:fresh-user-id
           #:set-equal-p))
(in-package #:recurya/specs/db/domain)

(defparameter *publication-statuses* '("draft" "published")
  "Notebook and course statuses: the STATUS values that %DECODE-STATE-TOKEN in
web/routes.lisp produces.")

(defparameter *visibilities* '("private" "unlisted" "public")
  "Notebook and course visibilities: %DECODE-STATE-TOKEN's values and the allow
list in NOTEBOOK-UPDATE-HANDLER (web/routes.lisp).")

(defparameter *text-pieces*
  (vector "a" "Title" "ラムダ λ" "say \"hi\"" "back\\slash" "x-y_z")
  "Pieces of in-domain text: ASCII, non-ASCII, quotes, backslash, punctuation.")

(defun random-element (sequence)
  "Return a uniformly chosen element of the non-empty SEQUENCE."
  (elt sequence (random (length sequence))))

(defun random-db-text (max-length)
  "A non-empty string of at most MAX-LENGTH characters; a fifth of the time
exactly MAX-LENGTH characters (ASCII or non-ASCII), to probe the column limit."
  (if (zerop (random 5))
      (make-string max-length :initial-element (random-element #(#\a #\λ)))
      (let ((text (format nil "~{~A~^ ~}"
                          (loop repeat (1+ (random 3))
                                collect (random-element *text-pieces*)))))
        (subseq text 0 (min max-length (length text))))))

(defun random-summary ()
  "NIL, the empty string, or text of at most 500 characters."
  (case (random 4)
    (0 nil)
    (1 "")
    (t (random-db-text 500))))

(defun publication-status-p (value)
  "True when VALUE is one of *PUBLICATION-STATUSES*."
  (and (stringp value) (member value *publication-statuses* :test #'string=) t))

(defun visibility-p (value)
  "True when VALUE is one of *VISIBILITIES*."
  (and (stringp value) (member value *visibilities* :test #'string=) t))

(defun varchar-255-p (value)
  "True for a string of 1-255 characters: the VARCHAR(255) NOT NULL columns
(title, slug) of db/schema.sql."
  (and (stringp value) (<= 1 (length value) 255)))

(defun summary-text-p (value)
  "True for NIL or a string of at most 500 characters: summary VARCHAR(500) NULL."
  (or (null value)
      (and (stringp value) (<= (length value) 500))))

(defgenerator publication-status ()
  "One of *PUBLICATION-STATUSES*."
  (random-element *publication-statuses*))

(defspec publication-status (satisfies publication-status-p)
  (:generator publication-status))

(defgenerator visibility ()
  "One of *VISIBILITIES*."
  (random-element *visibilities*))

(defspec visibility (satisfies visibility-p)
  (:generator visibility))

(defgenerator varchar-255 ()
  "In-domain title or slug text."
  (random-db-text 255))

(defspec varchar-255 (satisfies varchar-255-p)
  (:generator varchar-255))

(defgenerator summary-text ()
  "In-domain summary: NIL, empty, or up to 500 characters."
  (random-summary))

(defspec summary-text (satisfies summary-text-p)
  (:generator summary-text))

(defun id-string (id)
  "ID (a UUID object or string) as a lower-case string, for comparing ids."
  (string-downcase (princ-to-string id)))

(defun fresh-user-id ()
  "A fresh lower-case UUID string.  The learn tables key users by UUID without a
foreign key, so no user row is needed."
  (id-string (make-v4-uuid)))

(defun set-equal-p (a b)
  "True when lists A and B hold the same elements under EQUAL, ignoring order
and multiplicity."
  (and (subsetp a b :test #'equal)
       (subsetp b a :test #'equal)))

(defparameter *submission-statuses* '("pass" "fail" "error")
  "Exercise submission statuses: RUN-EXERCISE-CELL's :pass, :fail and :error,
lower-cased by %MAYBE-PERSIST-NOTEBOOK-CELL-RUN (web/routes.lisp).")

(defun submission-status-p (value)
  "True when VALUE is one of *SUBMISSION-STATUSES*."
  (and (stringp value) (member value *submission-statuses* :test #'string=) t))

(defgenerator submission-status ()
  "One of *SUBMISSION-STATUSES*."
  (random-element *submission-statuses*))

(defspec submission-status (satisfies submission-status-p)
  (:generator submission-status))
