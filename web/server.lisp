;;;; web/server.lisp --- Clack/Hunchentoot HTTP server lifecycle.
;;;;
;;;; Provides start!/stop! for the Hunchentoot-backed web server.
;;;; The Lack application is built in build-app with session and
;;;; backtrace middleware (see web/app.lisp for the Ningle app).

(defpackage #:recurya/web/server
  (:use #:cl)
  (:import-from #:clack
                #:clackup
                #:stop)
  (:import-from #:lack/middleware/csrf
                #:*lack-middleware-csrf*)
  (:import-from #:recurya/web/app
                #:make-recurya-app)
  (:import-from #:recurya/web/api-auth
                #:api-token-auth
                #:api-body-limit
                #:api-path-p)
  (:import-from #:recurya/web/http
                #:request-body-limit)
  (:import-from #:recurya/web/auth
                #:require-dashboard-auth
                #:require-real-handle)
  (:import-from #:recurya/web/i18n/core
                #:bind-locale)
  (:import-from #:recurya/web/routes
                #:setup-routes
                #:*learn-sync-max-body-bytes*)
  (:import-from #:recurya/web/ui/errors
                #:csrf-failure)
  (:export #:start!
           #:stop!
           #:start-worker-app
           #:csrf-with-skip
           #:build-app
           #:*handler*))

(in-package #:recurya/web/server)

(defvar *handler* nil
  "The Clack handler for the running server.")

(defparameter *default-port* 13000
  "Default port for the web server.")

(defun get-port ()
  "Get the server port from environment or use default."
  (let ((port-str (uiop:getenv "PORT")))
    (if port-str
        (parse-integer port-str :junk-allowed t)
        *default-port*)))

(defparameter *csrf-skip-paths* '("/learn/sync"
    ;; Legacy 308 redirect target. The redirect handler itself runs
    ;; after the middleware, so the upstream POST must bypass csrf
    ;; here just like its modern equivalent.
    "/wardlisp/learn/sync")
  "Paths bypassed by the CSRF middleware (JSON endpoints with their
own protection).")

(defun csrf-failure-handler (env)
  "Lack response returned when the CSRF middleware rejects a request."
  (declare (ignore env))
  (list 400
        (list :content-type "text/html; charset=utf-8")
        (list (csrf-failure))))

(defun csrf-with-skip (app)
  "Wrap APP in lack/middleware/csrf, but skip *csrf-skip-paths*.

Returns a Clack app that dispatches to either the bare APP or the
CSRF-protected wrapper based on the request path. The skip list is
intended for JSON endpoints that authenticate via session and consume
their own request body (so the CSRF middleware's body-parameter
inspection would interfere)."
  (let ((csrf-app
         (funcall *lack-middleware-csrf*
                  app :block-app #'csrf-failure-handler)))
    (lambda (env)
      (if (or (member (getf env :path-info) *csrf-skip-paths* :test #'string=)
              ;; /api/ authenticates by bearer token only (see web/api-auth).
              (api-path-p (getf env :path-info)))
          (funcall app env)
          (funcall csrf-app env)))))

(defun learn-sync-body-limit (app)
  "Lack middleware: refuse a POST /learn/sync (or its legacy URL) body over
*LEARN-SYNC-MAX-BODY-BYTES* with 413, and a chunked one without
Content-Length with 411, before Lack parses it.  Other paths pass through."
  (funcall (request-body-limit
            *learn-sync-max-body-bytes*
            (lambda (status)
              (list status
                    '(:content-type "application/json; charset=utf-8")
                    (list (if (= status 413)
                              "{\"error\":\"payload too large\"}"
                              "{\"error\":\"length required\"}"))))
            :applies-p (lambda (path)
                         (member path '("/learn/sync" "/wardlisp/learn/sync")
                                 :test #'equal)))
           app))

(defun ensure-sessions-table! ()
  "Create the DBI session-store backing table if it does not already exist.
Idempotent; called at server start so the persistent session store has its
table in every environment (the app does not auto-migrate)."
  (recurya/db/core:execute!
   "CREATE TABLE IF NOT EXISTS sessions (
      id VARCHAR(255) NOT NULL PRIMARY KEY,
      session_data TEXT NOT NULL)"))

(defun make-session-store ()
  "Build a DB-backed Lack session store so logins survive server/container
restarts. Each store operation uses a short-lived connection to the
application database, which is safe under Hunchentoot's worker threads."
  (lack/middleware/session/store/dbi:make-dbi-store
   :connector (lambda ()
                (recurya/db/core:connect-to-database
                 (or (uiop:getenv "POSTGRES_DB") "recurya")))
   :disconnector (lambda (conn) (dbi:disconnect conn))))

(defun build-app (&key (session-store (make-session-store)))
  "Build the complete Lack application with middleware.
Requests under /api/ go to a stack without :session (bearer-token auth only:
no session row, no Set-Cookie, no cookie path into the API); every other
request goes through the browser stack.  SESSION-STORE is the browser
stack's session store (tests pass an in-memory one)."
  (let ((app (make-recurya-app)))
    (setup-routes app)
    (let ((web-app
            ;; Browser stack (outermost listed first):
            ;; 1. :static                  — serves /static/* from resources/static/ on disk
            ;; 1b. #'learn-sync-body-limit — 413/411 for an oversized or unsized
            ;;                               POST /learn/sync body, before Lack
            ;;                               parses it or a session is made; every
            ;;                               other path passes straight through.
            ;; 2. :session                 — cookie-keyed, DB-backed session store
            ;;                               (persists logins across restarts; provides
            ;;                               ningle/context:*session*)
            ;; 3. #'bind-locale            — Binds *locale* from the session user's
            ;;                               :language (anonymous/unsupported -> :en)
            ;;                               for the request extent. Reads :lack.session,
            ;;                               so must run after :session; wraps all render.
            ;; 4. #'require-dashboard-auth — Login guard: redirects anonymous requests
            ;;                               to /dashboard or /dashboard/* back to
            ;;                               /login. Reads :lack.session, so must run
            ;;                               after :session. Runs before
            ;;                               require-real-handle so anonymous users go
            ;;                               to /login (not /onboarding/handle).
            ;; 5. #'csrf-with-skip         — CSRF token check on POST/PUT/DELETE/PATCH;
            ;;                               bypassed for paths in *csrf-skip-paths*.
            ;;                               Must run after :session because it reads
            ;;                               :lack.session.
            ;; 6. #'require-real-handle    — Onboarding guard: redirects users with
            ;;                               placeholder handles to /onboarding/handle.
            ;;                               Reads :lack.session, so must run after
            ;;                               :session. Sits before :backtrace so its
            ;;                               302 response is unaffected by error
            ;;                               handling.
            ;; 7. :backtrace               — renders a debug backtrace page on
            ;;                               unhandled errors.
            ;; 8. app                      — the Ningle router with all route handlers.
            (lack/builder:builder
             (:static :path "/static/"
                      :root (asdf:system-relative-pathname
                             :recurya "resources/static/"))
             #'learn-sync-body-limit
             (:session :store session-store)
             ;; セッション確定後に現在ロケールを *locale* へ束縛(全描画をカバー)
             #'bind-locale
             #'require-dashboard-auth
             #'csrf-with-skip
             #'require-real-handle
             :backtrace
             app))
          (api-app
            ;; API stack: no :session, so no cookie is read or set and no
            ;; session row is written.  bind-locale (no session -> :en) keeps
            ;; *locale* request-scoped; api-body-limit refuses bodies over
            ;; 1 MiB before Lack parses them (and before any token lookup);
            ;; api-token-auth is the only credential check; CSRF does not
            ;; apply to a bearer-token API.
            (lack/builder:builder
             #'api-body-limit
             #'bind-locale
             #'api-token-auth
             :backtrace
             app)))
      (lambda (env)
        (if (api-path-p (getf env :path-info))
            (funcall api-app env)
            (funcall web-app env))))))

(defun start! (&key (port nil) (address "0.0.0.0"))
  "Start the web server.

   Options:
   - :port    - Port to listen on (default: 13000 or PORT env var)
   - :address - Address to bind to (default: 0.0.0.0 for all interfaces)"
  (when *handler*
    (log:info "Server already running, stopping first...")
    (stop!))

  (let ((port (or port (get-port))))
    ;; Load timezone database for local-time
    ;; The bundled local-time zoneinfo may be absent in some deploy images, so
    ;; keep this non-fatal: UTC/ISO-8601 timestamps work regardless of the
    ;; named-zone database.
    (handler-case
        (progn
          (local-time:reread-timezone-repository)
          (log:info "Timezone repository loaded"))
      (error (e)
        (log:warn "Timezone repository load skipped: ~A" e)))

    ;; Ensure the persistent session store's table exists before serving.
    (ensure-sessions-table!)

    ;; Build and start the application
    (let ((app (build-app)))
      (setf *handler* (clackup app
                               :port port
                               :address address
                               :server :hunchentoot
                               :use-thread t
                               ;; In production (APP_ENV=production) disable the
                               ;; debug error page so a handler error returns 500
                               ;; instead of invoking the debugger (which hangs
                               ;; without a TTY). Dev keeps debug on.
                               :debug (not (equalp (uiop:getenv "APP_ENV")
                                                   "production"))
                               :silent nil))
      (log:info "Web server started on http://~A:~A" address port)
      *handler*)))

(defun start-worker-app ()
  "Entry point for cl-mcp's worker init hook (MCP_WORKER_INIT_ENTRY): bring
the full web app up inside the cl-mcp worker process and return the port so
the pool can record it in `app_port'.

Called with no arguments by the init hook. Returns promptly because START!
uses clackup with :use-thread t (the server runs on its own thread), and it
must NOT block or trigger a nested ASDF load (the worker-global load lock is
held across this call). Connecting the datasource and starting Hunchentoot
satisfy that contract.

Running the web server here (rather than in the cl-mcp parent) is what lets
`pool-kill-worker' reset the app's runtime to a fresh Lisp process without
dropping the parent's cl-mcp HTTP endpoint, i.e. without a manual reconnect."
  (recurya/db/core:start!)
  (start!)
  (get-port))

(defun stop! ()
  "Stop the running web server."
  (when *handler*
    (stop *handler*)
    (setf *handler* nil)
    (log:info "Web server stopped")))
