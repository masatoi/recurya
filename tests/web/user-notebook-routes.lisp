;;;; tests/web/user-notebook-routes.lisp --- Tests for user-notebook route handlers.

(defpackage #:recurya/tests/web/user-notebook-routes
  (:use #:cl
        #:rove)
  (:import-from #:recurya/tests/support/db
                #:with-test-db
                #:create-test-user)
  (:import-from #:recurya/web/routes
                #:user-notebooks-handler
                #:user-notebook-new-handler
                #:user-notebook-create-handler
                #:user-notebook-edit-handler
                #:user-notebook-update-handler
                #:user-notebook-toggle-status-handler
                #:user-notebook-confirm-delete-handler
                #:user-notebook-delete-handler)
  (:import-from #:recurya/db/users
                #:get-user-by-id
                #:users-id
                #:users-display-name)
  (:import-from #:recurya/db/user-notebooks
                #:create-user-notebook!
                #:get-user-notebook-by-id
                #:get-user-notebook-by-slug
                #:user-notebook-id
                #:user-notebook-title
                #:user-notebook-body-md
                #:user-notebook-status)
  (:import-from #:uuid
                #:make-v4-uuid))

(in-package #:recurya/tests/web/user-notebook-routes)

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
                       (when ,htmx (list :http-hx-request "true"))))
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
  (let ((dao (create-test-user :email-prefix "nb-route")))
    (list :id (users-id dao)
          :email (format nil "nb-route-~A@example.com" (make-v4-uuid))
          :name (users-display-name dao)
          :role :user
          :provider "google"
          :timezone "UTC"
          :language "en")))

;;; --- new / create ---

(deftest new-handler-redirects-anonymous
  (with-mock-session (make-session)
    (let ((res (user-notebook-new-handler nil)))
      (ok (= 302 (response-status res)))
      (ok (string= "/login" (response-location res))))))

(deftest new-handler-renders-form-for-user
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let ((res (user-notebook-new-handler nil)))
          (ok (= 200 (response-status res)))
          (ok (search "New Notebook" (first (response-body res)))))))))

(deftest create-handler-redirects-anonymous
  (with-mock-session (make-session)
    (let ((res (user-notebook-create-handler '(("title" . "x")))))
      (ok (= 302 (response-status res)))
      (ok (string= "/login" (response-location res))))))

(deftest create-handler-rejects-blank-title
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let* ((res (user-notebook-create-handler
                     '(("title" . "") ("body" . "===prose===
hi"))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "Title is required" body)))))))

(deftest create-handler-rejects-blank-body
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let* ((res (user-notebook-create-handler
                     '(("title" . "T1") ("body" . ""))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "Body is required" body)))))))

(deftest create-handler-shows-parser-errors
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let* ((res (user-notebook-create-handler
                     '(("title" . "Bad") ("body" . "===banana===
peel"))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "Validation errors" body)))))))

(deftest create-handler-persists-and-redirects
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let* ((params '(("title" . "My NB")
                         ("slug" . "")
                         ("summary" . "")
                         ("body" . "===prose===
Hello.")
                         ("status" . "draft")))
               (res (user-notebook-create-handler params)))
          (ok (= 302 (response-status res)))
          (ok (string= "/notebooks/me" (response-location res)))
          (let ((nb (get-user-notebook-by-slug "my-nb")))
            (ok nb)
            (ok (string= "My NB" (user-notebook-title nb)))
            (ok (string= "draft" (user-notebook-status nb)))))))))

(deftest create-handler-published-sets-published-at
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let ((params '(("title" . "Pub NB")
                        ("slug" . "")
                        ("summary" . "")
                        ("body" . "===prose===
hi")
                        ("status" . "published"))))
          (user-notebook-create-handler params)
          (let ((nb (get-user-notebook-by-slug "pub-nb")))
            (ok nb)
            (ok (string= "published" (user-notebook-status nb)))
            (ok (recurya/db/user-notebooks:user-notebook-published-at nb))))))))

;;; --- listing ---

(deftest list-handler-redirects-anonymous
  (with-mock-session (make-session)
    (let ((res (user-notebooks-handler nil)))
      (ok (= 302 (response-status res)))
      (ok (string= "/login" (response-location res))))))

(deftest list-handler-shows-own-only
  (with-test-db
    (let* ((alice (mk-user))
           (bob   (mk-user))
           (alice-dao (get-user-by-id (getf alice :id)))
           (bob-dao   (get-user-by-id (getf bob :id))))
      (create-user-notebook!
       :title "Alice NB" :body-md "===prose===
a" :cells '() :author alice-dao)
      (create-user-notebook!
       :title "Bob NB"   :body-md "===prose===
b" :cells '() :author bob-dao)
      (with-mock-session (make-session :user alice)
        (let* ((res (user-notebooks-handler nil))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "Alice NB" body))
          (ng (search "Bob NB" body)))))))

;;; --- edit / update ---

(deftest edit-handler-404-for-missing
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let ((res (user-notebook-edit-handler
                    '((:id . "00000000-0000-0000-0000-000000000000")))))
          (ok (= 404 (response-status res))))))))

(deftest edit-handler-403-for-non-owner
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user))
           (owner-dao (get-user-by-id (getf owner :id)))
           (nb (create-user-notebook! :title "Owned"
                                       :body-md "===prose===
hi"
                                       :cells '()
                                       :author owner-dao))
           (id (princ-to-string (user-notebook-id nb))))
      (with-mock-session (make-session :user other)
        (let ((res (user-notebook-edit-handler (list (cons :id id)))))
          (ok (= 403 (response-status res))))))))

(deftest edit-handler-renders-form-for-owner
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (nb (create-user-notebook! :title "Mine"
                                       :body-md "===prose===
hi"
                                       :cells '()
                                       :author dao))
           (id (princ-to-string (user-notebook-id nb))))
      (with-mock-session (make-session :user user)
        (let* ((res (user-notebook-edit-handler (list (cons :id id))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "Edit Notebook" body))
          (ok (search "Mine" body)))))))

(deftest update-handler-403-for-non-owner
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user))
           (owner-dao (get-user-by-id (getf owner :id)))
           (nb (create-user-notebook! :title "Owned"
                                       :body-md "===prose===
hi"
                                       :cells '()
                                       :author owner-dao))
           (id (princ-to-string (user-notebook-id nb))))
      (with-mock-session (make-session :user other)
        (let ((res (user-notebook-update-handler
                    (list (cons :id id)
                          (cons "title" "Stolen")
                          (cons "body" "===prose===
new")))))
          (ok (= 403 (response-status res))))))))

(deftest update-handler-persists-changes
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (nb (create-user-notebook! :title "Before"
                                       :body-md "===prose===
old"
                                       :cells '()
                                       :author dao))
           (id (princ-to-string (user-notebook-id nb))))
      (with-mock-session (make-session :user user)
        (let* ((res (user-notebook-update-handler
                     (list (cons :id id)
                           (cons "title" "After")
                           (cons "body" "===prose===
new")
                           (cons "status" "published")))))
          (ok (= 302 (response-status res)))
          (ok (string= "/notebooks/me" (response-location res)))
          (let ((updated (get-user-notebook-by-id id)))
            (ok (string= "After" (user-notebook-title updated)))
            (ok (search "new" (user-notebook-body-md updated)))
            (ok (string= "published" (user-notebook-status updated)))))))))

