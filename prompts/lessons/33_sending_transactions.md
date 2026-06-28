# Lesson 33: Sending Transactions — Writing to the Blockchain

**For Claude — do not show this file to the learner**

---

## Context for Claude

Everything so far has been read-only. Now they write to the blockchain: sign and send a real ETH transfer on the Sepolia testnet. This lesson covers private key management, nonce handling, gas estimation, and signing. Use testnet only — no real money involved.

**This lesson's goal:**
- Understand how a transaction gets signed in Go
- Generate a throwaway private key for Sepolia testnet
- Get testnet ETH from a faucet
- Estimate gas
- Sign and send a transaction
- Watch it confirm on Etherscan

---

## Testnet first — always

"Everything we do in this lesson uses Sepolia — Ethereum's test network. It works identically to mainnet but the ETH has no value. You can get it free from a faucet."

"NEVER use a private key with real money on mainnet until you fully understand what you're doing. Private key handling mistakes are irreversible."

Have them:
1. Change their Alchemy app to Sepolia network (or create a new app)
2. Update `ETH_RPC_URL` to the Sepolia URL

---

## Generate a private key

"For Sepolia testing, generate a throwaway key. Never use this for mainnet."

```go
package wallet

import (
    "crypto/ecdsa"
    "fmt"

    "github.com/ethereum/go-ethereum/common/hexutil"
    "github.com/ethereum/go-ethereum/crypto"
)

func GenerateKey() {
    privateKey, err := crypto.GenerateKey()
    if err != nil {
        panic(err)
    }

    privateKeyBytes := crypto.FromECDSA(privateKey)
    fmt.Printf("Private key: %s\n", hexutil.Encode(privateKeyBytes)[2:]) // strip 0x

    publicKey := privateKey.Public()
    publicKeyECDSA := publicKey.(*ecdsa.PublicKey)
    address := crypto.PubkeyToAddress(*publicKeyECDSA)
    fmt.Printf("Address:     %s\n", address.Hex())
}
```

Ask: "What is `crypto.PubkeyToAddress` doing?" (keccak256 of the public key bytes, take last 20 bytes — exactly the derivation we drew in lesson 27)

"Run this. You'll get a private key and address. WRITE THEM DOWN. Store the private key in an env var:"

```bash
export ETH_PRIVATE_KEY="your_private_key_here"
```

"Go to sepoliafaucet.com, paste your address, request ETH. Wait 30 seconds."

---

## Load the private key

```go
package wallet

import (
    "crypto/ecdsa"
    "fmt"
    "os"

    "github.com/ethereum/go-ethereum/crypto"
)

func LoadPrivateKey() (*ecdsa.PrivateKey, error) {
    raw := os.Getenv("ETH_PRIVATE_KEY")
    if raw == "" {
        return nil, fmt.Errorf("ETH_PRIVATE_KEY not set")
    }

    privateKey, err := crypto.HexToECDSA(raw)
    if err != nil {
        return nil, fmt.Errorf("parsing private key: %w", err)
    }

    return privateKey, nil
}
```

