# Anexo A.43 — El mapa completo de contratos para la categoría IAM Enterprise
## Todas las funciones/procesos que faltan para llegar a IAM Enterprise pleno (L4), por pilar, con estado de completitud

**Tipo:** ANEXO — mapa de completitud de la categoría (derivación sistemática de la carta rectora)
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Respalda a:** CARTA RECTORA (0.00 §4 pilares · §8 scorecard · §10 olas) · A.41 §11 (los 20 BA) · A.42 (las fichas de implementación) · todo el corpus
**Base:** derivación de los 7 pilares × sus criterios (0.00 §4) + las brechas del scorecard (0.00 §8) + la evidencia de código verificada en A.15–A.42
**Corrige:** A.41 §11 listaba 20 contratos = las **brechas de código** que la auditoría encontró. Este anexo deriva **TODA la categoría** — las capacidades que los 7 pilares exigen para L4, muchas de las cuales el código actual ni intenta.

---

## 0. Propósito y método

A.41 §11 tenía un sesgo: sus 20 contratos salieron de los **bugs/brechas que el código actual
tiene**, no de **todo lo que la categoría IAM Enterprise exige**. Son cosas distintas: arreglar
el código presente ≠ completar los 7 pilares hasta L4. Este anexo hace la derivación completa:
por cada pilar (0.00 §4), sus criterios de categoría, y **cada capacidad/función con su estado**.

**Estado de completitud (tres valores):**
- **✅ DESARROLLADO** — existe en código, funciona, verificado (con evidencia de anexo).
- **🔄 EN PROCESO** — existe base/sustrato pero incompleto o sin cablear (a medio construir).
- **⬜ POR DESARROLLAR** — no existe; la categoría lo exige.

**Numeración:** `<PILAR>-NN`. Donde aplica, se enlaza al contrato `BAn` de A.41/A.42.

---

## 1. Pilar I — AM (Access Management)

**Criterios (0.00 §4):** provider OIDC/SAML/OAuth2 · MFA resistente a phishing · passkeys ·
step-up (RFC 9470) · autenticación adaptativa · federación entrante · ciclo del token · FAPI 2.0.

| # | Capacidad / función | Norma | Ref. | Estado |
|---|---|---|---|:---:|
| AM-01 | OIDC Provider nativo (discovery + JWKS) | OIDC Core | 2.01 §11 / A.20 | ✅ |
| AM-02 | 9 métodos de autenticación nativos | 800-63B | 2.01 / A.15 | ✅ |
| AM-03 | WebAuthn verify_assertion (firma real) | W3C §7.2 | A.41 §2.1 / BA1 | ✅ |
| AM-04 | Passkeys | FIDO2 | 2.02 | ✅ |
| AM-05 | Step-up authentication | RFC 9470 | 2.01 §10 | ✅ |
| AM-06 | JWT propio firmado + hash-chain | RFC 7519 | 2.03 / A.28 | ✅ |
| AM-07 | Token validate (verifica firma) | RFC 7519 | A.41 §3 | ✅ |
| AM-08 | Token Exchange | RFC 8693 | A.16 | 🔄 |
| AM-09 | Introspection | RFC 7662 | A.28 | ✅ |
| AM-10 | **DPoP completo** (verificación real) | RFC 9449 | A.28 / **BA2** | ⬜ |
| AM-11 | **mTLS-bound tokens** (cnf/x5t) | RFC 8705 | A.28 / **BA5** | ⬜ |
| AM-12 | **WebAuthn attestation** (FIDO MDS) + **signature counter** | W3C §7.1/§7.2 | A.15-B1 / BA1 | 🔄 |
| AM-13 | **FAPI 2.0 + PAR** (RFC 9126) | FAPI 2.0 | A.20-O2 | ⬜ |
| AM-14 | **Federación entrante — social/OIDC broker** | OIDC | 0.00 §8 / A.20-O3 | ⬜ |
| AM-15 | **Federación entrante — LDAP/AD connector** | LDAP | 0.00 §8 | ⬜ |
| AM-16 | **Federación entrante — Kerberos/SPNEGO** | RFC 4559 | 0.00 §8 | ⬜ |
| AM-17 | **SAML SP entrante completo** (protección XSW) | SAML 2.0 | A.15-B2 | 🔄 |
| AM-18 | **CIBA** (backchannel auth) | OpenID CIBA | 2.02 | ⬜ |
| AM-19 | **Device Authorization Grant** | RFC 8628 | 2.02 | ⬜ |
| AM-20 | **Rate-limit anti-brute-force** | ASVS 2.2.1 | A.42 / **BA4** | ⬜ |
| AM-21 | **Rotación de claves de firma** | NIST 800-57 | A.08 / **BA9** | 🔄 |

**Completitud AM: 9 ✅ · 4 🔄 · 8 ⬜ (de 21)**

---

## 2. Pilar II — IGA (Identity Governance & Administration)

**Criterios:** JML automatizado · campañas de certificación · role management + mining · SoD
estático y dinámico · SCIM · detección de huérfanas y privilege creep.

