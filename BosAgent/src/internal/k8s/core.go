// Package k8s implements the sole kubectl dispatch point (Principle P1).
// All Kubernetes operations in the SBOS MUST route through this package.
// P10: Every apply is preceded by --dry-run validation.
package k8s

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// Core es el único dispatcher de operaciones K8s del SBOS (Principio P1).
//
// Thread safety: los métodos son seguros para llamar concurrentemente;
// cada llamada a kubectl usa su propio exec.CommandContext.
type Core struct {
	kubeconfig string
	timeout    time.Duration
}

// NewCore crea un Core K8s con el kubeconfig y timeout dados.
//
// Recibe:
//   - kubeconfig: string — ruta al kubeconfig (vacío → ~/.kube/config).
//   - timeout: time.Duration — timeout por operación kubectl (0 → 5min).
//
// Callers conocidos:
//   - cmd/bos/main.go:runNormal — crea Core para operaciones K8s.
func NewCore(kubeconfig string, timeout time.Duration) *Core {
	if kubeconfig == "" {
		kubeconfig = filepath.Join(os.Getenv("HOME"), ".kube", "config")
	}
	if timeout == 0 {
		timeout = 5 * time.Minute
	}
	return &Core{kubeconfig: kubeconfig, timeout: timeout}
}

func (c *Core) kubectl(ctx context.Context, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, "kubectl", args...)
	cmd.Env = append(os.Environ(), "KUBECONFIG="+c.kubeconfig)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("kubectl %s: %s — %w", strings.Join(args, " "), stderr.String(), err)
	}
	return stdout.String(), nil
}

// Apply aplica un manifest Kubernetes. P10: dry-run primero.
//
// Efectos secundarios:
//   - Ejecuta kubectl apply --dry-run=client; falla si el manifest es inválido.
//   - Ejecuta kubectl apply si dry-run pasa.
func (c *Core) Apply(manifestPath, namespace string) error {
	ctx, cancel := context.WithTimeout(context.Background(), c.timeout)
	defer cancel()

	// P10: dry-run validation before every apply
	args := []string{"apply", "-f", manifestPath, "--dry-run=client"}
	if namespace != "" {
		args = append(args, "-n", namespace)
	}
	if _, err := c.kubectl(ctx, args...); err != nil {
		return fmt.Errorf("k8s: dry-run failed for %s: %w", manifestPath, err)
	}

	// Actual apply
	args = []string{"apply", "-f", manifestPath}
	if namespace != "" {
		args = append(args, "-n", namespace)
	}
	if _, err := c.kubectl(ctx, args...); err != nil {
		return fmt.Errorf("k8s: apply failed for %s: %w", manifestPath, err)
	}

	return nil
}

// Delete elimina un manifest del cluster (--ignore-not-found).
//
// Efectos secundarios: ejecuta kubectl delete. No falla si el recurso no existe.
func (c *Core) Delete(manifestPath, namespace string) error {
	ctx, cancel := context.WithTimeout(context.Background(), c.timeout)
	defer cancel()

	args := []string{"delete", "-f", manifestPath, "--ignore-not-found"}
	if namespace != "" {
		args = append(args, "-n", namespace)
	}
	if _, err := c.kubectl(ctx, args...); err != nil {
		return fmt.Errorf("k8s: delete failed for %s: %w", manifestPath, err)
	}
	return nil
}

// CreateNamespace crea un namespace K8s si no existe. Ignora AlreadyExists.
//
// Efectos secundarios: ejecuta kubectl create namespace (con dry-run previo).
func (c *Core) CreateNamespace(name string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	_, err := c.kubectl(ctx, "create", "namespace", name, "--dry-run=client", "-o", "yaml")
	if err != nil {
		return err
	}
	_, err = c.kubectl(ctx, "create", "namespace", name)
	if err != nil {
		// Ignore AlreadyExists errors
		if strings.Contains(err.Error(), "AlreadyExists") {
			return nil
		}
		return fmt.Errorf("k8s: create namespace %s: %w", name, err)
	}
	return nil
}

// CreateSecret crea un Secret genérico K8s a partir de pares key=value.
// Ignora AlreadyExists. NUNCA registrar en logs los valores (ADR-003 Level 3 Efectos).
//
// Efectos secundarios: ejecuta kubectl create secret generic.
func (c *Core) CreateSecret(name, namespace string, data map[string]string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	args := []string{"create", "secret", "generic", name, "-n", namespace}
	for k, v := range data {
		args = append(args, fmt.Sprintf("--from-literal=%s=%s", k, v))
	}

	if _, err := c.kubectl(ctx, args...); err != nil {
		if strings.Contains(err.Error(), "AlreadyExists") {
			return nil
		}
		return fmt.Errorf("k8s: create secret %s/%s: %w", namespace, name, err)
	}
	return nil
}

// ApplyConfigMap crea o actualiza un ConfigMap desde un archivo. P10: dry-run previo.
//
// Efectos secundarios: ejecuta kubectl create configmap con --from-file. Ignora AlreadyExists.
func (c *Core) ApplyConfigMap(name, namespace, filePath string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	_, err := c.kubectl(ctx, "create", "configmap", name, "-n", namespace,
		"--from-file="+filePath, "--dry-run=client", "-o", "yaml")
	if err != nil {
		return err
	}
	_, err = c.kubectl(ctx, "create", "configmap", name, "-n", namespace,
		"--from-file="+filePath)
	if err != nil {
		if strings.Contains(err.Error(), "AlreadyExists") {
			return nil
		}
		return fmt.Errorf("k8s: configmap %s/%s: %w", namespace, name, err)
	}
	return nil
}

