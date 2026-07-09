# BAUTH-D12-INFRAESTRUCTURA-BLOCKCHAIN — Decisiones de Infraestructura

**Versión:** 1.0.0 · **Fecha:** 2026-06-22 · **Autor:** sbos-coordinador  
**Propósito:** Documentar TODAS las decisiones de infraestructura para D12 Blockchain.

---

## 1. Principio Rector

**Cero instalaciones nuevas en el host.** Todo sigue el patrón SBOS:
- Componentes Rust → compilados estáticos en binarios MUSL
- Servicios externos → pods K8s vía fichas declarativas BOS
- Smart contracts → CI/CD (Forge en GitHub Actions)
- Host → solo `/usr/local/bin/{bauth, bauthctl, bos-verify}`

---

## 2. Stack Tecnológico D12

```
┌──────────────────────────────────────────────────────────────────────┐
│                         HOST (Ubuntu 26.04)                           │
│                                                                       │
│  ┌──────────────────────┐  ┌──────────────────────────────────────┐ │
│  │ bAuth (Rust MUSL)    │  │ bos-verify (Rust MUSL)               │ │
│  │ 3.5MB binario        │  │ 1.2MB binario                       │ │
│  │ + sha3 (Keccak-256)  │  │ + sha3 + hex                         │ │
│  │ + ethers-rs (PLAN)   │  │ Cero deps runtime                    │ │
│  │ + hex                │  │ Verificación offline/online          │ │
│  └──────────────────────┘  └──────────────────────────────────────┘ │
│                                                                       │
│  ┌──────────────────────┐                                           │
│  │ BOS (Go 1.22+)       │                                           │
│  │ + bosctl CLI          │                                           │
│  │ Administra K8s        │                                           │
│  └──────────────────────┘                                           │
└──────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ k3s cluster
                                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│                       KUBERNETES (k3s v1.32+)                         │
│                                                                       │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────┐ │
│  │ Besu QBFT          │  │ PostgreSQL 18.4    │  │ Redis 8.6.2    │ │
│  │ S12/blockchain/    │  │ S01/dataserver/    │  │ S01/dataserver/ │ │
│  │ 4 validadores      │  │ bos_blockchain     │  │ ctx_id cache    │ │
│  │ 2 RPC nodes        │  │ schema (7 tablas)  │  │ rate limiting   │ │
│  │ (StatefulSet)      │  │ (StatefulSet)      │  │ (StatefulSet)   │ │
│  └────────────────────┘  └────────────────────┘  └────────────────────┘ │
│                                                                       │
│  ┌────────────────────┐                                              │
│  │ Vault 2.0.1        │                                              │
│  │ S03/authserver/    │                                              │
│  │ PKI engine         │                                              │
│  │ Transit (AES-GCM)   │                                              │
│  │ HSM PKCS#11 (PLAN) │                                              │
│  └────────────────────┘                                              │
└──────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ CI/CD (GitHub Actions)
                                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      CI/CD (GitHub Actions)                            │
│                                                                       │
│  ┌────────────────────┐                                              │
│  │ Forge (Foundry)    │                                              │
│  │ • Compilar .sol    │                                              │
│  │ • Ejecutar tests   │                                              │
│  │ • Gas report       │                                              │
│  │ • Slither (audit)  │                                              │
│  │ • Deploy testnet   │                                              │
│  │ • NO en producción │                                              │
│  └────────────────────┘                                              │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 3. Librerías — ¿Qué va dónde?

| Componente | Librería | Tipo | Binario | ¿Nueva? | Ficha BOS |
|-----------|---------|------|---------|---------|----------|
| Merkle Tree | `sha3` (Keccak-256) | Rust crate | bAuth | ❌ Ya existía | No |
| Hex encoding | `hex` | Rust crate | bAuth | ❌ Ya existía | No |
| Verificación offline | `sha3` + `hex` | Rust crate | bos-verify | ❌ Ya existía | No |
| Firmar tx Ethereum | `ethers-rs` v2.0 | Rust crate | bAuth | ✅ PLAN | No |
| Red Besu QBFT | `hyperledger/besu:24.12` | Docker image | Pod K8s | ✅ PLAN | ✅ S12 |
| Compilar Solidity | `foundry-rs/foundry` | Docker image | CI/CD | ✅ PLAN | No |
| Auditar Solidity | `crytic/slither` | Docker image | CI/CD | ✅ PLAN | No |

---

## 4. Dependencias de bAuth — Lo que se agrega al instalador

### 4.1 Cargo.toml (dependencias Rust)

```toml
# YA EXISTENTES (sin cambios):
sha3 = "0.10"      # Keccak-256 — Merkle Tree (FIPS 202)
hex = "0.4"        # Hex encoding — bitmask + Merkle proofs

