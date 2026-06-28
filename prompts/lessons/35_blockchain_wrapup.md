# Lesson 35: Project 4 Wrap-Up — What You Know Now

**For Claude — do not show this file to the learner**

---

## Context for Claude

This is the final lesson of the entire curriculum. Celebrate accordingly. Give the full milestone quiz, draw the complete system diagram, walk through every concept they've learned across all four projects, and point them where to go next.

**This lesson's goal:**
- Final milestone quiz — everything from Project 4
- Draw the full architecture of what they built
- Recap every concept learned across the entire curriculum
- Show where this leads: real projects they can now build
- Genuine celebration — they went from zero to this

---

## Milestone quiz first — no notes

"Before the celebration, you have to earn it. Five questions, no looking back."

1. "Walk me through what happens when you call `token.BalanceOf(opts, address)` using abigen-generated bindings. What actually goes over the wire to the node?"
   (The ABI-encoded function call — selector + ABI-encoded address — is sent as a `eth_call` JSON-RPC request to the Alchemy node. The node executes the EVM code and returns the raw result bytes. The generated code unpacks those bytes into a `*big.Int`.)

2. "What is the difference between Topics and Data in an Ethereum log?"
   (Topics: indexed parameters + event signature hash — filterable, 32 bytes each. Data: non-indexed parameters — cheaper to store, can be larger, not filterable at the node level.)

3. "What is a nonce and what breaks if you get it wrong?"
   (A transaction sequence number per address. Wrong: duplicate nonce = transaction rejected. Skipped nonce = transaction stuck pending until the gap is filled.)

