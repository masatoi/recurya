(defpackage #:recurya/tests/utils/handle
  (:use #:cl #:rove))
(in-package #:recurya/tests/utils/handle)

(deftest handle-validation
  (testing "valid handles"
    (ok (recurya/utils/handle:valid-handle-p "alice"))
    (ok (recurya/utils/handle:valid-handle-p "bob-the-builder"))
    (ok (recurya/utils/handle:valid-handle-p "user123"))
    (ok (recurya/utils/handle:valid-handle-p "abc")))
  (testing "invalid: too short"
    (ng (recurya/utils/handle:valid-handle-p "ab"))
    (ng (recurya/utils/handle:valid-handle-p "")))
  (testing "invalid: uppercase"
    (ng (recurya/utils/handle:valid-handle-p "Alice")))
  (testing "invalid: leading/trailing hyphen"
    (ng (recurya/utils/handle:valid-handle-p "-alice"))
    (ng (recurya/utils/handle:valid-handle-p "alice-")))
  (testing "invalid: special chars"
    (ng (recurya/utils/handle:valid-handle-p "alice.bob"))
    (ng (recurya/utils/handle:valid-handle-p "alice_bob"))
    (ng (recurya/utils/handle:valid-handle-p "alice@bob")))
  (testing "invalid: trailing or embedded whitespace"
    (ng (recurya/utils/handle:valid-handle-p (format nil "alice~%")))
    (ng (recurya/utils/handle:valid-handle-p (format nil "~%alice")))
    (ng (recurya/utils/handle:valid-handle-p "ali ce"))
    (ng (recurya/utils/handle:valid-handle-p " alice"))
    (ng (recurya/utils/handle:valid-handle-p "alice ")))
  (testing "boundary lengths"
    (ok (recurya/utils/handle:valid-handle-p
          (concatenate 'string "a" (make-string 62 :initial-element #\b) "c"))) ; 64 chars
    (ng (recurya/utils/handle:valid-handle-p
          (concatenate 'string "a" (make-string 63 :initial-element #\b) "c")))) ; 65 chars
  (testing "nil and non-string input"
    (ng (recurya/utils/handle:valid-handle-p nil))
    (ng (recurya/utils/handle:valid-handle-p 42))
    (ng (recurya/utils/handle:valid-handle-p :alice))))

(deftest reserved-handles
  (testing "reserved words are rejected"
    (ok (recurya/utils/handle:reserved-handle-p "notebooks"))
    (ok (recurya/utils/handle:reserved-handle-p "dashboard"))
    (ok (recurya/utils/handle:reserved-handle-p "admin"))
    (ok (recurya/utils/handle:reserved-handle-p "API")) ; case insensitive
    (ng (recurya/utils/handle:reserved-handle-p "alice")))
  (testing "nil and non-string input"
    (ng (recurya/utils/handle:reserved-handle-p nil))
    (ng (recurya/utils/handle:reserved-handle-p 42))
    (ng (recurya/utils/handle:reserved-handle-p :alice))))
