# Lesson 59: File Uploads and Image Handling

**For Claude — do not show this file to the learner**

---

## Context for Claude

File uploads are in every real app and most learners have never touched them. Cover: multipart form parsing, secure filename generation, file validation (type + size), serving uploaded files. Don't let them store files in the database as bytes — explain why that's wrong.

**This lesson's goal:**
- Understand multipart/form-data vs JSON
- Parse file uploads with `r.FormFile`
- Validate file type (via magic bytes) and size
- Store files on disk with UUID names
- Serve them as static files
- Understand why NOT to store files in the database

---

## Why not store files in the database?

"Before we write a line of code, answer this: could we store image bytes directly in Postgres as a BYTEA column? Why might that be a bad idea?"

Let them reason. Guide toward:
- Database size balloons — images are large, databases are expensive storage, not optimized for large binary blobs
- Every image fetch goes through the database — database connections are a limited resource
- CDNs, S3, static file servers exist specifically for this problem and do it better
- Database backups become enormous
- "For this project: files on disk, served as static files. In production: S3 with CloudFront in front of it."

---

## multipart/form-data

"When your browser submits a file upload, it doesn't use JSON. It uses a format called multipart/form-data — the request body contains multiple parts: text fields and binary file data."

Ask: "Why can't we use JSON for file uploads?" (JSON is text. Images are binary. Base64-encoding binary to fit in JSON wastes 33% extra space and is CPU-expensive. multipart is designed for mixed text+binary.)

---

## Parse the upload

`api/handlers/upload.go`:

```go
package handlers

import (
    "crypto/rand"
    "encoding/hex"
    "fmt"
    "io"
    "net/http"
    "os"
    "path/filepath"
    "strings"
)

const (
    maxUploadSize = 5 << 20 // 5 MB
)

var allowedTypes = map[string]string{
    "\xff\xd8\xff":     ".jpg",
    "\x89PNG\r\n\x1a\n": ".png",
    "GIF87a":           ".gif",
    "GIF89a":           ".gif",
    "RIFF":             ".webp",
}

func (h *Handler) UploadCoverImage(w http.ResponseWriter, r *http.Request) {
    // 1. Limit request body size
    r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)

    // 2. Parse the multipart form
    if err := r.ParseMultipartForm(maxUploadSize); err != nil {
        http.Error(w, "file too large", http.StatusBadRequest)
        return
    }

    // 3. Get the file
    file, header, err := r.FormFile("cover")
    if err != nil {
        http.Error(w, "missing cover field", http.StatusBadRequest)
        return
    }
    defer file.Close()

    // 4. Read first 512 bytes to detect file type
    buf := make([]byte, 512)
    n, err := file.Read(buf)
    if err != nil && err != io.EOF {
        http.Error(w, "reading file", 500)
        return
    }
    buf = buf[:n]

    ext, ok := detectImageType(buf)
    if !ok {
        http.Error(w, "unsupported image type (jpg, png, gif, webp only)", http.StatusBadRequest)
        return
    }

    // 5. Generate a random filename — NEVER use the original name
    name, err := randomHex(16)
    if err != nil {
        http.Error(w, "internal error", 500)
        return
    }
    filename := name + ext

    // 6. Write to disk
    dst, err := os.Create(filepath.Join(h.uploadDir, filename))
    if err != nil {
        http.Error(w, "saving file", 500)
        return
    }
    defer dst.Close()

    // Seek back to beginning (we read 512 bytes for type detection)
    if seeker, ok := file.(io.Seeker); ok {
        seeker.Seek(0, io.SeekStart)
    }

    written, err := io.Copy(dst, file)
    if err != nil {
        http.Error(w, "writing file", 500)
        return
    }

    _ = header // header.Filename is the original name — don't use it for storage
    _ = written

    url := "/uploads/" + filename
    w.Header().Set("Content-Type", "application/json")
    fmt.Fprintf(w, `{"url":%q}`, url)
}

func detectImageType(buf []byte) (string, bool) {
    s := string(buf)
    for magic, ext := range allowedTypes {
        if strings.HasPrefix(s, magic) {
            return ext, true
        }
    }
    return "", false
}

func randomHex(n int) (string, error) {
    b := make([]byte, n)
    if _, err := rand.Read(b); err != nil {
        return "", err
    }
    return hex.EncodeToString(b), nil
}
```

Drill every security decision:

Ask: "Why do we use `http.MaxBytesReader` AND `ParseMultipartForm(maxUploadSize)`? Isn't one enough?" (defense in depth — `MaxBytesReader` limits the raw body, `ParseMultipartForm` limits what's stored in memory. Both are needed for different attack vectors.)

Ask: "Why do we detect file type from the first bytes instead of trusting the file extension or the Content-Type header?" (an attacker can name a `.php` file `cute-cat.jpg` or set Content-Type to `image/jpeg`. Magic bytes are the actual file content — harder to fake, though not impossible. Real production apps also run image processing to re-encode to verify it's valid.)

Ask: "What are 'magic bytes'?" (file format signatures — the first bytes of a file that identify its format. JPEG always starts with `\xff\xd8\xff`. PNG with `\x89PNG`. This is how `file` command on Linux works.)

Ask: "Why generate a random filename instead of using `header.Filename`?" (multiple reasons:
1. Path traversal attack: `../../etc/passwd` as a filename would write outside the uploads dir
2. Filename collisions: two uploads named `photo.jpg` would overwrite each other
3. Enumeration: users could guess each other's upload URLs
Random hex names are safe on all three counts.)

Ask: "Why `io.Seek(0, io.SeekStart)` after reading 512 bytes?" (we read the first 512 bytes for type detection, which advances the reader. To copy the whole file to disk, we seek back to the beginning. Without this, the first 512 bytes are missing from the saved file.)

---

## Serve the files

In `main.go`:

```go
// Serve uploaded files
r.Handle("/uploads/*", http.StripPrefix("/uploads/", http.FileServer(http.Dir(uploadDir))))
```

Ask: "What does `http.StripPrefix` do?" (removes the `/uploads/` prefix from the URL before passing to `http.FileServer` — FileServer looks in the directory for files matching the remaining path)

Ask: "In production, would you serve files directly from Go?" (no — nginx, Caddy, or a CDN. Go's file server is fine for development. In production, static files should be served by a reverse proxy or a CDN like CloudFront for global distribution and caching.)

---

## Wire it into the post flow

"After uploading a cover image, the client gets back a URL. They include that URL when creating or updating a post."

```
POST /uploads/cover  → returns { "url": "/uploads/abc123.jpg" }
POST /posts          → { "title": "...", "body": "...", "cover_url": "/uploads/abc123.jpg" }
```

Ask: "What should happen if a user uploads a cover image but never creates a post?" (orphaned file — sits on disk forever. Production solution: store uploads in a `pending_uploads` table with a TTL, delete unclaimed ones with a background job — using the job queue from lesson 57!)

---

## Checkpoint

1. "Why can't we submit file uploads as JSON?"
2. "What are magic bytes? Why use them instead of checking the file extension?"
3. "Why generate a random filename for every upload?" (give at least 2 reasons)
4. "What is path traversal? How does our code prevent it?"
5. "Why do we `http.MaxBytesReader` the body?" (prevent a client from uploading a 10GB file and exhausting memory)
6. "After detecting the image type, why do we need to seek back to the beginning?"

---

## Commit

```bash
git add .
git commit -m "File uploads: multipart parsing, magic byte validation, random filenames"
```
