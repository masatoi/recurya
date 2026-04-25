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

(defparameter *user* nil
  "Current user plist (with :id, :name, etc.), or nil for anonymous.")

(defparameter *passed-counts* nil
  "Alist (notebook-id-keyword . passed-cell-count) for the logged-in user.")

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
.nb-card__meta { color: #64748b; font-size: 0.8rem; margin-top: 0.75rem; }
.user-banner { background: #1e293b; padding: 0.5rem 1rem; border-radius: 6px;
               margin-bottom: 1rem; font-size: 0.85rem; color: #94a3b8; }
.user-banner.anon { background: #1e2530; }
.user-banner a { color: #38bdf8; text-decoration: none; margin-left: 0.5rem; }
.user-banner strong { color: #f8fafc; }
.nb-card__progress { color: #4ade80; font-size: 0.85rem; margin-top: 0.5rem; }")

(defun notebook-url-id (nb)
  "Lowercase symbol-name of the notebook ID, for use in URLs."
  (string-downcase (symbol-name (notebook-id nb))))

(defun render (notebooks &key user passed-counts)
  "Render the SICP course index page as a complete HTML document.
   USER is the logged-in user plist or nil. PASSED-COUNTS is an alist
   (notebook-id-keyword . count) for the logged-in user."
  (let ((*user* user)
        (*passed-counts* passed-counts))
    (with-html-string
      (:doctype)
      (:html
       (:head
        (:meta :charset "utf-8")
        (:title "SICP コース — Recurya")
        (:style (:raw *styles*)))
       (:body :data-page "learn-home"
        :data-logged-in (if *user* "true" "false")
        (:main
         (cond
           (*user*
            (:div :class "user-banner"
                  "ログイン中: "
                  (:strong (or (getf *user* :name) "User"))
                  " · " (:form :method "post" :action "/logout"
                               :style "display:inline;"
                               (:button :type "submit" :class "user-banner__logout"
                                        :style "background:none;border:none;color:#38bdf8;cursor:pointer;padding:0;font:inherit;"
                                        "ログアウト"))))
           (t
            (:div :class "user-banner anon"
                  "進捗を端末を超えて保存するには "
                  (:a :href "/login" "ログイン")
                  " してください。")))
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
                                   (length (notebook-cells nb))))
                     (let* ((nb-id (recurya/game/notebook:notebook-id nb))
                            (count (and *passed-counts*
                                        (or (cdr (assoc nb-id *passed-counts*)) 0)))
                            (total (count-if (lambda (c)
                                               (eq (recurya/game/notebook:cell-kind c)
                                                   :code-exercise))
                                             (recurya/game/notebook:notebook-cells nb))))
                       (when (and *user* (plusp total))
                         (:div :class "nb-card__progress"
                               (format nil "~D / ~D 完了" count total)))))))))
        (:script :src "/static/js/learn.js"))))))
