;;;; tests/web/learn-routes.lisp --- Tests for the legacy /wardlisp/learn/*
;;;; redirect handlers (Task 24).
;;;;
;;;; The original SICP-specific handlers (learn-home-handler,
;;;; notebook-page-handler, notebook-cell-run-handler, learn-sync-handler,
;;;; %maybe-persist-cell-run) have been removed. Their routes are now
;;;; permanent redirects to the public notebook (/n/:slug) and course
;;;; (/c/:slug) endpoints.
;;;;
;;;; learn-sync-handler itself was migrated verbatim to recurya/web/routes
;;;; and is now served at POST /learn/sync. Here we only validate the 308
;;;; redirect from the legacy URL — the moved handler shares its
;;;; implementation with the previous version, so no behavioral test is
;;;; duplicated.

(defpackage #:recurya/tests/web/learn-routes
  (:use #:cl
        #:rove)
  (:import-from #:recurya/web/routes
                #:sicp-learn-redirect-handler
                #:sicp-notebook-redirect-handler
                #:sicp-cell-run-redirect-handler
                #:learn-sync-redirect-handler))

(in-package #:recurya/tests/web/learn-routes)

;;; --- Response accessors (mirrors tests/web/routes.lisp) ---

(defun response-status (response)
  (first response))

(defun response-headers (response)
  (second response))

(defun header-value (response name)
  "Fetch a response header value by case-insensitive NAME (string).
   Headers are a plist of keywords on the raw response."
  (let ((target (string-upcase name)))
    (loop for (k v) on (response-headers response) by #'cddr
          when (and (keywordp k)
                    (string= target (string-upcase (symbol-name k))))
            return v)))

(defun response-location (response)
  (header-value response "location"))

;;; --- Param helpers ---

(defun path-params (&rest kv)
  "Build a path-param alist: (:id . \"sicp-1-1-1\") etc. KV is flat kw/val list."
  (loop for (k v) on kv by #'cddr
        collect (cons k v)))

;;; ---------------------------------------------------------------------------
;;; GET /wardlisp/learn -> 301 /c/sicp
;;; ---------------------------------------------------------------------------

(deftest sicp-old-routes-redirect-301
  (testing "GET /wardlisp/learn redirects 301 to /c/sicp"
    (let ((response (sicp-learn-redirect-handler nil)))
      (ok (= 301 (response-status response)))
      (ok (string= "/c/sicp" (response-location response))))))

;;; ---------------------------------------------------------------------------
;;; GET /wardlisp/learn/:id -> 301 /n/:id
;;; ---------------------------------------------------------------------------

(deftest sicp-notebook-redirect
  (testing "GET /wardlisp/learn/sicp-1-1-1 redirects 301 to /n/sicp-1-1-1"
    (let ((response (sicp-notebook-redirect-handler
                     (path-params :id "sicp-1-1-1"))))
      (ok (= 301 (response-status response)))
      (ok (string= "/n/sicp-1-1-1" (response-location response))))))

;;; ---------------------------------------------------------------------------
;;; POST /wardlisp/learn/:id/cells/:index/run -> 308 /n/:id/cells/:index/run
;;; ---------------------------------------------------------------------------

(deftest sicp-cell-run-redirect
  (testing "POST .../cells/0/run redirects 308 preserving method to new path"
    (let ((response (sicp-cell-run-redirect-handler
                     (path-params :id "sicp-1-1-1" :index "0"))))
      (ok (= 308 (response-status response)))
      (ok (string= "/n/sicp-1-1-1/cells/0/run"
                   (response-location response))))))

;;; ---------------------------------------------------------------------------
;;; POST /wardlisp/learn/sync -> 308 /learn/sync
;;; ---------------------------------------------------------------------------

(deftest learn-sync-redirect
  (testing "POST /wardlisp/learn/sync redirects 308 to /learn/sync"
    (let ((response (learn-sync-redirect-handler nil)))
      (ok (= 308 (response-status response)))
      (ok (string= "/learn/sync" (response-location response))))))
