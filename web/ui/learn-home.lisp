;;;; web/ui/learn-home.lisp --- SICP course index page.

(defpackage #:recurya/web/ui/learn-home
  (:use #:cl)
  (:import-from #:spinneret
                #:with-html-string)
  (:import-from #:recurya/game/notebook
                #:notebook-id #:notebook-chapter
                #:notebook-title #:notebook-summary
                #:notebook-cells)
  (:export #:render))

(in-package #:recurya/web/ui/learn-home)

(defparameter *styles*
  "body { font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
         margin: 0; background: #0f172a; color: #e2e8f0; line-height: 1.6; }
main { max-width: 760px; margin: 0 auto; padding: 3rem 1.5rem; }
h1 { font-size: 2rem; letter-spacing: -0.03em; text-align: center;
     color: #f8fafc; margin-bottom: 0.5rem; }
.subtitle { text-align: center; color: #94a3b8; margin-bottom: 2.5rem; }
.note { text-align: center; color: #64748b; font-size: 0.85rem;
        margin-bottom: 2rem; }
.nb-list { list-style: none; padding: 0; display: flex; flex-direction: column;
           gap: 1rem; }
.nb-card { background: #1e293b; border-radius: 12px; padding: 1.5rem;
           text-decoration: none; color: #e2e8f0; display: block;
           border: 1px solid #334155; transition: border-color 0.15s; }
.nb-card:hover { border-color: #38bdf8; }
.nb-card__ch { color: #38bdf8; font-family: monospace; font-size: 0.85rem; }
.nb-card__title { font-size: 1.2rem; font-weight: 700; margin: 0.25rem 0;
                  color: #f8fafc; }
.nb-card__summary { color: #94a3b8; font-size: 0.9rem; margin: 0; }
.nb-card__meta { color: #64748b; font-size: 0.8rem; margin-top: 0.75rem; }")

(defun notebook-url-id (nb)
  "Lowercase symbol-name of the notebook ID, for use in URLs."
  (string-downcase (symbol-name (notebook-id nb))))

(defun render (notebooks)
  "Render the SICP course index page as a complete HTML document."
  (with-html-string
    (:doctype)
    (:html
     (:head
      (:meta :charset "utf-8")
      (:title "SICP コース — Recurya")
      (:style (:raw *styles*)))
     (:body :data-page "learn-home"
      (:main
       (:h1 "SICP で学ぶ WardLisp")
       (:p :class "subtitle"
           "Structure and Interpretation of Computer Programs")
       (:p :class "note" "進捗はこのブラウザ内にのみ保存されます。")
       (:ul :class "nb-list"
            (dolist (nb notebooks)
              (:li
               (:a :class "nb-card"
                   :href (format nil "/wardlisp/learn/~A"
                                 (notebook-url-id nb))
                   :data-notebook-id (notebook-url-id nb)
                   (:div :class "nb-card__ch" (notebook-chapter nb))
                   (:h3 :class "nb-card__title" (notebook-title nb))
                   (:p :class "nb-card__summary" (notebook-summary nb))
                   (:div :class "nb-card__meta"
                         (format nil "~A セル"
                                 (length (notebook-cells nb)))))))))
      (:script :src "/static/js/learn.js")))))
