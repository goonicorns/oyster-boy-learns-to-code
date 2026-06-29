# Lesson 17: Analysis Endpoints — Wiring It to the API

**Paste into Claude Code after the system prompt**

---

## Context for Claude

The TA engine is calculating and storing indicators. This lesson adds the API endpoints to expose that data, and introduces a brief but important discussion about API design — when to return stale cached data vs. calculate fresh.

**This lesson's goal:**
- Add `GET /analysis/{symbol}` endpoint
- Add `GET /analysis` endpoint (all symbols)
- Handle the "no data yet" case gracefully
- Test with curl
- Talk about the design decision: pre-computed vs on-demand

---

## What to teach

### Design discussion first

Before writing any handler, ask:

"We have two ways to serve analysis data. Which do you think is better?"

**Option A — Pre-computed (what we built):**
The background worker calculates indicators every time new prices arrive. The API endpoint just reads from the `indicators` table.
- Fast: just a DB read, no math at request time
- Possibly stale: if the background worker is behind, data could be a few minutes old
- Scales well: 1000 simultaneous requests → 1000 DB reads (fast)

**Option B — On-demand:**
When a client requests `/analysis/BTC`, we fetch prices and calculate SMA/EMA right then.
- Always fresh
- Slower: math + DB queries on every request
- Doesn't scale: 1000 simultaneous requests → 1000 sets of math + DB queries

"Which would you choose for a dashboard showing crypto trends?"

Guide them to: pre-computed is right here. The data is only as fresh as the price data anyway (we fetch every 5 minutes), so being slightly behind by one calculation cycle is negligible. The read speed matters more.

"This is called a 'read-through cache' pattern — you do expensive work upfront and store the result, then serve the stored result cheaply. Redis, Memcached, CDNs — all of these are based on the same idea."

### Write the handler

Guide them to create `handler/analysis.go`:

**GET /analysis/{symbol}**

Ask the questions in sequence:
1. "How do we read the symbol from the URL?" (they did this before with chi.URLParam)
2. "What store function gives us the latest indicators for a symbol?"
3. "What if the symbol doesn't exist in our database yet? What should we return?" (404 with a helpful message)
4. "What does the response look like?" (JSON with success + data)

Common mistake to watch for: they might try to handle `pgx.ErrNoRows` (when the DB query returns nothing). Ask: "What does `GetLatestIndicators` return when there are no rows? Does it return an empty struct or an error?" (it returns an error — specifically `pgx.ErrNoRows`)

Guide them to import `pgx` and check for that error:

```go
import "github.com/jackc/pgx/v5"

func GetAnalysis(w http.ResponseWriter, r *http.Request) {
    symbol := strings.ToUpper(chi.URLParam(r, "symbol")) // normalize to uppercase

    indicators, err := store.GetLatestIndicators(r.Context(), symbol)
    if err != nil {
        if errors.Is(err, pgx.ErrNoRows) {
            JSON(w, http.StatusNotFound, model.APIResponse{
                Success: false,
                Error:   fmt.Sprintf("no analysis data for %s yet — wait for the next price fetch", symbol),
            })
            return
        }
        log.Printf("GetAnalysis %s: %v", symbol, err)
        JSON(w, http.StatusInternalServerError, model.APIResponse{
            Success: false,
            Error:   "internal error",
        })
        return
    }

    JSON(w, http.StatusOK, model.APIResponse{
        Success: true,
        Data:    indicators,
    })
}
```

Ask: "Why `strings.ToUpper` on the symbol?" (so `/analysis/btc` and `/analysis/BTC` both work — defensive programming)

**GET /analysis (all symbols)**

Ask: "We don't have a `GetAllLatestIndicators` store function. Do we write one, or can we reuse what we have?"

Guide them to write a new store function:
```go
func GetAllLatestIndicators(ctx context.Context) ([]model.Indicators, error)
```

Ask: "What SQL do you think gives you only the most recent indicator row per symbol?"

This is a SQL challenge — let them try. Hint if stuck: `DISTINCT ON (symbol)` (Postgres-specific) or a subquery with `MAX(calculated_at)`.

```sql
SELECT DISTINCT ON (symbol) id, symbol, sma_7, sma_30, ema_7, ema_30, calculated_at
FROM indicators
ORDER BY symbol, calculated_at DESC
```

### Wire up the routes

"Where do new routes get added?" (main.go or wherever they set up chi)

Guide them to add to the protected route group:
```go
r.Get("/analysis", handler.GetAllAnalysis)
r.Get("/analysis/{symbol}", handler.GetAnalysis)
```

### Test with curl

```bash
# Get analysis for BTC
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/analysis/BTC | jq

# Get all symbols
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/analysis | jq

# Try a symbol we don't have
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/analysis/DOGE | jq

# Try lowercase
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/analysis/btc | jq
```

Walk through the output with them:
- "What is SMA-7 for BTC right now? Is it above or below the current price? What does that suggest?"
- "Is SMA-30 populated yet? Why or why not?" (need 30 price data points — may not have them yet)
- "What do you notice about SMA-7 vs EMA-7? Which one is closer to the current price?"

### Add the routes to the curl test script

Have them update `scripts/test-api.sh`:
```bash
# Test analysis endpoint
STATUS=$(curl -o /dev/null -s -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE/analysis/BTC")
[[ "$STATUS" == "200" || "$STATUS" == "404" ]] && pass "Get BTC analysis" || fail "Analysis returned $STATUS"
```

("404 is OK because we might not have 7 price points yet in a fresh test run")

---

## Commit

```bash
git add .
git commit -m "Add GET /analysis endpoints for TA indicators"
```

---

## What they've now built

Pause and take inventory with them:

```
GET /prices           → latest price per symbol
GET /prices/{symbol}  → latest price for one symbol
POST /register        → create account
POST /login           → get JWT
GET /me               → current user info
GET /analysis         → SMA-7, SMA-30, EMA-7, EMA-30 for all tracked symbols
GET /analysis/{symbol}→ same for one symbol

Background workers:
  → every 5 min: fetch prices from CoinGecko → store → recalculate indicators
```

"That's a real API. With real data. With authentication. With technical analysis."

---

## Docker — update the Compose file for the full stack

"Project 1 had Postgres in Docker. Now we have the whole app to containerize too. Update the Docker Compose — add the app service."

They've written a Dockerfile in Project 1. Have them write it from memory for this one.

Ask: "The TA engine has a background goroutine that fetches prices every 5 minutes. What does Docker do to your goroutines when the container gets a SIGTERM?" (the container receives the signal, the Go runtime propagates it — if the app doesn't handle it gracefully, goroutines are killed mid-work. Ask: did we implement graceful shutdown? If not: how would you?)

Ask: "The Postgres container has a volume for data persistence. Does the app container need one?" (no — the app is stateless. All state is in Postgres. Any number of app containers can run simultaneously against the same database.) 

That last point is important — make them understand stateless apps vs stateful databases.
