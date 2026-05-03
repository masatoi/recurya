;;;; tests/db/course-notebooks.lisp --- Tests for course-notebook join CRUD.

(defpackage #:recurya/tests/db/course-notebooks
  (:use #:cl
        #:rove)
  (:import-from #:recurya/tests/support/db
                #:with-test-db
                #:create-test-user)
  (:import-from #:recurya/db/courses
                #:create-course!
                #:course-id)
  (:import-from #:recurya/db/user-notebooks
                #:create-user-notebook!
                #:user-notebook-id)
  (:import-from #:recurya/db/course-notebooks
                #:add-notebook-to-course!
                #:remove-notebook-from-course!
                #:move-notebook-up!
                #:move-notebook-down!
                #:list-course-notebooks
                #:get-course-notebook
                #:course-notebook-position
                #:course-notebook-id
                #:course-notebook-notebook-id))

(in-package #:recurya/tests/db/course-notebooks)

(defun %make-course-with-notebooks (n)
  "Create a course owned by a fresh user plus N notebooks attached at
positions 0..N-1. Returns (values course (list notebook ...)
(list course-notebook ...)) where each list is in position order."
  (let* ((u (create-test-user))
         (c (create-course! :title "Course" :author u))
         (notebooks
          (loop for i from 0 below n
                collect (create-user-notebook!
                         :title (format nil "N~A" i)
                         :slug (format nil "n~A-~A" i (random 1000000))
                         :body-md "===prose===\nx"
                         :cells '()
                         :author u))))
    (let ((cns
           (loop for nb in notebooks
                 for i from 0
                 collect (add-notebook-to-course!
                          (course-id c)
                          (user-notebook-id nb)
                          :position i))))
      (values c notebooks cns))))

(deftest add-and-list-course-notebooks
  (testing "add-notebook-to-course! appends rows; list returns position-ordered"
    (with-test-db
      (let* ((u (create-test-user))
             (c (create-course! :title "C" :author u))
             (nb1 (create-user-notebook! :title "N1" :body-md "===prose===\nx"
                                         :cells '() :author u))
             (nb2 (create-user-notebook! :title "N2" :body-md "===prose===\ny"
                                         :cells '() :author u)))
        (add-notebook-to-course! (course-id c) (user-notebook-id nb1) :position 0)
        (add-notebook-to-course! (course-id c) (user-notebook-id nb2) :position 1)
        (let ((items (list-course-notebooks (course-id c))))
          (ok (= 2 (length items)))
          (ok (= 0 (course-notebook-position (first items))))
          (ok (= 1 (course-notebook-position (second items))))))))
  (testing "add without :position appends after the largest existing position"
    (with-test-db
      (let* ((u (create-test-user))
             (c (create-course! :title "Auto" :author u))
             (nb1 (create-user-notebook! :title "AA" :body-md "===prose===\nx"
                                         :cells '() :author u))
             (nb2 (create-user-notebook! :title "BB" :body-md "===prose===\ny"
                                         :cells '() :author u)))
        (let ((row1 (add-notebook-to-course! (course-id c) (user-notebook-id nb1)))
              (row2 (add-notebook-to-course! (course-id c) (user-notebook-id nb2))))
          (ok (= 0 (course-notebook-position row1)))
          (ok (= 1 (course-notebook-position row2))))))))

(deftest move-notebook-up-down
  (testing "move-up swaps adjacent rows"
    (with-test-db
      (multiple-value-bind (c notebooks cns) (%make-course-with-notebooks 3)
        (declare (ignore notebooks))
        (let ((middle (second cns)))
          (ok (eq t (move-notebook-up! (course-notebook-id middle))))
          (let ((items (list-course-notebooks (course-id c))))
            (ok (= 3 (length items)))
            ;; middle row (was N1) is now at pos 0, N0 at pos 1, N2 at pos 2
            (ok (equal (course-notebook-notebook-id (first items))
                       (course-notebook-notebook-id middle)))
            (ok (= 0 (course-notebook-position (first items))))
            (ok (= 1 (course-notebook-position (second items))))
            (ok (= 2 (course-notebook-position (third items)))))))))
  (testing "move-down swaps adjacent rows"
    (with-test-db
      (multiple-value-bind (c notebooks cns) (%make-course-with-notebooks 3)
        (declare (ignore notebooks))
        (let ((middle (second cns)))
          (ok (eq t (move-notebook-down! (course-notebook-id middle))))
          (let ((items (list-course-notebooks (course-id c))))
            (ok (= 3 (length items)))
            ;; middle row (was N1) is now at pos 2; N2 swaps to pos 1
            (ok (equal (course-notebook-notebook-id (third items))
                       (course-notebook-notebook-id middle)))
            (ok (= 2 (course-notebook-position (third items))))
            (ok (= 1 (course-notebook-position (second items))))
            (ok (= 0 (course-notebook-position (first items)))))))))
  (testing "move-up at top returns NIL"
    (with-test-db
      (multiple-value-bind (c notebooks cns) (%make-course-with-notebooks 3)
        (declare (ignore notebooks))
        (let* ((top (first cns))
               (result (move-notebook-up! (course-notebook-id top))))
          (ok (null result))
          (let ((items (list-course-notebooks (course-id c))))
            (ok (= 0 (course-notebook-position (first items))))
            (ok (equal (course-notebook-notebook-id top)
                       (course-notebook-notebook-id (first items)))))))))
  (testing "move-down at bottom returns NIL"
    (with-test-db
      (multiple-value-bind (c notebooks cns) (%make-course-with-notebooks 3)
        (declare (ignore notebooks))
        (let* ((bottom (third cns))
               (result (move-notebook-down! (course-notebook-id bottom))))
          (ok (null result))
          (let ((items (list-course-notebooks (course-id c))))
            (ok (= 2 (course-notebook-position (third items))))
            (ok (equal (course-notebook-notebook-id bottom)
                       (course-notebook-notebook-id (third items))))))))))

(deftest remove-notebook-from-course
  (testing "remove deletes the join row and returns T"
    (with-test-db
      (multiple-value-bind (c notebooks cns) (%make-course-with-notebooks 2)
        (declare (ignore cns))
        (let ((nb1-id (user-notebook-id (first notebooks))))
          (ok (eq t (remove-notebook-from-course! (course-id c) nb1-id)))
          (let ((items (list-course-notebooks (course-id c))))
            (ok (= 1 (length items)))
            (ok (equal (user-notebook-id (second notebooks))
                       (course-notebook-notebook-id (first items)))))))))
  (testing "remove returns NIL when no matching join row exists"
    (with-test-db
      (let* ((u (create-test-user))
             (c (create-course! :title "Solo" :author u))
             (nb (create-user-notebook! :title "Stray"
                                        :body-md "===prose===\nx"
                                        :cells '() :author u)))
        (ok (null (remove-notebook-from-course! (course-id c)
                                                (user-notebook-id nb))))))))

(deftest get-course-notebook-test
  (testing "get-course-notebook fetches by primary key"
    (with-test-db
      (multiple-value-bind (c notebooks cns) (%make-course-with-notebooks 1)
        (declare (ignore c notebooks))
        (let* ((row (first cns))
               (id (course-notebook-id row))
               (found (get-course-notebook id)))
          (ok found)
          (ok (= id (course-notebook-id found)))))))
  (testing "missing PK returns NIL"
    (with-test-db
      (ok (null (get-course-notebook -1))))))
