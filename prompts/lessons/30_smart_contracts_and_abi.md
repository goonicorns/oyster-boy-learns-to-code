# Lesson 30: Smart Contracts — The ABI and Calling Contract Functions

**For Claude — do not show this file to the learner**

---

## Context for Claude

This is the core of the project. They're going to read from a real deployed smart contract — specifically USDC (USD Coin), an ERC-20 token with billions of dollars of real value. The key new concept is the ABI: how Go (or anything) knows how to talk to a contract.

**This lesson's goal:**
- Understand what an ABI is and why it exists
- Understand how function calls are encoded (the 4-byte selector + ABI-encoded args)
- Read from a real ERC-20 contract: `name()`, `symbol()`, `decimals()`, `totalSupply()`
- Read the USDC balance of a real address
- Do this with raw ABI calls first (so they understand what's happening under the hood)

---

## What is an ABI?

"You know how in Go, a function has a signature — its name, parameter types, return types? When you compile Go, all of that is in the binary."

"Smart contracts compiled to EVM bytecode don't store function names — just the raw bytecode. So how does anything know how to call them?"

"The ABI — Application Binary Interface — is a separate JSON document that describes:
- Every function in the contract: name, parameter types, return types
- Every event: name and parameter types
- Whether functions can receive ETH, whether they modify state, etc."

"When you want to call a function, you:
1. Look up the function in the ABI
2. Encode the function name + parameter types as a 4-byte selector (keccak256 hash of the signature, first 4 bytes)
3. ABI-encode the arguments
4. Send that as the `data` field of a transaction (or `call` if you're just reading)"

Show them the ERC-20 ABI for the `symbol()` function:
```json
{
    "name": "symbol",
    "type": "function",
    "inputs": [],
    "outputs": [{"type": "string"}],
    "stateMutability": "view"
}
```

Ask:
- "What does `view` mean?" (this function only reads state — it doesn't modify anything, so it doesn't need a transaction and costs no gas)
- "What's `inputs: []` telling us?" (symbol() takes no arguments)
- "What does the output tell us?" (it returns a string)

---

## The ERC-20 standard

"ERC-20 is a standard — an agreed-upon interface that all fungible tokens implement. USDC, USDT, LINK, UNI — they're all ERC-20 tokens. The standard defines exactly which functions every token must have."

The standard functions (have them write these down):
```
name()        → string    — e.g. "USD Coin"
symbol()      → string    — e.g. "USDC"
decimals()    → uint8     — e.g. 6 (USDC uses 6 decimals, not 18)
totalSupply() → uint256   — total tokens in existence, in base units
balanceOf(address) → uint256  — balance of an address, in base units
transfer(address, uint256) → bool  — send tokens
approve(address, uint256) → bool   — allow another address to spend your tokens
transferFrom(address, address, uint256) → bool  — spend approved tokens
```

Ask: "USDC has 6 decimals. If balanceOf returns 1,000,000, how many USDC is that?" (1.0 USDC — divide by 10^6)

Ask: "Why would different tokens use different numbers of decimals?" (convention and precision — ETH itself uses 18; stablecoins often use 6 like the fiat currencies they mirror)

---

## Call a contract function (raw ABI, no generated bindings)

"Before we use the fancy code generator, let's do it manually so you understand exactly what's happening."

USDC contract address on mainnet: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`

```go
package contracts

import (
    "context"
    "fmt"
    "math/big"

    "github.com/ethereum/go-ethereum"
    "github.com/ethereum/go-ethereum/accounts/abi"
    "github.com/ethereum/go-ethereum/common"
    "github.com/ethereum/go-ethereum/ethclient"
    "strings"
)

const erc20ABI = `[
    {"name":"name","type":"function","inputs":[],"outputs":[{"type":"string"}],"stateMutability":"view"},
    {"name":"symbol","type":"function","inputs":[],"outputs":[{"type":"string"}],"stateMutability":"view"},
    {"name":"decimals","type":"function","inputs":[],"outputs":[{"type":"uint8"}],"stateMutability":"view"},
    {"name":"totalSupply","type":"function","inputs":[],"outputs":[{"type":"uint256"}],"stateMutability":"view"},
    {"name":"balanceOf","type":"function","inputs":[{"name":"account","type":"address"}],"outputs":[{"type":"uint256"}],"stateMutability":"view"}
]`

func ReadERC20(client *ethclient.Client, contractAddr string) error {
    ctx := context.Background()
    addr := common.HexToAddress(contractAddr)

    parsedABI, err := abi.JSON(strings.NewReader(erc20ABI))
    if err != nil {
        return fmt.Errorf("parsing ABI: %w", err)
    }

    // Call name()
    name, err := callString(ctx, client, addr, parsedABI, "name")
    if err != nil {
        return err
    }

    symbol, err := callString(ctx, client, addr, parsedABI, "symbol")
    if err != nil {
        return err
    }

    // Call decimals()
    decimalsData, err := callContract(ctx, client, addr, parsedABI, "decimals")
    if err != nil {
        return err
    }
    var decimals uint8
    if err := parsedABI.UnpackIntoInterface(&decimals, "decimals", decimalsData); err != nil {
        return fmt.Errorf("unpacking decimals: %w", err)
    }

    // Call totalSupply()
    supplyData, err := callContract(ctx, client, addr, parsedABI, "totalSupply")
    if err != nil {
        return err
    }
    var totalSupply *big.Int
    if err := parsedABI.UnpackIntoInterface(&totalSupply, "totalSupply", supplyData); err != nil {
        return fmt.Errorf("unpacking totalSupply: %w", err)
    }

    // Format supply with decimals
    divisor := new(big.Float).SetInt(new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(decimals)), nil))
    humanSupply := new(big.Float).Quo(new(big.Float).SetInt(totalSupply), divisor)

    fmt.Printf("Contract: %s\n", contractAddr)
    fmt.Printf("Name:     %s\n", name)
    fmt.Printf("Symbol:   %s\n", symbol)
    fmt.Printf("Decimals: %d\n", decimals)
    fmt.Printf("Supply:   %.2f %s\n", humanSupply, symbol)

    return nil
}

