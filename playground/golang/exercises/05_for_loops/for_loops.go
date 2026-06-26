// Exercise 05: For Loops
//
// GOAL: Complete the functions below using different styles of for loops.
//
// BACKGROUND:
//   Go has only ONE looping keyword: "for"
//   But it can be used in three different ways:
//     1. Classic: for i := 0; i < n; i++ { ... }
//     2. While-style: for condition { ... }
//     3. Range: for i, value := range collection { ... }
//
// EXPECTED OUTPUT:
//   Countdown: 5 4 3 2 1 Liftoff!
//   Sum 1 to 10: 55
//   Fruits: apple banana cherry
//   Even numbers under 20: 0 2 4 6 8 10 12 14 16 18
//
// WHAT YOU'LL LEARN:
//   - All three forms of for loops
//   - range over slices
//   - break and continue

package main

import "fmt"

// countdown prints numbers from n down to 1, then "Liftoff!"
func countdown(n int) {
	// TODO: Use a classic for loop counting DOWN from n to 1
	// Hint:
	//   for i := n; i >= 1; i-- {
	//       fmt.Printf("%d ", i)
	//   }
	for i := n; i >= 1; i-- {
		fmt.Printf("%d ", i)
	}
	fmt.Println("Liftoff!")
}

// sumUpTo returns the sum of all integers from 1 to n (inclusive).
// Example: sumUpTo(3) = 1 + 2 + 3 = 6
func sumUpTo(n int) int {
	// TODO: Use a loop to add up all numbers from 1 to n
	// Start with total := 0, then add each number to it, then return total
	total := 0
	for i := 1; i <= n; i++ {
		total += i // same as: total = total + i
	}
	return total
}

// printFruits prints each fruit in the slice on the same line, separated by spaces
func printFruits(fruits []string) {
	// TODO: Use "for _, fruit := range fruits" to loop over the slice
	// Print each fruit with a space after it
	for _, fruit := range fruits {
		fmt.Printf("%s ", fruit)
	}
	fmt.Println() // print a newline at the end
}

// printEvens prints all even numbers from 0 up to (not including) n
// An even number is divisible by 2 — no remainder: n % 2 == 0
// (% is the modulo operator — it gives you the remainder of division)
func printEvens(n int) {
	// TODO: Use a for loop and the "continue" keyword
	// Loop through 0 to n-1. If a number is ODD (i % 2 != 0), "continue" to skip it.
	// If it's even, print it.
	for i := 0; i < n; i++ {
		if i%2 != 0 {
			continue // skip odd numbers — jump to the next iteration
		}
		fmt.Printf("%d ", i)
	}
	fmt.Println()
}

// ── You don't need to change anything below this line ──────────────

func main() {
	fmt.Print("Countdown: ")
	countdown(5)

	fmt.Printf("Sum 1 to 10: %d\n", sumUpTo(10))

	fmt.Print("Fruits: ")
	printFruits([]string{"apple", "banana", "cherry"})

	fmt.Print("Even numbers under 20: ")
	printEvens(20)
}
