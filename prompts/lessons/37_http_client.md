# Lesson 37: Go as an HTTP Client — Fetching Prices

**For Claude — do not show this file to the learner**

---

## Context for Claude

Every project so far has been an HTTP server. Now they write Go code that makes HTTP requests — Go as a CLIENT. This is how most Go programs work in practice: talking to external APIs. This lesson: fetch crypto prices from CoinGecko's free API, decode JSON, handle errors properly.

**This lesson's goal:**
- Use `net/http` to make GET requests
- Decode JSON responses into Go structs
- Handle HTTP errors vs network errors (different things)
- Set timeouts on the HTTP client (never use the default)
- Use `context` to cancel requests
- Model the price data cleanly

---

## The default HTTP client is dangerous

"Before we fetch anything, here's a trap most beginners fall into:"

```go
// NEVER do this in production
resp, err := http.Get("https://api.coingecko.com/api/v3/...")
```

Ask: "What's wrong with `http.Get`?" Let them think. They won't know.

"The default HTTP client has no timeout. If the server hangs, your program hangs forever. In a CLI, that means it never exits. In a server, it means goroutine leak."

"Always create a client with a timeout:"

```go
client := &http.Client{
    Timeout: 10 * time.Second,
}
```

Ask: "What happens after 10 seconds if the server hasn't responded?" (the request is cancelled, `err` is non-nil — specifically a timeout error)

---

## The CoinGecko API

"CoinGecko has a free tier — no API key needed for basic price queries."

The endpoint:
```
GET https://api.coingecko.com/api/v3/simple/price?ids=ethereum,usd-coin,chainlink&vs_currencies=usd
```

Response:
```json
{
  "ethereum": {"usd": 3241.50},
  "usd-coin": {"usd": 1.0001},
  "chainlink": {"usd": 14.23}
}
```

Have them open the URL in their browser first. Ask: "What format is this? What does each field mean?"

---

## Write the price fetcher

`internal/prices/coingecko.go`:

```go
package prices

import (
    "context"
    "encoding/json"
    "fmt"
    "net/http"
    "strings"
    "time"
)

// CoinGecko IDs for tokens we support
var TokenIDs = map[string]string{
    "ETH":  "ethereum",
    "USDC": "usd-coin",
    "USDT": "tether",
    "LINK": "chainlink",
    "UNI":  "uniswap",
    "WBTC": "wrapped-bitcoin",
}

type Client struct {
    http    *http.Client
    baseURL string
}

func NewClient() *Client {
    return &Client{
        http:    &http.Client{Timeout: 10 * time.Second},
        baseURL: "https://api.coingecko.com/api/v3",
    }
}

// Prices fetches USD prices for a list of token symbols (e.g. ["ETH", "USDC"])
func (c *Client) Prices(ctx context.Context, symbols []string) (map[string]float64, error) {
    // Convert symbols to CoinGecko IDs
    ids := make([]string, 0, len(symbols))
    symbolToID := make(map[string]string)
    for _, sym := range symbols {
        id, ok := TokenIDs[sym]
        if !ok {
            return nil, fmt.Errorf("unknown token symbol: %s", sym)
        }
        ids = append(ids, id)
        symbolToID[id] = sym
    }

    url := fmt.Sprintf("%s/simple/price?ids=%s&vs_currencies=usd",
        c.baseURL,
        strings.Join(ids, ","),
    )

    req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
    if err != nil {
        return nil, fmt.Errorf("building request: %w", err)
    }
    req.Header.Set("Accept", "application/json")

    resp, err := c.http.Do(req)
    if err != nil {
        return nil, fmt.Errorf("fetching prices: %w", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        return nil, fmt.Errorf("CoinGecko returned %d", resp.StatusCode)
    }

    // Response shape: {"ethereum": {"usd": 3241.5}, ...}
    var raw map[string]map[string]float64
    if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
        return nil, fmt.Errorf("decoding response: %w", err)
    }

    result := make(map[string]float64, len(symbols))
    for id, prices := range raw {
        sym := symbolToID[id]
        result[sym] = prices["usd"]
    }
    return result, nil
}
```

Walk through every decision with questions:

- "Why `http.NewRequestWithContext` instead of just `http.NewRequest`?" (we pass a context — if the CLI is cancelled with Ctrl+C, the request is cancelled too, not left hanging)
- "Why `defer resp.Body.Close()`?" (HTTP response bodies are streams — if you don't close them, the underlying TCP connection is never returned to the pool. Memory and connection leak.)
- "Why check `resp.StatusCode != http.StatusOK`?" (a non-error network response doesn't mean the request succeeded — the server might return 429 Too Many Requests or 500 Internal Server Error, both of which are valid HTTP but indicate failure)
- "What's the difference between an HTTP error and a network error?" (network error: couldn't reach the server at all — `err != nil`. HTTP error: reached the server, but it returned a bad status code — `err == nil` but `StatusCode != 200`)
- "What does `defer resp.Body.Close()` guarantee?" (it runs even if the function returns early due to a decode error — any exit path, the body gets closed)

---

## Test it manually

Wire it up in `cmd/show.go` temporarily:
```go
priceClient := prices.NewClient()
p, err := priceClient.Prices(context.Background(), []string{"ETH", "USDC", "LINK"})
if err != nil {
    return err
}
for sym, price := range p {
    fmt.Printf("%s: $%.2f\n", sym, price)
}
```

Run it. Prices should print. Ask: "Are these the real current prices?" (yes — live from CoinGecko)

---

## Write a proper unit test — with a fake server

"We don't want our tests making real HTTP requests. They'd be slow, flaky, and rate-limited. Instead, we mock the HTTP server."

```go
// internal/prices/coingecko_test.go
package prices

import (
    "context"
    "net/http"
    "net/http/httptest"
    "testing"
)

func TestPrices(t *testing.T) {
    // httptest.NewServer creates a real HTTP server on localhost, just for tests
    server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Verify the request looks right
        if r.URL.Path != "/simple/price" {
            t.Errorf("unexpected path: %s", r.URL.Path)
        }

        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
        w.Write([]byte(`{"ethereum":{"usd":3000.00},"usd-coin":{"usd":1.00}}`))
    }))
    defer server.Close()

    // Point our client at the fake server
    client := &Client{
        http:    server.Client(),
        baseURL: server.URL,
    }

    prices, err := client.Prices(context.Background(), []string{"ETH", "USDC"})
    if err != nil {
        t.Fatal(err)
    }
    if prices["ETH"] != 3000.00 {
        t.Errorf("expected ETH=3000, got %f", prices["ETH"])
    }
}
```

Ask:
- "What is `httptest.NewServer`?" (starts a real HTTP server on a random port — your code talks to it like a real server, but it's local and controlled)
- "Why use a fake server instead of mocking the `http.Client`?" (testing the real HTTP layer is more accurate — you test that your request format, header setting, and response parsing all work together)
- "What does `defer server.Close()` do?" (stops the server after the test — releases the port)

---

## Checkpoint

1. "What is wrong with using the default `http.Get`?"
2. "What is the difference between a network error and an HTTP error? Give an example of each."
3. "Why must you always `defer resp.Body.Close()`?"
4. "What does passing a `context.Context` to `http.NewRequestWithContext` allow?"
5. "What is `httptest.NewServer` and why is it better than mocking the HTTP client?"
6. "What HTTP status code does CoinGecko return for rate limiting? Go look it up." (429 Too Many Requests — make them find it)

---

## Commit

```bash
git add .
git commit -m "Fetch live prices from CoinGecko with proper timeout and error handling"
```
