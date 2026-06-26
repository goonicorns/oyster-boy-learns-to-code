# Lesson 25: Testing — How Do You Test Real-Time Code?

**Paste into Claude Code after the system prompt**

---

## Context for Claude

Testing WebSocket code is genuinely harder than testing HTTP endpoints. This lesson teaches them to think carefully about what to test, why certain things are hard to test, and how to design their code to be testable. Don't shy away from the difficulty — the fact that some things are hard to test is itself an important lesson. Focus on testing the things they CAN and SHOULD test: the hub logic and the message history functions.

**This lesson's goal:**
- Understand why real-time code is harder to test than REST endpoints
- Learn what IS worth unit testing and what isn't
- Write unit tests for the hub's core logic
- Write unit tests for message store functions
- Understand the concept of testability as a design goal

---

## Start with the hard question

"We've written tests before. We tested SMA and EMA with table-driven tests — those were pure functions. Input goes in, output comes out. Easy."

"How would you test the Hub?"

Let them think. They'll realize: it's hard. The hub runs in a goroutine. It processes messages asynchronously. How do you check what happened?

"This is a real challenge. You've just discovered that some code is harder to test than other code. The question is: WHY?"

Guide them toward: the hub has **side effects** and **concurrency**. Pure functions are easy to test because they just transform input to output. The hub sends messages to channels, modifies maps, starts goroutines — all of which happen at unpredictable times.

"There are three ways engineers deal with this:
1. Test the pure parts separately (test hub logic without goroutines)
2. Write integration tests that let goroutines run and check outcomes after
3. Accept that some behavior is hard to unit-test and cover it with end-to-end tests

We'll do all three."

---

## Test the pure store functions first — they're easy

"Before we tackle the hub, let's test what we know how to test. The message store functions are database operations. We've done this before with the crypto project."

Ask: "What do we need to test `SaveMessage` and `GetRecentMessages`?"

They should say: a real database. Remind them: don't mock the database. We got burned when mock tests passed but real DB queries broke. (Reference the lesson from the crypto project if they remember it.)

**Test for SaveMessage:**
```go
func TestSaveMessage(t *testing.T) {
    // Setup: clean test database
    // (They should know this pattern from previous projects)
    
    err := store.SaveMessage(context.Background(), "test-room", "alice", "hello world")
    if err != nil {
        t.Fatalf("SaveMessage failed: %v", err)
    }

    // Verify it actually saved
    messages, err := store.GetRecentMessages(context.Background(), "test-room", 10)
    if err != nil {
        t.Fatalf("GetRecentMessages failed: %v", err)
    }

    if len(messages) != 1 {
        t.Fatalf("expected 1 message, got %d", len(messages))
    }

    if messages[0].Content != "hello world" {
        t.Errorf("expected content 'hello world', got '%s'", messages[0].Content)
    }
    if messages[0].Username != "alice" {
        t.Errorf("expected username 'alice', got '%s'", messages[0].Username)
    }
    if messages[0].Room != "test-room" {
        t.Errorf("expected room 'test-room', got '%s'", messages[0].Room)
    }
}
```

Ask: "What's the risk if we don't clean up test data between tests?" (tests might affect each other — one test's data bleeds into another's assertions)

Ask: "How would you make this test clean up after itself?" (defer a DELETE query, or use a transaction that you rollback at the end)

**Test for history ordering:**
```go
func TestGetRecentMessagesOrdering(t *testing.T) {
    // Save messages with known order
    messages := []string{"first", "second", "third"}
    for _, content := range messages {
        if err := store.SaveMessage(ctx, "ordering-test", "alice", content); err != nil {
            t.Fatal(err)
        }
        time.Sleep(1 * time.Millisecond) // ensure distinct timestamps
    }

    got, err := store.GetRecentMessages(ctx, "ordering-test", 10)
    if err != nil {
        t.Fatal(err)
    }

    if len(got) != 3 {
        t.Fatalf("expected 3, got %d", len(got))
    }

    // They should come back oldest-first (we reverse from the DB)
    for i, want := range messages {
        if got[i].Content != want {
            t.Errorf("position %d: expected '%s', got '%s'", i, want, got[i].Content)
        }
    }
}
```

Ask: "Why `time.Sleep(1 * time.Millisecond)` between saves?" (to guarantee distinct timestamps — without it, they might be saved at the same millisecond and the ordering would be undefined)

---

## Test the hub — the tricky part

"Now the hub. Here's the key insight: we can test the hub's logic WITHOUT goroutines by calling its methods directly in a test, THEN running the hub's run loop just long enough to process the messages."

Show them a test for registration:

