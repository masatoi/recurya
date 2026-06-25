;;;; scripts/seed-official-content.lisp --- Manual one-shot runner for the
;;;; official-content seeder. Auto-seed normally runs at boot via
;;;; docker-entrypoint.sh; use this for ad-hoc / CI runs.
;;;;
;;;; Usage (from project root, DB reachable):
;;;;   $ qlot exec ros run \
;;;;       -e '(asdf:load-system :recurya)' \
;;;;       -e '(load "scripts/seed-official-content.lisp")' \
;;;;       -q
;;;;
;;;; or from a connected REPL:
;;;;   (load "scripts/seed-official-content.lisp")

(asdf:load-system :recurya)
(unless (recurya/db/core:datasource)
  (recurya/db/core:start!))
(format t "~&~S~%" (recurya/seed/official-content:seed-official-content!))
