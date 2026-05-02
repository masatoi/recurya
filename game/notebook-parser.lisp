;;;; game/notebook-parser.lisp --- Markdown <-> cell list parser for user notebooks.

(defpackage #:recurya/game/notebook-parser
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-cell)
  (:import-from #:recurya/game/puzzle
                #:make-test-case)
  (:import-from #:uuid
                #:make-v4-uuid)
  (:export #:parse-notebook-body
           #:cells->body-md
           #:render-cell-prose-html))

(in-package #:recurya/game/notebook-parser)

(defun split-lines (s)
  "Split S into a list of lines (stripping a single trailing \\r if any)."
  (let ((lines '())
        (start 0))
    (loop for i from 0 below (length s)
          when (char= (char s i) #\Newline)
            do (let ((line (subseq s start i)))
                 (push (if (and (> (length line) 0)
                                (char= (char line (1- (length line))) #\Return))
                           (subseq line 0 (1- (length line)))
                           line)
                       lines)
                 (setf start (1+ i))))
    (when (< start (length s))
      (push (subseq s start) lines))
    (nreverse lines)))

(defun parse-fence-header (line)
  "If LINE is a fence header line (`===kind===' or `===kind: desc==='),
   return (values KIND DESCRIPTION-OR-NIL). Otherwise return
   (values NIL NIL).

   KIND is a keyword such as :prose or :code-eval. DESCRIPTION is a
   string for fences that carry one (added in later tasks) or NIL.

   Future tasks will extend this with :code-exercise and :expect."
  (cond
    ((string= line "===prose===") (values :prose nil))
    ((string= line "===eval===")  (values :code-eval nil))
    (t                            (values nil nil))))

(defun parse-notebook-body (body-md &optional existing-cells)
  "Parse BODY-MD into (values CELLS ERRORS).

   BODY-MD is a string using `===KIND===' fence lines to delimit cells.
   Currently supports `===prose===' and `===eval===' cells; future tasks
   will add `===exercise: ...===' and `===expect[: ...]===' fences.

   Each parsed cell receives a fresh string UUID as its ID. EXISTING-CELLS
   is reserved for future stable-ID matching and is ignored at this stage."
  (declare (ignore existing-cells))
  (let ((errors '())
        (cells '())
        (current-kind nil)
        (current-desc nil)
        (current-buffer (make-array 0 :element-type 'character
                                      :fill-pointer 0 :adjustable t))
        (lines (split-lines body-md)))
    (flet ((flush ()
             (when current-kind
               (let ((body (string-trim '(#\Space #\Tab #\Newline #\Return)
                                        (coerce current-buffer 'string))))
                 (push (make-cell :id (princ-to-string (uuid:make-v4-uuid))
                                  :kind current-kind
                                  :body body
                                  :description (or current-desc ""))
                       cells))
               (setf (fill-pointer current-buffer) 0))))
      (dolist (line lines)
        (multiple-value-bind (kind desc) (parse-fence-header line)
          (cond
            (kind
             (flush)
             (setf current-kind kind
                   current-desc desc))
            (t
             (vector-push-extend #\Newline current-buffer)
             (loop for c across line do (vector-push-extend c current-buffer))))))
      (flush))
    (values (nreverse cells) (nreverse errors))))

(defun cells->body-md (cells)
  "Render CELLS list back into the canonical body-md string. Stub."
  (declare (ignore cells))
  (error "not implemented"))

(defun render-cell-prose-html (markdown-string)
  "Markdown -> sanitized HTML. Stub."
  (declare (ignore markdown-string))
  (error "not implemented"))
