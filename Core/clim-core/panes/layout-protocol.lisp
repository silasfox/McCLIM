;;; ---------------------------------------------------------------------------
;;;   License: LGPL-2.1+ (See file 'Copyright' for details).
;;; ---------------------------------------------------------------------------
;;;
;;;  (c) copyright 1998-2001 by Michael McDonald <mikemac@mikemac.com>
;;;  (c) copyright 2000 by Iban Hatchondo <hatchond@emi.u-bordeaux.fr>
;;;  (c) copyright 2000 by Julien Boninfante <boninfan@emi.u-bordeaux.fr>
;;;  (c) copyright 2001 by Lionel Salabartan <salabart@emi.u-bordeaux.fr>
;;;  (c) copyright 2001 by Arnaud Rouanet <rouanet@emi.u-bordeaux.fr>
;;;  (c) copyright 2001-2002, 2014 by Robert Strandh <robert.strandh@gmail.com>
;;;  (c) copyright 2002-2003 by Gilbert Baumann <unk6@rz.uni-karlsruhe.de>
;;;  (c) copyright 2020-2022 by Daniel Kochmański <daniel@turtleware.eu>
;;;
;;; ---------------------------------------------------------------------------
;;;
;;; Implementation of the 29.3 Composite and Layout Panes (layout protocol).
;;;

(in-package #:clim-internals)

;;; CLIM Layout Protocol for Dummies
;;;
;;; Here is how I interpret the relevant sections of the specification:
;;;
;;; COMPOSE-SPACE
;;;
;;;   This is called by CLIM, when it wants to find out what the pane
;;;   thinks are its space requirements. The result of COMPOSE-SPACE is
;;;   cached by CLIM.
;;;
;;; ALLOCATE-SPACE
;;;
;;;   This method is called by CLIM when a pane is allocate space. It
;;;   should layout its possible children.
;;;
;;; CHANGE-SPACE-REQUIREMENTS
;;;
;;;   This is called by the application programmer to a) indicate that
;;;   COMPOSE-SPACE may now return something different from previous
;;;   invocations and/or b) to update the user space requirements
;;;   options (the :width, :height etc keywords as upon pane creation).
;;;
;;; NOTE-SPACE-REQUIREMENTS-CHANGED
;;;
;;;   Called by CLIM when the space requirements of a pane have changed.
;;;
;;; LAYOUT-FRAME
;;;
;;;   May be called by both CLIM and the application programmer to "invoke the
;;;   space allocation protocol", that is CLIM calls ALLOCATE-SPACE on the top
;;;   level sheet. This in turn will probably call COMPOSE-SPACE on its
;;;   children and layout then accordingly by calling ALLOCATE-SPACE again.
;;;
;;;   The effect is that ALLOCATE-SPACE propagate down the sheet hierarchy.
;;;
;;; --GB 2003-08-06

(defconstant +fill+
  (expt 10 (floor (log most-positive-fixnum 10))))


;;; Space Requirements

(defclass space-requirement () ())

(defclass standard-space-requirement (space-requirement)
  ((width      :initform 1
               :initarg :width
               :reader space-requirement-width)
   (max-width  :initform 1
               :initarg :max-width
               :reader space-requirement-max-width)
   (min-width  :initform 1
               :initarg :min-width
               :reader space-requirement-min-width)
   (height     :initform 1
               :initarg :height
               :reader space-requirement-height)
   (max-height :initform 1
               :initarg :max-height
               :reader space-requirement-max-height)
   (min-height :initform 1
               :initarg :min-height
               :reader space-requirement-min-height) ) )

(defmethod print-object ((space standard-space-requirement) stream)
  (with-slots (width height min-width max-width min-height max-height) space
    (print-unreadable-object (space stream :type t :identity nil)
      (format stream "width: ~S [~S,~S] height: ~S [~S,~S]"
              width
              min-width
              max-width
              height
              min-height
              max-height))))

