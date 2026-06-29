# Lesson 58: Redis Caching

**For Claude — do not show this file to the learner**

---

## Context for Claude

They've seen Redis concepts in Project 8 (they built a KV store). Now they use the real thing. Focus: cache-aside pattern, cache invalidation, why caching is tricky, and the specific pitfall of stale data. Don't let them think Redis is just "make it faster" — make them think about consistency. Drill hard, especially on Sim and Irsyad who may think they understand it.

**This lesson's goal:**
- Connect to Redis from Go using `github.com/redis/go-redis/v9`
- Implement the cache-aside pattern for blog posts
- Understand TTL-based invalidation vs explicit invalidation
- Understand what a cache miss is and what happens during one
- Implement cache invalidation on post update/delete

---

## Why cache?

"Reading a post from Postgres takes ~1-5ms. For a popular blog post read by 10,000 people per minute, that's 10,000 database queries per minute — potentially 10,000 connections held open."

"Redis reads take ~0.1ms and can handle hundreds of thousands of operations per second. We cache popular posts so Postgres only has to serve the first request for each post."

Ask: "What is the fundamental risk of caching?" (stale data — the cached version diverges from the database. A user edits a post, but readers see the old cached version.)

Ask: "What are the two strategies for keeping a cache fresh?"
1. TTL — cache expires automatically after N seconds. Simple. Easy. Slightly stale is acceptable.
2. Explicit invalidation — delete the cache key whenever the data changes. Always fresh. Must be done everywhere data can change.

"We'll use both: TTL as a safety net, explicit invalidation on writes."

---

## Connect to Redis

`internal/cache/cache.go`:

```go
package cache

import (
    "context"
    "encoding/json"
    "fmt"
    "time"

    "github.com/redis/go-redis/v9"
)

type Cache struct {
    rdb *redis.Client
    ttl time.Duration
}

func New(addr string, ttl time.Duration) *Cache {
    rdb := redis.NewClient(&redis.Options{
        Addr: addr,
    })
    return &Cache{rdb: rdb, ttl: ttl}
}

func (c *Cache) Ping(ctx context.Context) error {
    return c.rdb.Ping(ctx).Err()
}
```

