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

(defun lesson-cells ()
  "Parse the seeded lesson markdown into notebook cells."
  (recurya/game/notebook-parser:parse-notebook-body
   (uiop:read-file-string
    (asdf:system-relative-pathname :recurya "docs/novel-lessons/recursion.md"))))

(deftest lesson-content-structure
  "The lesson markdown parses into 3 scenes, 1 exercise (3 tests), 1 solution."
  (multiple-value-bind (cells errors) (lesson-cells)
    (ok (null errors) "no parse errors")
    (flet ((kind (c) (recurya/game/notebook:cell-kind c)))
      (ok (= 3 (count :scene cells :key #'kind)) "3 scene cells")
      (ok (= 1 (count :code-exercise cells :key #'kind)) "1 exercise")
      (ok (= 1 (count :code-solution cells :key #'kind)) "1 solution")
      (let ((ex (find :code-exercise cells :key #'kind)))
        (ok (= 3 (length (recurya/game/notebook:cell-test-cases ex)))
            "exercise has 3 expectations")))))

(deftest lesson-scenes-teach-recursion
  "Scene 1 introduces 再帰 in Alice's voice; scene 3 sets the ready flag."
  (let* ((cells (lesson-cells))
         (scenes (remove-if-not
                  (lambda (c) (eq :scene (recurya/game/notebook:cell-kind c)))
                  cells))
         (eval-scene #'recurya/game/novel/eval:eval-scene)
         (interp #'recurya/game/novel/interpreter:interpret-directives)
         (body #'recurya/game/notebook:cell-body))
    (let ((beats1 (funcall interp (funcall eval-scene (funcall body (first scenes))
                                           :flags nil))))
      (ok (some (lambda (b) (and (search "アリス" (or (getf b :speaker) ""))
                                 (search "再帰" (or (getf b :text) ""))))
                beats1)
          "scene 1: Alice talks about 再帰"))
    (multiple-value-bind (beats3 set-flags)
        (funcall interp (funcall eval-scene (funcall body (third scenes)) :flags nil))
      (declare (ignore beats3))
      (ok (assoc :ready-for-exercise set-flags)
          "scene 3 sets the ready-for-exercise flag"))))

(deftest lesson-solution-passes-all-expectations
  "The model solution satisfies every expect; a wrong base case does not."
  (let* ((cells (lesson-cells))
         (solution (recurya/game/notebook:cell-body
                    (find :code-solution cells
                          :key #'recurya/game/notebook:cell-kind)))
         (exercise (find :code-exercise cells
                         :key #'recurya/game/notebook:cell-kind)))
    (dolist (tc (recurya/game/notebook:cell-test-cases exercise))
      (let* ((input (recurya/game/puzzle:test-case-input tc))
             (expected (recurya/game/puzzle:test-case-expected tc))
             (result (wardlisp:evaluate (format nil "~A~%~A" solution input))))
        (ok (string= expected (wardlisp:print-value result))
            (format nil "~A => ~A" input expected))))
    ;; ??? -> 0 (wrong base case) must not satisfy 5! = 120
    (let ((r (wardlisp:evaluate
              "(define (factorial n) (if (= n 0) 0 (* n (factorial (- n 1)))))
(factorial 5)")))
      (ok (not (string= "120" (wardlisp:print-value r)))
          "a wrong base case fails the expectation"))))

(deftest lesson-cells-render-without-crashing
  "Every lesson cell renders (3 scenes inline + exercise) without error.
Uses render-cell directly to avoid the CSRF/request-bound page shell."
  (let* ((cells (lesson-cells))
         (html (spinneret:with-html-string
                 (loop for c in cells for i from 0
                       do (recurya/web/ui/notebook::render-cell c i "lesson")))))
    (ok (search "novel-player" html) "scenes render as inline players")
    (ok (search "factorial" html) "exercise body present")
    (ok (search "アリス" html) "scene dialogue present")
    (ok (search "novel-bg-cell-1" html) "each scene is scoped to its cell index")))
