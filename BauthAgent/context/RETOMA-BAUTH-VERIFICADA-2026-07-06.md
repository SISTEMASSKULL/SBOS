# RETOMA-BAUTH — Memoria Canónica Verificada
**Versión:** 1.0 · **Fecha:** 2026-07-06 · **Autor:** Bibliotecario (auditado, no auto-reportado)
**Propósito:** Esta es la ÚNICA fuente de verdad para la retoma del agente bauth.
Cualquier RETOMA escrita por el propio agente es secundaria y debe contrastarse con esta.

---

## REGLA NUEVA — Memoria de agente verificada

**Ningún agente escribe su propia memoria de cierre sin auditoría.**
El Bibliotecario (o el Revisor por delegación) verifica el estado real en disco
y escribe la retoma canónica. El auto-reporte del agente se ignora.

---

## 1. QUÉ SE HIZO REALMENTE (verificado en disco)

### Documentación generada en BnotifyAgent/context/ (35 archivos, 7,829 líneas)

Estado: **TODO en BORRADOR. Cero código implementado.**

| # | Documento | Líneas | Tema |
|---|-----------|:------:|------|
| 000 | DOCTRINA-Y-PLAN-MAESTRO | 455 | 18 principios D1-D18, arquitectura bNotify/bRocket/bChat |
| 001 | CONTRATO-GRPC | 311 | Proto NotifyDispatcher + AdapterChannel |
| 002 | BAUTH-OIDC | 316 | 5 endpoints OIDC, claims JWT, CONSUMER_MOBILE |
| 003 | BROCKET-DESPLIEGUE | 301 | Rocket.Chat 8.5.0 como solución interina |
| 004 | MODELO-EVENTOS | 257 | Taxonomía eventos, clases A/B/C, pipeline Merkle |
| 005 | NAVEGADOR | — | Índice de navegación entre documentos |
| 006 | STACK-TECNOLOGICO | — | Versiones fijadas (Rust 1.85, Flutter 3.27, etc.) |
| 007 | ADRs | 336 | 9 ADRs retro-documentados en formato MADR |
| 008 | DDL-ESQUEMAS | 369 | Esquemas PostgreSQL, vistas cruzadas, GRANTs |
| 009 | GLOSARIO | 297 | Ontología del proyecto |
| 010 | NUCLEO-ORQUESTADOR | 340 | Arquitectura Rust del dispatcher central |
| 011 | CANAL-CHAT | — | Adaptador chat, excepción HTTP documentada |
| 012 | CANAL-EMAIL | — | Adaptador email |
| 013 | CANAL-SMS | — | Adaptador SMS |
| 014 | CANAL-PUSH | — | Adaptador push (FCM/APNs) |
| 015 | CANAL-WEBHOOK | — | Adaptador webhook hacia exterior |
| 030 | BCHAT-PROTOCOLO | 350 | Protocolo cliente bChat |
| 031 | BCHAT-ESQUEMA | 253 | Esquema de datos de bChat |
| 032 | BCHAT-MOTOR-RUST | — | Motor bChat en Rust |
| 033 | BCHAT-CLIENTE-FLUTTER | 203 | Cliente Flutter multi-plataforma |
| 034 | BCHAT-MEDIA | — | Gestión de medios (S3) |
| 035 | BCHAT-LIVEKIT | — | WebRTC/LiveKit para videollamadas |
| 036 | MIGRACION-BROCKET | — | Plan de migración bRocket→bChat |
| 040 | MODULOS-MANIFIESTO | — | Sistema de módulos declarativos |
| 041 | MODULOS-WASM | — | Runtime WASM para extensiones |
| 042 | MODULO-ATENCION | — | Módulo de atención al cliente |
| 043 | MODULOS-FORMULARIOS | — | Motor de formularios |
| 044 | MODULO-CORREO | — | Módulo de correo integrado |
| 060 | E2EE-MLS | — | MLS/RFC 9420, OpenMLS, sin cripto propia |
| 061 | ANTIABUSO | — | Anti-abuso y moderación |
| 062 | KYC-TIERS | — | Niveles KYC y valor |
| 070 | CAPACIDAD | — | Pruebas de carga, modelo de capacidad |
| 071 | OPERACIONES-K8S | 232 | Despliegue K8s |
| 090 | GOBERNANZA | 200 | Gobernanza documental y de agentes |

### Contrato generado
- `context/contracts/BAUTH-BNOTIFY-CONTRATOS.md` — 462 líneas, 8 contratos (4 bAuth→bNotify, 4 bNotify→bAuth), append-only

### Auditoría del Revisor (2026-07-06)
- **35/35 documentos clasificados VALIOSOS** — contenido coherente, bien investigado, sin inflación
- **Cero afirmaciones falsas verificables** — los `criterio_implementado` son aspiracionales, los docs están honestamente marcados BORRADOR
- **Tensión con C11:** gRPC como protocolo primario sin paridad completa (requiere ADR de desviación)

---

## 2. QUÉ NO SE HIZO (y bauth podría afirmar falsamente)

