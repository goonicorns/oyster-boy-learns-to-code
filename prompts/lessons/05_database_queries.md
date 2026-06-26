# Lesson 05: Writing Database Queries

**Paste into Claude Code after the system prompt**

---

## Context for Claude

The learners have a connected database and a working router. Now they'll write actual SQL queries from Go to store and retrieve data.

**This lesson's goal:**
- Write SQL queries in Go with pgx
- Handle database errors properly
- Store price data
- Retrieve price data (all and by symbol)

---

## What to teach

### How Go talks to SQL

"We write SQL strings in Go and send them to the database. The database runs them and sends back results. The `pgx` library handles the network communication."

"Crucially: NEVER build SQL by concatenating strings with user input. This is called SQL injection and it's how databases get hacked. Always use parameterized queries where you use `$1`, `$2` placeholders."

Show the WRONG way then the RIGHT way:

```go
// WRONG — NEVER do this
query := "SELECT * FROM users WHERE username = '" + username + "'"
// If username is "'; DROP TABLE users; --" you just deleted your database

// RIGHT — parameterized query
query := "SELECT id, username, email FROM users WHERE username = $1"
row := DB.QueryRow(ctx, query, username) // username is passed separately, safely
```

Ask: "What do you think happens if someone types SQL code into the username field?" — make sure they understand the threat before moving on.

### Write the store functions

Guide them to create `store/price.go`. Ask first:

"What operations do we need for prices?"
- Save a new price
- Get all prices (maybe limited to most recent)
- Get the latest price for a specific symbol

"Let's write these one at a time. Start with saving a price. What information do we need to save?" (symbol, price)

For `InsertPrice`:

```go
func InsertPrice(ctx context.Context, symbol string, priceUSD float64) error {
    _, err := DB.Exec(ctx,
        "INSERT INTO prices (symbol, price_usd) VALUES ($1, $2)",
        symbol, priceUSD,
    )
    return err
}
```

Explain each part — especially `ctx`. "Context carries a deadline. If this query takes 10 seconds, we might want to cancel it. Passing ctx lets the caller control that."

For `GetLatestPrices`:

```go
func GetLatestPrices(ctx context.Context) ([]model.Price, error) {
    rows, err := DB.Query(ctx, `
        SELECT DISTINCT ON (symbol) id, symbol, price_usd, fetched_at
        FROM prices
        ORDER BY symbol, fetched_at DESC
    `)
    if err != nil {
        return nil, fmt.Errorf("querying prices: %w", err)
    }
    defer rows.Close()

    var prices []model.Price
    for rows.Next() {
        var p model.Price
        err := rows.Scan(&p.ID, &p.Symbol, &p.PriceUSD, &p.FetchedAt)
        if err != nil {
            return nil, fmt.Errorf("scanning price row: %w", err)
        }
        prices = append(prices, p)
    }

    return prices, rows.Err()
}
```

Walk through each part with questions:
- "What does `rows.Close()` do? Why defer it?"
- "What is `rows.Scan()`?" (reads the columns into Go variables)
- "Why `&p.ID`?" (the & means: write into p.ID's memory location — we need the address, not the value)

### Connect handlers to store

Guide them to update their price handler to call the store function:

```go
func GetPrices(w http.ResponseWriter, r *http.Request) {
    prices, err := store.GetLatestPrices(r.Context())
    if err != nil {
        http.Error(w, "internal error", http.StatusInternalServerError)
        log.Printf("GetPrices: %v", err)
        return
    }
    JSON(w, http.StatusOK, model.APIResponse{
        Success: true,
        Data:    prices,
    })
}
```

Ask: "What does `r.Context()` give us?" (the request's context — it's cancelled if the user disconnects)

### Test with real data

```bash
# Insert some test data directly in psql
docker exec -it cryptowatch-db psql -U dev -d cryptowatch
INSERT INTO prices (symbol, price_usd) VALUES ('BTC', 65000.00);
INSERT INTO prices (symbol, price_usd) VALUES ('ETH', 3500.00);
INSERT INTO prices (symbol, price_usd) VALUES ('BTC', 65100.00);  -- newer BTC price
\q

# Start the server and test
go run main.go
curl http://localhost:8080/prices
```

"What do you see? Is it valid JSON? Does it show the right data?"

---

## Key concepts to explain

**Query vs Exec vs QueryRow:**
- `DB.Exec` — run a query that doesn't return rows (INSERT, UPDATE, DELETE)
- `DB.QueryRow` — run a query that returns exactly one row (good for SELECT by ID)
- `DB.Query` — run a query that returns multiple rows (SELECT many)

**Why wrap errors:**
"When an error bubbles up through multiple function calls, wrapping adds context at each level. `fmt.Errorf('querying prices: %w', err)` means 'I was trying to query prices, and this is what went wrong inside.' The %w is special — it lets callers unwrap the chain."

---

## Commit

```bash
git add .
git commit -m "Add database queries for prices"
```
