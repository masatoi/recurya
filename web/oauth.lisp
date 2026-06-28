;;;; web/oauth.lisp --- OAuth 2.0 flow (Google + GitHub).
;;;;
;;;; Provider definitions, CSRF state generation, authorize URL
;;;; construction, code -> access-token exchange, and userinfo
;;;; fetching. HTTP I/O is dispatched through *http-post-fn* and
;;;; *http-get-fn* so tests can stub network calls.

(defpackage #:recurya/web/oauth
  (:use #:cl)
  (:import-from #:ironclad
                #:random-data
                #:byte-array-to-hex-string)
  (:export #:oauth-provider
           #:make-oauth-provider
           #:oauth-provider-p
           #:oauth-provider-name
           #:oauth-provider-authorize-url
           #:oauth-provider-token-url
           #:oauth-provider-userinfo-url
           #:oauth-provider-scope
           #:oauth-provider-client-id-env
           #:oauth-provider-client-secret-env
           #:oauth-provider-email-fn
           #:oauth-provider-uid-fn
           #:oauth-provider-name-fn
           #:*providers*
           #:*http-post-fn*
           #:*http-get-fn*
           #:find-provider
           #:provider-configured-p
           #:dev-stub-enabled-p
           #:dev-stub-email
           #:dev-stub-name
           #:generate-state
           #:redirect-uri
           #:build-authorize-url
           #:exchange-code
           #:fetch-userinfo
           #:extract-email
           #:extract-uid
           #:extract-name))

(in-package #:recurya/web/oauth)

(defstruct oauth-provider
  (name "" :type string)
  (authorize-url "" :type string)
  (token-url "" :type string)
  (userinfo-url "" :type string)
  (scope "" :type string)
  (client-id-env "" :type string)
  (client-secret-env "" :type string)
  (email-fn (lambda (info token)
              (declare (ignore token))
              (gethash "email" info)))
  (uid-fn (lambda (info) (gethash "sub" info)))
  (name-fn (lambda (info) (gethash "name" info))))

(defparameter *http-post-fn*
  (lambda (url &key content headers)
    (dexador:post url :content content :headers headers)))

(defparameter *http-get-fn*
  (lambda (url &key headers)
    (dexador:get url :headers headers)))

(defun env-or-nil (name)
  (let ((v (uiop:getenv name)))
    (if (and v (plusp (length v))) v nil)))

(defun dev-stub-enabled-p ()
  "Dev OAuth stub is active only when both gates pass:
1. OAUTH_DEV_STUB env var is set (any non-empty value).
2. OAUTH_REDIRECT_BASE is unset, points at localhost / 127.0.0.1, or
   contains \".ngrok\" (matches *.ngrok-free.app / .ngrok.app / .ngrok.io /
   .ngrok.dev — ngrok tunnels are inherently dev/temporary).
The host gate prevents a stray production deploy with the flag set
from minting admin sessions."
  (and (env-or-nil "OAUTH_DEV_STUB")
       (let ((base (env-or-nil "OAUTH_REDIRECT_BASE")))
         (or (null base)
             (search "localhost" base)
             (search "127.0.0.1" base)
             (search ".ngrok" base)))))

(defun dev-stub-email ()
  (or (env-or-nil "OAUTH_DEV_EMAIL") "dev@example.com"))

(defun dev-stub-name ()
  (or (env-or-nil "OAUTH_DEV_NAME") "Dev User"))

(defun fetch-github-primary-email (access-token)
  (let* ((body (funcall *http-get-fn*
                        "https://api.github.com/user/emails"
                        :headers `(("Authorization" . ,(format nil "Bearer ~A" access-token))
                                   ("Accept" . "application/vnd.github+json")
                                   ("User-Agent" . "recurya"))))
         (emails (com.inuoe.jzon:parse body)))
    (when (and emails (vectorp emails))
      (loop for entry across emails
            when (and (eq t (gethash "primary" entry))
                      (eq t (gethash "verified" entry)))
              return (gethash "email" entry)))))

(defparameter *google-provider*
  (make-oauth-provider
   :name "google"
   :authorize-url "https://accounts.google.com/o/oauth2/v2/auth"
   :token-url "https://oauth2.googleapis.com/token"
   :userinfo-url "https://www.googleapis.com/oauth2/v3/userinfo"
   :scope "openid email profile"
   :client-id-env "OAUTH_GOOGLE_CLIENT_ID"
   :client-secret-env "OAUTH_GOOGLE_CLIENT_SECRET"
   :email-fn (lambda (info token)
               (declare (ignore token))
               (gethash "email" info))
   :uid-fn (lambda (info) (gethash "sub" info))
   :name-fn (lambda (info)
              (or (gethash "name" info)
                  (gethash "email" info)))))

(defparameter *github-provider*
  (make-oauth-provider
   :name "github"
   :authorize-url "https://github.com/login/oauth/authorize"
   :token-url "https://github.com/login/oauth/access_token"
   :userinfo-url "https://api.github.com/user"
   :scope "read:user user:email"
   :client-id-env "OAUTH_GITHUB_CLIENT_ID"
   :client-secret-env "OAUTH_GITHUB_CLIENT_SECRET"
   :email-fn (lambda (info token)
               (or (gethash "email" info)
                   (fetch-github-primary-email token)))
   :uid-fn (lambda (info)
             (let ((id (gethash "id" info)))
               (if (numberp id) (princ-to-string id) id)))
   :name-fn (lambda (info)
              (or (gethash "name" info)
                  (gethash "login" info)))))

(defparameter *providers*
  (list (cons "google" *google-provider*)
        (cons "github" *github-provider*)))

(defun find-provider (name)
  (cdr (assoc name *providers* :test #'string-equal)))

(defun provider-configured-p (provider)
  (and provider
       (or (dev-stub-enabled-p)
           (and (env-or-nil (oauth-provider-client-id-env provider))
                (env-or-nil (oauth-provider-client-secret-env provider))))
       t))

(defun generate-state ()
  (ironclad:byte-array-to-hex-string (ironclad:random-data 16)))

(defun redirect-base ()
  (or (env-or-nil "OAUTH_REDIRECT_BASE") "http://localhost:13000"))

(defun redirect-uri (provider)
  (format nil "~A/auth/~A/callback"
          (redirect-base)
          (oauth-provider-name provider)))

(defun encode-form-data (alist)
  (format nil "~{~A~^&~}"
          (loop for (k . v) in alist
                collect (format nil "~A=~A"
                                (quri:url-encode k)
                                (quri:url-encode (or v ""))))))

(defun build-authorize-url (provider state)
  (cond
    ((dev-stub-enabled-p)
     ;; Skip the real provider entirely: redirect straight back to our own
     ;; callback with a fake code. Use a relative path so the browser keeps
     ;; whichever origin it is currently on (localhost, ngrok, etc.) — an
     ;; absolute URL built from OAUTH_REDIRECT_BASE would break the ngrok
     ;; flow. The state still round-trips so the CSRF check exercises the
     ;; same code path.
     (format nil "/auth/~A/callback?code=DEV-CODE&state=~A"
             (oauth-provider-name provider)
             (quri:url-encode state)))
    (t
     (let ((params `(("client_id" . ,(or (env-or-nil (oauth-provider-client-id-env provider)) ""))
                     ("redirect_uri" . ,(redirect-uri provider))
                     ("scope" . ,(oauth-provider-scope provider))
                     ("state" . ,state)
                     ("response_type" . "code"))))
       (format nil "~A?~A"
               (oauth-provider-authorize-url provider)
               (encode-form-data params))))))

(defun exchange-code (provider code)
  (cond
    ((dev-stub-enabled-p)
     "DEV-ACCESS-TOKEN")
    (t
     (let* ((params `(("client_id" . ,(or (env-or-nil (oauth-provider-client-id-env provider)) ""))
                      ("client_secret" . ,(or (env-or-nil (oauth-provider-client-secret-env provider)) ""))
                      ("code" . ,code)
                      ("redirect_uri" . ,(redirect-uri provider))
                      ("grant_type" . "authorization_code")))
            (body (encode-form-data params))
            (response (funcall *http-post-fn*
                               (oauth-provider-token-url provider)
                               :content body
                               :headers '(("Accept" . "application/json")
                                          ("Content-Type" . "application/x-www-form-urlencoded"))))
            (parsed (com.inuoe.jzon:parse response)))
       (gethash "access_token" parsed)))))

(defun fetch-userinfo (provider access-token)
  (cond
    ((dev-stub-enabled-p)
     (let ((info (make-hash-table :test 'equal))
           (uid (format nil "dev-~A" (oauth-provider-name provider))))
       (setf (gethash "sub" info) uid
             (gethash "id" info) uid
             (gethash "email" info) (dev-stub-email)
             (gethash "name" info) (dev-stub-name)
             (gethash "login" info) (dev-stub-name))
       info))
    (t
     (let ((response (funcall *http-get-fn*
                              (oauth-provider-userinfo-url provider)
                              :headers `(("Authorization" . ,(format nil "Bearer ~A" access-token))
                                         ("Accept" . "application/json")
                                         ("User-Agent" . "recurya")))))
       (com.inuoe.jzon:parse response)))))

(defun extract-email (provider userinfo access-token)
  (funcall (oauth-provider-email-fn provider) userinfo access-token))

(defun extract-uid (provider userinfo)
  (funcall (oauth-provider-uid-fn provider) userinfo))

(defun extract-name (provider userinfo)
  (funcall (oauth-provider-name-fn provider) userinfo))
