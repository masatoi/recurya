;;;; cli/workspace.lisp --- Local layout of a pulled notebook.
;;;;
;;;; A pulled notebook is a directory with README.md (prose, exercise
;;;; descriptions and tests), one NN-<kind>.wl file per code cell, and
;;;; .recurya/notebook.json, the manifest recording each cell's file and the
;;;; hash of what was last written there.  Everything here is pure except
;;;; the callers' file reads and writes; notebooks and manifests are jzon
;;;; objects (EQUAL hash tables with string keys).

(defpackage #:recurya/cli/workspace
  (:use #:cl)
  (:import-from #:ironclad
                #:digest-sequence
                #:byte-array-to-hex-string)
  (:import-from #:babel
                #:string-to-octets)
  ;; Bare import: declares the jzon dependency for package-inferred loading.
  (:import-from #:com.inuoe.jzon)
  (:export #:index-width
           #:cell-file-name
           #:initial-code
           #:content-hash
           #:render-readme
           #:plan-pull
           #:manifest-cells
           #:manifest-cell
           #:collect-codes
           #:resolve-cell-arg
           #:manifest->json
           #:json->manifest
           #:workspace-error
           #:workspace-error-message))

(in-package #:recurya/cli/workspace)

(define-condition workspace-error (error)
  ((message :initarg :message :reader workspace-error-message))
  (:report (lambda (c stream) (write-string (workspace-error-message c) stream))))

(defun workspace-error (control &rest args)
  "Signal a WORKSPACE-ERROR with a message formatted from CONTROL and ARGS."
  (error 'workspace-error :message (apply #'format nil control args)))

(defun jobj (&rest keys-and-values)
  "A JSON object from alternating string keys and values."
  (let ((h (make-hash-table :test 'equal)))
    (loop for (k v) on keys-and-values by #'cddr
          do (setf (gethash k h) v))
    h))

(defun jstring (value)
  "VALUE when it is a string, else NIL (JSON null and absent read as NIL)."
  (and (stringp value) value))

(defun index-width (n-cells)
  "Digits used to number files in a notebook of N-CELLS cells (at least 2)."
  (max 2 (length (princ-to-string (max 0 (1- n-cells))))))

(defun kind-suffix (kind)
  "File-name suffix of a cell KIND that gets a code file, or NIL."
  (cond ((string= kind "code-eval") "eval")
        ((string= kind "code-exercise") "exercise")
        ((string= kind "code-solution") "solution")
        (t nil)))

(defun cell-file-name (index kind width)
  "File name of the code cell at INDEX of KIND (\"03-exercise.wl\"), or NIL
for cells without a code file (prose, scene)."
  (let ((suffix (kind-suffix kind)))
    (and suffix (format nil "~v,'0D-~A.wl" width index suffix))))

(defun initial-code (cell)
  "What a fresh pull writes for CELL: the reader's saved code, else the body."
  (or (jstring (gethash "saved_code" cell))
      (jstring (gethash "body" cell))
      ""))

(defun content-hash (string)
  "SHA-256 of STRING's UTF-8 octets as lower-case hex."
  (byte-array-to-hex-string
   (digest-sequence :sha256 (string-to-octets string :encoding :utf-8))))

(defun cells-of (notebook)
  "NOTEBOOK's cells as a list."
  (coerce (gethash "cells" notebook) 'list))

(defun cell-file (cell width)
  "The file CELL is written to, or NIL (prose, scene, locked solution)."
  (let ((kind (gethash "kind" cell)))
    (and (or (string/= kind "code-solution") (eq (gethash "unlocked" cell) t))
         (cell-file-name (gethash "index" cell) kind width))))

(defun render-readme (notebook width)
  "README.md for NOTEBOOK: its prose, exercise descriptions and tests, and a
pointer to the file of each code cell, in cell order."
  (with-output-to-string (s)
    (format s "# ~A~%~%" (gethash "title" notebook))
    (let ((summary (jstring (gethash "summary" notebook))))
      (when (and summary (plusp (length summary)))
        (format s "~A~%~%" summary)))
    (dolist (cell (cells-of notebook))
      (let* ((index (gethash "index" cell))
             (kind (gethash "kind" cell))
             (file (cell-file cell width))
             (label (format nil "~v,'0D" width index)))
        (cond
          ((string= kind "prose")
           (format s "~A~%~%" (or (jstring (gethash "body" cell)) "")))
          ((string= kind "code-exercise")
           (format s "## [~A] Exercise~%~%" label)
           (let ((desc (jstring (gethash "description" cell))))
             (when (and desc (plusp (length desc)))
               (format s "~A~%~%" desc)))
           (let ((tests (coerce (gethash "test_cases" cell) 'list)))
             (when tests
               (format s "Tests:~%~%")
               (dolist (tc tests)
                 (format s "- `~A` => `~A`~%" (gethash "input" tc) (gethash "expected" tc)))
               (terpri s)))
           (format s "→ `~A` (run: `recurya run ~A`)~%~%" file label))
          ((string= kind "code-eval")
           (format s "→ `~A` (run: `recurya run ~A`)~%~%" file label))
          ((string= kind "code-solution")
           (if file
               (format s "→ `~A` (solution)~%~%" file)
               (format s "_[~A] Solution locked — pass the exercise above to unlock it._~%~%"
                       label)))
          (t
           (format s "_[~A] ~A cell — not supported by the CLI; open it in the browser._~%~%"
                   label kind)))))))

(defun old-hash (old-manifest file)
  "The hash OLD-MANIFEST recorded for FILE, or NIL."
  (when old-manifest
    (loop for cell in (manifest-cells old-manifest)
          when (equal (jstring (gethash "file" cell)) file)
            do (return (jstring (gethash "hash" cell))))))

(defun plan-pull (notebook width old-manifest existing force)
  "Decide what pulling NOTEBOOK writes.  EXISTING is an alist of
(file . current content) for the code files already on disk.  A file is
written when it is absent, already equal to the new content, unchanged since
the last pull (its content hash equals OLD-MANIFEST's), or when FORCE;
otherwise it is kept.
Returns (VALUES ACTIONS MANIFEST): ACTIONS is a list of (:WRITE FILE CONTENT)
and (:KEEP FILE); MANIFEST is the new manifest (without \"server\")."
  (let ((actions '())
        (cells '()))
    (dolist (cell (cells-of notebook))
      (let* ((file (cell-file cell width))
             (content (and file (initial-code cell)))
             (current (and file (assoc file existing :test #'string=)))
             (hash nil))
        (when file
          (cond
            ((or (null current)
                 force
                 (string= (cdr current) content)
                 (equal (content-hash (cdr current)) (old-hash old-manifest file)))
             (push (list :write file content) actions)
             (setf hash (content-hash content)))
            (t
             (push (list :keep file) actions)
             (setf hash (old-hash old-manifest file)))))
        (push (jobj "index" (gethash "index" cell)
                    "cell_id" (gethash "cell_id" cell)
                    "kind" (gethash "kind" cell)
                    "file" (or file 'null)
                    "hash" (or hash 'null)
                    "passed" (eq (gethash "passed" cell) t)
                    "unlocked" (eq (gethash "unlocked" cell) t))
              cells)))
    (values (nreverse actions)
            (jobj "handle" (gethash "handle" notebook)
                  "slug" (gethash "slug" notebook)
                  "title" (gethash "title" notebook)
                  "width" width
                  "cells" (coerce (nreverse cells) 'vector)))))

(defun manifest-cells (manifest)
  "MANIFEST's cell entries as a list."
  (coerce (gethash "cells" manifest) 'list))

(defun manifest-cell (manifest index)
  "MANIFEST's entry for cell INDEX, or NIL."
  (find index (manifest-cells manifest) :key (lambda (c) (gethash "index" c))))

(defun collect-codes (manifest index read-file)
  "The codes of cells 0..INDEX to submit: an eval or exercise cell sends the
content of its file (READ-FILE returns it, or NIL when missing); every other
cell, and a missing file, sends \"\", as the browser does."
  (loop for i from 0 to index
        for cell = (manifest-cell manifest i)
        collect (let ((file (and cell (jstring (gethash "file" cell))))
                      (kind (and cell (gethash "kind" cell))))
                  (or (and file
                           (member kind '("code-eval" "code-exercise") :test #'string=)
                           (funcall read-file file))
                      ""))))

(defun resolve-cell-arg (arg manifest)
  "The index of the runnable cell named by ARG: \"03\", \"3\" or a file name
such as \"03-exercise.wl\".  Signals WORKSPACE-ERROR when ARG names no cell or
a cell that cannot be run."
  (let* ((digits (subseq arg 0 (or (position-if-not #'digit-char-p arg) (length arg))))
         (index (and (plusp (length digits)) (parse-integer digits)))
         (cell (and index (manifest-cell manifest index))))
    (cond
      ((null index) (workspace-error "Not a cell number or file: ~A" arg))
      ((null cell) (workspace-error "No cell ~A in this notebook" arg))
      ((not (member (gethash "kind" cell) '("code-eval" "code-exercise") :test #'string=))
       (workspace-error "Cell ~A is a ~A cell and cannot be run" arg (gethash "kind" cell)))
      (t index))))

(defun manifest->json (manifest)
  "MANIFEST as pretty-printed JSON text."
  (com.inuoe.jzon:stringify manifest :pretty t))

(defun json->manifest (text)
  "Parse manifest TEXT.  Signals WORKSPACE-ERROR when it is not a JSON object."
  (let ((data (handler-case (com.inuoe.jzon:parse text) (error () nil))))
    (unless (hash-table-p data)
      (workspace-error "Corrupt manifest .recurya/notebook.json"))
    data))
