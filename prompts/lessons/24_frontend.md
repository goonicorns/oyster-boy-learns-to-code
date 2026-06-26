# Lesson 24: The Frontend — Making It Real

**Paste into Claude Code after the system prompt**

---

## Context for Claude

This is the moment everything becomes tangible. They've built a working chat server that nobody can see. Now they build a minimal HTML/JS frontend — just enough to open two browser tabs and watch messages appear in real-time. This lesson teaches the browser's WebSocket API, a tiny bit of JavaScript, and the "two tabs" moment that makes the project feel alive. 

Do NOT let them build a polished UI. The goal is understanding, not aesthetics. One HTML file, no frameworks, no npm.

**This lesson's goal:**
- Learn the browser WebSocket API (it's much simpler than the server side)
- Build a minimal chat UI in a single HTML file
- Understand the event-driven model in the browser
- Have the "two tabs" moment — sending a message in one tab, seeing it in another
- Understand how the server and browser mirror each other

---

## Start with a question — what does the browser need to do?

"We've been thinking entirely from the server's perspective. Now think like a browser. A user opens the chat page. What needs to happen?"

Let them walk through it:
1. Load the HTML page
2. Establish a WebSocket connection to the server
3. Show a text input and a send button
4. When the user sends a message, send it over the WebSocket
5. When a message arrives from the server, display it on screen
6. When the connection drops, show an error or reconnect

"That's the whole frontend. Four events: connect, disconnect, receive message, send message. Let's build it."

---

## The browser WebSocket API — simpler than you think

"The server side had goroutines, channels, a hub, pumps. The browser side is much simpler. Here's the entire WebSocket API in the browser:"

```javascript
// Open a connection
const ws = new WebSocket('ws://localhost:8080/ws?token=ABC&room=general');

// Event: connection established
ws.onopen = function() {
    console.log('connected');
};

// Event: message received from server
ws.onmessage = function(event) {
    const data = event.data; // this is the raw string (JSON in our case)
    const message = JSON.parse(data);
    console.log(message);
};

// Event: connection closed
ws.onclose = function() {
    console.log('disconnected');
};

// Event: connection error
ws.onerror = function(error) {
    console.error('error', error);
};

// Sending a message
ws.send(JSON.stringify({ content: 'hello!' }));
```

Ask: "How many events does the browser WebSocket API have?" (4: onopen, onmessage, onclose, onerror)

Ask: "Compare this to the server side. The server has a read pump and a write pump. What is the browser equivalent?"
- `onmessage` is the read pump — it fires when the server sends something
- `ws.send()` is the write pump — it sends data to the server
- `onopen`/`onclose` are the register/unregister equivalents

Ask: "Why is the browser side so much simpler?" (the browser handles all the goroutine complexity internally — the JavaScript runtime is event-driven, not concurrent in the same way)

---

## Build the HTML file — guide, don't write it for them

Have them create `static/index.html`. Walk them through it section by section.

**Step 1: The HTML structure**

Ask: "What elements do we need on the page?"
- A place to show messages (a list or a div)
- A text input for typing
- A send button
- Maybe a field for the room name and token

They should arrive at something like:
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Chat</title>
    <style>
        body { font-family: monospace; max-width: 600px; margin: 40px auto; }
        #messages { border: 1px solid #ccc; height: 400px; overflow-y: scroll; padding: 10px; margin-bottom: 10px; }
        .message { margin: 4px 0; }
        .message .user { font-weight: bold; color: #336699; }
        .message .time { color: #999; font-size: 0.85em; }
        #controls { display: flex; gap: 8px; }
        #input { flex: 1; padding: 8px; }
        button { padding: 8px 16px; cursor: pointer; }
        #status { color: #999; font-size: 0.85em; margin-top: 4px; }
    </style>
</head>
<body>
    <h2>Chat</h2>
    <div id="status">disconnected</div>
    <div id="messages"></div>
    <div id="controls">
        <input id="input" type="text" placeholder="Type a message..." />
        <button onclick="sendMessage()">Send</button>
    </div>
</body>
</html>
```

Ask: "What does `overflow-y: scroll` do?" (when messages overflow the box, a scrollbar appears — otherwise they'd push off the page)

---

**Step 2: The JavaScript**

"Now let's wire it up. We need to:
1. Get a token from localStorage (or hardcode one for now)
2. Open the WebSocket connection
3. Update the `#status` div on connect/disconnect
4. When a message arrives, add it to `#messages`
5. When send is clicked, send the message"

Ask them to write it. Guide them toward:

```html
<script>
    // In a real app, this would come from a login flow
    // For now, paste a token from: curl -X POST /login ...
    const TOKEN = localStorage.getItem('token') || prompt('Paste your JWT token:');
    const ROOM = new URLSearchParams(window.location.search).get('room') || 'general';

    const ws = new WebSocket(`ws://localhost:8080/ws?token=${TOKEN}&room=${ROOM}`);
    const messagesDiv = document.getElementById('messages');
    const statusDiv = document.getElementById('status');
    const input = document.getElementById('input');

    ws.onopen = function() {
        statusDiv.textContent = `connected to #${ROOM}`;
        statusDiv.style.color = 'green';
    };

    ws.onclose = function() {
        statusDiv.textContent = 'disconnected';
        statusDiv.style.color = 'red';
    };

    ws.onmessage = function(event) {
        const msg = JSON.parse(event.data);
        
        const div = document.createElement('div');
        div.className = 'message';
        
        const time = new Date(msg.sent_at).toLocaleTimeString();
        div.innerHTML = `<span class="time">[${time}]</span> <span class="user">${msg.username || msg.user}:</span> ${escapeHtml(msg.content)}`;
        
        messagesDiv.appendChild(div);
        // Auto-scroll to bottom
        messagesDiv.scrollTop = messagesDiv.scrollHeight;
    };

    ws.onerror = function(error) {
        statusDiv.textContent = 'error — check console';
        statusDiv.style.color = 'red';
    };

    function sendMessage() {
        const content = input.value.trim();
        if (!content || ws.readyState !== WebSocket.OPEN) return;
        
        ws.send(JSON.stringify({ content: content }));
        input.value = '';
    }

    // Send on Enter key
    input.addEventListener('keypress', function(e) {
        if (e.key === 'Enter') sendMessage();
    });

    // IMPORTANT: escape HTML to prevent XSS attacks
    function escapeHtml(text) {
        const div = document.createElement('div');
        div.appendChild(document.createTextNode(text));
        return div.innerHTML;
    }
</script>
```

---

## Stop and explain escapeHtml — this is critical

"I need you to understand why `escapeHtml` exists. This is not optional. This is not cosmetic. This is a security function."

"Imagine someone sends the message: `<script>alert('hacked')</script>`"

"If we just did `div.innerHTML = msg.content`, that script tag would execute in EVERY connected user's browser. The attacker could steal their tokens, make requests on their behalf, redirect them to malicious sites."

"This attack is called Cross-Site Scripting (XSS). It's in the OWASP Top 10 most common web vulnerabilities. We prevent it by treating user content as TEXT, not as HTML."

"Our `escapeHtml` function does exactly that — it creates a text node (which is never interpreted as HTML) and then reads back the HTML-escaped version. `<` becomes `&lt;`, `>` becomes `&gt;`, and the script tag becomes inert."

Ask: "If we didn't have escapeHtml, and someone in the chat sent `<img src=x onerror='steal_token()'>`, what would happen?" (every client would load that image, fail, and run `steal_token()` — classic XSS attack)

Ask: "Why does using `textContent` instead of `innerHTML` also solve this?" (textContent never interprets HTML — it's always treated as plain text. Our escapeHtml function converts to HTML-safe text, then we use innerHTML safely.)

---

## Serve the static file from Go

"We need the server to serve this HTML file. Add this to main.go:"

```go
// Serve static files from the ./static directory
r.Handle("/", http.FileServer(http.Dir("./static")))
```

Ask: "What does `http.FileServer` do?" (serves files from a directory over HTTP — when someone requests `/`, it looks for `static/index.html` and serves it)

"Now navigate to `http://localhost:8080` in a browser. You should see the chat UI."

---

## The two-tabs moment

This is the payoff. Walk them through it slowly.

1. Open `http://localhost:8080` in a browser tab. Paste a valid JWT when prompted.
2. Open a second tab to the same URL. Paste a valid JWT for a different user.
3. Type a message in tab 1. Press send.
4. Watch it appear in tab 2.

"You just built real-time communication. That message traveled: your keyboard → JavaScript → WebSocket → Go server → Hub goroutine → channel → write pump goroutine → WebSocket → JavaScript → screen."

Let that sink in. Then ask:

"Now open a third tab. When you connect, do you see the previous messages?" (yes — from the history query)

"Now close a tab. Does anything crash?" (no — the read pump exits, sends unregister to the hub, hub removes the client)

"Now stop the server. What do the browser tabs show?" (disconnected — `onclose` fires)

"Now restart the server. What do the browser tabs show?" (still disconnected — the WebSocket connection is gone. In a production app, you'd add reconnection logic)

---

## What they've built — make it explicit

Make them say it out loud, in their own words, before they move on.

"Tell me what this entire system does. Start from a user opening their browser. Walk me through every piece."

They should be able to describe:
- The browser connects via WebSocket (after verifying the JWT)
- The server upgrades the HTTP connection, creates a Client struct, starts two goroutines
- The Hub registers the client, loads history, sends it via the client's send channel
- When the user types and sends, JavaScript sends JSON over the WebSocket
- The read pump receives it, decodes JSON, fills in room and username, sends to hub.broadcast
- The hub receives it, saves to Postgres in a background goroutine, encodes to JSON, sends to all clients in the room
- Each client's write pump goroutine receives from its send channel and writes to the WebSocket
- Every browser in the room receives the message and renders it

If they can say all of that, they understand the whole system.

---

## Login page — small but important

"Right now users paste a token manually. Let's add a simple login page so the flow makes sense."

Guide them to add to `static/index.html` (or a separate `static/login.html`):

```html
<!-- Login form shown when no token exists -->
<div id="login" style="display:none">
    <h3>Login</h3>
    <input id="username" type="text" placeholder="Username" />
    <input id="password" type="password" placeholder="Password" />
    <button onclick="login()">Login</button>
    <div id="login-error" style="color:red"></div>
</div>

<script>
async function login() {
    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;
    
    const res = await fetch('/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password })
    });
    
    if (!res.ok) {
        document.getElementById('login-error').textContent = 'Invalid credentials';
        return;
    }
    
    const data = await res.json();
    localStorage.setItem('token', data.token);
    window.location.reload(); // reload to connect with token
}

// Show login form if no token
if (!localStorage.getItem('token')) {
    document.getElementById('login').style.display = 'block';
    document.getElementById('chat').style.display = 'none';
}
</script>
```

Ask: "Why do we store the token in `localStorage`?" (it persists across page refreshes — the user doesn't have to log in every time)

Ask: "Is localStorage secure?" — good question. "It's accessible to any JavaScript on the page. That's why XSS prevention is critical — if an attacker can run JavaScript on your page, they can steal the token from localStorage."

---

## Commit

```bash
git add .
git commit -m "Add minimal chat frontend with WebSocket client"
```
