;;;; specs/game/notebook-parser.lisp --- cl-spec contracts for the notebook parser.
;;;;
;;;; PARSE-FENCE-HEADER's classification, and the render/parse round trip
;;;; that CELLS->BODY-MD's docstring promises for canonical cells.

(defpackage #:recurya/specs/game/notebook-parser
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defspec-function
                #:defproperty
                #:defgenerator
                #:validp)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/specs/domain
                #:notebook-cell-kind
                #:fence-kind)
  (:import-from #:recurya/specs/game/notebook
                #:canonical-cells
                #:loose-cells
                #:cell-view
                #:trimmed-cell-view)
  (:import-from #:cl-ppcre
                #:scan)
  (:import-from #:recurya/game/notebook-parser
                #:parse-notebook-body
                #:cells->body-md
                ;; Internal helper under contract.
                #:parse-fence-header))
(in-package #:recurya/specs/game/notebook-parser)

(defparameter *fence-shape* "^===.+===$"
  "Regex for a line that looks like a fence header.  The requirement comes from
PARSE-NOTEBOOK-BODY's docstring (\"Unknown fence header (anything that looks
like `===...===')\"); +GENERIC-HEADER-REGEX+ implements the same definition.")

(defun fence-shaped-p (line)
  "True when LINE has the ===...=== shape of a fence header."
  (and (scan *fence-shape* line) t))

(defparameter *exact-headers*
  '(("===prose===" . :prose)
    ("===eval===" . :code-eval)
    ("===scene===" . :scene)
    ("===exercise===" . :code-exercise)
    ("===code===" . :code-delim)
    ("===expect===" . :expect))
  "Headers with no description, and the kind PARSE-FENCE-HEADER documents.")

(defparameter *described-headers*
  '(("===exercise: " :code-exercise nil t)
    ("===solution: " :code-solution nil nil)
    ("===solution-locked: " :code-solution t nil)
    ("===expect: " :expect nil t))
  "Described headers as (PREFIX KIND GATED-P DESCRIPTION-REQUIRED-P).")

(defun expected-header (line)
  "The documented (KIND DESCRIPTION GATED-P) for the fence-shaped LINE.
The description is everything between the prefix and the final ===."
  (let ((exact (assoc line *exact-headers* :test #'string=)))
    (if exact
        (list (cdr exact) nil nil)
        (dolist (entry *described-headers* (list nil nil nil))
          (destructuring-bind (prefix kind gated required) entry
            (when (and (eql 0 (search prefix line))
                       (>= (length line) (+ (length prefix) 3)))
              (let ((description (subseq line (length prefix) (- (length line) 3))))
                (return
                  (if (and required (zerop (length description)))
                      (list nil nil nil)
                      (list kind description gated))))))))))

(defun random-element (sequence)
  "Return a uniformly chosen element of the non-empty SEQUENCE."
  (elt sequence (random (length sequence))))

(defgenerator fence-line ()
  "Exact headers, described headers, near-miss shapes and plain text, about a
quarter each."
  (let ((text (random-element '("" "desc" "a b" "x===y" "λ"))))
    (case (random 4)
      (0 (random-element '("===prose===" "===eval===" "===scene==="
                           "===exercise===" "===code===" "===expect===")))
      (1 (format nil "===~A: ~A==="
                 (random-element '("exercise" "solution" "solution-locked" "expect"))
                 text))
      (2 (format nil "~A===~A===~A"
                 (random-element '("" " " "x"))
                 (random-element '("prose" "foo" "" "eval "))
                 (random-element '("" " " "="))))
      (t text))))

(defspec fence-line string (:generator fence-line))

(defspec-function parse-fence-header
  "A line without the ===...=== shape is never a header.  Exact headers map to
their documented kind with no description; described headers carry the text
between their prefix and the final === as description, with only
===solution-locked: ...=== gated.  Exercise and expect headers need a
non-empty description; anything else is not recognised."
  (:args (line fence-line))
  (:cases
    (:not-fence-shaped
      (:when (not (fence-shaped-p line)))
      (:returns (values null null null)))
    (:fence-shaped
      (:when (fence-shaped-p line))
      (:returns (values (or null fence-kind) (or null string) boolean))
      (:post-values (kind description gated-p)
        (equal (list kind description gated-p)
               (expected-header line))))))

(defun round-trip (cells)
  "Render CELLS and parse the result.  Return (VALUES CELLS ERRORS)."
  (parse-notebook-body (cells->body-md cells)))

(defproperty notebook-roundtrip ((cells canonical-cells))
  "Rendering canonical cells and parsing the result gives back the same cells
(kind, body, description, test cases, gate) with no parse errors."
  (:about cells->body-md)
  (:kind :roundtrip)
  (:trials (:smoke 50 :normal 300))
  (multiple-value-bind (parsed errors) (round-trip cells)
    (and (null errors)
         (equal (mapcar #'cell-view parsed) (mapcar #'cell-view cells)))))

(defproperty notebook-roundtrip-idempotent ((cells loose-cells))
  "One render/parse round turns cells whose bodies carry outer whitespace into
their canonical form (the same cells with bodies trimmed), without parse
errors; a second round changes nothing, and every parsed cell has a notebook
cell kind."
  (:about cells->body-md)
  (:kind :idempotence)
  (:trials (:smoke 50 :normal 300))
  (multiple-value-bind (once errors) (round-trip cells)
    (multiple-value-bind (twice errors-2) (round-trip once)
      (and (null errors)
           (null errors-2)
           (equal (mapcar #'cell-view once) (mapcar #'trimmed-cell-view cells))
           (equal (mapcar #'cell-view once) (mapcar #'cell-view twice))
           (every (lambda (cell)
                    (validp 'notebook-cell-kind (first (cell-view cell))))
                  once)))))

(defproperty body-md-cell-separator ((cells canonical-cells))
  "CELLS->BODY-MD separates cells by exactly one blank line and emits no
leading or trailing newline: the whole rendering is the single-cell renderings
joined by one blank line, and each of those starts and ends with a non-newline."
  (:about cells->body-md)
  (:kind :invariant)
  (:trials (:smoke 50 :normal 300))
  (let ((singles (mapcar (lambda (cell) (cells->body-md (list cell))) cells)))
    (and (equal (cells->body-md cells) (format nil "~{~A~^~%~%~}" singles))
         (every (lambda (single)
                  (and (plusp (length single))
                       (char/= (char single 0) #\Newline)
                       (char/= (char single (1- (length single))) #\Newline)))
                singles))))
