;;;; web/ui/user-notebooks.lisp --- Admin user-notebook list page with HTMX interactions.

(defpackage #:recurya/web/ui/user-notebooks
  (:use #:cl)
  (:import-from #:spinneret
                #:with-html-string)
  (:import-from #:recurya/web/ui/layout
                #:header
                #:header-styles
                #:common-styles
                #:format-timestamp)
  (:export #:render))

(in-package #:recurya/web/ui/user-notebooks)

(defparameter *page-styles*
  "/* User-notebooks admin page styles */
.actions-bar { display: flex; justify-content: flex-end; margin-bottom: 1rem; }
.new-nb-btn {
  display: inline-flex; align-items: center; gap: 0.4rem;
  padding: 0.5rem 1.2rem; border: none; border-radius: 6px;
  background: var(--color-primary); color: #fff;
  font-weight: 500; font-size: 0.85rem; cursor: pointer;
  text-decoration: none; transition: background 0.15s ease;
}
.new-nb-btn:hover { background: var(--color-primary-hover);
                    color: #fff; text-decoration: none; }
.status-pill { cursor: pointer; transition: opacity 0.15s ease; }
.status-pill:hover { opacity: 0.75; }
.status-pill.status-draft { background: var(--color-warning-bg);
                            color: var(--color-warning-text); }
.status-pill.status-private { background: #6b21a8; color: #f3e8ff; }
.status-pill.status-public { background: var(--color-success-bg);
                             color: var(--color-success-text); }
.actions-cell { display: flex; gap: 0.75rem; align-items: center; }
.actions-cell form { margin: 0; }
.flash-message { padding: 0.75rem 1rem; border-radius: 6px;
                 margin-bottom: 1rem; font-size: 0.9rem; }
.flash-message.success { background: var(--color-success-bg);
                         color: var(--color-success-text); }
.flash-message.error { background: var(--color-error-bg);
                       color: var(--color-error-text); }
tr.htmx-swapping { opacity: 0; transition: opacity 0.3s ease; }")

(defun render (&key user notebooks pagination message errors)
  "Render the admin user-notebook list page as an HTML string.

NOTEBOOKS is a list of plists with :id :title :slug :status
:published-at :created-at."
  (let ((user-timezone (getf user :timezone))
        (all-styles
          (concatenate 'string (common-styles) (header-styles) *page-styles*)))
    (spinneret:with-html-string
      (:doctype)
      (:html
       (:head (:meta :charset "utf-8")
              (:meta :name "viewport" :content "width=device-width, initial-scale=1")
              (:title "recurya - My Notebooks")
              (:script :src "https://unpkg.com/htmx.org@2.0.4"
                       :integrity "sha384-HGfztofotfshcF7+8n44JQL2oJmowVChPTg48S+jvZoztPfvwD79OC/LTtG6dMp+"
                       :crossorigin "anonymous")
              (:style (:raw all-styles)))
       (:body (:raw (header user))
              (:main
               (:div :class "card"
                     (:h1 "My Notebooks")
                     (:p :class "muted" "Manage your user-authored notebooks.")
                     (:div :class "actions-bar"
                           (:a :class "new-nb-btn" :href "/notebooks/new"
                               "+ New Notebook"))
                     (:div :id "flash-area"
                           (when message
                             (:div :class "flash-message success" message))
                           (when errors
                             (:div :class "flash-message error"
                                   (dolist (err errors) (:p err)))))
                     (if notebooks
                         (progn
                           (:table
                            (:thead
                             (:tr (:th "Title") (:th "Status")
                                  (:th "Published") (:th "Created")
                                  (:th "Actions")))
                            (:tbody :id "notebooks-body"
                                    (dolist (nb notebooks)
                                      (let* ((id (getf nb :id))
                                             (slug (getf nb :slug))
                                             (title (getf nb :title))
                                             (status (getf nb :status))
                                             (visibility (or (getf nb :visibility)
                                                             "private"))
                                             (status-lower (string-downcase
                                                            (or status "draft")))
                                             (visibility-lower (string-downcase
                                                                visibility))
                                             (state-class
                                              (cond ((equal status-lower "draft")
                                                     "status-draft")
                                                    ((equal visibility-lower "public")
                                                     "status-public")
                                                    (t "status-private")))
                                             (label
                                              (cond ((equal status-lower "draft")
                                                     "Draft")
                                                    ((equal visibility-lower "public")
                                                     "Public")
                                                    (t "Private")))
                                             (published-at (getf nb :published-at))
                                             (created-at (getf nb :created-at)))
                                        (:tr :id (format nil "nb-row-~A" id)
                                             (:td
                                              (if (and slug (string= status "published"))
                                                  (:a :href (format nil "/n/~A" slug)
                                                      title)
                                                  title))
                                             (:td
                                              (:span :class (format nil
                                                                    "status-pill ~A"
                                                                    state-class)
                                                     :id (format nil "status-~A" id)
                                                     :data-status status-lower
                                                     :data-visibility visibility-lower
                                                     :hx-post (format nil
                                                                      "/notebooks/~A/toggle-status"
                                                                      id)
                                                     :hx-target (format nil "#status-~A" id)
                                                     :hx-swap "outerHTML"
                                                     label))
                                             (:td (if published-at
                                                      (or (format-timestamp published-at
                                                                            user-timezone)
                                                          "—")
                                                      "—"))
                                             (:td (or (format-timestamp created-at
                                                                        user-timezone)
                                                      "—"))
                                             (:td
                                              (:div :class "actions-cell"
                                                    (:a :class "link"
                                                        :href (format nil
                                                                      "/notebooks/~A/edit"
                                                                      id)
                                                        "Edit")
                                                    (:button :class "button-danger btn-sm"
                                                             :hx-get
                                                             (format nil
                                                                     "/notebooks/~A/confirm-delete"
                                                                     id)
                                                             :hx-target "#modal-container"
                                                             :hx-swap "innerHTML"
                                                             "Delete"))))))))
                           (when pagination
                             (let ((current-page (getf pagination :current-page))
                                   (total-pages (getf pagination :total-pages))
                                   (has-prev (getf pagination :has-prev))
                                   (has-next (getf pagination :has-next))
                                   (prev-url (getf pagination :prev-url))
                                   (next-url (getf pagination :next-url)))
                               (:div :class "pagination"
                                     (:span :class "pagination-info"
                                            (format nil "Page ~A of ~A"
                                                    current-page total-pages))
                                     (:nav :class "pagination-nav"
                                           (if has-prev
                                               (:a :class "pagination-btn"
                                                   :href prev-url "← Previous")
                                               (:span :class "pagination-btn disabled"
                                                      "← Previous"))
                                           (if has-next
                                               (:a :class "pagination-btn"
                                                   :href next-url "Next →")
                                               (:span :class "pagination-btn disabled"
                                                      "Next →")))))))
                         (:p :class "muted"
                             "No notebooks yet. Create your first one!"))))
              (:div :id "modal-container"))))))