// callContract packs a function call and executes it against the node
func callContract(ctx context.Context, client *ethclient.Client, addr common.Address, parsedABI abi.ABI, method string, args ...interface{}) ([]byte, error) {
    data, err := parsedABI.Pack(method, args...)
    if err != nil {
        return nil, fmt.Errorf("packing %s call: %w", method, err)
    }

    msg := ethereum.CallMsg{
        To:   &addr,
        Data: data,
    }

    return client.CallContract(ctx, msg, nil) // nil = latest block
}

func callString(ctx context.Context, client *ethclient.Client, addr common.Address, parsedABI abi.ABI, method string) (string, error) {
    data, err := callContract(ctx, client, addr, parsedABI, method)
    if err != nil {
        return "", err
    }
    var result string
    if err := parsedABI.UnpackIntoInterface(&result, method, data); err != nil {
        return "", fmt.Errorf("unpacking %s: %w", method, err)
    }
    return result, nil
}
```

Walk through it with questions:
- "What is `parsedABI.Pack`?" (encodes the function selector + arguments into the raw bytes that get sent as transaction data)
- "What is `CallContract`?" (sends a read-only call to the node — no transaction, no gas, no signature needed)
- "What is `UnpackIntoInterface`?" (decodes the raw bytes returned by the contract into a Go value)
- "Why `nil` for the block number in `CallContract`?" (nil means latest block — you could pass a historical block number to read state at a point in the past)

---

## Read a balance

```go
func BalanceOf(client *ethclient.Client, contractAddr, holderAddr string) error {
    ctx := context.Background()
    addr := common.HexToAddress(contractAddr)

    parsedABI, _ := abi.JSON(strings.NewReader(erc20ABI))

    holder := common.HexToAddress(holderAddr)
    data, err := callContract(ctx, client, addr, parsedABI, "balanceOf", holder)
    if err != nil {
        return err
    }

    var balance *big.Int
    if err := parsedABI.UnpackIntoInterface(&balance, "balanceOf", data); err != nil {
        return fmt.Errorf("unpacking balance: %w", err)
    }

    // USDC has 6 decimals
    divisor := new(big.Float).SetInt(new(big.Int).Exp(big.NewInt(10), big.NewInt(6), nil))
    human := new(big.Float).Quo(new(big.Float).SetInt(balance), divisor)
    fmt.Printf("Balance of %s: %.2f USDC\n", holderAddr[:10]+"...", human)
    return nil
}
```

"Have them look up a USDC whale on Etherscan — go to the USDC token page, click 'Holders', pick a large holder's address. Call BalanceOf with that address."

Moment of awe: they should see hundreds of millions of USDC printed in their terminal.

Ask: "Is calling balanceOf 'reading from the blockchain' or 'reading from Alchemy's database'?" (Alchemy's node — but the node has a verified copy of chain state. The answer it gives you is cryptographically verifiable.)

Ask: "If you call balanceOf at block 18,000,000 vs today, what might be different?" (the holder might have transferred tokens between then and now — you're reading historical state)

---

## Checkpoint

1. "What is an ABI?"
2. "What is the 4-byte function selector and how is it derived?"
3. "What does `view` mean in a Solidity function? What does it change about how you call it?"
4. "USDC has 6 decimals. If balanceOf returns 50,000,000,000, how many USDC is that?"
5. "What's the difference between `CallContract` (what we used) and sending an actual transaction?"
6. "What are the 5 read functions every ERC-20 must have?"

---

## Commit

```bash
git add .
git commit -m "Read ERC-20 contract data: name, symbol, decimals, supply, balance"
```
