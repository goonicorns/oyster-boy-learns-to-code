# Emacs Config Lesson 1: The Init File — Where Emacs Gets Its Instructions

**Context for Claude**

The learner just finished the Emacs tour. They can navigate and edit. Now they're going to learn how to configure Emacs by writing Emacs Lisp (elisp). This is their first real exposure to a programming language in a configure-first context. Every configuration step should be taught, not just given. They must type every line themselves and understand what it does before moving on.

**Goal:** Find/create the init file, learn the basics of elisp syntax, evaluate code, and use the help system.

---

## Before typing a single line — what IS the init file?

"When Emacs starts, before it shows you anything, it runs a file of code called the init file. That code runs every time Emacs opens. It's where you tell Emacs how you want it to behave."

"Think of it like this: Emacs is a blank slate. Your init file is your list of instructions that runs at the start of every session. Want the scroll bar gone? Put that instruction in the init file. Want a theme loaded? Put it there. Want a keybinding? There."

Ask: "Where does that file live?"

Answer: on Mac (and Linux), Emacs looks for it in this order:
1. `~/.emacs` (old style — don't use this)
2. `~/.emacs.d/init.el` (common)
3. `~/.config/emacs/init.el` (modern, Emacs 29+)

"We'll use `~/.config/emacs/init.el` — the modern location."

---

## Open the init file

```
In Emacs:
C-x C-f ~/.config/emacs/init.el
```

"If it doesn't exist yet, Emacs will create an empty buffer for it. If it exists, you'll see what's already there."

Ask: "What does C-x C-f actually do?" (opens a file — 'find file'. If the file doesn't exist, it creates a new empty buffer. It only physically creates the file when you save with C-x C-s.)

---

## Elisp basics — the language of Emacs config

"The init file is written in Emacs Lisp — called elisp. It looks strange at first because everything is in parentheses. But there are only a few patterns you need."

**Pattern 1: Calling a function**
```elisp
(function-name argument1 argument2)
```

"This calls `function-name` with two arguments. The function name and all arguments go inside one pair of parentheses. Everything in elisp is a list surrounded by parentheses."

Ask: "What would `(+ 2 3)` mean in elisp?" (calling the + function with arguments 2 and 3 — it gives you 5)

**Pattern 2: Setting a variable**
```elisp
(setq variable-name value)
```

"setq means 'set quote'. It sets a variable to a value. The 'q' historically stands for 'quoted' — don't worry about that. Just know that `setq` is how you assign values to variables in elisp."

Ask: "How is this different from `=` in other languages?" (in Go you'd write `var x = 5`. In elisp: `(setq x 5)`. Same idea, different syntax.)

**Pattern 3: Comments**
```elisp
;; This is a comment. Two semicolons is the convention.
; One semicolon works too.
```

"The semicolon starts a comment. Emacs ignores everything from ; to the end of the line."

**Pattern 4: True and false**
```elisp
t    ;; true
nil  ;; false (also means "nothing", "empty", "null")
```

---

## Evaluating code — making it actually run

"You have code in the init file. How do you make it run without restarting Emacs?"

Three ways:

**Evaluate the expression before the cursor:**
```
Place cursor right after a closing parenthesis: (setq x 5)|
Then press: C-x C-e
```
"C-x C-e evaluates the last expression. The cursor must be right after the closing paren."

**Evaluate the entire buffer:**
```
M-x eval-buffer
```
"Runs every expression in the current buffer from top to bottom."

**Evaluate a region (selected text):**
```
Select some code with C-SPC, then:
M-x eval-region
```

Ask: "When would you use each?" 
- C-x C-e: testing one specific expression quickly
- eval-buffer: after changing the whole init file, to reload it
- eval-region: testing a block of new code without running the whole file

---

## Try it — your first elisp evaluation

Have them type this into their init file:

```elisp
;; Test line — we'll remove this after
(message "Hello from my init file!")
```

Then C-x C-e with the cursor after the closing paren.

"Look at the very bottom of the screen — the echo area. You should see 'Hello from my init file!'"

Ask: "What did `message` do?" (displayed text in the echo area — like console.log or fmt.Println, but in Emacs's status bar)

Have them delete that test line. We don't need it permanently.

---

## The help system as a learning tool

"Before we write real config, learn how to look things up. This is more important than any specific configuration."

**C-h f — describe function:**
- Press C-h f
- Type `setq` — wait, setq is special syntax, not a function. Try `message`.
- Read what it says. Every function has documentation.

**C-h v — describe variable:**
- Press C-h v
- Type `cursor-type`
- It shows: the current value, what values are allowed, and what it does.

**C-h k — describe key:**
- Press C-h k, then press C-x C-e
- It tells you exactly what that key binding calls

Make them practice each of these before continuing. Say: "For the rest of these lessons, whenever we introduce a new function or variable, look it up with C-h. Don't just take my word for it — Emacs will show you the full documentation."

---

## A note on reloading

"For most changes we make, you can reload with M-x eval-buffer. For some changes (like enabling/disabling modes at startup), you may need to restart Emacs entirely. When in doubt, restart."

```
C-x C-c   →   reopen Emacs
```

---

## First real line: keep the init file clean

```elisp
;; Don't put auto-generated customization here — use a separate file
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
```

Type this, then C-x C-e, then C-x C-s to save.

Ask: "What does this do?" 
Guide them: Emacs has a GUI customization system (M-x customize) that auto-generates code and dumps it into your init.el. This line tells Emacs to use a separate file for that, so our hand-written init stays clean.

Ask: "What is `user-emacs-directory`?" (a variable Emacs sets to ~/.config/emacs/ — you can check it with C-h v user-emacs-directory)

Ask: "What is `expand-file-name`?" (builds a complete path by combining a filename and a directory — C-h f expand-file-name to see more)

---

## Checkpoint before moving on

They should be able to answer:
1. "What is the init file and where does it live?"
2. "What does `setq` do?"
3. "How do you evaluate a single expression without restarting Emacs?"
4. "How do you look up what a function does?"
5. "How do you look up what a variable's current value is?"

Don't proceed until they can answer all five.

---

## Commit checkpoint

```bash
git add ~/.config/emacs/init.el
git commit -m "Start Emacs config — init file basics"
```
(Or: have them create a `dotfiles` repo for their config — but don't require it for this lesson.)
