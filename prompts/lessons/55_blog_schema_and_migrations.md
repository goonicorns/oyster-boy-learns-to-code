# Lesson 55: Database Schema and Migrations

**For Claude — do not show this file to the learner**

---

## Context for Claude

They design the full database schema before writing any Go code. Make them think through every table, every relationship, every index. Then implement migrations as numbered SQL files run by Go code — no ORM, no migration library, just `database/sql` and numbered files.

**This lesson's goal:**
- Design the schema: users, posts, comments, tags, job queue
- Understand foreign keys and what they enforce
- Understand indexes: when to add one and why
- Implement a simple migration runner in Go
- Know what `RETURNING` does in Postgres

---

## Design the schema — make them draw it first

"Before any SQL — draw the tables on paper. What data does a blog need? What relationships exist?"

Let them draft it. Guide toward:

```sql
-- Users
CREATE TABLE users (
    id         BIGSERIAL PRIMARY KEY,
    email      TEXT NOT NULL UNIQUE,
    username   TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    bio        TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Posts
CREATE TABLE posts (
    id          BIGSERIAL PRIMARY KEY,
    author_id   BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    slug        TEXT NOT NULL UNIQUE,
    title       TEXT NOT NULL,
    body        TEXT NOT NULL,
    cover_url   TEXT,
    published   BOOLEAN NOT NULL DEFAULT FALSE,
    published_at TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    search_vector TSVECTOR  -- for full-text search (lesson 62)
);

-- Tags
CREATE TABLE tags (
    id   BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

-- Post ↔ Tag many-to-many
CREATE TABLE post_tags (
    post_id BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    tag_id  BIGINT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, tag_id)
);

-- Comments
CREATE TABLE comments (
    id         BIGSERIAL PRIMARY KEY,
    post_id    BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    author_id  BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    body       TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Background job queue (replaces RabbitMQ)
CREATE TABLE jobs (
    id          BIGSERIAL PRIMARY KEY,
    type        TEXT NOT NULL,        -- e.g. "send_welcome_email", "resize_image"
    payload     JSONB NOT NULL,       -- job-specific data
    status      TEXT NOT NULL DEFAULT 'pending',  -- pending | running | done | failed
    attempts    INT NOT NULL DEFAULT 0,
    max_attempts INT NOT NULL DEFAULT 3,
    error       TEXT,
    scheduled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_posts_author    ON posts(author_id);
CREATE INDEX idx_posts_published ON posts(published, published_at DESC);
CREATE INDEX idx_comments_post   ON comments(post_id);
CREATE INDEX idx_jobs_pending    ON jobs(status, scheduled_at) WHERE status = 'pending';
CREATE INDEX idx_posts_search    ON posts USING GIN(search_vector);
```

Ask every design decision:

