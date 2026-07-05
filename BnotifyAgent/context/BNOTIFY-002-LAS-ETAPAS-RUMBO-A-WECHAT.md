# BNOTIFY-002-LAS-ETAPAS-RUMBO-A-WECHAT — Roadmap bChat
## De Rocket.Chat vanilla a super-app soberana · 5 Etapas

**Versión:** 2.0.0 · **Fecha:** 2026-07-05 · **Autor:** bauth-developer
**Referencia:** `BNOTIFY-001-VISION.md` v2.0 · `07-incrementos-bauth-para-mensajeria.md`
**Corrección v2.0:** bAuth OIDC Provider nativo. Keycloak backup. REST API interna vetada. Socket+RPC estándar.
**Inspiración:** WeChat (Tencent) — mensajería + identidad + pagos + mini-programas + cuentas oficiales

---

## VISIÓN GENERAL DEL ROADMAP

```
ETAPA 0 ─── ETAPA 1 ─── ETAPA 2 ─── ETAPA 3 ─── ETAPA 4
Cimientos    Chat básico   Identidad    Negocio     Super-app
  AHORA      1-2 sem      2-4 sem     4-8 sem     8-16 sem
```

WeChat no nació siendo super-app. Empezó como mensajería (2011), agregó Momentos (2012),
luego Pagos (2013), luego Mini-Programas (2017). bChat sigue el mismo camino evolutivo:
**primero mensajería que funciona, luego identidad gobernada, luego negocio integrado,
finalmente plataforma de mini-apps.**

---

## ETAPA 0 — CIMIENTOS (AHORA · Julio 2026)

**Objetivo:** Documentar, planificar, declarar infraestructura. Cero código de mensajería.
Todo es papel, fichas y contratos.

### Entregables

| ID | Entregable | Tipo | Estado |
|----|-----------|------|:------:|
| E0.01 | `BNOTIFY-000-INDEX.md` — índice de navegación | Documento | ✅ |
| E0.02 | `BNOTIFY-001-VISION.md` — visión de bChat | Documento | ✅ |
| E0.03 | `BNOTIFY-002-LAS-ETAPAS-RUMBO-A-WECHAT.md` — este documento | Documento | ✅ |
| E0.04 | `BNOTIFY-ARQUITECTURA.md` — arquitectura del daemon bnotify | Documento | ⏳ |
| E0.05 | `BNOTIFY-ROCKETCHAT-INTEGRACION.md` — integración bnotify↔bChat | Documento | ⏳ |
| E0.06 | `BNOTIFY-BAUTH-CONTRATOS.md` — contrato bilateral en `context/contracts/` | Contrato | ⏳ |
| E0.07 | `servers/S10-commsserver/bchat/manifest.yml` — ficha de despliegue actualizada (v8.5.0) | Ficha | ⏳ |
| E0.08 | `BnotifyAgent/src/` — esqueleto Rust (main.rs, config, server, Cargo.toml) | Código | ⏳ |
| E0.09 | `BnotifyAgent/PROPOSITO.md` actualizado — métodos bChat | Documento | ⏳ |
| E0.10 | `BnotifyAgent/CLAUDE.md` actualizado — stack Rust 1.85+ definido | Documento | ⏳ |
| E0.11 | Eliminar TODAS las referencias a Mattermost en el proyecto | Limpieza | ⏳ |

### Criterio de salida
- [ ] `find BnotifyAgent -type f` retorna ≥ 10 archivos (hoy: 2)
- [ ] `context/contracts/` contiene `BNOTIFY-BAUTH-CONTRATOS.md`
- [ ] `servers/S10-commsserver/bchat/` contiene ficha completa con Rocket.Chat 8.5.0
- [ ] `grep -rli Mattermost BauthAgent/` retorna 0
- [ ] `cargo check` en BnotifyAgent compila (exit code 0)

---

## ETAPA 1 — CHAT BÁSICO (1-2 semanas)

**Objetivo:** Rocket.Chat 8.5.0 funcionando en K8s con login OIDC vía bAuth (proveedor nativo,
no Keycloak). Usuarios pueden enviar mensajes, crear canales, chatear. Sin gobierno de
acceso aún — eso viene en Etapa 2.

### Lo que se instala

| Componente | Versión | Motor | Puerto | Comunicación |
|-----------|:-------:|-------|:------:|-------------|
| Rocket.Chat CE | 8.5.0 | Node 22.16 + Deno 1.43.5 | 3000 | REST (hacia afuera) |
| MongoDB | 8.0 | WiredTiger | 27017 (ClusterIP) | Driver nativo |
| bnotify (daemon) | 0.1.0 | Rust 1.85 MUSL | 28200 | Unix socket `/run/bos/bnotify.sock` |