```go
func TestHubRegisterClient(t *testing.T) {
    hub := NewHub()
    
    // Create a fake client with a test WebSocket
    // (gorilla/websocket has a test helper for this)
    server, client := net.Pipe() // creates two connected net.Conn
    wsServer := &websocket.Conn{} // simplified - see below
    
    c := &Client{
        hub:  hub,
        send: make(chan []byte, 256),
        room: "general",
        user: "alice",
    }
    
    // Start the hub in a goroutine (it runs until we stop it)
    go hub.run()
    
    // Register the client
    hub.register <- c
    
    // Give the hub a moment to process
    time.Sleep(10 * time.Millisecond)
    
    // Check that the client is now in the hub's rooms map
    // Problem: hub.rooms is private... how do we check it?
}
```

"Wait. There's a problem. `hub.rooms` is unexported — lowercase. We can't access it from a test in a different package. What do we do?"

Let them think. Options:
1. Make it exported (uppercase) — exposes internal state, usually bad
2. Move the test to the same package (`package chat` not `package chat_test`)
3. Add a method that returns information we need for testing

Ask: "Which would you choose?"

Guide toward option 2 — `package chat` in the test file means you're testing internals, which is appropriate for unit tests. Integration tests use `package chat_test` (external).

```go
// In hub_test.go — note: package chat (not chat_test)
package chat

func TestHubRegisterClient(t *testing.T) {
    hub := NewHub()
    go hub.run()
    
    c := &Client{
        hub:  hub,
        send: make(chan []byte, 256),
        room: "general",
        user: "alice",
    }
    
    hub.register <- c
    time.Sleep(10 * time.Millisecond) // let the goroutine process
    
    if _, exists := hub.rooms["general"]; !exists {
        t.Error("room 'general' should exist after registration")
    }
    if _, exists := hub.rooms["general"][c]; !exists {
        t.Error("client should be in 'general' room after registration")
    }
}
```

Ask: "Why is `time.Sleep` in a test a code smell?" (tests with sleeps are non-deterministic — they might pass on a fast machine and fail on a slow one, or pass sometimes and fail other times)

"What's the better approach?" (use a channel to signal when the hub has processed the message — but that requires changing the hub's API to support testing. For now, a short sleep is acceptable but acknowledge it's not ideal.)

---

## Test broadcast routing

```go
func TestHubBroadcastOnlyToRoom(t *testing.T) {
    hub := NewHub()
    go hub.run()
    
    // Client in "golang" room
    golangClient := &Client{
        hub:  hub,
        send: make(chan []byte, 256),
        room: "golang",
        user: "alice",
    }
    
    // Client in "cooking" room
    cookingClient := &Client{
        hub:  hub,
        send: make(chan []byte, 256),
        room: "cooking",
        user: "bob",
    }
    
    hub.register <- golangClient
    hub.register <- cookingClient
    time.Sleep(10 * time.Millisecond)
    
    // Broadcast a message to "golang"
    hub.broadcast <- Message{
        Room:    "golang",
        User:    "alice",
        Content: "hello golang",
    }
    time.Sleep(10 * time.Millisecond)
    
    // golangClient should have received the message
    select {
    case msg := <-golangClient.send:
        var m Message
        json.Unmarshal(msg, &m)
        if m.Content != "hello golang" {
            t.Errorf("expected 'hello golang', got '%s'", m.Content)
        }
    default:
        t.Error("golang client should have received the message")
    }
    
    // cookingClient should NOT have received anything
    select {
    case msg := <-cookingClient.send:
        t.Errorf("cooking client should NOT have received a message, but got: %s", msg)
    default:
        // Correct — nothing in the channel
    }
}
```

Walk through the test structure:
- Ask: "What is `select { case ...: default: }` doing here?" (non-blocking channel check — if there's something in the channel, read it; if not, immediately take the default branch)
- Ask: "Why do we need the non-blocking check?" (we don't want the test to hang forever waiting for a message that will never come)

---

## What NOT to test

Equally important: knowing when NOT to write a test.

"Should we write a unit test for the WebSocket read pump? The write pump? The ping/pong heartbeat?"

Let them think. Guide toward: these are hard to unit test because they require a real WebSocket connection and involve time-based behavior (ping every 54 seconds). The cost of testing them correctly exceeds the benefit.

"The right level of testing for this code is integration testing — running the whole server and connecting to it with a real WebSocket client. That's what manual testing with the browser catches."

"In a real production codebase, you might have:
- Unit tests for pure functions (what we wrote)
- Integration tests for server behavior (running the real server against a test database)
- End-to-end tests that drive a browser (using Playwright or Cypress)

We have the first two. That's good enough for this project."

---

## Run all tests

```bash
go test ./...
```

"Green? Good. What does `./...` mean?" (run tests in this directory AND all subdirectories recursively)

"What's the test coverage of our code?" 

```bash
go test ./... -cover
```

"Coverage tells you what percentage of your code is executed by tests. Is 100% coverage the goal?" — No. Guide them toward: 100% coverage often means you're testing trivial things just to hit the number. The goal is to test the things that matter: the business logic, the edge cases, the security-critical paths.

---

## Commit

```bash
git add .
git commit -m "Add unit tests for hub broadcast routing and message store"
```
