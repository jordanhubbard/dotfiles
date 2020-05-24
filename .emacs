(require 'package)
(let* ((no-ssl (and (memq system-type '(windows-nt ms-dos))
		    (not (gnutls-available-p))))
       (proto (if no-ssl "http" "https")))
  (when no-ssl (warn "\
Your version of Emacs does not support SSL connections,
            which is unsafe because it allows man-in-the-middle attacks.
        There are two things you can do about this warning:
        1. Install an Emacs version that does support SSL and be safe.
        2. Remove this warning from your init file so you won't see it again."))
  (add-to-list 'package-archives (cons "melpa" (concat proto "://melpa.org/packages/")) t)
  ;; Comment/uncomment this line to enable MELPA Stable if desired.  See `package-archive-priorities`
  ;; and `package-pinned-packages`. Most users will not need or want to do this.
  ;;(add-to-list 'package-archives (cons "melpa-stable" (concat proto "://stable.melpa.org/packages/")) t)
  )
(package-initialize)

(font-lock-mode t)
(desktop-save-mode 1)

(global-set-key "\M-g" 'goto-line)
(global-set-key "\C-c\C-w" 'write-region)
(global-set-key "\C-c\C-z" 'compile)
(global-set-key "\C-c\C-k" 'kill-compilation)

;; I should make this actually use the more "interesting" CC mode hooks to also reformat expressions and such.
(defun frob-buffer ()
  (interactive)
  (goto-line 1)
  (while (not (eobp))
    (indent-for-tab-command)
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

(add-to-list 'load-path "~/.emacs.d/julia-emacs")
(require 'julia-mode)
