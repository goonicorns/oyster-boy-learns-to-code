// Exercise 13: Goroutines — Doing Things Concurrently
//
// GOAL: Use goroutines and a WaitGroup to run tasks in parallel.
//
// BACKGROUND:
//   A goroutine is a lightweight "thread" — a function running independently.
//   The "go" keyword starts a goroutine: go myFunction()
//
//   The main() function is also a goroutine. When main() finishes,
//   ALL other goroutines stop too — even if they're not done.
//   So we use sync.WaitGroup to wait for goroutines to finish.
//
//   WaitGroup usage:
//     wg.Add(1)      — before starting a goroutine: "one more to wait for"
//     defer wg.Done() — inside the goroutine, when it finishes: "I'm done"
//     wg.Wait()      — in main: "wait here until everyone calls Done()"
//
// EXPECTED OUTPUT (order may vary because goroutines run concurrently):
//   Worker 1 starting...
//   Worker 2 starting...
//   Worker 3 starting...
//   Worker 1 done
//   Worker 2 done
//   Worker 3 done
//   All workers finished!
//   Results: [1 4 9]   (1², 2², 3²)
//
// WHAT YOU'LL LEARN:
//   - Starting goroutines with "go"
//   - sync.WaitGroup to wait for goroutines
//   - Channels to collect results from goroutines
//   - Why you pass loop variables as arguments (closure gotcha)

package main

import (
	"fmt"
	"sync"
)

// worker simulates a task running concurrently.
// It prints a start message, does some "work" (in real code this would be I/O, HTTP, etc.),
// then prints a done message.
//
// Parameters:
//   id  — the worker's number (for printing)
//   wg  — pointer to the WaitGroup so we can call Done() when finished
func worker(id int, wg *sync.WaitGroup) {
	// defer means "run this at the very end of the function, no matter what"
	// This ensures Done() is always called, even if the function returns early
	defer wg.Done()

	fmt.Printf("Worker %d starting...\n", id)

	// In real code, this is where actual work would happen:
	// making an HTTP request, reading a file, querying a database, etc.
	// Here we just print something to show it ran.

	fmt.Printf("Worker %d done\n", id)
}

// squareAll takes a slice of numbers and returns a new slice
// where each number has been squared (n²), using goroutines.
//
// It uses a channel to collect results from each goroutine.
func squareAll(numbers []int) []int {
	// A channel is a typed pipe for sending values between goroutines.
	// make(chan int, n) creates a buffered channel that can hold n values.
	// We make it the same size as our input so goroutines don't block while sending.
	results := make(chan int, len(numbers))

	// Start one goroutine per number
	for _, n := range numbers {
		// IMPORTANT: pass n as an argument, don't capture it directly.
		// If you write "go func() { results <- n * n }()", all goroutines
		// might use the same final value of n. Passing it as an argument
		// gives each goroutine its own copy.
		go func(num int) {
			results <- num * num // send n² into the channel
		}(n) // pass n here as an argument to the goroutine
	}

	// Collect all results from the channel
	squares := make([]int, len(numbers))
	for i := range numbers {
		squares[i] = <-results // receive one value from the channel
	}

	return squares
}

// ── You don't need to change anything below this line ──────────────

func main() {
	// Part 1: Run 3 workers concurrently with WaitGroup
	var wg sync.WaitGroup

	for i := 1; i <= 3; i++ {
		wg.Add(1) // tell the WaitGroup: one more goroutine is about to start

		// TODO: Start a goroutine that calls worker(i, &wg)
		// The & before wg means "give the goroutine a pointer to wg" so it can call Done()
		// Hint: go worker(i, &wg)
		// BUT: you need to capture i correctly — pass it as an argument
		go func(workerID int) {
			worker(workerID, &wg)
		}(i)
	}

	wg.Wait() // wait here until all 3 workers have called wg.Done()
	fmt.Println("All workers finished!")

	// Part 2: Use goroutines with a channel to compute squares
	numbers := []int{1, 2, 3}
	squares := squareAll(numbers)
	fmt.Printf("Results: %v\n", squares)
}
