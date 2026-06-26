#!/usr/bin/env bash
# =============================================================================
# GOLANG EXERCISES — Rustlings-style interactive Go learning
# =============================================================================
#
# This script helps you work through the Go exercises one at a time.
# Each exercise is a Go file in the exercises/ directory.
# Your job: edit the file to make it compile and produce the right output.
#
# HOW TO RUN:
#   bash run.sh
#
# WHAT YOU NEED:
#   Go installed (run: go version to check)
# =============================================================================

set -euo pipefail

readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;34m'
readonly CYAN='\033[1;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly RESET='\033[0m'

# The directory where exercises live (relative to this script)
# "$(dirname "$0")" = the folder where this script is located
EXERCISES_DIR="$(dirname "$0")/exercises"

# Print a formatted header
header() {
    echo
    echo -e "${BLUE}$(printf '═%.0s' {1..60})${RESET}"
    echo -e "${BLUE}║${RESET}  ${BOLD}$1${RESET}"
    echo -e "${BLUE}$(printf '═%.0s' {1..60})${RESET}"
    echo
}

# Print the main menu
show_menu() {
    clear
    echo -e "${BLUE}"
    cat << 'BANNER'
  ╔══════════════════════════════════════════════════════════╗
  ║               GO EXERCISES — Learn by Doing              ║
  ║                                                          ║
  ║  Each exercise has instructions at the top of the file.  ║
  ║  Edit the file, then come back here and press R to run.  ║
  ╚══════════════════════════════════════════════════════════╝
BANNER
    echo -e "${RESET}"

    # List all exercise directories, sorted
    # find: look in EXERCISES_DIR for directories at depth 1 (direct children)
    # sort: alphabetically (so 00_ comes before 01_)
    local exercises
    exercises=$(find "$EXERCISES_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

    local i=0
    # The while loop reads lines from the find output
    while IFS= read -r dir; do
        local name
        name=$(basename "$dir")  # get just the folder name, not the full path

        # Check if the exercise has already been "passed"
        # We track this with a .done file in the exercise directory
        if [[ -f "$dir/.done" ]]; then
            echo -e "  ${GREEN}✓${RESET}  $name"
        else
            echo -e "  ${YELLOW}○${RESET}  $name"
        fi
        i=$((i + 1))
    done <<< "$exercises"

    echo
    echo -e "  ${CYAN}Enter the exercise name (or number) to work on it.${RESET}"
    echo -e "  ${CYAN}Type 'hint' after selecting to get a hint.${RESET}"
    echo -e "  ${RED}q${RESET}  Quit"
    echo
    printf "Exercise: "
}

# Run a specific exercise
run_exercise() {
    local exercise_path="$1"
    local exercise_name
    exercise_name=$(basename "$exercise_path")

    # Find the .go file in the exercise directory
    local go_file
    go_file=$(find "$exercise_path" -name "*.go" | head -1)

    if [[ -z "$go_file" ]]; then
        echo -e "${RED}No .go file found in $exercise_path${RESET}"
        return 1
    fi

    header "Exercise: $exercise_name"

    # Print the instructions from the file header
    echo -e "${CYAN}Instructions:${RESET}"
    # grep the comment block at the top of the file
    # -m 30 = at most 30 lines, stop at the first blank non-comment line
    grep '^//' "$go_file" | head -30 | sed 's|^// *||' || true
    echo

    while true; do
        echo -e "${BOLD}Options:${RESET}"
        echo -e "  ${GREEN}r${RESET} — Run the exercise"
        echo -e "  ${BLUE}e${RESET} — Open the file in your editor"
        echo -e "  ${YELLOW}h${RESET} — Show a hint"
        echo -e "  ${DIM}c${RESET} — Show the current code"
        echo -e "  ${RED}q${RESET} — Back to menu"
        echo
        printf "What do you want to do? [r/e/h/c/q]: "
        read -r action

        case "$action" in
            r|R)
                echo
                echo -e "${CYAN}Running:${RESET} go run $go_file"
                echo -e "${DIM}$(printf '─%.0s' {1..50})${RESET}"

                # Run the Go file and capture the exit code
                # "|| true" prevents set -e from killing our script if go run fails
                if go run "$go_file" 2>&1; then
                    echo -e "${DIM}$(printf '─%.0s' {1..50})${RESET}"
                    echo -e "${GREEN}✓ Program ran successfully!${RESET}"
                    echo

                    # Ask if they want to mark it done
                    printf "Mark this exercise as complete? [y/N]: "
                    read -r done_answer
                    if [[ "$done_answer" =~ ^[yY] ]]; then
                        touch "$exercise_path/.done"
                        echo -e "${GREEN}Marked as done! On to the next one.${RESET}"
                        sleep 1
                        return 0
                    fi
                else
                    echo -e "${DIM}$(printf '─%.0s' {1..50})${RESET}"
                    echo -e "${RED}✗ There was an error.${RESET}"
                    echo -e "${YELLOW}Read the error message above — it tells you exactly what's wrong.${RESET}"
                    echo -e "${YELLOW}Go errors are precise: line number, what it expected, what it got.${RESET}"
                fi
                echo
                ;;

            e|E)
                # Open the file in the user's preferred editor
                # $EDITOR is an environment variable. If not set, try common ones.
                local editor="${EDITOR:-}"
                if [[ -z "$editor" ]]; then
                    if command -v emacs &>/dev/null; then
                        editor="emacs"
                    elif command -v nano &>/dev/null; then
                        editor="nano"
                    elif command -v vim &>/dev/null; then
                        editor="vim"
                    else
                        echo -e "${RED}No editor found. Open the file manually:${RESET}"
                        echo "  $go_file"
                        echo "(Set \$EDITOR in your shell to choose your editor)"
                        continue
                    fi
                fi
                "$editor" "$go_file"
                ;;

            h|H)
                local hint_file="$exercise_path/hint.md"
                if [[ -f "$hint_file" ]]; then
                    echo
                    echo -e "${YELLOW}Hint:${RESET}"
                    cat "$hint_file"
                else
                    echo -e "${YELLOW}No hint file found. Try reading the error message carefully —"
                    echo -e "Go error messages usually tell you exactly what to fix.${RESET}"
                fi
                echo
                ;;

            c|C)
                echo
                echo -e "${CYAN}Current code in $go_file:${RESET}"
                echo -e "${DIM}$(printf '─%.0s' {1..50})${RESET}"
                # cat -n shows line numbers
                cat -n "$go_file"
                echo -e "${DIM}$(printf '─%.0s' {1..50})${RESET}"
                echo
                ;;

            q|Q)
                return 0
                ;;

            *)
                echo -e "${RED}Unknown option: $action${RESET}"
                ;;
        esac
    done
}