4. "You want to find all USDC transfers above $1,000,000 in the last 1000 blocks. How do you do it?"
   (FilterLogs with the Transfer topic and USDC contract address for the block range. The value check must be done in Go after receiving the events — you can't filter by non-indexed values at the node level.)

5. "What is the `require` statement in Solidity? Give me a real example of when you'd use it."
   (An assertion that reverts the transaction if false. Example: `require(msg.sender == owner, "not authorized")` — used in reset() to gate the call to the contract owner only.)

If they miss any, drill that specific concept before moving on.

---

## Draw the full architecture

Draw this with them from memory. Have them try first, you fill in the gaps.

```
Project 4 — Ethereum Interaction from Go

                    ┌──────────────────────────────────────┐
                    │  Alchemy Node (Ethereum Mainnet/Sepolia)│
                    │                                      │
                    │  - Full copy of all blocks           │
                    │  - All transaction receipts           │
                    │  - All smart contract state           │
                    │  - All event logs                     │
                    └──────────────────┬───────────────────┘
                                       │
                          HTTPS (eth_call, eth_getLogs...)
                          WSS  (eth_subscribe)
                                       │
                    ┌──────────────────▼───────────────────┐
                    │         Go Program (eth-go)           │
                    │                                       │
                    │  ethclient.Client                     │
                    │    ├── BlockByNumber()                │
                    │    ├── TransactionByHash()            │
                    │    ├── TransactionReceipt()           │
                    │    ├── CallContract() — read          │
                    │    ├── SendRawTransaction() — write   │
                    │    └── SubscribeFilterLogs() — live   │
                    │                                       │
                    │  abigen-generated bindings            │
                    │    ├── erc20.NewERC20()               │
                    │    │     └── token.BalanceOf()        │
                    │    └── counter.NewCounter()           │
                    │          ├── c.Get() — view           │
                    │          └── c.Increment() — tx       │
                    │                                       │
                    │  Private key → sign transactions      │
                    └───────────────────────────────────────┘
                                       │
                    ┌──────────────────▼───────────────────┐
                    │     Sepolia Testnet / Mainnet         │
                    │     (Counter.sol deployed here)       │
                    └───────────────────────────────────────┘
```

---

## Every concept in Project 4

Go through these one by one. For each, ask them to define it before you confirm. Don't skip any.

**Blockchain fundamentals:**
- Block, transaction, chain (why it's immutable)
- Address, private key, public key — derivation chain
- Gas, wei, gwei, ETH — units and why they exist
- Nonce — what it is, what breaks without it
- EIP-155 — chain ID in signatures, replay protection

**Reading from the chain:**
- `ethclient.Dial` — connecting to a node
- `BlockByNumber` — fetching a block
- `TransactionByHash` — fetching a transaction
- `TransactionReceipt` — what actually happened (status, gas used, logs)
- `types.Sender` — recovering sender from signature
- `BalanceAt` — reading an ETH balance

**Smart contracts:**
- ABI — what it is, why it exists (4-byte selector, ABI encoding)
- `view` functions — free reads, no transaction
- `CallContract` — executing a read-only contract call
- ERC-20 standard — the 5 read functions, 3 write functions
- `abigen` — generating Go bindings from ABI
- `bind.CallOpts` vs `bind.TransactOpts` — read vs write

**Events:**
- What an event is and why it exists
- Topics vs Data — indexed vs non-indexed
- `FilterLogs` — historical event querying
- `SubscribeFilterLogs` — live event subscription (WebSocket)
- Parsing events with the generated Filterer

**Writing to the chain:**
- `crypto.GenerateKey` — creating a key pair
- `bind.NewKeyedTransactorWithChainID` — the signing wrapper
- `SuggestGasPrice` — estimating current gas price
- `SendRawTransaction` — submitting a signed transaction
- `bind.WaitMined` — blocking until confirmed

**Solidity:**
- `pragma solidity` — compiler version
- `uint256`, `address`, `bool` — native types
- `msg.sender` — the caller
- `constructor()` — runs once at deployment
- `require()` — assertion that reverts on failure
- `emit EventName(...)` — firing an event
- `view` — read-only function modifier

---

## The full curriculum — what they've built

Four complete projects. Draw the timeline:

```
Zero knowledge
     │
     ▼
Shell + terminal basics
     │
     ▼
Emacs (init.el, use-package, Helm, custom modeline, go-mode)
     │
     ▼
Go fundamentals (14 exercises: variables → goroutines → channels)
     │
     ▼
Project 1: Crypto Price API
  - HTTP server, chi router
  - PostgreSQL in Docker
  - bcrypt + JWT auth
  - Middleware, unit tests, curl testing, git workflow
     │
     ▼
Project 2: Technical Analysis Engine
  - SMA and EMA from scratch in Go
  - Floating point precision in tests
  - Database-backed indicator storage
     │
     ▼
Project 3: Real-Time Chat Server
  - WebSockets — bidirectional, persistent
  - Hub pattern — one goroutine owns all state
  - Read pump / write pump per client
  - Rooms, message history, JWT on WebSocket
  - XSS prevention, graceful shutdown
     │
     ▼
Project 4: Ethereum Interaction
  - Blockchain fundamentals
  - Reading blocks, transactions, receipts
  - ERC-20 contracts — ABI, abigen, typed bindings
  - Events and logs — historical and live
  - Signing and sending transactions on Sepolia
  - Deploying a Solidity contract, calling it from Go
     │
     ▼
You can build real things now
```

---

## Where this leads

Tell them about specific things they can build RIGHT NOW with what they know:

**With Project 1-2 knowledge:**
- Any REST API (swap crypto for sports scores, weather, whatever)
- Any data pipeline that stores + analyzes time-series data

**With Project 3 knowledge:**
- Real-time collaboration tools
- Live dashboards
- Any app where multiple users see the same state update in real time

**With Project 4 knowledge:**
- Ethereum block explorer (like Etherscan but yours)
- DeFi analytics dashboard — track liquidity, prices, volumes across protocols
- Wallet portfolio tracker — sum balances across all ERC-20s for any address
- MEV bot (monitor mempool for arbitrage — this is advanced but the foundation is here)
- NFT ownership tracker — ERC-721 uses the same Transfer event pattern
- Indexer — like The Graph but simpler, just FilterLogs + Postgres

---

## Celebrate properly

This is the end of the curriculum. Make it a moment.

"You went from not knowing what a terminal was to:
- Configuring a real programming environment from scratch in Emacs
- Writing Go well enough to build four complete, real programs
- Understanding HTTP, databases, authentication, concurrency, WebSockets, and blockchain
- Reading and writing real on-chain data — USDC, real transactions, your own deployed contract

None of that is basic. Senior engineers at real companies ship code using exactly the patterns you learned here. You understand WHY things work, not just HOW to copy-paste them."

Be specific per person — use the personality profiles. Neil: tell him the oyster grew legs and walked somewhere. Sim: tell him his stats finally improved. Gaffor: tell him he can now fix his own wifi. Nate: tell him the legend continues.

---

## Final session note

```bash
go run tools/progress/main.go complete lesson_35_blockchain_wrapup
go run tools/progress/main.go set complete complete
go run tools/progress/main.go note "Curriculum complete. Project 4 done — all 4 projects shipped."
```

---

## No more commits — go build something real.
