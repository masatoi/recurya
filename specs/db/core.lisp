;;;; specs/db/core.lisp --- cl-spec contracts for the pure DB helpers.
;;;;
;;;; NIL <-> :NULL conversion, keyword and timestamp formatting, UUID
;;;; normalisation and shape checks in db/core, and the OAuth placeholder
;;;; handle shape in db/users.  No database access.  Design doc:
;;;; docs/superpowers/specs/2026-10-11-cl-spec-db-design.md

(defpackage #:recurya/specs/db/core
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defspec-function
                #:defproperty
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/specs/db/domain
                #:random-element)
  (:import-from #:recurya/db/core
                #:nil->null
                #:null->nil
                #:keyword->db-string
                #:format-timestamp-for-db
                #:ensure-uuid
                #:uuid-string-p)
  (:import-from #:recurya/db/users
                #:placeholder-handle-p
                ;; Internal helper under contract.
                #:%generate-placeholder-handle)
  (:import-from #:cl-ppcre
                #:scan)
  (:import-from #:uuid
                #:make-v4-uuid)
  (:import-from #:local-time
                #:decode-timestamp
                #:unix-to-timestamp))
(in-package #:recurya/specs/db/core)

(defgenerator db-value ()
  "A value that may reach or leave cl-dbi: NIL, :NULL, numbers, strings,
keywords, plain symbols, a float, a list and a character."
  (random-element (vector nil :null 0 42 "" "x" :pending 'plain-symbol 1.5
                          (list 1 2) #\a)))

(defspec db-value t (:generator db-value))

(defspec-function nil->null
  "NIL becomes :NULL; every other value is returned unchanged (EQ)."
  (:args (value db-value))
  (:post (if (null value) (eq result :null) (eq result value))))

(defspec-function null->nil
  ":NULL becomes NIL; every other value is returned unchanged (EQ)."
  (:args (value db-value))
  (:post (if (eq value :null) (null result) (eq result value))))

(defspec-function keyword->db-string
  "NIL gives NIL, a keyword gives its name in lower case, and any other value
is refused with a TYPE-ERROR (the docstring's pre-condition)."
  (:args (kw db-value))
  (:cases
    (:absent
      (:when (null kw))
      (:returns null))
    (:keyword
      (:when (keywordp kw))
      (:returns string)
      (:post (string= result (string-downcase (symbol-name kw)))))
    (:other
      (:when (and kw (not (keywordp kw))))
      (:signals (type type-error)))))

(defgenerator db-timestamp ()
  "A timestamp between 1970 and 2096 with a random microsecond."
  (unix-to-timestamp (random 4000000000) :nsec (* 1000 (random 1000000))))

(defspec db-timestamp (type local-time:timestamp) (:generator db-timestamp))

(defparameter *db-timestamp-shape*
  "\\A\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}\\.\\d{6}\\z"
  "The shape FORMAT-TIMESTAMP-FOR-DB's docstring promises.")

(defun expected-db-timestamp (ts)
  "TS as the docstring's 'YYYY-MM-DD HH:MM:SS.UUUUUU' in the default time zone,
built from DECODE-TIMESTAMP's fields rather than a format string."
  (multiple-value-bind (nsec sec min hour day month year) (decode-timestamp ts)
    (format nil "~4,'0D-~2,'0D-~2,'0D ~2,'0D:~2,'0D:~2,'0D.~6,'0D"
            year month day hour min sec (floor nsec 1000))))

(defspec-function format-timestamp-for-db
  "A timestamp is written as 'YYYY-MM-DD HH:MM:SS.UUUUUU' with microseconds."
  (:args (ts db-timestamp))
  (:returns string)
  (:post (and (scan *db-timestamp-shape* result)
              (string= result (expected-db-timestamp ts)))))

(defun random-uuid-string ()
  "A fresh lower-case UUID string (of CHARACTERs, so it can be mutated)."
  (map 'string #'char-downcase (princ-to-string (make-v4-uuid))))

(defgenerator uuid-like-input ()
  "A UUID object, a non-string value, or a UUID string in either case padded
with spaces."
  (case (random 4)
    (0 (make-v4-uuid))
    (1 (random-element (vector 42 :abc 'plain-symbol)))
    (t (let ((text (random-uuid-string)))
         (format nil "~A~A~A"
                 (random-element #("" " " "  "))
                 (if (zerop (random 2)) (string-upcase text) text)
                 (random-element #("" " " "   ")))))))

(defspec uuid-like-input t (:generator uuid-like-input))

(defspec-function ensure-uuid
  "A string is trimmed of outer spaces and lower-cased; any other value is
printed and lower-cased."
  (:args (value uuid-like-input))
  (:returns string)
  (:post (string= result
                  (string-downcase (if (stringp value)
                                       (string-trim " " value)
                                       (princ-to-string value))))))

(defparameter *uuid-shape*
  (concatenate 'string
               "\\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}"
               "-[0-9a-fA-F]{12}\\z")
  "The 8-4-4-4-12 hexadecimal shape PostgreSQL accepts for a UUID: ASCII hex
digits of either case only.")

(defun mutate-uuid (text)
  "TEXT, a UUID string, with one defect (or none): a non-hex or non-ASCII digit
character, upper case, a missing or extra character, a trailing newline, no
hyphens, or a leading space."
  (let ((copy (copy-seq text))
        (i (random (length text))))
    (case (random 8)
      (0 (setf (char copy i)
               (random-element (vector #\g #\z #\- #\Space #\G
                                       (code-char #x0661) (code-char #xFF11))))
         copy)
      (1 (string-upcase copy))
      (2 (subseq copy 1))
      (3 (concatenate 'string copy "0"))
      (4 (concatenate 'string copy (string #\Newline)))
      (5 (remove #\- copy))
      (6 (concatenate 'string " " copy))
      (t copy))))

(defgenerator uuid-candidate ()
  "A value that may or may not be a canonical UUID string."
  (case (random 5)
    (0 (random-element (vector nil 42 :uuid "" "nil")))
    (1 (random-uuid-string))
    (t (mutate-uuid (random-uuid-string)))))

(defspec uuid-candidate t (:generator uuid-candidate))

(defspec-function uuid-string-p
  "True exactly for a 36-character 8-4-4-4-12 string of ASCII hex digits, so a
value PostgreSQL would reject as a UUID never reaches it."
  (:args (value uuid-candidate))
  (:post (eq (and result t)
             (and (stringp value) (scan *uuid-shape* value) t))))

(defparameter *placeholder-shape* "\\Au-[0-9a-f]{8}\\z"
  "The placeholder handle shape from PLACEHOLDER-HANDLE-P's docstring: u- and
exactly 8 lower-case hex digits.")

(defgenerator handle-candidate ()
  "A value that may or may not be a placeholder handle."
  (let ((hex (subseq (random-uuid-string) 0 8)))
    (case (random 7)
      (0 (format nil "u-~A" hex))
      (1 (format nil "u-~A" (string-upcase hex)))
      (2 (format nil "u-~A" (subseq hex 1)))
      (3 (format nil "u-~A0" hex))
      (4 (format nil "U-~A" hex))
      (5 (format nil "u-~A~%" hex))
      (t (random-element (vector nil "" "alice" "u-" 42
                                 (format nil "u-~Ag" (subseq hex 1))))))))

(defspec handle-candidate t (:generator handle-candidate))

(defspec-function placeholder-handle-p
  "True exactly for u- followed by 8 lower-case hex digits."
  (:args (handle handle-candidate))
  (:post (eq (and result t)
             (and (stringp handle) (scan *placeholder-shape* handle) t))))

(defproperty generated-placeholder-handle-is-placeholder ()
  "Every handle %GENERATE-PLACEHOLDER-HANDLE makes has the placeholder shape, so
a new OAuth user is always routed to onboarding."
  (:about placeholder-handle-p)
  (:kind :invariant)
  (:trials (:smoke 50 :normal 200))
  (let ((handle (%generate-placeholder-handle)))
    (and (placeholder-handle-p handle)
         (scan *placeholder-shape* handle)
         t)))
