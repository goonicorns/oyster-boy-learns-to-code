# Lesson 19: The Hub — Where Goroutines and Channels Finally Make Sense

**Paste into Claude Code after the system prompt**

---

## Context for Claude

This is the most important lesson in the entire curriculum. The Hub pattern is where everything the learners know about goroutines and channels stops being abstract and becomes concrete and obvious. Take as long as needed here. The code comes AFTER the picture is crystal clear.

**This lesson's goal:**
- Understand the hub pattern before writing it
- See why goroutines are perfect for this — one per client connection
- See why channels are perfect for this — safe message passing between goroutines
- Draw the architecture, then code it
- Understand what a race condition is and why channels prevent them

---

## Start by revisiting goroutines — connect to what they know

"In the exercises, goroutines were kind of abstract. You ran some functions concurrently and saw numbers print out of order. Why does any of that matter for a chat server?"

"Here's why: our chat server will have hundreds of clients connected at the same time. Each client has a persistent open connection. The server needs to be listening for messages from ALL of them simultaneously."

"In an older approach, you'd have one thread per client — but threads are expensive. Each one uses megabytes of memory. A server with 10,000 clients would need 10,000 threads = tens of gigabytes just for overhead."

"Goroutines cost about 2-8KB each. 10,000 goroutines = maybe 80MB. Go was literally designed for this. The chat server is the use case goroutines were built for."

---

## The fundamental problem: shared state

"Here's the problem we need to solve. Multiple goroutines — one per client — all need to do the same thing: when a message arrives, send it to all other connected clients."

"But there's a catch. Imagine two clients send a message at EXACTLY the same time. Both their goroutines are running simultaneously. Both try to access the list of connected clients to broadcast. What could go wrong?"

Let them think. Guide toward: **a race condition.** Both goroutines might try to modify or read the same list at the same time. One might see a half-updated list. Data gets corrupted. The server crashes or behaves randomly.

"This is one of the hardest problems in programming: shared mutable state accessed by multiple concurrent things. It's why multithreaded code is so notoriously difficult to write correctly."

"Go's answer: don't share state. Communicate instead."

---

## Channels as safe message pipes — really nail this

"Remember channels from the exercises. A channel is a typed pipe. You send a value in one end, it comes out the other. Crucially: only ONE goroutine can receive a given value. Channels are safe to use from multiple goroutines simultaneously — the Go runtime handles the synchronization."

"So instead of goroutines all reaching into a shared list of clients, they each SEND a message into a channel. One single goroutine reads from that channel and handles all the state. That goroutine — and only that goroutine — touches the client list. No race conditions possible."

"That one goroutine is what we call the Hub."

---

## Draw the Hub — do this before any code

Draw this with them. Have them draw it themselves, then compare.

```
                    ┌─────────────────────────────────┐
                    │              HUB                │
                    │                                 │
                    │   clients: map of connections   │
                    │                                 │
                    │   register channel  ←───────────┼── new client connects
                    │   unregister channel ←──────────┼── client disconnects
                    │   broadcast channel  ←──────────┼── client sends message
                    │                                 │
                    │   [single goroutine runs here]  │
                    │   reads from all three channels │
                    │   and dispatches work           │
                    └─────────────────────────────────┘
                            │           │
              sends to      │           │     sends to
              all clients   │           │     all clients
                            ↓           ↓
                    ┌──────────┐   ┌──────────┐
                    │ Client A │   │ Client B │
                    │goroutine │   │goroutine │
                    └──────────┘   └──────────┘
                         │               │
                    WebSocket        WebSocket
                    connection       connection
                         │               │
                       Alice's         Bob's
                       browser         browser
```

Ask them to explain back to you:
- "What is the Hub?" (a single goroutine that manages all client state)
- "Why is it ONE goroutine?" (so nothing else touches the client map — no race conditions)
- "What are the three channels?" (register, unregister, broadcast)
- "When Alice connects, what gets sent to the Hub?" (a register message with her connection)
- "When Alice disconnects, what gets sent?" (an unregister message)
- "When Alice sends a message, what gets sent?" (a broadcast message — and the Hub forwards it to all other clients)

---

## The per-client goroutines

"Each client connection has TWO goroutines. Why two?"

Let them think. Guide toward:
- One goroutine is dedicated to READING from the WebSocket (waiting for the client to send something)
- One goroutine is dedicated to WRITING to the WebSocket (waiting to send something to the client)

"Why not one goroutine per client?"

