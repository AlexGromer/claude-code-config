// PoC for ADR-007: PPID-keyed criteria isolation
//
// Standalone executable demonstrating the new resolve scheme.
// NOT production code — production wiring goes into tools-mcp/{shared,criteria}.go.
//
// Usage:
//   ppid_isolator path                    # print resolved storage path
//   ppid_isolator freeze "<goal text>"    # write a marker file
//   ppid_isolator check                   # read marker file (stdout: data or "NOT FROZEN")
//
// Storage layout: $POC_WORK_DIR/claude-<PPID>-<STARTTIME>/frozen.json
// PPID  = parent process (the bash spawning this binary; in real use = Claude Code)
// STARTTIME = field 22 of /proc/<PPID>/stat (clock ticks since boot) — defeats PID reuse
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type Frozen struct {
	FrozenAt   string `json:"frozen_at"`
	PPID       int    `json:"ppid"`
	StartEpoch string `json:"start_epoch"`
	Goal       string `json:"goal"`
}

func workDir() string {
	if v := os.Getenv("POC_WORK_DIR"); v != "" {
		return v
	}
	return "/opt/agent_work_directory"
}

// readStartTime reads field 22 of /proc/<pid>/stat = process start time in clock ticks since boot.
// Returns "0" on any error (still produces a deterministic key).
func readStartTime(pid int) string {
	data, err := os.ReadFile(fmt.Sprintf("/proc/%d/stat", pid))
	if err != nil {
		return "0"
	}
	// /proc/<pid>/stat format: pid (comm) state ppid ... starttime(field 22) ...
	// comm may contain spaces — find the LAST ')' to safely split.
	s := string(data)
	rparen := strings.LastIndex(s, ")")
	if rparen < 0 || rparen+2 > len(s) {
		return "0"
	}
	rest := strings.Fields(s[rparen+2:])
	// after "state ppid pgrp session tty_nr tpgid flags minflt cminflt majflt cmajflt utime stime cutime cstime priority nice num_threads itrealvalue starttime"
	// starttime is at index 19 of rest (state=0)
	if len(rest) < 20 {
		return "0"
	}
	return rest[19]
}

func sessionDir() string {
	ppid := os.Getppid()
	st := readStartTime(ppid)
	return filepath.Join(workDir(), fmt.Sprintf("claude-%d-%s", ppid, st))
}

func freezePath() string {
	return filepath.Join(sessionDir(), "frozen.json")
}

func cmdPath() {
	fmt.Println(freezePath())
}

func cmdFreeze(goal string) {
	if err := os.MkdirAll(sessionDir(), 0o755); err != nil {
		fail("mkdir: %v", err)
	}
	f := Frozen{
		FrozenAt:   time.Now().UTC().Format(time.RFC3339),
		PPID:       os.Getppid(),
		StartEpoch: readStartTime(os.Getppid()),
		Goal:       goal,
	}
	data, _ := json.MarshalIndent(f, "", "  ")
	if err := os.WriteFile(freezePath(), data, 0o644); err != nil {
		fail("write: %v", err)
	}
	fmt.Printf("FROZEN ppid=%d goal=%q path=%s\n", f.PPID, f.Goal, freezePath())
}

func cmdCheck() {
	data, err := os.ReadFile(freezePath())
	if err != nil {
		fmt.Printf("NOT FROZEN (looked at %s)\n", freezePath())
		return
	}
	var f Frozen
	_ = json.Unmarshal(data, &f)
	fmt.Printf("FROZEN ppid=%d goal=%q\n", f.PPID, f.Goal)
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "ERROR: "+format+"\n", args...)
	os.Exit(1)
}

func main() {
	if len(os.Args) < 2 {
		fail("usage: ppid_isolator path|freeze <goal>|check")
	}
	switch os.Args[1] {
	case "path":
		cmdPath()
	case "freeze":
		if len(os.Args) < 3 {
			fail("freeze requires <goal>")
		}
		cmdFreeze(strings.Join(os.Args[2:], " "))
	case "check":
		cmdCheck()
	case "ppid":
		fmt.Printf("ppid=%d starttime=%s\n", os.Getppid(), readStartTime(os.Getppid()))
	default:
		fail("unknown command: %s", os.Args[1])
	}
	_ = strconv.Itoa // keep import quiet if reduced
}
