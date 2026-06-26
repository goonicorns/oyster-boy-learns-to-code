# Lesson 20: Read Pump & Write Pump — The Client Goroutines

**Paste into Claude Code after the system prompt**

---

## Context for Claude

The Hub is defined. Now the learners implement the two goroutines that handle each client connection. This is where the architecture from lesson 19 becomes running code. Every line should connect back to the diagram they drew.

**This lesson's goal:**
- Implement the read pump (goroutine that reads from the WebSocket)
- Implement the write pump (goroutine that sends to the WebSocket)
- Understand timeouts and why connections go stale
- Wire up the WebSocket HTTP handler
- Test a working (but basic) connection

---

## Before touching code — ask them to predict the read pump

"From our diagram, what does the read pump goroutine need to do?"

They should say:
1. Loop forever, waiting for the client to send a message
2. When a message arrives, send it to the Hub's broadcast channel
3. If the connection closes or errors, tell the Hub to unregister this client and stop

"What could cause the read loop to stop?" — errors, disconnects, server shutdown. "When it stops, what MUST happen?" — the client must be unregistered from the Hub, or the Hub will keep trying to send messages to a dead connection.

---

## The read pump

Guide them to write it. Don't show the code until they've attempted each part.

```go
func (c *Client) readPump() {
    // When this function exits (for any reason), unregister from the hub
    // and close the WebSocket connection.
    // "defer" guarantees this runs even if we return early due to an error.
    defer func() {
        c.hub.unregister <- c
        c.conn.Close()
    }()

    // Set limits so a misbehaving client can't hold the connection open forever
    // or send a giant message that fills our memory
    c.conn.SetReadLimit(512 * 1024) // 512KB max message size

    // Deadline: if we don't hear from the client in 60 seconds, close the connection
    c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))

    // When the client sends a "ping" response ("pong"), reset the deadline
    // This is the heartbeat mechanism — proves the client is still alive
    c.conn.SetPongHandler(func(string) error {
        c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
        return nil
    })

    // Loop: read messages until the connection closes
    for {
        _, message, err := c.conn.ReadMessage()
        if err != nil {
            // Connection closed or errored — exit the loop
            // The deferred function above will clean up
            if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
                log.Printf("websocket error: %v", err)
            }
            break
        }
        // Clean up whitespace and send to hub for broadcasting
        message = bytes.TrimSpace(message)
        c.hub.broadcast <- message
    }
}
```

Go through every part:

**Defer block:**
Ask: "Why is the cleanup in a defer, not after the loop?" (the loop can exit in multiple ways — normal close, error, server shutdown. Defer catches all of them.)

