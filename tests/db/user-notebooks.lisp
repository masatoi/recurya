;;;; tests/db/user-notebooks.lisp --- Tests for user-notebook CRUD operations.

(defpackage #:recurya/tests/db/user-notebooks
  (:use #:cl
        #:rove)
  (:import-from #:recurya/tests/support/db
                #:with-test-db
                #:create-test-user)
  (:import-from #:recurya/db/user-notebooks
                #:user-notebook-id
                #:user-notebook-slug
                #:user-notebook-title
                #:user-notebook-body-md
                #:user-notebook-status
                #:user-notebook-author-id
                #:create-user-notebook!
                #:get-user-notebook-by-id
                #:get-user-notebook-by-slug)
  (:import-from #:recurya/db/users
                #:users-id))

(in-package #:recurya/tests/db/user-notebooks)

(deftest create-and-get-by-id
  (testing "create-user-notebook! persists and get-user-notebook-by-id retrieves"
    (with-test-db
      (let* ((u (create-test-user))
             (nb (create-user-notebook!
                  :title "T1"
                  :body-md "===prose===
x"
                  :cells '()
                  :author u))
             (id (user-notebook-id nb)))
        (let ((found (get-user-notebook-by-id id)))
          (ok found)
          (ok (string= "T1" (user-notebook-title found)))
          (ok (string= "t1" (user-notebook-slug found)))
          (ok (string= "draft" (user-notebook-status found)))
          (ok (equal (users-id u) (user-notebook-author-id found))))))))

(deftest fetch-by-slug
  (testing "get-user-notebook-by-slug finds by unique slug"
    (with-test-db
      (let* ((u (create-test-user))
             (nb (create-user-notebook!
                  :title "Slug Lookup"
                  :body-md "===prose===
y"
                  :cells '()
                  :author u)))
        (let ((found (get-user-notebook-by-slug "slug-lookup")))
          (ok found)
          (ok (equal (user-notebook-id nb) (user-notebook-id found))))
        (ok (null (get-user-notebook-by-slug "no-such-notebook")))))))

(deftest get-by-id-missing-returns-nil
  (with-test-db
    (ok (null (get-user-notebook-by-id "00000000-0000-0000-0000-000000000000")))))