(defun make-space-requirement (&key (min-width 0) (min-height 0)
                                 (width min-width) (height min-height)
                                 (max-width +fill+) (max-height +fill+))
  ;; Defensive programming. For instance SPACE-REQUIREMENT-+ may cause
  ;; max-{width,height} to be (+ +fill+ +fill+), what exceeds our biggest
  ;; allowed values. We fix that here.
  (clampf min-width 0 +fill+)
  (clampf max-width 0 +fill+)
  (clampf width min-width  max-width)
  (clampf min-height 0 +fill+)
  (clampf max-height 0 +fill+)
  (clampf height min-height max-height)
  (assert (<= min-width  max-width)  (min-width  max-width))
  (assert (<= min-height max-height) (min-height max-height))
  (make-instance 'standard-space-requirement
                 :width width
                 :max-width max-width
                 :min-width min-width
                 :height height
                 :max-height max-height
                 :min-height min-height))

(defmethod space-requirement-components ((space-req standard-space-requirement))
  (with-slots (width min-width max-width height min-height max-height) space-req
    (values width min-width max-width height min-height max-height)))

(defmethod space-requirement-equal ((sr1 space-requirement) (sr2 space-requirement))
  (multiple-value-bind (width1 min-width1 max-width1 height1 min-height1 max-height1)
      (space-requirement-components sr1)
    (multiple-value-bind (width2 min-width2 max-width2 height2 min-height2 max-height2)
        (space-requirement-components sr2)
      (and (eql width1 width2) (eql min-width1 min-width2) (eql max-width1 max-width2)
           (eql height1 height2) (eql min-height1 min-height2) (eql max-height1 max-height2)))))

