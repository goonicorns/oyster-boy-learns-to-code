# Lesson 22: Message History — Postgres for Persistence

**Paste into Claude Code after the system prompt**

---

## Context for Claude

The chat server works in memory. But if the server restarts, all messages are gone. And when a new user joins a room, they see nothing — no context of what was discussed before they arrived. This lesson adds Postgres persistence. It should feel familiar — they've done this before — but the flow is more interesting because it happens at two points: on send AND on join.

**This lesson's goal:**
- Understand why in-memory state is temporary
- Store messages in Postgres as they're sent
- Load message history when a client joins a room
- Send history to a new client before live messages start

---

## Start with the "server restart" problem

"What happens to our chat messages when we restart the server?"

They should know: gone. The hub's room maps live in RAM. RAM is wiped on restart.

"This is the fundamental difference between memory and a database. Memory is fast but temporary. A database is slower but permanent. For a chat app, which messages need to be permanent?"

Let them answer. Guide toward: all of them — users expect to scroll back and see what was said.

"What about the in-memory hub — do we get rid of it now that we have a database?"

This is a great question. The answer is NO, and the reason matters:

"The hub stays. It's still responsible for real-time delivery — routing live messages to connected clients instantly. The database is for persistence — reading history. They do different jobs. Fast things in memory, permanent things in the database. We use both."

This is a real architecture pattern. Reinforce it: "Slack works the same way. When you're in a channel, live messages come through WebSocket (like our hub). When you scroll back, it reads from their database. Two systems, two jobs."

---

## Schema design

"Before writing any Go, let's design the table. What columns does a messages table need?"

Let THEM design it. Ask questions to guide:
- "What identifies which room a message belongs to?" → `room`
- "Who sent it?" → `user`
- "What did they say?" → `content`
- "When?" → `sent_at`
- "Do we need a primary key?" → yes, `id`

```sql
CREATE TABLE messages (
    id         SERIAL PRIMARY KEY,
    room       VARCHAR(100) NOT NULL,
    username   VARCHAR(50) NOT NULL,
    content    TEXT NOT NULL,
    sent_at    TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Index on room + sent_at so history queries are fast
CREATE INDEX idx_messages_room_sent_at ON messages(room, sent_at DESC);
```

Have them run this in psql.

Ask: "What is the index for?" — don't let them skip this.

Guide toward: "When we load history for a room, we'll say 'give me the last 50 messages in #golang, ordered by time.' Without an index, Postgres scans EVERY row in the table looking for matching room values. With an index on (room, sent_at), it jumps directly to the right rows. The difference is seconds vs milliseconds once you have millions of messages."

Ask: "Why `DESC` in the index?" (our query will order by sent_at DESC to get recent messages first)

---

## Store functions

Guide them to create `store/message.go`. Two functions:

**SaveMessage:**
```go
func SaveMessage(ctx context.Context, room, username, content string) error {
    _, err := DB.Exec(ctx,
        `INSERT INTO messages (room, username, content) VALUES ($1, $2, $3)`,
        room, username, content,
    )
    if err != nil {
        return fmt.Errorf("saving message to %s: %w", room, err)
    }
    return nil
}
```

Ask: "Why don't we pass `sent_at`?" (the DB default handles it — `DEFAULT NOW()`)

Ask: "Should SaveMessage block the hub's run loop?" — this is subtle. Think about it.

"The hub's run loop is the bottleneck of the entire server. If SaveMessage is slow (database under load, network hiccup), the hub blocks. While the hub blocks, NO messages get delivered to ANYONE."

Guide toward: "We should save messages asynchronously — in a goroutine — so the hub never waits on the database."

```go
// In the hub's broadcast handling:
go func(msg Message) {
    if err := store.SaveMessage(ctx, msg.Room, msg.User, msg.Content); err != nil {
        log.Printf("saving message: %v", err)
    }
}(message) // pass message as argument — goroutine closure gotcha
```

Ask: "Why pass `message` as a function argument instead of capturing it directly?" (by the time the goroutine runs, the loop may have advanced to a new message — capturing it directly means all goroutines might see the same last value. Passing it as an argument gives each goroutine its own copy.)

This is the closure gotcha from the goroutine exercises. Make them connect it.

