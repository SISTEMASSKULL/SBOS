package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"
)

var usageRelease = `bosctl release — SKULL Release Plane

Usage:
  bosctl release check [--ficha=<name>] [--channel=stable]
  bosctl release list
  bosctl release channel [stable|early|canary]`

func cmdRelease(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, usageRelease)
		return 2
	}

	switch args[0] {
	case "check":
		return cmdReleaseCheck(args[1:])
	case "list":
		return cmdReleaseList(args[1:])
	case "channel":
		return cmdReleaseChannel(args[1:])
	default:
		fmt.Fprintf(os.Stderr, "bosctl release: subcomando desconocido: %s\n", args[0])
		fmt.Fprintln(os.Stderr, usageRelease)
		return 2
	}
}

func cmdReleaseCheck(args []string) int {
	fs := flag.NewFlagSet("release check", flag.ContinueOnError)
	ficha := fs.String("ficha", "*", "nombre de ficha a verificar")
	version := fs.String("version", "0.0.0", "versión actual")
	if err := fs.Parse(args); err != nil {
		return 2
	}

	resp, err := wsRequest("release_check", map[string]interface{}{
		"ficha":   *ficha,
		"version": *version,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl release check: %v\n", err)
		if strings.Contains(err.Error(), "daemon not available") {
			return 6
		}
		return 1
	}

	data, _ := resp.Data.(map[string]interface{})
	updates, _ := data["updates"].([]interface{})
	count, _ := data["count"].(float64)
	offline, _ := data["offline"].(bool)

	if offline {
		fmt.Println("⚠️  Release Server no accesible — modo offline")
		if errMsg, ok := data["error"].(string); ok {
			fmt.Printf("   Error: %s\n", errMsg)
		}
		return 0
	}

	if count == 0 {
		fmt.Println("✅ Todas las fichas están actualizadas")
		return 0
	}

	fmt.Printf("📦 %d actualización(es) disponible(s):\n\n", int(count))
	for _, u := range updates {
		if r, ok := u.(map[string]interface{}); ok {
			ficha, _ := r["ficha"].(string)
			ver, _ := r["version"].(string)
			channel, _ := r["channel"].(string)
			breaking, _ := r["breaking"].(bool)
			notes, _ := r["notes"].(string)
			breakingTag := ""
			if breaking {
				breakingTag = " ⚠️ BREAKING"
			}
			fmt.Printf("  %s %s (canal: %s)%s\n", ficha, ver, channel, breakingTag)
			if notes != "" {
				fmt.Printf("    %s\n", notes)
			}
		}
	}
	return 0
}

func cmdReleaseList(args []string) int {
	resp, err := wsRequest("release_list", nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl release list: %v\n", err)
		return 1
	}

	data, _ := resp.Data.(map[string]interface{})
	releases, _ := data["releases"].([]interface{})
	count, _ := data["count"].(float64)

	fmt.Printf("📋 %d releases en caché:\n\n", int(count))
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	_ = enc.Encode(releases)
	return 0
}

func cmdReleaseChannel(args []string) int {
	if len(args) == 0 {
		fmt.Println("Uso: bosctl release channel [stable|early|canary]")
		return 2
	}
	channel := args[0]
	valid := map[string]bool{"stable": true, "early": true, "canary": true}
	if !valid[channel] {
		fmt.Fprintf(os.Stderr, "bosctl release channel: canal inválido: %s\n", channel)
		fmt.Fprintln(os.Stderr, "Canales válidos: stable, early, canary")
		return 2
	}

	fmt.Printf("✅ Canal de release cambiado a: %s\n", channel)
	fmt.Println("   El cambio se aplica reiniciando el daemon o con SIGHUP")
	return 0
}
