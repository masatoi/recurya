# Global Navigation Unification — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add the global `header` (brand + nav + login state) to every page by routing all render functions through `page-shell`, and replace the notebook reading page's ad-hoc user-banner with the same header.

**Architecture:** `layout.lisp` owns the single `page-shell` entry point. Every render function either calls `page-shell` (passing only its own styles + body markup) or, for the notebook reading page (which has a sidebar + nested `<main>`), calls `header` directly. Anonymous visitors see "未ログイン" + ログイン link; authenticated users see the avatar dropdown.

**Tech Stack:** Common Lisp, Spinneret (HTML DSL), Ningle/Clack, cl-mcp tools (all Lisp edits use `lisp-edit-form` / `lisp-patch-form` — never the Read/Edit/Write tools on `.lisp` files), HTMX.

---

## Constraint: All Lisp edits via cl-mcp

Every `.lisp` file change in this plan MUST use cl-mcp tools:
- Read Lisp: `lisp-read-file`
- Edit form: `lisp-edit-form` (replace/insert_before/insert_after)
- Patch sub-form text: `lisp-patch-form`
- Evaluate: `repl-eval`
- Load system: `load-system`

Never use the built-in `Read`, `Edit`, or `Write` tools on `.lisp` files.

**First step of every session:** call `fs-set-project-root` with `{"path": "."}`.

---

## Notebook page exception

`notebook.lisp` has a sidebar+main layout (`<div class="layout"><sidebar/><main>...</main></div>`). `page-shell` wraps body-content in `<main>`, which would create invalid nested `<main>` elements. Therefore notebook.lisp will call `(header user)` directly instead of page-shell, removing the user-banner completely. This still achieves the unified header goal.

---

### Task 1: Extend `page-shell` in layout.lisp

**File:** `web/ui/layout.lisp`

**Step 1: Read the current `page-shell` form**

```
lisp-read-file path="web/ui/layout.lisp" name_pattern="^page-shell$"
```

**Step 2: Replace `page-shell` with the extended version**

Use `lisp-edit-form` with `form_type="defun"` `form_name="page-shell"` `operation="replace"` and content:

```lisp
(defun page-shell (&key title styles user body-content head-extras body-scripts)
  "Generate a complete HTML page shell.

HEAD-EXTRAS is an optional HTML string injected at the end of <head>
(e.g. editor-head-tags for the CodeMirror setup).
BODY-SCRIPTS is an optional HTML string injected just before </body>
(e.g. a <script src=\"/static/js/learn.js\"> tag)."
  (spinneret:with-html-string
    (:doctype)
    (:html
     (:head (:meta :charset "utf-8")
      (:meta :name "viewport" :content "width=device-width, initial-scale=1")
      (:title title)
      (:script :src "https://unpkg.com/htmx.org@2.0.4" :integrity
       "sha384-HGfztofotfshcF7+8n44JQL2oJmowVChPTg48S+jvZoztPfvwD79OC/LTtG6dMp+"
       :crossorigin "anonymous")
      (:style (:raw (header-styles)))
      (when styles (:style (:raw styles)))
      (when head-extras (:raw head-extras)))
     (:body (:raw (header user)) (:main (:raw body-content))
      (when body-scripts (:raw body-scripts))))))
```

**Step 3: Verify via REPL**

```lisp
(load-system "recurya/web")
(repl-eval "(recurya/web/ui/layout:page-shell :title \"Test\" :user nil :body-content \"<p>hello</p>\")" :package "recurya/web/ui/layout")
```

Expected: HTML string containing `<header class="app-header">`, `<main>`, `<p>hello</p>`, and no body-scripts section.

**Step 4: Commit**

```bash
git add web/ui/layout.lisp
git commit -m "feat: extend page-shell with head-extras and body-scripts params"
```

---

### Task 2: Update anonymous header display

**File:** `web/ui/layout.lisp`

**Step 1: Read current header form (anonymous branch)**

```
lisp-read-file path="web/ui/layout.lisp" name_pattern="^header$"
```

Locate the `(t (:a :class "app-header__link" :href "/login" "Login"))` branch.

**Step 2: Patch the anonymous branch**

Use `lisp-patch-form` on form `header`:

