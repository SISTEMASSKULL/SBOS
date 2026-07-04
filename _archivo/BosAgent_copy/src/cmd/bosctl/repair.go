package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"time"

	"bos/internal/repair"
	"bos/internal/state"

	"log/slog"
)

func cmdRepair(args []string) int {
	fs := flag.NewFlagSet("repair", flag.ExitOnError)
	target := fs.String("target", "all", "repair target: all, os, k8s, bos")
	dryRun := fs.Bool("dry-run", false, "simulate without executing")
	timeoutSec := fs.Int("timeout", 600, "max seconds for repair sequence")
	fs.Parse(args)

	if fs.NArg() > 0 {
		fmt.Fprintf(os.Stderr, "bosctl: repair: unexpected arguments: %v\n", fs.Args())
		return 2
	}

	var t repair.Target
	switch *target {
	case "all", "os", "k8s", "bos":
		t = repair.Target(*target)
	default:
		fmt.Fprintf(os.Stderr, "bosctl: repair: invalid target %q (valid: all, os, k8s, bos)\n", *target)
		return 2
	}

	timeout := time.Duration(*timeoutSec) * time.Second

	stateMgr, err := state.NewManager("/etc/bos/.sbos_state.json")
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl: repair: cannot open state file: %v\n", err)
		return 1
	}
	defer stateMgr.Close()

	logger := slog.New(slog.NewTextHandler(os.Stderr, nil))
	mgr := repair.NewRepairManager(stateMgr, nil, timeout, *dryRun, logger)
	result := mgr.Run(t)

	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	enc.Encode(result)

	if !result.Success {
		return 1
	}
	return 0
}
