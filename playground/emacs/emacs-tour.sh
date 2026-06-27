#!/usr/bin/env bash
# =============================================================================
# Emacs Tour — Interactive companion guide
# Run this in a terminal NEXT TO an open Emacs window.
# This script lives in your terminal. Emacs lives next door.
# =============================================================================
set -euo pipefail

# --- Colors -------------------------------------------------------------------
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# --- Helpers ------------------------------------------------------------------
header() {
    echo ""
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════${RESET}"
    echo -e "${CYAN}${BOLD}  $1${RESET}"
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════${RESET}"
    echo ""
}

subheader() {
    echo ""
    echo -e "${BOLD}▸ $1${RESET}"
    echo ""
}

info() {
    echo -e "  $1"
}

ok() {
    echo -e "  ${GREEN}✓ $1${RESET}"
}

warn() {
    echo -e "  ${YELLOW}⚠  $1${RESET}"
}

danger() {
    echo ""
    echo -e "  ${RED}${BOLD}☠  DANGER: $1${RESET}"
    echo ""
}

key() {
    # Display a key binding clearly
    echo -e "  ${BOLD}${CYAN}$1${RESET}  →  $2"
}

pause() {
    echo ""
    echo -e "  ${DIM}Press Enter when you've tried it...${RESET}"
    read -r
}

confirm() {
    echo ""
    echo -e "  ${DIM}Press Enter to continue.${RESET}"
    read -r
}

# --- Check for Emacs ----------------------------------------------------------
check_emacs() {
    if command -v emacs &>/dev/null; then
        EMACS_VERSION=$(emacs --version 2>/dev/null | head -1)
        ok "Found: $EMACS_VERSION"
    else
        echo ""
        warn "Emacs not found. Install it first:"
        info "  brew install --cask emacs"
        info "  (or download from https://emacsformacosx.com)"
        echo ""
        exit 1
    fi
}

# --- Open practice file in Emacs ----------------------------------------------
open_practice_file() {
    local file="$1"
    # Try to open GUI emacs; fall back to terminal emacs
    if open -a Emacs "$file" 2>/dev/null; then
        ok "Opened $file in Emacs (GUI)"
    elif command -v emacsclient &>/dev/null && emacsclient -n "$file" 2>/dev/null; then
        ok "Opened $file via emacsclient"
    else
        emacs "$file" &
        ok "Opened $file in Emacs"
    fi
    sleep 1
}

# =============================================================================
# PRACTICE FILE
# =============================================================================
create_practice_file() {
    local dir
    dir="$(dirname "$0")/practice_files"
    mkdir -p "$dir"

    cat > "$dir/practice.txt" <<'PRACTICE'
The Quick Brown Fox
===================

This is your practice file. You will use it to learn Emacs navigation.

Line 1: The fox jumped over the lazy dog.
Line 2: Programming is the art of telling a computer what to do.
Line 3: Emacs is not an editor. It is a Lisp machine that can edit text.
Line 4: Every expert was once a beginner.
Line 5: The best way to learn is to do.

A longer paragraph to practice word-by-word movement:
The quick brown fox jumps over the lazy dog. She sells seashells by the
seashore. How much wood would a woodchuck chuck if a woodchuck could chuck
wood? Peter Piper picked a peck of pickled peppers.

Some code to look at:
  func main() {
      fmt.Println("hello, world")
  }

More lines below for scrolling practice:
Alpha - Beta - Gamma - Delta - Epsilon
Zeta - Eta - Theta - Iota - Kappa
Lambda - Mu - Nu - Xi - Omicron
Pi - Rho - Sigma - Tau - Upsilon
Phi - Chi - Psi - Omega

This is the last line of the practice file.
PRACTICE

    echo "$dir/practice.txt"
}

