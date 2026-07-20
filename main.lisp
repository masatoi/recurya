;;;; main.lisp --- Production executable entry point.
;;;;
;;;; Boot sequence for the save-lisp-and-die core: reload foreign libraries,
;;;; connect the database, seed official content, start the web server, then
;;;; block until SIGTERM/SIGINT for graceful shutdown. Kept separate from
;;;; web/server.lisp so the deploy bootstrap has one clear responsibility and
;;;; the dev/worker startup paths (start-worker-app) stay untouched.

(defpackage #:recurya/main
  (:use #:cl)
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

(defun boot! ()
  "Run the production startup sequence and return once the web server thread is
listening. Non-blocking: START! uses clackup with :use-thread t."
  (recurya/db/core:start!)
  (handler-case (seed-official-content!)
    (error (e)
      (format *error-output* "~&[boot] WARN: seed failed: ~A~%" e)
      (force-output *error-output*)))
  (start!)
  (values))

(defun recurya-main ()
  "Container entry point (run from source). Boots the app, installs signal
handlers, and blocks the main thread until SIGTERM/SIGINT; then stops the
server gracefully and exits 0. A failure during BOOT! (e.g. the database is
unreachable) is logged with a backtrace and the process exits non-zero
(fail fast)."
  (setf *shutdown-requested* nil)
  ;; Surface a boot failure instead of exiting silently: log the condition and
  ;; a backtrace (captured in the signalling context via handler-bind) before
  ;; failing fast. Essential for diagnosing production boot failures.
  (handler-bind
      ((serious-condition
         (lambda (c)
           (format *error-output* "~&[boot] FATAL ~A: ~A~%" (type-of c) c)
           (ignore-errors
            (uiop:print-backtrace :stream *error-output* :count 50))
           (finish-output *error-output*)
           (sb-ext:exit :code 1 :abort t))))
    (boot!))
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
