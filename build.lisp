;;;; build.lisp --- Produce the standalone production executable core.
;;;;
;;;; Runs inside the builder stage of Dockerfile.prod:
;;;;   qlot exec sbcl --non-interactive --load build.lisp
;;;; Output: an executable SBCL core at $RECURYA_CORE_OUT (default /app/recurya)
;;;; whose toplevel is recurya/main:recurya-main.

(setf sb-impl::*default-external-format* :utf-8)

;; Load the project through Quicklisp/ASDF (qlot exec provides the local dist).
(ql:quickload :recurya)
(asdf:load-system "recurya/main")

(let ((out (or (uiop:getenv "RECURYA_CORE_OUT") "/app/recurya")))
  (format t "~&[build] saving executable core to ~A~%" out)
  (force-output)
  (sb-ext:save-lisp-and-die
   out
   :executable t
   :toplevel #'recurya/main:recurya-main
   :save-runtime-options nil
   #+sb-core-compression :compression #+sb-core-compression t))