# Check that Go is installed
check_go() {
    if ! command -v go &>/dev/null; then
        echo -e "${RED}Error: Go is not installed or not in your PATH.${RESET}"
        echo
        echo "Install Go from: https://golang.org/dl/"
        echo "Then add it to your PATH in ~/.zshrc or ~/.bashrc:"
        echo "  export PATH=\$PATH:/usr/local/go/bin"
        exit 1
    fi

    local go_version
    go_version=$(go version)
    echo -e "${GREEN}✓ Found Go:${RESET} $go_version"
}

# Main program
main() {
    check_go

    if [[ ! -d "$EXERCISES_DIR" ]]; then
        echo -e "${RED}Exercises directory not found: $EXERCISES_DIR${RESET}"
        exit 1
    fi

    while true; do
        show_menu
        read -r choice

        case "$choice" in
            q|Q)
                echo
                echo -e "${GREEN}Good work! Keep practicing.${RESET}"
                echo
                exit 0
                ;;
            "")
                continue
                ;;
            *)
                # Try to find the exercise by name or number
                local found_dir=""

                # First try: exact directory name match
                if [[ -d "$EXERCISES_DIR/$choice" ]]; then
                    found_dir="$EXERCISES_DIR/$choice"
                else
                    # Second try: find a directory that starts with the typed number
                    # e.g., typing "1" finds "01_hello"
                    found_dir=$(find "$EXERCISES_DIR" -mindepth 1 -maxdepth 1 -type d \
                        -name "${choice}_*" -o -name "0${choice}_*" 2>/dev/null | sort | head -1)
                fi

                if [[ -n "$found_dir" && -d "$found_dir" ]]; then
                    run_exercise "$found_dir"
                else
                    echo -e "${RED}Exercise '$choice' not found.${RESET}"
                    echo "Type the full name (like '01_variables') or just the number."
                    sleep 2
                fi
                ;;
        esac
    done
}

main
