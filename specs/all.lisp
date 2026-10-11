;;;; specs/all.lisp --- Load every Recurya cl-spec contract file.
;;;;
;;;; An umbrella with no code of its own: each :IMPORT-FROM pulls in one
;;;; contract file so `load-system recurya/specs/all' registers them all.
;;;; The production system never depends on this.

(defpackage #:recurya/specs/all
  (:use #:cl)
  ;; Every new contract file must be imported here AND its property and
  ;; function spec names added to *EXPECTED-PROPERTIES* /
  ;; *EXPECTED-FUNCTION-SPECS* in tests/specs/contracts.lisp; otherwise the
  ;; harness never loads it, or cannot tell that it went missing.
  (:import-from #:recurya/specs/domain)
  (:import-from #:recurya/specs/game/arena)
  (:import-from #:recurya/specs/game/notebook-parser)
  (:import-from #:recurya/specs/game/notebook-jsonb)
  (:import-from #:recurya/specs/db/domain)
  (:import-from #:recurya/specs/db/core)
  (:import-from #:recurya/specs/db/course-notebooks)
  (:import-from #:recurya/specs/db/learn)
  (:import-from #:recurya/specs/db/notebooks))

(in-package #:recurya/specs/all)
