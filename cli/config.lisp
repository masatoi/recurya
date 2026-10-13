;;;; cli/config.lisp --- Where the CLI keeps its server URL and token.

(defpackage #:recurya/cli/config
  (:use #:cl)
  ;; Bare imports: declare the packages used through qualified names.
  (:import-from #:com.inuoe.jzon)
  (:import-from #:uiop)
  (:import-from #:sb-posix)
  (:export #:config-write-failed
           #:config-write-failed-message
           #:config-dir
           #:load-config
           #:save-config
           #:resolve-server))

(in-package #:recurya/cli/config)

(define-condition config-write-failed (error)
  ((message :initarg :message :reader config-write-failed-message))
  (:report (lambda (c stream)
             (format stream "Could not save the config privately: ~A"
                     (config-write-failed-message c)))))

(defun config-dir ()
  "$RECURYA_CONFIG_DIR, else $XDG_CONFIG_HOME/recurya/, else ~/.config/recurya/."
  (let ((explicit (uiop:getenv "RECURYA_CONFIG_DIR"))
        (xdg (uiop:getenv "XDG_CONFIG_HOME")))
    (uiop:ensure-directory-pathname
     (cond ((and explicit (plusp (length explicit))) explicit)
           ((and xdg (plusp (length xdg))) (format nil "~A/recurya" xdg))
           (t (merge-pathnames ".config/recurya/" (user-homedir-pathname)))))))

(defun config-file ()
  (merge-pathnames "config.json" (config-dir)))

(defun load-config ()
  "The saved config object, or NIL when there is none or it is unreadable."
  (let ((file (config-file)))
    (when (probe-file file)
      (let ((data (handler-case (com.inuoe.jzon:parse (uiop:read-file-string file))
                    (error () nil))))
        (and (hash-table-p data) data)))))

(defun save-config (server token)
  "Save SERVER and TOKEN, readable by the user only.  The config directory is
created with mode 700 and the file is made mode 600 while still empty, before
the token is written.  On any failure the file is deleted and
CONFIG-WRITE-FAILED is signalled."
  (let ((file (config-file))
        (data (make-hash-table :test 'equal)))
    (setf (gethash "server" data) server
          (gethash "token" data) token)
    (handler-case
        (progn
          (unless (probe-file (config-dir))
            (ensure-directories-exist file)
            (sb-posix:chmod (uiop:native-namestring (config-dir)) #o700))
          ;; Create empty, restrict, then write: the token never sits in a
          ;; group- or world-readable file.
          (with-open-file (out file :direction :output :if-exists :supersede
                                    :external-format :utf-8)
            (declare (ignorable out)))
          (sb-posix:chmod (uiop:native-namestring file) #o600)
          (with-open-file (out file :direction :output :if-exists :overwrite
                                    :external-format :utf-8)
            (write-string (com.inuoe.jzon:stringify data :pretty t) out))
          file)
      (error (e)
        (handler-case (when (probe-file file) (delete-file file))
          (error () nil))
        (error 'config-write-failed :message (princ-to-string e))))))

(defun resolve-server (explicit config)
  "The server to talk to, without a trailing slash: EXPLICIT (--server), else
$RECURYA_SERVER, else CONFIG's \"server\"; NIL when none is set."
  (let ((value (or explicit
                   (let ((env (uiop:getenv "RECURYA_SERVER")))
                     (and env (plusp (length env)) env))
                   (and config (gethash "server" config)))))
    (and (stringp value) (string-right-trim "/" value))))
