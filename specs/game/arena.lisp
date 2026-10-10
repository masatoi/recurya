;;;; specs/game/arena.lisp --- cl-spec contracts for the arena engine.
;;;;
;;;; Function specs for action parsing and movement, and properties of the
;;;; grid helpers.  Expected behaviour comes from the docstrings of
;;;; recurya/game/arena.  Internal helpers are imported, not reached with ::.

(defpackage #:recurya/specs/game/arena
  (:use #:cl)
  (:import-from #:cl-spec/main
                #:defspec
                #:defspec-function
                #:defproperty
                #:defgenerator)
  (:import-from #:cl-spec/src/backends/check-it)
  (:import-from #:alexandria
                #:copy-array)
  (:import-from #:recurya/specs/domain
                #:arena-action
                #:grid-position)
  (:import-from #:recurya/game/arena
                #:make-grid
                #:grid-set!
                ;; Internal helpers under contract.
                #:parse-action
                #:action->delta
                #:apply-move
                #:manhattan-distance
                #:copy-grid))
(in-package #:recurya/specs/game/arena)

;;; Helpers

(defparameter *action-names* '("up" "down" "left" "right" "wait" "pickup")
  "The action names parse-action must accept, from its requirement: WardLisp
symbols arrive as strings naming the six arena actions.  Independent of the
engine's own *VALID-ACTION-STRINGS*.")

(defparameter *expected-deltas*
  '((:up . (-1 . 0)) (:down . (1 . 0)) (:left . (0 . -1)) (:right . (0 . 1)))
  "Expected (DROW . DCOL) per movement action.  Arena convention: row grows
downward and column grows rightward, so :UP decreases the row.")

(defun random-element (sequence)
  "Return a uniformly chosen element of the non-empty SEQUENCE."
  (elt sequence (random (length sequence))))

(defun random-mixed-case (string)
  "Return STRING with each character's case chosen at random."
  (map 'string
       (lambda (char)
         (if (zerop (random 2)) (char-upcase char) (char-downcase char)))
       string))

(defun valid-action-name-p (value)
  "True when VALUE is a string naming an action, ignoring case."
  (and (stringp value)
       (find value *action-names* :test #'string-equal)
       t))

(defun random-arena-grid ()
  "A fresh grid of 1..6 x 1..6 cells: about 30% walls, 20% resources."
  (let* ((rows (1+ (random 6)))
         (cols (1+ (random 6)))
         (grid (make-grid rows cols)))
    (dotimes (row rows grid)
      (dotimes (col cols)
        (let ((roll (random 10)))
          (cond ((< roll 3) (grid-set! grid row col :wall))
                ((< roll 5) (grid-set! grid row col :resource))))))))

(defun oracle-blocked-cell-p (grid row col)
  "True when (ROW, COL) cannot be entered per APPLY-MOVE's docstring: it is
off the board or a :WALL.  Independent of the engine's WALL-P/IN-BOUNDS-P."
  (or (not (array-in-bounds-p grid row col))
      (eq (aref grid row col) :wall)))

(defun open-positions (grid)
  "Every in-bounds, non-wall (ROW . COL) of GRID."
  (let ((positions '()))
    (dotimes (row (array-dimension grid 0) positions)
      (dotimes (col (array-dimension grid 1))
        (unless (oracle-blocked-cell-p grid row col)
          (push (cons row col) positions))))))

(defun step-target (pos action)
  "The (ROW . COL) one ACTION step from POS per *EXPECTED-DELTAS*, or NIL for
a non-movement action.  Independent of ACTION->DELTA."
  (let ((delta (cdr (assoc action *expected-deltas*))))
    (and delta
         (cons (+ (car pos) (car delta)) (+ (cdr pos) (cdr delta))))))

(defun blocked-p (grid pos action)
  "True when ACTION from POS moves nowhere: a non-movement action, or a step
into a wall or off the board (APPLY-MOVE's docstring)."
  (let ((target (step-target pos action)))
    (or (null target)
        (oracle-blocked-cell-p grid (car target) (cdr target)))))

;;; Generators

(defgenerator action-input ()
  "A value WardLisp could hand PARSE-ACTION: action names in any case (about
40%), near-miss strings, and non-strings."
  (case (random 5)
    ((0 1) (random-mixed-case (random-element *action-names*)))
    (2 (random-element '("" "jump" "UPP" "wai" " up" "pick-up")))
    (3 (random-element '(nil 0 42 :up up)))
    (t (random-element '(#\u 1.5 ("up"))))))

(defspec action-input t (:generator action-input))

(defgenerator arena-grid ()
  "A fresh random grid per draw."
  (random-arena-grid))

(defspec arena-grid (satisfies arrayp) (:generator arena-grid))

(defgenerator apply-move-arguments ()
  "(GRID POS ACTION) with a fresh grid and POS on one of its open cells."
  (loop
    (let* ((grid (random-arena-grid))
           (open (open-positions grid)))
      (when open
        (return (list grid
                      (random-element open)
                      (random-element '(:up :down :left :right :wait :pickup))))))))

;;; Function specs

(defspec-function parse-action
  "A string naming an action (any case) becomes that action's keyword;
anything else becomes :WAIT."
  (:args (value action-input))
  (:cases
    (:action-name
      (:when (valid-action-name-p value))
      (:returns arena-action)
      (:post (string-equal (symbol-name result) value)))
    (:anything-else
      (:when (not (valid-action-name-p value)))
      (:returns (member :wait)))))

(defspec-function action->delta
  "Movement actions map to a one-cell step (DROW . DCOL); others to NIL."
  (:args (action arena-action))
  (:cases
    (:movement
      (:when (member action '(:up :down :left :right)))
      (:returns (satisfies consp))
      (:post (equal result (cdr (assoc action *expected-deltas*)))))
    (:non-movement
      (:when (member action '(:wait :pickup)))
      (:returns null))))

(defspec-function apply-move
  "From an open cell, a move lands on the open in-bounds cell one step away;
a blocked move or a non-movement action leaves the position unchanged."
  (:args (grid arena-grid) (pos grid-position) (action arena-action))
  (:args-generator apply-move-arguments)
  (:pre (not (oracle-blocked-cell-p grid (car pos) (cdr pos))))
  (:cases
    (:moves
      (:when (not (blocked-p grid pos action)))
      (:returns grid-position)
      (:post (and (equal result (step-target pos action))
                  (not (oracle-blocked-cell-p grid (car result) (cdr result))))))
    (:stays
      (:when (blocked-p grid pos action))
      (:returns grid-position)
      (:post (equal result pos)))))

;;; Properties

(defproperty manhattan-distance-metric
    ((a grid-position) (b grid-position) (c grid-position))
  "Manhattan distance is a metric: non-negative, zero on the diagonal,
symmetric, and obeys the triangle inequality."
  (:about manhattan-distance)
  (:kind :invariant)
  (:trials (:smoke 50 :normal 300))
  (and (= (manhattan-distance a b)
          (+ (abs (- (car a) (car b))) (abs (- (cdr a) (cdr b)))))
       (>= (manhattan-distance a b) 0)
       (zerop (manhattan-distance a a))
       (= (manhattan-distance a b) (manhattan-distance b a))
       (<= (manhattan-distance a c)
           (+ (manhattan-distance a b) (manhattan-distance b c)))))

(defproperty copy-grid-independent ((grid arena-grid))
  "A copy starts equal to its source, and writing every cell of the copy
leaves the source untouched."
  (:about copy-grid)
  (:kind :invariant)
  (:trials (:smoke 30 :normal 200))
  (let ((snapshot (copy-array grid))
        (copy (copy-grid grid)))
    (and (equalp copy grid)
         (progn
           (dotimes (row (array-dimension copy 0))
             (dotimes (col (array-dimension copy 1))
               (grid-set! copy row col :copy-sentinel)))
           (equalp grid snapshot)))))
