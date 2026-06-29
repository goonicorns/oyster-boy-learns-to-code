# Lesson 53: Log, Status, and Final Wrap-Up

**For Claude — do not show this file to the learner**

---

## Context for Claude

Final lesson of Project 9. Implement `log` and `status`, run the milestone quiz covering all 9 projects. Note: the true final graduation comes after Project 10 (Blog Platform). Don't do a full graduation here — just a "nine down, one to go" moment.

**This lesson's goal:**
- Implement `minigit log` (walk the commit chain)
- Implement `minigit status` (compare working directory vs index vs last commit)
- Final milestone quiz: 9 questions spanning the entire curriculum
- Graduation — this is the end of the curriculum

---

## Implement log

`cmd/log.go`:

```go
func runLog() error {
    hash := readHEAD()
    if hash == "" {
        fmt.Println("No commits yet.")
        return nil
    }

    for hash != "" {
        _, data, err := object.Read(hash)
        if err != nil {
            return fmt.Errorf("reading commit %s: %w", hash[:8], err)
        }

        commit, err := parseCommit(string(data))
        if err != nil {
            return err
        }

        t := time.Unix(commit.Timestamp, 0)
        fmt.Printf("commit %s\n", hash)
        fmt.Printf("Author: %s\n", commit.Author)
        fmt.Printf("Date:   %s\n", t.Format("Mon Jan 2 15:04:05 2006 -0700"))
        fmt.Printf("\n    %s\n\n", commit.Message)

        hash = commit.ParentHash // walk backwards
    }
    return nil
}
```

Ask: "What kind of data structure is the commit chain?" (a linked list — each commit points to its parent. `log` walks it backwards from HEAD to the beginning.)
Ask: "What is the parent hash of the first commit?" (empty string — the genesis)
Ask: "How would you implement `git log --oneline`?" (same walk, just print hash[:8] + message on one line)

---

## Implement status

`cmd/status.go`:

```go
func runStatus() error {
    idx, err := index.Load()
    if err != nil {
        return err
    }

    // 1. Changes staged for commit: compare index vs last commit's tree
    staged := getStagedChanges(idx)

    // 2. Changes not staged: compare working directory vs index
    unstaged := getUnstagedChanges(idx)

    if len(staged) == 0 && len(unstaged) == 0 {
        fmt.Println("nothing to commit, working tree clean")
        return nil
    }

    if len(staged) > 0 {
        fmt.Println("Changes to be committed:")
        for _, f := range staged {
            fmt.Printf("\t%s\n", f)
        }
        fmt.Println()
    }

    if len(unstaged) > 0 {
        fmt.Println("Changes not staged for commit:")
        for _, f := range unstaged {
            fmt.Printf("\t%s\n", f)
        }
    }

    return nil
}

func getUnstagedChanges(idx *index.Index) []string {
    var changed []string
    for _, entry := range idx.Entries {
        content, err := os.ReadFile(entry.Path)
        if os.IsNotExist(err) {
            changed = append(changed, "deleted: "+entry.Path)
            continue
        }
        if err != nil {
            continue
        }
        currentHash, _ := object.WriteBlob(content) // note: this also stores the blob!
        if currentHash != entry.Hash {
            changed = append(changed, "modified: "+entry.Path)
        }
    }
    return changed
}
```