# NUEVA (B29.T05 — planificada):
ethers = { version = "2.0", features = ["rustls"] }
# Peso: ~2MB en binario (3.5MB → 5.5MB)
# Compilación: ~2min extra en CI
# Función: Firmar y enviar transacciones a Arbitrum One
# Clave: Desde Vault, NUNCA en código
```

### 4.2 bauth.service (systemd — sin cambios)

El servicio no necesita nuevas variables de entorno ni volúmenes.
La conexión a Besu se configura en `bauth.toml`:

```toml
[blockchain]
arbitrum_rpc = "https://arb1.arbitrum.io/rpc"    # Mainnet
arbitrum_testnet = "https://sepolia-rollup.arbitrum.io/rpc"
besu_rpc = "http://besu-rpc.sbos-blockchain:8545"  # K8s internal
anchor_contract = "0x..."   # Deployado por CI/CD
settlement_contract = "0x..."
```

### 4.3 Instalador BOS — No se modifica `install.sh`

Siguiendo ADR-022 (sin intervención manual en el servidor):
- El instalador copia `bin/bos`, `bin/bosctl`, `bin/bos-verify` (ya compilados con ethers)
- Las dependencias de sistema NO cambian
- Las fichas de blockchain se incluyen en el repositorio `bos-install`

---

## 5. Servidor S12 — Blockchain

### 5.1 Registro en el catálogo de servidores

```
servers/
├── S-HOST/hostserver/         ← Host físico
├── S01/dataserver/             ← PostgreSQL + Redis + MinIO
├── S03/authserver/             ← Keycloak + Vault + bAuth
├── S06/appserver/              ← bSearch + bNotify
├── S12/blockchain/             ← 🆕 NUEVO SERVIDOR LÓGICO
│   ├── README.md               ← Propósito: red Besu QBFT privada
│   ├── besu-validator/
│   │   ├── manifest.yml        ← StatefulSet 4 validadores
│   │   ├── genesis.json        ← Configuración QBFT
│   │   └── task_catalog.sh     ← Scripts de bootstrap
│   ├── besu-rpc/
│   │   ├── manifest.yml        ← 2 nodos RPC (sin validar)
│   │   └── task_catalog.sh
│   └── besu-genesis/
│       ├── manifest.yml        ← Job único: inicializar red
│       └── genesis.json
└── S15/monitoringserver/       ← Prometheus + Grafana + Loki
```

### 5.2 Fichas declarativas

#### besu-validator/manifest.yml

```yaml
ficha: besu-validator
version: "1.0.0"
servidor: S12
tipo: statefulset
dependencias:
  - postgresql      # S01
  - vault           # S03
  - besu-genesis    # S12 (job único)
recursos:
  cpu: "2000m"
  memoria: "4Gi"
  almacenamiento: "50Gi"
red:
  puerto_p2p: 30303
  puerto_rpc: 8545
  network_policy: "solo-nodos-S12"
```

#### besu-rpc/manifest.yml

```yaml
ficha: besu-rpc
version: "1.0.0"
servidor: S12
tipo: deployment
dependencias:
  - besu-validator
replicas: 2
recursos:
  cpu: "1000m"
  memoria: "2Gi"
