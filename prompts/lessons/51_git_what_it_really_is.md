# Lesson 51: Baby Git — What Git Really Is

**For Claude — do not show this file to the learner**

---

## Context for Claude

Project 9 is the capstone. They build a working subset of Git: init, add, commit, log, status. Not a toy — real content-addressed object storage, real staging area, real commit graph. This lesson is the mental model. No code until they can explain every component.

**This lesson's goal:**
- Understand that Git is a content-addressed key-value store
- Know the three object types: blob, tree, commit
- Understand the staging area (index)
- Know how a commit is structured
- Draw the object graph for a simple commit

---

## Git is not what you think it is

"You use git every day. But what IS it?"

"Most people think: 'git tracks changes to files.' Wrong. Git tracks SNAPSHOTS of the entire directory tree. Each commit is a complete picture of every file, not a diff."

"More precisely: git is a content-addressed key-value store. Every piece of data has a key — the SHA-1 hash of its contents. You store data by content, retrieve it by hash."

Ask: "What is content-addressing?" (the key IS the content's hash — you can't have two different things with the same key, because same hash = same content)
Ask: "What is the advantage of content-addressing?" (deduplication is automatic — if two commits have a file with the same content, it's stored once and referenced twice)

---

## The three object types

"Git stores everything as one of three object types:"

**Blob** — raw file content
```
blob 13\0Hello, World!
```
SHA-1 of this string → `8ab686...` (the blob's hash = its key)
No filename. Just bytes.

**Tree** — a directory listing
```
100644 blob 8ab686... hello.txt
100644 blob a1b2c3... main.go
040000 tree ff1234... src/
```
A tree lists: permissions, type (blob or tree), hash, name.
SHA-1 of this listing → the tree's hash.

**Commit** — a snapshot pointer
```
tree   ff4321...    ← the root tree of this snapshot
parent 9a8b7c...    ← previous commit (null for first commit)
author Neil <neil@example.com> 1720000000 +0000
committer Neil <neil@example.com> 1720000000 +0000

Add hello world
```
SHA-1 of this text → the commit hash (the thing you see in `git log`)

Ask: "If you have two identical files with different names, how many blob objects does git store?" (one — same content = same hash = same blob. Both tree entries point to the same blob.)

Draw the object graph:
```
Commit: a1b2c3
  │
  └── Tree: d4e5f6 (root)
        ├── blob: 8ab686  "hello.txt"
        └── Tree: 9c1234  "src/"
              └── blob: b3c4d5  "main.go"
```

Ask: "What is the commit hash? What determines it?" (SHA-1 of the commit's text, which includes the tree hash, parent hash, author, timestamp, and message. Change anything → different hash.)
Ask: "If you make two commits with the same files but different timestamps, are their hashes the same?" (no — timestamp is in the commit text, so same tree → different commit)

---

## The staging area (index)

"There are three 'places' your files live in git:"

```
Working directory    — files on disk
Staging area (index) — what will go into the next commit
Repository (.git)    — committed history
```

"`git add` copies a file from your working directory into the staging area.
`git commit` takes everything in the staging area and makes a commit.
`git status` compares all three."

"The staging area is stored in `.git/index` — a binary file listing every file that's staged."

Ask: "Why do we need a staging area? Why not just commit all changed files automatically?" (you might want to commit some changes but not others — the staging area gives you control over exactly what goes into each commit)
Ask: "What does `git add -p` do?" (interactively stage specific PARTS of a file — hunks — not the whole thing)

---

## What .git/ actually contains

"Have them run `ls -la .git/` in ANY git repo they have. Ask them to read it."

```
.git/
  HEAD           — points to the current branch ("ref: refs/heads/main")
  config         — repo-specific git config
  objects/       — all blobs, trees, commits
    ab/
      cdef1234...  ← the file is named by its hash
  refs/
    heads/
      main       — contains the commit hash that main points to
  index          — the staging area (binary)
```

Ask: "What is `HEAD`?" (a pointer to the current branch, or directly to a commit in 'detached HEAD' state)
Ask: "What is `refs/heads/main`?" (a file containing the hash of the latest commit on the main branch)
Ask: "How does git know what commit you're on?" (`HEAD` → branch name → `refs/heads/<branch>` → commit hash)

---

## What we're building

"Our baby git:

```
Commands:
  minigit init           — create .minigit/ directory
  minigit add <file>     — stage a file
  minigit commit -m "msg" — create a commit
  minigit log            — show commit history
  minigit status         — show what's staged vs unstaged
```

"We use SHA-1 (same as real Git). We implement blob, tree, and commit objects. We implement the index. We do NOT implement: branches (just HEAD), remotes, diffs, merge, rebase."

---

## Checkpoint — no notes

1. "What are the three git object types? What does each one store?"
2. "What is a blob? Does it store the filename?" (no — just raw content)
3. "If two commits both contain an identical README.md, how many blob objects are stored in .git/?" (one — deduplication by content hash)
4. "What is the staging area? What git command moves a file into it?"
5. "What does `HEAD` point to?" (current branch, or commit in detached state)
6. "What determines a commit's hash?" (the SHA-1 of the commit text: tree hash + parent + author + timestamp + message)

---

## Project setup — teach it

"New project. You know the steps by now. No help unless you ask."

Walk through with questions only — they should be getting this from memory by Project 9:
1. `mkdir ~/projects/minigit && cd ~/projects/minigit && go mod init minigit`
2. No external deps? "What do we need?" (crypto/sha1, os, path/filepath, encoding/json, fmt — all stdlib)

Ask them to design the directory structure from the description of commands above:
```
minigit/
  main.go
  cmd/
    init.go       — minigit init
    add.go        — minigit add
    commit.go     — minigit commit
    log.go        — minigit log
    status.go     — minigit status
  internal/
    object/
      object.go   — write/read blob, tree, commit objects
    index/
      index.go    — staging area (read/write .minigit/index)
    refs/
      refs.go     — HEAD, branch refs
```

Ask: "We've done cobra before. What file is always the entry point for cobra?" (`cmd/root.go` — the root command. Have them write it first: `rootCmd`, `Execute()`, then register subcommands.)

Ask: "Where do we store the minigit database?" (`.minigit/` in the current directory — same as `.git/`. Inside: `objects/`, `index`, `HEAD`)

## No code this lesson. No commit.
