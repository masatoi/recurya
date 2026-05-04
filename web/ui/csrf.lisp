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
session is bound (e.g. when called outside a request context).

The session key dynamic variable used by lack/middleware/csrf is only
bound while the middleware is on the call stack. When templates are
rendered outside that context (e.g. in tests, or in handlers that bypass
CSRF for skip-listed paths), we fall back to the middleware's default
key so the helper remains safe to call."
  (when *session*
    (if (boundp 'lack/middleware/csrf::*csrf-session-key*)
        (csrf-token *session*)
        (let ((lack/middleware/csrf::*csrf-session-key* "_csrf_token"))
          (csrf-token *session*)))))

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