// CreatePVC crea un PersistentVolumeClaim con accessMode ReadWriteOnce.
// Genera un manifiesto temporal y delega en Apply (con P10 dry-run).
//
// Efectos secundarios: escribe un archivo tmp, aplica con kubectl, elimina el tmp.
func (c *Core) CreatePVC(name, namespace, storageClass, size string) error {
	manifest := fmt.Sprintf(`---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: %s
  namespace: %s
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: %s
  storageClassName: %s
`, name, namespace, size, storageClass)

	tmp, err := os.CreateTemp("", "bos-pvc-*.yaml")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())

	if _, err := tmp.WriteString(manifest); err != nil {
		tmp.Close()
		return err
	}
	tmp.Close()

	return c.Apply(tmp.Name(), namespace)
}

// DeletePVC elimina un PersistentVolumeClaim (--ignore-not-found, timeout 2min).
func (c *Core) DeletePVC(name, namespace string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	_, err := c.kubectl(ctx, "delete", "pvc", name, "-n", namespace, "--ignore-not-found")
	return err
}

// PodReady verifica si un pod está en condición Ready (jsonpath .status.conditions[Ready].status).
//
// Retorna: (true, nil) si Ready=="True", (false, nil) si no Ready, (false, error) si kubectl falla.
func (c *Core) PodReady(name, namespace string) (bool, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	out, err := c.kubectl(ctx, "get", "pod", name, "-n", namespace,
		"-o", "jsonpath={.status.conditions[?(@.type==\"Ready\")].status}")
	if err != nil {
		return false, err
	}
	return strings.TrimSpace(out) == "True", nil
}

// ExecInPod ejecuta un comando dentro de un contenedor de pod (kubectl exec /bin/sh -c).
// Si container es vacío, usa el contenedor por defecto.
//
// Efectos secundarios: ejecuta código remoto en el pod — validar el caller que command no es destructivo.
func (c *Core) ExecInPod(pod, namespace, container, command string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	args := []string{"exec", pod, "-n", namespace}
	if container != "" {
		args = append(args, "-c", container)
	}
	args = append(args, "--", "/bin/sh", "-c", command)

	return c.kubectl(ctx, args...)
}

// ApplyNetworkPolicy aplica un manifiesto NetworkPolicy. Delega en Apply (P10 dry-run).
func (c *Core) ApplyNetworkPolicy(manifestPath, namespace string) error {
	return c.Apply(manifestPath, namespace)
}

// WaitForPodReady espera hasta que un pod esté Ready o se alcance el timeout.
// Pollea cada 2 segundos con PodReady().
//
// Efectos secundarios: hace múltiples llamadas a kubectl get pod durante el timeout.
func (c *Core) WaitForPodReady(name, namespace string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		ready, err := c.PodReady(name, namespace)
		if err == nil && ready {
			return nil
		}
		time.Sleep(2 * time.Second)
	}
	return fmt.Errorf("k8s: pod %s/%s not ready after %v", namespace, name, timeout)
}

// CreatePodFromManifest crea un pod temporal desde un manifiesto YAML en string.
// Escribe el YAML en un archivo tmp, lo aplica con Apply (P10 dry-run), luego elimina el tmp.
//
// Callers conocidos:
//   - internal/domain/pg_auxiliar_service.go:Start — pod auxiliar PostgreSQL.
func (c *Core) CreatePodFromManifest(manifestYAML, namespace string) error {
	tmp, err := os.CreateTemp("", "bos-pgaux-*.yaml")
	if err != nil {
		return fmt.Errorf("k8s: cannot create temp file: %w", err)
	}
	defer os.Remove(tmp.Name())

	if _, err := tmp.WriteString(manifestYAML); err != nil {
		tmp.Close()
		return fmt.Errorf("k8s: cannot write manifest: %w", err)
	}
	tmp.Close()

	return c.Apply(tmp.Name(), namespace)
}

// DeletePod elimina un pod por nombre en un namespace (--ignore-not-found, timeout 30s).
func (c *Core) DeletePod(name, namespace string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	_, err := c.kubectl(ctx, "delete", "pod", name, "-n", namespace, "--ignore-not-found")
	return err
}

// CopyToPod copia un archivo local a un pod mediante kubectl cp (timeout 2min).
func (c *Core) CopyToPod(srcPath, pod, namespace, destPath string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	_, err := c.kubectl(ctx, "cp", srcPath, fmt.Sprintf("%s/%s:%s", namespace, pod, destPath))
	return err
}

// GetRawJSON ejecuta kubectl con los args dados y retorna la salida en bytes.
// Punto único de acceso para fuentes de consulta (query/k8s.go — Principio P1).
func (c *Core) GetRawJSON(ctx context.Context, args ...string) ([]byte, error) {
	out, err := c.kubectl(ctx, args...)
	return []byte(out), err
}