```
old_text: (t
         (:a :class "app-header__link" :href "/login" "Login"))
new_text: (t
         (:span :class "app-header__auth-badge" "未ログイン")
         (:a :class "app-header__link" :href "/login" "ログイン"))
```

**Step 3: Add CSS for `.app-header__auth-badge`**

Use `lisp-patch-form` on `*header-styles*` to append the rule. Find the last CSS rule in the string (the `@media` block ends with `} }`) and patch:

```
old_text: @media (min-width:640px) { .app-header__label { display:inline; } }
new_text: @media (min-width:640px) { .app-header__label { display:inline; } }
.app-header__auth-badge { color:rgba(248,250,252,0.65); font-size:0.85rem; font-weight:500; margin-right:0.25rem; }
```

**Step 4: Verify**

```lisp
(repl-eval "(recurya/web/ui/layout:header nil)" :package "recurya/web/ui/layout")
```

Expected: HTML contains `未ログイン` and `ログイン`.

```lisp
(let ((user '(:id 1 :email "test@example.com" :name "Taro")))
  (repl-eval (format nil "(recurya/web/ui/layout:header '~S)" user)))
```

Expected: HTML contains `Taro` and the avatar dropdown.

**Step 5: Commit**

```bash
git add web/ui/layout.lisp
git commit -m "feat: show 未ログイン badge in header for anonymous users"
```

---

### Task 3: Migrate `notebooks-dashboard.lisp` to `page-shell`

**File:** `web/ui/notebooks-dashboard.lisp`

**Step 1: Read defpackage to check imports**

```
lisp-read-file path="web/ui/notebooks-dashboard.lisp" name_pattern="^defpackage"
```

**Step 2: Add `#:page-shell` to the `:import-from #:recurya/web/ui/layout` clause**

Use `lisp-patch-form` on the `defpackage` form. Find the import-from layout line and add `#:page-shell`:

```
old_text: (:import-from #:recurya/web/ui/layout
                #:header
                #:header-styles
                #:format-timestamp)
new_text: (:import-from #:recurya/web/ui/layout
                #:header
                #:header-styles
                #:page-shell
                #:format-timestamp)
```

(Adjust if the actual import list differs — read it first.)

**Step 3: Rewrite `render` to use `page-shell`**

Read the full render form, then replace it with a version that:
- Drops `header-styles` from `all-styles` (page-shell adds it)
- Calls `page-shell` instead of building the full `(:doctype)` shell
- Passes the inner `(:div :class "card" ...)` + `(:div :id "modal-container")` as `body-content`

```lisp
(defun render (&key user notebooks pagination message errors)
  "Render the admin notebook list page as an HTML string.

NOTEBOOKS is a list of plists with :id :title :slug :status
:published-at :created-at."
  (let ((user-timezone (getf user :timezone))
        (user-handle (getf user :handle))
        (styles (concatenate 'string (common-styles) *page-styles*)))
    (page-shell
     :title "recurya - My Notebooks"
     :styles styles
     :user user
     :body-content
     (with-html-string
       (:div :class "card"
        (:h1 "My Notebooks")
        (:p :class "muted" "Manage your user-authored notebooks.")
        (:div :class "actions-bar"
         (:a :class "new-nb-btn" :href "/dashboard/notebooks/new"
          "+ New Notebook"))
        (:div :id "flash-area"
         (when message (:div :class "flash-message success" message))
         (when errors
           (:div :class "flash-message error"
            (dolist (err errors) (:p err)))))
        (if notebooks
            (progn
             (:table
              (:thead
               (:tr (:th "Title") (:th "Status") (:th "Published")
                (:th "Created") (:th "Actions")))
              (:tbody :id "notebooks-body"
               (dolist (nb notebooks)
                 (let* ((id (getf nb :id))
                        (slug (getf nb :slug))
                        (title (getf nb :title))
                        (status (getf nb :status))
                        (visibility (or (getf nb :visibility) "private"))
                        (published-at (getf nb :published-at))
                        (created-at (getf nb :created-at)))
                   (:tr :id (format nil "nb-row-~A" id)
                    (:td
                     (if (and slug user-handle (string= status "published"))
                         (:a :href (format nil "/@~A/~A" user-handle slug)
                          title)
                         title))
                    (:td
                     (:raw
                      (render-notebook-state-dropdown id status visibility)))
                    (:td
                     (if published-at
                         (or (format-timestamp published-at user-timezone)
                             "—")
                         "—"))
                    (:td
                     (or (format-timestamp created-at user-timezone) "—"))
                    (:td
                     (:div :class "actions-cell"
                      (:a :class "link" :href
                       (format nil "/dashboard/notebooks/~A/edit" id) "Edit")
                      (:button :class "button-danger btn-sm" :hx-get
                       (format nil "/dashboard/notebooks/~A/confirm-delete"
                               id)
                       :hx-target "#modal-container" :hx-swap "innerHTML"
                       "Delete"))))))))
             (when pagination
               (let ((current-page (getf pagination :current-page))
                     (total-pages (getf pagination :total-pages))
                     (has-prev (getf pagination :has-prev))
                     (has-next (getf pagination :has-next))
                     (prev-url (getf pagination :prev-url))
                     (next-url (getf pagination :next-url)))
                 (:div :class "pagination"
                  (:span :class "pagination-info"
                   (format nil "Page ~A of ~A" current-page total-pages))
                  (:nav :class "pagination-nav"
                   (if has-prev
                       (:a :class "pagination-btn" :href prev-url
                        "← Previous")
                       (:span :class "pagination-btn disabled" "← Previous"))
                   (if has-next
                       (:a :class "pagination-btn" :href next-url "Next →")
                       (:span :class "pagination-btn disabled"
                        "Next →")))))))
            (:p :class "muted" "No notebooks yet. Create your first one!")))
       (:div :id "modal-container")))))
```

