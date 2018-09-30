(when (not (memq window-system '(mac ns x)))
  (package-initialize))

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(exec-path-from-shell elmine elm-mode ## elixir-mode load-dir)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

(require 'package)
(add-to-list 'package-archives '("melpa" . "http://melpa.org/packages/"))

(when (memq window-system '(mac ns x))
  (exec-path-from-shell-initialize))

;; Reformat some code based on its major mode.
(defun reformat-code()
  (interactive)
  (point-to-register 'a)
  (goto-line 1)
  (while (not (eobp))
    (indent-for-tab-command)
    (forward-line))
  (register-to-point 'a))






