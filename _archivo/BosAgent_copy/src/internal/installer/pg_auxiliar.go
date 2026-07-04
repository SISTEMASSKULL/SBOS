package installer

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
	"time"
)

// PgAuxStepObserver es una función callback que recibe progreso de un paso del PG auxiliar.
type PgAuxStepObserver func(stepName string, progress float64, message string)

// PgAuxBackupResult es el resultado de una operación de backup del PG auxiliar.
type PgAuxBackupResult struct {
	Success    bool
	BytesTotal int64
	WALOffset  string
	Error      string
}

// PgAuxiliarExecutor ejecuta comandos externos para el PG auxiliar anti-pérdida.
// Implementa domain.PgAuxInstallerPort implícitamente (Go structural typing).
type PgAuxiliarExecutor struct {
	kubeconfig string
}

// NewPgAuxiliarExecutor crea un nuevo executor de PG auxiliar.
func NewPgAuxiliarExecutor(kubeconfig string) *PgAuxiliarExecutor {
	return &PgAuxiliarExecutor{kubeconfig: kubeconfig}
}

// RunPgBasebackup ejecuta pg_basebackup desde el pod PG real al pod auxiliar.
func (e *PgAuxiliarExecutor) RunPgBasebackup(sourcePod, sourceNS, targetPod, targetNS string, observer PgAuxStepObserver) (*PgAuxBackupResult, error) {
	result := &PgAuxBackupResult{}

	// Obtener IP del pod target (auxiliar)
	targetIP, err := e.podIP(targetPod, targetNS)
	if err != nil {
		return result, fmt.Errorf("pg_auxiliar: cannot get aux pod IP: %w", err)
	}
	result.WALOffset = "0/0"

	// Configurar pg_hba.conf en el auxiliar para aceptar conexiones
	setupCmd := fmt.Sprintf(
		"echo 'host all all 0.0.0.0/0 md5' >> /var/lib/postgresql/data/pg_hba.conf && "+
			"echo \"listen_addresses = '*'\" >> /var/lib/postgresql/data/postgresql.conf && "+
			"pg_ctl -D /var/lib/postgresql/data reload 2>/dev/null || true")
	e.kubectlExec(targetPod, targetNS, "", setupCmd)

	// Ejecutar pg_basebackup desde el source hacia el target
	backupCmd := fmt.Sprintf(
		"PGPASSWORD=sbos_aux_temp_pass pg_basebackup -h %s -p 5432 -U postgres -D - -Ft -X fetch -P -v 2>&1",
		targetIP)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()

	kctx, kcancel := context.WithTimeout(ctx, 5*time.Minute)
	defer kcancel()

	execArgs := []string{
		"exec", sourcePod, "-n", sourceNS, "--",
		"/bin/sh", "-c", backupCmd,
	}

	cmd := exec.CommandContext(kctx, "kubectl", execArgs...)
	cmd.Env = append(os.Environ(), "KUBECONFIG="+e.kubeconfig)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Start(); err != nil {
		return result, fmt.Errorf("pg_basebackup start failed: %w", err)
	}

	// Leer progreso en tiempo real
	scanner := bufio.NewScanner(io.MultiReader(&stdout, &stderr))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.Contains(line, "KB") || strings.Contains(line, "MB") || strings.Contains(line, "GB") {
			fmt.Fprintf(os.Stderr, "[pg_auxiliar] %s\n", line)
		}
		if observer != nil {
			observer("pg_basebackup", 0.5, line)
		}
	}

	if err := cmd.Wait(); err != nil {
		return result, fmt.Errorf("pg_basebackup failed: %s — %w", stderr.String(), err)
	}

	result.Success = true
	return result, nil
}

// RunPgDump ejecuta pg_dump desde el pod auxiliar y retorna la ruta al dump.
func (e *PgAuxiliarExecutor) RunPgDump(sourcePod, sourceNS, database string) (string, error) {
	dumpPath := fmt.Sprintf("/tmp/sbos-pg-dump-%d.sql", time.Now().Unix())

	dumpCmd := fmt.Sprintf(
		"pg_dump -U postgres %s > %s 2>&1 && echo '__SBOS__STEP_OK__ pg_dump' || echo '__SBOS__STEP_FAIL__ pg_dump'",
		database, dumpPath)

	output, err := e.kubectlExecOutput(sourcePod, sourceNS, "", dumpCmd)
	if err != nil {
		return "", fmt.Errorf("pg_dump failed: %s — %w", output, err)
	}

	if strings.Contains(output, SignalStepFail) {
		return "", fmt.Errorf("pg_dump signal: %s", output)
	}

	return dumpPath, nil
}

// RunPgRestore restaura un dump SQL en el PG principal.
func (e *PgAuxiliarExecutor) RunPgRestore(targetPod, targetNS, dumpPath string) error {
	restoreCmd := fmt.Sprintf(
		"psql -U postgres -f %s 2>&1 && echo '__SBOS__STEP_OK__ pg_restore' || echo '__SBOS__STEP_FAIL__ pg_restore'",
		dumpPath)

	output, err := e.kubectlExecOutput(targetPod, targetNS, "", restoreCmd)
	if err != nil {
		return fmt.Errorf("pg_restore failed: %s — %w", output, err)
	}

	if strings.Contains(output, SignalStepFail) {
		return fmt.Errorf("pg_restore signal: %s", output)
	}

	return nil
}

// ── Helpers ─────────────────────────────────────────────────────────────

func (e *PgAuxiliarExecutor) podIP(pod, namespace string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	args := []string{"get", "pod", pod, "-n", namespace,
		"-o", "jsonpath={.status.podIP}"}

	cmd := exec.CommandContext(ctx, "kubectl", args...)
	cmd.Env = append(os.Environ(), "KUBECONFIG="+e.kubeconfig)

	var stdout bytes.Buffer
	cmd.Stdout = &stdout

	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("kubectl get pod IP: %w", err)
	}

	ip := strings.TrimSpace(stdout.String())
	if ip == "" {
		return "", fmt.Errorf("pod %s/%s has no IP", namespace, pod)
	}
	return ip, nil
}

func (e *PgAuxiliarExecutor) kubectlExec(pod, namespace, container, command string) (string, error) {
	return e.kubectlExecOutput(pod, namespace, container, command)
}

func (e *PgAuxiliarExecutor) kubectlExecOutput(pod, namespace, container, command string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	args := []string{"exec", pod, "-n", namespace}
	if container != "" {
		args = append(args, "-c", container)
	}
	args = append(args, "--", "/bin/sh", "-c", command)

	cmd := exec.CommandContext(ctx, "kubectl", args...)
	cmd.Env = append(os.Environ(), "KUBECONFIG="+e.kubeconfig)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return stderr.String(), fmt.Errorf("kubectl exec: %s — %w", stderr.String(), err)
	}

	return stdout.String(), nil
}
