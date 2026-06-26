# Lesson 26: Graceful Shutdown & The Full Picture

**Paste into Claude Code after the system prompt**

---

## Context for Claude

This is the final lesson for the chat server project. Two things happen here: (1) they add graceful shutdown so the server doesn't cut clients off mid-message when it stops, and (2) they do a full synthesis review — explaining the entire system from scratch, connecting it to everything they've learned. This lesson should feel like a graduation. They built something real. Make sure they know it.

**This lesson's goal:**
- Understand what graceful shutdown means and why it matters
- Implement OS signal handling in Go
- Give all connected clients a chance to close cleanly
- Do a full system synthesis — connect every piece
- Celebrate what they built — and what it means for where they go next

---

## The problem — the hard shutdown

"Right now, if you do Ctrl+C to stop the server, what happens to connected clients?"

Let them think. They probably don't know. The answer: the TCP connection gets severed immediately. Clients see the connection drop with no warning. Any in-flight message is lost. If they were in the middle of sending something, it disappears.

"For a chat app, this is acceptable during development. In production, you'd want to:
1. Stop accepting new connections
2. Tell all connected clients 'server is restarting, please reconnect in a moment'
3. Wait for all clients to disconnect
4. Then fully exit

That's called graceful shutdown."

---

## OS signals — what is Ctrl+C really doing?

"When you press Ctrl+C in a terminal, the operating system sends a signal to your program. In Unix, it's SIGINT — 'signal interrupt.'"

"By default, most programs just die when they receive SIGINT. But Go lets us catch signals and decide what to do."

Ask: "Can you think of other OS signals you might have heard of?" Guide toward:
- SIGTERM: "terminate" — sent by `kill` command and by Docker when stopping a container
- SIGKILL: "kill immediately" — cannot be caught, program dies instantly (this is `kill -9`)
- SIGHUP: "hang up" — originally meant the terminal disconnected, now often used to tell a server to reload its config

"For our purposes, we want to catch SIGINT and SIGTERM — the two signals that mean 'please stop.'"

---

## Implementing graceful shutdown

```go
// In main.go

import (
    "os"
    "os/signal"
    "syscall"
    "context"
    "net/http"
    "time"
)

func main() {
    // ... all your existing setup code ...

    // Create the HTTP server manually (instead of just calling http.ListenAndServe)
    // This gives us a handle to shut it down gracefully
    srv := &http.Server{
        Addr:    ":8080",
        Handler: r,
    }

    // Start the server in a goroutine so main() doesn't block
    go func() {
        log.Println("Server starting on :8080")
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatalf("server error: %v", err)
        }
    }()

    // Wait for an OS signal
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit // This blocks until a signal arrives

    log.Println("Shutting down server...")

    // Give the server 10 seconds to finish serving in-flight requests
    ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        log.Printf("Server forced to shutdown: %v", err)
    }

    log.Println("Server exited cleanly")
}
```

Go through this carefully:

