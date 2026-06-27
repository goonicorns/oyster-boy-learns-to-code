// Progress tracker for the Oyster Boy learning curriculum.
// Zero external dependencies — pure Go standard library only.
// Claude runs this with the Bash tool. Students do not touch it.
//
// Usage:
//   go run tools/progress/main.go show <name>
//   go run tools/progress/main.go complete <name> <item>
//   go run tools/progress/main.go set <name> <step> <lesson>
//   go run tools/progress/main.go note <name> <text...>
//   go run tools/progress/main.go list
//   go run tools/progress/main.go reset <name>

package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// ─── Data model ──────────────────────────────────────────────────────────────

type StudentProgress struct {
	Name           string   `json:"name"`
	CurrentStep    string   `json:"current_step"`    // e.g. "emacs_config", "go_exercises", "project1"
	CurrentLesson  string   `json:"current_lesson"`  // e.g. "emacs_04_use_package", "lesson_07", "exercise_05"
	Completed      []string `json:"completed"`       // list of completed items
	LastSession    string   `json:"last_session"`    // RFC3339 timestamp
	Notes          []string `json:"notes"`           // timestamped notes Claude adds
}

type ProgressFile struct {
	Students map[string]*StudentProgress `json:"students"`
}

// ─── File path ────────────────────────────────────────────────────────────────

// progressFilePath returns the path to progress.json.
// Always placed in the repo root (two directories above tools/progress/).
func progressFilePath() string {
	// When run via `go run tools/progress/main.go` from repo root,
	// the working directory IS the repo root.
	return filepath.Join(".", "progress.json")
}

// ─── Load / save ──────────────────────────────────────────────────────────────

func load() (*ProgressFile, error) {
	path := progressFilePath()
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		// First run — return empty file
		return &ProgressFile{Students: make(map[string]*StudentProgress)}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("reading progress file: %w", err)
	}
	var pf ProgressFile
	if err := json.Unmarshal(data, &pf); err != nil {
		return nil, fmt.Errorf("parsing progress file: %w", err)
	}
	if pf.Students == nil {
		pf.Students = make(map[string]*StudentProgress)
	}
	return &pf, nil
}