| # | Capacidad / función | Norma | Ref. | Estado |
|---|---|---|---|:---:|
| IGA-01 | SoD nativo O(1) (matriz de conflictos) | INCITS 359 · AC-5 | A.17 | ✅ |
| IGA-02 | Ciclo de vida del rol (7 estados) | AC-2(j) | 1.09 §10 | ✅ |
| IGA-03 | Tablas de certificación y huérfanas (DDL) | ISO A.5.18 | 5.01 | ✅ |
| IGA-04 | Handlers de ciclo de vida de roles (montados) | — | A.19 | ✅ |
| IGA-05 | **Motor de campañas de certificación** | AC-2(j) | A.30 / **BA13** | 🔄 |
| IGA-06 | **Barrido de cuentas huérfanas** (motor) | AC-2(j) | A.30 / **BA13** | 🔄 |
| IGA-07 | **JML Joiner automatizado** (desde RRHH) | ISO A.5.18 | A.10 / 1.08 §7 | 🔄 |
| IGA-08 | **JML Mover automatizado** | ISO A.5.18 | A.10 | 🔄 |
| IGA-09 | **JML Leaver automatizado** (offboarding) | AC-2(3) | A.10 | 🔄 |
| IGA-10 | **Role mining** (analítica de asignaciones) | — | 0.00 §8 | ⬜ |
| IGA-11 | **Privilege creep detection** (revisión trimestral) | AC-6 | A.10 | ⬜ |
| IGA-12 | **SCIM 2.0 server bidireccional** (provisioning) | RFC 7644 | 9.02 §18 / DIR-04 | 🔄 |
| IGA-13 | **Access request workflow** (solicitud+aprobación) | AC-5 | A.01 §B3 | ⬜ |
| IGA-14 | **Certificación asistida por IA** (ola 3) | — | 0.00 §10 | ⬜ |

**Completitud IGA: 4 ✅ · 6 🔄 · 4 ⬜ (de 14)**

---

## 3. Pilar III — PAM (Privileged Access Management)

**Criterios:** bóveda de credenciales · JIT con auto-expiración · break-glass · grabación/
monitoreo de sesión privilegiada · rotación de credenciales.

| # | Capacidad / función | Norma | Ref. | Estado |
|---|---|---|---|:---:|
| PAM-01 | Bóveda (Vault) — integración | — | 2.09 | 🔄 |
| PAM-02 | Break-glass / acceso de emergencia | AC-2(2) | A.01 §B2 | ✅ |
| PAM-03 | JIT parcial (delegación D10) | AC-6(3) | A.01 §B10 | 🔄 |
| PAM-04 | **JIT completo** (elevación temporal con auto-expiración) | AC-6(3) | 0.00 §8 | ⬜ |
| PAM-05 | **Grabación de sesión privilegiada** | AC-6 · PCI 10 | 0.00 §8 | ⬜ |
| PAM-06 | **Monitoreo de sesión privilegiada en vivo** | AC-6 | 0.00 §8 | ⬜ |
| PAM-07 | **Rotación automática de credenciales** | IA-5 | 0.00 §8 | ⬜ |
| PAM-08 | **Aislamiento de sesión privilegiada** | AC-6 | 0.00 §8 | ⬜ |
| PAM-09 | **Vault PKI cableado** (clave de firma) | NIST 800-57 | A.08 / **BA9** | 🔄 |
| PAM-10 | **Credential checkout/checkin** (préstamo de secretos) | — | 0.00 §8 | ⬜ |

**Completitud PAM: 1 ✅ · 3 🔄 · 6 ⬜ (de 10) — el pilar MENOS maduro**

---

## 4. Pilar IV — ITDR (Identity Threat Detection & Response)

**Criterios:** risk engine dinámico · evaluación continua · analítica conductual · CAE/SSF-CAEP
· respuesta automática · feeds de amenazas.

| # | Capacidad / función | Norma | Ref. | Estado |
|---|---|---|---|:---:|
| ITDR-01 | Risk engine (4 factores) escrito | 800-207 §4 | A.26 | 🔄 |
| ITDR-02 | Notificación de seguridad | — | A.10 | ✅ |
| ITDR-03 | Cliente CAEP salida (emitir señales) | CAEP 1.0 | A.38 | ✅ |
| ITDR-04 | **Cablear risk engine al pipeline D8** | 800-207 §4 | A.26 / **BA10** | ⬜ |
| ITDR-05 | **Poblar risk_score del JWT** | 800-207 | A.26 / **BA10** | ⬜ |
| ITDR-06 | **Evaluación continua post-login (CAE)** | CAEP | 0.00 §8 | ⬜ |
| ITDR-07 | **Consumir señales CAEP entrantes** (lazo de entrada) | CAEP | A.38-N1 | ⬜ |
| ITDR-08 | **Analítica conductual UEBA** (baseline) | — | A.02 §B13 | ⬜ |
| ITDR-09 | **Respuesta automática** (step-up/revoke on anomaly) | 800-207 | 3.01 | ⬜ |
| ITDR-10 | **Impossible travel detection** | — | A.01 §B4 | ⬜ |
| ITDR-11 | **Feeds de amenazas externos** | — | 0.00 §8 | ⬜ |

**Completitud ITDR: 2 ✅ · 1 🔄 · 8 ⬜ (de 11)**

---

## 5. Pilar V — Directory & Identity Store

**Criterios:** modelo extensible · multi-tenancy · atributos con clasificación · NHI tipadas y
gobernadas · árbol organizacional.

