;;;; cli/main.lisp --- recurya command-line client: login, list, pull, run, status.

(defpackage #:recurya/cli/main
  (:use #:cl)
  ;; Bare import: declares uiop, used through qualified names.
  (:import-from #:uiop)
  (:import-from #:recurya/cli/config
                #:load-config
                #:save-config
                #:resolve-server
                #:config-write-failed
                #:config-write-failed-message)
  (:import-from #:recurya/cli/client
                #:api-error
                #:api-error-status
                #:api-error-message
                #:request-failed
                #:request-failed-message
                #:fetch-me
                #:fetch-notebooks
                #:fetch-notebook
                #:post-cell-run)
  (:import-from #:recurya/cli/workspace
                #:index-width
                #:render-readme
                #:plan-pull
                #:manifest-cells
                #:manifest-cell
                #:collect-codes
                #:resolve-cell-arg
                #:content-hash
                #:cell-file-name
                #:manifest->json
                #:json->manifest
                #:workspace-error
                #:workspace-error-message)
  (:import-from #:recurya/cli/report
                #:format-run-result
                #:result-exit-code
                #:format-notebook-list
                #:format-status)
  (:export #:main
           #:parse-args))

(in-package #:recurya/cli/main)

(define-condition usage-error (error)
  ((message :initarg :message :reader usage-error-message))
  (:report (lambda (c stream) (write-string (usage-error-message c) stream))))

(defun usage-error (control &rest args)
  (error 'usage-error :message (apply #'format nil control args)))

(defparameter *usage*
  "usage: recurya <command> [args]
  login [--server URL] [--token TOKEN]   save a token issued on /account
  list [--page N]                        list notebooks
  pull @handle/slug [DIR] [--force]      fetch a notebook into DIR (default: slug)
  run NN                                 run cell NN of the notebook in this directory
  status                                 show passed cells and local edits")

(defparameter *options*
  '(("--server" :server t) ("--token" :token t) ("--page" :page t) ("--force" :force nil))
  "Known options: (FLAG KEY TAKES-VALUE-P).")

(defun parse-args (argv)
  "Split ARGV into (VALUES COMMAND POSITIONAL OPTIONS); OPTIONS is a plist
keyed by keywords (--page 2 => :PAGE \"2\", --force => :FORCE T)."
  (let ((command (first argv))
        (positional '())
        (options '()))
    (loop with rest = (rest argv)
          while rest
          do (let ((arg (pop rest)))
               (let ((spec (assoc arg *options* :test #'string=)))
                 (cond
                   ((and spec (third spec))
                    (unless rest (usage-error "~A needs a value" arg))
                    (setf (getf options (second spec)) (pop rest)))
                   (spec (setf (getf options (second spec)) t))
                   ((and (> (length arg) 2) (string= "--" arg :end2 2))
                    (usage-error "Unknown option ~A" arg))
                   (t (push arg positional))))))
    (values command (nreverse positional) options)))

(defun credentials (options)
  "(VALUES SERVER TOKEN) from OPTIONS and the saved config; usage error when
not logged in."
  (let* ((config (load-config))
         (server (resolve-server (getf options :server) config))
         (token (and config (gethash "token" config))))
    (unless (and server token)
      (usage-error "Not logged in. Run: recurya login --server URL"))
    (values server token)))

(defun workspace-file (name)
  (merge-pathnames name (uiop:getcwd)))

(defun read-text (path)
  (and (probe-file path) (uiop:read-file-string path :external-format :utf-8)))

(defun write-text (path content)
  (ensure-directories-exist path)
  (with-open-file (out path :direction :output :if-exists :supersede
                            :external-format :utf-8)
    (write-string content out)))

(defun manifest-path (dir)
  (merge-pathnames ".recurya/notebook.json" dir))

(defun load-workspace ()
  "The manifest of the notebook pulled into the current directory."
  (let ((text (read-text (manifest-path (uiop:getcwd)))))
    (unless text
      (usage-error "No pulled notebook here (.recurya/notebook.json is missing). Run recurya pull first."))
    (json->manifest text)))

(defun parse-notebook-ref (ref)
  "@handle/slug (the @ is optional) => (VALUES HANDLE SLUG)."
  (let* ((s (string-left-trim "@" ref))
         (slash (position #\/ s)))
    (unless (and slash (plusp slash) (< (1+ slash) (length s)))
      (usage-error "Expected @handle/slug, got ~A" ref))
    (values (subseq s 0 slash) (subseq s (1+ slash)))))

;;; Commands

(defun cmd-login (options)
  (let* ((server (resolve-server (getf options :server) (load-config)))
         (token (or (getf options :token)
                    (progn (format *query-io* "Paste the token from ~A/account: "
                                   (or server "<server>"))
                           (force-output *query-io*)
                           (string-trim " " (read-line *query-io* nil ""))))))
    (unless server (usage-error "Give the server once: recurya login --server URL"))
    (let ((me (fetch-me server token)))
      (save-config server token)
      (format t "Logged in to ~A as @~A~%" server (gethash "handle" me))
      0)))

(defun cmd-list (options)
  (multiple-value-bind (server token) (credentials options)
    (let ((page (let ((p (getf options :page)))
                  (or (and p (parse-integer p :junk-allowed t)) 1))))
      (format-notebook-list (fetch-notebooks server token page) *standard-output*)
      0)))

(defun apply-pull (notebook server dir force)
  "Write NOTEBOOK into DIR per PLAN-PULL and report kept files."
  (let* ((width (index-width (length (gethash "cells" notebook))))
         (old (let ((text (read-text (manifest-path dir))))
                (and text (json->manifest text))))
         (existing (loop for cell across (gethash "cells" notebook)
                         for file = (cell-file-name (gethash "index" cell)
                                                    (gethash "kind" cell) width)
                         for content = (and file (read-text (merge-pathnames file dir)))
                         when content collect (cons file content))))
    (multiple-value-bind (actions manifest) (plan-pull notebook width old existing force)
      (setf (gethash "server" manifest) server)
      (write-text (merge-pathnames "README.md" dir) (render-readme notebook width))
      (dolist (action actions)
        (destructuring-bind (op file &optional content) action
          (if (eq op :write)
              (write-text (merge-pathnames file dir) content)
              (format t "kept (edited locally): ~A~%" file))))
      (write-text (manifest-path dir) (manifest->json manifest))
      (format t "Pulled @~A/~A into ~A~%" (gethash "handle" notebook)
              (gethash "slug" notebook) (uiop:native-namestring dir))
      0)))

(defun cmd-pull (positional options)
  (unless positional (usage-error "pull needs @handle/slug"))
  (multiple-value-bind (server token) (credentials options)
    (multiple-value-bind (handle slug) (parse-notebook-ref (first positional))
      (let ((dir (uiop:ensure-directory-pathname
                  (merge-pathnames (or (second positional) slug) (uiop:getcwd)))))
        (apply-pull (fetch-notebook server token handle slug) server dir
                    (getf options :force))))))

(defun cmd-run (positional options)
  (unless positional (usage-error "run needs a cell number, e.g. recurya run 03"))
  (let* ((manifest (load-workspace))
         (index (resolve-cell-arg (first positional) manifest))
         (width (gethash "width" manifest))
         (codes (collect-codes manifest index
                               (lambda (file) (read-text (workspace-file file))))))
    (multiple-value-bind (server token) (credentials options)
      (let ((pulled-from (gethash "server" manifest)))
        ;; Never send the token to a host other than the one it was issued for.
        (when (and (stringp pulled-from)
                   (string/= (string-right-trim "/" pulled-from) server))
          (usage-error "This notebook was pulled from ~A but the configured server is ~A; ~
                        not sending your token there.  Pull it again from ~A, or run with ~
                        --server ~A."
                       pulled-from server server pulled-from)))
      (let ((result (post-cell-run server token (gethash "handle" manifest)
                                    (gethash "slug" manifest) index codes)))
        (format-run-result result width *standard-output*)
        (when (string= (gethash "status" result) "pass")
          (setf (gethash "passed" (manifest-cell manifest index)) t))
        (when (plusp (length (gethash "revealed_solutions" result)))
          ;; Refresh files, README and manifest so the unlocked solution lands.
          (apply-pull (fetch-notebook server token (gethash "handle" manifest)
                                      (gethash "slug" manifest))
                      server (uiop:getcwd) nil))
        (unless (plusp (length (gethash "revealed_solutions" result)))
          (write-text (manifest-path (uiop:getcwd)) (manifest->json manifest)))
        (result-exit-code result)))))

(defun cmd-status ()
  (let* ((manifest (load-workspace))
         (modified (loop for cell in (manifest-cells manifest)
                         for file = (gethash "file" cell)
                         for content = (and (stringp file) (read-text (workspace-file file)))
                         when (and content
                                   (not (equal (content-hash content) (gethash "hash" cell))))
                           collect file)))
    (format-status manifest modified *standard-output*)
    0))

(defun main (argv)
  "Run the CLI on ARGV (a list of strings); return the exit code: 0 success,
1 a run that failed or errored, 2 a usage, auth or connection problem."
  (handler-case
      (multiple-value-bind (command positional options) (parse-args argv)
        (cond
          ((null command) (usage-error "~A" *usage*))
          ((string= command "login") (cmd-login options))
          ((string= command "list") (cmd-list options))
          ((string= command "pull") (cmd-pull positional options))
          ((string= command "run") (cmd-run positional options))
          ((string= command "status") (cmd-status))
          (t (usage-error "Unknown command ~A~%~A" command *usage*))))
    (usage-error (e) (format *error-output* "~A~%" (usage-error-message e)) 2)
    (workspace-error (e) (format *error-output* "~A~%" (workspace-error-message e)) 2)
    (api-error (e)
      (if (eql (api-error-status e) 401)
          (format *error-output* "Not authorized: ~A~%Run: recurya login~%" (api-error-message e))
          (format *error-output* "Server said: ~A~%" (api-error-message e)))
      2)
    (config-write-failed (e) (format *error-output* "~A~%" (config-write-failed-message e)) 2)
    (request-failed (e) (format *error-output* "~A~%" (request-failed-message e)) 2)))
