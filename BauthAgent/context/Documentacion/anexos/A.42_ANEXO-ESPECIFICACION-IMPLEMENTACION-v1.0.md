# Anexo A.42 — Especificación de Implementación: las funciones a desarrollar, con parámetros y cuerpo
## Documento de desarrollo: cada función/proceso/módulo pendiente, especificado para implementar sin inventar

**Tipo:** ANEXO — especificación de implementación (contrato de desarrollo por función)
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Respalda a:** A.41 §11 (la base arquitectónica BA1–BA20) · el código `src/domain/andamiaje.rs` (las firmas) · todo el corpus
**Base:** el código existente + las normas que YA definen cada proceso (no se inventa: se especifica lo definido)
**Cómo se usa:** cada ficha da la **firma (parámetros tipados)** + **qué hace cada parámetro** + **el cuerpo paso a paso que la norma exige** + **errores** + **referencia**. El desarrollador (humano o agente) implementa el cuerpo directamente.

---

## 0. Propósito y formato

Este anexo **no diseña nada nuevo**: toma las funciones y procesos que las normas, los manuales y
los anexos **ya definen** y los especifica al nivel de implementación, de modo que su desarrollo
sea directo. Cada ficha tiene esta estructura fija:

```
### [BAn] nombre_de_la_funcion
Norma · Manual · Anexo · Estado
FIRMA:      la signatura exacta (parámetros tipados + retorno)
PARÁMETROS: qué es cada uno y de dónde viene
CUERPO:     el algoritmo paso a paso que la norma exige (numerado)
ERRORES:    qué condiciones producen fallo (fail-closed)
```

El andamiaje en código (`src/domain/andamiaje.rs`) contiene las FIRMAS como traits; **este anexo
contiene el CUERPO** de cada una. Los dos se leen juntos: el `.rs` da el punto de enganche en
Rust, A.42 da los pasos a programar.

---

## 1. BA1 — `verify_assertion` (WebAuthn) — ✅ YA IMPLEMENTADA (referencia de formato)

Sirve de ejemplo de una ficha ya desarrollada (A.41 §2.1):

**FIRMA:** `fn verify_assertion(rp_id: &str, client_data_json: &str, signature_b64: &str, authenticator_data_b64: &str, public_key: &[u8]) -> Result<bool, AuthMethodError>`
**CUERPO (W3C §7.2, implementado):** (1) `clientData.type=="webauthn.get"`; (2) rpIdHash==SHA256(rp_id) + flag UP; (3) verificar firma sobre `authData||SHA256(clientData)` con la clave; retorna el flag UV real. **Estado: ✅ hecho, 372 tests.**

---

## 2. BA2 — `verificar_proof_dpop` — RFC 9449 · 2.03 · A.28 · ❌ POR DESARROLLAR

**FIRMA:**
```rust
fn verificar_proof_dpop(
    proof_jwt: &str,          // el header HTTP "DPoP": un JWT con typ="dpop+jwt"
    access_token: &str,       // el access token que el cliente presenta
    metodo_http: &str,        // el método HTTP de la petición (para el claim htm)
    uri_http: &str,           // la URI del recurso, sin query ni fragment (claim htu)
    jti_store: &JtiStore,     // store anti-replay de identificadores jti ya vistos
    ventana_iat_seg: i64,     // ventana temporal aceptable para iat (ej. 60)
) -> Result<(), DpopError>
```
**PARÁMETROS:** `proof_jwt` viene del header `DPoP` de la request; `access_token` del header
`Authorization: DPoP <token>`; `metodo_http`/`uri_http` del contexto de la request; `jti_store`
es un almacén (Redis/tabla) con TTL = ventana_iat; `ventana_iat_seg` de configuración (no hardcode).

