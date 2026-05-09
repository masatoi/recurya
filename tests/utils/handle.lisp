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
    (ng (recurya/utils/handle:valid-handle-p "alice@bob"))))

(deftest reserved-handles
  (testing "reserved words are rejected"
    (ok (recurya/utils/handle:reserved-handle-p "notebooks"))
    (ok (recurya/utils/handle:reserved-handle-p "dashboard"))
    (ok (recurya/utils/handle:reserved-handle-p "admin"))
    (ok (recurya/utils/handle:reserved-handle-p "API")) ; case insensitive
    (ng (recurya/utils/handle:reserved-handle-p "alice"))))
