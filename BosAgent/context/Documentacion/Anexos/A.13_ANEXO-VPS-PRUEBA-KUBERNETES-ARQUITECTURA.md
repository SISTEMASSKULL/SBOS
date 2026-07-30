# Anexo A.13 — Arquitectura K8s de la VPS de Prueba
## Hallazgos, NetworkPolicies, Acceso a Servicios y Guía de Reconstrucción Idempotente

**Versión:** 1.0.0 · **Fecha:** 2026-07-25 · **Autor:** bauth-developer — SBOS  
**Fortalece al motor:** ① IAM Installer · ⑥ Banco de Pruebas  
**Referencia:** [1.01 — IAM Installer](../1.01_MANUAL-IAM-INSTALLER.md) · [A.11 — Cadena de Instalación](A.11_ANEXO-CADENA-INSTALACION.md)

---

## 1. Resumen ejecutivo

La VPS de prueba es un **cluster Kubernetes de un solo nodo** gestionado con kubeadm.
**Todo SBOS corre sobre Kubernetes** — incluyendo los daemons (bauth, bos, etc.) cuando
estén desplegados. La excepción actual es que BOS aún está en desarrollo: hasta que BOS
esté operativo, los recursos que él gestionará se crean manualmente o con scripts de
bootstrap.

> **Regla de diseño:** todo lo que se configure en la VPS de prueba debe ser idempotente
> y reconstruible desde cero sin trabajo manual. Ningún paso de instalación requiere
> intervención humana más allá de ejecutar el script de bootstrap.

---

## 2. Especificaciones del cluster

| Parámetro | Valor |
|---|---|
| Nodo | `vmi3346550` |
| IP externa | `13.140.128.230` |
| OS | Ubuntu 26.04 LTS (GNU/Linux 7.0.0-14-generic) |
| K8s versión | v1.32.13 (kubeadm) |
| Rol del nodo | `control-plane` (single-node) |
| CNI | Calico |
| Runtime | containerd 2.2.4 |
| Linkerd | Instalado (namespace `linkerd`) |
| **KUBECONFIG** | `/etc/kubernetes/admin.conf` |

```bash
# Siempre usar esta variable de entorno para kubectl en el host
export KUBECONFIG=/etc/kubernetes/admin.conf
```

---

## 3. Namespaces y su propósito

| Namespace | Propósito | Pods principales |
|---|---|---|
| `kube-system` | Infraestructura K8s (calico, coredns, etcd, apiserver) | Sistema |
| `sbos-data` | Capa de datos: PostgreSQL, Redis, etcd, pgbouncer, MinIO | `postgresql-0`, `redis-0`, `pgbouncer`, `etcd-0` |
| `sbos-security` | Identidad y seguridad: Keycloak, Vault, bAuth (futuro) | `keycloak`, `vault-0` |
| `sbos-gateway` | Gateway API: Kong | `kong` |
| `sbos-erp` | ERP: Tryton | `tryton-0` |
| `sbos-comm` | Comunicación: Mattermost | `mattermost` |
| `sbos-notifier` | Notificaciones: Centrifugo, sbos-notifier | `sbos-notifier` |
| `sbos-monitoring` | Observabilidad: Prometheus, Grafana, Alloy, Alertmanager | Varios |
| `sbos-gateway` | Edge: Kong proxy | `kong` |
| `sbos-skull` | Servicios propios de SKULL | — |
| `sbos-system` | Servicios de sistema SBOS | — |
| `sbos-1234567890` | Tenant de prueba | — |
| `linkerd` | Service mesh Linkerd | Control plane |

---

## 4. Inventario de pods activos (estado 2026-07-25)

```
NAMESPACE         POD                           STATUS    IMAGEN
sbos-data         postgresql-0                  Running   postgres:18.4-alpine
sbos-data         pgbouncer-*                   Running   edoburu/pgbouncer:v1.24.1-p1
sbos-data         redis-0                       Running   redis:8.6.2-alpine
sbos-data         etcd-0                        Running   —
sbos-security     keycloak-*                    Running   — (Keycloak 25+)
sbos-security     vault-0                       Running   hashicorp/vault:2.0.1
sbos-gateway      kong-*                        Running   kong:3.9.0
sbos-erp          tryton-0                      Running   tryton/tryton:7.4
sbos-comm         mattermost                    Running   mattermost/mattermost-team-edition:10.6.0
sbos-notifier     sbos-notifier-*               Running   —
sbos-notifier     centrifugo                    CrashLoop centrifugo/centrifugo:v6
sbos-monitoring   prometheus, grafana, alloy…   Running   Varios
```