**CUERPO (RFC 9449 §4.3 — pasos obligatorios, verificado 2026-07-11):**
1. Asegurar que hay **un solo** header DPoP y que `proof_jwt` es **un JWT bien formado** (3 partes).
2. Parsear el header JOSE: `typ` DEBE ser `"dpop+jwt"`.
3. `alg` DEBE ser un algoritmo de firma **asimétrico** registrado, **no `none`**, soportado.
4. Extraer la `jwk` del header; **verificar la firma del proof con esa clave pública**.
5. La `jwk` **NO** debe contener clave privada (rechazar si la tiene).
6. Verificar que **todos los claims requeridos** (§4.2) están presentes: `htm`, `htu`, `iat`, `jti`.
7. `htm` == `metodo_http` (comparación exacta).
8. `htu` == `uri_http` **ignorando query y fragment**.
9. `iat` dentro de `±ventana_iat_seg` respecto de ahora (rechazar proofs viejos/futuros).
10. `jti` **no visto antes** en `jti_store` (anti-replay) → si es nuevo, registrarlo con TTL.
11. Calcular `ath = base64url(SHA-256(access_token))` y verificar que **coincide con el claim `ath`** del proof.
12. Si TODO pasa → `Ok(())`. Cualquier fallo → `Err` (fail-closed).

**ERRORES:** `MasDeUnHeader`, `JwtMalformado`, `TypIncorrecto`, `AlgNoAsimetrico`, `FirmaInvalida`,
`JwkConClavePrivada`, `ClaimFaltante`, `HtmNoCoincide`, `HtuNoCoincide`, `IatFueraDeVentana`,
`JtiReplay`, `AthNoCoincide`. **Reutilizar:** `ring` para la firma (como en `jwt_signer.rs`),
`sha2` para el ath (como en webauthn).

---

## 3. BA3 — `evaluate_all` fail-closed — CLAUDE §8 · 1.01 · A.21 · 🔧 A COMPLETAR (1 línea)

**UBICACIÓN:** `src/bitmask/registry.rs`, dentro de `evaluate_all()`, la rama `None =>`.
**CAMBIO:** el default cuando un dominio activo no tiene evaluador debe ser **denegar**, no permitir.
```rust
// ANTES (fail-open, inseguro):
None => DomainResult::permitido(domain),
// DESPUÉS (fail-closed):
None => {
    // Un dominio ACTIVO sin evaluador es un error de arranque, no un permiso.
    tracing::error!(domain, "dominio activo sin evaluador — DENY fail-closed");
    DomainResult::denegado(domain, "evaluador ausente")
}
```
**CUERPO adicional:** añadir test `dominio_activo_sin_evaluador_deniega()`. **ERRORES:** ninguno
nuevo; el efecto es que la evaluación niega en vez de conceder ante configuración inconsistente.

---

## 4. BA4 — `permitir_intento_login` — OWASP ASVS 2.2.1 / NIST 800-63B §5.2.2 · 2.01 · ❌ POR DESARROLLAR

**FIRMA:**
```rust
async fn permitir_intento_login(
    &self,
    username: &str,           // la cuenta objetivo del intento
    client_ip: &str,          // la IP de origen (para límite por IP)
    ahora: DateTime<Utc>,     // el instante del intento (inyectado, testeable)
) -> Result<(), LoginBloqueado>
```
**CUERPO (patrón estándar de brute-force protection):**
1. Consultar `ath_login_attempt` los intentos FALLIDOS de `username` en la ventana reciente (ej. 15 min).
2. Consultar los fallidos de `client_ip` en la misma ventana (defensa contra password-spraying).
3. Si `fallos_cuenta >= umbral_cuenta` (config, ej. 5) → calcular backoff exponencial y devolver
   `Err(LoginBloqueado { hasta })`.
4. Si `fallos_ip >= umbral_ip` (config, ej. 20) → `Err` con bloqueo de IP.
5. Si por debajo de umbrales → `Ok(())` (puede intentar).
6. (El registro del resultado del intento — éxito/fallo — lo hace el flujo de login tras la
   verificación de contraseña, insertando en `ath_login_attempt`.)

**PARÁMETROS de config (no hardcode):** `umbral_cuenta`, `umbral_ip`, `ventana_min`, `backoff_base`.
**ERRORES:** `LoginBloqueado { hasta: DateTime }`. **Nota:** NIST 800-63B exige rate-limiting, no
rotación de contraseña — este es el control que falta para el login (que ya verifica bien, A.41 §3).

