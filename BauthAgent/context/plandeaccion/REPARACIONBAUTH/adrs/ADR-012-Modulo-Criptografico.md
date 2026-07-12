# ADR-012 — Centralización de la Criptografía en un Módulo Criptográfico único

**Estado:** Aceptado · **Fecha:** 2026-07-11 · **Autor:** bauth-developer
**Relacionado:** ADR-005 (Argon2id) · ADR-006 (Doble motor de firma) · ADR-011 (Gestor de Canales — la cripto de transporte) · ADR-009 (BitMask Dual)
**Contrato:** CORE-11 (A.43) · **Manual:** 2.01 §13 (Criptografía)

---

## Contexto

Las **primitivas criptográficas** de bAuth están **dispersas** (verificado por grep, 2026-07-11):
`ring` invocado en **34 archivos**, `ed25519`/EdDSA en **15**, `argon2` en **8**, `sha2`/`hmac` en
**9**. **No existe `src/crypto/`** — cada método de autenticación, cada handler y cada firmante
invoca la librería de cifrado directamente (`totp.rs` usa `ring::hmac` en su propio cuerpo;
`credential.rs` invoca `argon2` directo; `webauthn.rs` invoca `ring::signature` directo).

**NIST FIPS 140-3** («Security Requirements for Cryptographic Modules») define el concepto de
**cryptographic module** con una **frontera** definida (*cryptographic boundary*): las operaciones
criptográficas ocurren **dentro** de un módulo con interfaces declaradas, algoritmos aprobados,
*self-tests* (KAT) al arranque, y gestión de parámetros de seguridad sensibles (claves). Con las
primitivas dispersas en 34+ archivos es **imposible garantizar de forma auditable** que toda la
criptografía usa algoritmos aprobados con la misma parametrización — un solo archivo que elija un
algoritmo débil o parámetros erróneos es un incumplimiento silencioso e inauditable.

Es **el mismo problema del transporte** que resolvió ADR-011 (Gestor de Canales), aplicado a las
primitivas de cifrado en vez de a los canales de red.

> **No confundir con el motor de autenticación:** el «motor unificado de métodos» que orquesta los
> autenticadores **ya existe** — es el `MethodRegistry` + trait `AuthMethod` (2.01 §3.2-3.3), el
> patrón **PAM (Pluggable Authentication Module)**. Este ADR **no** lo reinventa: gobierna la capa
> de **abajo** — las primitivas de cifrado que esos métodos consumen. El motor de métodos se
> **completa** (9→18 métodos, CORE-12); la criptografía se **centraliza** (CORE-11, este ADR).

## Decisión

**Centralizar TODA operación criptográfica en un subsistema único: el Módulo Criptográfico
(`src/crypto/`).** Ningún método, handler ni firmante invoca `ring`/`argon2`/`ed25519`/`hmac`
directamente: **solicita la operación al Módulo Criptográfico** (`hash_password`, `verificar_hmac`,
`firmar`, `verificar_firma`, `cifrar_aead`, `derivar_clave`, `aleatorio_seguro`), que la ejecuta
con el algoritmo aprobado y los parámetros del catálogo (2.01 §13.1) o la **rechaza** (fail-closed:
algoritmo no aprobado → error, nunca *fallback* silencioso a algo débil).

El nombre deriva del término normativo (FIPS 140-3 «cryptographic module»), no de criterio de diseño.

## Alternativas consideradas

| Alternativa | Rechazo |
|-------------|---------|
| **Seguir disperso** (cada archivo su cripto) | Incumple FIPS 140-3 de forma inverificable; un archivo con algoritmo/parámetros erróneos rompe la garantía sin que nadie lo detecte. |
| **HSM / módulo FIPS certificado externo** | bAuth es soberano y systemd; la clave interna es Ed25519 vía Vault (ADR-006). Se adopta la **frontera lógica** FIPS 140-3 (interfaces, algoritmos aprobados, self-tests) sin depender de hardware certificado externo. Vault sigue siendo el custodio de la clave privada. |
| **Confiar en que `ring` ya es una frontera** | `ring` es una librería, no una frontera de política: no impone *qué* algoritmo se elige ni *con qué* parámetros por tier — eso hoy lo decide cada archivo. La frontera es de **política**, no solo de implementación. |

## Consecuencias

**Positivas:**
- La «cryptographic module boundary» (FIPS 140-3) se vuelve **verificable en un punto** — un solo
  módulo declara los algoritmos aprobados (los 12 del catálogo 2.01 §13.1) y su parametrización.
- *Self-tests* (KAT) al arranque en un solo lugar — hoy imposible con la cripto dispersa.
- Transición **PQC** (FIPS 203/204/205, deadline CNSA 2.0 2030) se hace en **un** módulo, no en 34
  archivos: agilidad criptográfica real.
- Los 18 métodos del `MethodRegistry` (CORE-12) consumen la misma cripto aprobada — coherencia AAL.
- Parámetros por tier (Argon2id, ADR-005) centralizados, no repetidos por archivo.

**Negativas / costes:**
- Refactor: los 34+ puntos que hoy invocan cripto directa migran a solicitar la operación al módulo
  (progresivo, sin romper — igual que ADR-011).
- Un punto único es también crítico — debe ser robusto, fail-closed y con *self-tests*.

**Riesgos mitigados:**
- Migración progresiva: el módulo coexiste con las invocaciones actuales; se migra archivo por
  archivo con evidencia (grep decreciente).
- Soberanía preservada: es un plano interno del daemon (frontera lógica), no un HSM externo.

## Referencias
- NIST FIPS 140-3 (Security Requirements for Cryptographic Modules) · FIPS 197 (AES) · FIPS 180-4
  (SHA-2) · FIPS 202 (SHA-3) · FIPS 186-5 (ECDSA/EdDSA) · FIPS 203/204/205 (PQC) · NIST SP 800-63B
  Rev.4 (autenticadores y criptografía aprobada) · NIST SP 800-56C (HKDF)
- Patrón **PAM (Pluggable Authentication Module)** — motor de métodos (ya existe, 2.01 §3)
- Manual 2.01 §13 (Criptografía) · A.42 §10.ter (ficha `operar_cripto`) · A.43 §CORE-11 · ADR-005
  (Argon2id) · ADR-006 (firma dual) · ADR-011 (Gestor de Canales — cripto de transporte)

*ADR-012 · bAuth Identity Core v3.0 · 2026-07-11*
