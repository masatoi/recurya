;;;; specs/db/course-notebooks.lisp --- cl-spec contract for course notebook order.
;;;;
;;;; Random sequences of add / remove / move-up / move-down on one course,
;;;; checked after every step against a Lisp list modelling the intended
;;;; order.  Each trial runs inside WITH-TEST-DB (recurya_test only).  Design
;;;; doc: docs/superpowers/specs/2026-10-11-cl-spec-db-design.md

(defpackage #:recurya/specs/db/course-notebooks
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defproperty
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/specs/db/domain
                #:random-element
                #:id-string)
  (:import-from #:recurya/tests/support/db
                #:with-test-db
                #:create-test-user)
  (:import-from #:recurya/db/courses
                #:create-course!
                #:course-id)
  (:import-from #:recurya/db/notebooks
                #:create-notebook!
                #:notebook-id)
  (:import-from #:recurya/db/course-notebooks
                #:add-notebook-to-course!
                #:remove-notebook-from-course!
                #:move-notebook-up!
                #:move-notebook-down!
                #:list-course-notebooks
                #:course-notebook-id
                #:course-notebook-notebook-id
                #:course-notebook-position))
(in-package #:recurya/specs/db/course-notebooks)

(defparameter *notebook-count* 6
  "Notebooks created per trial, the pool that operations attach and detach.")

(defgenerator course-notebook-ops ()
  "8-20 operations (KIND N): KIND is :ADD (twice as likely), :REMOVE, :UP or
:DOWN, and N picks the target among the candidates modulo their count.  An
:ADD when every notebook is already attached, and any other operation on an
empty course, is a no-op on both the model and the database."
  (loop repeat (+ 8 (random 13))
        collect (list (random-element #(:add :add :remove :up :down))
                      (random *notebook-count*))))

(defspec course-notebook-ops list (:generator course-notebook-ops))

(defun row-notebook-id (row)
  "The notebook id of the join ROW as a lower-case string."
  (id-string (course-notebook-notebook-id row)))

(defun attached-notebook-ids (course-id)
  "The notebook ids of COURSE-ID's join rows in listed (position) order."
  (mapcar #'row-notebook-id (list-course-notebooks course-id)))

(defun row-id-of (course-id notebook-id)
  "The join-row id linking COURSE-ID to NOTEBOOK-ID."
  (course-notebook-id
   (find notebook-id (list-course-notebooks course-id)
         :key #'row-notebook-id :test #'string=)))

(defun positions-distinct-p (course-id)
  "True when no two join rows of COURSE-ID share a position."
  (let ((positions (mapcar #'course-notebook-position
                           (list-course-notebooks course-id))))
    (= (length positions) (length (remove-duplicates positions)))))

(defun swap-at (list i j)
  "A copy of LIST with the elements at I and J exchanged."
  (let ((items (coerce list 'vector)))
    (rotatef (aref items i) (aref items j))
    (coerce items 'list)))

(defun apply-op (op course-id notebook-ids model)
  "Apply OP to the course and to MODEL, the intended order of notebook ids.
Return (VALUES OK-P NEW-MODEL): OK-P is true when the call's return value is
the one the docstrings promise (a row for :ADD; T when a row was removed or
moved; NIL for moving the first row up or the last row down)."
  (destructuring-bind (kind n) op
    (if (eq kind :add)
        (let ((free (remove-if (lambda (id) (member id model :test #'string=))
                               notebook-ids)))
          (if (null free)
              (values t model)
              (let ((id (nth (mod n (length free)) free)))
                (values (and (add-notebook-to-course! course-id id) t)
                        (append model (list id))))))
        (if (null model)
            (values t model)
            (let* ((k (mod n (length model)))
                   (id (nth k model))
                   (last-index (1- (length model))))
              (ecase kind
                (:remove
                 (values (eq (remove-notebook-from-course! course-id id) t)
                         (remove id model :test #'string=)))
                (:up
                 (let ((result (move-notebook-up! (row-id-of course-id id))))
                   (if (zerop k)
                       (values (null result) model)
                       (values (eq result t) (swap-at model (1- k) k)))))
                (:down
                 (let ((result (move-notebook-down! (row-id-of course-id id))))
                   (if (= k last-index)
                       (values (null result) model)
                       (values (eq result t) (swap-at model k (1+ k))))))))))))

(defun make-course-pool (author)
  "Create a course and *NOTEBOOK-COUNT* notebooks by AUTHOR.  Return
(VALUES COURSE-ID NOTEBOOK-IDS) as lower-case strings."
  (values (id-string (course-id (create-course! :title "Course" :slug "course"
                                                :author author)))
          (loop for i below *notebook-count*
                collect (id-string
                         (notebook-id
                          (create-notebook! :title (format nil "Notebook ~D" i)
                                            :slug (format nil "notebook-~D" i)
                                            :body-md (format nil "===prose===~%x")
                                            :author author))))))

(defproperty course-notebook-order ((ops course-notebook-ops))
  "After every add, remove, move-up and move-down, the course lists its
notebooks in the intended order with distinct positions: an add appends, a
remove drops only that notebook, and a move swaps with the neighbour in listed
order (NIL and no change at either end), even across a gap a remove left."
  (:about add-notebook-to-course! remove-notebook-from-course!
          move-notebook-up! move-notebook-down!)
  (:kind :invariant)
  (:trials (:smoke 20 :normal 100))
  (with-test-db
    (multiple-value-bind (course-id notebook-ids)
        (make-course-pool (create-test-user))
      (let ((model '()))
        (loop for op in ops
              always (multiple-value-bind (ok new-model)
                         (apply-op op course-id notebook-ids model)
                       (setf model new-model)
                       (and ok
                            (equal (attached-notebook-ids course-id) model)
                            (positions-distinct-p course-id))))))))
