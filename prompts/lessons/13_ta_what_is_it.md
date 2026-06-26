# Lesson 13: Technical Analysis Engine — What We're Building

**Paste into Claude Code after the system prompt**

---

## Context for Claude

The learners have a working crypto price monitoring API. Now they're building a technical analysis engine on top of it. This lesson is concept-heavy — make sure they understand WHAT technical analysis is before writing a single line of code.

**This lesson's goal:**
- Understand what technical analysis is and isn't
- Understand moving averages conceptually (SMA and EMA)
- Design the database schema for indicators
- Plan the new endpoints

---

## What to teach

### What is technical analysis?

"Technical analysis is the practice of looking at historical price data and trying to spot patterns or trends. It doesn't predict the future — nothing does — but it can help you understand what the market has been doing recently and in what direction it's moving."

"The simplest tool is the moving average: take the last N prices, average them. That average 'moves' as new prices come in. If the current price is above the moving average, things are trending up. If it's below, things are trending down."

"We are NOT building a machine learning price predictor. We're building the kind of indicators that actual trading dashboards show — the same thing you'd see on Coinbase or Binance in their charts."

### SMA — Simple Moving Average

"SMA-7 means: take the last 7 prices and average them. SMA-30 means: take the last 30 prices and average them."

Walk through the math manually first:

```
Prices (most recent last): 100, 102, 98, 105, 103, 107, 110

SMA-7 = (100 + 102 + 98 + 105 + 103 + 107 + 110) / 7
      = 725 / 7
      = 103.57
```

Ask: "If the current price is 115, and SMA-7 is 103.57, what does that tell you?"

Ask: "Why would you want BOTH SMA-7 and SMA-30? What's the difference?"
Guide them to: short-term vs long-term trend. SMA-7 reacts quickly to recent changes. SMA-30 is slower and smoother. When SMA-7 crosses above SMA-30, traders call that a "golden cross" — often a bullish signal.

### EMA — Exponential Moving Average

"SMA treats all prices equally. The price from 7 days ago counts the same as the price from yesterday. EMA fixes this: recent prices count more than old ones."

"EMA is calculated with a multiplier that gives more weight to recent data:

```
Multiplier = 2 / (N + 1)
EMA today  = (Price today × Multiplier) + (EMA yesterday × (1 - Multiplier))
```

For EMA-7:
- Multiplier = 2 / (7 + 1) = 0.25
- Yesterday's price matters 75%, today's price adds 25% of new weight"

Ask: "Why might traders prefer EMA over SMA?" (EMA reacts faster to price changes)

Ask: "What do you need to start calculating EMA?" (you need a starting value — usually the SMA of the first N prices)

### What we're building

Draw the picture for them:

```
Existing:
  GET /prices          → latest prices from DB
  Background worker    → fetches prices every 5 min from CoinGecko

New:
  GET /analysis/{symbol}  → returns SMA-7, SMA-30, EMA-7, EMA-30 for a symbol

  New background worker   → after each price fetch, recalculates indicators
                            and stores them in a new "indicators" table
```

### Schema design

Ask THEM to design the table before you show anything:

"What columns does an `indicators` table need?"

Let them think. Guide with questions:
- "Which symbol is this for?" → `symbol`
- "When was this calculated?" → `calculated_at`
- "What values are we storing?" → `sma_7`, `sma_30`, `ema_7`, `ema_30`
- "Do we need a primary key?" → yes, `id`

```sql
CREATE TABLE indicators (
    id            SERIAL PRIMARY KEY,
    symbol        VARCHAR(10) NOT NULL,
    sma_7         DECIMAL(20, 8),
    sma_30        DECIMAL(20, 8),
    ema_7         DECIMAL(20, 8),
    ema_30        DECIMAL(20, 8),
    calculated_at TIMESTAMP DEFAULT NOW()
);
```

Have them run this in psql.

### Plan the Go code structure

Ask: "Where should the math functions live? Should they touch the database?"

Guide them to: "Pure math functions belong in their own package — maybe `analysis/` or `ta/`. They take a slice of prices and return a number. No database, no HTTP — just math. That makes them very easy to test."

```
analysis/
  sma.go        — SMA calculation
  ema.go        — EMA calculation
  analysis.go   — orchestrates: fetches prices from DB, calculates, stores results
```

---

## End of lesson checkpoint

Before next lesson, they should be able to:
1. Explain SMA in their own words, including the math
2. Explain why EMA is different from SMA
3. Show the new `indicators` table in psql
4. Know where the math code will live and why it's separate from the database code
