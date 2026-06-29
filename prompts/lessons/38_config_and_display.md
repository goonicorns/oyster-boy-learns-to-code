# Lesson 38: Config Files, File I/O, and Terminal Tables

**For Claude — do not show this file to the learner**

---

## Context for Claude

Two things this lesson: (1) persisting config to a file so users don't have to pass --wallet every time, and (2) rendering the portfolio as a formatted terminal table. These are unglamorous but essential — real CLI tools do both. The file I/O section drills `os`, `encoding/json`, and `filepath`. The display section teaches `text/tabwriter`.

**This lesson's goal:**
- Read and write a JSON config file in the user's home directory
- Use `os.UserConfigDir()` to find the right place
- Handle the "file doesn't exist yet" case cleanly
- Render a formatted table with `text/tabwriter`
- Format numbers: commas, dollar signs, decimal places

---

## Where should config live?

"Where does your program store its config? Don't use the current directory — the user might run your tool from anywhere. Don't hardcode `/Users/neil/` — that's someone else's machine."

Ask: "Where does git store per-repo config? Where does it store global config?" (`.git/config` per-repo, `~/.gitconfig` global)

"Go has `os.UserConfigDir()` — returns the right config directory for the OS:
- macOS: `~/Library/Application Support`
- Linux: `~/.config`
- Windows: `%APPDATA%`"

And `os.UserHomeDir()` for the home directory directly.

---

## Write the config store

`internal/store/config.go`:

```go
package store

import (
    "encoding/json"
    "errors"
    "fmt"
    "os"
    "path/filepath"
)

type Config struct {
    Wallets []string `json:"wallets"`
    RPCURL  string   `json:"rpc_url"`
    Tokens  []string `json:"tokens"`
}

func DefaultConfig() *Config {
    return &Config{
        Tokens: []string{"ETH", "USDC", "LINK"},
    }
}

func configPath() (string, error) {
    dir, err := os.UserConfigDir()
    if err != nil {
        return "", fmt.Errorf("finding config dir: %w", err)
    }
    return filepath.Join(dir, "portfolio", "config.json"), nil
}

func Load() (*Config, error) {
    path, err := configPath()
    if err != nil {
        return nil, err
    }

    data, err := os.ReadFile(path)
    if errors.Is(err, os.ErrNotExist) {
        // No config yet — return defaults
        return DefaultConfig(), nil
    }
    if err != nil {
        return nil, fmt.Errorf("reading config: %w", err)
    }

    var cfg Config
    if err := json.Unmarshal(data, &cfg); err != nil {
        return nil, fmt.Errorf("parsing config: %w", err)
    }
    return &cfg, nil
}

func Save(cfg *Config) error {
    path, err := configPath()
    if err != nil {
        return err
    }

    // Create directory if it doesn't exist
    if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
        return fmt.Errorf("creating config dir: %w", err)
    }

    data, err := json.MarshalIndent(cfg, "", "  ")
    if err != nil {
        return fmt.Errorf("encoding config: %w", err)
    }

    if err := os.WriteFile(path, data, 0600); err != nil {
        return fmt.Errorf("writing config: %w", err)
    }
    return nil
}
```

