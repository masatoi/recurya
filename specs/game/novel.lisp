;;;; specs/game/novel.lisp --- cl-spec contracts for novel flags (pure).
;;;;
;;;; The flag-value domain (values a novel flag can hold and carry to the next
;;;; scene) and the set-flag check in INTERPRET-DIRECTIVES.  Design doc:
;;;; docs/superpowers/specs/2026-10-11-cl-spec-db-rest-design.md

(defpackage #:recurya/specs/game/novel
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defspec-function
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/specs/db/domain
                #:random-element)
  (:import-from #:recurya/game/novel/interpreter
                #:interpret-directives
                #:invalid-flag-error)
  (:export #:*flag-names*
           #:storable-flag-value-p
           #:random-flag-value
           #:random-flags
           #:flag-value))
(in-package #:recurya/specs/game/novel)

(defparameter *flag-names* #(:met-alice :mood :count :flag-a :flag-b :flag-c)
  "Flag names as the scene evaluator makes them: upper-case keywords from
wardlisp symbols.  None names a wardlisp builtin, so each can be bound.")

(defparameter *symbol-values* #(:happy :sad :sym-x :ready-for-exercise)
  "Symbol flag values (keywords), named unlike t and nil.")

(defparameter *flag-strings*
  (vector "" "hi" "ラムダ λ" "say \"hi\"" "back\\slash" (format nil "two~%lines") "HAPPY")
  "String flag values: empty, non-ASCII, quotes, backslash, newline, and one
spelled like a symbol value's stored name.")

(defun storable-flag-value-p (value)
  "The design's flag-value domain: T, NIL, an integer, a string or a keyword."
  (or (eq value t) (null value) (integerp value) (stringp value) (keywordp value)))

(defun random-flag-value ()
  "A value in the flag-value domain."
  (case (random 5)
    (0 t)
    (1 nil)
    (2 (- (random 2001) 1000))
    (3 (random-element *flag-strings*))
    (t (random-element *symbol-values*))))

(defgenerator flag-value ()
  "A value in the flag-value domain."
  (random-flag-value))

(defspec flag-value (satisfies storable-flag-value-p) (:generator flag-value))

(defun random-flags (min max)
  "An alist of MIN..MAX (at most 6) flags with distinct names from
*FLAG-NAMES* and values in the flag-value domain."
  (let ((names (coerce *flag-names* 'list)))
    (loop repeat (+ min (random (1+ (- max min))))
          collect (let ((name (random-element names)))
                    (setf names (remove name names))
                    (cons name (random-flag-value))))))

(defparameter *bad-flag-names* (vector "mood" 3 nil)
  "Set-flag names that are not keywords.")

(defparameter *bad-flag-values* (vector (list 1 2) (list :a "b") 1.5 (vector 1 2))
  "Set-flag values outside the flag-value domain.")

(defun random-set-flag ()
  "A set-flag directive: usually a keyword name with an omitted or storable
value; sometimes a non-keyword name or a value outside the domain."
  (let ((name (if (zerop (random 12))
                  (random-element *bad-flag-names*)
                  (random-element *flag-names*))))
    (case (random 10)
      ((0 1 2) (list :set-flag name))
      (3 (list :set-flag name (random-element *bad-flag-values*)))
      (t (list :set-flag name (random-flag-value))))))

(defun random-directive ()
  "A say, narrate, bg or set-flag directive."
  (case (random 6)
    (0 (list :say "アリス" (random-element *flag-strings*)))
    (1 (list :narrate "text"))
    (2 (list :bg "room"))
    (t (random-set-flag))))

(defgenerator directive-list ()
  "0-6 directives; a third of the time the tail is wrapped in a (:scene ...)
group."
  (let ((dirs (loop repeat (random 7) collect (random-directive))))
    (if (and dirs (zerop (random 3)))
        (let ((k (random (1+ (length dirs)))))
          (append (subseq dirs 0 k) (list (cons :scene (subseq dirs k)))))
        dirs)))

(defspec directive-list list (:generator directive-list))

(defun set-flag-forms (directives)
  "The set-flag directives of DIRECTIVES in order, looking inside :scene groups."
  (loop for d in directives
        append (case (first d)
                 (:scene (set-flag-forms (rest d)))
                 (:set-flag (list d)))))

(defun beat-count (directives)
  "The number of say and narrate directives in DIRECTIVES, :scene groups included."
  (loop for d in directives
        sum (case (first d)
              (:scene (beat-count (rest d)))
              ((:say :narrate) 1)
              (t 0))))

(defun valid-set-flag-p (directive)
  "True when DIRECTIVE, a set-flag, has a keyword name and an omitted or
storable value."
  (and (keywordp (second directive))
       (or (null (cddr directive))
           (storable-flag-value-p (third directive)))))

(defspec-function interpret-directives
  "Set-flags with a keyword name and an omitted or storable value are
collected in order as (NAME . VALUE), an omitted value as T, and every say and
narrate becomes a beat; any other set-flag signals INVALID-FLAG-ERROR."
  (:args (directives directive-list))
  (:cases
    (:valid
      (:when (every #'valid-set-flag-p (set-flag-forms directives)))
      (:returns (values list list))
      (:post-values (beats set-flags)
        (and (= (length beats) (beat-count directives))
             (equal set-flags
                    (mapcar (lambda (d) (cons (second d) (if (cddr d) (third d) t)))
                            (set-flag-forms directives))))))
    (:invalid
      (:when (notevery #'valid-set-flag-p (set-flag-forms directives)))
      (:signals (type invalid-flag-error)))))
