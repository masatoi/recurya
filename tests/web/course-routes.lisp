;;;; tests/web/course-routes.lisp --- Tests for course route handlers.

(defpackage #:recurya/tests/web/course-routes
  (:use #:cl
        #:rove)
  (:import-from #:recurya/tests/support/db
                #:with-test-db
                #:create-test-user)
  (:import-from #:recurya/web/routes
                #:courses-me-handler
                #:course-new-handler
                #:course-create-handler
                #:course-edit-handler
                #:course-update-handler
                #:course-toggle-status-handler
                #:course-confirm-delete-handler
                #:course-delete-handler)
  (:import-from #:recurya/db/users
                #:get-user-by-id
                #:users-id
                #:users-display-name)
  (:import-from #:recurya/db/courses
                #:create-course!
                #:get-course-by-id
                #:get-course-by-slug
                #:course-id
                #:course-title
                #:course-slug
                #:course-status
                #:course-published-at)
  (:import-from #:uuid
                #:make-v4-uuid))

(in-package #:recurya/tests/web/course-routes)

;;; --- helpers ---

(defmacro with-mock-session (session-hash &body body)
  `(let ((ningle/context:*session* ,session-hash))
     ,@body))

(defmacro with-mock-request ((&key htmx) &body body)
  "Bind ningle/context:*request* to a mock Lack request. When HTMX is true the
HX-Request header is included so htmx-request-p returns T."
  `(let* ((headers (make-hash-table :test 'equal))
          (env (append (list :request-method :get
                             :path-info "/test"
                             :headers headers)
                       (when ,htmx
                         (list :http-hx-request "true"))))
          (ningle/context:*request* (lack/request:make-request env)))
     ,@body))

(defun make-session (&key user)
  (let ((ht (make-hash-table)))
    (when user (setf (gethash :user ht) user))
    ht))

(defun response-status (response) (first response))
(defun response-headers (response) (second response))
(defun response-body (response) (third response))
(defun response-location (response)
  (getf (response-headers response) :location))

(defun mk-user ()
  "Create a test user and return the session plist used by handlers."
  (let ((dao (create-test-user :email-prefix "course-route")))
    (list :id (users-id dao)
          :email (format nil "course-route-~A@example.com" (make-v4-uuid))
          :name (users-display-name dao)
          :role :user
          :provider "google"
          :timezone "UTC"
          :language "en")))

;;; --- list ---

(deftest course-list-handler-redirects-anonymous
  (with-mock-session (make-session)
    (let ((res (courses-me-handler nil)))
      (ok (= 302 (response-status res)))
      (ok (string= "/login" (response-location res))))))

(deftest course-list-handler-shows-own-only
  (with-test-db
    (let* ((alice (mk-user))
           (bob   (mk-user))
           (alice-dao (get-user-by-id (getf alice :id)))
           (bob-dao   (get-user-by-id (getf bob :id))))
      (create-course! :title "Alice C" :author alice-dao)
      (create-course! :title "Bob C"   :author bob-dao)
      (with-mock-session (make-session :user alice)
        (let* ((res (courses-me-handler nil))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "Alice C" body))
          (ng (search "Bob C" body)))))))

;;; --- new ---

(deftest course-new-handler-redirects-anonymous
  (with-mock-session (make-session)
    (let ((res (course-new-handler nil)))
      (ok (= 302 (response-status res)))
      (ok (string= "/login" (response-location res))))))

(deftest course-new-handler-renders-form-for-user
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let ((res (course-new-handler nil)))
          (ok (= 200 (response-status res)))
          (ok (search "New Course" (first (response-body res)))))))))

;;; --- create ---

(deftest course-create-handler-redirects-anonymous
  (with-mock-session (make-session)
    (let ((res (course-create-handler '(("title" . "x")))))
      (ok (= 302 (response-status res)))
      (ok (string= "/login" (response-location res))))))

(deftest course-create-handler-rejects-blank-title
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let* ((res (course-create-handler
                     '(("title" . "") ("summary" . "s"))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "Title is required" body)))))))

(deftest course-create-handler-persists-and-redirects
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let* ((params '(("title" . "My Course")
                         ("slug" . "")
                         ("summary" . "Hello")
                         ("status" . "draft")))
               (res (course-create-handler params)))
          (ok (= 302 (response-status res)))
          (ok (string= "/courses/me" (response-location res)))
          (let ((c (get-course-by-slug "my-course")))
            (ok c)
            (ok (string= "My Course" (course-title c)))
            (ok (string= "draft" (course-status c)))))))))

(deftest course-create-handler-published-sets-published-at
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let ((params '(("title" . "Pub Course")
                        ("slug" . "")
                        ("summary" . "")
                        ("status" . "published"))))
          (course-create-handler params)
          (let ((c (get-course-by-slug "pub-course")))
            (ok c)
            (ok (string= "published" (course-status c)))
            (ok (course-published-at c))))))))

;;; --- edit ---

(deftest course-edit-handler-404-for-missing
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let ((res (course-edit-handler
                    '((:id . "00000000-0000-0000-0000-000000000000")))))
          (ok (= 404 (response-status res))))))))

(deftest course-edit-handler-403-for-non-owner
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user))
           (owner-dao (get-user-by-id (getf owner :id)))
           (c (create-course! :title "Owned" :author owner-dao))
           (id (princ-to-string (course-id c))))
      (with-mock-session (make-session :user other)
        (let ((res (course-edit-handler (list (cons :id id)))))
          (ok (= 403 (response-status res))))))))

(deftest course-edit-handler-renders-form-for-owner
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (c (create-course! :title "Mine" :author dao))
           (id (princ-to-string (course-id c))))
      (with-mock-session (make-session :user user)
        (let* ((res (course-edit-handler (list (cons :id id))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "Edit Course" body))
          (ok (search "Mine" body)))))))