(deftest update-handler-shows-parser-errors
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (nb (create-user-notebook! :title "Before"
                                       :body-md "===prose===
ok"
                                       :cells '()
                                       :author dao))
           (id (princ-to-string (user-notebook-id nb))))
      (with-mock-session (make-session :user user)
        (let* ((res (user-notebook-update-handler
                     (list (cons :id id)
                           (cons "title" "T")
                           (cons "body" "===banana===
nope"))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "Validation errors" body))
          (let ((nb-after (get-user-notebook-by-id id)))
            (ok (string= "Before" (user-notebook-title nb-after)))))))))

(deftest update-handler-preserves-cell-ids-on-rewrite
  (testing "rewriting unchanged body keeps stable cell ids in the JSONB cache"
    (with-test-db
      (let* ((user (mk-user))
             (dao (get-user-by-id (getf user :id)))
             (body "===prose===
Stable.

===eval===
(+ 1 2)")
             (cells-on-create
              (mapcar #'recurya/web/routes::cell->jsonb-form
                      (recurya/game/notebook-parser:parse-notebook-body body)))
             (nb (create-user-notebook!
                  :title "Stable" :body-md body
                  :cells cells-on-create :author dao))
             (id (princ-to-string (user-notebook-id nb)))
             (cells-before (recurya/db/user-notebooks:user-notebook-cells-parsed
                            (get-user-notebook-by-id id))))
        (with-mock-session (make-session :user user)
          (user-notebook-update-handler
           (list (cons :id id)
                 (cons "title" "Stable")
                 (cons "body" body))))
        (let ((cells-after
               (recurya/db/user-notebooks:user-notebook-cells-parsed
                (get-user-notebook-by-id id))))
          (ok (= (length cells-before) (length cells-after)))
          (ok (equalp cells-before cells-after)))))))

(deftest toggle-status-401-anonymous
  (with-mock-session (make-session)
    (let ((res (user-notebook-toggle-status-handler '((:id . "x")))))
      (ok (= 401 (response-status res))))))

(deftest toggle-status-404-missing
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let ((res (user-notebook-toggle-status-handler
                    '((:id . "00000000-0000-0000-0000-000000000000")))))
          (ok (= 404 (response-status res))))))))

(deftest toggle-status-403-non-owner
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user))
           (owner-dao (get-user-by-id (getf owner :id)))
           (nb (create-user-notebook! :title "Owned"
                                       :body-md "===prose===
hi"
                                       :cells '() :author owner-dao))
           (id (princ-to-string (user-notebook-id nb))))
      (with-mock-session (make-session :user other)
        (let ((res (user-notebook-toggle-status-handler (list (cons :id id)))))
          (ok (= 403 (response-status res))))))))

(deftest toggle-status-flips-and-sets-published-at
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (nb (create-user-notebook! :title "T"
                                       :body-md "===prose===
hi"
                                       :cells '() :author dao))
           (id (princ-to-string (user-notebook-id nb))))
      (with-mock-session (make-session :user user)
        (let ((res (user-notebook-toggle-status-handler (list (cons :id id)))))
          (ok (= 200 (response-status res)))
          (ok (search "data-status=published" (first (response-body res))))
          (let ((after (get-user-notebook-by-id id)))
            (ok (string= "published" (user-notebook-status after)))
            (ok (recurya/db/user-notebooks:user-notebook-published-at after))))
        (let ((res2 (user-notebook-toggle-status-handler (list (cons :id id)))))
          (ok (= 200 (response-status res2)))
          (ok (search "data-status=draft" (first (response-body res2))))
          (let ((after (get-user-notebook-by-id id)))
            (ok (string= "draft" (user-notebook-status after)))
            (ok (recurya/db/user-notebooks:user-notebook-published-at after)
                "published_at is preserved on un-publish")))))))

(deftest confirm-delete-401-anonymous
  (with-mock-session (make-session)
    (let ((res (user-notebook-confirm-delete-handler '((:id . "x")))))
      (ok (= 401 (response-status res))))))

(deftest confirm-delete-404-missing
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let ((res (user-notebook-confirm-delete-handler
                    '((:id . "00000000-0000-0000-0000-000000000000")))))
          (ok (= 404 (response-status res))))))))

(deftest confirm-delete-403-non-owner
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user))
           (owner-dao (get-user-by-id (getf owner :id)))
           (nb (create-user-notebook! :title "Owned"
                                       :body-md "===prose===
hi"
                                       :cells '() :author owner-dao))
           (id (princ-to-string (user-notebook-id nb))))
      (with-mock-session (make-session :user other)
        (let ((res (user-notebook-confirm-delete-handler (list (cons :id id)))))
          (ok (= 403 (response-status res))))))))

