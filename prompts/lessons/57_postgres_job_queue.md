# Lesson 57: Postgres as a Job Queue

**For Claude — do not show this file to the learner**

---

## Context for Claude

This is the most novel lesson in the blog project — using Postgres with SKIP LOCKED as a job queue instead of a message broker. The pattern is used in production by companies that don't want another dependency. Drill the concurrency reasoning: why SKIP LOCKED, what happens without it, how workers claim jobs safely.

**This lesson's goal:**
- Understand why you'd use Postgres instead of a message broker
- Implement job enqueuing (INSERT)
- Implement the worker: claim → execute → mark done/failed
- Understand `FOR UPDATE SKIP LOCKED` deeply
- Implement exponential backoff on failures
- Handle retries and dead jobs

---

## Why Postgres instead of RabbitMQ/Kafka?

"RabbitMQ is another service. It can fail. It needs its own monitoring. Its own backups. Its own authentication. For many apps, the complexity isn't worth it."

"Postgres already exists in our stack. It supports atomic updates. With `SKIP LOCKED`, it handles concurrent workers safely. For most apps: good enough."

"When would you outgrow Postgres as a queue?"
- Very high throughput (100k+ jobs/minute)
- When you need Kafka's durable log (jobs are events to replay)
- When consumers need to be in different languages with no Postgres client

Ask: "What is the risk of building a queue on Postgres?" (the job queue and your application data share the same database — a job spike can affect your app's database performance. With a separate broker, they're isolated.)

---

## The job types

"What background jobs does a blog need?"

Have them think through it:
- `send_welcome_email` — triggered on registration
- `notify_author` — comment on their post
- `resize_cover_image` — after upload
- `update_search_vector` — reindex post after edit (lesson 62)

---

## Enqueue a job

`internal/jobs/queue.go`:

```go
package jobs

import (
    "context"
    "database/sql"
    "encoding/json"
    "fmt"
    "time"
)

type Job struct {
    ID          int64
    Type        string
    Payload     json.RawMessage
    Status      string
    Attempts    int
    MaxAttempts int
    Error       string
    ScheduledAt time.Time
}

type Queue struct {
    db *sql.DB
}

func NewQueue(db *sql.DB) *Queue {
    return &Queue{db: db}
}

func (q *Queue) Enqueue(ctx context.Context, jobType string, payload any) error {
    data, err := json.Marshal(payload)
    if err != nil {
        return fmt.Errorf("encoding payload: %w", err)
    }

    _, err = q.db.ExecContext(ctx, `
        INSERT INTO jobs (type, payload)
        VALUES ($1, $2)
    `, jobType, data)
    return err
}

// EnqueueAfter schedules a job to run after a delay
func (q *Queue) EnqueueAfter(ctx context.Context, jobType string, payload any, delay time.Duration) error {
    data, err := json.Marshal(payload)
    if err != nil {
        return fmt.Errorf("encoding payload: %w", err)
    }

    _, err = q.db.ExecContext(ctx, `
        INSERT INTO jobs (type, payload, scheduled_at)
        VALUES ($1, $2, NOW() + $3::interval)
    `, jobType, data, delay.String())
    return err
}
```

Ask: "Why is `payload` typed as `any` in Enqueue?" (each job type has different data — `WelcomeEmailPayload{Email: "..."}` vs `ResizeImagePayload{URL: "..."}`. We marshal it to JSON for flexible storage.)
Ask: "What is `json.RawMessage`?" (raw, already-encoded JSON bytes — lets us store and retrieve JSON without knowing the exact type at queue read time)

---

## Claim and execute a job

```go
func (q *Queue) ClaimNext(ctx context.Context) (*Job, error) {
    var job Job
    var payload []byte

    err := q.db.QueryRowContext(ctx, `
        UPDATE jobs
        SET status = 'running',
            attempts = attempts + 1
        WHERE id = (
            SELECT id FROM jobs
            WHERE status = 'pending'
              AND scheduled_at <= NOW()
              AND attempts < max_attempts
            ORDER BY scheduled_at ASC
            FOR UPDATE SKIP LOCKED
            LIMIT 1
        )
        RETURNING id, type, payload, status, attempts, max_attempts, scheduled_at
    `).Scan(&job.ID, &job.Type, &payload, &job.Status,
        &job.Attempts, &job.MaxAttempts, &job.ScheduledAt)

    if err == sql.ErrNoRows {
        return nil, nil // no jobs available
    }
    if err != nil {
        return nil, fmt.Errorf("claiming job: %w", err)
    }

    job.Payload = payload
    return &job, nil
}

func (q *Queue) MarkDone(ctx context.Context, jobID int64) error {
    _, err := q.db.ExecContext(ctx, `
        UPDATE jobs SET status = 'done' WHERE id = $1
    `, jobID)
    return err
}

func (q *Queue) MarkFailed(ctx context.Context, jobID int64, errMsg string, retryAfter time.Duration) error {
    _, err := q.db.ExecContext(ctx, `
        UPDATE jobs
        SET status = CASE WHEN attempts >= max_attempts THEN 'failed' ELSE 'pending' END,
            error = $2,
            scheduled_at = NOW() + $3::interval
        WHERE id = $1
    `, jobID, errMsg, retryAfter.String())
    return err
}
```