---

## 5. BA6 — `verificar_proofing` (IAL) — NIST SP 800-63A · A.09 · ❌ POR DESARROLLAR

**FIRMA:**
```rust
async fn verificar_proofing(
    &self,
    evidencias: &[Evidencia], // documentos/pruebas aportados (tipo + datos)
    objetivo: NivelIal,       // IAL1 | IAL2 | IAL3 que se busca alcanzar
    ctx_id: &str,             // contexto para la auditoría del proofing
) -> Result<ResultadoProofing, ProofingError>
// Evidencia { tipo: FAIR|STRONG|SUPERIOR, clase: documento|biometrico|... , datos }
// ResultadoProofing { ial_logrado: NivelIal, evidencias_validadas, proofed_at, reproofing_due }
```
**CUERPO (NIST SP 800-63A, por nivel):**
1. **IAL1:** sin evidencia — sólo cuenta auto-declarada. Retornar `ial_logrado=Ial1`.
2. **IAL2:** exige **1 evidencia FAIR + 1 STRONG, o 1 SUPERIOR**, más los atributos núcleo con al
   menos un identificador gubernamental. Validar cada evidencia (documento vs registro de
   autoridad; biometría con liveness ISO 30107-3 si aplica). Si cumple → `Ial2`.
3. **IAL3:** exige verificación presencial o supervisada equivalente + evidencia SUPERIOR.
4. En todos: emitir `aud_event(IDENTITY_PROOFED, iso_control=["IA-12"])` con las fuentes de
   evidencia y el resultado (log inalterable — la industria lo exige, A.09 §4.bis).
5. Persistir en la sección `identity_proofing` del UserTemplate (requiere BA7 idn_atributo o
   columna dedicada): `{ial_logrado, tipo, evidencias, proofed_at, proofed_by, reproofing_due}`.
6. Si la evidencia no alcanza el `objetivo` → `Err(EvidenciaInsuficiente { falta })`.

**ERRORES:** `EvidenciaInsuficiente`, `DocumentoNoVerificable`, `LivenessFallido`, `AtributoNucleoFaltante`.

---

## 6. BA7 — migración `idn_atributo` — SCIM RFC 7643 / ISO 24760-1 · 1.07 · A.31 · ❌ POR DESARROLLAR

**No es una función: es una migración DDL.** ESTRUCTURA requerida (los campos que la norma exige):
```sql
CREATE TABLE bauth.idn_tipo_atributo (         -- catálogo de tipos (email, phone, address...)
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    codigo text NOT NULL UNIQUE,                -- 'email', 'phone', 'ci'...
    nombre_es text NOT NULL,
    cardinalidad text NOT NULL,                 -- '1:1' | '1:N' (SCIM multivaluado)
    clasificacion text NOT NULL,               -- PUBLIC|INTERNAL|CONFIDENTIAL|RESTRICTED (ISO A.5.12)
    enmascaramiento text,                       -- política de máscara (ej. 'lastFourVisible')
    verificable boolean NOT NULL DEFAULT false, -- si admite estado verified (ISO 24760: claimed vs verified)
    norma_ref text NOT NULL                     -- SCIM/OIDC de origen
);
CREATE TABLE bauth.idn_atributo (              -- los valores 1:N por sujeto
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    sujeto_id uuid NOT NULL,                    -- FK al usuario (idn_user_template)
    tipo_id uuid NOT NULL REFERENCES bauth.idn_tipo_atributo(id),
    valor text NOT NULL,                        -- el dato (cifrado si la clasificación lo exige)
    es_primario boolean NOT NULL DEFAULT false,
    verificado boolean NOT NULL DEFAULT false,  -- estado de verificación (ISO 24760-1 §6)
    verificado_at timestamptz,
    ctx_id text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
    -- + UNIQUE (sujeto_id, tipo_id, valor); + índice por sujeto
);
```
**Luego (proceso BA7b):** migrar los campos 1:N del JSONB del UserTemplate (emails/phones/
addresses — A.02 §B2) a estas tablas, siguiendo la regla de 1.08 §3.

