;;;; specs/db/notebooks.lisp --- cl-spec contracts for notebook and course rows.
;;;;
;;;; Create/get round trips over in-domain values, slug uniqueness per author,
;;;; list/count filters against a Lisp-side filter, and partial updates.  Each
;;;; trial runs inside WITH-TEST-DB (recurya_test only).  Design doc:
;;;; docs/superpowers/specs/2026-10-11-cl-spec-db-design.md

(defpackage #:recurya/specs/db/notebooks
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defproperty
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/specs/db/domain
                #:*publication-statuses*
                #:*visibilities*
                #:random-element
                #:random-db-text
                #:random-summary
                #:id-string)
  (:import-from #:recurya/tests/support/db
                #:with-test-db
                #:create-test-user)
  (:import-from #:recurya/models/users
                #:users-id)
  (:import-from #:recurya/db/notebooks
                #:create-notebook!
                #:get-notebook-by-id
                #:update-notebook!
                #:list-notebooks
                #:count-notebooks
                #:notebook-cells-parsed
                #:notebook-id
                #:notebook-title
                #:notebook-slug
                #:notebook-summary
                #:notebook-body-md
                #:notebook-status
                #:notebook-visibility
                #:notebook-author-id)
  (:import-from #:recurya/db/courses
                #:create-course!
                #:get-course-by-id
                #:list-courses
                #:count-courses
                #:course-id
                #:course-title
                #:course-slug
                #:course-summary
                #:course-status
                #:course-visibility
                #:course-author-id)
  (:import-from #:recurya/db/core
                #:execute!
                #:format-timestamp-for-db)
  (:import-from #:local-time
                #:timestamp-
                #:unix-to-timestamp))
(in-package #:recurya/specs/db/notebooks)

(defun random-status ()
  "One of *PUBLICATION-STATUSES*."
  (random-element *publication-statuses*))

(defun random-visibility ()
  "One of *VISIBILITIES*."
  (random-element *visibilities*))

(defun same-id-p (a b)
  "True when ids A and B (UUID objects or strings) name the same row."
  (string= (id-string a) (id-string b)))

;;; Round trips

(defgenerator notebook-values ()
  "Create-notebook! keyword arguments with in-domain values; CELLS is a JSON
array of 0-3 strings (the cell shape itself is sub-project B's contract)."
  (list :title (random-db-text 255)
        :slug (random-db-text 255)
        :summary (random-summary)
        :body-md (random-db-text 1000)
        :status (random-status)
        :visibility (random-visibility)
        :cells (loop repeat (random 4) collect (random-db-text 20))))

(defspec notebook-values list (:generator notebook-values))

(defproperty notebook-create-get-roundtrip ((row-values notebook-values))
  "A notebook created with in-domain values reads back with every column equal
and its author's id."
  (:about create-notebook! get-notebook-by-id)
  (:kind :roundtrip)
  (:trials (:smoke 20 :normal 100))
  (with-test-db
    (let* ((author (create-test-user))
           (created (apply #'create-notebook! :author author row-values))
           (nb (get-notebook-by-id (id-string (notebook-id created)))))
      (and nb
           (equal (notebook-title nb) (getf row-values :title))
           (equal (notebook-slug nb) (getf row-values :slug))
           (equal (notebook-summary nb) (getf row-values :summary))
           (equal (notebook-body-md nb) (getf row-values :body-md))
           (equal (notebook-status nb) (getf row-values :status))
           (equal (notebook-visibility nb) (getf row-values :visibility))
           (equal (coerce (notebook-cells-parsed nb) 'list) (getf row-values :cells))
           (same-id-p (notebook-author-id nb) (users-id author))))))

(defgenerator course-values ()
  "Create-course! keyword arguments with in-domain values."
  (list :title (random-db-text 255)
        :slug (random-db-text 255)
        :summary (random-summary)
        :status (random-status)
        :visibility (random-visibility)))

(defspec course-values list (:generator course-values))

(defproperty course-create-get-roundtrip ((row-values course-values))
  "A course created with in-domain values reads back with every column equal
and its author's id."
  (:about create-course! get-course-by-id)
  (:kind :roundtrip)
  (:trials (:smoke 20 :normal 100))
  (with-test-db
    (let* ((author (create-test-user))
           (created (apply #'create-course! :author author row-values))
           (course (get-course-by-id (id-string (course-id created)))))
      (and course
           (equal (course-title course) (getf row-values :title))
           (equal (course-slug course) (getf row-values :slug))
           (equal (course-summary course) (getf row-values :summary))
           (equal (course-status course) (getf row-values :status))
           (equal (course-visibility course) (getf row-values :visibility))
           (same-id-p (course-author-id course) (users-id author))))))

;;; Slug uniqueness

(defgenerator slug-text ()
  "In-domain slug text."
  (random-db-text 255))

(defspec slug-text string (:generator slug-text))

(defproperty notebook-slug-unique-per-author ((slug slug-text))
  "A second notebook with the same slug by the same author is refused with a
database error (the unique key (author_id, slug)); another author may use it."
  (:about create-notebook!)
  (:kind :invariant)
  (:trials (:smoke 20 :normal 100))
  (with-test-db
    (let ((alice (create-test-user))
          (bob (create-test-user)))
      (flet ((create (author)
               (create-notebook! :title "T" :slug slug :body-md "b" :author author)))
        (create alice)
        (and (handler-case (progn (create alice) nil)
               (dbi.error:dbi-database-error () t))
             (create bob)
             t)))))

;;; Listing

(defgenerator listing-scenario ()
  "(ROWS QUERY OFFSET LIMIT AGES): 0-8 rows (AUTHOR STATUS VISIBILITY) with
AUTHOR an index into two authors; a QUERY plist of optional :STATUS, :AUTHOR
(index) and :VISIBILITY; an OFFSET of NIL, 0, 1 or 3; a LIMIT of :DEFAULT
(argument omitted), NIL, 0, 1, 2 or 5; and AGES, a random permutation of
0..(rows - 1): the number of seconds each row's created_at is moved into the
past, so every row has a distinct creation time in a seeded random order.  The
permutation is drawn here because WITH-TEST-DB rebinds *RANDOM-STATE*."
  (let ((rows (loop repeat (random 9)
                    collect (list (random 2) (random-status) (random-visibility)))))
    (list rows
          (list :status (random-element (vector nil "draft" "published"))
                :author (random-element #(nil 0 1))
                :visibility (random-element (vector nil "private" "unlisted" "public")))
          (random-element #(nil 0 1 3))
          (random-element #(:default nil 0 1 2 5))
          (let ((ages (loop for i below (length rows) collect i)))
            (loop for i from (1- (length ages)) above 0
                  do (rotatef (nth i ages) (nth (random (1+ i)) ages)))
            ages))))

(defspec listing-scenario list (:generator listing-scenario))

(defparameter *listing-epoch* (unix-to-timestamp 1700000000)
  "The base time from which the listing properties assign each row a distinct
created_at (the DAO reads timestamps back at second granularity, so rows made
back to back would otherwise tie).")

(defun listing-holds-p (scenario table create list-fn count-fn id-fn)
  "Create SCENARIO's rows with CREATE (AUTHOR SLUG STATUS VISIBILITY -> row) in
TABLE, give each a distinct created_at (the epoch minus its age in seconds, from
the scenario's permutation) and check LIST-FN and COUNT-FN against filtering
the created rows in Lisp: with no limit the listing is exactly the matching
rows in order of descending created_at; the count is their number; and an
OFFSET/LIMIT listing is the exact slice [OFFSET, OFFSET+LIMIT) of it (LIMIT
defaulting to 50)."
  (destructuring-bind (rows query offset limit ages) scenario
    (let* ((authors (vector (create-test-user) (create-test-user)))
           (author-ids (map 'vector (lambda (author) (id-string (users-id author)))
                            authors))
           (created (loop for (a status visibility) in rows
                          for age in ages
                          for i from 0
                          collect (let ((id (id-string
                                             (funcall id-fn
                                                      (funcall create (aref authors a)
                                                               (format nil "slug-~D" i)
                                                               status visibility)))))
                                    (execute! (format nil "UPDATE ~A SET created_at = $1 ~
                                                           WHERE id = CAST($2 AS uuid)"
                                                      table)
                                              (format-timestamp-for-db
                                               (timestamp- *listing-epoch* age :sec))
                                              id)
                                    (list id a status visibility age))))
           (q-status (getf query :status))
           (q-author (getf query :author))
           (q-visibility (getf query :visibility))
           (filters (append (and q-status (list :status q-status))
                            (and q-author (list :author-id (aref author-ids q-author)))
                            (and q-visibility (list :visibility q-visibility))))
           ;; Newest first = smallest age first.
           (want (loop for (id a status visibility)
                         in (sort (copy-list created) #'< :key #'fifth)
                       when (and (or (null q-status) (string= status q-status))
                                 (or (null q-author) (= a q-author))
                                 (or (null q-visibility) (string= visibility q-visibility)))
                         collect id))
           (full (apply list-fn :limit nil filters))
           (full-ids (mapcar (lambda (row) (id-string (funcall id-fn row))) full))
           (paged (apply list-fn (append (and offset (list :offset offset))
                                         (unless (eq limit :default) (list :limit limit))
                                         filters)))
           (start (min (or offset 0) (length want)))
           (end (let ((size (if (eq limit :default) 50 limit)))
                  (if size (min (+ start size) (length want)) (length want)))))
      (and (equal full-ids want)
           (= (apply count-fn filters) (length want))
           (equal (mapcar (lambda (row) (id-string (funcall id-fn row))) paged)
                  (subseq want start end))))))

(defproperty notebook-list-filters ((scenario listing-scenario))
  "LIST-NOTEBOOKS returns exactly the notebooks matching its status, author and
visibility filters, newest first, COUNT-NOTEBOOKS counts them, and OFFSET/LIMIT
take a slice of that listing."
  (:about list-notebooks count-notebooks)
  (:kind :invariant)
  (:trials (:smoke 20 :normal 100))
  (with-test-db
    (listing-holds-p scenario "notebook"
                     (lambda (author slug status visibility)
                       (create-notebook! :title "T" :slug slug :body-md "b" :author author
                                         :status status :visibility visibility))
                     #'list-notebooks #'count-notebooks #'notebook-id)))

(defproperty course-list-filters ((scenario listing-scenario))
  "LIST-COURSES returns exactly the courses matching its status, author and
visibility filters, newest first, COUNT-COURSES counts them, and OFFSET/LIMIT
take a slice of that listing."
  (:about list-courses count-courses)
  (:kind :invariant)
  (:trials (:smoke 20 :normal 100))
  (with-test-db
    (listing-holds-p scenario "course"
                     (lambda (author slug status visibility)
                       (create-course! :title "T" :slug slug :author author
                                       :status status :visibility visibility))
                     #'list-courses #'count-courses #'course-id)))

;;; Partial update

(defparameter *updatable-fields* '(:title :slug :summary :body-md :status :visibility)
  "UPDATE-NOTEBOOK! keyword arguments covered by NOTEBOOK-UPDATE-PARTIAL.  CELLS
is left out: its docstring (F-C2) says an empty list is ignored.")

(defun random-notebook-fields ()
  "A plist of in-domain values for every field in *UPDATABLE-FIELDS*; summary is
always a string so it can serve as an update value."
  (list :title (random-db-text 255)
        :slug (random-db-text 255)
        :summary (random-db-text 500)
        :body-md (random-db-text 1000)
        :status (random-status)
        :visibility (random-visibility)))

(defgenerator notebook-update-plan ()
  "(BEFORE CHANGES CELLS): creation values, a random subset of the fields with
new non-NIL values, and 1-3 cell strings the notebook is created with (never
among CHANGES, so an update must leave them alone)."
  (let ((before (random-notebook-fields))
        (after (random-notebook-fields)))
    (list before
          (loop for field in *updatable-fields*
                when (zerop (random 2))
                  append (list field (getf after field)))
          (loop repeat (1+ (random 3)) collect (random-db-text 20)))))

(defspec notebook-update-plan list (:generator notebook-update-plan))

(defun notebook-field (nb field)
  "NB's value for the *UPDATABLE-FIELDS* keyword FIELD."
  (ecase field
    (:title (notebook-title nb))
    (:slug (notebook-slug nb))
    (:summary (notebook-summary nb))
    (:body-md (notebook-body-md nb))
    (:status (notebook-status nb))
    (:visibility (notebook-visibility nb))))

(defproperty notebook-update-partial ((plan notebook-update-plan))
  "UPDATE-NOTEBOOK! sets exactly the fields it is given and leaves every other
field, and the notebook's cells, as they were."
  (:about update-notebook!)
  (:kind :invariant)
  (:trials (:smoke 20 :normal 100))
  (destructuring-bind (before changes cells) plan
    (with-test-db
      (let* ((id (id-string (notebook-id (apply #'create-notebook!
                                                :author (create-test-user)
                                                :cells cells before))))
             (cells-before (coerce (notebook-cells-parsed (get-notebook-by-id id)) 'list)))
        (apply #'update-notebook! id changes)
        (let ((nb (get-notebook-by-id id)))
          (and (equal cells-before cells)
               (equal (coerce (notebook-cells-parsed nb) 'list) cells)
               (loop for field in *updatable-fields*
                     always (equal (notebook-field nb field)
                                   (getf changes field (getf before field))))))))))
