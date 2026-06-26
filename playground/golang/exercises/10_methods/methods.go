// Exercise 10: Methods — Functions That Belong to a Type
//
// GOAL: Add methods to the Rectangle struct.
//
// BACKGROUND:
//   A method is just a function with a "receiver" — it belongs to a specific type.
//   You call it on a value using dot notation: myRect.Area()
//
//   There are two kinds of receivers:
//   1. Value receiver:   func (r Rectangle) Area()    — gets a copy of the struct
//   2. Pointer receiver: func (r *Rectangle) Scale()  — works on the real struct (can modify it)
//
//   Use pointer receivers when you need to modify the struct.
//   Use value receivers when you're just reading data.
//
// EXPECTED OUTPUT:
//   Rectangle: 5.00 x 3.00
//   Area: 15.00
//   Perimeter: 16.00
//   After scaling by 2: 10.00 x 6.00
//   Is it a square? false
//   Square 4x4 is a square? true
//
// WHAT YOU'LL LEARN:
//   - Defining methods with value receivers
//   - Defining methods with pointer receivers
//   - Calling methods with dot notation

package main

import "fmt"

// Rectangle has a width and height.
type Rectangle struct {
	Width  float64
	Height float64
}

// String returns a human-readable description of the rectangle.
// Value receiver — just reading data, not changing it.
func (r Rectangle) String() string {
	return fmt.Sprintf("%.2f x %.2f", r.Width, r.Height)
}

// TODO: Write an "Area" method on Rectangle.
// It should return Width * Height as a float64.
// Use a value receiver: func (r Rectangle) Area() float64
func (r Rectangle) Area() float64 {
	return r.Width * r.Height
}

// TODO: Write a "Perimeter" method on Rectangle.
// A rectangle's perimeter is: 2 * (width + height)
// Use a value receiver.
func (r Rectangle) Perimeter() float64 {
	return 2 * (r.Width + r.Height)
}

// TODO: Write a "Scale" method on Rectangle.
// It should MULTIPLY both Width and Height by the given factor.
// This modifies the rectangle, so use a POINTER receiver:
//   func (r *Rectangle) Scale(factor float64)
// With a pointer receiver, changes to r.Width actually stick.
func (r *Rectangle) Scale(factor float64) {
	r.Width *= factor  // *= means: r.Width = r.Width * factor
	r.Height *= factor
}

// TODO: Write an "IsSquare" method on Rectangle.
// It returns true if Width == Height, false otherwise.
// Use a value receiver.
func (r Rectangle) IsSquare() bool {
	return r.Width == r.Height
}

// ── You don't need to change anything below this line ──────────────

func main() {
	rect := Rectangle{Width: 5, Height: 3}
	fmt.Printf("Rectangle: %s\n", rect.String())
	fmt.Printf("Area: %.2f\n", rect.Area())
	fmt.Printf("Perimeter: %.2f\n", rect.Perimeter())

	rect.Scale(2)
	fmt.Printf("After scaling by 2: %s\n", rect.String())
	fmt.Printf("Is it a square? %t\n", rect.IsSquare())

	square := Rectangle{Width: 4, Height: 4}
	fmt.Printf("Square 4x4 is a square? %t\n", square.IsSquare())
}
