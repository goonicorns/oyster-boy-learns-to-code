# Emacs Config Lesson 5: Themes — Making Emacs Look Good

**Context for Claude**

Themes are a great early win — the learner gets visible, satisfying results immediately. This lesson installs a theme package, teaches load-theme, and sets a default theme. It also reinforces use-package from the previous lesson. Recommend modus-themes first (they're built into Emacs 29+), then doom-themes as a backup with more variety. Let them choose what they like.

**Goal:** Install a theme package, understand load-theme, pick a theme they like, make it load on startup.

---

## What is a theme in Emacs?

"A theme in Emacs is a collection of 'faces'. A face is a set of visual properties — foreground color, background color, bold, italic — applied to a specific type of text."

"For example, the face `font-lock-keyword-face` controls how keywords like `func`, `if`, `return` look in code. A theme sets the colors for all faces consistently."

"Emacs ships with some built-in themes. Type M-x load-theme and Tab to see them. But the community-made themes are much nicer."

---

## Three great theme packages

**modus-themes** (built into Emacs 29+)
- Designed to meet WCAG AAA accessibility contrast requirements
- Very high contrast, extremely readable
- `modus-operandi` (light) and `modus-vivendi` (dark)
- Feels professional and calm

**ef-themes** (from the same author as modus)
- More varied color palettes, still accessible
- Good if modus feels too austere

**doom-themes** (from the Doom Emacs project)
- 60+ themes, very popular
- `doom-one`, `doom-gruvbox`, `doom-nord`, `doom-solarized-dark` are all great
- Good if they want more variety

---

## Install modus-themes (simplest — might be built in)

```elisp
;; ============================================================
;; THEMES
;; ============================================================

;; modus-themes: accessible, professional, built into Emacs 29+
(use-package modus-themes
  :ensure t   ;; installs from MELPA if not built-in
  :config
  ;; Load the dark theme by default
  (load-theme 'modus-vivendi t))
```

Have them type this, evaluate it, and look at the result.

Ask: "What does `load-theme` do?" (C-h f load-theme — activates a named theme, applying all its face settings)

Ask: "What does the `t` argument to `load-theme` mean?" (the second argument is `NO-CONFIRM` — passing t means "don't ask me if I trust this theme, just load it". Without it, Emacs asks every time.)

---

## Try some themes

"Let's look at your options. Type:"

```
M-x load-theme [Tab]
```

"Tab shows all available themes. Try a few:"

Built-in themes to try:
- `modus-vivendi` (dark, built-in)
- `modus-operandi` (light, built-in)
- `tango-dark` (decent built-in)
- `wombat` (built-in dark)

If they installed doom-themes, suggest:
- `doom-one` (dark purple-ish)
- `doom-gruvbox` (warm earthy tones)
- `doom-nord` (cool blue-grey)
- `doom-solarized-dark` (classic)

Ask: "How do you switch back if you don't like one?" (M-x load-theme, pick another — or M-x disable-theme to turn the current one off)

---

## Also try doom-themes for more variety

```elisp
;; doom-themes: 60+ high-quality themes (optional — install if you want variety)
(use-package doom-themes
  :ensure t
  :config
  ;; Global settings (defaults are usually fine)
  (setq doom-themes-enable-bold t
        doom-themes-enable-italic t)
  ;; Set your preferred theme here
  (load-theme 'doom-one t))
```

"You don't need both. Pick one package and stick with it. We'll build a theme selector in the next lesson so you can switch easily."

---

## Pick one and commit

Ask: "Which theme do you want as your default? Try a few and decide."

Once they've chosen, make sure their `load-theme` call reflects that choice in the `:config` block. Have them save and restart Emacs to confirm it loads on startup.

---

## A note on transparent backgrounds

"Some themes on Mac look different depending on whether Emacs was launched as a GUI or from the terminal. The GUI version always looks better for themes."

"If colors look wrong: make sure you're using the GUI Emacs (`open -a Emacs`) not terminal Emacs."

---

## Checkpoint

1. "What is a theme in Emacs — what does it actually control?"
2. "How do you temporarily try a different theme without changing your config?"
3. "What does the second argument `t` in `(load-theme 'modus-vivendi t)` do?"
4. "How do you make a theme persist across restarts?"