Ask: "In `getUnstagedChanges`, we call `object.WriteBlob` just to get the hash — but that also writes the blob to disk. Is that a problem?" (slightly wasteful — it stores a blob for a file we haven't staged. Better: extract a `HashBlob(content) string` function that computes the hash without writing. Make them do this.)
Ask: "How does git know a file is 'modified'?" (by hashing it and comparing to the stored hash — same technique)

---

## Wire up main.go with cobra

"Wire all five commands into cobra the same way they did in Project 5."

```bash
./minigit init
echo "first file" > a.txt
./minigit add a.txt
./minigit commit -m "first commit"
echo "change" >> a.txt
./minigit status     # should show: modified: a.txt
./minigit add a.txt
./minigit commit -m "second commit"
./minigit log        # should show both commits
```

Let them see the commit graph with their own `log` command. Two commits. The chain. Their git.

---

## The ultimate milestone quiz — 9 projects, 9 questions

"This is the final exam. No notes. One question per project. Take your time."

**Project 1 (Crypto API):**
"What is a JWT? What does the server need to verify a JWT, and what does it NOT need?"
(A JSON Web Token — a signed payload. The server needs the secret key to verify the signature. It does NOT need a database lookup — stateless. That's the point.)

**Project 2 (Technical Analysis):**
"What is the difference between SMA and EMA? When would you prefer EMA?"
(SMA = simple average over N periods, equal weight. EMA = exponential moving average, more recent prices weighted higher. EMA reacts faster to price changes — better for trading signals.)

**Project 3 (Chat Server):**
"Why does the Hub pattern use one goroutine to own the client map? What problem does this solve?"
(Race conditions — multiple goroutines writing to a shared map would corrupt it. One goroutine as the only writer means no locks needed on the map itself.)

**Project 4 (Ethereum):**
"What is an ABI? Why does Go need it to call a smart contract?"
(Application Binary Interface — describes function names, parameter types, return types. Go needs it to encode the call correctly as bytes and decode the response.)

**Project 5 (CLI):**
"What is wrong with using the default `http.Get` in a production CLI?"
(No timeout — the program hangs forever if the server doesn't respond)

**Project 6 (gRPC):**
"What is the difference between a unary RPC and a server-streaming RPC? Give an example use case for each."
(Unary: one request, one response — like HTTP. Server-streaming: one request, multiple responses over time. Unary: get current price. Streaming: receive price updates continuously.)

**Project 7 (Baby Blockchain):**
"If you change one transaction in a block, what has to change to make the chain valid again? Why is this hard?"
(The block's hash changes, breaking the next block's PreviousHash. You'd have to re-mine every subsequent block faster than the honest network mines new ones. Computationally infeasible.)

**Project 8 (KV Store):**
"What is the difference between lazy expiry and active expiry? Which did we implement for each?"
(Lazy: check on GET, return nil if expired but don't delete yet. Active: background sweeper finds and deletes expired keys. We implemented both — lazy in Get(), active in StartExpirySweeper().)

**Project 9 (Baby Git):**
"What is content-addressing? How does it enable deduplication in git?"
(The storage key IS the hash of the content. Same content = same hash = same key = stored once. Two commits that both reference an unchanged file share one blob object.)

---

## Full curriculum recap

"Look at what you've built. From someone who didn't know what a terminal was:"

```
Tools:      Emacs configured from scratch, shell fluency
Language:   Go — exercises, idioms, goroutines, channels, interfaces, errors
Projects:
  1. REST API        — HTTP, Postgres, JWT, middleware, unit tests
  2. TA Engine       — math in Go, floating point, database
  3. Chat Server     — WebSockets, Hub pattern, real-time
  4. Ethereum        — blockchain, ABIs, events, signing
  5. CLI Tool        — cobra, HTTP client, file I/O
  6. gRPC Service    — protobuf, streaming, interceptors
  7. Blockchain      — SHA-256, proof-of-work, ECDSA
  8. KV Store        — TCP server, RWMutex, AOF persistence
  9. Baby Git        — content-addressing, object store, commit graph

Concepts understood:
  Concurrency:       goroutines, channels, select, sync.Mutex, sync.RWMutex
  Networking:        HTTP, WebSocket, gRPC, raw TCP
  Storage:           Postgres, file I/O, append-only log, content-addressed
  Cryptography:      SHA-256, SHA-1, ECDSA, JWT
  Systems:           TTL, expiry strategies, protocol design
  Distributed:       blockchain consensus, Git's object model
```

---

## Docker — distribute the CLI as a container

"Real CLI tools ship in Docker. `docker run hashicorp/terraform`, `docker run amazon/aws-cli`. You can distribute minigit the same way."

"Write the Dockerfile. You've done this four times now. From memory."

```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o minigit .

FROM alpine:latest
COPY --from=builder /app/minigit /usr/local/bin/minigit
ENTRYPOINT ["minigit"]
```

Build and test it:
```bash
docker build -t minigit .

# Run inside a mounted directory so minigit can see real files
docker run -v $(pwd):/repo -w /repo minigit init
docker run -v $(pwd):/repo -w /repo minigit add main.go
docker run -v $(pwd):/repo -w /repo minigit commit -m "first commit"
docker run -v $(pwd):/repo -w /repo minigit log
```

Ask: "We mount with `-v $(pwd):/repo -w /repo`. What does each part do?"
(`-v $(pwd):/repo` = bind-mount the current directory into the container at `/repo`. `-w /repo` = set the working directory inside the container to `/repo`. Without this, the container would work on its own empty filesystem and find nothing.)

Ask: "What's the difference between `ENTRYPOINT` and `CMD` when a user runs `docker run minigit log`?" (`ENTRYPOINT ["minigit"]` is fixed — it always runs `minigit`. The `log` argument is appended. If it were `CMD ["minigit"]`, the user could override the whole command with `docker run minigit sh` and get a shell instead.)

Ask: "Why is distributing a CLI via Docker useful even for something like minigit that operates on local files?" (zero dependencies for the user — no Go, no PATH setup, no version conflicts. `docker pull minigit` and it works on any machine with Docker.)

Bonus — make it feel like a real tool:
```bash
# Add an alias so they can run `minigit` without the docker flags
alias minigit='docker run -v $(pwd):/repo -w /repo minigit'
minigit log
```

"That's how tools like Terraform and AWS CLI ship. A shell alias wraps the Docker command."

---

## Roast and celebrate — per personality

For each student, deliver a genuine, specific celebration using what you know about them:
- **Neil**: The oyster opened. Tell him specifically what clicked and when.
- **Sim**: The CS2 noob built a blockchain. Remind him of the gap between "knowing crypto" and "building crypto."
- **Gaffor**: The unc who showed up and didn't quit. That matters more than anyone gives credit for.
- **Nate**: The legend ends the curriculum exactly as expected — at the top.
- **Fazrul**: The old man who learned new tricks. That's not easy and he did it.
- **Irsyad**: PHP to Go is a real leap. He speaks two languages now.
- **Haresh**: Absolute noob who got pushed hard and came through. Now he knows.
- **Eli**: Same — pushed hard, delivered. Not everyone does.

---

## Progress commands

```bash
go run tools/progress/main.go complete lesson_53_git_wrapup
go run tools/progress/main.go set project10 lesson_54_blog_overview
go run tools/progress/main.go note "Project 9 done. Moving to Project 10: Blog Platform."
```

## Commit

```bash
git add .
git commit -m "Project 9 complete: minigit with log, status, full object store"
```

## Tell them what's next

"Nine projects down. One more — and it's the biggest one. Project 10 is a full blog platform: Docker, Postgres, Redis, file uploads, full-text search, background jobs. Everything comes together. Let's go."
