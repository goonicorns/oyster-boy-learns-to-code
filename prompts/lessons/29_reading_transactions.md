# Lesson 29: Transactions — Reading What Actually Happened

**For Claude — do not show this file to the learner**

---

## Context for Claude

They can read blocks. Now they go deeper: individual transactions. This lesson is about reading and decoding real transactions — ETH transfers and simple contract calls. The main concepts are: transaction hash as an ID, `TransactionByHash` vs `TransactionReceipt`, and how to read value/gas/from/to.

**This lesson's goal:**
- Fetch a transaction by its hash
- Read all its fields: from, to, value, gas, nonce, data
- Understand the difference between a pending transaction and a mined receipt
- Read the receipt: gas used, status (success/failure), logs
- Iterate a block's transactions and print a summary

---

## Transaction hash as a unique ID

"Every transaction gets a unique ID: its hash. On Etherscan, everything links to a tx hash. It's 32 bytes, shown as 64 hex characters starting with 0x."

"Find a transaction hash on Etherscan — any recent one. We're going to read it from Go."

Give them a well-known transaction to start with — a simple ETH transfer. You can look up any recent one on etherscan.io. Pick something with a large ETH value so it's obviously interesting.

---

## TransactionByHash

```go
package txns

import (
    "context"
    "fmt"
    "math/big"

    "github.com/ethereum/go-ethereum/common"
    "github.com/ethereum/go-ethereum/ethclient"
)

func PrintTransaction(client *ethclient.Client, txHashHex string) error {
    ctx := context.Background()

    txHash := common.HexToHash(txHashHex)

    tx, isPending, err := client.TransactionByHash(ctx, txHash)
    if err != nil {
        return fmt.Errorf("fetching transaction: %w", err)
    }

    fmt.Printf("Hash:      %s\n", tx.Hash().Hex())
    fmt.Printf("Pending:   %v\n", isPending)
    fmt.Printf("To:        %s\n", tx.To().Hex())
    fmt.Printf("Value:     %s wei\n", tx.Value().String())
    fmt.Printf("Gas limit: %d\n", tx.Gas())
    fmt.Printf("Gas price: %s gwei\n", weiToGwei(tx.GasPrice()))
    fmt.Printf("Nonce:     %d\n", tx.Nonce())
    fmt.Printf("Data:      %x\n", tx.Data())

    return nil
}

func weiToGwei(wei *big.Int) string {
    gwei := new(big.Float).Quo(
        new(big.Float).SetInt(wei),
        big.NewFloat(1e9),
    )
    return gwei.Text('f', 2)
}
```

