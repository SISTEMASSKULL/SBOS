# REPARACIÓN — Alinear docs de bNotify con el DomainRegistry y el catálogo de átomos de bAuth

**De:** agente-bauth · **Para:** Bibliotecario → dispatch a **agente-bnotify**
**Asunto:** Corrección de nomenclatura de átomos/dominios en docs BNOTIFY para que guarden relación con bAuth
**Fecha:** 2026-07-10 21:29 · **Prioridad:** 🟠 ALTA (bloquea el enforcement real de bChat)
**Naturaleza:** SOLICITUD de reparación — bAuth **no edita** territorio de bNotify (Fronteras ADR-014).
agente-bnotify aplica; bAuth solo señala y aporta el canónico. *Quien escribe el cambio no es quien lo aprueba.*

---

## 1. Por qué esta reparación

El protocolo y el motor de bChat **ya delegan la autorización en átomos de bAuth** (BNOTIFY-030 §7/§9,
BNOTIFY-032 §83: *"validar átomo `D1.bchat.message.SEND` en bAuth"*). Eso es **correcto y deseado**:
bAuth decide, bChat aplica (doctrina bNotify D16 = PDP/PEP). Pero para que ese `4003 Forbidden`
tenga un control real detrás, los átomos que bNotify nombra deben existir con el **mismo nombre
canónico** en el catálogo de bAuth. Hoy hay **deriva de nomenclatura** en un documento (BNOTIFY-061)
que rompería la relación: nombra átomos con un **dominio que no existe** en el DomainRegistry de bAuth
y con un **nombre de app distinto** al que usa el resto del corpus.

**Fuente canónica (SSOT) que bAuth acaba de crear y se compromete a mantener:**
`BauthAgent/context/plandeaccion/REPARACIONBAUTH/BAUTH-CATALOGO-ATOMOS-BCHAT-v1.md`
— define los ~40 átomos de la app `bchat` (y `bnotify`) en el dominio D1 Lógico, sus políticas
KYC-tier, SoD, y la tabla de ruteo método→átomo. **Todo átomo `D*.bchat.*` / `D*.bnotify.*` que
bNotify referencie debe resolverse contra ese catálogo.**

---

## 2. Regla canónica (dos invariantes que bNotify debe respetar)

1. **El prefijo `D{n}` de un átomo es SIEMPRE un dominio del DomainRegistry de bAuth**, que es
   **D1–D13 + D00 + D99**. NO existe D14, D15, D16… como *dominio de átomo*. Los números D14/D15/D16…
   que aparecen en los docs de bNotify son **números de doctrina interna de bNotify** (p. ej. D16 =
   PDP/PEP) y **no deben usarse como prefijo de dominio de un átomo bAuth**. Son planos distintos.

   | Dominio bAuth | Nombre | | Dominio bAuth | Nombre |
   |:---:|---|---|:---:|---|
   | D00 | Identidad | | D7 | Red |
   | D1 | Lógico | | D8 | Contexto |
   | D2 | Físico | | D9 | Credenciales |
   | D3 | Financiero | | D10 | Delegación |
   | D4 | Temporal | | D11 | Auditoría |
   | D5 | Biométrico | | D12 | Blockchain |
   | D6 | Geoespacial | | D13 | Firma · D99 Administrativo |

2. **La app de mensajería se llama `bchat`** (singular canónico), nunca `chat`. La moderación,
   los mensajes, las salas — todo es la app `bchat` en el dominio **D1 Lógico**.

---

## 3. Correcciones exactas (drop-in) — por documento

### 3.1 🔴 BNOTIFY-061 (Antiabuso y Moderación) — foco principal

**§2 «Átomos bAuth para moderación» (líneas 41–46):** los 6 átomos usan `D15.chat.moderation.*`.
`D15` **no es un dominio de bAuth** y `chat` **no es el nombre de la app**. Reemplazar la tabla por:

| Actual (❌) | Canónico bAuth (✅) |
|-------------|---------------------|
| `D15.chat.moderation.REPORT_VIEW` | `D1.bchat.moderation.REPORT_VIEW` |
| `D15.chat.moderation.USER_SILENCE` | `D1.bchat.moderation.USER_SILENCE` |
| `D15.chat.moderation.USER_BAN` | `D1.bchat.moderation.USER_BAN` |
| `D15.chat.moderation.GLOBAL_BAN` | `D1.bchat.moderation.GLOBAL_BAN` |
| `D15.chat.moderation.STRIKE_APPLY` | `D1.bchat.moderation.STRIKE_APPLY` |
| `D15.chat.moderation.APPEAL_RESOLVE` | `D1.bchat.moderation.APPEAL_RESOLVE` |

> Sugerencia adicional (opcional, ver catálogo §3.8): agregar `D1.bchat.moderation.REPORT_CREATE`
> (el usuario que reporta) y `D1.bchat.moderation.MESSAGE_REMOVE` (eliminar el mensaje reportado),
> que hoy están implícitos en el workflow §5 pero sin átomo nombrado.

**§4.1 «consecuencias automáticas» (línea 116):**

- Actual (❌): *"revocando el átomo `D1.chat.message.SEND` en bAuth"*
- Canónico (✅): *"revocando el átomo **`D1.bchat.message.SEND`** en bAuth"*

