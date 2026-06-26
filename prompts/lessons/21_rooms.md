# Lesson 21: Rooms — Multiple Conversations

**Paste into Claude Code after the system prompt**

---

## Context for Claude

The basic hub works — messages go to every connected client. Now they add rooms. This lesson is about evolving a working design rather than starting fresh. The mental model must update before the code does. Push them hard on the "why" before touching a single file.

**This lesson's goal:**
- Understand why a single broadcast-to-everyone model breaks with rooms
- Design the room model before coding it
- Update the Hub to support multiple rooms
- Understand the tradeoffs of different room implementations

---

## Start with the problem — make them feel it

"Right now, every message goes to everyone. Imagine this is a real chat app and there are 1000 users. There's a #golang room and a #cooking room. Someone in #cooking asks about pasta. Does everyone in #golang need to see that?"

"No. We need to send messages only to people in the same room."

Ask: "How would YOU change the hub to support rooms? What needs to change?"

Give them a few minutes to think. Don't help immediately. This thinking matters. They might say:
- "Add a room name to the message"
- "Have a separate hub per room"
- "Add a rooms field to the hub"

All of these are reasonable. Explore the tradeoffs with them.

---

## Two valid approaches — teach the tradeoff

**Option A: One hub, rooms are a map inside it**

```
Hub:
  rooms: map[string]map[*Client]bool
    "golang"  → {clientA, clientC, clientD}
    "cooking" → {clientB, clientE}
```

Pros: simple, one hub to manage everything
Cons: every broadcast now has to specify a room; the hub struct gets more complex

**Option B: One hub per room**

```
Hub for "golang":  {clientA, clientC, clientD}
Hub for "cooking": {clientB, clientE}
```

Pros: each room hub is simple (identical to what we already have)
Cons: need a "room registry" to track which hub belongs to which room

Ask: "Which would you choose? What's the consideration?"

Guide them toward: Option A is simpler and more practical for this project. Option B is cleaner architecturally but adds another layer of abstraction that's probably not worth it at this scale.

"We'll go with Option A. One hub, rooms are a field inside it."

---

## What a message needs to know

"Right now, a message is just `[]byte` — raw bytes. We're sending plain text. But now a message needs to carry more information. What does it need?"

Let them answer:
- Which room it belongs to
- Who sent it (username)
- The actual content
- Maybe a timestamp

"We need a message struct. And since we're sending it over WebSocket as text, we'll encode it as JSON."

Guide them to define:
```go
type Message struct {
    Room    string `json:"room"`
    User    string `json:"user"`
    Content string `json:"content"`
    SentAt  string `json:"sent_at"`
}
```

