;;;; web/routes.lisp --- Route handlers for the Ningle web application.
;;;;
;;;; Maps URL paths to handler functions for authentication, blog post
;;;; management, account settings, and public blog pages.  Includes
;;;; helpers for session management, pagination, and HTMX fragment
;;;; responses (status pills, confirmation modals, OOB swaps).

(defpackage #:recurya/web/routes
  (:use #:cl)
  (:import-from #:recurya/web/oauth)
  (:import-from #:recurya/db/users
                #:update-user!
                #:get-user-by-id
                #:find-or-create-oauth-user)
  (:import-from #:recurya/web/ui/login)
  (:import-from #:recurya/web/ui/errors)
  (:import-from #:recurya/web/ui/account)
  (:import-from #:recurya/web/ui/posts)
  (:import-from #:recurya/web/ui/post-form)
  (:import-from #:recurya/web/ui/blog)
  (:import-from #:spinneret #:with-html-string)
  (:import-from #:lack/request #:request-env)
  (:import-from #:recurya/web/ui/blog-post)
  (:import-from #:recurya/web/ui/user-notebooks)
  (:import-from #:recurya/web/ui/user-notebook-form)
  (:import-from #:recurya/web/ui/notebook-list)
  (:import-from #:recurya/web/ui/course)
  (:import-from #:recurya/web/ui/course-list)
  (:import-from #:recurya/web/ui/courses)
  (:import-from #:recurya/web/ui/course-form)
  (:import-from #:recurya/db/posts
                #:create-post!
                #:get-post-by-id
                #:get-post-by-slug
                #:update-post!
                #:delete-post!
                #:list-posts
                #:count-posts
                #:slugify
                #:post-id
                #:post-title
                #:post-slug
                #:post-body
                #:post-excerpt
                #:post-status
                #:post-published-at
                #:post-author
                #:post-author-id
                #:post-created-at
                #:post-updated-at)
  (:import-from #:recurya/db/user-notebooks
                #:create-user-notebook!
                #:get-user-notebook-by-id
                #:get-user-notebook-by-slug
                #:update-user-notebook!
                #:delete-user-notebook!
                #:list-user-notebooks
                #:count-user-notebooks
                #:user-notebook-id
                #:user-notebook-slug
                #:user-notebook-title
                #:user-notebook-summary
                #:user-notebook-body-md
                #:user-notebook-cells
                #:user-notebook-status
                #:user-notebook-published-at
                #:user-notebook-author
                #:user-notebook-author-id
                #:user-notebook-created-at
                #:user-notebook-updated-at)
  (:import-from #:recurya/db/courses
                #:create-course!
                #:get-course-by-id
                #:get-course-by-slug
                #:update-course!
                #:delete-course!
                #:list-courses
                #:count-courses
                #:course-id
                #:course-slug
                #:course-title
                #:course-summary
                #:course-status
                #:course-published-at
                #:course-author
                #:course-author-id
                #:course-created-at
                #:course-updated-at)
  (:import-from #:recurya/db/course-notebooks
                #:count-course-notebooks
                #:list-course-notebooks
                #:add-notebook-to-course!
                #:remove-notebook-from-course!
                #:move-notebook-up!
                #:move-notebook-down!
                #:get-course-notebook
                #:course-notebook-id
                #:course-notebook-course-id
                #:course-notebook-position
                #:course-notebook-notebook
                #:course-notebook-notebook-id)
  (:import-from #:recurya/game/notebook-parser
                #:parse-notebook-body)
  (:import-from #:recurya/game/notebook
                #:cell-id
                #:cell-kind
                #:cell-body
                #:cell-description
                #:cell-test-cases
                #:make-notebook
                #:notebook-cells
                #:run-cell
                #:notebook-cell-result-status
                #:notebook-cell-result-cell-id)
  (:import-from #:recurya/web/ui/notebook)
  (:import-from #:recurya/db/learn
                #:upsert-cell-code
                #:user-cell-codes
                #:user-passed-cells
                #:mark-cell-passed
                #:record-submission
                #:merge-localstorage)
  (:import-from #:recurya/utils/common
                #:parse-json
                #:json->string)
  (:import-from #:recurya/game/puzzle
                #:test-case-input
                #:test-case-expected
                #:test-case-description)
  (:export #:setup-routes
           #:account-confirm-delete-handler
           #:account-delete-handler
           #:post-confirm-delete-handler
           #:post-delete-handler
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
           #:public-user-notebook-cell-run-handler
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
           #:courses-public-handler
           #:learn-sync-handler
           #:sicp-learn-redirect-handler
           #:sicp-notebook-redirect-handler
           #:sicp-cell-run-redirect-handler
           #:learn-sync-redirect-handler))

(in-package #:recurya/web/routes)

;;; Response helpers

(defun html-response (body &key (status 200))
  "Create an HTML response."
  (list status '(:content-type "text/html; charset=utf-8") (list body)))

(defun redirect (location)
  "Create a redirect response."
  (list 302 (list :location location) (list "")))

(defun json-response (data &key (status 200))
  "Return a Clack ring response with JSON content."
  (list status
        '(:content-type "application/json; charset=utf-8")
        (list (json->string data))))

(defun %read-request-body ()
  "Read the raw POST body as a UTF-8 string, or empty string if unavailable."
  (let* ((env (lack/request:request-env ningle/context:*request*))
         (stream (getf env :raw-body))
         (content-length (or (getf env :content-length) 0)))
    (cond
      ((and stream (plusp content-length))
       (ignore-errors (file-position stream 0))
       (let ((buf (make-array content-length :element-type '(unsigned-byte 8))))
         (read-sequence buf stream)
         (babel:octets-to-string buf :encoding :utf-8)))
      (t ""))))

(defun get-session ()
  "Get the session hash table from the context."
  ningle/context:*session*)

(defun set-session-user! (user)
  "Store user in session."
  (when ningle/context:*session*
    (setf (gethash :user ningle/context:*session*) user)))

(defun clear-session! ()
  "Clear the session."
  (when ningle/context:*session*
    (clrhash ningle/context:*session*)))

(defun get-param (params key)
  "Get a parameter value from the alist."
  (cdr (assoc key params :test #'string-equal)))

(defun get-path-param (params key)
  "Get a path parameter (keyword) from the alist."
  (cdr (assoc key params)))



(defparameter *page-size* 5
  "Number of items per page for pagination.")



(defun parse-page-param (params)
  "Parse the page parameter from query params. Returns 1 if invalid or missing."
  (let* ((page-str (get-param params "page"))
         (page (when page-str (parse-integer page-str :junk-allowed t))))
    (if (and page (plusp page))
        page
        1)))



(defun make-pagination (current-page total-count page-size base-url)
  "Create pagination info plist.
Returns plist with :current-page :total-pages :total-count :has-prev :has-next
:prev-url :next-url."
  (let* ((total-pages (max 1 (ceiling total-count page-size)))
         (current-page (min current-page total-pages))
         (has-prev (> current-page 1))
         (has-next (< current-page total-pages)))
    (list :current-page current-page
          :total-pages total-pages
          :total-count total-count
          :has-prev has-prev
          :has-next has-next
          :prev-url (when has-prev (format nil "~A?page=~A" base-url (1- current-page)))
          :next-url (when has-next (format nil "~A?page=~A" base-url (1+ current-page))))))

;;; Route handlers

(defun get-current-user ()
  "Get the current user from session."
  (when ningle/context:*session*
    (gethash :user ningle/context:*session*)))

(defun root-handler (params)
  "Handle / - redirect to posts or login."
  (declare (ignore params))
  (if (get-current-user)
      (redirect "/posts")
      (redirect "/login")))

(defun login-page-handler (params)
  "Handle GET /login - show login form."
  (declare (ignore params))
  (if (get-current-user)
      (redirect "/posts")
      (html-response (recurya/web/ui/login:render))))

(defun logout-handler (params)
  "Handle POST /logout - clear session."
  (declare (ignore params))
  (clear-session!)
  (redirect "/login"))

(defun parse-admin-emails ()
  "Parse the ADMIN_OAUTH_EMAIL env var as a comma-separated list (lower-cased)."
  (let ((env (uiop:getenv "ADMIN_OAUTH_EMAIL")))
    (when (and env (plusp (length env)))
      (loop for raw in (cl-ppcre:split "," env)
            for trimmed = (string-trim '(#\Space #\Tab) raw)
            unless (string= trimmed "")
              collect (string-downcase trimmed)))))

(defun admin-email-p (email)
  "True if EMAIL appears in ADMIN_OAUTH_EMAIL (case-insensitive)."
  (and email
       (let ((lc (string-downcase email)))
         (member lc (parse-admin-emails) :test #'string=))))

(defun user-dao->plist (user)
  "Convert a USER mito instance to the session plist used elsewhere."
  (list :id (recurya/models/users:users-id user)
        :email (recurya/models/users:users-email user)
        :name (recurya/models/users:users-display-name user)
        :role (intern (string-upcase (recurya/models/users:users-role user)) :keyword)
        :provider (recurya/models/users:users-provider user)
        :language (recurya/models/users:users-language user)
        :timezone (recurya/models/users:users-timezone user)))

(defun oauth-start-handler (params)
  "Handle GET /auth/:provider/start - generate state and redirect to provider."
  (let* ((provider-name (get-path-param params :provider))
         (provider (and provider-name (recurya/web/oauth:find-provider provider-name))))
    (cond
      ((null provider)
       (html-response (recurya/web/ui/errors:not-found) :status 404))
      ((not (recurya/web/oauth:provider-configured-p provider))
       (html-response (recurya/web/ui/login:render
                       :error (format nil "OAuth provider ~A is not configured." provider-name))
                      :status 503))
      (t
       (let ((state (recurya/web/oauth:generate-state)))
         (when ningle/context:*session*
           (setf (gethash :oauth-state ningle/context:*session*) state)
           (setf (gethash :oauth-provider ningle/context:*session*) provider-name))
         (redirect (recurya/web/oauth:build-authorize-url provider state)))))))

(defun oauth-callback-handler (params)
  "Handle GET /auth/:provider/callback - validate state, exchange code, create session."
  (let* ((provider-name (get-path-param params :provider))
         (provider (and provider-name (recurya/web/oauth:find-provider provider-name)))
         (code (get-param params "code"))
         (state (get-param params "state"))
         (saved-state (and ningle/context:*session*
                           (gethash :oauth-state ningle/context:*session*)))
         (saved-provider (and ningle/context:*session*
                              (gethash :oauth-provider ningle/context:*session*))))
    (cond
      ((null provider)
       (html-response (recurya/web/ui/errors:not-found) :status 404))
      ((or (null code) (null state)
           (null saved-state)
           (not (string= state saved-state))
           (not (and saved-provider (string-equal provider-name saved-provider))))
       (html-response (recurya/web/ui/login:render
                       :error "Sign-in session expired. Please try again.")
                      :status 400))
      (t
       (when ningle/context:*session*
         (remhash :oauth-state ningle/context:*session*)
         (remhash :oauth-provider ningle/context:*session*))
       (handler-case
           (let* ((token (recurya/web/oauth:exchange-code provider code))
                  (info (and token (recurya/web/oauth:fetch-userinfo provider token)))
                  (email (and info (recurya/web/oauth:extract-email provider info token)))
                  (uid (and info (recurya/web/oauth:extract-uid provider info)))
                  (display-name (and info (recurya/web/oauth:extract-name provider info))))
             (cond
               ((or (null email) (null uid))
                (html-response (recurya/web/ui/login:render
                                :error "Could not retrieve a verified email from the provider.")
                               :status 400))
               (t
                (let* ((role (if (admin-email-p email) "admin" "user"))
                       (user (find-or-create-oauth-user
                              :provider provider-name
                              :provider-uid uid
                              :email email
                              :display-name display-name
                              :role role)))
                  (unless (string= (recurya/models/users:users-role user) role)
                    (update-user! (recurya/models/users:users-id user) :role role)
                    (setf user (get-user-by-id (recurya/models/users:users-id user))))
                  (set-session-user! (user-dao->plist user))
                  (redirect "/wardlisp/learn")))))
         (error (e)
           (declare (ignore e))
           (html-response (recurya/web/ui/login:render
                           :error "OAuth login failed. Please try again.")
                          :status 502)))))))

;;; Blog Post Handlers

(defun post->plist (p)
  "Convert a post instance to a plist for UI rendering.
Includes :author-name extracted from the FK author."
  (let* ((author (post-author p))
         (author-name (when author
                        (recurya/models/users:users-display-name author))))
    (list :id (post-id p)
          :title (post-title p)
          :slug (post-slug p)
          :body (post-body p)
          :excerpt (post-excerpt p)
          :status (post-status p)
          :published-at (post-published-at p)
          :created-at (post-created-at p)
          :updated-at (post-updated-at p)
          :author-name (or author-name "Anonymous"))))

(defun get-session-user-object ()
  "Get the current user as a Mito DAO object for FK references."
  (let ((user (get-current-user)))
    (when user
      (let ((user-id (getf user :id)))
        (when user-id
          (get-user-by-id user-id))))))

(defun posts-handler (params)
  "Handle GET /posts - admin post list with pagination (user's own posts only)."
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (let* ((user-id (getf user :id))
               (page (parse-page-param params))
               (total-count (count-posts :author-id user-id))
               (offset (* (1- page) *page-size*))
               (posts-raw (list-posts :author-id user-id
                                      :limit *page-size* :offset offset))
               (posts (mapcar #'post->plist posts-raw))
               (pagination (make-pagination page total-count *page-size* "/posts")))
          (html-response
           (recurya/web/ui/posts:render :user user :posts posts
                                           :pagination pagination))))))

(defun post-new-handler (params)
  "Handle GET /posts/new - show new post form."
  (declare (ignore params))
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (html-response
         (recurya/web/ui/post-form:render :user user)))))

(defun post-create-handler (params)
  "Handle POST /posts - create a new post."
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (let ((title (get-param params "title"))
              (slug (get-param params "slug"))
              (body (get-param params "body"))
              (excerpt (get-param params "excerpt"))
              (status (get-param params "status")))
          (cond
            ((or (null title) (equal title ""))
             (html-response
              (recurya/web/ui/post-form:render :user user
                                                  :errors '("Title is required."))))
            ((or (null body) (equal body ""))
             (html-response
              (recurya/web/ui/post-form:render :user user
                                                  :errors '("Body is required.")
                                                  :post (list :title title :slug slug
                                                              :excerpt excerpt :status status))))
            (t
             (let* ((slug-val (if (and slug (string/= slug "")) slug nil))
                    (excerpt-val (if (and excerpt (string/= excerpt "")) excerpt nil))
                    (published-at (when (equal status "published") (local-time:now)))
                    (post (create-post! :title title
                                        :slug slug-val
                                        :body body
                                        :excerpt excerpt-val
                                        :status (or status "draft")
                                        :published-at published-at
                                        :author (get-session-user-object))))
               (declare (ignore post))
               (redirect "/posts"))))))))

(defun post-edit-handler (params)
  "Handle GET /posts/:id/edit - show edit form for existing post (owner only)."
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (let* ((id (get-path-param params :id))
               (post (get-post-by-id id)))
          (cond
            ((null post)
             (html-response (recurya/web/ui/errors:not-found) :status 404))
            ((not (equal (princ-to-string (post-author-id post))
                         (princ-to-string (getf user :id))))
             (html-response "Forbidden" :status 403))
            (t
             (html-response
              (recurya/web/ui/post-form:render :user user
                                                  :post (post->plist post)))))))))

(defun post-update-handler (params)
  "Handle POST /posts/:id - update an existing post (owner only)."
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (let* ((id (get-path-param params :id))
               (existing (get-post-by-id id)))
          (cond
            ((null existing)
             (html-response (recurya/web/ui/errors:not-found) :status 404))
            ((not (equal (princ-to-string (post-author-id existing))
                         (princ-to-string (getf user :id))))
             (html-response "Forbidden" :status 403))
            (t
             (let ((title (get-param params "title"))
                   (slug (get-param params "slug"))
                   (body (get-param params "body"))
                   (excerpt (get-param params "excerpt"))
                   (status (get-param params "status")))
               (cond
                 ((or (null title) (equal title ""))
                  (html-response
                   (recurya/web/ui/post-form:render
                    :user user
                    :post (post->plist existing)
                    :errors '("Title is required."))))
                 ((or (null body) (equal body ""))
                  (html-response
                   (recurya/web/ui/post-form:render
                    :user user
                    :post (list :id id :title title :slug slug
                                :excerpt excerpt :status status)
                    :errors '("Body is required."))))
                 (t
                  (let* ((slug-val (if (and slug (string/= slug "")) slug nil))
                         (excerpt-val (if (and excerpt (string/= excerpt "")) excerpt nil))
                         (published-at
                          (when (and (equal status "published")
                                     (not (equal (post-status existing) "published")))
                            (local-time:now))))
                    (update-post! id
                                  :title title
                                  :slug slug-val
                                  :body body
                                  :excerpt excerpt-val
                                  :status (or status "draft")
                                  :published-at published-at)
                    (redirect "/posts")))))))))))

(defun cell->jsonb-form (cell)
  "Convert a cell struct into a hash-table that jzon serializes as a JSON
object. Pairs with `jsonb-hash->cell' to round-trip cells through the
JSONB column while preserving stable cell ids across edits."
  (let ((h (make-hash-table :test 'equal)))
    (setf (gethash "cell-id"     h) (or (cell-id cell) "")
          (gethash "kind"        h) (string-downcase (symbol-name (cell-kind cell)))
          (gethash "body"        h) (or (cell-body cell) "")
          (gethash "description" h) (cell-description cell)
          (gethash "test-cases"  h)
          (mapcar (lambda (tc)
                    (let ((th (make-hash-table :test 'equal)))
                      (setf (gethash "input"       th) (test-case-input tc)
                            (gethash "expected"    th) (test-case-expected tc)
                            (gethash "description" th) (test-case-description tc))
                      th))
                  (cell-test-cases cell)))
    h))

(defun jsonb-hash->cell (h)
  "Reconstruct a cell struct from a JSONB hash-table produced by
`cell->jsonb-form'. Used to seed parse-notebook-body's existing-cells
so cell ids stay stable across edits."
  (let ((kind-str (gethash "kind" h ""))
        (raw-tcs  (gethash "test-cases" h #())))
    (recurya/game/notebook:make-cell
     :id (or (gethash "cell-id" h "") "")
     :kind (if (and kind-str (plusp (length kind-str)))
               (intern (string-upcase kind-str) :keyword)
               :prose)
     :body (or (gethash "body" h "") "")
     :description (or (gethash "description" h "") "")
     :test-cases (mapcar
                  (lambda (th)
                    (recurya/game/puzzle:make-test-case
                     :input       (or (gethash "input" th "") "")
                     :expected    (or (gethash "expected" th "") "")
                     :description (or (gethash "description" th "") "")))
                  (coerce raw-tcs 'list)))))

(defun user-notebook->plist (nb)
  "Convert a user-notebook DAO into a plist for UI rendering."
  (list :id           (princ-to-string (user-notebook-id nb))
        :slug         (user-notebook-slug nb)
        :title        (user-notebook-title nb)
        :summary      (user-notebook-summary nb)
        :body-md      (user-notebook-body-md nb)
        :status       (user-notebook-status nb)
        :published-at (user-notebook-published-at nb)
        :created-at   (user-notebook-created-at nb)
        :updated-at   (user-notebook-updated-at nb)
        :author-id    (user-notebook-author-id nb)))

(defun user-notebooks-handler (params)
  "Handle GET /notebooks/me - admin user-notebook list (own notebooks)."
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (let* ((user-id (getf user :id))
               (page (parse-page-param params))
               (total-count (count-user-notebooks :author-id user-id))
               (offset (* (1- page) *page-size*))
               (raw (list-user-notebooks :author-id user-id
                                         :limit *page-size*
                                         :offset offset))
               (notebooks (mapcar #'user-notebook->plist raw))
               (pagination (make-pagination page total-count *page-size*
                                            "/notebooks/me")))
          (html-response
           (recurya/web/ui/user-notebooks:render
            :user user :notebooks notebooks :pagination pagination))))))

(defun user-notebook-new-handler (params)
  "Handle GET /notebooks/new - show new user-notebook form."
  (declare (ignore params))
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (html-response
         (recurya/web/ui/user-notebook-form:render :user user)))))

(defun user-notebook-create-handler (params)
  "Handle POST /notebooks - create a new user-notebook."
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (let ((title (get-param params "title"))
              (slug (get-param params "slug"))
              (summary (get-param params "summary"))
              (body (get-param params "body"))
              (status (get-param params "status")))
          (cond
            ((or (null title) (equal title ""))
             (html-response
              (recurya/web/ui/user-notebook-form:render
               :user user
               :notebook (list :title title :slug slug :summary summary
                               :body-md body :status status)
               :errors '((:line nil :message "Title is required.")))))
            ((or (null body) (equal body ""))
             (html-response
              (recurya/web/ui/user-notebook-form:render
               :user user
               :notebook (list :title title :slug slug :summary summary
                               :body-md body :status status)
               :errors '((:line nil :message "Body is required.")))))
            (t
             (multiple-value-bind (cells parse-errors)
                 (parse-notebook-body body)
               (cond
                 (parse-errors
                  (html-response
                   (recurya/web/ui/user-notebook-form:render
                    :user user
                    :notebook (list :title title :slug slug :summary summary
                                    :body-md body :status status)
                    :errors parse-errors)))
                 (t
                  (let* ((slug-val (if (and slug (string/= slug "")) slug nil))
                         (summary-val (if (and summary (string/= summary "")) summary nil))
                         (published-at
                           (when (equal status "published") (local-time:now)))
                         (cells-plists (mapcar #'cell->jsonb-form cells)))
                    (create-user-notebook!
                     :title title :slug slug-val :summary summary-val
                     :body-md body :cells cells-plists
                     :status (or status "draft")
                     :published-at published-at
                     :author (get-session-user-object))
                    (redirect "/notebooks/me")))))))))))

(defun user-notebook-edit-handler (params)
  "Handle GET /notebooks/:id/edit - show edit form for existing user-notebook
(owner only)."
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (let* ((id (get-path-param params :id))
               (nb (and id (get-user-notebook-by-id id))))
          (cond
            ((null nb)
             (html-response (recurya/web/ui/errors:not-found) :status 404))
            ((not (equal (princ-to-string (user-notebook-author-id nb))
                         (princ-to-string (getf user :id))))
             (html-response "Forbidden" :status 403))
            (t
             (html-response
              (recurya/web/ui/user-notebook-form:render
               :user user :notebook (user-notebook->plist nb)))))))))

(defun user-notebook-update-handler (params)
  "Handle POST /notebooks/:id - update an existing user-notebook (owner only).
The previous body markdown is reparsed to recover stable cell ids, then the
new body is parsed with those ids carried forward where (kind, body,
description) match."
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (let* ((id (get-path-param params :id))
               (existing (and id (get-user-notebook-by-id id))))
          (cond
            ((null existing)
             (html-response (recurya/web/ui/errors:not-found) :status 404))
            ((not (equal (princ-to-string (user-notebook-author-id existing))
                         (princ-to-string (getf user :id))))
             (html-response "Forbidden" :status 403))
            (t
             (let ((title (get-param params "title"))
                   (slug (get-param params "slug"))
                   (summary (get-param params "summary"))
                   (body (get-param params "body"))
                   (status (get-param params "status")))
               (cond
                 ((or (null title) (equal title ""))
                  (html-response
                   (recurya/web/ui/user-notebook-form:render
                    :user user
                    :notebook (list :id id :title title :slug slug
                                    :summary summary :body-md body
                                    :status status)
                    :errors '((:line nil :message "Title is required.")))))
                 ((or (null body) (equal body ""))
                  (html-response
                   (recurya/web/ui/user-notebook-form:render
                    :user user
                    :notebook (list :id id :title title :slug slug
                                    :summary summary :body-md body
                                    :status status)
                    :errors '((:line nil :message "Body is required.")))))
                 (t
                  (let ((existing-cells
                          (mapcar #'jsonb-hash->cell
                                  (coerce
                                   (recurya/db/user-notebooks:user-notebook-cells-parsed
                                    existing)
                                   'list))))
                    (multiple-value-bind (cells parse-errors)
                        (parse-notebook-body body existing-cells)
                      (cond
                        (parse-errors
                         (html-response
                          (recurya/web/ui/user-notebook-form:render
                           :user user
                           :notebook (list :id id :title title :slug slug
                                           :summary summary :body-md body
                                           :status status)
                           :errors parse-errors)))
                        (t
                         (let* ((slug-val
                                  (if (and slug (string/= slug "")) slug nil))
                                (summary-val
                                  (if (and summary (string/= summary ""))
                                      summary nil))
                                (published-at
                                  (when (and (equal status "published")
                                             (not (equal
                                                    (user-notebook-status existing)
                                                    "published")))
                                    (local-time:now)))
                                (cells-plists
                                  (mapcar #'cell->jsonb-form cells)))
                           (update-user-notebook!
                            id
                            :title title
                            :slug slug-val
                            :summary summary-val
                            :body-md body
                            :cells cells-plists
                            :status (or status "draft")
                            :published-at published-at)
                           (redirect "/notebooks/me")))))))))))))))

(defun course->plist (c)
  "Convert a course DAO into a plist for UI rendering. The :notebook-count
field is the number of notebooks attached to the course via course_notebook."
  (list :id              (princ-to-string (course-id c))
        :slug            (course-slug c)
        :title           (course-title c)
        :summary         (course-summary c)
        :status          (course-status c)
        :published-at    (course-published-at c)
        :created-at      (course-created-at c)
        :updated-at      (course-updated-at c)
        :author-id       (course-author-id c)
        :notebook-count  (count-course-notebooks (course-id c))))

(defun courses-me-handler (params)
  "Handle GET /courses/me - admin course list (own courses)."
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (let* ((user-id (getf user :id))
               (page (parse-page-param params))
               (total-count (count-courses :author-id user-id))
               (offset (* (1- page) *page-size*))
               (raw (list-courses :author-id user-id
                                  :limit *page-size*
                                  :offset offset))
               (courses (mapcar #'course->plist raw))
               (pagination (make-pagination page total-count *page-size*
                                            "/courses/me")))
          (html-response
           (recurya/web/ui/courses:render
            :user user :courses courses :pagination pagination))))))

(defun course-new-handler (params)
  "Handle GET /courses/new - show new course form."
  (declare (ignore params))
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (html-response
         (recurya/web/ui/course-form:render :user user)))))

(defun course-create-handler (params)
  "Handle POST /courses - create a new course."
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (let ((title (get-param params "title"))
              (slug (get-param params "slug"))
              (summary (get-param params "summary"))
              (status (get-param params "status")))
          (cond
            ((or (null title) (equal title ""))
             (html-response
              (recurya/web/ui/course-form:render
               :user user
               :course (list :title title :slug slug :summary summary
                             :status status)
               :errors '((:line nil :message "Title is required.")))))
            (t
             (let* ((slug-val (if (and slug (string/= slug "")) slug nil))
                    (summary-val (if (and summary (string/= summary "")) summary nil))
                    (published-at
                      (when (equal status "published") (local-time:now))))
               (create-course!
                :title title :slug slug-val :summary summary-val
                :status (or status "draft")
                :published-at published-at
                :author (get-session-user-object))
               (redirect "/courses/me"))))))))

(defun course-notebook-row->plist (cn)
  "Convert a COURSE-NOTEBOOK DAO into a plist
\(:id :cn-id :title :position) where:

  :id      - the underlying user-notebook UUID string (used by the
             eligible-notebooks dedup logic).
  :cn-id   - the course-notebook BIGSERIAL primary key (used by the
             reorder/remove HTMX endpoints)."
  (let ((nb (course-notebook-notebook cn)))
    (list :id (princ-to-string (course-notebook-notebook-id cn))
          :cn-id (course-notebook-id cn)
          :title (when nb (user-notebook-title nb))
          :position (course-notebook-position cn))))

(defun course-eligible-notebooks (user-id attached-notebook-ids)
  "Return plists (:id :title) of USER-ID's published notebooks that are
not already attached. ATTACHED-NOTEBOOK-IDS is a list of UUID strings."
  (let* ((own
          (list-user-notebooks :status "published" :author-id user-id
                               :limit 1000))
         (attached-set
          (mapcar (lambda (x) (princ-to-string x)) attached-notebook-ids)))
    (loop for nb in own
          for nb-id = (princ-to-string (user-notebook-id nb))
          unless (member nb-id attached-set :test #'string=)
            collect (list :id nb-id :title (user-notebook-title nb)))))

(defun course-edit-handler (params)
  "Handle GET /courses/:id/edit - show edit form for an existing course
(owner only). Includes the attached notebook list and Add dropdown
populated with the user's other published notebooks."
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (let* ((id (get-path-param params :id))
               (c (and id (get-course-by-id id))))
          (cond
            ((null c)
             (html-response (recurya/web/ui/errors:not-found) :status 404))
            ((not (equal (princ-to-string (course-author-id c))
                         (princ-to-string (getf user :id))))
             (html-response "Forbidden" :status 403))
            (t
             (let* ((rows (list-course-notebooks (course-id c)))
                    (course-notebooks
                     (mapcar #'course-notebook-row->plist rows))
                    (attached-ids
                     (mapcar (lambda (p) (getf p :id)) course-notebooks))
                    (eligible
                     (course-eligible-notebooks (getf user :id)
                                                attached-ids)))
               (html-response
                (recurya/web/ui/course-form:render
                 :user user :course (course->plist c)
                 :course-notebooks course-notebooks
                 :eligible-notebooks eligible)))))))))

(defun course-update-handler (params)
  "Handle POST /courses/:id - update an existing course (owner only)."
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (let* ((id (get-path-param params :id))
               (existing (and id (get-course-by-id id))))
          (cond
            ((null existing)
             (html-response (recurya/web/ui/errors:not-found) :status 404))
            ((not (equal (princ-to-string (course-author-id existing))
                         (princ-to-string (getf user :id))))
             (html-response "Forbidden" :status 403))
            (t
             (let ((title (get-param params "title"))
                   (slug (get-param params "slug"))
                   (summary (get-param params "summary"))
                   (status (get-param params "status")))
               (cond
                 ((or (null title) (equal title ""))
                  (html-response
                   (recurya/web/ui/course-form:render
                    :user user
                    :course (list :id id :title title :slug slug
                                  :summary summary :status status)
                    :errors '((:line nil :message "Title is required.")))))
                 (t
                  (let* ((slug-val
                           (if (and slug (string/= slug "")) slug nil))
                         (summary-val
                           (if (and summary (string/= summary ""))
                               summary nil))
                         (published-at
                           (when (and (equal status "published")
                                      (not (equal
                                             (course-status existing)
                                             "published")))
                             (local-time:now))))
                    (update-course!
                     id
                     :title title
                     :slug slug-val
                     :summary summary-val
                     :status (or status "draft")
                     :published-at published-at)
                    (redirect "/courses/me")))))))))))

(defun render-course-status-pill (id status)
  "Render the course status pill HTML fragment for HTMX swap."
  (let ((status-lower (string-downcase (or status "draft"))))
    (with-html-string
      (:span :class "status-pill"
             :id (format nil "status-~A" id)
             :data-status status-lower
             :hx-post (format nil "/courses/~A/toggle-status" id)
             :hx-target (format nil "#status-~A" id)
             :hx-swap "outerHTML"
             (string-capitalize status-lower)))))

(defun course-toggle-status-handler (params)
  "Handle POST /courses/:id/toggle-status - toggle between draft and published.
Returns the updated status pill HTML fragment for HTMX swap."
  (let ((user (get-current-user)))
    (if (null user)
        (html-response "Unauthorized" :status 401)
        (let* ((id (get-path-param params :id))
               (c (and id (get-course-by-id id))))
          (cond ((null c) (html-response "Not found" :status 404))
                ((not (equal (princ-to-string (course-author-id c))
                             (princ-to-string (getf user :id))))
                 (html-response "Forbidden" :status 403))
                (t
                 (let* ((current (course-status c))
                        (new-status (if (equal current "published")
                                        "draft"
                                        "published"))
                        (published-at
                         (when (equal new-status "published")
                           (local-time:now))))
                   (update-course! id
                                   :status new-status
                                   :published-at published-at)
                   (html-response
                    (render-course-status-pill id new-status)))))))))

(defun course-confirm-delete-handler (params)
  "Handle GET /courses/:id/confirm-delete - return modal fragment for deletion."
  (let ((user (get-current-user)))
    (if (null user)
        (html-response "Unauthorized" :status 401)
        (let* ((id (get-path-param params :id))
               (c (and id (get-course-by-id id))))
          (cond ((null c) (html-response "Not found" :status 404))
                ((not (equal (princ-to-string (course-author-id c))
                             (princ-to-string (getf user :id))))
                 (html-response "Forbidden" :status 403))
                (t
                 (html-response
                  (render-confirm-modal
                   :title "Delete this course?"
                   :message (format nil
                                    "\"~A\" will be permanently deleted. This cannot be undone."
                                    (course-title c))
                   :confirm-hx-post (format nil "/courses/~A/delete" id)
                   :confirm-label "Delete course"))))))))

(defun course-delete-handler (params)
  "Handle POST /courses/:id/delete - delete course (owner only).
For HTMX requests returns an empty OOB row swap; otherwise redirects."
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (let* ((id (get-path-param params :id))
               (c (and id (get-course-by-id id))))
          (cond ((null c) (html-response (not-found) :status 404))
                ((not (equal (princ-to-string (course-author-id c))
                             (princ-to-string (getf user :id))))
                 (html-response "Forbidden" :status 403))
                (t
                 (delete-course! id)
                 (if (htmx-request-p)
                     (html-response
                      (with-html-string
                        (:tr :id (format nil "course-row-~A" id)
                             :hx-swap-oob "outerHTML")))
                     (redirect "/courses/me"))))))))

(defun course-add-notebook-handler (params)
  "Handle POST /courses/:id/notebooks - attach a user-notebook to a course.

Owner only. Reads NOTEBOOK_ID from the form body. Returns the updated
notebook list as an HTML fragment (#course-notebooks-list) suitable for
HTMX outerHTML swap. Duplicate attachments are caught and reported as a
flash message in the rendered list."
  (let ((user (get-current-user)))
    (if (null user)
        (html-response "Unauthorized" :status 401)
        (let* ((id (get-path-param params :id))
               (c (and id (get-course-by-id id))))
          (cond ((null c) (html-response "Not found" :status 404))
                ((not
                  (equal (princ-to-string (course-author-id c))
                         (princ-to-string (getf user :id))))
                 (html-response "Forbidden" :status 403))
                (t
                 (let* ((nb-id-raw (get-param params "notebook_id"))
                        (nb-id (and nb-id-raw (string/= nb-id-raw "")
                                    nb-id-raw))
                        (nb (and nb-id (get-user-notebook-by-id nb-id)))
                        (course-id (course-id c))
                        (message nil))
                   (cond
                     ((null nb)
                      (setf message "Selected notebook does not exist."))
                     ((not (equal (princ-to-string
                                   (user-notebook-author-id nb))
                                  (princ-to-string (getf user :id))))
                      (setf message "You can only add your own notebooks."))
                     (t
                      (handler-case
                          (add-notebook-to-course! course-id nb-id)
                        (error ()
                          (setf message
                                "This notebook is already attached.")))))
                   (let* ((rows (list-course-notebooks course-id))
                          (course-notebooks
                           (mapcar #'course-notebook-row->plist rows))
                          (attached-ids
                           (mapcar (lambda (p) (getf p :id))
                                   course-notebooks))
                          (eligible
                           (course-eligible-notebooks
                            (getf user :id) attached-ids)))
                     (html-response
                      (recurya/web/ui/course-form:render-course-notebooks-list
                       (course->plist c) course-notebooks eligible
                       :message message))))))))))

(defun %render-course-notebook-list-fragment (course user-id &key message)
  "Helper: re-render the #course-notebooks-list fragment for COURSE owned by
USER-ID. Returns an HTML response. Used by add/move/remove handlers."
  (let* ((cid (course-id course))
         (rows (list-course-notebooks cid))
         (course-notebooks (mapcar #'course-notebook-row->plist rows))
         (attached-ids (mapcar (lambda (p) (getf p :id)) course-notebooks))
         (eligible (course-eligible-notebooks user-id attached-ids)))
    (html-response
     (recurya/web/ui/course-form:render-course-notebooks-list
      (course->plist course) course-notebooks eligible :message message))))

(defun %lookup-course-notebook-row (course-id cn-id-raw)
  "Resolve the course-notebook join row identified by CN-ID-RAW and verify it
belongs to COURSE-ID. Returns the row, or NIL on parse failure / mismatch /
missing row."
  (let ((cn-id (typecase cn-id-raw
                 (string (parse-integer cn-id-raw :junk-allowed t))
                 (integer cn-id-raw)
                 (t nil))))
    (when cn-id
      (let ((row (get-course-notebook cn-id)))
        (when (and row
                   (equal (princ-to-string (course-notebook-course-id row))
                          (princ-to-string course-id)))
          row)))))

(defun course-notebook-move-up-handler (params)
  "Handle POST /courses/:id/notebooks/:cn-id/up - move a course-notebook
one position up.

Owner only. Re-renders #course-notebooks-list as an HTMX outerHTML
fragment. No-op when already at position 0."
  (let ((user (get-current-user)))
    (if (null user)
        (html-response "Unauthorized" :status 401)
        (let* ((id (get-path-param params :id))
               (c (and id (get-course-by-id id))))
          (cond
            ((null c) (html-response "Not found" :status 404))
            ((not (equal (princ-to-string (course-author-id c))
                         (princ-to-string (getf user :id))))
             (html-response "Forbidden" :status 403))
            (t
             (let* ((cn-id-raw (get-path-param params :cn-id))
                    (row (%lookup-course-notebook-row (course-id c) cn-id-raw)))
               (cond
                 ((null row) (html-response "Not found" :status 404))
                 (t
                  (move-notebook-up! (course-notebook-id row))
                  (%render-course-notebook-list-fragment
                   c (getf user :id)))))))))))

(defun course-notebook-move-down-handler (params)
  "Handle POST /courses/:id/notebooks/:cn-id/down - move a course-notebook
one position down.

Owner only. Re-renders #course-notebooks-list as an HTMX outerHTML
fragment. No-op when already at the last position."
  (let ((user (get-current-user)))
    (if (null user)
        (html-response "Unauthorized" :status 401)
        (let* ((id (get-path-param params :id))
               (c (and id (get-course-by-id id))))
          (cond
            ((null c) (html-response "Not found" :status 404))
            ((not (equal (princ-to-string (course-author-id c))
                         (princ-to-string (getf user :id))))
             (html-response "Forbidden" :status 403))
            (t
             (let* ((cn-id-raw (get-path-param params :cn-id))
                    (row (%lookup-course-notebook-row (course-id c) cn-id-raw)))
               (cond
                 ((null row) (html-response "Not found" :status 404))
                 (t
                  (move-notebook-down! (course-notebook-id row))
                  (%render-course-notebook-list-fragment
                   c (getf user :id)))))))))))

(defun course-notebook-remove-handler (params)
  "Handle POST /courses/:id/notebooks/:cn-id/remove - detach a notebook
from a course.

Owner only. Re-renders #course-notebooks-list as an HTMX outerHTML
fragment with the row gone. We re-render the entire list (rather than
just the single row) for consistency with up/down — keeping the eligible
notebooks dropdown in sync."
  (let ((user (get-current-user)))
    (if (null user)
        (html-response "Unauthorized" :status 401)
        (let* ((id (get-path-param params :id))
               (c (and id (get-course-by-id id))))
          (cond
            ((null c) (html-response "Not found" :status 404))
            ((not (equal (princ-to-string (course-author-id c))
                         (princ-to-string (getf user :id))))
             (html-response "Forbidden" :status 403))
            (t
             (let* ((cn-id-raw (get-path-param params :cn-id))
                    (row (%lookup-course-notebook-row (course-id c) cn-id-raw)))
               (cond
                 ((null row) (html-response "Not found" :status 404))
                 (t
                  (remove-notebook-from-course!
                   (course-id c)
                   (course-notebook-notebook-id row))
                  (%render-course-notebook-list-fragment
                   c (getf user :id)))))))))))

(defun render-user-notebook-status-pill (id status)
  "Render the user-notebook status pill HTML fragment for HTMX swap."
  (let ((status-lower (string-downcase (or status "draft"))))
    (with-html-string
      (:span :class "status-pill"
             :id (format nil "status-~A" id)
             :data-status status-lower
             :hx-post (format nil "/notebooks/~A/toggle-status" id)
             :hx-target (format nil "#status-~A" id)
             :hx-swap "outerHTML"
             (string-capitalize status-lower)))))

(defun user-notebook-toggle-status-handler (params)
  "Handle POST /notebooks/:id/toggle-status - toggle between draft and published.
Returns the updated status pill HTML fragment for HTMX swap."
  (let ((user (get-current-user)))
    (if (null user)
        (html-response "Unauthorized" :status 401)
        (let* ((id (get-path-param params :id))
               (nb (and id (get-user-notebook-by-id id))))
          (cond
            ((null nb) (html-response "Not found" :status 404))
            ((not (equal (princ-to-string (user-notebook-author-id nb))
                         (princ-to-string (getf user :id))))
             (html-response "Forbidden" :status 403))
            (t
             (let* ((current (user-notebook-status nb))
                    (new-status (if (equal current "published")
                                    "draft"
                                    "published"))
                    (published-at (when (equal new-status "published")
                                    (local-time:now))))
               (update-user-notebook! id
                                      :status new-status
                                      :published-at published-at)
               (html-response
                (render-user-notebook-status-pill id new-status)))))))))

(defun user-notebook-confirm-delete-handler (params)
  "Handle GET /notebooks/:id/confirm-delete - return modal fragment for deletion."
  (let ((user (get-current-user)))
    (if (null user)
        (html-response "Unauthorized" :status 401)
        (let* ((id (get-path-param params :id))
               (nb (and id (get-user-notebook-by-id id))))
          (cond
            ((null nb) (html-response "Not found" :status 404))
            ((not (equal (princ-to-string (user-notebook-author-id nb))
                         (princ-to-string (getf user :id))))
             (html-response "Forbidden" :status 403))
            (t
             (html-response
              (render-confirm-modal
               :title "Delete this notebook?"
               :message (format nil
                                "\"~A\" will be permanently deleted. This cannot be undone."
                                (user-notebook-title nb))
               :confirm-hx-post (format nil "/notebooks/~A/delete" id)
               :confirm-label "Delete notebook"))))))))

(defun user-notebook-delete-handler (params)
  "Handle POST /notebooks/:id/delete - delete user-notebook (owner only).
For HTMX requests returns an empty OOB row swap; otherwise redirects."
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (let* ((id (get-path-param params :id))
               (nb (and id (get-user-notebook-by-id id))))
          (cond
            ((null nb)
             (html-response (recurya/web/ui/errors:not-found) :status 404))
            ((not (equal (princ-to-string (user-notebook-author-id nb))
                         (princ-to-string (getf user :id))))
             (html-response "Forbidden" :status 403))
            (t
             (delete-user-notebook! id)
             (if (htmx-request-p)
                 (html-response
                  (with-html-string
                    (:tr :id (format nil "nb-row-~A" id)
                         :hx-swap-oob "outerHTML")))
                 (redirect "/notebooks/me"))))))))

(defun user-notebook-public-plist (nb)
  "Convert a user-notebook DAO to a plist for the public listing UI."
  (let* ((author (user-notebook-author nb))
         (author-name
           (when author (recurya/models/users:users-display-name author))))
    (list :slug         (user-notebook-slug nb)
          :title        (user-notebook-title nb)
          :summary      (user-notebook-summary nb)
          :published-at (user-notebook-published-at nb)
          :author-name  (or author-name "Anonymous"))))

(defun notebooks-public-handler (params)
  "Handle GET /notebooks - public listing of published user-notebooks.
No authentication required."
  (let* ((page (parse-page-param params))
         (total-count (count-user-notebooks :status "published"
                                             :visibility "public"))
         (offset (* (1- page) *page-size*))
         (raw (list-user-notebooks :status "published"
                                   :visibility "public"
                                   :limit *page-size*
                                   :offset offset))
         (notebooks (mapcar #'user-notebook-public-plist raw))
         (pagination (make-pagination page total-count *page-size*
                                      "/notebooks")))
    (html-response
     (recurya/web/ui/notebook-list:render
      :notebooks notebooks :pagination pagination))))

(defun user-notebook-row->notebook-struct (nb-row)
  "Convert a user-notebook DAO into a recurya/game/notebook:notebook struct
that the existing notebook UI and run-cell logic can consume.
Cells come from the JSONB cache (parsed via jsonb-hash->cell)."
  (let* ((cells-data (recurya/db/user-notebooks:user-notebook-cells-parsed nb-row))
         (cells-list (mapcar #'jsonb-hash->cell
                             (coerce (or cells-data #()) 'list))))
    (make-notebook
     :id (princ-to-string (user-notebook-id nb-row))
     :chapter ""
     :title (or (user-notebook-title nb-row) "")
     :summary (or (user-notebook-summary nb-row) "")
     :cells cells-list)))

(defun public-user-notebook-handler (params)
  "Handle GET /n/:slug - public single user-notebook page.
Anonymous and other users see published notebooks; the owner can also
preview their own draft. Anything else is 404.

When the optional query parameter ?course=<slug> is supplied AND the
referenced course exists AND the notebook is attached to that course,
the page is rendered with the course context: the sidebar lists the
course's notebooks, the breadcrumb is
  Notebooks > <Course Title> > <Notebook Title>,
and prev/next links navigate to the surrounding notebooks within the
course (preserving the ?course=<slug> query string)."
  (let* ((slug (get-path-param params :slug))
         (nb-row (and slug (get-user-notebook-by-slug slug)))
         (user (get-current-user))
         (uid (and user (getf user :id))))
    (cond
      ((null nb-row)
       (html-response (recurya/web/ui/errors:not-found) :status 404))
      ((not (recurya/utils/access-control:can-view-notebook-p user nb-row))
       (html-response (recurya/web/ui/errors:not-found) :status 404))
      (t
       (let* ((notebook (user-notebook-row->notebook-struct nb-row))
              (nb-id-str (princ-to-string (user-notebook-id nb-row)))
              (saved (when uid (user-cell-codes uid nb-id-str)))
              (passed (when uid (user-passed-cells uid nb-id-str)))
              (run-cell-base
               (format nil "/n/~A" (user-notebook-slug nb-row)))
              (course-slug-param (get-param params "course"))
              (course-row
               (and course-slug-param
                    (get-course-by-slug course-slug-param)))
              (course-rows
               (and course-row
                    (list-course-notebooks (course-id course-row))))
              (notebook-in-course-p
               (and course-rows
                    (find (princ-to-string (user-notebook-id nb-row))
                          course-rows
                          :key (lambda (cn)
                                 (princ-to-string
                                  (course-notebook-notebook-id cn)))
                          :test #'equal))))
         (cond
           (notebook-in-course-p
            (let* ((sidebar-notebooks
                    (mapcar #'course-notebook-row->public-plist course-rows))
                   (current-slug (user-notebook-slug nb-row))
                   (current-pos
                    (position current-slug sidebar-notebooks
                              :key (lambda (p) (getf p :slug))
                              :test #'string=))
                   (cs (course-slug course-row))
                   (prev-url
                    (when (and current-pos (> current-pos 0))
                      (let ((prev (nth (1- current-pos)
                                       sidebar-notebooks)))
                        (format nil "/n/~A?course=~A"
                                (getf prev :slug) cs))))
                   (next-url
                    (when (and current-pos
                               (< current-pos
                                  (1- (length sidebar-notebooks))))
                      (let ((nxt (nth (1+ current-pos)
                                      sidebar-notebooks)))
                        (format nil "/n/~A?course=~A"
                                (getf nxt :slug) cs))))
                   (breadcrumb
                    (list (list :text "Notebooks" :href "/notebooks")
                          (list :text (course-title course-row)
                                :href (format nil "/c/~A" cs))
                          (list :text (user-notebook-title nb-row)))))
              (html-response
               (recurya/web/ui/notebook:render
                notebook
                :user user
                :saved-codes saved
                :passed-cells passed
                :sidebar-notebooks sidebar-notebooks
                :course-title (course-title course-row)
                :course-slug cs
                :breadcrumb breadcrumb
                :course-prev-url prev-url
                :course-next-url next-url
                :run-cell-base run-cell-base))))
           (t
            (html-response
             (recurya/web/ui/notebook:render
              notebook
              :user user
              :saved-codes saved
              :passed-cells passed
              :sidebar-notebooks nil
              :run-cell-base run-cell-base)))))))))

(defun course-notebook-row->public-plist (cn)
  "Convert a course-notebook DAO into a plist for the public course view.

CN's underlying user-notebook is fetched via course-notebook-notebook
and projected into (:slug :title :summary :position)."
  (let ((nb (course-notebook-notebook cn)))
    (list :slug (when nb (user-notebook-slug nb))
          :title (when nb (user-notebook-title nb))
          :summary (when nb (user-notebook-summary nb))
          :position (course-notebook-position cn))))

(defun public-course-handler (params)
  "Handle GET /c/:slug - public single course page.
Anonymous and other users see published courses; the owner can also
preview their own draft. Anything else is 404."
  (let* ((slug (get-path-param params :slug))
         (course-row (and slug (get-course-by-slug slug)))
         (user (get-current-user))
         (uid (and user (getf user :id)))
         (owner-p
          (and course-row uid
               (equal (princ-to-string (course-author-id course-row))
                      (princ-to-string uid)))))
    (cond
      ((null course-row)
       (html-response (recurya/web/ui/errors:not-found) :status 404))
      ((and (string= "draft" (course-status course-row)) (not owner-p))
       (html-response (recurya/web/ui/errors:not-found) :status 404))
      (t
       (let* ((rows (list-course-notebooks (course-id course-row)))
              (notebooks (mapcar #'course-notebook-row->public-plist rows)))
         (html-response
          (recurya/web/ui/course:render
           :course (course->plist course-row)
           :notebooks notebooks
           :user user
           :passed-by-notebook nil)))))))

(defun course-public-plist (c)
  "Convert a course DAO to a plist for the public listing UI."
  (let* ((author (course-author c))
         (author-name
          (when author (recurya/models/users:users-display-name author))))
    (list :slug (course-slug c)
          :title (course-title c)
          :summary (course-summary c)
          :published-at (course-published-at c)
          :author-name (or author-name "Anonymous")
          :notebook-count (count-course-notebooks (course-id c)))))

(defun courses-public-handler (params)
  "Handle GET /courses - public listing of published courses.
No authentication required."
  (let* ((page (parse-page-param params))
         (total-count (count-courses :status "published"))
         (offset (* (1- page) *page-size*))
         (raw (list-courses :status "published"
                            :limit *page-size*
                            :offset offset))
         (courses (mapcar #'course-public-plist raw))
         (pagination
          (make-pagination page total-count *page-size* "/courses")))
    (html-response
     (recurya/web/ui/course-list:render :courses courses
                                        :pagination pagination))))

(defun %maybe-persist-user-notebook-cell-run (uid nb-uuid cell result code)
  "Persist saved code, submission, and progress for a user-notebook cell run.
Anonymous users (UID NIL) are skipped silently; DB errors are logged but
do not poison the response."
  (when uid
    (handler-case
        (let* ((cell-id-str (string (or (cell-id cell) "")))
               (status      (notebook-cell-result-status result))
               (kind        (cell-kind cell))
               (status-str  (string-downcase (symbol-name status))))
          (upsert-cell-code uid nb-uuid cell-id-str (or code ""))
          (when (eq kind :code-exercise)
            (record-submission uid nb-uuid cell-id-str (or code "") status-str)
            (when (eq status :pass)
              (mark-cell-passed uid nb-uuid cell-id-str))))
      (error (e) (log:warn "Failed to persist user-notebook cell run: ~A" e)))))

(defun public-user-notebook-cell-run-handler (params)
  "Handle POST /n/:slug/cells/:index/run - HTMX fragment for cell execution.
Anonymous users may run cells but their progress is not persisted.
Drafts are visible (and runnable) only to the owner."
  (let* ((slug (get-path-param params :slug))
         (nb-row (and slug (get-user-notebook-by-slug slug)))
         (user (get-current-user))
         (uid (and user (getf user :id)))
         (owner-p (and nb-row uid
                       (equal (princ-to-string (user-notebook-author-id nb-row))
                              (princ-to-string uid)))))
    (cond
      ((null nb-row) (html-response "Notebook not found" :status 404))
      ((and (string= "draft" (user-notebook-status nb-row)) (not owner-p))
       (html-response "Notebook not found" :status 404))
      (t
       (let* ((notebook (user-notebook-row->notebook-struct nb-row))
              (cells (notebook-cells notebook))
              (index-raw (get-path-param params :index))
              (index (typecase index-raw
                       (string (parse-integer index-raw :junk-allowed t))
                       (integer index-raw)
                       (t nil)))
              (codes-list (loop for (k . v) in params
                                when (and (stringp k) (string= k "codes[]"))
                                collect v)))
         (cond
           ((null index) (html-response "Invalid index" :status 400))
           ((or (< index 0) (>= index (length cells)))
            (html-response "Index out of range" :status 400))
           ((member (cell-kind (nth index cells))
                    '(:prose :code-solution))
            (html-response "Cannot run this cell" :status 400))
           (t
            (let* ((nb-uuid (princ-to-string (user-notebook-id nb-row)))
                   (result (run-cell notebook index codes-list))
                   (body (recurya/web/ui/notebook:render-cell-result result)))
              (%maybe-persist-user-notebook-cell-run
               uid nb-uuid (nth index cells) result (nth index codes-list))
              (html-response body)))))))))

(defun htmx-request-p ()
  "Return T if the current request was made by HTMX (HX-Request header present).
Checks both the Clack :headers hash-table (Hunchentoot) and the :http-hx-request
plist key (some Clack handlers normalize headers there)."
  (let* ((env (lack/request:request-env ningle/context:*request*))
         (headers (getf env :headers)))
    (or (getf env :http-hx-request)
        (and headers
             (gethash "hx-request" headers)))))

(defun render-status-pill (id status)
  "Render a status pill HTML fragment for HTMX swap.
ID is the post UUID, STATUS is the current status string."
  (let ((status-lower (string-downcase (or status "draft"))))
    (spinneret:with-html-string
      (:span :class "status-pill"
       :id (format nil "status-~A" id)
       :data-status status-lower
       :hx-post (format nil "/posts/~A/toggle-status" id)
       :hx-target (format nil "#status-~A" id)
       :hx-swap "outerHTML"
       (string-capitalize status-lower)))))

(defun render-confirm-modal (&key title message confirm-hx-post
                                   confirm-hx-target confirm-hx-swap
                                   confirm-label)
  "Render a confirmation modal overlay as an HTML fragment.
TITLE and MESSAGE describe the action. CONFIRM-HX-POST is the URL for the
confirm button's hx-post. CONFIRM-HX-TARGET and CONFIRM-HX-SWAP control
where the confirm response is swapped. CONFIRM-LABEL defaults to \"Delete\"."
  (let ((confirm-label (or confirm-label "Delete")))
    (spinneret:with-html-string
      (:div :class "modal-overlay"
            :role "dialog"
            :aria-modal "true"
            :hx-on\:click "if(event.target===this) htmx.find('#modal-container').innerHTML=''"
        (:div :class "modal-card"
          (:h3 title)
          (:p message)
          (:div :class "modal-actions"
            ;; Cancel: clear #modal-container innerHTML to remove the modal.
            ;; No server round-trip needed — hx-on:click runs client-side JS.
            (:button :type "button" :class "button-secondary"
                     :hx-on\:click "htmx.find('#modal-container').innerHTML=''"
                     "Cancel")
            ;; Confirm: POST to the action URL.  The response is swapped into
            ;; #modal-container (default), clearing the modal.  Handlers may
            ;; also include OOB swap elements to update other parts of the page.
            (:button :type "button" :class "button-danger"
                     :hx-post confirm-hx-post
                     :hx-target (or confirm-hx-target "#modal-container")
                     :hx-swap (or confirm-hx-swap "innerHTML")
                     confirm-label)))))))

(defun post-toggle-status-handler (params)
  "Handle POST /posts/:id/toggle-status - toggle between draft and published (HTMX).
Returns the updated status pill HTML fragment."
  (let ((user (get-current-user)))
    (if (null user)
        (html-response "Unauthorized" :status 401)
        (let* ((id (get-path-param params :id))
               (post (get-post-by-id id)))
          (cond
            ((null post)
             (html-response "Not found" :status 404))
            ;; Ownership check: compare UUIDs as strings via princ-to-string
            ;; because session stores the ID as a string while Mito may
            ;; return a different representation.
            ((not (equal (princ-to-string (post-author-id post))
                         (princ-to-string (getf user :id))))
             (html-response "Forbidden" :status 403))
            (t
             (let* ((current-status (post-status post))
                    (new-status (if (equal current-status "published") "draft" "published"))
                    (published-at (when (equal new-status "published") (local-time:now))))
               (update-post! id :status new-status
                                :published-at published-at)
               (html-response (render-status-pill id new-status)))))))))

(defun post-confirm-delete-handler (params)
  "Handle GET /posts/:id/confirm-delete - return modal fragment for post deletion.
Auth + ownership check, then renders a confirmation modal with HTMX attributes."
  (let ((user (get-current-user)))
    (if (null user)
        (html-response "Unauthorized" :status 401)
        (let* ((id (get-path-param params :id))
               (post (get-post-by-id id)))
          (cond
            ((null post)
             (html-response "Not found" :status 404))
            ((not (equal (princ-to-string (post-author-id post))
                         (princ-to-string (getf user :id))))
             (html-response "Forbidden" :status 403))
            (t
             (html-response
              (render-confirm-modal
               :title "Delete this post?"
               :message (format nil "\"~A\" will be permanently deleted. This cannot be undone."
                                (post-title post))
               :confirm-hx-post (format nil "/posts/~A/delete" id)
               :confirm-label "Delete post"))))))))

(defun post-delete-handler (params)
  "Handle POST /posts/:id/delete - delete a post (owner only).
Returns empty HTML for HTMX requests (row removal), or redirects for normal requests."
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (let* ((id (get-path-param params :id))
               (post (get-post-by-id id)))
          (cond
            ((null post)
             (html-response (recurya/web/ui/errors:not-found) :status 404))
            ((not (equal (princ-to-string (post-author-id post))
                         (princ-to-string (getf user :id))))
             (html-response "Forbidden" :status 403))
            (t
             (delete-post! id)
             (if (htmx-request-p)
                 ;; HTMX OOB (Out-of-Band) swap: the primary swap target is
                 ;; #modal-container which receives "" (clearing the modal).
                 ;; The <tr> carries hx-swap-oob="outerHTML" so HTMX also
                 ;; replaces the matching post row with this empty element,
                 ;; effectively removing the row from the table.
                 (html-response
                  (spinneret:with-html-string
                    (:tr :id (format nil "post-row-~A" id)
                         :hx-swap-oob "outerHTML")))
                 (redirect "/posts"))))))))

(defun blog-handler (params)
  "Handle GET /blog - public blog listing (published posts only)."
  (let* ((page (parse-page-param params))
         (total-count (count-posts :status "published"))
         (offset (* (1- page) *page-size*))
         (posts-raw (list-posts :status "published" :limit *page-size* :offset offset))
         (posts (mapcar #'post->plist posts-raw))
         (pagination (make-pagination page total-count *page-size* "/blog")))
    (html-response
     (recurya/web/ui/blog:render :posts posts :pagination pagination))))

(defun blog-post-handler (params)
  "Handle GET /blog/:slug - public single post view."
  (let* ((slug (get-path-param params :slug))
         (post (get-post-by-slug slug)))
    (if (or (null post) (not (equal (post-status post) "published")))
        (html-response (recurya/web/ui/blog-post:render :post nil) :status 404)
        (html-response
         (recurya/web/ui/blog-post:render :post (post->plist post))))))

;;; Account Handlers

(defun account-page-handler (params)
  "Handle GET /account - show account settings."
  (declare (ignore params))
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (html-response (recurya/web/ui/account:render :user user)))))

(defun account-update-handler (params)
  "Handle POST /account - update account settings."
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (let ((display-name (get-param params "display-name"))
              (language (get-param params "language"))
              (timezone (get-param params "timezone")))
          (if (or (null display-name) (string= (string-trim '(#\Space) display-name) ""))
              (redirect "/account?error=Display+name+cannot+be+blank")
              (progn
                (update-user! (getf user :id)
                              :display-name display-name
                              :language language
                              :timezone timezone)
                (setf (getf user :name) display-name)
                (setf (getf user :language) language)
                (setf (getf user :timezone) timezone)
                (set-session-user! user)
                (redirect "/account?message=Settings+updated")))))))

(defun account-confirm-delete-handler (params)
  "Handle GET /account/confirm-delete - return modal fragment for account deletion."
  (declare (ignore params))
  (let ((user (get-current-user)))
    (if (null user)
        (html-response "Unauthorized" :status 401)
        (html-response
         (render-confirm-modal
          :title "Delete your account?"
          :message "This will permanently delete your account and all associated posts. This action cannot be undone."
          :confirm-hx-post "/account/delete"
          :confirm-label "Delete account")))))

(defun account-delete-handler (params)
  "Handle POST /account/delete - delete account.
For HTMX requests, returns HX-Redirect header. For normal requests, redirects."
  (declare (ignore params))
  (let ((user (get-current-user)))
    (if (null user)
        (redirect "/login")
        (progn
          (clear-session!)
          (if (htmx-request-p)
              ;; HTMX requests: use HX-Redirect header (not 302) because a
              ;; 302 redirect only applies to the AJAX sub-request — the
              ;; browser window wouldn't navigate.  HX-Redirect tells htmx.js
              ;; to set window.location, giving a full-page navigation.
              (list 200
                    (list :content-type "text/html; charset=utf-8"
                          :hx-redirect "/login")
                    (list ""))
              (redirect "/login"))))))

;;; Dynamic dispatch support for REPL-driven development

(defun %parse-sync-payload (raw-json)
  "Convert JSON payload {\"notebooks\":[{...}]} into the plist shape
   expected by recurya/db/learn:merge-localstorage. Tolerates missing or
   JSON-null fields (jzon decodes JSON null as the symbol NULL)."
  (let* ((parsed (parse-json raw-json))
         (notebooks (and (hash-table-p parsed) (gethash "notebooks" parsed))))
    (when (and notebooks (vectorp notebooks))
      (loop for nb across notebooks
            when (hash-table-p nb)
              collect (list :notebook-id (gethash "notebook_id" nb)
                            :passed
                            (let ((arr (gethash "passed" nb)))
                              (when (vectorp arr)
                                (loop for x across arr collect x)))
                            :codes
                            (let ((codes-ht (gethash "codes" nb)))
                              (when (hash-table-p codes-ht)
                                (let (acc)
                                  (maphash (lambda (k v) (push (cons k v) acc))
                                           codes-ht)
                                  acc))))))))

(defun learn-sync-handler (params)
  "POST /learn/sync — merge localStorage payload into DB.
   Auth required."
  (declare (ignore params))
  (let* ((session ningle/context:*session*)
         (user (and session (gethash :user session)))
         (uid (and user (getf user :id))))
    (cond
      ((null uid)
       (let ((h (make-hash-table :test 'equal)))
         (setf (gethash "error" h) "auth required")
         (json-response h :status 401)))
      (t
       (handler-case
           (let* ((raw (%read-request-body))
                  (notebooks (%parse-sync-payload raw))
                  (summary (merge-localstorage uid notebooks))
                  (out (make-hash-table :test 'equal)))
             (loop for (k v) on summary by #'cddr
                   do (setf (gethash (string-downcase (symbol-name k)) out) v))
             (json-response out))
         (error (e)
           (log:warn "Failed /learn/sync: ~A" e)
           (let ((h (make-hash-table :test 'equal)))
             (setf (gethash "error" h) "server error")
             (json-response h :status 500))))))))

(defun sicp-learn-redirect-handler (params)
  "GET /wardlisp/learn -> 301 /c/sicp.
   Permanent redirect from the legacy SICP listing to the public course page."
  (declare (ignore params))
  (list 301 (list :location "/c/sicp") (list "")))

(defun sicp-notebook-redirect-handler (params)
  "GET /wardlisp/learn/:id -> 301 /n/:id.
   Permanent redirect from the legacy notebook URL to the public user-notebook URL.
   The :id path parameter is reused verbatim as the new slug."
  (let ((id (get-path-param params :id)))
    (list 301
          (list :location (format nil "/n/~A" (or id "")))
          (list ""))))

(defun sicp-cell-run-redirect-handler (params)
  "POST /wardlisp/learn/:id/cells/:index/run -> 308 /n/:id/cells/:index/run.
   308 preserves the request method and body so HTMX POSTs are forwarded
   correctly to the new endpoint."
  (let ((id (get-path-param params :id))
        (index (get-path-param params :index)))
    (list 308
          (list :location (format nil "/n/~A/cells/~A/run" (or id "") (or index "")))
          (list ""))))

(defun learn-sync-redirect-handler (params)
  "POST /wardlisp/learn/sync -> 308 /learn/sync.
   308 preserves the POST method and body so existing browser localStorage
   sync clients keep working without changes."
  (declare (ignore params))
  (list 308 (list :location "/learn/sync") (list "")))

(defun make-dynamic-handler (handler-symbol)
  "Create a handler that looks up the function by symbol at call time.
This allows function redefinitions via SLIME to take effect immediately
without restarting the server."
  (lambda (params)
    (funcall (symbol-function handler-symbol) params)))

(defun not-found-handler (params)
  "Handle 404 - not found."
  (declare (ignore params))
  (html-response (recurya/web/ui/errors:not-found) :status 404))

;;; Route setup

(defun setup-routes (app)
  "Set up all routes on the Ningle application.
Uses dynamic dispatch to allow function redefinitions via SLIME to take effect
without restarting the server."
  (setf (ningle/app:route app "/") (make-dynamic-handler 'root-handler))
  (setf (ningle/app:route app "/login")
          (make-dynamic-handler 'login-page-handler))
  (setf (ningle/app:route app "/logout" :method :post)
          (make-dynamic-handler 'logout-handler))
  ;; OAuth flow
  (setf (ningle/app:route app "/auth/:provider/start")
          (make-dynamic-handler 'oauth-start-handler))
  (setf (ningle/app:route app "/auth/:provider/callback")
          (make-dynamic-handler 'oauth-callback-handler))
  ;; Blog admin routes (auth required)
  (setf (ningle/app:route app "/posts")
          (make-dynamic-handler 'posts-handler))
  (setf (ningle/app:route app "/posts/new")
          (make-dynamic-handler 'post-new-handler))
  (setf (ningle/app:route app "/posts" :method :post)
          (make-dynamic-handler 'post-create-handler))
  (setf (ningle/app:route app "/posts/:id/edit")
          (make-dynamic-handler 'post-edit-handler))
  (setf (ningle/app:route app "/posts/:id" :method :post)
          (make-dynamic-handler 'post-update-handler))
  (setf (ningle/app:route app "/posts/:id/toggle-status" :method :post)
          (make-dynamic-handler 'post-toggle-status-handler))
  (setf (ningle/app:route app "/posts/:id/confirm-delete")
          (make-dynamic-handler 'post-confirm-delete-handler))
  (setf (ningle/app:route app "/posts/:id/delete" :method :post)
          (make-dynamic-handler 'post-delete-handler))
  ;; User-notebook admin routes (auth required)
  (setf (ningle/app:route app "/notebooks/me")
          (make-dynamic-handler 'user-notebooks-handler))
  (setf (ningle/app:route app "/notebooks/new")
          (make-dynamic-handler 'user-notebook-new-handler))
  (setf (ningle/app:route app "/notebooks" :method :post)
          (make-dynamic-handler 'user-notebook-create-handler))
  (setf (ningle/app:route app "/notebooks/:id/edit")
          (make-dynamic-handler 'user-notebook-edit-handler))
  (setf (ningle/app:route app "/notebooks/:id" :method :post)
          (make-dynamic-handler 'user-notebook-update-handler))
  (setf (ningle/app:route app "/notebooks/:id/toggle-status" :method :post)
          (make-dynamic-handler 'user-notebook-toggle-status-handler))
  (setf (ningle/app:route app "/notebooks/:id/confirm-delete")
          (make-dynamic-handler 'user-notebook-confirm-delete-handler))
  (setf (ningle/app:route app "/notebooks/:id/delete" :method :post)
          (make-dynamic-handler 'user-notebook-delete-handler))
  ;; Course admin routes (auth required)
  (setf (ningle/app:route app "/courses/me")
          (make-dynamic-handler 'courses-me-handler))
  (setf (ningle/app:route app "/courses/new")
          (make-dynamic-handler 'course-new-handler))
  (setf (ningle/app:route app "/courses" :method :post)
          (make-dynamic-handler 'course-create-handler))
  (setf (ningle/app:route app "/courses/:id/edit")
          (make-dynamic-handler 'course-edit-handler))
  (setf (ningle/app:route app "/courses/:id" :method :post)
          (make-dynamic-handler 'course-update-handler))
  (setf (ningle/app:route app "/courses/:id/toggle-status" :method :post)
          (make-dynamic-handler 'course-toggle-status-handler))
  (setf (ningle/app:route app "/courses/:id/confirm-delete")
          (make-dynamic-handler 'course-confirm-delete-handler))
  (setf (ningle/app:route app "/courses/:id/delete" :method :post)
          (make-dynamic-handler 'course-delete-handler))
  (setf (ningle/app:route app "/courses/:id/notebooks" :method :post)
          (make-dynamic-handler 'course-add-notebook-handler))
  (setf (ningle/app:route app "/courses/:id/notebooks/:cn-id/up" :method :post)
          (make-dynamic-handler 'course-notebook-move-up-handler))
  (setf (ningle/app:route app "/courses/:id/notebooks/:cn-id/down" :method :post)
          (make-dynamic-handler 'course-notebook-move-down-handler))
  (setf (ningle/app:route app "/courses/:id/notebooks/:cn-id/remove" :method :post)
          (make-dynamic-handler 'course-notebook-remove-handler))
  ;; Public user-notebook routes (no auth)
  (setf (ningle/app:route app "/notebooks")
          (make-dynamic-handler 'notebooks-public-handler))
  (setf (ningle/app:route app "/n/:slug")
          (make-dynamic-handler 'public-user-notebook-handler))
  (setf (ningle/app:route app "/n/:slug/cells/:index/run" :method :post)
          (make-dynamic-handler 'public-user-notebook-cell-run-handler))
  ;; Public course routes (no auth)
  (setf (ningle/app:route app "/c/:slug")
          (make-dynamic-handler 'public-course-handler))
  (setf (ningle/app:route app "/courses")
          (make-dynamic-handler 'courses-public-handler))
  ;; Public blog routes (no auth)
  (setf (ningle/app:route app "/blog")
          (make-dynamic-handler 'blog-handler))
  (setf (ningle/app:route app "/blog/:slug")
          (make-dynamic-handler 'blog-post-handler))
  ;; Account management
  (setf (ningle/app:route app "/account")
          (make-dynamic-handler 'account-page-handler))
  (setf (ningle/app:route app "/account" :method :post)
          (make-dynamic-handler 'account-update-handler))
  (setf (ningle/app:route app "/account/confirm-delete")
          (make-dynamic-handler 'account-confirm-delete-handler))
  (setf (ningle/app:route app "/account/delete" :method :post)
          (make-dynamic-handler 'account-delete-handler))
  (setf (ningle/app:route app "/learn/sync" :method :post)
          (make-dynamic-handler 'learn-sync-handler))
  app)