| # | Capacidad / función | Norma | Ref. | Estado |
|---|---|---|---|:---:|
| DIR-01 | D00 árbol organizacional universal | ISO 24760 | 1.06 | ✅ |
| DIR-02 | Multi-tenancy (pool) | — | 1.12 | ✅ |
| DIR-03 | NHI tipado (catálogo de tipos) | AC-2 | A.01 §B1 | ✅ |
| DIR-04 | UserTemplate + validador | SCIM | A.02 / A.23 | ✅ |
| DIR-05 | **DDL `idn_atributo` + `idn_tipo_atributo`** | RFC 7643 | A.31 / **BA7** | ⬜ |
| DIR-06 | **Migrar 1:N del JSONB a idn_atributo** | 1.08 §3 | A.31 | ⬜ |
| DIR-07 | **Clasificación por atributo + enmascaramiento efectivo** | ISO A.5.12 | A.37-SD2 | 🔄 |
| DIR-08 | **Gobernanza NHI** (ciclo de vida propio de identidades no-humanas) | PAM NHI | 0.00 §8 | ⬜ |
| DIR-09 | **SCIM ↔ store bidireccional** | RFC 7644 | 0.00 §8 | 🔄 |
| DIR-10 | **RLS multi-tenant** (defensa en profundidad) | AC-4/SC-4 | A.22 / **BA17** | ⬜ |

**Completitud Directory: 4 ✅ · 2 🔄 · 4 ⬜ (de 10)**

---

## 6. Pilar VI — Standards & Compliance

**Criterios:** cumplimiento con catálogo · compliance como dato · certificación verificable ·
auditoría WORM · evidencia continua.

| # | Capacidad / función | Norma | Ref. | Estado |
|---|---|---|---|:---:|
| STD-01 | Compliance como dato (standard_ref, iso_control[]) | ISO A.8.5 | 7.03 | ✅ |
| STD-02 | 16 marcos normativos sembrados | — | 7.03 / A.06/A.07 | ✅ |
| STD-03 | Certificados firmados Ed25519 (DDL) | ISO A.8.9 | 7.03 §8 | ✅ |
| STD-04 | Auditoría WORM (DDL: aud_event + hash-chain) | A.8.15 | 5.01 / A.27 | ✅ |
| STD-05 | Merkle Engine (anclaje) | RFC 6962 | A.12 | ✅ |
| STD-06 | **Emisor central de auditoría** | AU-12 | A.27 / **BA11** | 🔄 |
| STD-07 | **Aplicar bauth_44 WORM en VPS** | A.5.33 | A.27 / **BA12** | 🔄 |
| STD-08 | **Lazo QA → tablas** (poblar compliance_test_result) | ISO A.8.9 | A.25 | ⬜ |
| STD-09 | **Poblar compliance_requirement** (marcos reales) | A.8.5 | A.25 | ⬜ |
| STD-10 | **Cargar vectores oficiales RFC** (test_case) | — | A.25 / A.15-B5 | ⬜ |
| STD-11 | **Reporte de cumplimiento autogenerado** | ISO 9001 §9.2 | A.25 | ⬜ |
| STD-12 | **Marcos EU 2026 (NIS2/DORA/AI Act)** fw_17-19 | NIS2/DORA | 7.03 §9 | ⬜ |
| STD-13 | **Firma de bloques de eventos** (AU-9) | AU-9 | 5.01 §11 | ⬜ |
| STD-14 | **Verificador de hash-chain expuesto** | — | 5.01 | ⬜ |
| STD-15 | **Salida SIEM Wazuh operativa** | 800-92 | A.27-AU3 | ⬜ |

**Completitud Standards: 5 ✅ · 2 🔄 · 8 ⬜ (de 15)**

---

## 7. Pilar VII — Enterprise Platform (transversal)

**Criterios:** soberanía · HA y escala · API-first · observabilidad · seguridad por diseño ·
gobierno de datos (RGPD) · extensibilidad · operación (runbook) · frontend.

| # | Capacidad / función | Norma | Ref. | Estado |
|---|---|---|---|:---:|
| PLT-01 | Soberanía (binario MUSL, sin SaaS) | — | A.40 | ✅ |
| PLT-02 | Superficie mínima (Unix socket, deny-all) | SBOS-050 | A.11 / A.16 | ✅ |
| PLT-03 | API-first (≈151 métodos JSON-RPC) | — | A.16 / A.19 | ✅ |
| PLT-04 | Interface Dual (WebSocket + JSON-RPC) | ADR-020 | A.16 | ✅ |
| PLT-05 | Context Plane (ctx_id) | 800-207 | A.14 | ✅ |
| PLT-06 | Defensa en profundidad (STRIDE) | STRIDE | A.11 | 🔄 |
| PLT-07 | **Frontend Flutter** (resolver divergencia 3 stacks) | — | A.18 / **BA-P1** | 🔄 |
| PLT-08 | **SPIFFE/SVID** (identidad de workload) | SPIFFE | 0.00 §8 | ⬜ |
| PLT-09 | **HA verificada** (failover, réplica) | CP-9/10 | A.29 | ⬜ |
| PLT-10 | **Runbook operativo** | CP | A.29 / 6.01 | ⬜ |
| PLT-11 | **WatchdogSec systemd** | — | A.29-OP1 | 🔄 |
| PLT-12 | **OpenRPC spec de la superficie** | OpenRPC | A.16-F1 | ⬜ |
| PLT-13 | **Observabilidad completa** (métricas + tracing) | — | 6.01 | 🔄 |
| PLT-14 | **Cifrado en reposo verificado** | RGPD 32 | A.37-SD1 | 🔄 |
| PLT-15 | **Field-level encryption / tokenización** | — | A.37-SD4 | ⬜ |
| PLT-16 | **Backup/restore probado** | CP-9 | A.29 | ⬜ |
| PLT-17 | **Gestor de Canales Protegidos** — punto único que gobierna TODOS los canales (entrante gRPC/JSON-RPC/WebSocket/socket + saliente HTTP/gRPC) con cifrado aprobado, mTLS, verificación del par, timeouts/reintentos y observabilidad. Hoy DISPERSO en 20+ archivos (inverificable) | **NIST 800-63B "authenticated protected channel"** · RFC 8705 (mTLS) · RFC 8446 (TLS 1.3) · 800-207 (PEP) | nuevo (ver §5.bis) | ⬜ |

