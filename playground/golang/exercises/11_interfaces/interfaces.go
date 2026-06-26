// Exercise 11: Interfaces — Describing What Something Can Do
//
// GOAL: Implement the Shape interface for Circle and Triangle.
//
// BACKGROUND:
//   An interface is a contract: "Any type that has THESE methods is a ___"
//   Go figures out automatically if a type satisfies an interface.
//   You don't have to say "implements Shape" anywhere — if the methods match, it works.
//
//   This is powerful: you can write functions that work with ANY type that
//   satisfies the interface, even types you haven't written yet.
//
// EXPECTED OUTPUT:
//   Rectangle: area=15.00, perimeter=16.00
//   Circle: area=78.54, perimeter=31.42
//   Triangle: area=6.00, perimeter=12.00
//   Biggest shape by area: Circle
//   Total area of all shapes: 99.54
//
// WHAT YOU'LL LEARN:
//   - Defining and using interfaces
//   - Implicit interface satisfaction
//   - Functions that accept an interface
//   - Why interfaces are useful

package main

import (
	"fmt"
	"math"
)

// Shape is an interface. Any type with these two methods is a Shape.
// You don't need to change this.
type Shape interface {
	Area() float64
	Perimeter() float64
	Name() string
}

// ── Rectangle ──────────────────────────────────────────────────────
// This one is already done. Use it as a reference for the others.

type Rectangle struct {
	Width, Height float64
}

func (r Rectangle) Area() float64      { return r.Width * r.Height }
func (r Rectangle) Perimeter() float64 { return 2 * (r.Width + r.Height) }
func (r Rectangle) Name() string       { return "Rectangle" }

// ── Circle ─────────────────────────────────────────────────────────
// A circle has a Radius.
// Area = π × r²      (math.Pi is π, math.Pow(r, 2) is r²)
// Perimeter = 2 × π × r  (the circumference)

type Circle struct {
	Radius float64
}

// TODO: Implement Area() for Circle
// Hint: math.Pi * r * r   OR   math.Pi * math.Pow(r, 2)
func (c Circle) Area() float64 {
	return math.Pi * c.Radius * c.Radius
}

// TODO: Implement Perimeter() for Circle (this is the circumference)
// Hint: 2 * math.Pi * radius
func (c Circle) Perimeter() float64 {
	return 2 * math.Pi * c.Radius
}

// TODO: Implement Name() for Circle — return "Circle"
func (c Circle) Name() string { return "Circle" }

// ── Triangle ───────────────────────────────────────────────────────
// A triangle has three sides: A, B, and C.
// For a right triangle, area = (1/2) × base × height
// We'll use: Area = (A * B) / 2  (treating A as base, B as height)
// Perimeter = A + B + C

type Triangle struct {
	A, B, C float64 // the three side lengths
}

// TODO: Implement Area() for Triangle
// Use: (A * B) / 2
func (t Triangle) Area() float64 {
	return (t.A * t.B) / 2
}

// TODO: Implement Perimeter() for Triangle
// Sum of all three sides
func (t Triangle) Perimeter() float64 {
	return t.A + t.B + t.C
}

// TODO: Implement Name() for Triangle
func (t Triangle) Name() string { return "Triangle" }

// ── Functions that accept any Shape ────────────────────────────────
// These functions work with ALL of the above types because they all
// satisfy the Shape interface. You don't need to change these.

func describeShape(s Shape) {
	fmt.Printf("%s: area=%.2f, perimeter=%.2f\n", s.Name(), s.Area(), s.Perimeter())
}

func biggestShape(shapes []Shape) Shape {
	biggest := shapes[0]
	for _, s := range shapes[1:] {
		if s.Area() > biggest.Area() {
			biggest = s
		}
	}
	return biggest
}

func totalArea(shapes []Shape) float64 {
	total := 0.0
	for _, s := range shapes {
		total += s.Area()
	}
	return total
}

// ── You don't need to change anything below this line ──────────────

func main() {
	shapes := []Shape{
		Rectangle{Width: 5, Height: 3},
		Circle{Radius: 5},
		Triangle{A: 3, B: 4, C: 5},
	}

	for _, s := range shapes {
		describeShape(s)
	}

	biggest := biggestShape(shapes)
	fmt.Printf("Biggest shape by area: %s\n", biggest.Name())
	fmt.Printf("Total area of all shapes: %.2f\n", totalArea(shapes))
}
