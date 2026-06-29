# Lesson 44: Baby Blockchain — What We're Actually Building

**For Claude — do not show this file to the learner**

---

## Context for Claude

Project 7 is a working blockchain implementation in Go. NOT a toy — a real proof-of-work chain with blocks, hashing, mining, validation, wallets, and transactions. "Baby" means no networking (single node, no peers), but every other concept is real. This lesson sets the mental model before a line of code.

**This lesson's goal:**
- Understand what problem a blockchain actually solves
- Know what goes in a block (header fields)
- Understand SHA-256 and why it's used
- Understand proof-of-work intuitively
- Draw the chain structure from memory

---

## What problem does a blockchain solve?

"Forget the hype. At its core: how do you maintain a shared record that nobody controls, but everyone can trust?"

"Traditional database: one company runs it. You trust them not to lie. If they lie, you have no recourse."

"Blockchain: every participant has a copy. Every new entry is cryptographically linked to all previous entries. To change history, you'd have to redo all the work that came after it, faster than the rest of the network. In practice: impossible."

Ask: "If I give you a database with 1 million transactions and claim it's genuine — how would you verify it?" (you can't, unless you have the full history and the math checks out — that's the chain)

---

## What's in a block

"A block is a container with two parts: a header and a body."

**Block header:**
```
Index       — the block number (0 = genesis, 1 = first real block...)
PreviousHash — SHA-256 hash of the previous block's header
Timestamp    — when it was mined
Nonce        — a number we vary to make mining work (explained next)
Hash         — SHA-256 hash of THIS block's header (computed last)
```

**Block body:**
```
Transactions — the list of transactions in this block
```

"The crucial field: `PreviousHash`. Block 5's header contains a hash of block 4's header. Block 4's header contains a hash of block 3's. This is the chain."

Draw it:
```
Block 0 (Genesis)          Block 1                     Block 2
┌──────────────────┐       ┌──────────────────┐        ┌──────────────────┐
│ Index: 0         │       │ Index: 1         │        │ Index: 2         │
│ PrevHash: 000... │ ──→   │ PrevHash: a3f9.. │ ──→    │ PrevHash: 8b2c.. │
│ Timestamp: ...   │       │ Timestamp: ...   │        │ Timestamp: ...   │
│ Nonce: 0         │       │ Nonce: 84291     │        │ Nonce: 11043     │
│ Hash: a3f9...    │       │ Hash: 8b2c...    │        │ Hash: 5d71...    │
└──────────────────┘       └──────────────────┘        └──────────────────┘
```

Ask: "If someone changes a transaction in Block 1, what changes?" (the hash of Block 1 changes, which means Block 2's PreviousHash no longer matches — the chain breaks)
Ask: "What would they have to do to make the chain valid again?" (recompute Block 1, then Block 2, then Block 3... all of them, faster than the honest network is adding new blocks)

---

## SHA-256

"SHA-256 is a hash function. You give it any data — any size. It gives you back 256 bits (64 hex characters). Always."

Properties:
1. **Deterministic**: same input always → same output
2. **Fast to compute**: easy to go data → hash
3. **One-way**: impossible to go hash → data
4. **Avalanche effect**: change one bit of input → completely different hash
5. **Collision-resistant**: two different inputs producing the same hash — essentially impossible to find

"SHA-256 is the standard in crypto and security. Bitcoin uses it. TLS uses it. Git uses SHA-1 (older, similar)."

Have them test the avalanche effect:
```go
package main

import (
    "crypto/sha256"
    "fmt"
)

func main() {
    h1 := sha256.Sum256([]byte("hello"))
    h2 := sha256.Sum256([]byte("hello!"))
    fmt.Printf("%x\n", h1)
    fmt.Printf("%x\n", h2)
}
```

Ask: "How different are those two hashes despite inputs differing by one character?" (completely different — that's the avalanche effect)
Ask: "What would happen if SHA-256 DIDN'T have the avalanche effect?" (you could guess inputs by looking at how the hash changed — would be predictable and exploitable)

---

## Proof of Work

"Here's the problem: if creating a block is free, anyone can create millions of fake blocks instantly and rewrite history. We need block creation to be EXPENSIVE."

"Proof of Work is the solution: to create a valid block, you must find a hash that starts with N zeros. The only way to find it is brute force — try millions of nonces until one produces a hash with N leading zeros."

```
We want a hash starting with "0000":
nonce=0:     hash = 8f3a9c... (no)
nonce=1:     hash = b2e14f... (no)
nonce=...    ...
nonce=84291: hash = 00003a9b... (YES! Found it.)
```

"The number of zeros required = difficulty. More zeros = harder. Bitcoin currently requires ~19 leading zeros."

Ask: "What is the nonce?" (a number you change to get a different hash without changing the actual block data)
Ask: "If difficulty is 4 (four leading zeros), roughly how many tries does it take?" (1/16^4 = 1/65536 — about 65,000 tries on average)
Ask: "Why does this make fraud expensive?" (to rewrite block 1, you'd have to re-mine it AND all subsequent blocks. With enough miners working on the honest chain, you'd never catch up.)

---

## What we're NOT building (and why)

"Our blockchain:
- ✓ Blocks with hashing
- ✓ Proof of work
- ✓ Chain validation
- ✓ Transactions (simple account model)
- ✓ REST API to interact with it
- ✗ Peer-to-peer networking (no gossiping to other nodes)
- ✗ Mempool (transaction pool before mining)
- ✗ Merkle trees (we hash all transactions simply)
- ✗ UTXO model (we use accounts like Ethereum, not UTXOs like Bitcoin)"

"The networking and Merkle tree parts aren't Go fundamentals — they're distributed systems problems. Those matter, but they're their own project. What we're building gives you the full understanding of everything else."

---

## Checkpoint — no notes

1. "What is in a block header? Name all five fields."
2. "What is `PreviousHash` for? What breaks if you change it?"
3. "Name three properties of SHA-256."
4. "What is the nonce? Why do we need it?"
5. "Explain proof of work to me like I'm 10 years old."
6. "If difficulty is 3 (three leading zeros), how many hashes do you try on average?" (1/16^3 ≈ 4,096)

---

## Project setup — teach it

"New project. You know the steps. What's first?"

Walk them through it with questions only:
1. `mkdir ~/projects/blockchain && cd ~/projects/blockchain`
2. `go mod init blockchain`
3. No external dependencies for this project — pure stdlib. Ask: "Why no `go get` needed?" (SHA-256 is in `crypto/sha256`, HTTP in `net/http`, JSON in `encoding/json` — all standard library)

Directory structure — ask them to design it based on what you just described we're building:
```
blockchain/
  main.go            — starts the HTTP API
  block/
    block.go         — Block struct, Mine, computeHash
  chain/
    chain.go         — Chain struct, AddBlock, IsValid
  wallet/
    wallet.go        — key generation, signing, verification
  api/
    handlers.go      — REST endpoints
```

Ask: "Why separate `block/` and `chain/`?" (block knows about itself — computing its own hash. Chain knows about the sequence — validation, adding blocks. Single responsibility.)
Ask: "What does `main.go` do in this structure?" (creates the chain, sets up the HTTP server, wires up the API handlers — just wiring, no business logic)

## No code this lesson. No commit.
