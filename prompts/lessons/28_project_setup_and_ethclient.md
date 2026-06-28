# Lesson 28: Project Setup — Connecting to Ethereum from Go

**For Claude — do not show this file to the learner**

---

## Context for Claude

Now they connect Go to a real Ethereum node. The goal is to get the dopamine hit of reading live blockchain data — latest block number, timestamp, hash — as fast as possible. Once they see real data come back, the rest of the project clicks into place.

**This lesson's goal:**
- Set up a new Go module for this project
- Create an Alchemy account (free) and get an API URL
- Connect to Ethereum mainnet via `ethclient`
- Read the latest block number
- Fetch a full block and inspect its fields
- Understand what `context.Background()` is and why it's everywhere in Go networking code

---

## Alchemy setup first

"We need a connection to an Ethereum node. Running your own node takes ~1TB of disk space and days to sync. We'll use Alchemy instead — a free service that gives you API access to a node."

Have them:
1. Go to alchemy.com and create a free account
2. Create an app — select "Ethereum", "Mainnet"
3. Copy the HTTPS URL — looks like `https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY`

"Store this in an environment variable — never hardcode API keys in source code."

```bash
export ETH_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"
```

Ask: "Why don't we hardcode it?" (it would end up in git history; anyone with the key can burn your API quota or use your account)

---

## Project structure

```bash
mkdir ~/projects/eth-go
cd ~/projects/eth-go
go mod init eth-go
go get github.com/ethereum/go-ethereum
```

"This is the official Go Ethereum library. Written by the same team that maintains the most popular Ethereum client. It's large — it IS a full Ethereum implementation — but we only use the client-side parts."

```
eth-go/
  main.go
  chain/
    client.go   — connection setup
  blocks/
    reader.go   — block reading
```

---

## Write the client

`chain/client.go`:

"Ask them: what do we need in this file?" — a function that connects to the node and returns a client.

Guide toward:

```go
package chain

import (
    "github.com/ethereum/go-ethereum/ethclient"
)

func Connect(rpcURL string) (*ethclient.Client, error) {
    return ethclient.Dial(rpcURL)
}
```

Ask:
- "What does `Dial` return?" (a connected client and an error)
- "What's the error for?" (network failure, bad URL, node is down)
- "Why do we return the error instead of logging and exiting?" (let the caller decide how to handle it — maybe they retry, maybe they exit, maybe they switch to a backup URL)

---

## context.Background() — explain this now, it's everywhere

Before they call any client methods, they'll see `context.Context` as a parameter. Explain it once, clearly.

"Almost every Go networking function takes a `context.Context` as its first argument. A context is a way to say: 'this operation has a deadline, and if it takes too long, cancel it.'"

"`context.Background()` is the default — it means 'no deadline, no cancellation, just do the thing.' You'll use this a lot while learning. In production code you'd set timeouts."

```go
ctx := context.Background()
```

"Think of it as a stopwatch you hand to a function. Background() is a stopwatch with no alarm set."

---

## Read the latest block number

`blocks/reader.go`:

Ask: "What function on the client do you think reads the latest block number?" — let them guess, then have them run `go doc github.com/ethereum/go-ethereum/ethclient` to look it up.

The function is `BlockNumber(ctx)`.

```go
package blocks

import (
    "context"
    "fmt"
    "github.com/ethereum/go-ethereum/ethclient"
)

func PrintLatestBlock(client *ethclient.Client) error {
    ctx := context.Background()

    blockNum, err := client.BlockNumber(ctx)
    if err != nil {
        return fmt.Errorf("getting block number: %w", err)
    }

    fmt.Printf("Latest block: %d\n", blockNum)
    return nil
}
```

Ask:
- "What type does `BlockNumber` return?" (`uint64` — ask why not int64. Because block numbers are never negative)
- "What does `%d` format?" (decimal integer)

---

## Fetch a full block and inspect it

"Block number is nice. But let's look at what a block actually contains."

The function is `BlockByNumber`. It takes a `*big.Int` for the block number — not a uint64.

Ask: "Why `*big.Int` instead of `uint64`?" (Ethereum numbers can exceed uint64 — block numbers are fine, but token amounts can be astronomically large. go-ethereum uses big.Int consistently for safety.)

```go
import (
    "math/big"
    "github.com/ethereum/go-ethereum/core/types"
)

func PrintBlock(client *ethclient.Client, number uint64) error {
    ctx := context.Background()

    block, err := client.BlockByNumber(ctx, new(big.Int).SetUint64(number))
    if err != nil {
        return fmt.Errorf("fetching block %d: %w", number, err)
    }

    fmt.Printf("Block number:    %d\n", block.Number())
    fmt.Printf("Timestamp:       %d\n", block.Time())
    fmt.Printf("Transactions:    %d\n", len(block.Transactions()))
    fmt.Printf("Gas used:        %d\n", block.GasUsed())
    fmt.Printf("Gas limit:       %d\n", block.GasLimit())
    fmt.Printf("Hash:            %s\n", block.Hash().Hex())
    fmt.Printf("Parent hash:     %s\n", block.ParentHash().Hex())

    return nil
}
```

After they run it, ask:
- "What's the parent hash?" (hash of the previous block — this is the chain)
- "How many transactions are in this block?" (varies — usually hundreds to thousands)
- "The timestamp is a Unix timestamp. What does that mean?" (seconds since January 1, 1970)
- "Gas used vs gas limit — what does it tell you if gas used is near the gas limit?" (the block is full; there's congestion; some transactions are probably waiting)

---

## Wire it up in main.go

```go
package main

import (
    "eth-go/chain"
    "eth-go/blocks"
    "fmt"
    "log"
    "os"
)

func main() {
    rpcURL := os.Getenv("ETH_RPC_URL")
    if rpcURL == "" {
        log.Fatal("ETH_RPC_URL environment variable not set")
    }

    client, err := chain.Connect(rpcURL)
    if err != nil {
        log.Fatalf("connecting to Ethereum: %v", err)
    }
    defer client.Close()

    fmt.Println("Connected to Ethereum.")

    if err := blocks.PrintLatestBlock(client); err != nil {
        log.Fatal(err)
    }

    // Print the block 3 blocks back (safer than latest which may be uncled)
    latestNum, _ := client.BlockNumber(context.Background())
    if err := blocks.PrintBlock(client, latestNum-3); err != nil {
        log.Fatal(err)
    }
}
```

Ask: "Why `-3` instead of latest?" (the latest block is sometimes reorganized — safer to use a block a few behind)

Ask: "What is `defer client.Close()` doing?" (runs at the end of main — closes the network connection cleanly)

---

## Checkpoint

1. "What is Alchemy and why are we using it instead of running our own node?"
2. "What does `context.Background()` mean?"
3. "What is a block hash?"
4. "What does `new(big.Int).SetUint64(n)` do? Why not just pass `n` directly?"
5. "What does the parent hash of block 19,000,000 point to?"

---

## Commit

```bash
git add .
git commit -m "Project 4 setup: connect to Ethereum, read blocks"
```