red:
  puerto_rpc: 8545
  puerto_ws: 8546
  network_policy: "exponer-a-daemons"
```

---

## 6. Átomos para el REGISTRO-ESTADO de BOS

Estos átomos deben agregarse al plan de desarrollo de BosAgent:

| ID | Átomo | Horas | Descripción |
|----|-------|-------|------------|
| **BOS-D12.T01** | Servidor lógico S12/blockchain | 2h | Crear `servers/S12/` en bos-install + registros |
| **BOS-D12.T02** | Ficha `besu-genesis` | 4h | `manifest.yml` + `genesis.json` QBFT (4 validadores, blockperiod=2s) |
| **BOS-D12.T03** | Ficha `besu-validator` | 8h | StatefulSet 4 validadores, PKCS#11 HSM, Vault integration |
| **BOS-D12.T04** | Ficha `besu-rpc` | 4h | 2 nodos RPC (no validadores), WebSocket, NetworkPolicy |
| **BOS-D12.T05** | NetworkPolicy S12 | 2h | Aislamiento de red: solo daemons SBOS pueden conectar a Besu |
| **BOS-D12.T06** | StorageClass `bos-blockchain` | 1h | 50Gi persistente para datos de blockchain |
| **BOS-D12.T07** | Monitoreo Besu | 4h | Métricas Prometheus: altura de bloque, validadores activos, gas |
| **BOS-D12.T08** | Health check Besu | 2h | Probes: readiness=liveness, endpoint `/liveness` |
| **BOS-D12.T09** | Backup cadena Besu | 4h | Snapshot diario a MinIO (S01), `besu --data-path` backup |
| **BOS-D12.T10** | bAuth → Besu (config) | 2h | `bauth.toml` con `[blockchain]` section, RPC endpoint |
| **BOS-D12.T11** | CI/CD Smart Contracts | 4h | GitHub Actions: Forge build, test, Slither audit, gas report |
| **BOS-D12.T12** | Deploy `AuditAnchor.sol` | 2h | Deploy a Arbitrum Sepolia desde CI, verificar en Arbiscan |

---

## 7. Pruebas de Blockchain — TODAS en ambiente real con pods K8s

**PRINCIPIO IRRENUNCIABLE:** No existen pruebas lógicas ni pruebas "sin pods". Toda prueba
se ejecuta en el cluster K8s real de staging/producción. Los pods de Besu son obligatorios
desde la primera prueba de integración — no hay etapas de "simulación sin infraestructura".

### Topología de pruebas (todo en pods K8s):

```
┌──────────────────────────────────────────────────────────────┐
│                CAPAS DE PRUEBA (todas requieren K8s real)     │
│                                                               │
│  CAPA 1: Pruebas unitarias del binario (en CI/CD con K8s)    │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ Merkle Tree Engine: 8/8 tests ✅                      │    │
│  │   - 100 leaves, batch 1000, domain separation,       │    │
│  │     tamper detection                                 │    │
│  │ bos-verify CLI: 2/2 tests ✅                          │    │
│  │   - hex roundtrip, strip 0x prefix                   │    │
│  │ CtxPlane (W3C traceparent): 8/8 tests ✅              │    │
│  │   - roundtrip, format validation, expiry             │    │
│  │ Ejecutados en pod bAuth del cluster real              │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                               │
│  CAPA 2: Pruebas de integración (BD real en VPS + K8s)       │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ Schema bos_blockchain: 7 tablas creadas ✅             │    │
│  │ D12 Chained Policies: 1005 políticas activas ✅        │    │
│  │ Seed atoms D12: 41 átomos en catálogo ✅               │    │
│  │ 42/42 JSON-RPC tests pasando en VPS ✅                 │    │
│  │ PostgreSQL corre en pod K8s ClusterIP                 │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                               │
│  CAPA 3: Integración con Besu (pods K8s obligatorios)        │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ Requiere fichas BOS-D12.T02, T03, T04 desplegadas     │    │
│  │ AnchorVerify: bAuth → Besu RPC pod → anchor en cadena│    │
│  │ Merkle Engine: genera batch → submite tx real a Besu  │    │
│  │ bos-verify: verifica proof contra tx real on-chain    │    │
│  │ Todo en pods K8s — sin mocks, sin simulación          │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                               │
│  CAPA 4: Testnet público (sin infra propia)                   │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ Arbitrum Sepolia: testnet público y gratuito           │    │
│  │ ethers-rs conecta a https://sepolia-rollup.arbitrum.io│    │
│  │ AuditAnchor.sol deployado con Foundry desde CI        │    │
│  │ Anclaje real: transacción → bloque → verificación     │    │
│  │ Costo: ~0.001 ETH/test (gratis con faucet)            │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                               │
│  CAPA 5: Red Besu propia (solo en staging/prod)               │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ Besu QBFT en K8s: 4 validadores + 2 RPC               │    │
│  │ SettlementEngine.sol deployado on-chain               │    │
│  │ Liquidación real: D3 Policy-Path → tx → confirmación  │    │
│  │ Reconciliación on-chain ↔ PostgreSQL cada 15min        │    │
│  └──────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

