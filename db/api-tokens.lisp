;;;; db/api-tokens.lisp --- Personal API access tokens: issue, authenticate, revoke.
;;;;
;;;; Tokens are "rcy_" + 64 lower-case hex characters drawn from a strong
;;;; random source.  Only their SHA-256 is stored, so a leaked table does not
;;;; leak usable tokens; the plaintext is returned once, at issue time.

(defpackage #:recurya/db/api-tokens
  (:use #:cl #:mito #:sxql)
  (:import-from #:recurya/models/api-token
                #:api-token
                #:api-token-user-id
                #:api-token-revoked-at
                #:api-token-last-used-at)
  (:import-from #:recurya/db/users
                #:get-user-by-id)
  (:import-from #:recurya/db/core
                #:null->nil
                #:execute-query)
  (:import-from #:local-time
                #:now)
  (:import-from #:ironclad
                #:random-data
                #:digest-sequence
                #:byte-array-to-hex-string)
  (:import-from #:babel
                #:string-to-octets)
  (:export #:*max-active-tokens*
           #:*token-prefix*
           #:token-format-p
           #:hash-token
           #:normalize-token-name
           #:issue-api-token
           #:authenticate-api-token
           #:list-api-tokens
           #:revoke-api-token
           #:api-token-limit-exceeded
           #:api-token-limit-exceeded-user-id))

(in-package #:recurya/db/api-tokens)

(defparameter *token-prefix* "rcy_"
  "Prefix of every plaintext API token.")

(defparameter *max-active-tokens* 10
  "Most unrevoked tokens one user may hold.")

(define-condition api-token-limit-exceeded (error)
  ((user-id :initarg :user-id :reader api-token-limit-exceeded-user-id))
  (:report (lambda (c stream)
             (format stream "User ~A already holds ~D active API tokens"
                     (api-token-limit-exceeded-user-id c) *max-active-tokens*))))

(defun token-format-p (value)
  "True when VALUE is a string shaped like a plaintext token: *TOKEN-PREFIX*
followed by exactly 64 lower-case hex digits."
  (and (stringp value)
       (= (length value) (+ (length *token-prefix*) 64))
       (string= *token-prefix* value :end2 (length *token-prefix*))
       (every (lambda (ch) (find ch "0123456789abcdef"))
              (subseq value (length *token-prefix*)))))

(defun hash-token (plaintext)
  "SHA-256 of PLAINTEXT's UTF-8 octets as 64 lower-case hex digits."
  (byte-array-to-hex-string
   (digest-sequence :sha256 (string-to-octets plaintext :encoding :utf-8))))

(defun normalize-token-name (name)
  "NAME without surrounding whitespace, cut to 64 characters; a blank or
non-string NAME becomes \"cli\"."
  (let ((trimmed (if (stringp name)
                     (string-trim '(#\Space #\Tab #\Newline #\Return) name)
                     "")))
    (if (zerop (length trimmed))
        "cli"
        (subseq trimmed 0 (min 64 (length trimmed))))))

(defun generate-token ()
  "A fresh plaintext token."
  (concatenate 'string *token-prefix* (byte-array-to-hex-string (random-data 32))))

(defun list-api-tokens (user-id)
  "USER-ID's unrevoked token rows, newest first."
  (select-dao 'api-token
    (where (:and (:= :user-id user-id)
                 (:is-null :revoked-at)))
    (order-by (:desc :created-at))))

(defun issue-api-token (user-id name)
  "Issue a token for USER-ID named NAME (normalised by NORMALIZE-TOKEN-NAME).
Returns (VALUES PLAINTEXT ROW).  Signals API-TOKEN-LIMIT-EXCEEDED when the user
already holds *MAX-ACTIVE-TOKENS* unrevoked tokens."
  (when (>= (length (list-api-tokens user-id)) *max-active-tokens*)
    (error 'api-token-limit-exceeded :user-id user-id))
  (let* ((plaintext (generate-token))
         (row (insert-dao (make-instance 'api-token
                                         :user-id user-id
                                         :name (normalize-token-name name)
                                         :token-hash (hash-token plaintext)
                                         :token-prefix (subseq plaintext 0 12)))))
    (values plaintext row)))

(defun authenticate-api-token (plaintext)
  "The users DAO owning PLAINTEXT when it is a well-formed, unrevoked token of
an existing user, recording the use in last_used_at; NIL otherwise."
  (when (token-format-p plaintext)
    (let ((row (find-dao 'api-token :token-hash (hash-token plaintext))))
      (when (and row (null (null->nil (api-token-revoked-at row))))
        (let ((user (get-user-by-id (api-token-user-id row))))
          ;; Touch only last_used_at, and only while the token is still live:
          ;; a full-row save-dao would overwrite a concurrent revocation.
          (when (and user
                     (execute-query
                      "UPDATE api_token SET last_used_at = now() WHERE id = $1 AND revoked_at IS NULL RETURNING id"
                      (object-id row)))
            user))))))

(defun revoke-api-token (user-id token-id)
  "Revoke USER-ID's unrevoked token TOKEN-ID.  T when it was revoked now, NIL
when no such live token of that user exists."
  (let ((row (and (integerp token-id)
                  (find-dao 'api-token :id token-id :user-id user-id))))
    (when (and row (null (null->nil (api-token-revoked-at row))))
      (setf (api-token-revoked-at row) (now))
      (save-dao row)
      t)))
