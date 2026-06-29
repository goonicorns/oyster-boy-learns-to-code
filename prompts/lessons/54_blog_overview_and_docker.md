# Lesson 54: Blog Platform — Overview and Docker Compose

**For Claude — do not show this file to the learner**

---

## Context for Claude

Project 10 is the most real thing they've built — a full blog platform: auth, posts, comments, tags, image uploads, background jobs, Redis caching, full-text search, Docker Compose. Everything from the previous 9 projects comes together here. It's deliberately large and complex. Be militant. Quiz constantly. This is where they prove it all landed.

Especially hard on Irsyad and Sim — they're most likely to think they understand when they're actually copying patterns without knowing why.

**This lesson's goal:**
- Understand what we're building end to end
- Write a Docker Compose file that runs Postgres and Redis
- Understand what Docker Compose is and why it exists
- Connect the Go app to both services from a single config

---

## What we're building

"A real blog platform. Not a toy. Things that will work:

- User registration + login (JWT, you've done this)
- Create, edit, delete blog posts (with drafts and published state)
- Comments on posts
- Tags on posts
- Image uploads (cover images)
- Background jobs via Postgres (welcome emails, image processing)
- Redis caching for popular posts
- Full-text search via Postgres
- Everything runs in Docker Compose with one command"

Draw the architecture:
```
┌─────────────────────────────────────────────────┐
│                Docker Compose                   │
│                                                 │
│  ┌──────────────┐   ┌───────────┐  ┌─────────┐ │
│  │  Go Blog App │   │ Postgres  │  │  Redis  │ │
│  │  :8080       │──▶│  :5432    │  │  :6379  │ │
│  │              │──▶│           │  │         │ │
│  │              │──▶└───────────┘  └─────────┘ │
│  └──────────────┘                              │
└─────────────────────────────────────────────────┘
```

Ask: "Name three things we're using from previous projects in this one."
(JWT from Project 1, Redis from Project 8 concepts, Postgres from Project 1, Docker from Project 1 setup, chi router from Project 1)

---

## Docker Compose

"In Project 1 they used `docker run` to start Postgres manually. Docker Compose lets you define ALL your services in one file and start them together."

`docker-compose.yml`:
```yaml
version: '3.9'

services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: blog
      POSTGRES_PASSWORD: blog
      POSTGRES_DB: blog
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U blog"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redisdata:/data
    command: redis-server --appendonly yes

  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      DATABASE_URL: postgres://blog:blog@postgres:5432/blog?sslmode=disable
      REDIS_URL: redis:6379
      JWT_SECRET: change-me-in-production
      UPLOAD_DIR: /uploads
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
    volumes:
      - uploads:/uploads

volumes:
  pgdata:
  redisdata:
  uploads:
```

Walk through with questions:

- "What is a `volume` in Docker?" (persistent storage that survives container restarts — without it, all your database data is deleted when the container stops)
- "What does `depends_on` with `condition: service_healthy` do?" (the app won't start until Postgres passes its healthcheck — prevents "connection refused" errors on startup)
- "What is `postgres:5432` in the app's DATABASE_URL? Why not `localhost`?" (in Docker Compose, containers communicate by service name, not localhost — the Postgres container's hostname IS `postgres`)
- "What does `redis-server --appendonly yes` do?" (enables AOF persistence in Redis — same thing they built in Project 8)
- "What is `alpine` in `redis:7-alpine`?" (a minimal Linux image — much smaller than the default. Production containers should be small.)

Ask: "If you run `docker-compose down`, what happens to your database data?" (it persists because of the volume. `docker-compose down -v` would delete it — `-v` removes volumes too.)

---

## The Dockerfile

`Dockerfile`:
```dockerfile
FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o blog .

FROM alpine:latest
RUN apk add --no-cache ca-certificates

WORKDIR /app
COPY --from=builder /app/blog .

EXPOSE 8080
CMD ["./blog"]
```

Ask:
- "What is a multi-stage build?" (two FROM statements — first stage compiles the Go binary, second stage only copies the binary. The final image has no Go compiler, no source code — much smaller.)
- "What is `CGO_ENABLED=0`?" (disables C code in the Go binary — makes it statically linked, so it works in the minimal alpine image with no C libraries)
- "Why `ca-certificates` in the final image?" (needed to make HTTPS requests — the Go standard library uses them to verify TLS certificates. Without it, all outbound HTTPS calls fail.)

---

## Project structure

```
blog/
  main.go
  cmd/
    server.go        — HTTP server startup
    migrate.go       — run database migrations
  internal/
    auth/            — JWT and password hashing
    posts/           — post CRUD, search
    users/           — user management
    comments/        — comments
    jobs/            — Postgres-based job queue
    cache/           — Redis caching layer
    storage/         — file upload handling
    db/
      migrations/    — SQL migration files
      db.go          — connection pool setup
  api/
    middleware/      — auth middleware
    handlers/        — HTTP handlers
  uploads/           — uploaded files (in Docker: mounted volume)
```

Ask: "Why is business logic in `internal/` and HTTP handlers in `api/`?" (separation of concerns — the business logic doesn't know or care how it's called. You could add a CLI or gRPC interface later without touching `internal/`.)

---

## Start it up

```bash
docker-compose up --build
```

"The first run builds the Go binary, pulls images, starts Postgres and Redis, then starts the app. Subsequent runs are fast — only rebuilds if code changed."

Test the connection:
```bash
# Check Postgres is reachable
docker-compose exec postgres psql -U blog -c '\l'

# Check Redis
docker-compose exec redis redis-cli ping
```

---

## Checkpoint

1. "What is Docker Compose and why is it better than `docker run` for development?"
2. "Why does the app container connect to `postgres:5432` instead of `localhost:5432`?"
3. "What is a Docker volume? What happens to database data if you don't use one?"
4. "What is a multi-stage Dockerfile? Why does it result in a smaller image?"
5. "What does `CGO_ENABLED=0` do and why do we need it?"
6. "What does `depends_on: condition: service_healthy` prevent?"

---

## Commit

```bash
git add .
git commit -m "Project 10: Blog — Docker Compose with Postgres and Redis"
```
