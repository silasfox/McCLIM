;;; ---------------------------------------------------------------------------
;;;   License: LGPL-2.1+ (See file 'Copyright' for details).
;;; ---------------------------------------------------------------------------
;;;
;;;  (c) Copyright 1998-2000 Michael McDonald <mikemac@mikemac.com>
;;;  (c) Copyright 2000-2014 Robert Strandh <robert.strandh@gmail.com>
;;;  (c) Copyright 1998-2002 Gilbert Baumann <unk6@rz.uni-karlsruhe.de>
;;;  (c) Copyright 2016-2018 Daniel Kochmański <daniel@turtleware.eu>
;;;
;;; ---------------------------------------------------------------------------

;;; Patterns are a bounded rectangular arrangements of designs, like a
;;; checkboard. Pattern may be transformed and composed with other designs.
;;;
;;; Extensions:
;;;
;;;   IMAGE-PATTERN                                                      [class]
;;;
;;;      Represents a raster image.
;;;
;;;   TRANSFORMED-PATTERN                                                [class]
;;;
;;;      Represents a pattern which was transformed. May be recursive - pattern
;;;      which is transformed may be another transformed-pattern.
;;;
;;;   RECTANGULAR-TILE-DESIGN tile                                      [method]
;;;
;;;      Returns a design used in the rectangular tile.
;;;
;;; Internals (i.e for use by a backend):
;;;
;;;   %ARRAY-PATTERN                                                     [class]
;;;
;;;      Base class for other all patterns which are based on an array having
;;;      pattern size. In case of transformations we start from that array.
;;;      Array is immutable, transformation should allocate its own array when
;;;      needed.
;;;
;;;   %RGBA-PATTERN                                                      [class]
;;;
;;;      Internal class. Its purpose is to hold cached precomputed RGBA array
;;;      for other patterns (so we collapse designs used as inks and opacities
;;;      into their final values). Computing such an array is not necessarily
;;;      trivial, for instance an INDEXED-PATTERN may have a RECTANGULAR-TILE as
;;;      one of its designs, in which case we "blit" rectangular tile instead of
;;;      simple color to all original array elements pointing at the tile. In
;;;      case of transformations this pattern should contain final (possibly
;;;      interpolated) values. This instance may be computed lazily and cached.
;;;
;;;   %RGBA-VALUE ink                                                 [function]
;;;
;;;      Collapses ink into a single RGBA value. Use only on uniform designs.
;;;
;;;   %PATTERN-RGBA-VALUE pattern x y                                 [function]
;;;
;;;      Returns pattern color in RGBA for a point [X,Y]. Unoptimized
;;;      implementation of %COLLAPSE-PATTERN may use that function.
;;;
;;;   %COLLAPSE-PATTERN pattern x y w h                               [function]
;;;
;;;      Takes an arbitrary design and returns an IMAGE.
;;;
;;; Note: rectangular-tile is an "infinite" pattern which has a special
;;; treatment for drawing. That is a consequence of wording in 14.2: "To create
;;; an infinite pattern, apply make-rectangular-tile to a pattern".
;;;
;;; Q: Should pattern be a region?
;;;
;;;    That could make the pattern composition easier. Patterns should certainly
;;;    implement bounding-rectangle protocol. In case of rectangular-tile it
;;;    should work on its base design size (and a transformation).
;;;
;;; A: This is implied by the fact that it is advised to use TRANSFORM-REGION on
;;;    a pattern in order to transform it. See 14.5.
;;;
;;; Q: Should a pattern which is not transformed have a starting position?
;;;
;;;    Most transformations on patterns will revolve around moving them. If we
;;;    decide that pattern is a region it could be useful.

