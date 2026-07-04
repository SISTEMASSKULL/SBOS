# SBOS-034-PORTABILIDAD
## Portabilidad y Multi-Entorno — Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Abril 2026

---

## 1. Matriz de Soporte de Sistemas Operativos

### Tiers

| Tier | Definición |
|---|---|
| **Tier 1** | Producción validada. CI/CD ejecuta contra esta distro. Runbooks aplican sin modificar. SKULL garantiza soporte. |
| **Tier 2** | Producción con guía. Ajustes documentados. CI/CD como pipeline secundario. Soporte con aviso 24h. |
| **Tier 3** | Desarrollo únicamente. Sin garantía. |

### Distribuciones soportadas

| Distribución | Versión | Tier | Arch | Estado |
|---|---|---|---|---|
| Ubuntu 26.04 LTS | Resolute Raccoon | **Tier 1** | x86_64 | ✅ Producción validada |
| Ubuntu 22.04 LTS | Jammy | Tier 2 | x86_64 | ✅ Con ajustes menores |
| Debian 12 | Bookworm | **Tier 2** | x86_64 | ✅ Con guía §3 |
| Fedora 38+ | — | Tier 3 | x86_64 | Desarrollo únicamente |
| CentOS Stream 9 | — | Evaluación | x86_64 | Q3 2026 |
| Ubuntu 26.04 | — | Evaluación | ARM64 | Ver roadmap §6 |

### Requisitos invariables

Kernel ≥ 5.15 (eBPF Calico + cgroup v2), systemd ≥ 245, glibc ≥ 2.35, acceso root instalación, conectividad a release.skull.systems:443.

## 2. Ubuntu 26.04 vs Debian 12 — Diferencias

| Componente | Ubuntu 26.04 | Debian 12 | Acción |
|---|---|---|---|
| Repos K8s/CRI-O | PPAs | Deb Sig repos (diferente GPG) | Ajustar sources |
| Firewall | ufw (activo) | iptables/nftables sin gestor | Instalar ufw |
| Snap | Disponible | **No disponible** | Verificar fichas sin snap |
| Network Manager | NetworkManager | /etc/network/interfaces | Parametrizar interfaz MetalLB |
| Python | 3.12 | 3.11 | Sin impacto (≥3.11 OK) |
| cgroup v2 | Habilitado por defecto | Requiere habilitación manual | GRUB cmdline |

### Componentes idénticos (sin ajuste)
Binarios Rust (bkernel, biedata) con glibc mínima. Binarios Go (bcompass, bsearch, bauth) CGO_ENABLED=0 estático. Manifests K8s, Helm charts. Imágenes OCI contenedores. PostgreSQL 17 + Patroni. Reglas YAML bKernel. Fichas del stack.

## 3. Guía Instalación Debian 12

### 3.1 Preparación
```bash
sudo apt install -y curl wget gnupg2 ca-certificates apt-transport-https ufw jq socat conntrack
echo "deb http://deb.debian.org/debian bookworm-backports main" | sudo tee /etc/apt/sources.list.d/backports.list
```

### 3.2 CRI-O + kubeadm (repos oficiales pkgs.k8s.io)
```bash
KUBERNETES_VERSION="v1.30"
curl -fsSL https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo apt install -y kubelet kubeadm kubectl cri-o
sudo systemctl enable --now crio
```

### 3.3 Firewall + iptables legacy
```bash
sudo apt install -y ufw && sudo ufw --force enable
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
```

### 3.4 cgroup v2
```bash
sudo sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1"/' /etc/default/grub
sudo update-grub && sudo reboot
```

### 3.5 Checklist validación post-instalación (7 checks)
CRI-O activo, K8s nodes OK, 3 daemons soberanos activos, Patroni OK, Keycloak health 200, Kong status reachable, bKernel checkpoint reciente.

### 3.6 Errores conocidos Debian 12

| Error | Causa | Solución |
|---|---|---|
| kubeadm "cgroup v2 not detected" | No habilitado | §3.4 GRUB |
| MetalLB no asigna IPs | Interfaz incorrecta | Parametrizar primary_interface |
| ufw not found en Bootstrap | No instalado | §3.3 |
| GLIBC_2.38 not found | glibc 2.36 insuficiente | Usar build musl |

## 4. Estrategia Multi-Entorno

