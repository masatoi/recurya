;;;; web/auth.lisp --- Session-based authentication with salted SHA-256.
;;;;
;;;; Password hashing (derive-password / verify-password), user
;;;; registration, login authentication, and default admin seeding.
;;;; All passwords are stored as hex-encoded salt + SHA-256(salt+password).

(defpackage #:recurya/web/auth
  (:use #:cl)
  (:import-from #:recurya/db/users
                #:placeholder-handle-p)
  (:export #:current-user
           #:require-real-handle
           #:require-dashboard-auth))

(in-package #:recurya/web/auth)

;;; Password hashing using SHA-256 with salt

(declaim (ftype (function (string) list) derive-password))

(declaim (ftype (function (string (or string null) (or string null)) boolean) verify-password))

;;; User authentication

(declaim (ftype (function (string) boolean) email-exists-p))

(declaim (ftype (function (string string) (or list null)) authenticate))

(declaim (ftype (function (&key (:email (or string null))
                                (:password (or string null))
                                (:name (or string null))
                                (:role t))
                          list)
                register!))

(declaim (ftype (function () (or list null)) ensure-default-admin!))

(defun current-user (env)
  "Extract the current user from the Lack session in ENV."
  (let ((session (getf env :lack.session)))
    (when session
      (gethash :user session))))

(defparameter *handle-onboarding-skip-paths*
  '("/onboarding/handle" "/login" "/logout")
  "Exact paths that bypass the require-real-handle redirect even when
the session user has a placeholder handle. The onboarding form itself
must be reachable, otherwise the user is locked out. /login and /logout
let the user start over if needed.")

(defparameter *handle-onboarding-skip-exact-paths*
  '("/" "/notebooks" "/courses")
  "Exact public landing/listing paths that anyone may view, even with
a placeholder handle. They are listed here (not as prefixes) because
their prefix would also catch /dashboard/notebooks and /dashboard/courses,
which we DO want to gate behind onboarding.")

(defparameter *handle-onboarding-skip-prefixes*
  '("/auth/" "/static/" "/@" "/c/@" "/wardlisp" "/onboarding/")
  "Path prefixes that bypass the require-real-handle redirect. Covers
OAuth callbacks, static assets, public profile/notebook (/@<handle>/...)
and single-course (/c/@<handle>/...) views, the WardLisp public surface,
and any future /onboarding/* sub-paths. Phase 7C dropped the legacy
/n/ and /c/ slug-only prefixes.")

(defun %require-real-handle-skip-p (path)
  "True if PATH should bypass the onboarding redirect."
  (or (member path *handle-onboarding-skip-paths* :test #'string=)
      (member path *handle-onboarding-skip-exact-paths* :test #'string=)
      (some (lambda (p) (alexandria:starts-with-subseq p path))
            *handle-onboarding-skip-prefixes*)))

(defun require-real-handle (app)
  "Lack middleware: redirect users with placeholder handles to /onboarding/handle.

Behavior:
  * No session user            -> pass through to APP.
  * Real (non-placeholder) handle -> pass through to APP.
  * Placeholder handle and the request path is allow-listed
    (*handle-onboarding-skip-paths*, *handle-onboarding-skip-exact-paths*,
    or starts with one of *handle-onboarding-skip-prefixes*) -> pass through.
  * Otherwise emit a 302 redirect to /onboarding/handle.

Must run AFTER the :session middleware (it reads :lack.session) and
BEFORE the Ningle app, so authenticated routes are guarded but
session/CSRF infrastructure can do its work first."
  (lambda (env)
    (let* ((session (getf env :lack.session))
           (user (and session (gethash :user session)))
           (handle (and user (getf user :handle)))
           (path (or (getf env :path-info) "/")))
      (cond
        ((null user) (funcall app env))
        ((not (placeholder-handle-p handle)) (funcall app env))
        ((%require-real-handle-skip-p path) (funcall app env))
        (t (list 302 (list :location "/onboarding/handle") (list "")))))))

(defparameter *dashboard-auth-paths*
  '("/dashboard")
  "Paths whose subtrees require an authenticated session. The check
applies when the request path equals any element exactly, or is at
or under that element with a trailing slash (e.g. \"/dashboard\" and
\"/dashboard/notebooks\" both match \"/dashboard\").")

(defun %dashboard-auth-required-p (path)
  "True if PATH is at or under a dashboard-auth path."
  (some (lambda (root)
          (or (string= path root)
              (alexandria:starts-with-subseq
               (concatenate 'string root "/") path)))
        *dashboard-auth-paths*))

(defun require-dashboard-auth (app)
  "Lack middleware: redirect anonymous requests to /dashboard/* to /login.

Behavior:
  * Path not under *dashboard-auth-paths* -> pass through to APP.
  * Path under *dashboard-auth-paths* and no session user
    -> 302 redirect to /login.
  * Otherwise -> pass through to APP (the user is authenticated;
    require-real-handle further down the chain still gets a chance
    to redirect placeholder-handle users to /onboarding/handle).

Must run AFTER the :session middleware (it reads :lack.session) and
BEFORE require-real-handle, so anonymous visitors are sent to /login
rather than to /onboarding/handle."
  (lambda (env)
    (let* ((session (getf env :lack.session))
           (user (and session (gethash :user session)))
           (path (or (getf env :path-info) "/")))
      (cond
        ((not (%dashboard-auth-required-p path)) (funcall app env))
        ((null user) (list 302 (list :location "/login") (list "")))
        (t (funcall app env))))))
