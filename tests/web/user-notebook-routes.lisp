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
                #:user-notebook-delete-handler
                #:notebooks-public-handler
                #:public-user-notebook-handler
                #:public-user-notebook-cell-run-handler)
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
                #:user-notebook-status
                #:user-notebook-visibility)
  (:import-from #:recurya/db/courses
                #:create-course!
                #:course-id
                #:course-slug
                #:course-title)
  (:import-from #:recurya/db/course-notebooks
                #:add-notebook-to-course!)
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

(deftest new-handler-form-has-visibility-select
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let* ((res (user-notebook-new-handler nil))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "name=visibility" body)
              "form has a visibility select")
          (ok (search "value=private" body)
              "private option is rendered")
          (ok (search "value=public" body)
              "public option is rendered"))))))

(deftest create-handler-persists-visibility-public
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let ((params '(("title" . "Vis NB")
                        ("slug" . "")
                        ("summary" . "")
                        ("body" . "===prose===
hi")
                        ("status" . "published")
                        ("visibility" . "public"))))
          (user-notebook-create-handler params)
          (let ((nb (get-user-notebook-by-slug "vis-nb")))
            (ok nb)
            (ok (string= "public" (user-notebook-visibility nb)))))))))

(deftest create-handler-defaults-visibility-private
  (with-test-db
    (let ((user (mk-user)))
      (with-mock-session (make-session :user user)
        (let ((params '(("title" . "Default Priv")
                        ("slug" . "")
                        ("summary" . "")
                        ("body" . "===prose===
hi")
                        ("status" . "draft"))))
          (user-notebook-create-handler params)
          (let ((nb (get-user-notebook-by-slug "default-priv")))
            (ok nb)
            (ok (string= "private" (user-notebook-visibility nb))
                "absent visibility param defaults to private")))))))

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

(deftest edit-handler-form-shows-existing-visibility
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (nb (create-user-notebook!
                :title "Public NB"
                :body-md "===prose===
hi"
                :cells '() :author dao
                :status "published" :visibility "public"
                :published-at (local-time:now)))
           (id (princ-to-string (user-notebook-id nb))))
      (with-mock-session (make-session :user user)
        (let* ((res (user-notebook-edit-handler (list (cons :id id))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "name=visibility" body)
              "edit form has visibility select")
          ;; The public option must be marked selected for an existing public
          ;; notebook. The order of attributes is "value=public ... selected".
          (let* ((vis-pos (search "name=visibility" body))
                 (segment (and vis-pos (subseq body vis-pos
                                               (min (length body)
                                                    (+ vis-pos 400))))))
            (ok segment)
            (ok (search "value=public selected" segment)
                "the public option is marked selected")))))))

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

