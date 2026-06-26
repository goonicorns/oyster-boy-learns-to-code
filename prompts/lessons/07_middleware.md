# Lesson 07: JWT Middleware — Protecting Routes

**Paste into Claude Code after the system prompt**

---

## Context for Claude

The learners have registration and login working. Now they need to protect routes so only authenticated users can access them.

**This lesson's goal:**
- Understand what middleware is in the context of HTTP
- Write JWT verification middleware
- Attach user info to the request context
- Protect specific routes

---

## What to teach

### What middleware does

"Right now, anyone can call `/prices`. We want to require a valid JWT. We could add JWT checking code at the start of every handler — but that's repetitive and we'd probably forget one."

"Middleware is a function that wraps a handler. It runs BEFORE the handler. If the request passes the check, it calls the next handler. If not, it returns an error and the handler never runs."

"Think of it like a bouncer at a club. Every person goes through the bouncer before entering. The bouncer doesn't care what the person does inside — that's the club's business. The bouncer just checks the ID."

Draw the request flow:
```
Request → Logger middleware → Auth middleware → Handler → Response
```

### How chi middleware works

"In chi, a middleware is a function that takes an `http.Handler` and returns an `http.Handler`. It wraps the next handler."

```go
func MyMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Code here runs BEFORE the handler
        
        next.ServeHTTP(w, r)  // call the actual handler
        
        // Code here runs AFTER the handler
    })
}
```

"You add it to a route group with `r.Use(MyMiddleware)`. It then runs for every route in that group."

### Write the JWT middleware

Guide them to create `middleware/auth.go`.

Step by step questions:
1. "Where will the client send the JWT?" (Authorization header: `Bearer <token>`)
2. "How do we read a header in Go?" (`r.Header.Get("Authorization")`)
3. "How do we extract the token from `Bearer <token>`?" (split on space, take [1])
4. "How do we verify a JWT?" (guide to `jwt.Parse`)
5. "If verification fails, what should we return?" (401 Unauthorized — and stop — don't call `next`)
6. "If verification succeeds, how does the handler know who the user is?"

That last question introduces **request context**:

"The `r.Context()` value travels with the request through all middleware and handlers. We can store values in it. It's like attaching a sticky note to the request: 'this user is alice (ID: 1)'."

```go
// Store a value in context
type contextKey string
const UserIDKey contextKey = "userID"

ctx := context.WithValue(r.Context(), UserIDKey, userID)
r = r.WithContext(ctx)
next.ServeHTTP(w, r)
```

```go
// Read it back in a handler
userID := r.Context().Value(middleware.UserIDKey).(int)
```

Explain type assertion: "`.(int)` says 'I know this value is an int, give it to me as one.' Context values are `interface{}` (any type), so we have to tell Go what type we expect."

### Update the router

Guide them to add the auth middleware to the protected route group:

```go
r.Group(func(r chi.Router) {
    r.Use(middleware.Authenticate) // now this runs before every route in this group
    r.Get("/prices", handler.GetPrices)
    r.Get("/prices/{symbol}", handler.GetPrice)
})
```

### Test it

```bash
# This should now return 401 Unauthorized
curl http://localhost:8080/prices

# Login first to get a token
TOKEN=$(curl -s -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"securepass123"}' | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

echo "Got token: $TOKEN"

# Use the token
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/prices
```

Walk through the curl command that saves the token. Ask: "What does `$()` do in bash?" (runs the command inside and uses its output as a value)

### Have them modify a handler to use the authenticated user

Guide them to update one handler to show who's calling it:

```go
func GetPrices(w http.ResponseWriter, r *http.Request) {
    userID := r.Context().Value(middleware.UserIDKey).(int)
    log.Printf("GetPrices called by user %d", userID)
    // ... rest of handler
}
```

---

## Commit

```bash
git add .
git commit -m "Add JWT authentication middleware"
```
