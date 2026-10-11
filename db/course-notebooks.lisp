;;;; db/course-notebooks.lisp --- CRUD for course<->notebook join with positions.

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
  (:import-from #:recurya/models/notebook #:notebook)
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
        (notebook (find-dao 'notebook :id (ensure-uuid notebook-id))))
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

Does NOT renumber remaining positions; the gap is harmless because
MOVE-NOTEBOOK-UP! / MOVE-NOTEBOOK-DOWN! swap with the neighbour in listed
order, not with position +/- 1.

Returns:
  T if a row was deleted, NIL otherwise."
  (let ((row (first
              (select-dao 'course-notebook
                (where (:and (:= :course_id (ensure-uuid course-id))
                             (:= :notebook_id (ensure-uuid notebook-id))))))))
    (when row
      (delete-dao row)
      t)))

(defun %adjacent-course-notebook (row direction)
  "The join row next to ROW in its course's listed (position) order: the one
just above it for DIRECTION :UP, just below it for :DOWN, or NIL at that end.
Positions may have gaps (REMOVE-NOTEBOOK-FROM-COURSE! does not renumber), so
the neighbour is found by order, not by position +/- 1."
  (let ((pos (course-notebook-position row))
        (rows (list-course-notebooks (course-notebook-course-id row))))
    (ecase direction
      (:up (car (last (remove-if-not (lambda (r) (< (course-notebook-position r) pos))
                                     rows))))
      (:down (find-if (lambda (r) (> (course-notebook-position r) pos)) rows)))))

(defun %swap-positions! (row neighbour)
  "Exchange the positions of ROW and NEIGHBOUR in one transaction, parking ROW
at the out-of-range position -1 in between so a future UNIQUE constraint on
(course_id, position) is never violated."
  (let ((pos (course-notebook-position row))
        (other (course-notebook-position neighbour)))
    (with-transaction
      (setf (course-notebook-position row) -1)
      (save-dao row)
      (setf (course-notebook-position neighbour) pos)
      (save-dao neighbour)
      (setf (course-notebook-position row) other)
      (save-dao row))))

(defun move-notebook-up! (course-notebook-id)
  "Swap the row's POSITION with the row just above it in its course's listed
order (the largest smaller position), so a gap left by a removal does not
block the move.

No-op when the row is already first or the row does not exist.

Returns:
  T when a swap occurred, NIL on no-op."
  (let* ((row (get-course-notebook course-notebook-id))
         (neighbour (and row (%adjacent-course-notebook row :up))))
    (when neighbour
      (%swap-positions! row neighbour)
      t)))

(defun move-notebook-down! (course-notebook-id)
  "Swap the row's POSITION with the row just below it in its course's listed
order (the smallest larger position), so a gap left by a removal does not
block the move.

No-op when the row is already last or the row does not exist.

Returns:
  T when a swap occurred, NIL on no-op."
  (let* ((row (get-course-notebook course-notebook-id))
         (neighbour (and row (%adjacent-course-notebook row :down))))
    (when neighbour
      (%swap-positions! row neighbour)
      t)))

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