**Completitud Platform: 5 ✅ · 5 🔄 · 7 ⬜ (de 17)**

> **PLT-17 — el hallazgo del control de canales (§5.bis):** el término es normativo, no propio —
> NIST SP 800-63B define **"authenticated protected channel"** como el canal cifrado con
> criptografía aprobada donde el iniciador autenticó al receptor, y **exige** que TODO el proceso
> de autenticación ocurra sobre él (y mTLS entre verifier↔CSP). El control de esos canales está
> hoy **disperso** (HTTP saliente en 10+ archivos, TLS en 10+, gRPC en 3, sin módulo único —
> verificado): es **imposible garantizar de forma auditable que todos cumplen "protected channel"**.
> Amerita subsistema propio: motor (`src/transport/`) + manual (2.12) + ADR + esta fila. Es de
> **seguridad de fondo → Fase 1** (no al final): un IdP con canales dispersos no certifica NIST/FAPI.

---

## 8. Núcleo transversal (no un pilar, pero condiciona a todos)

| # | Capacidad / función | Ref. | Estado |
|---|---|---|:---:|
| CORE-01 | Motor BitMask Dual (evaluación O(1)) | A.17 | ✅ |
| CORE-02 | Pipeline de dominios (orden correcto) | A.21 | ✅ |
| CORE-03 | **Pipeline fail-closed** (None => denegado) | A.21 / **BA3** | ⬜ |
| CORE-04 | **Seeds de átomos D2–D13** | A.05 / **BA14** | ⬜ |
| CORE-05 | **SAM-128: computar o deprecar B9** | A.17 / **BA15** | ⬜ |
| CORE-06 | **Completar evaluadores D5–D12 + D8/D9** | A.21 / **BA16** | 🔄 |
| CORE-07 | **Motor de Versionado Universal** (1.13 F2-F5) | A.33 | ⬜ |
| CORE-08 | **Reemplazar 175 unwrap por Result** | A.41 §7 / **BA18** | 🔄 |
| CORE-09 | **Auditar 100 allow(dead_code)** | A.41 §5 / **BA19** | 🔄 |
| CORE-10 | **Retirar idp_external declarativo** (KC eliminado) | A.41 / **BA20** | 🔄 |
| CORE-11 | **Módulo Criptográfico único** — centralizar las primitivas de cifrado dispersas (ring en 34 archivos, ed25519 en 15, argon2 en 8, sha2/hmac en 9) tras UNA frontera con algoritmos aprobados, self-tests y gestión de claves. **NIST FIPS 140-3** («cryptographic module»). Hoy cada método/handler invoca `ring`/`argon2`/`hmac` directo | **FIPS 140-3** · 800-63B | nuevo (§8.bis) | ⬜ |
| CORE-12 ⟂ | **Completar el motor de métodos a los 18** — el `MethodRegistry` (2.01 §3.3, patrón PAM) YA existe con 9/18 métodos; faltan passkey, X.509-smartcard, Kerberos, social-brokering, CIBA, device-auth, conditional-OTP, client-credentials, token-exchange. *Vista agregada — estos 9 ya se cuentan en el Pilar I AM (§4.I); no suma al total.* | 800-63B · el catálogo (CLAUDE) | 2.01 §4 | 🔄 |

**Completitud Núcleo: 2 ✅ · 4 🔄 · 5 ⬜ (de 11 contables; CORE-12 ⟂ es vista agregada del Pilar I AM, no suma al total)**

> **CORE-11/12 — el motor de autenticación (§8.bis):** el «motor unificado de métodos» **ya
> existe** — es el `MethodRegistry` + trait `AuthMethod` (2.01 §3.2-3.3), el patrón **PAM
> (Pluggable Authentication Module)**, estándar de facto Unix/Linux: una API única donde cada
> método se registra y se invoca sin que el llamador conozca su mecanismo. No se reinventa: se
> **completa** a los 18 (CORE-12). Lo que SÍ falta y está disperso es la **cripto** — las
> primitivas (`ring`/`argon2`/`ed25519`/`hmac`) se invocan directo en 34+ archivos, sin la
> **frontera de módulo criptográfico** que exige FIPS 140-3 (interfaces definidas, self-tests,
> gestión de claves): eso amerita el subsistema CORE-11 (`src/crypto/`), análogo al Gestor de
> Canales para la cripto.

---

## 9. El scorecard de completitud — la foto global

| Pilar | Total | ✅ Desarrollado | 🔄 En proceso | ⬜ Por desarrollar | % avance* |
|---|:---:|:---:|:---:|:---:|:---:|
| I — AM | 21 | 9 | 4 | 8 | ~52% |
| II — IGA | 14 | 4 | 6 | 4 | ~50% |
| III — PAM | 10 | 1 | 3 | 6 | ~25% |
| IV — ITDR | 11 | 2 | 1 | 8 | ~23% |
| V — Directory | 10 | 4 | 2 | 4 | ~50% |
| VI — Standards | 15 | 5 | 2 | 8 | ~40% |
| VII — Platform | 16 | 5 | 5 | 6 | ~47% |
| Núcleo | 11 | 2 | 4 | 5 | ~36% |
| **TOTAL** | **108** | **32** | **27** | **49** | **~42%** |

