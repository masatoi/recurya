(defpackage #:recurya/web/ui/csrf
  (:use #:cl)
  (:import-from #:spinneret #:with-html-string)
  (:import-from #:lack/middleware/csrf #:csrf-token)
  (:import-from #:ningle/context #:*session*)
  (:export #:current-csrf-token
           #:csrf-input
           #:csrf-form-block))

(in-package #:recurya/web/ui/csrf)

(defun current-csrf-token ()
  "Return the CSRF token for the current request session, or NIL if no
session is bound (e.g. when called outside a request context)."
  (when *session*
    (csrf-token *session*)))

(defun csrf-input ()
  "Render a hidden <input> carrying the current CSRF token. Returns a
string suitable for embedding via (:raw (csrf-input)) inside another
Spinneret template, or NIL when no session is available."
  (let ((tok (current-csrf-token)))
    (when tok
      (with-html-string
        (:input :type "hidden" :name "_csrf_token" :value tok)))))

(defun csrf-form-block ()
  "Render a hidden form holding the page-wide CSRF token. HTMX buttons
reference it via hx-include=\"#csrf-form\". Returns a string suitable
for embedding via (:raw (csrf-form-block)), or NIL when no session is
available."
  (let ((tok (current-csrf-token)))
    (when tok
      (with-html-string
        (:form :id "csrf-form" :style "display:none"
               (:input :type "hidden" :name "_csrf_token" :value tok))))))
