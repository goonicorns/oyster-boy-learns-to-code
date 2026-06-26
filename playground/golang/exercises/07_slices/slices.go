// Exercise 07: Slices — Ordered Lists
//
// GOAL: Complete the functions that work with slices.
//
// BACKGROUND:
//   A slice is like a resizable list. You can add items, remove them,
//   access them by position, and loop over them.
//   Index starts at 0 — so the first item is at [0], not [1].
//
// EXPECTED OUTPUT:
//   First item: apple
//   Last item: elderberry
//   After adding kiwi: [apple banana cherry date elderberry kiwi]
//   Middle slice [1:4]: [banana cherry date]
//   Total score: 450
//   Average score: 90.00
//
// WHAT YOU'LL LEARN:
//   - Creating slices
//   - Accessing elements by index
//   - append() to add elements
//   - Slicing a slice (getting a sub-slice)
//   - len() for length
//   - Looping with range

package main

import "fmt"

func main() {
	// ── Creating a slice ────────────────────────────────────────────────
	// The [] before the type is what makes it a slice (a list of things)
	// []string = a list of strings
	fruits := []string{"apple", "banana", "cherry", "date", "elderberry"}

	// ── Accessing elements ───────────────────────────────────────────────
	// Indexing starts at 0. The first element is [0].

	// TODO: Print the first item (at index 0)
	fmt.Printf("First item: %s\n", fruits[0])

	// TODO: Print the last item
	// Hint: the last index is len(fruits) - 1
	fmt.Printf("Last item: %s\n", fruits[len(fruits)-1])

	// ── append() ─────────────────────────────────────────────────────────
	// append() adds an item to the end of a slice.
	// IMPORTANT: append returns a NEW slice — you must assign the result back.
	// fruits = append(fruits, "kiwi") — this is the pattern

	// TODO: Add "kiwi" to the fruits slice using append
	fruits = append(fruits, "kiwi")
	fmt.Printf("After adding kiwi: %v\n", fruits) // %v prints a slice nicely

	// ── Sub-slices (slicing a slice) ─────────────────────────────────────
	// fruits[start:end] gives you elements from index "start" up to (not including) "end"
	// Example: fruits[1:4] gives you elements at index 1, 2, and 3

	// TODO: Get a sub-slice containing items at index 1, 2, and 3
	// middle := fruits[???:???]
	middle := fruits[1:4]
	fmt.Printf("Middle slice [1:4]: %v\n", middle)

	// ── Working with a slice of numbers ──────────────────────────────────
	scores := []int{85, 92, 78, 95, 100}

	// TODO: Calculate the total of all scores by looping with range
	// Use: for _, score := range scores { total += score }
	total := 0
	for _, score := range scores {
		total += score
	}
	fmt.Printf("Total score: %d\n", total)

	// TODO: Calculate the average (total divided by the count)
	// len(scores) gives you how many items are in the slice
	// Note: for float division, convert to float64 first
	average := float64(total) / float64(len(scores))
	fmt.Printf("Average score: %.2f\n", average)
}
