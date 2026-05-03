;;;; tests/db/courses.lisp --- Tests for course CRUD operations.

(defpackage #:recurya/tests/db/courses
  (:use #:cl
        #:rove)
  (:import-from #:recurya/tests/support/db
                #:with-test-db
                #:create-test-user)
  (:import-from #:recurya/db/courses
                #:course-id
                #:course-slug
                #:course-title
                #:course-status
                #:course-author-id
                #:create-course!
                #:get-course-by-id
                #:get-course-by-slug)
  (:import-from #:recurya/db/users
                #:users-id))

(in-package #:recurya/tests/db/courses)

(deftest create-and-get-course-by-id
  (testing "create-course! persists and get-course-by-id retrieves"
    (with-test-db
      (let* ((u (create-test-user))
             (c (create-course! :title "C1" :author u))
             (id (course-id c)))
        (let ((found (get-course-by-id id)))
          (ok found)
          (ok (string= "C1" (course-title found)))
          (ok (string= "c1" (course-slug found)))
          (ok (string= "draft" (course-status found)))
          (ok (equal (users-id u) (course-author-id found))))))))

(deftest fetch-course-by-slug
  (testing "get-course-by-slug finds by unique slug"
    (with-test-db
      (let* ((u (create-test-user))
             (c (create-course! :title "Course Lookup" :author u)))
        (let ((found (get-course-by-slug "course-lookup")))
          (ok found)
          (ok (equal (course-id c) (course-id found))))
        (ok (null (get-course-by-slug "no-such-course")))))))

(deftest get-course-by-id-missing-returns-nil
  (with-test-db
    (ok (null (get-course-by-id "00000000-0000-0000-0000-000000000000")))))