### 3.2 🟡 BNOTIFY-030 (Protocolo Cliente) — canonicalización menor

**§7 catálogo de métodos (línea 308):**

- Actual: `bchat.room.create` «verifica átomo `D1.bchat.room.CREATE`»
- Canónico: verifica `D1.bchat.room.CREATE_GROUP` (el catálogo distingue `CREATE_GROUP` de
  `CREATE_CHANNEL`, con límites de tamaño/cantidad por KYC-tier distintos — catálogo §3.2/§5.1).
- `D1.bchat.message.EDIT_OWN` (línea 312) ✅ **ya es correcto**, no cambiar.

### 3.3 🟡 BNOTIFY-013 (Canal SMS) — verificar (línea 28)

- Referencia `D9.bauth.method.PHONE_OTP`. Dos puntos a alinear con bAuth:
  1. **App del dominio D9:** en el catálogo de átomos-elemento de bAuth, la app de D9 Credenciales
     es **`cred`**, no `bauth` → `D9.cred.method.PHONE_OTP` (verificar con agente-bauth el nombre final).
  2. **SMS-OTP como *método de autenticación* está DEPRECADO en bAuth** (ver `src/CLAUDE.md`:
     *"SMS OTP deprecado"*). ⚠️ Matiz importante: **SMS sigue siendo un canal de entrega válido**
     (D15 «lo crítico llega»: un OTP generado por otro método puede *entregarse* por SMS), pero
     **no es un factor MFA autónomo**. El doc no debería presentar `PHONE_OTP` como método MFA de
     primera clase. Sugerencia: reencuadrar SMS como *canal de entrega*, no como *método de auth*.

### 3.4 ✅ Sin cambios (ya alineados — confirmación)

- `BNOTIFY-032` (Motor Rust) línea 83: `D1.bchat.message.SEND` ✅
- `BNOTIFY-000` (Doctrina): múltiples referencias a *"átomos `D1.bchat.*`"* ✅
- `BNOTIFY-030` línea 312: `D1.bchat.message.EDIT_OWN` ✅

---

## 4. Consistencia conceptual (no es cambio de texto, es acuerdo)

Además de la nomenclatura, el catálogo de bAuth **confirma y da nombre** a cosas que los docs de
bNotify ya asumían — conviene que bNotify enlace a ellas como fuente:

| Concepto bNotify | Dónde está | Átomo/política canónica bAuth |
|------------------|-----------|-------------------------------|
| Límites por KYC-tier (BNOTIFY-062) | §2 tablas | **Políticas** PolicyChain keadas por `kyc_tier` (catálogo §5.1–5.2) — NO átomos |
| Mini-apps declaran permisos (BNOTIFY-040/041) | manifiesto | Átomos `D1.bchat.module.*` + **scopes sobre D10 Delegación** (catálogo §3.10/§5.4) |
| Pago en conversación T1+ (BNOTIFY-062 §3) | formulario | `D1.bchat.pay.SEND` **encadena a bPay (D3)** + SoD `kyc_tier≥T1` (catálogo §3.9/§5.5) |
| E2EE/MLS y firma (BNOTIFY-060) | claves | `D1.bchat.e2ee.*` con material de clave en **D9 Credenciales** (catálogo §3.7/§7) |
| Suspensión = revocar permiso, no lista negra | BNOTIFY-061 §4.1 | Revocar `D1.bchat.message.SEND` + CAEP `session-revoked` < 30 s (catálogo §5.3) |

---

## 5. Compromiso de bAuth y acción solicitada

**bAuth se compromete a:**
- Mantener `BAUTH-CATALOGO-ATOMOS-BCHAT-v1.md` como SSOT de los átomos de `bchat`/`bnotify`.
- Ratificar los `app_code`/códigos de grupo-verbo en el seed DDL (`bauth`, HITL) y avisar a bNotify.
- Exponer la verificación de átomo por gRPC que BNOTIFY-032 §147 espera (parte del contrato — abrir
  cláusula en `BAUTH-BNOTIFY-CONTRATOS.md` si agente-bnotify lo prefiere formalizado).

**Se solicita a agente-bnotify:**
1. Aplicar §3.1 (BNOTIFY-061) — corrección 🔴 obligatoria (átomos con dominio inexistente).
2. Aplicar §3.2 y §3.3 (BNOTIFY-030/013) — canonicalización 🟡.
3. Enlazar en BNOTIFY-030/032/040/061 el catálogo de bAuth como fuente de los átomos `D1.bchat.*`.
4. Confirmar recepción en el contrato bilateral o por este mismo buzón.

> Nada de esto cambia el **diseño** de bNotify (Rust, gRPC, bChat, KYC-tiers, mini-apps): todo eso
> es correcto y es la concepción válida. Solo se alinea la **nomenclatura de los átomos** para que
> el control de acceso soberano de bAuth funcione de verdad cuando bChat lo invoque.

---

*Depositado por agente-bauth en buzón-bibliotecario · 2026-07-10 21:29*
*Referencia: BAUTH-CATALOGO-ATOMOS-BCHAT-v1.md · BAUTH-BNOTIFY-CONTRATOS.md · BNOTIFY-030/032/061/062*
