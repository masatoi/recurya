;;;; web/ui/login.lisp --- Login page.

(defpackage #:recurya/web/ui/login
  (:use #:cl)
  (:import-from #:spinneret
                #:with-html-string)
  (:import-from #:recurya/web/ui/styles
                #:auth-page-styles)
  (:import-from #:recurya/web/oauth
                #:dev-stub-enabled-p
                #:dev-stub-email)
  (:export #:render))

(in-package #:recurya/web/ui/login)

(defun render (&key error)
  "Render the OAuth login page with provider sign-in buttons."
  (spinneret:with-html-string
    (:doctype)
    (:html
     (:head
      (:meta :charset "utf-8")
      (:meta :name "viewport" :content "width=device-width, initial-scale=1")
      (:title "recurya - Sign in")
      (:style (:raw (auth-page-styles))))
     (:body
      (:div :class "auth-container"
            (:div :class "app-name" "Sign in to recurya")
            (when error
              (:div :class "error" error))
            (when (dev-stub-enabled-p)
              (:div :class "dev-banner"
                    (:strong "Dev OAuth stub is active.")
                    " Sign-in with any provider will create or reuse "
                    (:code (dev-stub-email))
                    " without contacting Google or GitHub."))
            (:h1 "Welcome")
            (:p :class "auth-help"
                "Pick a provider to sign in. Your progress and saved code will follow you across devices.")
            (:a :class "button-primary oauth-button oauth-google"
                :href "/auth/google/start"
                "Sign in with Google")
            (:a :class "button-primary oauth-button oauth-github"
                :href "/auth/github/start"
                "Sign in with GitHub")
            (:p :class "app-name auth-footnote"
                "We never see your password. Email and display name come from the provider you choose."))))))
