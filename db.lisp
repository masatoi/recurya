;;;; db.lisp --- Aggregate package re-exporting all DB layer symbols.

(defpackage #:recurya/db
  (:use #:cl)
  (:documentation "Database access facade. All database operations are delegated to specialized modules.")
  ;; Re-export from core
  (:import-from #:recurya/db/core
                #:start!
                #:stop!
                #:datasource
                #:with-transaction)
  ;; Re-export from users
  (:import-from #:recurya/db/users
                #:create-user!
                #:get-user-by-id
                #:get-user-by-email
                #:update-user!
                #:delete-user!
                #:list-users)
  (:export
   ;; Core database management
   #:start!
   #:stop!
   #:datasource
   #:with-transaction

   ;; Users
   #:create-user!
   #:get-user-by-id
   #:get-user-by-email
   #:update-user!
   #:delete-user!
   #:list-users))

(in-package #:recurya/db)

;; This package serves as a facade, re-exporting all database operations
;; from specialized modules. No additional code needed here.