---

## 7. BA8 — `firmar_adsib` (motor externo legal) — Ley 164 / ADSIB / eIDAS · 2.04 · A.08 · ❌ POR DESARROLLAR

**FIRMA:**
```rust
async fn firmar_adsib(
    &self,
    doc_hash: &[u8],          // SHA-256 del documento a firmar (nunca el documento crudo)
    cert_serial: &str,        // serial del certificado ADSIB del firmante (persona)
    formato: FormatoAdes,     // XAdES (factura SIN) | PAdES (PDF) | CAdES
) -> Result<FirmaLegal, FirmaError>
// FirmaLegal { firma_b64, algoritmo: "RSA-SHA256", cert_cadena, sello_tiempo, formato }
```
**CUERPO (Ley 164 Art. 78 + perfiles ETSI EN 319):**
1. Recuperar el certificado ADSIB del firmante por `cert_serial` (de la bóveda/almacén de certs).
2. Verificar que el certificado está **vigente** y **no revocado** (consultar CRL/OCSP de ADSIB).
3. Firmar `doc_hash` con **RSA-SHA256** usando la clave asociada al certificado.
4. Construir el contenedor **AdES** según `formato` (XAdES para XML de factura SIN, PAdES para PDF).
5. Añadir **sello de tiempo** confiable (perfil -T de ETSI) para validez a largo plazo.
6. Registrar `aud_event(FIRMA_LEGAL_EMITIDA)` con serial, formato, hash — evidencia (AU-3).
7. Retornar `FirmaLegal`. **ERRORES:** `CertNoVigente`, `CertRevocado`, `ClaveNoDisponible`,
   `FormatoNoSoportado`. **Distinto del motor interno Ed25519** (que ya existe, A.08 §2): este da
   validez jurídica oponible a terceros.

---

## 8. BA11 — `emitir_evento_auditoria` — NIST AU-3/AU-12 / ISO A.8.15 · 5.01 · A.27 · ❌ POR DESARROLLAR

**FIRMA:**
```rust
async fn emitir_evento_auditoria(
    &self,
    tipo_evento: TipoEvento,  // uno de los 30 tipos de aud_event (ENUM)
    iso_control: &[&str],     // los controles ISO/NIST que este evento satisface (en origen)
    sujeto: &str,             // identidad que ejecutó la acción (AU-3)
    recurso: &str,            // identidad del recurso afectado (AU-3)
    resultado: Resultado,     // Permitido | Denegado | Error
    ctx_id: &str,             // contexto SBOS-049
    detalle_json: &str,       // payload con la información para reconstruir qué ocurrió
) -> Result<Uuid, AuditError>  // retorna el id del evento emitido
```
**CUERPO (NIST AU-3 contenido + ISO A.8.15):**
1. Construir la fila `aud_event` con TODOS los campos AU-3: tipo, timestamp con precisión de
   microsegundos, `sujeto`, `recurso`, `resultado`, `ctx_id`, `traceparent`, `iso_control[]`, detalle.
2. Determinar `severity` (INFO/WARNING/CRITICAL) según el tipo y el resultado.
3. `INSERT` en `aud_event` — el trigger WORM (`fn_worm_hash_chain`, BA12) sella `entry_hash`.
4. Si `severity >= WARNING` → reenviar a **SIEM (Wazuh)** por syslog (`audit/siem.rs`).
5. Si `severity >= CRITICAL` → además notificar (bNotify) según `notification_channels` del tenant.
6. Retornar el `id`. **ERRORES:** `BdError` (fail-closed: si la auditoría no se puede escribir, la
   operación auditada debe abortar — un sistema sin registro no procede). **UBICACIÓN:** módulo
   nuevo `src/audit/audit_event.rs` (hoy `src/audit/` es solo mod.rs).

---

## 9. BA13 — motores IGA — NIST AC-2(j) / ISO A.5.18 · 7.01 · A.30 · 🔧 A COMPLETAR

