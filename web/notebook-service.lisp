;;;; web/notebook-service.lisp --- Run a notebook cell and persist the outcome.
;;;;
;;;; Shared by the HTML cell-run route and the JSON API so both validate,
;;;; execute, persist and unlock solutions identically.  Access control and
;;;; response rendering stay with the callers.

(defpackage #:recurya/web/notebook-service
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-notebook
                #:notebook-cells
                #:cell-id
                #:cell-kind
                #:run-cell
                #:notebook-cell-result-status)
  (:import-from #:recurya/game/notebook-jsonb
                #:jsonb-hash->cell)
  (:import-from #:recurya/game/notebook-gating
                #:gated-solution-indices)
  (:import-from #:recurya/db/notebooks
                #:notebook-cells-parsed
                #:notebook-title
                #:notebook-summary)
  (:import-from #:recurya/db/learn
                #:upsert-cell-code
                #:record-submission
                #:mark-cell-passed)
  (:export #:notebook-row->notebook-struct
           #:parse-cell-index
           #:persist-cell-run
           #:run-notebook-cell
           #:cell-run-refused
           #:cell-run-refused-reason))

(in-package #:recurya/web/notebook-service)

(defun notebook-row->notebook-struct (nb-row)
  "Convert a notebook DAO into a recurya/game/notebook:notebook struct
that the existing notebook UI and run-cell logic can consume.
Cells come from the JSONB cache (parsed via jsonb-hash->cell)."
  (let* ((cells-data (notebook-cells-parsed nb-row))
         (cells-list (mapcar #'jsonb-hash->cell
                             (coerce (or cells-data #()) 'list))))
    (make-notebook
     :id (princ-to-string (recurya/db/notebooks:notebook-id nb-row))
     :chapter ""
     :title (or (notebook-title nb-row) "")
     :summary (or (notebook-summary nb-row) "")
     :cells cells-list)))

(define-condition cell-run-refused (error)
  ((reason :initarg :reason :reader cell-run-refused-reason))
  (:report (lambda (c stream)
             (format stream "Cell run refused: ~(~A~)" (cell-run-refused-reason c)))))

(defun parse-cell-index (raw)
  "RAW (a path string or an integer) as a cell index, or NIL."
  (typecase raw
    (string (parse-integer raw :junk-allowed t))
    (integer raw)
    (t nil)))

(defun persist-cell-run (uid nb-uuid cell result code)
  "Persist saved code, submission, and progress for a notebook cell run.
Anonymous users (UID NIL) are skipped silently; DB errors are logged but
do not poison the response."
  (when uid
    (handler-case
        (let* ((cell-id-str (string (or (cell-id cell) "")))
               (status      (notebook-cell-result-status result))
               (kind        (cell-kind cell))
               (status-str  (string-downcase (symbol-name status))))
          (upsert-cell-code uid nb-uuid cell-id-str (or code ""))
          (when (eq kind :code-exercise)
            (record-submission uid nb-uuid cell-id-str (or code "") status-str)
            (when (eq status :pass)
              (mark-cell-passed uid nb-uuid cell-id-str))))
      (error (e) (log:warn "Failed to persist notebook cell run: ~A" e)))))

(defun run-notebook-cell (nb-row uid index-raw codes)
  "Run the cell at INDEX-RAW of NB-ROW with CODES, the submitted code of cells
0..N in order, and persist the outcome for UID (NIL: anonymous, nothing saved).
Returns (VALUES RESULT CELLS REVEALED-INDICES INDEX): REVEALED-INDICES are the
gated solutions a passing exercise unlocks.  Signals CELL-RUN-REFUSED with
reason :INVALID-INDEX, :INDEX-OUT-OF-RANGE or :CANNOT-RUN-CELL (prose and
solution cells).  The caller checks that the viewer may see NB-ROW."
  (let* ((notebook (notebook-row->notebook-struct nb-row))
         (cells (notebook-cells notebook))
         (index (parse-cell-index index-raw)))
    (cond
      ((null index) (error 'cell-run-refused :reason :invalid-index))
      ((or (< index 0) (>= index (length cells)))
       (error 'cell-run-refused :reason :index-out-of-range))
      ((member (cell-kind (nth index cells)) '(:prose :code-solution))
       (error 'cell-run-refused :reason :cannot-run-cell)))
    (let* ((cell (nth index cells))
           (result (run-cell notebook index codes))
           (revealed (when (and (eq (cell-kind cell) :code-exercise)
                                (eq (notebook-cell-result-status result) :pass))
                       (gated-solution-indices cells index))))
      (persist-cell-run uid (princ-to-string (recurya/db/notebooks:notebook-id nb-row))
                        cell result (nth index codes))
      (values result cells revealed index))))
