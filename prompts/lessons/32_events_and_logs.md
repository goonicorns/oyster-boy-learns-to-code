# Lesson 32: Events and Logs — Watching What Happens On-Chain

**For Claude — do not show this file to the learner**

---

## Context for Claude

Events are how smart contracts tell the outside world that something happened. They're the closest thing Ethereum has to a notification system. This lesson: understand what events are, how logs are stored, then filter and parse Transfer events from USDC — which fires thousands of them per hour.

**This lesson's goal:**
- Understand what Ethereum events/logs are and why they exist
- Understand how logs are stored (topics vs data, indexed vs non-indexed)
- Filter logs with `FilterLogs` for a range of blocks
- Parse the raw log bytes using the generated ABI bindings
- Subscribe to live events with `SubscribeFilterLogs` (websocket)

---

## What are events?

"Smart contracts can't send notifications. They can't call your API. They can't send an email. How does your off-chain code know when something happened on-chain?"

"Events. When a contract executes, it can emit events — entries in a special log attached to the transaction receipt. Events are:
- Cheap to write (much cheaper than storing in contract state)
- Permanent (stored on every node forever)
- Queryable (you can filter by contract address, event type, indexed parameters)"

"The ERC-20 standard requires two events:
- `Transfer(address indexed from, address indexed to, uint256 value)` — emitted on every token transfer
- `Approval(address indexed owner, address indexed spender, uint256 value)` — emitted on approve()"

"Every time someone sends USDC, a Transfer event is emitted. USDC processes millions of transfers. All of those are queryable from Go."

---

## How logs are stored — topics and data

"A log entry has two parts:
- `Topics`: up to 4 values, each 32 bytes. The first topic is ALWAYS the event signature hash. Indexed parameters go here.
- `Data`: everything else — non-indexed parameters, ABI-encoded."

"For Transfer(from indexed, to indexed, value NOT indexed):
```
Topics[0]: keccak256('Transfer(address,address,uint256)') — the event signature
Topics[1]: from address (padded to 32 bytes)
Topics[2]: to address (padded to 32 bytes)
Data:      value (ABI-encoded uint256)
```"

Ask: "Why are some parameters indexed and others not?"
Guide toward: indexed parameters go into topics and can be filtered efficiently (the node can skip blocks without a matching topic). Non-indexed parameters go into data — you have to read and decode them, but they're cheaper to store and can be bigger.

Ask: "If you wanted to find all USDC transfers TO a specific address, which field would you filter on?" (Topics[2] — the `to` address is indexed)

---

## FilterLogs — read historical events

"Let's find every USDC Transfer in the last 100 blocks."

```go
package events

import (
    "context"
    "fmt"
    "math/big"

    "github.com/ethereum/go-ethereum"
    "github.com/ethereum/go-ethereum/common"
    "github.com/ethereum/go-ethereum/crypto"
    "github.com/ethereum/go-ethereum/ethclient"

    "eth-go/contracts/erc20"
)

var (
    usdcAddress   = common.HexToAddress("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")
    // keccak256 of "Transfer(address,address,uint256)"
    transferTopic = crypto.Keccak256Hash([]byte("Transfer(address,address,uint256)"))
)

func PrintRecentTransfers(client *ethclient.Client, numBlocks uint64) error {
    ctx := context.Background()

    latest, err := client.BlockNumber(ctx)
    if err != nil {
        return fmt.Errorf("getting block number: %w", err)
    }

    fromBlock := latest - numBlocks

    query := ethereum.FilterQuery{
        FromBlock: new(big.Int).SetUint64(fromBlock),
        ToBlock:   new(big.Int).SetUint64(latest),
        Addresses: []common.Address{usdcAddress},
        Topics:    [][]common.Hash{{transferTopic}},
    }

    logs, err := client.FilterLogs(ctx, query)
    if err != nil {
        return fmt.Errorf("filtering logs: %w", err)
    }

    // Use abigen-generated ABI to parse logs
    contractABI, err := erc20.ERC20MetaData.GetAbi()
    if err != nil {
        return fmt.Errorf("getting ABI: %w", err)
    }

    fmt.Printf("Found %d USDC Transfer events in blocks %d–%d\n\n",
        len(logs), fromBlock, latest)

    for _, log := range logs[:min(10, len(logs))] {
        // Unpack the Transfer event
        event := struct {
            From  common.Address
            To    common.Address
            Value *big.Int
        }{}

        // Indexed fields come from Topics
        event.From = common.HexToAddress(log.Topics[1].Hex())
        event.To = common.HexToAddress(log.Topics[2].Hex())

        // Non-indexed fields come from Data
        if err := contractABI.UnpackIntoInterface(&event, "Transfer", log.Data); err != nil {
            return fmt.Errorf("unpacking transfer: %w", err)
        }

        // USDC has 6 decimals
        divisor := new(big.Float).SetInt(new(big.Int).Exp(big.NewInt(10), big.NewInt(6), nil))
        amount := new(big.Float).Quo(new(big.Float).SetInt(event.Value), divisor)

        fmt.Printf("Block %d: %s → %s  %.2f USDC\n",
            log.BlockNumber,
            event.From.Hex()[:10]+"...",
            event.To.Hex()[:10]+"...",
            amount)
    }
    return nil
}

func min(a, b int) int {
    if a < b {
        return a
    }
    return b
}
```