**FIRMA (campaña de certificación):**
```rust
async fn correr_campana_certificacion(
    &self,
    alcance: AlcanceCampana,  // qué revisar: por tenant | por rol | por tier
    ahora: DateTime<Utc>,
) -> Result<ResumenCampana, IgaError>
// ResumenCampana { revisiones_creadas, revisores_notificados }
```
**CUERPO:**
1. Seleccionar las asignaciones de acceso dentro de `alcance` que deben certificarse (por
   frecuencia del rol — A.01 §B13).
2. Para cada una, crear una fila en `aud_review` (pendiente) con su revisor (el `role_owner`/manager).
3. Notificar a cada revisor su lote con SLA (por bNotify).
4. Al vencer el SLA sin respuesta → aplicar la política (auto-revocar / escalar — A.10 §5).
5. Retornar el resumen. **ERRORES:** `AlcanceVacio`, `BdError`.

**FIRMA (barrido de huérfanas):** `async fn barrer_huerfanas(&self, ahora) -> Result<u32, IgaError>`
**CUERPO:** detectar cuentas sin dueño/uso (last_login antiguo, sin manager) → registrar en
`aud_ghost_account` → suspender según política. Retorna cuántas encontró.

---

## 10. BA17 — RLS multi-tenant — NIST AC-4/SC-4 · 1.12 · A.22 · ❌ POR DESARROLLAR

**No es función: es DDL por cada tabla tenant-scoped.** PATRÓN a aplicar (repetir por tabla):
```sql
ALTER TABLE bauth.<tabla> ENABLE ROW LEVEL SECURITY;
CREATE POLICY <tabla>_aislamiento ON bauth.<tabla>
    USING (tenant_id = current_setting('app.current_tenant', true)::uuid);
```
**PROCESO de soporte en código:** tras autenticar, el pool debe fijar `SET app.current_tenant =
'<uuid>'` en la sesión de BD. El `WHERE tenant_id` del código se mantiene (rendimiento); la RLS es
la segunda capa (seguridad). **Tablas objetivo:** todas las que llevan `tenant_id` (29 archivos las
tocan — A.22).

---

## 10.bis PLT-17 — `solicitar_canal` (Gestor de Canales Protegidos) — NIST 800-63B / RFC 8705 · 2.12 · ⬜ POR DESARROLLAR

**Módulo nuevo:** `src/transport/`. **El principio:** ningún módulo abre conexiones; **solicita
un canal al gestor**, que lo establece protegido o lo niega (fail-closed). **Además el gestor
NORMALIZA** (2.12 §4.bis): ENTRANTE demodula todo protocolo (HTTP/REST/gRPC/webhook) → canon
interno (JSON-RPC/socket) → **canonicaliza y sanitiza** (CWE-180: canonicalizar antes de validar)
→ entrega al núcleo; SALIENTE modula el canon interno al protocolo del destino. Firma complementaria:
```rust
// ENTRANTE: normaliza cualquier protocolo al canon interno, sanitizado.
fn demodular_a_canon(&self, protocolo: Protocolo, crudo: &[u8]) -> Result<MensajeRpc, CanalError>;
//   1. terminar TLS/mTLS · 2. decodificar UNA vez (CWE-174) a JSON-RPC · 3. canonicalizar ·
//   4. sanitizar sobre la forma canónica (domain/validate.rs) · fallo → Err (fail-closed).
// SALIENTE: modula el canon interno al protocolo que el destino exige.
fn modular_desde_canon(&self, canal_id: &str, msg: &MensajeRpc) -> Result<Vec<u8>, CanalError>;
```
El núcleo (BitMask, dominios, handlers) es **agnóstico de transporte** — solo recibe/emite `MensajeRpc`.

