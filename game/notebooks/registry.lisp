;;;; game/notebooks/registry.lisp --- List of all notebooks in display order.

(defpackage #:recurya/game/notebooks/registry
  (:use #:cl)
  (:import-from #:recurya/game/notebooks/sicp-1-1-1
                #:make-sicp-1-1-1-notebook)
  (:import-from #:recurya/game/notebooks/sicp-1-1-2
                #:make-sicp-1-1-2-notebook)
  (:import-from #:recurya/game/notebooks/sicp-1-1-3
                #:make-sicp-1-1-3-notebook)
  (:import-from #:recurya/game/notebooks/sicp-1-1-4
                #:make-sicp-1-1-4-notebook)
  (:import-from #:recurya/game/notebooks/sicp-1-1-5
                #:make-sicp-1-1-5-notebook)
  (:import-from #:recurya/game/notebooks/sicp-1-1-6
                #:make-sicp-1-1-6-notebook)
  (:import-from #:recurya/game/notebooks/sicp-1-1-7
                #:make-sicp-1-1-7-notebook)
  (:import-from #:recurya/game/notebooks/sicp-1-1-8
                #:make-sicp-1-1-8-notebook)
  (:import-from #:recurya/game/notebooks/sicp-1-2-1
                #:make-sicp-1-2-1-notebook)
  (:import-from #:recurya/game/notebooks/sicp-1-2-2
                #:make-sicp-1-2-2-notebook)
  (:import-from #:recurya/game/notebooks/sicp-1-2-3
                #:make-sicp-1-2-3-notebook)
  (:import-from #:recurya/game/notebooks/sicp-1-2-4
                #:make-sicp-1-2-4-notebook)
  (:import-from #:recurya/game/notebooks/sicp-1-2-5
                #:make-sicp-1-2-5-notebook)
  (:import-from #:recurya/game/notebooks/sicp-1-2-6
                #:make-sicp-1-2-6-notebook)
  (:import-from #:recurya/game/notebooks/sicp-1-3-1
                #:make-sicp-1-3-1-notebook)
  (:import-from #:recurya/game/notebooks/sicp-1-3-2
                #:make-sicp-1-3-2-notebook)
  (:import-from #:recurya/game/notebooks/sicp-1-3-3
                #:make-sicp-1-3-3-notebook)
  (:import-from #:recurya/game/notebooks/sicp-1-3-4
                #:make-sicp-1-3-4-notebook)
  (:import-from #:recurya/game/notebooks/sicp-2-1-1
                #:make-sicp-2-1-1-notebook)
  (:import-from #:recurya/game/notebooks/sicp-2-1-2
                #:make-sicp-2-1-2-notebook)
  (:import-from #:recurya/game/notebooks/sicp-2-1-3
                #:make-sicp-2-1-3-notebook)
  (:import-from #:recurya/game/notebooks/sicp-2-1-4
                #:make-sicp-2-1-4-notebook)
  (:import-from #:recurya/game/notebooks/sicp-2-2-1
                #:make-sicp-2-2-1-notebook)
  (:import-from #:recurya/game/notebooks/sicp-2-2-2
                #:make-sicp-2-2-2-notebook)
  (:import-from #:recurya/game/notebooks/sicp-2-2-3
                #:make-sicp-2-2-3-notebook)
  (:import-from #:recurya/game/notebooks/sicp-2-2-4
                #:make-sicp-2-2-4-notebook)
  (:import-from #:recurya/game/notebooks/sicp-2-3-1
                #:make-sicp-2-3-1-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-id)
  (:export #:all-notebooks #:get-notebook))

(in-package #:recurya/game/notebooks/registry)

(defparameter *notebooks*
  (list (make-sicp-1-1-1-notebook)
        (make-sicp-1-1-2-notebook)
        (make-sicp-1-1-3-notebook)
        (make-sicp-1-1-4-notebook)
        (make-sicp-1-1-5-notebook)
        (make-sicp-1-1-6-notebook)
        (make-sicp-1-1-7-notebook)
        (make-sicp-1-1-8-notebook)
        (make-sicp-1-2-1-notebook)
        (make-sicp-1-2-2-notebook)
        (make-sicp-1-2-3-notebook)
        (make-sicp-1-2-4-notebook)
        (make-sicp-1-2-5-notebook)
        (make-sicp-1-2-6-notebook)
        (make-sicp-1-3-1-notebook)
        (make-sicp-1-3-2-notebook)
        (make-sicp-1-3-3-notebook)
        (make-sicp-1-3-4-notebook)
        (make-sicp-2-1-1-notebook)
        (make-sicp-2-1-2-notebook)
        (make-sicp-2-1-3-notebook)
        (make-sicp-2-1-4-notebook)
        (make-sicp-2-2-1-notebook)
        (make-sicp-2-2-2-notebook)
        (make-sicp-2-2-3-notebook)
        (make-sicp-2-2-4-notebook)
        (make-sicp-2-3-1-notebook))
  "All available notebooks, in display order.")

(defun get-notebook (id)
  "Find notebook by keyword ID. Returns notebook struct or NIL."
  (find id *notebooks* :key #'notebook-id))

(defun all-notebooks ()
  "Return list of all notebooks in display order."
  *notebooks*)
