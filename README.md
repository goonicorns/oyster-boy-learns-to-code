# Oyster Boy Learns to Code

A learning kit for two people who have never written code before.

---

## Get this onto your computer

Open a terminal. On Mac: press `Cmd+Space`, type `Terminal`, press Enter.

```bash
git clone https://github.com/goonicorns/oyster-boy-learns-to-code.git
cd oyster-boy-learns-to-code
```

---

## Start here — one command

```bash
bash start.sh
```

That's it. Claude Code opens and takes over from there.

Claude is your tutor. It tells you what to do next. You don't need to figure anything out on your own — that's the whole point.

---

## What you need installed before starting

**Claude Code** (the thing that makes this work):
```bash
npm install -g @anthropic-ai/claude-code
```

**Go** (the programming language):
Download from [golang.org/dl](https://golang.org/dl/) and install it.
Check it worked: `go version`

**Emacs** (your code editor):
```bash
brew install --cask emacs
```
Or download from [emacsformacosx.com](https://emacsformacosx.com)

---

## What's in here

| Thing | What it is |
|---|---|
| `start.sh` | Run this to start. Claude takes over. |
| `cheatsheet.html` | Reference sheet for everything. Open in browser. |
| `playground/shell/` | Interactive terminal tutorial |
| `playground/emacs/` | Interactive Emacs tutorial |
| `playground/golang/` | Go exercises, one at a time |
| `prompts/` | Claude's lesson files (don't worry about these) |

---

## What you'll build

Three real projects, built in order:

1. **Crypto price monitoring API** — a web server that tracks prices, stores them in a database, and has user accounts with login
2. **Technical analysis engine** — computes moving averages and price indicators on top of the API
3. **Real-time chat server** — WebSockets, rooms, message history, a frontend you can open in two browser tabs and watch messages appear instantly

None of that will sound scary by the time you get there.