### Entregables

| ID | Entregable | Tipo |
|----|-----------|------|
| E1.01 | bChat desplegado en K8s (namespace `sbos-{tenant}`) — responde en `:3000` | Infra |
| E1.02 | Login OIDC funcional: usuario → bAuth OIDC nativo → JWT Ed25519 → bChat sesión iniciada | Integración |
| E1.03 | Claim `sbos_roles` en el JWT de bAuth — bChat recibe roles como claim OIDC | Integración |
| E1.04 | bnotify `health` endpoint responde en `/run/bos/bnotify.sock` (Unix socket, JSON-RPC) | Código |
| E1.05 | bnotify `bnotify.health.check` → `{"status":"operativo"}` sobre Unix socket | Código |
| E1.06 | bChat REST API accesible desde bnotify (token admin desde Vault). SOLO bnotify llama a bChat | Integración |
| E1.07 | Primer mensaje de prueba enviado: bnotify → bChat REST API → DM de usuario | Integración |

### Criterio de salida
- [ ] Usuario `test_user` inicia sesión en bChat con OIDC de bAuth (sin tocar Keycloak)
- [ ] `echo '{"jsonrpc":"2.0","method":"bnotify.health.check","id":1}' | nc -U /run/bos/bnotify.sock` → OK
- [ ] `bnotify.alert.send` sobre Unix socket entrega un mensaje en el DM del usuario
- [ ] bChat responde en `https://{tenant}.sbos.app/chat` vía Kong
- [ ] Kong PEP valida ctx_id llamando a bAuth por Unix socket (no REST)

---

## ETAPA 2 — IDENTIDAD GOBERNADA (2-4 semanas)

**Objetivo:** bAuth reemplaza TODAS las funciones EE de Rocket.Chat. Los roles de bAuth
gobiernan qué usuarios acceden a qué canales. La sincronización es automática cada 60s.
Un usuario sin átomo `D1.bchat.room.JOIN` no puede unirse a canales.

### Funciones EE reemplazadas por bAuth en esta etapa

| Función EE | Cómo la reemplaza bAuth |
|-----------|------------------------|
| LDAP Role Mapping | bAuth OIDC claims incluyen `sbos_roles`. bnotify mapea claim → rol Rocket.Chat |
| Auto-join channels by role | bAuth `context.evaluate` verifica átomo `D1.bchat.room.JOIN`. bnotify ejecuta join |
| Background Sync | bAuth reconcile loop (60s) → `bnotify.rocketchat.user.sync` incremental |
| Custom OAuth Role Assignment | bAuth emite claim `sbos_roles` en JWT. bnotify asigna rol vía REST API |
| SAML Field Mapping | No es necesario — bAuth es OIDC nativo. Sin dependencia SAML |

### Entregables

| ID | Entregable | Tipo |
|----|-----------|------|
| E2.01 | Contrato `C-BNOTIFY-001` implementado: bAuth provee OIDC con claims de rol | Código |
| E2.02 | Contrato `C-BNOTIFY-002` implementado: `bnotify.rocketchat.user.sync` funcional | Código |
| E2.03 | Contrato `C-BNOTIFY-003` implementado: `bnotify.rocketchat.channel.assign` funcional | Código |
| E2.04 | Contrato `C-BAUTH-001` implementado: bAuth → bnotify cuando cambia un rol | Código |
| E2.05 | Reconcile loop 60s: bAuth → bnotify → bChat REST API (usuarios + roles + canales) | Código |
| E2.06 | Átomos `D1.bchat.room.*` registrados en `privilege_atom` (CREATE, JOIN, INVITE, LEAVE, ARCHIVE) | DDL |
| E2.07 | Átomos `D1.bchat.message.*` registrados (SEND, EDIT_OWN, DELETE_OWN, DELETE_ANY) | DDL |
| E2.08 | Átomos `D1.bchat.moderation.*` registrados (VIEW_REPORTED, HIDE, SUSPEND_USER, BAN_USER) | DDL |
| E2.09 | Test: usuario sin rol `CONSUMER_T0` no puede enviar mensajes (átomo ausente → 403) | Test |
| E2.10 | Test: cambio de rol en bAuth → en < 60s el usuario gana/pierde acceso al canal en bChat | Test |

