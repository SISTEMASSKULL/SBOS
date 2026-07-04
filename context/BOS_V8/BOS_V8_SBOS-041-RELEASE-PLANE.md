# SBOS-041-RELEASE-PLANE
## Sistema de Distribucion Soberana — Estandar HUMAN-DOC
### SKULL · SBOS · V8 Enriquecido · Mayo 2026

---

## 1. Proposito

SKULL Release Plane: infraestructura que compila, firma y distribuye versiones del daemon bos, daemons soberanos y catalogo de fichas. Principio: **pull-only** — el cliente siempre tira, SKULL nunca empuja.

## 2. Arquitectura Release Server

```
/releases/
├── bos/
│   └── 0.9.3/ (iam-installer-amd64, arm64, checksums.sha256, .sig, changelog)
│   └── latest.json
├── bkernel/ (misma estructura)
├── fichas/
│   ├── catalog.json + catalog.json.sig
│   └── servers/ (dataserver/postgresql.tar.gz, ...)
└── channels/
    ├── canary.json
    ├── early.json
    └── stable.json

API:
  GET /api/v1/releases/latest?channel=X
  GET /api/v1/fichas/catalog
  GET /api/v1/rollout/wave/{channel}
```

### Enriquecimiento V5: Detalle de versiones y changelog

El catalogo de fichas incluye metadatos adicionales de versionado:

```json
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

### Enriquecimiento Smart Portfolio: Pipeline de entrega continua

El subproyecto Smart Portfolio define un pipeline de ingesta y procesamiento que se integra con el Release Plane para la distribucion de artefactos. El pipeline Smart Portfolio (SBOS-Portfolio-013) usa FastAPI para POST /ingesta/upload con validacion de tamano, tipo, y acceso de usuario, almacenando en MinIO y encolando tareas Celery. Este pipeline se sincroniza con el Release Plane para que las fichas de producto se distribuyan a traves de los mismos canales canary/early/stable.

El Release Plane de SKULL actua como el bus de distribucion unico: todos los artefactos generados por pipelines Smart* pasan por el mismo protocolo de firma Ed25519 y los mismos canales de rollout. La version del catalogo de fichas (fichas_catalog) se incrementa con cada actualizacion de productos Smart*.

## 3. Protocolo Ed25519

### Firma (SKULL pipeline)
```
1. make release VERSION=0.9.3
2. Generar checksums.sha256 de todos los artefactos
3. ed25519_sign(private_key, checksums.sha256) → .sig
4. Publicar artefactos + firma en Release Server
Clave privada: solo en SKULL CI/CD (HSM o Vault)
Clave publica: /etc/bos/skull-release.pub en cada cliente
```

### Verificacion (cliente)
```
1. Descargar binario + checksums + sig
2. ed25519_verify(public_key, checksums, sig)
   INVALIDA → ABORT + alerta "signature_verification_failed"
   VALIDA → verificar SHA-256 binario vs checksums
   MATCH → proceder con instalacion
```

### Enriquecimiento V5: Pipeline detallado de firma

```
SKULL genera keypair Ed25519:
  Clave privada: solo en SKULL CI/CD pipeline (HSM o Vault)
  Clave publica: distribuida en cada instalacion (/etc/bos/skull-release.pub)

Pipeline de firma:
  1. make release VERSION=0.9.3
  2. Generar checksums.sha256 de todos los artefactos
  3. Firmar: ed25519_sign(private_key, checksums.sha256) → checksums.sha256.sig
  4. Publicar artefactos + firma en Release Server
```

El RELEASE_MANAGER del daemon bos ejecuta la verificacion:
  1. GET /api/v1/releases/latest?channel=canary
  2. Si hay nueva version:
     a. Descargar binario + checksums.sha256 + checksums.sha256.sig
     b. Verificar firma: ed25519_verify(public_key, checksums.sha256, sig)
     c. SI INVALIDA → ABORT + alerta "signature_verification_failed"
     d. SI VALIDA → verificar SHA-256 del binario contra checksums
     e. SI MATCH → proceder con instalacion

## 4. Canales de Rollout

| Canal | Audiencia | Delay | Rollback |
|---|---|---|---|
| canary | 1-3 clientes piloto (SKULL interno) | 0 dias | Automatico 5 min |
| early | Clientes con riesgo moderado aceptado | 7 dias post-canary sin incidentes | Auto + manual |
| stable | Todos los clientes produccion | 14 dias post-early sin incidentes | Manual con aprobacion |

### Formato canal
```json
{
  "channel": "canary",
  "current_version": "0.9.3",
  "min_version": "0.9.0",
  "components": {
    "bos": { "version": "0.9.3", "url": "/releases/bos/0.9.3/" },
    "bkernel": { "version": "1.2.0" },
    "fichas_catalog": { "version": "2026.03.14" }
  }
}
```

### Enriquecimiento V5: Formato extendido de canal

```json
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

## 5. Catalogo de Fichas

