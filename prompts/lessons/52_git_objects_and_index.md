# Lesson 52: Objects, the Index, and Commits

**For Claude — do not show this file to the learner**

---

## Context for Claude

They implement the object store (blobs, trees, commits), the index (staging area), and `minigit init` + `minigit add` + `minigit commit`. By end of this lesson they have a working commit. Every line should be understood — don't let them copy-paste.

**This lesson's goal:**
- Implement the object store: write and read blobs, trees, commits
- Implement the index: stage files, read the staging area
- Implement `init`, `add`, `commit`
- See a real commit hash produced and files stored in `.minigit/objects/`

---

## Project setup

```bash
mkdir ~/projects/minigit
cd ~/projects/minigit
go mod init minigit
```

Structure:
```
minigit/
  object/
    store.go    — write/read objects (blobs, trees, commits)
    types.go    — Blob, Tree, TreeEntry, Commit types
  index/
    index.go    — staging area (read/write .minigit/index)
  cmd/
    init.go
    add.go
    commit.go
    log.go
    status.go
  main.go
```

---

## Object types

`object/types.go`:

```go
package object

import "strings"

type Type string

const (
    TypeBlob   Type = "blob"
    TypeTree   Type = "tree"
    TypeCommit Type = "commit"
)

// TreeEntry is one line in a tree object: permissions, type, hash, name
type TreeEntry struct {
    Mode string // "100644" = regular file, "040000" = directory
    Type Type
    Hash string
    Name string
}

type Commit struct {
    TreeHash  string
    ParentHash string // empty for first commit
    Author    string
    Message   string
    Timestamp int64
}

// CommitText serializes a commit to the format that gets hashed
func (c *Commit) Text() string {
    var sb strings.Builder
    sb.WriteString("tree " + c.TreeHash + "\n")
    if c.ParentHash != "" {
        sb.WriteString("parent " + c.ParentHash + "\n")
    }
    sb.WriteString("author " + c.Author + "\n")
    sb.WriteString("timestamp " + fmt.Sprintf("%d", c.Timestamp) + "\n")
    sb.WriteString("\n")
    sb.WriteString(c.Message)
    return sb.String()
}
```

---

## Object store

`object/store.go`:

```go
package object

import (
    "crypto/sha1"
    "fmt"
    "os"
    "path/filepath"
    "strings"
)

const objectsDir = ".minigit/objects"

// Write stores content under its SHA-1 hash. Returns the hash.
func Write(objType Type, content []byte) (string, error) {
    // Git format: "<type> <size>\0<content>"
    header := fmt.Sprintf("%s %d\x00", objType, len(content))
    full := append([]byte(header), content...)

    hash := fmt.Sprintf("%x", sha1.Sum(full))

    // Store at .minigit/objects/ab/cdef...
    dir := filepath.Join(objectsDir, hash[:2])
    if err := os.MkdirAll(dir, 0755); err != nil {
        return "", fmt.Errorf("creating object dir: %w", err)
    }

    path := filepath.Join(dir, hash[2:])
    if _, err := os.Stat(path); err == nil {
        return hash, nil // already exists — content-addressed, no need to rewrite
    }

    if err := os.WriteFile(path, full, 0444); err != nil {
        return "", fmt.Errorf("writing object: %w", err)
    }
    return hash, nil
}

// Read retrieves a stored object by hash
func Read(hash string) (Type, []byte, error) {
    path := filepath.Join(objectsDir, hash[:2], hash[2:])
    full, err := os.ReadFile(path)
    if err != nil {
        return "", nil, fmt.Errorf("reading object %s: %w", hash[:8], err)
    }

    // Find the null byte separating header from content
    nullIdx := -1
    for i, b := range full {
        if b == 0 {
            nullIdx = i
            break
        }
    }
    if nullIdx < 0 {
        return "", nil, fmt.Errorf("corrupt object: no null byte")
    }

    header := string(full[:nullIdx])
    parts := strings.SplitN(header, " ", 2)
    if len(parts) != 2 {
        return "", nil, fmt.Errorf("corrupt object header: %q", header)
    }

    return Type(parts[0]), full[nullIdx+1:], nil
}

// WriteBlob stores file content and returns its hash
func WriteBlob(content []byte) (string, error) {
    return Write(TypeBlob, content)
}

// WriteTree serializes a list of entries and stores them
func WriteTree(entries []TreeEntry) (string, error) {
    var sb strings.Builder
    for _, e := range entries {
        sb.WriteString(fmt.Sprintf("%s %s %s\t%s\n", e.Mode, e.Type, e.Hash, e.Name))
    }
    return Write(TypeTree, []byte(sb.String()))
}

// WriteCommit serializes and stores a commit
func WriteCommit(c *Commit) (string, error) {
    return Write(TypeCommit, []byte(c.Text()))
}
```