Ask: "Why do we load from an environment variable and not from a file?" (env vars don't get committed to git — a file with a private key is one accidental `git add` away from being public)

Ask: "In production systems, where are private keys stored?" (hardware security modules, AWS KMS, HashiCorp Vault — dedicated systems with audit logs, access controls, and no way to export the raw key)

---

## Check the balance

Before sending anything, check they got testnet ETH:

```go
func CheckBalance(client *ethclient.Client, address common.Address) error {
    ctx := context.Background()
    balance, err := client.BalanceAt(ctx, address, nil) // nil = latest block
    if err != nil {
        return fmt.Errorf("getting balance: %w", err)
    }

    ethValue := new(big.Float).Quo(
        new(big.Float).SetInt(balance),
        big.NewFloat(1e18),
    )
    fmt.Printf("Balance of %s: %.6f ETH\n", address.Hex(), ethValue)
    return nil
}
```

Ask: "Why is `BalanceAt` taking an address, not using 'my address' automatically?" (the node doesn't know who you are — it knows nothing about private keys. It just reads state. Anyone can query anyone's balance.)

---

## Build and send a transaction

```go
package txns

import (
    "context"
    "crypto/ecdsa"
    "fmt"
    "math/big"

    "github.com/ethereum/go-ethereum/common"
    "github.com/ethereum/go-ethereum/core/types"
    "github.com/ethereum/go-ethereum/crypto"
    "github.com/ethereum/go-ethereum/ethclient"
)

func SendETH(client *ethclient.Client, privateKey *ecdsa.PrivateKey, toAddr string, amountEth float64) error {
    ctx := context.Background()

    // Derive our address from the private key
    publicKey := privateKey.Public().(*ecdsa.PublicKey)
    fromAddr := crypto.PubkeyToAddress(*publicKey)

    // 1. Get the nonce — how many transactions this address has sent
    nonce, err := client.PendingNonceAt(ctx, fromAddr)
    if err != nil {
        return fmt.Errorf("getting nonce: %w", err)
    }
    fmt.Printf("Nonce: %d\n", nonce)

    // 2. Convert ETH amount to wei
    amountWei := new(big.Int)
    new(big.Float).Mul(
        big.NewFloat(amountEth),
        big.NewFloat(1e18),
    ).Int(amountWei)

    // 3. Estimate gas price
    gasPrice, err := client.SuggestGasPrice(ctx)
    if err != nil {
        return fmt.Errorf("getting gas price: %w", err)
    }
    fmt.Printf("Gas price: %s gwei\n", new(big.Float).Quo(
        new(big.Float).SetInt(gasPrice),
        big.NewFloat(1e9),
    ).Text('f', 2))

    // 4. Build the transaction
    to := common.HexToAddress(toAddr)
    tx := types.NewTransaction(
        nonce,
        to,
        amountWei,
        21000,    // gas limit for a plain ETH transfer
        gasPrice,
        nil,      // no data — plain ETH transfer
    )

    // 5. Get chain ID (Sepolia = 11155111)
    chainID, err := client.NetworkID(ctx)
    if err != nil {
        return fmt.Errorf("getting chain ID: %w", err)
    }

    // 6. Sign the transaction
    signedTx, err := types.SignTx(tx, types.NewLondonSigner(chainID), privateKey)
    if err != nil {
        return fmt.Errorf("signing: %w", err)
    }

    // 7. Send it
    if err := client.SendRawTransaction(ctx, signedTx); err != nil {
        return fmt.Errorf("sending: %w", err)
    }

    fmt.Printf("Sent! Tx hash: %s\n", signedTx.Hash().Hex())
    fmt.Printf("View on Etherscan: https://sepolia.etherscan.io/tx/%s\n", signedTx.Hash().Hex())

    return nil
}
```

Walk through every step with questions:

- "What is `PendingNonceAt`?" (returns the NEXT nonce to use — counts all confirmed + pending transactions from this address)
- "What happens if you reuse a nonce?" (the node rejects the transaction — duplicate)
- "What happens if you skip a nonce?" (the transaction is stuck pending until all lower nonces confirm)
- "Why is the gas limit 21,000 for an ETH transfer?" (the EVM defines the cost of a simple ETH transfer as exactly 21,000 gas — a constant, not an estimate)
- "What is `SuggestGasPrice`?" (asks the node what gas price would get included reasonably fast based on current demand)
- "What is `types.SignTx`?" (ECDSA-signs the transaction hash with the private key — this is the cryptographic proof of authorization)
- "Why do we need the chain ID in the signer?" (EIP-155 — prevents the signed transaction from being replayed on other chains)

---

## Send it and watch it confirm

Have them send 0.001 ETH to some address (can be any address — even their own). Open the Etherscan link immediately.

Watch the transaction go from "pending" to "confirmed" in about 12 seconds. Ask:
- "What is 'pending' mean?" (the transaction is in the mempool — validators have seen it but not included it in a block yet)
- "What determines how fast it gets included?" (the gas price — higher tip = validators prioritize it)
- "What information on the Etherscan page did we produce ourselves in Go?" (all of it — block, from, to, value, gas used, status)

---

## What we're NOT teaching (and why)

"We're not going to build a full transaction signing service or key management system. That's a separate specialty. What you've learned is enough to:
- Read any on-chain state
- Build analytics and monitoring tools
- Test contract interactions on testnets
- Understand how wallets work under the hood

Sending real money on mainnet requires understanding MEV, priority fees, transaction simulation, and key management security — each a deep topic."

---

## Checkpoint

1. "What is a nonce? What happens if you use the wrong one?"
2. "Why is the gas limit for a plain ETH transfer always 21,000?"
3. "What does `types.SignTx` produce? What does the signature prove?"
4. "Why do we use Sepolia instead of mainnet for testing?"
5. "If you accidentally expose your private key on GitHub, what can an attacker do with it?" (drain the wallet immediately, and it's irreversible)
6. "Walk me through the 7 steps of sending a transaction from memory."

---

## Commit

```bash
git add .
git commit -m "Sign and send ETH transactions on Sepolia testnet"
```
