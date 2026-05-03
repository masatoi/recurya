;;;; web/ui/notebook-list.lisp --- Public listing of user-authored notebooks.

(defpackage #:recurya/web/ui/notebook-list
  (:use #:cl)
  (:import-from #:spinneret #:with-html-string)
  (:import-from #:recurya/web/ui/layout
                #:format-timestamp)
  (:export #:render))

(in-package #:recurya/web/ui/notebook-list)

(defparameter *styles*
  "/* Public user-notebook listing styles */
body { font-family: 'Inter', -apple-system, BlinkMacSystemFont,
                    'Segoe UI', Roboto, sans-serif;
       margin: 0; background: #f8fafc; color: #0f172a; line-height: 1.6; }
main { max-width: 760px; margin: 0 auto; padding: 3rem 1.5rem 4rem; }
.list-header { text-align: center; margin-bottom: 3rem; }
.list-header h1 { font-size: 2.2rem; letter-spacing: -0.03em;
                  margin-bottom: 0.5rem; }
.list-header p { color: #64748b; font-size: 1.05rem; }
.nb-card { background: #fff; border-radius: 12px;
           box-shadow: 0 1px 3px rgba(0,0,0,0.08);
           padding: 1.75rem 2rem; margin-bottom: 1.5rem;
           transition: box-shadow 0.15s ease; }
.nb-card:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.12); }
.nb-card__title { margin: 0 0 0.5rem; font-size: 1.35rem;
                  letter-spacing: -0.02em; }
.nb-card__title a { color: #0f172a; text-decoration: none; }
.nb-card__title a:hover { color: #0ea5e9; }
.nb-card__meta { color: #64748b; font-size: 0.85rem; margin-bottom: 0.75rem; }
.nb-card__summary { color: #475569; line-height: 1.65; margin-bottom: 1rem; }
.nb-card__open { color: #0ea5e9; font-weight: 600; text-decoration: none;
                 font-size: 0.9rem; }
.nb-card__open:hover { text-decoration: underline; }
.pagination { display: flex; align-items: center; justify-content: center;
              gap: 1rem; margin-top: 2rem; padding-top: 1.5rem;
              border-top: 1px solid #e2e8f0; }
.pagination-info { color: #64748b; font-size: 0.9rem; }
.pagination-nav { display: flex; gap: 0.5rem; }
.pagination-btn { display: inline-flex; padding: 0.5rem 1rem;
                  border: 1px solid #cbd5e1; border-radius: 8px;
                  background: #fff; color: #0f172a; font-weight: 500;
                  font-size: 0.9rem; text-decoration: none; }
.pagination-btn:hover { background: #f1f5f9; text-decoration: none; }
.pagination-btn.disabled { opacity: 0.5; cursor: not-allowed;
                           pointer-events: none; }
.empty { text-align: center; color: #64748b; padding: 3rem 0; }")

(defun render (&key notebooks pagination)
  "Render the public user-notebook listing page (published only).
NOTEBOOKS is a list of plists with :slug :title :summary
:published-at :author-name."
  (with-html-string
    (:doctype)
    (:html
     (:head (:meta :charset "utf-8")
            (:meta :name "viewport" :content "width=device-width, initial-scale=1")
            (:title "Notebooks")
            (:style (:raw *styles*)))
     (:body
      (:main
       (:div :class "list-header"
             (:h1 "Notebooks")
             (:p "Community-authored Lisp notebooks."))
       (if notebooks
           (progn
             (dolist (nb notebooks)
               (let ((slug (getf nb :slug))
                     (title (getf nb :title))
                     (summary (getf nb :summary))
                     (published-at (getf nb :published-at))
                     (author-name (getf nb :author-name)))
                 (:div :class "nb-card"
                       (:h2 :class "nb-card__title"
                            (:a :href (format nil "/n/~A" slug) title))
                       (:div :class "nb-card__meta"
                             (format nil "~@[~A~]~@[ · ~A~]" author-name
                                     (format-timestamp published-at)))
                       (when (and summary (string/= summary ""))
                         (:p :class "nb-card__summary" summary))
                       (:a :class "nb-card__open"
                           :href (format nil "/n/~A" slug)
                           "Open →"))))
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
           (:p :class "empty"
               "No notebooks yet. Check back soon!")))))))
