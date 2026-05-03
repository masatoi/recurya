# Archived one-time migration scripts

These scripts were used during the courses + SICP migration (branch
`feat/courses-and-sicp-migration`, commits `8d848a2` and `cec869e`):

| Script | Purpose | Run when |
|--------|---------|----------|
| `sicp-to-markdown.lisp` | Walked the in-memory `recurya/game/notebooks/registry` (now deleted) and exported each SICP notebook to `docs/sicp/<slug>.md` using the `===prose===` / `===eval===` / `===exercise===` / `===expect===` fence syntax. | Once, to seed the markdown fixtures committed under `docs/sicp/`. |
| `inject-sicp-solutions.lisp` | Re-read `tests/game/notebooks/sicp-*.lisp` (now deleted) to extract canonical answer code and spliced `===solution: ...===` cells into the corresponding `docs/sicp/<slug>.md`. | Once, after running the markdown export. |
| `import-sicp-to-db.lisp` | Read `docs/sicp/*.md`, created `user_notebook` rows under a `course "sicp"`, and migrated existing `learn_*.notebook_id` rows from the legacy slug-string to the new UUID. Idempotent. | Once per environment (dev / staging / production) at deploy time. |

These scripts depend on packages that no longer exist (`recurya/game/notebooks/registry`,
`recurya/game/notebooks/sicp-*`). They will fail to load against the current
codebase and are kept here as historical reference, not for re-execution.

If you need to re-bootstrap a fresh database from `docs/sicp/*.md`, the
DB-backed integration test `tests/integration/sicp-canonical-solutions.lisp`
contains a `load-sicp-fixtures!` helper that writes the same data using
only currently-live packages.
