# Lesson 15: Exponential Moving Average — Weighted Math

**Paste into Claude Code after the system prompt**

---

## Context for Claude

The learners have SMA working and tested. EMA is more complex because it's iterative — each value depends on the previous one. This lesson teaches iteration over sequential data, a fundamental pattern in data processing.

**This lesson's goal:**
- Understand WHY EMA weights recent data more heavily
- Implement EMA from scratch
- Understand the "seeding" problem (what's the first EMA value?)
- Write tests (including verifying against known values)

---

## What to teach

### Why EMA matters — motivate it first

"Think about what SMA-30 does: it averages the last 30 days equally. If BTC crashed hard yesterday, that one day counts for 1/30th of the average — about 3%. It barely moves the needle."

"EMA fixes this. With EMA-30, yesterday's price has roughly 6.5% weight, the day before has ~6%, the day before that ~5.6%, and so on, decaying back through history. Recent events matter more."

Show the contrast:
```
Price spike yesterday: 100 → 100 → 100 → 200 (sudden spike)

SMA-4:  (100 + 100 + 100 + 200) / 4 = 125
EMA-4:  weighs the 200 more heavily → closer to ~150
```

Ask: "For a fast-moving market, which would you rather have? One that reacts quickly or one that's sluggish?"

### The formula

Write it out and explain each piece:

```
Multiplier k = 2 / (period + 1)

EMA[0] = first SMA (use SMA of first `period` prices as the seed)
EMA[i] = (Price[i] × k) + (EMA[i-1] × (1 - k))
```

For period = 4: k = 2/(4+1) = 0.4

Walk through the calculation with a small example:
```
Prices: 10, 11, 12, 13, 14, 15

Seed (SMA of first 4): (10+11+12+13)/4 = 11.5
EMA after price 14:   (14 × 0.4) + (11.5 × 0.6) = 5.6 + 6.9 = 12.5
EMA after price 15:   (15 × 0.4) + (12.5 × 0.6) = 6.0 + 7.5 = 13.5
```

Ask: "What would SMA-4 be after 15?" ((12+13+14+15)/4 = 13.5 — in this case the same, but with volatile data they diverge)

### The seeding problem

"EMA is iterative: each value needs the previous one. What do you use as the very first EMA value?"

"The standard approach: use the SMA of the first `period` prices as the seed. Then apply the EMA formula from there."

"This means we need at least `2 × period - 1` prices to get a meaningful EMA (period prices to seed + at least one more to calculate)."

Ask: "Why `2 × period - 1` and not just `period`?"

### Guide the implementation

Create `analysis/ema.go`. Guide with questions:

1. "What's our function signature?" (same shape as SMA: `func EMA(prices []float64, period int) (float64, error)`)
2. "What's the minimum number of prices we need?" (`2*period - 1` — but you could also just require `period + 1` for at least one real EMA step after seeding)
3. "How do we get the seed value?" (call their SMA function — no need to rewrite it)
4. "Now we iterate. We start from index `period` (the first price AFTER the seed window). What do we track?" (current EMA value)
5. "What's the loop look like?" (for i from period to len(prices)-1)

Guide them toward:
```go
func EMA(prices []float64, period int) (float64, error) {
    if len(prices) < period+1 {
        return 0, fmt.Errorf("need at least %d prices for EMA-%d, have %d",
            period+1, period, len(prices))
    }

    // Seed with SMA of the first `period` prices
    seed, err := SMA(prices[:period], period)
    if err != nil {
        return 0, err
    }

    k := 2.0 / float64(period+1)
    ema := seed

    // Apply EMA formula to each remaining price
    for _, price := range prices[period:] {
        ema = (price * k) + (ema * (1 - k))
    }

    return ema, nil
}
```

Ask them to trace through their example from above by hand and check it gives the right answer before running.

### Tests

Guide them to write `analysis/ema_test.go`. Key cases:

1. "Verify your hand-calculated example from above"
2. "Not enough data → error"
3. "Constant prices → EMA equals that price" (if every price is 100, EMA is 100)
4. "Rising prices → EMA below the most recent price but above the average" (EMA lags slightly)

For the "constant prices" test — ask them first: "If every price for 10 days is exactly 50.0, what should EMA-7 be?" They should be able to figure out it must be 50.0 without computing it.

```go
{
    name:   "constant prices",
    prices: []float64{50, 50, 50, 50, 50, 50, 50, 50},
    period: 7,
    want:   50.0,
},
```

Run: `go test ./analysis/... -v`

### Compare SMA and EMA visually

After both pass, have them write a quick main program (or test) that prints both:

```go
prices := []float64{
    65000, 64500, 63000, 65500, 66000, 67000, 65800, 66500, 68000, 67500,
}
sma7, _ := analysis.SMA(prices, 7)
ema7, _ := analysis.EMA(prices, 7)
fmt.Printf("SMA-7: %.2f\n", sma7)
fmt.Printf("EMA-7: %.2f\n", ema7)
fmt.Printf("Latest price: %.2f\n", prices[len(prices)-1])
```

Ask: "Which is closer to the current price? Why?"

---

## Commit

```bash
git add analysis/
git commit -m "Add EMA calculation with unit tests"
```
