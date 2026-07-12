# Motor Criptográfico — *cifrar / primitivas*

**Verbo:** cifrar · **Frontera:** `src/crypto/` *(no existe)* · **Estado:** ⬜ CORE-11 · **Rige:** ADR-013 · **Decisión:** ADR-012

---

## 1. Propósito
Frontera **única** de toda operación criptográfica (NIST **FIPS 140-3** «cryptographic module»).
Ningún archivo invoca `ring`/`argon2`/`ed25519`/`hmac` directo: **solicita la operación al motor**,
que la ejecuta con el algoritmo aprobado (catálogo 2.01 §13.1) o la **rechaza** (fail-closed). Es la
capa de abajo que consumen Métodos, Firma, Tokens y Canales.

## 2. El contrato del motor
- **Trait:** `ModuloCriptografico` *(a crear)* — `hash_password`/`verificar_password`/`hmac`/
  `firmar`/`verificar_firma`/`cifrar_aead`/`descifrar_aead`/`derivar_clave`/`aleatorio_seguro`/`autoprueba`.
- **Frontera:** `src/crypto/` — las librerías (`ring`/`argon2`/`ed25519-dalek`) viven **solo** aquí.
- **Algoritmos = enums cerrados** (no strings): uno no aprobado **no compila**.
- **Fail-closed:** algoritmo no aprobado ⇒ `Err`; **self-test (KAT) al arranque** ⇒ si falla, el daemon no arranca.

## 3. Los códigos que se juntan (frontera destino: `src/crypto/` — hoy DISPERSO)
| Primitiva dispersa hoy | Se centraliza como |
|------------------------|--------------------|
| `ring::hmac` (en `totp.rs`, `hotp.rs`…) | `motor.hmac(...)` |
| `argon2` (en `credential.rs`, `password/`…) | `motor.hash_password(...)` |
| `ed25519`/EdDSA (en `jwt_signer.rs`, `push.rs`…) | `motor.firmar(...)` / `motor.verificar_firma(...)` |
| `ring::signature` ECDSA (en `webauthn.rs`, `mtls.rs`) | `motor.verificar_firma(...)` |
| `ring` AEAD (JWE) · `ring::rand` | `motor.cifrar_aead(...)` / `motor.aleatorio_seguro(...)` |

> Conteo verificado (`use X`): `ed25519` en ~22 archivos, `ring` en ~8, `argon2` en ~6. Migración
> **progresiva** (grep decreciente fuera de `src/crypto/`), sin romper.

## 4. Manuales de referencia
- **2.01 §13** Criptografía — los 12 algoritmos del catálogo + §13.3 la frontera (**la madre está aquí**; portada propia por crear).
- **ADR-005** (Argon2id por tier) · **ADR-006** (doble motor de firma).

## 5. Anexos y contratos
- **A.42 §10.ter** — ficha `operar_cripto` (firma del trait + cuerpo + self-tests + fail-closed).
- **ADR-012** — la decisión (frontera FIPS 140-3, agilidad PQC).
- **A.43 CORE-11** — el contrato y su estado (⬜).

## 6. Estado real (verificado en código)
- ✅ Las primitivas clásicas funcionan (Argon2id, HMAC, Ed25519, ECDSA-P256, AES-GCM) — pero **dispersas**.
- ⬜ **No existe `src/crypto/`** — sin frontera, sin self-tests centralizados, sin enums de algoritmo.
- ⬜ PQC (ML-KEM/ML-DSA, FIPS 203/204) no implementado.

## 7. Plan para completarlo
1. Crear `src/crypto/` con el trait `ModuloCriptografico` + los enums de algoritmo aprobados.
2. Implementar `autoprueba()` (KAT al arranque, fail-closed).
3. **Migrar** las primitivas dispersas a la fachada, archivo por archivo (grep decreciente).
4. Dejar preparada la variante PQC (un enum más, no un refactor) — agilidad CNSA 2.0.

*Portada de motor · ADR-013 · 2026-07-12*
