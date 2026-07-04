package main

// cmdSystemInstall — "bosctl system-install"
//
// Punto de entrada para la primera instalación del sistema.
// Invocado por install.sh (el único script externo permitido).
//
// Responsabilidades:
//  1. Copiar binarios bos/bosctl a /opt/bos/bin/
//  2. Instalar servicios systemd
//  3. Ejecutar la ficha bos-preflight (dependencias del SO, usuario, dirs, cgroups)
//
// La ficha bos-preflight es declarativa (servers/S-HOST/bos-preflight/).
// Agregar dependencias = editar manifest.yml, sin recompilar.
//
// Norma: sin intervención manual en el servidor.
// El instalador cubre cualquier falla o dependencia faltante.

import (
	"flag"
	"fmt"
	"os"
	"strings"
	"os/exec"
	"path/filepath"

	"bos/internal/boslog"
	"bos/internal/paths"
)

func cmdSystemInstall(args []string) int {
	boslog.Init("bosctl")
	fs := flag.NewFlagSet("system-install", flag.ContinueOnError)
	mode := fs.String("mode", "prod", "modo de instalación: dev (advertencias no bloquean) | prod (requisitos estrictos)")
	if err := fs.Parse(args); err != nil {
		fmt.Fprintf(os.Stderr, "bosctl system-install: %v\n", err)
		return 8
	}

	if *mode != "dev" && *mode != "prod" {
		fmt.Fprintf(os.Stderr, "bosctl system-install: --mode debe ser 'dev' o 'prod' (recibido: %q)\n", *mode)
		return 8
	}

	if os.Geteuid() != 0 {
		fmt.Fprintln(os.Stderr, "bosctl system-install: se requiere ejecutar como root (sudo)")
		return 8
	}

	if *mode == "dev" {
		fmt.Println("⚠  MODO DEV — los requisitos de recursos son advertencias, no bloquean la instalación")
	}

	steps := []struct {
		name string
		fn   func() error
	}{
		{"binarios", installBinaries},
		{"core", installCore},
		{"blibs", installBlibs},
		{"env", installEnvTemplate},
		{"servicios", installServices},
		{"preflight", func() error { return runPreflightFicha(*mode) }},
	}

	for _, s := range steps {
		fmt.Printf("  → %s... ", s.name)
		boslog.Info("system-install paso iniciado", "paso", s.name)
		if err := s.fn(); err != nil {
			fmt.Printf("✗ %v\n", err)
			boslog.Error("system-install paso FALLO", "paso", s.name, "err", err)
			return 1
		}
		boslog.Info("system-install paso OK", "paso", s.name)
		fmt.Println("✓")
	}

	boslog.Info("system-install completado")
	fmt.Println("\nSistema listo. BOS arrancará en la consola (tty1) automáticamente.")
	fmt.Println("Para ver logs: journalctl -t bos-bosctl")
	return 0
}

// installBinaries copia bos y bosctl al directorio de instalación.
// Detecta la ubicación del binario actual para encontrar el bos companion.
func installBinaries() error {
	self, err := os.Executable()
	if err != nil {
		return fmt.Errorf("no se pudo detectar ruta del ejecutable: %w", err)
	}
	selfDir := filepath.Dir(self)

	const dest = paths.BinPath
	if err := os.MkdirAll(dest, 0755); err != nil {
		return fmt.Errorf("crear %s: %w", dest, err)
	}

	for _, name := range []string{"bos", "bosctl"} {
		src := filepath.Join(selfDir, name)
		if _, err := os.Stat(src); os.IsNotExist(err) {
			src = name
			if _, err2 := os.Stat(src); os.IsNotExist(err2) {
				return fmt.Errorf("binario %s no encontrado en %s ni en directorio actual", name, selfDir)
			}
		}
		dst := filepath.Join(dest, name)
		if err := copyFile(src, dst, 0755); err != nil {
			if strings.Contains(err.Error(), "text file busy") {
				continue // binario corriendo desde aquí
			}
			return fmt.Errorf("instalar %s: %w", name, err)
		}
		// Symlink en /usr/local/bin para que "bosctl setup" funcione sin ruta completa
		link := filepath.Join("/usr/local/bin", name)
		_ = os.Remove(link)
		if err := os.Symlink(dst, link); err != nil {
			return fmt.Errorf("symlink %s: %w", name, err)
		}
	}
	return nil
}