# =============================================================================
# LESSON 1: SURVIVAL — How to not be trapped
# =============================================================================
lesson_survival() {
    header "Lesson 1: Survival — How to Not Get Trapped"

    info "Before anything else, you need three keystrokes."
    info "These will save you every time you're lost or confused."
    echo ""
    info "Open Emacs. Just open it. Don't do anything yet."
    echo ""
    confirm

    subheader "The Escape Hatch — C-g"
    info "${BOLD}C-g${RESET} means: hold Control, press g."
    info ""
    info "C-g cancels WHATEVER is happening. Partial command? C-g."
    info "Accidentally started something? C-g. Emacs is waiting for input? C-g."
    info "It is your 'oh shit' key. It never deletes or saves anything."
    info "It just stops what Emacs is doing and returns to normal."
    echo ""
    key "C-g" "Cancel. Cancel. Cancel. Your best friend."
    echo ""
    info "Try it: Press M-x (hold Alt/Option/Meta, press x)."
    info "You'll see a 'M-x' prompt at the bottom of the screen."
    info "Now press C-g. The prompt disappears. Crisis averted."
    pause

    subheader "Undo — C-/"
    info "Emacs has undo. It undoes one action at a time."
    info "Keep pressing it to go further back."
    echo ""
    key "C-/"   "Undo last action"
    key "C-x u" "Also undo (alternate binding)"
    echo ""
    info "Emacs undo is unusual: after you undo some things,"
    info "any NEW action 'breaks' the undo chain and you can"
    info "undo the undos. Strange but powerful once you know it."
    echo ""
    info "Try it: Type a few letters in Emacs, then C-/ repeatedly."
    pause

    subheader "Quit — C-x C-c"
    info "C-x C-c quits Emacs. It will ask you to save if you have"
    info "unsaved changes. Never lose work accidentally."
    echo ""
    key "C-x C-c" "Quit Emacs (prompts to save)"
    echo ""
    warn "Don't quit yet. You need Emacs open for the rest of this tour."
    echo ""

    subheader "The bottom line — the echo area and mode line"
    info "Look at the very bottom of your Emacs window. Two things:"
    info ""
    info "  MODE LINE: the line that shows filename, mode, line number."
    info "  It looks like:  -UU-:----  *scratch*  All L1  (Lisp Interaction)"
    info ""
    info "  ECHO AREA: the line BELOW the mode line. This is where Emacs"
    info "  shows messages, prompts for input, and displays command feedback."
    info "  Watch it while you press keys."
    echo ""
    info "Press C-x C-f (hold Ctrl, press x, then hold Ctrl, press f)."
    info "Watch the echo area — it shows: Find file: ~/"
    info "Then press C-g to cancel."
    pause

    ok "You now know the three survival keystrokes."
    ok "C-g = cancel. C-/ = undo. C-x C-c = quit."
    echo ""
    confirm
}

# =============================================================================
# LESSON 2: NAVIGATION — Moving Around Without a Mouse
# =============================================================================
lesson_navigation() {
    local practice_file
    practice_file=$(create_practice_file)

    header "Lesson 2: Navigation — Moving Without a Mouse"

    info "Opening your practice file in Emacs..."
    open_practice_file "$practice_file"
    echo ""
    info "You'll see a file called practice.txt open in Emacs."
    info "Put your hands on the keyboard. No mouse for this lesson."
    echo ""
    confirm

    subheader "Character-by-character movement"
    info "The core navigation: one character or one line at a time."
    echo ""
    key "C-f" "Forward  one character  (→)"
    key "C-b" "Backward one character  (←)"
    key "C-n" "Next     line           (↓)"
    key "C-p" "Previous line           (↑)"
    echo ""
    info "These work just like arrow keys, but your hands never leave home row."
    info "Try moving around the practice file. Use only C-f, C-b, C-n, C-p."
    pause

    subheader "Word-by-word movement"
    info "Jumping a whole word at a time."
    echo ""
    key "M-f" "Forward  one word"
    key "M-b" "Backward one word"
    echo ""
    info "M means the Meta key. On Mac, that's the Option/Alt key by default."
    info "(We'll change it to Command later in the config lessons.)"
    info ""
    info "Go to the long paragraph that starts 'The quick brown fox...'"
    info "Use M-f to jump word by word across it. Then M-b to come back."
    pause

    subheader "Line navigation"
    echo ""
    key "C-a" "Beginning of line"
    key "C-e" "End of line"
    echo ""
    info "Go somewhere in the middle of a line. C-a jumps to the start."
    info "C-e jumps to the end. Try a few times."
    pause

    subheader "Buffer navigation — the whole file"
    echo ""
    key "M-<" "Very beginning of the buffer (first character)"
    key "M->" "Very end of the buffer (last character)"
    echo ""
    info "M-< means: hold Meta/Option, press Shift+, (which gives you <)."
    info "Jump to the bottom of the practice file, then back to the top."
    pause

    subheader "Scrolling"
    echo ""
    key "C-v" "Scroll down (next screen)"
    key "M-v" "Scroll up  (previous screen)"
    key "C-l" "Center the screen on the cursor (press 3 times: center, top, bottom)"
    echo ""
    info "C-v scrolls the view DOWN. M-v scrolls UP. Try them."
    info "Then try C-l a few times and watch what happens."
    pause

    subheader "Going to a specific line"
    echo ""
    key "M-g g" "Go to line number"
    echo ""
    info "Press M-g g, type '10', press Enter. You jump to line 10."
    info "Try it. Then C-g to cancel if you change your mind."
    pause

    subheader "The navigation map"
    echo ""
    info "                         C-p (up)"
    info "                          │"
    info "   C-b (back) ───── cursor ───── C-f (forward)"
    info "                          │"
    info "                         C-n (down)"
    echo ""
    info "   M-b (back word)   M-< (file start)   M-v (screen up)"
    info "   M-f (fwd word)    M-> (file end)      C-v (screen down)"
    info "   C-a (line start)  C-e (line end)      C-l (center)"
    echo ""
    confirm
}