**FIRMA:**
```rust
async fn solicitar_canal(
    &self,
    canal_id: &str,           // clave del catálogo: 'hibp' | 'bnotify_caep' | 'vault_pki'...
    ctx_id: &str,             // contexto SBOS-049 que viaja en el canal
) -> Result<CanalProtegido, CanalError>
// CanalProtegido: envoltura que expone enviar/recibir sobre el canal YA cifrado y verificado.
// El catálogo (config, no hardcode) define por canal_id: dirección, protocolo, política.
```
**PARÁMETROS:** `canal_id` debe existir en el catálogo declarativo (lista blanca — SBOS-050);
`ctx_id` se propaga como baggage (W3C Trace Context) para trazabilidad.

**CUERPO (deriva de NIST 800-63B «authenticated protected channel» + RFC 8446/8705):**
1. Buscar `canal_id` en el catálogo. Si no existe → `Err(CanalNoAutorizado)` (fail-closed: solo canales declarados).
2. Leer su política: cifrado, autenticacion_par (`server_only`|`mutual`), red, resiliencia.
3. Establecer TLS 1.3 (RFC 8446) con suites **FIPS 140-3** aprobadas; **rechazar** si el par ofrece < TLS 1.2 o suite no aprobada.
4. **Verificar el certificado del servidor**: cadena (RFC 5280) + validez + revocación (CRL/OCSP). Fallo → `Err(CertNoVerificable)`.
5. Si `autenticacion_par == mutual` (verifier↔CSP, bóveda, cliente confidencial): presentar el **certificado de cliente** (mTLS, RFC 8705) desde la bóveda; sin él → `Err(MtlsRequerido)`.
6. Aplicar la política de red del canal (CIDR/rate-limit — D7, 1.01) antes de completar.
7. Emitir `aud_event(CANAL_ABIERTO, iso_control=["SC-8","SC-13"])` con canal_id, par, cifrado, ctx_id.
8. Retornar `CanalProtegido` (con timeouts/reintentos/circuit-breaker de la política aplicados).
9. Al cerrar o fallar: `aud_event(CANAL_CERRADO | CANAL_FALLO)`.

**Jerarquía de protocolos (2.12 §5.bis) — el catálogo la codifica por canal:** 1 Unix socket
(preferido) · 2 gRPC sobre socket · 3 HTTP saliente mínimo (solo HIBP) · 4 REST excepcional (solo
frontera externa: OIDC/OAuth endpoints, webhooks, SCIM 2.0). Todo canal HTTP/REST expuesto lleva
en su política `via_gateway = true` (pasa por Kong=PEP) y el control más estricto (OWASP API Top
10) — el gestor lo rechaza si no cumple. HTTP nunca directo del daemon a la red.

**ERRORES (todos fail-closed — jamás degradar a claro):** `CanalNoAutorizado`, `CifradoNoAprobado`,
`CertNoVerificable`, `MtlsRequerido`, `RedBloqueada`, `HttpDirectoProhibido` (HTTP expuesto sin gateway), `Timeout`. **Reutiliza:** `rustls`/`ring`
(cifrado, ya en el stack), la bóveda PKI (A.08) para el cert de cliente, `aud_event` (A.27) para
la auditoría de canal. **Migración:** los 20+ clientes actuales (reqwest/tonic dispersos) pasan a
llamar `solicitar_canal` — progresivo, canal por canal, sin romper (ADR-011).

## 10.ter CORE-11 — `operar_cripto` (Módulo Criptográfico) — NIST FIPS 140-3 · 2.01 §13 · ADR-012 · ⬜ POR DESARROLLAR

**Módulo nuevo:** `src/crypto/`. **El principio (FIPS 140-3 «cryptographic module boundary»):**
ningún archivo invoca `ring`/`argon2`/`ed25519`/`hmac` directo; **solicita la operación al Módulo
Criptográfico**, que la ejecuta con el algoritmo **aprobado** del catálogo (2.01 §13.1) y sus
parámetros por tier, o la **rechaza** (fail-closed — jamás *fallback* a algo débil). Es al cifrado
lo que el Gestor de Canales (§10.bis) es al transporte. **No es el motor de métodos** — ese ya
existe (`MethodRegistry`, patrón PAM, 2.01 §3.3); este módulo es la capa de **abajo** que esos
métodos consumen.

