# ADR-002 — Roles, Modos de Operación y Privilegios del daemon bos

**Estado:** Aceptado  
**Fecha:** Junio 2026  
**Autores:** Equipo SKULL — SBOS Architecture  
**Supersede:** N/A  
**Relacionado:** ADR-001 (BOS como capa OS), SBOS-018, SBOS-049  
**Referenciado en:** PLAN_ACCION_BOSAGENT.md — Fase 1, Fase 5, Fase 6

---

## Contexto

El daemon `bos` es el componente central del SBOS. Corre como PID con privilegios de root sobre Ubuntu y como administrador del cluster Kubernetes. Sin una definición explícita de sus roles, modos de operación y límites de privilegios, el sistema viola el principio de menor privilegio requerido por:

- **NIST SP 800-207** (Zero Trust Architecture) — Tenet T-03: el acceso a recursos se otorga con los mínimos privilegios necesarios para la tarea específica
- **ISO 27001:2022 Annex A 8.2** — Privileged Access Management: los derechos de acceso privilegiado deben restringirse y controlarse
- **ISA-95 / IEC 62264-1:2025** — Separación de capas: cada nivel del stack tiene responsabilidades y límites definidos
- **CIS Controls v8** — Control 5: Gestión de cuentas y Control 6: Gestión de control de acceso

El problema concreto: el código actual en `cmd/bos/main.go` define operaciones root sin documentar cuáles son legítimas y cuáles son exceso de privilegio. Cualquier función nueva puede asumir privilegios ilimitados sin cuestionar si es correcto.

---

## Decisión

El daemon `bos` opera en **dos modos formales** con **tres roles funcionales** y un **conjunto acotado de privilegios** sobre Ubuntu y Kubernetes, definidos explícitamente a continuación.

---

## Modo 1 — Instalador (primera ejecución)

### Señal de activación
```
/etc/bos/bos-install.toml NO existe → modo config-pending
```

### Propósito
Preparar el entorno del sistema operativo, instalar el stack de 22 fichas del DAG de SBOS y dejar el sistema listo para operación permanente.

### Duración
Desde el primer arranque hasta que `bosctl bootstrap verify` retorna certificación completa (criterios C-01..C-08 cumplidos). Típicamente 45-90 minutos.

### Privilegios en Modo Instalador

**Sobre Ubuntu (legítimos y acotados):**
```
✓ Crear directorios canónicos: /opt/bos/, /etc/bos/, /var/log/bos/, /run/bos/
✓ Escribir archivos de configuración: bos.toml, bos-install.toml, bos-bootstrap.env
✓ Configurar sysctl: net.ipv4.ip_forward, bridge-nf-call-iptables (requerido por K8s)
✓ Deshabilitar swap: swapoff -a (requerido por K8s, documentado en docs.k8s.io)
✓ Configurar cgroups: crear /sys/fs/cgroup/k8s.io con Delegate=yes
✓ Configurar ufw: puertos 6443, 10250, 2379-2380 (solo los requeridos por K8s)
✓ Instalar k3s vía script oficial (curl piped a bash con checksum verificado)
✓ Habilitar y arrancar servicios: k3s.service, containerd.service
✓ Configurar nftables: regla FORWARD para subnet detectada
✓ Escribir /run/bos/bos.pid, /etc/bos/rbac/roles.json
✓ Configurar contraseña root (SOLO si BOS_ROOT_PASSWORD está en bos-bootstrap.env)
✓ Desplegar bosctl en /opt/bos/bin/bosctl
✓ Copiar scripts core a /opt/bos/core/

✗ NO modificar archivos fuera de /opt/bos/, /etc/bos/, /var/log/bos/, /run/bos/
✗ NO modificar configuración de red más allá de las reglas K8s requeridas
✗ NO instalar paquetes apt arbitrarios (solo los listados en la ficha sbos-bootstrap-os)
✗ NO modificar /etc/passwd, /etc/shadow (excepto root via chpasswd si BOS_ROOT_PASSWORD presente)
✗ NO acceder a filesystems de usuario: /home/, /root/ (excepto .kube/config)
```