Ask: "Why do we start the server in a goroutine now?" (so `main()` doesn't block on `ListenAndServe` — we need `main()` to continue to the signal waiting code)

Ask: "What does `signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)` do?" (tells the OS to route these two signals into our `quit` channel instead of killing the program)

Ask: "What is `<-quit` doing?" (blocking — it waits until something arrives in the quit channel. When Ctrl+C is pressed, the OS sends SIGINT, which gets routed to quit, which unblocks this line)

Ask: "What does `srv.Shutdown(ctx)` do?" (tells the HTTP server to stop accepting new connections, then waits for existing connections to finish — up to 10 seconds, then forces them closed)

Ask: "What about WebSocket connections? They're long-lived. Will they finish in 10 seconds?" (probably not — but that's acceptable. In a production system you'd notify clients first, give them a chance to reconnect, then shut down)

---

## Notifying clients before shutdown

For a better experience, notify clients that the server is restarting:

```go
// In Hub — add a shutdown method
func (h *Hub) Shutdown() {
    // Send a "server shutting down" message to all rooms
    shutdownMsg := Message{
        User:    "server",
        Content: "Server is restarting. Please refresh to reconnect.",
    }
    
    data, _ := json.Marshal(shutdownMsg)
    
    for _, room := range h.rooms {
        for client := range room {
            // Non-blocking send — if client's buffer is full, skip
            select {
            case client.send <- data:
            default:
            }
        }
    }
}
```

Ask: "Why is the User 'server' here?" (it's a system message, not from a real user — the frontend could style it differently)

Ask: "Can we call hub.Shutdown() safely from main()?" (careful — hub.rooms is only touched by the hub goroutine. Calling it from main() is a race condition. The cleaner approach is to send a shutdown message through a channel. But for a clean shutdown where the hub goroutine will end anyway, a short sleep to let the message send is usually acceptable.)

---

## The full system diagram — draw it one final time

"Before we celebrate, let's draw the whole system one last time. Not just the chat parts — everything we've built across three projects."

Have them draw or narrate:

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Container                      │
│  ┌─────────────────┐                                    │
│  │   PostgreSQL     │                                    │
│  │  - users         │                                    │
│  │  - prices        │                                    │
│  │  - indicators    │                                    │
│  │  - messages      │                                    │
│  └────────┬────────┘                                    │
└───────────│─────────────────────────────────────────────┘
            │ pgx driver
            ↕
┌───────────────────────────────────────────────────────────────┐
│                         Go Server                             │
│                                                               │
│  chi Router                                                   │
│  ├── POST /register, POST /login (bcrypt + JWT)               │
│  ├── GET /prices/{symbol} (REST, JWT middleware)              │
│  ├── GET /analysis/{symbol} (REST, JWT middleware)            │
│  └── GET /ws (WebSocket upgrade, JWT in query string)         │
│                                                               │
│  Background goroutines:                                       │
│  ├── Price fetcher (every 60s → external API → DB)           │
│  ├── Analysis calculator (after each price fetch)             │
│  └── Hub.run() (forever → manages WebSocket clients)          │
│                                                               │
│  Per-client WebSocket goroutines (2 per client):              │
│  ├── readPump → hub.broadcast channel                         │
│  └── writePump ← client.send channel                          │
└───────────────────────────────────────────────────────────────┘
            ↕ HTTP / WebSocket
┌───────────────────────────────────────────────────────────────┐
│                         Browser                               │
│  ├── static/index.html (chat UI)                              │
│  ├── WebSocket API (onmessage, send)                          │
│  └── fetch() API (login, REST endpoints)                      │
└───────────────────────────────────────────────────────────────┘
```

Ask them to point at each piece and explain:
- "What is bcrypt doing in the user flow?" (hashing passwords — intentionally slow to resist brute force)
- "What is JWT doing?" (stateless authentication — a signed token the server can verify without querying the database)
- "What is chi doing?" (routing HTTP requests to handler functions)
- "What is pgx doing?" (Go library for talking to PostgreSQL)
- "What is the Hub doing?" (managing all WebSocket connections, routing messages to rooms)
- "What are the read pump and write pump doing?" (one goroutine reads from WebSocket, one writes to WebSocket — two because they can happen simultaneously)
- "What is Docker doing?" (running PostgreSQL in an isolated container so they don't install it on their machine)

---

## The concepts they now own — say them out loud

Read this list out loud together. For each one, ask: "Can you explain this?"

**Networking & Protocols:**
- HTTP request/response cycle
- WebSocket — persistent, bidirectional connections
- The WebSocket handshake (HTTP upgrade → 101 Switching Protocols)
- TCP as the underlying transport

**Security:**
- bcrypt — intentionally slow password hashing
- JWT — signed stateless tokens with expiry
- XSS (cross-site scripting) — why you escape user content
- SQL injection — why you use parameterized queries
- Why you never trust data from the client

**Concurrency:**
- Goroutines — lightweight threads, ~2-8KB each
- Channels — typed pipes for safe communication between goroutines
- Race conditions — what happens when two goroutines share state
- The Hub pattern — one goroutine owns all shared state, others communicate via channels
- Deadlines and timeouts — why connections need heartbeats

**Databases:**
- SQL: SELECT, INSERT, DELETE, JOIN, ORDER BY, LIMIT, DISTINCT ON
- Indexes — why they matter for query performance
- Parameterized queries — placeholders instead of string concatenation
- pgx — the Go PostgreSQL driver
- Transactions — all or nothing operations

**Go Language:**
- All basic types, variables, control flow
- Functions with multiple return values
- Structs and methods (value vs pointer receivers)
- Interfaces — implicit satisfaction
- Error handling — (value, error) pattern, `fmt.Errorf` with `%w`
- Goroutines and channels
- `select` — waiting on multiple channels
- `defer` — guaranteed cleanup
- Slices, maps, and the patterns around them

**Software Architecture:**
- Package structure — separating concerns
- Middleware — request processing chains
- The store pattern — database access layer
- Background workers — goroutines that run for the lifetime of the server
- The hub/broadcast pattern — for any real-time fan-out problem
- Memory for speed, database for permanence

---

## Where they go from here

"You built three real systems:
1. A crypto price monitoring API — HTTP, auth, Postgres, Docker
2. A technical analysis engine — pure Go math, pre-computed indicators, background workers
3. A real-time chat server — WebSockets, goroutines, channels, real-time broadcast

These aren't toy projects. These are the patterns that run Slack, Discord, Bloomberg Terminal, and every fintech startup."

"What's next? Pick anything:
- Add private messages (direct messages between users)
- Add message reactions (like Slack emoji reactions)
- Deploy to a real server (DigitalOcean, Fly.io, Railway)
- Build a mobile app that talks to your API
- Learn React or Vue to build a nicer frontend
- Add file uploads (attach images to messages)
- Learn about Redis and use it as a faster message broker"

"You have the foundation. Everything else is just new APIs and new patterns on top of what you already know."

---

## Final commit

```bash
git add .
git commit -m "Add graceful shutdown, finalize chat server project"
git push
```

"You shipped it. Congratulations."

---

## One last question — ask them this before closing

"Without looking at anything — what is a goroutine, what is a channel, and what is the hub pattern?"

If they can answer that clearly, from memory, in their own words — they've got it. That knowledge is theirs now.
