# Lesson 45: Blocks, Hashing, and Mining

**For Claude — do not show this file to the learner**

---

## Context for Claude

They write the core data structures: Block, Transaction, Blockchain. Then implement hashing and proof-of-work mining. By end of this lesson they can mine their first block. Make them watch the nonce count up during mining — that moment of actually seeing it work is what makes it stick.

**This lesson's goal:**
- Define Block and Transaction structs
- Hash a block with SHA-256
- Implement proof-of-work mining
- Mine the genesis block and first real block
- Validate that the chain is intact

---

## Project setup

```bash
mkdir ~/projects/minichain
cd ~/projects/minichain
go mod init minichain
```

Structure:
```
minichain/
  chain/
    block.go       — Block struct and hashing
    blockchain.go  — Blockchain (the chain of blocks)
    transaction.go — Transaction struct
    mine.go        — proof-of-work mining
  api/
    server.go      — REST API to interact
  wallet/
    wallet.go      — key generation and signing
  main.go
```

---

## Transactions first

`chain/transaction.go`:

```go
package chain

import "time"

type Transaction struct {
    ID        string  `json:"id"`
    From      string  `json:"from"`   // sender address
    To        string  `json:"to"`     // recipient address
    Amount    float64 `json:"amount"` // in coins
    Timestamp int64   `json:"timestamp"`
}

func NewTransaction(from, to string, amount float64) Transaction {
    return Transaction{
        From:      from,
        To:        to,
        Amount:    amount,
        Timestamp: time.Now().UnixNano(),
    }
}
```

