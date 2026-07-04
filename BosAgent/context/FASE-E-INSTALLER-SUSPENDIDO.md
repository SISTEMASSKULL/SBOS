# Fase E — Installer ISO (D7) — SUSPENDIDA

**Sesión:** S-34
**Fecha:** 2026-05-20
**Estado:** SUSPENDIDA hasta nuevo aviso del HITL
**Motivo:** Decisión de arquitectura pendiente — estrategia de compilación de ISOs (host vs contenedor)

---

## Resumen de Fase A (Compositor)

La Fase A fue ejecutada completamente por el Compositor en S-34. Resultados:

### AI-DOC del dominio Installer ISO

- **Propósito:** Convertir BOS en SO de primera clase instalable desde ISO bootable
- **Modos:** Offline (TODO incluido) + Online (descarga en tiempo real)
- **Comandos previstos:** `bosctl build-iso --manifest=server.yml` + `bosctl deploy-iso --target=<host>`
- **Stack:** Go (builder) + YAML (user-data) + Bash (bootstrap) + Python+rich (TUI) + xorriso (empaquetado)
- **Arquitectura:** 6 archivos Go, 15 assets, 1 ficha nueva, 2 comandos CLI, 1 Makefile

### GAPS detectados

```
CRÍTICOS: 6  (E1-E6)
MEDIOS:   5  (E7-E11)
BAJOS:    2  (E12-E13)
```

| # | Gap | Criticidad |
|---|-----|------------|
| E1 | No existe directorio `installer/` ni archivos del D7 | ALTA |
| E2 | No existen `bosctl build-iso` ni `deploy-iso` | ALTA |
| E3 | No existe paquete `internal/installer/` (iso.go, manifest.go, preseed.go, branding.go) | ALTA |
| E4 | **xorriso, mkisofs, qemu NO instalados en el host — ESTRATEGIA PENDIENTE** | ALTA |
| E5 | No existe ficha `sbos-installer` | ALTA |
| E6 | No existe Makefile con targets ISO | ALTA |
| E7 | No hay assets de branding (splash, progress-screens, GRUB theme) | MEDIA |
| E8 | No hay `bos-installer-ui` (TUI de progreso Python+rich) | MEDIA |
| E9 | No hay `bos-bootstrap.sh` (late-commands) | MEDIA |
| E10 | No hay `user-data.yaml` (corazón del autoinstall) | MEDIA |
| E11 | No hay `server.yml` de ejemplo (modelo de entrada) | MEDIA |
| E12 | No hay tests de integración para ISO builder | BAJA |
| E13 | No hay documentación operativa del ISO builder | BAJA |

### Gate

**GAPS-VALIDATION: ABIERTO** — 6 gaps críticos bloquean Fase B.

---

## Decisión pendiente del HITL

**E4 — Estrategia de compilación de ISOs:**

| Opción A: Host nativo | Opción B: Contenedor Podman (recomendada) |
|---|---|
| Instalar xorriso+qemu en el host | `podman run ubuntu:24.04` con herramientas |
| Más rápido | Mismo patrón que Go (HERRAMIENTAS-HOST.md), sin polución |
| Instala paquetes en el host | Necesita construir imagen de contenedor |

---

## Árbol de implementación (concebido, no ejecutado)

```
BosAgent/installer/                          ← NUEVO: Assets del installer
  user-data.yaml
  meta-data
  grub.cfg
  grub/theme/
  bos-bootstrap.sh
  bos-installer-ui/
    main.py
    requirements.txt
    bos-installer-ui.service
  assets/
    splash.png
    progress-screens/
  Makefile

BosAgent/src/cmd/bosctl/
  build_iso.go                               ← NUEVO
  deploy_iso.go                              ← NUEVO

BosAgent/src/internal/installer/
  iso.go                                     ← NUEVO
  manifest.go                                ← NUEVO
  preseed.go                                 ← NUEVO
  branding.go                                ← NUEVO

BosAgent/staging/core/servers/hostserver/sbos-installer/
  manifest.yml                               ← NUEVO
  task_catalog.sh                            ← NUEVO
  yaml_engine.yml                            ← NUEVO

BosAgent/src/cmd/bosctl/main.go             ← MODIFICAR
```

---

## Próximos pasos cuando se reanude

1. HITL decide estrategia de compilación (A vs B)
2. Cerrar GAP-E4 (instalar herramientas o crear contenedor)
3. Ejecutar Fase B: scaffolding → bosctl → internal → ficha → Makefile
4. Probar con `make bos-installer-offline` en entorno de staging

---

**Documento generado por el Compositor en S-34. Suspendido por orden del HITL.**
