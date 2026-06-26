// Exercise 01: Variables
//
// GOAL: Make this program compile and print the correct output.
//
// WHAT TO DO:
//   Look for the lines that say "TODO" — those are the ones you need to fix.
//   Fill in the blanks to declare variables with the right values.
//
// EXPECTED OUTPUT (exactly this):
//   My name is Alice and I am 28 years old.
//   I live in Tokyo.
//   Today is sunny: true
//
// WHAT YOU'LL LEARN:
//   - How to declare variables with var and :=
//   - The difference between the two styles
//   - What string, int, and bool types are
//   - How fmt.Printf formats output with placeholders

package main

import "fmt"

func main() {
	// ── Long form variable declaration ──────────────────────────────────
	// "var" says we're declaring a variable.
	// Then the name, then the type, then = the value.
	// Type "string" means text. Type "int" means a whole number.

	// TODO: Declare a variable called "name" of type string with the value "Alice"
	// var name string = ???
	var name string = "Alice"

	// TODO: Declare a variable called "age" of type int with the value 28
	// var age int = ???
	var age int = 28

	// ── Short form declaration ───────────────────────────────────────────
	// The := operator is a shortcut: it declares AND assigns at the same time.
	// Go figures out the type from whatever you assign to it.
	// Use this style most of the time — it's the common Go way.

	// TODO: Use := to declare a "city" variable with the value "Tokyo"
	// city := ???
	city := "Tokyo"

	// TODO: Use := to declare an "isSunny" variable with the value true
	// (bool = boolean, only true or false)
	// isSunny := ???
	isSunny := true

	// ── Printing ─────────────────────────────────────────────────────────
	// fmt.Printf lets you use placeholders in text:
	//   %s = a string (text)
	//   %d = an integer (whole number)
	//   %t = a boolean (true or false)
	//   \n = a newline (go to the next line)
	fmt.Printf("My name is %s and I am %d years old.\n", name, age)
	fmt.Printf("I live in %s.\n", city)
	fmt.Printf("Today is sunny: %t\n", isSunny)
}
