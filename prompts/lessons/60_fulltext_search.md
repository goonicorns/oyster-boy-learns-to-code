# Lesson 60: Full-Text Search with Postgres

**For Claude — do not show this file to the learner**

---

## Context for Claude

Full-text search is one of the most impressive things Postgres can do that surprises people who only know `LIKE`. This is a real concept they'll use everywhere. Teach `tsvector`, `tsquery`, `@@` operator, ranking with `ts_rank`, and automatic updates via a trigger. Then connect it to the job queue from lesson 57.

**This lesson's goal:**
- Understand why `LIKE '%word%'` is terrible for search
- Understand `tsvector` and `tsquery`
- Use the `@@` operator to match
- Rank results with `ts_rank`
- Update `search_vector` automatically via Postgres trigger
- Use the job queue to reindex on post edit

---

## Why `LIKE` is terrible

"How would you search posts for the word 'goroutine' if you only knew SQL?"

They'll say `WHERE body LIKE '%goroutine%'`.

"What's wrong with that?"

Make them think:
- No index — Postgres must scan every row in the table
- Only exact string match — doesn't find `goroutines`, `Goroutine`, `go routine`
- No relevance ranking — all matches equal
- Doesn't understand language — `running`, `run`, `ran` are three different strings

"Full-text search solves all of these."

---

## tsvector and tsquery

"`tsvector` is a processed, sorted list of lexemes — words in their normalized form, stripped of stop words, with their positions."

```sql
SELECT to_tsvector('english', 'Go routines are running goroutines');
-- Result: 'go':1,5 'goroutin':5 'routin':2 'run':4
-- Note: 'are' is removed (stop word), 'routines' → 'routin' (stemmed)
```

"`tsquery` is a search query: words with AND, OR, NOT operators."

```sql
SELECT to_tsquery('english', 'goroutine & channel');
-- Result: 'goroutin' & 'channel'

-- Match:
SELECT to_tsvector('english', 'goroutines and channels are powerful')
    @@ to_tsquery('english', 'goroutine & channel');
-- true
```

Ask: "What does `'goroutines' → 'goroutin'` mean?" (stemming — reducing words to their root form. `goroutine`, `goroutines`, `goroutined` all map to `goroutin`. The same stem is used in both the document and the query, so they match.)
Ask: "What is a stop word?" (common words removed from the index: `the`, `is`, `are`, `a`. They appear everywhere and don't help narrow down results.)
Ask: "What does the `@@` operator do?" (matches a tsvector against a tsquery — returns true if the document matches the query)

---

## The search query

We stored `search_vector TSVECTOR` in the posts table. Now use it:

```sql
-- Search published posts
SELECT id, title, slug,
    ts_rank(search_vector, query) AS rank
FROM posts, to_tsquery('english', $1) query
WHERE published = TRUE
  AND search_vector @@ query
ORDER BY rank DESC
LIMIT 20;
```

In Go:

```go
func (s *Store) Search(ctx context.Context, q string, limit int) ([]*Post, error) {
    // Convert user input to tsquery (plainto_tsquery is more forgiving than to_tsquery)
    rows, err := s.db.QueryContext(ctx, `
        SELECT id, title, slug, published_at,
               ts_rank(search_vector, plainto_tsquery('english', $1)) AS rank,
               ts_headline('english', body, plainto_tsquery('english', $1),
                           'MaxWords=35, MinWords=15') AS excerpt
        FROM posts
        WHERE published = TRUE
          AND search_vector @@ plainto_tsquery('english', $1)
        ORDER BY rank DESC
        LIMIT $2
    `, q, limit)
    // ... scan results
}
```

Ask: "What is `plainto_tsquery` vs `to_tsquery`?" (`to_tsquery` requires proper tsquery syntax: `goroutine & channel`. `plainto_tsquery` accepts plain text: `"goroutine channel"` — words are AND'd together. For user input, always use `plainto_tsquery`.)
Ask: "What does `ts_rank` do?" (scores how well a document matches the query — more matches, closer together = higher rank. Used to sort by relevance.)
Ask: "What does `ts_headline` do?" (generates an excerpt snippet with the search terms highlighted — like Google's snippet in search results. Very useful for displaying search results.)

---

## Keeping search_vector current

"We have a `search_vector` column. How do we keep it updated when a post is created or edited?"

Two approaches:
1. Update it in Go whenever we INSERT or UPDATE a post
2. Postgres trigger — the database does it automatically

"We'll use both — the trigger is the safety net."

**Postgres trigger** (in a migration file):

```sql
CREATE FUNCTION update_post_search_vector() RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector :=
        setweight(to_tsvector('english', coalesce(NEW.title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(NEW.body, '')), 'B');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER post_search_vector_update
BEFORE INSERT OR UPDATE ON posts
FOR EACH ROW EXECUTE FUNCTION update_post_search_vector();
```

Ask: "What is `setweight`?" (assigns a weight A, B, C, or D to each lexeme. A is highest weight. Title matches rank higher than body matches — a post about goroutines should rank above a post that mentions goroutines once in the body.)
Ask: "What does `BEFORE INSERT OR UPDATE` mean in the trigger?" (the function runs BEFORE the row is saved — so it modifies `NEW` (the incoming row) to set `search_vector` before it's written. If it were AFTER, the vector would always be one version behind.)
Ask: "What is `coalesce(NEW.title, '')`?" (if title is NULL, use empty string — prevents `to_tsvector` from receiving NULL and erroring)

---

## Also update via the job queue

"The trigger updates `search_vector` synchronously on every INSERT/UPDATE. For large bodies, this adds latency to the write path. Alternative: clear the vector on write, enqueue an `update_search_vector` job to update it asynchronously."

```go
// In the worker
worker.Register("update_search_vector", func(ctx context.Context, payload json.RawMessage) error {
    var p struct{ PostID int64 }
    json.Unmarshal(payload, &p)

    _, err := db.ExecContext(ctx, `
        UPDATE posts
        SET search_vector =
            setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
            setweight(to_tsvector('english', coalesce(body, '')), 'B')
        WHERE id = $1
    `, p.PostID)
    return err
})
```

Ask: "What's the tradeoff between synchronous (trigger) and asynchronous (job queue) index updates?" (trigger: always fresh, adds latency to writes. Job queue: write is fast, search is slightly stale until the job runs. For a blog: trigger is fine. For high-write rate: async.)

---

## The GIN index

"We created this in lesson 55:"
```sql
CREATE INDEX idx_posts_search ON posts USING GIN(search_vector);
```

Ask: "What is a GIN index?" (Generalized Inverted Index — maps each lexeme to the rows that contain it. The same structure as an inverted index in a search engine. `@@` uses this index — very fast even on millions of posts.)
Ask: "Why is it called 'inverted'?" (instead of `row → words`, it's `word → rows`. You look up a word and get back all document IDs that contain it. Then intersect the lists for AND queries.)

---

## Checkpoint

1. "What is `tsvector`? How is it different from storing the raw text?"
2. "What is stemming? Give an example."
3. "What does `setweight` do? Why do we weight title higher than body?"
4. "What does a Postgres BEFORE trigger do that an AFTER trigger can't?"
5. "What is `plainto_tsquery`? When should you use it over `to_tsquery`?"
6. "What is a GIN index? Why does full-text search need it?"
7. "What does `ts_headline` produce?" (highlighted excerpt with search terms bolded)

---

## Commit

```bash
git add .
git commit -m "Full-text search: tsvector, trigger, GIN index, ts_rank, ts_headline"
```
