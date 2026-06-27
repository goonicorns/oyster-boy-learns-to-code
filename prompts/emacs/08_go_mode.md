# Emacs Config Lesson 8: Go Mode — Emacs Knows Go

**Context for Claude**

Final Emacs config lesson. Install go-mode and set up gofmt-before-save. This is the bridge between the Emacs configuration work and the Go learning that follows. It's also a good opportunity to teach hooks properly — what they are, how add-hook works, and why this pattern is so common in Emacs config.

**Goal:** Install go-mode, set up gofmt on save, understand hooks, and verify it works on a real Go file.

---

## Why does Emacs need Go mode?

"Right now, if you open a .go file in Emacs, it opens in fundamental-mode — no syntax highlighting, no indentation, nothing Go-specific. Go mode adds:"

- Syntax highlighting for Go keywords, types, functions
- Correct indentation (tabs, not spaces — Go's style)
- `gofmt` integration — automatic formatting on save
- Jump to definition (with additional setup)
- `go-test` integration

"All of this because someone wrote a Go mode package and put it on MELPA."

---

## Install go-mode

```elisp
;; ============================================================
;; GO MODE — Syntax highlighting and tooling for Go
;; ============================================================
(use-package go-mode
  :ensure t
  :hook
  (go-mode . (lambda ()
               (setq tab-width 4)
               (setq indent-tabs-mode t)))
  :config
  (add-hook 'before-save-hook #'gofmt-before-save))
```

Ask about each piece:

"`go-mode` — how does Emacs know which mode to use for .go files?" (packages register file extensions. go-mode registers itself for `*.go` files via `auto-mode-alist`. C-h v auto-mode-alist to see all registered extensions.)

---

## Teach hooks — this is important

"The `:hook` and `add-hook` things — what is a hook?"

"A hook is a list of functions that Emacs calls at a specific moment. Emacs has hooks for almost everything:
- `before-save-hook`: called before any file is saved
- `after-save-hook`: called after any file is saved  
- `go-mode-hook`: called every time a buffer enters Go mode
- `text-mode-hook`: called every time a buffer enters text mode"

Ask: "In our use-package, what does `:hook (go-mode . ...)` do?" (adds the lambda function to `go-mode-hook` — so every time you open a .go file, that lambda runs)

Ask: "What does the lambda function do?" (sets `tab-width` to 4 and `indent-tabs-mode` to t — Go uses real tabs for indentation, 4 columns wide)

Ask: "What is a lambda?" (an anonymous function — a function without a name. `(lambda (args) body)` is like `func(args) { body }` in Go. We use it here because we need a function to add to the hook, but we don't need to name it.)

"Now the second hook: `add-hook 'before-save-hook #'gofmt-before-save`"

Ask: "What does this do?" (every time any file is saved, calls `gofmt-before-save`. That function checks if the current buffer is in go-mode — if so, runs gofmt to format the code.)

Ask: "Why is this in `:config` not `:hook`?" (because `before-save-hook` is global — not specific to go-mode. We're adding gofmt to the global save hook, not to go-mode-hook. gofmt-before-save itself checks if it's in a Go buffer.)

---

## Make sure `gofmt` is available

"gofmt is a Go tool — it formats Go code. Is it installed?"

```bash
# In a terminal (not inside Emacs):
which gofmt
gofmt --version
```

"If Go is installed, gofmt comes with it. If `which gofmt` returns nothing, Go isn't installed yet — we'll do that in the next section."

Ask: "What happens if gofmt isn't installed and you save a .go file?" (Emacs will try to call gofmt, fail, and show an error in the minibuffer. The file still saves — gofmt failure doesn't prevent saving.)

---

## Test it on a real Go file

"Let's create a simple Go file and test that go-mode activates."

```
C-x C-f /tmp/hello.go
```

"Type this (intentionally badly formatted):"

```go
package main
import "fmt"
func main(){
fmt.Println("hello from emacs")
}
```

"Notice: syntax highlighting should appear as you type. Keywords like `package`, `import`, `func` should be colored."

"Now save with C-x C-s."

"Did gofmt run? Check the indentation — it should now have proper Go formatting (the opening `{` should be on the same line as `func main`, and the body should be indented with a tab)."

---

## One more useful Go config

"Two more things that make Go editing much better:"

```elisp
;; If you have gopls (Go language server) installed, enable it:
;; gopls gives you jump-to-definition, documentation on hover, etc.
;; Install gopls: go install golang.org/x/tools/gopls@latest
(use-package eglot
  :ensure t
  :hook (go-mode . eglot-ensure))
```

"eglot is Emacs's built-in language server client (Emacs 29+). When you open a .go file, eglot automatically connects to gopls (if installed) and gives you:
- M-. (jump to definition)
- M-, (jump back)
- C-h . (documentation at point)
- M-x eglot-format (format the file)
- Error highlighting as you type"

Ask: "What is a language server?" (a separate program that understands a programming language and talks to your editor. The editor sends questions: 'what's at this position? what are the errors here?' and the server answers. This is why modern editors feel smart without each one reimplementing all the intelligence.)

Ask: "Do we need this to write Go?" (no — go-mode and gofmt are enough to start. eglot + gopls is a nice upgrade for when you're deeper into projects.)

---

## Complete init.el at this point

At the end of these lessons, their init.el should look roughly like:

```elisp
;; custom-file: keep auto-generated stuff separate
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))

;; MODIFIER KEYS (Mac)
(when (eq system-type 'darwin)
  (setq mac-command-modifier 'meta)
  (setq mac-option-modifier 'super))

;; UI CLEANUP
(scroll-bar-mode -1)
(tool-bar-mode -1)
(setq-default truncate-lines t)
(global-hl-line-mode +1)
(setq-default cursor-type 'box)
(show-paren-mode +1)
(setq inhibit-startup-screen t)
(fset 'yes-or-no-p 'y-or-n-p)
(line-number-mode +1)
(column-number-mode +1)

;; PACKAGE MANAGEMENT
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))
(require 'use-package)
(setq use-package-always-ensure t)

;; WHICH-KEY
(use-package which-key
  :ensure t
  :config (which-key-mode +1))

;; THEMES
(use-package modus-themes
  :ensure t
  :config (load-theme 'modus-vivendi t))

;; HELM
(use-package helm
  :ensure t
  :config (helm-mode +1)
  :bind (("M-x"     . helm-M-x)
         ("C-x C-f" . helm-find-files)
         ("C-x b"   . helm-mini)))

;; CUSTOM FACES (for modeline)
(defface my/modeline-modified
  '((t :foreground "#E06C75" :weight bold)) "")
(defface my/modeline-buffer-name
  '((t :foreground "#61AFEF" :weight bold)) "")
(defface my/modeline-mode
  '((t :foreground "#98C379")) "")
(defface my/modeline-position
  '((t :foreground "#ABB2BF")) "")

;; CUSTOM MODELINE
(defun my/modeline-modified-indicator ()
  (if (buffer-modified-p)
      (propertize " ★ " 'face 'my/modeline-modified)
    (propertize "   " 'face 'my/modeline-position)))

(defun my/modeline-buffer-name ()
  (propertize (buffer-name) 'face 'my/modeline-buffer-name))

(defun my/modeline-mode-name ()
  (propertize (format-mode-line mode-name) 'face 'my/modeline-mode))

(defun my/modeline-position ()
  (propertize (format " %d:%d " (line-number-at-pos) (current-column))
              'face 'my/modeline-position))

(defun my/modeline-render ()
  (list " "
        (my/modeline-modified-indicator)
        " "
        (my/modeline-buffer-name)
        "  "
        (my/modeline-mode-name)
        "  "
        (my/modeline-position)))

(setq-default mode-line-format '(:eval (my/modeline-render)))

;; THEME SELECTOR
(defun my/select-theme ()
  "Select and load a theme using Helm."
  (interactive)
  (let* ((themes (mapcar #'symbol-name (custom-available-themes)))
         (chosen (helm :sources (helm-build-sync-source "Themes"
                                  :candidates themes)
                       :buffer "*helm themes*"
                       :prompt "Theme: ")))
    (when chosen
      (mapc #'disable-theme custom-enabled-themes)
      (load-theme (intern chosen) t))))

(global-set-key (kbd "C-c t") #'my/select-theme)

;; GO MODE
(use-package go-mode
  :ensure t
  :hook (go-mode . (lambda ()
                     (setq tab-width 4)
                     (setq indent-tabs-mode t)))
  :config (add-hook 'before-save-hook #'gofmt-before-save))
```

---

## Final checkpoint — what they now know

Ask them to explain each section of their init file from memory:

1. Why the custom-file line is there
2. What the modifier key section does and why the `when` wrapper
3. What each UI cleanup line removes/enables
4. What MELPA is and why we add it
5. What use-package does differently than package-install
6. What which-key shows them
7. What load-theme does
8. How Helm changes M-x and C-x C-f
9. How defface differs from inline colors
10. How defun, interactive, let*, mapcar, and propertize work together in the theme selector
11. What a hook is and how add-hook works
12. What gofmt does and when it runs

"You've written a real Emacs configuration in a real programming language. Every piece of it you can explain and modify. That's not a small thing."

---

## Now they're ready for Go

"You have Emacs set up, you know how to navigate it and configure it. Now we learn Go — and we'll be writing it in the editor you just built."
