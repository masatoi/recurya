;;;; models/api-token.lisp --- Mito table for personal API access tokens.

(defpackage #:recurya/models/api-token
  (:use #:cl #:mito)
  (:export #:api-token
           #:api-token-id
           #:api-token-user-id
           #:api-token-name
           #:api-token-token-hash
           #:api-token-token-prefix
           #:api-token-last-used-at
           #:api-token-revoked-at
           #:api-token-created-at))

(in-package #:recurya/models/api-token)

(deftable api-token ()
  ((user-id :col-type :uuid
            :initarg :user-id
            :accessor api-token-user-id)
   (name :col-type (:varchar 64)
         :initarg :name
         :accessor api-token-name)
   (token-hash :col-type (:varchar 64)
               :initarg :token-hash
               :accessor api-token-token-hash)
   (token-prefix :col-type (:varchar 12)
                 :initarg :token-prefix
                 :accessor api-token-token-prefix)
   (last-used-at :col-type (or :timestamptz :null)
                 :initarg :last-used-at
                 :initform nil
                 :accessor api-token-last-used-at)
   (revoked-at :col-type (or :timestamptz :null)
               :initarg :revoked-at
               :initform nil
               :accessor api-token-revoked-at))
  (:unique-keys token-hash)
  (:keys user-id)
  (:documentation "Personal access token for the JSON API. Only the SHA-256 of
the plaintext is stored; TOKEN-PREFIX keeps the first characters for display.
A non-NULL REVOKED-AT disables the token."))

(defun api-token-id (row) (mito:object-id row))
(defun api-token-created-at (row) (mito:object-created-at row))
