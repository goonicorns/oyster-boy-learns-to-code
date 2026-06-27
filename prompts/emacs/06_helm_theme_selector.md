# Emacs Config Lesson 6: Helm + Theme Selector — Your First Custom Command

**Context for Claude**

Two things happen in this lesson: (1) install Helm, a powerful completion/narrowing framework that transforms M-x and file-finding; (2) write a custom interactive command that uses Helm to let them pick a theme from their installed list. The theme selector is the teaching vehicle for `defun`, interactive commands, and Helm's API. This is their first real piece of Emacs Lisp programming — celebrate it.

**Goal:** Install Helm, understand what it does, write a custom `my/select-theme` command, learn defun and interactive.

---

## What is Helm?

"Right now, when you press M-x or C-x b, Emacs shows a basic completion prompt at the bottom. You type, it suggests. It works, but it's minimal."

"Helm replaces that completion system with a richer interface: as you type, it shows a live-filtered list of all matches. You can use arrow keys to navigate the list. It works for M-x, C-x b (buffer switching), C-x C-f (file finding), and more."

"Think of it like Spotlight search vs just typing a file path. Same destination, much more visibility into your options."

---

## Install Helm

```elisp
;; ============================================================
;; HELM — Completion and narrowing framework
;; ============================================================
(use-package helm
  :ensure t
  :config
  ;; Replace common built-in commands with helm versions
  (helm-mode +1)

  :bind
  ;; Remap the standard commands to helm equivalents
  (("M-x"     . helm-M-x)           ;; command palette with preview
   ("C-x C-f" . helm-find-files)    ;; file finder with live navigation
   ("C-x b"   . helm-mini)          ;; buffer switcher + recent files
   ("C-h f"   . helm-describe-function)  ;; function help with search
   ("C-h v"   . helm-describe-variable))) ;; variable help with search
```

Evaluate this and try M-x. Notice:
- The list appears immediately
- As you type, it narrows in real time
- Arrow keys navigate the list
- Tab completes, Enter selects

Ask: "What does `:bind` do in use-package?" (sets up key bindings — maps key sequences to functions. The dot `.` separates the key from the command it should call.)

Ask: "What does `helm-mode +1` do?" (enables helm globally for many completions, not just the ones we explicitly bind)

---

## Try Helm for file finding

```
C-x C-f
```

"Notice: it starts in your current directory, shows files immediately. Arrow keys navigate. Type to filter. Enter opens."

"Notice also: you can navigate directories by pressing Enter on a directory, or type / to separate path components."

Ask: "How is this different from before?" (before: typed a path blindly. Now: live visual navigation of the filesystem)

---

## Now write a custom command — the theme selector

"Here's where it gets interesting. We're going to write our own M-x command. This is a function you'll call by name from M-x. It uses Helm to show you all your installed themes and let you pick one."

"This is programming. Not a config option — actual code that does something. Let's do it."

---

## Step 1: What should this function do?

Ask them first: "In plain English, what does a theme selector need to do?"

Guide them to:
1. Get a list of all available themes
2. Show that list in a Helm picker
3. When they choose one, load it

---

## Step 2: How to get available themes

"Emacs tracks available themes in a variable. Let's look it up."

```
C-h v custom-available-themes
```

"It's a list of theme names (symbols). So if we have modus and doom themes installed, it will include modus-vivendi, modus-operandi, doom-one, doom-gruvbox, etc."

Ask: "What's the type of each theme name in that list?" (a symbol — like `'doom-one`, `'modus-vivendi`. Remember: symbols are named things, preceded by a quote when you want to treat them as data not code.)

---

## Step 3: Symbols to strings for Helm

"Helm works best with strings for display. We need to convert our list of theme symbols to strings."

Ask: "How do you turn a symbol into a string?" 

Guide toward: `symbol-name` — have them check with C-h f symbol-name.

```elisp
(symbol-name 'doom-one)   ;; → "doom-one"
```

"And to convert a list of symbols to a list of strings, we use `mapcar` — it applies a function to every element of a list."

```elisp
(mapcar #'symbol-name (custom-available-themes))
;; → ("modus-vivendi" "modus-operandi" "doom-one" ...)
```