func save(pf *ProgressFile) error {
	data, err := json.MarshalIndent(pf, "", "  ")
	if err != nil {
		return fmt.Errorf("encoding progress: %w", err)
	}
	if err := os.WriteFile(progressFilePath(), data, 0644); err != nil {
		return fmt.Errorf("writing progress file: %w", err)
	}
	return nil
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

func normalise(name string) string {
	return strings.ToLower(strings.TrimSpace(name))
}

func getOrCreate(pf *ProgressFile, name string) *StudentProgress {
	key := normalise(name)
	if pf.Students[key] == nil {
		pf.Students[key] = &StudentProgress{
			Name:          key,
			CurrentStep:   "not_started",
			CurrentLesson: "",
			Completed:     []string{},
			Notes:         []string{},
		}
	}
	return pf.Students[key]
}

func contains(list []string, item string) bool {
	for _, v := range list {
		if v == item {
			return true
		}
	}
	return false
}


func now() string {
	return time.Now().UTC().Format(time.RFC3339)
}

func nowShort() string {
	return time.Now().UTC().Format("2006-01-02 15:04")
}

// ─── Commands ─────────────────────────────────────────────────────────────────

// show prints a full progress summary for one student.
// Claude reads this output to orient itself at the start of a session.
func cmdShow(pf *ProgressFile, name string) {
	s := getOrCreate(pf, name)

	fmt.Println("╔══════════════════════════════════════════════╗")
	fmt.Printf("║  PROGRESS REPORT: %-26s║\n", strings.ToUpper(s.Name))
	fmt.Println("╚══════════════════════════════════════════════╝")
	fmt.Println()

	if s.LastSession == "" {
		fmt.Println("  Last session:    never — this is their first session")
	} else {
		fmt.Printf("  Last session:    %s\n", s.LastSession)
	}

	fmt.Printf("  Current step:    %s\n", stepLabel(s.CurrentStep))
	if s.CurrentLesson != "" {
		fmt.Printf("  Current lesson:  %s\n", s.CurrentLesson)
	}

	fmt.Println()
	if len(s.Completed) == 0 {
		fmt.Println("  Completed:       nothing yet")
	} else {
		fmt.Printf("  Completed (%d):\n", len(s.Completed))
		for _, item := range s.Completed {
			fmt.Printf("    ✓ %s\n", item)
		}
	}

	fmt.Println()
	if len(s.Notes) == 0 {
		fmt.Println("  Notes:           none")
	} else {
		fmt.Println("  Notes:")
		for _, note := range s.Notes {
			fmt.Printf("    • %s\n", note)
		}
	}

	fmt.Println()
	fmt.Println("  ── WHAT TO DO NEXT ──────────────────────────")
	fmt.Printf("  %s\n", nextStep(s))
	fmt.Println()
}

// list prints a one-line summary for every student.
func cmdList(pf *ProgressFile) {
	if len(pf.Students) == 0 {
		fmt.Println("No students tracked yet.")
		return
	}
	fmt.Println("╔══════════════════════════════════════════════╗")
	fmt.Println("║  ALL STUDENTS                                ║")
	fmt.Println("╚══════════════════════════════════════════════╝")
	fmt.Println()
	for _, name := range []string{"neil", "sim", "gaffor", "nate"} {
		s := pf.Students[name]
		if s == nil {
			fmt.Printf("  %-8s  not started\n", name)
			continue
		}
		lesson := s.CurrentLesson
		if lesson == "" {
			lesson = s.CurrentStep
		}
		fmt.Printf("  %-8s  %s  (last: %s)\n", s.Name, lesson, s.LastSession)
	}
	fmt.Println()
}

// complete marks an item done and updates last_session.
func cmdComplete(pf *ProgressFile, name, item string) {
	s := getOrCreate(pf, name)
	if !contains(s.Completed, item) {
		s.Completed = append(s.Completed, item)
	}
	s.LastSession = now()
	fmt.Printf("✓ Marked complete for %s: %s\n", s.Name, item)
}

// set updates the student's current position.
func cmdSet(pf *ProgressFile, name, step, lesson string) {
	s := getOrCreate(pf, name)
	s.CurrentStep = step
	s.CurrentLesson = lesson
	s.LastSession = now()
	fmt.Printf("→ Set %s: step=%s lesson=%s\n", s.Name, step, lesson)
}

// note adds a timestamped note.
func cmdNote(pf *ProgressFile, name string, parts []string) {
	s := getOrCreate(pf, name)
	text := strings.Join(parts, " ")
	entry := fmt.Sprintf("[%s] %s", nowShort(), text)
	s.Notes = append(s.Notes, entry)
	s.LastSession = now()
	fmt.Printf("✎ Note added for %s\n", s.Name)
}

// reset wipes a student's progress (asks for confirmation via args).
func cmdReset(pf *ProgressFile, name string) {
	key := normalise(name)
	delete(pf.Students, key)
	fmt.Printf("⚠  Progress reset for %s\n", key)
}

// ─── Label helpers ────────────────────────────────────────────────────────────

func stepLabel(step string) string {
	labels := map[string]string{
		"not_started":   "not started yet",
		"cheatsheet":    "Step 0 — cheatsheet",
		"shell_tour":    "Step 1 — shell tour",
		"emacs_tour":    "Step 1.5a — Emacs tour",
		"emacs_config":  "Step 1.5b — Emacs config lessons",
		"go_exercises":  "Step 2 — Go exercises",
		"project1":      "Step 3 — Project 1: Crypto API",
		"project2":      "Step 4 — Project 2: Technical Analysis",
		"project3":      "Step 5 — Project 3: Chat Server",
		"complete":      "ALL DONE 🎉",
	}
	if label, ok := labels[step]; ok {
		return label
	}
	return step
}

func nextStep(s *StudentProgress) string {
	switch s.CurrentStep {
	case "not_started", "":
		return "Start from the beginning: open the cheatsheet, then bash playground/shell/shell-tour.sh"
	case "cheatsheet":
		return "Run the shell tour: bash playground/shell/shell-tour.sh"
	case "shell_tour":
		return "Start the Emacs tour: bash playground/emacs/emacs-tour.sh"
	case "emacs_tour":
		if s.CurrentLesson == "" {
			return "Begin Emacs config — read prompts/emacs/01_init_file.md and start guiding"
		}
		return fmt.Sprintf("Continue Emacs config from: %s", s.CurrentLesson)
	case "emacs_config":
		if s.CurrentLesson == "" {
			return "Start Go exercises: bash playground/golang/run.sh"
		}
		return fmt.Sprintf("Continue Emacs config from: %s", s.CurrentLesson)
	case "go_exercises":
		if s.CurrentLesson == "" {
			return "Start Go exercises from exercise 00_hello"
		}
		return fmt.Sprintf("Continue Go exercises from: %s", s.CurrentLesson)
	case "project1":
		if s.CurrentLesson == "" {
			return "Start Project 1 — read prompts/lessons/01_project_setup.md"
		}
		return fmt.Sprintf("Continue Project 1 from: %s", s.CurrentLesson)
	case "project2":
		if s.CurrentLesson == "" {
			return "Start Project 2 — read prompts/lessons/13_ta_what_is_it.md"
		}
		return fmt.Sprintf("Continue Project 2 from: %s", s.CurrentLesson)
	case "project3":
		if s.CurrentLesson == "" {
			return "Start Project 3 — read prompts/lessons/18_websockets_mental_model.md"
		}
		return fmt.Sprintf("Continue Project 3 from: %s", s.CurrentLesson)
	case "complete":
		return "They've finished the curriculum. Time to build their own things."
	default:
		return fmt.Sprintf("Current position: %s / %s", s.CurrentStep, s.CurrentLesson)
	}
}

// ─── Main ─────────────────────────────────────────────────────────────────────

func usage() {
	fmt.Print(`
Progress tracker — DO NOT EDIT progress.json BY HAND.
Claude uses this tool to track where each student is.

Commands:
  show <name>                    Print full progress report for a student
  list                           Print one-line summary for all students
  complete <name> <item>         Mark an item complete
  set <name> <step> <lesson>     Update current position
  note <name> <text...>          Add a note about this session
  reset <name>                   Wipe progress for a student

Steps:    not_started | cheatsheet | shell_tour | emacs_tour | emacs_config
          go_exercises | project1 | project2 | project3 | complete

Examples:
  go run tools/progress/main.go show neil
  go run tools/progress/main.go set neil emacs_config emacs_04_use_package
  go run tools/progress/main.go complete neil emacs_03_ui_cleanup
  go run tools/progress/main.go note neil struggled with setq-default, clicked by end
  go run tools/progress/main.go list
`)
}

func main() {
	args := os.Args[1:]
	if len(args) == 0 {
		usage()
		os.Exit(1)
	}

	pf, err := load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading progress: %v\n", err)
		os.Exit(1)
	}

	cmd := args[0]
	switch cmd {
	case "show":
		if len(args) < 2 {
			fmt.Fprintln(os.Stderr, "Usage: show <name>")
			os.Exit(1)
		}
		cmdShow(pf, args[1])
		// Update last session on show (means a session is starting)
		s := getOrCreate(pf, args[1])
		s.LastSession = now()

	case "list":
		cmdList(pf)

	case "complete":
		if len(args) < 3 {
			fmt.Fprintln(os.Stderr, "Usage: complete <name> <item>")
			os.Exit(1)
		}
		cmdComplete(pf, args[1], args[2])

	case "set":
		if len(args) < 4 {
			fmt.Fprintln(os.Stderr, "Usage: set <name> <step> <lesson>")
			os.Exit(1)
		}
		cmdSet(pf, args[1], args[2], args[3])

	case "note":
		if len(args) < 3 {
			fmt.Fprintln(os.Stderr, "Usage: note <name> <text...>")
			os.Exit(1)
		}
		cmdNote(pf, args[1], args[2:])

	case "reset":
		if len(args) < 2 {
			fmt.Fprintln(os.Stderr, "Usage: reset <name>")
			os.Exit(1)
		}
		cmdReset(pf, args[1])

	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n", cmd)
		usage()
		os.Exit(1)
	}

	if err := save(pf); err != nil {
		fmt.Fprintf(os.Stderr, "Error saving progress: %v\n", err)
		os.Exit(1)
	}
}
