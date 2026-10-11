;;;; tests/db/novel.lisp
(defpackage #:recurya/tests/db/novel
  (:use #:cl #:rove)
  (:import-from #:recurya/tests/support/db #:with-test-db #:create-test-user)
  (:import-from #:recurya/models/users #:users-id)
  (:import-from #:recurya/db/core #:execute!)
  (:import-from #:recurya/db/novel
                #:get-novel-state #:upsert-novel-state #:novel-state-flags-alist)
  (:import-from #:recurya/models/novel-state
                #:novel-state-scene-index))

(in-package #:recurya/tests/db/novel)

(deftest upsert-and-get-roundtrip
  (with-test-db
    (let* ((u (create-test-user))
           (uid (users-id u))
           (nb "nb-123"))
      (ok (null (get-novel-state uid nb)) "no state initially")
      (upsert-novel-state uid nb :flags '((:met-alice . t) (:count . 3)) :scene-index 2)
      (let ((row (get-novel-state uid nb)))
        (ok row)
        (ok (= 2 (novel-state-scene-index row)))
        (let ((fl (novel-state-flags-alist row)))
          (ok (eq t (cdr (assoc :met-alice fl))))
          (ok (= 3 (cdr (assoc :count fl))))))
      ;; second upsert updates the same row (no duplicate)
      (upsert-novel-state uid nb :flags '((:met-alice . t)) :scene-index 5)
      (let ((row (get-novel-state uid nb)))
        (ok (= 5 (novel-state-scene-index row)))))))

(deftest symbol-flag-values-roundtrip
  (with-test-db
    (let ((uid (users-id (create-test-user))))
      (upsert-novel-state uid "nb-sym" :flags '((:mood . :happy) (:name . "HAPPY")))
      (let ((fl (novel-state-flags-alist (get-novel-state uid "nb-sym"))))
        (ok (eq :happy (cdr (assoc :mood fl))) "a symbol value comes back as a keyword")
        (ok (equal "HAPPY" (cdr (assoc :name fl))) "a string value stays a string")))))

(deftest unreadable-flag-values-are-dropped
  (with-test-db
    (let ((uid (users-id (create-test-user))))
      (upsert-novel-state uid "nb-old" :flags '((:ok . t)))
      (execute! "UPDATE novel_state SET flags = $1 WHERE notebook_id = $2"
                "{\"xs\":[1,2],\"ok\":true,\"f\":1.5}" "nb-old")
      (ok (equal '((:ok . t))
                 (novel-state-flags-alist (get-novel-state uid "nb-old")))
          "arrays and floats from old rows are dropped"))))
