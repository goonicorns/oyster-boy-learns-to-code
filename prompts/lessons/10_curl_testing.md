# Lesson 10: Testing Your API with curl

**Paste into Claude Code after the system prompt**

---

## Context for Claude

The API is taking shape. This lesson is dedicated to thorough testing with curl — teaching the learners to think like API users and find their own bugs.

**This lesson's goal:**
- Master curl for API testing
- Test every endpoint they've built
- Understand HTTP status codes
- Find and fix bugs through testing

---

## What to teach

### curl flags to know

Go through these one by one with live examples:

```bash
# Basic GET
curl http://localhost:8080/prices

# Verbose — shows request and response headers
curl -v http://localhost:8080/prices

# POST with JSON body
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"pass123"}'

# Include a token in the header
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8080/prices

# Pretty-print JSON output (requires jq to be installed)
curl http://localhost:8080/prices | jq

# Save the response to a variable
TOKEN=$(curl -s -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"pass123"}' | jq -r .token)

# Show only the HTTP status code
curl -o /dev/null -s -w "%{http_code}" http://localhost:8080/prices
```

### HTTP status codes to understand

Ask them what each code means before explaining. Let them guess first.

| Code | Name | Meaning |
|------|------|---------|
| 200 | OK | Request succeeded |
| 201 | Created | New resource was created (use after POST that creates something) |
| 400 | Bad Request | The request was malformed — missing field, wrong type, etc. |
| 401 | Unauthorized | Not authenticated — send your token |
| 403 | Forbidden | Authenticated but not allowed to do this |
| 404 | Not Found | The resource doesn't exist |
| 409 | Conflict | The thing you're trying to create already exists (duplicate username) |
| 422 | Unprocessable Entity | The request is well-formed but semantically wrong (validation failed) |
| 500 | Internal Server Error | Something broke on the server — check the logs |

"Which one should registration return when the username is already taken? 400? 409? There's legitimate debate. The important thing is to be consistent."

### Test every endpoint systematically

Walk through testing each endpoint:

**Registration:**
```bash
# Happy path
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"password123"}'

# Missing field — what status code do you get?
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser"}'

# Duplicate username — what status code?
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"other@example.com","password":"password123"}'
```

"What did you expect? What did you get? Are they different? Why?"

**Login:**
```bash
# Correct credentials
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"password123"}'

# Wrong password
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"wrongpassword"}'

# Non-existent user
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"nobody","password":"password123"}'
```

"Are the error messages for wrong password and non-existent user different? Why should they be the SAME?" (don't reveal which one doesn't exist — that's information an attacker could use)

**Protected endpoints:**
```bash
# Without token — should get 401
curl http://localhost:8080/prices

# With expired or fake token — should get 401
curl -H "Authorization: Bearer fakefakefake" http://localhost:8080/prices

# With valid token
TOKEN=$(curl -s -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"password123"}' | jq -r .token)
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/prices
```

### Introduce jq

"jq is a command-line JSON processor. It's incredibly useful for working with APIs."

```bash
# Install jq
brew install jq       # mac
apt install jq        # linux

# Parse specific fields
curl -s http://localhost:8080/prices | jq .data
curl -s http://localhost:8080/prices | jq '.data[0].symbol'

# Extract a value to use in next command
TOKEN=$(curl -s -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"pass"}' | jq -r '.token')
# jq -r means "raw" — prints without quotes
```

### Write a test script

"Let's write a bash script that runs all these tests automatically. This is the seed of integration testing."

Guide them to create `scripts/test-api.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:8080"
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

pass() { echo -e "${GREEN}✓ $1${RESET}"; }
fail() { echo -e "${RED}✗ $1${RESET}"; exit 1; }

echo "Testing API at $BASE..."

# Register a test user
STATUS=$(curl -o /dev/null -s -w "%{http_code}" -X POST "$BASE/register" \
  -H "Content-Type: application/json" \
  -d '{"username":"e2etest","email":"e2e@test.com","password":"testpass123"}')
[[ "$STATUS" == "201" || "$STATUS" == "409" ]] && pass "Registration" || fail "Registration returned $STATUS"

# Login
TOKEN=$(curl -s -X POST "$BASE/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"e2etest","password":"testpass123"}' | jq -r '.token')
[[ -n "$TOKEN" ]] && pass "Login" || fail "Login failed"

# Access protected route
STATUS=$(curl -o /dev/null -s -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$BASE/prices")
[[ "$STATUS" == "200" ]] && pass "Get prices (authenticated)" || fail "Get prices returned $STATUS"

# Try without token
STATUS=$(curl -o /dev/null -s -w "%{http_code}" "$BASE/prices")
[[ "$STATUS" == "401" ]] && pass "Reject unauthenticated request" || fail "Should have returned 401, got $STATUS"

echo "All tests passed!"
```

Guide them to run it: `bash scripts/test-api.sh`

---

## Commit

```bash
git add .
git commit -m "Add API test script"
```