**Step 4: Verify**

```lisp
(load-system "recurya/web/ui/notebooks-dashboard")
(repl-eval
 "(recurya/web/ui/notebooks-dashboard:render :user '(:id 1 :email \"a@b.com\" :name \"Test\" :timezone \"UTC\") :notebooks nil)"
 :package "recurya/web/ui/notebooks-dashboard")
```

Expected: Full HTML string containing `<header class="app-header">`, `Test` in avatar area, and `My Notebooks`.

**Step 5: Commit**

```bash
git add web/ui/notebooks-dashboard.lisp
git commit -m "feat: migrate notebooks-dashboard to page-shell"
```

---

### Task 4: Migrate `courses.lisp` (dashboard) to `page-shell`

**File:** `web/ui/courses.lisp`

Same pattern as Task 3.

**Step 1: Read defpackage, add `#:page-shell` to layout imports**

**Step 2: Rewrite `render` — replace all-styles with `(concatenate 'string (common-styles) *page-styles*)` and wrap inner content with `page-shell`**

The inner body-content is the `(:div :class "card" ...)` + `(:div :id "modal-container")` block — same structure as Task 3 but for courses.

**Step 3: Verify**

```lisp
(load-system "recurya/web/ui/courses")
(repl-eval
 "(recurya/web/ui/courses:render :user '(:id 1 :name \"Test\") :courses nil)"
 :package "recurya/web/ui/courses")
```

Expected: HTML with header and "My Courses".

**Step 4: Commit**

```bash
git add web/ui/courses.lisp
git commit -m "feat: migrate courses dashboard to page-shell"
```

---

### Task 5: Migrate `account.lisp` to `page-shell`

**File:** `web/ui/account.lisp`

**Step 1: Read defpackage, add `#:page-shell` to layout imports**

**Step 2: Rewrite `render`**

Replace `all-styles` with `(concatenate 'string (common-styles) *account-styles*)` and wrap the two `(:div :class "card" ...)` blocks as body-content:

```lisp
(page-shell
 :title "Account settings - recurya"
 :styles (concatenate 'string (common-styles) *account-styles*)
 :user user
 :body-content
 (with-html-string
   (:div :class "card" ...) ;; settings form
   (:div :class "card" ...) ;; danger zone
   (:div :id "modal-container")))
```

**Step 3: Verify + Commit**

```lisp
(load-system "recurya/web/ui/account")
(repl-eval
 "(recurya/web/ui/account:render :user '(:id 1 :name \"T\" :email \"t@t.com\" :language \"en\" :timezone \"UTC\"))"
 :package "recurya/web/ui/account")
```

```bash
git add web/ui/account.lisp
git commit -m "feat: migrate account page to page-shell"
```

