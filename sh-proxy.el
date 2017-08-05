;; sh-proxy.el -- experiment with elisp proxies for shell commands
;; License: GPL-3+
;;; Commentary:
;; 
;; (sh-proxy-create "df") defines a function sh/df
;; which takes keyword args corresponding to the flags of df.
;; eldoc works and function docstring

;; motivation: rather than a bunch of ugly notes like these:

;; export X=zen-mode
;; export USR=jave
;; export PASSWD=notmyactualpwd
;; ;mkdir $X
;; cd $X
;; ln -s *.el README
;; git init
;; git add .
;; git commit -m"initial commit"
;; curl -u "$USR:$PASSWD" -F "name=$X"  http://github.com/api/v2/json/repos/create/
;; git remote add origin git@github.com:jave/$X.git
;; git push origin master

;; Id like nice lisp:

;; (defun github-init-proj (x usr passwd)
;;   (cd x)
;;   (sh/ln :s "*.el" "README")
;;   (sh/git-init)
;;   (sh/git-add ".")
;;   (sh/git-commit :m "initial commit")
;;   (sh/curl :u (concat usr ":" passwd) :F (concat "name=" x)  "http://github.com/api/v2/json/repos/create/")
;;   (sh/git-remote :add "origin" (format "git@github.com:jave/%s.git" x))
;;   (sh/git-push "origin" "master"))

;; sh-proxy currently works somewhat with gnu style help output,
;; but not gits man style help output.

;; sh-proxy.el was inspired by dbus-proxy.el

;;; Code:

(defun sh-proxy-parse-help (command)
  "Run COMMAND --help, parse the output and return a list of flags.
Assumes output according to GNU standards."
  ;;look in col 2 and 6 for -
  (with-current-buffer (get-buffer-create  " *sh-proxy*")
    (erase-buffer)
    (process-file-shell-command command nil t nil "--help")
    (goto-char (point-min))
    (let
        ((args))
      ;;this regexp whas briefly tested on "ls --help" with re-builder
      (while (re-search-forward "^\\(  -\\(.\\). \\|      \\)\\(--\\([^ =[\n]*\\)\\|                \\)" nil t)
        (sh-proxy-parse-help-2 2)
        (sh-proxy-parse-help-2 4)
        )
      (cons (buffer-string) args))))

(defun sh-proxy-parse-help-2 (match-id)
  "Fiddle out info from help match MATCH-ID."
  (let*
      ((flag (match-string match-id)))
    (if flag
        (progn
          (setq args (append args (list (intern  flag))))))))

(defun sh-proxy-argstr (args)
  "Convert ARGS list to a string."
  (mapconcat 'sh-proxy-sym2flag args " ") )


(defun sh-proxy-sym2flag  (x)
"Massage arg X. Convert symbols to flags. :a or -a becomes -a. Longer symbols such as :aa becomes --aa.
Non symbols are untouched."
  (if (symbolp x)
      (concat (if (>  (length (symbol-name x)) 2) "--" "-") (substring (symbol-name x) 1))
    x))

(defun sh-proxy-create (command)
  "Defines a sh proxy, which will have the name sh/COMMAND."
  (eval `(defun ,(intern (concat "sh/" command)) (&rest rest)
           ,(concat (car (sh-proxy-parse-help command)) "\n\n(fn &key" (mapconcat  'symbol-name (cdr (sh-proxy-parse-help command)) " ") ")" )
        (apply 'eshell-command (concat ,command " " (sh-proxy-argstr rest)) nil))))

;;yeah, so far so good, but what about:
;; - piping? we would like the lisp syntax to be functional still (have a look at reusing eshell)
;; - stdin stdout? again, eshell
;; - other types help output?


(provide 'sh-proxy)

;;; sh-proxy.el ends here