**GetRecentMessages:**
```go
func GetRecentMessages(ctx context.Context, room string, limit int) ([]model.ChatMessage, error) {
    rows, err := DB.Query(ctx,
        `SELECT id, room, username, content, sent_at
         FROM messages
         WHERE room = $1
         ORDER BY sent_at DESC
         LIMIT $2`,
        room, limit,
    )
    if err != nil {
        return nil, fmt.Errorf("fetching history for %s: %w", room, err)
    }
    defer rows.Close()

    var messages []model.ChatMessage
    for rows.Next() {
        var m model.ChatMessage
        if err := rows.Scan(&m.ID, &m.Room, &m.Username, &m.Content, &m.SentAt); err != nil {
            return nil, err
        }
        messages = append(messages, m)
    }

    // Reverse: DB returned newest-first, we want oldest-first for display
    for i, j := 0, len(messages)-1; i < j; i, j = i+1, j-1 {
        messages[i], messages[j] = messages[j], messages[i]
    }

    return messages, rows.Err()
}
```

Ask: "We've reversed a slice before. Why are we reversing here?" (DB returns newest first because of ORDER BY DESC — we want to display oldest first, top to bottom)

Ask: "What limit should we use?" (50 is reasonable — enough context without overwhelming someone who just joined)

---

## Add ChatMessage to the model

```go
type ChatMessage struct {
    ID       int    `json:"id"`
    Room     string `json:"room"`
    Username string `json:"username"`
    Content  string `json:"content"`
    SentAt   string `json:"sent_at"`
}
```

---

## Sending history when a client joins

"When a new client connects to a room, what should they see?"

The last 50 messages. But there's a timing question. Ask them:

"When should we send history — before or after registering the client with the hub?"

This is subtle. Let them think.

Answer: AFTER registering. Here's why:

"If we send history before registering, there's a tiny gap. Between the time history is sent and the time the client registers, a live message could arrive and get lost. By registering first and then sending history, we guarantee the client will receive all live messages from the moment they connect. The history and live messages might overlap slightly, but that's fine — better to see a message twice than to miss one."

Guide them to update `ServeWs`:

```go
func ServeWs(hub *Hub, w http.ResponseWriter, r *http.Request) {
    // ... upgrade, create client ...

    // Register FIRST — client will now receive live messages
    client.hub.register <- client

    // THEN send history as a batch
    go func() {
        history, err := store.GetRecentMessages(r.Context(), client.room, 50)
        if err != nil {
            log.Printf("fetching history for %s: %v", client.room, err)
            return
        }
        for _, msg := range history {
            data, _ := json.Marshal(msg)
            client.send <- data
        }
    }()

    // Start the pumps
    go client.writePump()
    go client.readPump()
}
```

Ask: "Why send history in a goroutine?" (so ServeWs doesn't block waiting for the DB query — the pumps start immediately, history loads in the background)

Ask: "What if history loads AFTER some live messages arrive?" (the client gets: live message → history. Confusing? Yes. We could sort on the client side, or add a message type field to distinguish history from live. For now, live messages have a timestamp — the browser can sort. This is a real product decision.)

---

## Test it end to end

```bash
go run main.go

# In browser console tab 1:
const ws = new WebSocket('ws://localhost:8080/ws?room=golang');
ws.onmessage = e => console.log(JSON.parse(e.data));
ws.send(JSON.stringify({content: 'hello from tab 1'}));

# In browser console tab 2:
const ws2 = new WebSocket('ws://localhost:8080/ws?room=golang');
ws2.onmessage = e => console.log(JSON.parse(e.data));
# When tab 2 connects, it should receive the message tab 1 sent earlier (from history)
```

Check the database:
```bash
docker exec -it cryptowatch-db psql -U dev -d cryptowatch \
  -c "SELECT room, username, content, sent_at FROM messages ORDER BY sent_at DESC LIMIT 10;"
```

"Do you see your messages? Restart the server. Connect again. Does history still appear?"

---

## The pattern to burn in

Drill this into them explicitly before the commit:

"Memory is for now. Database is forever. The hub handles real-time delivery — fast, in memory. The database handles persistence — reliable, permanent. Every production system that does real-time and persistence uses this split. Slack, Discord, any trading platform, any live sports feed. Same pattern."

---

## Commit

```bash
git add .
git commit -m "Persist messages to Postgres, load history on room join"
```