**Actualmente estamos en CAPA 1 + 2 (verificadas en VPS con pods K8s).**
La CAPA 3 (Besu real) requiere fichas BOS-D12.T02–T04 desplegadas en K8s.
La CAPA 4 (testnet público) necesita ethers-rs compilado + pod bAuth en K8s.
La CAPA 5 (red propia certificada) requiere las fichas completas BOS-D12 en K8s.

**Regla absoluta:** No se acepta ninguna prueba fuera de pods K8s. No hay etapas sin pods.

### Lo que YA funciona sin blockchain real:

1. **Merkle Tree Engine:** construye árboles, genera proofs, verifica offline
2. **Schema bos_blockchain:** 7 tablas listas para recibir datos
3. **AnchorVerify handler:** verifica proofs contra raíces almacenadas
4. **bos-verify CLI:** verifica proofs desde archivo JSON (sin conexión)
5. **CtxPlane:** genera traceparent W3C, listo para propagación
6. **42/42 JSON-RPC:** todos los métodos responden correctamente

---

## 8. Dependencias — Lo que se suma al instalador de bAuth

### 8.1 Cargo.toml — Dependencias Rust

```toml
# ================================================================
# YA EXISTENTES (compiladas en bAuth v3.1.0)
# ================================================================
sha3 = "0.10"          # Keccak-256 (FIPS 202) — Merkle Tree
hex = "0.4"            # Hex encoding — Merkle proofs + BitMask
sha2 = "0.10"          # SHA-256/512 (FIPS 180-4)
sha1 = "0.10"          # SHA-1 — WebSocket handshake (RFC 6455)
argon2 = "0.5"         # Password hashing (Argon2id)
ed25519-dalek = "2"    # EdDSA — Release Plane signatures
aes-gcm = "0.10"       # AES-256-GCM — cifrado
base64 = "0.22"        # Base64 — RolBitMask serialization

# ================================================================
# PLANIFICADAS (para B29.T05 — ethers-rs)
# ================================================================
# ethers = { version = "2.0", features = ["rustls"] }
#   Peso binario: +2MB (3.5MB → 5.5MB)
#   Compilación: +2min en CI
#   Función: Firmar y enviar transacciones Ethereum
#   Clave: Desde Vault vía API, NUNCA hardcodeada
```

### 8.2 Lo que NO necesita el host

| No necesita | Por qué |
|------------|---------|
| `apt-get install solc` | Forge en CI/CD compila Solidity |
| `apt-get install geth` | Besu en pod K8s |
| `npm install -g hardhat` | Forge (Rust, sin Node.js) |
| `pip install web3` | ethers-rs compilado en bAuth |
| `docker pull besu` en host | BOS lo despliega en K8s |
| Ningún puerto nuevo en host | Todo en ClusterIP de K8s |