Ask:
- "What is `common.HexToHash`?" (converts the hex string to a 32-byte Hash type)
- "What does `isPending` mean?" (the transaction was submitted but not yet included in a block — its data is preliminary)
- "The value is in wei. What is wei?" (the smallest unit of ETH — 1 ETH = 1,000,000,000,000,000,000 wei = 1e18 wei)
- "What is the `Data` field for an ETH transfer?" (empty — data is only used when calling smart contract functions)
- "What's the nonce here?" (tell them to look it up: it's the number of transactions the sender has ever sent — this was their Nth transaction)

---

## Wei, Gwei, ETH — units

Drill this. They will get confused.

```
1 ETH = 1,000,000,000 Gwei (1e9)
1 ETH = 1,000,000,000,000,000,000 wei (1e18)
1 Gwei = 1,000,000,000 wei (1e9)
```

"Gas prices are quoted in Gwei. Token amounts are stored in wei. ETH is what humans say. You'll be converting constantly."

Ask: "If a transaction transfers 2.5 ETH, what number does `tx.Value()` return?" (2,500,000,000,000,000,000 — 2.5 × 1e18)

Ask: "Write me a `weiToEth` function." (same pattern as weiToGwei but divide by 1e18)

---

## The missing piece: who sent it?

"Notice we can get `tx.To()` — the recipient. But where is the sender? `tx.From()` doesn't exist."

"Why? Because the sender is cryptographically derived from the signature. The transaction data is signed, and from the signature + the transaction, you can mathematically recover who signed it. go-ethereum makes you do this explicitly."

```go
import "github.com/ethereum/go-ethereum/core/types"

// To recover the sender, you need to know what signing rules (signer) to use.
// EIP-155 is the standard since 2016 — it prevents replay attacks across chains.
chainID := big.NewInt(1) // 1 = Ethereum mainnet
signer := types.NewLondonSigner(chainID)

from, err := types.Sender(signer, tx)
if err != nil {
    return fmt.Errorf("recovering sender: %w", err)
}
fmt.Printf("From: %s\n", from.Hex())
```

Ask: "What is EIP-155?" (a proposal that added the chain ID to transaction signatures — without it, a transaction signed for Ethereum could be replayed on another chain like BSC)

Ask: "What does 'recovering' the sender mean?" (using the ECDSA signature math to derive the public key, then the address — you don't store the sender explicitly in the transaction)

---

## TransactionReceipt — what actually happened

"A transaction is a request. A receipt is what actually happened after it was mined."

"The receipt contains:
- `Status`: 1 = success, 0 = failed (the transaction was included but the code reverted)
- `GasUsed`: how much gas was actually consumed (vs the limit)
- `Logs`: events emitted by smart contracts during this transaction
- `ContractAddress`: if this transaction deployed a new contract, its address is here"

```go
func PrintReceipt(client *ethclient.Client, txHashHex string) error {
    ctx := context.Background()
    txHash := common.HexToHash(txHashHex)

    receipt, err := client.TransactionReceipt(ctx, txHash)
    if err != nil {
        return fmt.Errorf("fetching receipt: %w", err)
    }

    fmt.Printf("Status:          %d (1=success, 0=failed)\n", receipt.Status)
    fmt.Printf("Gas used:        %d\n", receipt.GasUsed)
    fmt.Printf("Block number:    %d\n", receipt.BlockNumber)
    fmt.Printf("Block hash:      %s\n", receipt.BlockHash.Hex())
    fmt.Printf("Logs emitted:    %d\n", len(receipt.Logs))

    return nil
}
```

Ask: "Can a failed transaction still cost gas?" (YES — this is important. The transaction is included in the block, gas is consumed for the computation that was done before the revert. You always pay.)

Ask: "What does it mean if a transaction has status=0?" (it reverted — the smart contract threw an error. But the transaction WAS processed; it just didn't change state the way the sender wanted.)

---

## Iterate a block's transactions

"Let's tie it together. Print a summary of every transaction in a block."

```go
func SummarizeBlock(client *ethclient.Client, blockNumber uint64) error {
    ctx := context.Background()

    block, err := client.BlockByNumber(ctx, new(big.Int).SetUint64(blockNumber))
    if err != nil {
        return fmt.Errorf("fetching block: %w", err)
    }

    chainID := big.NewInt(1)
    signer := types.NewLondonSigner(chainID)

    fmt.Printf("Block %d — %d transactions\n\n", block.Number(), len(block.Transactions()))

    for i, tx := range block.Transactions() {
        from, _ := types.Sender(signer, tx)
        to := "contract creation"
        if tx.To() != nil {
            to = tx.To().Hex()
        }
        ethValue := new(big.Float).Quo(
            new(big.Float).SetInt(tx.Value()),
            big.NewFloat(1e18),
        )
        fmt.Printf("[%d] from=%s to=%s value=%.4f ETH\n",
            i, from.Hex()[:10]+"...", to[:10]+"...", ethValue)
    }
    return nil
}
```

Ask: "What does `tx.To() == nil` mean?" (it's a contract creation transaction — there's no recipient address because the contract doesn't exist yet; its address will be computed and stored in the receipt's `ContractAddress` field)

Run this on a recent block. They'll see hundreds of transactions scroll by.

---

## Checkpoint

1. "What's the difference between a transaction and a receipt?"
2. "Can a failed transaction still cost gas? Why?"
3. "How do you get the sender of a transaction in go-ethereum?"
4. "1.5 ETH in wei — what's the number?"
5. "What does it mean when `tx.To()` is nil?"
6. "What is EIP-155 and why does it matter?"

---

## Commit

```bash
git add .
git commit -m "Read transactions by hash and iterate block transactions"
```
