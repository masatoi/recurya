;;;; web/api-auth.lisp --- Bearer-token authentication for the JSON API.
;;;;
;;;; Under /api/ the only credential is "Authorization: Bearer <token>"; the
;;;; session cookie is never consulted, which is what makes it safe to exempt
;;;; /api/ from the CSRF middleware.

(defpackage #:recurya/web/api-auth
  (:use #:cl)
  (:import-from #:alexandria
                #:starts-with-subseq)
  (:import-from #:recurya/db/api-tokens
                #:authenticate-api-token)
  (:import-from #:recurya/db/users
                #:user-dao->plist)
  (:import-from #:recurya/web/http
                #:json-response
                #:request-body-limit
                #:*max-request-body-bytes*)
  (:export #:*api-prefix*
           #:api-path-p
           #:api-error-response
           #:api-token-auth
           #:api-body-limit
           #:*token-authenticator*))

(in-package #:recurya/web/api-auth)

(defparameter *api-prefix* "/api/"
  "Path prefix of the token-authenticated JSON API.")

(defun api-path-p (path)
  "True when PATH is under *API-PREFIX*."
  (and (stringp path) (starts-with-subseq *api-prefix* path)))

(defun api-error-response (status code message)
  "A JSON error response {\"error\": {\"code\": CODE, \"message\": MESSAGE}}."
  (let ((err (make-hash-table :test 'equal))
        (body (make-hash-table :test 'equal)))
    (setf (gethash "code" err) code
          (gethash "message" err) message
          (gethash "error" body) err)
    (json-response body :status status)))

(defun api-body-limit (app)
  "Lack middleware: refuse /api/ request bodies over *MAX-REQUEST-BODY-BYTES*
(413 payload_too_large) and chunked bodies without Content-Length (411
length_required) before anything reads them."
  (funcall (request-body-limit
            *max-request-body-bytes*
            (lambda (status)
              (if (= status 413)
                  (api-error-response 413 "payload_too_large"
                                      (format nil "Request body is over ~D bytes"
                                              *max-request-body-bytes*))
                  (api-error-response 411 "length_required"
                                      "A request body needs a Content-Length header")))
            :applies-p #'api-path-p)
           app))

(defun bearer-token (env)
  "The token of ENV's \"Authorization: Bearer <token>\" header, or NIL."
  (let* ((headers (getf env :headers))
         (value (and (hash-table-p headers) (gethash "authorization" headers))))
    (when (and (stringp value)
               (> (length value) 7)
               (string-equal "Bearer " value :end2 7))
      (string-trim " " (subseq value 7)))))

(defvar *token-authenticator* 'authenticate-api-token
  "Function of one argument, the plaintext token, returning the owner's user
DAO or NIL.  Tests rebind it to simulate a failing database.")

(defun api-token-auth (app)
  "Lack middleware: authenticate /api/ requests by bearer token.
Outside *API-PREFIX* the request passes through untouched.  Under it, a valid
token adds the owner's session-shaped plist to ENV as :RECURYA.API-USER and
calls APP; a missing or invalid token is a 401 JSON error, and a failure of
the check itself (e.g. the database is down) is a 503, so clients are not told
to log in again during an outage."
  (lambda (env)
    (if (not (api-path-p (getf env :path-info)))
        (funcall app env)
        (let* ((token (bearer-token env))
               (user (and token
                          (handler-case (funcall *token-authenticator* token)
                            (error (e)
                              (log:warn "API token check failed: ~A" e)
                              :unavailable)))))
          (cond
            ((eq user :unavailable)
             (api-error-response 503 "unavailable"
                                 "Authentication is temporarily unavailable; try again later."))
            (user
             (funcall app (list* :recurya.api-user (user-dao->plist user) env)))
            (t
             (api-error-response 401 "unauthorized"
                                 "A valid API token is required (Authorization: Bearer <token>).")))))))