Ask question by question:
- "Why `errors.Is(err, os.ErrNotExist)` instead of `err != nil`?" (we want to specifically handle the missing-file case differently — any other error like a permission denied should still propagate)
- "What is `os.MkdirAll`?" (creates the full path of directories, including parents — like `mkdir -p`. Won't fail if they already exist.)
- "Why `0755` for the directory and `0600` for the file?" (0755 = directory readable by everyone, writable by owner; 0600 = file readable/writable by owner ONLY — config files might contain API keys)
- "What is `filepath.Dir(path)`?" (returns the directory part of a path — if path is `/a/b/c.json`, returns `/a/b`)
- "Why `json.MarshalIndent` instead of `json.Marshal`?" (human-readable config file — users might want to edit it manually)

---

## Wire up the `add` command

`cmd/add.go`:
```go
package cmd

import (
    "fmt"
    "portfolio/internal/store"
    "github.com/spf13/cobra"
)

var addCmd = &cobra.Command{
    Use:   "add --wallet <address>",
    Short: "Add a wallet address to your portfolio",
    RunE: func(cmd *cobra.Command, args []string) error {
        wallet, _ := cmd.Flags().GetString("wallet")
        if wallet == "" {
            return fmt.Errorf("--wallet is required")
        }

        cfg, err := store.Load()
        if err != nil {
            return err
        }

        // Check for duplicates
        for _, w := range cfg.Wallets {
            if w == wallet {
                fmt.Println("Wallet already in portfolio.")
                return nil
            }
        }

        cfg.Wallets = append(cfg.Wallets, wallet)
        if err := store.Save(cfg); err != nil {
            return err
        }

        fmt.Printf("Added %s\n", wallet)
        return nil
    },
}

func init() {
    rootCmd.AddCommand(addCmd)
    addCmd.Flags().String("wallet", "", "Ethereum wallet address to add")
}
```

Test: `portfolio add --wallet 0xd8dA...` then look at the config file. Ask: "Where did the file get created? Open it — is it valid JSON?"

---

## Format the portfolio table

`internal/display/table.go`:

```go
package display

import (
    "fmt"
    "io"
    "os"
    "text/tabwriter"

    "golang.org/x/text/language"
    "golang.org/x/text/message"
)

type Row struct {
    Token   string
    Balance float64
    Price   float64
    Value   float64
}

// Print renders a portfolio table to stdout
func PrintPortfolio(rows []Row, totalUSD float64) {
    p := message.NewPrinter(language.English) // for comma-separated numbers

    w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
    printTable(w, p, rows, totalUSD)
    w.Flush()
}

func printTable(w io.Writer, p *message.Printer, rows []Row, totalUSD float64) {
    fmt.Fprintln(w, "Token\tBalance\tPrice (USD)\tValue (USD)")
    fmt.Fprintln(w, "─────\t───────\t───────────\t──────────")

    for _, row := range rows {
        fmt.Fprintf(w, "%s\t%.4f\t$%s\t$%s\n",
            row.Token,
            row.Balance,
            p.Sprintf("%.2f", row.Price),
            p.Sprintf("%.2f", row.Value),
        )
    }

    fmt.Fprintln(w, "─────\t───────\t───────────\t──────────")
    fmt.Fprintf(w, "TOTAL\t\t\t$%s\n", p.Sprintf("%.2f", totalUSD))
}
```

"Install the formatting library:"
```bash
go get golang.org/x/text
```

Ask:
- "What is `tabwriter`?" (aligns columns by padding with spaces — tabs become column separators, `Flush()` writes it all at once after calculating widths)
- "What does `message.NewPrinter(language.English)` give us?" (number formatting with commas — `1000000` prints as `1,000,000`)
- "Why do we pass `io.Writer` to `printTable` instead of always using `os.Stdout`?" (testable — in tests we can pass a `bytes.Buffer` and check the output; in production we pass `os.Stdout`)
- "What is `w.Flush()`?" (tabwriter buffers everything to calculate column widths — Flush() writes the final aligned output. Without it, nothing prints.)

---

## Wire it all together in `show`

Update `cmd/show.go` to: load config, merge any --wallet flags, fetch balances from chain (they have this from Project 4), fetch prices, compute values, print table.

Don't write this for them — walk them through it conceptually and make them assemble the pieces. The data flow is:
```
Config + flags → wallet addresses
Wallet addresses → ethclient.BalanceAt() for ETH + ERC-20 balanceOf()
Token symbols → CoinGecko prices
Balance × Price → Value
All rows → display.PrintPortfolio()
```

---

## Checkpoint

1. "What does `errors.Is(err, os.ErrNotExist)` do? Why not just `err != nil`?"
2. "What permissions should a config file have? What about its directory? Why different?"
3. "What does `tabwriter.NewWriter` do? Why must you call `.Flush()`?"
4. "Why pass `io.Writer` to display functions instead of hardcoding `os.Stdout`?"
5. "What is `os.MkdirAll` equivalent to in the terminal?"
6. "Write me `os.UserConfigDir()` output for macOS." (~/Library/Application Support)

---

## Commit

```bash
git add .
git commit -m "Config persistence, add/remove wallets, formatted portfolio table"
```
