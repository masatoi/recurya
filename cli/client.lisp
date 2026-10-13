;;;; cli/client.lisp --- HTTP calls to the Recurya JSON API.

(defpackage #:recurya/cli/client
  (:use #:cl)
  ;; Bare imports: declare the packages used through qualified names.
  (:import-from #:dexador)
  (:import-from #:com.inuoe.jzon)
  (:import-from #:babel)
  (:export #:api-error
           #:api-error-status
           #:api-error-code
           #:api-error-message
           #:request-failed
           #:request-failed-message
           #:fetch-me
           #:fetch-notebooks
           #:fetch-notebook
           #:post-cell-run))

(in-package #:recurya/cli/client)

(define-condition api-error (error)
  ((status :initarg :status :reader api-error-status)
   (code :initarg :code :reader api-error-code)
   (message :initarg :message :reader api-error-message))
  (:report (lambda (c stream)
             (format stream "~A (HTTP ~D)" (api-error-message c) (api-error-status c)))))

(define-condition request-failed (error)
  ((message :initarg :message :reader request-failed-message))
  (:report (lambda (c stream)
             (format stream "Request failed: ~A" (request-failed-message c)))))

(defun error-from-response (status body)
  "An API-ERROR built from an error response's STATUS and BODY text."
  (let* ((parsed (handler-case (com.inuoe.jzon:parse body)
                    (error () nil)))
         (err (and (hash-table-p parsed) (gethash "error" parsed))))
    (make-condition 'api-error
                    :status status
                    :code (if (hash-table-p err) (gethash "code" err) "http_error")
                    :message (if (hash-table-p err)
                                 (gethash "message" err)
                                 (format nil "HTTP ~D" status)))))

(defun api-request (server token method path &key json)
  "Send METHOD PATH to SERVER with TOKEN (and JSON, a Lisp value to encode, as
the body); return the parsed JSON response.  Signals API-ERROR for an HTTP
error status and REQUEST-FAILED when no usable response arrives."
  (let ((headers `(("Authorization" . ,(format nil "Bearer ~A" token))
                   ("Accept" . "application/json")
                   ,@(when json '(("Content-Type" . "application/json"))))))
    (handler-case
        (com.inuoe.jzon:parse
         (dex:request (concatenate 'string server path)
                      :method method
                      :headers headers
                      :content (and json (com.inuoe.jzon:stringify json))
                      :force-string t))
      (dex:http-request-failed (e)
        (error (error-from-response (dex:response-status e)
                                    (let ((b (dex:response-body e)))
                                      (if (stringp b)
                                          b
                                          (babel:octets-to-string b :encoding :utf-8))))))
      (error (e)
        (error 'request-failed :message (princ-to-string e))))))

(defun fetch-me (server token)
  (api-request server token :get "/api/v1/me"))

(defun fetch-notebooks (server token page)
  (api-request server token :get (format nil "/api/v1/notebooks?page=~D" page)))

(defun fetch-notebook (server token handle slug)
  (api-request server token :get (format nil "/api/v1/notebooks/~A/~A" handle slug)))

(defun post-cell-run (server token handle slug index codes)
  (let ((body (make-hash-table :test 'equal)))
    (setf (gethash "codes" body) (coerce codes 'vector))
    (api-request server token :post
                 (format nil "/api/v1/notebooks/~A/~A/cells/~D/run" handle slug index)
                 :json body)))
