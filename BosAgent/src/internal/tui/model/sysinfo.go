// Package model — sysinfo.go: detección de información del sistema operativo.
// Migrado de cmd/bosctl/install_ui_impl.go en BOS-REPAIR F3.MIGRATE.
package model

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

// DetectSystemInfo detecta OS, kernel, RAM, disco y CPU del host.
// Se llama desde Init() como SysInfoMsg para no bloquear el loop TEA.
func DetectSystemInfo() SysInfo {
	info := SysInfo{}

	// OS — leer /etc/os-release directamente (no requiere lsb_release)
	if data, err := os.ReadFile("/etc/os-release"); err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			if strings.HasPrefix(line, "PRETTY_NAME=") {
				info.OS = strings.Trim(strings.TrimPrefix(line, "PRETTY_NAME="), "\"")
				break
			}
		}
	}
	if info.OS == "" {
		if out, err := runCmd("uname", "-o"); err == nil {
			info.OS = strings.TrimSpace(out)
		}
	}

	// Kernel
	if out, err := runCmd("uname", "-r"); err == nil {
		info.Kernel = strings.TrimSpace(out)
	}

	// RAM — leer /proc/meminfo directamente (sin awk)
	if data, err := os.ReadFile("/proc/meminfo"); err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			if strings.HasPrefix(line, "MemTotal:") {
				if fields := strings.Fields(line); len(fields) >= 2 {
					if kb, err := strconv.ParseInt(fields[1], 10, 64); err == nil {
						gb := float64(kb) / 1024 / 1024
						info.RAM = fmt.Sprintf("%.1f GB", gb)
					}
				}
				break
			}
		}
	}

	// Disco
	if out, err := runCmd("df", "-BG", "/"); err == nil {
		lines := strings.Split(out, "\n")
		if len(lines) >= 2 {
			if fields := strings.Fields(lines[1]); len(fields) >= 4 {
				info.Disk = strings.TrimSuffix(fields[3], "G") + " GB disponibles"
			}
		}
	}

	// CPU — leer /proc/cpuinfo directamente (sin nproc)
	if data, err := os.ReadFile("/proc/cpuinfo"); err == nil {
		count := 0
		for _, line := range strings.Split(string(data), "\n") {
			if strings.HasPrefix(line, "processor") {
				count++
			}
		}
		if count > 0 {
			info.CPU = fmt.Sprintf("%d cores", count)
		}
	}
	if info.CPU == "" {
		if out, err := runCmd("nproc"); err == nil {
			info.CPU = strings.TrimSpace(out) + " cores"
		}
	}

	return info
}

// runCmd ejecuta un comando externo y retorna stdout. Solo para detección de sysinfo.
func runCmd(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	var stdout bytes.Buffer
	cmd.Stdout = &stdout
	err := cmd.Run()
	return stdout.String(), err
}
