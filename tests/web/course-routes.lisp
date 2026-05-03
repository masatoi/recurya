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
                #:course-delete-handler
                #:course-add-notebook-handler
                #:course-notebook-move-up-handler
                #:course-notebook-move-down-handler
                #:course-notebook-remove-handler
                #:public-course-handler
                #:courses-public-handler)
  (:import-from #:recurya/db/user-notebooks
                #:create-user-notebook!
                #:user-notebook-id
                #:user-notebook-title)
  (:import-from #:recurya/db/course-notebooks
                #:add-notebook-to-course!
                #:list-course-notebooks
                #:course-notebook-id
                #:course-notebook-notebook-id
                #:course-notebook-position)
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
                #:course-summary
                #:course-status
                #:course-visibility
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

(deftest course-new-handler-form-has-visibility-select
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let* ((res (course-new-handler nil))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "name=visibility" body))
          (ok (search "value=private" body))
          (ok (search "value=public" body)))))))

(deftest course-create-handler-persists-visibility-public
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let ((params '(("title" . "Vis Course")
                        ("slug" . "")
                        ("summary" . "")
                        ("status" . "published")
                        ("visibility" . "public"))))
          (course-create-handler params)
          (let ((c (get-course-by-slug "vis-course")))
            (ok c)
            (ok (string= "public" (course-visibility c)))))))))

(deftest course-create-handler-defaults-visibility-private
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let ((params '(("title" . "Default Priv C")
                        ("slug" . "")
                        ("summary" . "")
                        ("status" . "draft"))))
          (course-create-handler params)
          (let ((c (get-course-by-slug "default-priv-c")))
            (ok c)
            (ok (string= "private" (course-visibility c)))))))))

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

(deftest course-edit-handler-form-shows-existing-visibility
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (c (create-course! :title "Public C"
                              :status "published"
                              :visibility "public"
                              :published-at (local-time:now)
                              :author dao))
           (id (princ-to-string (course-id c))))
      (with-mock-session (make-session :user user)
        (let* ((res (course-edit-handler (list (cons :id id))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "name=visibility" body))
          (let* ((vis-pos (search "name=visibility" body))
                 (segment (and vis-pos (subseq body vis-pos
                                               (min (length body)
                                                    (+ vis-pos 400))))))
            (ok segment)
            (ok (search "value=public selected" segment))))))))

(deftest course-edit-handler-eligible-list-excludes-private-notebook
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (c (create-course! :title "Mine" :author dao))
           (id (princ-to-string (course-id c))))
      (create-user-notebook!
       :title "EligPub"
       :body-md (format nil "===prose===~%hi")
       :cells nil :status "published" :visibility "public"
       :published-at (local-time:now) :author dao)
      (create-user-notebook!
       :title "EligPriv"
       :body-md (format nil "===prose===~%shh")
       :cells nil :status "published" :visibility "private"
       :published-at (local-time:now) :author dao)
      (with-mock-session (make-session :user user)
        (let* ((res (course-edit-handler (list (cons :id id))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "EligPub" body))
          (ng (search "EligPriv" body)))))))

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

(deftest course-update-handler-persists-visibility
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (c (create-course! :title "Vis"
                              :status "published"
                              :visibility "private"
                              :published-at (local-time:now)
                              :author dao))
           (id (princ-to-string (course-id c))))
      (with-mock-session (make-session :user user)
        (let ((res (course-update-handler
                    (list (cons :id id)
                          (cons "title" "Vis")
                          (cons "status" "published")
                          (cons "visibility" "public")))))
          (ok (= 302 (response-status res)))
          (let ((after (get-course-by-id id)))
            (ok (string= "public" (course-visibility after)))))))))

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

(deftest course-add-notebook-401-anonymous
  (with-mock-session (make-session)
    (let ((res (course-add-notebook-handler
                '((:id . "00000000-0000-0000-0000-000000000000")
                  ("notebook_id" . "x")))))
      (ok (= 401 (response-status res))))))

(deftest course-add-notebook-404-missing-course
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let ((res (course-add-notebook-handler
                    '((:id . "00000000-0000-0000-0000-000000000000")
                      ("notebook_id" . "x")))))
          (ok (= 404 (response-status res))))))))

