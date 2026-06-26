# Lesson 16: Storing Indicators — Database Integration

**Paste into Claude Code after the system prompt**

---

## Context for Claude

SMA and EMA work as pure math functions. Now we connect them to the database: pull price history from Postgres, calculate indicators, store the results back. This lesson teaches reading from and writing to the database in a real workflow.

**This lesson's goal:**
- Write a store function that fetches enough price history for TA calculations
- Write a store function that saves calculated indicators
- Write the orchestration function that ties math → database together
- Run it manually to verify it works

---

## What to teach

### What data we need from the database

"Our SMA-30 needs the last 30 prices. Our EMA-30 needs at least 31. So we need to fetch the last ~60 prices per symbol to have enough data for all calculations."

Ask: "We only want BTC prices, not mixed with ETH. What SQL does that look like?"

Guide them:
```sql
SELECT price_usd FROM prices
WHERE symbol = $1
ORDER BY fetched_at DESC
LIMIT $2
```

"But wait — we're ordering newest-first to get the most recent prices, then limiting. What problem does that create for our SMA/EMA functions?"

They should realize: the prices come back newest-to-oldest, but our functions expect oldest-to-newest (to iterate forward through time).

Ask: "How do we fix that?" Two options:
1. Reverse the slice in Go after fetching
2. Change the SQL: wrap in a subquery or use `ORDER BY fetched_at ASC` with a different approach

Guide them to reverse the slice in Go — simpler and teaches slice manipulation:

```go
// Reverse a slice in-place
for i, j := 0, len(prices)-1; i < j; i, j = i+1, j-1 {
    prices[i], prices[j] = prices[j], prices[i]
}
```

Ask: "What does `i, j = i+1, j-1` do? Walk through it for a 4-element slice."

### Write the store functions

Create `store/analysis.go`. Guide them to write two functions:

**Fetch prices for TA:**
```go
func GetPricesForAnalysis(ctx context.Context, symbol string, limit int) ([]float64, error) {
    rows, err := DB.Query(ctx,
        `SELECT price_usd FROM prices
         WHERE symbol = $1
         ORDER BY fetched_at DESC
         LIMIT $2`,
        symbol, limit,
    )
    if err != nil {
        return nil, fmt.Errorf("fetching prices for %s: %w", symbol, err)
    }
    defer rows.Close()

    var prices []float64
    for rows.Next() {
        var p float64
        if err := rows.Scan(&p); err != nil {
            return nil, err
        }
        prices = append(prices, p)
    }

    // Reverse: DB gave us newest-first, we need oldest-first
    for i, j := 0, len(prices)-1; i < j; i, j = i+1, j-1 {
        prices[i], prices[j] = prices[j], prices[i]
    }

    return prices, rows.Err()
}
```

Ask them to write this themselves, guided by the questions above. Don't show it until they've tried.

**Store calculated indicators:**
```go
func SaveIndicators(ctx context.Context, symbol string, sma7, sma30, ema7, ema30 float64) error {
    _, err := DB.Exec(ctx,
        `INSERT INTO indicators (symbol, sma_7, sma_30, ema_7, ema_30)
         VALUES ($1, $2, $3, $4, $5)`,
        symbol, sma7, sma30, ema7, ema30,
    )
    return err
}
```

**Get the latest indicators for a symbol:**
```go
func GetLatestIndicators(ctx context.Context, symbol string) (*model.Indicators, error) {
    var ind model.Indicators
    err := DB.QueryRow(ctx,
        `SELECT id, symbol, sma_7, sma_30, ema_7, ema_30, calculated_at
         FROM indicators
         WHERE symbol = $1
         ORDER BY calculated_at DESC
         LIMIT 1`,
        symbol,
    ).Scan(&ind.ID, &ind.Symbol, &ind.SMA7, &ind.SMA30, &ind.EMA7, &ind.EMA30, &ind.CalculatedAt)
    if err != nil {
        return nil, fmt.Errorf("getting indicators for %s: %w", symbol, err)
    }
    return &ind, nil
}
```

### Add the Indicators type to the model

Ask: "Where do shared data types live in our project?" (model/types.go)

Guide them to add:
```go
type Indicators struct {
    ID           int
    Symbol       string
    SMA7         float64
    SMA30        float64
    EMA7         float64
    EMA30        float64
    CalculatedAt string
}
```

### The orchestration function

This is the glue: fetch prices → calculate → store.

Create `analysis/analysis.go`:

```go
package analysis

import (
    "context"
    "fmt"
    "log"
    "cryptowatch/store"
)

// Calculate fetches price history for a symbol, runs all TA calculations,
// and stores the results in the database.
func Calculate(ctx context.Context, symbol string) error {
    // Fetch enough prices for our longest period (SMA-30 needs 30, EMA-30 needs 31)
    prices, err := store.GetPricesForAnalysis(ctx, symbol, 60)
    if err != nil {
        return fmt.Errorf("fetching prices for %s: %w", symbol, err)
    }

    if len(prices) < 7 {
        log.Printf("not enough price data for %s (have %d, need 7)", symbol, len(prices))
        return nil // not an error, just not enough data yet
    }

    // Calculate what we can (some may fail if not enough data yet)
    var sma7, sma30, ema7, ema30 float64

    if sma7, err = SMA(prices, 7); err != nil {
        log.Printf("SMA-7 for %s: %v", symbol, err)
    }
    if sma30, err = SMA(prices, 30); err != nil {
        log.Printf("SMA-30 for %s: %v (need more data)", symbol, err)
    }
    if ema7, err = EMA(prices, 7); err != nil {
        log.Printf("EMA-7 for %s: %v", symbol, err)
    }
    if ema30, err = EMA(prices, 30); err != nil {
        log.Printf("EMA-30 for %s: %v (need more data)", symbol, err)
    }

    return store.SaveIndicators(ctx, symbol, sma7, sma30, ema7, ema30)
}
```

Ask:
- "Why do we log errors for individual indicators instead of returning them?" (we still want to store what we CAN calculate, even if we don't have enough data for SMA-30 yet)
- "What's the minimum prices before SMA-7 is possible?" (7) "Before SMA-30?" (30) "Before EMA-30?" (31)

### Wire it into the price fetcher

Guide them to update `store/fetch.go` to call `analysis.Calculate` after storing new prices:

```go
// After inserting prices...
for _, symbol := range []string{"BTC", "ETH"} {
    if err := analysis.Calculate(ctx, symbol); err != nil {
        log.Printf("calculating indicators for %s: %v", symbol, err)
    }
}
```

### Test it manually

```bash
go run main.go
# Wait a few seconds for the first fetch

# Check the database
docker exec -it cryptowatch-db psql -U dev -d cryptowatch \
  -c "SELECT symbol, sma_7, sma_30, ema_7, ema_30, calculated_at FROM indicators ORDER BY calculated_at DESC LIMIT 5;"
```

"Do you see rows? If SMA-30 is 0, why? How many prices do we have so far?"

```bash
docker exec -it cryptowatch-db psql -U dev -d cryptowatch \
  -c "SELECT symbol, COUNT(*) FROM prices GROUP BY symbol;"
```

---

## Commit

```bash
git add .
git commit -m "Store and retrieve TA indicators in database"
```
