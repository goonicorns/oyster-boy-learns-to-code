// Exercise 09: Structs — Grouping Related Data
//
// GOAL: Define a struct and create instances of it.
//
// BACKGROUND:
//   A struct lets you group related pieces of data under one name.
//   Instead of having separate variables for a person's name, age, and email,
//   you put them all in one struct called Person.
//
//   This is Go's version of an "object" — but without all the complicated
//   inheritance and class stuff from other languages.
//
// EXPECTED OUTPUT:
//   Name: Alice
//   Email: alice@example.com
//   Age: 30
//   Is admin: true
//   ---
//   Name: Bob
//   Email: bob@example.com
//   Age: 25
//   Is admin: false
//   ---
//   Older person: Alice
//
// WHAT YOU'LL LEARN:
//   - Defining a struct type
//   - Creating struct instances
//   - Accessing fields with dot notation
//   - Passing structs to functions

package main

import "fmt"

// TODO: Define a struct type called "User"
// It should have these fields:
//   Name  (string)
//   Email (string)
//   Age   (int)
//   Admin (bool)
//
// Syntax:
//   type User struct {
//       FieldName  FieldType
//       ...
//   }
type User struct {
	Name  string
	Email string
	Age   int
	Admin bool
}

// printUser prints the details of a User in a readable format.
// It takes a User (not a pointer — just a copy of the struct).
func printUser(u User) {
	// TODO: Print each field using fmt.Printf
	// Access fields with a dot: u.Name, u.Email, u.Age, u.Admin
	fmt.Printf("Name: %s\n", u.Name)
	fmt.Printf("Email: %s\n", u.Email)
	fmt.Printf("Age: %d\n", u.Age)
	fmt.Printf("Is admin: %t\n", u.Admin)
	fmt.Println("---")
}

// olderUser returns the user with the greater age.
// If they're the same age, return the first one.
func olderUser(a, b User) User {
	// TODO: Compare a.Age and b.Age, return the older one
	if a.Age >= b.Age {
		return a
	}
	return b
}

func main() {
	// TODO: Create a User variable called "alice" with:
	//   Name:  "Alice"
	//   Email: "alice@example.com"
	//   Age:   30
	//   Admin: true
	//
	// Syntax:
	//   alice := User{
	//       Name:  "Alice",
	//       Email: "alice@example.com",
	//       ...
	//   }
	alice := User{
		Name:  "Alice",
		Email: "alice@example.com",
		Age:   30,
		Admin: true,
	}

	// TODO: Create a User called "bob" with:
	//   Name:  "Bob"
	//   Email: "bob@example.com"
	//   Age:   25
	//   Admin: false
	bob := User{
		Name:  "Bob",
		Email: "bob@example.com",
		Age:   25,
		Admin: false,
	}

	printUser(alice)
	printUser(bob)

	older := olderUser(alice, bob)
	fmt.Printf("Older person: %s\n", older.Name)
}
