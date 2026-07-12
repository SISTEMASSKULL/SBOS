# Anexo A.41 — Evaluación CRUDA del código: qué funciona, qué es fachada, qué es estafa
## Auditoría de veracidad del código real de bAuth — terminado vs a medio vs valor ficticio hardcodeado

**Tipo:** ANEXO — auditoría de veracidad (tipo **D** verificación de código cruda + **B** normas/industria como refuerzo)
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Respalda a:** TODO el corpus — es el espejo crudo del código contra lo que los manuales afirman · consolida A.15–A.40
**Verificación de código:** barrido completo de `src/` (grep de patrones de veracidad) — leída 2026-07-11
**Normas de refuerzo:** W3C WebAuthn L3 §7.2 · RFC 9449 (DPoP) · fail-closed (OWASP) · DOC-SBOS-001 N3 (regla propia: cero unwrap) · NIST 800-63B

---

## 1. Propósito y método

Esta es la **evaluación cruda y honesta del código** — sin diplomacia. Clasifica lo que bAuth
tiene HOY en cinco categorías de veracidad, con evidencia de grep y cruce normativo:

- 🟢 **ROBUSTO** — funciona de verdad, código completo, verificado.
- 🟡 **A MEDIO CONSTRUIR** — empezado, con la parte crítica faltante.
- 🔵 **PLANIFICADO / L1** — declarado honestamente sin código (no es engaño: está marcado).
- ⚫ **CÓDIGO MUERTO** — escrito pero desconectado (`dead_code`).
- 🔴 **VALOR FICTICIO / ESTAFA** — **retorna éxito sin hacer el trabajo**: el más grave, porque
  parece funcionar y pasa revisiones superficiales.

**El método (grep de veracidad, 2026-07-11):** 12 TODO/FIXME · **100 archivos con
`#[allow(dead_code)]`** · **175 `unwrap/expect/panic` fuera de tests** · 56 handlers · retornos
`verified:true`/`valid:true` auditados uno a uno.

---

## 2. 🔴 VALOR FICTICIO / ESTAFA — retorna éxito sin hacer el trabajo (lo más grave)

Estos son los hallazgos que un sistema de autenticación NO puede tener: código que declara éxito
de seguridad sin ejecutar la verificación. **Parecen funcionar; son bypasses.**

### 2.1 ✅ WebAuthn `verify_assertion` — BYPASS DE AUTENTICACIÓN → **CORREGIDO 2026-07-11**

**Era (el bypass):** `verify_assertion` recibía `_public_key_der` (con underscore = la clave
pública NO se usaba), solo comprobaba que la firma tuviera ≥16 caracteres, y retornaba
`user_verified:true` hardcodeado. El propio comentario (línea 84) lo admitía: *"En producción:
verificar firma COSE con ring::ecdsa"*. Un atacante con un `credential_id` y 16 bytes cualesquiera
se autenticaba como cualquier usuario — bypass de MFA que prometía AAL3 y daba AAL0.

