# BAUTH-CONTRATO-SYMBIOSIS — La Unión Trilateral
## Principio de Simbiosis: bAuth ↔ Keycloak ↔ Tryton
### v1.0 · 2026-06-19 · SKULL · BitMask Dual Jun 2026

---

> ⚠️ **CORRECCIÓN BITMASK — JUNIO 2026:** Las referencias al modelo BitMask (SAM-128, "2 capas", "BitmaskBundle") en este documento corresponden al diseño anterior. El modelo actual es el **BitMask Dual**: `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md`. Para desarrollo, consultar los manuales actualizados.

## 1. Metáfora: La Red Neuronal Simbiótica

> **Así como las neuronas se unen por afinidad química, formando redes que persisten
> aunque algunas mueran y renazcan, bAuth, Keycloak y Tryton se unen simbióticamente
> mediante contratos declarativos que sobreviven a la destrucción y recreación
> de cualquiera de las partes.**

```
┌─────────────────────────────────────────────────────────────┐
│                    RED SIMBIÓTICA                           │
│                                                             │
│    ┌──────────┐         ┌──────────┐         ┌──────────┐  │
│    │ Keycloak │◄───────►│  bAuth   │◄───────►│  Tryton  │  │
│    │ (cuerpo) │ afinidad│ (cerebro)│ afinidad│(memoria) │  │
│    └──────────┘         └──────────┘         └──────────┘  │
│         │                     │                     │       │
│         │    ◄── CONTRATO DE SIMBIOSIS ──►         │       │
│         │                                         │       │
│    ┌────┴─────────────────────────────────────────┴────┐  │
│    │  RolTemplate:  el contrato vinculante            │  │
│    │  UserTemplate: la asignación vinculante           │  │
│    │  bauth_db:     la memoria persistente             │  │
│    │  audit_events: la trazabilidad absoluta           │  │
│    └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 1.1 La promesa de la simbiosis

| Si esto pasa... | La simbiosis garantiza que... |
|-----------------|-------------------------------|
| **Tryton se borra** (upgrade, corrupción, rebuild) | bAuth regenera TODOS los grupos y usuarios desde `bauth_db.rol_templates` y `bauth_db.user_templates` vía XML-RPC. Nada se pierde. |
| **Keycloak se borra** (realm rebuild, migración) | bAuth regenera TODOS los roles, realms y usuarios desde `bauth_db` vía Keycloak Admin REST API. Nada se pierde. |
| **bAuth se borra** (migración Go→Rust, rebuild) | El nuevo bAuth lee `bauth_db` (que sobrevive en PostgreSQL), reconstruye el estado, reconcilia KC y Tryton en el primer loop. Nada se pierde. |
| **Los 3 se borran simultáneamente** | `bauth_db` persiste en PostgreSQL (PV con Retain). Al reinstalar, bAuth reconcilia desde la última verdad conocida. |
| **Un admin cambia algo manualmente en KC** | El reconcile loop (60s) detecta drift y lo revierte a la verdad de `bauth_db`. |

---

## 2. Principios de Diseño

### P1 — Verdad Canónica Única

> **`bauth_db` es la ÚNICA fuente de verdad.**
> Ni Keycloak ni Tryton tienen autoridad para modificar la identidad.
> Si KC tiene un rol que no está en `bauth_db.rol_templates`, es drift — se elimina.
> Si Tryton tiene un grupo que no está en `bauth_db.rol_templates`, es drift — se elimina.

```
bauth_db (PostgreSQL) ← ÚNICA fuente de verdad
    │
    ├──► Keycloak (copia administrada, reconcile cada 60s)
    └──► Tryton   (copia administrada, reconcile cada 60s)
```

### P2 — Contrato Declarativo, No Imperativo

> bAuth no le dice a Keycloak "crea este rol". bAuth declara:
> **"El estado deseado del ecosistema es este RolTemplate".**
> El Sync Engine calcula la diferencia entre el estado deseado y el estado real,
> y aplica solo los cambios necesarios. Si no hay diferencia, no toca nada.

```rust
// No imperativo:
//   keycloak_client.create_role("Contador")  ← frágil, sin contexto

