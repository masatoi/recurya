;;;; db/users.lisp --- CRUD operations for the users table.
;;;;
;;;; Provides create, read, update, delete, and listing for users.
;;;; Uses Mito ORM (select-dao, insert-dao) with the users deftable
;;;; defined in models/users.lisp.

(defpackage #:recurya/db/users
  (:use #:cl)
  (:import-from #:mito
                #:find-dao
                #:select-dao
                #:insert-dao
                #:save-dao
                #:delete-dao)
  (:import-from #:sxql
                #:order-by)
  (:import-from #:recurya/db/core
                #:generate-uuid)
  ;; Import users class and accessors from models
  (:import-from #:recurya/models/users
                #:users
                #:users-id
                #:users-email
                #:users-password-hash
                #:users-password-salt
                #:users-display-name
                #:users-handle
                #:users-role
                #:users-language
                #:users-timezone
                #:users-provider
                #:users-provider-uid
                #:users-created-at
                #:users-updated-at)
  (:export
   ;; Re-export the Mito class and accessors
   #:users
   #:users-id
   #:users-email
   #:users-password-hash
   #:users-password-salt
   #:users-display-name
   #:users-handle
   #:users-role
   #:users-language
   #:users-timezone
   #:users-provider
   #:users-provider-uid
   #:users-created-at
   #:users-updated-at
   ;; CRUD operations
   #:create-user!
   #:get-user-by-id
   #:get-user-by-email
   #:get-user-by-provider
   #:find-or-create-oauth-user
   #:update-user!
   #:delete-user!
   #:list-users))

(in-package #:recurya/db/users)

;;; ============================================================
;;; CRUD Operations using Mito DAO
;;; ============================================================

(defun create-user! (&key email password-hash password-salt display-name handle (role "user"))
  "Create a new user and return the created user instance.

Used by tests and legacy admin seeding. OAuth-based registration goes
through FIND-OR-CREATE-OAUTH-USER instead.

Arguments:
  EMAIL         - User's email address (required, must be unique)
  PASSWORD-HASH - Pre-computed password hash (optional, NIL for OAuth-only)
  PASSWORD-SALT - Salt used for hashing (optional, NIL for OAuth-only)
  DISPLAY-NAME  - Optional display name
  HANDLE        - Per-user URL handle (required at the DB level once
                  Phase 5 migration runs; may be NIL here for legacy
                  call sites until callers are updated)
  ROLE          - User role (default: \"user\")

Returns:
  The newly created USER instance."
  (let ((user-id (generate-uuid)))
    (insert-dao (make-instance 'users
                               :id user-id
                               :email email
                               :handle handle
                               :password-hash password-hash
                               :password-salt password-salt
                               :display-name (or display-name email)
                               :role role))))

(defun get-user-by-id (user-id)
  "Fetch a user by their unique ID.

Arguments:
  USER-ID - UUID string.

Returns:
  USER instance if found, NIL otherwise."
  (find-dao 'users :id user-id))

(defun get-user-by-email (email)
  "Fetch a user by their email address.

Arguments:
  EMAIL - Email address string.

Returns:
  USER instance if found, NIL otherwise.

Note: Email lookup is case-sensitive."
  (find-dao 'users :email email))

(defun get-user-by-provider (provider provider-uid)
  "Fetch a user by their OAuth (provider, provider-uid) pair.
   Returns USER instance if found, NIL otherwise."
  (find-dao 'users :provider provider :provider-uid provider-uid))

(defun find-or-create-oauth-user (&key provider provider-uid email display-name (role "user"))
  "Idempotently resolve an OAuth login to a USER instance.

Strategy:
  1. Look up by (PROVIDER, PROVIDER-UID). If found, return it.
  2. Look up by EMAIL (provider-agnostic). If found, attach the new
     PROVIDER/PROVIDER-UID to it (merging this OAuth identity into the
     existing user) and return it.
  3. Otherwise create a new user with the given identity and return it.

This makes Google ⇄ GitHub login on the same email resolve to the same
account. Both Google and GitHub return verified emails by default, so
the merge is safe.

Returns the USER instance."
  (or (get-user-by-provider provider provider-uid)
      (let ((existing (and email (get-user-by-email email))))
        (cond
          (existing
           (setf (users-provider existing) provider
                 (users-provider-uid existing) provider-uid)
           (when (and display-name
                      (or (null (users-display-name existing))
                          (zerop (length (users-display-name existing)))))
             (setf (users-display-name existing) display-name))
           (save-dao existing)
           existing)
          (t
           (insert-dao (make-instance 'users
                                      :id (generate-uuid)
                                      :email (or email "")
                                      :display-name (or display-name email "User")
                                      :role role
                                      :provider provider
                                      :provider-uid provider-uid)))))))

(defun update-user! (user-id &key password-hash password-salt display-name role
                              language timezone)
  "Update user attributes. Only provided fields are updated.

Arguments:
  USER-ID       - UUID of the user to update
  PASSWORD-HASH - New password hash (optional)
  PASSWORD-SALT - New password salt (optional)
  DISPLAY-NAME  - New display name (optional)
  ROLE          - New role (optional)
  LANGUAGE      - Preferred language code, e.g. \"en\", \"ja\" (optional)
  TIMEZONE      - Preferred timezone, e.g. \"Asia/Tokyo\" (optional)

Returns:
  The updated USER instance.

Side Effects:
  Updates the specified fields. Mito automatically updates updated_at."
  (let ((user (find-dao 'users :id user-id)))
    (when user
      (when password-hash
        (setf (users-password-hash user) password-hash))
      (when password-salt
        (setf (users-password-salt user) password-salt))
      (when display-name
        (setf (users-display-name user) display-name))
      (when role
        (setf (users-role user) role))
      (when language
        (setf (users-language user) language))
      (when timezone
        (setf (users-timezone user) timezone))
      (save-dao user))
    user))

(defun delete-user! (email)
  "Delete a user by email address.

Arguments:
  EMAIL - Email address of the user to delete.

Returns:
  T if a user was deleted, NIL if no user with that email existed."
  (let ((user (find-dao 'users :email email)))
    (when user
      (delete-dao user)
      t)))

(defun list-users ()
  "List all users ordered by creation date (newest first).

Returns:
  List of USER instances.

Note: For production use, consider pagination for large user bases."
  (select-dao 'users (order-by (:desc :created-at))))