;;; --- update ---

(deftest course-update-handler-403-for-non-owner
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user))
           (owner-dao (get-user-by-id (getf owner :id)))
           (c (create-course! :title "Owned" :author owner-dao))
           (id (princ-to-string (course-id c))))
      (with-mock-session (make-session :user other)
        (let ((res (course-update-handler
                    (list (cons :id id)
                          (cons "title" "Stolen")))))
          (ok (= 403 (response-status res))))))))

(deftest course-update-handler-persists-changes
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (c (create-course! :title "Before" :author dao))
           (id (princ-to-string (course-id c))))
      (with-mock-session (make-session :user user)
        (let ((res (course-update-handler
                    (list (cons :id id)
                          (cons "title" "After")
                          (cons "summary" "now")
                          (cons "status" "published")))))
          (ok (= 302 (response-status res)))
          (ok (string= "/courses/me" (response-location res)))
          (let ((updated (get-course-by-id id)))
            (ok (string= "After" (course-title updated)))
            (ok (string= "published" (course-status updated)))
            (ok (course-published-at updated))))))))

(deftest course-toggle-status-401-anonymous
  (with-mock-session (make-session)
    (let ((res (course-toggle-status-handler '((:id . "x")))))
      (ok (= 401 (response-status res))))))

(deftest course-toggle-status-404-missing
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let ((res (course-toggle-status-handler
                    '((:id . "00000000-0000-0000-0000-000000000000")))))
          (ok (= 404 (response-status res))))))))

(deftest course-toggle-status-403-non-owner
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user))
           (owner-dao (get-user-by-id (getf owner :id)))
           (c (create-course! :title "Owned" :author owner-dao))
           (id (princ-to-string (course-id c))))
      (with-mock-session (make-session :user other)
        (let ((res (course-toggle-status-handler (list (cons :id id)))))
          (ok (= 403 (response-status res))))))))

(deftest course-toggle-status-flips-and-sets-published-at
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (c (create-course! :title "T" :author dao))
           (id (princ-to-string (course-id c))))
      (with-mock-session (make-session :user user)
        (let ((res (course-toggle-status-handler (list (cons :id id)))))
          (ok (= 200 (response-status res)))
          (ok (search "data-status=published" (first (response-body res))))
          (let ((after (get-course-by-id id)))
            (ok (string= "published" (course-status after)))
            (ok (course-published-at after))))
        (let ((res2 (course-toggle-status-handler (list (cons :id id)))))
          (ok (= 200 (response-status res2)))
          (ok (search "data-status=draft" (first (response-body res2))))
          (let ((after (get-course-by-id id)))
            (ok (string= "draft" (course-status after)))
            (ok (course-published-at after)
                "published_at is preserved on un-publish")))))))

(deftest course-confirm-delete-401-anonymous
  (with-mock-session (make-session)
    (let ((res (course-confirm-delete-handler '((:id . "x")))))
      (ok (= 401 (response-status res))))))

(deftest course-confirm-delete-404-missing
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let ((res (course-confirm-delete-handler
                    '((:id . "00000000-0000-0000-0000-000000000000")))))
          (ok (= 404 (response-status res))))))))

(deftest course-confirm-delete-403-non-owner
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user))
           (owner-dao (get-user-by-id (getf owner :id)))
           (c (create-course! :title "Owned" :author owner-dao))
           (id (princ-to-string (course-id c))))
      (with-mock-session (make-session :user other)
        (let ((res (course-confirm-delete-handler (list (cons :id id)))))
          (ok (= 403 (response-status res))))))))

(deftest course-confirm-delete-renders-modal-for-owner
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (c (create-course! :title "Doomed" :author dao))
           (id (princ-to-string (course-id c))))
      (with-mock-session (make-session :user user)
        (let* ((res (course-confirm-delete-handler (list (cons :id id))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "modal-overlay" body))
          (ok (search "Delete this course?" body))
          (ok (search (format nil "hx-post=\"/courses/~A/delete\"" id) body))
          (ok (search "Delete course" body)))))))

(deftest course-delete-redirects-anonymous
  (with-mock-session (make-session)
    (let ((res (course-delete-handler '((:id . "x")))))
      (ok (= 302 (response-status res)))
      (ok (string= "/login" (response-location res))))))

(deftest course-delete-403-non-owner
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user))
           (owner-dao (get-user-by-id (getf owner :id)))
           (c (create-course! :title "Owned" :author owner-dao))
           (id (princ-to-string (course-id c))))
      (with-mock-session (make-session :user other)
        (with-mock-request (:htmx t)
          (let ((res (course-delete-handler (list (cons :id id)))))
            (ok (= 403 (response-status res)))))))))

(deftest course-delete-htmx-returns-oob-row
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (c (create-course! :title "Bye" :author dao))
           (id (princ-to-string (course-id c))))
      (with-mock-session (make-session :user user)
        (with-mock-request (:htmx t)
          (let* ((res (course-delete-handler (list (cons :id id))))
                 (body (first (response-body res))))
            (ok (= 200 (response-status res)))
            (ok (search (format nil "course-row-~A" id) body))
            (ok (search "hx-swap-oob" body))
            (ok (null (get-course-by-id id)))))))))

(deftest course-delete-non-htmx-redirects
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (c (create-course! :title "Bye" :author dao))
           (id (princ-to-string (course-id c))))
      (with-mock-session (make-session :user user)
        (with-mock-request (:htmx nil)
          (let ((res (course-delete-handler (list (cons :id id)))))
            (ok (= 302 (response-status res)))
            (ok (string= "/courses/me" (response-location res)))))))))