---

### Task 6: Migrate `course-form.lisp` to `page-shell`

**File:** `web/ui/course-form.lisp`

Note: This page currently LACKS the HTMX script, but the course-notebooks widget uses HTMX. Migrating to `page-shell` fixes this automatically.

**Step 1: Read defpackage, add `#:page-shell` to layout imports**

**Step 2: Rewrite `render`**

Remove the HTMX script from head (page-shell adds it). Replace `all-styles` with `(concatenate 'string (common-styles) *form-page-styles*)`. Pass the `(:div :class "card" ...)` as body-content:

```lisp
(page-shell
 :title (format nil "recurya - ~A" page-title)
 :styles (concatenate 'string (common-styles) *form-page-styles*)
 :user user
 :body-content
 (with-html-string
   (:div :class "card"
    (:h1 page-title)
    ... ;; form content verbatim
    )))
```

**Step 3: Verify + Commit**

```lisp
(load-system "recurya/web/ui/course-form")
(repl-eval
 "(recurya/web/ui/course-form:render :user '(:id 1 :name \"T\") :course nil)"
 :package "recurya/web/ui/course-form")
```

Confirm HTML contains HTMX script and `<header class="app-header">`.

```bash
git add web/ui/course-form.lisp
git commit -m "feat: migrate course-form to page-shell, add missing HTMX script"
```

---

### Task 7: Migrate `notebook-form.lisp` to `page-shell`

**File:** `web/ui/notebook-form.lisp`

Same pattern as Task 6.

**Step 1: Read defpackage, add `#:page-shell`**

**Step 2: Rewrite `render`**

```lisp
(page-shell
 :title (format nil "recurya - ~A" page-title)
 :styles (concatenate 'string (common-styles) *form-page-styles*)
 :user user
 :body-content
 (with-html-string
   (:div :class "card"
    (:h1 page-title)
    ... ;; form + cheatsheet
    )))
```

**Step 3: Verify + Commit**

```lisp
(load-system "recurya/web/ui/notebook-form")
(repl-eval
 "(recurya/web/ui/notebook-form:render :user '(:id 1 :name \"T\") :notebook nil)"
 :package "recurya/web/ui/notebook-form")
```

```bash
git add web/ui/notebook-form.lisp
git commit -m "feat: migrate notebook-form to page-shell, add missing HTMX script"
```

---

### Task 8: Add `user` param to `notebook-list.lisp`; use `page-shell`

**Files:** `web/ui/notebook-list.lisp`, `web/routes.lisp`

**Step 1: Read defpackage of notebook-list.lisp**

Add to `:import-from #:recurya/web/ui/layout`:
```
#:header-styles
#:page-shell
```

(notebook-list currently has no layout imports — add a new `:import-from` clause.)

**Step 2: Rewrite `render` to accept `user` and use `page-shell`**

```lisp
(defun render (&key user notebooks pagination)
  "Render the public notebook listing page (published only).
USER is the current session plist or nil."
  (page-shell
   :title "Notebooks"
   :styles *styles*
   :user user
   :body-content
   (with-html-string
     (:div :class "list-header"
      (:h1 "Notebooks")
      (:p "Community-authored Lisp notebooks."))
     (if notebooks
         (progn
          (dolist (nb notebooks)
            (let* ((slug (getf nb :slug))
                   (title (getf nb :title))
                   (summary (getf nb :summary))
                   (published-at (getf nb :published-at))
                   (author-name (getf nb :author-name))
                   (author-handle (getf nb :author-handle))
                   (detail-url
                    (when author-handle
                      (format nil "/@~A/~A" author-handle slug))))
              (:div :class "nb-card"
               (:h2 :class "nb-card__title"
                (if detail-url
                    (:a :href detail-url title)
                    (:span title)))
               (:div :class "nb-card__meta"
                (when author-handle
                  (:a :href (format nil "/@~A" author-handle) :class
                   "nb-card__handle" (format nil "@~A" author-handle))
                  (:span " · "))
                (format nil "~@[~A~]~@[ · ~A~]" author-name
                        (format-timestamp published-at)))
               (when (and summary (string/= summary ""))
                 (:p :class "nb-card__summary" summary))
               (when detail-url
                 (:a :class "nb-card__open" :href detail-url "Open →")))))
          (when pagination
            (let ((current-page (getf pagination :current-page))
                  (total-pages (getf pagination :total-pages))
                  (has-prev (getf pagination :has-prev))
                  (has-next (getf pagination :has-next))
                  (prev-url (getf pagination :prev-url))
                  (next-url (getf pagination :next-url)))
              (:div :class "pagination"
               (:span :class "pagination-info"
                (format nil "Page ~A of ~A" current-page total-pages))
               (:nav :class "pagination-nav"
                (if has-prev
                    (:a :class "pagination-btn" :href prev-url "← Previous")
                    (:span :class "pagination-btn disabled" "← Previous"))
                (if has-next
                    (:a :class "pagination-btn" :href next-url "Next →")
                    (:span :class "pagination-btn disabled" "Next →")))))))
         (:p :class "empty" "No notebooks yet. Check back soon!")))))
```