Ask: "What does `mapcar` remind you of from Go?" (like `for _, theme := range themes { ... }` but returns the results as a new list. In functional programming this is called 'map'.)

Ask: "What is `#'symbol-name`?" (the `#'` prefix is shorthand for `function` — it says 'I want the function object called symbol-name, not a variable named symbol-name'. For mapcar, we need to pass the function itself, not call it.)

---

## Step 4: Write the function

"Now we know how to get the list. Let's write the full function."

Ask them to try writing it before showing them. Give hints:
- "What keyword do you use to define a function in elisp?" (`defun`)
- "The function needs to work with an argument — the chosen theme name. But Helm gives us a string, not a symbol. How do we convert back?" (`intern` — the opposite of `symbol-name`)

Guide them to:

```elisp
;; ============================================================
;; CUSTOM COMMANDS
;; ============================================================

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
```

Walk through EVERY piece. Do not rush this.

---

## Teaching defun

"Let's read this function definition carefully."

```elisp
(defun my/select-theme ()
```

"What does `defun` do?" (defines a function. `my/` is a naming convention — prefix your custom functions with something to avoid clashing with Emacs built-ins. The `/` is valid in function names.)

"The `()` after the name is the argument list. This function takes no arguments."

```elisp
  "Select and load a theme using Helm."
```

"This is the docstring — documentation for the function. C-h f my/select-theme will show this string. Always write docstrings."

Ask: "If you added this function to a library and someone used C-h f, what would they see?" (exactly this string — it's the documentation Emacs shows)

```elisp
  (interactive)
```

"This is crucial. `(interactive)` is what makes a function callable from M-x. Without it, the function exists but you can't run it as a command. With it, Emacs lists it in M-x and you can call it."

Ask: "What would happen if you removed `(interactive)`?" (the function would still work if you call it from code or C-x C-e, but M-x wouldn't find it)

```elisp
  (let* ((themes ...) (chosen ...)) ...)
```

"What is `let*`?" 

Guide them: `let` creates local variables — variables that only exist inside the let block. Like creating variables inside a function in Go.

`let*` (let star) means each binding can see the previous ones — `themes` is available when we define `chosen`.

Ask: "How is this like Go?" (like `themes := ...; chosen := ...` inside a function — local variables that don't exist outside)

```elisp
(mapc #'disable-theme custom-enabled-themes)
```

"Before loading a new theme, we disable all currently active themes. `mapc` is like `mapcar` but we don't care about the return values — we just want the side effect (disabling themes)."

Ask: "What is `custom-enabled-themes`?" (a variable Emacs keeps — a list of currently active themes. C-h v to read about it.)

```elisp
(load-theme (intern chosen) t)
```

"We convert the string back to a symbol with `intern`, then load it. `intern` is the opposite of `symbol-name`."

---

## Evaluate and test

Have them:
1. M-x eval-buffer (or C-x C-e after the function)
2. M-x my/select-theme
3. A Helm picker should appear with all available themes
4. Type to filter, arrow keys to navigate, Enter to select

Ask: "What happens when you select a theme?" (the previous theme is disabled, the new one loads — Emacs colors change immediately)

Ask: "Could you add a keybinding for this?" (yes — add `("C-c t" . my/select-theme)` to their global map. Show them how: `(global-set-key (kbd "C-c t") #'my/select-theme)`)

---

## Teach them what they just did

"Stop and look at what you wrote. You defined a function in a programming language. It:
1. Gets a list of data (available themes)
2. Transforms it (symbol to string with mapcar)
3. Shows it to the user (Helm picker)
4. Responds to user input (disables old, loads new)

This is a complete, useful program. Not a config option — code that does something."

Ask: "What would you change if you wanted to show only themes whose names contain 'dark'?" (filter the list before passing to Helm — `(seq-filter (lambda (x) (string-match-p "dark" x)) themes)`)

---

## Checkpoint

1. "What does `(interactive)` do to a function?"
2. "What is the difference between `mapcar` and `mapc`?"
3. "What does `let*` do?"
4. "How do you convert a symbol to a string? A string back to a symbol?"
5. "What does `#'` mean before a function name?"