**Sobre Kubernetes (como administrador del cluster):**
```
✓ Crear namespaces SBOS: sbos-data, sbos-security, sbos-gateway, sbos-monitoring
✓ Aplicar manifiestos de las 22 fichas del DAG en orden topológico
✓ Crear PersistentVolumeClaims para fichas stateful (postgresql, redis, minio)
✓ Ejecutar kubectl exec para verificaciones de salud durante instalación
✓ Configurar Calico CNI, Linkerd service mesh, Kyverno policies
✓ Leer estado de pods, deployments, statefulsets durante verificación

✗ NO modificar workloads fuera del namespace sbos-* durante instalación
✗ NO acceder a namespaces de usuario/tenant (se crean en Fase 5 por el daemon)
✗ NO escalar o eliminar workloads K8s sin explícita instrucción del operador
```

### Transición a Modo Daemon
```
Condición: bosctl bootstrap verify → C-01..C-08 OK
Acción:     bos escribe /etc/bos/bos-install.toml completo
            bos envía SIGHUP a sí mismo
Resultado:  bos recarga configuración → entra en Modo Daemon
```

---

## Modo 2 — Daemon Soberano (operación permanente)

### Señal de activación
```
/etc/bos/bos-install.toml EXISTE → modo normal (runNormal)
```

### Propósito
Mantener el sistema operativo SBOS en funcionamiento continuo: monitorear salud, reconciliar drift, gestionar el Context Plane y servir como interfaz privilegiada para todos los daemons del sistema.

### Duración
Permanente. Arranca con systemd después de cada reinicio. Nunca termina excepto por shutdown explícito.

---

## Los Tres Roles Funcionales del Daemon

### Rol A — Observador de Infraestructura

**Qué observa:**
- Estado de los 22 pods de fichas SBOS en Kubernetes (cada 30s via watchdog)
- Health de Ubuntu: CPU, memoria, disco, servicios systemd críticos (cada 30s)
- Drift de hashes SHA-256 de los scripts de instalación vs. manifiestos (cada 300s)
- Estado de la máquina de 18 estados de cada ficha (cada 5s via observer loop)

**Qué NO hace en este rol:**
- No interviene automáticamente sin política definida en manifest.yml
- No altera workloads K8s sin pasar por el orquestador
- No modifica archivos del sistema sin audit log previo

**Estándares aplicables:**
- NIST SP 800-207 Tenet T-05: monitoreo continuo de todos los activos
- ISA-95 Level 3: Manufacturing Operations Management — supervisión y estado en tiempo real
- CIS Controls v8 — Control 8: Gestión de logs de auditoría

### Rol B — Administrador de Ubuntu y Kubernetes

**Qué puede hacer:**

*Ubuntu:*
```
✓ Reiniciar servicios systemd de fichas SBOS (k3s, containerd, bos)
✓ Aplicar parches de seguridad a paquetes de fichas instaladas (vía apt)
✓ Rotar certificados TLS generados por certbot/Vault
✓ Leer logs de journalctl para diagnóstico (no modifica)
✓ Ejecutar comandos privilegiados VIA bosctl (ADR-001: reemplaza sudo)
✓ Configurar fail2ban, ufw para nuevas fichas de red

✗ NO ejecutar apt upgrade general sin ficha explícita que lo ordene
✗ NO reiniciar el sistema operativo sin instrucción explícita del operador
✗ NO modificar configuración de red del host más allá de las reglas de fichas
```

*Kubernetes:*
```
✓ Reconciliar fichas SBOS que fallen (repair saga vía orchestrator)
✓ Cordon/drain/uncordon nodos K8s durante mantenimiento controlado
✓ Actualizar imágenes de fichas durante upgrade (vía release manager)
✓ Gestionar secretos en Vault para fichas SBOS
✓ Leer métricas de Prometheus/Grafana para health checks

✗ NO eliminar PersistentVolumeClaims sin aprobación explícita del operador
✗ NO modificar workloads de namespaces no-SBOS (tenant namespaces son del Context Plane)
✗ NO escalar fichas más allá de lo definido en su manifest.yml
✗ NO acceder a secretos de Vault fuera del path sbos/*
```

