# Lesson 40: gRPC — What It Is and Why It Exists

**For Claude — do not show this file to the learner**

---

## Context for Claude

Project 6 takes the crypto price API from Project 1 and rebuilds it as a gRPC service with a streaming price ticker. This lesson is purely conceptual: what gRPC is, why it exists, how it differs from REST, and what Protocol Buffers are. No code until the mental model is solid.

**This lesson's goal:**
- Understand what gRPC is at a protocol level
- Know the difference between REST and gRPC (when to use which)
- Understand what Protocol Buffers are and why they exist vs JSON
- Know the four types of gRPC methods: unary, server streaming, client streaming, bidirectional
- Be able to explain what a `.proto` file is

---

## The problem with REST at scale

"REST with JSON works great. You've built three projects with it. But it has inefficiencies that matter at scale:"

1. **JSON is text** — it's human-readable, but a computer has to parse strings into numbers and booleans. Bigger payload than necessary.
2. **No contract** — REST APIs don't enforce a schema. Any field can be missing, null, or a different type than you expected. You find out at runtime.
3. **One request, one response** — you can't stream data from a REST endpoint without workarounds (SSE, polling).
4. **No built-in code generation** — you write client and server code by hand, both have to agree on the same field names and types.

"gRPC solves all four. It's used by Google, Netflix, Uber, Square — anywhere services talk to each other at high volume."

Ask: "Can you think of when real-time streaming would matter in the crypto context?" (live price feed — instead of polling every second, the server pushes new prices as they come in)

---

## What gRPC actually is

"gRPC is:
1. A protocol built on HTTP/2 (vs HTTP/1.1 for most REST)
2. Uses Protocol Buffers (protobuf) for serialization — binary, typed, compact
3. Generates client and server code from a schema file (`.proto`)
4. Supports four types of communication:

```
Unary:               Client sends one request, server responds once
                     (same as REST)

Server streaming:    Client sends one request, server responds with a stream
                     (perfect for price tickers)

Client streaming:    Client sends a stream, server responds once
                     (uploading a large file in chunks)

Bidirectional:       Both sides stream simultaneously
                     (live chat, game state sync)
```"

Draw this out. Have them describe which type matches each use case:
- "Getting the current ETH price" → Unary
- "Subscribing to live price updates" → Server streaming
- "Uploading a CSV of transactions for analysis" → Client streaming
- "A trading platform where you stream orders and receive fills" → Bidirectional

---

## Protocol Buffers

"Protocol Buffers are a language-neutral way to define the shape of your data. Instead of JSON fields that could be anything, you declare exact types in a `.proto` file."

Compare:

```json
// JSON — no contract, types are implicit
{
  "symbol": "ETH",
  "price": 3241.50,
  "timestamp": 1720000000
}
```

```protobuf
// Protobuf — explicit types, numbered fields
message PriceUpdate {
  string symbol    = 1;
  double price     = 2;
  int64  timestamp = 3;
}
```

"When serialized, protobuf uses field numbers (1, 2, 3) not names. The binary is much smaller and faster to decode."

Ask: "What happens in JSON if a server adds a new field that the client doesn't know about?" (usually fine — Go's JSON decoder ignores unknown fields by default)
Ask: "What happens in protobuf if a server adds a new field?" (clients that don't know about it simply ignore it — same behavior, but the schema is versioned and explicit)
Ask: "Why are fields numbered instead of named?" (field numbers don't change even if you rename the field — old clients and new servers can still communicate)

---

## When to use gRPC vs REST

"This is a real engineering decision. Here's the rule of thumb:"

| Use REST when | Use gRPC when |
|---|---|
| Public-facing API (browsers, mobile) | Internal service-to-service communication |
| You want to be easily curl-able | You need streaming |
| Clients might be in many languages | You want strict schema enforcement |
| Simplicity matters more than performance | You need maximum performance |

"In practice: user-facing APIs are usually REST (Lesson 1). Backend services talking to each other are often gRPC."

Ask: "Our crypto API from Project 1 — is it user-facing or backend?" (depends — if a frontend app calls it, REST makes sense. If another backend service calls it for processing, gRPC makes more sense.)

---

## What we're building

"We'll build a gRPC service on top of the crypto API from Project 1. Two endpoints:
1. `GetPrice(symbol)` → `PriceResponse` — unary, get current price
2. `StreamPrices(symbols)` → stream of `PriceUpdate` — server streaming, push live prices"

"Then a Go client that calls both."

---

## Checkpoint — no notes

1. "Name the four types of gRPC methods and give an example use case for each."
2. "What is a `.proto` file?"
3. "Why are protobuf fields numbered instead of named?"
4. "Name two reasons gRPC is faster than REST+JSON."
5. "When would you choose REST over gRPC?"
6. "What does HTTP/2 give you that HTTP/1.1 doesn't?" (multiplexing — multiple requests/responses on one TCP connection simultaneously; header compression; binary framing)

---

## No code this lesson. No commit.

Next lesson: write the `.proto` file and generate Go code.
