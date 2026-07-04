// Package demo — demo.go: datos y simulador del modo instalación sin daemon.
// Extraído de cmd/bosctl/install_ui.go en F3.5 (BOS-REPAIR).
package demo

import (
	"time"

	tuimodel "bos/internal/tui/model"
)

// DemoSubComponents define sub-componentes realistas por ficha para la simulación.
// Clave: ID de ficha. Valor: slice de pasos (name + desc).
var DemoSubComponents = map[string][]struct{ Name, Desc string }{
	"sbos-bootstrap-os": {
		{"instalar_dependencias", "apt: curl, wget, gnupg, ca-certificates, apt-transport-https"},
		{"configurar_kernel", "sysctl: net.ipv4.ip_forward, bridge-nf-call-iptables"},
		{"deshabilitar_swap", "swapoff -a, comentar /etc/fstab"},
		{"configurar_firewall", "ufw: puertos 6443/tcp, 10250/tcp, 2379-2380/tcp"},
		{"verificar_sistema", "Comprobando kernel ≥ 5.15, cgroups v2, containerd"},
	},
	"sbos-bootstrap-k8s": {
		{"instalar_kubeadm", "Instalando kubeadm v1.32 + kubectl + kubelet"},
		{"configurar_kubeconfig", "Configurando ~/.kube/config y KUBECONFIG"},
		{"esperar_nodos", "kubectl wait node --for=condition=Ready"},
		{"instalar_helm", "Descargando helm v3.17 (15MB)"},
		{"verificar_cluster", "kubectl cluster-info, get nodes -o wide"},
	},
	"sbos-bootstrap-cni": {
		{"aplicar_calico_operator", "kubectl apply -f tigera-operator.yaml (Calico 3.32.0)"},
		{"configurar_ippool", "CalicoNetwork: CIDR 10.244.0.0/16, IPIP disabled"},
		{"esperar_calico_pods", "kubectl wait pod -n calico-system --for=condition=Ready"},
		{"verificar_cni", "Comprobando interfaces tunl0, cali*, eth0"},
	},
	"postgresql": {
		{"crear_namespace", "kubectl create namespace postgresql"},
		{"crear_pvc", "PersistentVolumeClaim: 50Gi, StorageClass: local-path"},
		{"desplegar_statefulset", "StatefulSet postgresql-0 — imagen bitnami/postgresql:18.4"},
		{"inicializar_bd", "initdb: locale=es_BO.UTF-8, encoding=UTF8"},
		{"configurar_replicacion", "postgresql.conf: wal_level=logical, max_wal_senders=10"},
		{"instalar_extensiones", "CREATE EXTENSION: pg_trgm, uuid-ossp, pgcrypto, unaccent"},
		{"verificar_salud", "pg_isready -h localhost -p 5432"},
	},
	"redis": {
		{"crear_namespace", "kubectl create namespace redis"},
		{"crear_pvc", "PersistentVolumeClaim: 10Gi, StorageClass: local-path"},
		{"desplegar_statefulset", "StatefulSet redis-0 — imagen bitnami/redis:8.6.2"},
		{"configurar_streams", "redis.conf: maxmemory-policy=noeviction, AOF enabled"},
		{"verificar_ping", "redis-cli PING → PONG"},
	},
	"vault": {
		{"desplegar_vault", "StatefulSet vault-0 — imagen hashicorp/vault:2.0.1"},
		{"inicializar_vault", "vault operator init -key-shares=5 -key-threshold=3"},
		{"unseal_vault", "vault operator unseal (3 de 5 llaves)"},
		{"configurar_pki", "vault secrets enable pki, generar CA raíz del SBOS"},
		{"configurar_kv", "vault secrets enable -path=sbos kv-v2"},
	},
	"keycloak": {
		{"crear_bd_keycloak", "CREATE DATABASE keycloak OWNER keycloak"},
		{"desplegar_keycloak", "Deployment keycloak — imagen quay.io/keycloak/keycloak:26.6.2"},
		{"configurar_realm", "POST /admin/realms: sbos-realm, BO locale"},
		{"configurar_clientes", "Registrar clientes: bosctl, core-ui, kong"},
		{"instalar_spis", "Deploy bAuth Java SPIs (5 SPIs): PrivilegeEngine, BitMask64"},
		{"verificar_oidc", "GET /.well-known/openid-configuration"},
	},
}