// Declarativo (bAuth):
struct RolTemplate {
    id: "CONTADOR",
    inherits_from: vec!["BASE"],
    bitmask_add: PhysicalDomainMask::BUILDING_ACCESS,
    kc_realm_role: true,
    tryton_group: "Contabilidad",
}
// → SyncEngine calcula diff y aplica mínimo cambio necesario
```

### P3 — Idempotencia Absoluta

> Ejecutar la sincronización 1 vez o 1000 veces produce EXACTAMENTE el mismo resultado.
> No hay "ya estaba creado", "ya estaba actualizado". Siempre se llega al mismo estado.

| Operación | Idempotencia |
|-----------|-------------|
| `sync_roltemplate("CONTADOR")` ejecutado 5 veces | KC tiene 1 rol "CONTADOR", Tryton tiene 1 grupo "Contabilidad" |
| `bauth_db` restaurado desde backup | Reconcile loop detecta diff y sincroniza |
| Tryton recreado desde cero | bAuth regenera todos los grupos vía XML-RPC |
| KC realm recreado desde cero | bAuth regenera todos los roles vía REST API |

### P4 — Trazabilidad Total

> Cada cambio de identidad deja huella en `bkernel_db.audit_events`.
> Se sabe QUIÉN cambió QUÉ, CUÁNDO, desde DÓNDE, con QUÉ ctx_id.

### P5 — Recuperación desde Cero

> Dado un PostgreSQL con `bauth_db` intacto, bAuth puede reconstruir
> TODO el estado de identidad en Keycloak y Tryton sin intervención humana.
> Esto se llama "bootstrap simbiótico".

---

## 3. El Contrato de Simbiosis en la Ficha BOS

### 3.1 Orden de instalación

```
bosctl deploy seed-skull.yml:

  [PASO 4]  keycloak   ← se instala PRIMERO (el cuerpo)
  [PASO 8]  tryton     ← se instala SEGUNDO (la memoria)
  [PASO 9]  bauth      ← se instala TERCERO (el cerebro)
                          Al iniciar, bauth:
                          1. Crea DDL en bauth_db (idempotente)
                          2. Verifica conexión KC + Tryton
                          3. Ejecuta PRIMER reconcile loop
                          4. Sincroniza RolTemplates → KC + Tryton
                          5. La simbiosis está ACTIVA
```

### 3.2 Dependencias declaradas en manifest.yml

```yaml
# servers/S03/bauth/manifest.yml
requirements:
  dependencies:
    - keycloak      # PRIMERO: el cuerpo
    - tryton        # SEGUNDO: la memoria
    - postgresql    # La verdad canónica (bauth_db)
    - redis         # Cache de BitmaskBundle (TTL 30s)
```

### 3.3 Ficha bauth — ficha_post_install

```bash
ficha_post_install() {
    # 1. Verificar que KC responde
    curl -sf http://keycloak.sbos-security:8080/health || return 1
    
    # 2. Verificar que Tryton responde  
    curl -sf http://tryton.sbos-erp:8000 || return 1
    
    # 3. Ejecutar bootstrap simbiótico
    curl -s --unix-socket /run/bos/bauth.sock -X POST http://localhost/rpc \
      -d '{"jsonrpc":"2.0","method":"bauth.symbiosis.bootstrap","id":1}'
    
    # 4. Verificar que la simbiosis está activa
    curl -s --unix-socket /run/bos/bauth.sock -X POST http://localhost/rpc \
      -d '{"jsonrpc":"2.0","method":"bauth.symbiosis.status","id":2}'
    # Esperado: {"kc_synced": true, "tryton_synced": true, "contracts": 5}
}
```

---

## 4. La Simbiosis en el Código

### 4.1 Bootstrap Simbiótico (arranque de bauth)

```rust
/// Bootstrap simbiótico: reconstruye la unión bAuth↔KC↔Tryton desde bauth_db.
/// Idempotente: ejecutar 100 veces produce el mismo resultado.
/// 
/// Orden de operaciones:
///   1. migrate() — DDL en bauth_db (CREATE IF NOT EXISTS)
///   2. verify_kc() — Ping a Keycloak Admin REST API
///   3. verify_tryton() — Ping a Tryton XML-RPC
///   4. load_contracts() — Cargar RolTemplates y UserTemplates desde bauth_db
///   5. reconcile_all() — Sincronizar KC y Tryton con la verdad de bauth_db
///   6. start_reconcile_loop() — Iniciar reconcile cada 60s
async fn bootstrap_symbiosis(pool: &PgPool, kc: &KeycloakClient, tryton: &TrytonClient) -> Result<()> {
    // 1. DDL — idempotente, sobrevive a cualquier destrucción
    migrate_bauth_db(pool).await?;
    
    // 2-3. Verificación de los brazos de ejecución
    kc.ping().await.context("Keycloak no accesible — simbiosis en modo degradado")?;
    tryton.ping().await.context("Tryton no accesible — simbiosis en modo degradado")?;
    
    // 4. Cargar contratos desde la verdad canónica
    let contracts = load_all_contracts(pool).await?;
    info!(contracts = contracts.len(), "contratos cargados desde bauth_db");
    
    // 5. Reconciliación completa — idempotente
    let diff = compute_symbiosis_diff(&contracts, kc, tryton).await?;
    apply_symbiosis_diff(diff, kc, tryton).await?;
    info!("simbiosis restaurada — KC y Tryton sincronizados con bauth_db");
    
    // 6. Loop continuo
    spawn_reconcile_loop(pool.clone(), kc.clone(), tryton.clone());
    Ok(())
}
```

### 4.2 Reconcile Loop (el latido de la simbiosis)

```
Cada 60 segundos:
  1. Leer RolTemplates desde bauth_db
  2. Leer roles desde Keycloak Admin REST API
  3. Leer grupos desde Tryton XML-RPC
  4. Calcular diff (lo que falta, lo que sobra, lo que difiere)
  5. Aplicar diff (crear/actualizar/eliminar en KC y Tryton)
  6. Registrar en audit_events
