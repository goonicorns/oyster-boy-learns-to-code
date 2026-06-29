# Lesson 46: Wallets, Signed Transactions, and REST API

**For Claude — do not show this file to the learner**

---

## Context for Claude

The chain works but accepts transactions from anyone claiming to be anyone. Now they add wallets (real key pairs) and transaction signing — so only the holder of a private key can send from that address. Then wire everything to a REST API. This is the most satisfying part: they mine blocks through curl commands.

**This lesson's goal:**
- Generate key pairs for wallets (reuse crypto/ecdsa from Project 4)
- Sign transactions with the sender's private key
- Verify signatures before adding transactions to a block
- Calculate balances by scanning the chain
- REST API: POST /transaction, POST /mine, GET /chain, GET /balance/:address

---

## Wallets

`wallet/wallet.go`:

```go
package wallet

import (
    "crypto/ecdsa"
    "crypto/elliptic"
    "crypto/rand"
    "crypto/sha256"
    "encoding/hex"
    "fmt"
    "math/big"
)

type Wallet struct {
    PrivateKey *ecdsa.PrivateKey
    PublicKey  *ecdsa.PublicKey
    Address    string
}

func New() (*Wallet, error) {
    privateKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
    if err != nil {
        return nil, fmt.Errorf("generating key: %w", err)
    }

    pubKey := &privateKey.PublicKey
    address := publicKeyToAddress(pubKey)

    return &Wallet{
        PrivateKey: privateKey,
        PublicKey:  pubKey,
        Address:    address,
    }, nil
}

func publicKeyToAddress(pub *ecdsa.PublicKey) string {
    // Simplified: hash the public key bytes
    keyBytes := append(pub.X.Bytes(), pub.Y.Bytes()...)
    hash := sha256.Sum256(keyBytes)
    return hex.EncodeToString(hash[:20]) // take first 20 bytes like Ethereum
}

func (w *Wallet) Sign(data []byte) (string, error) {
    hash := sha256.Sum256(data)
    r, s, err := ecdsa.Sign(rand.Reader, w.PrivateKey, hash[:])
    if err != nil {
        return "", fmt.Errorf("signing: %w", err)
    }
    // Encode r and s as hex, concatenated
    sig := hex.EncodeToString(r.Bytes()) + hex.EncodeToString(s.Bytes())
    return sig, nil
}

func Verify(pubKey *ecdsa.PublicKey, data []byte, signature string) bool {
    if len(signature) < 64 {
        return false
    }
    mid := len(signature) / 2
    rBytes, err1 := hex.DecodeString(signature[:mid])
    sBytes, err2 := hex.DecodeString(signature[mid:])
    if err1 != nil || err2 != nil {
        return false
    }
    r := new(big.Int).SetBytes(rBytes)
    s := new(big.Int).SetBytes(sBytes)

    hash := sha256.Sum256(data)
    return ecdsa.Verify(pubKey, hash[:], r, s)
}
```

Ask:
- "What is `elliptic.P256()`?" (a specific elliptic curve — secp256r1. Note Bitcoin and Ethereum use secp256k1, a different curve. For our baby chain, P256 is fine.)
- "Why do we hash the data before signing?" (ECDSA operates on fixed-size inputs — SHA-256 maps any data to 32 bytes)
- "What does the signature prove?" (that the holder of the private key corresponding to the public key authorized this data)
- "What is `rand.Reader`?" (cryptographically secure random number generator — both key generation and signing need genuine randomness)

---

## Add signature to Transaction

Update `chain/transaction.go`:

```go
type Transaction struct {
    ID        string  `json:"id"`
    From      string  `json:"from"`
    To        string  `json:"to"`
    Amount    float64 `json:"amount"`
    Timestamp int64   `json:"timestamp"`
    Signature string  `json:"signature"` // add this
    PublicKey string  `json:"public_key"` // hex-encoded public key for verification
}

func (t *Transaction) DataToSign() []byte {
    return []byte(fmt.Sprintf("%s%s%f%d", t.From, t.To, t.Amount, t.Timestamp))
}
```

And in `Blockchain.AddBlock`, verify each transaction:
```go
for _, tx := range txns {
    if tx.From == "COINBASE" {
        continue // mining reward, no signature needed
    }
    // Parse the public key and verify
    if !verifyTransaction(tx) {
        return nil, fmt.Errorf("invalid signature on transaction from %s", tx.From)
    }
}
```

