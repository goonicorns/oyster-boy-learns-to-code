# Lesson 34: Deploy a Contract, Own It From Go

**For Claude — do not show this file to the learner**

---

## Context for Claude

They've read from existing contracts and sent ETH. Now they close the loop: write a tiny smart contract in Solidity, deploy it to Sepolia via Remix (no toolchain needed), generate Go bindings with abigen, and call their OWN contract from Go. This is the moment everything connects — they wrote it, they deployed it, they're talking to it.

**This lesson's goal:**
- Write a minimal Solidity contract (a counter with get/increment/reset)
- Deploy it to Sepolia via Remix (browser IDE, zero setup)
- Copy the ABI from Remix and run abigen
- Call their contract's functions from Go
- Understand what "ownable" means and write a basic access check

Keep Solidity very brief — one lesson, just enough to understand what a contract looks like. They're not becoming Solidity developers. The point is to understand what Go is talking TO.

---

## Write the contract in Remix

"Open remix.ethereum.org in your browser. This is a browser-based Solidity IDE — no installation, just works."

Have them create a new file called `Counter.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Counter {
    uint256 private count;
    address public owner;

    event CountIncremented(address indexed by, uint256 newCount);
    event CountReset(address indexed by);

    constructor() {
        owner = msg.sender;  // whoever deploys the contract is the owner
        count = 0;
    }

    function increment() public {
        count += 1;
        emit CountIncremented(msg.sender, count);
    }

    function reset() public {
        require(msg.sender == owner, "only owner can reset");
        count = 0;
        emit CountReset(msg.sender);
    }

    function get() public view returns (uint256) {
        return count;
    }
}
```

Walk through every line with questions:

