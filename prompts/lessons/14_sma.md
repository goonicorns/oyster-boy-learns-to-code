# Lesson 14: Simple Moving Average — Pure Go Math

**Paste into Claude Code after the system prompt**

---

## Context for Claude

The learners understand what SMA is conceptually. Now they implement it in Go. This lesson is also a unit testing lesson in disguise — SMA is perfect for testing because the math is verifiable by hand.

**This lesson's goal:**
- Implement SMA as a pure Go function
- Handle edge cases (not enough data)
- Write comprehensive unit tests
- Understand why pure functions are easy to test

---

## What to teach

### Create the analysis package

"Let's create `analysis/sma.go`. This file will have no imports except `fmt` for errors — no database, no HTTP, nothing. Just math."

Guide them to create the file. Ask first:

"What does this function need to take as input, and what should it give back?"
- Input: a slice of prices (`[]float64`), and N (how many prices to average)
- Output: the SMA value (`float64`) and an error (if there aren't enough prices)

"Why do we need an error return?" — ask them. What happens if you ask for SMA-30 but only have 5 prices?

Guide them to write the function signature:
```go
func SMA(prices []float64, period int) (float64, error)
```

Then guide the implementation step by step with questions:

1. "What's the first thing to check?" (do we have enough prices?)
2. "If not enough, what do we return?" (0, error — and what's a good error message?)
3. "We only want the last `period` prices. How do we get those from the slice?" (slicing: `prices[len(prices)-period:]`)
4. "Now how do we add them all up?" (a for loop with range)
5. "And divide by what?" (period — but careful: need `float64(period)` not just `period`)

After they write it, verify their answer is essentially:
```go
func SMA(prices []float64, period int) (float64, error) {
    if len(prices) < period {
        return 0, fmt.Errorf("not enough data: need %d prices, have %d", period, len(prices))
    }
    window := prices[len(prices)-period:]
    sum := 0.0
    for _, p := range window {
        sum += p
    }
    return sum / float64(period), nil
}
```

Ask: "Why `float64(period)` instead of just `period`?" (integer division truncates — `7/2 = 3` in Go, not `3.5`)

### Write the tests before moving on

"Let's write tests for this. What are the interesting cases?"

Let them brainstorm first. Guide toward:
1. Normal case: enough prices, correct result
2. Edge case: exactly N prices (boundary)
3. Error case: fewer than N prices
4. Edge case: period of 1 (average of one number = that number)

Guide them to create `analysis/sma_test.go` with a table-driven test:

```go
func TestSMA(t *testing.T) {
    tests := []struct {
        name    string
        prices  []float64
        period  int
        want    float64
        wantErr bool
    }{
        {
            name:   "basic 3-period average",
            prices: []float64{100, 102, 104},
            period: 3,
            want:   102.0, // (100+102+104)/3 = 102
        },
        {
            name:   "uses only last N prices",
            prices: []float64{1000, 100, 102, 104},
            period: 3,
            want:   102.0, // ignores the 1000
        },
        {
            name:   "period of 1",
            prices: []float64{50, 60, 70},
            period: 1,
            want:   70.0, // just the last price
        },
        {
            name:    "not enough data",
            prices:  []float64{100, 102},
            period:  7,
            wantErr: true,
        },
        {
            name:    "empty prices",
            prices:  []float64{},
            period:  7,
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := SMA(tt.prices, tt.period)
            if (err != nil) != tt.wantErr {
                t.Errorf("SMA() error = %v, wantErr = %v", err, tt.wantErr)
                return
            }
            if !tt.wantErr && got != tt.want {
                t.Errorf("SMA() = %v, want %v", got, tt.want)
            }
        })
    }
}
```

Ask them to verify each test case by hand before running. "What should the answer be for 'basic 3-period average'? Work it out with a calculator."

Run the tests: `go test ./analysis/...`

If they all pass — point out: "You just wrote math code that is verifiably correct. The tests proved it. This is why pure functions are great — no database to set up, no server to start. Just input → output."

### Floating point precision

Run this and show them:
```go
fmt.Println((0.1 + 0.2) == 0.3) // false in most languages including Go
fmt.Println(0.1 + 0.2)          // 0.30000000000000004
```

"Floating point numbers are stored in binary, and most decimals can't be represented exactly. This is why financial software uses decimal libraries or integer math (storing cents, not dollars). For a learning project showing price trends, float64 is fine. For real trading systems, you'd use a decimal library."

Update the test comparison:
```go
// Instead of: got != tt.want
// Use a small tolerance:
const epsilon = 0.0001
if !tt.wantErr && math.Abs(got-tt.want) > epsilon {
    t.Errorf("SMA() = %v, want %v", got, tt.want)
}
```

Ask: "Why epsilon? What's `math.Abs`?" — make sure they understand before moving on.

---

## Commit

```bash
git add analysis/
git commit -m "Add SMA calculation with unit tests"
```