(deftest course-add-notebook-403-non-owner
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user))
           (owner-dao (get-user-by-id (getf owner :id)))
           (c (create-course! :title "Owned" :author owner-dao))
           (id (princ-to-string (course-id c))))
      (with-mock-session (make-session :user other)
        (let ((res (course-add-notebook-handler
                    (list (cons :id id)
                          (cons "notebook_id" "x")))))
          (ok (= 403 (response-status res))))))))

(deftest course-add-notebook-attaches-and-renders-list
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (c (create-course! :title "Course" :author dao))
           (course-uuid (course-id c))
           (course-id-str (princ-to-string course-uuid))
           (nb (create-user-notebook!
                :title "Attachable"
                :body-md "===prose===
hi"
                :cells nil
                :status "published"
                :published-at (local-time:now)
                :author dao))
           (nb-id-str (princ-to-string (user-notebook-id nb))))
      (with-mock-session (make-session :user user)
        (let* ((res (course-add-notebook-handler
                     (list (cons :id course-id-str)
                           (cons "notebook_id" nb-id-str))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "course-notebooks-list" body))
          (ok (search "Attachable" body))
          (let ((rows (list-course-notebooks course-uuid)))
            (ok (= 1 (length rows)))))))))

(deftest course-add-notebook-rejects-duplicate
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (c (create-course! :title "Course" :author dao))
           (course-uuid (course-id c))
           (course-id-str (princ-to-string course-uuid))
           (nb (create-user-notebook!
                :title "Once"
                :body-md "===prose===
hi"
                :cells nil
                :status "published"
                :published-at (local-time:now)
                :author dao))
           (nb-id-str (princ-to-string (user-notebook-id nb))))
      (add-notebook-to-course! course-uuid (user-notebook-id nb))
      (with-mock-session (make-session :user user)
        (let* ((res (course-add-notebook-handler
                     (list (cons :id course-id-str)
                           (cons "notebook_id" nb-id-str))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "already attached" body))
          (let ((rows (list-course-notebooks course-uuid)))
            (ok (= 1 (length rows)))))))))

(defun %attach-n-notebooks (n &key user)
  "Create COURSE owned by USER and attach N user-notebooks at positions 0..N-1.

Returns (values course-id-uuid course-id-str (list cn-id ...) (list nb-id-str ...))
where the lists are aligned with the attached positions."
  (let* ((dao (get-user-by-id (getf user :id)))
         (c (create-course! :title "Course" :author dao))
         (course-uuid (course-id c))
         (course-id-str (princ-to-string course-uuid))
         (nbs (loop for i from 0 below n
                    collect (create-user-notebook!
                             :title (format nil "N~D" i)
                             :body-md (format nil "===prose===~%body~D" i)
                             :cells nil
                             :status "published"
                             :published-at (local-time:now)
                             :author dao))))
    (loop for nb in nbs
          for i from 0
          do (add-notebook-to-course! course-uuid (user-notebook-id nb)
                                      :position i))
    (let* ((rows (list-course-notebooks course-uuid))
           (cn-ids (mapcar #'course-notebook-id rows))
           (nb-id-strs
             (mapcar (lambda (nb) (princ-to-string (user-notebook-id nb))) nbs)))
      (values course-uuid course-id-str cn-ids nb-id-strs))))

(deftest course-notebook-move-up-401-anonymous
  (with-mock-session (make-session)
    (let ((res (course-notebook-move-up-handler
                '((:id . "00000000-0000-0000-0000-000000000000")
                  (:cn-id . "1")))))
      (ok (= 401 (response-status res))))))

(deftest course-notebook-move-up-403-non-owner
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user)))
      (multiple-value-bind (course-uuid course-id-str cn-ids nb-ids)
          (%attach-n-notebooks 2 :user owner)
        (declare (ignore course-uuid nb-ids))
        (with-mock-session (make-session :user other)
          (let ((res (course-notebook-move-up-handler
                      (list (cons :id course-id-str)
                            (cons :cn-id (princ-to-string (second cn-ids)))))))
            (ok (= 403 (response-status res)))))))))

