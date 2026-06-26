// Exercise 00: Hello World
//
// GOAL: Run this program and understand its structure.
// You don't need to change anything here.
//
// WHAT TO DO:
//   1. Read every line and its comment carefully.
//   2. Run it with: go run hello.go
//   3. When it prints "Hello, World!" you're done.
//
// WHAT YOU'LL LEARN:
//   - What a Go file looks like
//   - What "package" and "import" mean
//   - What the main() function is
//   - How to print text

// Every Go file starts with a "package" declaration.
// Think of a package as a folder or namespace — a way to organize code.
// "package main" is special: it tells Go this file is the entry point of a program.
// Any file that can be run directly must have "package main".
package main

// "import" brings in code from other packages (like Go's built-in libraries).
// "fmt" stands for "format" — it gives us tools to print text and format strings.
// Without importing fmt, we couldn't use fmt.Println.
import "fmt"

// func main() is the starting point of your program.
// When you run your program, Go automatically calls this function first.
// Every runnable Go program must have exactly one main() function.
// The curly braces { } define the beginning and end of the function body.
func main() {
	// fmt.Println prints text to the screen, then adds a newline at the end.
	// "Println" = "Print Line". The argument (what goes inside the parentheses)
	// is a string — text surrounded by double quotes.
	fmt.Println("Hello, World!")

	// Try changing the text above to something else and run it again.
	// For example: fmt.Println("Hello, I'm learning Go!")
}
