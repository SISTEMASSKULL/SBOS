# SBOS-038-RELEASE-PLANE
## SKULL Release Plane: Sistema de Distribución Soberana
### SP-16 · Gestión de Versiones del Stack

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

## 1. Propósito

El SKULL Release Plane es la infraestructura de SKULL que compila, firma y distribuye versiones del daemon bos, de los daemons soberanos, y del catálogo de fichas a todos los clientes. Opera bajo el principio **pull-only**: el cliente siempre tira, SKULL nunca empuja.

---

## 2. Arquitectura del Release Server

```
SKULL INFRAESTRUCTURA
┌─────────────────────────────────────────────┐
│            SKULL Release Server              │
│                                             │
│  /releases/                                 │
│    ├── bos/                                 │
│    │   ├── 0.9.3/                           │
│    │   │   ├── iam-installer-amd64          │
│    │   │   ├── iam-installer-arm64          │
│    │   │   ├── checksums.sha256             │
│    │   │   ├── checksums.sha256.sig         │
│    │   │   └── changelog.md                 │
│    │   └── latest.json                      │
│    ├── bkernel/                             │
│    │   └── (misma estructura)               │
│    ├── fichas/                              │
│    │   ├── catalog.json                     │
│    │   ├── catalog.json.sig                 │
│    │   └── servers/                         │
│    │       ├── dataserver/postgresql.tar.gz │
│    │       └── ...                          │
│    └── channels/                            │
│        ├── canary.json                      │
│        ├── early.json                       │
│        └── stable.json                      │
│                                             │
│  API:                                       │
│    GET /api/v1/releases/latest?channel=X    │
│    GET /api/v1/fichas/catalog               │
│    GET /api/v1/rollout/wave/{channel}       │
└─────────────────────────────────────────────┘
```

---

## 3. Protocolo Ed25519

### 3.1 Firma

```
SKULL genera keypair Ed25519:
  Clave privada: solo en SKULL CI/CD pipeline (HSM o Vault)
  Clave pública: distribuida en cada instalación (/etc/bos/skull-release.pub)

Pipeline de firma:
  1. make release VERSION=0.9.3
  2. Generar checksums.sha256 de todos los artefactos
  3. Firmar: ed25519_sign(private_key, checksums.sha256) → checksums.sha256.sig
  4. Publicar artefactos + firma en Release Server
```

### 3.2 Verificación (en el cliente)

```
RELEASE_MANAGER del daemon bos:
  1. GET /api/v1/releases/latest?channel=canary
  2. Si hay nueva versión:
     a. Descargar binario + checksums.sha256 + checksums.sha256.sig
     b. Verificar firma: ed25519_verify(public_key, checksums.sha256, sig)
     c. SI INVÁLIDA → ABORT + alerta "signature_verification_failed"
     d. SI VÁLIDA → verificar SHA-256 del binario contra checksums
     e. SI MATCH → proceder con instalación
```

---

## 4. Canales de Rollout

| Canal | Audiencia | Delay | Rollback |
|-------|-----------|-------|----------|
| **canary** | 1-3 clientes piloto (SKULL interno) | 0 días | Automático en 5 min |
| **early** | Clientes que aceptan riesgo moderado | 7 días post-canary sin incidentes | Automático + manual |
| **stable** | Todos los clientes en producción | 14 días post-early sin incidentes | Manual con aprobación |

### 4.1 Formato de canal

```json
// /releases/channels/canary.json
{
  "channel": "canary",
  "current_version": "0.9.3",
  "released_at": "2026-03-14T00:00:00Z",
  "min_version": "0.9.0",
  "components": {
    "bos": { "version": "0.9.3", "url": "/releases/bos/0.9.3/" },
    "bkernel": { "version": "1.2.0", "url": "/releases/bkernel/1.2.0/" },
    "fichas_catalog": { "version": "2026.03.14", "url": "/releases/fichas/" }
  },
  "changelog_url": "/releases/bos/0.9.3/changelog.md"
}
```

---

## 5. Formato del Catálogo de Fichas

```json
// /releases/fichas/catalog.json
{
  "version": "2026.03.14",
  "generated_at": "2026-03-14T00:00:00Z",
  "fichas": [
    {
      "id": "postgresql",
      "version": "18.0",
      "server": "dataserver",
      "checksum": "sha256:abc123...",
      "size_bytes": 245760,
      "url": "/releases/fichas/servers/dataserver/postgresql.tar.gz"
    },
    {
      "id": "keycloak",
      "version": "26.1",
      "server": "identityserver",
      "checksum": "sha256:def456...",
      "size_bytes": 512000,
      "url": "/releases/fichas/servers/identityserver/keycloak.tar.gz"
    }
  ],
  "total_fichas": 96
}
```

---

## 6. Proceso de Upgrade en el Cliente

```
RELEASE_MANAGER loop (cada 6 horas):
  │
  ├── GET /api/v1/releases/latest?channel={mi_canal}
  │
  ├── ¿Nueva versión disponible?
  │     NO → sleep hasta próximo check
  │     SÍ → continuar
  │
  ├── Descargar + verificar Ed25519 + SHA-256
  │
  ├── ¿auto_update habilitado en bos.toml?
  │     NO → notificar admin via Core UI/Centrifugo
  │     SÍ → proceder con actualización automática
  │
  ├── Backup binario actual → iam-installer.prev
  ├── Instalar nuevo binario
  ├── systemctl restart bos
  │
  ├── ExecStartPost: bosctl health --wait-stable=60
  │     OK → update exitoso, limpiar .prev después de 7 días
  │     FAIL → rollback automático a .prev
  │
  └── Registrar en STATE_MANAGER:
      release.current_version = nueva
      release.prev_version = anterior
```

---

## 7. Registro de Cambios

### v1.0 — Marzo 2026

Documento nuevo. Arquitectura del Release Server, protocolo Ed25519 con firma y verificación, 3 canales de rollout (canary/early/stable), formato del catálogo de fichas, y proceso de upgrade con rollback automático.

---

*SKULL · SBOS · SBOS-038-RELEASE-PLANE · v1.0 · Marzo 2026*