- ❌ **No hay código.** Cero archivos .rs, .go, .proto creados en BnotifyAgent/src/
- ❌ **No hay migraciones SQL ejecutadas.** `0001_bnotify_core.sql` no existe
- ❌ **No hay compilación verificada.** `cargo check` nunca se ejecutó en BnotifyAgent
- ❌ **No hay VPS de staging.** Ninguna verificación se ejecutó en entorno real
- ❌ **Mattermost no fue eliminado.** ~30 archivos aún lo referencian en BauthAgent

---

## 3. PENDIENTE REAL (próxima sesión)

### Etapa 0 — Entregables NO completados:

| ID | Entregable | Estado |
|----|-----------|--------|
| E0.01 | BNOTIFY-000 (doctrina) | ✅ BORRADOR — requiere HITL review |
| E0.02 | BNOTIFY-002 (visión v3) | ✅ BORRADOR |
| E0.03 | BNOTIFY-003 (roadmap) | ✅ BORRADOR |
| E0.04 | Arquitectura del daemon | ✅ BNOTIFY-001/010 en BORRADOR |
| E0.05 | Integración bnotify↔bChat | ✅ BNOTIFY-011 en BORRADOR |
| E0.06 | Contrato bilateral | ✅ BAUTH-BNOTIFY-CONTRATOS.md en BORRADOR |
| E0.07 | Ficha bChat v8.5.0 | ❌ PENDIENTE |
| E0.08 | Esqueleto Rust bnotify | ❌ PENDIENTE (Cargo.toml + main.rs) |
| E0.09 | PROPOSITO.md actualizado | ❌ PENDIENTE |
| E0.10 | CLAUDE.md actualizado | ❌ PENDIENTE |
| E0.11 | Eliminar Mattermost | ❌ PENDIENTE (~30 archivos) |
| E0.12 | ADR desviación C11 | ❌ PENDIENTE (gRPC primario vs Interface Triple) |

---

## 4. ESTADO DEL SISTEMA

- **Coordinador:** activo `:8095`, 0 tareas en grafo
- **UUID proyecto SBOS:** `4c697f66-d204-45a5-ac36-c104f07c7046`
- **Modelo actual:** Claude Sonnet (MODEL_ROUTER_POLICY=production)
- **Último commit SBOS:** `646d9da docs(bnotify): inicializar BnotifyAgent con vision bChat multi-canal`

---

## 5. PROTOCOLO DE RETOMA PARA EL PRÓXIMO AGENTE

Al iniciar sesión, el agente bauth DEBE:
1. Leer ESTE archivo primero (no su propio auto-reporte)
2. Leer `BNOTIFY-000-DOCTRINA-Y-PLAN-MAESTRO.md` (la doctrina bNotify)
3. **Revisar TODA la documentación de bNotify:** los 35 archivos en `BnotifyAgent/context/` — entender la arquitectura completa antes de tocar código
4. **Revisar TODA la documentación de reparación de bauth:** `BauthAgent/context/plandeaccion/REPARACIONBAUTH/` — ~33 documentos de diseño de bAuth que deben completarse
5. **Objetivo principal: completar la documentación de reparación de bauth** usando la información de bNotify como referencia cruzada. La reparación de bauth es prioridad sobre la implementación de bNotify
6. Verificar en disco: `find BnotifyAgent/src -name "*.rs" | wc -l` — debe retornar 0
7. Verificar en disco: `find . -name "*.proto" | grep bnotify` — debe retornar 0
8. C12 obligatorio: toda afirmación con `verificar_afirmacion.sh`
9. **No escribir su propia retoma.** El Bibliotecario la escribe al auditar

### Orden de lectura recomendado

```
Paso 1 — Doctrina bNotify:
  BnotifyAgent/context/BNOTIFY-000-DOCTRINA-Y-PLAN-MAESTRO.md

Paso 2 — Estado actual de bauth:
  BauthAgent/context/plandeaccion/REPARACIONBAUTH/REGISTRO-ESTADO-BAUTH-PRINCIPAL.md
  BauthAgent/context/plandeaccion/REPARACIONBAUTH/INDICE-NAVEGACION.md

Paso 3 — Documentos de diseño de bauth a completar:
  BauthAgent/context/plandeaccion/REPARACIONBAUTH/*.md (~33 archivos)

Paso 4 — Contratos bilaterales:
  context/contracts/BOS-BAUTH-CONTRATOS.md
  context/contracts/BAUTH-BNOTIFY-CONTRATOS.md
```

---

## 6. REGISTRO EN SKDATA

```sql
INSERT INTO memoria.bitacora_agente (agente_id, sesion_fecha, donde_quede, que_falta)
VALUES ('bauth', '2026-07-06', 'Etapa 0 completada en documentación (35 archivos, 7829 líneas). Todo en BORRADOR. Cero código.',
        'E0.07-E0.12: ficha bChat, esqueleto Rust, actualizar PROPOSITO/CLAUDE, eliminar Mattermost, ADR C11');
```

---
*Memoria canónica escrita por el Bibliotecario · 2026-07-06 · Verificada contra disco*
*Este archivo reemplaza cualquier RETOMA auto-reportada por el agente bauth*