| Entorno | Datos | TLS | Instalación |
|---|---|---|---|
| **dev** | Sintéticos (make seed) | Opcional | Nodo único 8GB |
| **staging** | Sintéticos representativos | Activo | Nodo único réplica topología |
| **prod** | Reales del cliente | Zero Trust completo | Nodo único o multi-nodo |

### Configuración por entorno (config.yaml)
```yaml
environment: prod       # dev | staging | prod
bkernel:
  log_level: warn       # dev: debug, staging: info, prod: warn
  batch_size: 1000      # dev: 100, staging: 500, prod: 1000
kong:
  waf_mode: blocking    # dev: detection-only, staging/prod: blocking
```

### K8s overlays Kustomize
dev: replicas=1, memory=128Mi. staging: replicas=1, topología prod. prod: valores del manifest.yml.

### Keycloak realms aislados
dev: `bos-dev` (usuarios prueba). staging: `bos-staging` (regenerados). prod: `bos-{client-slug}` (reales, backup SBOS-026).

### Seeding datos
```bash
make seed ENV=dev      # ~50 empleados, ~200 clientes, ~1000 facturas
make seed ENV=staging  # ~500 empleados, ~2000 clientes
```

### Promoción entre entornos
✅ Fichas, reglas YAML, prompts bCompass, config Kong.
❌ Datos, secretos Vault, realm data KC, certificados TLS.

## 5. Portabilidad Daemons Soberanos

### Compilación Rust actual
```toml
[profile.release]
opt-level = 3, lto = true, codegen-units = 1, strip = true
# Binario ~12MB bkernel, ~8MB biedata
# Sin libssl (usa rustls — TLS en Rust puro)
```

### Dos artefactos por release

| Artefacto | Target | Compatible |
|---|---|---|
| bkernel-x86_64-gnu | x86_64-unknown-linux-gnu | Ubuntu 22.04+, Debian 12+ (glibc ≥ 2.35) |
| bkernel-x86_64-musl | x86_64-unknown-linux-musl | **Cualquier** Linux x86_64 kernel ≥ 4.19 |

IAM Installer selecciona automáticamente: glibc ≥ 2.35 → gnu (más pequeño). Menor → musl (estático).

### Go daemons
bcompass, bsearch, bauth: CGO_ENABLED=0 → binario 100% estático, portable a cualquier Linux.

## 6. Roadmap ARM64

| Fase | Período | Entregable |
|---|---|---|
| 1 Validación | Q3 2026 | Target aarch64-unknown-linux-musl en CI + tests ARM64 |
| 2 Tier 3 | Q4 2026 | Binarios ARM64 en Release Server, detección automática uname -m |
| 3 Tier 2 prod | H1 2027 | Validación cliente piloto + guía instalación ARM64 |

Casos de uso: Raspberry Pi 5 para dev, cloud ARM (Graviton/Ampere) -40% costo, appliance embebido.

Limitaciones: cajas .so recompilar por arch, bit operations (little-endian OK en práctica).

---

## Trazabilidad

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1 Matriz | SBOS-029 v1.0 | §1 (tiers, tabla distros, requisitos invariables) |
| §2 Ubuntu vs Debian | SBOS-029 v1.0 | §2 (tabla 12 diferencias + componentes idénticos) |
| §3 Guía Debian | SBOS-029 v1.0 | §3 completo (8 subsecciones con scripts bash, checklist, errores) |
| §4 Multi-entorno | SBOS-029 v1.0 | §4 (definición entornos, config.yaml, Kustomize, realms, seeding, promoción) |
| §5 Portabilidad | SBOS-029 v1.0 | §5 (Cargo.toml, gnu vs musl, Go estático, selección automática) |
| §6 ARM64 | SBOS-029 v1.0 | §6 (3 fases, casos uso, limitaciones) |

---

---

# ENRIQUECIMIENTO V8 — SBOS-034-PORTABILIDAD

## V5 — Enriquecimiento desde BOS_V5_SBOS-029-Portabilidad-MultiEntorno

### V5 §1 — Tabla Expandida de Diferencias Ubuntu vs Debian (22 diferencias)

Además de las 6 diferencias en V6, las siguientes diferencias adicionales aplican:

