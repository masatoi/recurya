;;;; tests/integration/novel-recursion-lesson.lisp
;;;; Verifies the "Alice & factorial" novel recursion lesson: scoped player,
;;;; scene beats, and exercise correctness.
(defpackage #:recurya/tests/integration/novel-recursion-lesson
  (:use #:cl #:rove)
  (:import-from #:recurya/web/ui/novel #:render-player))

(in-package #:recurya/tests/integration/novel-recursion-lesson)

(deftest render-player-scoped-by-id
  "Multiple inline players coexist: element ids and JS are scoped per :id."
  (let ((a (render-player :id "a" :beats '((:type :narrate :text "AA" :bg ""))))
        (b (render-player :id "b" :beats '((:type :narrate :text "BB" :bg "")))))
    (ok (search "novel-bg-a" a) "player a scopes element ids to 'a'")
    (ok (search "novel-bg-b" b) "player b scopes element ids to 'b'")
    (ok (not (search "novel-bg-b" a)) "player a must not reference b's element ids")
    (ok (search "getElementById" a) "JS targets its own element by id")
    (ok (search "novel-player" a) "novel-player class preserved")
    (ok (search "AA" a) "beat text present")))

(deftest scene-cell-renders-inline-player
  "A :scene notebook cell renders as an inline, index-scoped novel player."
  (let* ((cell (recurya/game/notebook:make-cell
                :id "s1" :kind :scene
                :body "(list (list 'say \"アリス\" \"やあ\"))"))
         (html (spinneret:with-html-string
                 (recurya/web/ui/notebook::render-cell cell 0 "nb"))))
    (ok (search "novel-player" html) "scene renders as a player")
    (ok (search "やあ" html) "scene dialogue present")
    (ok (search "novel-bg-cell-0" html) "player scoped to the cell index")))