Ask: "Why is `Amount` a float64 and not an int?" (decimal coins — though in production you'd use a big.Int with fixed decimal places to avoid floating point issues; ask them why)
Ask: "What would go wrong with floating point for money?" (0.1 + 0.2 != 0.3 in float arithmetic — famous bug. Bitcoin uses satoshis (integers). ETH uses wei (integers).)
Ask: "What is `UnixNano`?" (nanoseconds since epoch — more precise than Unix() which is seconds. For a high-throughput chain, two transactions in the same second need to be distinguishable.)

---

## Block struct

`chain/block.go`:

```go
package chain

import (
    "crypto/sha256"
    "encoding/json"
    "fmt"
    "time"
)

type Block struct {
    Index        int           `json:"index"`
    PreviousHash string        `json:"previous_hash"`
    Timestamp    int64         `json:"timestamp"`
    Nonce        int           `json:"nonce"`
    Transactions []Transaction `json:"transactions"`
    Hash         string        `json:"hash"`
}

// computeHash generates the SHA-256 hash of this block's contents
func (b *Block) computeHash() string {
    // We serialize everything except the Hash field itself
    record := struct {
        Index        int           `json:"index"`
        PreviousHash string        `json:"previous_hash"`
        Timestamp    int64         `json:"timestamp"`
        Nonce        int           `json:"nonce"`
        Transactions []Transaction `json:"transactions"`
    }{
        Index:        b.Index,
        PreviousHash: b.PreviousHash,
        Timestamp:    b.Timestamp,
        Nonce:        b.Nonce,
        Transactions: b.Transactions,
    }

    data, _ := json.Marshal(record)
    hash := sha256.Sum256(data)
    return fmt.Sprintf("%x", hash)
}
```

Ask: "Why do we serialize to JSON before hashing?" (we need a deterministic byte representation of the block — JSON encoding of the same struct is always the same)
Ask: "Why is the Hash field excluded from what we hash?" (it would be circular — you can't include a hash in the data that produces that hash)
Ask: "What does `%x` format do?" (encodes bytes as hex — `[0xde 0xad 0xbe 0xef]` → `"deadbeef"`)

---

## Proof-of-work mining

`chain/mine.go`:

```go
package chain

import (
    "fmt"
    "strings"
    "time"
)

// Mine finds a nonce that makes the block hash start with `difficulty` zeros.
// It modifies the block in place and returns how long it took.
func Mine(block *Block, difficulty int) (int, time.Duration) {
    target := strings.Repeat("0", difficulty)
    start := time.Now()
    attempts := 0

    for {
        block.Nonce = attempts
        block.Hash = block.computeHash()

        if strings.HasPrefix(block.Hash, target) {
            return attempts, time.Since(start)
        }
        attempts++
    }
}
```

"Simple. Try nonce=0. Hash it. Does it start with enough zeros? No? Try nonce=1. Repeat until it does."

Ask: "This function runs forever until it finds a nonce. What guarantees it eventually finds one?" (SHA-256's output is effectively random and uniformly distributed — statistically, you will hit the target. With enough nonces, you'll always find one.)
Ask: "What would you change to make mining harder?" (increase `difficulty` — each extra zero multiplies expected attempts by 16)

Have them mine with difficulty=2 (fast), then difficulty=4 (takes a few seconds). Let them watch the nonce climb. Then:

```go
block := &chain.Block{
    Index:        1,
    PreviousHash: genesis.Hash,
    Timestamp:    time.Now().Unix(),
    Transactions: []chain.Transaction{
        chain.NewTransaction("alice", "bob", 50),
    },
}
attempts, duration := chain.Mine(block, 4)
fmt.Printf("Mined block! Nonce: %d, took %v, hash: %s\n", attempts, duration, block.Hash)
```

That moment when they see it print: "Block mined in 83,241 attempts (0.003s)" — let it land.

---

## The blockchain

`chain/blockchain.go`:

```go
package chain

import (
    "errors"
    "sync"
)

type Blockchain struct {
    mu     sync.RWMutex
    blocks []*Block
    difficulty int
}

func New(difficulty int) *Blockchain {
    bc := &Blockchain{difficulty: difficulty}
    bc.blocks = append(bc.blocks, bc.createGenesis())
    return bc
}

func (bc *Blockchain) createGenesis() *Block {
    genesis := &Block{
        Index:        0,
        PreviousHash: "0000000000000000000000000000000000000000000000000000000000000000",
        Timestamp:    0,
        Transactions: nil,
    }
    Mine(genesis, bc.difficulty)
    return genesis
}

func (bc *Blockchain) AddBlock(txns []Transaction) *Block {
    bc.mu.Lock()
    defer bc.mu.Unlock()

    last := bc.blocks[len(bc.blocks)-1]
    block := &Block{
        Index:        last.Index + 1,
        PreviousHash: last.Hash,
        Timestamp:    time.Now().Unix(),
        Transactions: txns,
    }
    Mine(block, bc.difficulty)
    bc.blocks = append(bc.blocks, block)
    return block
}

func (bc *Blockchain) Blocks() []*Block {
    bc.mu.RLock()
    defer bc.mu.RUnlock()
    return bc.blocks
}

func (bc *Blockchain) IsValid() error {
    bc.mu.RLock()
    defer bc.mu.RUnlock()

    for i := 1; i < len(bc.blocks); i++ {
        cur := bc.blocks[i]
        prev := bc.blocks[i-1]

        // Recompute hash and check it matches
        if cur.Hash != cur.computeHash() {
            return errors.New(fmt.Sprintf("block %d has invalid hash", i))
        }

        // Check the link to previous block
        if cur.PreviousHash != prev.Hash {
            return errors.New(fmt.Sprintf("block %d has wrong previous hash", i))
        }
    }
    return nil
}
```

Ask:
- "Why `sync.RWMutex` instead of `sync.Mutex`?" (RWMutex allows multiple concurrent reads — `RLock` for reads, `Lock` for writes. Better performance when reads are frequent.)
- "Why is `IsValid` important?" (before trusting any chain someone sends you, verify it — this is what nodes do when they receive a chain from a peer)
- "What is the genesis block's PreviousHash?" (all zeros — there is no previous block, so we use a known sentinel value)

---

## Tamper with a block and call IsValid

Have them:
1. Build a 3-block chain
2. Call `IsValid()` — should succeed
3. Directly modify a transaction in block 1: `bc.blocks[1].Transactions[0].Amount = 999999`
4. Call `IsValid()` again — should fail

This is the moment that proves immutability isn't magic — it's just math.

Ask: "What error did you get and why?" (block 1 has invalid hash — the hash stored in the block no longer matches a fresh recompute of its contents)

---

## Checkpoint

1. "Walk me through `computeHash()`. What data goes in? What comes out?"
2. "Why is the Hash field excluded from the hash computation?"
3. "Explain proof-of-work in one sentence."
4. "What would you change to make mining 16x harder?" (increment difficulty by 1)
5. "In `AddBlock`, what is `bc.mu.Lock()` protecting?" (the `bc.blocks` slice — if two goroutines called AddBlock simultaneously without the lock, they'd both read the same `last` block and produce two blocks with the same index)
6. "Tamper with a block manually and call IsValid. What breaks first?"

---

## Commit

```bash
git add .
git commit -m "Block hashing, proof-of-work mining, chain validation"
```
