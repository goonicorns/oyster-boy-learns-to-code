# Lesson 42: gRPC Server, Client, and Streaming

**For Claude — do not show this file to the learner**

---

## Context for Claude

They implement both the gRPC server and a Go client. The unary method first (GetPrice), then the streaming method (StreamPrices). The key moments: the server implements the generated interface, the client uses the generated stub, and the streaming loop shows them how different this is from REST.

**This lesson's goal:**
- Implement the PriceFeedServer interface
- Start a gRPC server on a TCP port
- Write a Go client that connects and calls both methods
- Implement server streaming: push prices in a loop
- See the difference between unary and streaming in practice

---

## Implement the server

`server/main.go`:

```go
package main

import (
    "context"
    "fmt"
    "log"
    "net"
    "time"

    "google.golang.org/grpc"
    "google.golang.org/grpc/reflection"

    pb "pricefeed/gen/prices"
    "pricefeed/internal/fetcher"
)

// priceFeedServer implements the generated pb.PriceFeedServer interface
type priceFeedServer struct {
    pb.UnimplementedPriceFeedServer // embed this — required by generated code
    fetcher *fetcher.Client
}

// GetPrice handles unary requests
func (s *priceFeedServer) GetPrice(ctx context.Context, req *pb.PriceRequest) (*pb.PriceResponse, error) {
    if req.Symbol == "" {
        return nil, fmt.Errorf("symbol is required")
    }

    prices, err := s.fetcher.Prices(ctx, []string{req.Symbol})
    if err != nil {
        return nil, fmt.Errorf("fetching price: %w", err)
    }

    price, ok := prices[req.Symbol]
    if !ok {
        return nil, fmt.Errorf("unknown symbol: %s", req.Symbol)
    }

    return &pb.PriceResponse{
        Symbol:    req.Symbol,
        PriceUsd:  price,
        Timestamp: time.Now().Unix(),
    }, nil
}

// StreamPrices handles server-streaming requests
func (s *priceFeedServer) StreamPrices(req *pb.StreamRequest, stream pb.PriceFeed_StreamPricesServer) error {
    interval := time.Duration(req.IntervalSeconds) * time.Second
    if interval < time.Second {
        interval = time.Second
    }

    ticker := time.NewTicker(interval)
    defer ticker.Stop()

    for {
        select {
        case <-stream.Context().Done():
            // Client disconnected or cancelled
            return stream.Context().Err()

        case <-ticker.C:
            prices, err := s.fetcher.Prices(stream.Context(), req.Symbols)
            if err != nil {
                return fmt.Errorf("fetching prices: %w", err)
            }

            for symbol, price := range prices {
                if err := stream.Send(&pb.PriceResponse{
                    Symbol:    symbol,
                    PriceUsd:  price,
                    Timestamp: time.Now().Unix(),
                }); err != nil {
                    return err // client went away
                }
            }
        }
    }
}

func main() {
    lis, err := net.Listen("tcp", ":50051")
    if err != nil {
        log.Fatalf("failed to listen: %v", err)
    }

    grpcServer := grpc.NewServer()
    pb.RegisterPriceFeedServer(grpcServer, &priceFeedServer{
        fetcher: fetcher.NewClient(),
    })

    // Enable reflection — lets grpcurl and other tools inspect the API
    reflection.Register(grpcServer)

    log.Println("gRPC server listening on :50051")
    if err := grpcServer.Serve(lis); err != nil {
        log.Fatalf("failed to serve: %v", err)
    }
}
```

Walk through with questions:

