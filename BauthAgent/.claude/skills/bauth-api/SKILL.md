---
name: bauth-api
description: >
  La superficie JSON-RPC de bAuth: ~147 métodos organizados por dominio/motor bajo el
  namespace `bauth.*`. Úsala cuando implementes, corrijas o verifiques un método RPC,
  necesites conocer la firma de un método existente, o quieras añadir un método nuevo
  siguiendo la convención de nomenclatura y estructura de servidor (3 capas).
---

# Skill — bAuth: API JSON-RPC

**Referencias principales:**
- `context/Documentacion/9.02_MANUAL-REFERENCIA-API-v1.0.md` — catálogo de ~141 métodos por plano
- `context/Documentacion/anexos/A.19_ANEXO-SUPERFICIE-JSONRPC-REAL-v1.0.md` — superficie real verificada en código
- `context/Documentacion/anexos/A.16_ANEXO-PROTOCOLOS-JSONRPC-v1.0.md` — protocolo JSON-RPC 2.0 en bAuth
- Doctrina JSON-RPC de la fábrica: `context-fabrica/doctrina/json-RPC/` (9 partes, 304 KB) — **leer antes de diseñar cualquier método**

---

## 1 · Namespace y convención de nomenclatura

**Todo método de bAuth sigue:** `bauth.<dominio>.<accion>`

| Nivel | Ejemplo | Notas |
|-------|---------|-------|
| Namespace raíz | `bauth.*` | Solo bAuth expone métodos en este namespace |
| Dominio/motor | `bauth.identity.*` `bauth.auth.*` `bauth.policy.*` | Un grupo por motor o dominio lógico |
| Acción | `bauth.identity.create_user` | Verbo en snake_case |

**Lectura obligatoria antes de diseñar un método:** fábrica `ORQUESTA-043` + Partes 1 (fundamentos) y 6 (errores) del manual JSON-RPC.

---

## 2 · Planos de la API (9.02)

La referencia API organiza los ~141 métodos en planos:

| Plano | Prefijo | Contenido |
|-------|---------|-----------|
| **Identidad** | `bauth.identity.*` | CRUD de usuarios, templates, atributos |
| **Roles** | `bauth.role.*` | CRUD roles, asignaciones, DAG, SoD |
| **Átomos** | `bauth.atom.*` | Catálogo de permisos atómicos |
| **Autenticación** | `bauth.auth.*` | Login, step-up, sesiones, métodos |
| **Políticas** | `bauth.policy.*` | PDP — evaluar, gestionar reglas |
| **Tokens** | `bauth.token.*` | Emit, validate, revoke JWT |
| **Firma** | `bauth.sign.*` | Firma de documentos Ed25519 / ADSIB |
| **Auditoría** | `bauth.audit.*` | Consulta WORM, trazabilidad |
| **Administración** | `bauth.admin.*` | Configuración, tenants, IDPs |
| **Operación** | `bauth.ops.*` | Health, reconcile, bootstrap |

---

## 3 · Arquitectura del servidor — 3 capas (ORQUESTA-043 Parte 5)

```
Transport  ←  recibe JSON-RPC sobre Unix socket (WebSocket-RPC o raw JSON-RPC 2.0)
    ↓
Dispatcher ←  despacha por namespace a la capa Domain
    ↓
Domain     ←  implementa la lógica; produce result/error estricto de protocolo
```

**Reglas:**
- El Transport NUNCA contiene lógica de negocio.
- El Domain NUNCA toca el socket directamente.
- El Dispatcher NUNCA mezcla errores de protocolo con errores de aplicación.
- Errores de protocolo: `-32700` (parse) · `-32600` (request) · `-32601` (method not found) · `-32602` (params) · `-32603` (internal)
- Errores de aplicación: `bauth.*` (rango > `-32000`), definidos por dominio.

---

## 4 · Cómo verificar un método existente

```bash
# 1. Buscar el método en el código
grep -r "\"bauth\.<dominio>\.<accion>\"" src/ --include="*.rs"

# 2. Verificar que tiene handler en el Dispatcher
grep -r "register.*bauth\.<dominio>\.<accion>" src/ --include="*.rs"

# 3. Verificar que el response sigue el schema definido en A.19
# (comparar con la sección del anexo correspondiente)

# 4. Ejecutar la prueba CLI si existe
# Ver: context/Documentacion/7.04_MANUAL-CLI-PRUEBAS-EXTERNAS-v1.0.md
# y: context/Documentacion/anexos/A.39_ANEXO-CLI-PRUEBAS-v1.0.md
```

---

## 5 · Cómo añadir un método nuevo

1. **Determinar el plano** (§2) al que pertenece el método.
2. **Nombrar** siguiendo `bauth.<plano>.<verbo_snake_case>`.
3. **Leer** el manual del motor correspondiente (`bauth-motores` skill) antes de implementar.
4. **Implementar en 3 capas** (§3): Domain → Dispatcher → (Transport ya existe).
5. **Definir el schema** de params + result en JSON Schema.
6. **Añadir test** unitario + test de integración CLI.
7. **Actualizar** `9.02_MANUAL-REFERENCIA-API-v1.0.md` con la nueva entrada.
8. **Verificar** con `scripts/verificar_afirmacion.sh` antes de afirmar que funciona (C12).

---

## 6 · Protocolo JSON-RPC 2.0 — recordatorio

```json
// Request
{"jsonrpc":"2.0","id":"<uuid>","method":"bauth.auth.login","params":{...}}

// Response éxito — HTTP 200 siempre
{"jsonrpc":"2.0","id":"<uuid>","result":{...}}

// Response error — HTTP 200 también (el error va en el body)
{"jsonrpc":"2.0","id":"<uuid>","error":{"code":-32001,"message":"...","data":{...}}}
```

**NUNCA HTTP 4xx/5xx para errores de negocio** — siempre HTTP 200 con `error` en el body (ORQUESTA-043 Parte 6).

---

## 7 · Herramienta OIDC Provider

**Manual:** `context/Documentacion/anexos/A.20_ANEXO-OIDC-PROVIDER-v1.0.md`  
bAuth actúa como OIDC Provider (sin Keycloak — ADR-010). Los flujos OIDC se implementan en el motor de Métodos y exponen endpoints en el plano `bauth.oidc.*`.

---

## 8 · Superficie real verificada (A.19)

`anexos/A.19_ANEXO-SUPERFICIE-JSONRPC-REAL-v1.0.md` contiene la lista de métodos verificados contra el código real con estado: ✅ implementado · ⚠️ parcial · ❌ no existe.  
**Leer este anexo antes de asumir que un método existe.**
