# BosAgent

**Proyecto:** SBOS — Sovereign Business Operating System
**Árbol:** 26a83fa0-d71c-476b-b52c-4cb14bdd2929
**Nodo SKDATA:** bos-agent
**Perfil:** dominio (orden 5, P1)
**Materializado:** 2026-05-12
**Estado:** en-construccion — Fase C completada, transición a Fase D

---

## Resumen

BosAgent es el núcleo del BOS (Business Operating System). Es un daemon Go que corre como root en el host, actuando como capa del sistema operativo que unifica Ubuntu + Kubernetes bajo una sola superficie de control: `bosctl`.

**BOS no administra Ubuntu y Kubernetes. BOS ES Ubuntu + Kubernetes + sus propias capacidades.**

---

## Estado de Construcción

| Fase | Dominio | Estado |
|---|---|---|
| Sprints 1-4 | Ciclo de vida (state, installer, health, reconcile, plugin, K8s, server) | ✅ Certificado E2E 24/24 |
| Fase A | D6 Seguridad (CIS scanner, RBAC, hardening) | ✅ Completa |
| Fase B | D1+D2 Reparación + Package Manager | ✅ Completa |
| Fase C | D3 Observabilidad (top, health-report, watchdog 30s) | ✅ Completa |
| Fase D | D5+D4 Catálogo de Apps + Agente IA | ⬜ Pendiente |
| Fase E | D7 BOS Installer ISO | ⬜ Pendiente |

**Código:** 12,379 líneas Go · 30+ archivos · 18 paquetes internos · 23 comandos bosctl

---

## Arquitectura

```
bosctl (CLI soberana) ──► Unix socket (/run/bos/bos.sock) ──► bos daemon
                                                              │
    ┌─────────────────────────────────────────────────────────┤
    │  internal/                                              │
    │  ├── state/         State manager (fcntl flock)         │
    │  ├── installer/     Saga pattern (compensator)          │
    │  ├── health/        Health checker periódico            │
    │  ├── reconcile/     Drift detection + topological sort  │
    │  ├── repair/        OS + K8s + BOS repair multi-capa    │
    │  ├── packages/      apt + pip + helm unificados         │
    │  ├── security/      RBAC + CIS scanner + hardening      │
    │  ├── observability/ top + health-report 3-capas         │
    │  ├── watchdog/      Ciclo 30s Ubuntu→K8s→BOS            │
    │  ├── server/        HTTP API + WebSocket                │
    │  ├── plugin/        Cargador de fichas YAML             │
    │  ├── k8s/           Cliente Kubernetes                  │
    │  ├── config/        Configuración + defaults            │
    │  └── ...            release, wslib, toml                │
    │                                                         │
    └── /etc/bos/.sbos_state.json  ←  Estado unificado        │
       /etc/bos/blibs/servers/     ←  ~112 fichas             │
       /opt/bos/bin/bosctl         ←  CLI privilegiada        │
```

---

## Requisitos

- Ubuntu 24.04+ (host bare-metal o VM)
- Podman (rootless para desarrollo, rootful en producción)
- Go 1.22 (compilación en contenedor `golang:1.22`)
- Containerd + kubeadm + kubelet (instalados por sbos-bootstrap-os/k8s)

---

## Compilación y Despliegue

```bash
# Compilar (Go 1.22 en contenedor — no instalar Go en el host)
S=src/
mkdir -p /tmp/bos-build
podman run --rm -v "$S:/src:Z" -v /tmp/bos-build:/out:Z -w /src \
  -e CGO_ENABLED=0 golang:1.22 sh -c \
  'go build -o /out/bos ./cmd/bos && go build -o /out/bosctl ./cmd/bosctl'

# Desplegar en staging
  > /var/log/bos/bos.log 2>&1 &

# Verificar
```

---

## Comandos principales

```bash
bosctl top                     # Métricas unificadas CPU/MEM/DISK + K8s + Fichas
bosctl health-report           # Reporte de salud 3-capas
bosctl repair --target=all     # Reparación completa Ubuntu+K8s+BOS
bosctl install nginx           # Instalar paquete + auto-generar ficha
bosctl security scan           # CIS scan: Ubuntu + K8s + RBAC
bosctl logs <pod|servicio>     # Logs unificados
bosctl identity whoami         # Usuario y rol actual
bosctl shutdown                # Apagado limpio con drain de K8s
```

Referencia completa en [MANUAL-SUPERVISOR-BOS-AGENT.md](context/MANUAL-SUPERVISOR-BOS-AGENT.md) §11.

---

## Documentación

| Documento | Propósito |
|---|---|
| [MANUAL-SUPERVISOR-BOS-AGENT.md](context/MANUAL-SUPERVISOR-BOS-AGENT.md) | Guía operativa del supervisor — comandos, despliegue, arquitectura |
| [BOS-OS-ELEVATION-PLAN-v3.md](context/BOS-OS-ELEVATION-PLAN-v3.md) | Plan maestro de elevación: BOS = Ubuntu + K8s + BOS |
| [plan-desarrollo-bos-elevacion.md](context/plan-desarrollo-bos-elevacion.md) | Plan de desarrollo por fases (A-E) con archivos y certificación |
| [BOS-LIFECYCLE-PLAN-v2.md](context/BOS-LIFECYCLE-PLAN-v2.md) | Ciclo de vida validado contra ISO/IEC 25010 |
| [VERIFICACION-COMPLETITUD-FICHAS.md](context/VERIFICACION-COMPLETITUD-FICHAS.md) | Taxonomía de 112 fichas, laboratorio SKULL |

---

## Proyecto padre

Este proyecto es parte del ecosistema [SBOS](../../../PROYECTO-ESTADO.md).  
Ver [SBOS-INHERITANCE.md](../../../SBOS-INHERITANCE.md) para el contexto heredado del padre.
