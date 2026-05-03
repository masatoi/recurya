;;;; web/ui/course-form.lisp --- Create/edit form for courses.

(defpackage #:recurya/web/ui/course-form
  (:use #:cl)
  (:import-from #:spinneret
                #:with-html-string)
  (:import-from #:recurya/web/ui/layout
                #:header
                #:header-styles
                #:common-styles)
  (:export #:render))

(in-package #:recurya/web/ui/course-form)

(defparameter *form-page-styles*
  "/* Course form page styles */
.course-form { display: flex; flex-direction: column; gap: 1.25rem; }
.form-group { display: flex; flex-direction: column; gap: 0.35rem; }
.form-group label { font-weight: 600; font-size: 0.9rem; }
.form-group input,
.form-group textarea,
.form-group select { width: 100%; box-sizing: border-box; }
.form-group textarea.summary-field { min-height: 80px; resize: vertical; }
.form-hint { color: var(--color-text-muted); font-size: 0.8rem; }
.form-actions { display: flex; gap: 0.75rem; margin-top: 0.5rem; }
.flash-message { padding: 0.75rem 1rem; border-radius: 6px;
                 margin-bottom: 1rem; font-size: 0.9rem; }
.flash-message.success { background: var(--color-success-bg);
                         color: var(--color-success-text); }
.flash-message.error { background: var(--color-error-bg);
                       color: var(--color-error-text); }
.error-list { list-style: none; padding: 0; margin: 0; }
.error-list li { padding: 0.25rem 0; font-size: 0.85rem; }
.error-list .line { display: inline-block; min-width: 4rem;
                    color: var(--color-text-muted);
                    font-family: monospace; }")

(defun render (&key user course message errors)
  "Render the course create/edit form as an HTML string.

COURSE is a plist with :id :title :slug :summary :status when editing.
When COURSE is NIL, renders a new-course form. ERRORS is a list of
plists like (:line N :message \"...\")."
  (let* ((editing-p (not (null course)))
         (c-id      (getf course :id))
         (c-title   (or (getf course :title) ""))
         (c-slug    (or (getf course :slug) ""))
         (c-summary (or (getf course :summary) ""))
         (c-status  (or (getf course :status) "draft"))
         (action-url (if editing-p
                         (format nil "/courses/~A" c-id)
                         "/courses"))
         (page-title (if editing-p "Edit Course" "New Course"))
         (all-styles
           (concatenate 'string
                        (common-styles) (header-styles) *form-page-styles*)))
    (spinneret:with-html-string
      (:doctype)
      (:html
       (:head (:meta :charset "utf-8")
              (:meta :name "viewport" :content "width=device-width, initial-scale=1")
              (:title (format nil "recurya - ~A" page-title))
              (:style (:raw all-styles)))
       (:body (:raw (header user))
              (:main
               (:div :class "card"
                     (:h1 page-title)
                     (when message
                       (:div :class "flash-message success" message))
                     (when errors
                       (:div :class "flash-message error"
                             (:strong "Validation errors:")
                             (:ul :class "error-list"
                                  (dolist (err errors)
                                    (:li
                                     (:span :class "line"
                                            (format nil "L~A" (or (getf err :line) "?")))
                                     " "
                                     (getf err :message))))))
                     (:form :class "course-form" :method "post" :action action-url
                            (:div :class "form-group"
                                  (:label :for "title" "Title")
                                  (:input :type "text" :id "title" :name "title"
                                          :value c-title :required t
                                          :placeholder "Course title"))
                            (:div :class "form-group"
                                  (:label :for "slug" "Slug")
                                  (:input :type "text" :id "slug" :name "slug"
                                          :value c-slug
                                          :placeholder "auto-generated-from-title")
                                  (:span :class "form-hint"
                                         "Leave blank to auto-generate from title."))
                            (:div :class "form-group"
                                  (:label :for "summary" "Summary")
                                  (:textarea :id "summary" :name "summary"
                                             :class "summary-field"
                                             :maxlength "500"
                                             :placeholder "Short summary (max 500 chars)"
                                             c-summary))
                            (:div :class "form-group"
                                  (:label :for "status" "Status")
                                  (:select :id "status" :name "status"
                                           (:option :value "draft"
                                                    :selected
                                                    (when (equal c-status "draft") "selected")
                                                    "Draft")
                                           (:option :value "published"
                                                    :selected
                                                    (when (equal c-status "published") "selected")
                                                    "Published")))
                            (:div :class "form-actions"
                                  (:button :type "submit" :class "btn-primary"
                                           (if editing-p "Update Course" "Create Course"))
                                  (:a :class "btn-secondary" :href "/courses/me"
                                      :style "text-decoration:none;text-align:center"
                                      "Cancel"))))))))))
