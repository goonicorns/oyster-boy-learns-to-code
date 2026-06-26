# Oyster Boy Learns to Code

A learning kit for two people who have never written code before.

---

## What's in here

| Thing | What it is |
|---|---|
| `cheatsheet.html` | Reference sheet — Unix shell, tmux, Go, Emacs. Open in your browser. |
| `playground/shell/` | Interactive shell tutorial. Run it in a terminal to learn bash. |
| `playground/golang/` | Go exercises. Fix the code, make it run. Like a puzzle. |
| `prompts/` | Instructions for your Claude Code tutor. |

---

## Step 0 — Get this onto your computer

Open a terminal and run:

```bash
git clone https://github.com/goonicorns/oyster-boy-learns-to-code.git
cd oyster-boy-learns-to-code
```

Don't know what a terminal is? On Mac: press `Cmd+Space`, type `Terminal`, press Enter.

---

## Step 1 — Open the cheatsheet

This is your reference. Keep it open in a browser tab the whole time.

```bash
open cheatsheet.html
```

On Linux: `xdg-open cheatsheet.html`  
Or just find the file in Finder/Files and double-click it.

---

## Step 2 — Do the shell tour first

This teaches you how to use the terminal. Run it, pick a lesson, follow along.

```bash
bash playground/shell/shell-tour.sh
```

Pick lessons in order. You can come back to any lesson anytime.

---

## Step 3 — Do the Go exercises

Before this step: make sure Go is installed.  
Check: `go version` — if you see a version number, you're good.  
If not: download Go from [golang.org](https://golang.org/dl/) and install it.

```bash
bash playground/golang/run.sh
```

Start at exercise `00_hello` and work through them in order. Each exercise tells you exactly what to do at the top of the file.

**How it works:**
1. Pick an exercise from the menu
2. Press `e` to open the file in your editor
3. Read the instructions at the top
4. Fill in the `TODO` sections
5. Press `r` to run it — if it works, mark it done and move on

---

## Step 4 — Build the API with Claude Code

Once you've done the exercises, you're ready to build something real: a crypto price monitoring API.

**You'll need Claude Code installed.** If you don't have it:
```bash
npm install -g @anthropic-ai/claude-code
```

Then open Claude Code inside this folder:
```bash
claude
```

Claude will automatically read the instructions in `CLAUDE.md` and act as your tutor. It will NOT write the code for you — it will teach you to write it yourself.

Tell it: `"I'm ready to start lesson 1"`

The lessons live in `prompts/lessons/` — you can read ahead if you want to know what's coming.

---

## Order to do things

```
1. Shell tour         (playground/shell/shell-tour.sh)
      ↓
2. Go exercises       (playground/golang/run.sh)  — exercises 00 through 13
      ↓
3. API project        (open claude in this folder, say "start lesson 1")
```

---

## When you get stuck

- **Shell or tmux:** Check `cheatsheet.html` — the relevant section is there
- **Go syntax:** Check the Go section of `cheatsheet.html`
- **An exercise won't run:** Read the error message — Go errors point to the exact line. Press `h` in the exercise runner for a hint.
- **The API project:** Ask your Claude Code tutor. That's what it's there for.

---

## What you'll build by the end

A real, working web API that:
- Tracks crypto prices (fetched live from the internet)
- Has user accounts with login
- Uses a real database (PostgreSQL in Docker)
- Is tested with curl
- Has unit tests
- Is tracked with git

None of that will sound scary by the time you get there.
