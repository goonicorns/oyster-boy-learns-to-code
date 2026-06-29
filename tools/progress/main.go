// Progress tracker for the Oyster Boy learning curriculum.
// Zero external dependencies — pure Go standard library only.
// Claude runs this with the Bash tool. Students do not touch it.
//
// One progress.json per machine (gitignored). One learner per machine.
// git pull never overwrites their progress.
//
// Usage:
//   go run tools/progress/main.go show
//   go run tools/progress/main.go setname <name>
//   go run tools/progress/main.go complete <item>
//   go run tools/progress/main.go set <step> <lesson>
//   go run tools/progress/main.go note <text...>
//   go run tools/progress/main.go reset

package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"time"
)

// ─── Data model ──────────────────────────────────────────────────────────────

type Progress struct {
	Name          string   `json:"name"`           // neil | sim | gaffor | nate
	CurrentStep   string   `json:"current_step"`   // e.g. "emacs_config", "go_exercises"
	CurrentLesson string   `json:"current_lesson"` // e.g. "emacs_04_use_package"
	Completed     []string `json:"completed"`      // items fully finished
	LastSession   string   `json:"last_session"`   // RFC3339
	Notes         []string `json:"notes"`          // timestamped session notes from Claude
}

// ─── File I/O ─────────────────────────────────────────────────────────────────

func filePath() string {
	return filepath.Join(".", "progress.json")
}

func load() (*Progress, error) {
	data, err := os.ReadFile(filePath())
	if os.IsNotExist(err) {
		return &Progress{
			CurrentStep: "not_started",
			Completed:   []string{},
			Notes:       []string{},
		}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("reading progress.json: %w", err)
	}
	var p Progress
	if err := json.Unmarshal(data, &p); err != nil {
		return nil, fmt.Errorf("parsing progress.json: %w", err)
	}
	return &p, nil
}