(deftest update-handler-persists-visibility
  (with-test-db
    (let* ((user (mk-user))
           (dao (get-user-by-id (getf user :id)))
           (nb (create-user-notebook!
                :title "Vis"
                :body-md "===prose===
hi"
                :cells '() :author dao
                :status "published" :visibility "private"
                :published-at (local-time:now)))
           (id (princ-to-string (user-notebook-id nb))))
      (with-mock-session (make-session :user user)
        (let ((res (user-notebook-update-handler
                    (list (cons :id id)
                          (cons "title" "Vis")
                          (cons "body" "===prose===
hi")
                          (cons "status" "published")
                          (cons "visibility" "public")))))
          (ok (= 302 (response-status res)))
          (let ((after (get-user-notebook-by-id id)))
            (ok (string= "public" (user-notebook-visibility after))
                "visibility flips from private to public")))))))

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

(deftest list-renders-3-state-pill-classes
  (testing "Notebooks listing emits status-{draft|private|public} CSS classes
that drive the 3-state pill colour, computed from (status, visibility)."
    (with-test-db
      (let* ((user (mk-user))
             (dao (get-user-by-id (getf user :id))))
        (create-user-notebook!
         :title "DraftA" :slug "drafta" :body-md "===prose===
hi"
         :cells '() :author dao :status "draft"
         :visibility "private")
        (create-user-notebook!
         :title "PrivPub" :slug "priv-pub-listing" :body-md "===prose===
hi"
         :cells '() :author dao :status "published"
         :visibility "private" :published-at (local-time:now))
        (create-user-notebook!
         :title "PublicPub" :slug "public-pub-listing" :body-md "===prose===
hi"
         :cells '() :author dao :status "published"
         :visibility "public" :published-at (local-time:now))
        (with-mock-session (make-session :user user)
          (let* ((res (user-notebooks-handler nil))
                 (body (first (response-body res))))
            (ok (= 200 (response-status res)))
            (ok (search "status-draft" body)
                "draft notebook gets status-draft class")
            (ok (search "status-private" body)
                "published+private gets status-private class")
            (ok (search "status-public" body)
                "published+public gets status-public class")))))))

(deftest toggle-status-pill-from-draft-emits-private-state
  (testing "Legacy toggle-status flips draft to published while preserving
visibility, so the returned pill shows status-private when visibility was
already private."
    (with-test-db
      (let* ((user (mk-user))
             (dao (get-user-by-id (getf user :id)))
             (nb (create-user-notebook!
                  :title "T" :body-md "===prose===
hi"
                  :cells '() :author dao
                  :status "draft" :visibility "private"))
             (id (princ-to-string (user-notebook-id nb))))
        (with-mock-session (make-session :user user)
          (let* ((res (user-notebook-toggle-status-handler
                       (list (cons :id id))))
                 (body (first (response-body res))))
            (ok (= 200 (response-status res)))
            (ok (search "status-private" body)
                "pill turns purple/private after publish")
            (ng (search "status-draft" body)
                "draft class no longer applies")))))))

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

(deftest public-list-shows-published-only
  (with-test-db
    (let* ((alice (mk-user))
           (alice-dao (get-user-by-id (getf alice :id))))
      (create-user-notebook!
       :title "Pub" :slug "pub" :body-md "===prose===
hi"
       :cells '() :author alice-dao :status "published"
       :visibility "public" :published-at (local-time:now))
      (create-user-notebook!
       :title "Drafty" :slug "drafty" :body-md "===prose===
sh"
       :cells '() :author alice-dao :status "draft")
      (with-mock-session (make-session)
        (let* ((res (notebooks-public-handler nil))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "Pub" body))
          (ng (search "Drafty" body))
          (ok (search "/n/pub" body)))))))

(deftest public-list-shows-only-public
  (with-test-db
    (let* ((alice (mk-user))
           (alice-dao (get-user-by-id (getf alice :id))))
      (create-user-notebook!
       :title "PubPublic" :slug "pub-public" :body-md "===prose===
hi"
       :cells '() :author alice-dao :status "published"
       :visibility "public" :published-at (local-time:now))
      (create-user-notebook!
       :title "PubPrivate" :slug "pub-private" :body-md "===prose===
shh"
       :cells '() :author alice-dao :status "published"
       :visibility "private" :published-at (local-time:now))
      (with-mock-session (make-session)
        (let* ((res (notebooks-public-handler nil))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "PubPublic" body))
          (ng (search "PubPrivate" body)))))))

(deftest public-list-anonymous-200
  (with-test-db
    (with-mock-session (make-session)
      (let ((res (notebooks-public-handler nil)))
        (ok (= 200 (response-status res)))
        (ok (search "Notebooks" (first (response-body res))))))))

