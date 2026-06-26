# Lesson 08: Unit Tests — Writing Tests in Go

**Paste into Claude Code after the system prompt**

---

## Context for Claude

The learners have a working API with authentication. Now they'll learn why tests matter and how to write them.

**This lesson's goal:**
- Understand why tests exist and what they protect against
- Write unit tests for their pure functions
- Understand table-driven tests (Go's idiom)
- Run tests and read output

---

## What to teach

### Why tests exist

Start with a story, not a definition:

"Imagine you built everything we have so far — registration, login, prices — and it all works. Now you add a new feature that changes how passwords are hashed. All your tests pass, you ship it, and now nobody can log in. Their old passwords no longer work. Users are locked out. This is a real thing that happens."

"Tests are the safety net. They capture how things should behave so that when you change something, you know immediately if you broke it. Not in production — in your own terminal, before anyone sees it."

"A unit test tests ONE function in isolation. Not the whole system — just one piece. You give it specific inputs and check that you get the expected output."

### How Go tests work

"In Go, test files end in `_test.go`. Test functions start with `Test` (capital T) and take `*testing.T` as their argument. To run them: `go test ./...`"

"That's it. No test framework, no extra setup. It's built in."

Example structure:
```go
// math_test.go
package mypkg

import "testing"

func TestAdd(t *testing.T) {
    result := Add(2, 3)
    if result != 5 {
        t.Errorf("Add(2, 3) = %d; want 5", result)
    }
}
```

Ask: "What is `t.Errorf`?" (marks the test as failed and prints a message, but keeps running)
Ask: "What would `t.Fatalf` do?" (marks as failed AND stops the test immediately)

### Table-driven tests — Go's way

"Instead of writing one test per case, Go programmers typically write one test function with a table of test cases. This is much cleaner when testing many inputs."

```go
func TestGetGrade(t *testing.T) {
    tests := []struct {
        score    int
        expected string
    }{
        {score: 95, expected: "A"},
        {score: 85, expected: "B"},
        {score: 75, expected: "C"},
        {score: 65, expected: "D"},
        {score: 45, expected: "F"},
    }

    for _, tt := range tests {
        result := getGrade(tt.score)
        if result != tt.expected {
            t.Errorf("getGrade(%d) = %q; want %q", tt.score, result, tt.expected)
        }
    }
}
```

Ask them to write table-driven tests for:
1. The `divide` function from the errors exercise
2. The `getGrade` function

Guide with questions, don't write it:
- "What are the interesting cases to test for divide? Just normal division?"
- "What about dividing by zero? That's a case where the behavior MATTERS — test it."
- "Edge cases: what about negative numbers? What about very large numbers?"

### Test their store functions

"Functions that talk to a database are harder to test — you need a real database. For now, let's focus on testing our pure functions (functions that don't talk to external systems)."

"What functions do we have that don't touch the database?"
- JWT generation and verification
- The response builder
- Any validation logic

Guide them to write tests for JWT:
```go
func TestJWTRoundTrip(t *testing.T) {
    // Generate a token for user 42
    token, err := generateToken(42)
    if err != nil {
        t.Fatalf("generateToken failed: %v", err)
    }

    // Verify the token and get the user ID back
    userID, err := verifyToken(token)
    if err != nil {
        t.Fatalf("verifyToken failed: %v", err)
    }

    if userID != 42 {
        t.Errorf("got user ID %d; want 42", userID)
    }
}
```

### Run the tests

```bash
go test ./...         # run all tests
go test ./handler/... # run tests in a specific package
go test -v ./...      # verbose — show each test name and result
go test -run TestJWT  # run only tests whose name matches "TestJWT"
```

"What does PASS mean? What does FAIL mean? What does the error message tell you?"

### Deliberately break something

"Let me show you why tests are worth it. Change your `getGrade` function to return 'A' for scores above 85 instead of 90. Now run the tests. What happened?"

The test for score=88 expecting B will fail. Let them fix it and run again.

"That's the point. You changed something, the test caught it immediately, you fixed it. Without the test, that bug goes to production."

---

## Commit

```bash
git add .
git commit -m "Add unit tests for core logic"
```

---

## Reinforce

"Going forward, try to write a test whenever you write a new function. The habit pays off. Not everything needs a test — generated boilerplate doesn't. But anything with logic? Test it."