// ── installCore ───────────────────────────────────────────────────
// Copia los scripts del motor Bash (core/) a /opt/bos/core/.
// El daemon los necesita para ejecutar las sagas de fichas.
// Sin esto, bos.ficha.install falla con exit 127.
func installCore() error {
	const dest = paths.CorePath
	if err := os.MkdirAll(dest, 0755); err != nil {
		return fmt.Errorf("crear %s: %w", dest, err)
	}

	self, _ := os.Executable()
	selfDir := filepath.Dir(self)

	coreDir := ""
	for _, d := range []string{
		filepath.Join(selfDir, "core"),
		"core",
	} {
		if info, err := os.Stat(d); err == nil && info.IsDir() {
			coreDir = d
			break
		}
	}
	if coreDir == "" {
		return fmt.Errorf("directorio core/ no encontrado — incluir en el paquete de deploy")
	}

	entries, err := os.ReadDir(coreDir)
	if err != nil {
		return fmt.Errorf("leer core/: %w", err)
	}
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".sh") {
			continue
		}
		src := filepath.Join(coreDir, e.Name())
		dst := filepath.Join(dest, e.Name())
		if err := copyFile(src, dst, 0755); err != nil {
			if strings.Contains(err.Error(), "text file busy") {
				continue
			}
			return fmt.Errorf("copiar %s: %w", e.Name(), err)
		}
	}
	return nil
}

// ── installBlibs ──────────────────────────────────────────────────
// Copia el directorio servers/ a /etc/bos/blibs/servers/.
// El daemon carga las fichas declarativas desde aquí al iniciar.
// Sin esto, bos.ficha.install no encuentra ninguna ficha.
func installBlibs() error {
	const dest = paths.ServersPath
	if err := os.MkdirAll(dest, 0755); err != nil {
		return fmt.Errorf("crear %s: %w", dest, err)
	}

	self, _ := os.Executable()
	selfDir := filepath.Dir(self)

	serversDir := ""
	for _, d := range []string{
		filepath.Join(selfDir, "servers"),
		"servers",
	} {
		if info, err := os.Stat(d); err == nil && info.IsDir() {
			serversDir = d
			break
		}
	}
	if serversDir == "" {
		return fmt.Errorf("directorio servers/ no encontrado — incluir en el paquete de deploy")
	}

	// Copiar recursivamente con cp -a
	cmd := exec.Command("cp", "-a", serversDir+"/.", dest+"/")
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("copiar servers/ a blibs: %w — %s", err, out)
	}
	return nil
}

// installServices instala los archivos .service en systemd y los habilita.
func installServices() error {
	self, err := os.Executable()
	if err != nil {
		return fmt.Errorf("detectar ejecutable: %w", err)
	}
	selfDir := filepath.Dir(self)

	services := []string{"bos.service", "bos-console.service"}
	for _, svc := range services {
		src := filepath.Join(selfDir, svc)
		if _, err := os.Stat(src); os.IsNotExist(err) {
			// Generar servicio mínimo si no está en el directorio de deploy
			if err2 := writeDefaultService(svc); err2 != nil {
				return fmt.Errorf("generar %s: %w", svc, err2)
			}
			continue
		}
		dst := filepath.Join("/etc/systemd/system", svc)
		if err := copyFile(src, dst, 0644); err != nil {
			return fmt.Errorf("instalar %s: %w", svc, err)
		}
	}

	cmd := exec.Command("systemctl", "daemon-reload")
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("daemon-reload: %w — %s", err, out)
	}
	for _, svc := range services {
		cmd = exec.Command("systemctl", "enable", svc)
		if out, err := cmd.CombinedOutput(); err != nil {
			return fmt.Errorf("enable %s: %w — %s", svc, err, out)
		}
	}
	return nil
}