- "What is `pragma solidity ^0.8.0`?" (specifies which version of the Solidity compiler to use — `^` means 0.8.x or higher but less than 0.9)
- "What is `uint256`?" (an unsigned 256-bit integer — the native integer type in Solidity, matches Ethereum's word size)
- "What is `address`?" (a 20-byte Ethereum address — a first-class type in Solidity)
- "What is `msg.sender`?" (the address that sent the current transaction — the caller. It's a global variable in Solidity, always available.)
- "What does `private` mean for `count`?" (not directly readable from outside the contract — you'd need a getter function. Note: it's NOT actually secret on-chain; anyone can read raw storage.)
- "What does `public` mean for `owner`?" (Solidity auto-generates a getter — callers can read `owner` directly without you writing a function)
- "What is `constructor()`?" (runs exactly once when the contract is deployed — like main() but only at deployment time)
- "What does `require(msg.sender == owner, "...")` do?" (it's an assertion — if the condition is false, the transaction reverts with the error message and no state changes are kept)
- "What does `emit CountIncremented(...)` do?" (fires the event — this is what we'd see in FilterLogs from Go)
- "What does `view` mean on `get()`?" (it doesn't modify state — can be called for free without a transaction)

Ask: "Which functions require a transaction and which don't?" (`increment` and `reset` modify state → transactions needed; `get` is view → free call)

---

## Deploy via Remix

1. In Remix, click the Solidity compiler icon → click "Compile Counter.sol"
2. Click the Deploy & Run icon
3. Change environment to "Injected Provider - MetaMask" (if they have MetaMask) OR "WalletConnect"
4. If no wallet: use "Remix VM (Sepolia)" — a built-in simulator. Good enough for seeing it work, but they won't get a real Sepolia address to query from Go. Recommend they install MetaMask quickly if they haven't.
5. Make sure they're on Sepolia network in MetaMask
6. Click "Deploy" — MetaMask will ask to confirm

"After deployment, Remix shows the contract address. Copy it. Also copy the ABI — in the compiler tab, there's an 'ABI' button that copies the JSON."

Save the ABI to `contracts/counter/counter.abi`.

---

## Generate bindings

```bash
abigen --abi=contracts/counter/counter.abi --pkg=counter --out=contracts/counter/counter.go
```

Open the generated file. Ask:
- "Find the `Increment` method in the generated code. What does it take as arguments?" (`*bind.TransactOpts` — because it's a state-changing function that needs a signed transaction)
- "Find the `Get` method. What does it take?" (`*bind.CallOpts` — because it's a view function, read-only)
- "Find the `CountIncrementedIterator`. What's that?" (the generated event filter/parser for the CountIncremented event — same pattern as ERC-20 Transfer)

This is the key insight: `CallOpts` vs `TransactOpts` in generated code tells you whether a function costs gas or not.

---

## Call the contract from Go

`contracts/counter/interact.go`:

```go
package counter

import (
    "context"
    "crypto/ecdsa"
    "fmt"
    "math/big"

    "github.com/ethereum/go-ethereum/accounts/abi/bind"
    "github.com/ethereum/go-ethereum/common"
    "github.com/ethereum/go-ethereum/ethclient"
)

func InteractWithCounter(
    client *ethclient.Client,
    privateKey *ecdsa.PrivateKey,
    contractAddr string,
) error {
    ctx := context.Background()
    addr := common.HexToAddress(contractAddr)

    // Bind the contract
    c, err := NewCounter(addr, client)
    if err != nil {
        return fmt.Errorf("binding counter: %w", err)
    }

    // Read-only: get current count
    count, err := c.Get(&bind.CallOpts{Context: ctx})
    if err != nil {
        return fmt.Errorf("get: %w", err)
    }
    fmt.Printf("Current count: %s\n", count)

    // Read-only: get owner
    owner, err := c.Owner(&bind.CallOpts{Context: ctx})
    if err != nil {
        return fmt.Errorf("owner: %w", err)
    }
    fmt.Printf("Owner: %s\n", owner.Hex())

    // Build TransactOpts to sign a transaction
    chainID, err := client.NetworkID(ctx)
    if err != nil {
        return fmt.Errorf("chain ID: %w", err)
    }
    auth, err := bind.NewKeyedTransactorWithChainID(privateKey, chainID)
    if err != nil {
        return fmt.Errorf("creating transactor: %w", err)
    }
    auth.GasLimit = 100000 // generous limit for a simple counter call

    // Send increment() transaction
    tx, err := c.Increment(auth)
    if err != nil {
        return fmt.Errorf("increment: %w", err)
    }
    fmt.Printf("Increment tx: %s\n", tx.Hash().Hex())

    // Wait for it to be mined
    receipt, err := bind.WaitMined(ctx, client, tx)
    if err != nil {
        return fmt.Errorf("waiting: %w", err)
    }
    fmt.Printf("Mined in block %d, status: %d\n", receipt.BlockNumber, receipt.Status)

    // Read count again
    count, _ = c.Get(&bind.CallOpts{Context: ctx})
    fmt.Printf("Count after increment: %s\n", count)

    return nil
}
```

Walk through:
- "What is `bind.NewKeyedTransactorWithChainID`?" (creates an object that will sign transactions with your private key — you hand it to any state-changing method)
- "What is `bind.WaitMined`?" (polls the node until the transaction appears in a block — blocks the goroutine until confirmed)
- "What happens if we call `c.Reset(auth)` from a different address than the owner?" (the transaction succeeds at the Go level — it's sent — but the EVM reverts it and receipt.Status will be 0)

Have them call Reset from a different key to see it fail. This is important: failure at the EVM level vs failure at the Go/network level are two different things.

---

## Watch the events

```go
func ReadCounterEvents(client *ethclient.Client, contractAddr string, fromBlock uint64) error {
    ctx := context.Background()
    addr := common.HexToAddress(contractAddr)

    filterer, err := NewCounterFilterer(addr, client)
    if err != nil {
        return err
    }

    opts := &bind.FilterOpts{
        Start:   fromBlock,
        Context: ctx,
    }

    iter, err := filterer.FilterCountIncremented(opts, nil) // nil = any address
    if err != nil {
        return err
    }
    defer iter.Close()

    for iter.Next() {
        evt := iter.Event
        fmt.Printf("Block %d: counter incremented by %s, new count: %s\n",
            evt.Raw.BlockNumber,
            evt.By.Hex(),
            evt.NewCount)
    }
    return iter.Error()
}
```

"Every time they called `Increment` in Go, a `CountIncremented` event fired. This function reads them all back — the complete history of who incremented the counter and when."

Ask: "Why can we trust this history?" (it's on Sepolia — immutable, every node agrees on it)

---

## Checkpoint

1. "What does `msg.sender` mean in Solidity?"
2. "What does `require` do? What happens if it fails?"
3. "What's the difference between `CallOpts` and `TransactOpts` in generated bindings?"
4. "If you call `reset()` from an address that isn't the owner, what happens at the EVM level? What does the receipt show?"
5. "How would you read the complete history of all increments from this contract?"
6. "What would you change in the contract to allow ANYONE to reset, not just the owner?" (remove the `require`)

---

## Commit

```bash
git add .
git commit -m "Deploy Counter contract to Sepolia, interact from Go"
```