(defun space-requirement-combine* (function sr1 &key (width 0) (min-width 0) (max-width 0)
                                                  (height 0) (min-height 0) (max-height 0))
  (apply #'make-space-requirement
         (mapcan #'(lambda (c1 c2 keyword)
                     (list keyword (funcall function c1 c2)))
                 (multiple-value-list (space-requirement-components sr1))
                 (list width min-width max-width height min-height max-height)
                 '(:width :min-width :max-width :height :min-height :max-height))))

(defun space-requirement-combine (function sr1 sr2)
  (multiple-value-bind (width min-width max-width height min-height max-height)
      (space-requirement-components sr2)
    (space-requirement-combine* function sr1
                                :width      width
                                :min-width  min-width
                                :max-width  max-width
                                :height     height
                                :min-height min-height
                                :max-height max-height)))

(defun space-requirement+ (sr1 sr2)
  (space-requirement-combine #'+ sr1 sr2))

(defun space-requirement+* (space-req &key (width 0) (min-width 0) (max-width 0)
                                        (height 0) (min-height 0) (max-height 0))
  (space-requirement-combine* #'+ space-req
                              :width      width
                              :min-width  min-width
                              :max-width  max-width
                              :height     height
                              :min-height min-height
                              :max-height max-height))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun spacing-value-p (x)
    (or (and (realp x) (>= x 0))
        (and (consp x)
             (realp (car x))
             (consp (cdr x))
             (member (cadr x) '(:point :pixel :mm :character :line))
             (null (cddr x)))
        ;; For clim-stream-pane
        (eq x :compute))))

(deftype spacing-value ()
  ;; just for documentation
  `(satisfies spacing-value-p))


;;; User space requirements
(defclass space-requirement-options-mixin ()
  ((user-width
    :initarg  :width
    :initform nil
    :reader   pane-user-width
    :type     (or null spacing-value))
   (user-min-width
    :initarg :min-width
    :initform nil
    :reader   pane-user-min-width
    :type     (or null spacing-value))
   (user-max-width
    :initarg :max-width
    :initform nil
    :reader   pane-user-max-width
    :type     (or null spacing-value))
   (user-height
    :initarg :height
    :initform nil
    :reader   pane-user-height
    :type     (or null spacing-value))
   (user-min-height
    :initarg :min-height
    :initform nil
    :reader   pane-user-min-height
    :type     (or null spacing-value))
   (user-max-height
    :initarg :max-height
    :initform nil
    :reader   pane-user-max-height
    :type     (or null spacing-value))
   (x-spacing
    :initarg :x-spacing
    :initform 0
    :reader   pane-x-spacing
    :type     (or null spacing-value))
   (y-spacing
    :initarg :y-spacing
    :initform 0
    :reader   pane-y-spacing
    :type     (or null spacing-value))
   (align-x
    :initarg :align-x
    :reader pane-align-x
    :type (member :left :center :right :expand))
   (align-y
    :initarg :align-y
    :reader pane-align-y
    :type (member :top :center :bottom :expand)))
  (:default-initargs
   :align-x :left
   :align-y :top)
  (:documentation
   "Mixin class for panes which offer the standard user space requirements options."))

(defmethod shared-initialize :after ((instance space-requirement-options-mixin)
                                     (slot-names t)
                                     &key
                                       (x-spacing nil x-spacing-p)
                                       (y-spacing nil y-spacing-p)
                                       (spacing nil spacing-p))
  (declare (ignore x-spacing y-spacing))
  (cond ((not spacing-p))
        (x-spacing-p
         (error #1="~@<The initargs ~S and ~S are mutually exclusive~@:>"
                :spacing :x-spacing))
        (y-spacing-p
         (error #1# :spacing :y-spacing))
        (t
         (setf (slot-value instance 'x-spacing) spacing
               (slot-value instance 'y-spacing) spacing))))

(defclass standard-space-requirement-options-mixin (space-requirement-options-mixin)
  ())

(defgeneric spacing-value-to-device-units (pane x))

(defun merge-one-option (pane foo user-foo user-min-foo user-max-foo min-foo max-foo)
  (macrolet ((frob (user-val pane-val null-val)
               `(setf ,user-val
                      (cond ((eq ,user-val :compute)
                             (spacing-value-to-device-units pane ,pane-val))
                            ((eq ,user-val nil)
                             (spacing-value-to-device-units pane ,null-val))
                            (t
                             (spacing-value-to-device-units pane ,user-val))))))
    (frob user-foo foo foo)
    ;; MIN and MAX when NIL are defaulting to 0 and +FILL+ - this is for
    ;; consistency with MAKE-SPACE-REQUIREMENT.
    ;;
    ;; When the value is (:RELATIVE NUMBER), then it indicates the mumber of
    ;; device units that the pane is willing to stretch or shrink.
    ;;
    ;; -- jd 2022-05-24
    (if (typep user-min-foo '(cons (eql :relative)))
        (destructuring-bind (key val) user-min-foo
          (assert (eq key :relative))
          (setf user-min-foo (- user-foo val)))
        (frob user-min-foo min-foo 0))
    (if (typep user-max-foo '(cons (eql :relative)))
        (destructuring-bind (key val) user-max-foo
          (assert (eq key :relative))
          (setf user-max-foo (+ user-foo val)))
        (frob user-max-foo max-foo +fill+)))
  ;; Now we have two space requirements which need to be 'merged'.
  (setf min-foo (clamp user-min-foo min-foo max-foo)
        max-foo (clamp user-max-foo min-foo max-foo)
        foo     (clamp user-foo min-foo max-foo))
  (values foo min-foo max-foo))

(defun merge-user-specified-options (pane sr)
  (check-type pane space-requirement-options-mixin)
  ;; I want proper error checking and in case there is an error we should just
  ;; emit a warning and move on. CLIM should not die from garbage passed in
  ;; here. -- gb 2003-03-14
  (multiple-value-bind (width min-width max-width height min-height max-height)
      (space-requirement-components sr)
    (multiple-value-bind (new-width new-min-width new-max-width)
        (merge-one-option pane
                          width
                          (pane-user-width pane)
                          (pane-user-min-width pane)
                          (pane-user-max-width pane)
                          min-width
                          max-width)
      (multiple-value-bind (new-height new-min-height new-max-height)
          (merge-one-option pane
                            height
                            (pane-user-height pane)
                            (pane-user-min-height pane)
                            (pane-user-max-height pane)
                            min-height
                            max-height)
        (make-space-requirement
         :width      new-width
         :min-width  new-min-width
         :max-width  new-max-width
         :height     new-height
         :min-height new-min-height
         :max-height new-max-height)))))


(defmethod compose-space :around ((pane space-requirement-options-mixin)
                                  &key width height)
  (declare (ignore width height))
  ;; merge user specified options.
  (let ((sr (call-next-method)))
    (unless sr
      (warn "~S has no idea about its space-requirements." pane)
      (setf sr (make-space-requirement :width 100 :height 100)))
    (merge-user-specified-options pane sr)))

(defmethod change-space-requirements :before
    ((pane space-requirement-options-mixin)
     &key
       (width :nochange) (min-width :nochange) (max-width :nochange)
       (height :nochange) (min-height :nochange) (max-height :nochange)
       (align-x :nochange) (align-y :nochange)
       (x-spacing :nochange) (y-spacing :nochange)
     &allow-other-keys)
  (macrolet ((update (parameter slot-name)
               `(unless (eq ,parameter :nochange)
                  (setf (slot-value pane ',slot-name) ,parameter))))
    (update width user-width)
    (update min-width user-min-width)
    (update max-width user-max-width)
    (update height user-height)
    (update min-height user-min-height)
    (update max-height user-max-height)
    (update align-x align-x)
    (update align-y align-y)
    (update x-spacing x-spacing)
    (update y-spacing y-spacing)))


;;; Layout protocol mixin

(defclass layout-protocol-mixin ()
  ((space-requirement
    :accessor pane-space-requirement
    :initform nil
    :documentation "The cache of the space requirements of the pane. NIL means: need to recompute.") ))

(defun layout-sheet (sheet &optional width height)
  (when (and (null width) (null height))
    (let ((space (compose-space sheet)))
      (setq width (space-requirement-width space))
      (setq height (space-requirement-height space))))
  (unless (and (= width (bounding-rectangle-width sheet))
               (= height (bounding-rectangle-height sheet)))
    (resize-sheet sheet width height))
  (allocate-space sheet width height))

;;; Note

;;; This is how I read the relevant section of the specification:
;;;
;;; - space is only allocated / composed when the space allocation
;;;   protocol is invoked, that is when layout-frame is called.
;;;
;;; - CHANGE-SPACE-REQUIREMENTS is only for
;;;   . reparsing the user space options
;;;   . flushing the space requirement cache of that pane.
;;;
;;; - when within CHANGING-SPACE-REQUIREMENTS, the method for
;;;   CHANGING-SPACE-REQUIREMENTS on the top level sheet should not
;;;   invoke the layout protocol but remember that the SR of the frame
;;;   LAYOUT-FRAME then is then called when leaving
;;;   CHANGING-SPACE-REQUIREMENTS.
;;;
;;; --GB 2003-03-16

(defmethod compose-space :around ((pane layout-protocol-mixin) &key width height)
  (declare (ignore width height))
  (or (pane-space-requirement pane)
      (setf (pane-space-requirement pane)
            (call-next-method))))


;;; Changing space requirements

;;; Here is what we do:
;;;
;;; change-space-requirements (pane) :=
;;;   clear space requirements cache
;;;   call note-space-requirements-changed
;;;
;;; This is split into :before, primary and :after method to allow for
;;; easy overriding of change-space-requirements without needing to
;;; know the details of the space requirement cache and the
;;; note-space-requirements-changed notifications.
;;;
;;; If :resize-frame t the calls to change-space-requirements travel
;;; all the way up to the top-level-sheet-pane which then invokes the
;;; layout protocol calling layout-frame.
;;;
;;; In case this happens within changing-space-requirements layout
;;; frame is not called but simply recorded and then called when
;;; changing-space-requirements is left.

(defvar *changing-space-requirements* nil
  "Bound to non-NIL while within the execution of CHANGING-SPACE-REQUIREMENTS.")

(defvar *changed-space-requirements* nil
  "A list of (FRAMES . PANES) tuples recording frames and panes which changed
during the current execution of CHANGING-SPACE-REQUIREMENTS.")

(defmethod change-space-requirements :before ((pane layout-protocol-mixin)
                                              &rest space-req-keys
                                              &key resize-frame &allow-other-keys)
  (declare (ignore resize-frame space-req-keys))
  ;; Clear the cached value
  (setf (pane-space-requirement pane) nil))

(defmethod change-space-requirements ((pane layout-protocol-mixin)
                                      &key resize-frame &allow-other-keys)
  (declare (ignore resize-frame))
  ;; do nothing here
  nil)

(defmethod change-space-requirements :after ((pane layout-protocol-mixin)
                                             &key resize-frame &allow-other-keys)
  (when-let ((parent (sheet-parent pane)))
    (if resize-frame
        ;; From Spec 29.3.4: "If resize-frame is true, then
        ;; layout-frame will be invoked on the frame". Here instead of
        ;; call directly LAYOUT-FRAME, we call
        ;; CHANGE-SPACE-REQUIREMENTS on the parent and it travels all
        ;; the way up to the top-level-sheet-pane which then invokes
        ;; the layout protocol calling LAYOUT-FRAME. The rationale of
        ;; this is:
        ;; 1. we can't call (LAYOUT-FRAME (PANE-FRAME pane)) on a
        ;;   menu because with the actual implementation of menu it
        ;;   will layout the main application and not the menu frame.
        ;; 2. we automatically clear the cached values of
        ;;    space-requirements for the involved panes.
        ;; -- admich 2020-08-11
        (if (top-level-sheet-pane-p pane)
            (note-space-requirements-changed parent pane)
            (change-space-requirements parent :resize-frame t))
        (note-space-requirements-changed parent pane))))

(defmethod note-space-requirements-changed (pane client)
  "Just a no-op fallback method."
  (declare (ignore pane client))
  nil)

;;; CHANGING-SPACE-REQUIREMENTS macro

(defmacro changing-space-requirements ((&key resize-frame layout) &body body)
  `(invoke-with-changing-space-requirements
    (lambda () ,@body) :resize-frame ,resize-frame :layout ,layout))

;;; Invalidates space requirements up to the top-level sheet forcing them to
;;; be recomputed when the frame is laid out.
(defun invalidate-space-requirements (pane)
  (loop for sheet = pane then (sheet-parent sheet)
        while (panep sheet)
        do (setf (pane-space-requirement sheet) nil)))

(defmethod change-space-requirements :around
    ((pane layout-protocol-mixin) &rest space-req-keys
     &key resize-frame &allow-other-keys)
  (declare (ignore space-req-keys))
  (if *changing-space-requirements*
      (let ((frame (pane-frame pane)))
        ;; FIXME we should not eagerly invalidate all requirements when
        ;; RESIZE-FRAME is NIL, but this requires some deeper changes to
        ;; NOTE-SPACE-REQUIREMENTS-CHANGED, ALLOCATE-SPACE etc; so we retain
        ;; the old behavior for now. -- jd 2022-05-27
        (invalidate-space-requirements pane)
        (if (or resize-frame (frame-resize-frame frame))
            (pushnew frame (car *changed-space-requirements*))
            (pushnew pane  (cdr *changed-space-requirements*))))
      (call-next-method)))

(defmethod note-space-requirements-changed :around (sheet pane)
  (unless *changing-space-requirements*
    (call-next-method)))

(defun invoke-with-changing-space-requirements
    (continuation &key resize-frame layout)
  (when *changing-space-requirements*
    (return-from invoke-with-changing-space-requirements
      (funcall continuation)))
  (let ((*changed-space-requirements* (cons nil nil)))
    (multiple-value-prog1 (let ((*changing-space-requirements* t))
                            (funcall continuation))
      (let ((frames (car *changed-space-requirements*))
            (panes (cdr *changed-space-requirements*)))
        (loop for frame in frames do
          (layout-frame frame))
        (loop for pane in panes
              for frame = (pane-frame pane)
              unless (or (member frame frames)
                         (some (lambda (p)
                                 (and (not (eq p pane))
                                      (sheet-ancestor-p pane p)))
                               panes))
                do (cond
                     (resize-frame
                      (layout-frame frame))
                     (layout
                      (with-bounding-rectangle* (:width width :height height)
                          (frame-top-level-sheet frame)
                        (layout-frame frame width height)))
                     (t
                      (note-space-requirements-changed (sheet-parent pane) pane))))))))