**FRONTERA (la fachada única — trait, no una función suelta):**
```rust
/// Frontera del módulo criptográfico (FIPS 140-3). Toda primitiva pasa por aquí.
pub trait ModuloCriptografico: Send + Sync {
    // Hashing de contraseñas (Argon2id, parámetros por tier — ADR-005)
    fn hash_password(&self, tier: Tier, secreto: &[u8]) -> Result<HashPhc, CriptoError>;
    fn verificar_password(&self, phc: &str, secreto: &[u8]) -> Result<bool, CriptoError>;
    // MAC / OTP (HMAC-SHA1/256/512 — TOTP/HOTP)
    fn hmac(&self, alg: AlgHmac, clave: &[u8], datos: &[u8]) -> Result<Vec<u8>, CriptoError>;
    // Firma / verificación (Ed25519, ES256/384 — aprobados FIPS 186-5)
    fn firmar(&self, alg: AlgFirma, clave_id: &ClaveId, datos: &[u8]) -> Result<Vec<u8>, CriptoError>;
    fn verificar_firma(&self, alg: AlgFirma, pubkey: &[u8], datos: &[u8], firma: &[u8]) -> Result<bool, CriptoError>;
    // Cifrado autenticado (AES-256-GCM — FIPS 197) · KDF (HKDF-SHA256 — SP 800-56C)
    fn cifrar_aead(&self, clave: &[u8], plano: &[u8], aad: &[u8]) -> Result<Sobre, CriptoError>;
    fn descifrar_aead(&self, clave: &[u8], sobre: &Sobre, aad: &[u8]) -> Result<Vec<u8>, CriptoError>;
    fn derivar_clave(&self, ikm: &[u8], info: &[u8], bytes: usize) -> Result<Vec<u8>, CriptoError>;
    // Aleatoriedad segura (ring::rand::SecureRandom — única fuente)
    fn aleatorio_seguro(&self, bytes: usize) -> Result<Vec<u8>, CriptoError>;
    // Autoprueba obligatoria FIPS 140-3 (KAT) — se corre al arranque
    fn autoprueba(&self) -> Result<(), CriptoError>;
}
```
**PARÁMETROS:** los algoritmos son **enums cerrados** (`AlgFirma`, `AlgHmac`, `Tier`) — no strings:
solo los 12 aprobados del catálogo (2.01 §13.1) son representables; un algoritmo no aprobado **no
compila**, no falla en runtime. `ClaveId` referencia la clave en la bóveda (ADR-006), nunca el
material en claro.

**CUERPO (deriva de FIPS 140-3 §self-tests + §approved security functions):**
1. **Al arranque del daemon**, `autoprueba()` corre los KAT (Known Answer Tests) de cada algoritmo:
   si uno falla → el daemon **no arranca** (fail-closed — FIPS 140-3 exige self-test antes de operar).
2. Cada operación valida su entrada (longitud de clave, nonce único en AEAD) y selecciona la
   implementación aprobada (`ring`/`argon2` bajo la frontera) — nunca expone la librería al llamador.
3. Los parámetros por tier (Argon2id: memoria/iteraciones/paralelismo — ADR-005) viven **aquí**,
   centralizados, no repetidos por archivo.
4. `firmar` **no recibe el material de la clave**: recibe `ClaveId` y la resuelve contra la bóveda
   (ADR-006 — la clave privada nunca sale de Vault/frontera).
5. Emitir `aud_event` en operaciones sensibles de clave (firma legal, rotación) — trazabilidad (A.27).
6. Transición **PQC**: agregar ML-KEM/ML-DSA (FIPS 203/204) es **una** variante de enum aquí, no un
   refactor de 34 archivos — agilidad criptográfica (CNSA 2.0, deadline 2030).