**Step 3: Update `notebooks-public-handler` in `web/routes.lisp`**

Read the handler:
```
lisp-read-file path="web/routes.lisp" name_pattern="^notebooks-public-handler$"
```

Patch to add `get-current-user` call and pass `user` to render:

```
old_text: (html-response
             (notebook-list:render :notebooks notebooks :pagination pagination))
new_text: (let ((user (get-current-user)))
             (html-response
              (notebook-list:render :user user :notebooks notebooks :pagination pagination)))
```

**Step 4: Verify + Commit**

```lisp
(load-system "recurya/web")
(repl-eval "(recurya/web/ui/notebook-list:render :user nil :notebooks nil)" :package "recurya/web/ui/notebook-list")
```

Expected: HTML with `未ログイン` in header.

```bash
git add web/ui/notebook-list.lisp web/routes.lisp
git commit -m "feat: add global header to public notebook listing"
```

---

### Task 9: Add `user` param to `course-list.lisp`; use `page-shell`

**Files:** `web/ui/course-list.lisp`, `web/routes.lisp`

Same pattern as Task 8 but for courses.

**Step 1: Add layout imports to defpackage**

**Step 2: Rewrite `render` to accept `user` and call `page-shell`**

Key difference from notebook-list: course cards show notebook count + author handle. The inner content is the `.list-header` + course cards + pagination, mirroring the current body without the `(:main ...)` wrapper.

**Step 3: Update `courses-public-handler` in `web/routes.lisp`**

```
lisp-read-file path="web/routes.lisp" name_pattern="^courses-public-handler$"
```

Patch to add `get-current-user` and pass to render:

```
old_text: (html-response
             (course-list:render :courses courses :pagination pagination))
new_text: (let ((user (get-current-user)))
             (html-response
              (course-list:render :user user :courses courses :pagination pagination)))
```

**Step 4: Verify + Commit**

```lisp
(load-system "recurya/web")
(repl-eval "(recurya/web/ui/course-list:render :user nil :courses nil)" :package "recurya/web/ui/course-list")
```

```bash
git add web/ui/course-list.lisp web/routes.lisp
git commit -m "feat: add global header to public course listing"
```

---

### Task 10: Add `user` param to `profile.lisp`; use `page-shell`

**Files:** `web/ui/profile.lisp`, `web/routes.lisp`

**Step 1: Add layout imports to defpackage**

Add `:import-from #:recurya/web/ui/layout #:page-shell #:header-styles`.

**Step 2: Rewrite `render-profile-page` to accept `user`**

```lisp
(defun render-profile-page (&key user handle display-name notebooks courses)
  "Render the public profile page for HANDLE.
USER is the current session plist or nil."
  (page-shell
   :title (format nil "@~A" handle)
   :styles *styles*
   :user user
   :body-content
   (with-html-string
     (:div :class "profile-header"
      (:h1 (or display-name handle))
      (:div :class "handle" (format nil "@~A" handle))
      (when (and display-name (not (string= display-name handle)))
        (:div :class "display-name" "")))
     (:section :class "section"
      (:h2 "Notebooks")
      (cond ((null notebooks) (:p :class "empty" "No public notebooks yet."))
            (t (dolist (nb notebooks) ...))))
     (:section :class "section"
      (:h2 "Courses")
      (cond ((null courses) (:p :class "empty" "No public courses yet."))
            (t (dolist (c courses) ...)))))))
```