// DemoLogLine retorna líneas de log realistas para un paso específico de una ficha.
func DemoLogLine(ficha, step string) []string {
	key := ficha + "." + step
	switch key {
	case "sbos-bootstrap-k8s.instalar_kubeadm":
		return []string{
			"[INFO] Instalando kubeadm v1.32, kubectl y kubelet...",
			"[INFO] apt-get install -y kubeadm=1.32.* kubelet=1.32.* kubectl=1.32.*",
			"[INFO] systemctl enable kubelet",
			"[INFO] kubeadm init --config kubeadm-config.yaml",
			"[INFO] Control plane inicializado correctamente",
			"[INFO] kubectl apply -f calico-v3.32.0.yaml",
			"[INFO] Cluster K8s listo",
		}
	case "postgresql.desplegar_statefulset":
		return []string{
			"[INFO] kubectl apply -f postgresql-statefulset.yaml",
			"[INFO] statefulset.apps/postgresql created",
			"[INFO] service/postgresql created",
			"[INFO] Esperando pod postgresql-0 Running...",
			"[INFO] pod/postgresql-0 0/1 ContainerCreating",
			"[INFO] pod/postgresql-0 1/1 Running",
		}
	case "postgresql.instalar_extensiones":
		return []string{
			"[INFO] CREATE EXTENSION pg_trgm",
			"[INFO] CREATE EXTENSION uuid-ossp",
			"[INFO] CREATE EXTENSION pgcrypto",
			"[INFO] CREATE EXTENSION unaccent",
			"[INFO] Extensiones instaladas: 4",
		}
	case "redis.desplegar_statefulset":
		return []string{
			"[INFO] kubectl apply -f redis-statefulset.yaml",
			"[INFO] statefulset.apps/redis created",
			"[INFO] Esperando pod redis-0 Running...",
			"[INFO] pod/redis-0 1/1 Running",
		}
	}
	return []string{"[INFO] " + ficha + ": ejecutando " + step + "..."}
}

// RunDemo envía eventos sintéticos a ch simulando una instalación completa.
// phases describe el DAG de instalación (N0–N6). ch debe tener buffer suficiente.
// La goroutine cierra ch al terminar.
func RunDemo(ch chan<- tuimodel.WsEventMsg, phases []tuimodel.InstallPhase) {
	pasosFallback := []struct{ Name, Desc string }{
		{"check_prerequisites", "Verificando requisitos del sistema"},
		{"pull_image", "Descargando imagen del contenedor"},
		{"deploy_manifest", "Aplicando manifiestos Kubernetes"},
		{"wait_ready", "Esperando que el pod esté listo"},
		{"verify_health", "Verificando health check"},
	}

	total := 0
	for _, ph := range phases {
		total += len(ph.Fichas)
	}
	ch <- tuimodel.WsEventMsg{EvType: "response", Total: total}
	time.Sleep(400 * time.Millisecond)

	for _, ph := range phases {
		for _, ficha := range ph.Fichas {
			ch <- tuimodel.WsEventMsg{EvType: tuimodel.EvSagaStart, Ficha: ficha}
			time.Sleep(250 * time.Millisecond)

			pasos, ok := DemoSubComponents[ficha]
			if !ok {
				pasos = pasosFallback
			}

			for _, paso := range pasos {
				ch <- tuimodel.WsEventMsg{EvType: tuimodel.EvStepStart, Ficha: ficha, Step: paso.Name, Msg: paso.Desc}
				for _, logLine := range DemoLogLine(ficha, paso.Name) {
					time.Sleep(120 * time.Millisecond)
					ch <- tuimodel.WsEventMsg{EvType: tuimodel.EvFichaLog, Ficha: ficha, Msg: logLine}
				}
				time.Sleep(200 * time.Millisecond)
				ch <- tuimodel.WsEventMsg{EvType: tuimodel.EvStepOK, Ficha: ficha, Step: paso.Name}
				time.Sleep(100 * time.Millisecond)
			}

			ch <- tuimodel.WsEventMsg{EvType: tuimodel.EvSagaOK, Ficha: ficha}
			time.Sleep(200 * time.Millisecond)
		}
	}

	time.Sleep(600 * time.Millisecond)
	ch <- tuimodel.WsEventMsg{EvType: "bootstrap_complete"}
	close(ch)
}
