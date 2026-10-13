;;;; cli/config.lisp --- Where the CLI keeps its server URL and token.

(defpackage #:recurya/cli/config
  (:use #:cl)
  ;; Bare imports: declare the packages used through qualified names.
  (:import-from #:com.inuoe.jzon)
  (:import-from #:uiop)
  (:export #:config-dir
           #:load-config
           #:save-config
           #:resolve-server))

(in-package #:recurya/cli/config)

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
  "Save SERVER and TOKEN, readable by the user only (mode 600)."
  (let ((file (config-file))
        (data (make-hash-table :test 'equal)))
    (setf (gethash "server" data) server
          (gethash "token" data) token)
    (ensure-directories-exist file)
    (with-open-file (out file :direction :output :if-exists :supersede
                              :external-format :utf-8)
      (write-string (com.inuoe.jzon:stringify data :pretty t) out))
    (uiop:run-program (list "chmod" "600" (uiop:native-namestring file)))
    file))

(defun resolve-server (explicit config)
  "The server to talk to, without a trailing slash: EXPLICIT (--server), else
$RECURYA_SERVER, else CONFIG's \"server\"; NIL when none is set."
  (let ((value (or explicit
                   (let ((env (uiop:getenv "RECURYA_SERVER")))
                     (and env (plusp (length env)) env))
                   (and config (gethash "server" config)))))
    (and (stringp value) (string-right-trim "/" value))))
