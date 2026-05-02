;;;; game/notebook-parser.lisp --- Markdown <-> cell list parser for user notebooks.

(defpackage #:recurya/game/notebook-parser
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:make-cell
                #:cell-test-cases)
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

(defparameter +exercise-header-regex+
  (cl-ppcre:create-scanner "^===exercise: (.+)===$")
  "Scanner for `===exercise: <description>===' fence headers.")

(defparameter +expect-header-regex+
  (cl-ppcre:create-scanner "^===expect(?:: (.+))?===$")
  "Scanner for `===expect===' and `===expect: <description>===' fence headers.
   The optional capture group holds the description, or NIL when absent.")

(defun parse-fence-header (line)
  "If LINE is a fence header line, return (values KIND DESCRIPTION-OR-NIL).
   Otherwise return (values NIL NIL).

   Recognised KINDs:
     :prose          for `===prose==='
     :code-eval      for `===eval==='
     :code-exercise  for `===exercise: <desc>==='
     :expect         for `===expect===' and `===expect: <desc>==='
                     (sentinel kind: not stored as a cell, used by the
                      state machine in parse-notebook-body to attach a
                      test-case to the pending exercise cell)

   DESCRIPTION is the captured description string, or NIL when no
   description is present in the header."
  (cond
    ((string= line "===prose===") (values :prose nil))
    ((string= line "===eval===")  (values :code-eval nil))
    (t
     (multiple-value-bind (m groups)
         (cl-ppcre:scan-to-strings +exercise-header-regex+ line)
       (when m
         (return-from parse-fence-header
           (values :code-exercise (aref groups 0)))))
     (multiple-value-bind (m groups)
         (cl-ppcre:scan-to-strings +expect-header-regex+ line)
       (when m
         (return-from parse-fence-header
           (values :expect (aref groups 0)))))
     (values nil nil))))

(defun parse-expect-block (body description)
  "Parse the buffered text BODY of a single `===expect===' block into a
   test-case struct.

   Two forms are supported:
     - input/output form: lines `input: <expr>' and `output: <value>'
       (in either order). When any `input:' line is present this form
       is used; the captured input/output strings are passed to
       MAKE-TEST-CASE as :input and :expected.
     - one-line form: a single non-empty trimmed line is treated as the
       expected output, with :input set to the empty string.

   DESCRIPTION is the description string carried on the test-case
   (typically NIL or empty when absent). When NIL, an empty string is
   stored on the struct."
  (let* ((trimmed (string-trim '(#\Space #\Tab #\Newline #\Return) body))
         (lines (remove-if (lambda (l) (zerop (length l)))
                           (split-lines trimmed)))
         (input-line (find-if (lambda (l)
                                (and (>= (length l) 6)
                                     (string= (subseq l 0 6) "input:")))
                              lines))
         (output-line (find-if (lambda (l)
                                 (and (>= (length l) 7)
                                      (string= (subseq l 0 7) "output:")))
                               lines))
         (desc (or description "")))
    (cond
      (input-line
       ;; input/output form: extract substrings after the prefix and trim.
       (let ((input (string-trim '(#\Space #\Tab)
                                 (subseq input-line 6)))
             (output (if output-line
                         (string-trim '(#\Space #\Tab)
                                      (subseq output-line 7))
                         "")))
         (make-test-case :input input
                         :expected output
                         :description desc)))
      (t
       ;; one-line form: treat the trimmed body as the expected output.
       (make-test-case :input ""
                       :expected trimmed
                       :description desc)))))

(defun parse-notebook-body (body-md &optional existing-cells)
  "Parse BODY-MD into (values CELLS ERRORS).

   BODY-MD is a string using `===KIND===' fence lines to delimit cells.
   Supported fences:
     ===prose===
     ===eval===
     ===exercise: <description>===
     ===expect===
     ===expect: <description>===

   Each parsed cell receives a fresh string UUID as its ID. EXISTING-CELLS
   is reserved for future stable-ID matching and is ignored at this stage.

   State machine:
     * CURRENT-KIND / CURRENT-DESC / CURRENT-BUFFER hold the cell that is
       currently being collected (prose, eval, or exercise body).
     * PENDING-EXERCISE-CELL is non-NIL while collecting test-cases for
       an exercise. When the exercise body is closed (by encountering an
       :expect header), the cell struct is constructed and held here so
       successive ===expect=== blocks can append test-cases.
     * IN-EXPECT-P + EXPECT-DESC + EXPECT-BUFFER track the currently
       collected expect block, finalised on the next non-expect header
       or EOF.

   Test-cases accumulate on PENDING-EXERCISE-CELL via APPEND so they are
   stored in source order. The exercise cell is flushed to CELLS only
   when the next non-expect header arrives (or EOF). Stray ===expect===
   blocks with no preceding exercise are silently ignored at this stage;
   validation is the responsibility of a later task."
  (declare (ignore existing-cells))
  (let ((errors '())
        (cells '())
        (current-kind nil)
        (current-desc nil)
        (current-buffer (make-array 0 :element-type 'character
                                      :fill-pointer 0 :adjustable t))
        (pending-exercise-cell nil)
        (in-expect-p nil)
        (expect-desc nil)
        (expect-buffer (make-array 0 :element-type 'character
                                     :fill-pointer 0 :adjustable t))
        (lines (split-lines body-md)))
    (labels ((buffer-string (buf)
               (string-trim '(#\Space #\Tab #\Newline #\Return)
                            (coerce buf 'string)))
             (append-line-to (buf line)
               (vector-push-extend #\Newline buf)
               (loop for c across line do (vector-push-extend c buf)))
             (finalise-expect ()
               ;; Convert the buffered expect block into a test-case and
               ;; append it to the pending exercise cell. Silently no-op
               ;; if there is no pending exercise (validation deferred).
               (when in-expect-p
                 (when pending-exercise-cell
                   (let ((tc (parse-expect-block
                              (coerce expect-buffer 'string)
                              expect-desc)))
                     (setf (cell-test-cases pending-exercise-cell)
                           (append (cell-test-cases pending-exercise-cell)
                                   (list tc)))))
                 (setf (fill-pointer expect-buffer) 0
                       expect-desc nil
                       in-expect-p nil)))
             (close-exercise-body ()
               ;; Convert the currently-collected exercise body+desc into
               ;; a struct held in pending-exercise-cell, ready to receive
               ;; test-cases from following ===expect=== blocks.
               (when (eq current-kind :code-exercise)
                 (setf pending-exercise-cell
                       (make-cell :id (princ-to-string (uuid:make-v4-uuid))
                                  :kind :code-exercise
                                  :body (buffer-string current-buffer)
                                  :description (or current-desc "")
                                  :test-cases nil))
                 (setf (fill-pointer current-buffer) 0
                       current-kind nil
                       current-desc nil)))
             (flush-pending-exercise ()
               (when pending-exercise-cell
                 (push pending-exercise-cell cells)
                 (setf pending-exercise-cell nil)))
             (flush-current ()
               ;; Flush a non-exercise cell (prose / eval) into CELLS.
               (when current-kind
                 (push (make-cell :id (princ-to-string (uuid:make-v4-uuid))
                                  :kind current-kind
                                  :body (buffer-string current-buffer)
                                  :description (or current-desc ""))
                       cells)
                 (setf (fill-pointer current-buffer) 0
                       current-kind nil
                       current-desc nil))))
      (dolist (line lines)
        (multiple-value-bind (kind desc) (parse-fence-header line)
          (cond
            ;; ===expect=== or ===expect: <desc>===
            ((eq kind :expect)
             ;; Closing expect of any in-progress expect block.
             (finalise-expect)
             ;; If we were collecting an exercise body, freeze it now.
             (when (eq current-kind :code-exercise)
               (close-exercise-body))
             ;; Begin a new expect block.
             (setf in-expect-p t
                   expect-desc desc
                   (fill-pointer expect-buffer) 0))
            ;; Any other recognised header.
            (kind
             ;; First close any open expect block.
             (finalise-expect)
             ;; Flush the pending exercise (with its accumulated tests).
             (flush-pending-exercise)
             ;; Flush any open prose/eval cell.
             (flush-current)
             (setf current-kind kind
                   current-desc desc))
            ;; Body line: append to the active buffer.
            (t
             (cond
               (in-expect-p
                (append-line-to expect-buffer line))
               (current-kind
                (append-line-to current-buffer line)))))))
      ;; EOF cleanup, in order: close expect, flush pending exercise,
      ;; flush plain cell.
      (finalise-expect)
      (flush-pending-exercise)
      (flush-current))
    (values (nreverse cells) (nreverse errors))))

(defun cells->body-md (cells)
  "Render CELLS list back into the canonical body-md string. Stub."
  (declare (ignore cells))
  (error "not implemented"))

(defun render-cell-prose-html (markdown-string)
  "Markdown -> sanitized HTML. Stub."
  (declare (ignore markdown-string))
  (error "not implemented"))