// installEnvTemplate copia bos-bootstrap.env a /etc/bos/ si no existe.
// No sobreescribe nunca — el admin puede haber personalizado los valores.
func installEnvTemplate() error {
	// Crear bos-install.toml mínimo si no existe (requerido para modo normal)
	tomlDest := paths.InstallToml
	if _, err := os.Stat(tomlDest); os.IsNotExist(err) {
		tomlContent := `org_name = "SBOS-Setup"
client_domain = "skull.local"
channel = "stable"
http_port = 9443
servers_path = paths.CorePath + "/servers"
kubeconfig_path = paths.KubeconfigPath
unix_socket = paths.SocketPath
bos_user = "bosagent"
bos_group = "bosagent"
log_path = paths.VarLogBos
`
		_ = os.MkdirAll(paths.EtcBos, 0750)
		_ = os.WriteFile(tomlDest, []byte(tomlContent), 0644)
	}

	const dest = paths.BootstrapEnv
	if _, err := os.Stat(dest); err == nil {
		return nil // ya existe — no tocar
	}
	if err := os.MkdirAll(paths.EtcBos, 0750); err != nil {
		return err
	}

	self, _ := os.Executable()
	selfDir := filepath.Dir(self)
	for _, src := range []string{
		filepath.Join(selfDir, "bos-bootstrap.env"),
		"bos-bootstrap.env",
	} {
		if data, err := os.ReadFile(src); err == nil {
			return os.WriteFile(dest, data, 0640)
		}
	}
	// Si no hay plantilla en el paquete, crear una mínima
	const minimal = "# bos-bootstrap.env — completar y ejecutar: bosctl setup\n" +
		"BOS_TENANT_NAME=\nBOS_TENANT_NIT=\nBOS_TENANT_PAIS=BO\n" +
		"BOS_TENANT_DOMAIN=\nBOS_ROOT_USER=\nBOS_ADMIN_NOMBRE=\n" +
		"BOS_ROOT_PASSWORD=\nBOS_MFA_ENABLED=true\n"
	return os.WriteFile(dest, []byte(minimal), 0640)
}

// runPreflightFicha ejecuta la ficha bos-preflight via task_catalog.sh.
// mode: "dev" (advertencias no bloquean) | "prod" (requisitos estrictos).
func runPreflightFicha(mode string) error {
	// Buscar el task_catalog.sh de bos-preflight en rutas conocidas.
	candidates := []string{
		"/opt/bos/core/servers/S-HOST/bos-preflight/task_catalog.sh",
		"servers/S-HOST/bos-preflight/task_catalog.sh",
	}
	// También buscar junto al ejecutable actual
	if self, err := os.Executable(); err == nil {
		candidates = append(candidates,
			filepath.Join(filepath.Dir(self), "servers/S-HOST/bos-preflight/task_catalog.sh"),
		)
	}

	catalog := ""
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			catalog = c
			break
		}
	}
	if catalog == "" {
		return fmt.Errorf("task_catalog.sh de bos-preflight no encontrado — incluir en el paquete de deploy")
	}

	cmd := exec.Command("bash", catalog)
	cmd.Env = append(os.Environ(),
		"__SBOS__STEP_START__=STEP_START",
		"__SBOS__STEP_OK__=STEP_OK",
		"__SBOS__STEP_FAIL__=STEP_FAIL",
		"__SBOS__STEP_SKIP__=STEP_SKIP",
		"FICHA_LOG=/var/log/bos/fichas/bos-preflight.log",
		"BOS_INSTALL_MODE="+mode,
	)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// Llamar ficha_install (función dentro del catalog)
	// En bash, source + llamar función directamente
	wrapper := exec.Command("bash", "-c",
		fmt.Sprintf(`source %q && ficha_pre_install && ficha_install && ficha_post_install`, catalog),
	)
	wrapper.Env = cmd.Env
	wrapper.Stdout = os.Stdout
	wrapper.Stderr = os.Stderr

	if err := wrapper.Run(); err != nil {
		return fmt.Errorf("ficha bos-preflight falló: %w", err)
	}
	return nil
}

// copyFile copia src a dst con permisos perm.
func copyFile(src, dst string, perm os.FileMode) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	_ = os.Remove(dst) // quitar destino si existe (evita text file busy)
	return os.WriteFile(dst, data, perm)
}

// writeDefaultService genera un archivo .service mínimo si no viene en el deploy.
func writeDefaultService(name string) error {
	var content string
	switch name {
	case "bos.service":
		content = `[Unit]
Description=BOS IAM Installer Daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/bos
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
`
	case "bos-console.service":
		content = `[Unit]
Description=BOS Console — Dashboard en tty1
After=bos.service
Requires=bos.service

[Service]
Type=simple
ExecStart=/usr/local/bin/bosctl setup
StandardInput=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
`
	default:
		return fmt.Errorf("servicio desconocido: %s", name)
	}
	return os.WriteFile(filepath.Join("/etc/systemd/system", name), []byte(content), 0644)
}
