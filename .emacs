(require 'package)
(let* ((no-ssl (and (memq system-type '(windows-nt ms-dos))
                    (not (gnutls-available-p))))
       (proto (if no-ssl "http" "https")))
  ;; Comment/uncomment these two lines to enable/disable MELPA and MELPA Stable as desired
  (add-to-list 'package-archives (cons "melpa" (concat proto "://melpa.org/packages/")) t)
  ;;(add-to-list 'package-archives (cons "melpa-stable" (concat proto "://stable.melpa.org/packages/")) t)
  (when (< emacs-major-version 24)
    ;; For important compatibility libraries like cl-lib
    (add-to-list 'package-archives (cons "gnu" (concat proto "://elpa.gnu.org/packages/")))))
(package-initialize)

(font-lock-mode t)
(desktop-save-mode 1)

(global-set-key "\M-g" 'goto-line)
(global-set-key "\C-c\C-w" 'write-region)
(global-set-key "\C-c\C-z" 'compile)
(global-set-key "\C-c\C-k" 'kill-compilation)

;; I should make this actually use the more "interesting" CC mode hooks to also reformat expressions and such.
(defun c-frob-buffer ()
  (interactive)
  (goto-line 1)
  (while (not (eobp))
    (c-indent-line)
    (forward-line 1)))

;; For plain-old-emacs's C mode
(setq 
  c-indent-level                4
  c-continued-statement-offset  4
  c-brace-offset               -4
  c-argdecl-indent              0
  c-label-offset               -4)

(defun my-c-mode-common-hook ()
  ;; use BSD style for all C, C++, and Objective-C code
  (c-set-style "BSD"))
(add-hook 'c-mode-common-hook 'my-c-mode-common-hook)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(load-home-init-file t t)
 '(package-selected-packages
   (quote
    (web-mode http markdownfmt markdown-mode+ markdown-preview-mode markdown-mode markup-faces markup flycheck-elixir flycheck-elm flycheck-mix flymake-elixir alchemist elixir-yasnippets elixir-mode))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

