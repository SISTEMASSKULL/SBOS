// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

package paths_test

import (
	"strings"
	"testing"

	"bos/internal/paths"
)

// TestPaths_ConstantesNoVacias verifica que ninguna constante de paths es vacía
// y que todas empiezan con "/" (son rutas absolutas).
func TestPaths_ConstantesNoVacias(t *testing.T) {
	t.Parallel()

	constantes := map[string]string{
		"VarLibBos":      paths.VarLibBos,
		"VarLogBos":      paths.VarLogBos,
		"EtcBos":         paths.EtcBos,
		"RunBos":         paths.RunBos,
		"BosPath":        paths.BosPath,
		"SocketPath":     paths.SocketPath,
		"PidFile":        paths.PidFile,
		"BosToml":        paths.BosToml,
		"InstallToml":    paths.InstallToml,
		"BootstrapEnv":   paths.BootstrapEnv,
		"StatePath":      paths.StatePath,
		"KubeDir":        paths.KubeDir,
		"KubeconfigPath": paths.KubeconfigPath,
		"BlibsDir":       paths.BlibsDir,
		"ServersPath":    paths.ServersPath,
		"RBACRoles":      paths.RBACRoles,
		"AuditLog":       paths.AuditLog,
		"AIAuditLog":     paths.AIAuditLog,
		"BootstrapLog":   paths.BootstrapLog,
		"SagasStore":     paths.SagasStore,
		"CatalogVectors": paths.CatalogVectors,
		"BinPath":        paths.BinPath,
		"BosBin":         paths.BosBin,
		"BosctlBin":      paths.BosctlBin,
		"CorePath":       paths.CorePath,
		"MasterScript":   paths.MasterScript,
		"TaskCatalog":    paths.TaskCatalog,
		"YamlEngine":     paths.YamlEngine,
		"HostSetup":      paths.HostSetup,
	}

	for nombre, valor := range constantes {
		t.Run(nombre, func(t *testing.T) {
			t.Parallel()
			if valor == "" {
				t.Errorf("paths.%s está vacío", nombre)
			}
			if !strings.HasPrefix(valor, "/") {
				t.Errorf("paths.%s = %q no es una ruta absoluta", nombre, valor)
			}
		})
	}
}

// TestPaths_JerarquiaCorrecta verifica que los paths hijos están bajo su padre esperado.
func TestPaths_JerarquiaCorrecta(t *testing.T) {
	t.Parallel()

	casos := []struct {
		hijo   string
		padre  string
		nombre string
	}{
		{paths.SocketPath, paths.RunBos, "SocketPath bajo RunBos"},
		{paths.PidFile, paths.RunBos, "PidFile bajo RunBos"},
		{paths.BosToml, paths.EtcBos, "BosToml bajo EtcBos"},
		{paths.InstallToml, paths.EtcBos, "InstallToml bajo EtcBos"},
		{paths.StatePath, paths.EtcBos, "StatePath bajo EtcBos"},
		{paths.KubeconfigPath, paths.KubeDir, "KubeconfigPath bajo KubeDir"},
		{paths.KubeDir, paths.EtcBos, "KubeDir bajo EtcBos"},
		{paths.ServersPath, paths.BlibsDir, "ServersPath bajo BlibsDir"},
		{paths.BlibsDir, paths.EtcBos, "BlibsDir bajo EtcBos"},
		{paths.AuditLog, paths.VarLogBos, "AuditLog bajo VarLogBos"},
		{paths.AIAuditLog, paths.VarLogBos, "AIAuditLog bajo VarLogBos"},
		{paths.BootstrapLog, paths.VarLogBos, "BootstrapLog bajo VarLogBos"},
		{paths.SagasStore, paths.VarLibBos, "SagasStore bajo VarLibBos"},
		{paths.CatalogVectors, paths.VarLibBos, "CatalogVectors bajo VarLibBos"},
		{paths.BosBin, paths.BinPath, "BosBin bajo BinPath"},
		{paths.BosctlBin, paths.BinPath, "BosctlBin bajo BinPath"},
		{paths.BinPath, paths.BosPath, "BinPath bajo BosPath"},
		{paths.MasterScript, paths.CorePath, "MasterScript bajo CorePath"},
		{paths.TaskCatalog, paths.CorePath, "TaskCatalog bajo CorePath"},
		{paths.YamlEngine, paths.CorePath, "YamlEngine bajo CorePath"},
		{paths.HostSetup, paths.CorePath, "HostSetup bajo CorePath"},
		{paths.CorePath, paths.BosPath, "CorePath bajo BosPath"},
	}

	for _, c := range casos {
		t.Run(c.nombre, func(t *testing.T) {
			t.Parallel()
			if !strings.HasPrefix(c.hijo, c.padre+"/") {
				t.Errorf("%s: %q no está bajo %q", c.nombre, c.hijo, c.padre)
			}
		})
	}
}

// TestPaths_ConfigDir verifica el helper ConfigDir.
func TestPaths_ConfigDir(t *testing.T) {
	t.Parallel()

	casos := []struct {
		subdir   string
		esperado string
	}{
		{"certs", "/etc/bos/certs"},
		{"plugins", "/etc/bos/plugins"},
		{"rbac", "/etc/bos/rbac"},
	}

	for _, c := range casos {
		t.Run(c.subdir, func(t *testing.T) {
			t.Parallel()
			got := paths.ConfigDir(c.subdir)
			if got != c.esperado {
				t.Errorf("ConfigDir(%q) = %q, quería %q", c.subdir, got, c.esperado)
			}
		})
	}
}

// TestPaths_LogFile verifica el helper LogFile.
func TestPaths_LogFile(t *testing.T) {
	t.Parallel()

	got := paths.LogFile("saga-install.log")
	esperado := "/var/log/bos/saga-install.log"
	if got != esperado {
		t.Errorf("LogFile(%q) = %q, quería %q", "saga-install.log", got, esperado)
	}
}

// TestPaths_RuntimeFile verifica el helper RuntimeFile para sockets de daemons.
func TestPaths_RuntimeFile(t *testing.T) {
	t.Parallel()

	casos := []struct {
		nombre   string
		esperado string
	}{
		{"bauth.sock", "/run/bos/bauth.sock"},
		{"bkernel.sock", "/run/bos/bkernel.sock"},
		{"biedata.sock", "/run/bos/biedata.sock"},
	}

	for _, c := range casos {
		t.Run(c.nombre, func(t *testing.T) {
			t.Parallel()
			got := paths.RuntimeFile(c.nombre)
			if got != c.esperado {
				t.Errorf("RuntimeFile(%q) = %q, quería %q", c.nombre, got, c.esperado)
			}
		})
	}
}

// TestPaths_SocketPath_SinEspacios verifica que SocketPath no tiene espacios
// (evita errores en syscall.Bind con sockets Unix).
func TestPaths_SocketPath_SinEspacios(t *testing.T) {
	if strings.Contains(paths.SocketPath, " ") {
		t.Errorf("SocketPath = %q contiene espacios — inválido para Unix socket", paths.SocketPath)
	}
}
