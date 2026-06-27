# Emacs Config Lesson 4: use-package — Installing Packages

**Context for Claude**

This is the gateway to the entire Emacs package ecosystem. The learner needs to understand what a package is, what MELPA is, how package.el works, and how use-package simplifies package declarations. This is abstract at first — make it concrete by installing something immediately after setting it up. In Emacs 29+, use-package is built in, which simplifies things greatly.

**Goal:** Set up package.el with MELPA, understand use-package syntax, install one package to prove it works.

---

## What is a package?

"Emacs is extensible. People write code that adds features to Emacs and share it. These are called packages."

"A package is a collection of elisp files that adds something to Emacs. Go mode (syntax highlighting for Go) is a package. Doom themes (a collection of color themes) is a package. Helm (a completion system) is a package."

"Where do packages come from? From a package repository — a server that hosts packages."

Ask: "What's the equivalent in Go?" (Go modules — the packages you install with `go get`. The repository is pkg.go.dev or GitHub.)

---

## MELPA — the main package repository

"The main Emacs package repository is called MELPA (Milkyway Emacs Lisp Package Archive). It has 5000+ packages. Everything we'll install today comes from there."

"There's also GNU ELPA (the official GNU one, more conservative, fewer packages) and NonGNU ELPA. We'll add MELPA since it has everything we need."

---

## Setting up package.el

"Emacs has a built-in package manager called `package.el`. We need to tell it about MELPA and initialize it."

Have them add to their init file:

```elisp
;; ============================================================
;; PACKAGE MANAGEMENT
;; ============================================================

;; package.el is built into Emacs — just configure it
(require 'package)

;; Add MELPA to the list of repositories
(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/") t)

;; Initialize the package system
(package-initialize)

;; Refresh the package list if we don't have it yet
(unless package-archive-contents
  (package-refresh-contents))
```

Ask about each piece:

"`(require 'package)` — what does require do?" (loads a feature/library. 'package is the built-in package management system. We're telling Emacs to load it before we try to use it.)

"`(add-to-list 'package-archives ...)` — what's a list here?" (package-archives is a list of (name . url) pairs. We're adding a new pair for MELPA. The `t` at the end means 'add at the end' rather than the beginning.)

Ask: "What is `'("melpa" . "https://melpa.org/packages/")`?" (a cons cell — a pair of two things. The dot separates the two parts. The car (first part) is the name "melpa", the cdr (second part) is the URL. C-h f add-to-list to read more.)

"`(package-initialize)` — what does this do?" (sets up the package system, loads package information from disk, makes installed packages available)

"`(unless package-archive-contents ...)` — explain unless and the condition" (unless is like `when` but inverted — it runs the body when the condition is FALSE. package-archive-contents is nil if we've never downloaded the package list. So: if we don't have the package list, download it.)

---

## use-package — the cleaner way to declare packages

"Now we can install packages with `M-x package-install`. But there's a better way called `use-package`."

"use-package is a macro that lets you declare packages in a clean, consistent way. Instead of scattered calls to package-install, load-path changes, and require statements, you have one unified block per package."

**Check if use-package is available:**

In Emacs 29+, use-package is built in. Check:
```elisp
;; In *scratch* buffer, evaluate:
(featurep 'use-package)
;; If it returns t, you have it built in.
```

Ask: "What does `featurep` do?" (checks if a feature is currently loaded — returns t or nil. C-h f featurep to read more.)

**If Emacs 29+ (use-package built in):**
```elisp
;; use-package is built into Emacs 29+ — just configure it
(require 'use-package)
(setq use-package-always-ensure t)  ;; auto-install packages if not present
```

**If older Emacs (needs installing):**
```elisp
;; Install use-package if not present
(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)
```

Ask: "`(package-installed-p 'use-package)` — what does this do?" (checks if the use-package package is already installed — returns t or nil)

Ask: "What does `use-package-always-ensure t` mean?" (tells use-package to automatically install any package you declare if it's not already installed — so you never have to manually run package-install)

---

## The use-package syntax

"Here's what a use-package declaration looks like. We'll use a simple example first:"

```elisp
(use-package some-package
  :ensure t              ;; install if not present (redundant with always-ensure, but explicit)
  :init                  ;; code to run BEFORE loading the package
    (setq some-setting t)
  :config                ;; code to run AFTER loading the package
    (some-package-mode +1)
  :bind                  ;; key bindings to set up
    ("C-c s" . some-command)
  :hook                  ;; hooks to add
    (text-mode . some-package-mode))
```

"You don't need all of these. Most packages only need `:ensure t` and `:config`."

Ask: "What's the difference between `:init` and `:config`?" (`:init` runs before the package loads — use it for settings the package reads at load time. `:config` runs after the package loads — use it for setup that requires the package to already be loaded.)

Ask: "What's a hook?" (a list of functions that Emacs runs at a specific moment. `text-mode-hook` runs whenever you open a text file. `:hook (text-mode . some-package-mode)` means "add some-package-mode to text-mode-hook".)

---

## Install your first real package — which-key

"Let's install a package to prove this works. `which-key` shows available key completions as you type partial commands. Press C-x and wait a second — a popup shows all the things you can press next."

```elisp
;; which-key: shows available keybindings after a prefix key
(use-package which-key
  :ensure t
  :config
  (which-key-mode +1))
```

Have them type this, evaluate it (C-x C-e or M-x eval-buffer), and then:

- Press C-x and wait
- A popup appears at the bottom showing all C-x key options

Ask: "What does this tell you about Emacs?" (there are thousands of keybindings — which-key makes them discoverable without memorization)

Ask: "What did use-package do here?" (checked if which-key was installed, installed it from MELPA if not, loaded it, then ran the `:config` block which enables the mode)

---

## Where packages are stored

"Packages download to `~/.emacs.d/elpa/` (or `~/.config/emacs/elpa/`). You can C-x d there to see them."

"You never need to edit these files. Just know they're there."

---

## Checkpoint

They should be able to answer:
1. "What is MELPA?"
2. "What does `package-initialize` do?"
3. "What does `use-package-always-ensure t` mean?"
4. "What's the difference between `:init` and `:config` in use-package?"
5. "How would you install a package called `rainbow-delimiters` and enable it globally?"