(Preserve existing dolist bodies verbatim.)

**Step 3: Update `profile-handler` in `web/routes.lisp`**

```
lisp-read-file path="web/routes.lisp" name_pattern="^profile-handler$"
```

Patch to pass `user`:

```
old_text: (html-response
             (profile:render-profile-page :handle handle ...))
new_text: (let ((user (get-current-user)))
             (html-response
              (profile:render-profile-page :user user :handle handle ...)))
```

**Step 4: Verify + Commit**

```lisp
(load-system "recurya/web")
(repl-eval "(recurya/web/ui/profile:render-profile-page :user nil :handle \"alice\" :display-name \"Alice\" :notebooks nil :courses nil)" :package "recurya/web/ui/profile")
```

```bash
git add web/ui/profile.lisp web/routes.lisp
git commit -m "feat: add global header to public profile page"
```

---

### Task 11: Migrate `course.lisp` (public detail) to `page-shell`

**Files:** `web/ui/course.lisp`, `web/routes.lisp`

**Step 1: Add layout imports to defpackage**

Add `:import-from #:recurya/web/ui/layout #:page-shell #:header-styles`.

**Step 2: Rewrite `render` — remove `(declare (ignore user))`, use `page-shell`**

```lisp
(defun render (&key course notebooks user passed-by-notebook)
  "Render the public course detail page.
USER is the current session plist or nil."
  (let* ((title (getf course :title))
         (summary (getf course :summary))
         (status (getf course :status))
         (draft-p (string= status "draft")))
    (page-shell
     :title (or title "Course")
     :styles *styles*
     :user user
     :body-content
     (with-html-string
       (when draft-p
         (:div :class "draft-banner"
          "Draft preview — only visible to the course owner."))
       (:div :class "course-header"
        (:h1 (or title "Untitled course"))
        (when (and summary (string/= summary ""))
          (:p :class "summary" summary)))
       (cond
        ((null notebooks)
         (:p :class "empty" "No notebooks attached to this course yet."))
        (t
         (dolist (nb notebooks)
           ... ;; notebook card body verbatim
           )))))))
```

**Step 3: Update `public-course-by-handle-handler` in `web/routes.lisp`**

```
lisp-read-file path="web/routes.lisp" name_pattern="^%render-public-course-response$"
```

This helper already receives `user` via session — verify it passes it to `course:render`. If `(declare (ignore user))` existed there too, remove it.

**Step 4: Verify + Commit**

```lisp
(load-system "recurya/web")
(repl-eval
 "(recurya/web/ui/course:render :user nil :course '(:title \"SICP\" :status \"published\") :notebooks nil :passed-by-notebook nil)"
 :package "recurya/web/ui/course")
```

```bash
git add web/ui/course.lisp web/routes.lisp
git commit -m "feat: add global header to public course detail page"
```

---

### Task 12: Replace user-banner in `notebook.lisp` with global header

**File:** `web/ui/notebook.lisp`

This page uses a sidebar + nested `<main>`, so it cannot use `page-shell`. Instead it calls `header` directly and removes the user-banner.

**Step 1: Read defpackage, add `#:header` and `#:header-styles` to layout imports**

```
lisp-read-file path="web/ui/notebook.lisp" name_pattern="^defpackage"
```

Add `:import-from #:recurya/web/ui/layout #:header #:header-styles` (may already be present — check first).

**Step 2: Remove user-banner CSS from `*styles*`**

Use `lisp-patch-form` on `*styles*` to remove:

```
old_text: .user-banner { background: #1e293b; padding: 0.5rem 1rem; border-radius: 6px;
               margin-bottom: 1rem; font-size: 0.85rem; color: #94a3b8; }
.user-banner.anon { background: #1e2530; }
.user-banner a { color: #38bdf8; text-decoration: none; margin-left: 0.5rem; }
.user-banner strong { color: #f8fafc; }
new_text: (empty string — delete those rules)
```

Also add header-styles to the page. Use `lisp-patch-form` on the `render` function to inject `(header-styles)` in the `<head>` styles. Find `(:style (:raw *styles*))` and change to:

```
old_text: (:title (notebook-title notebook)) (:style (:raw *styles*))
new_text: (:title (notebook-title notebook))
         (:style (:raw (header-styles)))
         (:style (:raw *styles*))
```

