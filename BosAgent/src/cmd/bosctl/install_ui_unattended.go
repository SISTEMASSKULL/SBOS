// Package main — install_ui_unattended.go: modo desatendido del comando "bosctl setup".
// Migrado de install_ui_impl.go en BOS-REPAIR F3.MIGRATE.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	tuimodel "bos/internal/tui/model"
	"bos/internal/wslib"
)

// runUnattended ejecuta la instalación automática desde un seed file JSON/YAML sin TUI.
func runUnattended(seedFile string) int {
	data, err := os.ReadFile(seedFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl setup: no se pudo leer seed file: %v\n", err)
		return 1
	}
	var seed tuimodel.SeedData
	if err := json.Unmarshal(data, &seed); err != nil {
		if p := parseSimpleSeed(string(data)); p.RazonSocial != "" {
			seed = p
		}
	}
	// Pre-rellenar desde el .env si faltan campos
	if seed.Pais == "" {
		seed.Pais = "BO"
	}

	fmt.Println("\033[1mSBOS — Instalación Automática\033[0m")
	fmt.Printf("Empresa: %s  ·  Admin: %s  ·  Dominio: %s\n\n",
		seed.RazonSocial, seed.Email, seed.Dominio)

	socketPath := os.Getenv("BOS_SOCKET")
	if socketPath == "" {
		socketPath = defaultSocket
	}
	conn, err := wslib.DialUnix(socketPath, 5*time.Second)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl setup: daemon no disponible: %v\n", err)
		return 6
	}
	defer conn.Close()

	_ = conn.WriteJSON(map[string]interface{}{
		"type": "request", "id": fmt.Sprintf("ua-%d", time.Now().UnixNano()),
		"action": "bootstrap_start",
		"params": map[string]interface{}{
			"razon_social": seed.RazonSocial, "nit": seed.NIT,
			"pais": seed.Pais, "dominio": seed.Dominio,
			"email": seed.Email, "nombre": seed.Nombre,
			"password": seed.Password, "mfa": seed.MFA,
		},
	})

	phases := tuimodel.DefaultPhases()
	fichasOK, fichasTotal := 0, 22
	curPhase := -1

	for {
		_, raw, err := conn.ReadMessage()
		if err != nil {
			break
		}
		var ev map[string]interface{}
		if json.Unmarshal(raw, &ev) != nil {
			continue
		}
		evType, _ := ev["type"].(string)
		ficha, _ := ev["ficha"].(string)
		step, _ := ev["step"].(string)
		msg, _ := ev["message"].(string)

		switch evType {
		case "response":
			if d, ok := ev["data"].(map[string]interface{}); ok {
				if t, ok := d["fichas_total"].(float64); ok && t > 0 {
					fichasTotal = int(t)
				}
			}
		case tuimodel.EvSagaStart:
			if lvl, ok := tuimodel.FichaPhaseMap[ficha]; ok && lvl != curPhase {
				curPhase = lvl
				if lvl < len(phases) {
					fmt.Printf("\n\033[1m› %s\033[0m\n", phases[lvl].Nombre)
				}
			}
			fmt.Printf("  \033[36m📦 %s%s\033[0m\n", ficha, versionSuffixPlain(ficha))
		case tuimodel.EvStepStart:
			fmt.Printf("  \033[2m  ↳ %s\033[0m\n", step)
		case tuimodel.EvStepOK:
			fmt.Printf("  \033[32m  ✓ %s%s\033[0m\n", step, fmtMsg(msg))
		case tuimodel.EvStepFail:
			errDetail, _ := ev["error"].(string)
			fmt.Printf("  \033[31m  ✗ %s: %s\033[0m\n", step, errDetail)
		case tuimodel.EvSagaOK:
			fichasOK++
			fmt.Printf("  \033[32m✅ [%d/%d] %s\033[0m\n", fichasOK, fichasTotal, ficha)
		case tuimodel.EvSagaFail:
			fmt.Printf("  \033[31m❌ %s: %s\033[0m\n", ficha, msg)
			return 1
		case "bootstrap_complete":
			fmt.Printf("\n\033[1;32m✅ Bootstrap completado: %d/%d componentes\033[0m\n",
				fichasOK, fichasTotal)
			return 0
		}
	}
	return 1
}

// versionSuffixPlain retorna " <versión>" de una ficha sin formato de color.
func versionSuffixPlain(id string) string {
	if v, ok := tuimodel.FichaVersions[id]; ok {
		return " " + v
	}
	return ""
}

// fmtMsg retorna ": <msg>" si msg no está vacío.
func fmtMsg(msg string) string {
	if msg != "" {
		return ": " + msg
	}
	return ""
}

// parseSimpleSeed parsea un seed file en formato simple KEY=VALUE o KEY: VALUE.
func parseSimpleSeed(raw string) tuimodel.SeedData {
	s := tuimodel.SeedData{Pais: "BO"}
	for _, line := range strings.Split(raw, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		var k, v string
		if idx := strings.Index(line, "="); idx > 0 {
			k, v = strings.TrimSpace(line[:idx]), strings.TrimSpace(line[idx+1:])
		} else if idx := strings.Index(line, ":"); idx > 0 {
			k, v = strings.TrimSpace(line[:idx]), strings.Trim(strings.TrimSpace(line[idx+1:]), "\"'")
		} else {
			continue
		}
		switch k {
		case "razon_social":
			s.RazonSocial = v
		case "nit":
			s.NIT = v
		case "pais":
			s.Pais = v
		case "dominio":
			s.Dominio = v
		case "email":
			s.Email = v
		case "nombre":
			s.Nombre = v
		case "password":
			s.Password = v
		case "mfa":
			s.MFA = v == "true" || v == "1"
		}
	}
	return s
}