**ERRORES (todos fail-closed — jamás degradar):** `AlgoritmoNoAprobado`, `ClaveInvalida`,
`NonceReutilizado` (AEAD), `AutopruebaFallida` (aborta arranque), `ClaveNoEncontrada` (bóveda),
`LongitudInvalida`. **Reutiliza:** `ring`/`argon2`/`ed25519-dalek` (ya en el stack — pasan a vivir
**solo** bajo `src/crypto/`), la bóveda PKI (A.08) para claves privadas, `aud_event` (A.27).
**Migración:** los **34+** puntos que hoy invocan cripto directa pasan a llamar la fachada —
progresivo, archivo por archivo, con evidencia (grep de `use ring`/`use argon2` decreciente fuera
de `src/crypto/`), sin romper (igual que ADR-011/ADR-012).

## 11. Resumen — el orden de desarrollo (con las fichas listas)

| Orden | Ficha | Tipo | Esfuerzo |
|:---:|---|---|---|
| 1 | BA3 (§3) | 1 línea + test | Mínimo |
| 2 | BA12 (aplicar bauth_44 WORM) | operación VPS | Bajo (desbloquea BA11 y motor 1.13) |
| 3 | BA2 DPoP (§2) | función cripto | Medio (12 pasos, `ring`+`sha2` ya están) |
| 4 | BA4 rate-limit (§4) | función + config | Medio |
| 5 | BA11 emisor auditoría (§8) | módulo nuevo | Medio-alto |
| 6 | BA7 idn_atributo (§6) | migración DDL | Bajo |
| 7 | BA6 IAL (§5) | función + persistencia | Alto |
| 8 | BA17 RLS (§10) | DDL por tabla | Bajo-medio |
| 9 | BA13 IGA (§9) | 2 motores | Alto |
| 10 | BA8 ADSIB (§7) | motor externo | Alto |
| ⟂ | **CORE-11 Módulo Criptográfico (§10.ter)** | **frontera + refactor progresivo** | **transversal** (habilita firma coherente en BA2/BA8/métodos; migración por grep) |
| ⟂ | **PLT-17 Gestor de Canales (§10.bis)** | frontera + refactor progresivo | transversal (habilita BA8, mTLS, red D7) |

Las demás (BA5, BA9, BA10, BA14, BA15, BA16, BA18-20) están en A.41 §11 con su firma; sus fichas
detalladas se añaden a este anexo conforme entren en desarrollo.

---

## 12. Referencias

**Del código:** `src/bitmask/registry.rs` (BA3) · `src/audit/` (BA11) · `src/domain/andamiaje.rs` (firmas) · `Cargo.toml` (ring/sha2 reutilizables).
**Normas (base del cuerpo de cada ficha):** [RFC 9449 §4.3 DPoP](https://datatracker.ietf.org/doc/html/rfc9449) (verificado: los 12 pasos) · [W3C WebAuthn §7.2](https://www.w3.org/TR/webauthn-3/) · [NIST SP 800-63A IAL](https://pages.nist.gov/800-63-4/sp800-63a/) · [NIST AU-3](https://csf.tools/reference/nist-sp-800-53/r5/au/au-3/) · [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/) · [SCIM RFC 7643](https://datatracker.ietf.org/doc/html/rfc7643) · [PostgreSQL RLS](https://www.postgresql.org/docs/current/ddl-rowsecurity.html) · Ley 164 / ETSI EN 319.

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Especificación de implementación (corrección del rumbo: el humano pidió los procesos/funciones YA DEFINIDOS por las normas, con su listado de parámetros y la explicación del cuerpo — no un andamiaje de traits, que fue interpretación previa). Fichas listas para desarrollar: BA1 (WebAuthn, ejemplo hecho), BA2 (DPoP — los 12 pasos de RFC 9449 §4.3 verificados), BA3 (pipeline fail-closed, el cambio exacto), BA4 (rate-limit login), BA6 (IAL 800-63A por nivel), BA7 (DDL idn_atributo con los campos SCIM/ISO), BA8 (firma ADSIB, pasos Ley 164/ETSI), BA11 (emisor auditoría, contenido AU-3), BA13 (motores IGA), BA17 (RLS patrón por tabla). Cada ficha: firma con parámetros explicados + cuerpo paso a paso de la norma + errores fail-closed. El orden de desarrollo con esfuerzo estimado. |
