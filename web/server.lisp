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
  (:import-from #:recurya/web/auth
                #:require-real-handle)
  (:import-from #:recurya/web/routes
                #:setup-routes)
  (:import-from #:recurya/web/ui/errors
                #:csrf-failure)
  (:export #:start!
           #:stop!
           #:*handler*))

(in-package #:recurya/web/server)

(defvar *handler* nil
  "The Clack handler for the running server.")

(defparameter *default-port* 3000
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
      (if (member (getf env :path-info) *csrf-skip-paths* :test #'string=)
          (funcall app env)
          (funcall csrf-app env)))))

(defun build-app ()
  "Build the complete Lack application with middleware."
  (let ((app (make-recurya-app)))
    (setup-routes app)
    ;; Lack middleware stack (outermost listed first):
    ;; 1. :static               — serves /static/* from resources/static/ on disk
    ;; 2. :session              — cookie-based session (provides ningle/context:*session*)
    ;; 3. #'csrf-with-skip      — CSRF token check on POST/PUT/DELETE/PATCH;
    ;;                            bypassed for paths in *csrf-skip-paths*. Must
    ;;                            run after :session because it reads
    ;;                            :lack.session.
    ;; 4. #'require-real-handle — Onboarding guard: redirects users with
    ;;                            placeholder handles to /onboarding/handle.
    ;;                            Reads :lack.session, so must run after
    ;;                            :session. Sits before :backtrace so its 302
    ;;                            response is unaffected by error handling.
    ;; 5. :backtrace            — renders a debug backtrace page on unhandled
    ;;                            errors.
    ;; 6. app                   — the Ningle router with all route handlers.
    (lack/builder:builder
     (:static :path "/static/"
              :root (asdf:system-relative-pathname
                     :recurya "resources/static/"))
     :session
     #'csrf-with-skip
     #'require-real-handle
     :backtrace
     app)))

(defun start! (&key (port nil) (address "0.0.0.0"))
  "Start the web server.

   Options:
   - :port    - Port to listen on (default: 3000 or PORT env var)
   - :address - Address to bind to (default: 0.0.0.0 for all interfaces)"
  (when *handler*
    (log:info "Server already running, stopping first...")
    (stop!))

  (let ((port (or port (get-port))))
    ;; Load timezone database for local-time
    (local-time:reread-timezone-repository)
    (log:info "Timezone repository loaded")

    ;; Build and start the application
    (let ((app (build-app)))
      (setf *handler* (clackup app
                               :port port
                               :address address
                               :server :hunchentoot
                               :use-thread t
                               :silent nil))
      (log:info "Web server started on http://~A:~A" address port)
      *handler*)))

(defun stop! ()
  "Stop the running web server."
  (when *handler*
    (stop *handler*)
    (setf *handler* nil)
    (log:info "Web server stopped")))
