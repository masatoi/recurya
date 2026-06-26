;;;; tests/game/novel/value.lisp
(defpackage #:recurya/tests/game/novel/value
  (:use #:cl #:rove)
  (:import-from #:recurya/game/novel/value #:ward->directives))

(in-package #:recurya/tests/game/novel/value)

(defun eval-ward (code)
  (multiple-value-bind (r m) (wardlisp:evaluate code)
    (when (getf m :error-message) (error "ward error: ~A" (getf m :error-message)))
    r))

(deftest walks-list-of-directives
  ;; (list (list 'bg "room") (list 'say "アリス" "やあ"))
  (let* ((result (eval-ward "(list (list 'bg \"room\") (list 'say \"アリス\" \"やあ\"))"))
         (dirs (ward->directives result)))
    (ok (equal dirs '((:bg "room") (:say "アリス" "やあ"))))))

(deftest walks-numbers-and-symbols
  (let* ((result (eval-ward "(list (list 'set-flag 'met-alice) (list 'set-flag 'count 3))"))
         (dirs (ward->directives result)))
    (ok (equal dirs '((:set-flag :met-alice) (:set-flag :count 3))))))