*Nota: +1 vs. v1.0.0 (CORE-11 Módulo Criptográfico, FIPS 140-3 — ADR-012). CORE-12 (completar métodos a 18) es vista agregada del Pilar I AM, no suma.*

*% avance = (✅ + 0.5·🔄) / total. Es una estimación de completitud, no de esfuerzo.

**Lectura cruda:** **108 contratos** para la categoría IAM Enterprise plena — no 20. **~42% de
completitud** ponderada: **32 desarrollados** (el núcleo robusto: AM base, BitMask, Context Plane,
compliance como dato), **27 en proceso** (sustrato sin cablear: risk, auditoría, IGA, JML), y
**48 por desarrollar** (lo que el código actual ni intenta: PAM completo, federación entrante,
ITDR continuo, NHI, HA, SPIFFE). Coincide con el veredicto de la carta rectora (0.00 §8):
*"cumple la categoría en diseño y sustrato; la distancia es de integración (L2→L3)"* — pero
cuantificado. **Los pilares más lejos: PAM (~25%) e ITDR (~23%)** — como el scorecard §8 anticipó.

**El orden (olas de 0.00 §10):** Ola 1 (encender motores L2→L3): ITDR-04/05, IGA-05/06, STD-06 →
los 🔄 se vuelven ✅. Ola 2 (cerrar convergencia): AM-14/15/16 federación, IGA-07/08/09 JML,
ITDR-06, PAM-05, PLT-07 frontend. Ola 3 (ciclo cerrado L4): ITDR conductual+feeds, IGA-14 IA,
DIR-08 NHI, PQC, STD-12 marcos EU.

---

## 10. Orden de desarrollo — qué se implementa primero y qué después

La secuencia concreta, ordenada por **(1) riesgo de seguridad activo → (2) lo que desbloquea a
otros → (3) valor/esfuerzo**. Cada fase indica **qué desbloquea** para la siguiente.

### FASE 0 — Seguridad crítica (riesgo activo, va PRIMERO)
Un IAM con bypasses no puede optimizarse antes de cerrarlos.
1. **AM-03 WebAuthn** (verify_assertion real) — ✅ **HECHO 2026-07-11**.
2. **CORE-03 / BA3** pipeline fail-closed (`None => denegado`) — 1 línea + test. **Trivial, primero.**
3. **AM-10 / BA2** DPoP real (RFC 9449, 12 pasos — A.42 §2).
4. **AM-20 / BA4** rate-limit anti-brute-force login (A.42 §4).
> Cierre de fase: cero bypasses; el núcleo de autenticación es fiable.

### FASE 1 — Fundamentos que DESBLOQUEAN (dependencias raíz)
Se hacen antes que los motores porque muchos dependen de ellos.
5. **STD-07 / BA12** aplicar `bauth_44` WORM en VPS → **desbloquea** STD-06 (emisor auditoría) Y el Motor de Versionado (CORE-07, 1.13 F2).
6. **DIR-05 / BA7** DDL `idn_atributo` + `idn_tipo_atributo` (A.42 §6) → **desbloquea** DIR-06 (migrar 1:N) y BA6 (persistencia del IAL).
7. **CORE-04 / BA14** seeds de átomos D2–D13 → **desbloquea** CORE-06 (evaluadores) y los planos External del pipeline (sin bits no hay qué evaluar).
8. **DIR-10 / BA17** RLS multi-tenant (A.42 §10) — defensa en profundidad, DDL por tabla.
> Cierre: el sustrato de datos está completo; los motores ya tienen dónde operar.

### FASE 2 — Encender los motores que YA EXISTEN (Ola 1 · los 🔄 → ✅)
Máximo valor/mínimo esfuerzo: cablear lo escrito, no construir de cero.
9. **STD-06 / BA11** emisor central de auditoría (A.42 §8) — depende de FASE 1 (BA12).
10. **STD-15** salida SIEM Wazuh — depende de BA11.
11. **ITDR-04/05 / BA10** cablear el Risk Engine al pipeline D8 + poblar `risk_score` del JWT.
12. **IGA-05/06 / BA13** motores de campañas de certificación + barrido de huérfanas (A.42 §9).
13. **STD-08/09/10** lazo QA → poblar `compliance_requirement` + vectores RFC.
14. **CORE-06 / BA16** completar los evaluadores de dominio delgados (D5–D12, D8/D9).
> Cierre: todos los pilares suben a L3; el ~42% pasa a ~60%+.

### FASE 3 — Cerrar la convergencia (Ola 2 · construcción nueva)
15. **IGA-07/08/09** JML automatizado (Joiner/Mover/Leaver desde RRHH vía biedata).
16. **AM-14/15/16** federación entrante (social/OIDC broker · LDAP/AD · Kerberos).
17. **AM-12** WebAuthn attestation + signature counter · **AM-13** FAPI 2.0/PAR · **AM-11/BA5** mTLS-bound.
18. **PAM-04/05/07** JIT completo + grabación de sesión + rotación de credenciales.
19. **DIR-09** SCIM bidireccional · **PLT-07** frontend Flutter (tras resolver la divergencia A.18).
20. **STD-08 (firma) BA8** motor ADSIB (firma legal Ley 164, A.42 §7).
> Cierre: los 4 pilares convergentes (AM/IGA/PAM/ITDR) operativos.

### FASE 4 — El ciclo cerrado L4 (Ola 3)
21. **ITDR-06/08/11** evaluación continua (CAE) + UEBA conductual + feeds de amenazas.
22. **DIR-08** gobernanza NHI completa · **IGA-10/14** role mining + certificación asistida por IA.
23. **STD-12** marcos EU 2026 (NIS2/DORA/AI Act) · **PLT-08/09** SPIFFE + HA verificada · PQC.
> Cierre: IAM Enterprise pleno (L4) — ciclo detección→respuesta→causa raíz→remediación.

