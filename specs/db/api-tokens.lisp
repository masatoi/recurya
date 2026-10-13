;;;; specs/db/api-tokens.lisp --- cl-spec contracts for personal API tokens.
;;;;
;;;; A token authenticates exactly its owner while unrevoked; revocation is
;;;; owner-only; nothing but the SHA-256 of a token is stored.  Each trial
;;;; runs inside WITH-TEST-DB (recurya_test only).  Design doc:
;;;; docs/superpowers/specs/2026-10-13-learner-cli-design.md

(defpackage #:recurya/specs/db/api-tokens
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defspec-function
                #:defproperty
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:recurya/specs/db/domain
                #:random-element)
  (:import-from #:recurya/tests/support/db
                #:with-test-db
                #:create-test-user)
  (:import-from #:recurya/db/users
                #:users-id)
  (:import-from #:recurya/models/api-token
                #:api-token-id
                #:api-token-token-hash)
  (:import-from #:recurya/db/api-tokens
                #:issue-api-token
                #:authenticate-api-token
                #:revoke-api-token
                #:list-api-tokens
                #:hash-token
                #:normalize-token-name))
(in-package #:recurya/specs/db/api-tokens)

(defgenerator token-ops ()
  "0-10 operations: (:issue U), (:revoke K) by the owner, (:cross-revoke K) by
the other user, (:forge).  U picks one of two users; K indexes the tokens
issued so far (modulo their count).  At most 10 issues, so the per-user limit
is never reached."
  (loop repeat (random 11)
        collect (random-element
                 (vector (list :issue (random 2))
                         (list :revoke (random 10))
                         (list :cross-revoke (random 10))
                         (list :forge)))))

(defspec token-ops list (:generator token-ops))

(defun same-id-p (a b)
  "True when ids A and B print the same, ignoring case."
  (string-equal (princ-to-string a) (princ-to-string b)))

(defproperty api-token-lifecycle ((ops token-ops))
  "After any sequence of issues and revocations: every unrevoked token
authenticates to its owner, every revoked or forged one to nobody, a user
cannot revoke another's token, rows hold only the hash of the plaintext, and
each user lists exactly their unrevoked tokens."
  (:about issue-api-token authenticate-api-token revoke-api-token list-api-tokens)
  (:kind :invariant)
  (:trials (:smoke 10 :normal 50))
  (with-test-db
    (let ((users (vector (users-id (create-test-user :email-prefix "spec-tok"))
                         (users-id (create-test-user :email-prefix "spec-tok"))))
          (issued '())                  ; newest first: (plain owner row revoked-p)
          (forged '())
          (cross-ok t))
      (dolist (op ops)
        (ecase (first op)
          (:issue
           (let ((owner (second op)))
             (multiple-value-bind (plain row)
                 (issue-api-token (aref users owner) "spec")
               (push (list plain owner row nil) issued))))
          (:revoke
           (when issued
             (let ((entry (nth (mod (second op) (length issued)) issued)))
               (revoke-api-token (aref users (second entry)) (api-token-id (third entry)))
               (setf (fourth entry) t))))
          (:cross-revoke
           (when issued
             (let ((entry (nth (mod (second op) (length issued)) issued)))
               (when (revoke-api-token (aref users (- 1 (second entry)))
                                       (api-token-id (third entry)))
                 (setf cross-ok nil)))))
          (:forge
           (push (concatenate 'string "rcy_"
                              (format nil "~(~64,'0x~)" (random (expt 2 256))))
                 forged))))
      (and cross-ok
           (loop for (plain owner row revoked) in issued
                 always (and (string= (api-token-token-hash row) (hash-token plain))
                             (string/= (api-token-token-hash row) plain)
                             (let ((who (authenticate-api-token plain)))
                               (if revoked
                                   (null who)
                                   (and who (same-id-p (users-id who)
                                                       (aref users owner)))))))
           (loop for plain in forged
                 always (null (authenticate-api-token plain)))
           (loop for u below 2
                 always (let ((listed (mapcar #'api-token-id
                                              (list-api-tokens (aref users u))))
                              (live (loop for (nil owner row revoked) in issued
                                          when (and (= owner u) (not revoked))
                                            collect (api-token-id row))))
                          (and (subsetp listed live) (subsetp live listed)
                               (= (length listed) (length live)))))))))

(defgenerator token-name-input ()
  "Names a user might type: empty, blank, plain, padded, over-long, non-ASCII."
  (random-element (vector "" "   " "laptop" "  ci box  "
                          (make-string 80 :initial-element #\a)
                          "ラップトップ" (format nil "~Ctab~%" #\Tab))))

(defspec token-name-input string (:generator token-name-input))

(defspec-function normalize-token-name
  "Surrounding whitespace is trimmed, a blank name becomes \"cli\", and the
result is at most 64 characters."
  (:args (name token-name-input))
  (:returns string)
  (:post (let ((trimmed (string-trim '(#\Space #\Tab #\Newline #\Return) name)))
           (if (zerop (length trimmed))
               (string= result "cli")
               (string= result (subseq trimmed 0 (min 64 (length trimmed))))))))