# =============================================================================
# LESSON 3: EDITING — Cutting, Copying, Pasting
# =============================================================================
lesson_editing() {
    header "Lesson 3: Editing — The Kill Ring"

    info "Emacs calls cut 'kill' and paste 'yank'. Confusing at first,"
    info "but there's a reason: Emacs keeps a history of everything you've"
    info "killed. That history is called the kill ring. You can yank any"
    info "of the previous kills, not just the most recent one."
    echo ""
    confirm

    subheader "Deleting text"
    echo ""
    key "C-d"        "Delete character AFTER cursor (forward delete)"
    key "Backspace"  "Delete character BEFORE cursor"
    key "M-d"        "Delete word forward (kills it — goes to kill ring)"
    key "M-Backspace" "Delete word backward (kills it)"
    echo ""
    info "In the practice file, position your cursor in the middle of a word."
    info "Try C-d to delete forward, then M-d to delete a whole word."
    info "Then C-/ to undo it back."
    pause

    subheader "Killing lines — C-k"
    echo ""
    key "C-k" "Kill to end of line"
    echo ""
    info "C-k deletes from the cursor to the end of the current line."
    info "Press it TWICE on the same line: first press kills the text,"
    info "second press kills the empty line itself."
    echo ""
    info "Try it: go to a line in the practice file, press C-k."
    info "Undo with C-/ when done."
    pause

    subheader "Setting the mark — selecting text"
    echo ""
    key "C-SPC"   "Set mark (start selection)"
    echo ""
    info "C-SPC means Control + Space Bar. It plants a 'mark' at the cursor."
    info "Now move the cursor — everything between the mark and cursor is 'the region.'"
    info "The region is Emacs's selection."
    echo ""
    info "Try it: C-SPC, then move with C-f or C-n a few times."
    info "You'll see the region highlighted."
    pause

    subheader "Cut and copy the region"
    echo ""
    key "C-w" "Kill (cut) the region"
    key "M-w" "Copy the region (without deleting)"
    key "C-y" "Yank (paste) the last kill"
    echo ""
    info "Select some text with C-SPC, then C-w to cut it."
    info "Move somewhere else. C-y to paste it."
    info "Undo with C-/ to put things back."
    pause

    subheader "The kill ring — cycling through history"
    echo ""
    key "M-y" "After C-y, cycle to PREVIOUS kill (yank-pop)"
    echo ""
    info "Kill several things (C-k, C-k, C-k)."
    info "Then C-y to paste the most recent. Then M-y to cycle back to older kills."
    info "This is incredibly powerful once you're used to it."
    pause

    subheader "Duplicate a line (useful trick)"
    echo ""
    info "Emacs doesn't have a 'duplicate line' command built in, but you can:"
    info "  C-a       (go to beginning of line)"
    info "  C-k C-k   (kill line + blank line)"
    info "  C-y C-y   (yank twice)"
    info "  C-p       (go back up — now you have two copies)"
    echo ""
    info "Or: C-a, C-SPC, C-n (select line), M-w (copy), C-y (paste below)"
    pause

    subheader "Transpose (swap) characters and words"
    echo ""
    key "C-t" "Transpose two characters (swap char before and after cursor)"
    key "M-t" "Transpose two words"
    echo ""
    info "Place cursor between two characters and press C-t. They swap."
    info "Useful for fixing typos like 'hte' → 'the': put cursor on h, C-t."
    pause

    ok "You now know how to edit without a mouse."
    confirm
}