### Criterio de salida
- [ ] `bnotify.rocketchat.user.sync` crea/actualiza usuario en bChat con roles correctos
- [ ] Un usuario sin átomo `D1.bchat.room.JOIN` recibe 403 al intentar unirse a un canal
- [ ] Un moderador con átomo `D1.bchat.moderation.HIDE` puede ocultar mensajes
- [ ] El reconcile loop no produce duplicados ni inconsistencias tras 100 ejecuciones

---

## ETAPA 3 — NEGOCIO INTEGRADO (4-8 semanas)

**Objetivo:** bChat deja de ser solo chat. Se integra con el ecosistema SBOS:
notificaciones del ERP, alertas del calendario, Push MFA, canales automáticos
por tenant/empresa/sucursal.

### Lo que se integra

| Sistema | Qué dispara | Qué llega a bChat |
|---------|------------|-------------------|
| Tryton (ERP) | Factura emitida | DM al cliente: "Factura #1234 emitida por Bs 5,000" |
| bCalendar | Alarma de cita | DM: "Recordatorio: Reunión directorio en 30 min" |
| bAuth MFA | Desafío Push MFA | DM: "¿Eres tú iniciando sesión desde La Paz? [SÍ] [NO]" |
| Wazuh (SIEM) | Alerta de seguridad | Canal #seguridad: "Intento fallido de login 5x en usuario X" |
| bKernel | Error de importación | Canal #operaciones: "Falló importación de facturas: archivo inválido" |

### Entregables

| ID | Entregable | Tipo |
|----|-----------|------|
| E3.01 | Canales automáticos por tenant: `#general`, `#seguridad`, `#operaciones`, `#compliance`, `#admin` | Infra |
| E3.02 | Notificaciones del ERP: factura emitida → DM al cliente con datos de factura | Código |
| E3.03 | Notificaciones del calendario: alarma → DM al usuario con título y hora | Código |
| E3.04 | Push MFA: bAuth → bnotify → DM con challenge "¿Eres tú?" + botones Sí/No | Código |
| E3.05 | Alertas de seguridad: Wazuh → bKernel → bnotify → canal #seguridad | Código |
| E3.06 | Mensajes formateados Markdown con links accionables (factura, tarea, evento) | Código |
| E3.07 | Átomos `D8.bchat.session.*` para gobernar sesiones de consumo | DDL |
| E3.08 | Átomos `D8.bchat.audit.*` para clase de auditoría por tipo de evento | DDL |
| E3.09 | Test: factura emitida en Tryton → DM aparece en bChat en < 5s | Test |
| E3.10 | Test: MFA challenge respondido → bAuth recibe respuesta en < 3s | Test |

### Criterio de salida
- [ ] 5 canales automáticos existen por tenant al desplegar
- [ ] Factura emitida → notificación en DM del cliente en < 5s
- [ ] Push MFA funcional: bAuth → bnotify → bChat DM → respuesta → bAuth
- [ ] Todos los mensajes automáticos tienen `ctx_id` en `notifier_db.notification_events`

---

## ETAPA 4 — SUPER-APP (8-16 semanas)

**Objetivo:** bChat se convierte en la plataforma de interacción del SBOS. Mini-aplicaciones
embebidas, cuentas oficiales de negocio, wallet soberana, firma digital desde el chat.

WeChat logró esto con Mini-Programs (2017) — aplicaciones ligeras que corren dentro
de WeChat sin instalar nada. bChat usa Rocket.Chat Apps (Deno) para lo mismo.

### Lo que se construye

| Componente | Descripción | Inspiración WeChat |
|-----------|------------|-------------------|
| **bChat Apps (Deno)** | Mini-aplicaciones dentro de bChat: consulta de saldo, aprobación de facturas, solicitud de vacaciones | Mini-Programs |
| **Cuentas oficiales** | Empresas y servicios del tenant con canal de broadcast verificado | Official Accounts |
| **Wallet bChat** | Consulta de saldo, envío de dinero entre usuarios del mismo tenant, facturación electrónica SIN | WeChat Pay |
| **Firma digital** | Firmar documentos desde el chat. bAuth → Vault Ed25519. Validez legal Bolivia (Ley 164) | Certificación digital |
| **Marketplace de Apps** | Repositorio interno de Apps bChat por tenant: RRHH instala "Solicitud de Vacaciones", Finanzas instala "Aprobación de Gastos" | Mini-Programs Marketplace |

### Entregables