(deftest confirm-delete-renders-modal-for-owner
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (nb (create-user-notebook! :title "Doomed"
                                       :body-md "===prose===
hi"
                                       :cells '() :author dao))
           (id (princ-to-string (user-notebook-id nb))))
      (with-mock-session (make-session :user user)
        (let* ((res (user-notebook-confirm-delete-handler (list (cons :id id))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "modal-overlay" body))
          (ok (search "Delete this notebook?" body))
          (ok (search (format nil "hx-post=\"/notebooks/~A/delete\"" id) body))
          (ok (search "Delete notebook" body)))))))

(deftest delete-redirects-anonymous
  (with-mock-session (make-session)
    (let ((res (user-notebook-delete-handler '((:id . "x")))))
      (ok (= 302 (response-status res)))
      (ok (string= "/login" (response-location res))))))

(deftest delete-403-non-owner
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user))
           (owner-dao (get-user-by-id (getf owner :id)))
           (nb (create-user-notebook! :title "Owned"
                                       :body-md "===prose===
hi"
                                       :cells '() :author owner-dao))
           (id (princ-to-string (user-notebook-id nb))))
      (with-mock-session (make-session :user other)
        (with-mock-request (:htmx t)
          (let ((res (user-notebook-delete-handler (list (cons :id id)))))
            (ok (= 403 (response-status res)))))))))

(deftest delete-htmx-returns-oob-row
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (nb (create-user-notebook! :title "Bye"
                                       :body-md "===prose===
hi"
                                       :cells '() :author dao))
           (id (princ-to-string (user-notebook-id nb))))
      (with-mock-session (make-session :user user)
        (with-mock-request (:htmx t)
          (let* ((res (user-notebook-delete-handler (list (cons :id id))))
                 (body (first (response-body res))))
            (ok (= 200 (response-status res)))
            (ok (search (format nil "nb-row-~A" id) body))
            (ok (search "hx-swap-oob" body))
            (ok (null (get-user-notebook-by-id id)))))))))

(deftest delete-non-htmx-redirects
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (nb (create-user-notebook! :title "Bye"
                                       :body-md "===prose===
hi"
                                       :cells '() :author dao))
           (id (princ-to-string (user-notebook-id nb))))
      (with-mock-session (make-session :user user)
        (with-mock-request (:htmx nil)
          (let ((res (user-notebook-delete-handler (list (cons :id id)))))
            (ok (= 302 (response-status res)))
            (ok (string= "/notebooks/me" (response-location res)))))))))
