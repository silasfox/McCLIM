(in-package #:mcclim-render)

(defun aa-render-draw-fn (image clip-region design)
  (let ((pixels (pattern-array image)))
    (lambda (x y alpha)
      (declare (type fixnum x y alpha))
      (setf alpha (min (abs alpha) 255))
      (unless (or (zerop alpha)
                  (and clip-region
                       (not (region-contains-position-p clip-region x y))))
        (let* ((value (climi::%pattern-rgba-value design x y))
               (a.fg (ldb (byte 8 24) value)))
          (if (> (octet-mult a.fg alpha) 250)
              (setf (aref pixels y x) value)
              (let-rgba ((r.fg g.fg b.fg a.fg) value)
                (let-rgba ((r.bg g.bg b.bg a.bg) (aref pixels y x))
                  (setf (aref pixels y x)
                        (multiple-value-call #'%vals->rgba
                          (octet-rgba-blend-function
                           r.fg g.fg b.fg (octet-mult a.fg alpha)
                           r.bg g.bg b.bg a.bg)))))))))))

(defun aa-render-xor-draw-fn (image clip-region design)
  (let ((pixels (pattern-array image)))
    (lambda (x y alpha)
      (declare (type fixnum x y alpha))
      (setf alpha (min (abs alpha) 255))
      (unless (or (zerop alpha)
                  (and clip-region
                       (not (region-contains-position-p clip-region x y))))
        (multiple-value-bind (r.fg g.fg b.fg a.fg)
            (%rgba->vals (let* ((ink (climi::design-ink* design x y))
                                (c1 (climi::%pattern-rgba-value
                                     (slot-value ink 'climi::design1) x y))
                                (c2 (climi::%pattern-rgba-value
                                     (slot-value ink 'climi::design2) x y)))
                           (logior (logxor c1 c2) #xff000000)))
          (let-rgba ((r.bg g.bg b.bg a.bg) (aref pixels y x))
            (setf (aref pixels y x)
                  (octet-blend-function*
                   (color-octet-xor r.fg r.bg)
                   (color-octet-xor g.fg g.bg)
                   (color-octet-xor b.fg b.bg)
                   (octet-mult a.fg alpha)
                   r.bg g.bg b.bg a.bg))))))))

(defun aa-render-alpha-draw-fn (image clip-region)
  (let ((pixels (pattern-array image)))
    (lambda (x y alpha)
      (declare (type fixnum x y alpha))
      (setf alpha (min (abs alpha) 255))
      (unless (or (zerop alpha)
                  (and clip-region
                       (not (region-contains-position-p clip-region x y))))
        (setf (aref pixels y x) alpha)))))