(in-package #:clim-internals)

(define-protocol-class pattern (design) ()
  (:documentation "Abstract class for all pattern-like designs."))

(defclass %array-pattern (pattern)
  ((array :initarg :array :reader pattern-array))
  (:documentation "Abstract class for all patterns based on an array (indexed
pattern, stencil, image etc)."))

(defmethod print-object ((object %array-pattern) stream)
  (print-unreadable-object (object stream :type t :identity nil)
    (format stream ":WIDTH ~s :HEIGHT ~S"
            (pattern-width object)
            (pattern-height object))))

(defmethod pattern-width ((pattern %array-pattern))
  (array-dimension (pattern-array pattern) 1))

(defmethod pattern-height ((pattern %array-pattern))
  (array-dimension (pattern-array pattern) 0))

(defmethod bounding-rectangle* ((pattern %array-pattern))
  (let ((width (pattern-width pattern))
        (height (pattern-height pattern)))
    (values 0 0 width height)))

(defmethod bounding-rectangle ((pattern %array-pattern))
  (destructuring-bind (height width) (array-dimensions (pattern-array pattern))
    (make-bounding-rectangle 0 0 width height)))

(defclass %rgba-pattern (%array-pattern)
  ((array :type (simple-array (unsigned-byte 32) 2)))
  (:documentation "Helper class of RGBA result of another pattern."))

(defmethod design-ink ((pattern %rgba-pattern) x y)
  (let ((array (pattern-array pattern)))
    (declare (type (array (unsigned-byte 32) 2) array))
    (if (array-in-bounds-p array y x)
        (let* ((rgba-value (aref array y x))
               (alpha (ldb (byte 8 24) rgba-value)))
          (flet ((color ()
                   (make-rgb-color (/ (ldb (byte 8 16) rgba-value) 255.0)
                                   (/ (ldb (byte 8  8) rgba-value) 255.0)
                                   (/ (ldb (byte 8  0) rgba-value) 255.0))))
            (case alpha
              (0 +transparent-ink+)
              (255 (color))
              (t (make-uniform-compositum (color) (/ alpha 255.0))))))
        +transparent-ink+)))


;;; Rectangular patterns

(defclass indexed-pattern (%array-pattern)
  ((designs :initarg :designs :reader pattern-designs))
  (:documentation "Indexed pattern maps numbers in array to designs."))

(defun make-pattern (array designs)
  (check-type array array)
  (check-type designs sequence)
  (make-instance 'indexed-pattern :array array :designs designs))

(defmethod design-ink ((pattern indexed-pattern) x y)
  (let ((array (pattern-array pattern)))
    ;; An INDEXED-PATTERN may be used as a design in a RECTANGULAR-TILE. If it
    ;; is bigger than our pattern we return +transparent-ink+.
    (if (array-in-bounds-p array y x)
        (elt (pattern-designs pattern) (aref array y x))
        +transparent-ink+)))

(defclass stencil (%array-pattern)
  ((array :type (simple-array (single-float 0.0f0 1.0f0) 2)))
  (:documentation "Stencil pattern provides opacity mask."))

(defun make-stencil (array)
  (make-instance 'stencil :array array))

(defmethod design-ink ((pattern stencil) x y)
  (let ((array (pattern-array pattern)))
    (if (array-in-bounds-p array y x)
        (make-opacity (aref array y x))
        +transparent-ink+)))

;;; If we had wanted to convert stencil to indexed array these functions would
;;; come handy what would not serve much purpose though.
#+(or)
(defun indexed-pattern-array ((pattern stencil))
  (let ((array (make-array (list (pattern-height pattern)
                                 (pattern-width pattern)))))
    (dotimes (i (pattern-height pattern))
      (dotimes (j (pattern-width pattern))
        (setf (aref array i j) (+ (* i (array-dimension array 1)) j))))
    array))

#+(or)
(defun indexed-pattern-designs ((pattern stencil))
  (with-slots (array) pattern
    (let ((designs (make-array (* (pattern-height pattern)
                                  (pattern-width pattern)))))
      (dotimes (i (length designs))
        (setf (aref designs i) (make-opacity (row-major-aref array i))))
      array)))

(defclass %ub8-stencil (%array-pattern)
  ((array :type (simple-array (unsigned-byte 8) 2)))
  (:documentation "Internal class analogous to a stencil, but whose
array is of type (unsigned-byte 8), rather than a float from 0 to
1."))

(defclass rectangular-tile (pattern)
  ((width  :initarg :width   :reader pattern-width)
   (height :initarg :height  :reader pattern-height)
   (design :initarg :design  :reader rectangular-tile-design))
  (:documentation "Rectangular tile repeats a rectangular portion of a design
throughout the drawing plane. This is most commonly used with patterns."))

(defun make-rectangular-tile (design width height)
  (make-instance 'rectangular-tile
                 :width  width
                 :height height
                 :design design))

(defmethod design-ink ((pattern rectangular-tile) x y
                       &aux
                         (x (mod x (pattern-width pattern)))
                         (y (mod y (pattern-height pattern))))
  (design-ink (rectangular-tile-design pattern) x y))

(defmethod bounding-rectangle ((pattern rectangular-tile))
  (make-rectangle* 0 0 (pattern-width pattern) (pattern-height pattern)))


;;; Bitmap images (from files)
;;;
;;; Based on CLIM 2.2, with an extension permitting the definition of
;;; new image formats by the user.

(defclass image-pattern (%rgba-pattern) ()
  (:documentation "RGBA pattern. Class defined for specialization. Instances of
this class may be returned by MAKE-PATTERN-FROM-BITMAP-FILE."))

(defvar *bitmap-file-readers* (make-hash-table :test 'equalp)
  "A hash table mapping keyword symbols naming bitmap image formats to a
function that can read an image of that format. The functions will be called
with one argument, the pathname of the file to be read. The functions should
return two values as per READ-BITMAP-FILE.")

(defvar *bitmap-file-writers* (make-hash-table :test 'equalp)
  "A hash table mapping keyword symbols naming bitmap image formats to a
function that can write an image of that format. The functions will be called
with two arguments, the image pattern and the pathname to which the file to be
wrote. The functions should return the pathname.")

(defmacro define-bitmap-file-reader (bitmap-format (&rest args) &body body)
  "Define a method for reading bitmap images of format BITMAP-FORMAT that will
be used by READ-BITMAP-FILE and MAKE-PATTERN-FROM-BITMAP-FILE. BODY should
return two values as per `read-bitmap-file'."
  `(setf (gethash ,bitmap-format *bitmap-file-readers*)
         #'(lambda (,@args) ,@body)))

(defmacro define-bitmap-file-writer (format (&rest args) &body body)
  "Define a method for writing bitmap images of format FORMAT that will be used
by WRITE-BITMAP-FILE. BODY should return a pathname written."
  `(setf (gethash ,format *bitmap-file-writers*)
         #'(lambda (,@args) ,@body)))

(defun bitmap-format-supported-p (format)
  "Return true if FORMAT is supported by READ-BITMAP-FILE."
  (not (null (gethash format *bitmap-file-readers*))))

(defun bitmap-output-supported-p (format)
  "Return true if FORMAT is supported by WRITE-BITMAP-FILE."
  (not (null (gethash format *bitmap-file-writers*))))

(define-condition unsupported-bitmap-format (simple-error) ()
  (:report (lambda (condition stream)
             (declare (ignore condition))
             (format stream "Unsupported bitmap format")))
  (:documentation "This condition is signaled when trying to read or write a
bitmap file whose format is not supported." ))

(defun read-bitmap-file (pathname &key (format :bitmap))
  "Read a bitmap file named by PATHNAME. FORMAT is a keyword symbol naming any
defined bitmap file format defined by CLIM-EXTENSIONS:DEFINE-BITMAP-FILE-READER.

Two values are returned: pattern of type IMAGE-PATTERN or if the second value is
non-NIL returns INDEXED-PATTERN and design-inks for it."
  (funcall (or (gethash format *bitmap-file-readers*)
               (gethash :fallback *bitmap-file-readers*)
               (error 'unsupported-bitmap-format))
           pathname))

(defun write-bitmap-file (image pathname &key (format :bitmap))
  "Write the image-pattern to file named by PATHNAME. FORMAT is a keyword symbol
naming any defined bitmap file format defined by
CLIM-EXTENSIONS:DEFINE-BITMAP-FILE-WRITER. Returns a written file pathname."
  (funcall (or (gethash format *bitmap-file-writers*)
               (gethash :fallback *bitmap-file-writers*)
               (error 'unsupported-bitmap-format))
           image pathname))

(defun make-pattern-from-bitmap-file (pathname &key designs (format :bitmap))
  "Read a bitmap file named by PATHNAME. FORMAT is a keyword symbol naming any
defined bitmap file format defined by CLIM-EXTENSIONS:DEFINE-BITMAP-FILE-READER.
Returns a pattern representing this file."
  (multiple-value-bind (array read-designs)
      (read-bitmap-file pathname :format format)
    (if read-designs
        (make-pattern array (or designs read-designs))
        (make-instance 'image-pattern :array array))))


;;; Transformed patterns

(defclass transformed-pattern (transformed-design pattern) ())

;;; This may be cached in a transformed-pattern slot. -- jd 2018-09-24
(defmethod bounding-rectangle* ((pattern transformed-pattern))
  (let* ((source-pattern (transformed-design-design pattern))
         (transformation (transformed-design-transformation pattern)))
    (bounding-rectangle* (transform-region transformation
                                           (bounding-rectangle source-pattern)))))

(defmethod pattern-width ((pattern transformed-pattern)
                          &aux
                            (pattern* (transformed-design-design pattern))
                            (transformation (transformed-design-transformation pattern))
                            (width (pattern-width pattern*))
                            (height (pattern-height pattern*))
                            (rectangle (make-rectangle* 0 0 width height)))
  (bounding-rectangle-width (transform-region transformation rectangle)))

(defmethod pattern-height ((pattern transformed-pattern)
                           &aux
                             (pattern* (transformed-design-design pattern))
                             (transformation (transformed-design-transformation pattern))
                             (width (pattern-width pattern*))
                             (height (pattern-height pattern*))
                             (rectangle (make-rectangle* 0 0 width height)))
  (bounding-rectangle-height (transform-region transformation rectangle)))

(defmethod transform-region (transformation (design pattern))
  (let ((old-transformation (transformed-design-transformation design)))
    (make-instance 'transformed-pattern
                   :design (transformed-design-design design)
                   :transformation (compose-transformations old-transformation transformation))))

(defmethod design-ink ((design transformed-design) x y)
  (let* ((source-pattern (transformed-design-design design))
         (transformation (transformed-design-transformation design))
         (inv-tr (invert-transformation transformation)))
    (multiple-value-bind (x y) (transform-position inv-tr x y)
      ;; It is important to not use ROUND here, since when the fractional part
      ;; is exactly 0.5, we get wrong dimensions -- loke 2019-01-06
      (design-ink source-pattern (floor (+ x 0.5)) (floor (+ y 0.5))))))


;;; Utilities

(declaim (ftype (function (t) (values (unsigned-byte 32) &optional nil)) %rgba-value))
(defun %rgba-value (element)
  "Helper function collapsing uniform design into 4-byte RGBA value."
  (flet ((transform (parameter)
           (logand (truncate (* parameter 255)) 255)))
    (etypecase element
      ((unsigned-byte 32) element)
      ;; Uniform-compositium is a masked-compositum rgb + opacity
      ((or color opacity uniform-compositum)
       (multiple-value-bind (red green blue opacity)
           (color-rgba element)
         (logior (ash (transform opacity) 24)
                 (ash (transform red)     16)
                 (ash (transform green)    8)
                 (ash (transform blue)     0))))
      (indirect-ink
       (%rgba-value (indirect-ink-ink element)))
      (everywhere-region
       (%rgba-value *foreground-ink*)))))

(defun %pattern-rgba-value (pattern x y)
  (let ((ink (design-ink pattern x y)))
    (if (eq ink pattern)
        (%rgba-value ink)
        (%pattern-rgba-value ink x y))))

(defun %collapse-pattern (design x0 y0 width height)
  (when (and (typep design '%rgba-pattern)
             (zerop x0)
             (zerop y0)
             (= width (pattern-width design))
             (= height (pattern-height design)))
    (return-from %collapse-pattern design))
  (let* ((x0 (floor (+ x0 .5)))
         (y0 (floor (+ y0 .5)))
         (width (floor (+ width .5)))
         (height (floor (+ height .5)))
         (array (make-array (list height width)
                            :element-type '(unsigned-byte 32))))
    (loop for i from 0 below width
          for x from x0 do
            (loop for j below height
                  for y from y0 do
        (setf (aref array j i) (%pattern-rgba-value design x y))))
    (make-instance '%rgba-pattern :array array)))