```json
{
  "version": "2026.03.14",
  "fichas": [
    { "id": "postgresql", "version": "18.0", "server": "dataserver", "checksum": "sha256:..." },
    { "id": "keycloak", "version": "26.1", "server": "identityserver", "checksum": "sha256:..." }
  ],
  "total_fichas": 96
}
```

## 6. Proceso de Upgrade en Cliente

```
RELEASE_MANAGER loop (cada 6 horas):
  GET /api/v1/releases/latest?channel={mi_canal}
  ¿Nueva version? NO → sleep | SI ↓
  Descargar + verificar Ed25519 + SHA-256
  ¿auto_update en bos.toml? NO → notificar admin | SI ↓
  Backup binario → iam-installer.prev
  Instalar nuevo → systemctl restart bos
  ExecStartPost: bosctl health --wait-stable=60
    OK → update exitoso, limpiar .prev despues 7 dias
    FAIL → rollback automatico a .prev
  Registrar en STATE_MANAGER
```

### Enriquecimiento V5: Proceso de upgrade detallado con STATE_MANAGER

```
RELEASE_MANAGER loop (cada 6 horas):
  │
  ├── GET /api/v1/releases/latest?channel={mi_canal}
  │
  ├── ¿Nueva version disponible?
  │     NO → sleep hasta proximo check
  │     SI → continuar
  │
  ├── Descargar + verificar Ed25519 + SHA-256
  │
  ├── ¿auto_update habilitado en bos.toml?
  │     NO → notificar admin via Core UI/Centrifugo
  │     SI → proceder con actualizacion automatica
  │
  ├── Backup binario actual → iam-installer.prev
  ├── Instalar nuevo binario
  ├── systemctl restart bos
  │
  ├── ExecStartPost: bosctl health --wait-stable=60
  │     OK → update exitoso, limpiar .prev despues de 7 dias
  │     FAIL → rollback automatico a .prev
  │
  └── Registrar en STATE_MANAGER:
      release.current_version = nueva
      release.prev_version = anterior
```

## 7. Integracion con Smart Portfolio Pipeline

El Release Plane se integra con el pipeline de Smart Portfolio (SBOS-Portfolio-013) de la siguiente manera:

1. **Ingesta de artefactos:** Los PDFs procesados por el pipeline Smart Portfolio (clasificacion por pypdf, procesamiento por pagina con Docling/MinerU, extraccion con Camelot/tabula) producen fichas de configuracion que deben distribuirse a traves del Release Plane.
2. **Firma de artefactos Smart*:** Todos los artefactos generados por subproyectos Smart* se firman con Ed25519 a traves del mismo pipeline de release, garantizando integridad y trazabilidad.
3. **Canales de rollout unificados:** Los productos Smart* (SmartTax, SmartReport, SmartRates, etc.) siguen el mismo esquema de canales canary/early/stable que el bos y los daemons soberanos.

## 8. Seguridad del Pipeline de Distribucion

| Aspecto | Medida |
|---|---|
| Clave privada | Solo en HSM/Vault del CI/CD de SKULL |
| Clave publica | /etc/bos/skull-release.pub en cada cliente |
| Firma | Ed25519 de todos los checksums |
| Verificacion | IAM Installer verifica antes de ejecutar |
| Rollback automatico | En fallo post-upgrade, restaura .prev |
| Notificacion admin | Si auto_update=false, alerta via Core UI/Centrifugo |

---

## Trazabilidad

| Seccion | Extraida de | Secciones originales |
|---|---|---|
| §1-2 | SBOS-038 v1.0 | §1-§2 (proposito, arquitectura Release Server con estructura dirs) |
| §3 Ed25519 | SBOS-038 v1.0 | §3 (firma pipeline + verificacion cliente) |
| §4 Canales | SBOS-038 v1.0 | §4 (3 canales con delay/rollback + formato JSON) |
| §5 Catalogo | SBOS-038 v1.0 | §5 (formato catalog.json con fichas) |
| §6 Upgrade | SBOS-038 v1.0 | §6 (loop 6h, auto_update, rollback, STATE_MANAGER) |

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Aportacion |
|---|---|---|
| V5 | /opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-038-RELEASE-PLANE-v1_0.md | Pipeline detallado de firma, formato extendido de canal con changelog_url, proceso upgrade con STATE_MANAGER, metadatos adicionales en catalogo |
| Smart Portfolio | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Portfolio/context/SBOS-Portfolio-013-PIPELINE.md | Pipeline de ingesta FastAPI/Celery, clasificacion de PDFs, procesamiento por pagina, integracion con Release Plane para distribucion de artefactos Smart* |
| Correlacion V8 | Consolidacion de patrones | Canales de rollout unificados para todos los productos SKULL incluyendo Smart*; seccion de seguridad del pipeline de distribucion |

---

_SKULL · SBOS · SBOS-041-RELEASE-PLANE · V8 Enriquecido · Mayo 2026_
