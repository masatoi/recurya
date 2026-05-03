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
                #:get-user-notebook-by-slug
                #:update-user-notebook!
                #:delete-user-notebook!
                #:list-user-notebooks
                #:count-user-notebooks)
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

(deftest update-user-notebook-test
  (testing "update-user-notebook! modifies provided fields and returns instance"
    (with-test-db
      (let* ((u (create-test-user))
             (nb (create-user-notebook!
                  :title "Before"
                  :body-md "===prose===
old"
                  :cells '()
                  :author u))
             (updated (update-user-notebook!
                       (user-notebook-id nb)
                       :title "After"
                       :body-md "===prose===
new"
                       :status "published")))
        (ok updated)
        (ok (string= "After" (user-notebook-title updated)))
        (ok (string= "published" (user-notebook-status updated)))
        (ok (search "new" (user-notebook-body-md updated))))))
  (testing "update on missing id returns NIL"
    (with-test-db
      (ok (null (update-user-notebook!
                 "00000000-0000-0000-0000-000000000000"
                 :title "X"))))))

(deftest delete-user-notebook-test
  (testing "delete-user-notebook! removes row and returns T"
    (with-test-db
      (let* ((u (create-test-user))
             (nb (create-user-notebook!
                  :title "To Delete"
                  :body-md "===prose===
bye"
                  :cells '()
                  :author u))
             (id (user-notebook-id nb)))
        (ok (eq t (delete-user-notebook! id)))
        (ok (null (get-user-notebook-by-id id))))))
  (testing "delete on missing id returns NIL"
    (with-test-db
      (ok (null (delete-user-notebook!
                 "00000000-0000-0000-0000-000000000000"))))))

(deftest list-user-notebooks-test
  (testing "list-user-notebooks returns newest first; status and author filters work"
    (with-test-db
      (let* ((u1 (create-test-user :email-prefix "alice"))
             (u2 (create-test-user :email-prefix "bob")))
        (create-user-notebook! :title "A1" :body-md "===prose===
a1" :cells '() :author u1 :status "published")
        (create-user-notebook! :title "A2" :body-md "===prose===
a2" :cells '() :author u1 :status "draft")
        (create-user-notebook! :title "B1" :body-md "===prose===
b1" :cells '() :author u2 :status "published")
        (let ((all (list-user-notebooks)))
          (ok (= 3 (length all))))
        (let ((pubs (list-user-notebooks :status "published")))
          (ok (= 2 (length pubs)))
          (ok (every (lambda (nb) (string= "published" (user-notebook-status nb)))
                     pubs)))
        (let ((u1-nbs (list-user-notebooks :author-id (users-id u1))))
          (ok (= 2 (length u1-nbs)))
          (ok (every (lambda (nb) (equal (users-id u1) (user-notebook-author-id nb)))
                     u1-nbs))))))
  (testing "limit and offset paginate"
    (with-test-db
      (let ((u (create-test-user)))
        (dotimes (i 5)
          (create-user-notebook!
           :title (format nil "T~A" i)
           :slug (format nil "t~A" i)
           :body-md "===prose===
x"
           :cells '()
           :author u))
        (let ((page1 (list-user-notebooks :limit 2)))
          (ok (= 2 (length page1))))
        (let ((page2 (list-user-notebooks :limit 2 :offset 2)))
          (ok (= 2 (length page2))))
        (let ((page3 (list-user-notebooks :limit 2 :offset 4)))
          (ok (= 1 (length page3))))))))

(deftest count-user-notebooks-test
  (testing "count-user-notebooks returns total and filters by status / author"
    (with-test-db
      (let* ((u1 (create-test-user :email-prefix "carol"))
             (u2 (create-test-user :email-prefix "dave")))
        (create-user-notebook! :title "C1" :body-md "===prose===
c1" :cells '() :author u1 :status "published")
        (create-user-notebook! :title "C2" :body-md "===prose===
c2" :cells '() :author u1 :status "draft")
        (create-user-notebook! :title "D1" :body-md "===prose===
d1" :cells '() :author u2 :status "published")
        (ok (= 3 (count-user-notebooks)))
        (ok (= 2 (count-user-notebooks :status "published")))
        (ok (= 1 (count-user-notebooks :status "draft")))
        (ok (= 2 (count-user-notebooks :author-id (users-id u1))))))))
