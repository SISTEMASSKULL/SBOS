# BAUTH-D99 — Dominio Administrativo Global
**Versión:** 1.0 · **Fecha:** 2026-07-07 · **Autor:** bauth-developer
**Estándares:** NIST SP 800-207 (Zero Trust) · NIST SP 800-53 Rev.5 (PM Controls) · ISO 27001:2022 A.8

---

## 1. Qué es D99

D99 es el **Dominio Administrativo Global** de bAuth. No es un dominio funcional como D1–D12
(autenticación, autorización, financiero, físico…). Es la capa de **políticas y configuraciones
globales de seguridad** que bAuth posee como autoridad central y que **todo componente del
ecosistema SBOS debe adoptar** como reglas irrenunciables de operación.

En los estándares internacionales, D99 corresponde a:

| Estándar | Nombre del concepto | Descripción |
|---|---|---|
| NIST SP 800-207 | **Control Plane Policies** | Políticas del plano de control que gobiernan todos los planos de datos |
| NIST SP 800-53 Rev.5 | **Program Management (PM) Controls** | Controles de gestión del programa aplicables a todo el sistema |
| ISO 27001:2022 | **Baseline Controls (Annex A §8)** | Controles tecnológicos transversales: criptografía, claves, auditoría |
| XACML 3.0 | **Global PolicySet / Obligation Policies** | PolicySet raíz evaluado antes de cualquier dominio funcional |
| SABSA | **Security Services Layer** | Capa de servicios de seguridad que fundamenta todos los dominios |

---

## 2. Qué contiene D99

D99 agrupa las configuraciones que definen **cómo opera la seguridad del sistema entero**,
no quién puede hacer qué. Sus nodos en `cfg_policy_library` incluyen:

| Área | Ejemplos | Aplica a |
|---|---|---|
| **Criptografía global** | Algoritmos permitidos (RSA-4096, Ed25519, AES-256-GCM), tamaños mínimos de clave | Todo componente que firme, cifre o verifique |
| **Resistencia cuántica** | Algoritmos PQC (ML-KEM, ML-DSA), modo híbrido, estándares IETF | bAuth, bkernel, bnexus |
| **Gestión de claves** | Intervalo de rotación, almacenamiento (HSM), políticas de expiración | bAuth, bkernel, Vault |
| **Auditoría global** | Retención mínima de logs (365d), integridad, formato de eventos | Todo daemon (ctx_id SBOS-049) |
| **Metadatos del framework** | Versión, historial de cambios, clasificación de seguridad | Todo componente que lea la versión del framework |
| **Sesión global** | Timeout por defecto del sistema, límites de sesiones concurrentes | bAuth, bkernel, bnexus |

---

## 3. Diferencia con D1–D12

```
D1–D12  →  "¿Quién puede hacer qué?"        →  BitMask 64-bit por rol/usuario
D99     →  "¿Cómo opera el sistema?"         →  Configuración global — NO entra al BitMask
```

D99 **nunca se asigna a un rol ni a un usuario**. No tiene bits en el BitMask Dual 64-bit.
Es configuración del sistema operada por SKULL a través de migraciones controladas (HITL).

---

## 4. bAuth como emisor — arquitectura PAP/PIP

bAuth es el **único emisor y custodio** de las políticas D99. Los demás daemons del
ecosistema SBOS no definen sus propias políticas de seguridad base — las solicitan a bAuth.

```
bAuth (PAP/PIP)
    │
    │  JSON-RPC  bauth.config.global_get
    │  ──────────────────────────────────────────────────────────►  bkernel
    │  ──────────────────────────────────────────────────────────►  biedata
    │  ──────────────────────────────────────────────────────────►  bsearch
    │  ──────────────────────────────────────────────────────────►  bnexus
    │  ──────────────────────────────────────────────────────────►  bnotify
    │
    │  Cambio en D99 → bkernel CDC → WAL → Redis Streams → fanout
    └──────────────────────────────────────────────────────────────►  todos los daemons
```