func save(p *Progress) error {
	data, err := json.MarshalIndent(p, "", "  ")
	if err != nil {
		return fmt.Errorf("encoding progress: %w", err)
	}
	if err := os.WriteFile(filePath(), data, 0644); err != nil {
		return fmt.Errorf("writing progress.json: %w", err)
	}
	return nil
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

func now() string      { return time.Now().UTC().Format(time.RFC3339) }
func nowShort() string { return time.Now().UTC().Format("2006-01-02 15:04") }

func stepLabel(step string) string {
	labels := map[string]string{
		"not_started":  "not started yet",
		"cheatsheet":   "Step 0 — cheatsheet",
		"shell_tour":   "Step 1 — shell tour",
		"emacs_tour":   "Step 1.5a — Emacs interactive tour",
		"emacs_config": "Step 1.5b — Emacs config lessons",
		"go_exercises": "Step 2 — Go exercises",
		"project1":     "Step 3 — Project 1: Crypto API",
		"project2":     "Step 4 — Project 2: Technical Analysis",
		"project3":     "Step 5 — Project 3: Chat Server",
		"project4":  "Step 6 — Project 4: Ethereum & Smart Contracts",
		"project5":  "Step 7 — Project 5: CLI Portfolio Tracker",
		"project6":  "Step 8 — Project 6: gRPC Price Feed",
		"project7":  "Step 9 — Project 7: Baby Blockchain in Go",
		"project8":  "Step 10 — Project 8: Key-Value Store",
		"project9":  "Step 11 — Project 9: Baby Git in Go",
		"project10": "Step 12 — Project 10: Blog Platform (Docker + Postgres + Redis)",
		"complete":  "ALL DONE 🎓",
	}
	if l, ok := labels[step]; ok {
		return l
	}
	return step
}

func whatNext(p *Progress) string {
	switch p.CurrentStep {
	case "not_started", "":
		return "Start from scratch — open cheatsheet.html, then bash playground/shell/shell-tour.sh"
	case "cheatsheet":
		return "Run the shell tour: bash playground/shell/shell-tour.sh"
	case "shell_tour":
		return "Start Emacs tour: bash playground/emacs/emacs-tour.sh"
	case "emacs_tour":
		if p.CurrentLesson == "" {
			return "Begin Emacs config — guide through prompts/emacs/01_init_file.md"
		}
		return "Continue Emacs tour at: " + p.CurrentLesson
	case "emacs_config":
		if p.CurrentLesson == "" {
			return "Start Emacs config — prompts/emacs/01_init_file.md"
		}
		return "Continue Emacs config at: " + p.CurrentLesson
	case "go_exercises":
		if p.CurrentLesson == "" {
			return "Start Go exercises: bash playground/golang/run.sh — begin at 00_hello"
		}
		return "Continue Go exercises at: " + p.CurrentLesson
	case "project1":
		if p.CurrentLesson == "" {
			return "Start Project 1 — read prompts/lessons/01_project_setup.md"
		}
		return "Continue Project 1 at: " + p.CurrentLesson
	case "project2":
		if p.CurrentLesson == "" {
			return "Start Project 2 — read prompts/lessons/13_ta_what_is_it.md"
		}
		return "Continue Project 2 at: " + p.CurrentLesson
	case "project3":
		if p.CurrentLesson == "" {
			return "Start Project 3 — read prompts/lessons/18_websockets_mental_model.md"
		}
		return "Continue Project 3 at: " + p.CurrentLesson
	case "project4":
		if p.CurrentLesson == "" {
			return "Start Project 4 — read prompts/lessons/27_blockchain_mental_model.md"
		}
		return "Continue Project 4 at: " + p.CurrentLesson
	case "project5":
		if p.CurrentLesson == "" {
			return "Start Project 5 — read prompts/lessons/36_cli_design_and_cobra.md"
		}
		return "Continue Project 5 at: " + p.CurrentLesson
	case "project6":
		if p.CurrentLesson == "" {
			return "Start Project 6 — read prompts/lessons/40_grpc_what_and_why.md"
		}
		return "Continue Project 6 at: " + p.CurrentLesson
	case "project7":
		if p.CurrentLesson == "" {
			return "Start Project 7 — read prompts/lessons/44_baby_blockchain_model.md"
		}
		return "Continue Project 7 at: " + p.CurrentLesson
	case "project8":
		if p.CurrentLesson == "" {
			return "Start Project 8 — read prompts/lessons/48_kv_what_are_we_building.md"
		}
		return "Continue Project 8 at: " + p.CurrentLesson
	case "project9":
		if p.CurrentLesson == "" {
			return "Start Project 9 — read prompts/lessons/51_git_what_it_really_is.md"
		}
		return "Continue Project 9 at: " + p.CurrentLesson
	case "project10":
		if p.CurrentLesson == "" {
			return "Start Project 10 — read prompts/lessons/54_blog_overview_and_docker.md"
		}
		return "Continue Project 10 at: " + p.CurrentLesson
	case "complete":
		return "Curriculum complete. All 10 projects done. Go build something real."
	}
	return p.CurrentStep + " / " + p.CurrentLesson
}

// ─── Commands ─────────────────────────────────────────────────────────────────

func cmdShow(p *Progress) {
	fmt.Println("╔══════════════════════════════════════════════╗")
	fmt.Println("║  PROGRESS REPORT                             ║")
	fmt.Println("╚══════════════════════════════════════════════╝")
	fmt.Println()

	if p.Name == "" {
		fmt.Println("  Learner:         *** NOT SET — ask who they are, then run: setname <name> ***")
	} else {
		fmt.Printf("  Learner:         %s\n", p.Name)
	}

	if p.LastSession == "" {
		fmt.Println("  Last session:    never — first session")
	} else {
		fmt.Printf("  Last session:    %s\n", p.LastSession)
	}

	fmt.Printf("  Current step:    %s\n", stepLabel(p.CurrentStep))
	if p.CurrentLesson != "" {
		fmt.Printf("  Current lesson:  %s\n", p.CurrentLesson)
	}

	fmt.Println()
	if len(p.Completed) == 0 {
		fmt.Println("  Completed:       nothing yet")
	} else {
		fmt.Printf("  Completed (%d):\n", len(p.Completed))
		for _, item := range p.Completed {
			fmt.Printf("    ✓ %s\n", item)
		}
	}

	fmt.Println()
	if len(p.Notes) == 0 {
		fmt.Println("  Notes:           none")
	} else {
		fmt.Println("  Notes:")
		for _, note := range p.Notes {
			fmt.Printf("    • %s\n", note)
		}
	}

	fmt.Println()
	fmt.Println("  ── WHAT TO DO NEXT ──────────────────────────")
	fmt.Printf("  %s\n", whatNext(p))
	fmt.Println()
}

func cmdSetName(p *Progress, name string) {
	p.Name = strings.ToLower(strings.TrimSpace(name))
	p.LastSession = now()
	fmt.Printf("✓ Learner set to: %s\n", p.Name)
}

func cmdComplete(p *Progress, item string) {
	if !slices.Contains(p.Completed, item) {
		p.Completed = append(p.Completed, item)
	}
	p.LastSession = now()
	fmt.Printf("✓ Marked complete: %s\n", item)
}

func cmdSet(p *Progress, step, lesson string) {
	p.CurrentStep = step
	p.CurrentLesson = lesson
	p.LastSession = now()
	fmt.Printf("→ Position set: %s / %s\n", step, lesson)
}

func cmdNote(p *Progress, parts []string) {
	text := strings.Join(parts, " ")
	p.Notes = append(p.Notes, fmt.Sprintf("[%s] %s", nowShort(), text))
	p.LastSession = now()
	fmt.Println("✎ Note saved.")
}

func cmdReset(p *Progress) {
	name := p.Name // preserve the name on reset
	*p = Progress{
		Name:        name,
		CurrentStep: "not_started",
		Completed:   []string{},
		Notes:       []string{},
	}
	fmt.Println("⚠  Progress reset (name kept).")
}

// ─── Main ─────────────────────────────────────────────────────────────────────

func usage() {
	fmt.Print(`
Progress tracker — Claude uses this. Students do not touch it.

Commands:
  show                    Print full progress report
  setname <name>          Set who the learner is (neil/sim/gaffor/nate)
  complete <item>         Mark an item complete
  set <step> <lesson>     Update current position
  note <text...>          Add a session note
  reset                   Wipe progress (keeps name)

Steps:
  not_started | cheatsheet | shell_tour | emacs_tour | emacs_config
  go_exercises | project1 | project2 | project3 | project4 | complete

Examples:
  go run tools/progress/main.go show
  go run tools/progress/main.go setname neil
  go run tools/progress/main.go set emacs_config emacs_04_use_package
  go run tools/progress/main.go complete emacs_03_ui_cleanup
  go run tools/progress/main.go note "helm clicked, let* still shaky"
`)
}

func main() {
	args := os.Args[1:]
	if len(args) == 0 {
		usage()
		os.Exit(1)
	}

	p, err := load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	switch args[0] {
	case "show":
		cmdShow(p)
		p.LastSession = now()

	case "setname":
		if len(args) < 2 {
			fmt.Fprintln(os.Stderr, "Usage: setname <name>")
			os.Exit(1)
		}
		cmdSetName(p, args[1])

	case "complete":
		if len(args) < 2 {
			fmt.Fprintln(os.Stderr, "Usage: complete <item>")
			os.Exit(1)
		}
		cmdComplete(p, args[1])

	case "set":
		if len(args) < 3 {
			fmt.Fprintln(os.Stderr, "Usage: set <step> <lesson>")
			os.Exit(1)
		}
		cmdSet(p, args[1], args[2])

	case "note":
		if len(args) < 2 {
			fmt.Fprintln(os.Stderr, "Usage: note <text...>")
			os.Exit(1)
		}
		cmdNote(p, args[1:])

	case "reset":
		cmdReset(p)

	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n", args[0])
		usage()
		os.Exit(1)
	}

	if err := save(p); err != nil {
		fmt.Fprintf(os.Stderr, "Error saving: %v\n", err)
		os.Exit(1)
	}
}
