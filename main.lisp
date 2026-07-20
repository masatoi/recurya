;;;; main.lisp --- Production executable entry point.
;;;;
;;;; Boot sequence for the save-lisp-and-die core: reload foreign libraries,
;;;; connect the database, seed official content, start the web server, then
;;;; block until SIGTERM/SIGINT for graceful shutdown. Kept separate from
;;;; web/server.lisp so the deploy bootstrap has one clear responsibility and
;;;; the dev/worker startup paths (start-worker-app) stay untouched.

(defpackage #:recurya/main
  (:use #:cl)
  (:import-from #:cl+ssl
                #:reload)
  (:import-from #:recurya/db/core
                #:connect-to-database)
  (:import-from #:recurya/web/server
                #:start!
                #:stop!)
  (:import-from #:recurya/seed/official-content
                #:seed-official-content!)
  (:export #:recurya-main
           #:boot!))

(in-package #:recurya/main)

(defvar *shutdown-requested* nil
  "Set by the SIGTERM/SIGINT handler so the main loop can stop the server in a
normal (non-signal) context.")

(defun reload-foreign-libraries! ()
  "Reload foreign libraries after a save-lisp-and-die restore.

A saved core loses its live foreign-library handles, so cl+ssl (used by
dexador for the OAuth HTTPS calls to Google/GitHub) must reopen libssl before
the first request. Failures are logged, not fatal, so the operator can still
reach the box even if the TLS stack is broken."
  (handler-case (cl+ssl:reload)
    (error (e)
      (format *error-output* "~&[boot] WARN: cl+ssl reload failed: ~A~%" e)
      (force-output *error-output*))))

(defun boot! ()
  "Run the production startup sequence and return once the web server thread is
listening. Non-blocking: START! uses clackup with :use-thread t."
  (reload-foreign-libraries!)
  (recurya/db/core:start!)
  (handler-case (seed-official-content!)
    (error (e)
      (format *error-output* "~&[boot] WARN: seed failed: ~A~%" e)
      (force-output *error-output*)))
  (start!)
  (values))

(defun recurya-main ()
  "Executable toplevel for the production core. Boots the app, installs signal
handlers, and blocks the main thread until SIGTERM/SIGINT; then stops the
server gracefully and exits 0. A failure during BOOT! (e.g. the database is
unreachable) is intentionally left to propagate, so the process fails fast with
a non-zero exit."
  (setf *shutdown-requested* nil)
  (boot!)
  (flet ((request-shutdown (signo info context)
           (declare (ignore signo info context))
           (setf *shutdown-requested* t)))
    (sb-sys:enable-interrupt sb-unix:sigterm #'request-shutdown)
    (sb-sys:enable-interrupt sb-unix:sigint #'request-shutdown))
  (format t "~&recurya production core listening (PORT=~A)~%"
          (or (uiop:getenv "PORT") "13000"))
  (force-output)
  (loop until *shutdown-requested* do (sleep 1))
  (format t "~&[boot] shutdown requested; stopping server~%")
  (force-output)
  (ignore-errors (stop!))
  (sb-ext:exit :code 0))