Ask: "Why do we need to BOTH unregister AND close the connection?" (unregister removes us from the hub's map — but the actual TCP connection is separate. We need to close both.)

**Read limits:**
"Without SetReadLimit, a malicious client could send a 1GB message and crash our server. We cap it at 512KB — way more than any chat message needs."

Ask: "What would happen if we forgot this limit and someone exploited it?" (memory exhaustion, server crash — this is a real category of attack called a DoS attack)

**Read deadline and Pong handler:**
This is subtle. Explain carefully.

"How does the server know if a client has silently disconnected? Their phone died, their wifi cut out, they closed the laptop. No 'close' message was sent — the connection just... died."

"The answer: ping/pong heartbeats. Every 54 seconds, our write pump will send a ping frame. The WebSocket protocol requires the browser to respond with a pong. If we get a pong, we reset the 60-second deadline. If we don't get a pong before the deadline... the connection is dead. We close it."

Ask: "Why 54 seconds for the ping interval and 60 seconds for the read deadline?" (gives the client 6 seconds to respond to the ping before we give up)

---

## The write pump

"What does the write pump goroutine need to do?"

They should say:
1. Wait for messages to appear in the client's `send` channel
2. When one arrives, write it to the WebSocket connection
3. Periodically send pings to check if the client is still alive
4. When the `send` channel closes (which happens when the hub unregisters this client), exit

```go
const (
    writeWait  = 10 * time.Second  // time allowed to write a message to the client
    pongWait   = 60 * time.Second  // time allowed to read the next pong from the client
    pingPeriod = (pongWait * 9) / 10 // send pings at 90% of the pong wait (54s)
)

func (c *Client) writePump() {
    // Create a ticker that fires every 54 seconds to send pings
    ticker := time.NewTicker(pingPeriod)

    defer func() {
        ticker.Stop()
        c.conn.Close()
    }()

    for {
        select {
        case message, ok := <-c.send:
            // Set a deadline for this write operation
            c.conn.SetWriteDeadline(time.Now().Add(writeWait))

            if !ok {
                // The hub closed the channel — we're done
                c.conn.WriteMessage(websocket.CloseMessage, []byte{})
                return
            }

            // Get a writer for the next message
            w, err := c.conn.NextWriter(websocket.TextMessage)
            if err != nil {
                return
            }
            w.Write(message)

            // Drain any queued messages and send them in the same WebSocket frame
            // (this is an optimization — batches messages that arrive at the same time)
            n := len(c.send)
            for i := 0; i < n; i++ {
                w.Write([]byte{'\n'})
                w.Write(<-c.send)
            }

            if err := w.Close(); err != nil {
                return
            }

        case <-ticker.C:
            // Ping time — check if client is still alive
            c.conn.SetWriteDeadline(time.Now().Add(writeWait))
            if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
                return // client didn't respond to the ping — connection is dead
            }
        }
    }
}
```

Key questions to ask:

"In `case message, ok := <-c.send` — what does the `ok` variable tell us?" (whether the channel is still open — when the hub calls `close(client.send)`, ok becomes false)

"Why do we drain queued messages in one frame?" (if 50 messages arrive at once, sending them as one batched write is faster than 50 separate WebSocket frames)

"What's the ticker for?" (periodic pings — connect this back to the read pump's pong handler discussion)

---

## The HTTP handler — upgrading the connection

"Now we need an HTTP handler that upgrades an incoming HTTP connection to a WebSocket. This is called the 'upgrader'."

```go
var upgrader = websocket.Upgrader{
    ReadBufferSize:  1024,
    WriteBufferSize: 1024,
    // In production you'd check the Origin header to prevent cross-site WebSocket hijacking
    // For now, allow all origins
    CheckOrigin: func(r *http.Request) bool {
        return true
    },
}

func ServeWs(hub *Hub, w http.ResponseWriter, r *http.Request) {
    // Upgrade the HTTP connection to WebSocket
    conn, err := upgrader.Upgrade(w, r, nil)
    if err != nil {
        log.Printf("websocket upgrade error: %v", err)
        return
    }

    // Create the client
    client := &Client{
        hub:  hub,
        conn: conn,
        send: make(chan []byte, 256), // buffered channel
    }

    // Register the client with the hub
    client.hub.register <- client

    // Start the two goroutines for this client
    // Each runs in the background — this function returns immediately
    go client.writePump()
    go client.readPump()
}
```

Ask:
- "Why does this function return immediately after starting the goroutines?" (the goroutines run independently — the HTTP handler just kicks them off and is done)
- "What's the buffer size of 256 for the send channel?" (the hub can queue up to 256 messages for this client before blocking — if it fills up, we assume the client is dead and disconnect them)

---

## Wire it up in main.go

Add the route and start the hub:
```go
hub := chat.NewHub()
go hub.run()

r.Get("/ws", func(w http.ResponseWriter, r *http.Request) {
    chat.ServeWs(hub, w, r)
})
```

Ask: "Why `go hub.run()` instead of just `hub.run()`?" (run() is an infinite loop — calling it without `go` would block main() and the HTTP server would never start)

---

## Test it — even without a frontend

Use a WebSocket testing tool. Guide them to install `websocat` (a curl-like tool for WebSockets):

```bash
brew install websocat  # mac

# Connect to the WebSocket
websocat ws://localhost:8080/ws
# Type a message and press Enter — you should see it echoed back
```

Or use the browser console:
```javascript
// Open browser, go to any page, open DevTools console, paste:
const ws = new WebSocket('ws://localhost:8080/ws');
ws.onmessage = (e) => console.log('received:', e.data);
ws.send('hello server');
```

Open two browser tabs and send from one — do they see it in both?

---

## Commit

```bash
git add .
git commit -m "Implement read pump, write pump, and WebSocket handler"
```
