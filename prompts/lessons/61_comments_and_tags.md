# Lesson 61: Comments, Tags, and HTTP Handler Patterns

**For Claude — do not show this file to the learner**

---

## Context for Claude

Comments and tags are more CRUD but use them to cement patterns: transactions (add tags atomically with the post), upsert (create a tag if it doesn't exist), and input validation. Don't let them copy-paste — quiz on every line. Also cover proper HTTP handler structure, error types, and returning the right status codes.

**This lesson's goal:**
- Implement comments (CREATE + LIST — delete is review)
- Implement tag upsert with `INSERT ... ON CONFLICT DO NOTHING`
- Use transactions to associate tags with a post atomically
- Input validation: what to check, where to check it
- Return the right HTTP status codes for each error case

---

## Comments

"Comments are the simplest: user ID (from JWT), post ID (from URL), body (from request). What validations would you add?"

Make them think through it:
- body must not be empty
- body has a max length (prevent 100MB comments)
- post must be published (can't comment on a draft)
- optional: rate limiting (1 comment per 10 seconds per user)

`internal/comments/store.go`:

```go
type Comment struct {
    ID        int64
    PostID    int64
    AuthorID  int64
    Body      string
    CreatedAt time.Time
    // Joined:
    AuthorUsername string
}

func (s *Store) Create(ctx context.Context, postID, authorID int64, body string) (*Comment, error) {
    if len(strings.TrimSpace(body)) == 0 {
        return nil, fmt.Errorf("comment body cannot be empty")
    }
    if len(body) > 10000 {
        return nil, fmt.Errorf("comment too long (max 10000 characters)")
    }

    var c Comment
    err := s.db.QueryRowContext(ctx, `
        INSERT INTO comments (post_id, author_id, body)
        VALUES ($1, $2, $3)
        RETURNING id, post_id, author_id, body, created_at
    `, postID, authorID, body).Scan(
        &c.ID, &c.PostID, &c.AuthorID, &c.Body, &c.CreatedAt,
    )
    if err != nil {
        return nil, fmt.Errorf("creating comment: %w", err)
    }
    return &c, nil
}

func (s *Store) ListByPost(ctx context.Context, postID int64) ([]*Comment, error) {
    rows, err := s.db.QueryContext(ctx, `
        SELECT c.id, c.post_id, c.author_id, c.body, c.created_at, u.username
        FROM comments c
        JOIN users u ON u.id = c.author_id
        WHERE c.post_id = $1
        ORDER BY c.created_at ASC
    `, postID)
    if err != nil {
        return nil, err
    }
    defer rows.Close()

    var comments []*Comment
    for rows.Next() {
        var c Comment
        if err := rows.Scan(&c.ID, &c.PostID, &c.AuthorID, &c.Body, &c.CreatedAt, &c.AuthorUsername); err != nil {
            return nil, err
        }
        comments = append(comments, &c)
    }
    return comments, rows.Err()
}
```

Ask: "What does `JOIN users u ON u.id = c.author_id` do?" (fetches the author's username alongside the comment in one query — instead of fetching comments, then looping and fetching each user separately, which would be N+1 queries)
Ask: "What is the N+1 query problem?" (if you fetch 100 comments and then make 100 separate queries for each author's username, that's 101 queries. A JOIN does it in 1.)

---

## Tags with upsert

"Tags need to exist before we can associate them with a post. But we don't know which tags exist yet. Solution: `INSERT ... ON CONFLICT DO NOTHING RETURNING id`."

```go
func (s *Store) UpsertTags(ctx context.Context, tx *sql.Tx, tagNames []string) ([]int64, error) {
    var tagIDs []int64
    for _, name := range tagNames {
        name = strings.ToLower(strings.TrimSpace(name))
        if name == "" {
            continue
        }

        var id int64
        err := tx.QueryRowContext(ctx, `
            INSERT INTO tags (name) VALUES ($1)
            ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
            RETURNING id
        `, name).Scan(&id)
        if err != nil {
            return nil, fmt.Errorf("upsert tag %q: %w", name, err)
        }
        tagIDs = append(tagIDs, id)
    }
    return tagIDs, nil
}
```

Ask: "What does `ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name` do?" (if a tag with this name already exists, do a no-op update — updating name to itself. This lets us RETURNING id for existing tags too. `DO NOTHING` wouldn't return the id of existing rows in all Postgres versions.)
Ask: "What is `EXCLUDED`?" (a virtual table containing the values that WOULD have been inserted — lets you reference the rejected row in your ON CONFLICT handler)

---

## Transactions for post creation with tags

"Creating a post with tags must be atomic — either both succeed or neither does. If we insert the post successfully but fail on tags, we have a post with no tags and no way to retry cleanly."

```go
func (s *Store) CreateWithTags(ctx context.Context, authorID int64, title, body string, tagNames []string) (*Post, error) {
    tx, err := s.db.BeginTx(ctx, nil)
    if err != nil {
        return nil, fmt.Errorf("beginning transaction: %w", err)
    }
    defer tx.Rollback() // no-op if committed

    // Insert the post
    var post Post
    err = tx.QueryRowContext(ctx, `
        INSERT INTO posts (author_id, slug, title, body)
        VALUES ($1, $2, $3, $4)
        RETURNING id, slug, title, body, published, created_at
    `, authorID, slugify(title), title, body).Scan(
        &post.ID, &post.Slug, &post.Title, &post.Body, &post.Published, &post.CreatedAt,
    )
    if err != nil {
        return nil, fmt.Errorf("inserting post: %w", err)
    }

    // Upsert tags
    if len(tagNames) > 0 {
        tagIDs, err := s.UpsertTags(ctx, tx, tagNames)
        if err != nil {
            return nil, err // Rollback will fire via defer
        }

        // Associate with post
        for _, tagID := range tagIDs {
            _, err = tx.ExecContext(ctx, `
                INSERT INTO post_tags (post_id, tag_id) VALUES ($1, $2)
                ON CONFLICT DO NOTHING
            `, post.ID, tagID)
            if err != nil {
                return nil, fmt.Errorf("associating tag: %w", err)
            }
        }
    }

    if err := tx.Commit(); err != nil {
        return nil, fmt.Errorf("committing: %w", err)
    }

    post.AuthorID = authorID
    return &post, nil
}
```

Drill transactions:
Ask: "What does `defer tx.Rollback()` do? Why is it a no-op after Commit?" (if we return an error at any point, `Rollback()` fires and undoes all changes. After `Commit()` succeeds, `Rollback()` on a committed transaction does nothing — safe to always have it as the fallback)
Ask: "What goes wrong if we don't wrap this in a transaction?" (post is inserted, then tag insertion fails. We have an orphaned post with no tags. The caller gets an error, but the post IS in the database. Inconsistent state.)
Ask: "Why `ON CONFLICT DO NOTHING` in `post_tags`?" (prevent duplicate tag associations — if we call CreateWithTags twice with the same post and tags, the second call should not fail)

---

## HTTP error handling — do it right

"Every handler needs to return the correct HTTP status code. Not just 200 or 500."

```go
var (
    ErrNotFound   = fmt.Errorf("not found")
    ErrForbidden  = fmt.Errorf("forbidden")
    ErrValidation = fmt.Errorf("validation failed")
)

// Use errors.Is to classify:
func httpErrorCode(err error) int {
    switch {
    case errors.Is(err, ErrNotFound):
        return http.StatusNotFound // 404
    case errors.Is(err, ErrForbidden):
        return http.StatusForbidden // 403
    case errors.Is(err, ErrValidation):
        return http.StatusBadRequest // 400
    default:
        return http.StatusInternalServerError // 500
    }
}
```

Ask: "What is the difference between 401 and 403?" (401 Unauthorized: not authenticated — the request needs a valid token. 403 Forbidden: authenticated but not authorized — you're logged in, but this isn't your post.)
Ask: "What does a client do with a 400 vs a 500?" (400 Bad Request: the client should fix their request and NOT retry it. 500: something is wrong on the server — the client may retry.)
Ask: "Why use sentinel errors like `ErrNotFound` instead of checking error messages?" (message strings can change. Sentinel errors use `errors.Is` which works through error wrapping chains — `fmt.Errorf("getting post: %w", ErrNotFound)` still matches `errors.Is(err, ErrNotFound)`.)

---

## Checkpoint

1. "What is the N+1 query problem? How does a JOIN solve it?"
2. "What does `ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name` do? What is `EXCLUDED`?"
3. "Why wrap post creation + tag association in a transaction?"
4. "How does `defer tx.Rollback()` work after a successful Commit?"
5. "What is the difference between HTTP 401 and 403?"
6. "Why use sentinel error values (`ErrNotFound`) instead of checking error message strings?"

---

## Commit

```bash
git add .
git commit -m "Comments, tags with upsert, transactions, proper HTTP error codes"
```