Ask: "What is a COINBASE transaction?" (the mining reward — the first transaction in every real Bitcoin block. The miner pays themselves. No sender, no signature. Our chain uses the same concept.)

---

## Balance calculation

"There's no 'balance' field anywhere in our chain. So how do you know how much someone has?"

"You scan every transaction from block 0 to now. Add up what they received, subtract what they sent."

```go
func (bc *Blockchain) Balance(address string) float64 {
    bc.mu.RLock()
    defer bc.mu.RUnlock()

    var balance float64
    for _, block := range bc.blocks {
        for _, tx := range block.Transactions {
            if tx.To == address {
                balance += tx.Amount
            }
            if tx.From == address {
                balance -= tx.Amount
            }
        }
    }
    return balance
}
```

Ask: "What's the problem with this approach as the chain grows?" (gets slower as the chain gets longer — O(n) per query where n = all transactions ever. Real blockchains maintain a UTXO set or account state trie for O(1) lookups.)
Ask: "What is a UTXO?" (Unspent Transaction Output — Bitcoin's model. You don't have a balance; you have a set of unspent outputs you can spend. More complex but enables certain optimizations.)

---

## REST API

`api/server.go`:

```go
package api

import (
    "encoding/json"
    "minichain/chain"
    "net/http"

    "github.com/go-chi/chi/v5"
)

type Server struct {
    bc *chain.Blockchain
}

func New(bc *chain.Blockchain) *Server {
    return &Server{bc: bc}
}

func (s *Server) Router() http.Handler {
    r := chi.NewRouter()
    r.Get("/chain", s.handleChain)
    r.Get("/balance/{address}", s.handleBalance)
    r.Post("/transaction", s.handleTransaction)
    r.Post("/mine", s.handleMine)
    return r
}

func (s *Server) handleChain(w http.ResponseWriter, r *http.Request) {
    json.NewEncoder(w).Encode(s.bc.Blocks())
}

func (s *Server) handleBalance(w http.ResponseWriter, r *http.Request) {
    address := chi.URLParam(r, "address")
    balance := s.bc.Balance(address)
    json.NewEncoder(w).Encode(map[string]float64{"balance": balance})
}

// handleTransaction adds a pending transaction
// handleMine mines a new block with pending transactions
// (have them implement these themselves)
```

"Wire up a pending transaction pool (a slice protected by a mutex) and implement the mine endpoint. The mine endpoint: takes all pending transactions, calls `AddBlock`, clears the pool, returns the new block."

Ask: "What is the race condition risk in the transaction pool?" (multiple concurrent POST /transaction requests could corrupt the slice — needs a mutex)
Ask: "What should happen if someone tries to mine when the pending pool is empty?" (return an error or mine a block with just a coinbase transaction)

---

## Test the full flow with curl

```bash
# Start the server
go run main.go

# Check the chain (just genesis block)
curl localhost:8080/chain | jq

# Fund an address (pretend - we'll skip signing for now)
curl -X POST localhost:8080/transaction \
  -H "Content-Type: application/json" \
  -d '{"from":"COINBASE","to":"alice","amount":100}'

# Mine a block
curl -X POST localhost:8080/mine

# Check alice's balance
curl localhost:8080/balance/alice

# Alice sends to Bob
curl -X POST localhost:8080/transaction \
  -d '{"from":"alice","to":"bob","amount":30}'

# Mine again
curl -X POST localhost:8080/mine

# Check balances
curl localhost:8080/balance/alice
curl localhost:8080/balance/bob
```

Let them watch transactions become real as they mine blocks. This is their blockchain.

---

## Checkpoint

1. "How is balance calculated in our chain? What's the performance problem?"
2. "What is a COINBASE transaction? Why doesn't it need a signature?"
3. "What does the ECDSA signature prove about a transaction?"
4. "If someone sends a transaction claiming to be Alice without her private key, what breaks?"
5. "Why does `AddBlock` need to hold the mutex lock, but `Balance` uses `RLock`?"
6. "Walk me through what happens when you POST /mine."

---

## Commit

```bash
git add .
git commit -m "Wallets, signing, balance calculation, REST API"
```
