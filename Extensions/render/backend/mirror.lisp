(in-package #:mcclim-render)

(defclass image-mirror-mixin ()
  ((image
    :initform nil
    :accessor image-mirror-image)
   (dirty-region
    :type region
    :initform +nowhere+
    :accessor image-dirty-region)
   (state
    :initform (aa:make-state)
    :reader image-mirror-state)
   (image-lock
    :initform (clim-sys:make-lock "image"))))

(defmethod image-mirror-image ((sheet sheet))
  (when-let ((mirror (sheet-mirror sheet)))
    (image-mirror-image mirror)))

(defmethod (setf image-mirror-image) (image (sheet sheet))
  (assert (not (null image)))
  (when-let ((mirror (sheet-mirror sheet)))
    (setf (image-mirror-image mirror) image)))

(defmacro with-image-locked ((mirror) &body body)
  `(clim-sys:with-lock-held ((slot-value ,mirror 'image-lock))
     ,@body))

;;; implementation

(defun %set-image-region (mirror region)
  (check-type mirror image-mirror-mixin)
  (let ((image (image-mirror-image mirror)))
    (with-bounding-rectangle* (:width w :height h) region
      (setf w (ceiling w))
      (setf h (ceiling h))
      (if (or (null image)
              (/= w (pattern-width image))
              (/= h (pattern-height image)))
          (%create-mirror-image mirror w h)
          image))))

(defmethod %create-mirror-image (mirror width height)
  (check-type mirror image-mirror-mixin)
  (setf width (ceiling width))
  (setf height (ceiling height))
  (let ((new-image  (make-image width height)))
    (setf (image-mirror-image mirror) new-image
          (image-dirty-region mirror) +nowhere+)
    new-image))

(defun %notify-image-updated (mirror region)
  (check-type mirror image-mirror-mixin)
  (when region
    (setf (image-dirty-region mirror)
          (region-union (image-dirty-region mirror) region))))

;;; XXX: this is used for scroll
(defun %draw-image (mirror src-image x y width height to-x to-y)
  (check-type mirror image-mirror-mixin)
  (when-let ((image (image-mirror-image mirror)))
    (with-image-locked (mirror)
      (let* ((image (image-mirror-image mirror))
             (region (copy-image src-image x y width height image to-x to-y)))
        (%notify-image-updated mirror region)))))

(defun %fill-image (mirror x y width height ink clip-region
                    &optional stencil (x-dest 0) (y-dest 0))
  (check-type mirror image-mirror-mixin)
  (when-let ((image (image-mirror-image mirror)))
    (with-image-locked (mirror)
      (let ((region (fill-image image ink
                                :x x :y y :width width :height height
                                :stencil stencil
                                :stencil-dx x-dest :stencil-dy y-dest
                                :clip-region clip-region)))
        (%notify-image-updated mirror region)))))

(defun %fill-paths (mirror paths transformation region ink)
  (check-type mirror image-mirror-mixin)
  (when-let ((image (image-mirror-image mirror)))
    (with-image-locked (mirror)
      (let* ((state (image-mirror-state mirror))
             (reg (aa-fill-paths image ink paths state transformation region)))
        (with-bounding-rectangle* (min-x min-y max-x max-y) reg
          (%notify-image-updated mirror
                                 (make-rectangle* (floor min-x) (floor min-y)
                                                  (ceiling max-x) (ceiling max-y))))))))

(defun %stroke-paths (medium mirror paths line-style transformation region ink)
  (check-type mirror image-mirror-mixin)
  (when-let ((image (image-mirror-image mirror)))
    (with-image-locked (mirror)
      (let* ((state (image-mirror-state mirror))
             (reg (aa-stroke-paths medium image ink paths line-style state transformation region)))
        (with-bounding-rectangle* (min-x min-y max-x max-y) reg
          (%notify-image-updated mirror (make-rectangle* (floor min-x) (floor min-y)
                                                         (ceiling max-x) (ceiling max-y))))))))
