;;;; db/novel.lisp --- CRUD for per-reader novel state.
(defpackage #:recurya/db/novel
  (:use #:cl)
  (:import-from #:mito #:find-dao #:insert-dao #:save-dao)
  (:import-from #:recurya/db/core #:ensure-uuid)
  (:import-from #:recurya/utils/common #:parse-json #:json->string)
  (:import-from #:recurya/models/novel-state
                #:novel-state
                #:novel-state-flags #:novel-state-scene-index)
  (:export #:novel-state
           #:get-novel-state #:upsert-novel-state
           #:novel-state-flags-alist))

(in-package #:recurya/db/novel)

(defun %flag-value->json (value)
  "VALUE as stored in the flags JSON: a keyword as {\"symbol\": <lower-case
name>}; T, NIL, integers and strings as themselves (true, false, numbers,
strings)."
  (if (keywordp value)
      (let ((h (make-hash-table :test 'equal)))
        (setf (gethash "symbol" h) (string-downcase (symbol-name value)))
        h)
      value))

(defun %json->flag-value (json)
  "Read one stored flag value.  Returns (VALUES VALUE T) for true, false, an
integer, a string, or a {\"symbol\": name} object (a keyword); (VALUES NIL NIL)
for anything else (arrays, floats, null, other objects), which the reader
drops."
  (cond ((eq json t) (values t t))
        ((null json) (values nil t))
        ((integerp json) (values json t))
        ((stringp json) (values json t))
        ((and (hash-table-p json)
              (= (hash-table-count json) 1)
              (stringp (gethash "symbol" json)))
         (values (intern (string-upcase (gethash "symbol" json)) :keyword) t))
        (t (values nil nil))))

(defun %flags->json (flags)
  "Serialize FLAGS, an alist (flag-keyword -> value), to the flags JSON object
stored in novel_state: keys are the lower-case flag names.  Values are written
by %FLAG-VALUE->JSON."
  (let ((h (make-hash-table :test 'equal)))
    (dolist (pair flags)
      (setf (gethash (string-downcase (symbol-name (car pair))) h)
            (%flag-value->json (cdr pair))))
    (json->string h)))

(defun get-novel-state (user-id notebook-id)
  "Return the NOVEL-STATE row for (USER-ID, NOTEBOOK-ID), or NIL."
  (find-dao 'novel-state :user-id (ensure-uuid user-id) :notebook-id notebook-id))

(defun upsert-novel-state (user-id notebook-id &key flags scene-index)
  "Insert or update the per-reader novel state. FLAGS is an alist
   (flag-keyword -> T, NIL, integer, string or keyword) stored as JSON by
   %FLAGS->JSON; a NIL FLAGS or SCENE-INDEX leaves an existing row's value
   unchanged. Returns the row."
  (let* ((uid (ensure-uuid user-id))
         (flags-json (%flags->json flags))
         (existing (find-dao 'novel-state :user-id uid :notebook-id notebook-id)))
    (if existing
        (progn
          (when flags (setf (novel-state-flags existing) flags-json))
          (when scene-index (setf (novel-state-scene-index existing) scene-index))
          (save-dao existing))
        (insert-dao (make-instance 'novel-state
                                   :user-id uid :notebook-id notebook-id
                                   :flags flags-json
                                   :scene-index (or scene-index 0))))))

(defun novel-state-flags-alist (row)
  "Parse ROW's flags JSON back to an alist (flag-keyword -> value).  Values
come back as %FLAGS->JSON wrote them: T, NIL, integers, strings and keywords.
A stored value of any other shape (an array written before symbol values were
tagged, a float, null) is dropped with its flag.  NIL when the column does not
hold a JSON object."
  (let ((ht (parse-json (novel-state-flags row))))
    (when (hash-table-p ht)
      (loop for k being the hash-keys of ht using (hash-value v)
            for (value ok) = (multiple-value-list (%json->flag-value v))
            when ok
              collect (cons (intern (string-upcase k) :keyword) value)))))
