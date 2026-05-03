;;;; utils/html-sanitize.lisp --- Allowlist HTML sanitizer.

(defpackage #:recurya/utils/html-sanitize
  (:use #:cl)
  (:export #:sanitize-html))

(in-package #:recurya/utils/html-sanitize)

(defparameter +allowed-tags+
  '("p" "strong" "em" "code" "pre" "a" "ul" "ol" "li" "blockquote"
    "h1" "h2" "h3" "h4" "h5" "h6" "br" "hr" "img")
  "HTML tags permitted in user-authored prose. Anything else is dropped
along with its content (including <script>, <style>, <iframe>).")

(defparameter +allowed-attrs+
  '(("a"   . ("href"))
    ("img" . ("src" "alt")))
  "Per-tag allowlist of attribute names. Any attribute not in this
list (including class, style, and on* event handlers) is removed.")

(defparameter +url-prefix-whitelist+
  '("http://" "https://" "/" "./" "../" "#")
  "URL prefixes considered safe for href/src. A URL that contains a
colon but does not begin with one of these prefixes is treated as an
unsafe scheme (javascript:, data:, mailto:, file:, etc.) and rejected.")

(defun starts-with-p (prefix str)
  "Return T if STR begins with PREFIX (case-sensitive)."
  (let ((lp (length prefix))
        (ls (length str)))
    (and (>= ls lp)
         (string= prefix str :end2 lp))))

(defun safe-url-p (url)
  "Return T if URL uses a safe scheme or is a relative reference.
Empty strings, fragment links (#foo), absolute paths (/foo), and
http(s):// URLs pass. A URL with any colon that did not match an
http(s):// prefix is rejected as an unsafe scheme. Whitespace is
trimmed before inspection so '  javascript:...' is also rejected."
  (let ((url (string-trim '(#\Space #\Tab #\Newline #\Return) (or url ""))))
    (cond
      ((zerop (length url)) t)
      ((some (lambda (p) (starts-with-p p url)) +url-prefix-whitelist+) t)
      ((find #\: url) nil)
      (t t))))

(defun sanitize-html (html-string)
  "Sanitize HTML-STRING using a tag/attribute allowlist.

Returns a string. Disallowed tags (e.g. <script>, <iframe>, <style>) are
removed entirely along with their content. Disallowed attributes (e.g.
class, onclick, style) are stripped from kept tags. The href attribute
on <a> and the src attribute on <img> are dropped if their value uses
an unsafe URL scheme (anything other than http://, https://, fragments,
or a relative path). HTML entities are decoded by Plump at parse time,
so entity-encoded schemes like 'javascript&#58;' are handled."
  (let ((root (plump:parse (or html-string ""))))
    ;; Pass 1: drop disallowed elements (script, style, iframe, ...) entirely.
    ;; We collect first, then remove, to keep traversal predictable.
    (let ((dead '()))
      (plump:traverse
       root
       (lambda (node)
         (let ((tag (string-downcase (plump:tag-name node))))
           (unless (member tag +allowed-tags+ :test #'equal)
             (push node dead))))
       :test #'plump:element-p)
      (dolist (node dead)
        (plump:remove-child node)))
    ;; Pass 2: scrub attributes on the remaining (allowlisted) elements.
    (plump:traverse
     root
     (lambda (node)
       (let* ((tag (string-downcase (plump:tag-name node)))
              (allowed (cdr (assoc tag +allowed-attrs+ :test #'equal)))
              (attrs   (plump:attributes node))
              (to-drop '()))
         (maphash (lambda (k v)
                    (let ((lc (string-downcase k)))
                      (cond
                        ;; not in this tag's allowlist -> drop
                        ((not (member lc allowed :test #'equal))
                         (push k to-drop))
                        ;; URL-bearing attribute with unsafe scheme -> drop
                        ((and (member lc '("href" "src") :test #'equal)
                              (not (safe-url-p v)))
                         (push k to-drop)))))
                  attrs)
         (dolist (k to-drop)
           (plump:remove-attribute node k))))
     :test #'plump:element-p)
    (with-output-to-string (s)
      (plump:serialize root s))))
