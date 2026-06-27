# Oyster Boy Learns to Code

---

## Before anything else — install these three things

You need these installed on your computer. Do this first.

### 1. Node.js
Download and install from [nodejs.org](https://nodejs.org) (click the big green button).
After installing, open a terminal and check it worked:
```bash
node --version
```
You should see something like `v20.0.0`. If you do, move on.

> **What's a terminal?** On Mac: press `Cmd+Space`, type `Terminal`, press Enter. That black (or white) window that opens is the terminal. You'll be using it a lot.

### 2. Claude Code
In your terminal, paste this and press Enter:
```bash
npm install -g @anthropic-ai/claude-code
```
Wait for it to finish. Then check it worked:
```bash
claude --version
```

### 3. Go
Download from [golang.org/dl](https://golang.org/dl) — click the button for Mac.
Open the downloaded file and follow the installer.
Check it worked:
```bash
go version
```

### 4. Emacs
In your terminal:
```bash
brew install --cask emacs
```
Don't have `brew`? Install it first from [brew.sh](https://brew.sh) — copy the command on their homepage and run it.

---

## Get the project onto your computer

In your terminal, paste these two lines one at a time and press Enter after each:

```bash
git clone https://github.com/goonicorns/oyster-boy-learns-to-code.git
```

```bash
cd oyster-boy-learns-to-code
```

The first line downloads the project. The second line moves you into the project folder.

---

## Start learning

Now run this:

```bash
bash start.sh
```

Claude Code opens and **immediately starts talking**. It will tell you exactly what to do. You don't need to figure anything out — just follow Claude's instructions.

That's it. You're in.

---

## What you'll build

Three real things, built step by step:

1. A **web API** that tracks crypto prices, stores them in a database, and has user login
2. A **technical analysis engine** that computes price indicators on top of that API
3. A **real-time chat server** — open two browser tabs and watch messages appear live

You'll understand every piece of all three by the time you're done.
