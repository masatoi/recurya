;;;; web/ui/notebook.lisp --- Notebook page and cell result HTMX fragment.

(defpackage #:recurya/web/ui/notebook
  (:use #:cl)
  (:import-from #:spinneret
                #:with-html-string
                #:with-html)
  (:import-from #:alexandria
                #:when-let*)
  (:import-from #:recurya/game/notebook
                #:notebook-id #:notebook-chapter #:notebook-title
                #:notebook-summary #:notebook-cells
                #:cell-id #:cell-kind #:cell-body #:cell-description
                #:notebook-cell-result-cell-id
                #:notebook-cell-result-kind
                #:notebook-cell-result-status
                #:notebook-cell-result-value
                #:notebook-cell-result-print-output
                #:notebook-cell-result-error-message
                #:notebook-cell-result-metrics
                #:notebook-cell-result-test-results)
  (:import-from #:recurya/web/ui/editor
                #:editor-head-tags
                #:editor-textarea)
  (:export #:render #:render-cell-result))

(in-package #:recurya/web/ui/notebook)

(defparameter *saved-codes* nil
  "Alist (cell-id-string . code-string) of DB-saved code, or nil for anonymous.")

(defparameter *passed-cells* nil
  "List of cell-id strings the current user has passed, or nil for anonymous.")

(defparameter *user* nil
  "Current user plist (with :id, :name, etc.), or nil for anonymous.")

(defparameter *styles*
  "body { font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
         margin: 0; background: #0f172a; color: #e2e8f0; line-height: 1.6; }
main { max-width: 900px; margin: 0 auto; padding: 2rem 1.5rem; }
.breadcrumb { color: #64748b; font-size: 0.9rem; margin-bottom: 1rem; }
.breadcrumb a { color: #38bdf8; text-decoration: none; }
h1 { font-size: 1.6rem; letter-spacing: -0.02em; color: #f8fafc; }
.summary { color: #94a3b8; margin-bottom: 2rem; }
.cell { margin-bottom: 1.75rem; }
.cell--prose { background: #111827; border-left: 3px solid #334155;
               padding: 1rem 1.25rem; border-radius: 0 8px 8px 0; }
.cell--code { background: #1e293b; border-radius: 10px; padding: 1rem; }
.cell--exercise { border: 1px solid #f59e0b; }
.cell__desc { color: #fbbf24; font-size: 0.95rem; margin-bottom: 0.75rem; }
.notebook-code { width:100%; background:#0f172a; color:#e2e8f0;
                 border:1px solid #334155; border-radius:6px;
                 font-family:'SF Mono',monospace; padding:0.5rem;
                 min-height: 4rem; box-sizing: border-box; }
.btn-run { background: #2563eb; color: #fff; border: none;
           padding: 0.55rem 1.25rem; border-radius: 8px;
           font-weight: 600; cursor: pointer; font-size: 0.9rem;
           margin-top: 0.5rem; }
.btn-run:hover { background: #1d4ed8; }
.btn-run.htmx-request { opacity: 0.7; cursor: wait; }
.result-panel { min-height: 1.5rem; margin-top: 0.75rem; }
.result-ok { color: #4ade80; font-family: monospace; }
.result-fail { color: #f87171; font-family: monospace; }
.result-error { color: #f87171; background: #2d1b1b;
                padding: 0.5rem 0.75rem; border-radius: 6px;
                font-family: monospace; font-size: 0.85rem;
                white-space: pre-wrap; }
.result-line { padding: 0.25rem 0; font-size: 0.9rem; }
.test-list { list-style: none; padding: 0; margin: 0.5rem 0 0 0; }
.metrics { color: #64748b; font-size: 0.8rem; margin-top: 0.5rem; }
.badge-pass { background: #16a34a; color: white;
              padding: 0.15rem 0.6rem; border-radius: 999px;
              font-size: 0.75rem; }
.print-output { background:#0f172a; padding:0.5rem;
                border-radius: 4px; color: #94a3b8;
                font-family: monospace; font-size: 0.85rem;
                white-space: pre-wrap; margin-top: 0.5rem; }
.user-banner { background: #1e293b; padding: 0.5rem 1rem; border-radius: 6px;
               margin-bottom: 1rem; font-size: 0.85rem; color: #94a3b8; }
.user-banner.anon { background: #1e2530; }
.user-banner a { color: #38bdf8; text-decoration: none; margin-left: 0.5rem; }
.user-banner strong { color: #f8fafc; }")

(defun notebook-url-id (notebook)
  "Lowercase symbol-name of the notebook ID, for use in URLs."
  (string-downcase (symbol-name (notebook-id notebook))))

(defun render-prose-tree (tree)
  "Render a Spinneret DSL list at runtime to an HTML string."
  (with-html-string (spinneret:interpret-html-tree tree)))

(defun render-prose-cell (cell)
  (with-html
    (:div :class "cell cell--prose"
          (:raw (render-prose-tree (cell-body cell))))
    ;; Positional placeholder so codes[] on the wire stays index-aligned
    ;; with notebook-cells. The value is always empty; prose cells carry
    ;; no user code.
    (:input :type "hidden"
            :class "notebook-code"
            :name "codes[]"
            :value "")))

(defun render-code-cell (cell index nb-id exercise-p)
  (let* ((result-id (format nil "cell-~D-result" index))
         (id-suffix (format nil "-~D" index))
         (cid-str (string-downcase (symbol-name (cell-id cell))))
         (saved (and *saved-codes*
                     (cdr (assoc cid-str *saved-codes* :test #'string=))))
         (initial-code (or saved (cell-body cell) ""))
         (passed-p (and exercise-p
                        (member cid-str *passed-cells* :test #'string=))))
    (with-html
      (:div :class
       (if exercise-p
           "cell cell--code cell--exercise"
           "cell cell--code")
       :data-cell-id cid-str
       (when exercise-p (:div :class "cell__desc" (cell-description cell)))
       (when passed-p (:span :class "badge-pass" "✓ done"))
       (:form :class "notebook-form"
        (:raw
         (editor-textarea "codes[]" initial-code :id-suffix
                          id-suffix :textarea-class "notebook-code"))
        (:button :type "button" :class "btn-run" :hx-post
         (format nil "/wardlisp/learn/~A/cells/~D/run" nb-id index) :hx-target
         (format nil "#~A" result-id) :hx-include ".notebook-code" :hx-swap
         "innerHTML" "Run"))
       (:div :class "result-panel" :id result-id)))))

(defun render-cell (cell index nb-id)
  (ecase (cell-kind cell)
    (:prose         (render-prose-cell cell))
    (:code-eval     (render-code-cell cell index nb-id nil))
    (:code-exercise (render-code-cell cell index nb-id t))))

(defun render (notebook &key user saved-codes passed-cells)
  "Render the full notebook page as a complete HTML document.
   USER is the logged-in user plist or nil.
   SAVED-CODES is an alist (cell-id-string . code-string) of DB-saved code.
   PASSED-CELLS is a list of cell-id strings this user has passed."
  (let ((*saved-codes* saved-codes) (*passed-cells* passed-cells) (*user* user))
    (with-html-string
      (:doctype)
      (:html
       (:head (:meta :charset "utf-8")
        (:meta :name "viewport" :content "width=device-width, initial-scale=1")
        (:title
         (format nil "~A — SICP ~A" (notebook-title notebook)
                 (notebook-chapter notebook)))
        (:style (:raw *styles*))
        (:script :src "https://unpkg.com/htmx.org@2.0.4" :integrity
         "sha384-HGfztofotfshcF7+8n44JQL2oJmowVChPTg48S+jvZoztPfvwD79OC/LTtG6dMp+"
         :crossorigin "anonymous")
        (:raw (editor-head-tags)))
       (:body :data-notebook-id (notebook-url-id notebook)
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
         (:div :class "breadcrumb" (:a :href "/wardlisp/" "WardLisp") " > "
          (:a :href "/wardlisp/learn" "SICPコース") " > "
          (notebook-chapter notebook))
         (:h1 (notebook-title notebook))
         (:p :class "summary" (notebook-summary notebook))
         (loop for cell in (notebook-cells notebook)
               for i from 0
               do (render-cell cell i (notebook-url-id notebook))))
        (:script :src "/static/js/learn.js"))))))

(defun render-test-results (results)
  (spinneret:with-html
    (:ul :class "test-list"
         (dolist (tr results)
           (:li :class "result-line"
                (if (getf tr :passed)
                    (:span :class "result-ok" "✓")
                    (:span :class "result-fail" "✗"))
                " "
                (:code (getf tr :input))
                " — expected "
                (:code (getf tr :expected))
                " got "
                (:code (or (getf tr :actual) "<error>")))))))

(defun render-cell-result (result)
  "Render one cell's result as an HTMX fragment (no html/head wrappers)."
  (with-html-string
    ;; Normalize :limit-exceeded to :error for rendering: both surface to
    ;; the user as an error message, and Spinneret's HTML walker mangles
    ;; hyphenated keywords in case/ecase clauses (treats them as custom
    ;; elements), so we flatten to plain keywords before dispatching.
    (let ((raw-status (notebook-cell-result-status result)))
      (let ((status (if (eq raw-status :limit-exceeded) :error raw-status)))
        (ecase status
          (:ok
           (:div :class "result-ok"
                 (:code "=> " (notebook-cell-result-value result))))
          (:pass
           (:div :class "result-ok" (:span :class "badge-pass" "PASS") " 全テスト合格")
           (render-test-results (notebook-cell-result-test-results result)))
          (:fail
           (:div :class "result-fail" "一部のテストが失敗しました")
           (render-test-results (notebook-cell-result-test-results result)))
          (:error
           (:pre :class "result-error"
                 (notebook-cell-result-error-message result))))))
    (let ((out (notebook-cell-result-print-output result)))
      (when (and out (plusp (length out))) (:pre :class "print-output" out)))))
