# Lesson 56: Auth and Post CRUD

**For Claude — do not show this file to the learner**

---

## Context for Claude

Auth is review from Project 1 — implement it fast. The focus is post CRUD: create, read, update, delete with proper ownership checks, draft/published state, slug generation, and the `RETURNING` clause. Be militant — every SQL query must be explained line by line.

**This lesson's goal:**
- Auth: register, login, JWT — fast (they've done this)
- Post CRUD with ownership enforcement
- Slug generation from title
- Draft vs published workflow
- `RETURNING` in INSERT for getting the ID back
- List posts with pagination

---

## Auth — quick implementation

"You've done all of this in Project 1. Move fast. The pattern is identical:
- `POST /auth/register` → hash password with bcrypt → INSERT user → return JWT
- `POST /auth/login` → look up user → verify bcrypt → return JWT
- Auth middleware → parse JWT → put user ID in context"

"Have them implement it. If they need reminders, ask questions — don't show the code."

Questions to ask as they implement:
- "What is `bcrypt.GenerateFromPassword` and why bcrypt specifically?" (adaptive hashing — slow by design, with a cost factor. Can be made slower as hardware gets faster.)
- "What goes in the JWT claims?" (user ID, issued-at, expiry — never the password)
- "How does the middleware pass the user ID to handlers?" (store in `context.WithValue`, retrieve with a typed key — not a raw string key)

---

## Slug generation

"Blog posts need URL-friendly slugs. `"My Great Post!"` → `"my-great-post"`"

```go
package posts

import (
    "regexp"
    "strings"
    "unicode"
    "golang.org/x/text/unicode/norm"
)

var nonAlphanumeric = regexp.MustCompile(`[^a-z0-9]+`)

func slugify(title string) string {
    // Normalize unicode (é → e)
    normalized := norm.NFKD.String(title)

    // Keep only ASCII
    ascii := strings.Map(func(r rune) rune {
        if r > unicode.MaxASCII {
            return -1
        }
        return r
    }, normalized)

    // Lowercase, replace non-alphanumeric runs with hyphens
    slug := nonAlphanumeric.ReplaceAllString(strings.ToLower(ascii), "-")

    // Trim leading/trailing hyphens
    return strings.Trim(slug, "-")
}
```

Ask: "What is `norm.NFKD`?" (unicode normalization — decomposes accented characters into base letter + accent mark, so stripping the accent mark gives you the base letter. `é` → `e` + combining acute → `e`)
Ask: "What if two posts have the same title?" (same slug — UNIQUE constraint will reject the second INSERT. Solution: append a number: `my-great-post-2`. Make them implement the retry logic.)

---

## Post CRUD

`internal/posts/store.go`:

```go
package posts

import (
    "context"
    "database/sql"
    "fmt"
    "time"
)

type Post struct {
    ID          int64
    AuthorID    int64
    Slug        string
    Title       string
    Body        string
    CoverURL    string
    Published   bool
    PublishedAt *time.Time
    CreatedAt   time.Time
    UpdatedAt   time.Time
}

type Store struct {
    db *sql.DB
}

func NewStore(db *sql.DB) *Store {
    return &Store{db: db}
}

func (s *Store) Create(ctx context.Context, authorID int64, title, body string) (*Post, error) {
    slug := slugify(title)

    var p Post
    err := s.db.QueryRowContext(ctx, `
        INSERT INTO posts (author_id, slug, title, body)
        VALUES ($1, $2, $3, $4)
        RETURNING id, author_id, slug, title, body, published, created_at, updated_at
    `, authorID, slug, title, body).Scan(
        &p.ID, &p.AuthorID, &p.Slug, &p.Title, &p.Body,
        &p.Published, &p.CreatedAt, &p.UpdatedAt,
    )
    if err != nil {
        return nil, fmt.Errorf("creating post: %w", err)
    }
    return &p, nil
}

func (s *Store) GetBySlug(ctx context.Context, slug string) (*Post, error) {
    var p Post
    var coverURL sql.NullString
    var publishedAt sql.NullTime

    err := s.db.QueryRowContext(ctx, `
        SELECT id, author_id, slug, title, body, cover_url, published, published_at, created_at, updated_at
        FROM posts WHERE slug = $1
    `, slug).Scan(
        &p.ID, &p.AuthorID, &p.Slug, &p.Title, &p.Body,
        &coverURL, &p.Published, &publishedAt, &p.CreatedAt, &p.UpdatedAt,
    )
    if err == sql.ErrNoRows {
        return nil, nil
    }
    if err != nil {
        return nil, fmt.Errorf("getting post: %w", err)
    }
    if coverURL.Valid {
        p.CoverURL = coverURL.String
    }
    if publishedAt.Valid {
        p.PublishedAt = &publishedAt.Time
    }
    return &p, nil
}

func (s *Store) Publish(ctx context.Context, postID, authorID int64) error {
    result, err := s.db.ExecContext(ctx, `
        UPDATE posts
        SET published = TRUE, published_at = NOW(), updated_at = NOW()
        WHERE id = $1 AND author_id = $2
    `, postID, authorID)
    if err != nil {
        return fmt.Errorf("publishing: %w", err)
    }
    rows, _ := result.RowsAffected()
    if rows == 0 {
        return fmt.Errorf("post not found or not your post")
    }
    return nil
}

func (s *Store) Delete(ctx context.Context, postID, authorID int64) error {
    result, err := s.db.ExecContext(ctx, `
        DELETE FROM posts WHERE id = $1 AND author_id = $2
    `, postID, authorID)
    if err != nil {
        return fmt.Errorf("deleting: %w", err)
    }
    rows, _ := result.RowsAffected()
    if rows == 0 {
        return fmt.Errorf("post not found or not your post")
    }
    return nil
}

func (s *Store) List(ctx context.Context, limit, offset int) ([]*Post, error) {
    rows, err := s.db.QueryContext(ctx, `
        SELECT id, author_id, slug, title, published_at, created_at
        FROM posts
        WHERE published = TRUE
        ORDER BY published_at DESC
        LIMIT $1 OFFSET $2
    `, limit, offset)
    if err != nil {
        return nil, fmt.Errorf("listing posts: %w", err)
    }
    defer rows.Close()

    var posts []*Post
    for rows.Next() {
        var p Post
        var publishedAt sql.NullTime
        if err := rows.Scan(&p.ID, &p.AuthorID, &p.Slug, &p.Title, &publishedAt, &p.CreatedAt); err != nil {
            return nil, err
        }
        if publishedAt.Valid {
            p.PublishedAt = &publishedAt.Time
        }
        posts = append(posts, &p)
    }
    return posts, rows.Err()
}
```

Ask every line:
- "What does `RETURNING` do in the INSERT?" (returns the inserted row immediately — instead of INSERT then SELECT, we do both in one query)
- "What is `sql.NullString`?" (a nullable string — `cover_url` can be NULL in the database. Go's `string` can't be nil, so we need this wrapper. `.Valid` is true if the value is non-null.)
- "In `Publish`, why do we check `AND author_id = $2`?" (ownership — without it, anyone could publish anyone else's posts. The extra condition makes the ownership check atomic with the update.)
- "What does `rows.Err()` at the end of List check for?" (errors that occurred during iteration — `rows.Next()` returns false on both EOF and error; `rows.Err()` tells you which)
- "What is `OFFSET` in the List query?" (pagination — skip the first N rows. What's the problem with OFFSET at large values? It scans and discards rows — slow on big tables. Cursor-based pagination with `WHERE id > $lastID` is faster.)

---

## Pagination — drill this

"Our list uses OFFSET. What's wrong with that at scale?"

Ask: "If you request page 10,000 with 20 items per page, what does Postgres do?" (scans and discards 200,000 rows before returning 20. Terrible performance.)

"A better approach: cursor-based pagination:"
```sql
SELECT ... FROM posts
WHERE published = TRUE AND id < $cursor
ORDER BY id DESC
LIMIT $limit
```
The client passes the last seen ID as the cursor. Fast regardless of depth.

Have them implement this as an alternative to the OFFSET approach.

---

## Checkpoint

1. "What does `RETURNING` do in a Postgres INSERT? Why is it useful?"
2. "Why do we use `sql.NullString` instead of `string` for nullable columns?"
3. "In `Publish`, why include `AND author_id = $2` in the WHERE clause?"
4. "What is the performance problem with `OFFSET` pagination at large page numbers?"
5. "What does `defer rows.Close()` prevent?" (connection pool exhaustion — an open `*sql.Rows` holds a database connection. Without Close(), the connection is never returned to the pool.)
6. "Why is `rows.Err()` checked after the loop and not just `rows.Next()`?"

---

## Commit

```bash
git add .
git commit -m "Auth + post CRUD with ownership checks, draft/publish workflow"
```
