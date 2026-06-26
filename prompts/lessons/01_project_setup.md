# Lesson 01: Setting Up the Project

**Paste into Claude Code after the system prompt from CLAUDE_TUTOR.md**

---

## Context for Claude

The learners are starting their first real Go project. They've done the playground exercises and understand variables, functions, and basic types. Now they're building something real.

**This lesson's goal:** The learner should end up with:
- A git repository initialized
- A Go module set up (`go mod init`)
- A working `main.go` that starts an HTTP server and responds to a request
- An understanding of what each piece does and why

**Tools they'll use:** `git`, `go`, `curl`

---

## What to teach in this lesson

### Git first

Before any code, introduce git. Explain it as a time machine for code:
- Every time they make a change that works, they can save a "snapshot" (commit)
- If they break something, they can go back to the last snapshot
- It also lets multiple people work on the same code without overwriting each other

Guide them through:
```
git init
git status
```

Explain what `git status` shows. They'll use this constantly.

### Go modules

Explain: "A Go module is how Go organizes a project. The `go.mod` file is like an ID card for your project — it has the project name and records what external packages you use."

Guide them to run: `go mod init cryptowatch`

Ask: "What file did that create? Open it and read it. What do you see?"

### The HTTP server

This is the core concept of today. Before writing any code, explain:

**What an HTTP server is:**
"An HTTP server is a program that sits and waits. When another program (like a browser or curl) sends it a request, it reads that request and sends back a response. That's it. Every website, every API, is some variant of this."

**The three parts of a request:**
- Method: what do you want to do? (GET = read, POST = create, PUT = update, DELETE = remove)
- Path: what are you asking about? (/users, /prices/bitcoin)
- Body: what data are you sending? (for POST/PUT requests)

**The response:**
- Status code: 200 = OK, 404 = not found, 500 = server exploded
- Body: the data you're sending back (often JSON)

### Guide them to write this code step by step

Do NOT write this for them. Guide with questions and hints:

1. "Start with `package main` and the imports. What do you think you need to import for an HTTP server?" (they need `net/http` and `fmt`)

2. "What function does every Go program start in?" (main)

3. "Inside main, we need two things: a handler function and to start the server. A handler is a function that receives a request and writes a response. Can you try writing a function signature for that?"

4. If stuck on the handler signature: "In Go's `net/http` package, handler functions always look like: `func name(w http.ResponseWriter, r *http.Request)` — `w` is how you write the response, `r` is the incoming request."

5. "Inside the handler, how do we write something to the response?" (guide to `fmt.Fprintln(w, "Hello!")`)

6. "Now we need to tell Go: when someone requests the path `/`, use our handler. The function for this is `http.HandleFunc`. Try looking that up."

7. "Finally, how do we actually start listening for requests?" (guide to `http.ListenAndServe(":8080", nil)`)

8. After they write it: "Run it with `go run main.go`. Now open another terminal and type: `curl http://localhost:8080/`. What do you see?"

### Introduce curl

"curl is a command-line tool for making HTTP requests. We'll use it constantly to test our API. It's like a browser for the terminal."

Basic curl commands to teach:
```bash
curl http://localhost:8080/            # GET request
curl -v http://localhost:8080/         # verbose — shows headers and status code
curl -X POST http://localhost:8080/    # POST request
```

### Commit the work

"Let's save this progress to git."

Guide them through:
```bash
git status           # see what changed
git add main.go      # stage the file
git status           # see it's staged
git commit -m "Add basic HTTP server"  # save the snapshot
git log              # see the history
```

Explain each step. What does "staging" mean? Why does git have this intermediate step?

---

## Common mistakes to watch for

- Forgetting to call `http.HandleFunc` before `http.ListenAndServe`
- Using `:= ` inside the handler where it's not needed
- Not running `go run` after making changes
- Forgetting that `http.ListenAndServe` blocks — the program runs until you Ctrl+C it

## End of lesson checkpoint

Before moving on, they should be able to:
1. Explain what an HTTP server is in their own words
2. Use `curl` to make a GET request
3. Know what `git status`, `git add`, and `git commit` do
4. Run their server and see a response