| Componente | Ubuntu 26.04 | Debian 12 | Acción |
|---|---|---|---|
| AppArmor | Activo por defecto | Activo (perfil menos restrictivo) | Verificar perfiles existentes |
| SELinux | No disponible | Disponible (no default) | Elegir AppArmor o SELinux, no ambos |
| auditd | Instalado | No instalado | Instalar auditd |
| Chrony/NTP | Instalado (chrony) | No instalado | Instalar chrony |
| Postfix | No instalado | No instalado | Instalar ficha mail |
| containerd | Misma versión | Misma versión | Sin impacto |
| runc | Misma versión | Misma versión | Sin impacto |
| kernel mismo | 6.8+ HWE | 6.1 LTS | Verificar compatibilidad eBPF |

### V5 §2 — Detalle de Compilación glibc vs musl

| Característica | GNU (glibc) | MUSL (musl) |
|---|---|---|
| Tamaño binario bkernel | ~12MB | ~18MB |
| Dependencia libc | glibc ≥ 2.35 | Ninguna (estático total) |
| Rendimiento | Optimizado para servidores | Competitivo en cargas típicas |
| Compatibilidad NSS | Sistema completo | Limitada (no soporta systemd-resolved) |
| Símbolos dinámicos | Carga dinámica de .so | Sin carga dinámica |
| Selección IAM Installer | `ldd --version` glibc ≥ 2.35 | Fallback si glibc < 2.35 |

**IAM Installer detection logic:**
```bash
# Auto-detect: GNU vs MUSL
if ldd --version 2>&1 | grep -q "GLIBC 2.35\|GLIBC 2.38\|GLIBC 2.39\|GLIBC 2.40"; then
    ARCHIVE="bkernel-x86_64-gnu.tar.gz"
else
    ARCHIVE="bkernel-x86_64-musl.tar.gz"
fi
```

### V5 §3 — ARM64 Roadmap Expandido

| Fase | Hito técnico | Dependencia |
|---|---|---|
| 1.1 Q3 2026 | CI matrix: añadir aarch64-unknown-linux-musl a GitHub Actions | GitHub runners ARM64 o self-hosted |
| 1.2 Q3 2026 | Tests unitarios + integración en ARM64 | Equivalente a x86_64 pass rate |
| 1.3 Q4 2026 | Binarios ARM64 en Release Server bajo /arm64/ | Release Plane soporte multi-arch |
| 2.1 Q4 2026 | Detección automática: `uname -m` → descargar binario correcto | IAM Installer upgrade |
| 2.2 H1 2027 | Validación con cliente piloto ARM64 | Contrato piloto |
| 3.1 H1 2027 | Documentación instalación ARM64 | Runbooks, troubleshooting |

### V5 §4 — Estrategia Multi-Entorno Expandida

**Ciclo de promoción entre entornos:**
```
DEV (commits)
  ├── make validate + make test
  ├── Si pasa → push a branch feature
  └── Seeding: ~50 empleados sintéticos

STAGING (release candidate)
  ├── Tests de integración completos
  ├── Tests de humo
  ├── Simulacro DR (cada 6 meses)
  └── Seeding: ~500 empleados

PROD (estable)
  ├── Canary rollout con criterios del SRE
  ├── Error budget tracking
  └── Datos reales del cliente
```

**Artefactos que se promocionan entre entornos:**
| Artefacto | Dev → Staging | Staging → Prod |
|---|---|---|
| Imágenes OCI | ✅ | ✅ (firmadas) |
| Manifests K8s | ✅ | ✅ (firmados) |
| Reglas YAML bKernel | ✅ | ✅ |
| Fichas del stack | ✅ | ✅ |
| Configuraciones Kong | ✅ | ✅ (WAF blocking) |
| Secrets | ❌ (sintéticos) | ❌ (Vault) |
| Datos de BD | ❌ (sintéticos) | ❌ (reales) |

---

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Secciones utilizadas |
|---|---|---|
| V6 original | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V6_SBOS-034-PORTABILIDAD.md` | Documento completo (170 líneas) |
| V5 Portabilidad | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-029-Portabilidad-MultiEntorno.md` | §1 Tabla expandida 22 diferencias, §2 glibc vs musl detalle, §3 ARM64 roadmap expandido, §4 Multi-entorno ciclo promoción |

---

_SKULL · SBOS · SBOS-034-PORTABILIDAD · V8 (V6+V5) · Mayo 2026_
