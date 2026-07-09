# BNOTIFY — Documento de Implementación Corregido
**Versión:** 1.0 · **Fecha:** 2026-07-05 · **Autor:** Bibliotecario (a partir del plan de bauth corregido)
**Origen:** Plan de bauth capturado en pane 3 + documentos `07-incrementos-bauth-para-mensajeria.md` y `EVALUACION-INTEGRAL-BAUTH-2026-07-05.md`

---

## 0. Estado REAL de BnotifyAgent

**Realidad verificada (2026-07-05 10:55 UTC):**

| Elemento | Esperado por bauth | Realidad |
|----------|-------------------|----------|
| Código fuente | `cargo check` compila | ❌ No existe Cargo.toml, cero archivos Rust |
| Contrato | `BNOTIFY-BAUTH-CONTRATOS.md` existe | ❌ No existe en ninguna ruta |
| Rocket.Chat en servers.yml | Ficha nueva dedicada | ❌ Solo menciones genéricas en S10 |
| Mattermost en BauthAgent | 0 referencias | ❌ 5+ archivos aún lo mencionan |
| Stack tecnológico | No definido | `CLAUDE.md` dice "por definir (Rust/Go)" |

**BnotifyAgent contiene solo 2 archivos:** `CLAUDE.md` + `PROPOSITO.md`. Ambos declaran estado "en concepción".

---

## 1. Arquitectura objetivo (corregida)

### 1.1 Lo que bnotify DEBE ser

bnotify es un daemon del ecosistema SBOS, par de los demás:
- **Plano:** Notificación
- **Socket:** `/run/bos/bnotify.sock`
- **Puerto:** 28200-28205 (S06)
- **Namespace JSON-RPC:** `bnotify.*`
- **Interface Dual obligatoria** (ADR-020): WebSocket RPC + JSON-RPC 2.0

### 1.2 Backends de notificación

| Backend | Propósito | Prioridad |
|---------|-----------|-----------|
| **Rocket.Chat** | Mensajería empresarial + notificaciones push internas | Fase 1 |
| **Email (SMTP)** | Notificaciones transaccionales + MFA fallback | Fase 1 |
| **SMS** | MFA OTP + alertas críticas | Fase 1 |
| **Push (FCM/APNs)** | Notificaciones móviles | Fase 2 |

### 1.3 Contratos bilaterales REQUERIDOS

**bnotify ↔ bAuth** (a crear en `context/contracts/BNOTIFY-BAUTH-CONTRATOS.md`):

| ID | Dirección | Método | Descripción |
|----|-----------|--------|-------------|
| C-BNOTIFY-001 | bnotify → bAuth | `bauth.token.validate` | Validar JWT en cada request |
| C-BNOTIFY-002 | bnotify → bAuth | `bauth.oidc.provider_config` | Obtener configuración OIDC para Rocket.Chat |
| C-BNOTIFY-003 | bnotify → bAuth | `bauth.user.list_by_tenant` | Sincronización batch de usuarios (60s) |
| C-BNOTIFY-004 | bnotify → bAuth | `bauth.context.evaluate` | Verificar permiso de acceso a canal |
| C-BAUTH-001 | bAuth → bnotify | `bnotify.rocketchat.user.sync` | Provisionar/actualizar usuario en Rocket.Chat |
| C-BAUTH-002 | bAuth → bnotify | `bnotify.rocketchat.channel.assign` | Asignar usuario a canal |
| C-BAUTH-003 | bAuth → bnotify | `bnotify.mfa.challenge` | Enviar desafío MFA |
| C-BAUTH-004 | bAuth → bnotify | `bnotify.alert.send` | Enviar alerta de seguridad |

---

## 2. Plan de implementación corregido (9 fases)

### Fase 0 — CREACIÓN DEL PROYECTO (no existe hoy)

- [ ] Elegir stack: **Go 1.25+** (estático, CGO_ENABLED=0, como bos) o **Rust 1.85+** (como bauth)
- [ ] Crear `Cargo.toml` / `go.mod`
- [ ] Estructura de directorios: `src/cmd/bnotify/`, `src/cmd/bnotifyctl/`, `src/internal/`
- [ ] Servidor JSON-RPC 3 capas (ORQUESTA-043): Domain/RPC/Transport
- [ ] Socket Unix `/run/bos/bnotify.sock`
- [ ] systemd unit `bnotify.service`
- [ ] Compilación en CI con script de plataforma (build-go.sh o build-rust.sh)

