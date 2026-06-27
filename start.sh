#!/usr/bin/env bash
# Run this to start your learning session.
# It opens Claude Code and kicks off the tutor automatically.
cd "$(dirname "$0")"

# Show progress so Claude knows where to pick up
echo ""
echo "Loading progress..."
go run tools/progress/main.go show 2>/dev/null || echo "(no progress tracked yet — first session)"
echo ""

claude "start"
