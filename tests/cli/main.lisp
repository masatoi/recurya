;;;; tests/cli/main.lisp --- CLI argument parsing, config and dependency boundary.

(defpackage #:recurya/tests/cli/main
  (:use #:cl #:rove)
  (:import-from #:recurya/cli/main
                #:parse-args
                #:main
                #:apply-pull)
  (:import-from #:recurya/cli/config
                #:config-dir
                #:load-config
                #:save-config
                #:resolve-server)
  ;; Bare import: declares the sb-posix dependency (setenv, stat).
  (:import-from #:sb-posix)
  ;; Bare import: manifest JSON is parsed through qualified names.
  (:import-from #:com.inuoe.jzon))

(in-package #:recurya/tests/cli/main)

(defmacro with-temp-config-dir ((var) &body body)
  `(let ((,var (uiop:ensure-directory-pathname
                (format nil "~A/recurya-cli-test-~36R/"
                        (string-right-trim "/" (namestring (uiop:temporary-directory)))
                        (random (expt 36 8) (make-random-state t))))))
     (sb-posix:setenv "RECURYA_CONFIG_DIR" (namestring ,var) 1)
     (unwind-protect (progn ,@body)
       (sb-posix:unsetenv "RECURYA_CONFIG_DIR")
       (uiop:delete-directory-tree ,var :validate t :if-does-not-exist :ignore))))

(deftest parse-args-splits-options
  (multiple-value-bind (cmd pos opts) (parse-args '("pull" "@a/b" "dir" "--force"))
    (ok (string= "pull" cmd))
    (ok (equal '("@a/b" "dir") pos))
    (ok (eq t (getf opts :force))))
  (multiple-value-bind (cmd pos opts) (parse-args '("login" "--server" "http://x" "--token" "t"))
    (ok (string= "login" cmd))
    (ok (null pos))
    (ok (string= "http://x" (getf opts :server)))
    (ok (string= "t" (getf opts :token))))
  (multiple-value-bind (cmd pos opts) (parse-args '("list" "--page" "2"))
    (declare (ignore pos))
    (ok (string= "list" cmd))
    (ok (string= "2" (getf opts :page)))))

(deftest config-roundtrip-and-permissions
  (with-temp-config-dir (dir)
    (ok (null (load-config)))
    (save-config "http://localhost:13000" "rcy_abc")
    (let ((cfg (load-config)))
      (ok (string= "http://localhost:13000" (gethash "server" cfg)))
      (ok (string= "rcy_abc" (gethash "token" cfg))))
    (ok (uiop:directory-pathname-p (config-dir)))
    (let ((mode (sb-posix:stat-mode (sb-posix:stat (merge-pathnames "config.json" (config-dir))))))
      (ok (= #o600 (logand mode #o777)) "config file is private to the user"))
    (let ((mode (sb-posix:stat-mode (sb-posix:stat (uiop:native-namestring (config-dir))))))
      (ok (= #o700 (logand mode #o777)) "config directory is private to the user"))))

(deftest resolve-server-precedence
  (let ((cfg (make-hash-table :test 'equal)))
    (setf (gethash "server" cfg) "http://cfg")
    (ok (string= "http://flag" (resolve-server "http://flag/" cfg)) "flag wins, trailing / dropped")
    (ok (string= "http://cfg" (resolve-server nil cfg)))
    (ok (null (resolve-server nil nil)))))

(deftest usage-errors-exit-2
  (with-temp-config-dir (dir)
    (ok (= 2 (main '())))
    (ok (= 2 (main '("frobnicate"))))
    (ok (= 2 (main '("list" "--bogus"))) "unknown option")
    (ok (= 2 (main '("list"))) "not logged in")
    (ok (= 2 (main '("run" "3"))) "not inside a pulled notebook")))

(deftest cli-does-not-load-server-systems
  (let ((seen (make-hash-table :test 'equal)))
    (labels ((walk (name)
               (unless (gethash name seen)
                 (setf (gethash name seen) t)
                 (let ((system (asdf:find-system name nil)))
                   (when system
                     (dolist (dep (asdf:system-depends-on system))
                       (when (stringp dep) (walk dep))))))))
      (walk "recurya/cli/main"))
    (loop for name being the hash-keys of seen
          do (ng (or (search "mito" name)
                     (search "recurya/db" name)
                     (search "recurya/web" name)
                     (string= "wardlisp" name))
                 (format nil "CLI must not depend on ~A" name)))))

(defun jobj (&rest kv)
  (let ((h (make-hash-table :test 'equal)))
    (loop for (k v) on kv by #'cddr do (setf (gethash k h) v))
    h))

(defun stub-notebook (&key passed)
  "An exercise at 0 and its solution at 1, which is unlocked once PASSED."
  (jobj "handle" "al" "slug" "nb" "title" "NB" "summary" 'null
        "cells" (vector
                 (jobj "index" 0 "cell_id" "c0" "kind" "code-exercise" "body" "(define x 1)"
                       "saved_code" 'null "description" "d" "test_cases" #()
                       "passed" passed "unlocked" t)
                 (jobj "index" 1 "cell_id" "c1" "kind" "code-solution" "body" "(define x 2)"
                       "saved_code" 'null "passed" nil "unlocked" passed))))

(deftest pull-after-passing-run-keeps-passed-and-writes-solution
  ;; cmd-run re-pulls the notebook when a run reveals a solution; the refetched
  ;; notebook carries the server-side progress, so the rewritten manifest must
  ;; already mark the exercise passed and list the unlocked solution file.
  (let ((dir (uiop:ensure-directory-pathname
              (format nil "~A/recurya-cli-pull-~36R/"
                      (string-right-trim "/" (namestring (uiop:temporary-directory)))
                      (random (expt 36 8) (make-random-state t))))))
    (unwind-protect
         (progn
           (let ((*standard-output* (make-broadcast-stream)))
             (apply-pull (stub-notebook :passed nil) "http://s" dir nil)
             (ok (not (probe-file (merge-pathnames "01-solution.wl" dir))))
             (apply-pull (stub-notebook :passed t) "http://s" dir nil))
           (let* ((manifest (com.inuoe.jzon:parse
                             (uiop:read-file-string (merge-pathnames ".recurya/notebook.json" dir))))
                  (cells (coerce (gethash "cells" manifest) 'list)))
             (ok (eq t (gethash "passed" (first cells))))
             (ok (equal "01-solution.wl" (gethash "file" (second cells))))
             (ok (probe-file (merge-pathnames "01-solution.wl" dir)))))
      (uiop:delete-directory-tree dir :validate t :if-does-not-exist :ignore))))

(deftest run-refuses-to-send-token-to-another-server
  (with-temp-config-dir (cfg)
    (save-config "http://configured" "rcy_secret")
    (let ((dir (uiop:ensure-directory-pathname
                (format nil "~A/recurya-cli-run-~36R/"
                        (string-right-trim "/" (namestring (uiop:temporary-directory)))
                        (random (expt 36 8) (make-random-state t))))))
      (unwind-protect
           (progn
             (let ((*standard-output* (make-broadcast-stream)))
               (apply-pull (stub-notebook :passed nil) "http://other-host" dir nil))
             (uiop:with-current-directory (dir)
               (let* ((err (make-string-output-stream))
                      (code (let ((*error-output* err)) (main '("run" "00"))))
                      (text (get-output-stream-string err)))
                 (ok (= 2 code))
                 (ok (search "http://other-host" text))
                 (ok (search "http://configured" text)))))
        (uiop:delete-directory-tree dir :validate t :if-does-not-exist :ignore)))))
