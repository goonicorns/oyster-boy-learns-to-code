# Lesson 03: Docker and PostgreSQL

**Paste into Claude Code after the system prompt**

---

## Context for Claude

The learners now have a structured Go project. It's time to add a real database. We'll use Docker to run PostgreSQL without installing it directly on the system.

**This lesson's goal:**
- Understand what Docker is and why we use it
- Run a PostgreSQL container
- Connect to the database from Go using the `pgx` driver
- Write their first database query

---

## What to teach

### What Docker is — explain carefully

This concept trips people up. Use an analogy:

"Think of Docker like a lunchbox. You pack everything your app needs into the box — the software, the settings, the files — and it runs the same way on any computer. We're using it to run PostgreSQL in a box, so it doesn't conflict with anything else on your machine and you can throw the whole thing away and start over with one command."

"A 'container' is one of these running boxes. An 'image' is the recipe for making a container."

Commands to walk them through:

```bash
# Check Docker is installed
docker --version

# Download the PostgreSQL image (this takes a minute first time)
docker pull postgres:16

# Run a PostgreSQL container
docker run --name cryptowatch-db \
  -e POSTGRES_USER=dev \
  -e POSTGRES_PASSWORD=devpass \
  -e POSTGRES_DB=cryptowatch \
  -p 5432:5432 \
  -d \
  postgres:16
```

Explain each flag:
- `--name cryptowatch-db` — give the container a name so we can find it
- `-e` — set an environment variable inside the container (the database username/password)
- `-p 5432:5432` — map port 5432 on your computer to port 5432 in the container (this is how Go will connect)
- `-d` — detached mode: run in the background (don't take over the terminal)
- `postgres:16` — which image to use (PostgreSQL version 16)

```bash
# Check that it's running
docker ps

# Stop it (data is preserved)
docker stop cryptowatch-db

# Start it again
docker start cryptowatch-db

# Connect to it with psql (the PostgreSQL command-line client, running inside the container)
docker exec -it cryptowatch-db psql -U dev -d cryptowatch
```

### Introduce SQL basics

"PostgreSQL speaks SQL — Structured Query Language. It's a language for talking to databases."

Don't go deep here. Just enough to create tables and understand what they're doing:

```sql
-- Create a table (like a spreadsheet with defined columns)
CREATE TABLE users (
    id       SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email    VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create the prices table
CREATE TABLE prices (
    id         SERIAL PRIMARY KEY,
    symbol     VARCHAR(10) NOT NULL,
    price_usd  DECIMAL(20, 8) NOT NULL,
    fetched_at TIMESTAMP DEFAULT NOW()
);
```

Guide them to run these in `psql`, not just show them. Ask:
"What do you think SERIAL means? What about PRIMARY KEY? What about NOT NULL?"

Let them guess, then confirm/correct.

### Connecting Go to PostgreSQL

Introduce the concept of a database driver: "Go doesn't know how to talk to PostgreSQL by default. We need a package that knows the Postgres protocol. We'll use `pgx`."

```bash
go get github.com/jackc/pgx/v5
```

Explain `go get`: "This downloads the package from the internet and adds it to go.mod. Like npm install or pip install."

Now guide them to create `store/db.go`:

"We need a function that creates a connection to the database. What information would we need to connect?" (host, port, username, password, database name)

Guide them toward using a connection string and environment variables:

"The database credentials shouldn't be hardcoded in your code — if you commit them to git, they become public. Use environment variables instead. `os.Getenv('DB_URL')` reads an environment variable."

Help them write (guide with questions, don't write it):

```go
package store

import (
    "context"
    "fmt"
    "os"
    "github.com/jackc/pgx/v5/pgxpool"
)

// DB is our connection pool. A pool manages multiple connections so we don't
// create a new one for every request (that would be very slow).
var DB *pgxpool.Pool

// Connect initializes the database connection pool.
// Call this once at startup in main().
func Connect() error {
    url := os.Getenv("DB_URL")
    if url == "" {
        // Default for local development
        url = "postgres://dev:devpass@localhost:5432/cryptowatch"
    }

    var err error
    DB, err = pgxpool.New(context.Background(), url)
    if err != nil {
        return fmt.Errorf("connecting to database: %w", err)
    }

    // Ping to verify the connection actually works
    if err = DB.Ping(context.Background()); err != nil {
        return fmt.Errorf("pinging database: %w", err)
    }

    return nil
}
```

Then update main.go to call `store.Connect()` at startup.

### Test it

```bash
go run main.go
```

If the connection fails, guide them to read the error message. Common issues:
- Docker container isn't running → `docker start cryptowatch-db`
- Wrong credentials → check the -e flags used when creating the container

---

## Commit checkpoint

After everything works, commit:
```bash
git add .
git commit -m "Add Docker PostgreSQL setup and database connection"
```

---

## Key explanations to give

**Connection pool:** "Creating a database connection takes time (network handshake, authentication). A pool keeps several connections open and reuses them. Our Go server handles many requests per second — it needs connections ready immediately."

**context.Background():** "Context is Go's way of handling cancellation and timeouts. `context.Background()` is the simplest one — it never times out or cancels. We'll use proper contexts when we build handlers."

**Why not hardcode credentials:** "If you put passwords in your code and commit to git, they're now part of the git history forever. Even if you delete them later, they're still in the history. Use environment variables."
