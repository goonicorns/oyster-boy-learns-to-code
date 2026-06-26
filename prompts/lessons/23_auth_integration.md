# Lesson 23: Auth Integration — Who Are You on a WebSocket?

**Paste into Claude Code after the system prompt**

---

## Context for Claude

The chat server has rooms and history. But right now anyone can connect with any username — there's no authentication. This lesson wires in their existing JWT system. The twist: WebSocket connections don't use HTTP headers the same way REST endpoints do. This lesson forces them to think about HOW to pass credentials over a different transport.

**This lesson's goal:**
- Understand why WebSocket auth is different from REST auth
- Pass JWTs over WebSocket (via query parameter or initial message)
- Verify the token before accepting the connection
- Connect the user's identity to their Client struct
- Understand what happens when an unauthenticated client tries to connect

---

## The problem — make them feel it

"In our API endpoints, we check the JWT in the `Authorization: Bearer <token>` HTTP header. The middleware reads it, verifies it, attaches the user ID to the request context. Simple."

"A WebSocket connection starts as an HTTP request — the upgrade request. Can we use that same header?"

Let them think. The answer is: technically yes, but browsers make it hard.

"The browser's WebSocket API doesn't let you set custom headers. You can't do:
```javascript
// This DOES NOT work in browsers
const ws = new WebSocket('ws://localhost:8080/ws', {
    headers: { 'Authorization': 'Bearer ...' }
})
```

"The browser WebSocket constructor only accepts the URL and a protocol string. Custom headers aren't supported."

Ask: "So how do we pass the token?"

Let them brainstorm. Common options:
1. Put the token in the URL query string: `ws://localhost:8080/ws?token=abc123`
2. Send the token as the FIRST message after connecting, before any chat messages
3. Use a cookie (if JWT is stored in a cookie)

"Each has tradeoffs. Query string: simple, but the token appears in server logs — a minor security concern. First message: clean, but adds a handshake round-trip. Cookie: works if you set it on login, but requires cookie setup."

Guide them: "We'll use the query string for now. It's simple, and for a learning project the log concern is acceptable. In production you'd likely use the first-message approach or cookies."

---

## How token verification changes

"Right now our auth middleware does the verification. For WebSocket, we can't use middleware the same way because the connection is long-lived — middleware runs once at upgrade time, not on every message."

"So we verify the token IN ServeWs, at connection time. If the token is invalid, we reject the upgrade. If it's valid, we know who this client is for the lifetime of the connection."

Ask: "What happens to the user's identity after we verify the token?" (we store it in the Client struct's `user` field — then every message from this connection automatically has the right username, and the client can't lie about who they are)

---

## Move JWT logic to a shared function

"Right now the JWT verification might be inside the middleware. We need to call it from ServeWs too. What's the right thing to do?"

Guide them: extract the verification into a shared function in the middleware or auth package that both can call:

```go
// middleware/auth.go — add this function
func VerifyToken(tokenString string) (int, error) {
    token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
        if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
            return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
        }
        return []byte(os.Getenv("JWT_SECRET")), nil
    })
    if err != nil {
        return 0, fmt.Errorf("invalid token: %w", err)
    }

    claims, ok := token.Claims.(jwt.MapClaims)
    if !ok || !token.Valid {
        return 0, fmt.Errorf("invalid token claims")
    }

    userID, ok := claims["user_id"].(float64) // JWT numbers decode as float64
    if !ok {
        return 0, fmt.Errorf("user_id not found in token")
    }

    return int(userID), nil
}
```

Ask: "Why does `claims["user_id"]` come back as `float64`?" (JSON numbers are all floats — when JWT decodes claims to a `map[string]interface{}`, all numbers become float64. We convert to int.)

Ask: "What would happen if we forgot to validate `token.Valid`?" (we'd accept expired or tampered tokens — always check this)

---

## Update ServeWs to verify the token

```go
func ServeWs(hub *Hub, w http.ResponseWriter, r *http.Request) {
    // Get token from query string
    tokenString := r.URL.Query().Get("token")
    if tokenString == "" {
        http.Error(w, "missing token", http.StatusUnauthorized)
        return
    }

    // Verify the token and get the user ID
    userID, err := middleware.VerifyToken(tokenString)
    if err != nil {
        http.Error(w, "invalid token", http.StatusUnauthorized)
        return
    }

    // Look up the username from the database
    username, err := store.GetUsernameByID(r.Context(), userID)
    if err != nil {
        http.Error(w, "user not found", http.StatusUnauthorized)
        return
    }

    // Get room from query string
    room := r.URL.Query().Get("room")
    if room == "" {
        room = "general" // default room
    }

    // Now upgrade the connection — we've verified they're allowed in
    conn, err := upgrader.Upgrade(w, r, nil)
    if err != nil {
        log.Printf("upgrade error: %v", err)
        return
    }

    client := &Client{
        hub:  hub,
        conn: conn,
        send: make(chan []byte, 256),
        room: room,
        user: username,
    }

    client.hub.register <- client

    go func() {
        history, _ := store.GetRecentMessages(r.Context(), room, 50)
        for _, msg := range history {
            data, _ := json.Marshal(msg)
            client.send <- data
        }
    }()

    go client.writePump()
    go client.readPump()
}
```

Walk through with questions:

Ask: "We verify the token BEFORE upgrading the connection. Why?" (if the token is invalid, we want to return a regular HTTP 401 error. Once we upgrade to WebSocket, we can no longer send HTTP status codes — we'd have to close the WebSocket instead)

Ask: "What's `store.GetUsernameByID`?" (they need to write this — a simple SELECT by user ID)

Guide them to add to `store/user.go`:
```go
func GetUsernameByID(ctx context.Context, id int) (string, error) {
    var username string
    err := DB.QueryRow(ctx,
        "SELECT username FROM users WHERE id = $1",
        id,
    ).Scan(&username)
    if err != nil {
        return "", fmt.Errorf("user %d not found: %w", id, err)
    }
    return username, nil
}
```

---

## Test auth is enforced

```bash
# Try connecting without a token — should get 401
curl -i http://localhost:8080/ws
# Expected: HTTP/1.1 401 Unauthorized

# Get a real token first
TOKEN=$(curl -s -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"pass123"}' | jq -r '.token')

# Connect with the token
websocat "ws://localhost:8080/ws?token=$TOKEN&room=general"
# Should connect successfully

# Try with a fake token
websocat "ws://localhost:8080/ws?token=faketoken&room=general"
# Should get 401 and connection refused
```

---

## The security properties to lock in

Stop and be explicit about this. Ask them:

"What can an authenticated user NOT do now?"

They should be able to say:
1. Can't pretend to be someone else — username comes from the verified JWT
2. Can't talk in a room as the wrong user — identity is locked at connection time
3. Can't connect at all without a valid, unexpired token

"What CAN they still do that a production app would lock down further?"
- Join any room (no room permissions yet)
- Send messages as fast as they want (no rate limiting)
- Send any content (no content moderation)

"These are product features, not bugs. We'd add them as the app grows."

---

## Commit

```bash
git add .
git commit -m "Add JWT authentication to WebSocket connections"
```
