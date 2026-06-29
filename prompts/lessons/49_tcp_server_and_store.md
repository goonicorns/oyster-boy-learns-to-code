# Lesson 49: TCP Server, Store Implementation, TTL

**For Claude — do not show this file to the learner**

---

## Context for Claude

They build the TCP server and in-memory store. Key moments: `net.Listen`, the accept loop (each connection → goroutine), parsing the text protocol, TTL with background expiry goroutine. Do NOT let them google/copy the TCP server pattern — make them build it by understanding each line.

**This lesson's goal:**
- Build a TCP server with `net.Listen` and `net.Accept`
- Handle each connection in a goroutine
- Read and parse commands from the connection
- Implement GET/SET/DEL with the Store
- Add TTL: lazy expiry on GET, background active expiry

---

## Project setup

```bash
mkdir ~/projects/minikvs
cd ~/projects/minikvs
go mod init minikvs
```

Structure:
```
minikvs/
  store/
    store.go     — in-memory store
    expiry.go    — TTL and cleanup
  server/
    server.go    — TCP server
    handler.go   — command parsing and dispatch
  main.go
```

---

## The store

`store/store.go`:

```go
package store

import (
    "sync"
    "time"
)

type Store struct {
    mu     sync.RWMutex
    data   map[string]string
    expiry map[string]time.Time
}

func New() *Store {
    return &Store{
        data:   make(map[string]string),
        expiry: make(map[string]time.Time),
    }
}

func (s *Store) Set(key, value string, ttl time.Duration) {
    s.mu.Lock()
    defer s.mu.Unlock()

    s.data[key] = value
    if ttl > 0 {
        s.expiry[key] = time.Now().Add(ttl)
    } else {
        delete(s.expiry, key) // remove any old expiry
    }
}

func (s *Store) Get(key string) (string, bool) {
    s.mu.RLock()
    defer s.mu.RUnlock()

    // Lazy expiry check
    if exp, ok := s.expiry[key]; ok && time.Now().After(exp) {
        return "", false // expired — pretend it doesn't exist
    }

    val, ok := s.data[key]
    return val, ok
}

func (s *Store) Del(key string) bool {
    s.mu.Lock()
    defer s.mu.Unlock()

    _, existed := s.data[key]
    delete(s.data, key)
    delete(s.expiry, key)
    return existed
}

func (s *Store) TTL(key string) int {
    s.mu.RLock()
    defer s.mu.RUnlock()

    if _, ok := s.data[key]; !ok {
        return -2 // key doesn't exist (Redis convention)
    }
    exp, ok := s.expiry[key]
    if !ok {
        return -1 // key exists but no expiry
    }
    remaining := time.Until(exp)
    if remaining < 0 {
        return -2 // expired
    }
    return int(remaining.Seconds())
}

func (s *Store) Keys() []string {
    s.mu.RLock()
    defer s.mu.RUnlock()

    keys := make([]string, 0, len(s.data))
    for k := range s.data {
        if exp, ok := s.expiry[k]; !ok || time.Now().Before(exp) {
            keys = append(keys, k)
        }
    }
    return keys
}

func (s *Store) Flush() {
    s.mu.Lock()
    defer s.mu.Unlock()
    s.data = make(map[string]string)
    s.expiry = make(map[string]time.Time)
}
```

