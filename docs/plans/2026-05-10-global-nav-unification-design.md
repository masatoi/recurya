# Global Navigation Unification Design

**Date:** 2026-05-10  
**Status:** Approved

## Goal

Add a consistent global navigation bar to the top of all pages. Login state (logged in / not logged in) is displayed in the top right. Currently, only dashboard pages use the shared `header` function; public pages and the notebook reading page lack it, creating an inconsistent experience.

## Approach: `page-shell` Unification

All pages (except `/login` and `/onboarding/*`) will be rendered through the existing `page-shell` function in `web/ui/layout.lisp`. This eliminates duplicated HTML boilerplate across render functions.

## Changes

### 1. Extend `page-shell`

Add three optional keyword parameters to accommodate pages with special needs:

```
page-shell
  &key title styles user body-content
       head-extras    ;; additional <head> content string (e.g. editor-head-tags)
       body-attrs     ;; plist of extra <body> attributes (e.g. :data-notebook-id "foo")
       body-scripts   ;; HTML string appended before </body> (e.g. learn.js <script>)
```

### 2. Header: Anonymous State Display

Change the anonymous (not logged in) branch in `header` from a bare "Login" link to:

- `"未ログイン"` label (styled badge)
- `"ログイン"` link to `/login`

### 3. Pages to Migrate

| Route | Render function | Changes |
|-------|----------------|---------|
| `/notebooks` | `notebook-list:render` | Add `user` param; use `page-shell` |
| `/@:handle` | `profile:render-profile-page` | Add `user` param; use `page-shell` |
| `/c/@:handle/:slug` | `course:render` | Remove `(declare (ignore user))`; use `page-shell` |
| `/@:handle/:slug` | `notebook:render` | Remove user-banner; use `page-shell` with `head-extras`, `body-attrs`, `body-scripts` |
| `/dashboard/notebooks` | `notebooks-dashboard:render` | Replace direct `header` call with `page-shell` |
| `/dashboard/courses` | `courses:render` | Replace direct `header` call with `page-shell` |
| Other dashboard pages | (account, course-form, etc.) | Audit and migrate as needed |

**Excluded:** `/login`, `/onboarding/*`

### 4. Route Handler Changes

Public page handlers that currently omit session lookup must call `get-current-user` and pass the result to their render function:

- `notebooks-public-handler`
- `profile-handler`
- `public-course-by-handle-handler`
- `%render-public-notebook-response` (used by `public-notebook-by-handle-handler`)

### 5. notebook.lisp Layout

The notebook reading page has a sidebar + main layout. After migration:

- The `user-banner` div is removed entirely
- `page-shell` emits the global `<header>` at the top
- The `.layout` div (sidebar + main) is passed as `body-content`
- `editor-head-tags` output passed via `head-extras`
- `data-notebook-id` / `data-logged-in` passed via `body-attrs`
- `learn.js` `<script>` passed via `body-scripts`

## Constraints

- Public pages remain accessible without login; `user` is simply `nil` when anonymous
- No changes to authentication logic or middleware
- Login and onboarding pages keep their current standalone shells
- HTMX fragments (partial responses) are not affected — they do not use `page-shell`
