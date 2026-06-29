# Lesson 12: Final Project — Putting It All Together

**Paste into Claude Code after the system prompt**

---

## Context for Claude

This is the final lesson. The learners should have a mostly-working API. This session is for finishing touches, reviewing what they built, and giving them the vocabulary to keep learning on their own.

**This lesson's goal:**
- Finish any incomplete features
- Review the full project architecture
- Understand what's missing for "production"
- Know what to learn next

---

## First: Inventory what they have

Guide them through a code review of their own project. Ask them to explain each piece:

"Walk me through the project. If someone new joined your team tomorrow, how would you explain the structure?"

They should be able to describe:
- What `main.go` does
- What each folder is for
- How a request flows from curl to the database and back
- How authentication works

If they can't explain something, that's the thing to revisit.

---

## Fill in any missing endpoints

By now they should have:
- `POST /register` — create an account
- `POST /login` — get a JWT
- `GET /prices` — get latest prices (authenticated)
- `GET /prices/{symbol}` — get latest price for one symbol (authenticated)
- `GET /me` — get current user's info (authenticated)

If any are missing, guide them to complete the missing ones.

---

## Add input validation

"Right now, what happens if someone sends a registration request with an empty username? Or a 2-character password? Let's add validation."

"Validation rules:
- username: required, 3-20 characters, only letters/numbers/underscore
- email: required, valid email format
- password: required, at least 8 characters"

Guide them to write a validation function. Ask:
- "What package in Go handles regular expressions?" (regexp)
- "What would a regex for 'only letters and numbers' look like?"

Don't implement it for them — guide with questions. Let them look things up.

---

## Environment variable configuration

"Right now some things are hardcoded. Let's make the configuration come from environment variables."

Create a `config` package or just use a config struct in main:

```go
type Config struct {
    Port      string
    DBUrl     string
    JWTSecret string
}

func configFromEnv() Config {
    c := Config{
        Port:      os.Getenv("PORT"),
        DBUrl:     os.Getenv("DB_URL"),
        JWTSecret: os.Getenv("JWT_SECRET"),
    }
    if c.Port == "" { c.Port = "8080" }
    if c.DBUrl == "" { c.DBUrl = "postgres://dev:devpass@localhost:5432/cryptowatch" }
    if c.JWTSecret == "" { c.JWTSecret = "development-secret-change-me" }
    return c
}
```

"Create a `.env` file for local development (add it to .gitignore!):

```
PORT=8080
DB_URL=postgres://dev:devpass@localhost:5432/cryptowatch
JWT_SECRET=my-long-random-secret-key-here
```

---

## The "what you didn't build" conversation

Be honest about what's missing for a real production system:

**Rate limiting:** "Right now anyone can hammer your API with 10,000 requests per second. chi has a rate limiter middleware."

**HTTPS:** "All our traffic is unencrypted. In production you'd put a reverse proxy (like nginx or Caddy) in front that handles TLS certificates."

**Database migrations:** "We created tables manually in psql. In a real project you use a migration tool (like `golang-migrate`) that tracks which SQL changes have been applied."

**Logging:** "We used `log.Printf` which is fine. For production, you'd want structured logging (`zerolog` or `slog`) that outputs JSON you can search in a log aggregator."

**Observability:** "How do you know if your server is slow? How do you know if errors are happening? You'd add metrics (Prometheus), tracing (OpenTelemetry), and alerting."

**Password reset:** "Users will forget their passwords. You'd need email sending."

**Token refresh:** "JWTs expire. Users don't want to log in every 24 hours. You'd add a refresh token mechanism."

"You built the core of a real API. Everything above is real engineering, but it builds on exactly what you understand now."

---

## What to learn next

Give them a clear path forward:

**Immediate next steps:**
- Read "The Go Programming Language" book by Donovan & Kernighan (the definitive reference)
- Do more exercises at exercism.io/tracks/go
- Build another project from scratch without a tutor

**Go-specific deepening:**
- `context` package — cancellation and deadlines
- Generics (Go 1.18+)
- `io` and `bufio` for file and stream processing
- `sync` and `atomic` for concurrent data structures

**Web API skills:**
- OpenAPI / Swagger for API documentation
- Database migrations with golang-migrate
- Caching with Redis
- Message queues for background jobs

**General software engineering:**
- Clean Architecture / Hexagonal Architecture (structuring large Go apps)
- Domain-Driven Design concepts
- How to do proper code review

---

## Docker — containerize the API itself

"You've been running Postgres in Docker. The API is still running with `go run`. Let's fix that — the whole thing should run with one command."

"Write a Dockerfile for the API. What do you need?"

Let them attempt it. Guide toward:

```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o cryptowatch .

FROM alpine:latest
RUN apk add --no-cache ca-certificates
COPY --from=builder /app/cryptowatch /cryptowatch
EXPOSE 8080
CMD ["/cryptowatch"]
```

Ask every line they don't know — by now they've seen `docker run postgres` many times, but this is their first time writing a Dockerfile.

Then update `docker-compose.yml` to include the app alongside Postgres:

```yaml
version: '3.9'
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: cryptowatch
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: cryptowatch
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      DATABASE_URL: postgres://cryptowatch:secret@postgres:5432/cryptowatch?sslmode=disable
      JWT_SECRET: change-me
    depends_on:
      - postgres

volumes:
  pgdata:
```

Run it:
```bash
docker-compose up --build
curl http://localhost:8080/health
```

Ask: "Before Docker Compose, what two commands did you need to run to start the project?" (`docker run postgres...` then `go run main.go`. Now it's just `docker-compose up`. One command for the whole stack.)

Ask: "Why `DATABASE_URL: postgres://...@postgres:...` and not `@localhost:`?" (containers are on the same Docker Compose network — `postgres` is the service name, which resolves to the Postgres container's IP. `localhost` would refer to the app container itself.)

Ask: "What does `depends_on: postgres` guarantee?" (the app container won't start until Postgres container is running — not until Postgres is *ready* to accept connections, just that it's started. For true readiness, you'd add a healthcheck.)

---

## Final git state

```bash
# Make sure everything is committed
git status
git add .
git commit -m "Final cleanup and validation"
git log --oneline  # look at your whole history
```

"Look at that git log. Every commit is a thing you built. A month ago you didn't know what a variable was."

---

## Celebrate

They built:
- A Go HTTP server from scratch
- PostgreSQL running in Docker
- User authentication with bcrypt + JWT
- Protected API routes with middleware
- Real-time crypto price fetching from an external API
- Unit tests
- A working git workflow
- curl-based API testing

That's real software engineering. It's not a toy.
