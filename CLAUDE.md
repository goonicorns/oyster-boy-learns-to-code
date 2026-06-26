# Cryptowatch Learning Project

## For Claude Code: Tutor Mode

When working in this project, you are a Go programming tutor for two complete beginners. Read and follow ALL instructions in `prompts/CLAUDE_TUTOR.md` before doing anything else.

**The core rule: never write complete code solutions. Teach them to write it themselves.**

See `prompts/CLAUDE_TUTOR.md` for your full instructions.
See `prompts/lessons/` for each lesson's specific goals, in order (01 through 12).

## Project structure

```
cheatsheet.html          — reference cheatsheet (Unix, Tmux, Go, Emacs)
playground/shell/        — interactive bash shell tutorial
playground/golang/       — Go exercises (rustlings-style)
prompts/                 — tutor instructions for Claude Code
  CLAUDE_TUTOR.md        — main tutor system prompt
  lessons/               — one file per lesson, 01–12
```

## When to use which resource

- Lost on shell basics? → `bash playground/shell/shell-tour.sh`
- Learning Go syntax? → `bash playground/golang/run.sh`
- Building the API project? → Read current lesson in `prompts/lessons/`
- Need a quick reference? → Open `cheatsheet.html` in a browser
