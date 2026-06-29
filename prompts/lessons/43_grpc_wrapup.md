# Lesson 43: gRPC Wrap-Up — Errors, Interceptors, Final Quiz

**For Claude — do not show this file to the learner**

---

## Context for Claude

Polish the gRPC service: proper error codes (not plain Go errors), a logging interceptor (gRPC's version of middleware), and the final quiz. The interceptor lesson is important — it shows that gRPC has the same middleware pattern as HTTP, just named differently.

**This lesson's goal:**
- Return proper gRPC status codes (not just fmt.Errorf)
- Write a server interceptor for logging (same idea as HTTP middleware)
- Final milestone quiz: all of Project 6

---

## gRPC error codes

"When you return `fmt.Errorf("symbol is required")` from a gRPC handler, what does the client see?"

Have them check — they'll see `rpc error: code = Unknown desc = symbol is required`. The `Unknown` code is unhelpful.

"gRPC has standard status codes. Same idea as HTTP status codes."

```go
import "google.golang.org/grpc/codes"
import "google.golang.org/grpc/status"

// Instead of:
return nil, fmt.Errorf("symbol is required")

// Use:
return nil, status.Errorf(codes.InvalidArgument, "symbol is required")
```

Key codes to know:
| Code | HTTP equivalent | When to use |
|---|---|---|
| `codes.InvalidArgument` | 400 | Bad input from client |
| `codes.NotFound` | 404 | Resource doesn't exist |
| `codes.Internal` | 500 | Server bug or unexpected error |
| `codes.Unauthenticated` | 401 | Missing or invalid auth |
| `codes.PermissionDenied` | 403 | Authenticated but not allowed |
| `codes.ResourceExhausted` | 429 | Rate limited |
| `codes.Unavailable` | 503 | Server is down or can't handle it |

"Update `GetPrice` to return `codes.InvalidArgument` for missing symbol and `codes.NotFound` for unknown symbols."

Ask: "On the client side, how do you check which code you got?"
```go
st, ok := status.FromError(err)
if ok && st.Code() == codes.NotFound {
    fmt.Println("That token doesn't exist")
}
```

---

## Server interceptors — gRPC middleware

"HTTP middleware wraps handlers. gRPC has the same pattern — interceptors."

"A unary interceptor wraps every unary RPC call:"

```go
func loggingInterceptor(
    ctx context.Context,
    req interface{},
    info *grpc.UnaryServerInfo,
    handler grpc.UnaryHandler,
) (interface{}, error) {
    start := time.Now()

    // Call the actual handler
    resp, err := handler(ctx, req)

    duration := time.Since(start)
    if err != nil {
        log.Printf("ERROR %s (%v): %v", info.FullMethod, duration, err)
    } else {
        log.Printf("OK    %s (%v)", info.FullMethod, duration)
    }

    return resp, err
}
```

Wire it in:
```go
grpcServer := grpc.NewServer(
    grpc.UnaryInterceptor(loggingInterceptor),
)
```

Ask: "What is `info.FullMethod`?" (e.g. `/prices.PriceFeed/GetPrice` — the full method name including service and package)
Ask: "How is this the same as HTTP middleware?" (wraps the handler, can inspect request/response, can short-circuit, runs for every call)
Ask: "What would an authentication interceptor do?" (check a token in the metadata, return `codes.Unauthenticated` if missing/invalid, call `handler` only if valid)

---

## gRPC metadata (headers equivalent)

"HTTP has headers. gRPC has metadata — key-value pairs attached to a call."

```go
// Client: attach metadata
md := metadata.Pairs("authorization", "Bearer "+token)
ctx := metadata.NewOutgoingContext(context.Background(), md)
resp, err := client.GetPrice(ctx, req)

// Server: read metadata
md, ok := metadata.FromIncomingContext(ctx)
if ok {
    auth := md.Get("authorization")
    // auth[0] = "Bearer <token>"
}
```

Ask: "Why not just put the token in the request message?" (separation of concerns — auth tokens are infrastructure, not application data. Interceptors can handle auth without touching business logic.)

---

## Docker Compose — server + client in separate containers

"A gRPC server running locally is fine for development. But how would you deploy it? Two services — server and client — each in their own container, talking over a network."

"Write a Docker Compose for this. What services do we need?"

Let them think it through. Then:

```yaml
version: '3.9'

services:
  server:
    build:
      context: .
      dockerfile: Dockerfile.server
    ports:
      - "50051:50051"

  client:
    build:
      context: .
      dockerfile: Dockerfile.client
    depends_on:
      - server
    environment:
      SERVER_ADDR: server:50051
```

Two Dockerfiles — one per binary:

`Dockerfile.server`:
```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o server ./server
FROM alpine:latest
COPY --from=builder /app/server /server
EXPOSE 50051
CMD ["/server"]
```

`Dockerfile.client`:
```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o client ./client
FROM alpine:latest
COPY --from=builder /app/client /client
CMD ["/client"]
```

Ask them to write these with minimal hints — they've seen this pattern in Project 5.

Ask:
- "The client connects to `server:50051`. Why `server` and not `localhost`?" (Docker Compose service name is the hostname — same as lesson 54's Postgres example)
- "Why `depends_on: server`?" (client can't connect before server is up — without this the client starts instantly and immediately fails with "connection refused")
- "We have two Dockerfiles. What's the alternative to having two separate files?" (`--target` in a multi-stage build — each stage is a different service. One file, `docker build --target server` or `--target client`.)

Have them implement the multi-stage alternative as a bonus.

---

## Final milestone quiz — no notes, no looking

1. "What gRPC status code would you return if someone requests a symbol that doesn't exist in your database?"
   (`codes.NotFound`)

2. "What is a gRPC interceptor? Give me an example of two things you'd do in one."
   (middleware for RPC calls — logging timing, checking auth tokens, rate limiting, panic recovery)

3. "The streaming client gets an error from `stream.Recv()`. How do you tell if the stream ended normally vs something went wrong?"
   (`io.EOF` = normal end; any other error = problem)

4. "In your proto file, what does `repeated` do? What Go type does it generate?"
   (declares a list field; generates a Go slice e.g. `[]string`)

5. "Why would you choose gRPC over REST for a service that two Go backends use to talk to each other?"
   (typed contract enforced at compile time, smaller binary payload, streaming support, generated client removes hand-writing HTTP calls)

6. "Explain what `context.WithTimeout(ctx, 5*time.Second)` does and why you'd use it on a gRPC unary call."
   (creates a derived context that cancels after 5 seconds — prevents hanging if the server is slow. The gRPC framework uses this to abort the call and return an error to the caller.)

---

## What they've learned in Project 6

- Protocol Buffers: message types, field numbers, `repeated`, `stream`
- `protoc` and `protoc-gen-go` / `protoc-gen-go-grpc`
- Implementing the generated server interface
- `grpc.NewServer`, `Serve`, `net.Listen`
- Unary vs server streaming
- `stream.Send()` and `stream.Recv()`
- `stream.Context().Done()` for client disconnect detection
- `context.WithTimeout` on clients
- gRPC status codes vs plain errors
- Server interceptors (middleware pattern)
- gRPC metadata (headers equivalent)
- `grpcurl` for manual testing

---

## Progress commands

```bash
go run tools/progress/main.go complete lesson_43_grpc_wrapup
go run tools/progress/main.go set project7 lesson_44_baby_blockchain_model
go run tools/progress/main.go note "Project 6 done — gRPC solid, streaming clicked"
```

## Commit

```bash
git add .
git commit -m "Project 6 complete: gRPC errors, interceptor, final quiz"
```
