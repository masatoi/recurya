;;;; web/http.lisp --- Request/response helpers shared by HTML and JSON routes.

(defpackage #:recurya/web/http
  (:use #:cl)
  (:import-from #:recurya/utils/common
                #:json->string)
  (:export #:read-request-body
           #:json-response))

(in-package #:recurya/web/http)

(defun json-response (data &key (status 200))
  "Return a Clack ring response with JSON content."
  (list status
        '(:content-type "application/json; charset=utf-8")
        (list (json->string data))))

(defun read-request-body ()
  "Read the raw POST body as a UTF-8 string, or empty string if unavailable."
  (let* ((env (lack/request:request-env ningle/context:*request*))
         (stream (getf env :raw-body))
         (content-length (or (getf env :content-length) 0)))
    (cond
      ((and stream (plusp content-length))
       (handler-case (file-position stream 0) (error () nil))
       (let ((buf (make-array content-length :element-type '(unsigned-byte 8))))
         (read-sequence buf stream)
         (babel:octets-to-string buf :encoding :utf-8)))
      (t ""))))
