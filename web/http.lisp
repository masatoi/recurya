;;;; web/http.lisp --- Request/response helpers shared by HTML and JSON routes.

(defpackage #:recurya/web/http
  (:use #:cl)
  (:import-from #:recurya/utils/common
                #:json->string)
  (:export #:read-request-body
           #:*max-request-body-bytes*
           #:request-body-too-large
           #:request-body-limit
           #:*max-request-integer*
           #:parse-bounded-positive-integer
           #:json-response))

(in-package #:recurya/web/http)

(defun json-response (data &key (status 200))
  "Return a Clack ring response with JSON content."
  (list status
        '(:content-type "application/json; charset=utf-8")
        (list (json->string data))))

(defparameter *max-request-integer* 1000000000
  "Largest page number or row id accepted from a URL (10^9); anything larger
is treated as invalid instead of reaching PostgreSQL.")

(defun parse-bounded-positive-integer (raw &key (max *max-request-integer*))
  "RAW (a string from a URL) as an integer in 1..MAX, or NIL when it is
missing, not a number, not positive or larger than MAX."
  (let ((n (and (stringp raw) (parse-integer raw :junk-allowed t))))
    (and n (<= 1 n max) n)))

(defparameter *max-request-body-bytes* (* 1024 1024)
  "Default cap on a request body READ-REQUEST-BODY will read (1 MiB).")

(define-condition request-body-too-large (error)
  ((length :initarg :length :reader request-body-too-large-length)
   (limit :initarg :limit :reader request-body-too-large-limit))
  (:report (lambda (c stream)
             (format stream "Request body of ~D bytes exceeds the ~D-byte limit"
                     (request-body-too-large-length c)
                     (request-body-too-large-limit c))))
  (:documentation "Signalled by READ-REQUEST-BODY when Content-Length is over its cap."))

(defun read-request-body (&key (max-bytes *max-request-body-bytes*))
  "Read the raw POST body as a UTF-8 string, or empty string if unavailable.
Signals REQUEST-BODY-TOO-LARGE, before reading anything, when the declared
Content-Length exceeds MAX-BYTES."
  (let* ((env (lack/request:request-env ningle/context:*request*))
         (stream (getf env :raw-body))
         (content-length (or (getf env :content-length) 0)))
    (when (> content-length max-bytes)
      (error 'request-body-too-large :length content-length :limit max-bytes))
    (cond
      ((and stream (plusp content-length))
       (handler-case (file-position stream 0) (error () nil))
       (let ((buf (make-array content-length :element-type '(unsigned-byte 8))))
         (read-sequence buf stream)
         (babel:octets-to-string buf :encoding :utf-8)))
      (t ""))))

(defun request-body-limit (max-bytes refuse &key (applies-p (constantly t)))
  "A Lack middleware capping request bodies at MAX-BYTES before anything
reads them (Lack parses JSON and form bodies when the request object is made,
so a cap inside a handler comes too late).  For a request whose path satisfies
APPLIES-P: a declared Content-Length over MAX-BYTES gets (FUNCALL REFUSE 413),
and a chunked body without Content-Length gets (FUNCALL REFUSE 411).  Other
requests pass through untouched."
  (lambda (app)
    (lambda (env)
      (if (not (funcall applies-p (getf env :path-info)))
          (funcall app env)
          (let ((length (getf env :content-length))
                (headers (getf env :headers)))
            (cond
              ((and (integerp length) (> length max-bytes))
               (funcall refuse 413))
              ((and (null length)
                    (hash-table-p headers)
                    (gethash "transfer-encoding" headers))
               (funcall refuse 411))
              (t (funcall app env))))))))
