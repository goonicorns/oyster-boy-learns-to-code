# Lesson 48: Key-Value Store — What We're Building

**For Claude — do not show this file to the learner**

---

## Context for Claude

Project 8 builds a simplified Redis from scratch — a TCP server that stores key-value pairs in memory, supports TTL expiry, and persists to disk. Before any code, the mental model: what IS a key-value store, why TCP not HTTP, and what protocol they'll implement.

**This lesson's goal:**
- Understand what a key-value store is and when you'd use one
- Know why Redis uses TCP, not HTTP
- Understand the RESP protocol at a high level
- Know what TTL is and why it matters
- Plan the data structures before writing them

---

## What is a key-value store?

"A key-value store is the simplest useful database. Every value has a key. You store by key, you retrieve by key."

```
SET user:123:name  "Alice"
GET user:123:name   → "Alice"

SET session:abc token "eyJ..."
GET session:abc        → "eyJ..."

DEL user:123:name
GET user:123:name   → (nil)
```

"When would you use this instead of Postgres?"
- Session storage (user logged in → token in Redis, fast lookup)
- Caching (expensive DB query result → store in Redis for 5 minutes)
- Rate limiting (count how many requests this IP made in the last minute)
- Pub/Sub messaging
- Leaderboards (sorted sets by score)

"What you WOULDN'T use it for: complex queries, relationships, transactions across multiple records, joins."

Ask: "In Project 1's JWT auth, where is the 'is this token valid' check happening?" (decoding the JWT and verifying the signature — stateless. An alternative: store token→user in Redis, look it up on every request — stateful.)
Ask: "Which approach is faster?" (Redis lookup is faster for the lookup, but stateless JWT means no DB call at all for many checks)

---

## Why TCP, not HTTP?

"Redis uses raw TCP. No HTTP. Why?"

"HTTP adds overhead: headers, status lines, content-type, host header. For a database that runs inside your datacenter, called thousands of times per second, that overhead matters."

"TCP gives you a raw byte stream. You design exactly the protocol you need. No overhead."

"This is the same reason databases (Postgres, MySQL) use their own TCP protocols, not HTTP."

Ask: "When IS HTTP a good choice even for internal services?" (when you need things like streaming, existing tooling like curl/browsers, or you're doing gRPC which is HTTP/2 underneath)

---

## Our protocol (simplified RESP)

"Redis uses RESP — REdis Serialization Protocol. We'll implement a simplified version."

Our commands:
```
SET key value         — store a value
SET key value EX 30   — store with expiry in seconds
GET key               — retrieve a value
DEL key               — delete a key
EXISTS key            — check if key exists
TTL key               — seconds until expiry (-1 if no expiry, -2 if missing)
KEYS *                — list all keys (or keys matching a pattern)
FLUSH                 — delete everything
```

Our wire format (text-based, simple to implement and debug):
```
Client sends:   SET mykey myvalue\n
Server replies: OK\n

Client sends:   GET mykey\n
Server replies: myvalue\n

Client sends:   GET nonexistent\n
Server replies: (nil)\n

Client sends:   SET counter 0 EX 60\n
Server replies: OK\n

Client sends:   TTL counter\n
Server replies: 57\n        (time remaining)
```

"Real RESP is binary-safe and more complex. Ours is text-based — easier to understand, telnet-testable."

Ask: "What's the advantage of real RESP's binary format over our text format?" (values can contain newlines and special characters without escaping; our protocol would break if a value contains `\n`)

---

## Plan the data structures

"Before code — what do we need in memory?"

Have them think through it:

```go
type Store struct {
    mu      sync.RWMutex
    data    map[string]string        // key → value
    expiry  map[string]time.Time     // key → expiry time (if set)
}
```

Ask: "Why two maps instead of one?" (clean separation — not every key has an expiry. Storing the expiry in a struct alongside the value would work too — ask them to consider both designs)

Ask: "How do you check if a key has expired?" (`time.Now().After(expiry[key])`)

Ask: "What happens if we never clean up expired keys?" (they stay in memory forever — memory leak. Redis uses two strategies: lazy expiry on GET, and active expiry that periodically scans for expired keys)

---

## Checkpoint

1. "Name three things you'd use Redis for that you wouldn't use Postgres for."
2. "Why does Redis use TCP instead of HTTP?"
3. "What does TTL stand for? Give a real-world example of when you'd use it."
4. "What would break in our text protocol if a value contained a newline character?"
5. "What are the two expiry strategies Redis uses to clean up expired keys?"
6. "In our Store struct, why do we need `sync.RWMutex`?" (concurrent clients reading and writing simultaneously)

---

## No code this lesson. No commit.
