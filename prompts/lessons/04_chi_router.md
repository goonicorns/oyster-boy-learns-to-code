# Lesson 04: The Chi Router — Organizing Your Routes

**Paste into Claude Code after the system prompt**

---

## Context for Claude

The learners are using Go's basic `net/http` package for routing. It works, but it's limited: no URL parameters, no middleware, verbose grouping. We're switching to `chi`, a lightweight router that solves these problems without being a bloated framework.

**This lesson's goal:**
- Understand why we need a router
- Install and use chi
- Set up URL parameters (`/prices/{symbol}`)
- Understand middleware and add logging

---

## What to teach

### Why a router?

"The standard library's routing is basic. It can match `/prices` but it can't match `/prices/{symbol}` where `symbol` is a variable. It also doesn't handle method matching (GET vs POST on the same path) cleanly. Chi solves these things without adding heavy framework overhead."

"Chi is not a framework — it's a router. It doesn't tell you how to structure your code, it doesn't add magic, it just does one job well: route HTTP requests to the right handler."

Ask: "What does 'route' mean?" — make sure they can articulate it before moving on.

### Install chi

```bash
go get github.com/go-chi/chi/v5
go get github.com/go-chi/chi/v5/middleware
```

### Rewrite main.go routing

Guide them to replace `http.HandleFunc` calls with chi. The key concepts to teach:

**Router creation:** `r := chi.NewRouter()`

**Middleware:** "Middleware is code that runs on EVERY request before it reaches your handler. Useful for logging, authentication, compression, etc. With chi, you add middleware with `r.Use()`."

**Route definition:** 
```go
r.Get("/prices", handler.GetPrices)        // GET only
r.Post("/prices", handler.CreatePrice)     // POST only
r.Get("/prices/{symbol}", handler.GetPrice) // with URL parameter
```

**Route groups:** "Groups let you share a prefix and middleware between related routes."

Guide them toward something like:

```go
r := chi.NewRouter()

// Middleware that runs on all routes
r.Use(middleware.Logger)    // logs every request
r.Use(middleware.Recoverer) // if a handler panics, recover gracefully instead of crashing

// Public routes (no authentication needed)
r.Post("/register", handler.Register)
r.Post("/login", handler.Login)

// Protected routes (authentication required — we'll add the middleware later)
r.Group(func(r chi.Router) {
    r.Get("/prices", handler.GetPrices)
    r.Get("/prices/{symbol}", handler.GetPrice)
})
```

### Reading URL parameters

"A URL parameter is a variable part of the path. `/prices/{symbol}` matches `/prices/BTC` and `/prices/ETH`. Chi extracts the value for you."

Show them how to read it in a handler:
```go
func GetPrice(w http.ResponseWriter, r *http.Request) {
    symbol := chi.URLParam(r, "symbol")
    // now symbol = "BTC" or "ETH" or whatever was in the URL
}
```

Guide them to write a handler that reads the symbol and returns a placeholder response for now.

### Test with curl

This is important — they need to develop the habit of testing every new route immediately.

```bash
# Start the server
go run main.go

# Test the routes
curl -v http://localhost:8080/prices
curl -v http://localhost:8080/prices/BTC
curl -X POST -v http://localhost:8080/login

# Look at the server terminal — you should see chi logging each request
```

Walk through the verbose (-v) output:
- "What's the first line? That's the request line: method, path, HTTP version"
- "What are all those < lines? Those are response headers"
- "What does the status code 200 mean? What about 404? 405?"

### JSON responses

"Our API should always return JSON. Let's write a helper function for this so we don't repeat ourselves."

Guide them toward a helper that:
1. Sets `Content-Type: application/json` header
2. Sets the status code
3. Encodes the data as JSON and writes it

Ask: "What package in Go handles JSON?" (encoding/json)
Ask: "What function encodes a Go value to JSON?" (guide them to json.NewEncoder or json.Marshal)

```go
// handler/respond.go
func JSON(w http.ResponseWriter, status int, data interface{}) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(data)
}
```

Ask them to update their handlers to use this.

---

## Commit

```bash
git add .
git commit -m "Switch to chi router, add JSON response helper"
```

---

## Key things to reinforce

- chi is minimal — it doesn't do ORM, it doesn't do validation, it doesn't do authentication. Those are separate concerns.
- Middleware runs in order — the first `r.Use()` call wraps the outermost layer.
- Always test with curl after writing a new route. Don't assume it works.
