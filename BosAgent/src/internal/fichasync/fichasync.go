// Package fichasync sincroniza fichas desde un repositorio git remoto.
// Permite que BOS auto-actualice su catálogo de fichas al arrancar
// sin intervención humana — principio P5 (pull-only, nunca recibe push).
//
// Usa git sparse-checkout para descargar SOLO servers/ del monorepo,
// evitando clonar el código fuente completo (~MB vs ~GB).
//
// Flujo:
//  1. Si servers_git_url está vacío → sync desactivado, BOS opera con fichas locales.
//  2. Si el clon sparse existe en /tmp/bos-fichas-sync → git pull.
//  3. Si no existe → git clone --depth=1 --filter=blob:none --sparse + sparse-checkout set servers/
//  4. Copia servers/ del clon a ServersPath con rsync --archive --delete.
//  5. Cualquier error es WARN (no fatal) — el daemon nunca falla por sync.
package fichasync

import (
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

const cloneDir = "/tmp/bos-fichas-sync"

// SyncFromGit descarga o actualiza las fichas desde el repositorio git configurado.
// Retorna nil en éxito y también en fallo no-fatal — nunca bloquea el arranque de BOS.
func SyncFromGit(serversPath, gitURL string, log *slog.Logger) error {
	if gitURL == "" {
		log.Debug("fichasync: servers_git_url no configurado — sync desactivado")
		return nil
	}

	start := time.Now()
	log.Info("fichasync: iniciando sincronización", "url", maskURL(gitURL), "dest", serversPath)

	if err := runGitStep(gitURL, log); err != nil {
		log.Warn("fichasync: git falló — BOS continúa con fichas existentes", "error", err)
		return nil
	}

	srcServers := filepath.Join(cloneDir, "servers")
	if _, err := os.Stat(srcServers); os.IsNotExist(err) {
		log.Warn("fichasync: servers/ no encontrado en clon", "path", srcServers)
		return nil
	}

	if err := runRsync(srcServers, serversPath, log); err != nil {
		log.Warn("fichasync: rsync falló — BOS continúa con fichas existentes", "error", err)
		return nil
	}

	count := countManifests(serversPath)
	log.Info("fichasync: sincronización completada",
		"fichas", count,
		"elapsed", time.Since(start).Round(time.Millisecond))
	return nil
}

// runGitStep ejecuta git clone (sparse) o git pull según si el clon ya existe.
// Sparse checkout descarga SOLO servers/ — evita clonar el monorepo completo.
func runGitStep(gitURL string, log *slog.Logger) error {
	if _, err := os.Stat(filepath.Join(cloneDir, ".git")); err == nil {
		log.Info("fichasync: actualizando clon existente", "dir", cloneDir)
		cmd := exec.Command("git", "-C", cloneDir, "pull", "--depth=1", "--rebase=false")
		if out, err := cmd.CombinedOutput(); err != nil {
			return fmt.Errorf("git pull: %w — %s", err, out)
		}
		return nil
	}

	// Clon nuevo con sparse checkout — solo descarga servers/
	_ = os.RemoveAll(cloneDir)
	log.Info("fichasync: clonando (sparse) — solo servers/", "url", maskURL(gitURL))

	steps := [][]string{
		{"git", "clone", "--depth=1", "--filter=blob:none", "--sparse", gitURL, cloneDir},
		{"git", "-C", cloneDir, "sparse-checkout", "set", "servers"},
	}
	for _, args := range steps {
		if out, err := exec.Command(args[0], args[1:]...).CombinedOutput(); err != nil {
			return fmt.Errorf("%s: %w — %s", args[2], err, out)
		}
	}
	return nil
}

// runRsync copia srcServers/ a destServers/ con --archive --delete.
func runRsync(srcServers, destServers string, log *slog.Logger) error {
	if err := os.MkdirAll(destServers, 0755); err != nil {
		return fmt.Errorf("crear destino: %w", err)
	}
	log.Info("fichasync: copiando servers/", "src", srcServers, "dst", destServers)
	cmd := exec.Command("rsync", "-a", "--delete",
		"--exclude=_descartadas",
		"--exclude=PROPOSITO.md",
		"--exclude=servers.yml",
		srcServers+"/",
		destServers+"/",
	)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("rsync: %w — %s", err, out)
	}
	return nil
}

// countManifests cuenta manifests en serversPath para el log de cierre.
func countManifests(serversPath string) int {
	count := 0
	_ = filepath.WalkDir(serversPath, func(_ string, d os.DirEntry, err error) error {
		if err == nil && !d.IsDir() && d.Name() == "manifest.yml" {
			count++
		}
		return nil
	})
	return count
}

// maskURL oculta credenciales en URLs del tipo https://user:token@host/repo.
func maskURL(u string) string {
	for i, c := range u {
		if c == '@' {
			for j := i - 1; j >= 0; j-- {
				if u[j] == ':' {
					return u[:j+1] + "***" + u[i:]
				}
			}
		}
	}
	return u
}
