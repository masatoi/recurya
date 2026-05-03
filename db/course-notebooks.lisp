;;;; db/course-notebooks.lisp --- CRUD for course<->user-notebook join with positions.

(defpackage #:recurya/db/course-notebooks
  (:use #:cl)
  (:import-from #:mito
                #:find-dao
                #:select-dao
                #:insert-dao
                #:save-dao
                #:delete-dao)
  (:import-from #:sxql #:where #:order-by)
  (:import-from #:recurya/db/core #:ensure-uuid #:with-transaction)
  (:import-from #:recurya/models/course-notebook
                #:course-notebook
                #:course-notebook-course
                #:course-notebook-notebook
                #:course-notebook-position
                #:course-notebook-id
                #:course-notebook-course-id
                #:course-notebook-notebook-id)
  (:import-from #:recurya/models/course #:course)
  (:import-from #:recurya/models/user-notebook #:user-notebook)
  (:export #:add-notebook-to-course!
           #:remove-notebook-from-course!
           #:move-notebook-up!
           #:move-notebook-down!
           #:list-course-notebooks
           #:count-course-notebooks
           #:get-course-notebook
           ;; re-exports for caller convenience
           #:course-notebook
           #:course-notebook-id
           #:course-notebook-course
           #:course-notebook-course-id
           #:course-notebook-notebook
           #:course-notebook-notebook-id
           #:course-notebook-position))

(in-package #:recurya/db/course-notebooks)

(defun add-notebook-to-course! (course-id notebook-id &key position)
  "Attach a notebook to a course at the given POSITION.

If POSITION is NIL, the new row is appended after the largest existing
position for this course (0 when the course has no notebooks).

Arguments:
  COURSE-ID    - Course UUID (string).
  NOTEBOOK-ID  - User-notebook UUID (string).
  POSITION     - Integer position, or NIL to append.

Returns:
  The newly created COURSE-NOTEBOOK row.

Signals:
  An SQL unique-violation error if the (course, notebook) pair already
  exists. Callers that may attach the same notebook twice should check
  first."
  (let ((course (find-dao 'course :id (ensure-uuid course-id)))
        (notebook (find-dao 'user-notebook :id (ensure-uuid notebook-id))))
    (unless course
      (error "add-notebook-to-course!: course not found: ~A" course-id))
    (unless notebook
      (error "add-notebook-to-course!: notebook not found: ~A" notebook-id))
    (let ((pos (or position
                   (let ((existing
                          (select-dao 'course-notebook
                            (where (:= :course_id (ensure-uuid course-id))))))
                     (if existing
                         (1+ (reduce #'max existing
                                     :key #'course-notebook-position))
                         0)))))
      (insert-dao
       (make-instance 'course-notebook
                      :course course
                      :notebook notebook
                      :position pos)))))

(defun remove-notebook-from-course! (course-id notebook-id)
  "Delete the join row linking COURSE-ID to NOTEBOOK-ID.

Does NOT renumber remaining positions; gaps are tolerated and resolved
by subsequent moves.

Returns:
  T if a row was deleted, NIL otherwise."
  (let ((row (first
              (select-dao 'course-notebook
                (where (:and (:= :course_id (ensure-uuid course-id))
                             (:= :notebook_id (ensure-uuid notebook-id))))))))
    (when row
      (delete-dao row)
      t)))

(defun move-notebook-up! (course-notebook-id)
  "Swap the row's POSITION with the row immediately above it
(POSITION = self.position - 1) within the same course.

No-op when the row is already at POSITION 0 or the row does not exist.

Performed inside a single transaction. A temporary out-of-range
position (-1) is used during the swap to remain safe even if a UNIQUE
constraint on (course_id, position) is added in the future.

Returns:
  T when a swap occurred, NIL on no-op."
  (let ((row (get-course-notebook course-notebook-id)))
    (when (and row (> (course-notebook-position row) 0))
      (let* ((cid (course-notebook-course-id row))
             (pos (course-notebook-position row))
             (neighbour
              (first
               (select-dao 'course-notebook
                 (where (:and (:= :course_id (ensure-uuid cid))
                              (:= :position (1- pos))))))))
        (when neighbour
          (with-transaction
            (setf (course-notebook-position row) -1)
            (save-dao row)
            (setf (course-notebook-position neighbour) pos)
            (save-dao neighbour)
            (setf (course-notebook-position row) (1- pos))
            (save-dao row))
          t)))))

(defun move-notebook-down! (course-notebook-id)
  "Swap the row's POSITION with the row immediately below it
(POSITION = self.position + 1) within the same course.

No-op when the row is already at the last position or the row does not
exist.

Performed inside a single transaction with a temporary out-of-range
position (-1) for safety against future UNIQUE constraints.

Returns:
  T when a swap occurred, NIL on no-op."
  (let ((row (get-course-notebook course-notebook-id)))
    (when row
      (let* ((cid (course-notebook-course-id row))
             (pos (course-notebook-position row))
             (neighbour
              (first
               (select-dao 'course-notebook
                 (where (:and (:= :course_id (ensure-uuid cid))
                              (:= :position (1+ pos))))))))
        (when neighbour
          (with-transaction
            (setf (course-notebook-position row) -1)
            (save-dao row)
            (setf (course-notebook-position neighbour) pos)
            (save-dao neighbour)
            (setf (course-notebook-position row) (1+ pos))
            (save-dao row))
          t)))))

(defun list-course-notebooks (course-id)
  "Return all join rows attached to COURSE-ID, ordered by POSITION ascending."
  (select-dao 'course-notebook
    (where (:= :course_id (ensure-uuid course-id)))
    (order-by :position)))

(defun count-course-notebooks (course-id)
  "Return the number of notebooks attached to COURSE-ID."
  (let ((result
          (mito.db:retrieve-by-sql
           "SELECT COUNT(*) AS count FROM course_notebook WHERE course_id = ?"
           :binds (list (princ-to-string (ensure-uuid course-id))))))
    (if result (getf (first result) :count) 0)))

(defun get-course-notebook (course-notebook-id)
  "Fetch a join row by its BIGSERIAL primary key.

Returns:
  COURSE-NOTEBOOK instance, or NIL when no such row exists."
  (find-dao 'course-notebook :id course-notebook-id))
