;;;; web/ui/profile.lisp --- Public user profile page (@handle).
;;;;
;;;; Renders a per-author landing page with their public notebooks and
;;;; courses. Reached via GET /@:handle. Notebooks and courses come from
;;;; recurya/db/notebooks:list-public-notebooks-of and
;;;; recurya/db/courses:list-public-courses-of.

(defpackage #:recurya/web/ui/profile
  (:use #:cl)
  (:import-from #:spinneret #:with-html-string)
  (:import-from #:recurya/web/ui/layout #:format-timestamp)
  (:export #:render-profile-page))

(in-package #:recurya/web/ui/profile)

(defparameter *styles*
  "/* Public profile page styles */
body { font-family: 'Inter', -apple-system, BlinkMacSystemFont,
                    'Segoe UI', Roboto, sans-serif;
       margin: 0; background: #f8fafc; color: #0f172a; line-height: 1.6; }
main { max-width: 760px; margin: 0 auto; padding: 3rem 1.5rem 4rem; }
.profile-header { text-align: center; margin-bottom: 3rem; }
.profile-header h1 { font-size: 2.2rem; letter-spacing: -0.03em;
                     margin-bottom: 0.25rem; }
.profile-header .handle { color: #0ea5e9; font-size: 1.05rem;
                          font-weight: 600; }
.profile-header .display-name { color: #475569; font-size: 1.05rem;
                                margin-top: 0.5rem; }
.section { margin-top: 2.5rem; }
.section h2 { font-size: 1.25rem; letter-spacing: -0.02em;
              margin-bottom: 1rem; color: #0f172a; }
.card { background: #fff; border-radius: 12px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.08);
        padding: 1.5rem 1.75rem; margin-bottom: 1rem;
        transition: box-shadow 0.15s ease; }
.card:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.12); }
.card__title { margin: 0 0 0.5rem; font-size: 1.15rem;
               letter-spacing: -0.02em; }
.card__title a { color: #0f172a; text-decoration: none; }
.card__title a:hover { color: #0ea5e9; }
.card__meta { color: #64748b; font-size: 0.85rem; margin-bottom: 0.5rem; }
.card__summary { color: #475569; line-height: 1.5; }
.empty { color: #64748b; font-style: italic; padding: 0.5rem 0; }")

(defun render-profile-page (&key handle display-name notebooks courses)
  "Render the public profile page for HANDLE.

Arguments:
  HANDLE       - The user's URL handle string (e.g. \"alice\").
  DISPLAY-NAME - Their display name (string).
  NOTEBOOKS    - List of NOTEBOOK DAO instances (their public+published).
  COURSES      - List of COURSE DAO instances (their public+published).

Returns the full HTML page as a string."
  (with-html-string
    (:doctype)
    (:html
     (:head
      (:meta :charset "utf-8")
      (:meta :name "viewport"
             :content "width=device-width, initial-scale=1")
      (:title (format nil "@~A" handle))
      (:style (:raw *styles*)))
     (:body
      (:main
       (:div :class "profile-header"
             (:h1 (or display-name handle))
             (:div :class "handle"
                   (format nil "@~A" handle))
             (when (and display-name
                        (not (string= display-name handle)))
               (:div :class "display-name" "")))
       (:section :class "section"
                 (:h2 "Notebooks")
                 (cond
                   ((null notebooks)
                    (:p :class "empty"
                        "No public notebooks yet."))
                   (t
                    (dolist (nb notebooks)
                      (let ((slug (recurya/db/notebooks:notebook-slug nb))
                            (title (recurya/db/notebooks:notebook-title nb))
                            (summary (recurya/db/notebooks:notebook-summary nb))
                            (published-at
                             (recurya/db/notebooks:notebook-published-at nb)))
                        (:div :class "card"
                              (:h3 :class "card__title"
                                   (:a :href (format nil "/@~A/~A"
                                                     handle slug)
                                       title))
                              (:div :class "card__meta"
                                    (or (format-timestamp published-at)
                                        ""))
                              (when (and summary (string/= summary ""))
                                (:p :class "card__summary" summary))))))))
       (:section :class "section"
                 (:h2 "Courses")
                 (cond
                   ((null courses)
                    (:p :class "empty"
                        "No public courses yet."))
                   (t
                    (dolist (c courses)
                      (let ((slug (recurya/db/courses:course-slug c))
                            (title (recurya/db/courses:course-title c))
                            (summary (recurya/db/courses:course-summary c))
                            (published-at
                             (recurya/db/courses:course-published-at c)))
                        (:div :class "card"
                              (:h3 :class "card__title"
                                   (:a :href (format nil "/c/@~A/~A"
                                                     handle slug)
                                       title))
                              (:div :class "card__meta"
                                    (or (format-timestamp published-at)
                                        ""))
                              (when (and summary (string/= summary ""))
                                (:p :class "card__summary" summary))))))))
       )))))
