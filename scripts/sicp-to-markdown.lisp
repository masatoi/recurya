;;;; scripts/sicp-to-markdown.lisp --- Export SICP notebooks to markdown fixtures.
;;;;
;;;; Usage (from the REPL after loading recurya):
;;;;   (load "scripts/sicp-to-markdown.lisp")
;;;;   (scripts/sicp-to-markdown:export-all-sicp-to-markdown!)
;;;;
;;;; Generates one markdown file per notebook under docs/sicp/, where each
;;;; cell is fenced with the same `===KIND===' headers used by
;;;; recurya/game/notebook-parser:parse-notebook-body. Prose bodies (which
;;;; live in the source as Spinneret DSL trees) are converted to plain
;;;; Markdown by SPINNERET-TREE->MARKDOWN.

(defpackage #:scripts/sicp-to-markdown
  (:use #:cl)
  (:import-from #:recurya/game/notebook
                #:notebook-id
                #:notebook-cells
                #:cell-kind
                #:cell-body
                #:cell-description
                #:cell-test-cases)
  (:import-from #:recurya/game/puzzle
                #:test-case-input
                #:test-case-expected
                #:test-case-description)
  (:import-from #:recurya/game/notebooks/registry
                #:all-notebooks)
  (:export #:spinneret-tree->markdown
           #:cell->markdown
           #:notebook->markdown
           #:export-all-sicp-to-markdown!
           #:flatten-description))

(in-package #:scripts/sicp-to-markdown)

;;; ---------------------------------------------------------------------------
;;; Spinneret DSL tree -> markdown
;;; ---------------------------------------------------------------------------

(defun keyword-attr-p (x)
  "Return T when X is a Spinneret attribute keyword (e.g. :HREF, :CLASS).
   Tag keywords (:P, :STRONG, ...) only ever appear in the head position
   of a node, never in the children list, so any keyword we encounter
   while walking children must be an attribute marker."
  (keywordp x))

(defun strip-attribute-pairs (children)
  "Drop leading :KEY VALUE pairs from CHILDREN, returning the remaining
   children list. Spinneret attribute syntax: (:tag :class \"x\" \"text\")."
  (loop with rest = children
        while (and rest (keyword-attr-p (car rest)))
        do (setf rest (cddr rest))
        finally (return rest)))

(defun collect-attributes (children)
  "Return (values ATTRS-PLIST CONTENT-CHILDREN) by peeling leading
   :KEY VALUE attribute pairs."
  (let ((plist 'nil)
        (rest children))
    (loop while (and rest (keyword-attr-p (car rest)))
          do (let ((k (car rest))
                   (v (cadr rest)))
               (push v plist)
               (push k plist)
               (setf rest (cddr rest))))
    (values plist rest)))

(defun children->md (children)
  "Render a list of child nodes (strings and (TAG ...) sublists) into a
   single concatenated markdown string. Pure Spinneret keyword attributes
   (:HREF, :CLASS, ...) on the leading position of children are stripped."
  (with-output-to-string (s)
    (dolist (child (strip-attribute-pairs children))
      (write-string (node->md child) s))))

(defun node->md (node)
  "Render a single node (string or list-form) to markdown."
  (cond
    ((stringp node) node)
    ((null node) "")
    ((and (consp node) (keywordp (car node)))
     (let* ((tag (car node))
            (rest (cdr node)))
       (multiple-value-bind (attrs content)
           (collect-attributes rest)
         (tag->md tag attrs content))))
    (t (error "Unexpected SICP prose node: ~S" node))))

(defun li-children (children)
  "Return the (:LI ...) sub-lists from CHILDREN, ignoring whitespace
   strings between them."
  (remove-if-not (lambda (c) (and (consp c) (eq (car c) :li)))
                 (strip-attribute-pairs children)))

(defun tag->md (tag attrs children)
  "Convert a single Spinneret form (:TAG attrs... children...) to
   markdown.  ATTRS is the collected attribute plist (currently only
   used for :A href).  CHILDREN excludes attribute pairs already."
  (declare (ignorable attrs))
  (case tag
    (:p (format nil "~A~%~%" (children->md children)))
    (:strong (format nil "**~A**" (children->md children)))
    (:em (format nil "*~A*" (children->md children)))
    (:code (format nil "`~A`" (children->md children)))
    (:pre (format nil "```~%~A~%```~%~%" (children->md children)))
    (:blockquote (format nil "> ~A~%~%" (children->md children)))
    (:div (children->md children))
    (:ul
     (with-output-to-string (s)
       (dolist (li (li-children children))
         (format s "- ~A~%" (children->md (cdr li))))
       (write-char #\Newline s)))
    (:ol
     (with-output-to-string (s)
       (loop for li in (li-children children)
             for i from 1
             do (format s "~D. ~A~%" i (children->md (cdr li))))
       (write-char #\Newline s)))
    (:li (children->md children))
    (:br (format nil "  ~%"))
    (:hr "---~%~%")
    (:a
     ;; Not present in the corpus today, but be lenient.
     (let ((href (getf attrs :href "")))
       (format nil "[~A](~A)" (children->md children) href)))
    (otherwise
     (error "Unknown tag in SICP prose: ~A" tag))))

(defun spinneret-tree->markdown (tree)
  "Convert a single Spinneret DSL tree to markdown text. The trailing
   whitespace produced by block-level elements is trimmed so the caller
   can join cell bodies cleanly."
  (string-trim '(#\Newline #\Space #\Tab #\Return)
               (node->md tree)))

;;; ---------------------------------------------------------------------------
;;; Cell -> markdown
;;; ---------------------------------------------------------------------------

(defun flatten-description (s)
  "Collapse internal newlines in a fence description to single spaces.
   The `===kind: <desc>===' grammar in notebook-parser is line-based, so
   any embedded newline would split the header. Multiple consecutive
   whitespace characters collapse to one."
  (cond
    ((null s) "")
    ((zerop (length s)) "")
    (t
     (let* ((replaced
             (with-output-to-string (out)
               (loop for c across s
                     do (write-char (if (or (char= c #\Newline)
                                            (char= c #\Return)
                                            (char= c #\Tab))
                                        #\Space
                                        c)
                                    out))))
            (collapsed (cl-ppcre:regex-replace-all "[ ]{2,}" replaced " ")))
       (string-trim '(#\Space) collapsed)))))

(defun render-test-case-block (tc)
  "Render a single TEST-CASE TC as a `===expect[: <desc>]===' block."
  (let* ((desc (flatten-description (test-case-description tc)))
         (input (or (test-case-input tc) ""))
         (expected (or (test-case-expected tc) ""))
         (header (if (zerop (length desc))
                     "===expect==="
                     (format nil "===expect: ~A===" desc))))
    (cond
      ((plusp (length input))
       (format nil "~A~%input: ~A~%output: ~A" header input expected))
      (t
       (format nil "~A~%~A" header expected)))))

(defun cell->markdown (cell)
  "Render one CELL as a fenced markdown block.  No trailing newline.

   Cell descriptions are flattened to a single line so the resulting
   `===exercise: <desc>===' header survives PARSE-NOTEBOOK-BODY (the
   grammar is line-based)."
  (let ((kind (cell-kind cell))
        (body (cell-body cell))
        (desc (flatten-description (cell-description cell))))
    (ecase kind
      (:prose
       (format nil "===prose===~%~A"
               (spinneret-tree->markdown body)))
      (:code-eval
       (format nil "===eval===~%~A" (or body "")))
      (:code-exercise
       (with-output-to-string (s)
         (format s "===exercise: ~A===~%~A" desc (or body ""))
         (dolist (tc (cell-test-cases cell))
           (format s "~%~%~A" (render-test-case-block tc))))))))

(defun notebook->markdown (nb)
  "Render NB to a single markdown string. Cells are separated by exactly
   one blank line; no trailing newline is emitted."
  (format nil "~{~A~^~%~%~}"
          (mapcar #'cell->markdown (notebook-cells nb))))

;;; ---------------------------------------------------------------------------
;;; Top-level driver
;;; ---------------------------------------------------------------------------

(defun notebook-id->slug (id)
  "Convert a notebook id (keyword or string) to a kebab-case file slug."
  (cond
    ((keywordp id) (string-downcase (symbol-name id)))
    ((stringp id) (string-downcase id))
    (t (error "Unsupported notebook id: ~S" id))))

(defun export-notebook-to-markdown! (nb output-dir)
  "Write NB to <output-dir>/<id>.md.  Returns the absolute pathname."
  (let* ((slug (notebook-id->slug (notebook-id nb)))
         (path (merge-pathnames (format nil "~A.md" slug) output-dir)))
    (with-open-file (s path :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create)
      (write-string (notebook->markdown nb) s)
      (write-char #\Newline s))
    path))

(defun export-all-sicp-to-markdown! (&optional (output-dir #P"docs/sicp/"))
  "Export every notebook returned by ALL-NOTEBOOKS to a markdown file
   under OUTPUT-DIR. Returns the list of written pathnames."
  (ensure-directories-exist output-dir)
  (let ((written 'nil))
    (dolist (nb (all-notebooks))
      (push (export-notebook-to-markdown! nb output-dir) written))
    (nreverse written)))