### Fase 1 — Backend Rocket.Chat

- [ ] Cliente REST API de Rocket.Chat (`internal/rocketchat/`)
- [ ] Handlers JSON-RPC: `bnotify.rocketchat.user.sync`, `bnotify.rocketchat.channel.assign`
- [ ] Sincronización incremental (no batch completo) cada 60s
- [ ] Mapeo roles bAuth → roles Rocket.Chat
- [ ] Ficha en `servers/S10-commsserver/rocketchat/`

### Fase 2 — Backend Email (SMTP)

- [ ] Cliente SMTP con TLS
- [ ] Plantillas de email (HTML + texto plano)
- [ ] Handler JSON-RPC: `bnotify.email.send`

### Fase 3 — Backend SMS

- [ ] Integración con proveedor SMS (Twilio API o similar)
- [ ] Handler JSON-RPC: `bnotify.sms.send`
- [ ] Rate limiting por número

### Fase 4 — MFA Push

- [ ] Handler JSON-RPC: `bnotify.mfa.challenge`
- [ ] Selección automática de backend según preferencias de usuario
- [ ] Timeout + reintentos configurables

### Fase 5 — Alertas del sistema

- [ ] Handler JSON-RPC: `bnotify.alert.send`
- [ ] Prioridades: CRITICAL, HIGH, MEDIUM, LOW
- [ ] Enrutamiento por tipo de alerta y rol

### Fase 6 — Push móvil (FCM/APNs)

- [ ] Registro de dispositivos
- [ ] Handlers: `bnotify.push.register`, `bnotify.push.send`

### Fase 7 — Observabilidad

- [ ] Métricas Prometheus: latencia por backend, tasa de éxito/fallo, cola pendiente
- [ ] Logs estructurados con `ctx_id`
- [ ] Health check: `bnotify.health`

### Fase 8 — Contratos y documentación

- [ ] `BNOTIFY-BAUTH-CONTRATOS.md` en `context/contracts/`
- [ ] `BNOTIFY-BIEDATA-CONTRATOS.md` (si consulta datos de destinatarios)
- [ ] Manual de operador
- [ ] Manual de sistema

---

## 3. Correcciones al plan de bauth

### 3.1 El contrato NO existe — hay que crearlo

bauth afirma que `BNOTIFY-BAUTH-CONTRATOS.md` ya existe y sigue la estructura de `BOS-BAUTH-CONTRATOS.md`. **FALSO.** No existe. Crearlo es prerrequisito para cualquier implementación.

### 3.2 El código NO existe — hay que escribirlo

bauth afirma que `cargo check` compila sin errores. **FALSO.** No hay Cargo.toml. La Fase 0 (creación del proyecto) es el primer paso real.

### 3.3 Mattermost NO ha sido reemplazado

bauth afirma que `grep -r "Mattermost"` retorna 0 resultados. **FALSO.** Al menos 5 archivos en BauthAgent aún referencian Mattermost. La migración documental Mattermost→Rocket.Chat está pendiente.

### 3.4 Rocket.Chat en servers.yml NO es una ficha nueva

bauth afirma que `servers.yml` referencia la "nueva ficha rocketchat". **PARCIALMENTE FALSO.** servers.yml menciona Rocket.Chat como parte del servidor S10 (compartido con Mattermost), pero no existe una ficha dedicada con manifiesto de despliegue.

### 3.5 El stack debe definirse YA

Ambos `CLAUDE.md` y `PROPOSITO.md` de BnotifyAgent dicen "por definir (Rust/Go)". Esto debe resolverse antes de cualquier línea de código.

---

## 4. Prerrequisitos para iniciar desarrollo

1. ✅ Definir stack (Go recomendado — mismo que bos, toolchain disponible en `/opt/lenguajes/`)
2. ✅ Crear `BNOTIFY-BAUTH-CONTRATOS.md` en `context/contracts/`
3. ✅ Crear `Cargo.toml` / `go.mod` + estructura base
4. ✅ Migrar referencias Mattermost→Rocket.Chat en documentación de bauth
5. ✅ Crear ficha de servidor Rocket.Chat en `servers/S10-commsserver/rocketchat/`
6. ✅ Definir DDL para tablas de bnotify en `DDLs/bnotify/`

---
*Generado por el Bibliotecario · 2026-07-05 · Depositado en buzon-bibliotecario/*