Drill `SKIP LOCKED` hard:

Ask: "Walk me through what happens when Worker A and Worker B both run `ClaimNext` at the same time."
(Both run the inner SELECT. Worker A gets job ID 5, locks it. Worker B's SELECT SKIPS locked rows — it gets job ID 6. They claim different jobs. No conflict, no blocking.)

Ask: "What would happen without `SKIP LOCKED`?" (Worker B blocks waiting for Worker A to release the lock. Only one job is processed at a time — no parallelism.)

Ask: "What does `FOR UPDATE` alone do vs `FOR UPDATE SKIP LOCKED`?" (`FOR UPDATE` locks and WAITS for the lock. `SKIP LOCKED` locks and SKIPS locked rows immediately.)

Ask: "In `MarkFailed`, what does the CASE statement do?" (if we've hit max_attempts, mark it 'failed' permanently. Otherwise put it back to 'pending' with a future scheduled_at for retry.)

---

## The worker

```go
type HandlerFunc func(ctx context.Context, payload json.RawMessage) error

type Worker struct {
    queue    *Queue
    handlers map[string]HandlerFunc
    interval time.Duration
}

func NewWorker(q *Queue, interval time.Duration) *Worker {
    return &Worker{
        queue:    q,
        handlers: make(map[string]HandlerFunc),
        interval: interval,
    }
}

func (w *Worker) Register(jobType string, handler HandlerFunc) {
    w.handlers[jobType] = handler
}

func (w *Worker) Run(ctx context.Context) {
    ticker := time.NewTicker(w.interval)
    defer ticker.Stop()

    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            w.processNext(ctx)
        }
    }
}

func (w *Worker) processNext(ctx context.Context) {
    job, err := w.queue.ClaimNext(ctx)
    if err != nil {
        log.Printf("error claiming job: %v", err)
        return
    }
    if job == nil {
        return // nothing to do
    }

    handler, ok := w.handlers[job.Type]
    if !ok {
        w.queue.MarkFailed(ctx, job.ID, fmt.Sprintf("no handler for job type %q", job.Type), 0)
        return
    }

    if err := handler(ctx, job.Payload); err != nil {
        // Exponential backoff: 1m, 2m, 4m, 8m...
        backoff := time.Duration(1<<job.Attempts) * time.Minute
        w.queue.MarkFailed(ctx, job.ID, err.Error(), backoff)
        log.Printf("job %d (%s) failed (attempt %d): %v", job.ID, job.Type, job.Attempts, err)
        return
    }

    w.queue.MarkDone(ctx, job.ID)
    log.Printf("job %d (%s) done", job.ID, job.Type)
}
```

Ask:
- "What is exponential backoff?" (retry after 1min, then 2min, then 4min — the wait doubles each time. Prevents hammering a failing service every second.)
- "Why does the worker use `ctx.Done()` to stop?" (graceful shutdown — when the app receives SIGTERM, the context is cancelled, the worker finishes its current job and exits cleanly)
- "If a job has no registered handler, what should we do? Why `MarkFailed` instead of silently dropping?" (we want a record — dropped jobs are invisible bugs. Failing them makes the problem visible in the database.)

---

## Wire up the handlers and start the worker in main.go

```go
worker := jobs.NewWorker(queue, 5*time.Second)

worker.Register("send_welcome_email", func(ctx context.Context, payload json.RawMessage) error {
    var p struct{ Email, Username string }
    if err := json.Unmarshal(payload, &p); err != nil {
        return err
    }
    // In real life: send an email via SendGrid/SES/etc.
    log.Printf("Welcome email sent to %s (%s)", p.Email, p.Username)
    return nil
})

worker.Register("notify_author", func(ctx context.Context, payload json.RawMessage) error {
    var p struct{ AuthorID int64; CommenterName, PostTitle string }
    json.Unmarshal(payload, &p)
    log.Printf("Notified author %d: %s commented on %q", p.AuthorID, p.CommenterName, p.PostTitle)
    return nil
})

// Start worker in background
go worker.Run(ctx)
```

---

## Checkpoint

1. "What does `FOR UPDATE SKIP LOCKED` do? What problem does it solve?"
2. "Explain exponential backoff. Why is it better than retrying immediately?"
3. "What is `json.RawMessage`? Why is it useful for the job payload?"
4. "When a job fails, what two things does `MarkFailed` do based on attempt count?"
5. "Why use `ctx.Done()` in the worker loop instead of a global stop flag?"
6. "What is the downside of using Postgres as a job queue?" (shared resource with app DB — high job load affects app queries)

---

## Commit

```bash
git add .
git commit -m "Postgres job queue with SKIP LOCKED, worker, exponential backoff"
```
