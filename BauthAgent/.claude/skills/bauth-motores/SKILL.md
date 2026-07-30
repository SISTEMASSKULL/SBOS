---
name: bauth-motores
description: >
  Los 7 motores de capacidad de bAuth (ADR-013): qué es cada uno, su frontera de código,
  su estado actual, y qué leer antes de tocarlo. Úsala cuando vayas a implementar,
  reparar o extender cualquier motor (BitMask, Métodos, Políticas, Canales, Criptográfico,
  Firma, Auditoría). Incluye la regla de convergencia y el contrato de cada motor.
---

# Skill — bAuth: Los 7 Motores (ADR-013)

**Rige:** `context/Documentacion/MOTORES/MOTORES-INDEX.md`  
**Regla ADR-013:** `1 motor = 1 trait + 1 registro + 1 frontera + fail-closed + punto único de cambio`.  
Si lógica de un motor vive fuera de su frontera → defecto a reparar, no a preservar.

---

## 1 · BitMask — verbo: calcular privilegios ✅ robusto

**Frontera:** `src/bitmask/`  
**Manual:** `context/Documentacion/1.04_MANUAL-BITMASK-v1.0.md`  
**Portada:** `context/Documentacion/MOTORES/motor-bitmask.md`  
**Qué hace:** BitMask Dual 64-bit (D00 operacional + D00 confianza) sobre 12 dominios (D0–D11).
Cálculo O(1) por consulta a `DomainRegistry`. Átomos como bits posicionales.  
**Antes de tocar:** leer la portada + `1.04` (§3 Estructura del bit, §6 DomainRegistry).

## 2 · Métodos — verbo: autenticar 🔄 9/18

**Frontera destino:** `src/domain/auth_methods/`  
**Manual:** `context/Documentacion/2.01_MANUAL-AUTENTICACION-v1.0.md`  
**Estado industria:** `context/Documentacion/2.02_MANUAL-METODOS-ESTADO-INDUSTRIA-v1.0.md`  
**Portada:** `context/Documentacion/MOTORES/motor-metodos.md`  
**Familias:** software (pwd/TOTP/WebAuthn) · físico (smart card/NFC/PIV/biometría) ·
federación (SAML/OIDC) · descentralizada (DID/VC).  
**Antes de tocar:** leer la portada + `A.44` (arquitectura métodos) + `A.06` (framework auth).

## 3 · Políticas (PDP) — verbo: autorizar 🔄 **URGENTE — fail-open**

**Frontera destino:** `src/policy/` *(a crear)*  
**Manual:** `context/Documentacion/2.05_MANUAL-POLITICAS-v1.0.md`  
**AtomLang:** `context/Documentacion/2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md`  
**Portada:** `context/Documentacion/MOTORES/motor-politicas.md`  
**Gap crítico:** hoy el motor retorna `None ⇒ permitido` (fail-open) → DEBE ser `None ⇒ denegado` (fail-closed).
Una línea de código + test. **P1 absoluto.**  
**Antes de tocar:** leer portada + `2.05` §4 + `A.07` (Policies Framework JSON5) + `A.21` (pipeline dominios en código).

## 4 · Canales — verbo: transportar ⬜ PLT-17

**Frontera destino:** `src/transport/` *(a crear)*  
**Manual:** `context/Documentacion/2.12_MANUAL-CANALES-PROTEGIDOS-v1.0.md`  
**Portada:** `context/Documentacion/MOTORES/motor-canales.md`  
**Qué hace:** Unix socket (WS-RPC humanos + JSON-RPC daemons) · TLS mutual · gestor de canales.  
**Antes de tocar:** leer portada + `2.12` + `2.09` (seguridad de red) + `A.11` (red).

## 5 · Criptográfico — verbo: cifrar ⬜ CORE-11

**Frontera destino:** `src/crypto/` *(a crear)*  
**Portada:** `context/Documentacion/MOTORES/motor-criptografico.md`  
**Qué hace:** primitivas criptográficas (Ed25519 Vault, ECDSA Besu), cifrado de atributos
sensibles (D12), gestión de claves. Sirve a Firma, Tokens y Seguridad de datos.  
**Antes de tocar:** leer portada + `2.04` (firma digital) + `2.10` (seguridad datos) + `A.08` (motores firma) + `A.15` (stack Rust autenticación).

## 6 · Firma — verbo: firmar documentos 🔄 interno ✅ / ADSIB ⬜

**Frontera:** `src/domain/signature/`  
**Manual:** `context/Documentacion/2.04_MANUAL-FIRMA-DIGITAL-v1.0.md`  
**Portada:** `context/Documentacion/MOTORES/motor-firma.md`  
**Motores:** interno Ed25519 (Vault) ✅ · externo ADSIB RSA-SHA256 ⬜.  
**Antes de tocar:** leer portada + `2.04` + `A.08` (motores firma) + `A.28` (JWT Token Binding/DPoP).

## 7 · Auditoría — verbo: auditar (WORM) 🔄 esqueleto

**Frontera destino:** `src/audit/`  
**Manual:** `context/Documentacion/5.01_MANUAL-AUDITORIA-TRAZABILIDAD-v1.0.md`  
**Portada:** `context/Documentacion/MOTORES/motor-auditoria.md`  
**Qué hace:** registro WORM de todo evento de identidad. Hash-chain + ctx_id + W3C trace +
Merkle (trazabilidad extremo a extremo). Blockchain D12 como ancla (5.02).  
**Antes de tocar:** leer portada + `5.01` + `5.02` (Blockchain D12) + `A.27` (auditoría código).

---

## Capacidades de soporte (NO son motores — ADR-013 §criterio)

| Capacidad | Manual | Rol |
|-----------|:---:|-----|
| Emisión de tokens JWT | `2.03` | Empaqueta veredicto de Métodos+Políticas, firma con motor Cripto |
| Motor de Versionado Universal | `1.13` | Versiona TODO dato de bAuth — temporal constraints PG18 |
| Context Plane (ctx_id) | `1.11` | PIP: provee `ctx_id`/contexto al PDP — obligatorio en toda operación |
| Multi-tenancy / IDaaS | `1.12` | Transversal de aislamiento — `bauth.tenant.*` + `bauth.idp.*` |

---

## Orden de convergencia (ADR-013)

1. **Políticas** → fix fail-open (1 línea) → luego consolidar frontera `src/policy/`
2. **Criptográfico** (`src/crypto/`, CORE-11) + **Canales** (`src/transport/`, PLT-17) → extraer
3. **Métodos** → completar 9 → 18 (ver `A.44`)
4. **Firma** ADSIB + **Auditoría** → cablear el emisor

**Regla:** un motor = un punto único de cambio. Si hay lógica del motor dispersa en otros módulos, reubicarla en la frontera es parte del trabajo, no es refactoring extra.
