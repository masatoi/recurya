;;;; game/notebooks/registry.lisp --- List of all notebooks in display order.

(defpackage #:recurya/game/notebooks/registry
  (:use #:cl)
  (:import-from #:recurya/game/notebooks/sicp-1-1-1
                #:make-sicp-1-1-1-notebook)
  (:import-from #:recurya/game/notebook
                #:notebook-id)
  (:export #:all-notebooks #:get-notebook))

(in-package #:recurya/game/notebooks/registry)

(defparameter *notebooks*
  (list (make-sicp-1-1-1-notebook))
  "All available notebooks, in display order.")

(defun get-notebook (id)
  "Find notebook by keyword ID. Returns notebook struct or NIL."
  (find id *notebooks* :key #'notebook-id))

(defun all-notebooks ()
  "Return list of all notebooks in display order."
  *notebooks*)
