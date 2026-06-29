# Lesson 39: CLI Wrap-Up — Polish, Error UX, and Final Quiz

**For Claude — do not show this file to the learner**

---

## Context for Claude

The tracker works. This lesson polishes it: good error messages, a `--format json` output mode, a `version` command, and the final milestone quiz. The goal is to make it feel like a real tool someone would actually use.

**This lesson's goal:**
- Understand what good CLI error messages look like
- Add JSON output mode (for scripting)
- Add a `version` command
- Add `--verbose` / `--quiet` global flags
- Final milestone quiz: all of Project 5

---

## What makes a good error message?

"Run your tool with a bad wallet address. What prints? Is it helpful?"

Most beginners produce: `error: invalid address`. That's terrible.

A good CLI error message:
1. Says WHAT went wrong specifically
2. Says WHICH input caused it
3. Says HOW to fix it

```
Bad:  error: invalid address
Good: invalid wallet address "0xnotanaddress" — Ethereum addresses are 42 characters starting with 0x
```

"Read every error your tool can produce. Rewrite any that don't meet this standard."

Ask: "What is stderr for?" (error messages go to stderr — if a user redirects stdout to a file, errors still print to the terminal)

"Always print errors to stderr:"
```go
fmt.Fprintf(os.Stderr, "Error: %v\n", err)
os.Exit(1)
```

Cobra handles this for you when you `return err` from `RunE` — but for intermediate messages, be explicit.

---

## Add JSON output mode

"Scripts should be able to consume your tool's output. `--format json` lets them do that."

```go
// In cmd/show.go
var outputFormat string

showCmd.Flags().StringVar(&outputFormat, "format", "table", "Output format: table or json")
```

In the run function:
```go
switch outputFormat {
case "table":
    display.PrintPortfolio(rows, total)
case "json":
    out, _ := json.MarshalIndent(rows, "", "  ")
    fmt.Println(string(out))
default:
    return fmt.Errorf("unknown format %q — use table or json", outputFormat)
}
```

Ask: "Why would someone want JSON output?" (pipe to `jq`, use in a shell script, feed into another program)
Ask: "What is `jq`? Go look it up." (command-line JSON processor — `portfolio show --format json | jq '.[] | .Value'` would print all values)

---

## Add a version command

`cmd/version.go`:
```go
package cmd

import (
    "fmt"
    "github.com/spf13/cobra"
)

var Version = "dev" // overridden at build time

var versionCmd = &cobra.Command{
    Use:   "version",
    Short: "Print version information",
    Run: func(cmd *cobra.Command, args []string) {
        fmt.Printf("portfolio version %s\n", Version)
    },
}

func init() {
    rootCmd.AddCommand(versionCmd)
}
```

"To bake the version in at build time:"
```bash
go build -ldflags "-X portfolio/cmd.Version=1.0.0" -o portfolio .
./portfolio version
```

Ask: "What is `-ldflags`?" (linker flags — they modify values in the binary at link time, after compilation. Here we're setting a Go variable to a specific string.)
Ask: "Why not just hardcode the version string?" (you'd have to edit the code for every release. With ldflags, CI can inject the git tag automatically.)

---

## Build the binary

```bash
go build -o portfolio .
./portfolio show --wallet 0x...
```

"Now they have a real binary. They can move it to `/usr/local/bin/portfolio` and it works from anywhere."

```bash
sudo mv portfolio /usr/local/bin/
portfolio show --wallet 0x...
```

Moment of satisfaction: they typed `portfolio` with no `go run` and it just worked.

Ask: "What did `go build` produce? How is it different from `go run`?" (a compiled binary — no Go needed to run it. `go run` compiles and runs in one step but leaves no binary.)

---

## Docker — ship the CLI as a container

"You can run this binary on any Mac. But what about Linux? A server? Someone else's machine with no Go installed? That's what Docker is for."

"Write a Dockerfile for this CLI. What do you need?"

Let them try. Guide toward:

```dockerfile
FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o portfolio .

FROM alpine:latest
RUN apk add --no-cache ca-certificates
COPY --from=builder /app/portfolio /usr/local/bin/portfolio
ENTRYPOINT ["portfolio"]
```

Before showing each line, ask them:
- "Why do we copy `go.mod` and `go.sum` BEFORE copying the rest of the code?" (Docker caches layer by layer — if go.mod hasn't changed, `go mod download` is skipped on the next build. This makes rebuilds fast.)
- "Why `CGO_ENABLED=0 GOOS=linux`?" (cross-compile to a static Linux binary from Mac. `CGO_ENABLED=0` disables C dependencies so it runs in the minimal alpine image.)
- "Why `FROM alpine:latest` as a second stage?" (multi-stage build — the final image only has the binary, not the Go compiler or source code. Much smaller.)
- "What is `ENTRYPOINT` vs `CMD`?" (ENTRYPOINT: always runs, not replaceable. CMD: default args, replaceable. Using ENTRYPOINT means `docker run portfolio show` works — `portfolio` is the fixed command, `show` is the arg.)

Build and run it:
```bash
docker build -t portfolio .
docker run portfolio show --help
docker run portfolio show --wallet 0xABC
```

Ask: "What happened to the config file?" (it's gone — the container has no access to your home directory. To persist config, mount a volume: `docker run -v ~/.config/portfolio:/root/.config/portfolio portfolio show`)

Have them add the volume mount and verify config persists across `docker run` calls.

---

## Final milestone quiz — no notes

"Five questions. From memory. No notes. All of Project 5."

1. "Walk me through what happens when someone runs `portfolio show --wallet 0xABC`. Every step from the moment they press Enter."
   (shell finds the binary, passes args, cobra parses flags, RunE fires, config loaded, wallets merged, ethclient fetches balances, CoinGecko fetches prices, values computed, table printed, exit 0)

2. "What is the HTTP client timeout for and what happens if you don't set one?"
   (prevents hanging forever if the server is slow/down. Without it, the goroutine/program blocks indefinitely.)

3. "What's wrong with this error message: `error: request failed`? Write a better one for a failed CoinGecko request." (doesn't say what failed, why, or how to fix it. Better: `fetching prices from CoinGecko: request timed out after 10s — check your internet connection`)

4. "What file permissions should you use for a config file and why?" (0600 — owner read/write only. Config may contain API keys or wallet addresses.)

5. "What does `-ldflags "-X main.Version=1.2.3"` do?" (injects the string "1.2.3" into the `Version` variable at link time — no source code change needed per release)

---

## What they've learned in Project 5

Go concepts covered:
- `cobra` — subcommands, flags, `RunE`
- `net/http` as a client — `http.Client`, `http.NewRequestWithContext`, `resp.Body.Close()`
- HTTP vs network errors
- `os.ReadFile`, `os.WriteFile`, `os.MkdirAll`
- `os.UserConfigDir`, `filepath.Join`
- `errors.Is` for sentinel errors
- `text/tabwriter` for aligned output
- `encoding/json` — `json.MarshalIndent`, `json.NewDecoder`
- `context.Context` for cancellation
- `-ldflags` for version injection
- `httptest.NewServer` for testing HTTP clients

---

## Progress commands

```bash
go run tools/progress/main.go complete lesson_39_cli_wrapup
go run tools/progress/main.go set project6 lesson_40_grpc_what_and_why
go run tools/progress/main.go note "Project 5 done — cobra, HTTP client, file I/O all solid"
```

## Commit

```bash
git add .
git commit -m "Project 5 complete: polish, JSON output, version flag"
```