(deftest course-notebook-move-up-swaps-positions
  (with-test-db
    (let ((user (mk-user)))
      (multiple-value-bind (course-uuid course-id-str cn-ids nb-ids)
          (%attach-n-notebooks 3 :user user)
        (declare (ignore nb-ids))
        (with-mock-session (make-session :user user)
          ;; Move position 2 (third notebook) up -> ends up at position 1.
          (let* ((target (third cn-ids))
                 (res (course-notebook-move-up-handler
                       (list (cons :id course-id-str)
                             (cons :cn-id (princ-to-string target))))))
            (ok (= 200 (response-status res)))
            (ok (search "course-notebooks-list" (first (response-body res))))
            (let* ((rows (list-course-notebooks course-uuid))
                   (positions
                    (mapcar (lambda (r)
                              (cons (course-notebook-id r)
                                    (course-notebook-position r)))
                            rows)))
              (ok (= 0 (cdr (assoc (first cn-ids) positions))))
              (ok (= 2 (cdr (assoc (second cn-ids) positions))))
              (ok (= 1 (cdr (assoc (third cn-ids) positions)))))))))))

(deftest course-notebook-move-up-noop-at-top
  (with-test-db
    (let ((user (mk-user)))
      (multiple-value-bind (course-uuid course-id-str cn-ids nb-ids)
          (%attach-n-notebooks 3 :user user)
        (declare (ignore nb-ids))
        (with-mock-session (make-session :user user)
          (let ((res (course-notebook-move-up-handler
                      (list (cons :id course-id-str)
                            (cons :cn-id (princ-to-string (first cn-ids)))))))
            (ok (= 200 (response-status res)))
            (let* ((rows (list-course-notebooks course-uuid))
                   (positions
                    (mapcar (lambda (r)
                              (cons (course-notebook-id r)
                                    (course-notebook-position r)))
                            rows)))
              (ok (= 0 (cdr (assoc (first cn-ids) positions))))
              (ok (= 1 (cdr (assoc (second cn-ids) positions))))
              (ok (= 2 (cdr (assoc (third cn-ids) positions)))))))))))

(deftest course-notebook-move-down-swaps-positions
  (with-test-db
    (let ((user (mk-user)))
      (multiple-value-bind (course-uuid course-id-str cn-ids nb-ids)
          (%attach-n-notebooks 3 :user user)
        (declare (ignore nb-ids))
        (with-mock-session (make-session :user user)
          ;; Move position 0 (first notebook) down -> ends up at position 1.
          (let* ((target (first cn-ids))
                 (res (course-notebook-move-down-handler
                       (list (cons :id course-id-str)
                             (cons :cn-id (princ-to-string target))))))
            (ok (= 200 (response-status res)))
            (ok (search "course-notebooks-list" (first (response-body res))))
            (let* ((rows (list-course-notebooks course-uuid))
                   (positions
                    (mapcar (lambda (r)
                              (cons (course-notebook-id r)
                                    (course-notebook-position r)))
                            rows)))
              (ok (= 1 (cdr (assoc (first cn-ids) positions))))
              (ok (= 0 (cdr (assoc (second cn-ids) positions))))
              (ok (= 2 (cdr (assoc (third cn-ids) positions)))))))))))

(deftest course-notebook-move-down-noop-at-bottom
  (with-test-db
    (let ((user (mk-user)))
      (multiple-value-bind (course-uuid course-id-str cn-ids nb-ids)
          (%attach-n-notebooks 3 :user user)
        (declare (ignore nb-ids))
        (with-mock-session (make-session :user user)
          (let ((res (course-notebook-move-down-handler
                      (list (cons :id course-id-str)
                            (cons :cn-id (princ-to-string (third cn-ids)))))))
            (ok (= 200 (response-status res)))
            (let* ((rows (list-course-notebooks course-uuid))
                   (positions
                    (mapcar (lambda (r)
                              (cons (course-notebook-id r)
                                    (course-notebook-position r)))
                            rows)))
              (ok (= 0 (cdr (assoc (first cn-ids) positions))))
              (ok (= 1 (cdr (assoc (second cn-ids) positions))))
              (ok (= 2 (cdr (assoc (third cn-ids) positions)))))))))))

(deftest course-notebook-remove-401-anonymous
  (with-mock-session (make-session)
    (let ((res (course-notebook-remove-handler
                '((:id . "00000000-0000-0000-0000-000000000000")
                  (:cn-id . "1")))))
      (ok (= 401 (response-status res))))))

