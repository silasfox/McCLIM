;;; ---------------------------------------------------------------------------
;;;   License: LGPL-2.1+ (See file 'Copyright' for details).
;;; ---------------------------------------------------------------------------
;;;
;;;  (c) Copyright 1998-2000 by Michael McDonald <mikemac@mikemac.com>
;;;  (c) Copyright 2000 by Iban Hatchondo <hatchond@emi.u-bordeaux.fr>
;;;  (c) Copyright 2000 by Julien Boninfante <boninfan@emi.u-bordeaux.fr>
;;;  (c) Copyright 2000,2014 by Robert Strandh <robert.strandh@gmail.com>
;;;  (c) Copyright 2022 by Daniel Kochmański <daniel@turtleware.eu>
;;;
;;; ---------------------------------------------------------------------------
;;;
;;; The Repaint Protocol.
;;;

(in-package #:clim-internals)


;;; Input protocol functions.

(defmethod handle-event ((sheet basic-sheet)
                         (event window-repaint-event))
  (when-let ((msheet (sheet-mirrored-ancestor (event-sheet event))))
    ;; Only dispatch repaints when the sheet has a mirror. Dispatch to the
    ;; mirrored sheet to ensure that translucent backgrounds rendesr correctly.
    ;; This also improves performance thanks to the better compression of the
    ;; repaint events in the queue.
    (dispatch-repaint msheet (window-event-native-region event))))

;;; Backward compatibility.
(defmethod queue-repaint ((sheet basic-sheet) (event window-repaint-event))
  (when-let ((msheet (sheet-mirrored-ancestor (event-sheet event))))
    (dispatch-repaint msheet (window-event-native-region event))))


;;; Repaint protocol functions.

(defmethod handle-repaint ((sheet basic-sheet) region)
  (declare (ignore region))
  nil)

(defmethod repaint-sheet :around ((sheet basic-sheet) region)
  (declare (ignore region))
  (when (and (sheet-mirror sheet)
             (sheet-viewable-p sheet))
    (call-next-method)))

(defmethod handle-repaint :around ((sheet sheet-with-medium-mixin) region)
  (typecase region
    (nowhere-region)
    (everywhere-region
     (call-next-method))
    (otherwise
     (with-sheet-medium (medium sheet)
       (letf (((medium-clipping-region medium) region))
         (call-next-method))))))

;;; NOTE the native region may be smaller than the sheet region.
;;; NOTE see #1280 to learn why SHEET-NATIVE-REGION* is introduced.
;;; FIXME caching.
(defgeneric sheet-native-region* (sheet)
  (:method ((sheet graft))
    +everywhere+)
  (:method ((sheet mirrored-sheet-mixin))
    (if-let ((parent (sheet-parent sheet)))
      (region-intersection
       (sheet-region sheet)
       (untransform-region (sheet-transformation sheet)
                           (sheet-native-region* parent)))
      (sheet-region sheet)))
  (:method ((sheet basic-sheet))
    (region-intersection
     (transform-region (sheet-native-transformation sheet) (sheet-region sheet))
     (sheet-native-region* (sheet-parent sheet)))))

(defun sheet-visible-region (sheet)
  (if (sheet-direct-mirror sheet)
      (sheet-native-region* sheet)
      (untransform-region (sheet-native-transformation sheet)
                          (sheet-native-region* sheet))))

(defmethod repaint-sheet ((sheet basic-sheet) region)
  (let* ((visible (sheet-visible-region sheet))
         (clipped (region-intersection visible region)))
    (unless (region-equal clipped +nowhere+)
      (with-output-buffered (sheet)
        (handle-repaint sheet clipped)
        (loop for child in (sheet-children sheet)
              unless (sheet-direct-mirror child)
                do (let* ((tr (sheet-transformation child))
                          (cr (untransform-region tr region)))
                     (repaint-sheet child cr)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Repaint protocol classes.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Class STANDARD-REPAINTING-MIXIN.

(defclass standard-repainting-mixin () ())

(defmethod queue-repaint
    ((sheet standard-repainting-mixin) (region region))
  (error "Not implemented yet!"))

(defmethod dispatch-repaint ((sheet standard-repainting-mixin) region)
  (queue-repaint sheet region))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Class IMMEDIATE-REPAINTING-MIXIN.

(defclass immediate-repainting-mixin () ())

;;; Backward compatibility.
(defmethod queue-repaint
    ((sheet standard-repainting-mixin) (region region))
  (repaint-sheet sheet region))

(defmethod dispatch-repaint ((sheet immediate-repainting-mixin) region)
  (repaint-sheet sheet region))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Class SHEET-MUTE-REPAINTING-MIXIN.

(defclass sheet-mute-repainting-mixin () ())

(defmethod dispatch-repaint ((sheet sheet-mute-repainting-mixin) region)
  (declare (ignore sheet region))
  (values))

(defclass clim-repainting-mixin (immediate-repainting-mixin)
  ;; (#+clim-mp standard-repainting-mixin #-clim-mp immediate-repainting-mixin)
  ()
  (:documentation "Internal class that implements the repainting protocol."))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; No Standard.

;; as present in silica's implementation
(defclass always-repaint-background-mixin () ())

;; never repaint the background (only for speed)
(defclass never-repaint-background-mixin () ())

(defmethod handle-repaint :before ((sheet always-repaint-background-mixin) region)
  (when (typep sheet 'never-repaint-background-mixin)
    (return-from handle-repaint))
  (with-sheet-medium (medium sheet)
    (with-bounding-rectangle* (x1 y1 x2 y2)
        (region-intersection region (sheet-visible-region sheet))
      (medium-clear-area medium x1 y1 x2 y2))))

;;; Integration with region and transformation changes
(defparameter *skip-repaint-p* nil)

(defun dispatch-repaint-region (sheet
                                old-transformation old-region
                                new-transformation new-region)
  (when (and (not *skip-repaint-p*)
             (sheet-viewable-p sheet))
    (if (sheet-direct-mirror sheet)
        (dispatch-repaint sheet new-region)
        (dispatch-repaint (sheet-parent sheet)
                          (region-union
                           (rounded-bounding-rectangle
                            (transform-region old-transformation old-region))
                           (rounded-bounding-rectangle
                            (transform-region new-transformation new-region)))))))

(defmethod (setf sheet-region) :around (new-region (sheet basic-sheet))
  (let ((old-region (sheet-region sheet)))
    (unless (region-equal new-region old-region)
      (let ((*skip-repaint-p* t))
        (call-next-method))
      (let ((transformation (sheet-transformation sheet)))
        (dispatch-repaint-region sheet
                                 transformation old-region
                                 transformation new-region))))
  new-region)

(defmethod (setf sheet-transformation) :around (new-transformation (sheet basic-sheet))
  (let ((old-transformation (sheet-transformation sheet)))
    (unless (transformation-equal new-transformation old-transformation)
      (let ((*skip-repaint-p* t))
        (call-next-method))
      (let ((region (sheet-region sheet)))
        (dispatch-repaint-region sheet
                                 old-transformation region
                                 new-transformation region))))
  new-transformation)

(defun %set-sheet-region-and-transformation (sheet new-region new-transformation)
  (let ((old-transformation (sheet-transformation sheet))
        (old-region (sheet-region sheet)))
    (unless (and (region-equal new-region old-region)
                 (transformation-equal new-transformation old-transformation))
      (let ((*skip-repaint-p* t))
        (setf (sheet-region sheet) new-region
              (sheet-transformation sheet) new-transformation))
      (dispatch-repaint-region sheet
                               old-transformation old-region
                               new-transformation new-region))))
