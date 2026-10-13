;;;; web/ui/account.lisp --- Account settings page with HTMX delete modal.
;;;;
;;;; Renders profile settings (display name, language, timezone) and a
;;;; danger zone with HTMX-powered account deletion confirmation modal.

(defpackage #:recurya/web/ui/account
  (:use #:cl)
  (:import-from #:spinneret
                #:with-html-string)
  (:import-from #:recurya/web/ui/layout
                #:common-styles
                #:page-shell)
  (:import-from #:recurya/web/ui/csrf
                #:csrf-input)
  (:import-from #:recurya/web/i18n/core
                #:tr
                #:available-locales)
  (:import-from #:recurya/models/api-token
                #:api-token-id
                #:api-token-name
                #:api-token-token-prefix
                #:api-token-created-at
                #:api-token-last-used-at)
  (:import-from #:recurya/db/core
                #:null->nil)
  (:export #:render
           #:render-api-tokens))

(in-package #:recurya/web/ui/account)

(defparameter *account-styles*
  "/* Account page specific styles */
form.settings {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  margin-top: 1.5rem;
}

form.settings .button-primary {
  align-self: flex-start;
}

.settings-section {
  margin-top: 1.5rem;
  padding-top: 1.5rem;
  border-top: 1px solid var(--color-border-light);
}

.settings-section h3 {
  margin: 0 0 1rem 0;
  font-size: 1rem;
  color: var(--color-text-dark);
}

.settings-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}

@media (max-width: 640px) {
  .settings-row {
    grid-template-columns: 1fr;
  }
}")

(defparameter *languages*
  '(("en" . "English")
    ("ja" . "日本語")
    ("zh" . "中文")
    ("ko" . "한국어")
    ("es" . "Español")
    ("fr" . "Français")
    ("de" . "Deutsch")
    ("pt" . "Português")
    ("it" . "Italiano"))
  "Supported language options for user preferences.")

(defparameter *timezones*
  '(("UTC" . "UTC")
    ("America/New_York" . "Eastern Time (US)")
    ("America/Chicago" . "Central Time (US)")
    ("America/Denver" . "Mountain Time (US)")
    ("America/Los_Angeles" . "Pacific Time (US)")
    ("Europe/London" . "London")
    ("Europe/Paris" . "Paris / Berlin")
    ("Europe/Moscow" . "Moscow")
    ("Asia/Dubai" . "Dubai")
    ("Asia/Kolkata" . "India")
    ("Asia/Singapore" . "Singapore")
    ("Asia/Shanghai" . "China")
    ("Asia/Tokyo" . "Tokyo")
    ("Asia/Seoul" . "Seoul")
    ("Australia/Sydney" . "Sydney")
    ("Pacific/Auckland" . "Auckland"))
  "Common timezone options for user preferences.")

(defun format-token-time (timestamp)
  "TIMESTAMP as YYYY-MM-DD HH:MM (UTC), or NIL for NIL/:NULL."
  (let ((ts (null->nil timestamp)))
    (when ts
      (local-time:format-timestring
       nil ts :format '(:year "-" (:month 2) "-" (:day 2) " " (:hour 2) ":" (:min 2))
              :timezone local-time:+utc-zone+))))

(defun render-api-tokens (tokens &key new-token error)
  "The API token section (#api-tokens): an HTMX form to issue a token, the
just-issued NEW-TOKEN shown once, ERROR if any, and TOKENS (rows) with a
revoke button each.  Returned as an HTML string; it is both part of the
account page and the HTMX swap response."
  (with-html-string
    (:section :id "api-tokens" :class "card"
      (:h2 (tr :account.tokens.heading))
      (:p :class "muted" (tr :account.tokens.body))
      (when error
        (:div :class "message error" error))
      (when new-token
        (:div :class "message success"
          (:p (tr :account.tokens.new_notice))
          (:pre (:code new-token))))
      (:form :class "settings" :hx-post "/account/tokens"
             :hx-target "#api-tokens" :hx-swap "outerHTML"
        (:raw (csrf-input))
        (:div
          (:label :for "api-token-name" (tr :account.tokens.name_label))
          (:input :id "api-token-name" :name "name" :type "text" :maxlength "64"))
        (:button :type "submit" :class "button-primary" (tr :account.tokens.create)))
      (if (null tokens)
          (:p :class "muted" (tr :account.tokens.empty))
          (:table
            (:thead
              (:tr (:th (tr :account.tokens.col_name))
                   (:th (tr :account.tokens.col_token))
                   (:th (tr :account.tokens.col_created))
                   (:th (tr :account.tokens.col_last_used))
                   (:th "")))
            (:tbody
              (dolist (row tokens)
                (:tr
                  (:td (api-token-name row))
                  (:td (:code (api-token-token-prefix row) "…"))
                  (:td (or (format-token-time (api-token-created-at row)) ""))
                  (:td (or (format-token-time (api-token-last-used-at row))
                           (tr :account.tokens.never)))
                  (:td
                    (:form :hx-post (format nil "/account/tokens/~D/revoke" (api-token-id row))
                           :hx-target "#api-tokens" :hx-swap "outerHTML"
                      (:raw (csrf-input))
                      (:button :type "submit" :class "button-danger"
                               (tr :account.tokens.revoke))))))))))))

(defun render (&key user message error tokens)
  "Render the account settings page."
  (let ((email (getf user :email))
        (display-name (or (getf user :name) ""))
        (language (or (getf user :language) "en"))
        (timezone (or (getf user :timezone) "UTC"))
        (page-styles (concatenate 'string (common-styles) *account-styles*)))
    (page-shell
     :title (tr :account.page_title)
     :styles page-styles
     :user user
     :body-content
     (with-html-string
       (:div :class "card"
         (:h1 (tr :account.heading))
         (:p :class "muted" (tr :account.subtitle))
         (when message
           (:div :class "message success" message))
         (when error
           (:div :class "message error" error))
         (:form :class "settings" :method "post" :action "/account"
           (:raw (csrf-input))
           (:div
             (:label :for "account-email" (tr :account.field.email))
             (:input :id "account-email" :type "text" :value email :readonly t))
           (:div
             (:label :for "account-display-name" (tr :account.field.display_name))
             (:input :id "account-display-name"
                     :name "display-name"
                     :type "text"
                     :value display-name
                     :required t
                     :minlength "1"
                     :maxlength "120"))
           ;; Language and Timezone settings
           (:div :class "settings-section"
             (:h3 (tr :account.regional.heading))
             (:div :class "settings-row"
               (:div
                 (:label :for "account-language" (tr :account.regional.language))
                 (:select :id "account-language" :name "language"
                   (dolist (lang *languages*)
                     (let ((code (car lang))
                           (label (cdr lang)))
                       (when (member code (available-locales)
                                     :key #'symbol-name :test #'string-equal)
                         (if (string= code language)
                             (:option :value code :selected t label)
                             (:option :value code label)))))))
               (:div
                 (:label :for "account-timezone" (tr :account.regional.timezone))
                 (:select :id "account-timezone" :name "timezone"
                   (dolist (tz *timezones*)
                     (let ((code (car tz))
                           (label (cdr tz)))
                       (if (string= code timezone)
                           (:option :value code :selected t label)
                           (:option :value code label))))))))
           (:button :type "submit" :class "button-primary" (tr :account.save))))
       (:raw (render-api-tokens tokens))
       (:div :class "card"
         (:h2 (tr :account.danger.heading))
         (:p :class "muted" (tr :account.danger.body))
         (:button :type "button" :class "button-danger"
                  :hx-get "/account/confirm-delete"
                  :hx-target "#modal-container"
                  :hx-swap "innerHTML"
                  (tr :account.danger.delete)))
       (:div :id "modal-container")))))
