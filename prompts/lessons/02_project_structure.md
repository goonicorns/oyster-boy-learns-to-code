# Lesson 02: Project Structure — Organizing Go Code

**Paste into Claude Code after the system prompt**

---

## Context for Claude

The learners have a working HTTP server in a single `main.go` file. As we add features, that file will become impossible to manage. This lesson teaches them how real Go projects are organized.

**This lesson's goal:**
- Understand why code organization matters
- Split `main.go` into multiple packages
- Understand Go's package system
- Set up the folder structure they'll use for the whole project

---

## The project structure to build toward

By the end of this series, they'll have:

```
cryptowatch/
├── main.go              — starts the server, wires everything together
├── go.mod               — module definition
├── go.sum               — dependency checksums (auto-generated)
├── handler/
│   ├── price.go         — HTTP handlers for price endpoints
│   └── auth.go          — HTTP handlers for login/register
├── store/
│   ├── user.go          — database operations for users
│   └── price.go         — database operations for prices
├── model/
│   └── types.go         — data types shared across the project
└── middleware/
    └── auth.go          — JWT verification middleware
```

---

## What to teach

### Why structure matters

"Right now everything is in main.go. What happens when we have 500 lines? 2000 lines? You can't find anything. Every piece of code that does different things should live in a different file or folder."

"In Go, a folder is a package. Code inside a package can see each other freely. Code in different packages communicates through exported functions — functions with capital letters."

### The rule about exported vs unexported

This is critical. Make sure they really understand this:

"In Go, the case of the first letter determines visibility:
- `GetUser()` — capital G — other packages can see and call this
- `queryDB()` — lowercase q — only code in the SAME package can call this

This isn't just a convention — Go enforces it. If you try to call an unexported function from another package, it won't compile."

Ask: "Can you think of why you'd WANT to hide some functions?"
Guide them to: "It's about what you promise to other parts of your code. If a function is exported, other code depends on it. If it's unexported, you can change it without breaking anything outside the package."

### Create the structure

Guide them to create these directories first:
```bash
mkdir handler store model middleware
```

Then create `model/types.go` together. This is where shared data types live.

Guide them to think about: "What are the things in our app?" (Users, Prices, API responses)

Help them define (but don't write it for them — ask questions):

```go
// model/types.go
package model

type User struct {
    ID       int
    Username string
    Email    string
    Password string // hashed, never the real one
}

type Price struct {
    ID        int
    Symbol    string  // "BTC", "ETH"
    PriceUSD  float64
    FetchedAt string  // timestamp
}

type APIResponse struct {
    Success bool        `json:"success"`
    Data    interface{} `json:"data,omitempty"`
    Error   string      `json:"error,omitempty"`
}
```

Explain `interface{}` briefly: "This is a way to say 'this field can hold ANY type.' It's useful for an API response that sometimes returns a user, sometimes returns a price, sometimes returns a list. We'll use it sparingly — it disables Go's type checking."

Explain JSON tags: "The backtick annotations are metadata — they tell the JSON encoder what to call each field in the output. `json:"success"` means: in JSON, call this field 'success' (lowercase). Without this, Go would use the field name as-is."

### Move handler code into handler/

Ask them: "Where should the code that handles HTTP requests live?"

Guide them to create `handler/price.go`. Ask them to write a simple handler that returns JSON:

"What does the function signature for an HTTP handler look like? (from last lesson)"

Guide them toward:
```go
func GetPrices(w http.ResponseWriter, r *http.Request) {
    // set Content-Type header so the client knows this is JSON
    w.Header().Set("Content-Type", "application/json")
    // write a placeholder response
    fmt.Fprintln(w, `{"success": true, "data": []}`)
}
```

Then update `main.go` to import and use it. This is where the import path concept comes up:
"To import your own package: `import "cryptowatch/handler"` — the module name from go.mod, slash the folder name."

### Test it still works

```bash
go run main.go
curl http://localhost:8080/prices
```

### Commit

Guide them through committing this refactor.

---

## Common confusion points

- "Why can't I just have everything in main.go?" — Scale. And testability. Code in packages is easy to test in isolation.
- "What's the difference between a file and a package?" — A package can span multiple files. All files in the same folder share the same package name.
- "Why does main have to be in package main?" — Go requires it. The `main` package with a `main()` function is the entry point contract.
