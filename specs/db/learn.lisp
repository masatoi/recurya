;;;; specs/db/learn.lisp --- cl-spec contracts for learner progress storage.
;;;;
;;;; Passed cells form a set per (user, notebook), saved code keeps the last
;;;; write per cell, and a localStorage merge follows the "passed = OR, codes =
;;;; DB wins" rule of MERGE-LOCALSTORAGE's docstring.  Each trial runs inside
;;;; WITH-TEST-DB (recurya_test only).  Design doc:
;;;; docs/superpowers/specs/2026-10-11-cl-spec-db-design.md

(defpackage #:recurya/specs/db/learn
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defproperty
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/specs/db/domain
                #:fresh-user-id
                #:set-equal-p
                #:random-element
                #:*submission-statuses*)
  (:import-from #:recurya/tests/support/db
                #:with-test-db)
  (:import-from #:recurya/db/learn
                #:mark-cell-passed
                #:user-passed-cells
                #:upsert-cell-code
                #:user-cell-codes
                #:merge-localstorage
                #:record-submission
                #:cell-submissions)
  (:import-from #:recurya/models/learn-progress
                #:learn-progress)
  (:import-from #:recurya/models/learn-submission
                #:learn-submission-code
                #:learn-submission-status))
(in-package #:recurya/specs/db/learn)

(defparameter *notebook-keys* #("nb-0" "nb-1")
  "Notebook ids used by the learn trials (VARCHAR(64), no foreign key).")

(defparameter *cell-keys* #("c-0" "c-1" "c-2" "c-3")
  "Cell ids used by the learn trials (VARCHAR(64)).")

(defparameter *codes*
  (vector "" "(+ 1 2)" "λ" (format nil "line1~%line2") "say \"hi\"")
  "Saved code values: empty, Lisp, non-ASCII, multi-line, quoted.")

(defun two-users ()
  "A vector of two fresh user ids."
  (vector (fresh-user-id) (fresh-user-id)))

(defun no-duplicates-p (list &key (key #'identity))
  "True when no two elements of LIST have EQUAL keys."
  (= (length list) (length (remove-duplicates list :key key :test #'equal))))

(defgenerator pass-marks ()
  "0-15 marks (USER NOTEBOOK CELL), as indices into two users, *NOTEBOOK-KEYS*
and *CELL-KEYS*; repeats are likely."
  (loop repeat (random 16)
        collect (list (random 2) (random 2) (random 4))))

(defspec pass-marks list (:generator pass-marks))

(defproperty learn-progress-is-a-set ((marks pass-marks))
  "Marking cells passed, repeats included, returns a progress row each time,
and each (user, notebook) then lists exactly the distinct cells marked for it:
marking is idempotent and never leaks across users or notebooks."
  (:about mark-cell-passed user-passed-cells)
  (:kind :invariant)
  (:trials (:smoke 20 :normal 100))
  (with-test-db
    (let ((users (two-users)))
      (and (loop for (u n c) in marks
                 always (typep (mark-cell-passed (aref users u)
                                                 (aref *notebook-keys* n)
                                                 (aref *cell-keys* c))
                               'learn-progress))
           (loop for u below 2
                 always (loop for n below 2
                              always (let ((got (user-passed-cells
                                                 (aref users u)
                                                 (aref *notebook-keys* n)))
                                           (want (loop for (mu mn mc) in marks
                                                       when (and (= mu u) (= mn n))
                                                         collect (aref *cell-keys* mc))))
                                       (and (no-duplicates-p got)
                                            (set-equal-p got want)))))))))

(defgenerator code-writes ()
  "0-15 writes (USER NOTEBOOK CELL CODE) as indices; repeated cells are likely."
  (loop repeat (random 16)
        collect (list (random 2) (random 2) (random 4) (random (length *codes*)))))

(defspec code-writes list (:generator code-writes))

(defun last-writes (writes u n)
  "The ((CELL-ID . CODE) ...) that the last write per cell of user U and
notebook N in WRITES leaves."
  (let ((want '()))
    (loop for (wu wn wc wk) in writes
          when (and (= wu u) (= wn n))
            do (let ((cell (aref *cell-keys* wc)))
                 (setf want (acons cell (aref *codes* wk)
                                   (remove cell want :key #'car :test #'equal)))))
    want))

(defproperty cell-code-last-write-wins ((writes code-writes))
  "After a sequence of saves, each (user, notebook) holds one code per cell:
the one written last."
  (:about upsert-cell-code user-cell-codes)
  (:kind :invariant)
  (:trials (:smoke 20 :normal 100))
  (with-test-db
    (let ((users (two-users)))
      (loop for (u n c k) in writes
            do (upsert-cell-code (aref users u) (aref *notebook-keys* n)
                                 (aref *cell-keys* c) (aref *codes* k)))
      (loop for u below 2
            always (loop for n below 2
                         always (let ((got (user-cell-codes (aref users u)
                                                            (aref *notebook-keys* n))))
                                  (and (no-duplicates-p got :key #'car)
                                       (set-equal-p got (last-writes writes u n)))))))))

(defgenerator merge-scenario ()
  "(OLD-PASSED OLD-CODES PAYLOAD): rows already in the DB as (N C) and (N C K)
indices, and a localStorage payload of 1-3 entries (N CELLS PAIRS), where CELLS
are cell indices and PAIRS are (C K); repeats are likely everywhere."
  (list (loop repeat (random 5) collect (list (random 2) (random 4)))
        (loop repeat (random 5)
              collect (list (random 2) (random 4) (random (length *codes*))))
        (loop repeat (1+ (random 3))
              collect (list (random 2)
                            (loop repeat (random 5) collect (random 4))
                            (loop repeat (random 5)
                                  collect (list (random 4) (random (length *codes*))))))))

(defspec merge-scenario list (:generator merge-scenario))

(defun payload-plists (payload)
  "PAYLOAD as the plists MERGE-LOCALSTORAGE takes."
  (loop for (n cells pairs) in payload
        collect (list :notebook-id (aref *notebook-keys* n)
                      :passed (mapcar (lambda (c) (aref *cell-keys* c)) cells)
                      :codes (mapcar (lambda (pair)
                                       (cons (aref *cell-keys* (first pair))
                                             (aref *codes* (second pair))))
                                     pairs))))

(defproperty merge-localstorage-rules ((scenario merge-scenario))
  "Merging a payload into existing rows: passed cells become the union; a cell
that already has saved code keeps it (DB wins) and the first payload code wins
for a new cell; the returned counts are those of this rule applied in order."
  (:about merge-localstorage)
  (:kind :invariant)
  (:trials (:smoke 20 :normal 100))
  (destructuring-bind (old-passed old-codes payload) scenario
    (with-test-db
      (let ((user (fresh-user-id))
            (passed (make-hash-table :test 'equal))
            (codes (make-hash-table :test 'equal))
            (passed-merged 0)
            (codes-merged 0)
            (codes-skipped 0))
        (loop for (n c) in old-passed
              do (mark-cell-passed user (aref *notebook-keys* n) (aref *cell-keys* c))
                 (setf (gethash (cons n c) passed) t))
        (loop for (n c k) in old-codes
              do (upsert-cell-code user (aref *notebook-keys* n) (aref *cell-keys* c)
                                   (aref *codes* k))
                 (setf (gethash (cons n c) codes) (aref *codes* k)))
        ;; The model: apply the docstring's rule to the payload in order.
        (loop for (n cells pairs) in payload
              do (dolist (c cells)
                   (unless (gethash (cons n c) passed)
                     (setf (gethash (cons n c) passed) t)
                     (incf passed-merged)))
                 (loop for (c k) in pairs
                       do (if (nth-value 1 (gethash (cons n c) codes))
                              (incf codes-skipped)
                              (progn (setf (gethash (cons n c) codes) (aref *codes* k))
                                     (incf codes-merged)))))
        (and (equal (merge-localstorage user (payload-plists payload))
                    (list :passed-merged passed-merged
                          :codes-merged codes-merged
                          :codes-skipped codes-skipped))
             (loop for n below 2
                   always (and (set-equal-p
                                (user-passed-cells user (aref *notebook-keys* n))
                                (loop for c below 4
                                      when (gethash (cons n c) passed)
                                        collect (aref *cell-keys* c)))
                               (set-equal-p
                                (user-cell-codes user (aref *notebook-keys* n))
                                (loop for c below 4
                                      when (nth-value 1 (gethash (cons n c) codes))
                                        collect (cons (aref *cell-keys* c)
                                                      (gethash (cons n c) codes)))))))))))

(defgenerator submission-plan ()
  "(SUBMISSIONS LIMIT): 1-10 submissions (USER NOTEBOOK CELL CODE STATUS) as
indices into two users, *NOTEBOOK-KEYS*, the first two *CELL-KEYS* and
*CODES*, with STATUS from *SUBMISSION-STATUSES*; LIMIT is :DEFAULT (argument
omitted) or 1-12."
  (list (loop repeat (1+ (random 10))
              collect (list (random 2) (random 2) (random 2)
                            (random (length *codes*))
                            (random-element *submission-statuses*)))
        (if (zerop (random 3)) :default (1+ (random 12)))))

(defspec submission-plan list (:generator submission-plan))

(defproperty submission-history ((plan submission-plan))
  "Every submission is kept: for each (user, notebook, cell),
CELL-SUBMISSIONS returns that cell's submissions newest first, at most LIMIT
of them (50 by default), and none of another cell's."
  (:about record-submission cell-submissions)
  (:kind :invariant)
  (:trials (:smoke 20 :normal 100))
  (destructuring-bind (submissions limit) plan
    (with-test-db
      (let ((users (two-users)))
        (loop for (u n c k status) in submissions
              do (record-submission (aref users u) (aref *notebook-keys* n)
                                    (aref *cell-keys* c) (aref *codes* k) status))
        (loop for u below 2
              always
              (loop for n below 2
                    always
                    (loop for c below 2
                          always
                          (let* ((args (list (aref users u) (aref *notebook-keys* n)
                                             (aref *cell-keys* c)))
                                 (rows (if (eq limit :default)
                                           (apply #'cell-submissions args)
                                           (apply #'cell-submissions
                                                  (append args (list :limit limit)))))
                                 (newest-first
                                   (reverse (loop for (su sn sc k status) in submissions
                                                  when (and (= su u) (= sn n) (= sc c))
                                                    collect (list (aref *codes* k) status)))))
                            (equal (mapcar (lambda (row)
                                             (list (learn-submission-code row)
                                                   (learn-submission-status row)))
                                           rows)
                                   (subseq newest-first 0
                                           (min (length newest-first)
                                                (if (eq limit :default) 50 limit))))))))))))