**Flujo de adopción:**
1. Al arrancar, cada daemon llama `bauth.config.global_get` y carga la configuración D99
2. El daemon aplica esas configuraciones en su runtime (algoritmos, timeouts, retención de logs)
3. bAuth notifica cambios en D99 vía bkernel CDC (WAL → Redis Streams)
4. Los daemons escuchan el stream y recargan la configuración sin reiniciar

---

## 5. Método JSON-RPC — `bauth.config.global_get`

**Namespace:** `bauth.config`
**Método:** `global_get`
**Socket:** `/run/bos/bauth.sock` (ADR-020 Interface Dual)

### Request
```json
{
    "jsonrpc": "2.0",
    "method": "bauth.config.global_get",
    "params": {
        "ctx_id": "<uuid>",
        "caller": "bkernel",
        "domain": "D99",
        "filter": ["cryptography", "key_management"]
    },
    "id": 1
}
```

`filter` es opcional. Sin él devuelve el árbol D99 completo.

### Response
```json
{
    "jsonrpc": "2.0",
    "result": {
        "domain": "D99",
        "version": "2.0.0",
        "effective_from": "2026-07-07T00:00:00Z",
        "config": {
            "cryptographyServices": {
                "_meta": { "level_type": "POLICY_SET", "standard_ref": "NIST SP 800-57" },
                "keyManagement": {
                    "keyGeneration": {
                        "algorithms": {
                            "symmetric": {
                                "aes": {
                                    "sizes":  { "_type": "ENUM", "_options": ["256", "384"] }
                                }
                            },
                            "asymmetric": {
                                "rsa": {
                                    "minimum_key_size": { "_type": "INTEGER", "_value": "4096" }
                                }
                            }
                        }
                    },
                    "rotationPolicies": {
                        "interval_days": { "_type": "INTEGER", "_value": "90" }
                    }
                }
            }
        }
    },
    "id": 1
}
```

La respuesta es el JSONB generado por `bauth.fn_compose_tree()` filtrado por D99.

---

## 6. Contrato de adopción — obligaciones de cada daemon

Todo daemon SBOS que consuma D99 **debe** cumplir estas reglas:

| Obligación | Descripción |
|---|---|
| **Leer al arrancar** | Llamar `bauth.config.global_get` antes de aceptar tráfico |
| **Respetar sin override** | No puede ignorar ni sobreescribir una configuración D99 con su propia config local |
| **Escuchar cambios** | Suscribirse al stream de bkernel para recargar D99 sin reiniciar |
| **Propagar ctx_id** | Toda operación derivada de una config D99 lleva el `ctx_id` de la transacción que la originó (SBOS-049) |
| **No modificar** | Ningún daemon modifica D99 — solo bAuth vía migración HITL aprobada |

---

## 7. Gestión de cambios en D99

D99 es **inmutable en runtime**. Los cambios siguen el flujo HITL del proyecto:

```
SKULL detecta necesidad de cambio
    → propone en context/buzon-bibliotecario/
    → Bibliotecario revisa y eleva a HITL
    → Humano aprueba
    → bauth-developer genera migración bauth_NN__d99_update.sql
    → Revisor audita
    → Testeador verifica en VPS
    → Merge + deploy
    → bkernel propaga cambio automáticamente
```

Nadie puede cambiar D99 desde la UI ni desde un JSON-RPC de runtime. Solo migraciones SQL auditadas.

---

## 8. Registro en cfg_policy_library

Los nodos D99 se identifican en la tabla con:

```sql
SELECT * FROM bauth.cfg_policy_library
WHERE domain_map @> ARRAY['D99']
ORDER BY path;
```

Actualmente: **447 nodos** (POLICY_SET + POLICY + RULE + PROPERTY) cubriendo
criptografía, resistencia cuántica, gestión de claves, auditoría base y metadatos del framework.
