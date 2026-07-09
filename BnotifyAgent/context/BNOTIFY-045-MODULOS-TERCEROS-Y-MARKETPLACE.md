---
codigo: BNOTIFY-045
version: 1.0.0
estado: BORRADOR
gate: G4
depende_de: [BNOTIFY-040, BNOTIFY-041, BNOTIFY-042]
doctrina_que_ejerce: [D2, D6, D12, D14, D15]
criterio_implementado: >
  Un desarrollador externo puede crear un módulo siguiendo el SDK (BNOTIFY-041).
  El módulo pasa el proceso de revisión y firma por SKULL.
  El módulo se instala en un tenant de prueba y funciona correctamente.
  El módulo es revocado y el motor lo descarga en < 5 segundos.
  Verificado con verificar_afirmacion.sh en VPS.
---

# BNOTIFY-045 — Módulos de Terceros y Marketplace
## Apertura a terceros: SDK, revisión, versionado, distribución y revocación

**Versión:** 1.0.0 · **Gate:** G4 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-040 (manifiesto y catálogo), BNOTIFY-041 (runtime WASM)

---

## 1. Apertura controlada

bChat es un sistema soberano — los datos del cliente **nunca salen de su servidor**. Abrirlo a módulos de terceros sin control podría romper esa garantía. Por eso:

- **SKULL es el único firmante de módulos:** ningún módulo se instala sin haber sido revisado y firmado por SKULL
- **El WASM sandbox garantiza aislamiento:** incluso si un módulo tiene código malicioso, el sandbox WASM impide el acceso a datos fuera de sus capacidades declaradas
- **Capacidades mínimas:** el módulo declara qué capacidades necesita; SKULL verifica que las capacidades son coherentes con la funcionalidad declarada
- **Revocación inmediata:** SKULL puede revocar un módulo y el motor lo descarga en segundos

---

## 2. Proceso de publicación de un módulo de tercero

```
Desarrollador externo
│
│  1. Desarrolla el módulo usando bchat-module-sdk (BNOTIFY-041 §6)
│  2. Compila con: cargo build --target wasm32-wasi --release
│  3. Crea module.toml con su manifiesto
│  4. Envía a SKULL: { wasm_binary, module.toml, documentación }
│     Vía: developer.sbos.cl (portal de desarrolladores — futura)
│
▼
SKULL — Proceso de revisión
│  1. Revisión de seguridad:
│     - Verificar que las capacidades declaradas son coherentes con la funcionalidad
│     - Análisis estático del WASM: wasm-validate, custom lints
│     - Revisión de la documentación del módulo
│  2. Prueba funcional en sandbox:
│     - Instalar en tenant de prueba
│     - Verificar que el módulo hace lo que dice
│  3. Si aprobado:
│     - Firmar el binario con la clave Ed25519 de SKULL
│     - Agregar al catálogo público con state = 'ACTIVE'
│  4. Si rechazado:
│     - Notificación al desarrollador con motivo detallado
│     - El desarrollador puede corregir y re-enviar
│
▼
Distribución
│  - El módulo firmado se sube a MinIO del catálogo público SBOS
│  - Los tenants pueden instalarlo desde el marketplace
```

---

## 3. Marketplace de módulos

El marketplace es una lista de módulos aprobados y firmados disponibles para instalar:

```sql
-- Catálogo público (compartido entre todos los tenants)
-- Schema: bnotify, tabla: module_marketplace

CREATE TABLE bnotify.module_marketplace (
    id              UUID    NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    module_id       TEXT    NOT NULL UNIQUE,
    name            TEXT    NOT NULL,
    description     TEXT    NOT NULL,
    author          TEXT    NOT NULL,
    category        TEXT    NOT NULL,  -- 'productividad', 'rrhh', 'finanzas', etc.
    version         TEXT    NOT NULL,
    wasm_s3_key     TEXT    NOT NULL,
    wasm_sha256     TEXT    NOT NULL,
    signature_ed25519 TEXT  NOT NULL,
    manifest_toml   TEXT    NOT NULL,

    -- Estadísticas (no personales — solo contadores)
    install_count   BIGINT  NOT NULL DEFAULT 0,
    rating_avg      NUMERIC(3,2) NULL,

    published_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Revocación
    revoked         BOOLEAN NOT NULL DEFAULT FALSE,
    revoked_at      TIMESTAMPTZ NULL,
    revoke_reason   TEXT    NULL
);
```

---

## 4. Instalación de un módulo de tercero por un tenant

Un administrador del tenant instala el módulo desde la UI de administración bChat:

```
Admin del tenant
│
│  bchat.admin.module.install({ marketplace_module_id, tenant_id })
│
▼
Motor bChat
│  1. Verificar que el admin tiene átomo D6.module.INSTALL en bAuth
│  2. Descargar módulo desde marketplace MinIO
│  3. Verificar SHA256 + firma Ed25519
│  4. Copiar a MinIO del tenant
│  5. Crear registro en bnotify.module_catalog con state = 'PENDING_REVIEW'
│  6. Notificar al admin que requiere aprobación final
│
▼
Admin del tenant (o un aprobador designado)
│
│  bchat.admin.module.approve({ module_catalog_id })
│
▼
Motor bChat
│  → state = 'ACTIVE'
│  → Carga el módulo en wasmtime
│  → El módulo está disponible para usuarios del tenant
```

---

## 5. Revocación de módulos

La revocación puede ser iniciada por SKULL (revocación global) o por el admin del tenant (revocación local):

### 5.1 Revocación global (SKULL)

Cuando SKULL revoca un módulo:
1. `module_marketplace.revoked = TRUE`
2. Se publica evento NATS: `bnotify.module.revoked.global.{module_id}`
3. Todos los motores bChat con el módulo activo lo descargan en < 5 segundos
4. `module_catalog.state = 'REVOKED'` en todos los tenants

### 5.2 Revocación local (admin del tenant)

El admin puede desactivar un módulo solo en su tenant sin que afecte a otros:
1. `module_catalog.state = 'DISABLED'` para ese `tenant_id`
2. El motor descarga el módulo para ese tenant
3. Los datos generados por el módulo permanecen en la base de datos

---

## 6. Categorías de módulos del marketplace

| Categoría | Ejemplos de módulos |
|-----------|---------------------|
| Productividad | Recordatorios, gestión de tareas, notas |
| Recursos Humanos | Solicitudes de vacaciones, evaluaciones, encuestas |
| Finanzas | Aprobaciones de pago (se integra con bPay) |
| Atención al cliente | Extensiones del módulo base BNOTIFY-042 |
| Integraciones SBOS | Conectores con bHR, bERP, bCRM |
| Herramientas de equipo | Polls, planificadores, retrospectivas |

---

*BNOTIFY-045 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*La soberanía no es aislamiento — es control. SKULL firma, el tenant instala, el sandbox aísla. Cada uno hace su parte.*