Ask: "Why JSON?" (the browser JavaScript on the other side can parse JSON natively — it's the language of the web)

Ask: "What was a message before?" (just `[]byte` — raw bytes of text)

Ask: "What is it now?" (a structured object we encode as JSON before sending, decode when receiving)

---

## Updating the Hub struct

"Now let's update the Hub. What needs to change?"

```go
type Hub struct {
    // rooms maps room name → set of clients in that room
    rooms      map[string]map[*Client]bool

    // broadcast now carries a full Message, not just bytes
    broadcast  chan Message

    register   chan *Client
    unregister chan *Client
}
```

Ask: "What changed from before?" (clients map is gone — replaced by rooms which is a map OF maps; broadcast carries a Message struct instead of raw bytes)

Ask: "If a client is in only one room, how do we know which room they're in?" — this is a good question. They need to think about where room membership lives.

Guide them: we add a `room string` field to the Client struct:
```go
type Client struct {
    hub  *Hub
    conn *websocket.Conn
    send chan []byte
    room string   // which room this client is in
    user string   // who this client is (username from JWT)
}
```

---

## Updating the Hub's run loop — carefully

"Now update the run loop. What changes in each case?"

**Register:**
Before: `h.clients[client] = true`
Now: need to create the room map if it doesn't exist, then add the client

```go
case client := <-h.register:
    if _, exists := h.rooms[client.room]; !exists {
        h.rooms[client.room] = make(map[*Client]bool)
    }
    h.rooms[client.room][client] = true
```

Ask: "Why do we check if the room exists first?" (the first client to join a room creates it; subsequent clients just add themselves)

Ask: "What's `make(map[*Client]bool)`?" (initializes a new empty map — you can't add to a nil map in Go)

**Unregister:**
```go
case client := <-h.unregister:
    if room, exists := h.rooms[client.room]; exists {
        if _, ok := room[client]; ok {
            delete(room, client)
            close(client.send)
            // If the room is now empty, delete the room entirely
            if len(room) == 0 {
                delete(h.rooms, client.room)
            }
        }
    }
```

Ask: "Why delete the room when it's empty?" (memory leak — if we never clean up empty rooms, a server running for weeks might accumulate hundreds of dead room maps)

Ask: "What's the risk of not cleaning up?" (memory grows forever — the program uses more and more RAM until the server runs out and crashes)

**Broadcast:**
```go
case message := <-h.broadcast:
    // Only send to clients in the SAME room
    if room, exists := h.rooms[message.Room]; exists {
        // Encode the message to JSON once, then send the same bytes to all clients
        data, err := json.Marshal(message)
        if err != nil {
            log.Printf("marshal error: %v", err)
            continue
        }
        for client := range room {
            select {
            case client.send <- data:
            default:
                close(client.send)
                delete(room, client)
            }
        }
    }
```

Ask: "Why do we encode to JSON once, outside the loop?" (encoding is work — why do the same work 100 times if we have 100 clients in the room? Encode once, send the same bytes to everyone)

Ask: "What is `continue` doing in the error case?" (skips to the next iteration of the outer for loop — like break but for the select, not the for)

---

## Updating the read pump to decode JSON

"Before, the read pump sent raw bytes to the hub. Now it needs to decode the JSON the browser sends and create a proper Message struct."

Guide them:
```go
_, rawMessage, err := c.conn.ReadMessage()
// ... error handling ...

var msg Message
if err := json.Unmarshal(rawMessage, &msg); err != nil {
    log.Printf("invalid message from %s: %v", c.user, err)
    continue // skip malformed messages, don't crash
}

// Fill in the fields the client didn't send
msg.Room = c.room
msg.User = c.user
msg.SentAt = time.Now().UTC().Format(time.RFC3339)

c.hub.broadcast <- msg
```

Ask: "Why do we fill in `Room` and `User` from the server rather than trusting what the client sends?"

This is a crucial security lesson. Let them think.

Guide toward: "Because the client could lie. If the browser sends `{"room": "admin", "user": "god", "content": "..."}`, and we trusted it, someone could impersonate anyone and talk in any room. We KNOW who they are from their JWT. We KNOW which room they're in because we assigned it when they connected. Never trust data from the client when you already know the answer."

---

## Checkpoint — rooms mental model

Before moving on, ask them to trace through this scenario with no notes:

"Alice is in #golang. Bob is in #cooking. Charlie is in #golang. Alice sends 'anyone tried generics yet?'"

Walk through every step:
1. Alice's browser → WebSocket → Alice's read pump goroutine
2. Read pump decodes JSON, fills in room="golang", user="alice"
3. Read pump sends Message to hub.broadcast channel
4. Hub's run goroutine receives it
5. Hub looks up h.rooms["golang"] → finds Alice and Charlie
6. Hub encodes Message to JSON bytes
7. Hub sends bytes to Alice's send channel and Charlie's send channel
8. Alice's write pump goroutine reads from send channel → sends over WebSocket → Alice's browser
9. Charlie's write pump goroutine reads from send channel → sends over WebSocket → Charlie's browser
10. Bob's browser receives NOTHING — Bob is in #cooking

"Can you do this from memory? Yes? Then you understand rooms."

---

## Commit

```bash
git add .
git commit -m "Add room support to hub — messages scoped to rooms"
```
