;;; markdownfmt-autoloads.el --- automatically extracted autoloads
;;
;;; Code:

(add-to-list 'load-path (directory-file-name
                         (or (file-name-directory #$) (car load-path))))


;;;### (autoloads nil "markdownfmt" "markdownfmt.el" (0 0 0 0))
;;; Generated autoloads from markdownfmt.el

(autoload 'markdownfmt-format-buffer "markdownfmt" "\
Format the current buffer using markdownfmt.

\(fn)" t nil)

(autoload 'markdownfmt-enable-on-save "markdownfmt" "\
Run markdownfmt when saving buffer.

\(fn)" t nil)

(if (fboundp 'register-definition-prefixes) (register-definition-prefixes "markdownfmt" '("markdownfmt-")))

;;;***

;; Local Variables:
;; version-control: never
;; no-byte-compile: t
;; no-update-autoloads: t
;; coding: utf-8
;; End:
;;; markdownfmt-autoloads.el ends here