---

## 5. Servicios de acceso a PostgreSQL

### 5.1 Acceso desde dentro del cluster (correcto)

```
Host:     postgresql.sbos-data.svc.cluster.local
Puerto:   5432
Usuario:  postgres
Password: <ver secret postgresql-credentials en sbos-data>
BD:       SBOSDB
```

Servicio K8s:
```
sbos-data / postgresql   ClusterIP None   5432/TCP   (headless — DNS resuelve al pod directamente)
sbos-data / pgbouncer    ClusterIP 10.x   6432/TCP   (pooler — para conexiones de aplicaciones)
sbos-data / postgresql-external  NodePort  5432:30054/TCP  (acceso desde fuera del cluster)
```

### 5.2 Acceso desde el host (desarrollo temporal)

El puerto `15432` en el host es un **`kubectl port-forward` manual** que lleva activo
desde el 29 de junio de 2026 como proceso permanente:

```bash
kubectl port-forward -n sbos-data pod/postgresql-0 15432:5432 --address 0.0.0.0
```

⚠️ **Este port-forward es frágil.** Si el proceso muere (reinicio del nodo, OOM, etc.),
el acceso en `127.0.0.1:15432` desaparece hasta que alguien lo reinicia manualmente.
Esta es una solución de desarrollo: en producción, usar el NodePort `30054` o el servicio
headless desde dentro del cluster.

**Hasta que BOS gestione los port-forwards, incluir este proceso en un systemd service
en el host para que se reinicie automáticamente:**

```ini
# /etc/systemd/system/sbos-pg-portforward.service
[Unit]
Description=SBOS PostgreSQL port-forward (desarrollo)
After=network.target

[Service]
Type=simple
Environment=KUBECONFIG=/etc/kubernetes/admin.conf
ExecStart=/usr/bin/kubectl port-forward -n sbos-data pod/postgresql-0 15432:5432 --address 0.0.0.0
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
systemctl enable --now sbos-pg-portforward.service
```

### 5.3 Credenciales

```bash
# Leer el secret (desde el host con kubeconfig)
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl get secret postgresql-credentials -n sbos-data \
  -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
# → sbos_bootstrap_pass  (contraseña del superusuario postgres dentro del cluster)
```

> **Nota:** la contraseña vista desde el port-forward del host puede diferir si el pod
> fue inicializado con una contraseña diferente a la del secret. Verificar siempre
> con el secret de K8s como fuente de verdad.

---

## 6. Patrón de NetworkPolicies

Todos los namespaces SBOS siguen el mismo patrón:

```
default-deny-all     → deniega todo el tráfico entrante y saliente por defecto
allow-dns-egress     → permite salida al DNS (puerto 53 UDP/TCP al kube-dns)
allow-<svc>-access   → permite ingress al servicio específico desde namespaces autorizados
allow-<svc>-egress   → permite egress de pods específicos al servicio destino
```

### 6.1 NetworkPolicies activas en `sbos-data` (PostgreSQL)

| Policy | Selector | Efecto |
|---|---|---|
| `default-deny-all` | todos | Deniega todo |
| `allow-dns` | todos | Egress DNS |
| `allow-intra-data` | todos | Tráfico interno entre pods de sbos-data |
| `allow-postgresql-access` | `app=postgresql` | Ingress desde: `sbos-system`, `sbos-security`, `sbos-gateway`, `sbos-data`, `sbos-monitoring` |
| `allow-redis-access` | `app=redis` | Ingress desde namespaces autorizados |

> `allow-postgresql-access` ya autoriza todos los pods de `sbos-security` a conectar a PostgreSQL
> en el puerto 5432. Lo que se necesita es la política de **egress** en el namespace origen.

### 6.2 NetworkPolicies activas en `sbos-security`

| Policy | Selector | Efecto |
|---|---|---|
| `default-deny-all` | todos | Deniega todo |
| `allow-dns` | todos | Egress DNS |
| `allow-keycloak-access` | `app=keycloak` | Ingress a Keycloak |
| `allow-keycloak-egress-postgresql` | `app=keycloak` | Egress de Keycloak → sbos-data:5432 |
| `allow-bauth-egress-postgresql` | `app=bauth` | Egress de bAuth → sbos-data:5432 *(agregado 2026-07-25)* |

### 6.3 Patrón para agregar un nuevo daemon a sbos-security

Todo daemon nuevo en `sbos-security` que necesite acceder a PostgreSQL requiere:

