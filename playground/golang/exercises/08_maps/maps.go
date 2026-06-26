// Exercise 08: Maps — Key-Value Storage
//
// GOAL: Complete the functions that use maps.
//
// BACKGROUND:
//   A map is a lookup table — you give it a key, it gives you a value.
//   Like a dictionary: you look up a word (key) to get a definition (value).
//   Keys must be unique. Values can repeat.
//
//   IMPORTANT: Always check if a key exists before using its value.
//   If you look up a missing key, Go gives you the zero value (0, "", false)
//   — not an error. This can cause silent bugs if you're not careful.
//
// EXPECTED OUTPUT:
//   Alice's age: 30
//   Bob is in the map: true
//   Dave is in the map: false
//   After deleting Bob: map[Alice:30 Charlie:35]
//   Word count of "the cat sat on the mat":
//     the: 2
//     cat: 1
//     sat: 1
//     on: 1
//     mat: 1
//
// WHAT YOU'LL LEARN:
//   - Creating maps
//   - Adding, reading, deleting entries
//   - Checking if a key exists (the comma-ok pattern)
//   - Counting things with maps

package main

import (
	"fmt"
	"strings"
)

func main() {
	// ── Creating a map with initial values ───────────────────────────────
	// map[KeyType]ValueType{key: value, key: value, ...}
	ages := map[string]int{
		"Alice":   30,
		"Bob":     25,
		"Charlie": 35,
	}

	// ── Reading a value ──────────────────────────────────────────────────
	// TODO: Print Alice's age from the map
	fmt.Printf("Alice's age: %d\n", ages["Alice"])

	// ── The comma-ok pattern — safely checking if a key exists ───────────
	// When you read a map, you can get TWO values: the value AND a bool.
	// The bool is true if the key exists, false if it doesn't.
	// Pattern: value, ok := myMap["key"]
	//          if !ok { ... handle missing key ... }

	// TODO: Check if "Bob" is in the map using the comma-ok pattern
	// _, bobExists := ages[???]
	_, bobExists := ages["Bob"]
	fmt.Printf("Bob is in the map: %t\n", bobExists)

	// TODO: Check if "Dave" is in the map
	_, daveExists := ages["Dave"]
	fmt.Printf("Dave is in the map: %t\n", daveExists)

	// ── Deleting a key ───────────────────────────────────────────────────
	// delete(map, key) removes a key from the map
	// It's safe to delete a key that doesn't exist — no error

	// TODO: Delete "Bob" from the ages map
	delete(ages, "Bob")
	fmt.Printf("After deleting Bob: %v\n", ages)

	// ── Counting with maps ────────────────────────────────────────────────
	// A common pattern: use a map to count how many times things appear
	sentence := "the cat sat on the mat"
	words := strings.Split(sentence, " ") // Split the sentence into individual words

	// Create an empty map to store word counts
	// map[string]int = keys are strings (words), values are ints (counts)
	wordCount := make(map[string]int) // make() initializes an empty map

	// TODO: Loop over the words slice and count each word
	// For each word, do: wordCount[word]++
	// (If the key doesn't exist yet, Go creates it with value 0, then adds 1)
	for _, word := range words {
		wordCount[word]++
	}

	fmt.Printf("Word count of %q:\n", sentence)
	// Loop over the map and print each word and its count
	for word, count := range wordCount {
		fmt.Printf("  %s: %d\n", word, count)
	}
	// Note: map iteration order is random in Go — your output may be in different order
}