| ID | Entregable | Tipo |
|----|-----------|------|
| E4.01 | Primera bChat App: "Aprobación de Factura" — recibe notificación, revisa, aprueba/rechaza | App Deno |
| E4.02 | Cuentas oficiales: `@finanzas`, `@rrhh`, `@soporte` con broadcast restringido por rol | Infra |
| E4.03 | Wallet bChat: consulta de saldo Tryton desde el chat | App Deno |
| E4.04 | Wallet bChat: envío de dinero entre usuarios (demo interno, sin liquidez real) | App Deno |
| E4.05 | Firma digital: "Firmar documento" → Vault → ADSIB → PDF firmado | App Deno |
| E4.06 | Átomos `D3.bchat.wallet.*` para gobernar operaciones financieras desde el chat | DDL |
| E4.07 | Átomos `D13.bchat.firma.*` para gobernar firma digital desde el chat | DDL |
| E4.08 | Pipeline de auditoría de alto volumen: clase A/B/C + Merkle batch + almacenamiento frío | Código |
| E4.09 | Dashboard de uso de bChat: usuarios activos, mensajes/día, canales, apps instaladas | Infra |

### Criterio de salida
- [ ] Usuario aprueba una factura desde bChat sin salir de la app
- [ ] Usuario firma un PDF con validez legal desde bChat
- [ ] `@finanzas` emite broadcast que solo usuarios con átomo `D3.finanzas.READ` reciben
- [ ] Wallet muestra saldo real desde Tryton en < 2s
- [ ] Pipeline de auditoría procesa ≥ 1000 eventos/s en clase B sin degradación
- [ ] 100% de eventos de moderación y finanzas son clase A (WORM individual)

---

## ETAPA 5 — ESCALA Y PRODUCCIÓN (16+ semanas)

**Objetivo:** bChat en producción multi-tenant. 50K usuarios concurrentes. Alta
disponibilidad. Recuperación ante desastres. Certificación ISO 27001.

### Entregables

| ID | Entregable |
|----|-----------|
| E5.01 | MongoDB replicaset 3 nodos con backup a MinIO S01 |
| E5.02 | bChat escalado horizontalmente (3+ pods con sticky sessions vía Kong) |
| E5.03 | Redis cluster para plano de sesión (validación ctx_id < 5ms P99 a 50K concurrentes) |
| E5.04 | Particionamiento temporal de `aud_event` por mes |
| E5.05 | Pruebas de carga: 50K WebSockets concurrentes, 2000 msg/s, < 5s entrega notificación |
| E5.06 | DR plan: recuperación de bChat desde backup en < 1 hora |
| E5.07 | Certificación ISO 27001:2022 A.8.15 (logging) + A.5.15-18 (access control) para bChat |
| E5.08 | Documentación de operador: instalación, monitoreo, troubleshooting, upgrade |

---

## RESUMEN DE ETAPAS

| Etapa | Nombre | Duración | Entregables | Estado |
|-------|--------|:--------:|:-----------:|:------:|
| **0** | Cimientos | Julio 2026 | 11 documentos + fichas + esqueleto Rust | ⏳ EN PROGRESO |
| **1** | Chat básico | 1-2 sem | Rocket.Chat 8.5.0 + OIDC + bnotify health | ⏳ |
| **2** | Identidad gobernada | 2-4 sem | bAuth reemplaza EE + átomos bchat.* + reconcile loop | ⏳ |
| **3** | Negocio integrado | 4-8 sem | Notificaciones ERP + calendario + MFA + alertas seguridad | ⏳ |
| **4** | Super-app | 8-16 sem | bChat Apps + Wallet + Firma digital + Cuentas oficiales | ⏳ |
| **5** | Escala y producción | 16+ sem | Multi-tenant 50K + HA + DR + ISO 27001 | ⏳ |

---

## LO QUE NO ESTÁ EN ESTE ROADMAP

- **IA conversacional dentro de bChat** — eso es responsabilidad de bSearch/bCompass (S09), no de bnotify
- **E2EE (End-to-End Encryption)** — Rocket.Chat no soporta E2EE nativo. Si se requiere, se evalúa en Etapa 5 con Signal Protocol o MLS (RFC 9420)
- **Federación con otros servidores Rocket.Chat** — bChat es intra-SBOS. La federación externa no es prioridad
- **Voice/Video calls** — Rocket.Chat 8.x lo soporta vía WebRTC. Se habilita bajo demanda, no es parte del roadmap base

---

*Roadmap bChat · BnotifyAgent/context/ · 2026-07-05*
*Este documento se actualiza al completar cada etapa. Las fechas son estimaciones.*
