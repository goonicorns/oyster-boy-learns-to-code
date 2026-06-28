# Lesson 27: Blockchain — What It Actually Is

**For Claude — do not show this file to the learner**

---

## Context for Claude

This is the start of Project 4: Ethereum smart contract interaction from Go. Before a single line of code, the learner needs a rock-solid mental model of what a blockchain is. Most people have heard the word and vaguely associate it with Bitcoin or scams. That surface-level knowledge will get in the way. Clear it out. Build from scratch.

**This lesson's goal:**
- Understand what a block, a chain, and a transaction actually are
- Understand what an address and a private key are — and the relationship between them
- Understand what gas is and why it exists
- Understand what a smart contract is at the conceptual level
- Know what "on-chain" vs "off-chain" means

No code this lesson. Mental model only. If they can't answer the checkpoint questions at the end, they are not ready for lesson 28.

---

## Start with the database analogy

"You've built APIs. You've used Postgres. You understand that a database stores state — balances, user accounts, whatever. A blockchain is also a database. But it has two unusual properties. What do you think makes a database 'trustworthy'?"

Let them think. They'll probably say "it doesn't lose data", "it's backed up", etc. Push further: "What if the company running the database lies to you? What if they change a number and you'd never know?"

"That's the actual problem blockchains solve. A blockchain is a database where no single party can change history without everyone else noticing. Here's how."

---

## What a block is

"Instead of storing data in rows and tables, a blockchain stores data in blocks. A block is a batch of transactions — maybe a few thousand — bundled together and timestamped. Every ~12 seconds on Ethereum, a new block gets added to the chain."

"Each block contains:
- A list of transactions
- A timestamp
- A reference to the previous block (a 'hash' of it — a fingerprint)
- Some metadata"

"That reference to the previous block is what makes it a 'chain.' Each block points back to the one before it. If you tried to change an old block — even one character — its fingerprint would change. That would break the reference from the next block. And the one after that. You'd have to re-do the entire chain from that point. With thousands of computers all checking each other, that's practically impossible to fake."

Ask: "So if a transaction was included in a block 1,000 blocks ago, what would have to happen for someone to erase it?"

Guide toward: they'd have to recompute 1,000 blocks faster than the rest of the network. In practice: can't be done. This is what "immutable" means.

---

## What a transaction is

"A transaction is a signed instruction to change state. 'Move 1 ETH from address A to address B.' That's it. Ethereum is a giant state machine. Its state is: who owns what. Transactions change that state."

"Every transaction has:
- `from`: who's sending it (an address)
- `to`: who's receiving it (an address, or a smart contract)
- `value`: how much ETH to send (can be 0)
- `data`: optional — used when calling a smart contract function
- `gasLimit`: max gas willing to pay
- `gasPrice`: how much to pay per unit of gas
- `nonce`: a sequence number (prevents replaying the same transaction twice)
- `signature`: cryptographic proof that the `from` address authorized this"

Ask them: "What's a nonce?" (a counter that increases for each transaction from a given address — so you can't resubmit the same transaction twice).

---

## Addresses and private keys

"An Ethereum address is a public identifier — like an email address. Anyone can send you ETH at your address. You don't keep it secret."

"A private key is a secret number — 256 bits, totally random. You use it to sign transactions. The signature proves you authorized the transaction without revealing the private key."

"The relationship: your address is derived from your public key, which is derived from your private key. It's a one-way function. Given the private key, you can compute the address. Given the address, you can't reverse-engineer the private key."

Draw it:
```
private key (secret, 32 bytes)
    ↓  (elliptic curve math, one-way)
public key (64 bytes)
    ↓  (keccak256 hash, take last 20 bytes)
address (20 bytes, shown as hex: 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045)
```

"If you lose your private key, you lose access to everything at that address. There's no 'forgot password.' The blockchain doesn't know who you are — it only knows that whoever signed this transaction had the right key."

Ask: "Why can't Ethereum just let you reset your private key?" (because no central authority exists to authorize the reset — that's the whole point)

---

## Gas

"Every operation on Ethereum costs gas. Simple ETH transfer: 21,000 gas. Calling a smart contract function: more, depending on how much computation it does."

"Gas prevents spam. If computation were free, someone could run an infinite loop and grind the whole network to a halt. Gas makes computation metered. The more your program does, the more it costs."

"You pay gas in ETH. The price is `gasPrice * gasUsed`. If you set your gasPrice too low, miners/validators deprioritize your transaction. If you set it too high, you overpay but get in faster."

"Since EIP-1559 (2021), there's a `baseFee` that the network sets automatically based on demand, plus a `priorityFee` (tip) you set. The baseFee gets burned — destroyed. The tip goes to the validator."

Ask: "If gas prices spike to 200 gwei and your transaction only has gasPrice set to 10 gwei, what happens?" (it sits in the mempool, unconfirmed, until gas drops or you cancel it)

---

## Smart contracts

"A smart contract is a program that lives at an Ethereum address. Instead of a person or company controlling that address, a program controls it. The program is stored on-chain and runs on every node."

"When you send a transaction to a smart contract address, you're calling a function in that program. The transaction's `data` field contains: which function to call, and what arguments to pass."

"Smart contracts can:
- Store data (like a database)
- Receive and send ETH
- Call other smart contracts
- Emit events (logs)"

"Smart contracts cannot:
- Make HTTP requests
- Read from the internet
- Know what time it is (without an oracle)
- Be changed once deployed"

"That last one is important. Smart contracts are immutable. Once deployed, the code doesn't change. This is a feature (trustworthy) and a bug (can't fix mistakes)."

Ask: "Why would immutability be considered a feature for financial contracts?" (you can audit the exact code that's running; no one can change the rules on you later)

Ask: "If there's a bug in a smart contract, what happens?" (it's there forever. Real money has been lost this way. Auditing matters enormously.)

---

## On-chain vs off-chain

"On-chain means stored or computed on the blockchain. Every node stores it. It costs gas. It's permanent."

"Off-chain means everything else — your server, a database, an API. Cheaper, faster, not immutable."

"Most real applications are hybrid: the smart contract handles the trust-critical parts (ownership, balances, rules), and off-chain infrastructure handles everything else (UI, price feeds, historical queries)."

"Our project will be entirely off-chain Go code that TALKS to the blockchain via an API. We don't change any state — we read and observe. This is how analytics tools, explorers like Etherscan, and trading bots work."

---

## Checkpoint — do not proceed until all of these are answered from memory

1. "What's the difference between a block and a transaction?"
2. "Why can't someone go back and change a transaction from 2 years ago?"
3. "What's the relationship between a private key and an address?"
4. "What is gas and why does it exist?"
5. "What can a smart contract NOT do that a regular server can?"
6. "What does 'on-chain' mean vs 'off-chain'?"

---

## No code this lesson. No commit.

Next lesson: set up the project, connect to Ethereum via Alchemy, read your first block.
