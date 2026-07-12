# Índice Maestro de Motores — bAuth

**Rige:** ADR-013 (Arquitectura de Motores Únicos) · **Fecha:** 2026-07-12 · **Estado:** vivo

---

## 0. Qué es esto y cómo se usa

bAuth se estructura **por motores**: una capacidad (verbo) = un motor = un punto único de cambio
(ADR-013). Esta carpeta es la **vista por motor** sobre los 37 manuales y los anexos: **no los
reemplaza ni los renumera** — los **agrupa e indexa** bajo el motor al que sirven.

**Para trabajar (reparar/completar) un motor:** abre su **portada** (`motor-<nombre>.md`). Cada
portada reúne, sin fricción, todo lo necesario:
1. **Propósito** del motor (su verbo, su frontera).
2. **El contrato** (trait + registro + frontera + fail-closed).
3. **Los códigos que se juntan** — los archivos `.rs` actuales (dispersos) → la frontera destino.
4. **Manuales de referencia** (qué leer antes de tocar).
5. **Anexos y contratos** (la especificación y el estado por contrato).
6. **Estado real** (qué hay, qué falta — verificado en código).
7. **Plan** para completarlo.

---

## 1. Los 7 motores de capacidad (el núcleo)

| # | Motor | Verbo | Frontera destino | Manual madre | Portada | Estado |
|:-:|-------|-------|------------------|:---:|---|:---:|
| 1 | **BitMask** | calcular privilegios | `src/bitmask/` | 1.04 | [motor-bitmask](motor-bitmask.md) | ✅ robusto |
| 2 | **Métodos** | autenticar | `src/domain/auth_methods/` | 2.01 | [motor-metodos](motor-metodos.md) | 🔄 9/18 |
| 3 | **Políticas (PDP)** | autorizar / decidir | `src/policy/` *(a crear)* | 2.05 | [motor-politicas](motor-politicas.md) | 🔄 partido + fail-open |
| 4 | **Canales** | transportar | `src/transport/` *(a crear)* | 2.12 | [motor-canales](motor-canales.md) | ⬜ PLT-17 |
| 5 | **Criptográfico** | cifrar / primitivas | `src/crypto/` *(a crear)* | — *(a crear)* | [motor-criptografico](motor-criptografico.md) | ⬜ CORE-11 |
| 6 | **Firma** | firmar documentos | `src/domain/signature/` | 2.04 | [motor-firma](motor-firma.md) | 🔄 interno ✅ / ADSIB ⬜ |
| 7 | **Auditoría** | auditar (WORM) | `src/audit/` | 5.01 | [motor-auditoria](motor-auditoria.md) | 🔄 esqueleto |

**Regla (ADR-013):** un motor = **un trait + un registro + una frontera única + fail-closed + punto
único de cambio**. Si una lógica de la capacidad vive fuera de su frontera, es un defecto a reparar.

## 2. Especialización DENTRO de los motores (no son motores nuevos — ADR-013 §criterio)

- **Familias** (Motor de Métodos): *software* (pwd/TOTP/WebAuthn) · *hardware-físico* (smart card/NFC/
  PIV/biometría, adquiridos por el **edge**) · *federación* (SAML/OIDC) · *descentralizada* (DID/VC).
- **Dominios/evaluadores** (Motor de Políticas): los 12 — lógico, físico, **geoespacial (D7)**,
  financiero, temporal, red, delegación, **blockchain (D12)**, contexto, biométrico…
- **PIP** (fuentes de atributos que alimentan el PDP, no deciden): ubicación/geo, riesgo, device
  posture, Context Plane.

## 3. Emisión y datos (capacidades de soporte)

| Capacidad | Manual | Notas |
|-----------|:---:|-------|
| **Emisión de Tokens** (JWT) | 2.03 | La *salida*: empaqueta el veredicto de Métodos+Políticas y lo firma (usa Firma + Cripto). Portada ligada a Firma. |
| **Versionado** (motor transversal de datos) | 1.13 | Versiona TODO dato de bAuth (temporal constraints PG18). Transversal a todos los motores. |

## 4. Transversales — NO son motores (rectores, PIP, infraestructura)

| Manual | Rol |
|--------|-----|
| 0.00 Directrices IAM · 7.03 Normas | **Rectores** — la doctrina que todos cumplen |
| 2.09 Seguridad · 2.10 Seguridad de datos | Transversal de seguridad |
| 1.11 Context Plane | **PIP** — provee `ctx_id`/contexto al PDP |
| 1.12 Multi-tenancy | Transversal de aislamiento |
| 1.05 DDL-Seeds | Modelo de datos (infraestructura) |
| 2.11 Frontend | UI (observa los motores) |
| 6.01 Operación · 7.04 CLI-pruebas | Operación/testing |
| 4.01 bAuth-bNotify | Integración (contrato con hermano) |
| 9.01 Producto · 9.02 API | Producto / referencia API (expone los motores) |

## 5. Orden de convergencia (ADR-013 · qué reparar primero)
1. **Políticas** — fail-closed (`None ⇒ denegado`, BA3/A.21, 1 línea + test) → luego unir la frontera `src/policy/`.
2. **Criptográfico** (`src/crypto/`, CORE-11) y **Canales** (`src/transport/`, PLT-17) — extraer lo disperso.
3. **Métodos** — completar 9 → 18 (A.44).
4. **Firma** externa (ADSIB) + **Auditoría** (cablear el emisor).

*Índice Maestro de Motores · bAuth Identity Core v3.0 · ADR-013 · 2026-07-12*
