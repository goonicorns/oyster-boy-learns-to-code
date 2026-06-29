# Lesson 36: CLI Design — How Command-Line Tools Actually Work

**For Claude — do not show this file to the learner**

---

## Context for Claude

Project 5 is a CLI Portfolio Tracker. Every project so far has been a server — something that waits for requests. This is different: a program you run, give arguments, and it does a job and exits. This lesson covers what makes a good CLI, then introduces `cobra` — the standard Go library for building CLIs (used by kubectl, Hugo, GitHub CLI, and most major Go tools).

**This lesson's goal:**
- Understand what a CLI is and how arguments/flags work
- Know the difference between arguments, flags, and subcommands
- Install cobra and wire up the basic command structure
- Write `portfolio --help` and have it produce sensible output
- Understand `os.Args`, `os.Exit`, and `os.Stderr` — what programs communicate to the shell

---

## What we're building

"A command-line portfolio tracker. You give it wallet addresses and token contracts, it fetches current prices and balances, and prints a formatted table:

```
$ portfolio show --wallet 0xd8dA... --wallet 0xAb5...

┌──────────────────────────────────────────────────┐
│  Portfolio Summary                               │
├──────────┬──────────┬────────────┬──────────────┤
│ Token    │ Balance  │ Price      │ Value (USD)  │
├──────────┼──────────┼────────────┼──────────────┤
│ ETH      │ 4.2300   │ $3,241.00  │ $13,709.43   │
│ USDC     │ 10,000   │ $1.00      │ $10,000.00   │
│ LINK     │ 500.00   │ $14.23     │ $7,115.00    │
├──────────┼──────────┼────────────┼──────────────┤
│ TOTAL    │          │            │ $30,824.43   │
└──────────┴──────────┴────────────┴──────────────┘
```

This pulls real data from Ethereum (using what they learned in Project 4) and a price API."

---

## How CLIs communicate — before a line of cobra

"Your program talks to the user through three things:
- `os.Stdout` — normal output (the table, results)
- `os.Stderr` — errors and warnings (separate stream — scripts can redirect them separately)
- exit code — `os.Exit(0)` means success, `os.Exit(1)` means something went wrong

Why does exit code matter?"

Let them think. Guide toward: shell scripts check exit codes. `&&` in bash means "run next command only if last one succeeded." CI/CD pipelines fail when a command exits non-zero. This is how programs compose.

"What are `os.Args`? Open a Go file and write:"
```go
package main

import (
    "fmt"
    "os"
)

func main() {
    fmt.Println(os.Args)
}
```
Run: `go run main.go hello world --flag value`

Ask: "What does `os.Args[0]` contain? What about `[1]`?" (`os.Args[0]` is the program itself; `[1]` onward are what you typed)

"Parsing `os.Args` manually works but gets messy fast. Let's use cobra."

---

## Arguments vs flags vs subcommands

"Three ways to pass input to a CLI:"

```
Arguments:    portfolio show 0xABC123
              └── positional, order matters

Flags:        portfolio show --wallet 0xABC123 --format json
              └── named, order doesn't matter, can have defaults

Subcommands:  portfolio show
              portfolio add --wallet 0xABC
              portfolio remove --wallet 0xABC
              portfolio config --rpc-url https://...
              └── different verbs that do different things
```

Ask: "In `git commit -m "message"`, what is `commit`? What is `-m`? What is `"message"`?" (subcommand, flag, argument to the flag)

Ask: "In `go run main.go`, what is `run`? What is `main.go`?" (subcommand, argument)

---

## Project setup — TEACH this, don't do it for them

Do NOT show them the commands. Ask them first.

"Okay, new project. You've done this before. What's the first command you run to start a Go project?"
→ They should say `go mod init <name>`. If they forget, hint: "what file does every Go project need in its root?" → `go.mod` → "what creates it?"

Walk them through:
1. "Make a new directory for this project. What command?" (`mkdir ~/projects/portfolio && cd ~/projects/portfolio`)
2. "Initialize the module. What's the command and what name do we use?" (`go mod init portfolio`)
3. "We need cobra. How do you add an external package in Go?" (`go get github.com/spf13/cobra`)