**Estándares aplicables:**
- ISO 27001:2022 Annex A 8.2: Privileged Access Management
- CIS Kubernetes Benchmark v1.9: Least Privilege para service accounts
- NSA/CISA Kubernetes Hardening Guide: limitación de acceso a API server
- NIST SP 800-207: Policy Enforcement Point (PEP) para operaciones privilegiadas

### Rol C — Gestor del Context Plane (SBOS-049)

**Qué gestiona:**
```
✓ Crear y mantener DeviceContext (dctx_id) para terminales registradas
✓ Promover dctx_id → ctx_id al completarse autenticación Keycloak
✓ Gestionar ciclo de vida de ctx_id: activo, suspendido, bloqueado, invalidado
✓ Invalidar todos los ctx_id de un tenant ante suspensión
✓ Servir como Policy Administrator (NIST 800-207) para decisiones de acceso
✓ Registrar eventos de contexto en audit log (ISO 27001 A.8.15)
✓ Exponer Context Registry via JSON-RPC para Kong, bAuth, biedata
```

**Qué NO hace:**
```
✗ NO toma decisiones de autenticación (eso es Keycloak)
✗ NO calcula BitMask de privilegios (eso es bAuth con sus 5 SPIs Java)
✗ NO gestiona identidades de usuario (eso es Keycloak + SCIM)
✗ NO accede a datos de negocio de tenants (solo metadata de contexto)
```

**Estándares aplicables:**
- NIST SP 800-207: Policy Administrator (PA) — establece y corta paths de comunicación
- OpenID Connect Session Management 1.0: gestión de estado de sesión
- SCIM RFC 7644: ciclo de vida de identidades (active/suspended/revoked)
- ISO 27001:2022 A.9.4.2: session timeout enforcement
- W3C Trace Context: propagación de trazabilidad distribuida

---

## Máquina de Estados del Context Plane

Basado en NIST 800-207 (Policy Administrator), SCIM RFC 7644 y ISO 27001 A.9.4.2:

```
Estado         Descripción                           Quién lo establece
─────────────────────────────────────────────────────────────────────────
PRE_AUTH      Dispositivo registrado, sin usuario    bos automático
              BitMask=0x0. Contexto OS disponible.

ACTIVO        Usuario autenticado. BitMask>0.        bos via ctx.promote
              Empresa+Sucursal+POS asignados.        (post KC token)

SUSPENDIDO    Inactividad > TTL_idle (15 min         bos automático (idle)
              ISO 27001 A.9.4.2) o admin suspende.  Admin via ctx.suspend
              BitMask preservado. Reactivable.

BLOQUEADO     Anomalía detectada (NIST 800-207:      bos automático
              nuevo dispositivo, geo anómala,        Admin via ctx.block
              comportamiento atípico). Step-up
              requerido. BitMask preservado.

STEP_UP       Operación de alto riesgo detectada.   bos automático
              Re-autenticación KC requerida.         (nivel 3 privilegio)
              Temporal. Resuelve a ACTIVO o BLOQ.

SWITCHED      Cambio de empresa/sucursal/POS.        bos via ctx.switch
              ctx_id anterior marcado SWITCHED.      (nuevo ctx_id emitido)
              Terminal. Audit trail preservado.

INVALIDADO    Logout, expiración TTL, o admin        bos (logout/TTL)
              invalida. Terminal. Audit trail         Admin via ctx.invalidate
              preservado SIEMPRE (ISO 27001).        KC (token revocado)
─────────────────────────────────────────────────────────────────────────
```

### Transiciones permitidas

```
PRE_AUTH    → ACTIVO      (bos.ctx.promote + KC token válido)
ACTIVO      → SUSPENDIDO  (idle timeout / admin)
ACTIVO      → BLOQUEADO   (anomalía / admin)
ACTIVO      → STEP_UP     (operación alto riesgo)
ACTIVO      → SWITCHED    (bos.ctx.switch)
ACTIVO      → INVALIDADO  (logout / TTL / admin)
SUSPENDIDO  → ACTIVO      (reactivación admin / re-auth)
BLOQUEADO   → ACTIVO      (step-up KC exitoso)
BLOQUEADO   → INVALIDADO  (admin fuerza invalidación)
STEP_UP     → ACTIVO      (re-auth KC exitosa)
STEP_UP     → BLOQUEADO   (re-auth KC fallida)
SWITCHED    → (terminal)
INVALIDADO  → (terminal)
```

