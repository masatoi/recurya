;;;; web/auth.lisp --- Session-based authentication with salted SHA-256.
;;;;
;;;; Password hashing (derive-password / verify-password), user
;;;; registration, login authentication, and default admin seeding.
;;;; All passwords are stored as hex-encoded salt + SHA-256(salt+password).

(defpackage #:recurya/web/auth
  (:use #:cl)
  (:export #:current-user))

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