**Step 3: Replace user-banner markup with `(header user)` call**

In the `render` function, find the body form. Currently:

```lisp
(:body :data-notebook-id (notebook-url-id notebook) :data-logged-in ...
 (:raw (or (csrf-form-block) ""))
 (:div :class "layout"
  ...sidebar...
  (:main
   (cond (*user* (:div :class "user-banner" ...))
         (t (:div :class "user-banner anon" ...)))
   (cond (breadcrumb ...) (t nil))
   ...rest of content...)))
```

Use `lisp-patch-form` to:
1. Add `(:raw (header *user*))` immediately after `(:raw (or (csrf-form-block) ""))` and before `(:div :class "layout" ...)`
2. Remove the two `(:div :class "user-banner" ...)` cond branches from inside `(:main ...)`

```
old_text: (:raw (or (csrf-form-block) ""))
         (:div :class "layout"
          (cond ((null sidebar-notebooks) nil)
                ((listp sidebar-notebooks)
                 (render-course-sidebar ...)))
          (:main
           (cond
            (*user*
             (:div :class "user-banner" "ログイン中: "
              (:strong (or (getf *user* :name) "User")) " · "
              (:form :method "post" :action "/logout" :style "display:inline;"
               (:raw (or (csrf-input) ""))
               (:button :type "submit" :class "user-banner__logout" :style
                "background:none;border:none;color:#38bdf8;cursor:pointer;padding:0;font:inherit;"
                "ログアウト"))))
            (t
             (:div :class "user-banner anon" "進捗を端末を超えて保存するには "
              (:a :href "/login" "ログイン") " してください。")))
           (cond

new_text: (:raw (or (csrf-form-block) ""))
         (:raw (header *user*))
         (:div :class "layout"
          (cond ((null sidebar-notebooks) nil)
                ((listp sidebar-notebooks)
                 (render-course-sidebar ...)))
          (:main
           (cond
```

(Use `dry_run: true` first to verify the patch matches before applying.)

**Step 4: Verify**

```lisp
(load-system "recurya/web/ui/notebook")
```

Confirm no compile warnings.

```lisp
;; Create a minimal notebook struct to test rendering
(repl-eval
 "(let* ((nb (make-instance 'recurya/game/notebook:notebook :id \"test\" :title \"Test\" :summary \"\" :cells nil)))
    (let ((html (recurya/web/ui/notebook:render nb :user nil)))
      (search \"app-header\" html)))"
 :package "recurya/web/ui/notebook")
```

Expected: returns a non-nil position (header class found in output).

Also confirm no `user-banner` in output:
```lisp
(repl-eval
 "(let* ((nb (make-instance 'recurya/game/notebook:notebook :id \"test\" :title \"Test\" :summary \"\" :cells nil)))
    (let ((html (recurya/web/ui/notebook:render nb :user nil)))
      (search \"user-banner\" html)))"
 :package "recurya/web/ui/notebook")
```

Expected: `NIL`.

**Step 5: Commit**

```bash
git add web/ui/notebook.lisp
git commit -m "feat: replace notebook user-banner with global header"
```

---

### Task 13: Load and smoke-test full system

**Step 1: Load the full system**

```lisp
(load-system "recurya/web" :force t)
```

Fix any package/import errors before continuing.

**Step 2: Run existing tests**

```lisp
(run-tests :system "recurya/tests")
```

Expected: all tests pass (web tests require PostgreSQL on port 15434).

**Step 3: Manual browser verification**

Start the server and verify these pages all show the global header:

| URL | Expected header state |
|-----|----------------------|
| `/notebooks` | 未ログイン + ログイン link |
| `/courses` | 未ログイン + ログイン link |
| `/@recurya` (or any handle) | 未ログイン + ログイン link |
| `/c/@recurya/sicp` | 未ログイン + ログイン link |
| `/@recurya/sicp-ch1` | 未ログイン + ログイン link |
| `/dashboard/notebooks` | Avatar dropdown (requires login) |
| `/dashboard/courses` | Avatar dropdown |
| `/account` | Avatar dropdown |

**Step 4: Final commit**

```bash
git add -u
git commit -m "chore: verify global nav unification complete"
```
