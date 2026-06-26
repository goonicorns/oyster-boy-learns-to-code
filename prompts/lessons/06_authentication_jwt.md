# Lesson 06: Authentication — Passwords, Hashing, and JWTs

**Paste into Claude Code after the system prompt**

---

## Context for Claude

This is the most concept-heavy lesson. The learners need to understand authentication before writing any code. Take time to explain. Do not rush.

**This lesson's goal:**
- Understand how passwords should be stored (hashed, never plaintext)
- Implement user registration and login
- Understand what a JWT is and how it works
- Generate and verify JWTs
- Understand why we chose JWTs over sessions (and what the tradeoffs are)

---

## Conceptual groundwork — teach these BEFORE any code

### Never store passwords as plaintext

"If your database gets hacked and you stored passwords as text, every user's password is exposed — and since people reuse passwords, this means their email, their bank, their everything is compromised."

"Instead, we store a 'hash' of the password. A hash is a one-way transformation: given the original, you can compute the hash. But given the hash, you cannot recover the original. It's like a fingerprint — it identifies the original but you can't reverse it to get the original back."

"When someone logs in, we hash what they typed and compare it to the stored hash. If they match, the password is correct."

"We use a special hashing algorithm called bcrypt that is intentionally slow. This is on purpose — it makes brute-force attacks (trying millions of passwords) take years instead of seconds."

Ask: "Why do you think we'd want a hashing function to be SLOW?"

### What is a JWT?

"JWT stands for JSON Web Token. Let me explain what it solves first."

"Problem: HTTP is stateless. Every request is independent. The server doesn't remember that you logged in 30 seconds ago. So how do we know who's sending this request?"

"Option 1 — Sessions: Server generates a random ID, stores it in a database, gives it to you in a cookie. On every request, you send the ID, server looks it up, finds who you are. Works fine. But requires a database lookup on EVERY request, and if you have multiple servers they all need to share the session database."

"Option 2 — JWT: Server creates a token that CONTAINS your user info (like your user ID), digitally signs it with a secret key, and gives it to you. On every request, you send the token. Server checks the signature — if valid, it trusts the content without any database lookup."

"A JWT has three parts: Header.Payload.Signature"

Show them a real JWT and decode it at jwt.io (don't send them there, just explain the structure):

```
eyJhbGc...  ←  Header (base64): {"alg":"HS256","typ":"JWT"}
.eyJ1c2...  ←  Payload (base64): {"user_id":1,"exp":1234567890}
.SflKxw...  ←  Signature: HMAC-SHA256(header + "." + payload, secret)
```

"The payload is base64 encoded, NOT encrypted. Anyone can read it. But no one can CHANGE it without invalidating the signature. Don't put sensitive data in a JWT — it's readable."

### Why we chose JWT over sessions

Be honest about the tradeoffs:

"JWTs are simpler to scale and don't require database lookups on every request. But they come with a big limitation: you can't revoke them. If a user's JWT is stolen, the attacker can use it until it expires. With sessions, you can delete the session from the database and the attacker is immediately locked out."

"For a learning project and a crypto price watcher, JWTs are fine. For a banking app or anything where revoking access immediately matters, you'd use sessions or a hybrid approach."

---

## Implementation

### Install dependencies

```bash
go get golang.org/x/crypto
go get github.com/golang-jwt/jwt/v5
```

### User registration

Guide them to create `store/user.go` with:
1. A function to create a user (after hashing their password)
2. A function to find a user by username

For password hashing, guide them to:
```go
// hash the password before storing it
hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
```

For verification:
```go
// check if a password matches the stored hash
err := bcrypt.CompareHashAndPassword([]byte(storedHash), []byte(inputPassword))
// if err is nil, the password is correct
```

"Why do we pass []byte?" — ask them. (bcrypt works on bytes, not strings)

### The auth handler

Guide them to create `handler/auth.go` with `Register` and `Login` handlers.

For Register:
- Read JSON body (guide them to `json.NewDecoder(r.Body).Decode(&input)`)
- Validate input (non-empty fields)
- Hash the password
- Store in database
- Return 201 Created

For Login:
- Read credentials from JSON body
- Find user in database (what if not found? → 401, not 404 — ask them why)
- Compare password hash
- Generate JWT
- Return the token

Ask: "Why do we return 401 (Unauthorized) instead of 404 (Not Found) when the user doesn't exist? What could an attacker learn from a 404?"

### JWT generation

```go
// Create a JWT containing the user's ID
token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
    "user_id": user.ID,
    "exp":     time.Now().Add(24 * time.Hour).Unix(), // expires in 24 hours
})

// Sign it with our secret key
tokenString, err := token.SignedString([]byte(os.Getenv("JWT_SECRET")))
```

"The JWT_SECRET is a long random string only your server knows. If someone gets this, they can forge tokens for any user. Keep it secret."

### Test registration and login

```bash
# Register a user
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","email":"alice@example.com","password":"securepass123"}'

# Login
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"securepass123"}'

# You should get back a token
```

Ask: "Take the token and go to jwt.io to decode it. What's in the payload? Can you see your user ID?"

---

## Commit

```bash
git add .
git commit -m "Add user registration and JWT-based login"
```
