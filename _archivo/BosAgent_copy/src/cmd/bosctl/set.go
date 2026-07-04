package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

// envPath is the canonical .env file for BOS AI configuration.
const envPath = "/etc/bos/.env"

// modelToEnv maps user-friendly model names to their environment variables.
var modelToEnv = map[string]string{
	"claude":   "ANTHROPIC_API_KEY",
	"anthropic": "ANTHROPIC_API_KEY",
	"deepseek": "DEEPSEEK_API_KEY",
	"openai":   "OPENAI_API_KEY",
	"ollama":   "OLLAMA_HOST",
	"local":    "OLLAMA_HOST",
}

func cmdSet(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Usage: bosctl set apikey <model>=<key>")
		fmt.Fprintln(os.Stderr, "  bosctl set apikey claude=sk-ant-...")
		fmt.Fprintln(os.Stderr, "  bosctl set apikey deepseek=sk-...")
		fmt.Fprintln(os.Stderr, "  bosctl set apikey ollama=http://localhost:11434")
		return 2
	}

	switch args[0] {
	case "apikey":
		return cmdSetApikey(args[1:])
	default:
		fmt.Fprintf(os.Stderr, "bosctl set: unknown target: %s\n", args[0])
		return 2
	}
}

func cmdSetApikey(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Usage: bosctl set apikey <model>=<key>")
		fmt.Fprintln(os.Stderr, "  modelos: claude, deepseek, openai, ollama")
		return 2
	}

	for _, arg := range args {
		parts := strings.SplitN(arg, "=", 2)
		if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
			fmt.Fprintf(os.Stderr, "bosctl set apikey: formato invalido: %s (usar: modelo=key)\n", arg)
			return 2
		}
		model := strings.ToLower(strings.TrimSpace(parts[0]))
		key := strings.TrimSpace(parts[1])

		envVar, ok := modelToEnv[model]
		if !ok {
			fmt.Fprintf(os.Stderr, "bosctl set apikey: modelo desconocido: %s\n", model)
			fmt.Fprintf(os.Stderr, "  modelos validos: claude, deepseek, openai, ollama\n")
			return 2
		}

		if err := updateEnvFile(envVar, key); err != nil {
			fmt.Fprintf(os.Stderr, "bosctl set apikey: %v\n", err)
			return 1
		}

		fmt.Printf("apikey %s configurada (%s)\n", model, envVar)
	}
	return 0
}

// updateEnvFile sets or replaces KEY=VALUE in the .env file.
// Creates the file with mode 0600 if it doesn't exist.
func updateEnvFile(envVar, value string) error {
	// Ensure directory exists
	if err := os.MkdirAll(strings.TrimSuffix(envPath, "/.env"), 0755); err != nil {
		// TrimSuffix may not work perfectly for /etc/bos/.env; use filepath.Dir equivalent.
		_ = os.MkdirAll("/etc/bos", 0755)
	}

	lines := make(map[string]string)

	// Read existing file
	f, err := os.Open(envPath)
	if err == nil {
		scanner := bufio.NewScanner(f)
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line == "" || strings.HasPrefix(line, "#") {
				continue // skip comments and blanks; they'll be re-added at the end
			}
			kv := strings.SplitN(line, "=", 2)
			if len(kv) == 2 {
				lines[strings.TrimSpace(kv[0])] = strings.TrimSpace(kv[1])
			}
		}
		f.Close()
	} else if !os.IsNotExist(err) {
		return err
	}

	// Set or replace the target key
	lines[envVar] = value

	// Write back
	tmp := envPath + ".tmp"
	out, err := os.Create(tmp)
	if err != nil {
		return err
	}

	fmt.Fprintln(out, "# BOS AI — API keys configuradas via bosctl set apikey")
	for k, v := range lines {
		fmt.Fprintf(out, "%s=%s\n", k, v)
	}

	out.Close()
	if err := os.Rename(tmp, envPath); err != nil {
		os.Remove(tmp)
		return err
	}
	os.Chmod(envPath, 0600)
	return nil
}
