package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func cmdLogs(args []string) int {
	fs := flag.NewFlagSet("logs", flag.ExitOnError)
	follow := fs.Bool("follow", false, "stream logs in real time")
	namespace := fs.String("namespace", "", "kubernetes namespace (for pod logs)")
	fs.Parse(args)

	target := fs.Arg(0)

	if target == "" {
		return followSystemdLogs("bos", *follow)
	}

	// Systemd service (ends with .service or known service names)
	if strings.HasSuffix(target, ".service") ||
		target == "bos" || target == "containerd" || target == "kubelet" ||
		target == "etcd" {
		svc := target
		if !strings.HasSuffix(svc, ".service") {
			svc = svc + ".service"
		}
		return followSystemdLogs(svc, *follow)
	}

	// K8s pod log
	return followK8sPodLogs(target, *namespace, *follow)
}

func followSystemdLogs(service string, follow bool) int {
	args := []string{"-u", service, "--no-pager", "-n", "50"}
	if follow {
		args = []string{"-u", service, "-f"}
	}
	cmd := exec.Command("journalctl", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		// Fallback to /var/log/bos/
		if service == "bos.service" || service == "bos" {
			fmt.Fprintf(os.Stderr, "bosctl: journalctl failed, trying /var/log/bos/bos.log\n")
			tailCmd := exec.Command("tail", "-n", "50", "/var/log/bos/bos.log")
			tailCmd.Stdout = os.Stdout
			tailCmd.Stderr = os.Stderr
			if err := tailCmd.Run(); err != nil {
				fmt.Fprintf(os.Stderr, "bosctl: no logs available\n")
				return 1
			}
			return 0
		}
		return 1
	}
	return 0
}

func followK8sPodLogs(pod, namespace string, follow bool) int {
	args := []string{"logs", pod}
	if namespace != "" {
		args = append(args, "--namespace", namespace)
	}
	if follow {
		args = append(args, "--follow")
	}
	cmd := exec.Command("kubectl", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return 1
	}
	return 0
}
