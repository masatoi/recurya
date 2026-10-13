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
                #:json-response)
  (:export #:*api-prefix*
           #:api-path-p
           #:api-error-response
           #:api-token-auth))

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

(defun bearer-token (env)
  "The token of ENV's \"Authorization: Bearer <token>\" header, or NIL."
  (let* ((headers (getf env :headers))
         (value (and (hash-table-p headers) (gethash "authorization" headers))))
    (when (and (stringp value)
               (> (length value) 7)
               (string-equal "Bearer " value :end2 7))
      (string-trim " " (subseq value 7)))))

(defun api-token-auth (app)
  "Lack middleware: authenticate /api/ requests by bearer token.
Outside *API-PREFIX* the request passes through untouched.  Under it, a valid
token adds the owner's session-shaped plist to ENV as :RECURYA.API-USER and
calls APP; anything else is a 401 JSON error."
  (lambda (env)
    (if (not (api-path-p (getf env :path-info)))
        (funcall app env)
        (let* ((token (bearer-token env))
               (user (and token
                          (handler-case (authenticate-api-token token)
                            (error (e)
                              (log:warn "API token check failed: ~A" e)
                              nil)))))
          (if user
              (funcall app (list* :recurya.api-user (user-dao->plist user) env))
              (api-error-response 401 "unauthorized"
                                  "A valid API token is required (Authorization: Bearer <token>)."))))))