# =============================================================================
# LESSON 4: SEARCH — Finding Things Fast
# =============================================================================
lesson_search() {
    header "Lesson 4: Search — Finding Things Fast"

    subheader "Incremental search — C-s"
    echo ""
    key "C-s"      "Search forward (incremental)"
    key "C-r"      "Search backward (incremental)"
    key "C-s C-s"  "Search for the same thing again (next match)"
    key "Enter"    "Stop searching, leave cursor here"
    key "C-g"      "Cancel search, return cursor to where you started"
    echo ""
    info "C-s and start typing. Emacs jumps to the first match AS YOU TYPE."
    info "Press C-s again to jump to the next match."
    info "Press Enter when you've found what you want."
    info "Press C-g to give up and go back to where you started."
    echo ""
    info "Try: C-s, type 'fox'. Watch it find the word as you type."
    info "Then C-s again to find the next one. Then Enter to stop."
    pause

    subheader "Search for the word under cursor"
    echo ""
    key "C-s C-w" "After C-s, C-w adds the word under cursor to the search"
    echo ""
    info "Press C-s, then C-w. It grabs the current word and searches for it."
    info "Great for finding all usages of a variable name in code."
    pause

    subheader "Replace — M-%"
    echo ""
    key "M-%" "Query replace (find and replace with confirmation)"
    echo ""
    info "M-% asks: 'Query replace:' — type what to find, press Enter."
    info "Then: 'with:' — type the replacement, press Enter."
    info "For each match:"
    key "y or SPC" "Replace this one, move to next"
    key "n"        "Skip this one, move to next"
    key "!"        "Replace ALL remaining without asking"
    key "q"        "Quit"
    key "C-g"      "Cancel (but already-replaced ones stay replaced — undo if needed)"
    echo ""
    info "Try replacing 'fox' with 'cat' in the practice file."
    info "Use C-/ to undo afterward."
    pause

    ok "Tip: For regex search, C-M-s (regexp search forward)."
    ok "For now, C-s and M-% are all you need."
    confirm
}

# =============================================================================
# LESSON 5: BUFFERS AND WINDOWS — The Emacs Screen Model
# =============================================================================
lesson_buffers() {
    header "Lesson 5: Buffers and Windows"

    subheader "What are buffers?"
    info "A buffer is an in-memory document. When you open a file, Emacs"
    info "reads it into a buffer. When you edit, you're editing the buffer."
    info "Saving writes the buffer back to disk."
    echo ""
    info "Emacs can have MANY buffers open at once — far more than you can see."
    info "Windows are the panes you see on screen. One buffer shows in one window."
    info "You can have multiple windows showing different buffers."
    echo ""
    confirm

    subheader "Working with buffers"
    echo ""
    key "C-x b"   "Switch to a different buffer (by name)"
    key "C-x C-b" "List all open buffers"
    key "C-x k"   "Kill (close) a buffer"
    echo ""
    info "Try C-x b. The echo area shows: 'Switch to buffer: '"
    info "Start typing a buffer name. Tab completes. Enter confirms."
    info "Try switching to *scratch* (the default Emacs buffer)."
    pause

    subheader "Splitting the screen — windows"
    echo ""
    key "C-x 2" "Split window horizontally (top and bottom)"
    key "C-x 3" "Split window vertically (left and right)"
    key "C-x o" "Move cursor to the OTHER window (o = other)"
    key "C-x 1" "Keep only THIS window (close all others)"
    key "C-x 0" "Close THIS window (keep all others)"
    echo ""
    info "Try C-x 3 to split vertically. You get two panes."
    info "Then C-x o to jump to the other pane."
    info "Then C-x b to open a different buffer there."
    info "Then C-x 1 to go back to one window."
    pause

    subheader "Resize windows"
    echo ""
    key "C-x ^"   "Make window taller"
    key "C-x {"   "Make window narrower"
    key "C-x }"   "Make window wider"
    echo ""
    info "Or grab the dividing line with the mouse — that works too."
    confirm
}

