# SBOS-029 — Guía de Portabilidad y Multi-Entorno de SBOS
## Soporte multi-distribución, estrategia de entornos y portabilidad de daemons

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-029
**Versión:** 1.0
**Estado:** ACTIVO
**Documento nuevo** — complementa SBOS-004 (K8s), SBOS-005 (SBOS IAM Installer), SBOS-021 (Onboarding)
**Clasificación:** Especificación Técnica — Portabilidad e Infraestructura

---

## Índice

1. [Matriz de soporte de sistemas operativos](#1-matriz-de-soporte)
2. [Diferencias Ubuntu 24.04 vs Debian 12](#2-diferencias-ubuntu-vs-debian)
3. [Guía de instalación en Debian 12](#3-guia-de-instalacion-debian-12)
4. [Estrategia de multi-entorno dev / staging / prod](#4-estrategia-multi-entorno)
5. [Portabilidad de los daemons soberanos](#5-portabilidad-daemons-soberanos)
6. [Roadmap de portabilidad ARM64](#6-roadmap-arm64)

---

## 1. Matriz de Soporte de Sistemas Operativos

### 1.1 Definición de tiers

| Tier | Definición |
|---|---|
| **Tier 1 — Producción validada** | Totalmente soportado. CI/CD ejecuta contra esta distribución. Los runbooks de SBOS-024 y SBOS-026 aplican sin modificaciones. SKULL garantiza soporte. |
| **Tier 2 — Producción con guía** | Soportado en producción con ajustes documentados en este documento. CI/CD valida contra esta distribución como pipeline secundario. SKULL provee soporte con aviso previo de 24h. |
| **Tier 3 — Desarrollo únicamente** | Funciona para desarrollo local y pruebas de fichas y reglas YAML. **No usar en producción.** Sin garantía de soporte de SKULL. |
| **En evaluación** | Se está midiendo la factibilidad. Sin compromiso de soporte. |

### 1.2 Tabla de soporte por distribución

| Distribución | Versión mínima | Tier | Arquitectura | Estado |
|---|---|---|---|---|
| Ubuntu | 24.04 LTS (Noble Numbat) | **Tier 1** | x86_64 | ✅ Producción validada |
| Ubuntu | 22.04 LTS (Jammy) | Tier 2 | x86_64 | ✅ Con guía de ajustes menores |
| Debian | 12 (Bookworm) | **Tier 2** | x86_64 | ✅ Con guía en §3 |
| Fedora | 38+ | Tier 3 | x86_64 | 🔵 Desarrollo únicamente |
| CentOS Stream | 9 | En evaluación | x86_64 | 🟡 En evaluación — Q3 2026 |
| Ubuntu | 24.04 LTS | En evaluación | ARM64 (aarch64) | 🟡 En evaluación — ver §6 |

### 1.3 Restricciones aplicables a todos los tiers

Independientemente de la distribución, los siguientes requisitos son invariables:

- **Kernel Linux ≥ 5.15** — requerido por eBPF (Calico NetworkPolicies) y cgroup v2 (kubeadm)
- **systemd ≥ 245** — requerido por los daemons soberanos (SBOS Data Kernel, SBOS Data Integration, SBOS AI Tools)
- **glibc ≥ 2.35** — requerido por los binarios Rust de los daemons soberanos
- **Acceso root** durante la instalación — el SBOS IAM Installer requiere privilegios de root para la Fase 0 Bootstrap
- **Conectividad de salida** hacia el Release Server de SKULL (Ed25519 verificado) — `release.skull.systems:443`

---

## 2. Diferencias Ubuntu 24.04 vs Debian 12

### 2.1 Tabla completa de diferencias

| Componente | Ubuntu 24.04 | Debian 12 | Acción requerida |
|---|---|---|---|
| **Gestor de paquetes** | `apt` con PPAs | `apt` sin PPAs (usar backports) | Ajustar sources.list — ver §3.1 |
| **Nombre paquete CRI-O** | `cri-o` (PPA Kubernetes) | `cri-o` (repositorio Deb Sig) | Diferente repositorio — ver §3.2 |
| **Nombre paquete kubeadm** | `kubeadm` (PPA Kubernetes) | `kubeadm` (repositorio Deb Sig) | Diferente GPG key y repo — ver §3.2 |
| **Firewall por defecto** | `ufw` (activo por defecto) | `iptables` + `nftables` sin gestor de alto nivel por defecto | Instalar `ufw` en Debian o ajustar scripts — ver §3.3 |
| **Snap** | Disponible, algunos paquetes lo usan | **No disponible** — Debian no incluye snapd | Verificar fichas — ninguna debe requerir snap — ver §3.4 |
| **Network Manager** | NetworkManager (GUI, headless opcional) | networking (interfaz `/etc/network/interfaces`) | Ajustar configuración de red para MetalLB — ver §3.5 |
| **Nombre interfaz de red** | `enp3s0`, `ens3` (predictable) | `eth0`, `enp3s0` (variable) | Parametrizar nombre de interfaz en SBOS IAM Installer config |
| **Python** | Python 3.12 por defecto | Python 3.11 por defecto | Sin impacto — SBOS IAM Installer soporta Python 3.11+ |
| **Rust toolchain** | Via rustup (misma instalación) | Via rustup (misma instalación) | Sin impacto — rustup es agnóstico a la distro |
| **Nombre servicio PostgreSQL** | `postgresql` | `postgresql` | Sin impacto |
| **Ruta systemd** | `/etc/systemd/system/` | `/etc/systemd/system/` | Sin impacto |
| **Usuario postgres** | `postgres` | `postgres` | Sin impacto |
| **cgroup v2** | Habilitado por defecto | Requiere habilitación manual | Ver §3.6 |
| **AppArmor** | Habilitado por defecto | Disponible pero no habilitado por defecto | Sin impacto para K8s — Kyverno es el enforcement principal en SBOS |

### 2.2 Componentes idénticos en ambas distribuciones

Los siguientes componentes no requieren ajuste alguno al pasar de Ubuntu a Debian:

- Binarios Rust: SBOS Data Kernel (bkernel) y SBOS Data Integration (biedata) — compilados para `x86_64-unknown-linux-gnu` con glibc estática mínima
- Binarios Go: SBOS AI Tools (bcompass), SBOS Data RAG (bsearch), SBOS Auth Enforce (bauth), SBOS Nexus Host (bhnexus) — compilados con CGO_ENABLED=0 go build (estático, portable)
- Configuración de Kubernetes (manifests YAML, Helm charts, Kustomize)
- Imágenes de contenedores (OCI-compatible, agnósticas a la distro del host)
- Configuración de PostgreSQL 17 + Patroni
- Reglas YAML del SBOS Data Kernel (`/etc/bos/blibs/bkernel/rules/`)
- Fichas del stack (manifest.yml + yaml_engine.yml) — son contratos de K8s, no dependen de la distro del host
- Configuración de Kong, Keycloak, Redis, MinIO

---

## 3. Guía de Instalación en Debian 12

### 3.1 Preparación del sistema

```bash
# PASO 1: Actualizar el sistema
sudo apt update && sudo apt upgrade -y

# PASO 2: Instalar dependencias base
sudo apt install -y \
  curl wget gnupg2 ca-certificates \
  apt-transport-https software-properties-common \
  lsb-release git make \
  python3 python3-pip python3-venv \
  ufw \
  jq \
  socat conntrack

# PASO 3: Configurar backports de Debian 12 (para paquetes más recientes)
echo "deb http://deb.debian.org/debian bookworm-backports main contrib non-free" \
  | sudo tee /etc/apt/sources.list.d/backports.list
sudo apt update
```

### 3.2 Instalación de CRI-O y kubeadm en Debian 12

**Diferencia crítica respecto a Ubuntu:** Debian no tiene PPAs. Los repositorios de Kubernetes se configuran vía el repositorio oficial del proyecto Kubernetes.

```bash
# Configurar repositorio de Kubernetes (válido para Ubuntu y Debian)
KUBERNETES_VERSION="v1.30"
curl -fsSL https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Instalar kubeadm, kubelet, kubectl
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Configurar repositorio de CRI-O para Debian
CRIO_VERSION="v1.30"
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/stable:/${CRIO_VERSION}/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] \
  https://pkgs.k8s.io/addons:/cri-o:/stable:/${CRIO_VERSION}/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/cri-o.list

sudo apt update
sudo apt install -y cri-o
sudo systemctl enable --now crio
```

### 3.3 Configuración de firewall en Debian 12

Ubuntu tiene `ufw` activo por defecto. Debian usa `iptables`/`nftables` directamente. El SBOS IAM Installer de SBOS asume `ufw` en su fase de Bootstrap.

```bash
# Instalar y habilitar ufw en Debian (hace el comportamiento idéntico a Ubuntu)
sudo apt install -y ufw
sudo ufw --force enable

# El SBOS IAM Installer continuará con los mismos comandos ufw que en Ubuntu
# No se requieren cambios en los scripts del SBOS IAM Installer

# Verificar que iptables legacy está disponible (requerido por algunas versiones de kubeadm)
sudo apt install -y iptables
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
```

### 3.4 Verificación de ausencia de snap en fichas

Debian no incluye snapd. Antes de instalar SBOS en Debian, verificar que ninguna ficha del stack require snap:

```bash
# Verificar que ningún script de las fichas referencia snap
grep -r "snap install" /path/to/fichas/ && echo "ERROR: fichas con snap encontradas" || echo "OK: ninguna ficha usa snap"

# En SBOS estándar, este comando debe devolver OK.
# Si alguna ficha custom del cliente usa snap, debe ser adaptada para Debian.
```

### 3.5 Configuración de red para MetalLB en Debian 12

MetalLB en modo L2 requiere que la interfaz de red del host esté correctamente identificada. En Debian, el nombre puede variar.

```bash
# Identificar el nombre de la interfaz de red principal
ip route show default | awk '{print $5}' | head -1
# Ejemplo de salida: eth0 (o enp3s0 dependiendo del hardware)

# Configurar en el archivo de configuración del SBOS IAM Installer
# /etc/sbos/config.yaml:
network:
  primary_interface: eth0    # Ajustar según output del comando anterior
  metallb_pool: "192.168.1.200-192.168.1.250"  # Ajustar según red del cliente
```

### 3.6 Habilitación de cgroup v2 en Debian 12

Debian 12 no habilita cgroup v2 por defecto en todos los casos. Kubeadm y CRI-O lo requieren.

```bash
# Verificar si cgroup v2 está activo
mount | grep cgroup2
# Si no aparece ninguna línea, cgroup v2 no está activo

# Habilitar cgroup v2 via GRUB
sudo sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1"/' \
  /etc/default/grub
sudo update-grub
sudo reboot

# Verificar post-reboot
mount | grep cgroup2
# Debe aparecer: cgroup2 on /sys/fs/cgroup type cgroup2 (...)
```

### 3.7 Checklist de validación post-instalación en Debian 12

Ejecutar después de completar la instalación con el SBOS IAM Installer:

```bash
# CHECK 1: CRI-O activo
systemctl is-active crio && echo "✅ CRI-O activo" || echo "❌ CRI-O inactivo"

# CHECK 2: Kubernetes control plane
kubectl get nodes && echo "✅ K8s nodes OK" || echo "❌ K8s nodes ERROR"

# CHECK 3: Daemons soberanos activos
for daemon in bkernel biedata bcompass; do
  systemctl is-active $daemon && echo "✅ $daemon activo" || echo "❌ $daemon inactivo"
done

# CHECK 4: PostgreSQL (via Patroni)
patronictl -c /etc/patroni/config.yml list && echo "✅ Patroni OK" || echo "❌ Patroni ERROR"

# CHECK 5: Keycloak responde
curl -s -o /dev/null -w "%{http_code}" https://keycloak.$(hostname -f)/health/ready
# Esperado: 200

# CHECK 6: Kong Gateway
curl -s http://localhost:8001/status | jq '.database.reachable'
# Esperado: true

# CHECK 7: SBOS Data Kernel procesando eventos
journalctl -u bkernel --since "5 minutes ago" | grep "checkpoint" | tail -1
# Debe mostrar un checkpoint reciente
```

### 3.8 Errores conocidos en Debian 12 y soluciones

| Error | Causa | Solución |
|---|---|---|
| `kubeadm init` falla con "cgroup v2 not detected" | cgroup v2 no habilitado | Seguir §3.6 |
| MetalLB no asigna IPs | Nombre de interfaz incorrecto | Ajustar `primary_interface` en config.yaml — ver §3.5 |
| `ufw` no encontrado en Fase 0 Bootstrap | ufw no instalado por defecto en Debian | Instalar `ufw` antes de ejecutar el SBOS IAM Installer — ver §3.3 |
| `snap: command not found` en alguna ficha | Ficha custom usa snap | La ficha debe ser adaptada para usar apt — reportar al equipo de la ficha |
| Errores de IPTables legacy | Debian usa nftables por defecto | Seguir ajuste de §3.3 (iptables-legacy) |
| Daemon SBOS Data Kernel no inicia: "GLIBC_2.38 not found" | glibc demasiado antigua | Verificar Debian 12 (glibc 2.36) — se requiere compilar con target musl para Debian <12 |

---

## 4. Estrategia de Multi-Entorno dev / staging / prod

### 4.1 Definición formal de entornos en SBOS

| Entorno | Propósito | Datos | Seguridad | Instalación |
|---|---|---|---|---|
| **dev** | Desarrollo local — una sola persona | Datos sintéticos generados por `make seed` | Sin TLS en algunos casos (opcional) | Nodo único mínimo — 8 GB RAM suficiente |
| **staging** | Integración y pruebas de regresión — equipo | Datos sintéticos representativos (copia anonimizada de producción) | TLS activo, Keycloak con realm `staging` | Nodo único que replica la topología de producción |
| **prod** | Operación real con datos del cliente | Datos reales del cliente | Configuración Zero Trust completa, WAF activo, mTLS | Puede ser nodo único o multi-nodo según cliente |

### 4.2 Qué cambia entre entornos en SBOS

**Variables de configuración por entorno:**

```yaml
# /etc/sbos/config.yaml — fragmento de configuración por entorno
environment: prod   # dev | staging | prod

keycloak:
  realm_name: "bos-${CLIENT_SLUG}"     # prod: "bos-acme-corp", staging: "bos-staging", dev: "bos-dev"
  admin_password: "${VAULT_KC_ADMIN}"   # prod: desde Vault, staging: desde Vault, dev: puede ser local

postgresql:
  host: "localhost"                     # dev: localhost, staging/prod: S01 dataserver
  pool_max_connections: 50              # dev: 10, staging: 25, prod: 50+

bkernel:
  log_level: "info"                     # dev: debug, staging: info, prod: warn
  batch_size: 1000                      # dev: 100, staging: 500, prod: 1000

kong:
  rate_limit_per_second: 100            # dev: sin límite, staging: 50, prod: 100+
  waf_mode: "blocking"                  # dev: detection-only, staging: blocking, prod: blocking
```

**Diferencias en Kubernetes por entorno:**

```yaml
# ConfigMap por entorno — aplicado via Kustomize overlays

# overlays/dev/kustomization.yaml
patches:
  - patch: |-
      - op: replace
        path: /spec/replicas
        value: 1
    target:
      kind: Deployment
      # En dev: todas las apps tienen 1 réplica
  - patch: |-
      - op: replace
        path: /spec/resources/requests/memory
        value: "128Mi"   # Recursos mínimos en dev para caber en portátil

# overlays/staging/kustomization.yaml  
patches:
  - patch: |-
      - op: replace
        path: /spec/replicas
        value: 1         # Igual que prod en topología pero menor tamaño de instancia

# overlays/prod/kustomization.yaml
# Sin patches — usa los valores del manifest.yml de cada ficha
```

### 4.3 Keycloak realms por entorno

Cada entorno tiene su propio realm de Keycloak, **completamente aislado**:

| Entorno | Realm Keycloak | Usuarios | Datos de sesión |
|---|---|---|---|
| dev | `bos-dev` | Usuarios de prueba creados con `make seed-users` | Se pueden borrar en cualquier momento |
| staging | `bos-staging` | Usuarios de prueba equivalentes a los de producción | Se regeneran en cada ciclo de staging |
| prod | `bos-{client-slug}` | Usuarios reales del cliente | Datos protegidos — backup según SBOS-026 |

### 4.4 Seeding de datos de prueba para dev y staging

```bash
# Generar datos sintéticos para dev/staging
make seed ENV=dev     # Genera ~50 empleados, ~200 clientes, ~1000 facturas sintéticas
make seed ENV=staging # Genera ~500 empleados, ~2000 clientes — más representativo

# El comando make seed:
# 1. Ejecuta scripts Python de seeders por bounded context
# 2. Inserta en las BDs de aplicaciones (Tryton, OrangeHRM, Saleor)
# 3. El SBOS Data Kernel propaga los cambios via WAL automáticamente
# 4. NO toca keycloak_db ni bkernel_db (se generan automáticamente)
```

### 4.5 Promoción de configuración entre entornos

```
dev → staging → prod

Qué se puede promover:
✅ Fichas nuevas (manifest.yml + yaml_engine.yml)
✅ Reglas YAML del SBOS Data Kernel (/etc/bos/blibs/bkernel/rules/)
✅ Prompts de SBOS AI Tools (/etc/bos/blibs/bcompass/prompts/)
✅ Configuración de Kong (rutas, plugins)

Qué NO se promueve (siempre es específico del entorno):
❌ Datos (nunca se llevan datos de prod a staging/dev)
❌ Secretos de Vault (cada entorno tiene su propio Vault)
❌ Keycloak realm data
❌ Certificados TLS (cada entorno tiene los suyos)
```

---

## 5. Portabilidad de los Daemons Soberanos

### 5.1 Arquitectura de compilación actual

Los daemons Rust del SBOS — SBOS Data Kernel (bkernel) y SBOS Data Integration (biedata) — son binarios compilados con el target `x86_64-unknown-linux-gnu`. Este target usa glibc dinámica — los binarios requieren `glibc ≥ 2.35` en el sistema del cliente.

```toml
# Cargo.toml de SBOS Data Kernel — configuración de compilación
[profile.release]
opt-level = 3
lto = true
codegen-units = 1
strip = true   # Elimina símbolos de debug del binario final

# El binario resultante:
# - Tamaño: ~12 MB (SBOS Data Kernel), ~8 MB (SBOS Data Integration), ~7 MB (SBOS AI Tools)
# - Dependencias dinámicas: libm, libc, libpthread (glibc standard)
# - Sin dependencias de libssl (usa rustls — TLS en Rust puro)
```

### 5.2 Verificación de compatibilidad de glibc

```bash
# En el servidor destino, verificar la versión de glibc
ldd --version | head -1
# Ubuntu 24.04: ldd (Ubuntu GLIBC 2.39-0ubuntu8.3) 2.39  ✅
# Debian 12:    ldd (Debian GLIBC 2.36-9+deb12u9) 2.36   ✅
# Ubuntu 22.04: ldd (Ubuntu GLIBC 2.35-0ubuntu3.8) 2.35  ✅

# Verificar que el binario de SBOS Data Kernel es compatible
ldd /usr/local/bin/bkernel | grep "not found"
# Si hay output → incompatibilidad de glibc → usar build musl (ver §5.3)
```

### 5.3 Compilación con musl para máxima portabilidad

Para distribuciones con glibc más antigua (o para generar binarios completamente estáticos), compilar con el target `x86_64-unknown-linux-musl`:

```bash
# Añadir target musl al toolchain de Rust
rustup target add x86_64-unknown-linux-musl

# En Ubuntu/Debian, instalar el linker de musl
sudo apt install musl-tools

# Compilar SBOS Data Kernel con musl (binario 100% estático, sin dependencias de glibc)
cargo build --release --target x86_64-unknown-linux-musl

# El binario resultante:
# - Tamaño: ~18 MB (mayor porque incluye libc estáticamente)
# - Dependencias dinámicas: NINGUNA
# - Compatible con cualquier distribución Linux con kernel ≥ 4.19
```

El pipeline CI/CD de GitLab (S14 opsserver) produce **dos artefactos** por daemon en cada release:

| Artefacto | Target | Distribuciones soportadas |
|---|---|---|
| `bkernel-x86_64-gnu` | `x86_64-unknown-linux-gnu` | Ubuntu 22.04+, Debian 12+, cualquier distro con glibc ≥ 2.35 |
| `bkernel-x86_64-musl` | `x86_64-unknown-linux-musl` | **Cualquier** distribución Linux x86_64 con kernel ≥ 4.19 |

El SBOS IAM Installer selecciona automáticamente el artefacto correcto durante la instalación:

```bash
# Lógica de selección en el SBOS IAM Installer (Fase 7 — despliegue de daemons)
GLIBC_VERSION=$(ldd --version | awk 'NR==1{print $NF}')
MIN_VERSION="2.35"

if [ "$(printf '%s\n' "$MIN_VERSION" "$GLIBC_VERSION" | sort -V | head -1)" = "$MIN_VERSION" ]; then
  DAEMON_VARIANT="gnu"   # glibc ≥ 2.35 — usar binario gnu (más pequeño)
else
  DAEMON_VARIANT="musl"  # glibc < 2.35 — usar binario musl (estático)
fi

wget "https://release.skull.systems/daemons/bkernel-${VERSION}-x86_64-${DAEMON_VARIANT}" \
  -O /usr/local/bin/bkernel
```

---

## 6. Roadmap de Portabilidad ARM64

### 6.1 Estado actual

Los daemons soberanos **no compilan actualmente para ARM64**. Los binarios son exclusivamente x86_64. Los contenedores K8s del stack (PostgreSQL, Keycloak, Kong, etc.) tienen imágenes ARM64 disponibles en sus repositorios oficiales.

El bloqueador principal para ARM64 en SBOS es: **los daemons soberanos**.

### 6.2 Casos de uso que justifican ARM64

| Caso de uso | Justificación |
|---|---|
| Raspberry Pi 5 / cluster ARM para dev | Costo de hardware bajo para entornos de desarrollo |
| Servidores cloud ARM (AWS Graviton, Oracle Ampere) | Hasta 40% más económico por vCPU vs x86_64 en algunos cloud providers |
| Appliance SBOS embebido | Hardware ARM dedicado para clientes pequeños |

### 6.3 Plan de implementación ARM64

**Fase 1 — Q3 2026: Validación técnica**
- Añadir target `aarch64-unknown-linux-musl` al pipeline CI/CD
- Compilar los daemons soberanos y ejecutar el test suite en hardware ARM (GitHub Actions ARM runner)
- Identificar dependencias específicas de x86_64 (intrínsecos SIMD, etc.)
- Criterio de éxito: todos los tests del SBOS Data Kernel pasan en ARM64

**Fase 2 — Q4 2026: Tier 3 ARM64**
- Publicar binarios ARM64 en el Release Server junto a los x86_64
- El SBOS IAM Installer detecta la arquitectura y descarga el binario correcto:
  ```bash
  ARCH=$(uname -m)   # x86_64 o aarch64
  wget "https://release.skull.systems/daemons/bkernel-${VERSION}-${ARCH}-musl"
  ```
- Declarar ARM64 como Tier 3 (desarrollo únicamente) hasta validación en producción

**Fase 3 — H1 2027: Tier 2 ARM64 producción**
- Validar en cliente piloto con hardware ARM en producción
- Completar la guía de instalación ARM64 equivalente a §3
- Declarar ARM64 como Tier 2 producción

### 6.4 Limitaciones conocidas para ARM64

| Componente | Limitación | Plan de resolución |
|---|---|---|
| SBOS Data Kernel — Rule Engine | Usa operaciones de bit que pueden tener comportamiento diferente en ARM64 big-endian | PostgreSQL WAL es little-endian — sin impacto en práctica; validar con tests |
| SBOS Data Integration — Cajas SIAT/AFIP | Las cajas `.so` compiladas para x86_64 no son compatibles con ARM64 | Recompilar cajas para cada arquitectura objetivo |
| PostgreSQL | Patroni + PostgreSQL 17 tienen imágenes ARM64 oficiales | Sin acción — ya soportado |
| Keycloak | Imagen oficial multi-arch | Sin acción — ya soportado |

---

## 7. Referencias Cruzadas

- **SBOS-004** — Arquitectura Kubernetes (configuración base que este documento extiende)
- **SBOS-005** — SBOS IAM Installer (los 4 archivos maestros Bash que requieren ajustes para Debian)
- **SBOS-021** — Onboarding (distribuciones soportadas para desarrollo — §2.1)
- **SBOS-016** — Servidores lógicos (topología de servidores que aplica a todos los entornos)
- **SBOS-024** — Operaciones (runbooks válidos para Tier 1 sin modificaciones; Tier 2 con ajustes de §3)

---

## 8. Registro de Cambios

| Versión | Fecha | Autor | Descripción |
|---|---|---|---|
| 1.0 | Marzo 2026 | SKULL DevOps Team | Documento inicial — matriz de soporte, guía Debian 12, multi-entorno dev/staging/prod, portabilidad daemons Rust, roadmap ARM64 |

---

*SKULL · SBOS · SBOS-029 · v1.0 · Marzo 2026*
*Complementa: SBOS-004 (K8s), SBOS-005 (SBOS IAM Installer), SBOS-021 (Onboarding)*
*Clasificación: Especificación Técnica — Portabilidad e Infraestructura*