Walk through the FilterQuery:
- "What does `Addresses` do?" (only return logs from this contract — without it you'd get logs from every contract on chain)
- "What does `Topics[0]` filter on?" (only return logs whose first topic matches — i.e., only Transfer events, not Approval)
- "What if we wanted only transfers TO a specific address?" (add that address to `Topics[2]` — `[][]common.Hash{{transferTopic}, {}, {targetAddr.Hash()}}`)
- "Why do we slice `logs[:min(10, len(logs))]`?" (100 blocks of USDC can have thousands of transfers — we just print 10 for demo)

Run it. Let them see real USDC transfers scroll past.

---

## Parse using the abigen event struct

"The abigen tool also generates typed event parsing. Let's use that instead of manually splitting topics and data."

```go
func PrintTransfersParsed(client *ethclient.Client, numBlocks uint64) error {
    ctx := context.Background()
    latest, _ := client.BlockNumber(ctx)
    fromBlock := latest - numBlocks

    query := ethereum.FilterQuery{
        FromBlock: new(big.Int).SetUint64(fromBlock),
        ToBlock:   new(big.Int).SetUint64(latest),
        Addresses: []common.Address{usdcAddress},
        Topics:    [][]common.Hash{{transferTopic}},
    }

    logs, err := client.FilterLogs(ctx, query)
    if err != nil {
        return err
    }

    // abigen generated a filterer — use it
    filterer, err := erc20.NewERC20Filterer(usdcAddress, nil)
    if err != nil {
        return err
    }

    var totalValue big.Float
    divisor := new(big.Float).SetInt(new(big.Int).Exp(big.NewInt(10), big.NewInt(6), nil))

    for _, log := range logs {
        transfer, err := filterer.ParseTransfer(log)
        if err != nil {
            continue
        }
        v := new(big.Float).Quo(new(big.Float).SetInt(transfer.Value), divisor)
        totalValue.Add(&totalValue, v)
    }

    fmt.Printf("Total USDC transferred in %d blocks: %.2f USDC\n", numBlocks, &totalValue)
    fmt.Printf("Across %d transfers\n", len(logs))
    return nil
}
```

"The `filterer.ParseTransfer(log)` call does all the topic/data splitting for you. `transfer.From`, `transfer.To`, `transfer.Value` — all typed."

Ask: "What does the total USDC volume number tell you about the 100 blocks?" (billions of dollars move through USDC constantly — they're reading real financial data)

---

## Subscribe to live events (websocket)

"FilterLogs queries the past. To watch events as they happen, you subscribe. This requires a WebSocket connection, not HTTP."

"When you created your Alchemy app, there's also a WebSocket URL — `wss://eth-mainnet.g.alchemy.com/v2/YOUR_KEY`"

```go
func WatchTransfers(wsURL string) error {
    ctx := context.Background()

    // Must use WebSocket client for subscriptions
    client, err := ethclient.Dial(wsURL)
    if err != nil {
        return fmt.Errorf("connecting via ws: %w", err)
    }
    defer client.Close()

    query := ethereum.FilterQuery{
        Addresses: []common.Address{usdcAddress},
        Topics:    [][]common.Hash{{transferTopic}},
    }

    logsCh := make(chan types.Log)
    sub, err := client.SubscribeFilterLogs(ctx, query, logsCh)
    if err != nil {
        return fmt.Errorf("subscribing: %w", err)
    }
    defer sub.Unsubscribe()

    filterer, _ := erc20.NewERC20Filterer(usdcAddress, nil)
    divisor := new(big.Float).SetInt(new(big.Int).Exp(big.NewInt(10), big.NewInt(6), nil))

    fmt.Println("Watching USDC transfers (Ctrl+C to stop)...")
    for {
        select {
        case err := <-sub.Err():
            return fmt.Errorf("subscription error: %w", err)
        case log := <-logsCh:
            transfer, err := filterer.ParseTransfer(log)
            if err != nil {
                continue
            }
            amount := new(big.Float).Quo(new(big.Float).SetInt(transfer.Value), divisor)
            fmt.Printf("%.2f USDC  %s → %s\n",
                amount,
                transfer.From.Hex()[:10]+"...",
                transfer.To.Hex()[:10]+"...")
        }
    }
}
```

Run it. Let them watch live USDC transfers print in their terminal in real time.

This is the moment. Let it breathe. Don't move on too fast. Ask: "What's actually happening right now as these print?" (people moving USDC around the world in real time, visible to anyone with a node connection)

Tie it back to WebSockets: "Sound familiar? `SubscribeFilterLogs` is a WebSocket subscription — the node pushes events to us. We learned the same pattern in the chat server."

---

## Checkpoint

1. "What is an Ethereum event?"
2. "What's the difference between an indexed and a non-indexed parameter in an event?"
3. "What is Topics[0] always?" (the keccak256 hash of the event signature)
4. "Why does `SubscribeFilterLogs` need a WebSocket URL instead of HTTP?"
5. "How would you filter for USDC transfers above 1,000,000 USDC?" (trick question — you can't filter by value on-chain since `value` is non-indexed; you filter client-side after receiving all transfers)
6. "Where do we know goroutines and channels from, in what we're doing now?" (the subscription loop uses channels — `logsCh` is a Go channel, same as everything in the chat server)

---

## Commit

```bash
git add .
git commit -m "Filter and subscribe to ERC-20 Transfer events"
```
