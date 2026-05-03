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
                #:notebook-cell-result-error-cell-id
                #:notebook-cell-result-metrics
                #:notebook-cell-result-test-results)
  (:import-from #:recurya/web/ui/editor
                #:editor-head-tags
                #:editor-textarea)
  (:import-from #:recurya/game/notebooks/registry
                #:all-notebooks)
  (:export #:render #:render-cell-result))

(in-package #:recurya/web/ui/notebook)

(defparameter *saved-codes* nil
  "Alist (cell-id-string . code-string) of DB-saved code, or nil for anonymous.")

(defparameter *passed-cells* nil
  "List of cell-id strings the current user has passed, or nil for anonymous.")

(defparameter *user* nil
  "Current user plist (with :id, :name, etc.), or nil for anonymous.")

(defparameter *run-cell-base* nil
  "URL prefix used to build run-cell HTMX endpoints for the cell currently
being rendered. Set by `render'. The full URL is
\"<base>/cells/<index>/run\".")

(defparameter *chapter-titles*
  '(("1" . "第1章 手続きによる抽象化")
    ("2" . "第2章 データによる抽象化")
    ("3" . "第3章 並行性、状態、ストリーム"))
  "Top-level chapter labels for the sidebar TOC.")

(defparameter *section-titles*
  '(("1.1" . "1.1 言語の要素")
    ("1.2" . "1.2 手続きと作りだすプロセス")
    ("1.3" . "1.3 高階手続きでの抽象化の定式化")
    ("2.1" . "2.1 データ抽象入門")
    ("2.2" . "2.2 階層データと閉包性")
    ("2.3" . "2.3 記号データ")
    ("2.4" . "2.4 抽象データの複数表現")
    ("2.5" . "2.5 ジェネリック演算系")
    ("3.1" . "3.1 代入と局所状態")
    ("3.2" . "3.2 評価の環境モデル")
    ("3.3" . "3.3 可変データを用いたモデル化")
    ("3.4" . "3.4 並行性")
    ("3.5" . "3.5 ストリーム"))
  "Section labels (e.g. 1.1) for the sidebar TOC.")

(defparameter *styles*
  "body { font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
         margin: 0; background: #0f172a; color: #e2e8f0; line-height: 1.6; }
main { max-width: 900px; margin: 0 auto; padding: 2rem 1.5rem; flex: 1; min-width: 0; }
.layout { display: flex; align-items: flex-start; }
.sidebar { width: 260px; flex-shrink: 0; background: #0a0f1a;
           border-right: 1px solid #1e293b; padding: 1.5rem 1rem;
           overflow-y: auto; max-height: 100vh; position: sticky; top: 0;
           font-size: 0.85rem; }
.sidebar-home { display: block; color: #38bdf8; font-weight: 700;
                margin-bottom: 1rem; text-decoration: none; font-size: 0.95rem; }
.sb-chapter { margin-bottom: 0.5rem; border: 1px solid #1e293b;
              border-radius: 6px; padding: 0.4rem 0.6rem; }
.sb-chapter[open] { background: #0f172a; }
.sb-summary { color: #f8fafc; font-weight: 600; cursor: pointer;
              font-size: 0.88rem; padding: 0.2rem 0; }
.sb-summary:hover { color: #38bdf8; }
.sb-section { margin: 0.4rem 0 0.6rem 0; }
.sb-section-title { color: #94a3b8; font-size: 0.75rem; font-weight: 600;
                    margin: 0.5rem 0 0.25rem 0; }
.sb-list { list-style: none; padding: 0; margin: 0; }
.sb-list li { margin: 0; }
.sb-link { display: block; padding: 0.2rem 0.5rem; color: #94a3b8;
           text-decoration: none; font-size: 0.8rem; border-radius: 4px;
           line-height: 1.35; }
.sb-link:hover { background: #1e293b; color: #e2e8f0; }
.sb-link.active { background: #1e3a8a; color: #f8fafc; font-weight: 600; }
@media (max-width: 768px) {
  .layout { display: block; }
  .sidebar { width: auto; max-height: none; position: static;
             border-right: none; border-bottom: 1px solid #1e293b; }
}
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
.btn-reset { background: none; color: #94a3b8; border: 1px solid #334155;
             padding: 0.4rem 0.9rem; border-radius: 8px; font-size: 0.8rem;
             cursor: pointer; margin-top: 0.5rem; margin-left: 0.4rem; }
.btn-reset:hover { color: #f8fafc; border-color: #64748b; }
.error-hint { color: #fbbf24; font-size: 0.8rem; margin-top: 0.4rem;
              padding: 0.3rem 0.6rem; background: #1e293b;
              border-left: 3px solid #f59e0b; border-radius: 0 4px 4px 0; }
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
  "Lowercase id of the notebook, for use in URLs.
Accepts both keyword (legacy SICP) and string (UUID) ids."
  (let ((id (notebook-id notebook)))
    (string-downcase (if (keywordp id) (symbol-name id) (string id)))))

(defun %cell-id->string (id)
  "Stringify a cell or notebook id, accepting both keyword (legacy SICP)
and string (UUID) representations. NIL becomes \"\"."
  (cond ((null id) "")
        ((keywordp id) (string-downcase (symbol-name id)))
        ((symbolp id) (string-downcase (symbol-name id)))
        (t (string id))))

(defun %chapter-prefix (notebook)
  "Return the chapter number string (e.g. '1') from notebook-chapter '1.1.1'."
  (let ((c (notebook-chapter notebook)))
    (if (and c (plusp (length c))) (subseq c 0 1) "")))

(defun %section-prefix (notebook)
  "Return the section prefix (e.g. '1.1') from notebook-chapter '1.1.1'."
  (let ((c (notebook-chapter notebook)))
    (if (and c (plusp (length c)))
        (let ((p (position #\. c :start 2)))
          (if p (subseq c 0 p) c))
        "")))

(defun render-sidebar (current-id all)
  "Render a left sidebar with collapsible chapter TOC.
   ALL is the list of notebooks (typically (all-notebooks)).
   CURRENT-ID is the notebook-id keyword of the page being rendered.
   The chapter containing CURRENT-ID is shown expanded; others collapsed."
  (let* ((current-nb (find current-id all :key #'notebook-id))
         (current-ch (and current-nb (%chapter-prefix current-nb))))
    (with-html
      (:aside :class "sidebar"
              (:a :class "sidebar-home" :href "/wardlisp/learn"
                  "📘 SICP コース")
              (dolist (ch '("1" "2" "3"))
                (let ((ch-nbs (sort (copy-list
                                     (remove-if-not
                                      (lambda (nb) (string= (%chapter-prefix nb) ch))
                                      all))
                                    #'string<
                                    :key #'notebook-chapter)))
                  (when ch-nbs
                    (:details :class "sb-chapter"
                              :open (when (equal ch current-ch) "open")
                              (:summary :class "sb-summary"
                                        (or (cdr (assoc ch *chapter-titles* :test #'string=))
                                            (format nil "Chapter ~A" ch)))
                              (let (sections-seen)
                                (dolist (nb ch-nbs)
                                  (let ((sec (%section-prefix nb)))
                                    (unless (member sec sections-seen :test #'string=)
                                      (push sec sections-seen))))
                                (dolist (sec (nreverse sections-seen))
                                  (:div :class "sb-section"
                                        (:h4 :class "sb-section-title"
                                             (or (cdr (assoc sec *section-titles*
                                                             :test #'string=))
                                                 sec))
                                        (:ul :class "sb-list"
                                             (dolist (nb (remove-if-not
                                                          (lambda (n)
                                                            (string= (%section-prefix n) sec))
                                                          ch-nbs))
                                               (:li
                                                (:a :href (format nil "/wardlisp/learn/~A"
                                                                  (string-downcase
                                                                   (symbol-name
                                                                    (notebook-id nb))))
                                                    :class (if (eq (notebook-id nb) current-id)
                                                               "sb-link active"
                                                               "sb-link")
                                                    (format nil "~A ~A"
                                                            (notebook-chapter nb)
                                                            (notebook-title nb)))))))))))))))))

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
  (declare (ignore nb-id))
  (let* ((result-id (format nil "cell-~D-result" index))
         (id-suffix (format nil "-~D" index))
         (cid-str (%cell-id->string (cell-id cell)))
         (saved
           (and *saved-codes*
                (cdr (assoc cid-str *saved-codes* :test #'string=))))
         (original-code (or (cell-body cell) ""))
         (initial-code (or saved original-code ""))
         (passed-p
           (and exercise-p (member cid-str *passed-cells* :test #'string=)))
         (run-url (format nil "~A/cells/~D/run" (or *run-cell-base* "") index)))
    (with-html
      (:div :class
            (if exercise-p
                "cell cell--code cell--exercise"
                "cell cell--code")
            :data-cell-id cid-str :data-original-code original-code
            :data-textarea-id (format nil "editor-source~A" id-suffix)
            (when exercise-p (:div :class "cell__desc" (cell-description cell)))
            (when passed-p (:span :class "badge-pass" "✓ done"))
            (:raw
             (editor-textarea "codes[]" initial-code :id-suffix id-suffix
                              :textarea-class "notebook-code"))
            (:button :type "button" :class "btn-run"
                     :hx-post run-url
                     :hx-target (format nil "#~A" result-id)
                     :hx-include ".notebook-code"
                     :hx-swap "innerHTML"
                     "Run")
            (:button :type "button" :class "btn-reset"
                     :title "セルを初期コードに戻す"
                     "リセット")
            (:div :class "result-panel" :id result-id)))))

(defun render-cell (cell index nb-id)
  (ecase (cell-kind cell)
    (:prose         (render-prose-cell cell))
    (:code-eval     (render-code-cell cell index nb-id nil))
    (:code-exercise (render-code-cell cell index nb-id t))))

(defun render (notebook &key user saved-codes passed-cells
                        (sidebar-notebooks t)
                        run-cell-base)
  "Render the full notebook page as a complete HTML document.
USER is the logged-in user plist or nil.
SAVED-CODES is an alist (cell-id-string . code-string) of DB-saved code.
PASSED-CELLS is a list of cell-id strings this user has passed.
SIDEBAR-NOTEBOOKS controls the left TOC: T (default) uses (all-notebooks),
NIL omits the sidebar entirely (used for stand-alone user-authored
notebooks at /n/:slug), or pass an explicit list to use a custom set.
RUN-CELL-BASE is the URL prefix for run-cell HTMX endpoints. Defaults
to the SICP route /wardlisp/learn/<id> when omitted."
  (let* ((*saved-codes* saved-codes)
         (*passed-cells* passed-cells)
         (*user* user)
         (*run-cell-base*
           (or run-cell-base
               (format nil "/wardlisp/learn/~A" (notebook-url-id notebook))))
         (sidebar (cond ((null sidebar-notebooks) nil)
                        ((eq sidebar-notebooks t) (all-notebooks))
                        (t sidebar-notebooks))))
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
              (:div :class "layout"
                    (when sidebar
                      (render-sidebar (notebook-id notebook) sidebar))
                    (:main
                     (cond
                       (*user*
                        (:div :class "user-banner" "ログイン中: "
                              (:strong (or (getf *user* :name) "User")) " · "
                              (:form :method "post" :action "/logout"
                                     :style "display:inline;"
                                     (:button :type "submit"
                                              :class "user-banner__logout"
                                              :style "background:none;border:none;color:#38bdf8;cursor:pointer;padding:0;font:inherit;"
                                              "ログアウト"))))
                       (t
                        (:div :class "user-banner anon" "進捗を端末を超えて保存するには "
                              (:a :href "/login" "ログイン") " してください。")))
                     (when (and (notebook-chapter notebook)
                                (plusp (length (notebook-chapter notebook))))
                       (:div :class "breadcrumb"
                             (:a :href "/wardlisp/" "WardLisp") " > "
                             (:a :href "/wardlisp/learn" "SICPコース") " > "
                             (notebook-chapter notebook)))
                     (:h1 (notebook-title notebook))
                     (:p :class "summary" (notebook-summary notebook))
                     (loop for cell in (notebook-cells notebook)
                           for i from 0
                           do (render-cell cell i (notebook-url-id notebook)))))
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
           (let ((origin (notebook-cell-result-error-cell-id result)))
             (:pre :class "result-error"
                   (if origin
                       (format nil "セル「~A」でエラー: ~A"
                               (%cell-id->string origin)
                               (notebook-cell-result-error-message result))
                       (notebook-cell-result-error-message result)))
             (:div :class "error-hint"
                   (if origin
                       "💡 上のセル「リセット」ボタンで初期コードに戻せます。"
                       "💡 上のセルを編集している場合、「リセット」ボタンで初期コードに戻せます。")))))))
    (let ((out (notebook-cell-result-print-output result)))
      (when (and out (plusp (length out))) (:pre :class "print-output" out)))))