### Privilegios por estado de contexto

```
Estado       BitMask    Acceso al sistema
──────────────────────────────────────────────────────────────
PRE_AUTH     0x0        Solo read de recursos públicos del tenant
ACTIVO       > 0x0      Según BitMask calculado por bAuth
SUSPENDIDO   preservado Sin acceso hasta reactivación
BLOQUEADO    preservado Sin acceso hasta step-up
STEP_UP      parcial    Solo operaciones de re-autenticación
SWITCHED     0x0        Sin acceso (terminal)
INVALIDADO   0x0        Sin acceso (terminal)
──────────────────────────────────────────────────────────────
```

---

## Privilegios que el bos NUNCA debe tener

Independientemente del modo de operación, el daemon bos tiene prohibido:

```
✗ Acceder a datos de negocio de tenants (ERP, POS, documentos)
✗ Leer o escribir credenciales de usuario almacenadas en Keycloak
✗ Modificar el BitMask de privilegios directamente (competencia exclusiva de bAuth)
✗ Tomar decisiones de autenticación (competencia exclusiva de Keycloak)
✗ Eliminar datos de auditoría (solo append, nunca delete)
✗ Operar en modo BOS_DEV_SKIP_ROOT=1 en producción
✗ Exponer el Unix socket /run/bos/bos.sock fuera del grupo bosagent
✗ Ejecutar operaciones destructivas sin audit log previo
```

---

## Consecuencias de esta decisión

### Positivas
1. Cada función nueva en `cmd/bos/main.go` puede verificarse contra esta lista antes de mergearse
2. El RBAC de bosctl puede implementar `CanExecute()` consultando esta lista como política
3. La auditoría ISO 27001 puede verificar privilegios contra un documento formal
4. El Context Plane tiene estados formales y transiciones documentadas

### Negativas (trade-offs aceptados)
1. Requiere actualizar este ADR cada vez que se agrega un nuevo privilegio
2. Algunos scripts de instalación actuales exceden estos límites — requieren revisión
3. El modo instalador tiene privilegios amplios por necesidad — esto es correcto pero debe auditarse

### Implicaciones en el código
1. `internal/observer/loop.go` — el mutex anti-race condition es consecuencia directa del Rol B (no puede reparar en paralelo)
2. `internal/context/service.go` — la máquina de estados de ctx_id implementa directamente este ADR
3. `internal/audit/log.go` — toda operación privilegiada debe llamar `audit.Log()` ANTES de ejecutarse
4. `cmd/bos/main.go` — `autoBootstrap()` debe auditarse contra la lista de privilegios del Modo Instalador

---

## Referencias normativas

| Estándar | Sección | Aplicación en bos |
|---|---|---|
| NIST SP 800-207 | Tenets T-03, T-05 | Least privilege, monitoreo continuo |
| NIST SP 800-207 | Policy Administrator | Rol C — Context Plane |
| ISO 27001:2022 | Annex A 8.2 | Privileged Access Management |
| ISO 27001:2022 | Annex A 9.4.2 | Session timeout (TTL_idle 15 min) |
| ISO 27001:2022 | Annex A 8.15 | Audit trail inmutable |
| ISA-95 / IEC 62264-1:2025 | Levels 3-4 | Separación de capas OS/negocio |
| SCIM RFC 7644 | §3.4 | Estados de identidad: active/suspended |
| OpenID Connect Session | §2 | Session state lifecycle |
| RFC 8693 | Token Exchange | Promote dctx_id → ctx_id |
| CIS Controls v8 | 5, 6, 8 | Privileged accounts, access control, audit |
| CIS Kubernetes Benchmark v1.9 | §4 | Least privilege en K8s |
| NSA/CISA K8s Hardening | §3 | Limitación de acceso al API server |

---

## Changelog

| Fecha | Versión | Cambio |
|---|---|---|
| Junio 2026 | 1.0 | Versión inicial — define modos, roles y privilegios del bos |

---

*ADR-002 — BosAgent/SBOS — Junio 2026*  
*Referencia: PLAN_ACCION_BOSAGENT.md (Fase 1 F1.6, Fase 5 F5.2, Fase 6 F6.1)*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
