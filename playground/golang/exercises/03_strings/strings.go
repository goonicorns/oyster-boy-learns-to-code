// Exercise 03: Strings
//
// GOAL: Complete the functions that work with strings.
//
// WHAT TO DO:
//   Fill in the TODO sections. Each one asks you to do something
//   with the "strings" package from Go's standard library.
//
// EXPECTED OUTPUT:
//   Original: "Hello, World!"
//   Uppercase: "HELLO, WORLD!"
//   Lowercase: "hello, world!"
//   Contains "World": true
//   Starts with "Hello": true
//   Replace "World" with "Go": "Hello, Go!"
//   Split on ",": [Hello  World!]
//   Length: 13 characters
//
// WHAT YOU'LL LEARN:
//   - Common string operations from the "strings" package
//   - How strings work in Go
//   - fmt.Sprintf for building strings with placeholders

package main

import (
	"fmt"
	"strings" // the "strings" package has lots of useful string functions
)

func main() {
	text := "Hello, World!"
	fmt.Printf("Original: %q\n", text)

	// ── strings.ToUpper / ToLower ─────────────────────────────────────────
	// These return a NEW string — they don't modify the original.
	// Strings in Go are immutable (can't be changed, only replaced).

	// TODO: Create "upper" by converting text to uppercase
	// upper := strings.ToUpper(???)
	upper := strings.ToUpper(text)
	fmt.Printf("Uppercase: %q\n", upper)

	// TODO: Create "lower" by converting text to lowercase
	lower := strings.ToLower(text)
	fmt.Printf("Lowercase: %q\n", lower)

	// ── strings.Contains ─────────────────────────────────────────────────
	// Returns true if the second string is found anywhere inside the first.

	// TODO: Check if text contains "World" — store the result in "hasWorld"
	// hasWorld := strings.Contains(???, ???)
	hasWorld := strings.Contains(text, "World")
	fmt.Printf("Contains \"World\": %t\n", hasWorld)

	// ── strings.HasPrefix ────────────────────────────────────────────────
	// Returns true if the string starts with the given prefix.

	// TODO: Check if text starts with "Hello"
	startsWithHello := strings.HasPrefix(text, "Hello")
	fmt.Printf("Starts with \"Hello\": %t\n", startsWithHello)

	// ── strings.ReplaceAll ────────────────────────────────────────────────
	// Replaces ALL occurrences of one substring with another.
	// Arguments: (original string, what to find, what to replace with)

	// TODO: Replace "World" with "Go" in text
	// replaced := strings.ReplaceAll(???, "World", "Go")
	replaced := strings.ReplaceAll(text, "World", "Go")
	fmt.Printf("Replace \"World\" with \"Go\": %q\n", replaced)

	// ── strings.Split ─────────────────────────────────────────────────────
	// Splits a string into a slice (list) of strings.
	// Arguments: (the string to split, what to split on)

	// TODO: Split text on "," (comma)
	// parts := strings.Split(???, ???)
	parts := strings.Split(text, ",")
	fmt.Printf("Split on \",\": %v\n", parts) // %v prints the slice in a readable way

	// ── len() ─────────────────────────────────────────────────────────────
	// len() returns the number of bytes in a string (for pure ASCII, this equals characters)

	// TODO: Get the length of "text" and store it in "length"
	length := len(text)
	fmt.Printf("Length: %d characters\n", length)
}
