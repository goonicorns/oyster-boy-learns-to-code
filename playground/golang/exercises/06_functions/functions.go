// Exercise 06: Functions
//
// GOAL: Write the function bodies from scratch.
//
// BACKGROUND:
//   In Go, functions are defined with "func".
//   Functions can return multiple values — this is used constantly for (result, error).
//   The underscore _ is used to discard a return value you don't need.
//
// EXPECTED OUTPUT:
//   Area of 5x3 rectangle: 15.00
//   Min of 7 and 3: 3
//   Max of 7 and 3: 7
//   Swap of (hello, world): world, hello
//   Is 7 prime? true
//   Is 9 prime? false
//   Is 13 prime? true
//
// WHAT YOU'LL LEARN:
//   - Writing functions
//   - Multiple return values
//   - Named return values
//   - Using _ to ignore values you don't need

package main

import "fmt"

// area returns the area of a rectangle.
// Takes width and height as float64, returns a float64.
func area(width, height float64) float64 {
	// TODO: return width multiplied by height
	return width * height
}

// minMax returns both the minimum AND the maximum of two integers.
// This shows Go's ability to return multiple values — no need for a special struct.
func minMax(a, b int) (int, int) {
	// TODO: Return (the smaller one, the larger one)
	// Hint: use an if/else
	if a < b {
		return a, b
	}
	return b, a
}

// swap takes two strings and returns them in REVERSED order.
// Example: swap("hello", "world") returns ("world", "hello")
func swap(a, b string) (string, string) {
	// TODO: return b first, then a
	return b, a
}

// isPrime returns true if n is a prime number, false otherwise.
// A prime number is only divisible by 1 and itself.
// Examples: 2, 3, 5, 7, 11, 13 are prime. 4, 6, 8, 9 are not.
//
// Algorithm:
//   - Numbers less than 2 are not prime
//   - Check if any number from 2 up to n-1 divides evenly into n
//   - If any do, it's not prime
//   - If none do, it is prime
func isPrime(n int) bool {
	// TODO: implement the prime check
	// Hint:
	//   if n < 2 { return false }
	//   for i := 2; i < n; i++ {
	//       if n % i == 0 { return false }  // % = remainder (0 means evenly divisible)
	//   }
	//   return true
	if n < 2 {
		return false
	}
	for i := 2; i < n; i++ {
		if n%i == 0 {
			return false
		}
	}
	return true
}

// ── You don't need to change anything below this line ──────────────

func main() {
	fmt.Printf("Area of 5x3 rectangle: %.2f\n", area(5, 3))

	min, max := minMax(7, 3)
	fmt.Printf("Min of 7 and 3: %d\n", min)
	fmt.Printf("Max of 7 and 3: %d\n", max)

	first, second := swap("hello", "world")
	fmt.Printf("Swap of (hello, world): %s, %s\n", first, second)

	for _, n := range []int{7, 9, 13} {
		fmt.Printf("Is %d prime? %t\n", n, isPrime(n))
	}
}