Ask: "What is `redis.NewClient`? What does it return?" (a Redis client — a connection pool manager. Like `sql.DB`, it manages multiple connections. Creating it doesn't connect yet.)
Ask: "What does `Ping` do?" (sends the Redis PING command, expects PONG — a health check. Good to call on startup.)

---

## Cache-aside pattern

"Cache-aside: the application manages the cache manually.
1. Try to read from cache
2. If found (hit): return it
3. If not found (miss): read from database, write to cache, return it"

```go
func (c *Cache) GetPost(ctx context.Context, slug string) (*Post, error) {
    key := "post:" + slug
    data, err := c.rdb.Get(ctx, key).Bytes()
    if err == redis.Nil {
        return nil, nil // cache miss — caller must check and query DB
    }
    if err != nil {
        return nil, fmt.Errorf("redis get: %w", err)
    }

    var post Post
    if err := json.Unmarshal(data, &post); err != nil {
        return nil, fmt.Errorf("unmarshalling cached post: %w", err)
    }
    return &post, nil
}

func (c *Cache) SetPost(ctx context.Context, post *Post) error {
    key := "post:" + post.Slug
    data, err := json.Marshal(post)
    if err != nil {
        return err
    }
    return c.rdb.Set(ctx, key, data, c.ttl).Err()
}

func (c *Cache) DeletePost(ctx context.Context, slug string) error {
    return c.rdb.Del(ctx, "post:"+slug).Err()
}
```

The handler that uses it:

```go
func (h *Handler) GetPost(w http.ResponseWriter, r *http.Request) {
    slug := chi.URLParam(r, "slug")

    // 1. Try cache
    cached, err := h.cache.GetPost(r.Context(), slug)
    if err != nil {
        log.Printf("cache error: %v", err) // non-fatal — fall through to DB
    }
    if cached != nil {
        json.NewEncoder(w).Encode(cached)
        return
    }

    // 2. Cache miss — hit the database
    post, err := h.store.GetBySlug(r.Context(), slug)
    if err != nil {
        http.Error(w, "internal error", 500)
        return
    }
    if post == nil {
        http.Error(w, "not found", 404)
        return
    }

    // 3. Store in cache
    if err := h.cache.SetPost(r.Context(), post); err != nil {
        log.Printf("cache set error: %v", err) // non-fatal
    }

    json.NewEncoder(w).Encode(post)
}
```

Drill every decision:

Ask: "What is `redis.Nil`?" (a sentinel error meaning the key doesn't exist — NOT a real error. Similar to `sql.ErrNoRows`. You must handle it separately.)
Ask: "In the handler, why do we `log.Printf` the cache error and fall through instead of returning 500?" (a broken cache is not a fatal error — the data is still in the database. Return 500 only if you can't serve the request at all. Degrade gracefully.)
Ask: "What is the key format `"post:"+slug`?" (namespace by prefix — Redis is a flat keyspace. Without prefixes, `"my-post"` for a post and `"my-post"` for something else would conflict.)
Ask: "What happens if we DON'T call `DeletePost` when the post is updated?" (readers see the old content until TTL expires. If TTL is 1 hour, readers see stale content for up to 1 hour after the edit.)

---

## Cache invalidation on writes

"Whenever a post is updated or deleted, delete its cache entry immediately."

```go
func (h *Handler) UpdatePost(w http.ResponseWriter, r *http.Request) {
    // ... update in database ...

    // Invalidate cache
    if err := h.cache.DeletePost(r.Context(), post.Slug); err != nil {
        log.Printf("cache invalidation error: %v", err) // non-fatal
    }

    json.NewEncoder(w).Encode(post)
}
```

Ask: "Why not update the cache with the new version instead of deleting it?" (simpler and safer. If the database update fails, we still need to NOT have stale data in cache. Delete is always safe — at worst, the next request misses and re-fetches. An update could race with the database in complex ways.)

---

## Redis data structures — quick tour

"Redis isn't just key-value strings. It has:"

- `String`: `SET key value` — we used this
- `List`: `LPUSH / LRANGE` — ordered list of strings (e.g., recent posts)
- `Set`: `SADD / SMEMBERS` — unordered unique values (e.g., tags)
- `Sorted Set`: `ZADD / ZRANGE` — sorted by score (e.g., posts sorted by view count)
- `Hash`: `HSET / HGETALL` — field-value pairs (e.g., user session data)

Ask: "What Redis data structure would you use to track the most-viewed 10 posts?" (Sorted Set — key is the post slug, score is view count. `ZADD posts:views 1000 "my-post"`. `ZREVRANGE posts:views 0 9` returns top 10.)

Have them implement a simple "increment view count and track top posts" using sorted sets.

```go
func (c *Cache) IncrViewCount(ctx context.Context, slug string) error {
    return c.rdb.ZIncrBy(ctx, "posts:views", 1, slug).Err()
}

func (c *Cache) TopPosts(ctx context.Context, n int) ([]string, error) {
    return c.rdb.ZRevRange(ctx, "posts:views", 0, int64(n-1)).Result()
}
```

Ask: "What is `ZIncrBy`?" (atomically increments the score for a member in a sorted set — thread-safe without any locks, handled by Redis's single-threaded command processor)

---

## Checkpoint

1. "What is the cache-aside pattern? Walk me through the three steps."
2. "What is `redis.Nil`? Why must you handle it differently from other errors?"
3. "Why do we use key prefixes like `'post:'`?"
4. "A post is updated in the database. What must happen to the cache?"
5. "Why delete the cache key on update instead of setting the new value?"
6. "A cache error occurs during GetPost. Should we return 500 or fall through to the database? Why?"
7. "What Redis data structure would you use to find the top 10 most-commented posts?"

---

## Commit

```bash
git add .
git commit -m "Redis caching: cache-aside pattern, invalidation, sorted set view counts"
```
