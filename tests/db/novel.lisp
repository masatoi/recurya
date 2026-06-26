;;;; tests/db/novel.lisp
(defpackage #:recurya/tests/db/novel
  (:use #:cl #:rove)
  (:import-from #:recurya/tests/support/db #:with-test-db #:create-test-user)
  (:import-from #:recurya/models/users #:users-id)
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
