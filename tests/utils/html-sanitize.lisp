;;;; tests/utils/html-sanitize.lisp --- Tests for HTML sanitizer.

(defpackage #:recurya/tests/utils/html-sanitize
  (:use #:cl #:rove)
  (:import-from #:recurya/utils/html-sanitize #:sanitize-html))

(in-package #:recurya/tests/utils/html-sanitize)

(deftest passes-allowed-tags
  (testing "p, strong, em, code, a remain"
    (ok (search "<p>"        (sanitize-html "<p>hello</p>")))
    (ok (search "<strong>"   (sanitize-html "<strong>x</strong>")))
    (ok (search "<a href"    (sanitize-html "<a href=\"https://example.com\">x</a>")))))

(deftest strips-script-and-on-handlers
  (testing "<script> is removed"
    (ng (search "<script"    (sanitize-html "<p>ok</p><script>alert(1)</script>"))))
  (testing "onclick attribute is removed"
    (ng (search "onclick"    (sanitize-html "<a href=\"x\" onclick=\"a()\">x</a>")))))

(deftest strips-javascript-href
  (testing "javascript: scheme is removed from a@href"
    (let ((out (sanitize-html "<a href=\"javascript:alert(1)\">x</a>")))
      (ng (search "javascript:" out)))))

(deftest strips-iframe-and-style
  (ng (search "<iframe" (sanitize-html "<iframe src=\"x\"></iframe>")))
  (ng (search "<style"  (sanitize-html "<style>body{}</style>"))))
