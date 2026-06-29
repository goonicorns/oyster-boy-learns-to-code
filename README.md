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

### 4. Emacs (skip this if Claude tells you to)
In your terminal:
```bash
brew install --cask emacs
```
Don't have `brew`? Install it first from [brew.sh](https://brew.sh) — copy the command on their homepage and run it.

> Some learners skip the Emacs section entirely. Claude will tell you whether you need it.

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

Ten real things, built step by step:

1. A **crypto price API** — HTTP server, Postgres database, user login with JWT
2. A **technical analysis engine** — EMA, SMA, price indicators
3. A **real-time chat server** — WebSockets, live messages across browser tabs
4. An **Ethereum client** — read the blockchain, interact with smart contracts, sign transactions
5. A **CLI portfolio tracker** — command-line tool, cobra, live price fetching
6. A **gRPC price feed** — Protocol Buffers, streaming data to multiple clients
7. A **blockchain** — proof-of-work, SHA-256, ECDSA wallets, REST API — all from scratch in Go
8. A **key-value store** — raw TCP server, TTL expiry, append-only persistence
9. **Baby Git** — content-addressing, object store, staging area, commit graph — real git internals
10. A **full blog platform** — Docker Compose, Postgres, Redis, full-text search, file uploads, background job queue

You'll understand every piece of all ten by the time you're done.

---

## What you'll learn along the way

- Go: types, interfaces, goroutines, channels, errors, the whole language
- Shell and terminal fluency
- Emacs (configured from scratch)
- Databases: Postgres — schema design, migrations, transactions, full-text search
- Networking: HTTP, WebSockets, gRPC, raw TCP
- Cryptography: SHA-256, ECDSA, JWT
- Docker: containers, Docker Compose, multi-stage builds
- Redis: caching, cache invalidation, sorted sets
- Concurrency: goroutines, channels, mutexes — for real
