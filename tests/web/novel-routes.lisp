;;;; tests/web/novel-routes.lisp --- Tests for novel play/advance route handlers.
(defpackage #:recurya/tests/web/novel-routes
  (:use #:cl #:rove)
  (:import-from #:recurya/tests/support/db #:with-test-db #:create-test-user)
  (:import-from #:recurya/db/users #:users-id #:users-handle)
  (:import-from #:recurya/db/notebooks #:create-notebook!)
  (:import-from #:recurya/game/notebook-parser #:parse-notebook-body)
  (:import-from #:recurya/web/routes-novel
                #:novel-play-handler #:novel-advance-handler))

(in-package #:recurya/tests/web/novel-routes)

;;; --- helpers (mirroring tests/web/notebook-routes.lisp) ---

(defmacro with-mock-session (session-hash &body body)
  `(let ((ningle/context:*session* ,session-hash))
     ,@body))

(defun make-session (&key user)
  (let ((ht (make-hash-table)))
    (when user (setf (gethash :user ht) user))
    ht))

(defun response-status (r) (first r))
(defun response-body (r) (third r))

(defun create-scene-notebook (author &key (slug "novel-1"))
  "Create a published+public notebook with two scene cells; the second
branches on the MET-ALICE flag."
  (let* ((body "===scene===
(list (list 'narrate \"教室。\")
      (list 'say \"アリス\" \"やあ\")
      (list 'set-flag 'met-alice))

===scene===
(list (if met-alice
          (list 'say \"アリス\" \"また会ったね。\")
          (list 'say \"アリス\" \"…誰？\")))")
         (cells (mapcar #'recurya/web/routes::cell->jsonb-form
                        (parse-notebook-body body))))
    (create-notebook! :title "Novel" :slug slug :body-md body
                      :cells cells :author author :status "published"
                      :visibility "public" :published-at (local-time:now))))

(deftest play-renders-first-scene-beats
  (with-test-db
    (let* ((author (create-test-user))
           (handle (users-handle author)))
      (create-scene-notebook author)
      (with-mock-session (make-session)
        (let ((res (novel-play-handler
                    (list (cons :captures (list handle "novel-1"))))))
          (ok (= 200 (response-status res)))
          (ok (search "やあ" (first (response-body res))))
          (ok (search "novel-player" (first (response-body res)))))))))

(deftest play-missing-notebook-is-404
  (with-test-db
    (with-mock-session (make-session)
      (let ((res (novel-play-handler
                  (list (cons :captures (list "nope" "nope"))))))
        (ok (= 404 (response-status res)))))))

(deftest advance-with-login-flows-flags
  "A logged-in reader: play sets met-alice; advance to scene 2 sees it set."
  (with-test-db
    (let* ((author (create-test-user))
           (handle (users-handle author))
           (user (list :id (users-id author))))
      (create-scene-notebook author)
      (with-mock-session (make-session :user user)
        ;; play scene 0 (sets met-alice and persists it)
        (novel-play-handler (list (cons :captures (list handle "novel-1"))))
        ;; advance to scene 1: met-alice now set -> the "again" line
        (let ((res (novel-advance-handler
                    (list (cons :captures (list handle "novel-1"))))))
          (ok (= 200 (response-status res)))
          (ok (search "また会ったね。" (first (response-body res))))
          (ok (not (search "誰？" (first (response-body res))))))))))
