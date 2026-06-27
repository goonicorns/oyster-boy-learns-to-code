# Emacs Config Lesson 3: UI Cleanup — Removing the Junk

**Context for Claude**

Default Emacs looks ugly. Scroll bars, toolbars, and menu bars eat screen space and aren't useful once you know keybindings. This lesson removes them. More importantly: every line of config is understood BEFORE it's typed. This is also the lesson where they learn the difference between `setq`, `setq-default`, and calling a mode function.

**Goal:** Clean up the Emacs UI. Teach `setq` vs `setq-default` vs mode functions. Understand the difference between global and buffer-local settings.

---

## Start by looking at the problem

"Look at your Emacs window right now. What do you see that seems unnecessary?"

Guide them to notice:
- The scroll bar on the right (or left)
- The toolbar at the top with icons (bold, italic, open file, etc.)
- Possibly the menu bar (File, Edit, View...)

"We're going to remove all of these. But first — why are they there?"

"They're there because Emacs has been around since 1976. These UI elements were added for users who didn't know the keybindings. Once you know the keybindings — which you do now — they're just noise."

---

## Three different ways to configure in elisp

Before writing any config, teach the three patterns they'll use:

**Pattern A: Calling a mode function**
```elisp
(scroll-bar-mode -1)
```
"Some features in Emacs are 'modes' — they can be on or off. You toggle them by calling a function with the same name. Passing -1 turns it OFF. Passing +1 turns it ON. Passing no argument toggles it."

Ask: "How would you turn scroll-bar-mode ON?" (`(scroll-bar-mode +1)` or `(scroll-bar-mode 1)`)

Ask: "How would you check if it's currently on or off?" (C-h v scroll-bar-mode — it's a variable AND a function)

**Pattern B: setq — sets a variable globally**
```elisp
(setq variable-name value)
```
"Sets this variable for the entire Emacs session. Most settings are global."

**Pattern C: setq-default — sets the DEFAULT for buffer-local variables**
```elisp
(setq-default variable-name value)
```
"Some variables are 'buffer-local' — each buffer can have its own value. `truncate-lines` is like this: one buffer might want line wrapping, another might not. `setq-default` sets what value NEW buffers start with."

Ask: "What's the difference between setq and setq-default?" (setq sets it for THIS buffer or globally. setq-default sets the default for all new buffers. For most settings, they work the same — but for buffer-local variables, you need setq-default to affect all buffers, not just the current one.)

---

## Write the UI cleanup, one line at a time

Have them type each line, understand it, then evaluate it immediately with C-x C-e before moving to the next.

```elisp
;; ============================================================
;; UI CLEANUP — Remove default chrome we don't need
;; ============================================================

;; Remove the scroll bar — we use C-v/M-v for scrolling
(scroll-bar-mode -1)
```

After they type and evaluate this: "Look at your Emacs window. Did the scroll bar disappear?"

If not: restart Emacs. Some UI changes only take effect on startup.

Ask: "Why would some changes only work on startup?" (some modes set up UI at initialization time — calling the mode function later can undo the setup, but the visual element was already drawn)

```elisp
;; Remove the toolbar — icons for bold/italic/save/etc we don't need
(tool-bar-mode -1)
```

Evaluate. Toolbar should disappear.

Ask: "Is there anything you'd actually miss from the toolbar?" (probably not — everything on it has a keybinding)

```elisp
;; Remove the menu bar (optional — some beginners like to keep it)
;; Remove it when you know Emacs well enough
;; (menu-bar-mode -1)
```

"We're COMMENTING THIS OUT for now. The menu bar has 'Help' and 'File' menus that are actually useful for beginners finding things. Once you're confident, uncomment this line."

Ask: "How do you uncomment a line in elisp?" (remove the ;; at the start, or select it and M-x uncomment-region)

```elisp
;; Disable line wrapping by default
;; Long lines will extend off screen (use C-l and horizontal scrolling)
;; Some modes (like text editing) can override this
(setq-default truncate-lines t)
```

Evaluate. Now open a file with a very long line — does it extend off screen instead of wrapping?

Ask: "Why is `t` the value here?" (in elisp, `t` is true. This variable controls whether lines truncate (t) or wrap (nil).)

Ask: "Why setq-default instead of setq?" (truncate-lines is buffer-local — each buffer has its own value. setq-default sets the default for all new buffers. setq would only affect the current buffer.)

```elisp
;; Highlight the current line
(global-hl-line-mode +1)
```

"This draws a subtle background color on whatever line your cursor is on. Makes it easier to track your position in a file."

Evaluate. Does a highlight appear on the current line?

```elisp
;; Cursor style
;;(setq-default cursor-type 'hbar)          ;; horizontal bar
(setq-default cursor-type 'box)             ;; filled box (default, but explicit)
;;(setq-default cursor-type '(hbar . 3))    ;; thin horizontal bar, 3px
```

"Emacs lets you choose your cursor shape. We're going with 'box' — a solid filled cursor. The other options are commented out so you can see them and try them later."

Ask: "What does the `. 3` in `'(hbar . 3)` mean?" (it's a 'cons cell' — elisp's basic data pair. In this case, it means an hbar cursor with height 3 pixels. We'll learn more about cons cells when we build the modeline.)

---

## A few more useful defaults while we're here

```elisp
;; ============================================================
;; SENSIBLE DEFAULTS
;; ============================================================

;; Show matching parentheses
(show-paren-mode +1)

;; Don't show the startup splash screen
(setq inhibit-startup-screen t)

;; Shorter yes/no prompts (type y or n instead of yes or no)
(fset 'yes-or-no-p 'y-or-n-p)

;; Show line and column numbers in the mode line
(line-number-mode +1)
(column-number-mode +1)
```

Ask about each:
- "`show-paren-mode` — why is this useful for programming?" (shows you the matching open/close paren when your cursor is on one — essential for elisp and eventually for any code)
- "What is `inhibit-startup-screen`?" (the variable that controls whether Emacs shows the 'Welcome to Emacs' splash on startup — C-h v to read about it)
- "What does `fset` do?" (sets a function definition — it replaces the `yes-or-no-p` function with the `y-or-n-p` function, so any time Emacs would ask "yes or no", it now accepts "y or n")

---

## Putting it all together

At this point their init file should have:
1. The custom-file line (from lesson 1)
2. Modifier key config (from lesson 2)
3. UI cleanup (this lesson)

Have them save: C-x C-s

Then M-x eval-buffer to reload everything.

Then restart Emacs to confirm it all applies on startup too.

---

## Checkpoint

Before moving on, they should be able to:
1. "What does `(scroll-bar-mode -1)` do? What would `+1` do?"
2. "When do you use `setq` vs `setq-default`?"
3. "What does `t` and `nil` mean in elisp?"
4. "How do you evaluate all your config changes without restarting Emacs?"
5. "How do you comment out a line of elisp?"
