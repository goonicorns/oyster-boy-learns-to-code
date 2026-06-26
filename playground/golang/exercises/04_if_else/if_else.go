// Exercise 04: If / Else
//
// GOAL: Complete the functions below so they return the right values.
//
// WHAT TO DO:
//   Fill in the bodies of the two functions.
//   Don't change the function signatures or the main() function.
//
// EXPECTED OUTPUT:
//   Grade for 95: A
//   Grade for 82: B
//   Grade for 74: C
//   Grade for 60: D
//   Grade for 45: F
//   18 can vote: true
//   15 can vote: false
//
// WHAT YOU'LL LEARN:
//   - if / else if / else chains
//   - Comparison operators: >, <, >=, <=, ==, !=
//   - Returning values from functions
//   - Writing functions that solve a problem

package main

import "fmt"

// getGrade returns a letter grade for a given numeric score.
//
// Grading scale:
//   90 and above → "A"
//   80 to 89     → "B"
//   70 to 79     → "C"
//   60 to 69     → "D"
//   below 60     → "F"
//
// This function takes one argument: score (an int)
// It returns one value: the grade (a string)
func getGrade(score int) string {
	// TODO: Write an if/else chain that returns the right grade
	// Start with the highest grade and work down.
	//
	// if score >= 90 {
	//     return "A"
	// } else if score >= 80 {
	//     ...
	// }
	if score >= 90 {
		return "A"
	} else if score >= 80 {
		return "B"
	} else if score >= 70 {
		return "C"
	} else if score >= 60 {
		return "D"
	} else {
		return "F"
	}
}

// canVote returns true if the given age is 18 or older.
//
// This function takes one argument: age (an int)
// It returns one value: true or false (a bool)
func canVote(age int) bool {
	// TODO: Return true if age is 18 or older, false otherwise
	// Hint: you can write a simple one-liner here:
	//   return age >= 18
	return age >= 18
}

// ── You don't need to change anything below this line ──────────────

func main() {
	scores := []int{95, 82, 74, 60, 45}
	for _, score := range scores {
		fmt.Printf("Grade for %d: %s\n", score, getGrade(score))
	}

	ages := []int{18, 15}
	for _, age := range ages {
		fmt.Printf("%d can vote: %t\n", age, canVote(age))
	}
}
