#!/usr/bin/env bash
# =============================================================================
# SHELL TOUR — An interactive introduction to the Unix shell
# =============================================================================
#
# This script is two things at once:
#   1. Something you RUN to learn what the shell can do
#   2. Something you READ to learn how bash scripts are written
#
# Every piece of code has a comment explaining what it does and why.
# When something looks confusing, the comment next to it is the explanation.
#
# HOW TO RUN:
#   bash shell-tour.sh
#   (or: chmod +x shell-tour.sh && ./shell-tour.sh)
# =============================================================================

# "set -e" means: if ANY command exits with an error, stop the whole script.
# Without this, the script keeps running even after failures, which can cause
# confusing behavior. It's good practice to always include this.
set -e

# "set -u" means: if you try to use a variable that was never set, throw an error.
# Without this, using an undefined variable just gives you an empty string —
# which can lead to bugs like "rm -rf $UNDEFINED_VAR/" becoming "rm -rf /".
set -u


# =============================================================================
# COLORS
# =============================================================================
# ANSI escape codes let us print colored text in terminals.
# The format is: \033[ + color code + m
#
# Common codes:
#   0  = reset to default
#   1  = bold
#   31 = red, 32 = green, 33 = yellow, 34 = blue, 36 = cyan
#
# The "readonly" keyword means this variable cannot be changed later.
# "export" makes the variable available to programs we run FROM this script.
readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;34m'
readonly CYAN='\033[1;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly RESET='\033[0m'

# A variable for a horizontal rule (line of dashes)
# We define it once here and reuse it in multiple places
readonly RULE="${BLUE}$(printf '═%.0s' {1..60})${RESET}"


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
# In bash, functions look like: name() { ... }
# You call them just by typing the name.
# Arguments are accessed as $1, $2, $3... (first, second, third argument)
# All arguments together: "$@"
# Number of arguments: $#

# Print a big section header
header() {
    # "$1" = the first argument passed to this function
    # We use it as the header text
    echo
    echo -e "$RULE"
    # printf formats a string. "%-58s" means: left-align in 58 characters.
    # This centers the text within the rule.
    echo -e "${BLUE}║${RESET} ${BOLD}$1${RESET}"
    echo -e "$RULE"
    echo
}

# Print a smaller subsection header
subheader() {
    echo
    echo -e "${CYAN}▸ $1${RESET}"
    echo -e "${DIM}$(printf '─%.0s' {1..50})${RESET}"
}

# Print a normal info line
info() {
    echo -e "${CYAN}ℹ${RESET}  $1"
}

# Print a success message
ok() {
    echo -e "${GREEN}✓${RESET}  $1"
}

# Print a warning
warn() {
    echo -e "${YELLOW}⚠${RESET}  $1"
}

# Pause and wait for the user to press Enter before continuing.
# "read" with no variable name just waits for Enter.
pause() {
    echo
    # printf without -n keeps the cursor on the same line (no newline)
    printf "${YELLOW}Press Enter to continue...${RESET}"
    read -r  # -r means "raw" — don't interpret backslashes
    echo
}

# Show a command, explain it, then actually run it.
# Usage: demo "the command" "explanation of what it does"
demo() {
    local cmd="$1"        # "local" = this variable only exists inside this function
    local desc="$2"

    echo
    echo -e "${GREEN}What we're doing:${RESET} $desc"
    echo -e "${BOLD}${BLUE}\$${RESET} ${BOLD}$cmd${RESET}"
    echo -e "${DIM}Output:${RESET}"

    # "eval" runs a string as a shell command.
    # Normally you'd just type the command, but since we stored it in a variable,
    # we need eval to execute it.
    eval "$cmd"
}

# Show a command but DON'T run it (for dangerous examples)
show_only() {
    local cmd="$1"
    local desc="$2"

    echo
    echo -e "${RED}Example (DO NOT RUN):${RESET} $desc"
    echo -e "${BOLD}${RED}\$${RESET} ${BOLD}$cmd${RESET}"
}

# Ask the user a yes/no question.
# Returns 0 (success/yes) or 1 (failure/no)
confirm() {
    local question="$1"
    local answer

    printf "${YELLOW}%s [y/N]${RESET} " "$question"
    read -r answer

    # [[ ]] is a bash test. "=~" tests a regex.
    # This checks if the answer starts with y or Y.
    [[ "$answer" =~ ^[yY] ]]
}


# =============================================================================
# LESSON: NAVIGATION
# =============================================================================

lesson_navigation() {
    header "LESSON 1: Navigation — Moving Around Your Computer"

    info "Your files live in a tree of folders (directories)."
    info "You are always 'inside' some folder. These commands show where you are"
    info "and let you move around."
    pause

    subheader "Where am I?"

    # pwd = Print Working Directory
    # It prints the full path from / (the root) to wherever you are right now
    demo "pwd" "Print Working Directory — shows exactly where you are"
    pause

    subheader "What's in here?"

    # ls = list
    # Without flags it just shows filenames
    demo "ls" "List files in the current directory"
    echo
    echo -e "  Now with more detail:"

    # ls -la breaks down as:
    #   -l = long format (shows permissions, owner, size, date)
    #   -a = all (including hidden files that start with a dot)
    demo "ls -la" "List with full details, including hidden files"
    pause

    echo
    info "What does each column mean in 'ls -la' output?"
    echo
    echo "  -rw-r--r--  1  alice  staff  1234  Jun 12  file.txt"
    echo "  │           │  │      │      │      │       └─ filename"
    echo "  │           │  │      │      │      └───────── date modified"
    echo "  │           │  │      │      └──────────────── size in bytes"
    echo "  │           │  │      └─────────────────────── group"
    echo "  │           │  └────────────────────────────── owner"
    echo "  │           └───────────────────────────────── number of links"
    echo "  └───────────────────────────────────────────── permissions"
    echo
    echo "  The permissions string: -rw-r--r--"
    echo "    First char:  - means file, d means directory, l means link"
    echo "    Next 3:      rw-  = owner can Read + Write (not execute)"
    echo "    Next 3:      r--  = group can only Read"
    echo "    Last 3:      r--  = everyone else can only Read"
    pause

    subheader "Moving around"

    # Create a safe temp directory for our demos
    # $$ is the Process ID of the current shell — using it makes a unique name
    # so multiple people can run this script at the same time without conflicts
    local demo_dir
    demo_dir="/tmp/shell-tour-$$"
    mkdir -p "$demo_dir"

    # Trap: even if the script exits early (error, Ctrl+C), clean up our temp files.
    # "trap 'command' EXIT" runs the command when the script exits for any reason.
    trap "rm -rf '$demo_dir'" EXIT

    # Make some folders to navigate
    mkdir -p "$demo_dir/projects/myapp/src"
    mkdir -p "$demo_dir/projects/myapp/tests"
    mkdir -p "$demo_dir/documents"
    touch "$demo_dir/documents/notes.txt"
    touch "$demo_dir/projects/myapp/src/main.go"

    demo "cd $demo_dir" "Move into our demo folder"
    demo "pwd" "See where we are now"
    demo "ls" "See what's in this folder"
    pause

    demo "cd projects/myapp" "Go into a subfolder"
    demo "pwd" "See the full path"
    demo "ls -la" "List everything here"
    pause

    demo "cd .." "Go UP one level (.. always means 'parent folder')"
    demo "pwd" "We're back in projects/"

    demo "cd ../.." "Go up TWO levels at once"
    demo "pwd" "Back where we started"
    pause

    demo "cd ~" "Go to your home directory (~ is always your home)"
    demo "pwd" "Home sweet home"

    # cd - goes back to where you JUST were, like pressing Back in a browser
    info "Handy trick: 'cd -' jumps back to wherever you were last"
    demo "cd -" "Jump back to the previous directory"
    demo "pwd" "We're back in the demo folder"
    pause

    subheader "Making and removing directories"

    demo "mkdir $demo_dir/new-folder" "Create a new folder"
    demo "ls $demo_dir" "See it in the listing"

    # mkdir -p creates ALL the directories in the path, even if parents don't exist yet
    # Without -p, mkdir would fail if the parent didn't exist
    demo "mkdir -p $demo_dir/a/b/c/d/e" "Create a whole nested path at once"
    demo "ls -R $demo_dir/a" "See all the nested folders (-R = recursive)"
    pause

    # rmdir only works on EMPTY directories
    demo "rmdir $demo_dir/new-folder" "Remove an empty directory"
    info "rmdir only works if the directory is empty."
    info "To remove a folder AND everything inside it, use: rm -rf foldername/"
    warn "But be careful with rm -rf — there is no undo! We cover this in the Danger section."

    pause

    # Go back home before finishing this lesson
    cd ~
    ok "Navigation lesson complete!"
    pause
}


# =============================================================================
# LESSON: FILES
# =============================================================================

lesson_files() {
    header "LESSON 2: Working with Files"

    local demo_dir="/tmp/shell-tour-files-$$"
    mkdir -p "$demo_dir"
    trap "rm -rf '$demo_dir'" EXIT
    cd "$demo_dir"

    subheader "Creating files"

    # touch creates an empty file. If the file already exists, it just updates
    # the "last modified" timestamp.
    demo "touch hello.txt" "Create an empty file"
    demo "touch file1.txt file2.txt file3.txt" "Create multiple files at once"
    demo "ls -la" "See our new files"
    pause

    # The > operator REDIRECTS output into a file.
    # echo prints text. By combining echo with >, we write text into a file.
    demo "echo 'Hello, World!' > hello.txt" "Write text into hello.txt"
    demo "echo 'This is line 2' >> hello.txt" "APPEND text (>> adds to the end)"
    demo "echo 'This is line 3' >> hello.txt" "Add one more line"
    pause

    subheader "Reading files"

    # cat prints the ENTIRE file contents to the screen
    demo "cat hello.txt" "Print the whole file"
    pause

    # head shows only the FIRST N lines. Default is 10.
    echo "Apple" > fruits.txt
    echo "Banana" >> fruits.txt
    echo "Cherry" >> fruits.txt
    echo "Durian" >> fruits.txt
    echo "Elderberry" >> fruits.txt
    echo "Fig" >> fruits.txt

    demo "head -n 3 fruits.txt" "Show first 3 lines"
    demo "tail -n 2 fruits.txt" "Show last 2 lines"
    pause

    # wc = word count. -l counts lines, -w counts words, -c counts characters
    demo "wc -l fruits.txt" "Count how many lines are in the file"
    demo "wc -w hello.txt" "Count words in hello.txt"
    pause

    subheader "Copying files"

    # cp = copy. Source comes first, destination comes second.
    demo "cp hello.txt hello-backup.txt" "Make a copy of hello.txt"
    demo "ls -la" "See both files exist now"
    demo "cat hello-backup.txt" "The copy has the same contents"
    pause

    # To copy a whole directory, you need -r (recursive)
    mkdir -p "$demo_dir/myproject/src"
    echo "package main" > "$demo_dir/myproject/src/main.go"
    demo "cp -r $demo_dir/myproject $demo_dir/myproject-backup" "Copy a whole directory"
    demo "ls $demo_dir" "See both project folders"
    pause

    subheader "Moving and renaming"

    # mv = move. It works for both moving AND renaming.
    # If the destination is in the same directory, it's a rename.
    # If the destination is a different directory, it's a move.
    demo "mv hello-backup.txt hello-renamed.txt" "Rename a file"
    demo "ls -la" "hello-backup.txt is gone, hello-renamed.txt exists"
    pause

    mkdir -p "$demo_dir/archive"
    demo "mv hello-renamed.txt $demo_dir/archive/" "Move a file to another directory"
    demo "ls $demo_dir/archive/" "It's in the archive now"
    demo "ls -la" "It's gone from here"
    pause

    subheader "Checking file types and sizes"

    # file tells you what KIND of data is in a file (regardless of extension)
    demo "file hello.txt" "What kind of file is this?"
    demo "file fruits.txt" "What about this one?"
    pause

    # du = disk usage. Shows how much space files take up.
    # -h = human-readable (KB, MB instead of bytes)
    # -s = summary (show total for each argument, not each individual file)
    demo "du -sh $demo_dir" "How much space does our demo folder use?"
    pause

    cd ~
    ok "File operations lesson complete!"
    pause
}


# =============================================================================
# LESSON: SEARCHING
# =============================================================================

lesson_searching() {
    header "LESSON 3: Searching — Finding What You're Looking For"

    local demo_dir="/tmp/shell-tour-search-$$"
    mkdir -p "$demo_dir/src"
    trap "rm -rf '$demo_dir'" EXIT

    # Create some files with content to search through
    cat > "$demo_dir/src/main.go" << 'EOF'
package main

import "fmt"

func main() {
    greeting := "Hello, World!"
    fmt.Println(greeting)
    // TODO: add error handling
}
EOF

    cat > "$demo_dir/src/user.go" << 'EOF'
package main

import "fmt"

type User struct {
    Name  string
    Email string
}

func (u User) Greet() string {
    return fmt.Sprintf("Hello, %s!", u.Name)
    // TODO: add validation
}
EOF

    cat > "$demo_dir/notes.txt" << 'EOF'
Meeting notes - June 2025

Action items:
- Fix the login bug (urgent)
- Update the README
- TODO: write unit tests
- Talk to Alice about the database migration
TODO: follow up with Bob
EOF

    subheader "grep — searching INSIDE files"

    # grep = "globally search for a regular expression and print matching lines"
    # Basic usage: grep "what to search for" file-to-search
    demo "grep 'TODO' $demo_dir/notes.txt" "Find lines containing 'TODO' in notes.txt"
    pause

    # -i = case insensitive (finds TODO, todo, Todo, tOdO, etc.)
    demo "grep -i 'todo' $demo_dir/notes.txt" "Case-insensitive search"
    pause

    # -n = show line numbers with the results
    demo "grep -n 'TODO' $demo_dir/notes.txt" "Show which line numbers match"
    pause

    # -r = recursive (search through ALL files in a directory)
    demo "grep -r 'TODO' $demo_dir/" "Search through ALL files in the directory"
    pause

    # -l = only show filenames (not the matching lines)
    demo "grep -rl 'TODO' $demo_dir/" "Just show which FILES contain 'TODO'"
    pause

    # -v = invert — show lines that do NOT match
    demo "grep -v 'TODO' $demo_dir/notes.txt" "Show lines that DON'T contain 'TODO'"
    pause

    # Combining: search for import statements in all .go files
    demo "grep -rn 'import' $demo_dir/ --include='*.go'" "Find all import lines in .go files"
    pause

    subheader "find — finding FILES by name, type, or other properties"

    # find . -name "*.go" means:
    #   find      = the command
    #   .         = start searching from here (current directory)
    #   -name     = match the filename
    #   "*.go"    = any filename ending in .go (* is a wildcard)
    demo "find $demo_dir -name '*.go'" "Find all .go files"
    pause

    # -type f = only show files (not directories)
    # -type d = only show directories
    demo "find $demo_dir -type f" "Find all files (not directories)"
    demo "find $demo_dir -type d" "Find all directories"
    pause

    # Find files modified in the last 1 day
    demo "find $demo_dir -mtime -1" "Files modified in the last day"
    pause

    # Find and then DO something with the results (-exec)
    # {} is a placeholder for each found file
    # \; ends the -exec command
    info "You can run a command on every file you find with -exec:"
    demo "find $demo_dir -name '*.go' -exec echo 'Found: {}' \\;" "Run 'echo' on each .go file found"
    pause

    subheader "which — where is this program installed?"

    demo "which bash" "Where is bash installed?"
    demo "which ls" "Where is ls?"
    demo "which go" "Where is Go? (if installed)"
    pause

    ok "Searching lesson complete!"
    pause
}


# =============================================================================
# LESSON: PIPES
# =============================================================================

lesson_pipes() {
    header "LESSON 4: Pipes — Chaining Commands Together"

    info "The pipe symbol '|' sends the OUTPUT of one command as INPUT to the next."
    info "This is one of the most powerful ideas in Unix — small, focused commands"
    info "that you combine to do complex things."
    echo
    info "Think of it like an assembly line:"
    echo "  raw data → command 1 → cleaner data → command 2 → final result"
    pause

    local demo_dir="/tmp/shell-tour-pipes-$$"
    mkdir -p "$demo_dir"
    trap "rm -rf '$demo_dir'" EXIT

    # Create a log file to work with
    cat > "$demo_dir/app.log" << 'EOF'
2025-06-01 10:00:01 INFO  Server started on port 8080
2025-06-01 10:01:23 INFO  User alice logged in
2025-06-01 10:02:45 ERROR Database connection failed: timeout
2025-06-01 10:03:12 INFO  User bob logged in
2025-06-01 10:04:33 ERROR Failed to process payment: invalid card
2025-06-01 10:05:01 INFO  User alice logged out
2025-06-01 10:06:22 WARN  Memory usage at 80%
2025-06-01 10:07:44 ERROR Database connection failed: timeout
2025-06-01 10:08:59 INFO  User charlie logged in
2025-06-01 10:09:15 ERROR Failed to process payment: insufficient funds
2025-06-01 10:10:30 WARN  Memory usage at 90%
2025-06-01 10:11:45 ERROR Database connection failed: timeout
2025-06-01 10:12:00 INFO  Server shutting down
EOF

    subheader "Basic pipes"

    # cat outputs the file, | sends it to grep, grep filters for ERROR lines
    demo "cat $demo_dir/app.log | grep 'ERROR'" "Show only ERROR lines from the log"
    pause

    # Multiple pipes chained together
    # cat → grep (filter errors) → wc -l (count them)
    demo "cat $demo_dir/app.log | grep 'ERROR' | wc -l" "Count how many errors there are"
    pause

    # sort sorts lines alphabetically. uniq removes adjacent duplicate lines.
    # To count unique errors, sort first (so duplicates are adjacent), then uniq -c
    demo "cat $demo_dir/app.log | grep 'ERROR' | sort" "Sort the error lines"
    pause

    # uniq -c = count consecutive duplicates
    demo "cat $demo_dir/app.log | grep 'ERROR' | sort | uniq -c" "Count each unique error type"
    pause

    # sort -rn = sort numerically (-n) in reverse (-r), so biggest counts come first
    demo "cat $demo_dir/app.log | grep 'ERROR' | sort | uniq -c | sort -rn" "Most common errors first"
    pause

    subheader "head and tail with pipes"

    demo "cat $demo_dir/app.log | head -n 3" "Show only the first 3 log lines"
    demo "cat $demo_dir/app.log | tail -n 3" "Show only the last 3 log lines"

    # head + tail together can give you the middle of a file
    info "Combine head and tail to see a specific range of lines:"
    demo "cat $demo_dir/app.log | head -n 8 | tail -n 3" "Lines 6-8 (get first 8, then last 3 of those)"
    pause

    subheader "Redirects — saving output to files"

    # > creates/overwrites a file with the output
    demo "cat $demo_dir/app.log | grep 'ERROR' > $demo_dir/errors.txt" "Save errors to a file"
    demo "cat $demo_dir/errors.txt" "See what we saved"
    pause

    # >> appends to a file instead of overwriting
    demo "echo '--- end of errors ---' >> $demo_dir/errors.txt" "Append a line to the file"
    demo "tail -n 3 $demo_dir/errors.txt" "See the end of the file"
    pause

    # 2> redirects stderr (error output) to a file
    info "By default, error messages go to 'stderr' (a different output stream than normal output)"
    info "You can redirect them separately:"
    echo
    echo -e "  ${BOLD}command > output.txt 2> errors.txt${RESET}   — normal output and errors go to separate files"
    echo -e "  ${BOLD}command > output.txt 2>&1${RESET}           — both go to the same file"
    echo -e "  ${BOLD}command 2>/dev/null${RESET}                  — discard errors (send them to the void)"
    pause

    subheader "awk and cut — extracting columns"

    # awk is a full text-processing language. Its simplest use: print specific columns.
    # $1 = first field, $2 = second field, etc. (fields separated by whitespace by default)
    demo "cat $demo_dir/app.log | awk '{print \$3}'" "Print only the log level column (3rd word)"
    pause

    # cut works on delimiters
    # -d = delimiter (what separates columns), -f = which field number to print
    demo "cat $demo_dir/app.log | cut -d' ' -f1" "Get just the date column (split on space, get field 1)"
    pause

    ok "Pipes lesson complete!"
    pause
}


# =============================================================================
# LESSON: PERMISSIONS
# =============================================================================

lesson_permissions() {
    header "LESSON 5: Permissions — Who Can Do What"

    local demo_dir="/tmp/shell-tour-perms-$$"
    mkdir -p "$demo_dir"
    trap "rm -rf '$demo_dir'" EXIT
    cd "$demo_dir"

    info "Every file and directory has permissions: who can read it, write to it,"
    info "or execute it as a program. This is fundamental to Unix security."
    pause

    demo "ls -la $demo_dir" "See current permissions"
    pause

    echo
    info "Reading the permissions string, e.g.: -rw-r--r--"
    echo
    echo "  Position 1:     - file, d directory, l link"
    echo "  Positions 2-4:  owner permissions  (rw-)"
    echo "  Positions 5-7:  group permissions  (r--)"
    echo "  Positions 8-10: everyone else       (r--)"
    echo
    echo "  r = read   (can look at/list it)"
    echo "  w = write  (can change it)"
    echo "  x = execute (can run it as a program, or enter if it's a directory)"
    echo "  - = no permission"
    pause

    touch "$demo_dir/script.sh"
    echo '#!/bin/bash' > "$demo_dir/script.sh"
    echo 'echo "This script ran!"' >> "$demo_dir/script.sh"

    demo "ls -la $demo_dir/script.sh" "See the script's permissions"
    pause

    # chmod +x adds execute permission for everyone
    demo "chmod +x $demo_dir/script.sh" "Make the script executable"
    demo "ls -la $demo_dir/script.sh" "See the 'x' appear in permissions"
    demo "$demo_dir/script.sh" "Now we can run it!"
    pause

    # chmod with numbers:
    # Each permission group is a 3-bit number: r=4, w=2, x=1
    # 7 = 4+2+1 = rwx (all three)
    # 6 = 4+2   = rw- (read and write)
    # 5 = 4+1   = r-x (read and execute)
    # 4 = 4     = r-- (read only)
    # 0 = 0     = --- (no permissions)
    echo
    info "You can also use numbers to set permissions:"
    echo
    echo "  chmod 755 file  = rwxr-xr-x  (owner: all  | others: read+execute)"
    echo "  chmod 644 file  = rw-r--r--  (owner: rw   | others: read only)"
    echo "  chmod 600 file  = rw-------  (owner only, nobody else)"
    echo "  chmod 777 file  = rwxrwxrwx  (EVERYONE can do everything — rarely a good idea)"
    echo
    echo "  The three digits are: owner / group / everyone else"
    echo "  Each digit: 4=read  2=write  1=execute  (add them up)"

    demo "chmod 644 $demo_dir/script.sh" "Set permissions with numbers (rw-r--r--)"
    demo "ls -la $demo_dir/script.sh" "See the change"
    pause

    ok "Permissions lesson complete!"
    pause
}


# =============================================================================
# LESSON: PROCESSES
# =============================================================================

lesson_processes() {
    header "LESSON 6: Processes — What's Running on Your Computer"

    info "A process is a program that's currently running. Every time you run a command,"
    info "the shell starts a new process. The operating system manages all of them."
    pause

    subheader "Listing processes"

    # ps = process status
    # aux breaks down as:
    #   a = show processes for all users (not just yours)
    #   u = show in user-friendly format (with username, CPU%, memory%)
    #   x = include processes that aren't attached to a terminal
    demo "ps aux | head -20" "Show running processes (first 20)"
    pause

    info "Each column in ps aux output:"
    echo "  USER   = who owns this process"
    echo "  PID    = Process ID (the unique number you use to kill it)"
    echo "  %CPU   = CPU usage percentage"
    echo "  %MEM   = memory usage percentage"
    echo "  COMMAND = what program is running"
    pause

    # Find a specific process
    demo "ps aux | grep bash" "Find bash processes"
    pause

    subheader "Process IDs (PIDs)"

    # $$ is a special bash variable containing the PID of the current shell
    echo
    echo -e "${CYAN}The current script's PID:${RESET} $$"
    echo
    info "Every process has a unique PID. You use it to send signals to the process."
    pause

    subheader "Background jobs"

    # When you append & to a command, it runs in the background
    # The shell immediately gives you back a prompt while it runs
    info "You can run commands in the background by adding & at the end"
    echo
    echo -e "${BOLD}\$ sleep 10 &${RESET}"
    echo "  [1] 12345    ← the job number and PID"
    echo "  (shell is immediately available again)"
    echo
    echo -e "${BOLD}\$ jobs${RESET}   ← see background jobs"
    echo "  [1]+  Running    sleep 10 &"
    echo
    echo -e "${BOLD}\$ fg${RESET}     ← bring it to the foreground"
    echo -e "${BOLD}\$ bg${RESET}     ← after Ctrl+Z (pause), send it to background"
    pause

    subheader "Killing processes"

    echo
    echo "  Keyboard shortcuts while a process is running:"
    echo -e "  ${BOLD}Ctrl+C${RESET}  — Send SIGINT (interrupt). Most programs stop gracefully."
    echo -e "  ${BOLD}Ctrl+Z${RESET}  — Send SIGTSTP (stop/pause). The process is suspended."
    echo -e "  ${BOLD}Ctrl+D${RESET}  — Send EOF (end of input). Closes the current shell or input."
    echo
    echo "  From another terminal or after Ctrl+Z:"
    echo -e "  ${BOLD}kill 1234${RESET}     — Send SIGTERM to PID 1234 (polite request to stop)"
    echo -e "  ${BOLD}kill -9 1234${RESET}  — Send SIGKILL to PID 1234 (force kill — no cleanup)"
    echo -e "  ${BOLD}killall myapp${RESET}  — Kill all processes named 'myapp'"
    echo
    warn "kill -9 is the nuclear option. Use it only when the process won't respond to regular kill."
    warn "It doesn't let the process clean up after itself."
    pause

    ok "Processes lesson complete!"
    pause
}


# =============================================================================
# LESSON: ENVIRONMENT
# =============================================================================

lesson_environment() {
    header "LESSON 7: Environment Variables — The Shell's Settings"

    info "Environment variables are named values the shell (and programs) use as configuration."
    info "Think of them as settings that are always available to any program you run."
    pause

    subheader "Reading variables"

    # The $ before a variable name means "give me the value of this variable"
    demo "echo \$HOME" "Your home directory"
    demo "echo \$USER" "Your username"
    demo "echo \$SHELL" "Which shell you're using"
    demo "echo \$PWD" "Current directory (same as pwd)"
    pause

    # PATH is special: it's a colon-separated list of directories.
    # When you type a command, the shell looks in each of these directories to find it.
    demo "echo \$PATH" "Where the shell looks for programs"
    pause

    info "Notice PATH looks like: /usr/local/bin:/usr/bin:/bin"
    info "Each directory is separated by a colon."
    info "When you type 'ls', the shell looks in each PATH directory until it finds 'ls'."
    info "That's why 'which ls' shows you WHERE ls lives."
    pause

    subheader "Setting variables"

    # = with no spaces sets a variable for just this shell session
    # There must be NO spaces around the = sign
    MY_NAME="Alice"
    FAVORITE_NUMBER=42

    # Just setting a variable doesn't export it to programs you run from this shell
    # You need "export" to make it visible to child processes
    export MY_NAME
    export FAVORITE_NUMBER
    # Or set and export in one step:
    export GREETING="Hello from the shell!"

    echo
    echo -e "${GREEN}We just set these variables:${RESET}"
    demo "echo \$MY_NAME" "Our custom variable"
    demo "echo \$FAVORITE_NUMBER" "Another custom variable"
    demo "echo \$GREETING" "Our greeting"
    pause

    # env lists all current environment variables
    demo "env | grep MY_NAME" "See our variable in the environment"
    demo "env | grep GREETING" "And our greeting"
    pause

    subheader "Config files"

    info "Variables you set in a terminal session disappear when you close it."
    info "To make them permanent, add them to your shell config file:"
    echo
    echo "  ~/.zshrc    — if you use zsh (default on modern Macs)"
    echo "  ~/.bashrc   — if you use bash (default on Linux)"
    echo "  ~/.profile  — runs for any login shell"
    echo
    info "Example lines you'd add to ~/.zshrc:"
    echo
    echo "  export PATH=\"\$HOME/go/bin:\$PATH\"  # add Go binaries to PATH"
    echo "  export GOPATH=\"\$HOME/go\"           # tell Go where to store things"
    echo "  export EDITOR=\"emacs\"              # default editor for git, etc."
    echo
    info "After editing the file, reload it with:"
    demo "echo 'source command (not running for real):'" "source ~/.zshrc"
    info "This applies the changes without restarting the terminal."
    pause

    ok "Environment lesson complete!"
    pause
}


# =============================================================================
# MAIN MENU
# =============================================================================

show_menu() {
    clear  # clear = erase the screen

    # cat with << 'BANNER' ... BANNER is a "heredoc" — a multi-line string.
    # The content between BANNER markers is printed as-is.
    echo -e "${BLUE}"
    cat << 'BANNER'
  ╔══════════════════════════════════════════════════════════╗
  ║                    SHELL TOUR v1.0                       ║
  ║          An interactive Unix shell adventure             ║
  ║                                                          ║
  ║  This script teaches you shell basics by doing things    ║
  ║  live, right in front of you. Pick a lesson below.       ║
  ╚══════════════════════════════════════════════════════════╝
BANNER
    echo -e "${RESET}"

    # Print the menu options
    echo -e "  ${GREEN}1${RESET}  Navigation        — moving around folders, ls, cd, mkdir"
    echo -e "  ${GREEN}2${RESET}  Files             — create, copy, move, rename, read"
    echo -e "  ${GREEN}3${RESET}  Searching         — grep, find, which"
    echo -e "  ${GREEN}4${RESET}  Pipes             — chaining commands, redirects"
    echo -e "  ${GREEN}5${RESET}  Permissions       — chmod, who can do what"
    echo -e "  ${GREEN}6${RESET}  Processes         — what's running, kill, background jobs"
    echo -e "  ${GREEN}7${RESET}  Environment       — variables, PATH, shell config"
    echo -e "  ${GREEN}A${RESET}  All lessons       — run everything in order"
    echo -e "  ${RED}q${RESET}  Quit"
    echo
    printf "Pick a lesson [1-7, A, q]: "
}

# =============================================================================
# MAIN PROGRAM
# =============================================================================
# This is where the script actually starts running.
# Everything above was just defining functions and variables.

# Check if we're running with bash (not sh or dash)
if [ -z "${BASH_VERSION:-}" ]; then
    echo "This script requires bash. Run: bash $0"
    exit 1
fi

# Main loop
# A "while true" loop runs forever until explicitly broken with "break"
while true; do
    show_menu

    # Read the user's choice.
    # -r means "raw" (don't interpret backslashes)
    read -r choice

    # Case statement — like switch in other languages
    # Each pattern ends with ) and each block ends with ;;
    case "$choice" in
        1)  lesson_navigation ;;
        2)  lesson_files ;;
        3)  lesson_searching ;;
        4)  lesson_pipes ;;
        5)  lesson_permissions ;;
        6)  lesson_processes ;;
        7)  lesson_environment ;;
        A|a)
            lesson_navigation
            lesson_files
            lesson_searching
            lesson_pipes
            lesson_permissions
            lesson_processes
            lesson_environment
            header "ALL DONE!"
            ok "You've completed the full shell tour."
            info "Check out the cheatsheet.html for a quick reference."
            info "And try the Go exercises in playground/golang/"
            echo
            break
            ;;
        q|Q)
            echo
            ok "Thanks for using Shell Tour. Go build something!"
            echo
            break
            ;;
        *)
            # * matches anything not matched above
            echo -e "${RED}Invalid choice: $choice${RESET}"
            echo "Please enter 1-7, A, or q"
            sleep 1
            ;;
    esac
done
