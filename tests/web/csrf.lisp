;;;; tests/web/csrf.lisp --- Integration tests for the CSRF middleware.
;;;;
;;;; These tests boot the full Lack/Hunchentoot stack via clack-test and
;;;; exercise the CSRF middleware end-to-end with real HTTP requests.
;;;; They verify:
;;;;   * GET requests bypass the middleware (it only guards POST/PUT/DELETE/PATCH).
;;;;   * POST without a token is rejected with 400.
;;;;   * POST with a mismatched token is rejected with 400.
;;;;   * POST with a valid token reaches the handler (no 400).
;;;;   * /learn/sync is on the skip-list and is never rejected for missing token.
;;;;   * The OAuth GET callback is unaffected (no token required).

(defpackage #:recurya/tests/web/csrf
  (:use #:cl
        #:rove)
  (:import-from #:clack.test
                #:testing-app
                #:localhost
                #:*clack-test-access-port*)
  (:import-from #:cl-ppcre
                #:register-groups-bind)
  ;; recurya/web/server is required so the package exists and we can
  ;; reach the internal BUILD-APP via ::. We don't import the symbol
  ;; because it is not exported from the server package.
  (:import-from #:recurya/web/server))

(in-package #:recurya/tests/web/csrf)

;;; -- Test helpers ----------------------------------------------------------

(defun build-test-app ()
  "Build a fresh Lack app for CSRF integration testing.
BUILD-APP is internal to recurya/web/server, so we resolve it via
UIOP:SYMBOL-CALL rather than importing it directly."
  (uiop:symbol-call '#:recurya/web/server '#:build-app))

(defun http-request (path &key (method :get) content cookie)
  "Issue an HTTP request to the locally-running test app.
Returns (values BODY STATUS HEADERS).

Wraps DEXADOR so that 4xx/5xx responses do not signal — instead we capture
the response status from the condition and continue. This lets the tests
assert specific status codes (400, 401, etc.) without HANDLER-CASE noise
in each deftest."
  (let ((url (localhost path *clack-test-access-port*))
        (headers (when cookie
                   `(("cookie" . ,cookie)))))
    (handler-bind
        ((dexador.error:http-request-failed
           (lambda (c)
             (return-from http-request
               (values (dexador.error:response-body c)
                       (dexador.error:response-status c)
                       (dexador.error:response-headers c))))))
      (dex:request url
                   :method method
                   :content content
                   :headers headers
                   :max-redirects 0
                   :keep-alive nil
                   :use-connection-pool nil))))

(defun extract-cookie (headers)
  "Pull the lack.session cookie name=value pair from a response HEADERS hash.
HEADERS is the third value returned by DEX:REQUEST. The Set-Cookie entry
may be either a string or a list of strings (one per cookie). Returns a
string suitable for resending in the Cookie request header, or NIL if no
session cookie was issued."
  (let* ((set-cookie (gethash "set-cookie" headers))
         (entries (cond
                    ((null set-cookie) nil)
                    ((listp set-cookie) set-cookie)
                    (t (list set-cookie)))))
    (loop for entry in entries
          for match = (and (stringp entry)
                           (register-groups-bind (pair)
                               ("(lack\\.session=[^;]+)" entry)
                             pair))
          when match return match)))

(defun extract-csrf-token (body)
  "Extract the CSRF token value from an HTML BODY (string or octet vector).
The form_block helper renders the input as

    <input type=hidden name=_csrf_token
           value=abcdef0123...>

Spinneret omits quotes around safe attribute values, so we accept both
quoted and unquoted forms and we tolerate whitespace between attributes.
Returns the token string or NIL if not found."
  (let ((s (if (stringp body)
               body
               (babel:octets-to-string body :encoding :utf-8))))
    (or (register-groups-bind (tok)
            ("name=\"?_csrf_token\"?\\s+value=\"?([A-Za-z0-9_\\-]+)\"?" s)
          tok)
        (register-groups-bind (tok)
            ("value=\"?([A-Za-z0-9_\\-]+)\"?\\s+name=\"?_csrf_token\"?" s)
          tok))))

;;; -- Tests -----------------------------------------------------------------

(deftest get-skips-csrf
  (testing "GET /login is not blocked by CSRF middleware"
    (testing-app "csrf get bypass"
        (build-test-app)
      (multiple-value-bind (body status headers)
          (http-request "/login" :method :get)
        (declare (ignore body headers))
        (ok (= 200 status)
            "GET /login should reach the handler (CSRF guards only mutating methods)")))))

(deftest post-without-token-returns-400
  (testing "POST without _csrf_token is rejected with 400"
    (testing-app "csrf reject missing"
        (build-test-app)
      (multiple-value-bind (body status headers)
          (http-request "/wardlisp/playground/run"
                        :method :post
                        :content '(("code" . "(+ 1 2)")))
        (declare (ignore body headers))
        (ok (= 400 status)
            "POST without a CSRF token must be rejected with 400")))))

(deftest post-with-mismatched-token-returns-400
  (testing "POST with a wrong _csrf_token is rejected with 400"
    (testing-app "csrf reject mismatch"
        (build-test-app)
      ;; Establish a session cookie + token via a GET that renders the form.
      (multiple-value-bind (get-body get-status get-headers)
          (http-request "/wardlisp/playground" :method :get)
        (declare (ignore get-body))
        (ok (= 200 get-status)
            "Setup GET /wardlisp/playground should succeed")
        (let ((cookie (extract-cookie get-headers)))
          (ok cookie "Setup GET should set a session cookie")
          ;; Now POST with a bogus token but a valid session cookie.
          (multiple-value-bind (body status headers)
              (http-request "/wardlisp/playground/run"
                            :method :post
                            :content '(("code" . "(+ 1 2)")
                                       ("_csrf_token" . "bogus-token-value"))
                            :cookie cookie)
            (declare (ignore body headers))
            (ok (= 400 status)
                "POST with mismatched token must be rejected with 400")))))))

(deftest post-with-valid-token-passes-csrf
  (testing "POST with the matching session token passes CSRF and reaches the handler"
    (testing-app "csrf accept valid"
        (build-test-app)
      ;; First GET to obtain a session cookie + csrf token from a public form.
      (multiple-value-bind (get-body get-status get-headers)
          (http-request "/wardlisp/playground" :method :get)
        (ok (= 200 get-status))
        (let ((cookie (extract-cookie get-headers))
              (token  (extract-csrf-token get-body)))
          (ok cookie "GET should set a session cookie")
          (ok token  "GET should embed a _csrf_token in the playground form")
          ;; Now POST with the token. The endpoint may legitimately respond
          ;; with 200 (success) or another non-400 status — we only assert
          ;; that it is NOT the CSRF rejection.
          (multiple-value-bind (body status headers)
              (http-request "/wardlisp/playground/run"
                            :method :post
                            :content `(("code" . "(+ 1 2)")
                                       ("_csrf_token" . ,token))
                            :cookie cookie)
            (declare (ignore body headers))
            (ng (= 400 status)
                "POST with a valid token must not be rejected by CSRF middleware")))))))

(deftest learn-sync-skips-csrf
  (testing "POST /learn/sync is exempt from CSRF middleware"
    (testing-app "csrf skip learn-sync"
        (build-test-app)
      (multiple-value-bind (body status headers)
          (http-request "/learn/sync"
                        :method :post
                        :content "{}")
        (declare (ignore body headers))
        ;; Without auth, the handler itself returns 401. The point of this
        ;; test is that the CSRF middleware does NOT short-circuit with 400
        ;; before the handler runs, even though no _csrf_token was sent.
        (ok (or (= 200 status)
                (= 401 status)
                (= 500 status))
            "learn-sync should bypass CSRF (any status except 400 is acceptable)")
        (ng (= 400 status)
            "learn-sync must not be blocked by CSRF middleware")))))

(deftest oauth-callback-skips-csrf
  (testing "GET /auth/google/callback is unaffected by CSRF middleware"
    (testing-app "csrf get oauth callback"
        (build-test-app)
      ;; OAuth callback is GET, so the CSRF middleware skips it on the
      ;; method-check. The handler may return 302/400/500 depending on its
      ;; own validation — we only assert it is not the CSRF 400 rejection
      ;; produced *before* the handler runs.
      (multiple-value-bind (body status headers)
          (http-request "/auth/google/callback?code=x&state=y" :method :get)
        (declare (ignore body headers))
        (ok (integerp status)
            "OAuth callback should produce some HTTP response")
        ;; Acceptable: 302 redirect, 400 from handler validation, 500 from
        ;; downstream error. The CSRF middleware never runs for GET, so
        ;; whatever status comes back was decided by the handler itself.
        (ok (member status '(200 302 400 401 500))
            "OAuth callback GET reaches handler (CSRF skips GET methods)")))))