# =============================================================================
# LESSON 6: FILES — Opening, Saving, and Finding
# =============================================================================
lesson_files() {
    header "Lesson 6: Files — Opening and Saving"

    subheader "The core file commands"
    echo ""
    key "C-x C-f" "Find file (open — creates it if it doesn't exist)"
    key "C-x C-s" "Save current buffer to its file"
    key "C-x C-w" "Save As (write to a different filename)"
    key "C-x C-v" "Find alternate file (replace current buffer with a new file)"
    echo ""
    info "C-x C-f is 'find file'. It's also 'new file' — if the path doesn't"
    info "exist, Emacs creates a new buffer for it. The file isn't created on"
    info "disk until you save with C-x C-s."
    echo ""
    info "Try C-x C-f and navigate to your home directory. Tab completes paths."
    info "Then C-g to cancel."
    pause

    subheader "The modification indicator"
    info "Look at the mode line at the bottom:"
    info "  -UU-:----  means unmodified."
    info "  -UU-:**--  means modified (unsaved changes)."
    info ""
    info "The ** is your warning that you have unsaved work."
    info "The U means the file uses Unicode encoding."
    echo ""
    info "Type something in your practice file. Watch the ** appear."
    info "Then C-x C-s to save. The ** disappears."
    pause

    subheader "Auto-save and backup files"
    info "Emacs auto-saves periodically to a file named #filename#"
    info "It also keeps backup files named filename~ (with a tilde)."
    info "If Emacs crashes, M-x recover-file will restore from auto-save."
    echo ""
    warn "You may see #file# and file~ scattered around. That's normal."
    warn "You can configure Emacs to put these somewhere else — we'll do that later."
    confirm
}

# =============================================================================
# LESSON 7: DIRED — The File Manager (With DANGER Zones)
# =============================================================================
lesson_dired() {
    header "Lesson 7: Dired — The File Manager"

    warn "This lesson has real danger zones. Pay close attention to the"
    warn "warnings. Dired can delete files permanently with a single keystroke."
    echo ""
    confirm

    subheader "Opening Dired"
    echo ""
    key "C-x d"   "Open Dired (asks which directory)"
    key "C-x C-f" "If you give it a directory, it opens in Dired"
    echo ""
    info "Try C-x d. Type ~ (your home directory) and press Enter."
    info "You'll see a listing of files and directories."
    pause

    subheader "Moving around in Dired"
    echo ""
    key "n"   "Next file"
    key "p"   "Previous file"
    key "Enter" "Open file or directory"
    key "^"   "Go to parent directory"
    key "q"   "Quit Dired"
    echo ""
    info "Use n and p to move up and down. Enter to open something."
    info "^ goes up one directory (like cd ..)."
    pause

    subheader "Marking files"
    echo ""
    key "m"   "Mark a file (for later operations)"
    key "u"   "Unmark a file"
    key "U"   "Unmark ALL files"
    key "* ." "Mark all files with a certain extension"
    echo ""
    info "Mark is NOT delete. You're just tagging files for batch operations."
    info "Marks appear as > at the start of the line."
    info "Try marking and unmarking a few files."
    pause

    danger "THE DANGER ZONE — Read this before continuing"
    echo -e "  ${RED}The following commands DELETE files. There is NO TRASH.${RESET}"
    echo -e "  ${RED}Deleted files are GONE. They do NOT go to Trash.${RESET}"
    echo ""

    key "d"   "Mark for DELETION (shows D flag, doesn't delete yet)"
    key "x"   "Execute marked deletions (THIS IS WHERE IT HAPPENS)"

    danger "D (capital) — Deletes the file AT CURSOR IMMEDIATELY. No confirmation."
    echo -e "  ${RED}There is no undo for D. The file is gone.${RESET}"
    echo ""

    danger "! — Runs a shell command on the marked files."
    echo -e "  ${RED}You could accidentally run rm -rf on your entire home directory.${RESET}"
    echo -e "  ${RED}Think twice before pressing ! in Dired.${RESET}"
    echo ""

    info "The safe workflow for deleting:"
    info "  1. Use lowercase d to MARK files for deletion (reversible)"
    info "  2. Review what's marked"
    info "  3. Press x to actually delete (asks for confirmation)"
    info "  4. OR press u to unmark if you changed your mind"
    echo ""
    info "The ONLY time you should press D or ! is when you are"
    info "absolutely sure you know what you're doing."
    echo ""
    confirm

    subheader "Copying and moving in Dired"
    echo ""
    key "C"   "Copy marked files (asks destination)"
    key "R"   "Rename/Move marked files"
    key "+"   "Create a new directory"
    echo ""
    info "These are safer. They ask for a destination and confirm."
    pause

    subheader "Viewing file info"
    echo ""
    key "l"   "Refresh the directory listing"
    key "s"   "Toggle sort (by name / by date)"
    key "("   "Toggle showing hidden files"
    key "i"   "Insert subdirectory listing inline"
    echo ""

    ok "Dired summary: n/p to navigate, Enter to open, ^ to go up."
    ok "d to mark-for-delete, x to execute. AVOID D and ! until you're confident."
    confirm
}

