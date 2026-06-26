# Lesson 09: Fetching Real Crypto Prices

**Paste into Claude Code after the system prompt**

---

## Context for Claude

The app needs real price data. We'll fetch it from a free public API (CoinGecko) using Go's HTTP client. This lesson teaches them how to make outgoing HTTP requests and parse JSON responses.

**This lesson's goal:**
- Make outgoing HTTP requests from Go
- Parse JSON from an external API
- Store fetched prices in the database
- Schedule periodic price fetching with a goroutine

---

## What to teach

### Go as an HTTP client (not just server)

"So far Go has been the server — it received HTTP requests. Now it's going to be a client — it will MAKE HTTP requests to another server to get data."

"The `net/http` package handles both. `http.Get(url)` sends a GET request and gives you the response."

### The API we'll use

"CoinGecko has a free API that doesn't require authentication for basic price queries."

Endpoint: `https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=usd`

Response looks like:
```json
{
  "bitcoin": {"usd": 65000.5},
  "ethereum": {"usd": 3502.75}
}
```

### Guide them to write the fetch function

Create `store/fetch.go`. Guide with questions:

1. "What package do we need to make HTTP requests?" (net/http)
2. "How do you think we make a GET request in Go?"
3. Show them: `resp, err := http.Get(url)`
4. "What's in resp? What's resp.Body?"
5. "We need to close the body when we're done. How do we ensure that?" (defer resp.Body.Close())
6. "How do we parse the JSON response?" (json.NewDecoder(resp.Body).Decode(&result))
7. "What type do we decode into?" — this is interesting. Ask them to look at the JSON structure.

The response is a map of maps:
```go
type CoinGeckoResponse map[string]map[string]float64
```

Guide them to write:
```go
func FetchAndStorePrices(ctx context.Context) error {
    url := "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=usd"

    resp, err := http.Get(url)
    if err != nil {
        return fmt.Errorf("fetching prices: %w", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        return fmt.Errorf("unexpected status: %d", resp.StatusCode)
    }

    var data map[string]map[string]float64
    if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
        return fmt.Errorf("decoding response: %w", err)
    }

    // Map from CoinGecko names to our symbol names
    symbols := map[string]string{
        "bitcoin":  "BTC",
        "ethereum": "ETH",
    }

    for coinID, prices := range data {
        symbol, ok := symbols[coinID]
        if !ok {
            continue
        }
        usdPrice := prices["usd"]
        if err := InsertPrice(ctx, symbol, usdPrice); err != nil {
            log.Printf("storing %s price: %v", symbol, err)
        }
    }

    return nil
}
```

### Test the fetch

Guide them to call this from main on startup and check the database:

```bash
go run main.go
# Check prices appeared
docker exec -it cryptowatch-db psql -U dev -d cryptowatch -c "SELECT * FROM prices ORDER BY fetched_at DESC LIMIT 5;"
```

### Schedule periodic fetching

"The prices should update automatically. We'll use a goroutine and a ticker."

"A ticker fires on a regular interval. Like an alarm clock that repeats."

Guide them to add to main.go (before `http.ListenAndServe`):

```go
go func() {
    // Fetch immediately on startup
    if err := store.FetchAndStorePrices(context.Background()); err != nil {
        log.Printf("initial price fetch: %v", err)
    }

    // Then fetch every 5 minutes
    ticker := time.NewTicker(5 * time.Minute)
    defer ticker.Stop()

    for {
        <-ticker.C  // wait for the ticker to fire
        if err := store.FetchAndStorePrices(context.Background()); err != nil {
            log.Printf("price fetch: %v", err)
        }
    }
}()
```

Ask: "Why do we put this in a goroutine?" (so it doesn't block the HTTP server from starting)
Ask: "What does `<-ticker.C` do?" (blocks until the ticker fires — the channel syntax from the exercises)

---

## Commit

```bash
git add .
git commit -m "Add crypto price fetching from CoinGecko API"
```