Ask question by question:
- "Why `sha1.Sum(full)` where `full` includes the header?" (real git includes the header in what gets hashed — it's how git tells what type an object is when reading it back)
- "Why do we check if the object already exists before writing?" (content-addressed means same content = same hash. Already stored = nothing to do. This is deduplication.)
- "Why `0444` permissions on stored objects?" (read-only — objects are immutable. Once written, never changed. The permissions make this explicit at the OS level.)
- "What is the null byte (`\x00`) for?" (separator between header and content — same as git. Headers could theoretically contain spaces, so a non-printable separator is unambiguous.)
- "Why split the hash into a two-character prefix and the rest for the directory?" (performance — if you have millions of objects in one directory, filesystem listing gets slow. Two-character prefix = 256 possible directories, each with a fraction of the objects. Git does the same.)

---

## The index (staging area)

`index/index.go`:

```go
package index

import (
    "encoding/json"
    "os"
)

// Entry represents one staged file
type Entry struct {
    Path string `json:"path"` // relative path
    Hash string `json:"hash"` // blob hash of staged content
}

type Index struct {
    Entries []Entry `json:"entries"`
}

const indexPath = ".minigit/index"

func Load() (*Index, error) {
    data, err := os.ReadFile(indexPath)
    if os.IsNotExist(err) {
        return &Index{}, nil
    }
    if err != nil {
        return nil, err
    }
    var idx Index
    if err := json.Unmarshal(data, &idx); err != nil {
        return nil, err
    }
    return &idx, nil
}

func (idx *Index) Save() error {
    data, err := json.MarshalIndent(idx, "", "  ")
    if err != nil {
        return err
    }
    return os.WriteFile(indexPath, data, 0644)
}

func (idx *Index) Add(path, hash string) {
    // Update existing or append
    for i, e := range idx.Entries {
        if e.Path == path {
            idx.Entries[i].Hash = hash
            return
        }
    }
    idx.Entries = append(idx.Entries, Entry{Path: path, Hash: hash})
}

func (idx *Index) Remove(path string) {
    for i, e := range idx.Entries {
        if e.Path == path {
            idx.Entries = append(idx.Entries[:i], idx.Entries[i+1:]...)
            return
        }
    }
}
```

Ask: "Why do we use JSON for the index instead of binary?" (simplicity — real git's index is binary for performance, but JSON is readable and debuggable. Open `.minigit/index` in a text editor after staging — they'll see their staged files.)

---

## Implement the commands

`cmd/init.go`:
```go
func runInit() error {
    dirs := []string{
        ".minigit",
        ".minigit/objects",
        ".minigit/refs/heads",
    }
    for _, d := range dirs {
        if err := os.MkdirAll(d, 0755); err != nil {
            return err
        }
    }
    // HEAD points to main (initially)
    if err := os.WriteFile(".minigit/HEAD", []byte("ref: refs/heads/main\n"), 0644); err != nil {
        return err
    }
    fmt.Println("Initialized empty minigit repository in .minigit/")
    return nil
}
```

`cmd/add.go`:
```go
func runAdd(path string) error {
    content, err := os.ReadFile(path)
    if err != nil {
        return fmt.Errorf("reading %s: %w", path, err)
    }

    hash, err := object.WriteBlob(content)
    if err != nil {
        return err
    }

    idx, err := index.Load()
    if err != nil {
        return err
    }

    idx.Add(path, hash)
    if err := idx.Save(); err != nil {
        return err
    }

    fmt.Printf("staged: %s (%s)\n", path, hash[:8])
    return nil
}
```

`cmd/commit.go`:
```go
func runCommit(message, author string) error {
    idx, err := index.Load()
    if err != nil {
        return err
    }
    if len(idx.Entries) == 0 {
        return fmt.Errorf("nothing staged — run 'minigit add <file>' first")
    }

    // Build tree entries from index
    entries := make([]object.TreeEntry, 0, len(idx.Entries))
    for _, e := range idx.Entries {
        entries = append(entries, object.TreeEntry{
            Mode: "100644",
            Type: object.TypeBlob,
            Hash: e.Hash,
            Name: e.Path,
        })
    }

    treeHash, err := object.WriteTree(entries)
    if err != nil {
        return err
    }

    // Read current HEAD to get parent
    parentHash := readHEAD()

    commit := &object.Commit{
        TreeHash:   treeHash,
        ParentHash: parentHash,
        Author:     author,
        Message:    message,
        Timestamp:  time.Now().Unix(),
    }

    commitHash, err := object.WriteCommit(commit)
    if err != nil {
        return err
    }

    // Update HEAD
    if err := writeHEAD(commitHash); err != nil {
        return err
    }

    fmt.Printf("[main %s] %s\n", commitHash[:8], message)
    return nil
}
```

Ask:
- "In `runAdd`, what does `object.WriteBlob` return?" (the SHA-1 hash of the file's content)
- "In `runCommit`, why do we need `parentHash`?" (to form the chain — commits point to their parent, making git log possible)
- "What is `readHEAD()`?" (read `.minigit/HEAD`, follow the ref to `.minigit/refs/heads/main`, read that file — have them implement it)

---

## Test it

```bash
go build -o minigit .
./minigit init

echo "Hello, Git!" > hello.txt
./minigit add hello.txt

echo "main.go content" > main.go
./minigit add main.go

./minigit commit -m "Initial commit"

# Inspect what was stored
ls .minigit/objects/
cat .minigit/refs/heads/main    # the commit hash
cat .minigit/index              # the staging area
```

Let them look at the raw files in `.minigit/objects/`. They can see git's internals with their own eyes.

---

## Checkpoint

1. "What is stored in a blob? What is NOT stored in a blob?"
2. "Walk me through `minigit add hello.txt`. Every step."
3. "What is the null byte in the object file format for?"
4. "Why are object files stored at `objects/ab/cdef...` instead of `objects/abcdef...`?"
5. "What is `HEAD`? What does it contain right now?"
6. "If I add the same file twice with unchanged content, what happens to the blob store?" (nothing — same content = same hash = object already exists)

---

## Commit

```bash
git add .
git commit -m "Object store, index, init/add/commit commands"
```
