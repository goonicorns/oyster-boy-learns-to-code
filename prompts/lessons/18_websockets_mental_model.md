# Lesson 18: WebSockets — Understanding What They Actually Are

**Paste into Claude Code after the system prompt**

---

## Context for Claude

This is the start of the third project: a real-time chat server. Before a single line of code, the learners need a deep, concrete mental model of WebSockets. This lesson is entirely conceptual. Do not let them touch code until they can explain WebSockets in their own words without prompting.

**This lesson's goal:**
- Understand WHY HTTP fails for real-time apps
- Understand exactly what a WebSocket is and how it works
- Build a mental model strong enough to understand everything that follows
- Know the difference between HTTP and WebSocket at a protocol level

---

## The problem with HTTP first — make it stick

Start here. Do not jump to WebSockets.

"Tell me what happens when you open a webpage. Walk me through it step by step."

Let them answer. Fill in gaps. The answer should be:
1. Browser sends an HTTP request to a server
2. Server receives it, processes it, sends back a response
3. **Connection closes**
4. Done

"That's it. HTTP is letters. You write a letter (request), mail it, the server writes back (response), and both of you put down the pen. The conversation is over."

"Now ask yourself: how does that work for a chat app? You're in a conversation with someone. A message comes in. How does your browser know?"

Let them think. They'll probably say "it checks repeatedly?" — exactly right. That's called **polling**. Show them what that looks like:

```
Browser: "Any new messages?" → Server: "No."
Browser: "Any new messages?" → Server: "No."
Browser: "Any new messages?" → Server: "No."
Browser: "Any new messages?" → Server: "Yes! Here's one."
Browser: "Any new messages?" → Server: "No."
```

"How often would you poll? Every second? Every 100ms? What if you have 10,000 users all polling every second? That's 10,000 HTTP requests per second for... mostly 'No.' That's wasteful and slow."

Ask: "Can you think of a better model? Instead of the browser asking constantly, what if the server could... what?"

Let them arrive at: "the server could just tell us when something happens."

---

## WebSockets — the phone call model

"That's exactly what WebSockets are. Instead of letters, it's a phone call."

"HTTP: you write a letter, wait for a reply, hang up.
WebSocket: you call someone. The line stays open. Either side can talk at any time. You hang up when you're done."

"Technically: a WebSocket starts as an HTTP request — a special one called an 'upgrade request.' The server agrees, the protocol switches, and now you have a persistent, bidirectional connection. The browser and the server can send data to each other at any time, without waiting to be asked."

Draw this out explicitly:

```
HTTP (what they know):
  Browser ──── request ────→ Server
  Browser ←─── response ──── Server
  [connection closes]

WebSocket:
  Browser ──── HTTP upgrade request ────→ Server
  Browser ←──── "101 Switching Protocols" Server
  [connection stays open — both sides can send anytime]
  Browser ←── message ──── Server   (server pushes to browser)
  Browser ──── message ──→ Server   (browser sends to server)
  Browser ←── message ──── Server
  Browser ──── close ─────→ Server
  [connection closes]
```

Ask them to draw this themselves on paper or describe it back to you before continuing.

---

## The key properties to burn into their memory

Go through these one by one. For each, ask them to explain it back before moving on.

**1. Persistent.** The connection stays open until one side closes it. There's no "request" and "response" — it's a stream.

**2. Bidirectional.** Either side can send a message at any time. The server doesn't have to wait for the browser to ask. This is what makes real-time possible.

**3. Low overhead.** After the initial handshake, WebSocket messages have very small headers (2-14 bytes vs. hundreds of bytes for HTTP headers). This is why it's efficient.

**4. Still runs on top of TCP.** WebSocket isn't magic — it's TCP with a protocol on top. TCP is the thing that makes sure packets arrive in order and get retransmitted if lost. WebSocket inherits all of that.

Ask: "If a user's internet cuts out while they're connected to our chat server, what happens to their WebSocket connection?"

Guide them to: the connection dies. The server eventually realizes it (via a timeout or error on the socket). We have to handle that gracefully.

---

## How it maps to our chat server

"Think about a chat room. What needs to happen?"

Walk through it with them:
1. Alice opens the chat page → browser establishes a WebSocket connection to our server
2. Bob opens the chat page → browser establishes a WebSocket connection to our server
3. Alice types a message and hits send → browser sends the message over the WebSocket
4. Our server receives it
5. Our server sends it to ALL other connected clients — including Bob
6. Bob's browser receives it over Bob's WebSocket → it appears on Bob's screen instantly

"No polling. No Alice's browser asking 'any new messages?' every second. The server just sends it the moment it arrives."

Ask: "In step 5, how does the server know which connections to send to?" — this question plants the seed for the Hub pattern in the next lesson.

---

## The library we'll use

"Go's standard library doesn't have a WebSocket implementation. We'll use a package called `gorilla/websocket` — one of the most widely used Go packages, tens of thousands of projects use it."

```bash
go get github.com/gorilla/websocket
```

"Don't worry about the API yet. We'll learn it as we use it."

---

## Before you write a single line of code — checkpoint

Do not proceed until they can answer all of these without looking at notes:

1. "What's the difference between HTTP and WebSocket?"
2. "Why is polling bad for real-time apps?"
3. "What does 'bidirectional' mean in the context of WebSocket?"
4. "What is the WebSocket handshake? What HTTP status code does the server send when it accepts?"
5. "In our chat app, when Alice sends a message, walk me through exactly what happens at the network level."

If they can't answer any of these, go back and re-explain that part. Do not rush this. The entire chat server project rests on understanding this lesson.

---

## No commit this lesson — it's all concepts

The next lesson starts writing code. Make sure the mental model is solid first.
