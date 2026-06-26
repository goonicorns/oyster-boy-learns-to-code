# Lesson 11: Git Workflow — Using Version Control Like a Developer

**Paste into Claude Code after the system prompt**

---

## Context for Claude

The learners have been doing basic git commits throughout the project. This lesson makes the workflow explicit and teaches branching — the most important git concept for working with others.

**This lesson's goal:**
- Understand git's core model (commits, branches, HEAD)
- Work with branches (create, switch, merge)
- Read git log and history
- Understand what to commit and what NOT to commit
- Handle a merge conflict (simplified)

---

## What to teach

### What git actually is

"Git saves snapshots of your project over time. Every time you commit, you're taking a photo of all your files at that moment. You can go back to any photo."

"A branch is a named sequence of commits. When you create a branch, you're creating a new timeline that diverges from the current one. You can work on the new timeline without affecting the main one."

"HEAD is a pointer to where you are right now. Usually it points to the tip of a branch."

Draw this out:

```
main:    A──B──C
                 \
feature-auth:     D──E
```

"Commits A, B, C are on main. D and E are on feature-auth. They share history up to C."

### The daily workflow

```bash
# See the current state
git status

# See what changed in each file
git diff

# Stage specific files (don't use git add . blindly)
git add handler/auth.go store/user.go

# Commit with a meaningful message
git commit -m "Add password reset endpoint"

# See history
git log --oneline  # compact view
git log            # full view
```

Ask them to read their own git log: "What do the commits look like? Are the messages meaningful? If you came back in 3 months, would you understand what each one did?"

### What NOT to commit

This is critical:

```bash
# Create a .gitignore file
cat > .gitignore << 'EOF'
# Compiled binary
cryptowatch

# Environment variables with secrets
.env
.env.local
*.env

# Go test cache
/tmp/

# macOS metadata
.DS_Store

# IDE files
.idea/
.vscode/
*.swp
EOF
```

"A .gitignore file tells git to ignore specific files. The most important things to ignore: compiled binaries, files with passwords or API keys, and system/editor files."

"Never commit a file with real credentials. Even if you delete it in the next commit, it's in the git history permanently. There are bots that scan GitHub for API keys."

### Branching

"Let's create a branch for a new feature: adding a `GET /me` endpoint that returns the current user's info."

```bash
# Create and switch to a new branch
git checkout -b feature/user-profile

# Or the modern way:
git switch -c feature/user-profile

# See all branches
git branch

# Switch back to main
git checkout main  # or: git switch main

# Switch back to feature branch
git checkout feature/user-profile
```

Guide them to:
1. Create the branch
2. Add the `GET /me` endpoint on that branch
3. Test it
4. Commit it
5. Merge it back to main

```bash
# After committing the feature:
git switch main
git merge feature/user-profile

# Delete the branch after merging
git branch -d feature/user-profile
```

### Simulate a merge conflict

"A merge conflict happens when two branches changed the same lines in the same file. Git doesn't know which version to keep, so it asks you."

Do this carefully:
1. Create two branches from main
2. Edit the same line in `main.go` on both branches
3. Merge one branch, then try to merge the other

Git will output:
```
CONFLICT (content): Merge conflict in main.go
Automatic merge failed; fix conflicts and then commit the result.
```

Open the file — it looks like:
```
<<<<<<< HEAD
r.Get("/prices", handler.GetPrices)
=======
r.Get("/prices", priceHandler.GetAll)
>>>>>>> feature/refactor-handlers
```

"The `<<<<<<< HEAD` section is YOUR version. The `>>>>>>> feature/...` section is the INCOMING version. You pick which one to keep (or combine them), delete the conflict markers, and commit."

Guide them through resolving it manually.

### Reading git history

```bash
# See full history with changes
git log --stat

# See what changed in a specific commit (use a commit hash from git log)
git show abc1234

# See who changed each line of a file
git blame main.go

# Compare two commits
git diff main..feature/user-profile

# Find the commit that introduced a bug (advanced — mention, don't require)
git bisect
```

---

## Commit

```bash
git add .gitignore
git commit -m "Add .gitignore"
git commit -m "Merge feature/user-profile"
```
