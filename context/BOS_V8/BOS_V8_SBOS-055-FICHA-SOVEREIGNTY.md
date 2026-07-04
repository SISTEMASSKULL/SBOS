# SBOS-055 — Soberanía de Fichas y Cero Intervención Manual

**Norma irrenunciable del proyecto SBOS. Rige todo desarrollo, instalación y operación del BOS.**
**Este documento es la formalización canónica de ADR-022. Todo agente debe conocerlo.**

**Versión:** 1.0.0 · **Fecha:** 2026-06-17 · **Autor:** sbos-coordinador + bos-developer
**Alineado con:** ADR-022 · SBOS-019-FICHAS · SBOS-053-DAEMON-TUI-DECOUPLING · SBOS-054-NETWORK-SECURITY
**Estándares:** Debian Policy (debconf) · systemd.io (declarative units) · NIST SP 800-207 (Zero Trust) ·
ISO/IEC 27001:2022 A.8.9 (configuration management) · CIS Benchmark v8

---

## Tabla de Contenidos

1. [El Principio](#1-el-principio)
2. [Por Qué Esta Norma Existe](#2-por-qué-esta-norma-existe)
3. [Reglas Irrenunciables (SOV)](#3-reglas-irrenunciables-sov)
4. [Qué Pertenece a Cada Ficha](#4-qué-pertenece-a-cada-ficha)
5. [Ejemplos de Violación y Corrección](#5-ejemplos-de-violación-y-corrección)
6. [Checklist de Cumplimiento](#6-checklist-de-cumplimiento)
7. [Auditoría de Soberanía](#7-auditoría-de-soberanía)
8. [Referencias](#8-referencias)

---

## 1. El Principio

> **Una vez copiados los binarios al servidor, TODO lo que el servidor necesita para operar**
> **debe ser provisto por una ficha declarativa del BOS — sin que ningún humano ni script**
> **externo intervenga manualmente.**
>
> **Si un administrador humano tiene que escribir un comando en la terminal del servidor**
> **para que algo funcione, ese comando DEBE convertirse en una ficha.**

```
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║   ❌ PROHIBIDO                           ✅ OBLIGATORIO                   ║
║   ─────────────                          ──────────────                   ║
║   ssh server && apt install X            servers/.../manifest.yml         ║
║   ssh server && openssl req ...          → system_packages: [X]           ║
║   ssh server && useradd bosagent         ficha: bos-preflight             ║
║   ssh server && mkdir -p /etc/bos        → task_catalog.sh:               ║
║   ssh server && chmod 0660 /run/bos        ficha_install() {              ║
║   ssh server && systemctl enable X           ...                          ║
║   ssh server && echo 'config' > file      }                               ║
║                                                                          ║
║   Toda tarea manual = bug de diseño.                                     ║
║   Toda tarea manual = ficha faltante.                                    ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
```

---

## 2. Por Qué Esta Norma Existe

### 2.1 Causa Raíz del Problema Recurrente

En el desarrollo del BOS, se ha observado un patrón repetido:

1. Se necesita una nueva capacidad (ej: certificado TLS para :9443)
2. El desarrollador la implementa manualmente en la VPS de staging
3. La capacidad funciona en staging
4. Al instalarse en un servidor limpio, **el agente no sabe que debe generarse**
5. El sistema falla porque el paso manual no está documentado ni automatizado

Este ciclo se ha repetido con: creación de directorios, permisos de socket, configuración de systemd, paquetes del SO, y certificados TLS. **Cada vez, la causa raíz es la misma: la tarea no pertenece a ninguna ficha.**

### 2.2 La Analogía del Cirujano y el Robot

> Un cirujano humano puede improvisar durante una operación. Un robot quirúrgico no.
> SBOS es el robot quirúrgico — debe tener cada paso declarado antes de ejecutar.
> El humano que hace SSH al servidor y ejecuta comandos manuales es el cirujano improvisando.
> **SBOS no improvisa. SBOS ejecuta fichas.**

### 2.3 Consecuencias de Violar Esta Norma

| Consecuencia | Ejemplo real |
|-------------|-------------|
| **Instalación incompleta** | Servidor limpio: `bosctl setup` falla porque falta `openssl` para generar certificado |
| **Estado no rastreable** | No se sabe si el certificado fue generado o no, porque no hay registro en `.sbos_state.json` |
| **Reproducibilidad nula** | Staging funciona, producción no. Nadie documentó el paso manual |
| **Auditoría imposible** | ISO 27001 A.8.9 exige gestión de configuración. Sin ficha → sin trazabilidad |
| **Drift invisible** | Un admin cambió el certificado manualmente. El reconcile loop no lo detecta |

---

## 3. Reglas Irrenunciables (SOV)

Estas reglas son **obligatorias** para cualquier tarea de instalación, configuración o mantenimiento. Se numeran `SOV` (Sovereignty) para referencia cruzada.

| # | Regla | Verificable por |
|---|-------|-----------------|
| **SOV-01** | Toda dependencia del sistema operativo se declara en `manifest.yml → system_packages`. Nunca `apt install` manual. | `grep -r "apt install\|apt-get install"` en documentación → cero resultados |
| **SOV-02** | Todo directorio, archivo de configuración, certificado o recurso del sistema es creado por una ficha. Nunca `mkdir`, `touch`, `openssl` manual. | `grep -r "mkdir -p /etc\|openssl req"` en instructivos → solo dentro de task_catalog.sh |
| **SOV-03** | Todo usuario, grupo, permiso o política de acceso es creado por una ficha. Nunca `useradd`, `chown`, `chmod` manual. | `grep -r "useradd\|groupadd"` → solo dentro de task_catalog.sh |
| **SOV-04** | Toda unidad systemd, cron job, timer o servicio es instalado por una ficha. Nunca `systemctl enable` manual. | `systemctl list-units` debe coincidir con lo declarado en fichas |
| **SOV-05** | `install.sh` hace UNA sola cosa: copiar binarios y ejecutar `bosctl system-install`. Sin apt-get, sin useradd, sin systemctl, sin openssl. | `install.sh` ≤ 20 líneas. Sin comandos de sistema. |
| **SOV-06** | El BOS escribe su propio estado. Nunca crear `.sbos_state.json`, `tenant.conf` o archivos de configuración manualmente. | Solo `internal/state/manager.go` escribe `.sbos_state.json` |
| **SOV-07** | Toda tarea que hoy se ejecuta manualmente en la VPS de staging DEBE convertirse en un paso de ficha antes de considerarse "completada". | Staging = producción en miniatura. Si algo requiere mano humana en staging, requiere ficha en producción. |
| **SOV-08** | Si una tarea no pertenece a ninguna ficha existente, se crea una ficha nueva. "No hay ficha para eso" no es excusa — es un gap que debe cerrarse. | `servers/` debe contener una ficha por cada responsabilidad del sistema |

---

## 4. Qué Pertenece a Cada Ficha

### 4.1 Fichas Existentes y su Responsabilidad

| Ficha | Servidor | Responsabilidad | Lo que NUNCA debe hacer otro |
|-------|----------|----------------|------------------------------|
| **bos-preflight** | S-HOST | SO: paquetes, usuario bosagent, directorios, cgroups, sudoers, **certificado TLS** | — |
| **sbos-namespace** | S-HOST | K8s: namespace, NetworkPolicy, ResourceQuota, LimitRange, labels | — |
| **postgresql** | S01 | PostgreSQL 18.4: instalación, 9 BDs, usuarios, WAL slot | — |
| **redis** | S01 | Redis 8.6.2: instalación, 3 DBs, ACLs, persistencia | — |
| **vault** | S02 | Vault 2.0.1: init, unseal, PKI, AppRole, paths | — |
| **keycloak** | S03 | Keycloak 26.6.2: instalación, realm, 5 SPIs | — |
| **kong** | S02 | Kong 3.9.x: instalación, plugins, rutas | — |

### 4.2 Cuándo Crear una Ficha Nueva

```
¿La tarea que necesito hacer...
   │
   ├── ¿Ya la hace una ficha existente?
   │   └── SÍ → agregar el paso a esa ficha (NO hacerlo manual)
   │
   ├── ¿Es una dependencia del SO?
   │   └── SÍ → bos-preflight: manifest.yml → system_packages
   │
   ├── ¿Es configuración de un servicio existente?
   │   └── SÍ → la ficha de ese servicio: task_catalog.sh → ficha_install()
   │
   └── ¿Es algo nuevo que no existe en ninguna ficha?
       └── SÍ → CREAR NUEVA FICHA en servers/<servidor>/<nombre>/
           con: manifest.yml + task_catalog.sh + yaml_engine.yml + resources/
```

---

## 5. Ejemplos de Violación y Corrección

### 5.1 Certificado TLS para :9443 (2026-06-17)

**Violación (antes de SOV-08):**
```bash
# Manual — el operador ejecutó esto en la VPS:
ssh root@vps
mkdir -p /etc/bos/certs
openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout /etc/bos/certs/bos.key \
  -out /etc/bos/certs/bos.crt \
  -subj "/CN=bos.sbos-system.svc.cluster.local"
```

**Corrección (SOV-08 aplicado):**
```bash
# La ficha bos-preflight ahora incluye cert generation en su task_catalog.sh
# El operador NUNCA ejecuta openssl manualmente
# La ficha lo hace idempotentemente: si el cert ya existe → skip
```

### 5.2 Directorios del Sistema

**Violación:**
```bash
ssh root@vps "mkdir -p /etc/bos /run/bos /var/log/bos && chown ..."
```

**Corrección:**
```yaml
# bos-preflight task_catalog.sh → ficha_install()
# Paso "crear_directorios" — idempotente, declarativo
```

### 5.3 Paquetes del SO

**Violación:**
```bash
ssh root@vps "apt install -y curl jq openssl"
```

**Corrección:**
```yaml
# bos-preflight manifest.yml
system_packages:
  - curl
  - jq
  - openssl
```

---

## 6. Checklist de Cumplimiento

Antes de cerrar cualquier sesión de desarrollo, verificar:

### Bloque A — Auditoría de Comandos Manuales

- [ ] ¿Se ejecutó algún `ssh root@vps ...` que no sea `bosctl` o `systemctl start/stop`?
- [ ] ¿Se ejecutó `apt install` fuera de una ficha?
- [ ] ¿Se ejecutó `openssl`, `mkdir`, `useradd`, `chown`, `chmod` manualmente?
- [ ] ¿Se editó un archivo en `/etc/bos/` manualmente?
- [ ] ¿Se ejecutó `systemctl enable` fuera de una ficha?

**Si alguna respuesta es SÍ → hay una ficha faltante. Crearla antes de cerrar la sesión.**

### Bloque B — Cobertura de Fichas

- [ ] ¿Cada recurso en `/etc/bos/`, `/run/bos/`, `/var/log/bos/` es creado por una ficha?
- [ ] ¿Cada paquete instalado está en `manifest.yml → system_packages` de alguna ficha?
- [ ] ¿Cada certificado es generado por una ficha?
- [ ] ¿Cada usuario/grupo es creado por una ficha?
- [ ] ¿`install.sh` tiene ≤ 20 líneas y solo copia binarios + ejecuta `bosctl system-install`?

### Bloque C — Idempotencia

- [ ] ¿Cada paso de `ficha_install()` es idempotente? (ejecutarlo 2 veces = mismo resultado)
- [ ] ¿Si el recurso ya existe, la ficha lo detecta y hace skip?
- [ ] ¿Si el recurso está corrupto, `ficha_repair()` lo regenera?

---

## 7. Auditoría de Soberanía

### 7.1 Comando de Verificación

```bash
# Verificar que no hay archivos en /etc/bos/ creados fuera de una ficha:
find /etc/bos/ -type f ! -name "*.toml" ! -name "*.env" ! -name ".sbos_state.json" \
  ! -path "*/servers/*" ! -path "*/certs/*" ! -path "*/.kube/*"
# Si hay resultados → archivos huérfanos. Investigar qué ficha debería crearlos.

# Verificar paquetes instalados vs declarados:
dpkg -l | grep "^ii" | awk '{print $2}' > /tmp/installed.txt
grep -rh "system_packages:" /etc/bos/blibs/servers/ -A 20 | grep "^  - " | \
  sed 's/  - //' > /tmp/declared.txt
diff /tmp/installed.txt /tmp/declared.txt
# Los paquetes en installed pero no en declared → posible deuda de ficha
```

### 7.2 CI Check

```yaml
# .github/workflows/ci.yml
sovereignty-check:
  runs-on: ubuntu-latest
  steps:
    - name: Verificar install.sh mínimo
      run: |
        lines=$(wc -l < BosAgent/src/staging/install.sh)
        if [ "$lines" -gt 25 ]; then
          echo "❌ install.sh tiene $lines líneas (máx 25). SOV-05 violado."
          exit 1
        fi
        if grep -qE 'apt-get|apt install|useradd|mkdir|openssl|systemctl' BosAgent/src/staging/install.sh; then
          echo "❌ install.sh contiene comandos de sistema. SOV-05 violado."
          exit 1
        fi
        echo "✅ install.sh cumple SOV-05"
```

---

## 8. Referencias

### Documentos del Proyecto

| Documento | Relación |
|-----------|----------|
| **ADR-022** | Origen de esta norma: "sin intervención manual en el servidor" |
| **SBOS-019-FICHAS** | Unidad atómica de despliegue — la ficha es el único mecanismo de cambio |
| **SBOS-053-DAEMON-TUI-DECOUPLING** | DTC-01: toda ficha ejecutable sin TUI (headless-first) |
| **SBOS-054-NETWORK-SECURITY** | NRS: seguridad aplicada desde la ficha, no desde el manual |
| **CLAUDE.md (BosAgent)** | NORMA IRRENUNCIABLE — Sin intervención manual en el servidor |
| **DATOS-TUI-INSTALACION.md** | §4: catálogo de fichas con variables, pruebas y comandos |

### Estándares Internacionales

| Estándar | Qué aporta |
|----------|-----------|
| **Debian Policy (debconf)** | Separación frontend/backend: la configuración vive en el paquete, no en quien instala |
| **systemd.io** | Unidades declarativas: el estado deseado se declara, systemd lo aplica |
| **NIST SP 800-207** | Zero Trust: cada cambio de configuración es verificado y autorizado |
| **ISO/IEC 27001:2022 A.8.9** | Configuration management: toda configuración debe estar documentada, versionada y controlada |
| **CIS Benchmark v8 §4.1** | Configuration files deben ser gestionados por un sistema de configuración, no manualmente |

---

*SBOS-055-FICHA-SOVEREIGNTY.md v1.0 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
*Esta norma es irrenunciable. Ningún agente, desarrollador u operador puede violarla.*
*"Si un humano tiene que escribirlo, una ficha debe existir para ello."*