(deftest course-notebook-remove-403-non-owner
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user)))
      (multiple-value-bind (course-uuid course-id-str cn-ids nb-ids)
          (%attach-n-notebooks 1 :user owner)
        (declare (ignore course-uuid nb-ids))
        (with-mock-session (make-session :user other)
          (let ((res (course-notebook-remove-handler
                      (list (cons :id course-id-str)
                            (cons :cn-id
                                  (princ-to-string (first cn-ids)))))))
            (ok (= 403 (response-status res)))))))))

(deftest course-notebook-remove-deletes-and-rerenders
  (with-test-db
    (let ((user (mk-user)))
      (multiple-value-bind (course-uuid course-id-str cn-ids nb-ids)
          (%attach-n-notebooks 2 :user user)
        (declare (ignore nb-ids))
        (with-mock-session (make-session :user user)
          (let* ((target (first cn-ids))
                 (res (course-notebook-remove-handler
                       (list (cons :id course-id-str)
                             (cons :cn-id (princ-to-string target)))))
                 (body (first (response-body res))))
            (ok (= 200 (response-status res)))
            (ok (search "course-notebooks-list" body))
            ;; N0 is gone from the attached <li> rows but reappears as an
            ;; eligible <option>. Check it no longer carries an nb-title span.
            (ng (search "<span class=nb-title>N0" body))
            (ok (search "<span class=nb-title>N1" body))
            (let ((rows (list-course-notebooks course-uuid)))
              (ok (= 1 (length rows)))
              (ok (= (second cn-ids)
                     (course-notebook-id (first rows)))))))))))

(deftest public-course-handler-404-missing
  (with-test-db
    (with-mock-session (make-session)
      (let ((res (public-course-handler '((:slug . "no-such-course")))))
        (ok (= 404 (response-status res)))))))

(deftest public-course-handler-200-published-anonymous
  (with-test-db
    (let* ((author (mk-user))
           (dao (get-user-by-id (getf author :id)))
           (course (create-course! :title "Public Course"
                                   :summary "Course summary text."
                                   :status "published"
                                   :visibility "public"
                                   :published-at (local-time:now)
                                   :author dao))
           (slug (course-slug course))
           (nb (create-user-notebook!
                :title "Attached Notebook"
                :body-md (format nil "===prose===~%hi")
                :cells nil
                :status "published"
                :published-at (local-time:now)
                :author dao)))
      (add-notebook-to-course! (course-id course) (user-notebook-id nb))
      (with-mock-session (make-session)
        (let* ((res (public-course-handler (list (cons :slug slug))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "Public Course" body))
          (ok (search "Course summary text." body))
          (ok (search "attached-notebook" body))
          (ok (search "Attached" body)))))))

(deftest public-course-handler-404-draft-other-user
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user))
           (owner-dao (get-user-by-id (getf owner :id)))
           (course (create-course! :title "Draft Course"
                                   :status "draft"
                                   :author owner-dao))
           (slug (course-slug course)))
      (with-mock-session (make-session :user other)
        (let ((res (public-course-handler (list (cons :slug slug)))))
          (ok (= 404 (response-status res))))))))

(deftest public-course-handler-200-draft-owner
  (with-test-db
    (let* ((owner (mk-user))
           (owner-dao (get-user-by-id (getf owner :id)))
           (course (create-course! :title "Owner Draft"
                                   :status "draft"
                                   :author owner-dao))
           (slug (course-slug course)))
      (with-mock-session (make-session :user owner)
        (let* ((res (public-course-handler (list (cons :slug slug))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "Owner Draft" body)))))))

(deftest public-course-handler-published-private-404-for-others
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user))
           (owner-dao (get-user-by-id (getf owner :id)))
           (course (create-course! :title "Pub Priv Course"
                                   :status "published"
                                   :visibility "private"
                                   :published-at (local-time:now)
                                   :author owner-dao))
           (slug (course-slug course)))
      (with-mock-session (make-session :user other)
        (let ((res (public-course-handler (list (cons :slug slug)))))
          (ok (= 404 (response-status res)))))
      (with-mock-session (make-session)
        (let ((res (public-course-handler (list (cons :slug slug)))))
          (ok (= 404 (response-status res))))))))

