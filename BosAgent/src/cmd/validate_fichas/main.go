// validate_local.go — valida todas las fichas locales usando el parser de BOS
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"bos/internal/ficha"
)

func main() {
	serversRoot := "/opt/skull/orquestador/proyectos/SBOS/servers"
	var ok, fail int
	var failList []string

	err := filepath.Walk(serversRoot, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() || info.Name() != "manifest.yml" {
			return nil
		}
		content, err := os.ReadFile(path)
		if err != nil {
			return nil
		}
		fichaDir := filepath.Dir(path)
		result := ficha.ParseManifestStrict(string(content), fichaDir)
		if result.Valid {
			ok++
		} else {
			fail++
			rel := strings.TrimPrefix(fichaDir, serversRoot+"/")
			msgs := make([]string, len(result.Errors))
			for i, e := range result.Errors {
				msgs[i] = e.Field + ": " + e.Message
			}
			failList = append(failList, fmt.Sprintf("FALLA %s\n  → %s", rel, strings.Join(msgs, "\n  → ")))
		}
		return nil
	})
	if err != nil {
		fmt.Println("error:", err)
		os.Exit(1)
	}

	sort.Strings(failList)
	for _, f := range failList {
		fmt.Println(f)
	}
	fmt.Printf("\n========================================\n")
	fmt.Printf("TOTAL: %d  ✓ OK: %d  ✗ FALLAN: %d\n", ok+fail, ok, fail)
}
