;;;; tests/main.lisp --- Smoke test for the production executable entry point.
;;;; Importing the exported symbols forces recurya/main to load as a
;;;; dependency; if they are missing/unexported the test system fails to load
;;;; (a valid red state before main.lisp exists).
(defpackage #:recurya/tests/main
  (:use #:cl #:rove)
  (:import-from #:recurya/main
                #:recurya-main
                #:boot!))
(in-package #:recurya/tests/main)

(deftest production-entry-points-exist
  (testing "recurya/main exposes callable boot + toplevel entry points"
    (ok (fboundp 'recurya-main))
    (ok (fboundp 'boot!))))
