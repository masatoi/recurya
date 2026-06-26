;;;; web/routes-novel.lisp --- Novel player routes (play / advance).
(defpackage #:recurya/web/routes-novel
  (:use #:cl)
  (:import-from #:recurya/db/notebooks
                #:find-notebook-by-handle-and-slug #:notebook-id
                #:notebook-title #:notebook-cells-parsed)
  (:import-from #:recurya/game/notebook-jsonb #:jsonb-hash->cell)
  (:import-from #:recurya/game/notebook #:cell-kind #:cell-body)
  (:import-from #:recurya/game/novel/eval #:split-novel-cells #:eval-scene)
  (:import-from #:recurya/game/novel/interpreter #:interpret-directives)
  (:import-from #:recurya/db/novel
                #:get-novel-state #:upsert-novel-state #:novel-state-flags-alist)
  (:import-from #:recurya/models/novel-state #:novel-state-scene-index)
  (:import-from #:recurya/web/ui/novel #:render-player)
  (:import-from #:recurya/utils/access-control #:can-view-notebook-p)
  (:import-from #:recurya/web/ui/errors #:not-found)
  (:export #:setup-novel-routes #:novel-play-handler #:novel-advance-handler))

(in-package #:recurya/web/routes-novel)

;;; --- Local response/request helpers (same pattern as web/routes.lisp) ---

(defun html-response (body &key (status 200))
  "Create an HTML response."
  (list status '(:content-type "text/html; charset=utf-8") (list body)))

(defun captures (params)
  "Return the regex capture list (strings, in pattern order)."
  (cdr (assoc :captures params)))

(defun current-user ()
  "Get the current user plist from the session, or NIL."
  (when ningle/context:*session*
    (gethash :user ningle/context:*session*)))

(defun make-dynamic-handler (handler-symbol)
  "Create a handler that looks up the function by symbol at call time."
  (lambda (params) (funcall (symbol-function handler-symbol) params)))

(defun novel-cell-pairs (nb-row)
  "Return (kind . body) pairs (kind keyword, body string) for NB-ROW's cells."
  (mapcar (lambda (c) (cons (cell-kind c) (cell-body c)))
          (mapcar #'jsonb-hash->cell
                  (coerce (or (notebook-cells-parsed nb-row) #()) 'list))))

(defun reader-state (uid nb-id-str)
  "Return (values SCENE-INDEX FLAGS) for UID on NB-ID-STR.
   Anonymous reader or no saved row -> (values 0 NIL)."
  (let ((row (and uid (get-novel-state uid nb-id-str))))
    (if row
        (values (novel-state-scene-index row) (novel-state-flags-alist row))
        (values 0 nil))))

(defun merge-flags (flags set-flags)
  "Merge SET-FLAGS (alist) into FLAGS (alist); SET-FLAGS override existing keys."
  (let ((result (copy-alist flags)))
    (dolist (sf set-flags result)
      (let ((cell (assoc (car sf) result)))
        (if cell
            (setf (cdr cell) (cdr sf))
            (setf result (append result (list (cons (car sf) (cdr sf))))))))))

(defun scene-beats (scenes prelude index flags uid nb-id-str)
  "Evaluate scene INDEX (when in range) with FLAGS, persist the merged flags and
   INDEX for a logged-in reader (UID), and return the scene's BEATS. Returns NIL
   when INDEX is out of range (the reader has reached the end)."
  (if (and (>= index 0) (< index (length scenes)))
      (multiple-value-bind (beats set-flags)
          (interpret-directives
           (eval-scene (nth index scenes) :prelude prelude :flags flags))
        (when uid
          (upsert-novel-state uid nb-id-str
                              :flags (merge-flags flags set-flags)
                              :scene-index index))
        beats)
      (progn
        (when uid
          (upsert-novel-state uid nb-id-str :flags flags
                                            :scene-index (max 0 index)))
        nil)))

(defun load-novel (params)
  "Resolve PARAMS to (values NB-ROW UID). NB-ROW is NIL when the notebook is
   missing or not viewable by the current reader."
  (let* ((caps (captures params))
         (nb-row (find-notebook-by-handle-and-slug (first caps) (second caps)))
         (user (current-user))
         (uid (and user (getf user :id))))
    (if (and nb-row (can-view-notebook-p user nb-row))
        (values nb-row uid)
        (values nil uid))))

;;; --- Handlers ---

(defun novel-play-handler (params)
  "GET /@<handle>/<slug>/play - render the reader's current scene as a player."
  (multiple-value-bind (nb-row uid) (load-novel params)
    (if (null nb-row)
        (html-response (not-found) :status 404)
        (let ((nb-id-str (princ-to-string (notebook-id nb-row))))
          (multiple-value-bind (prelude scenes)
              (split-novel-cells (novel-cell-pairs nb-row))
            (multiple-value-bind (index flags) (reader-state uid nb-id-str)
              (html-response
               (render-player
                :title (notebook-title nb-row)
                :beats (or (scene-beats scenes prelude index flags uid nb-id-str)
                           '())))))))))

(defun novel-advance-handler (params)
  "POST /@<handle>/<slug>/play/advance - advance to the next scene and return
   the player for it. Flag changes from already-rendered scenes persist for a
   logged-in reader, so the next scene branches on the up-to-date flags."
  (multiple-value-bind (nb-row uid) (load-novel params)
    (if (null nb-row)
        (html-response (not-found) :status 404)
        (let ((nb-id-str (princ-to-string (notebook-id nb-row))))
          (multiple-value-bind (prelude scenes)
              (split-novel-cells (novel-cell-pairs nb-row))
            (multiple-value-bind (index flags) (reader-state uid nb-id-str)
              (html-response
               (render-player
                :title (notebook-title nb-row)
                :beats (or (scene-beats scenes prelude (1+ index) flags
                                        uid nb-id-str)
                           '())))))))))

;;; --- Route setup ---

(defun setup-novel-routes (app)
  "Register the novel player routes (play / advance) on the Ningle APP.
   Registered as regex routes because Ningle URL-encodes literal `@'."
  (setf (ningle/app:route app "^/@([\\w-]+)/([\\w-]+)/play/advance$"
                          :method :post :regexp t)
        (make-dynamic-handler 'novel-advance-handler))
  (setf (ningle/app:route app "^/@([\\w-]+)/([\\w-]+)/play/?$"
                          :method :get :regexp t)
        (make-dynamic-handler 'novel-play-handler))
  app)
