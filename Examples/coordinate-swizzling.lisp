;;; ------------------------------------
;;; coordinate-swizzling.lisp

(defpackage #:clim-demo.coord-swizzling
  (:use #:clim-lisp #:clim)
  (:export #:run #:coordinate-swizzling))
(in-package #:clim-demo.coord-swizzling)

(clim:define-application-frame coordinate-swizzling ()
  ()
  (:menu-bar nil)
  (:panes (app :application
               :scroll-bars nil
               :display-time t)
          (int :interactor
               :scroll-bars nil))
  (:layouts
   (:default (clim:vertically ()
               (clim:scrolling (:height 400 :scroll-bars t) app)
               (clim:scrolling (:height 50 :scroll-bars t) int)))))

(defun run ()
  (clim:run-frame-top-level
   (clim:make-application-frame 'coordinate-swizzling)))

(define-coordinate-swizzling-command (com-fill :name t) ()
  (let ((pane (clim:find-pane-named clim:*application-frame* 'app))
        (time (get-universal-time)))
    (loop for i from 0 to 4400
          do (format pane "~4,'0d~%" i))
    (setf time (- (get-universal-time) time))
    (let ((output (make-broadcast-stream *standard-input* *debug-io*)))
      (format output "Fill took ~Ds.~%" time))))

(define-coordinate-swizzling-command (com-quit :name t) ()
  (clim:frame-exit clim:*application-frame*))