- "What is `pb.UnimplementedPriceFeedServer`?" (a generated struct that returns 'not implemented' for all methods — embedding it means if you forget to implement a method, you get a runtime error instead of a compile error. Go requires you embed it.)
- "In `StreamPrices`, why are there no HTTP status codes, no `w.Write`, no headers?" (gRPC abstracts all that — you just call `stream.Send()` and the framework handles framing, flow control, and delivery)
- "What does `stream.Context().Done()` tell you?" (the client disconnected or cancelled — if you don't check this, your goroutine leaks forever sending to nobody)
- "What is `time.NewTicker`?" (fires on a channel at regular intervals — same pattern as the chat server's ping/pong ticker)
- "What is gRPC reflection?" (a service that describes your API at runtime — tools like `grpcurl` use it to discover methods without needing the proto file)

Ask: "In the streaming loop, why do we check `stream.Context().Done()` in the select?" (if we only checked the ticker, we'd never notice the client leaving. The select waits for whichever happens first.)

---

## Write the client

`client/main.go`:

```go
package main

import (
    "context"
    "fmt"
    "io"
    "log"
    "time"

    "google.golang.org/grpc"
    "google.golang.org/grpc/credentials/insecure"

    pb "pricefeed/gen/prices"
)

func main() {
    // Connect (insecure for local dev — use TLS in production)
    conn, err := grpc.Dial("localhost:50051",
        grpc.WithTransportCredentials(insecure.NewCredentials()),
    )
    if err != nil {
        log.Fatalf("connecting: %v", err)
    }
    defer conn.Close()

    client := pb.NewPriceFeedClient(conn)

    // --- Unary: get one price ---
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    resp, err := client.GetPrice(ctx, &pb.PriceRequest{Symbol: "ETH"})
    if err != nil {
        log.Fatalf("GetPrice: %v", err)
    }
    fmt.Printf("ETH: $%.2f (at %d)\n", resp.PriceUsd, resp.Timestamp)

    // --- Server streaming: watch prices ---
    streamCtx, streamCancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer streamCancel()

    stream, err := client.StreamPrices(streamCtx, &pb.StreamRequest{
        Symbols:         []string{"ETH", "USDC", "LINK"},
        IntervalSeconds: 5,
    })
    if err != nil {
        log.Fatalf("StreamPrices: %v", err)
    }

    fmt.Println("\nLive prices (updates every 5s, 30s total):")
    for {
        update, err := stream.Recv()
        if err == io.EOF {
            fmt.Println("Stream ended.")
            break
        }
        if err != nil {
            log.Fatalf("stream error: %v", err)
        }
        fmt.Printf("[%s] %s: $%.2f\n",
            time.Unix(update.Timestamp, 0).Format("15:04:05"),
            update.Symbol,
            update.PriceUsd,
        )
    }
}
```

Ask:
- "What is `grpc.WithTransportCredentials(insecure.NewCredentials())`?" (disables TLS — fine for localhost, never for production)
- "What is `context.WithTimeout`?" (gives the context a deadline — if GetPrice takes longer than 5s, it's cancelled and returns an error)
- "In the streaming loop, what does `io.EOF` mean?" (the server closed the stream normally — no error, just done)
- "What's the difference between `stream.Recv()` erroring with `io.EOF` vs a real error?" (io.EOF = clean stream end; any other error = something broke)
- "How would you make the client run forever instead of stopping after 30 seconds?" (use `context.Background()` instead of `WithTimeout`)

---

## Test it with grpcurl

Install: `brew install grpcurl`

```bash
# Start the server in one terminal
go run server/main.go

# In another terminal:
grpcurl -plaintext localhost:50051 list
grpcurl -plaintext localhost:50051 prices.PriceFeed/GetPrice '{"symbol": "ETH"}'
```

Ask: "What is `grpcurl`?" (curl for gRPC — makes requests without writing Go code. Needs reflection to discover methods.)
Ask: "What does `list` show?" (all services registered on this server)

---

## Checkpoint

1. "Why must you embed `UnimplementedPriceFeedServer` in your server struct?"
2. "In the streaming server, what does `stream.Context().Done()` signal? What happens if you don't check it?"
3. "What does `stream.Recv()` return when the stream ends normally?"
4. "Why do we use `context.WithTimeout` for the unary call but not necessarily for streaming?"
5. "What is gRPC reflection for?"
6. "Compare: REST polling every 5 seconds vs gRPC server streaming for live prices. Which uses fewer connections? Why?"

---

## Commit

```bash
git add .
git commit -m "Implement gRPC server and client with unary and streaming price feed"
```
