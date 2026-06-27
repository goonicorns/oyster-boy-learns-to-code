# Emacs Config Lesson 2: Modifier Keys — Making Mac Feel Right

**Context for Claude**

On a Mac, the default Emacs modifier key mapping is awkward: Meta (M-) is bound to the Option/Alt key, which conflicts with Mac shortcuts and special characters. The fix is to swap it so Command = Meta and Option = Super. This is almost always already set up, but they need to understand WHY and be able to verify it.

**Goal:** Check current modifier key mapping, understand what Meta and Super are, confirm or add the mapping.

---

## What are modifier keys in Emacs?

"In Emacs, keys are described using abbreviations for modifier keys:
- C- means Control
- M- means Meta (the old Lisp Machine key — doesn't exist on modern keyboards)
- S- means Shift
- s- means Super (lowercase s — the old Sun workstation modifier key)

On Mac, we have to MAP these to physical keys."

Ask: "What physical key on a Mac keyboard would you want to use for the most-used modifier (M-)?"

Guide toward: Command. It's the most prominent modifier, right next to the space bar on both sides. Option is in an awkward position and already does special character input on Mac.

---

## Check what's already set

```elisp
;; In Emacs, check current setting:
;; C-h v mac-command-modifier
;; C-h v mac-option-modifier
```

Have them press C-h v and type `mac-command-modifier`. Look at the value.

"What does it say?" If it's already set to `meta`, great. If it's `super` or something else, we need to fix it.

---

## Set the modifier keys

Have them add this to their init file:

```elisp
;; ============================================================
;; MODIFIER KEYS (Mac)
;; Command key → Meta (the main Emacs modifier, used for M-x etc.)
;; Option key  → Super (less-used, available for custom bindings)
;; ============================================================
(when (eq system-type 'darwin)   ;; only on Mac
  (setq mac-command-modifier 'meta)
  (setq mac-option-modifier 'super))
```

Ask about each piece:

"What does `when` do?" (runs the body only if the condition is true — like `if` but without an else branch)

"What does `(eq system-type 'darwin)` mean?" (checks if the system-type variable equals the symbol 'darwin — which is what macOS reports)

Ask: "Why do we use `when` instead of just setting it unconditionally?" (if someone else uses this init file on Linux or Windows, setting mac-command-modifier would either error or do nothing — the `when` makes it safe and self-documenting)

"What is `'darwin`? What's the single quote?" (the quote means 'don't evaluate this as code, treat it as a literal symbol name'. In elisp, symbols are like named constants. `'darwin` is the symbol `darwin`, not a variable named darwin.)

---

## Evaluate and test

Have them M-x eval-buffer to reload.

Test: try pressing Command+x (which should now act as M-x). They should see the M-x prompt at the bottom.

Test: try pressing Option+f (which should now act as s-f — super+f). It shouldn't do anything special, which is correct — Super bindings are rarely used by default.

---

## Why does this matter?

"Now that Command = Meta, your muscle memory from Command+C/V for copy/paste is going to interfere a tiny bit. In Emacs, M-w is copy and C-y is paste. Command+C and Command+V will do M-w and... well, V doesn't map to anything by default.

You have two choices:
1. Learn the Emacs way (M-w, C-y) — recommended long term
2. Add Command+C/V bindings to Emacs — easy but fights the grain of Emacs

We'll use the Emacs way. It feels weird for a week. After that, it feels better than anything else."

---

## A note on `ns-command-modifier` vs `mac-command-modifier`

"You might see either spelling in config examples online. `ns-` prefix comes from 'NeXTStep' (the OS that became macOS). `mac-` prefix is Emacs-specific. In modern Emacs (27+), either works. Use `mac-command-modifier` — it's more common in recent configs."

---

## Checkpoint

They should be able to say:
1. "What does M- stand for in Emacs key notation?"
2. "Which physical Mac key maps to Meta after our config?"
3. "What does `'darwin` mean and why the quote?"
4. "Why do we wrap the setting in `(when (eq system-type 'darwin) ...)`?"