```

### 4.3 Degradación Graciosa

Si uno de los brazos falla, la simbiosis NO se rompe:

| Escenario | Comportamiento |
|-----------|---------------|
| KC caído | bauth sigue operando. Cache Redis responde consultas. Sync se reintenta cada 60s. |
| Tryton caído | bauth sigue operando. Sync a Tryton se encola. Se reintenta cada 60s. |
| Ambos caídos | bauth usa solo cache Redis. Modo "identidad congelada" — no se pueden crear nuevos roles hasta que vuelvan. |
| bauth_db caído | ❌ CRÍTICO — bauth no puede operar sin verdad canónica. Requiere intervención. |

---

## 5. La Simbiosis en las Fichas BOS

### 5.1 Ficha Keycloak → ficha_post_install

```bash
# La ficha de KC crea el realm "skull" y prepara el terreno
ficha_post_install() {
    # Crear cliente "bauth" en realm skull para Admin REST API
    kcadm.sh create clients -r skull -s clientId=bauth -s secret="${BAUTH_SECRET}"
    # Crear roles base que bAuth luego poblará
    kcadm.sh create roles -r skull -s name=BASE
}
```

### 5.2 Ficha Tryton → ficha_post_install

```bash
# La ficha de Tryton crea la BD y prepara el terreno
ficha_post_install() {
    # Crear grupos base que bAuth luego poblará
    trytond-admin -d tryton_db -m res,ir,res_group
}
```

### 5.3 Ficha bAuth → ficha_post_install (EL MOMENTO DE LA SIMBIOSIS)

```bash
ficha_post_install() {
    # Este es el momento en que la red neuronal se activa.
    # KC existe. Tryton existe. bAuth tiende los puentes.
    
    # 1. Bootstrap simbiótico
    bauthctl symbiosis bootstrap
    
    # 2. Verificar que los 5 contratos están activos
    local count=$(bauthctl symbiosis status | jq '.contracts_synced')
    if [ "$count" -lt 5 ]; then
        echo "⚠️  Simbiosis parcial: $count/5 contratos activos"
    else
        echo "✅ Simbiosis completa: 5/5 contratos activos"
    fi
}
```

---

## 6. Pruebas de la Simbiosis

### 6.1 Test: Destrucción y Recuperación de Tryton

```bash
# 1. Destruir Tryton
kubectl delete statefulset tryton -n sbos-erp
kubectl delete pvc data-tryton-0 -n sbos-erp

# 2. Reinstalar Tryton (simula upgrade de versión)
bosctl ficha install tryton

# 3. Verificar simbiosis restaurada
bauthctl symbiosis verify
# Esperado: ✅ tryton synced — 5 contracts, 12 groups restored

# 4. Verificar que los grupos de Tryton son IDÉNTICOS a antes
bauthctl tryton diff --baseline backup-2026-06-19.json
# Esperado: ✅ 0 differences — simbiosis intacta
```

### 6.2 Test: Migración de bAuth Go→Rust

```bash
# 1. Detener bAuth Go
systemctl stop bauth

# 2. Respaldar bauth_db
pg_dump -U postgres bauth_db > bauth_db_backup.sql

# 3. Instalar bAuth Rust (nuevo binario)
cp target/release/bauth-daemon /usr/local/bin/bauth-daemon
systemctl start bauth

# 4. Verificar que el nuevo bAuth reconoce los contratos
bauthctl symbiosis status
# Esperado: ✅ 5 contracts loaded from bauth_db, KC synced, Tryton synced

# 5. Verificar que no hay drift
bauthctl symbiosis verify
# Esperado: ✅ No drift detected — simbiosis intacta a través de la migración
```

---

## 7. Registro en el Plan de Desarrollo

Cada átomo de bAuth debe considerar EL IMPACTO SIMBIÓTICO en KC y Tryton:

| Átomo | Impacto en KC | Impacto en Tryton | Prueba simbiótica |
|-------|-------------|-------------------|-------------------|
| B0 (Esqueleto) | Ninguno | Ninguno | N/A |
| B1 (PrivilegeEngine) | Ninguno (lógica pura) | Ninguno | Unit tests |
| B2 (Sync KC↔Tryton) | 🔴 ALTO — CRUD de roles/realms | 🔴 ALTO — CRUD de grupos | Test destrucción/recuperación |
| B3 (API Unix Socket) | Medio — consultas de auth | Ninguno | Test de carga con KC real |
| B4 (Identidad Física) | Medio — WebAuthn, QR | Ninguno | Test NFC/QR |
| B5 (Ficha) | 🔴 ALTO — bootstrap simbiótico | 🔴 ALTO — bootstrap simbiótico | Test destrucción total |

---
*BAUTH-CONTRATO-SYMBIOSIS v1.0 · 2026-06-19 · SKULL*
*Este documento es vinculante para todo desarrollo de bAuth, Keycloak y Tryton.*