Ask question by question:
- "In `Get`, we check expiry under `RLock`. But if the key IS expired, we return false without deleting. Is this a problem?" (slightly — the expired key stays in memory until the background sweeper finds it or `Del` is called. This is lazy expiry — acceptable tradeoff for avoiding a write lock on every read.)
- "Why `time.Until(exp)` instead of `exp.Sub(time.Now())`?" (same result, `time.Until` is more idiomatic)
- "In `TTL`, what does returning -1 vs -2 communicate?" (-1 = key exists, no expiry; -2 = key doesn't exist or is expired. This is the Redis convention — they should follow it so their tool is compatible)

---

## Background expiry sweeper

`store/expiry.go`:

```go
package store

import (
    "log"
    "time"
)

// StartExpirySweeper runs in the background, deleting expired keys periodically.
// Call this once at startup in a goroutine.
func (s *Store) StartExpirySweeper(interval time.Duration) {
    ticker := time.NewTicker(interval)
    go func() {
        for range ticker.C {
            s.sweepExpired()
        }
    }()
    log.Printf("Expiry sweeper running every %v", interval)
}

func (s *Store) sweepExpired() {
    s.mu.Lock()
    defer s.mu.Unlock()

    now := time.Now()
    deleted := 0
    for key, exp := range s.expiry {
        if now.After(exp) {
            delete(s.data, key)
            delete(s.expiry, key)
            deleted++
        }
    }
    if deleted > 0 {
        log.Printf("Expiry sweep: deleted %d expired keys", deleted)
    }
}
```

Ask: "Why does the sweeper need `Lock()` (write lock) instead of `RLock()`?" (it deletes from the maps — a write operation)
Ask: "The sweeper runs `for range ticker.C` — what does ranging over a channel do?" (blocks until a value arrives, processes it, repeats — same as the Hub's select loop)

---

## TCP server

`server/server.go`:

```go
package server

import (
    "bufio"
    "fmt"
    "log"
    "net"
    "strings"

    "minikvs/store"
)

type Server struct {
    store *store.Store
    addr  string
}

func New(s *store.Store, addr string) *Server {
    return &Server{store: s, addr: addr}
}

func (srv *Server) ListenAndServe() error {
    ln, err := net.Listen("tcp", srv.addr)
    if err != nil {
        return fmt.Errorf("listening on %s: %w", srv.addr, err)
    }
    log.Printf("KV store listening on %s", srv.addr)

    for {
        conn, err := ln.Accept()
        if err != nil {
            log.Printf("accept error: %v", err)
            continue // don't stop the server on one bad connection
        }
        go srv.handleConn(conn) // one goroutine per connection
    }
}

func (srv *Server) handleConn(conn net.Conn) {
    defer conn.Close()
    remote := conn.RemoteAddr().String()
    log.Printf("new connection from %s", remote)

    scanner := bufio.NewScanner(conn)
    for scanner.Scan() {
        line := strings.TrimSpace(scanner.Text())
        if line == "" {
            continue
        }

        response := srv.handleCommand(line)
        fmt.Fprintf(conn, "%s\n", response)
    }

    log.Printf("connection closed: %s", remote)
}
```

Walk through with questions:
- "What does `net.Listen("tcp", ":6379")` do?" (binds to port 6379 on all interfaces — 6379 is Redis's default port)
- "What does `ln.Accept()` do?" (blocks until a client connects, then returns a `net.Conn` representing that connection)
- "Why `go srv.handleConn(conn)`?" (each connection runs in its own goroutine — the accept loop keeps accepting new connections without waiting for old ones to finish)
- "What is `bufio.NewScanner`?" (reads line by line from the connection — `scanner.Scan()` blocks until a line arrives or the connection closes)
- "Why `continue` after an accept error instead of returning?" (one bad connection shouldn't kill the server — log it and keep accepting)

---

## Command handler

`server/handler.go`:

```go
package server

import (
    "fmt"
    "strconv"
    "strings"
    "time"
)

func (srv *Server) handleCommand(line string) string {
    parts := strings.Fields(line) // split on whitespace
    if len(parts) == 0 {
        return "ERR empty command"
    }

    cmd := strings.ToUpper(parts[0])

    switch cmd {
    case "SET":
        if len(parts) < 3 {
            return "ERR SET requires key and value"
        }
        key, value := parts[1], parts[2]
        var ttl time.Duration
        if len(parts) >= 5 && strings.ToUpper(parts[3]) == "EX" {
            secs, err := strconv.Atoi(parts[4])
            if err != nil {
                return "ERR invalid TTL: must be integer seconds"
            }
            ttl = time.Duration(secs) * time.Second
        }
        srv.store.Set(key, value, ttl)
        return "OK"

    case "GET":
        if len(parts) < 2 {
            return "ERR GET requires key"
        }
        val, ok := srv.store.Get(parts[1])
        if !ok {
            return "(nil)"
        }
        return val

    case "DEL":
        if len(parts) < 2 {
            return "ERR DEL requires key"
        }
        existed := srv.store.Del(parts[1])
        if existed {
            return "1"
        }
        return "0"

    case "TTL":
        if len(parts) < 2 {
            return "ERR TTL requires key"
        }
        return strconv.Itoa(srv.store.TTL(parts[1]))

    case "EXISTS":
        if len(parts) < 2 {
            return "ERR EXISTS requires key"
        }
        _, ok := srv.store.Get(parts[1])
        if ok {
            return "1"
        }
        return "0"

    case "KEYS":
        keys := srv.store.Keys()
        if len(keys) == 0 {
            return "(empty)"
        }
        return strings.Join(keys, "\n")

    case "FLUSH":
        srv.store.Flush()
        return "OK"

    default:
        return fmt.Sprintf("ERR unknown command %q", cmd)
    }
}
```

Ask:
- "What does `strings.Fields` do?" (splits on any whitespace — multiple spaces, tabs, all treated as one separator. Different from `strings.Split(s, " ")` which would produce empty strings for multiple spaces.)
- "Why `strings.ToUpper(parts[0])` for the command?" (case-insensitive commands: `get` and `GET` both work — like Redis)
- "What does DEL return 0 vs 1?" (Redis convention: 1 = deleted, 0 = key didn't exist)

---

## Test with telnet

```bash
go run main.go &

# Connect with telnet (raw TCP)
telnet localhost 6379

# In the telnet session:
SET name Alice
GET name
SET counter 0 EX 10
TTL counter
GET counter
# Wait 11 seconds
GET counter
FLUSH
KEYS
```

This is the moment — they built a working key-value store they can telnet into.

---

## Checkpoint

1. "What does `net.Listen` return? What does `ln.Accept` return?"
2. "Why does `handleConn` start with `defer conn.Close()`?"
3. "What is `bufio.NewScanner` for? What does `scanner.Scan()` do when the connection closes?"
4. "What is lazy expiry? What is active expiry? Which one does our sweeper implement?"
5. "If 1000 clients connect simultaneously, how many goroutines does our server start?" (1000 — one per connection)
6. "What would happen if we ran `handleConn` directly instead of in a goroutine?" (the accept loop would block until that client disconnected — no new clients could connect)

---

## Commit

```bash
git add .
git commit -m "TCP server, KV store with GET/SET/DEL/TTL, background expiry sweeper"
```