(deftest public-course-handler-published-private-200-for-owner
  (with-test-db
    (let* ((owner (mk-user))
           (owner-dao (get-user-by-id (getf owner :id)))
           (course (create-course! :title "Owner Pub Priv"
                                   :status "published"
                                   :visibility "private"
                                   :published-at (local-time:now)
                                   :author owner-dao))
           (slug (course-slug course)))
      (with-mock-session (make-session :user owner)
        (let* ((res (public-course-handler (list (cons :slug slug))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "Owner Pub Priv" body)))))))

(deftest public-course-handler-shows-attached-notebooks-in-order
  (with-test-db
    (let* ((author (mk-user))
           (dao (get-user-by-id (getf author :id)))
           (course (create-course! :title "Ordered"
                                   :status "published"
                                   :visibility "public"
                                   :published-at (local-time:now)
                                   :author dao))
           (course-uuid (course-id course))
           (slug (course-slug course))
           (nb-a (create-user-notebook!
                  :title "Notebook-A"
                  :body-md (format nil "===prose===~%a")
                  :cells nil
                  :status "published"
                  :published-at (local-time:now)
                  :author dao))
           (nb-b (create-user-notebook!
                  :title "Notebook-B"
                  :body-md (format nil "===prose===~%b")
                  :cells nil
                  :status "published"
                  :published-at (local-time:now)
                  :author dao))
           (nb-c (create-user-notebook!
                  :title "Notebook-C"
                  :body-md (format nil "===prose===~%c")
                  :cells nil
                  :status "published"
                  :published-at (local-time:now)
                  :author dao)))
      (add-notebook-to-course! course-uuid (user-notebook-id nb-a) :position 0)
      (add-notebook-to-course! course-uuid (user-notebook-id nb-b) :position 1)
      (add-notebook-to-course! course-uuid (user-notebook-id nb-c) :position 2)
      (with-mock-session (make-session)
        (let* ((res (public-course-handler (list (cons :slug slug))))
               (body (first (response-body res)))
               (pa (search "Notebook-A" body))
               (pb (search "Notebook-B" body))
               (pc (search "Notebook-C" body)))
          (ok (= 200 (response-status res)))
          (ok pa)
          (ok pb)
          (ok pc)
          (ok (and pa pb (< pa pb)))
          (ok (and pb pc (< pb pc))))))))

(deftest courses-public-handler-shows-published-only
  (with-test-db
    (let* ((author (mk-user))
           (dao (get-user-by-id (getf author :id))))
      (create-course! :title "Pub Course"
                      :status "published"
                      :visibility "public"
                      :published-at (local-time:now)
                      :author dao)
      (create-course! :title "Drafty Course"
                      :status "draft"
                      :author dao)
      (with-mock-session (make-session)
        (let* ((res (courses-public-handler nil))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "Pub Course" body))
          (ng (search "Drafty Course" body)))))))

(deftest courses-public-handler-shows-only-public
  (with-test-db
    (let* ((author (mk-user))
           (dao (get-user-by-id (getf author :id))))
      (create-course! :title "PubPub Course"
                      :status "published" :visibility "public"
                      :published-at (local-time:now) :author dao)
      (create-course! :title "PubPriv Course"
                      :status "published" :visibility "private"
                      :published-at (local-time:now) :author dao)
      (with-mock-session (make-session)
        (let* ((res (courses-public-handler nil))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "PubPub Course" body))
          (ng (search "PubPriv Course" body)))))))

(deftest courses-public-handler-anonymous-200
  (with-test-db
    (with-mock-session (make-session)
      (let ((res (courses-public-handler nil)))
        (ok (= 200 (response-status res)))
        (ok (search "Courses" (first (response-body res))))))))

(deftest courses-public-handler-includes-slug-link
  (with-test-db
    (let* ((author (mk-user))
           (dao (get-user-by-id (getf author :id)))
           (course (create-course! :title "Slug Linked"
                                   :status "published"
                                   :visibility "public"
                                   :published-at (local-time:now)
                                   :author dao))
           (slug (course-slug course)))
      (with-mock-session (make-session)
        (let* ((res (courses-public-handler nil))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search (format nil "/c/~A" slug) body)))))))

(deftest courses-public-handler-empty-state
  (with-test-db
    (with-mock-session (make-session)
      (let* ((res (courses-public-handler nil))
             (body (first (response-body res))))
        (ok (= 200 (response-status res)))
        (ok (search "No courses yet" body))))))