(deftest public-page-404-for-missing-slug
  (with-test-db
    (with-mock-session (make-session)
      (let ((res (public-user-notebook-handler '((:slug . "no-such")))))
        (ok (= 404 (response-status res)))))))

(deftest public-page-404-for-others-draft
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user))
           (owner-dao (get-user-by-id (getf owner :id))))
      (create-user-notebook!
       :title "Hidden" :slug "hidden" :body-md "===prose===
shh"
       :cells '() :author owner-dao :status "draft")
      (with-mock-session (make-session :user other)
        (let ((res (public-user-notebook-handler '((:slug . "hidden")))))
          (ok (= 404 (response-status res)))))
      (with-mock-session (make-session)
        (let ((res (public-user-notebook-handler '((:slug . "hidden")))))
          (ok (= 404 (response-status res))))))))

(deftest public-page-owner-can-preview-draft
  (with-test-db
    (let* ((owner (mk-user))
           (owner-dao (get-user-by-id (getf owner :id))))
      (create-user-notebook!
       :title "Owner Draft" :slug "od" :body-md "===prose===
mine"
       :cells '() :author owner-dao :status "draft")
      (with-mock-session (make-session :user owner)
        (let* ((res (public-user-notebook-handler '((:slug . "od"))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "Owner Draft" body)))))))

(deftest public-page-published-anonymous
  (with-test-db
    (let* ((owner (mk-user))
           (dao (get-user-by-id (getf owner :id))))
      (create-user-notebook!
       :title "Open" :slug "open" :body-md "===prose===
hello"
       :cells '() :author dao :status "published"
       :visibility "public" :published-at (local-time:now))
      (with-mock-session (make-session)
        (let ((res (public-user-notebook-handler '((:slug . "open")))))
          (ok (= 200 (response-status res))))))))

(deftest public-page-published-private-404-for-others
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user))
           (owner-dao (get-user-by-id (getf owner :id))))
      (create-user-notebook!
       :title "Private Pub" :slug "priv-pub" :body-md "===prose===
shh"
       :cells '() :author owner-dao :status "published"
       :visibility "private" :published-at (local-time:now))
      (with-mock-session (make-session :user other)
        (let ((res (public-user-notebook-handler '((:slug . "priv-pub")))))
          (ok (= 404 (response-status res)))))
      (with-mock-session (make-session)
        (let ((res (public-user-notebook-handler '((:slug . "priv-pub")))))
          (ok (= 404 (response-status res))))))))

(deftest public-page-published-private-200-for-owner
  (with-test-db
    (let* ((owner (mk-user))
           (owner-dao (get-user-by-id (getf owner :id))))
      (create-user-notebook!
       :title "Owner Private Pub" :slug "owner-priv-pub" :body-md "===prose===
mine"
       :cells '() :author owner-dao :status "published"
       :visibility "private" :published-at (local-time:now))
      (with-mock-session (make-session :user owner)
        (let* ((res (public-user-notebook-handler
                     '((:slug . "owner-priv-pub"))))
               (body (first (response-body res))))
          (ok (= 200 (response-status res)))
          (ok (search "Owner Private Pub" body)))))))

(deftest run-cell-published-private-404-for-non-owner
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user))
           (dao (get-user-by-id (getf owner :id)))
           (body "===prose===
hi

===eval===
(+ 1 2)")
           (cells (mapcar #'recurya/web/routes::cell->jsonb-form
                          (recurya/game/notebook-parser:parse-notebook-body body))))
      (create-user-notebook!
       :title "PrivPub" :slug "priv-pub-run" :body-md body
       :cells cells :author dao :status "published"
       :visibility "private" :published-at (local-time:now))
      (with-mock-session (make-session :user other)
        (let ((res (public-user-notebook-cell-run-handler
                    '((:slug . "priv-pub-run") (:index . "1")
                      ("codes[]" . "")
                      ("codes[]" . "(+ 1 2)")))))
          (ok (= 404 (response-status res))))))))

(deftest public-page-renders-code-cell-with-correct-run-url
  (testing "code cells use /n/<slug>/cells/<i>/run, not the SICP route"
    (with-test-db
      (let* ((owner (mk-user))
             (dao (get-user-by-id (getf owner :id)))
             (body "===prose===
hi

===eval===
(+ 1 2)")
             (cells (mapcar #'recurya/web/routes::cell->jsonb-form
                            (recurya/game/notebook-parser:parse-notebook-body body))))
        (create-user-notebook!
         :title "Code" :slug "with-code" :body-md body
         :cells cells :author dao :status "published"
         :visibility "public" :published-at (local-time:now))
        (with-mock-session (make-session)
          (let* ((res (public-user-notebook-handler '((:slug . "with-code"))))
                 (html (first (response-body res))))
            (ok (= 200 (response-status res)))
            (ok (search "data-cell-id=" html))
            (ok (search "hx-post=\"/n/with-code/cells/1/run\"" html))
            (ng (search "/wardlisp/learn/" html))))))))

(deftest public-page-renders-prose-markdown-not-literal
  (testing "prose body markdown is rendered to sanitized HTML, not escaped verbatim"
    (with-test-db
      (let* ((owner (mk-user))
             (dao (get-user-by-id (getf owner :id)))
             (body "===prose===
**bold** *italic* hello.")
             (cells (mapcar #'recurya/web/routes::cell->jsonb-form
                            (recurya/game/notebook-parser:parse-notebook-body body))))
        (create-user-notebook!
         :title "Prose" :slug "prose-md" :body-md body
         :cells cells :author dao :status "published"
         :visibility "public" :published-at (local-time:now))
        (with-mock-session (make-session)
          (let* ((res (public-user-notebook-handler '((:slug . "prose-md"))))
                 (html (first (response-body res))))
            (ok (= 200 (response-status res)))
            (ok (search "<strong>bold</strong>" html))
            (ng (search "**bold**" html))))))))

(deftest public-page-renders-200-when-body-has-solution-cells
  (testing "viewer survives notebooks that contain ===solution=== cells (hidden)"
    (with-test-db
      (let* ((owner (mk-user))
             (dao (get-user-by-id (getf owner :id)))
             (body "===exercise: square===
(define (square x) ???)

===expect: square===
4

===solution: square===
(define (square x) (* x x))")
             (cells (mapcar #'recurya/web/routes::cell->jsonb-form
                            (recurya/game/notebook-parser:parse-notebook-body body))))
        (create-user-notebook!
         :title "Solo" :slug "with-solution" :body-md body
         :cells cells :author dao :status "published"
         :visibility "public" :published-at (local-time:now))
        (with-mock-session (make-session)
          (let* ((res (public-user-notebook-handler
                       '((:slug . "with-solution"))))
                 (html (first (response-body res))))
            (ok (= 200 (response-status res)))
            (ng (search "(* x x)" html)
                "solution body must not leak to public viewers")))))))

(deftest run-cell-404-missing-slug
  (with-test-db
    (with-mock-session (make-session)
      (let ((res (public-user-notebook-cell-run-handler
                  '((:slug . "no-such") (:index . "0")))))
        (ok (= 404 (response-status res)))))))

(deftest run-cell-rejects-prose-cell
  (with-test-db
    (let* ((owner (mk-user))
           (dao (get-user-by-id (getf owner :id)))
           (body "===prose===
hi")
           (cells (mapcar #'recurya/web/routes::cell->jsonb-form
                          (recurya/game/notebook-parser:parse-notebook-body body))))
      (create-user-notebook!
       :title "P" :slug "p1" :body-md body
       :cells cells :author dao :status "published"
       :visibility "public" :published-at (local-time:now))
      (with-mock-session (make-session)
        (let ((res (public-user-notebook-cell-run-handler
                    '((:slug . "p1") (:index . "0")))))
          (ok (= 400 (response-status res))))))))

(deftest run-cell-eval-anonymous-no-persist
  (with-test-db
    (let* ((owner (mk-user))
           (dao (get-user-by-id (getf owner :id)))
           (body "===prose===
hi

===eval===
(+ 1 2)")
           (cells (mapcar #'recurya/web/routes::cell->jsonb-form
                          (recurya/game/notebook-parser:parse-notebook-body body))))
      (create-user-notebook!
       :title "Eval" :slug "ev" :body-md body
       :cells cells :author dao :status "published"
       :visibility "public" :published-at (local-time:now))
      (with-mock-session (make-session)
        (let* ((res (public-user-notebook-cell-run-handler
                     '((:slug . "ev") (:index . "1")
                       ("codes[]" . "")
                       ("codes[]" . "(+ 1 2)")))))
          (ok (= 200 (response-status res))))))))

(deftest run-cell-eval-logged-in-persists-saved-code
  (with-test-db
    (let* ((owner (mk-user))
           (other (mk-user))
           (dao (get-user-by-id (getf owner :id)))
           (body "===prose===
hi

===eval===
(+ 1 2)")
           (cells (mapcar #'recurya/web/routes::cell->jsonb-form
                          (recurya/game/notebook-parser:parse-notebook-body body)))
           (nb (create-user-notebook!
                :title "Pers" :slug "pers" :body-md body
                :cells cells :author dao :status "published"
                :visibility "public" :published-at (local-time:now)))
           (nb-uuid (princ-to-string (user-notebook-id nb))))
      (with-mock-session (make-session :user other)
        (let ((res (public-user-notebook-cell-run-handler
                    `((:slug . "pers") (:index . "1")
                      ("codes[]" . "")
                      ("codes[]" . "(+ 1 2)")))))
          (ok (= 200 (response-status res))))
        (let ((codes (recurya/db/learn:user-cell-codes
                      (getf other :id) nb-uuid)))
          (ok (= 1 (length codes)))
          (ok (search "(+ 1 2)" (cdar codes))))))))

(deftest notebook-page-with-course-shows-sidebar
  (testing "?course=<slug> renders the course sidebar with course title link
and the breadcrumb shows Notebooks > Course Title > Notebook Title."
    (with-test-db
      (let* ((author (mk-user))
             (dao (get-user-by-id (getf author :id)))
             (course (create-course! :title "SICP"
                                     :slug "sicp"
                                     :status "published"
                                     :published-at (local-time:now)
                                     :author dao))
             (nb (create-user-notebook!
                  :title "1.1.1 Expressions"
                  :slug "sicp-1-1-1"
                  :body-md "===prose===
hi"
                  :cells nil
                  :status "published"
                  :visibility "public"
                  :published-at (local-time:now)
                  :author dao)))
        (add-notebook-to-course! (course-id course) (user-notebook-id nb)
                                 :position 0)
        (with-mock-session (make-session)
          (let* ((res (public-user-notebook-handler
                       '((:slug . "sicp-1-1-1") ("course" . "sicp"))))
                 (body (first (response-body res))))
            (ok (= 200 (response-status res)))
            (ok (search "href=\"/c/sicp\"" body))
            (ok (search "SICP" body))
            (ok (search "href=\"/notebooks\"" body))
            (ok (search "1.1.1 Expressions" body))))))))

(deftest notebook-page-with-course-shows-prev-next
  (testing "middle notebook in course gets prev=first, next=last URLs
preserving the ?course=<slug> query string."
    (with-test-db
      (let* ((author (mk-user))
             (dao (get-user-by-id (getf author :id)))
             (course (create-course! :title "SICP"
                                     :slug "sicp"
                                     :status "published"
                                     :published-at (local-time:now)
                                     :author dao))
             (nb1 (create-user-notebook!
                   :title "First" :slug "first"
                   :body-md "===prose===
a"
                   :cells nil :status "published"
                   :visibility "public"
                   :published-at (local-time:now) :author dao))
             (nb2 (create-user-notebook!
                   :title "Middle" :slug "middle"
                   :body-md "===prose===
b"
                   :cells nil :status "published"
                   :visibility "public"
                   :published-at (local-time:now) :author dao))
             (nb3 (create-user-notebook!
                   :title "Last" :slug "last"
                   :body-md "===prose===
c"
                   :cells nil :status "published"
                   :visibility "public"
                   :published-at (local-time:now) :author dao)))
        (add-notebook-to-course! (course-id course) (user-notebook-id nb1)
                                 :position 0)
        (add-notebook-to-course! (course-id course) (user-notebook-id nb2)
                                 :position 1)
        (add-notebook-to-course! (course-id course) (user-notebook-id nb3)
                                 :position 2)
        (with-mock-session (make-session)
          (let* ((res (public-user-notebook-handler
                       '((:slug . "middle") ("course" . "sicp"))))
                 (body (first (response-body res))))
            (ok (= 200 (response-status res)))
            (ok (search "/n/first?course=sicp" body))
            (ok (search "/n/last?course=sicp" body))))))))

(deftest notebook-page-with-course-no-prev-at-first
  (testing "first notebook in course renders next URL but no prev URL."
    (with-test-db
      (let* ((author (mk-user))
             (dao (get-user-by-id (getf author :id)))
             (course (create-course! :title "SICP"
                                     :slug "sicp"
                                     :status "published"
                                     :published-at (local-time:now)
                                     :author dao))
             (nb1 (create-user-notebook!
                   :title "First" :slug "first"
                   :body-md "===prose===
a"
                   :cells nil :status "published"
                   :visibility "public"
                   :published-at (local-time:now) :author dao))
             (nb2 (create-user-notebook!
                   :title "Second" :slug "second"
                   :body-md "===prose===
b"
                   :cells nil :status "published"
                   :visibility "public"
                   :published-at (local-time:now) :author dao)))
        (add-notebook-to-course! (course-id course) (user-notebook-id nb1)
                                 :position 0)
        (add-notebook-to-course! (course-id course) (user-notebook-id nb2)
                                 :position 1)
        (with-mock-session (make-session)
          (let* ((res (public-user-notebook-handler
                       '((:slug . "first") ("course" . "sicp"))))
                 (body (first (response-body res))))
            (ok (= 200 (response-status res)))
            (ok (search "/n/second?course=sicp" body))
            (ng (search "/n/first?course=sicp" body)
                "the current page does not link to itself as prev")))))))

(deftest notebook-page-with-course-no-next-at-last
  (testing "last notebook in course renders prev URL but no next URL."
    (with-test-db
      (let* ((author (mk-user))
             (dao (get-user-by-id (getf author :id)))
             (course (create-course! :title "SICP"
                                     :slug "sicp"
                                     :status "published"
                                     :published-at (local-time:now)
                                     :author dao))
             (nb1 (create-user-notebook!
                   :title "First" :slug "first"
                   :body-md "===prose===
a"
                   :cells nil :status "published"
                   :visibility "public"
                   :published-at (local-time:now) :author dao))
             (nb2 (create-user-notebook!
                   :title "Second" :slug "second"
                   :body-md "===prose===
b"
                   :cells nil :status "published"
                   :visibility "public"
                   :published-at (local-time:now) :author dao)))
        (add-notebook-to-course! (course-id course) (user-notebook-id nb1)
                                 :position 0)
        (add-notebook-to-course! (course-id course) (user-notebook-id nb2)
                                 :position 1)
        (with-mock-session (make-session)
          (let* ((res (public-user-notebook-handler
                       '((:slug . "second") ("course" . "sicp"))))
                 (body (first (response-body res))))
            (ok (= 200 (response-status res)))
            (ok (search "/n/first?course=sicp" body))
            (ng (search "/n/second?course=sicp" body)
                "the current page does not link to itself as next")))))))

(deftest notebook-page-with-invalid-course-falls-back-no-context
  (testing "?course=<unknown-slug> falls back to no-course-context render
(no sidebar header link, no prev/next URLs, default breadcrumb logic)."
    (with-test-db
      (let* ((author (mk-user))
             (dao (get-user-by-id (getf author :id)))
             (nb (create-user-notebook!
                  :title "Standalone" :slug "standalone"
                  :body-md "===prose===
hi"
                  :cells nil :status "published"
                  :visibility "public"
                  :published-at (local-time:now) :author dao)))
        (declare (ignore nb))
        (with-mock-session (make-session)
          (let* ((res (public-user-notebook-handler
                       '((:slug . "standalone") ("course" . "no-such-course"))))
                 (body (first (response-body res))))
            (ok (= 200 (response-status res)))
            (ng (search "/c/no-such-course" body)
                "no link to a non-existent course")
            (ng (search "?course=no-such-course" body)
                "no prev/next URLs referencing the unknown course")
            (ok (search "Standalone" body))))))))