```yaml
# egress en sbos-security para el nuevo daemon
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-<daemon>-egress-postgresql
  namespace: sbos-security
spec:
  podSelector:
    matchLabels:
      app: <daemon>
  policyTypes: [Egress]
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: sbos-data
    ports:
    - port: 5432
      protocol: TCP
  - ports:               # DNS siempre incluido
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
```

El ingress en `sbos-data` (`allow-postgresql-access`) **ya incluye `sbos-security`**,
por lo que NO es necesario modificarlo al agregar daemons nuevos en ese namespace.

---

## 7. Hallazgo crítico — pgbackrest: backups sin funcionar (35+ días)

### Estado

```
sbos-data / pgbackrest-backup-* → ErrImagePull / ImagePullBackOff
Imagen: pgbackrest/pgbackrest:2.54.0
```

35+ pods de backup acumulados en falla desde hace más de un mes. Los backups de
PostgreSQL **no están funcionando**. Esto significa que si `postgresql-0` falla,
**no hay backup para restaurar**.

### Causa probable

La imagen `pgbackrest/pgbackrest:2.54.0` no está en el cache local del nodo y no
puede descargarse (rate limit de Docker Hub, red, o imagen no existente en esa versión).

### Acción requerida (HITL)

1. Verificar si la imagen existe: `docker pull pgbackrest/pgbackrest:2.54.0`
2. Si falla por rate limit: configurar un registry mirror o usar una imagen alternativa
3. Si la imagen no existe: actualizar a la versión disponible más cercana
4. Limpiar los pods fallidos: `kubectl delete pods -n sbos-data -l job-name --field-selector=status.phase=Failed`
5. Configurar un registry de imágenes local (Harbor o similar) para evitar dependencia de Docker Hub

> ⚠️ **BLOQUEANTE para producción.** Sin backups, cualquier fallo de disco es pérdida total
> de datos. Resolver antes de usar la VPS para pruebas con datos reales.

---

## 8. Reconstrucción idempotente — guía

Todo lo documentado en este anexo debe poder reconstruirse con el siguiente orden.
BOS lo hará automáticamente cuando esté desplegado; hasta entonces, estos son los
pasos manuales:

### 8.1 Pre-requisitos del nodo

```bash
# kubeadm, kubelet, kubectl ya instalados (parte del bootstrap de la VPS)
export KUBECONFIG=/etc/kubernetes/admin.conf
```

### 8.2 Orden de aplicación de namespaces y NetworkPolicies

```bash
# Aplicar en este orden — las dependencias van de sbos-data hacia afuera
kubectl apply -f manifests/namespaces.yaml
kubectl apply -f manifests/networkpolicies/sbos-data.yaml
kubectl apply -f manifests/networkpolicies/sbos-security.yaml
kubectl apply -f manifests/networkpolicies/sbos-gateway.yaml
# ... resto de namespaces
```

### 8.3 Port-forward estable (mientras BOS no gestiona esto)

```bash
# Aplicar el systemd service del port-forward (sección 5.2)
systemctl enable --now sbos-pg-portforward.service
```

### 8.4 Verificación post-instalación

```bash
# Cluster healthy
kubectl get nodes
kubectl get pods -A | grep -v Running | grep -v Completed

# PostgreSQL accesible desde dentro del cluster
kubectl run pg-test --image=postgres:18.4-alpine -n sbos-data --rm \
  --restart=Never --env="PGPASSWORD=sbos_bootstrap_pass" \
  --command -- psql -h postgresql.sbos-data.svc.cluster.local \
  -U postgres -d SBOSDB -t -c 'SELECT current_database();'
```

---

## 9. Imágenes pre-cacheadas en el nodo (2026-07-25)

Imágenes ya disponibles sin necesidad de pull:

```
docker.io/library/postgres:18.4-alpine
docker.io/library/redis:8.6.2-alpine
docker.io/library/kong:3.9.0
docker.io/edoburu/pgbouncer:v1.24.1-p1
docker.io/hashicorp/vault:2.0.1
docker.io/grafana/grafana:12.0.1
docker.io/grafana/alloy:v1.8.3
docker.io/prom/prometheus:v3.4.0
docker.io/prom/alertmanager:v0.28.1
docker.io/mattermost/mattermost-team-edition:10.6.0
docker.io/tryton/tryton:7.4
docker.io/library/busybox:stable
docker.io/library/python:3.14
docker.io/hyperledger/besu:24.12.0 (Podman, no K8s)
```

> En una instalación nueva, estas imágenes deben pre-cachearse o servirse desde
> un registry local para garantizar instalación sin fricción sin depender de Docker Hub.

---

*SKULL · SBOS · BosAgent · 2026-07-25*