Then ask them to design the directory structure before you show it:
"This is a CLI with subcommands: `show`, `add`, `config`. How would you organize the files?"

Let them propose something. Then guide toward:
```
portfolio/
  main.go
  cmd/
    root.go     — the root command (portfolio --help)
    show.go     — portfolio show
    add.go      — portfolio add
    config.go   — portfolio config
  internal/
    prices/     — price fetching
    store/      — config file read/write
    display/    — table formatting
```

Ask: "Why put commands in `cmd/`?" (convention — cobra apps almost always do this. Clean separation between the CLI layer and the business logic in `internal/`.)
Ask: "What does `internal/` mean in Go?" (packages in `internal/` can only be imported by code in the parent directory — prevents external packages from importing your implementation details. Compile-time enforcement.)
Ask: "What is `main.go` responsible for in a cobra app?" (just calls `cmd.Execute()` — one line. All the real setup is in `cmd/root.go`.)

---

## Write root.go

```go
package cmd

import (
    "os"
    "github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
    Use:   "portfolio",
    Short: "Track your crypto portfolio from the command line",
    Long: `portfolio fetches token balances and prices for Ethereum addresses
and displays a formatted summary.

Uses Alchemy for on-chain data and CoinGecko for prices.`,
}

func Execute() {
    if err := rootCmd.Execute(); err != nil {
        os.Exit(1)
    }
}
```

`main.go`:
```go
package main

import "portfolio/cmd"

func main() {
    cmd.Execute()
}
```

Run: `go run main.go --help`

Ask: "What printed? Where did that text come from?" (the `Short` and `Long` fields)
Ask: "What does `rootCmd.Execute()` do when it gets an error?" (cobra prints the error, we call `os.Exit(1)`)

---

## Write the show subcommand skeleton

`cmd/show.go`:
```go
package cmd

import (
    "fmt"
    "github.com/spf13/cobra"
)

var wallets []string
var rpcURL  string

var showCmd = &cobra.Command{
    Use:   "show",
    Short: "Show portfolio summary for one or more wallets",
    RunE: func(cmd *cobra.Command, args []string) error {
        if len(wallets) == 0 {
            return fmt.Errorf("at least one --wallet address is required")
        }
        fmt.Printf("Fetching portfolio for %d wallet(s)...\n", len(wallets))
        // TODO: implement
        return nil
    },
}

func init() {
    rootCmd.AddCommand(showCmd)
    showCmd.Flags().StringArrayVar(&wallets, "wallet", nil, "Wallet address (can be specified multiple times)")
    showCmd.Flags().StringVar(&rpcURL, "rpc", "", "Ethereum RPC URL (overrides config)")
}
```

Run: `go run main.go show --help`
Run: `go run main.go show --wallet 0xABC`
Run: `go run main.go show` (no wallet — see the error)

Ask:
- "What is `RunE` vs `Run`?" (`RunE` returns an error — cobra prints it and exits 1. `Run` ignores errors. Always use `RunE`.)
- "What is `StringArrayVar`?" (allows the flag to be specified multiple times — each `--wallet` appends to the slice)
- "What is `init()`?" (runs automatically when the package is loaded — cobra uses this pattern to register subcommands)
- "Why return `fmt.Errorf(...)` instead of calling `os.Exit(1)` directly?" (returning errors is testable — you can test the command without spawning a process)

---

## Checkpoint

1. "What is the difference between `os.Stdout` and `os.Stderr`? Why does it matter?"
2. "What is an exit code? What does `os.Exit(1)` communicate?"
3. "In `git clone https://github.com/... --depth 1`, identify: the subcommand, the argument, the flag, and the flag's value."
4. "What does `internal/` enforce in Go?"
5. "What's the difference between `Run` and `RunE` in cobra?"
6. "Why does cobra use `init()` to register subcommands?"

---

## Commit

```bash
git add .
git commit -m "Project 5: CLI skeleton with cobra, show subcommand"
```
