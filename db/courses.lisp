;;;; db/courses.lisp --- CRUD operations for courses.

(defpackage #:recurya/db/courses
  (:use #:cl)
  (:import-from #:mito
                #:find-dao
                #:select-dao
                #:insert-dao
                #:save-dao
                #:delete-dao)
  (:import-from #:sxql #:where #:order-by #:limit)
  (:import-from #:recurya/db/core #:generate-uuid #:ensure-uuid)
  (:import-from #:recurya/db/posts #:slugify)
  (:import-from #:recurya/models/course
                #:course
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
  (:export #:course
           #:course-id
           #:course-slug
           #:course-title
           #:course-summary
           #:course-status
           #:course-published-at
           #:course-author
           #:course-author-id
           #:course-created-at
           #:course-updated-at
           #:create-course!
           #:get-course-by-id
           #:get-course-by-slug))

(in-package #:recurya/db/courses)

(defun create-course! (&key title summary slug status published-at author course-id)
  "Create a new course and return the created instance.

Arguments:
  TITLE         - Course title (required)
  SUMMARY       - Short summary, max 500 chars (optional)
  SLUG          - URL slug (auto-generated from title if omitted)
  STATUS        - \"draft\" or \"published\" (default: \"draft\")
  PUBLISHED-AT  - Timestamp when published (optional)
  AUTHOR        - Users instance (required, FK is NOT NULL)
  COURSE-ID     - Pre-generated UUID (optional)

Returns:
  The newly created COURSE instance."
  (let ((id (or course-id (generate-uuid)))
        (slug (or slug (slugify title))))
    (insert-dao
     (make-instance 'course
                    :id id
                    :slug slug
                    :title title
                    :summary summary
                    :status (or status "draft")
                    :published-at published-at
                    :author author))))

(defun get-course-by-id (id)
  "Fetch a course by UUID.

Returns:
  COURSE instance if found, NIL otherwise."
  (find-dao 'course :id (ensure-uuid id)))

(defun get-course-by-slug (slug)
  "Fetch a course by slug.

Returns:
  COURSE instance if found, NIL otherwise."
  (find-dao 'course :slug slug))