"Because reading and writing can happen at the same time. While you're waiting for Alice to send a message (reading), you might need to send her a message that Bob just sent (writing). If you only had one goroutine, you'd have to pick: either wait for Alice's input OR send her messages. You can't do both simultaneously with one goroutine."

"Two goroutines per client: one ear (read pump), one mouth (write pump). They communicate with each other via a per-client channel."

Add this to the diagram:

```
Alice's connection:
  ┌──────────────────────────────────┐
  │  read pump goroutine             │  ← waits for Alice to send something
  │    → sends to Hub's broadcast ch │
  ├──────────────────────────────────┤
  │  write pump goroutine            │  ← waits for messages to send to Alice
  │    ← reads from send channel    │
  └──────────────────────────────────┘
         ↕ send channel (buffered)
```

---

## The Client struct

Now they're ready to think about code. Ask:

"What data does our program need to track for each connected client?"

Guide toward:
```go
type Client struct {
    hub  *Hub              // pointer back to the hub (to send on broadcast channel)
    conn *websocket.Conn   // the actual WebSocket connection
    send chan []byte       // buffered channel of outbound messages
}
```

Ask about each field:
- "Why a pointer to the hub?" (so the read pump can send to hub.broadcast when Alice sends a message)
- "What is `websocket.Conn`?" (the gorilla/websocket type representing the open connection)
- "What is the `send` channel?" (when the hub wants to send a message to THIS client, it puts it in this channel; the write pump goroutine reads from it and sends over the WebSocket)
- "Why buffered?" (so the hub doesn't block if a client's write pump is slow — we'll pick a buffer size like 256)

---

## The Hub struct

"Now what does the Hub need?"

Guide toward:
```go
type Hub struct {
    clients    map[*Client]bool  // all currently connected clients
    broadcast  chan []byte        // messages to send to all clients
    register   chan *Client       // clients wanting to join
    unregister chan *Client       // clients wanting to leave
}
```

Ask about each field:
- "Why `map[*Client]bool` instead of `[]*Client`?" (a map makes O(1) lookup for removal — when a client disconnects you can delete it instantly)
- "What does the `bool` value mean?" (it doesn't — it's just a placeholder. `map[*Client]struct{}` would be more idiomatic but map[*Client]bool is clearer for beginners)
- "All three channels — why are they channels instead of just calling functions?" (so goroutines can interact with the hub safely — the hub's single goroutine processes them one at a time)

---

## The Hub's run loop — the heart of the server

"Now write the hub's run loop. This is the goroutine that runs for the lifetime of the server."

Ask them: "What does this function need to do?"
- Wait for something to happen on one of the three channels
- When a client registers: add it to the clients map
- When a client unregisters: remove it, close its send channel
- When a broadcast message comes in: send it to every client

Guide them to:
```go
func (h *Hub) run() {
    for {
        select {
        case client := <-h.register:
            h.clients[client] = true

        case client := <-h.unregister:
            if _, ok := h.clients[client]; ok {
                delete(h.clients, client)
                close(client.send)
            }

        case message := <-h.broadcast:
            for client := range h.clients {
                select {
                case client.send <- message:
                    // message queued for this client
                default:
                    // client's send buffer is full — they're too slow or disconnected
                    close(client.send)
                    delete(h.clients, client)
                }
            }
        }
    }
}
```

Go through every line with questions:
- "What does `select` do here?" (waits for whichever channel has something ready)
- "In unregister, why do we `close(client.send)`?" (signals the write pump goroutine to stop — it's ranging over the channel and `close` causes the range to exit)
- "In broadcast, why is there a second `select` with a `default`?" (if a client's send channel is full, we don't want the hub to block waiting for it — instead we assume the client is broken and remove them)
- "Why do we delete from the map while iterating over it?" (safe in Go — the language spec allows this for map deletion during range)

---

## Checkpoint — explain it back before writing any more code

"Stop. Before we write the read pump and write pump, explain the whole Hub to me like I'm someone who's never heard of it."

They should be able to say something like:
"The Hub is a single goroutine that manages all client connections. Other goroutines don't touch the client list directly — they send messages to the Hub via channels. The Hub processes them one at a time: adding new clients, removing disconnected ones, and forwarding messages to everyone. This is safe because only one goroutine ever touches the client map."

If they can say that clearly, they understand it. If not, re-explain and try again.

---

## Commit the struct definitions (even without full implementation)

```bash
git add .
git commit -m "Add Hub and Client structs for chat server"
```
