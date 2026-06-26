// Exercise 02: Types and Type Conversion
//
// GOAL: Fix the compile errors by converting between types correctly.
//
// BACKGROUND:
//   Go is strict about types. You can't add a string and a number.
//   You can't put a float into an int without explicitly converting it.
//   This feels annoying at first, but it prevents a huge class of bugs.
//
// WHAT TO DO:
//   This file has compile errors. Fix them using type conversions.
//   The comments explain what each conversion should look like.
//
// EXPECTED OUTPUT:
//   An integer: 42
//   As a float: 42.000000
//   Sum of two floats: 7.500000
//   A string from a number: "The answer is 42"
//
// WHAT YOU'LL LEARN:
//   - Go's basic types: int, float64, string, bool
//   - How to convert between types explicitly
//   - Why Go doesn't let you mix types without converting

package main

import (
	"fmt"
	"strconv" // strconv = "string conversion" — has functions to convert between strings and numbers
)

func main() {
	// ── Integers ──────────────────────────────────────────────────────────
	// int = whole numbers. No decimal point. Can be negative.
	var wholeNumber int = 42
	fmt.Printf("An integer: %d\n", wholeNumber)

	// ── Converting int to float64 ─────────────────────────────────────────
	// float64 = numbers with a decimal point. "64" means 64 bits of precision.
	// Go will NOT automatically convert int to float64 for you.
	// You must wrap it in float64(...) to do the conversion explicitly.

	// TODO: This line has a type error. Fix it by converting wholeNumber to float64.
	// Hint: asFloat := float64(wholeNumber)
	var asFloat float64 = float64(wholeNumber) // fix this line
	fmt.Printf("As a float: %f\n", asFloat)

	// ── Math with different number types ─────────────────────────────────
	// You cannot add an int and a float64 directly. Both must be the same type.
	var a float64 = 3.0
	var b float64 = 4.5

	// This is fine — both are float64
	sum := a + b
	fmt.Printf("Sum of two floats: %f\n", sum)

	// ── Converting a number to a string ──────────────────────────────────
	// strconv.Itoa converts an int to a string ("Itoa" = "Integer to ASCII")
	// You cannot just do string(42) — that gives you a Unicode character, not "42"

	// TODO: Use strconv.Itoa to convert wholeNumber to a string called "numAsString"
	// numAsString := strconv.Itoa(???)
	numAsString := strconv.Itoa(wholeNumber)

	// String concatenation uses the + operator
	message := "The answer is " + numAsString
	fmt.Printf("A string from a number: %q\n", message) // %q prints with quotes around it
}
