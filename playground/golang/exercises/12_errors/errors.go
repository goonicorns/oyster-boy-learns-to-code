// Exercise 12: Error Handling
//
// GOAL: Write functions that return errors and handle them properly.
//
// BACKGROUND:
//   In Go, errors are just values — not exceptions that "throw."
//   A function that can fail returns (result, error).
//   The caller checks if error is nil (no error) before using the result.
//
//   This feels verbose at first. You'll write "if err != nil" a LOT.
//   But it makes bugs impossible to hide — you can't accidentally ignore an error.
//
//   nil means "nothing" — when error is nil, there's no error.
//
// EXPECTED OUTPUT:
//   10 / 2 = 5.00
//   Error: cannot divide by zero
//   Parsed "42" as: 42
//   Error: strconv.Atoi: parsing "banana": invalid syntax
//   User alice found: {alice alice@example.com}
//   Error: user "dave" not found
//
// WHAT YOU'LL LEARN:
//   - Returning errors from functions
//   - The (value, error) pattern
//   - errors.New() and fmt.Errorf()
//   - Checking err != nil

package main

import (
	"errors"
	"fmt"
	"strconv"
)

// divide divides a by b and returns the result.
// If b is 0, it returns 0 and an error.
//
// The return type (float64, error) means this function returns TWO things:
// the result (or 0 on failure) and an error (or nil on success).
func divide(a, b float64) (float64, error) {
	// TODO: If b is 0, return 0 and an error.
	// Create the error with: errors.New("cannot divide by zero")
	// Return zero AND the error: return 0, errors.New("cannot divide by zero")
	//
	// If b is not zero, return a/b and nil (nil = "no error")
	if b == 0 {
		return 0, errors.New("cannot divide by zero")
	}
	return a / b, nil
}

// parseNumber parses a string into an integer.
// If the string isn't a valid number, it returns 0 and an error.
//
// strconv.Atoi already does this — just call it and return its result.
// The function signature: strconv.Atoi(s string) (int, error)
func parseNumber(s string) (int, error) {
	// TODO: Call strconv.Atoi(s) and return whatever it returns
	// This is a one-liner: return strconv.Atoi(s)
	return strconv.Atoi(s)
}

// User represents a person in our system.
type User struct {
	Username string
	Email    string
}

// our fake "database" of users
var users = map[string]User{
	"alice": {Username: "alice", Email: "alice@example.com"},
	"bob":   {Username: "bob", Email: "bob@example.com"},
}

// findUser looks up a user by username.
// If not found, it returns an empty User and a descriptive error.
//
// fmt.Errorf works like fmt.Sprintf but creates an error instead of a string.
// Use %q to print a string with quotes around it: fmt.Errorf("user %q not found", username)
func findUser(username string) (User, error) {
	// TODO: Look up username in the users map (use the comma-ok pattern)
	// If it exists, return (user, nil)
	// If it doesn't, return (User{}, fmt.Errorf("user %q not found", username))
	user, ok := users[username]
	if !ok {
		return User{}, fmt.Errorf("user %q not found", username)
	}
	return user, nil
}

// ── You don't need to change anything below this line ──────────────

func main() {
	// Test divide
	result, err := divide(10, 2)
	if err != nil {
		fmt.Println("Error:", err)
	} else {
		fmt.Printf("10 / 2 = %.2f\n", result)
	}

	// Test divide by zero
	result, err = divide(5, 0)
	if err != nil {
		fmt.Println("Error:", err)
	} else {
		fmt.Printf("result: %.2f\n", result)
	}

	// Test parseNumber with a valid number
	num, err := parseNumber("42")
	if err != nil {
		fmt.Println("Error:", err)
	} else {
		fmt.Printf("Parsed \"42\" as: %d\n", num)
	}

	// Test parseNumber with an invalid string
	num, err = parseNumber("banana")
	if err != nil {
		fmt.Println("Error:", err)
	} else {
		fmt.Printf("Parsed as: %d\n", num)
	}

	// Test findUser with an existing user
	user, err := findUser("alice")
	if err != nil {
		fmt.Println("Error:", err)
	} else {
		fmt.Printf("User alice found: %+v\n", user) // %+v prints struct with field names
	}

	// Test findUser with a missing user
	user, err = findUser("dave")
	if err != nil {
		fmt.Println("Error:", err)
	} else {
		fmt.Printf("User found: %+v\n", user)
	}
}
