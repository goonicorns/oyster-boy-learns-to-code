# Lesson 50: Persistence and KV Store Wrap-Up

**For Claude — do not show this file to the learner**

---

## Context for Claude

The store works but loses everything on restart. This lesson adds persistence: an append-only log (like Redis's AOF mode) that replays commands on startup. Then the final milestone quiz.

**This lesson's goal:**
- Understand the two Redis persistence models (RDB snapshot vs AOF)
- Implement AOF: append every write command to a file
- Replay the log on startup to restore state
- Final milestone quiz: all of Project 8

---

## Two ways to persist a key-value store

"Right now, kill and restart the server. What happens to your data?"

(It's gone. In-memory only.)

"Redis has two persistence modes:

**RDB (Redis Database)** — takes a snapshot of all data at intervals. Like a periodic backup. Fast to restore but you lose the last few minutes of data if you crash.

**AOF (Append-Only File)** — every write command is appended to a log file. On restart, replay all commands. Slower but no data loss."

"We'll implement AOF — it's more instructive."

Ask: "What's the tradeoff of AOF vs RDB?" (AOF: no data loss, but the file grows forever and startup gets slower. RDB: fast startup, but you lose writes since last snapshot. Redis supports both simultaneously.)

---

## Implement AOF

`store/aof.go`:

```go
package store

import (
    "bufio"
    "fmt"
    "log"
    "os"
    "strings"
)

type AOF struct {
    file   *os.File
    writer *bufio.Writer
}

func NewAOF(path string) (*AOF, error) {
    f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
    if err != nil {
        return nil, fmt.Errorf("opening AOF: %w", err)
    }
    return &AOF{
        file:   f,
        writer: bufio.NewWriter(f),
    }, nil
}

func (a *AOF) Write(command string) error {
    _, err := fmt.Fprintln(a.writer, command)
    if err != nil {
        return err
    }
    return a.writer.Flush() // flush to OS immediately
}

func (a *AOF) Close() error {
    return a.file.Close()
}
```

"Now update the Store to take an optional AOF and write to it on every mutation:"

```go
type Store struct {
    mu     sync.RWMutex
    data   map[string]string
    expiry map[string]time.Time
    aof    *AOF // nil if persistence disabled
}

func (s *Store) Set(key, value string, ttl time.Duration) {
    s.mu.Lock()
    defer s.mu.Unlock()

    s.data[key] = value
    if ttl > 0 {
        s.expiry[key] = time.Now().Add(ttl)
        if s.aof != nil {
            s.aof.Write(fmt.Sprintf("SET %s %s EX %d", key, value, int(ttl.Seconds())))
        }
    } else {
        delete(s.expiry, key)
        if s.aof != nil {
            s.aof.Write(fmt.Sprintf("SET %s %s", key, value))
        }
    }
}

func (s *Store) Del(key string) bool {
    s.mu.Lock()
    defer s.mu.Unlock()

    _, existed := s.data[key]
    delete(s.data, key)
    delete(s.expiry, key)
    if existed && s.aof != nil {
        s.aof.Write(fmt.Sprintf("DEL %s", key))
    }
    return existed
}
```

Ask: "Why don't we log GET or TTL commands to the AOF?" (they don't change state — only writes need to be logged. Replaying reads would waste time.)
Ask: "Why `bufio.NewWriter` and then `Flush()`?" (bufio batches writes for performance, but we flush immediately after each command so it's actually on disk — a crash between write and flush would lose that command)

---

## Replay on startup

`store/aof.go` — add a Replay function:

```go
func ReplayAOF(path string, s *Store) error {
    f, err := os.Open(path)
    if os.IsNotExist(err) {
        return nil // no AOF yet — first startup
    }
    if err != nil {
        return fmt.Errorf("opening AOF for replay: %w", err)
    }
    defer f.Close()

    scanner := bufio.NewScanner(f)
    count := 0
    for scanner.Scan() {
        line := strings.TrimSpace(scanner.Text())
        if line == "" {
            continue
        }
        // Re-use the command handler logic to replay each command
        // We need a way to call handleCommand without the server —
        // refactor: extract command execution into the store
        applyCommand(s, line)
        count++
    }

    log.Printf("AOF replay: applied %d commands", count)
    return scanner.Err()
}
```

"Have them refactor the command dispatch out of the server and into the store, so both the TCP handler and the replay function can use it. This is a real engineering moment — design changes when you discover a new use case."

Ask: "What do we need to be careful about when replaying SET ... EX N commands?" (if a key was set with EX 60 yesterday and we replay the command today, it'll immediately expire — we should skip commands where the TTL would already have elapsed. Or store the absolute expiry timestamp in the AOF instead of relative seconds.)

That last question is important — probe them on it and make them solve it.

---

## Wire it in main.go

```go
func main() {
    aof, err := store.NewAOF("minikvs.aof")
    if err != nil {
        log.Fatal(err)
    }
    defer aof.Close()

    s := store.New(aof)

    // Replay persisted commands
    if err := store.ReplayAOF("minikvs.aof", s); err != nil {
        log.Printf("AOF replay warning: %v", err)
    }

    s.StartExpirySweeper(30 * time.Second)

    srv := server.New(s, ":6379")
    log.Fatal(srv.ListenAndServe())
}
```

Test:
1. Start server, SET some keys
2. Kill server (Ctrl+C)
3. Restart — GET the same keys — they're still there
4. Open `minikvs.aof` — read the raw log — they can see every command

---

## Final milestone quiz — no notes

1. "What is the difference between AOF and RDB persistence? Which does our implementation use?"
2. "Why do we `bufio.Flush()` after every AOF write instead of letting it buffer?" (crash safety — an unflushed write is lost if the program dies)
3. "What is the problem with replaying `SET key value EX 60` from a file written yesterday?" (the TTL is relative to when the command was written, not now — the key would expire immediately)
4. "Walk me through what happens when a new client connects. Start from `ln.Accept()`."
5. "What does `strings.Fields` do? How is it different from `strings.Split(s, " ")`?"
6. "Why does `Get` hold an `RLock` while `Set` holds a full `Lock`? What would go wrong with two full Locks?"
   (two full Locks would mean only one reader at a time — `RLock` allows many concurrent readers. Safety: no writer can hold RLock, so reads are always consistent.)
7. "The sweeper runs every 30 seconds. A key with TTL=1 is set. When does it actually get cleaned up?"
   (lazily on first GET — returns nil immediately even before the sweeper runs. The sweeper cleans the memory between 1 and 30 seconds later.)

---

## What they've learned in Project 8

- `net.Listen`, `net.Accept`, `net.Conn` — raw TCP
- `bufio.NewScanner` — line-by-line reading from a connection
- `strings.Fields` — whitespace splitting
- `sync.RWMutex` — deeply: when to use RLock vs Lock
- TTL: lazy expiry vs active (background) expiry
- AOF persistence: append-only log, replay on startup
- `os.OpenFile` with `O_APPEND` and `O_CREATE`
- The accept loop + goroutine per connection pattern
- How Redis actually works under the hood

---

## Progress commands

```bash
go run tools/progress/main.go complete lesson_50_kv_wrapup
go run tools/progress/main.go set project9 lesson_51_git_what_it_really_is
go run tools/progress/main.go note "Project 8 done — TCP server, RWMutex, AOF persistence all landed"
```

## Commit

```bash
git add .
git commit -m "Project 8 complete: AOF persistence, replay on startup"
```