**Corrección aplicada (verificada, compila + 369 tests ok):** `verify_assertion` implementa ahora
los pasos obligatorios de [W3C WebAuthn L3 §7.2](https://www.w3.org/TR/webauthn-3/):
```
1. clientDataJSON.type == "webauthn.get"                  (§7.2 paso 11)
2. authenticatorData: rpIdHash == SHA-256(rp_id)          (§7.2 paso 13 — anti RP-confusion)
   + flag User Present (UP) obligatorio                   (§7.2 paso 14)
3. Verifica la firma sobre authenticatorData||SHA-256(clientDataJSON) con la CLAVE PÚBLICA
   registrada (ECDSA P-256 ASN.1 o EdDSA Ed25519, vía ring — FIPS 186-5)   (§7.2 paso 20)
Retorna Ok(user_verified) = el flag UV REAL (no hardcodeado) → AAL3 si UV, AAL2 si solo UP.
Fail-closed: sin clave pública, o firma inválida, o type incorrecto → Err (jamás Ok ficticio).
```
Se corrigió también `finish_authentication` (recibe la clave pública, deriva `user_verified` del
authData real) y el handler `webauthn_handlers.rs` (exige `public_key_b64`, falla cerrado sin
ella). **3 tests nuevos de fail-closed** (clave ausente / firma falsa / type incorrecto → todos
rechazan) — pasan. El `standard_ref` se actualizó de "L2" a "L3 §7.2 / AAL3".

**Brecha residual (base arquitectónica, §11):** el handler recibe la clave del parámetro; la
arquitectura completa la busca por `credential_id` en la tabla de credenciales + verifica el
**signature counter** (anti-clonación, §8). Ver §11-BA1.

### 2.2 🔴 DPoP `dpop_verified: true` sin criptografía (ya en A.28)

`token_protocols.rs:DpopHandler` retorna `dpop_verified:true` verificando solo que el proof
tenga 3 segmentos — sin firma, `ath`, `htm/htu`, `jti` (RFC 9449). Falsa garantía de
sender-constrained token. **Mismo patrón que WebAuthn: éxito de seguridad sin verificación.**

### 2.3 🔴 Pipeline FAIL-OPEN (ya en A.21)

`registry.rs:evaluate_all()` → `None => DomainResult::permitido(domain)`: un dominio activo sin
evaluador **concede acceso**. No retorna un `true` falso explícito, pero el efecto es el mismo:
acceso sin evaluación. Contradice fail-closed.

---

## 3. 🟢 ROBUSTO — funciona de verdad (para que la evaluación sea justa)

No todo es fachada. Estos componentes son **código completo y verificado** — la base sólida:

| Componente | Evidencia cruda | Por qué es robusto |
|---|---|---|
| **Login con Argon2id** | `saga/login.rs:56` — `verified:true` **solo tras** `argon2.verify_password(...) → Ok(())` | La verificación es real; el true viene del resultado criptográfico |
| **Validación de token** | `token_validate.rs:120` — verifica firma y retorna `valid:false, "firma criptográfica inválida"` ANTES de cualquier `valid:true` | Fail-closed correcto: si la firma falla, niega |
| **Firma JWT Ed25519** | `jwt_signer.rs` — `ring::Ed25519KeyPair` (FIPS 186-5) | Criptografía real, no simulada |
| **BitMask Dual** | `src/bitmask/` 2.640 líneas (A.17) | Motor completo, label/one-hot separados |
| **Context Plane** | `src/context/` 535 líneas + ctx_id en 47 archivos (A.14) | Subsistema completo L3 |
| **Merkle Engine** | `merkle.rs` 205 líneas (RFC 6962) | Anclaje real |
| **Disciplina anti-hardcode** | `resolver.rs:8` "todo desde BD" · `startup.rs:116` "sin hardcodear: cargar tenants reales de BD" · `config/mod.rs:237` | En varios módulos la regla DOC-SBOS-001 SÍ se respeta |
| **Pipeline (orden)** | `registry.rs` EVAL_ORDER coincide con 1.01 §5.1 + cortocircuito real (A.21) | El orden y el cortocircuito funcionan (la falla es solo el fail-open) |

**Cruce honesto:** el login, la validación de token y la firma JWT — el camino de autenticación
por contraseña — son robustos. La estafa está en los métodos MFA avanzados (WebAuthn, DPoP), no
en el núcleo del password. Un sistema que verifica bien el password pero finge verificar WebAuthn
da una **falsa sensación de MFA fuerte** — el usuario cree tener AAL2/3 y tiene AAL1 real.

---

## 4. 🟡 A MEDIO CONSTRUIR — la parte crítica falta

| Componente | Qué funciona | Qué falta (la parte crítica) | Refuerzo normativo |
|---|---|---|---|
| **Firma digital** (A.08) | Motor interno Ed25519 | Motor EXTERNO ADSIB (validez legal Ley 164) **no existe**; clave interna en memoria dev | Ley 164 · eIDAS |
| **Credenciales/IAL** (A.09) | Argon2id, recovery | Identity proofing IAL 1-3 **sin código**; `credential.rs` 61 líneas | NIST 800-63A |
| **Dominios D5–D12** (A.21) | Existen como módulos | 59–90 líneas c/u — evaluación parcial; D8/D9 Pre-BitMask delgados | NIST 800-207 |
| **Revocación/IGA** (A.10) | Invalidación ctx real | Motores de campañas/barrido/JML ausentes; `sync/` 173 líneas | NIST AC-2(j) |
| **Blockchain D12** (A.12) | Merkle real | `blockchain.rs` 62 líneas; sin producción | — |

---

## 5. ⚫ CÓDIGO MUERTO / DESCONECTADO — escrito pero sin efecto

> **⚠️ ACLARACIÓN CRÍTICA — el BitMask NO es código muerto.** El **motor BitMask Dual
> (`src/bitmask/`, 2.640 líneas, 11 módulos, importado por 34 archivos, ~62 tests) está VIVO,
> es de lo MÁS ROBUSTO del proyecto** (§3, A.17) — fue lo primero que se programó y funciona. Lo
> único que se eliminó 2026-07-11 fue `src/domain/bitmask.rs` (23 líneas): el **shim del modelo
> VIEJO** (BitMask 1 — SAM-128, OR directo sobre u64, que producía escalamiento silencioso) que
> quedó **huérfano** (ni siquiera declarado en `mod.rs`, el compilador no lo compilaba) cuando el
> proyecto migró al **BitMask Dual (el "BitMask 2")**. Es exactamente lo que se sospechaba: un
> residuo desconectado de la transición al modelo nuevo — no el motor. **El motor no se tocó.**

| Componente | Evidencia | Impacto |
|---|---|---|
| **Risk Engine** | `risk.rs` `#![allow(dead_code)]` — 0 invocaciones (A.26) | El scoring de riesgo NO se ejecuta; `risk_score` del JWT siempre None |
| **100 archivos con `#[allow(dead_code)]`** | grep | Mucho código escrito que el compilador sabe que nadie llama — señal de features a medio cablear |
| **Emisor de auditoría** | `src/audit/` solo mod.rs 94 líneas (A.27) | El DDL superior de auditoría casi sin quien lo llene |

---

## 6. 🔵 PLANIFICADO / L1 — declarado honestamente (esto NO es engaño)

Para ser justos: parte de lo faltante está **declarado con honestidad** — no finge estar hecho:
- **Motor de Versionado** (1.13/A.33): L1 explícito, 0 código, ruta F2-F5.
- **Catálogo de átomos D2–D13** (A.05): estado DISEÑO declarado.
- **Redis/cache** (H-019): comentado en Cargo.toml con nota explícita.
- **notify**: `domain/mod.rs:22` "contrato + stub para desarrollo" — el stub está DECLARADO.

La diferencia entre §6 y §2 es la honestidad: aquí se dice "no está hecho"; en §2 se retorna
`true` como si lo estuviera. **§6 es deuda sana; §2 es deuda peligrosa.**

---

## 7. Violaciones de las reglas del PROPIO proyecto

| Regla (CLAUDE / DOC-SBOS-001) | Realidad cruda | Gravedad |
|---|---|---|
| *"Cero `unwrap()` en producción — usar Result<T, BauthError>"* | **175 `unwrap/expect/panic` fuera de tests** | Alta — cada uno es un pánico potencial (DoS) |
| *"Prohibido código sin documentación"* | 100 `allow(dead_code)` — código que existe sin uso | Media |
| Fail-closed (CLAUDE §8) | WebAuthn/DPoP fail-open (§2); pipeline fail-open (§2.3) | **Crítica** |
| Q5 (informe consistencia) | `idp_external.rs` declarativo responde `"realm_por_tenant"` — la arquitectura KC **eliminada** (ADR-010) | Media (doctrina) |

---

## 8. Faltantes NO considerados por el proyecto (industria/normas lo exigen)

Cruzando con la industria, cosas que ni los manuales ni los gaps mencionan:

| Faltante | Quién lo exige | Por qué importa |
|---|---|---|
| **Rate limiting anti-brute-force en el login** | OWASP ASVS 2.2.1 · NIST 800-63B §5.2.2 | El login Argon2 es robusto pero sin límite de intentos por cuenta/IP es vulnerable a fuerza bruta online (`ath_login_attempt` existe como tabla — ¿se usa para bloquear?) |
| **Signature counter de WebAuthn** (anti-clonación) | W3C §7.2 (el counter detecta authenticators clonados) | Además de no verificar firma, no hay counter |
| **Constant-time comparison** en verificación de secretos | timing attacks | Verificar que las comparaciones de tokens/códigos son constant-time (`ring` lo da, pero los `==` manuales no) |
| **Key rotation del firmante JWT** | NIST 800-57 | La clave en memoria dev no rota; en prod sin política verificable |
| **Límite de tamaño y validación de profundidad JSON** (anti-DoS de parsing) | OWASP | El socket limita bytes (M-03) pero el parsing JSON anidado puede agotar stack |

---

## 9. El veredicto crudo (lo que el reparador debe saber)

1. **bAuth NO es una estafa global** — tiene un núcleo robusto real (login, token, firma JWT,
   BitMask, Context Plane, Merkle). Es un producto que compila y cuyo camino base funciona.
2. **Pero tiene 3 estafas de seguridad puntuales y graves** (§2): WebAuthn sin verificar firma
   (bypass de MFA), DPoP falso, pipeline fail-open. **Son P0** — un sistema de identidad con
   WebAuthn que no verifica firma es peor que sin WebAuthn, porque promete AAL3 y da AAL0.
3. **Mucho está a medio o desconectado** (§4, §5): ADSIB, IAL, risk engine, emisor de auditoría,
   dominios external — el patrón "existe pero no opera".
4. **Viola sus propias reglas** (§7): 175 unwrap, fail-open donde exige fail-closed.
5. **Prioridad de reparación cruda:** P0 los bypasses de §2 (WebAuthn, DPoP, fail-open) →
   P1 lo que engaña sobre su madurez (risk dead_code, ADSIB, emisor auditoría) → P2 el resto.

**La honestidad como activo:** este anexo existe para que el proyecto enfrente su realidad
absoluta. Lo declarado honestamente (§6) es reparable con calma; lo que retorna `true` sin
trabajar (§2) es lo que hay que atacar HOY antes de cualquier optimización.

---

## 11. LA BASE ARQUITECTÓNICA — los contratos que la norma exige y faltan por desarrollar

Esta es la **infraestructura diseñada**: el catálogo explícito de los métodos/funciones que la
arquitectura de bAuth necesita para estar completa y que HOY faltan o son ficticios. Cada uno con
su **firma propuesta**, la **norma que lo exige**, el **manual/anexo que lo justifica** y su
**estado**. Es el mapa de "qué desarrollar" — sin ambigüedad, para programar sin fricciones.

> **✅ EL ANDAMIAJE YA ESTÁ EN CÓDIGO (2026-07-11): `src/domain/andamiaje.rs`.** El esqueleto
> arquitectónico está construido — los contratos que no existen (BA2, BA4, BA6, BA8, BA11, BA13)
> están definidos como **traits con firma exacta + justificación (norma/manual/anexo) + stub
> fail-closed** (`Pendiente`, que NIEGA hasta que se implemente — nunca un `Ok` ficticio). El
> desarrollador implementa el CUERPO; la firma ya está. Y `registro_base_arquitectonica()`
> devuelve el mapa de los 20 contratos con su estado — consultable por código (dashboard /
> `bauthctl`). Compila + 3 tests (fail-closed verificado, registro de 20, formato). **El proyecto
> ya no reinventa lo definido: va directo a llenar los cuerpos.**

**Leyenda de estado:** ✅ hecho · 🔧 a completar (existe, falta la parte crítica) · ❌ por
desarrollar (no existe) · ⚫ a cablear (existe, desconectado).

### 11.1 Núcleo de autenticación (fail-closed obligatorio)

| # | Contrato / función a desarrollar | Norma | Justificación | Estado |
|---|---|---|---|---|
| **BA1** | `WebAuthnValidator::verify_assertion(rp_id, client_data, sig, auth_data, public_key) -> Result<bool>` | W3C §7.2 | A.41 §2.1 · A.15-B1 | ✅ **HECHO 2026-07-11** — falta añadir **signature counter** (anti-clonación, §8) y búsqueda de clave por `credential_id` en BD (hoy por parámetro) → 🔧 |
| **BA2** | `DpopHandler`: `verify_dpop_proof(proof_jwt, access_token, htm, htu) -> Result<()>` — verificar firma con la `jwk` del header + `ath` (hash del token) + `htm`/`htu` + `jti` anti-replay + ventana `iat` | RFC 9449 | A.28-T1 · A.41 §2.2 | ❌ **por desarrollar** — hoy retorna `verified:true` sin verificar. Mismo patrón que BA1: verificar firma real con `ring`, o fail-closed |
| **BA3** | `DomainRegistry::evaluate_all`: cambiar `None => DomainResult::denegado` (hoy `permitido`) + alerta "dominio activo sin evaluador" | fail-closed (CLAUDE §8) | A.21 §4 · A.41 §2.3 | 🔧 **1 línea** — el fix es directo: invertir el default a denegado + test "dominio activo sin evaluador → denegado" |
| **BA4** | `LoginRateLimiter::check(username, client_ip) -> Result<()>` sobre `ath_login_attempt` — bloqueo tras N intentos por cuenta/IP (backoff exponencial) | OWASP ASVS 2.2.1 · NIST 800-63B §5.2.2 | A.41 §8 (faltante no considerado) | ❌ **por desarrollar** — la tabla `ath_login_attempt` existe; falta el motor que la consulte para bloquear brute-force online |
| **BA5** | `mtls`: `verify_x509_chain(cert_der) -> Result<CertInfo>` (parsing X.509, KU/EKU, cadena, revocación) + emitir token con claim `cnf`/`x5t#S256` (RFC 8705) | RFC 5280 · RFC 8705 | A.15-B3 · A.28-T2 | 🔧 **a completar** — `mtls.rs` no parsea el cert; incorporar `x509-parser` |

### 11.2 Identidad y credenciales

| # | Contrato / función | Norma | Justificación | Estado |
|---|---|---|---|---|
| **BA6** | `IdentityProofing::verify(evidence, ial_target) -> Result<IalResult>` + tabla/sección `identity_proofing` (ial_achieved, proofing_type, evidence[], proofed_by, reproofing_due) | NIST SP 800-63A | A.09 §4.bis · A.02 §19.2-U1 | ❌ **por desarrollar** — el IAL 1-3 no tiene código; es la fuente de la resolución A.02 U1 |
| **BA7** | Migración `bauth_NN__idn_atributo.sql`: tablas `idn_atributo` + `idn_tipo_atributo` (valores 1:N con clasificación y enmascaramiento) | SCIM RFC 7643 · ISO 24760-1 §6 | A.31-AT1 | ❌ **por desarrollar** — la tabla destino de los campos multivaluados del UserTemplate NO existe en el DDL |
| **BA8** | `SignatureEngineExternal::sign_adsib(doc_hash, cert) -> Result<Signature>` — motor de firma legal RSA-SHA256 con certificado ADSIB (validez jurídica Ley 164) | Ley 164 Art. 78 · ADSIB-FD-POLT-015 · eIDAS | A.08 §3.bis (F-C1) | ❌ **por desarrollar** — solo existe el motor interno Ed25519; el externo (firma legal) falta |
| **BA9** | `JwtSigner`: cablear la clave a **Vault PKI** (hoy en memoria dev) + política de rotación | NIST 800-57 | A.08 §3.bis (F-C2) · A.41 §8 | 🔧 **a completar** — la clave se genera en memoria; producción requiere la bóveda |

### 11.3 Motores escritos pero desconectados (cablear)

| # | Contrato / función | Norma | Justificación | Estado |
|---|---|---|---|---|
| **BA10** | Cablear `risk::RiskEngine::evaluate(ctx) -> RiskScore` al pipeline D8 + poblar el claim `risk_score` del JWT (hoy siempre None) + quitar `#![allow(dead_code)]` | NIST 800-207 §4 | A.26-R1/R2 | ⚫ **a cablear** — el motor (4 factores) existe, 0 invocaciones |
| **BA11** | `AuditEmitter::emit(event, iso_control[]) -> Result<()>` (módulo `audit/audit_event.rs`) + `audit/siem.rs` (salida Wazuh) | NIST AU-12 · ISO A.8.15 | A.27-AU1 | ❌ **por desarrollar** — `src/audit/` es solo mod.rs (94 líneas); el DDL superior casi sin emisor |
| **BA12** | Aplicar `bauth_44__gap04_worm_hash_chain.sql` en VPS (TRIGGER + REVOKE) — desbloquea auditoría WORM Y el motor de versionado 1.13 F2 | ISO A.5.33 | A.27-AU2 · A.33 | 🔧 **aplicar** — la migración está escrita, sin evidencia de aplicada |
| **BA13** | Motores IGA: `CertificationCampaign::run()` + `OrphanSweep::run()` + JML `sync::joiner/mover/leaver()` (hoy `sync/` = 173 líneas) | NIST AC-2(j) · ISO A.5.18 | A.10 §4.bis · A.30 | 🔧 **a completar** — tablas existen (`aud_review`/`aud_ghost_account`), motores ausentes |

### 11.4 Sustrato del BitMask y dominios

| # | Contrato / función | Norma | Justificación | Estado |
|---|---|---|---|---|
| **BA14** | Seeds `bauth_NN__atoms_dNN.sql` — sembrar los ~72 átomos D2–D12 + 36 de D13 (del catálogo A.05) | Diseño SBOS | A.05 · A.17-C1 | ❌ **por desarrollar** — sin ellos los planos External no tienen bits que evaluar |
| **BA15** | Decidir SAM-128: computar los 4 cuadrantes desde el RolBitMask, o **deprecar B9** en favor del RolBitMask Base64 (que sí existe) | G-B09 | A.17-C2 · A.01 §B9 | ❌ **decisión + desarrollo** — hoy los `*_domain_mask_hex` son decorativos |
| **BA16** | Completar los evaluadores de dominio delgados: D5–D12 (59–90 líneas) y en especial **D8/D9 Pre-BitMask** (deciden antes del BitMask) | NIST 800-207 | A.21 §5 | 🔧 **a completar** |
| **BA17** | RLS: `ALTER TABLE … ENABLE ROW LEVEL SECURITY` + `CREATE POLICY … USING (tenant_id = current_setting(...))` en las tablas tenant-scoped | NIST AC-4/SC-4 | A.22-M1 | ❌ **por desarrollar** — 0 policies; el aislamiento depende solo del `WHERE` del código |

### 11.5 Higiene de código (regla propia DOC-SBOS-001)

| # | Acción | Justificación | Estado |
|---|---|---|---|
| **BA18** | Reemplazar los **175 `unwrap/expect/panic` fuera de test** por `Result<T, BauthError>` — el CLAUDE exige "cero unwrap en producción" | A.41 §7 | 🔧 progresivo — cada uno es un pánico/DoS potencial |
| **BA19** | Auditar los **100 `#[allow(dead_code)]`**: eliminar los residuales (como `domain/bitmask.rs` ✅ ya eliminado), cablear los planificados (risk, audit) | A.41 §5 | 🔧 en curso — 1 huérfano eliminado 2026-07-11 |
| **BA20** | Retirar `idp_external.rs` declarativo (responde la arquitectura KC `realm_por_tenant` **eliminada** por ADR-010) o re-especificarlo nativo | Q5 · ADR-010 | 🔧 HITL doctrina |

### 11.6 Resumen de la base arquitectónica

**De 20 contratos de la base:** ✅ 1 hecho (BA1 WebAuthn) · 🔧 10 a completar (existe base) ·
❌ 8 por desarrollar (no existen) · ⚫ 1 a cablear. **El orden de construcción** (por dependencia
y severidad): BA3 (fail-closed pipeline, 1 línea) → BA2 (DPoP) → BA4 (rate-limit) → BA12 (aplicar
WORM, desbloquea BA11 y el motor 1.13) → BA11 (emisor auditoría) → BA10 (cablear risk) → BA6/BA7
(IAL + idn_atributo) → BA14/BA17 (átomos + RLS) → BA8/BA13 (ADSIB + IGA) → BA5/BA9/BA16 → BA18-20.

**Con este catálogo, el proyecto sabe exactamente:** lo ✅ desarrollado (núcleo robusto +
WebAuthn corregido), lo 🔧 a completar (10 contratos con base), lo ❌ por desarrollar (8 nuevos),
y lo ⚫ a cablear (risk). Cada uno trazable a su norma, manual y anexo.

---

## 10. Referencias

**Del código (grep 2026-07-11):** `webauthn.rs:61-84` · `token_protocols.rs:51` · `saga/login.rs:56` · `token_validate.rs:120` · `registry.rs` · `risk.rs` · barrido: 175 unwrap / 100 dead_code / 12 TODO.
**Normas (refuerzo):** [W3C WebAuthn L3 §7.2](https://www.w3.org/TR/webauthn-3/) · [RFC 9449 DPoP](https://datatracker.ietf.org/doc/html/rfc9449) · [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/) · [NIST 800-63B](https://pages.nist.gov/800-63-4/sp800-63b.html) · fail-closed (OWASP secure design).
**Anexos consolidados:** A.15 (stack) · A.17 (BitMask) · A.21 (pipeline) · A.26 (risk) · A.27 (auditoría) · A.28 (DPoP) · A.08 (firma).

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Auditoría de veracidad cruda (solicitud del humano: qué funciona vs estafa/ficticio/hardcodeado, con base en el código y refuerzo de normas/internet). Barrido de grep (175 unwrap fuera de test, 100 dead_code, 12 TODO). **Hallazgo P0 nuevo: WebAuthn `verify_assertion` es un BYPASS DE AUTENTICACIÓN** — no verifica la firma COSE (`_public_key_der` sin usar, solo comprueba longitud ≥16; el propio comentario línea 84 lo admite), retorna `user_verified:true` hardcodeado, viola W3C §7.2. Clasificación de 5 categorías (🟢 robusto: login Argon2/token_validate/JWT Ed25519/BitMask/Context Plane reales · 🟡 a medio: ADSIB/IAL/dominios · ⚫ muerto: risk/audit · 🔵 planificado honesto: motor versionado/átomos · 🔴 estafa: WebAuthn/DPoP/fail-open), violaciones de reglas propias (175 unwrap vs "cero unwrap"), y faltantes no considerados (rate-limit brute-force, signature counter, constant-time, key rotation). Veredicto: núcleo robusto real + 3 estafas de seguridad P0 a atacar primero. |