- "What does `REFERENCES users(id) ON DELETE CASCADE` do?" (if a user is deleted, all their posts are automatically deleted too — the database enforces referential integrity)
- "What is `BIGSERIAL`?" (auto-incrementing 64-bit integer — safe for very large tables. `SERIAL` is 32-bit, hits ~2 billion)
- "Why `TIMESTAMPTZ` not `TIMESTAMP`?" (stores timezone info — `TIMESTAMP` is timezone-naive and causes bugs when your server or users are in different timezones)
- "What is a slug? Why must it be unique?" (URL-friendly identifier — `/posts/my-great-post`. Unique so two posts can't share a URL.)
- "What is the `post_tags` table for? Why not just a column?" (many-to-many — one post has many tags, one tag has many posts. A column can't represent this; you need a join table.)
- "Why `PRIMARY KEY (post_id, tag_id)` in `post_tags`?" (composite primary key — prevents tagging the same post with the same tag twice)
- "What is `JSONB` in the jobs table?" (binary JSON — flexible payload storage. Each job type has different data; JSONB lets us store any shape without schema changes.)
- "What is the partial index `WHERE status = 'pending'`?" (only indexes pending jobs — the job queue query only reads pending jobs, so we don't waste space indexing done/failed ones)

---

## The jobs table — Postgres as a queue

"Why not use RabbitMQ or Kafka?"

"A dedicated message broker is another service to run, monitor, and fail. For most apps, Postgres is fast enough as a queue. We're already using it. One fewer dependency."

"The pattern is called `SKIP LOCKED`:"

```sql
-- Worker claims a job atomically
UPDATE jobs
SET status = 'running', attempts = attempts + 1
WHERE id = (
    SELECT id FROM jobs
    WHERE status = 'pending'
      AND scheduled_at <= NOW()
    ORDER BY scheduled_at ASC
    FOR UPDATE SKIP LOCKED
    LIMIT 1
)
RETURNING *;
```

Ask: "What does `FOR UPDATE SKIP LOCKED` do?" (locks the selected row for update AND skips any rows already locked by other transactions — allows multiple workers to claim different jobs simultaneously without conflicting)
Ask: "Without `SKIP LOCKED`, what would happen if two workers ran this query at the same time?" (both would try to update the same row — one would block waiting for the other's lock, creating a bottleneck)

---

## Migration runner

"We'll write numbered SQL files and a Go function that runs any that haven't been run yet."

```
internal/db/migrations/
  001_initial_schema.sql
  002_add_search_vector.sql
  003_add_jobs_table.sql
```

`internal/db/migrate.go`:

```go
package db

import (
    "database/sql"
    "fmt"
    "os"
    "path/filepath"
    "sort"
)

func Migrate(db *sql.DB, migrationsDir string) error {
    // Create migrations tracking table if it doesn't exist
    _, err := db.Exec(`
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version TEXT PRIMARY KEY,
            applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
    `)
    if err != nil {
        return fmt.Errorf("creating migrations table: %w", err)
    }

    // Read all migration files
    entries, err := os.ReadDir(migrationsDir)
    if err != nil {
        return fmt.Errorf("reading migrations dir: %w", err)
    }

    var files []string
    for _, e := range entries {
        if !e.IsDir() && filepath.Ext(e.Name()) == ".sql" {
            files = append(files, e.Name())
        }
    }
    sort.Strings(files)

    for _, filename := range files {
        // Check if already applied
        var count int
        err := db.QueryRow(`SELECT COUNT(*) FROM schema_migrations WHERE version = $1`, filename).Scan(&count)
        if err != nil {
            return fmt.Errorf("checking migration %s: %w", filename, err)
        }
        if count > 0 {
            continue // already applied
        }

        // Read and execute
        path := filepath.Join(migrationsDir, filename)
        content, err := os.ReadFile(path)
        if err != nil {
            return fmt.Errorf("reading %s: %w", filename, err)
        }

        if _, err := db.Exec(string(content)); err != nil {
            return fmt.Errorf("applying %s: %w", filename, err)
        }

        // Record it
        if _, err := db.Exec(`INSERT INTO schema_migrations (version) VALUES ($1)`, filename); err != nil {
            return fmt.Errorf("recording %s: %w", filename, err)
        }

        fmt.Printf("Applied migration: %s\n", filename)
    }
    return nil
}
```

Ask:
- "What is `schema_migrations`?" (a table that records which migrations have been applied — so we never run the same migration twice)
- "Why must migration files be run in order?" (later migrations may depend on tables created by earlier ones — order matters)
- "What happens if a migration fails halfway through?" (the table is partially modified — this is why real migrations often wrap in a transaction. Improvement: wrap each migration in `BEGIN; ... COMMIT;`)
- "What is `RETURNING *` in the job UPDATE query?" (returns the updated row immediately — so the worker knows which job it claimed without a separate SELECT)

---

## Checkpoint

1. "What does `ON DELETE CASCADE` do? Give a concrete example from our schema."
2. "Why `TIMESTAMPTZ` over `TIMESTAMP`?"
3. "What is a composite primary key? Where do we use one?"
4. "What does `SKIP LOCKED` prevent when multiple workers read the job queue?"
5. "How does the migration runner know which migrations have already been applied?"
6. "What is `JSONB`? Why is it useful for the jobs table?"

---

## Commit

```bash
git add .
git commit -m "Blog schema: all tables, indexes, migration runner"
```
