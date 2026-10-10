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
                #:cell-view)
  (:import-from #:recurya/game/notebook-parser
                #:parse-notebook-body
                #:cells->body-md
                ;; Internal helper under contract.
                #:parse-fence-header))
(in-package #:recurya/specs/game/notebook-parser)

(defparameter *fence-shape* "^===.+===$"
  "Regex every fence header line matches (+GENERIC-HEADER-REGEX+'s pattern).")

(defun fence-shaped-p (line)
  "True when LINE has the ===...=== shape of a fence header."
  (and (cl-ppcre:scan *fence-shape* line) t))

(defun locked-solution-line-p (line)
  "True when LINE starts with the ===solution-locked: header prefix."
  (eql 0 (search "===solution-locked: " line)))

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
  "A line without the ===...=== shape is never a header.  A header's kind is a
fence kind; only ===solution-locked: ...=== is gated, and a line that is not
recognised carries no description or gate."
  (:args (line fence-line))
  (:cases
    (:not-fence-shaped
      (:when (not (fence-shaped-p line)))
      (:returns (values null null null)))
    (:fence-shaped
      (:when (fence-shaped-p line))
      (:returns (values (or null fence-kind) (or null string) t))
      (:post-values (kind description gated-p)
        (and (if gated-p (eq kind :code-solution) t)
             (if (null kind) (and (null description) (null gated-p)) t)
             (eq (and gated-p t) (locked-solution-line-p line)))))))

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
  "One render/parse round normalizes any cells; a second round changes
nothing, and every parsed cell has a notebook cell kind."
  (:about cells->body-md)
  (:kind :idempotence)
  (:trials (:smoke 50 :normal 300))
  (let* ((once (round-trip cells))
         (twice (round-trip once)))
    (and (equal (mapcar #'cell-view once) (mapcar #'cell-view twice))
         (every (lambda (cell)
                  (validp 'notebook-cell-kind (first (cell-view cell))))
                once))))
