# Lesson 41: Protocol Buffers and Code Generation

**For Claude — do not show this file to the learner**

---

## Context for Claude

They define the `.proto` schema for the price feed service, install the protobuf compiler, and generate Go code. The key insight is that generated code is a contract — both the client and server are guaranteed to agree on types. Make them read the generated code before using it.

**This lesson's goal:**
- Write a real `.proto` file with messages and a service definition
- Install `protoc` and the Go plugins
- Generate Go code and read it
- Understand what was generated and why

---

## Install the toolchain

```bash
# Install protoc (the protobuf compiler)
brew install protobuf

# Install Go plugins
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

# Verify
protoc --version
```

"You'll need protoc in your PATH. If it's not found after installing, check `brew info protobuf` for the path."

---

## Project setup

```bash
mkdir ~/projects/pricefeed
cd ~/projects/pricefeed
go mod init pricefeed
go get google.golang.org/grpc
go get google.golang.org/protobuf
```

Structure:
```
pricefeed/
  proto/
    prices.proto          — the schema definition
  gen/
    prices/
      prices.pb.go        — generated message types
      prices_grpc.pb.go   — generated server/client interfaces
  server/
    main.go               — gRPC server
  client/
    main.go               — gRPC client
  internal/
    fetcher/
      coingecko.go        — price fetching (from Project 5)
```

---

## Write the .proto file

`proto/prices.proto`:

```protobuf
syntax = "proto3";

package prices;

option go_package = "pricefeed/gen/prices";

// A request to get the current price of a single token
message PriceRequest {
  string symbol = 1;  // e.g. "ETH", "BTC", "USDC"
}

// A price at a point in time
message PriceResponse {
  string symbol    = 1;
  double price_usd = 2;
  int64  timestamp = 3;  // Unix timestamp
}

// A request to stream prices for multiple tokens
message StreamRequest {
  repeated string symbols         = 1;  // e.g. ["ETH", "BTC"]
  int32           interval_seconds = 2;  // how often to push updates
}

// The service definition
service PriceFeed {
  // Unary: get the current price of one token
  rpc GetPrice(PriceRequest) returns (PriceResponse);

  // Server streaming: push price updates at regular intervals
  rpc StreamPrices(StreamRequest) returns (stream PriceResponse);
}
```

Walk through every line:

- "What is `syntax = "proto3"`?" (protobuf version — proto3 is the current standard, simpler than proto2)
- "What is `option go_package`?" (tells protoc where to put the generated Go package)
- "What is `repeated`?" (a list — `repeated string symbols` generates `[]string` in Go)
- "What is a `service`?" (defines the RPC methods — this is what gRPC implements)
- "What does `returns (stream PriceResponse)` mean?" (the server sends multiple PriceResponse messages, not just one)
- "Why numbers after each field name?" (field numbers — used in binary serialization. Once set, NEVER change them or old clients break.)

Ask: "What would `client streaming` look like in the proto syntax?" (`rpc Upload(stream PriceRequest) returns (PriceResponse)`)
Ask: "What would bidirectional look like?" (`rpc Chat(stream Message) returns (stream Message)`)

---

## Generate the Go code

```bash
protoc \
  --go_out=. \
  --go_opt=paths=source_relative \
  --go-grpc_out=. \
  --go-grpc_opt=paths=source_relative \
  proto/prices.proto
```

"This generates two files:
- `prices.pb.go` — the Go structs for your messages (PriceRequest, PriceResponse, StreamRequest)
- `prices_grpc.pb.go` — the interfaces and stubs for the service"

**Make them read both files.** Not the whole thing, but the key parts:

In `prices_grpc.pb.go`:
```go
// PriceFeedServer is the interface you must implement on the server
type PriceFeedServer interface {
    GetPrice(context.Context, *PriceRequest) (*PriceResponse, error)
    StreamPrices(*StreamRequest, PriceFeed_StreamPricesServer) error
    mustEmbedUnimplementedPriceFeedServer()
}
```

Ask: "What is `PriceFeedServer`?" (the interface your server must implement — if you don't implement all methods, your code won't compile)
Ask: "What is `PriceFeed_StreamPricesServer`?" (an interface representing the stream — you call `Send(*PriceResponse)` on it to push messages to the client)

In `prices.pb.go`:
```go
type PriceRequest struct {
    Symbol string `protobuf:"bytes,1,opt,name=symbol,proto3" json:"symbol,omitempty"`
    // ...
}
```

Ask: "What do those struct tags mean?" (protobuf uses them for serialization; they're also valid JSON tags so you can serialize protobufs as JSON if needed)

---

## Add to Makefile for convenience

`Makefile`:
```makefile
.PHONY: proto
proto:
	protoc \
		--go_out=. \
		--go_opt=paths=source_relative \
		--go-grpc_out=. \
		--go-grpc_opt=paths=source_relative \
		proto/prices.proto
```

Ask: "What is a Makefile?" (a file that defines commands you can run with `make proto` — a convention for documenting and automating project tasks. The generated Go files should be committed to git — not regenerated by teammates unless they change the proto.)

---

## Checkpoint

1. "What is the difference between `prices.pb.go` and `prices_grpc.pb.go`?"
2. "What does `repeated` map to in Go?"
3. "What is a field number in protobuf? Why can't you change it once deployed?"
4. "What interface must your server implement? Where is it defined?"
5. "What does `PriceFeed_StreamPricesServer.Send()` do?"
6. "Write the proto syntax for a bidirectional streaming method called `Trade`." (`rpc Trade(stream Order) returns (stream Fill);`)

---

## Commit

```bash
git add .
git commit -m "Define price feed proto schema and generate Go code"
```
