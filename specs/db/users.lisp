;;;; specs/db/users.lisp --- cl-spec contracts for user accounts and handles.
;;;;
;;;; Handle reservation (pure) and, inside WITH-TEST-DB (recurya_test only),
;;;; user creation and lookup, OAuth login resolution and partial updates.
;;;; Design doc: docs/superpowers/specs/2026-10-11-cl-spec-db-rest-design.md

(defpackage #:recurya/specs/db/users
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defspec-function
                #:defproperty
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/specs/db/domain
                #:random-element
                #:random-db-text
                #:id-string)
  (:import-from #:recurya/utils/handle
                #:valid-handle-p
                #:reserved-handle-p
                #:placeholder-handle-p)
  (:import-from #:recurya/tests/support/db
                #:with-test-db)
  (:import-from #:recurya/db/core
                #:execute-one)
  (:import-from #:recurya/db/users
                #:create-user!
                #:get-user-by-id
                #:get-user-by-email
                #:get-user-by-handle
                #:find-or-create-oauth-user
                #:update-user!
                #:users-id
                #:users-email
                #:users-handle
                #:users-display-name
                #:users-role
                #:users-password-hash
                #:users-password-salt
                #:users-language
                #:users-timezone
                #:users-provider
                #:users-provider-uid)
  (:import-from #:uuid
                #:make-v4-uuid)
  (:import-from #:cl-ppcre
                #:scan))

(in-package #:recurya/specs/db/users)

(defparameter *reserved-words*
  '("notebooks" "courses" "c" "n" "dashboard" "account" "login" "logout"
    "auth" "onboarding" "api" "static" "admin" "assets" "learn" "wardlisp"
    "settings" "help" "about" "new" "edit" "search" "blog" "posts"
    "register" "signup" "signin" "user" "users" "me")
  "The reserved handles, copied from utils/handle.lisp so the oracle does not
read the implementation's table.")

(defparameter *placeholder-shape* "\\Au-[a-f0-9]{8}\\z"
  "The placeholder handle shape: u- and exactly 8 lower-case hex digits.")

(defun random-hex (n)
  "A string of N random lower-case hex digits."
  (let ((digits "0123456789abcdef"))
    (coerce (loop repeat n collect (char digits (random 16))) 'string)))

(defun random-case (string)
  "STRING with each character upper-cased at random."
  (map 'string (lambda (ch) (if (zerop (random 2)) (char-upcase ch) ch)) string))

(defgenerator handle-text ()
  "A value that may or may not be an acceptable handle: a reserved word or a
placeholder shape (either in mixed case), a near miss of the placeholder
shape, a plain handle, odd strings, or a non-string."
  (case (random 8)
    (0 (random-element *reserved-words*))
    (1 (random-case (random-element *reserved-words*)))
    (2 (format nil "u-~A" (random-hex 8)))
    (3 (random-case (format nil "u-~A" (random-hex 8))))
    (4 (random-element (vector (format nil "u-~A" (random-hex 7))
                               (format nil "u-~A" (random-hex 9))
                               (format nil "u_~A" (random-hex 8))
                               (format nil "u-~Ag" (random-hex 7))
                               (format nil "x-~A" (random-hex 8))
                               (format nil "u-~A~%" (random-hex 8)))))
    (5 (random-element (vector "alice" "bob-the-builder" "user123" "abc" "a1-b2")))
    (6 (random-element (vector "" "a" "-abc" "abc-" "ab cd" "λambda"
                               (make-string 65 :initial-element #\a))))
    (t (random-element (vector nil 42 :admin)))))

(defspec handle-text t (:generator handle-text))

(defun expected-reserved-p (value)
  "The design's rule: VALUE is a string whose lower-cased form is a reserved
word or has the placeholder shape."
  (and (stringp value)
       (let ((lower (string-downcase value)))
         (or (member lower *reserved-words* :test #'string=)
             (scan *placeholder-shape* lower)))
       t))

(defspec-function reserved-handle-p
  "True exactly for a string whose lower-cased form is a reserved word or has
the placeholder shape; NIL for everything else, non-strings included."
  (:args (value handle-text))
  (:cases
    (:reserved
      (:when (expected-reserved-p value))
      (:returns (member t)))
    (:free
      (:when (not (expected-reserved-p value)))
      (:returns null))))

(defproperty placeholder-handle-never-real ((value handle-text))
  "No value is both accepted by onboarding (VALID-HANDLE-P and not
RESERVED-HANDLE-P) and a placeholder (PLACEHOLDER-HANDLE-P), so a user can
never pick a handle that keeps them in onboarding."
  (:about valid-handle-p reserved-handle-p placeholder-handle-p)
  (:kind :invariant)
  (:trials (:smoke 50 :normal 300))
  (not (and (valid-handle-p value)
            (not (reserved-handle-p value))
            (placeholder-handle-p value))))

;;; Create and look up

(defun example-user-count ()
  "The number of users rows WITH-TEST-DB owns (email ending in @example.com)."
  (second (execute-one "SELECT count(*) AS n FROM users WHERE email LIKE '%@example.com'")))

(defgenerator user-values ()
  "CREATE-USER! arguments for one user: a unique @example.com email, a real
handle, and a display name and password fields that may be NIL."
  (let ((tag (random-hex 8)))
    (list :email (format nil "user-~A@example.com" tag)
          :handle (format nil "user-~A" tag)
          :display-name (random-element (vector nil "" "Alice" "ラムダ λ" "say \"hi\""
                                                (random-db-text 255)))
          :role (random-element #("user" "admin"))
          :password-hash (random-element #(nil "hash"))
          :password-salt (random-element #(nil "salt")))))

(defspec user-values list (:generator user-values))

(defproperty user-create-get-roundtrip ((row-values user-values))
  "A user created with in-domain values is found by id, email and handle as
the same row with every column equal; a NIL display name becomes the email.
Unknown emails and handles, and an empty or NIL handle, find nothing."
  (:about create-user! get-user-by-id get-user-by-email get-user-by-handle)
  (:kind :roundtrip)
  (:trials (:smoke 20 :normal 100))
  (with-test-db
    (let* ((created (apply #'create-user! row-values))
           (id (id-string (users-id created))))
      (and (every (lambda (user)
                    (and user
                         (string= (id-string (users-id user)) id)
                         (equal (users-email user) (getf row-values :email))
                         (equal (users-handle user) (getf row-values :handle))
                         (equal (users-display-name user)
                                (or (getf row-values :display-name)
                                    (getf row-values :email)))
                         (equal (users-role user) (getf row-values :role))
                         (equal (users-password-hash user) (getf row-values :password-hash))
                         (equal (users-password-salt user) (getf row-values :password-salt))))
                  (list (get-user-by-id id)
                        (get-user-by-email (getf row-values :email))
                        (get-user-by-handle (getf row-values :handle))))
           (null (get-user-by-email "nobody@example.com"))
           (null (get-user-by-handle "nobody-here"))
           (null (get-user-by-handle ""))
           (null (get-user-by-handle nil))))))

;;; OAuth login resolution

;; An identity is a (provider, uid) pair, numbered 0-5 (see *OAUTH-PROVIDERS*).
(defparameter *oauth-providers* #("google" "github")
  "The OAuth providers; identity I is provider (floor I 3), uid (mod I 3).")

(defun oauth-email (index)
  "The email address with INDEX (0-2) used by the OAuth scenarios."
  (format nil "oauth-~D@example.com" index))

(defgenerator oauth-scenario ()
  "(IDENTITY-EMAILS EXISTING LOGINS): the email index (0-2) of each of the six
identities (provider x uid), fixed for the whole scenario; existing users as
(EMAIL-INDEX DISPLAY-NAME) for emails 0 and 1, each present with probability
1/2 and a display name of \"\" or \"Existing\"; and 1-8 logins as (IDENTITY
DISPLAY-NAME) with a display name that may be NIL."
  (list (loop repeat 6 collect (random 3))
        (loop for e below 2
              when (zerop (random 2))
                collect (list e (random-element #("" "Existing"))))
        (loop repeat (1+ (random 8))
              collect (list (random 6) (random-element (vector nil "Alice" "ラムダ"))))))

(defspec oauth-scenario list (:generator oauth-scenario))

(defproperty oauth-login-resolution ((scenario oauth-scenario))
  "Each OAuth login returns a user carrying that login's provider, uid and
email.  Logins with the same email resolve to the same user (an existing one
if there is one) and different emails to different users, so the users are
exactly one per email seen.  A new user gets a placeholder handle and the
login's display name (the email when NIL).  An existing user's display name
changes only when a login links a new identity to it by email (not when the
identity already linked logs in again), and only while it is empty."
  (:about find-or-create-oauth-user)
  (:kind :invariant)
  (:trials (:smoke 20 :normal 100))
  (destructuring-bind (identity-emails existing logins) scenario
    (with-test-db
      (let ((owners (make-hash-table))   ; email index -> user id string
            (names (make-hash-table))    ; email index -> expected display name
            (linked (make-hash-table)))  ; email index -> identity now linked
        (loop for (e name) in existing
              do (let ((user (create-user! :email (oauth-email e)
                                           :handle (format nil "existing-~D" e)
                                           :display-name name)))
                   (setf (gethash e owners) (id-string (users-id user))
                         (gethash e names) name)))
        (loop for (identity name) in logins
              always
              (let* ((e (nth identity identity-emails))
                     (provider (aref *oauth-providers* (floor identity 3)))
                     (uid (format nil "uid-~D" (mod identity 3)))
                     (email (oauth-email e))
                     (known (gethash e owners))
                     ;; The provider lookup finds the user only while this
                     ;; identity is the one linked to it; otherwise the login
                     ;; goes through the email merge (or creates the user).
                     (relinked (not (eql (gethash e linked) identity)))
                     (id (id-string (users-id (find-or-create-oauth-user
                                               :provider provider :provider-uid uid
                                               :email email :display-name name))))
                     (user (get-user-by-id id)))
                (if known
                    (when (and relinked name (equal (gethash e names) ""))
                      (setf (gethash e names) name))
                    (setf (gethash e owners) id
                          (gethash e names) (or name email)))
                (setf (gethash e linked) identity)
                (and user
                     (if known (string= id known) t)
                     (equal (users-provider user) provider)
                     (equal (users-provider-uid user) uid)
                     (equal (users-email user) email)
                     (equal (users-display-name user) (gethash e names))
                     (or known (and (scan *placeholder-shape* (users-handle user)) t))
                     (let ((ids (loop for v being the hash-values of owners collect v)))
                       (= (length (remove-duplicates ids :test #'string=))
                          (hash-table-count owners)
                          (example-user-count))))))))))

;;; Partial update

;; One UPDATE-USER! call gets a random subset of the fields; the rest must stay unchanged.
(defparameter *user-update-fields*
  '(:password-hash :password-salt :display-name :role :language :timezone)
  "UPDATE-USER! keyword arguments covered by USER-UPDATE-PARTIAL.")

(defparameter *user-column-defaults* '(:language "en" :timezone "UTC")
  "Column initforms (models/users.lisp) for the fields CREATE-USER! cannot set.")

(defun random-user-fields ()
  "A plist of in-domain values for every field in *USER-UPDATE-FIELDS*."
  (list :password-hash (format nil "hash-~A" (random-hex 6))
        :password-salt (format nil "salt-~A" (random-hex 6))
        :display-name (random-db-text 255)
        :role (random-element #("user" "admin"))
        :language (random-element #("en" "ja"))
        :timezone (random-element #("UTC" "Asia/Tokyo" "America/New_York"))))

(defgenerator user-update-plan ()
  "(BEFORE OTHER CHANGES): creation values for the target user and for a
bystander, and a random subset of *USER-UPDATE-FIELDS* with new values."
  (let ((after (random-user-fields)))
    (list (random-user-fields)
          (random-user-fields)
          (loop for field in *user-update-fields*
                when (zerop (random 2))
                  append (list field (getf after field))))))

(defspec user-update-plan list (:generator user-update-plan))

(defun create-plan-user (fields tag)
  "Create a user from FIELDS (CREATE-USER! takes all but language and
timezone) with an email and handle derived from TAG; return its id string."
  (id-string (users-id (create-user! :email (format nil "update-~A@example.com" tag)
                                     :handle (format nil "update-~A" tag)
                                     :password-hash (getf fields :password-hash)
                                     :password-salt (getf fields :password-salt)
                                     :display-name (getf fields :display-name)
                                     :role (getf fields :role)))))

(defun user-field (user field)
  "USER's value for the *USER-UPDATE-FIELDS* keyword FIELD."
  (ecase field
    (:password-hash (users-password-hash user))
    (:password-salt (users-password-salt user))
    (:display-name (users-display-name user))
    (:role (users-role user))
    (:language (users-language user))
    (:timezone (users-timezone user))))

(defun user-fields-hold-p (user before changes)
  "True when every field of USER equals its CHANGES value, else its creation
value from BEFORE (or the column default for language and timezone)."
  (and user
       (loop for field in *user-update-fields*
             always (equal (user-field user field)
                           (getf changes field
                                 (getf *user-column-defaults* field
                                       (getf before field)))))))

(defproperty user-update-partial ((plan user-update-plan))
  "UPDATE-USER! sets exactly the fields it is given and leaves the user's
other fields, and every other user, as they were; for an unknown id it returns
NIL and changes nothing."
  (:about update-user!)
  (:kind :invariant)
  (:trials (:smoke 20 :normal 100))
  (destructuring-bind (before other changes) plan
    (with-test-db
      (let* ((target (create-plan-user before "target"))
             (bystander (create-plan-user other "bystander"))
             (missing (apply #'update-user! (id-string (make-v4-uuid)) changes))
             (updated (apply #'update-user! target changes)))
        (and (null missing)
             updated
             (string= (id-string (users-id updated)) target)
             (user-fields-hold-p (get-user-by-id target) before changes)
             (user-fields-hold-p (get-user-by-id bystander) other nil))))))
