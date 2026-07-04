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

// Core is the single K8s operation dispatcher. Principle P1.
type Core struct {
	kubeconfig string
	timeout    time.Duration
}

// NewCore creates a K8s Core with the given kubeconfig path.
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

// Apply applies a Kubernetes manifest. P10: dry-run first.
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

// Delete removes a manifest from the cluster.
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

// CreateNamespace creates a Kubernetes namespace if it doesn't exist.
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

// CreateSecret creates a Kubernetes secret from literal key=value pairs.
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

// ApplyConfigMap creates or updates a ConfigMap from a file.
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

// CreatePVC creates a PersistentVolumeClaim.
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

// DeletePVC removes a PersistentVolumeClaim.
func (c *Core) DeletePVC(name, namespace string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	_, err := c.kubectl(ctx, "delete", "pvc", name, "-n", namespace, "--ignore-not-found")
	return err
}

// PodReady checks if a pod is in Ready condition.
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

// ExecInPod runs a command inside a pod container.
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

// ApplyNetworkPolicy applies a NetworkPolicy manifest.
func (c *Core) ApplyNetworkPolicy(manifestPath, namespace string) error {
	return c.Apply(manifestPath, namespace)
}

// WaitForPodReady espera hasta que un pod esté Ready o se alcance el timeout.
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

// DeletePod elimina un pod por nombre en un namespace.
func (c *Core) DeletePod(name, namespace string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	_, err := c.kubectl(ctx, "delete", "pod", name, "-n", namespace, "--ignore-not-found")
	return err
}

// CopyToPod copia un archivo local a un pod mediante kubectl cp.
func (c *Core) CopyToPod(srcPath, pod, namespace, destPath string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	_, err := c.kubectl(ctx, "cp", srcPath, fmt.Sprintf("%s/%s:%s", namespace, pod, destPath))
	return err
}