# =============================================================================
# LESSON 8: HELP — Getting Help From Emacs Itself
# =============================================================================
lesson_help() {
    header "Lesson 8: Help — Emacs Knows Everything About Itself"

    info "Emacs has built-in documentation for every function, variable,"
    info "and keybinding. You never have to leave Emacs to look something up."
    echo ""
    confirm

    subheader "Describe a key — what does this key do?"
    echo ""
    key "C-h k" "Describe key — press C-h k, then press any key"
    echo ""
    info "Try C-h k, then press C-x C-s."
    info "Emacs opens a help buffer explaining exactly what that key does."
    info "Press q to close the help buffer."
    pause

    subheader "Describe a function — what does this function do?"
    echo ""
    key "C-h f" "Describe function — shows documentation for any function"
    echo ""
    info "Try C-h f, then type 'save-buffer' and press Enter."
    info "You'll see the full documentation for that function."
    info "The help buffer shows: what arguments it takes, what it does,"
    info "what its keybinding is, and where in the source code it's defined."
    pause

    subheader "Describe a variable — what is this setting?"
    echo ""
    key "C-h v" "Describe variable — shows current value and documentation"
    echo ""
    info "Try C-h v, then type 'cursor-type' and press Enter."
    info "It shows the current value and what values are allowed."
    pause

    subheader "Describe mode — what keybindings are active right now?"
    echo ""
    key "C-h m" "Describe mode — shows all keybindings for the current mode"
    echo ""
    info "This is incredibly useful when you're in an unfamiliar mode."
    info "Try it and scroll through the list."
    pause

    subheader "M-x — the command palette"
    echo ""
    key "M-x" "Run any command by name (like a command palette)"
    echo ""
    info "M-x is how you run commands that don't have a keybinding."
    info "It also autocompletes. Type a partial name and press Tab."
    info ""
    info "Try M-x, type 'count-words', press Enter."
    info "Emacs tells you how many words are in the current buffer."
    echo ""
    info "Every keybinding in Emacs is just a shortcut for an M-x command."
    info "C-x C-s is just a shortcut for M-x save-buffer."
    pause

    subheader "The Info documentation system"
    echo ""
    key "C-h i" "Open the Info manual (full Emacs documentation)"
    echo ""
    info "The Info manual is a complete reference. Use it when you need"
    info "deep information about any topic. Navigate with n (next), p (previous),"
    info "u (up), and q (quit)."
    pause

    subheader "Search for commands matching a keyword"
    echo ""
    key "C-h a" "Apropos — search for commands containing a keyword"
    echo ""
    info "Try C-h a, type 'find'. It shows all commands with 'find' in the name."
    info "This is great when you know what you WANT to do but not the command name."
    pause

    ok "The help system is there. Use it. Emacs is self-documenting."
    ok "When in doubt: C-h k (what does this key do?)"
    ok "              C-h f (what does this function do?)"
    ok "              C-h m (what can I do in this mode?)"
    echo ""
    confirm
}

