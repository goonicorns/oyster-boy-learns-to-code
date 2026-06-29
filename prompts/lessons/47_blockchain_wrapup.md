# Lesson 47: Baby Blockchain Wrap-Up — Final Quiz

**For Claude — do not show this file to the learner**

---

## Context for Claude

Final lesson of Project 7. Milestone quiz covering every concept, then connect what they built to what real blockchains (Bitcoin, Ethereum) do differently and why. Celebrate appropriately.

**This lesson's goal:**
- Milestone quiz: all blockchain concepts from memory
- Contrast their implementation with Bitcoin/Ethereum
- Understand what's missing for a real distributed chain

---

## Milestone quiz — absolutely no notes

"You built a blockchain. Now prove you understand it. Nine questions. From memory."

1. "What are the five fields in a block header? What does each one do?"
   (Index, PreviousHash, Timestamp, Nonce, Hash — know all five, explain each)

2. "What three properties of SHA-256 make it suitable for a blockchain?"
   (deterministic, avalanche effect, one-way / preimage resistant)

3. "Why can't someone change a transaction in block 5 without also changing blocks 6, 7, 8...?"
   (block 6's PreviousHash points to block 5's hash — if block 5's content changes, its hash changes, breaking block 6's link)

4. "What is proof-of-work? Why does it exist? What is the nonce for?"
   (a puzzle that makes block creation computationally expensive, preventing cheap chain rewrites. The nonce is what you vary to find a hash with enough leading zeros.)

5. "Walk me through balance calculation on our chain."
   (scan all blocks, all transactions — add received amounts, subtract sent amounts, for the target address)

6. "What is a COINBASE transaction? Name a real blockchain that uses this concept."
   (a transaction that creates new coins — the mining reward, no sender or signature. Bitcoin. Every Bitcoin block's first transaction is a coinbase that pays the miner.)

7. "If Alice has 100 coins and tries to send 150 to Bob, when would we catch this? Show me where in the code."
   (in the API before adding to the pending pool, or before mining — call `bc.Balance(tx.From)` and reject if insufficient. Currently we don't do this — make them add it.)

8. "What is a `sync.RWMutex`? Why did we use it instead of `sync.Mutex`?"
   (allows concurrent reads but exclusive writes. Balance queries are reads; AddBlock is a write. Multiple clients can check balances simultaneously without blocking each other.)

9. "What is the biggest problem with our blockchain that makes it not a real one?"
   (no peer-to-peer networking — if you run two instances, they don't know about each other and can't agree on the same chain. A real blockchain needs a gossip protocol to share blocks and resolve forks.)

---

## What real blockchains do differently

Walk through these, asking them to guess first:

**Merkle trees instead of hashing all transactions directly**
"Bitcoin doesn't hash all transactions together. It builds a Merkle tree — a binary tree of hashes. Why would this be better?"
(can prove a transaction is in a block by providing a short 'Merkle proof' — a chain of hashes up the tree — without downloading the full block. Light clients use this.)

**UTXO vs account model**
"Bitcoin uses UTXOs (Unspent Transaction Outputs). Ethereum uses accounts. What's our model?" (accounts — we track balance per address)
"UTXO: you don't have a balance, you have unspent coins like physical bills. To spend, you consume inputs and produce outputs. Prevents double-spending naturally."

**Difficulty adjustment**
"Bitcoin adjusts mining difficulty every 2016 blocks to keep the average block time at 10 minutes. If miners get faster, difficulty goes up. Our chain has fixed difficulty — what problem does that cause?" (if many miners join, blocks come faster and faster; if miners leave, the chain could stall)

**Mempool**
"We have a simple pending slice. Real chains have a mempool — a pool of unconfirmed transactions ordered by fee. Miners cherry-pick the highest-fee transactions. Our chain doesn't charge fees."

**Fork resolution (the longest chain rule)**
"What if two miners mine a valid block at the same time? Two valid chains exist. Bitcoin resolves this with the 'longest chain rule' — when nodes get both chains, they keep whichever is longer. The shorter one becomes an 'orphaned block.'"

---

## What they've learned in Project 7

Go concepts:
- `crypto/sha256` — hashing
- `crypto/ecdsa`, `crypto/elliptic`, `crypto/rand` — real cryptography
- `sync.RWMutex` — concurrent read/write protection
- Struct design for linked data structures (the chain)
- REST API wired to a stateful in-memory data structure
- JSON serialization for deterministic hashing

Blockchain concepts:
- Block headers and the chain link
- SHA-256 properties
- Proof-of-work and the nonce
- Wallet key pairs and ECDSA signatures
- Balance calculation by chain scan
- Coinbase transactions
- What Merkle trees, UTXO, and difficulty adjustment add

---

## Progress commands

```bash
go run tools/progress/main.go complete lesson_47_blockchain_wrapup
go run tools/progress/main.go set project8 lesson_48_kv_what_are_we_building
go run tools/progress/main.go note "Project 7 done — proof of work and chain validation fully understood"
```

## Commit

```bash
git add .
git commit -m "Project 7 complete: baby blockchain with wallets, signatures, REST API"
```