**Regla transversal (en paralelo, continuo):** CORE-08/BA18 (reemplazar los 175 unwrap) y
CORE-09/BA19 (auditar dead_code) se atienden como higiene continua en cada PR, no como fase.

**El grafo de dependencias en una línea:** `BA3 → (BA2, BA4) ‖ BA12 → BA11 → SIEM` · `BA7 → IAL`
· `BA14 → evaluadores` · `BA11 + BA10 → ITDR continuo` · `tablas IGA + JML → certificación`.

---

## 11. TABLA MAESTRA — TODAS las tareas en una sola vista (hecho + orden de desarrollo)

Una **sola tabla** con los ~106 contratos de la categoría: primero lo **✅ ya desarrollado** (la
base construida, sin número de orden porque está hecha), luego las **pendientes en orden de
implementación** (#1→72 + 3 continuas), por las fases de §10. No reemplaza las tablas por
pilar (§1–§8) — es la vista única de ejecución. **Estado:** ✅ hecho · 🔄 en proceso · ⬜ por desarrollar.

| # | Contrato | Tarea | Pilar | Estado | Fase | Depende de |
|:--:|---|---|:--:|:--:|:--:|---|
| ✓ | AM-01 | OIDC Provider nativo (discovery + JWKS) | I | ✅ | hecho | — |
| ✓ | AM-02 | 9 métodos de autenticación nativos | I | ✅ | hecho | — |
| ✓ | AM-03 | WebAuthn verify_assertion (firma real W3C §7.2) | I | ✅ | hecho | — |
| ✓ | AM-04 | Passkeys | I | ✅ | hecho | — |
| ✓ | AM-05 | Step-up authentication (RFC 9470) | I | ✅ | hecho | — |
| ✓ | AM-06 | JWT propio firmado Ed25519 + hash-chain | I | ✅ | hecho | — |
| ✓ | AM-07 | Token validate (verifica firma criptográfica) | I | ✅ | hecho | — |
| ✓ | AM-09 | Introspection (RFC 7662) | I | ✅ | hecho | — |
| ✓ | IGA-01 | SoD nativo O(1) (matriz de conflictos) | II | ✅ | hecho | — |
| ✓ | IGA-02 | Ciclo de vida del rol (7 estados) | II | ✅ | hecho | — |
| ✓ | IGA-03 | Tablas de certificación y huérfanas (DDL) | II | ✅ | hecho | — |
| ✓ | IGA-04 | Handlers de ciclo de vida de roles (montados) | II | ✅ | hecho | — |
| ✓ | PAM-02 | Break-glass / acceso de emergencia | III | ✅ | hecho | — |
| ✓ | ITDR-02 | Notificación de seguridad | IV | ✅ | hecho | — |
| ✓ | ITDR-03 | Cliente CAEP salida (emitir señales) | IV | ✅ | hecho | — |
| ✓ | DIR-01 | D00 árbol organizacional universal | V | ✅ | hecho | — |
| ✓ | DIR-02 | Multi-tenancy (pool) | V | ✅ | hecho | — |
| ✓ | DIR-03 | NHI tipado (catálogo de tipos) | V | ✅ | hecho | — |
| ✓ | DIR-04 | UserTemplate + validador (495 líneas) | V | ✅ | hecho | — |
| ✓ | STD-01 | Compliance como dato (standard_ref, iso_control[]) | VI | ✅ | hecho | — |
| ✓ | STD-02 | 16 marcos normativos sembrados | VI | ✅ | hecho | — |
| ✓ | STD-03 | Certificados firmados Ed25519 (DDL) | VI | ✅ | hecho | — |
| ✓ | STD-04 | Auditoría WORM (aud_event + hash-chain, DDL) | VI | ✅ | hecho | — |
| ✓ | STD-05 | Merkle Engine (anclaje RFC 6962) | VI | ✅ | hecho | — |
| ✓ | PLT-01 | Soberanía (binario MUSL, sin SaaS) | VII | ✅ | hecho | — |
| ✓ | PLT-02 | Superficie mínima (Unix socket, deny-all) | VII | ✅ | hecho | — |
| ✓ | PLT-03 | API-first (≈151 métodos JSON-RPC) | VII | ✅ | hecho | — |
| ✓ | PLT-04 | Interface Dual (WebSocket + JSON-RPC) | VII | ✅ | hecho | — |
| ✓ | PLT-05 | Context Plane (ctx_id, 535 líneas) | VII | ✅ | hecho | — |
| ✓ | CORE-01 | Motor BitMask Dual (evaluación O(1), 2.640 líneas) | Núcleo | ✅ | hecho | — |
| ✓ | CORE-02 | Pipeline de dominios (orden correcto) | Núcleo | ✅ | hecho | — |
| 1 | CORE-03 / BA3 | Pipeline fail-closed (`None => denegado`) | Núcleo | ⬜ | 0 | — |
| 2 | AM-10 / BA2 | DPoP real (RFC 9449, 12 pasos) | I | ⬜ | 0 | — |
| 3 | AM-20 / BA4 | Rate-limit anti-brute-force login | I | ⬜ | 0 | — |
| 4 | STD-07 / BA12 | Aplicar `bauth_44` WORM en VPS | VI | 🔄 | 1 | — |
| 5 | DIR-05 / BA7 | DDL `idn_atributo` + `idn_tipo_atributo` | V | ⬜ | 1 | — |
| 6 | CORE-04 / BA14 | Seeds de átomos D2–D13 | Núcleo | ⬜ | 1 | — |
| 7 | DIR-10 / BA17 | RLS multi-tenant (por tabla) | V | ⬜ | 1 | — |
| 8 | DIR-06 | Migrar 1:N del JSONB a `idn_atributo` | V | ⬜ | 1 | #5 |
| 8b | PLT-17 | **Gestor de Canales Protegidos** (centralizar todos los transportes) | VII | ⬜ | 1 | — |
| 9 | STD-06 / BA11 | Emisor central de auditoría | VI | 🔄 | 2 | #4 |
| 10 | STD-15 | Salida SIEM Wazuh operativa | VI | ⬜ | 2 | #9 |
| 11 | ITDR-04 / BA10 | Cablear Risk Engine al pipeline D8 | IV | ⬜ | 2 | — |
| 12 | ITDR-05 | Poblar `risk_score` del JWT | IV | ⬜ | 2 | #11 |
| 13 | IGA-05 / BA13 | Motor de campañas de certificación | II | 🔄 | 2 | — |
| 14 | IGA-06 / BA13 | Barrido de cuentas huérfanas | II | 🔄 | 2 | — |
| 15 | CORE-06 / BA16 | Completar evaluadores D5–D12 + D8/D9 | Núcleo | 🔄 | 2 | #6 |
| 16 | CORE-07 | Motor de Versionado Universal (1.13 F2–F5) | Núcleo | ⬜ | 2 | #4 |
| 17 | STD-09 | Poblar `compliance_requirement` (marcos reales) | VI | ⬜ | 2 | — |
| 18 | STD-10 | Cargar vectores oficiales RFC (test_case) | VI | ⬜ | 2 | — |
| 19 | STD-08 | Lazo QA → poblar `compliance_test_result` | VI | ⬜ | 2 | #17,#18 |
| 20 | STD-13 | Firma de bloques de eventos (AU-9) | VI | ⬜ | 2 | #9 |
| 21 | STD-14 | Verificador de hash-chain expuesto | VI | ⬜ | 2 | #4 |
| 22 | IGA-07 | JML Joiner automatizado (desde RRHH) | II | 🔄 | 3 | — |
| 23 | IGA-08 | JML Mover automatizado | II | 🔄 | 3 | #22 |
| 24 | IGA-09 | JML Leaver automatizado (offboarding) | II | 🔄 | 3 | #22 |
| 25 | IGA-12 | SCIM 2.0 server bidireccional | II | 🔄 | 3 | #5 |
| 26 | IGA-11 | Privilege creep detection | II | ⬜ | 3 | — |
| 27 | IGA-13 | Access request workflow | II | ⬜ | 3 | — |
| 28 | AM-14 | Federación entrante — social/OIDC broker | I | ⬜ | 3 | — |
| 29 | AM-15 | Federación entrante — LDAP/AD connector | I | ⬜ | 3 | — |
| 30 | AM-16 | Federación entrante — Kerberos/SPNEGO | I | ⬜ | 3 | — |
| 31 | AM-17 | SAML SP entrante completo (protección XSW) | I | 🔄 | 3 | — |
| 32 | AM-12 | WebAuthn attestation + signature counter | I | 🔄 | 3 | — |
| 33 | AM-11 / BA5 | mTLS-bound tokens (cnf/x5t) + parsing X.509 | I | ⬜ | 3 | — |
| 34 | AM-13 | FAPI 2.0 + PAR (RFC 9126) | I | ⬜ | 3 | #2,#33 |
| 35 | AM-08 | Token Exchange completo | I | 🔄 | 3 | — |
| 36 | AM-18 | CIBA (backchannel auth) | I | ⬜ | 3 | — |
| 37 | AM-19 | Device Authorization Grant | I | ⬜ | 3 | — |
| 38 | AM-21 / BA9 | Rotación de claves de firma + Vault PKI | I | 🔄 | 3 | — |
| 39 | PAM-09 | Vault PKI cableado (clave de firma) | III | 🔄 | 3 | #38 |
| 40 | PAM-01 | Bóveda (Vault) — integración completa | III | 🔄 | 3 | — |
| 41 | PAM-04 | JIT completo (elevación con auto-expiración) | III | ⬜ | 3 | — |
| 42 | PAM-05 | Grabación de sesión privilegiada | III | ⬜ | 3 | — |
| 43 | PAM-06 | Monitoreo de sesión privilegiada en vivo | III | ⬜ | 3 | #42 |
| 44 | PAM-07 | Rotación automática de credenciales | III | ⬜ | 3 | #40 |
| 45 | PAM-08 | Aislamiento de sesión privilegiada | III | ⬜ | 3 | — |
| 46 | PAM-10 | Credential checkout/checkin | III | ⬜ | 3 | #40 |
| 47 | BA6 | Identity Proofing IAL 1-3 | I/V | ⬜ | 3 | #5 |
| 48 | BA8 | Motor de firma externo ADSIB (Ley 164) | VI | ⬜ | 3 | #40 |
| 49 | DIR-09 | SCIM ↔ store bidireccional | V | 🔄 | 3 | #25 |
| 50 | DIR-07 | Clasificación por atributo + enmascaramiento | V | 🔄 | 3 | #5 |
| 51 | PLT-07 | Frontend Flutter (resolver divergencia 3 stacks) | VII | 🔄 | 3 | — |
| 52 | PLT-06 | OpenRPC spec de la superficie | VII | ⬜ | 3 | — |
| 53 | PLT-11 | WatchdogSec systemd | VII | 🔄 | 3 | — |
| 54 | PLT-14 | Cifrado en reposo verificado | VII | 🔄 | 3 | — |
| 55 | ITDR-06 | Evaluación continua post-login (CAE) | IV | ⬜ | 4 | #11 |
| 56 | ITDR-07 | Consumir señales CAEP entrantes | IV | ⬜ | 4 | #11 |
| 57 | ITDR-08 | Analítica conductual UEBA (baseline) | IV | ⬜ | 4 | #11 |
| 58 | ITDR-09 | Respuesta automática (step-up/revoke on anomaly) | IV | ⬜ | 4 | #55 |
| 59 | ITDR-10 | Impossible travel detection | IV | ⬜ | 4 | #57 |
| 60 | ITDR-11 | Feeds de amenazas externos | IV | ⬜ | 4 | — |
| 61 | DIR-08 | Gobernanza NHI (ciclo de vida no-humano) | V | ⬜ | 4 | — |
| 62 | IGA-10 | Role mining (analítica de asignaciones) | II | ⬜ | 4 | — |
| 63 | IGA-14 | Certificación asistida por IA | II | ⬜ | 4 | #13 |
| 64 | STD-11 | Reporte de cumplimiento autogenerado | VI | ⬜ | 4 | #19 |
| 65 | STD-12 | Marcos EU 2026 (NIS2/DORA/AI Act) fw_17-19 | VI | ⬜ | 4 | — |
| 66 | PLT-08 | SPIFFE/SVID (identidad de workload) | VII | ⬜ | 4 | — |
| 67 | PLT-09 | HA verificada (failover, réplica) | VII | ⬜ | 4 | — |
| 68 | PLT-10 | Runbook operativo | VII | ⬜ | 4 | — |
| 69 | PLT-13 | Observabilidad completa (métricas + tracing) | VII | 🔄 | 4 | — |
| 70 | PLT-15 | Field-level encryption / tokenización | VII | ⬜ | 4 | #54 |
| 71 | PLT-16 | Backup/restore probado | VII | ⬜ | 4 | — |
| 72 | PLT-06b | Defensa en profundidad completa (STRIDE) | VII | 🔄 | 4 | — |
| C1 | CORE-08 / BA18 | Reemplazar los 175 unwrap por Result | Núcleo | 🔄 | Continuo | — |
| C2 | CORE-09 / BA19 | Auditar los 100 allow(dead_code) | Núcleo | 🔄 | Continuo | — |
| C3 | CORE-10 / BA20 | Retirar `idp_external` declarativo (KC eliminado) | Núcleo | 🔄 | Continuo | — |

**Visión completa en una tabla:** **31 ✅ desarrollado + 25 🔄 en proceso + 52 ⬜ por desarrollar
= 108 contratos** de la categoría IAM Enterprise (incluye PLT-17 Gestor de Canales Protegidos y CORE-11 Módulo Criptográfico). Los ✅ (# = ✓) son la base construida
verificada; del #1 en adelante es el orden de desarrollo por fases. Completar #1–#21 (Fases 0-1-2)
lleva la completitud de ~42% a ~65%+; el resto cierra la convergencia (Fase 3) y el ciclo L4 (Fase 4).


---

## 12. Referencias e historial

**Del proyecto:** CARTA RECTORA 0.00 (§4/§8/§10) · A.41 §11 · A.42 · los anexos A.15–A.40 (la
evidencia de código por pilar).
**Normas:** las citadas por contrato (columna «Norma»).

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Mapa completo de la categoría (corrección: el humano observó que 20 contratos no cubren todo lo que los manuales/IAM Enterprise exigen — tenía razón). Derivación sistemática de los 7 pilares × criterios (0.00 §4) + scorecard de brechas (§8) + olas (§10): **107 contratos** con estado de tres valores (✅ desarrollado / 🔄 en proceso / ⬜ por desarrollar) y evidencia de código (A.15–A.42). Scorecard de completitud por pilar y global (~42% ponderado: 32 ✅ / 27 🔄 / 48 ⬜). Pilares menos maduros: PAM ~25% e ITDR ~23%. Incluye capacidades que el código actual ni intenta y que A.41 §11 no listaba: PAM completo (grabación/rotación/aislamiento de sesión), federación entrante (social/LDAP/Kerberos), ITDR continuo (CAE/UEBA/feeds), gobernanza NHI, SCIM bidireccional, SPIFFE, HA. El orden de construcción mapeado a las 3 olas. |
| 1.1.0 | 2026-07-11 | **+CORE-11 Módulo Criptográfico** (Núcleo): centralizar las primitivas de cifrado dispersas (verificado por grep: `ring` en 34 archivos, `ed25519` en 15, `argon2` en 8, `sha2`/`hmac` en 9; no existe `src/crypto/`) tras la **frontera de módulo criptográfico** que exige **NIST FIPS 140-3** — algoritmos aprobados, self-tests (KAT), agilidad PQC en un punto. Nombre normativo («cryptographic module»). ADR-012 · ficha A.42 §10.ter · reforzado 2.01 §13.3. **Hallazgo clave:** el «motor de autenticación unificado» que se pedía **ya existe** — es el `MethodRegistry` + trait `AuthMethod` (2.01 §3.3, patrón **PAM**); no se reinventa, se **completa** a 18 métodos (CORE-12 ⟂, vista agregada del Pilar I AM). Total: **107 → 108 contratos** (~42% estable). |

---