# =============================================================================
# WRAP UP
# =============================================================================
wrap_up() {
    header "You've Completed the Emacs Tour"

    echo ""
    info "${BOLD}What you now know:${RESET}"
    echo ""
    ok "Survive:    C-g (cancel), C-/ (undo), C-x C-c (quit)"
    ok "Navigate:   C-f/b/n/p (char/line), M-f/b (word), C-a/e (line ends)"
    ok "            M-</> (buffer start/end), C-v/M-v (scroll)"
    ok "Edit:       C-k (kill line), C-SPC (mark), C-w/M-w (cut/copy), C-y (paste)"
    ok "Search:     C-s (forward), C-r (backward), M-% (replace)"
    ok "Buffers:    C-x b (switch), C-x k (kill), C-x C-b (list)"
    ok "Windows:    C-x 2/3 (split), C-x o (other), C-x 1 (only this)"
    ok "Files:      C-x C-f (open), C-x C-s (save)"
    ok "Dired:      C-x d (open), n/p (move), Enter (open), ^ (up), d/x (delete)"
    ok "Help:       C-h k/f/v/m (describe key/function/variable/mode)"
    echo ""
    warn "AVOID in Dired: D (instant delete), ! (run shell command)"
    echo ""
    info "${BOLD}Next step:${RESET}"
    info "  Tell Claude Code you've finished the Emacs tour."
    info "  Claude will guide you through configuring Emacs —"
    info "  cleaning up the UI, setting up packages, and building"
    info "  your own custom configuration file."
    echo ""
}

# =============================================================================
# MAIN MENU
# =============================================================================
show_menu() {
    echo ""
    echo -e "${BOLD}${CYAN}  Emacs Tour — Choose a Lesson${RESET}"
    echo ""
    echo -e "  ${BOLD}1${RESET}  Survival       — C-g, undo, quit"
    echo -e "  ${BOLD}2${RESET}  Navigation     — moving without a mouse"
    echo -e "  ${BOLD}3${RESET}  Editing        — cut, copy, paste, the kill ring"
    echo -e "  ${BOLD}4${RESET}  Search         — finding and replacing text"
    echo -e "  ${BOLD}5${RESET}  Buffers        — managing multiple documents"
    echo -e "  ${BOLD}6${RESET}  Files          — open, save, find"
    echo -e "  ${BOLD}7${RESET}  Dired          — the file manager (danger zones!)"
    echo -e "  ${BOLD}8${RESET}  Help           — let Emacs teach you"
    echo -e "  ${BOLD}a${RESET}  All lessons in order"
    echo -e "  ${BOLD}q${RESET}  Quit"
    echo ""
    echo -n "  Choice: "
}

main() {
    clear
    echo ""
    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════════╗"
    echo "  ║         EMACS TOUR                    ║"
    echo "  ║   Learn Emacs One Lesson at a Time    ║"
    echo "  ╚═══════════════════════════════════════╝"
    echo -e "${RESET}"
    echo ""
    info "This tour runs in the TERMINAL."
    info "Keep Emacs open in a SEPARATE WINDOW next to this."
    info "The tour tells you what to do. You do it in Emacs."
    info "Then come back here and press Enter to continue."
    echo ""
    info "Before we start — checking for Emacs..."
    check_emacs
    echo ""
    confirm

    while true; do
        show_menu
        read -r choice
        case "$choice" in
            1) lesson_survival ;;
            2) lesson_navigation ;;
            3) lesson_editing ;;
            4) lesson_search ;;
            5) lesson_buffers ;;
            6) lesson_files ;;
            7) lesson_dired ;;
            8) lesson_help ;;
            a)
                lesson_survival
                lesson_navigation
                lesson_editing
                lesson_search
                lesson_buffers
                lesson_files
                lesson_dired
                lesson_help
                wrap_up
                ;;
            q|Q)
                wrap_up
                break
                ;;
            *)
                warn "Type a number 1-8, 'a' for all, or 'q' to quit."
                ;;
        esac
    done
}

main
