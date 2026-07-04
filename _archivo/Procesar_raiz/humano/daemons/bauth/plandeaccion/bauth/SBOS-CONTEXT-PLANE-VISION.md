# SBOS Context Plane — Visión y Alcances del Proyecto

**Versión:** 1.0 · **Fecha:** 2026-06-24 · **Autor:** sbos-coordinador
**Clasificación:** DOCUMENTO FUNDACIONAL — Define el propósito, la propuesta de valor y los alcances
del proyecto SBOS. Todo desarrollo, migración y decisión arquitectónica debe alinearse con esta visión.

---

## 1. EL PROBLEMA QUE SBOS RESUELVE

Cada empresa que desarrolla software enfrenta el mismo ciclo inevitable. Antes de poder
escribir una sola línea de lógica de negocio — inventarios, ventas, compras, producción —
el equipo de desarrollo debe construir, integrar y mantener:

| Componente | Esfuerzo típico | Qué implica realmente |
|-----------|:---:|------|
| **Autenticación** | 3–6 meses | Password, MFA, WebAuthn, Passkeys. No es solo un formulario de login. |
| **Roles y permisos** | 4–8 meses | RBAC, ABAC, herencia, segregación de funciones, conflictos. |
| **Sesiones** | 1–2 meses | Timeout, inactividad, reautenticación, sesiones concurrentes, rotación. |
| **MFA** | 2–4 meses | TOTP, SMS (deprecado), Passkeys, FIDO2, recovery codes. |
| **Dispositivos de confianza** | 2–3 meses | Postura del dispositivo, scoring, verificación continua. No es un checkbox. |
| **SSO / Federación** | 3–5 meses | OIDC, SAML, OAuth 2.1, PKCE, CIBA, token exchange. |
| **Control de acceso físico** | 3–6 meses | OSDP, NFC, QR, biométrico, zonas de seguridad, anti-passback. |
| **Auditoría** | 2–4 meses | WORM, hash-chain, compliance (SOX, PCI, GDPR, ISO 27001). |

**Total acumulado: 20–38 meses.** Y eso es antes de escribir la primera línea de código
que genera valor para el negocio.

Todas las empresas reconstruyen esta infraestructura desde cero. Todas cometen los mismos
errores. Todas llegan al mismo resultado: un sistema de autenticación que funciona
medianamente bien para su caso de uso específico, pero que no escala, no se adapta, y
requiere mantenimiento constante.

**SBOS elimina este ciclo.**

---

## 2. LA PROPUESTA DE VALOR CENTRAL

### SBOS no vende autenticación. SBOS vende contexto.

La distinción es fundamental. Un sistema de autenticación responde una pregunta binaria:
**"¿Tiene permiso?"** → `true` o `false`.

El Context Plane responde una pregunta radicalmente distinta:
**"¿Puede hacerlo en este contexto?"** → Una respuesta multidimensional que considera
identidad, ubicación, horario, dispositivo, nivel de confianza, empresa, sucursal,
sesión laboral, recursos físicos y capacidades asignadas.

### Una sola llamada

El desarrollador hace exactamente una llamada:

```go
ctx := bos.GetContext()
```

Y recibe todo lo que necesita saber para tomar decisiones de negocio:

```json
{
  "user":        "juan",
  "tenant":      "empresa_a",
  "branch":      "lapaz",
  "trust":       "biometric",
  "permissions": ["inventory.read", "inventory.write"]
}
```

A partir de ese punto, el desarrollador se concentra **únicamente** en su lógica de negocio:
inventarios, ventas, compras, producción. La autenticación, las sesiones, los permisos, los
dispositivos, los horarios, las sucursales, la auditoría — todo eso ya está resuelto por
el Context Plane.

---

## 3. EL EJEMPLO QUE EXPLICA TODO

**Juan es cajero.** Quiere procesar un cobro de 3.500 BOB.

### Con un sistema de autenticación tradicional:

```
¿Tiene permiso para cobrar? → Sí.
✅ Cobro autorizado.
```

El sistema verificó un permiso. Punto. No verificó nada más. Juan podría estar
cobrando desde su casa, fuera de horario, desde un dispositivo personal, en una
sucursal donde no trabaja. El sistema tradicional no lo sabe porque no tiene
contexto.

### Con el Context Plane de SBOS:

```
¿Puede cobrar 3.500 BOB?
  → Solo en sucursal La Paz           ← Ubicación física verificada
  → Solo durante su turno (08:00–18:00) ← Horario validado
  → Solo desde un dispositivo autorizado ← Postura del dispositivo verificada
  → Solo con biometría validada         ← Nivel de confianza AAL2
  → Solo hasta 5.000 BOB por transacción ← Límite financiero del rol
  → Con segundo factor para >2.000 BOB  ← Step-up RFC 9470 activado
✅ Cobro autorizado con contexto completo.
```

**La aplicación no implementa ninguna de esas reglas. Las consume.** El desarrollador
de la aplicación de caja nunca escribió código para verificar la sucursal, ni el
horario, ni el dispositivo, ni la biometría, ni el límite financiero, ni el step-up.
Todo eso lo resolvió el Context Plane antes de que la aplicación recibiera el contexto.

---

## 4. QUÉ INCLUYE EL CONTEXTO

Lo que hace único al Context Plane no es que verifique nueve dimensiones — es que
las verifica **juntas, en un solo ciclo de evaluación determinista**, con un orden
de precedencia definido y con la capacidad de cortocircuitar la evaluación en el
primer dominio que deniegue.

| Dimensión | Dominio | Qué verifica | Ejemplo |
|-----------|:---:|------|------|
| **Identidad** | D9 | Quién es, cómo se autenticó, con qué nivel de garantía | Juan, AAL2, Passkey + TOTP |
| **Dispositivo** | D7 | Desde qué dispositivo, postura de seguridad, scoring | Terminal POS-23, score 85/100 |
| **Ubicación** | D6 | Desde dónde físicamente, geo-fence, velocidad | Sucursal La Paz, radio 200m |
| **Horario** | D4 | En qué momento, dentro de su turno, día hábil | Lunes 14:30, turno activo |
| **Nivel de confianza** | D9+D8 | AAL, MFA, session binding, riesgo en tiempo real | AAL2, MFA verificado, riesgo bajo |
| **Empresa** | ORG | En qué empresa del tenant está operando | Empresa A (NIT 123456) |
| **Sucursal** | ORG | En qué ubicación física de la empresa | Sucursal La Paz Central |
| **Sesión laboral** | D8+D4 | Sesión activa, no expirada, dentro del turno | Sesión 8h, 4h restantes |
| **Recursos físicos** | D2 | A qué espacios, dispositivos, actuadores tiene acceso | Caja 01, lector NFC, cámara |

---

## 5. POSICIONAMIENTO ESTRATÉGICO

El mercado de identidad tiene tres niveles. SBOS elige deliberadamente el tercero.

### Nivel 1 — Auth as a Service

```
"Te vendemos autenticación. Maneja tus usuarios, passwords y MFA."
```

**Mercado:** Saturado. **Competidores:** Okta, Auth0, Microsoft Entra ID, Clerk, WorkOS, Keycloak.
**Propuesta de valor:** Commodity. Se compite por precio y features incrementales.
**Diferenciación:** Ninguna. Todos ofrecen lo mismo.

SBOS **no** compite en este nivel.

### Nivel 2 — Identity + Context Platform

```
"Te damos identidad, sesiones, dispositivos, ubicación, horarios. 
Todo integrado. Una sola API."
```

**Mercado:** Menos saturado. **Competidores:** Pocos. Ping Identity, CyberArk (parcial).
**Propuesta de valor:** El desarrollador no integra 5 proveedores. Integra uno.
**Diferenciación:** El contexto como producto, no como feature.

SBOS **compite aquí hoy** y **gana por profundidad de contexto**.

### Nivel 3 — Business Context Operating System

```
"Recibes identidad, contexto, confianza, recursos, capacidades y auditoría 
como plataforma unificada. El desarrollador deja de pensar en autenticación, 
sesiones, permisos, dispositivos, presencia, horarios, sucursales y auditoría. 
Todo eso ya está resuelto por el Context Plane."
```

**Mercado:** Nuevo. **Competidores:** Ninguno. Es una categoría que SBOS crea.
**Propuesta de valor:** El desarrollador hace `bos.GetContext()` y recibe todo.
**Diferenciación:** Categórica. No se compite con un proveedor de login. Es otra categoría.

SBOS se posiciona aquí como objetivo estratégico.

---

## 6. FASES DE ALCANCE DEL PROYECTO

### Fase 1 — CONSOLIDAR LOS TRES PLANOS FUNDAMENTALES

**Duración estimada:** 12–18 meses
**Estado actual:** En desarrollo

Consolidar los tres planos sin los cuales nada más funciona:

| Plano | Responsabilidad | Daemons | Estado |
|-------|----------------|---------|:---:|
| **Identity Plane** | Quién es, cómo se autenticó, con qué nivel de garantía | `bauth` + Keycloak | 🔄 En migración de DDL |
| **Trust Plane** | Desde qué dispositivo, en qué red, con qué postura de seguridad | `bhnexus` + `banexus` | 🔄 En desarrollo |
| **Context Plane** | Dónde, cuándo, en qué empresa, sucursal, sesión, con qué capacidades | `bauth` + `bkernel` + `biedata` | 🔄 En diseño |

**Criterio de completitud:** Un desarrollador puede llamar `bos.GetContext()` y recibir
identidad + confianza + contexto para un usuario autenticado en una sesión laboral activa.

### Fase 2 — SDK OFICIAL MULTI-LENGUAJE

**Duración estimada:** 6–12 meses después de Fase 1

Publicar SDKs oficiales para los lenguajes donde viven los clientes:

| Lenguaje | Clientes objetivo | API |
|----------|-------------------|-----|
| **Go** | Daemons SBOS, backends | `ctx, err := bos.GetContext()` |
| **Rust** | bkernel, biedata, sistemas de alta performance | `let ctx = bos::get_context()?` |
| **Flutter/Dart** | Aplicaciones móviles, VDI, POS | `final ctx = await Bos.getContext()` |
| **TypeScript/Node** | Frontends web, APIs | `const ctx = await bos.getContext()` |
| **Python** | Data science, scripting, integración | `ctx = bos.get_context()` |

Cada SDK expone **una sola función principal** — `bos.context()` — y abstrae:
- Autenticación (todos los métodos, todos los flujos)
- Sesiones (creación, renovación, expiración, rotación)
- Permisos (evaluación, scope, step-up)
- Dispositivos (postura, scoring, verificación continua)
- Contexto (empresa, sucursal, POS, turno)
- Auditoría (automática, WORM, hash-chain)

### Fase 3 — INTEGRACIÓN EN UN DÍA

**Duración estimada:** 6 meses después de Fase 2

**Objetivo:** Cualquier desarrollador puede integrar SBOS en un día laboral (8 horas)
y olvidarse **permanentemente** de construir:

- Autenticación
- Sesiones
- Permisos
- MFA
- SSO
- Auditoría
- Control de acceso
- Gestión de dispositivos

**Métrica de éxito:** De 20–38 meses de desarrollo pre-negocio a 8 horas de integración.
**Reducción:** ~99.5% del esfuerzo de infraestructura de identidad.

### Fase 4 — MÁS ALLÁ DEL SOFTWARE

**Duración estimada:** 12–24 meses después de Fase 3

Extender el Context Plane más allá del software puro:

| Extensión | Qué habilita | Ejemplo |
|-----------|-------------|------|
| **IoT** | Dispositivos conectados como parte del contexto | Sensor de temperatura en almacén farmacéutico |
| **Domótica** | Edificios inteligentes integrados al control de acceso | Sistema de iluminación que responde al contexto del empleado |
| **Control de acceso físico** | Puertas, torniquetes, cámaras como recursos del Context Plane | Acceso a sala de servidores requiere AAL3 + two-person rule |
| **Recursos físicos** | Terminales, cajas, salas, vehículos como entidades contextuales | Caja registradora asignada al turno del cajero |

---

## 7. LA PREGUNTA FUNDACIONAL

Todo el producto se resume en una distinción:

| Sistema tradicional | Context Plane |
|---------------------|---------------|
| ¿Tiene permiso? | ¿Puede hacerlo **en este contexto**? |
| Binario: `true/false` | Multidimensional: identidad + dispositivo + ubicación + horario + confianza + empresa + sucursal + sesión + recursos |
| La aplicación implementa las reglas | La aplicación **consume** las reglas |
| El desarrollador integra 5–10 proveedores | El desarrollador hace **una llamada** |
| 20–38 meses de infraestructura | 8 horas de integración |

---

## 8. LO QUE SBOS NO ES

Para clarificar el posicionamiento, es igualmente importante declarar lo que SBOS **no** es:

- ❌ **No es un IdP genérico.** Keycloak es el IdP. SBOS es el orquestador de contexto que envuelve al IdP.
- ❌ **No es un ERP.** Tryton es el ERP. SBOS le provee el contexto de identidad.
- ❌ **No es un SIEM.** Wazuh es el SIEM. SBOS le alimenta eventos de auditoría con ctx_id trazable.
- ❌ **No es un PAM.** CyberArk/HashiCorp Vault manejan secretos. SBOS maneja el contexto que determina QUIÉN puede acceder a esos secretos.
- ❌ **No es un MDM.** SBOS consume señales de postura de dispositivo, no gestiona los dispositivos.

---

## 9. PRINCIPIOS DE DISEÑO IRRENUNCIABLES

| # | Principio | Significado |
|---|-----------|-------------|
| **P1** | El contexto es el producto | No vendemos features de autenticación. Vendemos la capacidad de obtener contexto en una llamada. |
| **P2** | Una sola llamada | `bos.GetContext()`. Sin excepciones. Sin flags. Sin parámetros que el desarrollador deba entender. |
| **P3** | El desarrollador no implementa reglas | Las consume del Context Plane. Las reglas de negocio viven en bAuth, no en la aplicación. |
| **P4** | 12 dominios de soberanía | D1–D12. Cada dominio contribuye una dimensión al contexto. La evaluación es determinista y auditable. |
| **P5** | Determinista y auditable | Misma entrada → misma salida. Cada decisión trazable vía ctx_id y audit_event. |
| **P6** | Sin HTTP entre daemons | Unix socket + WebSocket. SBOS-050 P9. |
| **P7** | Interface Dual obligatoria | WebSocket RPC + JSON-RPC 2.0 sobre el mismo socket. ADR-020. |
| **P8** | Zero Trust desde el diseño | Nunca confiar, siempre verificar. Cada request evalúa el contexto completo. NIST 800-207. |

---

## 10. MÉTRICAS DE ÉXITO DEL PROYECTO

| Fase | Métrica | Objetivo |
|------|---------|----------|
| **Fase 1** | `bos.GetContext()` funcional | < 5ms latencia, 99.9% disponibilidad |
| **Fase 2** | SDKs publicados | 5 lenguajes, 1 función principal cada uno |
| **Fase 3** | Tiempo de integración | < 8 horas para un desarrollador nuevo |
| **Fase 4** | Extensiones físicas | IoT + domótica + acceso físico integrados |

---

*Documento unificado generado 2026-06-24. 1175 líneas.*
*Parte 1: Visión estratégica y posicionamiento del Context Plane.*
*Parte 2: Experiencia real — 10 momentos del ciclo de vida del usuario.*
*Parte 3: El celular como Identity Hub — arquitectura, protocolos, impacto en DDL.*
*Todo desarrollo, migración y decisión arquitectónica debe poder trazarse a un principio aquí declarado.*

---

## PRINCIPIO ABSOLUTO

> **El celular del usuario es su llave universal.**
> Registra su huella UNA VEZ en el teléfono.
> A partir de ahí, todo lo demás funciona sin fricción:
> aplicaciones, puertas, terminales, cajas.
> El ctx_id vive en el celular y se transfiere vía QR.

---

## MOMENTO 1 — ONBOARDING (Día 1)

```
Juan llega a la oficina el primer día.
─────────────────────────────────────────
1. En recepción, hay un QR en la pantalla.
2. Juan abre la app SBOS Authenticator en su celular.
3. Escanea el QR.
4. El QR contiene: {tenant:"skull", empresa:"acme", sucursal:"central", action:"onboard"}
5. El celular envía la petición a bAuth vía bhnexus.
6. bAuth:
   - Crea el idn_user_template de Juan
   - Registra vigencia, horario, sucursal
   - Instruye a BOS: registrar ingreso (hora_entrada)
   - Solicita al celular: "registra tu huella digital"
7. Juan apoya el dedo en el sensor de su teléfono.
   - El sensor captura la huella → desbloquea clave privada FIDO2
   - El dispositivo firma el challenge de bAuth
   - bAuth verifica la firma con la clave pública
   - NUNCA se envía la huella. Solo la firma criptográfica.
8. bAuth emite el ctx_id y lo envía al celular.
9. El celular ahora tiene: ctx_id, token JWT, BitMask, permisos.
10. Juan está listo. No escribió un password. No tocó un teclado.
```

**Tablas involucradas:** `idn_user_template`, `ath_binding`, `ath_mfa_enrollment`,
`ses_context`, `idn_user_role`, `org_empresa`, `org_sucursal`

---

## MOMENTO 2 — INICIO DE JORNADA (Cada día)

```
Juan llega a la oficina a las 08:00.
─────────────────────────────────────────
1. Escanea el QR de entrada con su celular.
2. El QR contiene: {sucursal:"central", action:"clock_in"}
3. bAuth recibe la petición.
4. Verifica:
   - ctx_id de Juan sigue activo (no expirado)
   - Sesión laboral dentro del horario (08:00-18:00)
   - Dispositivo de confianza (el mismo celular)
   - Ubicación dentro del geo-fence de la sucursal
5. bAuth → BOS: "registrar hora_entrada de Juan"
6. BOS registra en el calendario laboral.
7. ctx_id de Juan se promueve a sesión laboral activa.
8. BitMask se activa con los permisos del turno.
```

**Tablas involucradas:** `ses_context`, `cal_schedule`, `cal_event`,
`geo_fence`, `geo_trust_tier`, `net_device`

---

## MOMENTO 3 — USAR APLICACIONES EN LA OFICINA (Varias veces al día)

```
Juan necesita usar el ERP en una computadora de la oficina.
─────────────────────────────────────────
1. La computadora muestra un QR en la pantalla de login.
2. El QR contiene: {device:"CPU-045", pos_logico:"POS-23", action:"ctx_transfer"}
3. Juan escanea el QR con su celular.
4. El celular envía a bAuth vía bhnexus:
   - ctx_id de Juan
   - device_id de la computadora (CPU-045)
   - pos_logico donde está (POS-23)
5. bAuth:
   - Verifica que Juan tiene permiso para usar esa computadora
   - Verifica que está en la sucursal correcta
   - Verifica que la computadora es un dispositivo autorizado
   - Crea un ctx_id derivado para la sesión de escritorio (TTL: 8h o fin de turno)
   - Transfiere el ctx_id a la computadora
6. La computadora recibe el ctx_id.
7. Todas las aplicaciones en esa computadora usan ese ctx_id.
8. Juan no escribió usuario, no escribió password, no usó MFA.
   Solo escaneó un QR con su celular.
```

**Tablas involucradas:** `ses_context_switch`, `zone_application_map`,
`zone_button_rule`, `net_device`, `org_pos_logico`

---

## MOMENTO 4 — ABRIR UNA PUERTA (Varias veces al día)

```
Juan necesita entrar al almacén.
─────────────────────────────────────────
1. En la puerta del almacén hay un lector NFC/QR.
2. Juan acerca su celular al lector.
3. El celular transmite el ctx_id vía NFC o QR.
4. bhnexus recibe la petición.
5. bAuth evalúa:
   - ¿Tiene Juan acceso a PHY_ZONE_ALMACEN?
   - ¿Está dentro de su horario?
   - ¿El dispositivo tiene confianza suficiente?
   - ¿El método de acceso cumple el LoA requerido?
6. Si todo OK → bAuth → bhnexus → controladora OSDP → abre la puerta.
7. Juan no sacó una tarjeta, no puso un PIN, no escaneó su huella en la puerta.
   El ctx_id en su celular ya contiene toda la autorización.
```

**Tablas involucradas:** `fis_access_zone`, `fis_zone_member`, `fis_device`,
`fis_zone_method_requirement`, `dlg_delegation`, `ses_context`

---

## MOMENTO 5 — COBRAR EN CAJA (Operación financiera)

```
Juan es cajero. Un cliente paga 3.500 BOB.
─────────────────────────────────────────
1. Juan ya tiene su ctx_id activo en la terminal de caja (transferido vía QR en M3).
2. La aplicación de caja procesa el cobro.
3. bAuth evalúa:
   - ¿Juan tiene permiso para cobrar? → privilege_atom: zone_logical/caja:EXECUTE
   - ¿El monto está dentro de su límite? → 3.500 < 5.000 (fin_limit)
   - ¿Está en sucursal La Paz? → geo_fence: inside
   - ¿Dentro de su turno? → cal_schedule: 14:30, turno activo
   - ¿Dispositivo autorizado? → net_device: POS-23, score 85
   - ¿Step-up necesario? → 3.500 < 5.000 (límite step-up) → No requiere
4. bAuth responde: ALLOW.
5. La aplicación registra el cobro.
6. Juan nunca vio un diálogo de "¿tiene permiso?".
   La evaluación ocurrió en <5ms, transparente.
```

**Tablas involucradas:** `privilege_atom`, `privilege_atom_policy`,
`fin_limit`, `fin_sod_rule`, `fin_transaction_type`, `privilege_atom_audit`

---

## MOMENTO 6 — DELEGAR UN PERMISO (Temporal)

```
Juan se va de vacaciones. Delega su acceso a María por 7 días.
─────────────────────────────────────────
1. Juan abre la app SBOS Authenticator.
2. Selecciona: "Delegar acceso" → elige a María → elige fechas.
3. bAuth:
   - Verifica que Juan puede delegar (dlg_delegation policy)
   - Crea delegación: from=Juan, to=María, rol=CAJERO, valid_until=+7d
   - Calcula mask_delegated: mask_eff(Juan) AND mask_own(CAJERO)
4. María recibe una notificación: "Juan te delegó acceso de cajero por 7 días".
5. El ctx_id de María ahora incluye los permisos delegados.
6. Al vencer, bAuth revoca automáticamente.
7. Juan no llamó a sistemas. No abrió un ticket. Lo hizo en 30 segundos desde su celular.
```

**Tablas involucradas:** `dlg_delegation`, `idn_user_role`, `ath_step_up_rule`

---

## MOMENTO 7 — USUARIO EXTERNO (Cliente de una empresa)

```
Un cliente de ACME necesita ver sus facturas en el portal.
─────────────────────────────────────────
1. El cliente abre la app SBOS Authenticator (o el portal web).
2. Inicia sesión con Passkey (huella en su celular).
3. bAuth verifica la Passkey → autenticado.
4. bAuth emite ctx_id con scope EXTERNO.
5. El cliente ve SOLO sus facturas, SOLO de su empresa, SOLO en modo lectura.
6. No puede ver otros clientes, no puede modificar, no puede acceder al ERP interno.
7. El cliente nunca creó una "cuenta". Su identidad es su Passkey.
```

**Tablas involucradas:** `idn_user_template` (account_type=EXTERNO),
`ath_binding`, `idn_tier_policy` (tier=EXT_N0), `zone_record_rule`

---

## ARQUITECTURA DEL FLUJO

```
                      ┌─────────────────────────────┐
                      │     SBOS Authenticator       │
                      │     (App en el celular)      │
                      │                              │
                      │  • ctx_id almacenado         │
                      │  • Token JWT                 │
                      │  • BitMask activa            │
                      │  • Passkey (huella/Face ID)  │
                      │  • QR Scanner                │
                      │  • NFC transmitter           │
                      └──────────┬──────────────────┘
                                 │
                    QR / NFC / WebSocket
                                 │
              ┌──────────────────┼──────────────────┐
              ▼                  ▼                  ▼
        ┌──────────┐      ┌──────────┐      ┌──────────┐
        │  Desktop │      │  Puerta  │      │  Caja    │
        │  (CPU)   │      │ (OSDP)   │      │ (POS)    │
        └────┬─────┘      └────┬─────┘      └────┬─────┘
             │                 │                 │
             └─────────────────┼─────────────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │       bhnexus        │
                    │   (Nexus Host)       │
                    │   WebSocket mTLS     │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │        bAuth         │
                    │   (Context Plane)    │
                    │                      │
                    │  Evalúa 12 dominios  │
                    │  en <5ms             │
                    │  Responde: ctx_id    │
                    └──────────┬──────────┘
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
              ┌──────────┐         ┌──────────┐
              │ Keycloak │         │  Tryton  │
              │  (IdP)   │         │  (ERP)   │
              └──────────┘         └──────────┘
```

---

## LA FRICCIÓN QUE DESAPARECE

| Sin Context Plane | Con Context Plane |
|-------------------|-------------------|
| "Ingrese su usuario" | Escanea QR → listo |
| "Ingrese su password" | No hay password |
| "Ingrese código TOTP" | La huella en el celular ya verificó MFA |
| "¿Tiene permiso para esta app?" | El ctx_id ya contiene los permisos |
| "Pase su tarjeta por el lector" | Acerca el celular → puerta abierta |
| "Llame a sistemas para delegar" | Delega desde la app en 30 segundos |
| "Cree una cuenta en el portal" | Su Passkey ES su cuenta |
| "Recuerde 15 passwords distintos" | Un solo ctx_id para todo |

---

## PRINCIPIOS DE DISEÑO

| # | Principio | Significado |
|---|-----------|-------------|
| **P1** | El celular es la llave universal | Un solo dispositivo. Apps, puertas, cajas, todo. |
| **P2** | La biometría se registra UNA VEZ | En el celular. Nunca en cada lector de puerta. |
| **P3** | QR como transporte de contexto | Mueve el ctx_id del celular a cualquier dispositivo sin contacto. |
| **P4** | Cero fricción post-onboarding | Después del Día 1, el usuario nunca más escribe credenciales. |
| **P5** | Evaluación transparente | El usuario no ve "cargando permisos...". Ocurre en <5ms. |
| **P6** | La biometría nunca sale del dispositivo | Solo viaja la firma criptográfica. GDPR Art.9 compliant. |
| **P7** | Un ctx_id para todo | Mismo contexto para apps, puertas, cajas, reportes, delegaciones. |

---

---

## MOMENTO 8 — EMERGENCIA LABORAL (Override temporal por supervisor)

```
Son las 23:00. El servidor principal falla.
─────────────────────────────────────────
Carlos, el técnico de sistemas, está en su casa.
Su ctx_id normal NO le permite:
  - Ingresar fuera de horario (cal_schedule: 08:00-18:00)
  - Ingresar desde su casa (geo_trust_tier: LOW)
  - Acceder a la sala de servidores (fis_access_zone: CRITICAL)

1. La alarma de monitoreo dispara una alerta al supervisor (María).
2. María abre SBOS Authenticator en su celular.
3. Selecciona: "Autorizar acceso de emergencia" → elige a Carlos.
4. Configura la política temporal:
   - Ventana: 23:00 a 04:00 (4 horas)
   - Ubicación: sucursal La Paz (geo_fence override)
   - Zonas físicas: PHY_ZONE_SERVIDOR
   - Nivel de acceso: FULL
   - Justificación: "Falla crítica servidor principal — ticket INC-2026-0042"
5. bAuth:
   - Verifica que María tiene autoridad para delegar acceso de emergencia
   - Crea una política temporal (dlg_delegation + emergency_override)
   - Step-up: María debe autenticarse con AAL3 (Passkey device-bound)
   - Genera un QR con la política temporal embebida
6. María envía el QR al celular de Carlos por WhatsApp/RocketChat.
7. Carlos escanea el QR con su celular.
8. bAuth:
   - Actualiza el ctx_id de Carlos con la política temporal
   - Registra el inicio de horas extra (cal_overtime_policy)
   - Registra en auditoría: "acceso emergencia autorizado por María, ticket INC-2026-0042"
9. Carlos llega a la oficina, acerca su celular a la puerta.
   - La puerta abre (tenía PHY_ZONE_SERVIDOR restringido, ahora tiene override)
10. Carlos trabaja en el servidor. Cada acción queda registrada en audit_event.
11. A las 04:00, la política temporal expira automáticamente.
    - El ctx_id de Carlos vuelve a su estado normal.
    - La puerta de servidores ya no le abre.
    - Se registran 5 horas extra para Carlos.
12. A las 08:00, María recibe un resumen: "Carlos trabajó 5h extra. Acceso a servidores
    de 23:00 a 04:00. 127 comandos ejecutados. Todo dentro de la ventana autorizada."
```

**Tablas involucradas:** `dlg_delegation`, `ath_step_up_rule`, `ses_context`,
`fis_access_zone`, `geo_fence`, `geo_trust_tier`, `cal_schedule`, `cal_overtime_policy`,
`aud_event`, `fis_emergency_config`

**Nuevo concepto:** `bauth.emergency_override_policy` — política temporal que anula
restricciones geoespaciales, temporales y físicas por un período limitado, con
trazabilidad completa y fecha de expiración automática.

---

## MOMENTO 9 — RESIDENCIA INTELIGENTE (Visitante temporal)

```
Ana vive en un departamento con SBOS Home.
Su hermano Pablo viene de visita por el fin de semana.
─────────────────────────────────────────
1. Ana abre SBOS Home en su celular.
2. Selecciona: "Invitar visitante" → ingresa el número de Pablo.
3. Configura:
   - Acceso físico: puerta principal, puerta de lavandería
   - Horario: sábado 08:00 a domingo 20:00
   - Días: solo sábado y domingo
   - Ambientes: sala, cocina, baño de visitas, lavandería
   - Ambientes restringidos: dormitorio principal, estudio (NO acceso)
   - Servicios: iluminación de sala y cocina, calefacción
   - Control remoto: NO (solo presencial)
4. bAuth:
   - Crea un idn_user_template temporal para Pablo (account_type=VISITANTE)
   - Asigna políticas: temporal (D4: 48h), geoespacial (D6: departamento), física (D2: puertas)
   - Genera un QR de invitación
5. Ana envía el QR a Pablo por WhatsApp.
6. Pablo llega el sábado a las 09:00. Escanea el QR en la puerta con su celular.
7. La puerta abre.
8. Pablo entra a la sala. Las luces se encienden automáticamente (su ctx_id activó
   la iluminación de la sala).
9. Pablo va a la lavandería. La puerta abre.
10. Pablo intenta entrar al estudio de Ana. La puerta NO abre.
    bAuth evaluó: "Pablo NO tiene acceso a zona ESTUDIO. DENY."
11. El domingo a las 20:00, el ctx_id de Pablo expira.
    - Ya no puede abrir ninguna puerta.
    - Las luces ya no responden a su presencia.
    - Su idn_user_template pasa a estado TERMINATED.
12. Ana recibe una notificación: "La visita de Pablo ha finalizado. Accesos revocados."
```

**Tablas involucradas:** `idn_user_template` (VISITANTE), `idn_tier_policy` (tier=VISITANTE),
`fis_access_zone`, `fis_device`, `cal_schedule`, `geo_fence`, `dlg_delegation`,
`ses_context`, `ath_consent`

**Nuevo concepto:** SBOS no es solo empresarial. La misma arquitectura de 12 dominios
funciona para una residencia. Lo que cambia es la escala y el tenant, no el motor.

---

## MOMENTO 10 — CONTROL REMOTO DE RESIDENCIA (Dueño desde otra ciudad)

```
Ana está de viaje en otra ciudad. Quiere verificar su departamento.
─────────────────────────────────────────
1. Ana abre SBOS Home.
2. Ve el dashboard de su residencia:
   - Puertas: principal CERRADA, lavandería CERRADA
   - Iluminación: todo APAGADO
   - Temperatura: 18°C
   - Último acceso: hace 3 días (ella misma)
3. Ana activa la calefacción remotamente para que el departamento esté
   caliente cuando regrese mañana.
4. bAuth:
   - Verifica que Ana es la dueña (org_empresa con es_operador=true, o
     idn_role_template con role=PROPIETARIO)
   - Autoriza el control remoto (D7: VPN requerida, device trust MEDIUM)
   - Ejecuta: actuador de calefacción → ON
5. Ana recibe confirmación: "Calefacción activada. Temperatura estimada
   al llegar: 22°C."
6. Ana también puede:
   - Ver las cámaras de seguridad (zona común, no dormitorios privados)
   - Abrir la puerta remotamente para un delivery (política temporal de 5 min)
   - Recibir alertas: "Movimiento detectado en la puerta principal"
```

**Tablas involucradas:** `fis_device` (actuadores), `net_device`, `geo_trust_tier`,
`ses_context` (ctx_id remoto), `net_ztna_policy`, `zone_record_rule`

---

## EL MUNDO QUE bAuth ABRE

```
EMPRESARIAL                          RESIDENCIAL
────────────                         ────────────
Control de acceso a oficinas         Control de acceso al hogar
Gestión de empleados y turnos        Gestión de familia y visitantes
Autorización de horas extra          Invitaciones temporales
Delegación de permisos               Compartir acceso con invitados
Control de cajas y POS               Control de iluminación y climatización
Auditoría financiera (SOX, PCI)      Auditoría de accesos al hogar
Cumplimiento normativo (ISO 27001)   Privacidad y seguridad familiar
──────────────────────────────────────────────────────────────────
              EL MISMO MOTOR: 12 dominios D1-D12
              LA MISMA APP: SBOS Authenticator
              EL MISMO FLUJO: QR → ctx_id → acceso
              DIFERENTE ESCALA: 500 empleados o 5 familiares
──────────────────────────────────────────────────────────────────
```

**bAuth no es un producto de autenticación — es una plataforma de contexto.**
El mismo motor que autoriza a un cajero a cobrar 3.500 BOB en una sucursal
en La Paz, autoriza a un visitante a encender las luces de la sala un sábado.
Lo que cambia es la configuración de los 12 dominios, no el motor.

---

*Documento generado 2026-06-24. 10 momentos documentados.*
*No es arquitectura técnica — es el "qué se siente usar SBOS".*
*Cada momento referenciado aquí debe tener cobertura de tablas en el inventario.*
*bAuth no es solo empresarial. Es una plataforma de contexto universal.*
# SBOS-MOBILE-CTXID-CONTROL.md — El Celular como Centro de Control del Context Plane

**Versión:** 1.0 · **Fecha:** 2026-06-24 · **Autor:** sbos-coordinador + humano
**Propósito:** Documentar cómo el celular almacena, gestiona y transmite el ctx_id para
convertirse en la llave universal del ecosistema SBOS. Este documento es la base para
robustecer la DDL con las capacidades móviles requeridas.

**Estándares investigados:** FIDO2 CTAP 2.2 · WebAuthn Level 3 · W3C WebAuthn · caBLE ·
NIST SP 800-63B-4 Final (2025) · ISO 18013-5 (mDL) · OpenID Connect · OAuth 2.1

---

## 1. ARQUITECTURA: EL CELULAR COMO IDENTITY HUB

```
┌─────────────────────────────────────────────────────────────────┐
│                    SBOS AUTHENTICATOR                             │
│                 (Aplicación Flutter en el celular)                │
│                                                                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────┐  │
│  │ Secure Storage   │  │ Passkey Manager │  │ QR/NFC Engine    │  │
│  │ (Keystore/       │  │ (FIDO2/CTAP2/   │  │ (CTAP 2.2 Hybrid │  │
│  │  Secure Enclave) │  │  WebAuthn)      │  │  + NFC NDEF)     │  │
│  └────────┬────────┘  └────────┬────────┘  └────────┬─────────┘  │
│           │                    │                     │            │
│  ┌────────┴────────────────────┴─────────────────────┴────────┐  │
│  │                    ctx_id Store                             │  │
│  │  • ctx_id activo (sesión laboral)                           │  │
│  │  • Token JWT (access_token + refresh_token)                 │  │
│  │  • BitMask efectiva (hex)                                   │  │
│  │  • dctx_id (device context, pre-autenticación)              │  │
│  │  • Trust level (HIGH/MEDIUM/LOW)                            │  │
│  │  • Historial de ctx_id derivados (desktop, puerta, caja)    │  │
│  │  • Políticas temporales activas (overrides con TTL)         │  │
│  └─────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. CICLO DE VIDA DEL ctx_id EN EL CELULAR

### 2.1 Nacimiento: Onboarding (Día 1)

```
PASO 1 ─── El celular escanea QR de onboarding
           QR contiene: {tenant, empresa, sucursal, action:"onboard"}
           
PASO 2 ─── bAuth recibe la petición vía bhnexus (WebSocket mTLS)
           Crea idn_user_template, asigna roles, registra vigencia
           
PASO 3 ─── bAuth solicita al celular: registro de Passkey (FIDO2)
           ┌─ iOS: ASAuthorizationController.performRequests()
           └─ Android: CredentialManager.createCredential()
           
PASO 4 ─── El usuario apoya el dedo en el sensor
           ┌─ Secure Enclave (iOS) / TEE (Android) genera par de claves
           ├─ Clave privada: NUNCA sale del dispositivo
           ├─ Clave pública + credential_id → enviados a bAuth
           └─ bAuth almacena en ath_binding + ath_mfa_enrollment
           
PASO 5 ─── bAuth emite el primer ctx_id
           ┌─ ctx_id: UUID v4 (sesión autenticada)
           ├─ dctx_id: UUID v4 (dispositivo vinculado)
           ├─ token JWT: {sub, ctx_id, tenant, empresa, sucursal, bitmask, loa}
           └─ almacenado en Secure Storage del celular
           
PASO 6 ─── El celular ahora ES la identidad del usuario
           No necesita password. No necesita token físico.
           Su huella en SU celular desbloquea todo.
```

**Tablas DDL involucradas en este flujo:**

| Paso | Tabla | Acción |
|:---:|-------|--------|
| 1-2 | `idn_user_template` | INSERT nuevo usuario |
| 3-4 | `ath_binding` | INSERT vínculo authenticator↔user (binding_method=self_service) |
| 4 | `ath_mfa_enrollment` | INSERT dispositivo MFA (mfa_type=passkey) |
| 5 | `ses_context` | INSERT ctx_id + dctx_id |
| 5 | `ath_recovery_method` | INSERT método de recuperación |
| 5 | `net_device` | INSERT/UPSERT dispositivo móvil |
| 5 | `idn_user_role` | INSERT asignación de roles |
| 6 | `geo_location_log` | INSERT ubicación del onboarding |
| Todo | `aud_event` | INSERT evento IDENTITY_CREATE |

### 2.2 Vida: Jornada diaria

```
┌──────────────────────────────────────────────────────────────────┐
│                     ESTADOS DEL ctx_id EN EL CELULAR              │
│                                                                   │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌─────────────┐ │
│  │ INACTIVO │───▶│ ACTIVO   │───▶│ EXTENDIDO│───▶│ DERIVADO    │ │
│  │ (fuera   │    │ (sesión  │    │ (QR      │    │ (ctx_id     │ │
│  │  horario)│    │ laboral) │    │ override)│    │ transferido │ │
│  └──────────┘    └──────────┘    └──────────┘    │ a desktop)  │ │
│       ▲               │               │          └──────┬──────┘ │
│       │               │               │                 │        │
│       └───────────────┴───────────────┴─────────────────┘        │
│                     Todos los estados son trazables               │
│                     en ses_context + ses_context_switch            │
└──────────────────────────────────────────────────────────────────┘
```

### 2.3 Muerte: Expiración y Revocación

| Evento | Disparador | Acción en el celular |
|--------|-----------|---------------------|
| **Fin de turno** | `cal_schedule.end_time` alcanzado | ctx_id → EXPIRADO. Token JWT invalidado. App muestra "sesión finalizada" |
| **Logout manual** | Usuario cierra sesión en la app | `bos.ctx.invalidate` → ctx_id → INVALIDADO. Secure Storage limpio |
| **Revocación admin** | Admin revoca acceso desde panel | Push notification → app borra ctx_id local. Próximo uso requiere re-autenticación |
| **Dispositivo comprometido** | `net_device.status = compromised` | CAEP event `device-compliance-change` → ctx_id revocado remotamente |
| **Viaje imposible** | `geo_check_velocity()` detecta >900 km/h | ctx_id → STEP_UP requerido. App solicita re-autenticación biométrica |
| **Delegación expirada** | `dlg_delegation.valid_until` alcanzado | Política temporal revocada. ctx_id vuelve a permisos base |

---

## 3. PROTOCOLOS DE TRANSMISIÓN DEL ctx_id

### 3.1 QR Code (CTAP 2.2 Hybrid Transport)

```
┌──────────────────┐                    ┌──────────────────┐
│   DISPOSITIVO A   │                    │   DISPOSITIVO B   │
│  (desktop/puerta) │                    │    (celular)      │
└────────┬─────────┘                    └────────┬─────────┘
         │                                       │
         │  1. Muestra QR                        │
         │  ┌──────────────────────┐             │
         │  │ {                    │             │
         │  │  "action":"ctx_xfer",│             │
         │  │  "device":"CPU-045", │             │
         │  │  "pos":"POS-23",     │             │
         │  │  "challenge":"0xA3", │             │
         │  │  "timestamp":"..."   │             │
         │  │ }                    │             │
         │  └──────────────────────┘             │
         │                                       │
         │        2. Escanea QR ─────────────────┤
         │                                       │
         │        3. Firma challenge ────────────┤
         │           (Passkey desbloqueada       │
         │            con huella/Face ID)        │
         │                                       │
         │  4. Recibe ctx_id ────────────────────┤
         │  ┌──────────────────────┐             │
         │  │ {                    │             │
         │  │  "ctx_id":"uuid",    │             │
         │  │  "user":"juan",      │             │
         │  │  "bitmask":"0x...",  │             │
         │  │  "ttl":28800         │             │
         │  │ }                    │             │
         │  └──────────────────────┘             │
         │                                       │
    ┌────┴────┐                            ┌────┴────┐
    │ Sesión  │                            │ ctx_id  │
    │ abierta │                            │ intacto │
    └─────────┘                            └─────────┘
```

**Formato del QR de transferencia de contexto (SBOS):**

```json
{
  "v": 1,
  "action": "ctx_transfer",
  "device_id": "CPU-045",
  "pos_logico": "POS-23",
  "tenant": "skull",
  "empresa": "acme",
  "sucursal": "central",
  "challenge": "base64url_random_32_bytes",
  "timestamp": "2026-06-24T14:30:00Z",
  "ttl_seconds": 120
}
```

**Seguridad del QR:**
- Challenge aleatorio de 32 bytes (anti-replay)
- TTL de 120 segundos (QR visible solo 2 minutos)
- El celular firma el challenge con su Passkey antes de enviar
- bhnexus valida: firma, TTL, device_id conocido, challenge no reutilizado

### 3.2 NFC (Near Field Communication)

```
CELULAR ──────── NFC (13.56 MHz) ──────── LECTOR OSDP
   │                                            │
   │  1. NDEF message:                          │
   │     {ctx_id, challenge_signed, timestamp}  │
   │                                            │
   │  2. Lector envía a bhnexus ────────────────┤
   │                                            │
   │  3. bhnexus → bAuth: validate(ctx_id)      │
   │                                            │
   │  4. bAuth → bhnexus: ALLOW/DENY ───────────┤
   │                                            │
   │                                     ┌──────┴──────┐
   │                                     │ Puerta abre │
   │                                     │ o no abre   │
   └─────────────────────────────────────┤ dependiendo │
                                         │ del ctx_id  │
                                         └─────────────┘
```

**Ventajas de NFC sobre QR para acceso físico:**
- No requiere cámara (útil en oscuridad o lluvia)
- Más rápido: <500ms vs 1-2s del QR
- Android 16 (2026) ya soporta CTAP2 sobre NFC con PIN
- Funciona con el celular bloqueado (modo "solo lectura" del ctx_id)
- Alcance corto (4cm) = seguridad física inherente

### 3.3 WebSocket mTLS (App ↔ bhnexus)

La app SBOS Authenticator mantiene una conexión WebSocket persistente con bhnexus.
Es el canal principal para:

| Operación | Dirección | Frecuencia |
|-----------|-----------|------------|
| Heartbeat del ctx_id | Celular → bhnexus | Cada 30s |
| Notificaciones push | bhnexus → Celular | Event-driven |
| Renovación de token JWT | Celular → bhnexus | Cada 55min (5min antes de expirar) |
| Actualización de BitMask | bhnexus → Celular | On role/policy change |
| Comando de revocación | bhnexus → Celular | On admin action |
| Sincronización de políticas temporales | Bidireccional | On delegation/override |

---

## 4. EL CELULAR COMO PROVEEDOR DE IDENTIDAD (IdP)

### 4.1 Passkeys: El estándar que lo hace posible

| Concepto | Cómo lo usa SBOS |
|----------|-----------------|
| **Passkey = par de claves** | Clave privada en Secure Enclave/TEE del celular. Clave pública en `ath_binding` |
| **User Verification (UV)** | Huella, Face ID, PIN del celular = verificación biométrica sin enviar datos biométricos |
| **Phishing-resistant** | La clave privada está vinculada al dominio (sbos.app). No funciona en sitios falsos |
| **Device-bound vs Synced** | SBOS soporta ambos: synced (AAL2) para empleados, device-bound (AAL3) para admin/SU |
| **Cross-device (hybrid)** | CTAP 2.2: QR + BLE permite usar el celular para autenticarse en desktop/puerta/TV |

### 4.2 El celular como Identity Provider para aplicaciones externas

```
┌──────────────────────────────────────────────────────────────┐
│              APLICACIÓN EXTERNA (tercero)                     │
│  Ej: portal de facturas de ACME, app de delivery, banca      │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ OIDC / SAML / OAuth 2.1
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                        bAuth (IdP)                            │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ idp_client: cliente registrado (client_id, redirect_uri) │ │
│  │ idp_client_policy: requiere Passkey AAL2, token TTL 1h  │ │
│  │ idp_token_config: JWT con claims: sub, ctx_id, empresa  │ │
│  └─────────────────────────────────────────────────────────┘ │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ WebSocket mTLS
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                    CELULAR DEL USUARIO                        │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ App externa redirige al navegador del celular           │ │
│  │ → WebAuthn conditional UI muestra "Iniciar sesión con   │ │
│  │   SBOS"                                                 │ │
│  │ → Usuario autentica con huella (Passkey)                │ │
│  │ → bAuth emite token JWT para la app externa             │ │
│  │ → La app externa NUNCA ve la huella, NUNCA ve el        │ │
│  │   password, NUNCA accede a la BD de bAuth               │ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## 5. IMPACTO EN LA DDL: NUEVAS TABLAS REQUERIDAS

La capacidad del celular como Identity Hub requiere las siguientes tablas
adicionales que NO están en el inventario actual:

### 5.1 Registro de dispositivos móviles vinculados

```sql
-- T-700: Dispositivos móviles vinculados al usuario
-- Un usuario puede tener N dispositivos (celular personal, celular trabajo, tablet)
CREATE TABLE bauth.user_mobile_device (
    device_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    user_uuid       UUID NOT NULL REFERENCES bauth.idn_user_template(uuid),
    net_device_id   UUID REFERENCES bauth.net_device(device_id),
    platform        TEXT NOT NULL,           -- 'ios' | 'android'
    device_name     TEXT,                    -- 'iPhone 15 Pro'
    os_version      TEXT,                    -- '18.3'
    app_version     TEXT,                    -- '1.2.3'
    passkey_type    TEXT NOT NULL,           -- 'device_bound' | 'synced_icloud' | 'synced_google'
    aaguid          TEXT,                    -- FIDO2 Authenticator Attestation GUID
    is_primary      BOOLEAN DEFAULT false,   -- Dispositivo principal del usuario
    last_seen_at    TIMESTAMPTZ,
    trust_score     INTEGER DEFAULT 100,     -- 0-100, disminuye con anomalías
    status          TEXT DEFAULT 'ACTIVE',   -- ACTIVE | COMPROMISED | LOST | DECOMMISSIONED
    metadata        JSONB DEFAULT '{}',      -- modelo, IMEI hash, carrier, etc.
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_uuid, net_device_id)
);
```

### 5.2 Historial de transferencias de contexto (QR/NFC)

```sql
-- T-701: Registro de cada transferencia de ctx_id entre dispositivos
CREATE TABLE bauth.ctx_transfer_log (
    transfer_id     UUID PRIMARY KEY DEFAULT uuidv7(),
    from_device_id  UUID NOT NULL,           -- dispositivo origen (celular)
    to_device_id    TEXT NOT NULL,           -- dispositivo destino ('CPU-045', 'DOOR-12')
    ctx_id          TEXT NOT NULL,
    transfer_method TEXT NOT NULL,           -- 'QR' | 'NFC' | 'BLE' | 'WEBSOCKET'
    challenge       TEXT NOT NULL,           -- challenge que firmó el celular
    signature       TEXT NOT NULL,           -- firma del celular sobre el challenge
    ttl_seconds     INTEGER DEFAULT 300,     -- TTL del ctx_id transferido
    result          TEXT NOT NULL,           -- 'ALLOW' | 'DENY'
    den y_reason    TEXT,
    source_ip       INET,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ctl_ctx ON bauth.ctx_transfer_log(ctx_id, created_at DESC);
```

### 5.3 Aplicaciones externas registradas (bAuth como IdP)

```sql
-- T-702: Aplicaciones externas que usan bAuth como Identity Provider
CREATE TABLE bauth.idp_client (
    client_id           UUID PRIMARY KEY DEFAULT uuidv7(),
    client_name         TEXT NOT NULL,
    client_type         TEXT NOT NULL,        -- 'oidc' | 'saml' | 'oauth2'
    tenant_id           UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    redirect_uris       TEXT[] NOT NULL,
    allowed_scopes      TEXT[] DEFAULT '{openid,profile,email}',
    token_endpoint      TEXT,
    client_secret_hash  BYTEA,
    grant_types         TEXT[] DEFAULT '{authorization_code,refresh_token}',
    require_pkce        BOOLEAN DEFAULT true,
    require_dpop        BOOLEAN DEFAULT false,
    logo_url            TEXT,
    tos_url             TEXT,
    policy_url          TEXT,
    is_active           BOOLEAN DEFAULT true,
    ctx_id              TEXT NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, client_name)
);
```

### 5.4 Políticas de autenticación por cliente externo

```sql
-- T-703: Qué métodos de autenticación requiere cada app externa
CREATE TABLE bauth.idp_client_policy (
    policy_id           UUID PRIMARY KEY DEFAULT uuidv7(),
    client_id           UUID NOT NULL REFERENCES bauth.idp_client(client_id),
    min_aal             INTEGER DEFAULT 2,
    allowed_methods     TEXT[] DEFAULT '{WEBAUTHN_PWDLESS,PASSKEY_DEVICE}',
    require_biometric   BOOLEAN DEFAULT true,
    allow_synced_passkeys BOOLEAN DEFAULT true,
    max_session_seconds INTEGER DEFAULT 3600,
    token_type          TEXT DEFAULT 'JWT',
    refresh_token_ttl   INTEGER DEFAULT 86400,
    require_consent     BOOLEAN DEFAULT true,
    consent_prompt_text JSONB DEFAULT '{}',
    is_active           BOOLEAN DEFAULT true,
    ctx_id              TEXT NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (client_id)
);
```

### 5.5 Configuración de emisión de tokens

```sql
-- T-704: Configuración de tokens JWT emitidos a apps externas
CREATE TABLE bauth.idp_token_config (
    config_id           UUID PRIMARY KEY DEFAULT uuidv7(),
    client_id           UUID NOT NULL REFERENCES bauth.idp_client(client_id),
    signing_algorithm   TEXT DEFAULT 'EdDSA',
    include_claims      TEXT[] DEFAULT '{sub,iss,aud,exp,iat,ctx_id,tenant,empresa}',
    custom_claims       JSONB DEFAULT '{}',
    jwt_ttl_seconds     INTEGER DEFAULT 3600,
    opaque_token        BOOLEAN DEFAULT false,
    sender_constrained  BOOLEAN DEFAULT false,
    dpop_required       BOOLEAN DEFAULT false,
    is_active           BOOLEAN DEFAULT true,
    ctx_id              TEXT NOT NULL DEFAULT 'system',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (client_id)
);
```

---

## 6. RESUMEN: IMPACTO EN EL INVENTARIO

| Código | Nueva tabla | Dominio | Propósito | Prioridad |
|--------|------------|---------|-----------|:---:|
| **T-700** | `bauth.user_mobile_device` | D5/D7 | Dispositivos móviles vinculados al usuario. Passkey type, trust score, platform | 🔴 |
| **T-701** | `bauth.ctx_transfer_log` | D8 | Historial de transferencias de contexto (QR, NFC, BLE, WebSocket) | 🔴 |
| **T-702** | `bauth.idp_client` | D5/D9 | Aplicaciones externas registradas como OIDC/SAML/OAuth2 clients | 🔴 |
| **T-703** | `bauth.idp_client_policy` | D5/D9 | Políticas de autenticación por cliente externo (métodos biométricos requeridos) | 🟠 |
| **T-704** | `bauth.idp_token_config` | D5/D9 | Configuración de emisión de tokens JWT para apps externas | 🟠 |

**Total: 5 tablas nuevas.** Todas habilitan la visión del celular como Identity Hub.

---

## 7. PRINCIPIOS DE DISEÑO MÓVIL

| # | Principio | Significado |
|---|-----------|-------------|
| **P1** | La biometría NUNCA sale del dispositivo | Solo viaja la firma criptográfica. GDPR Art.9. ISO 27001 A.8.15 |
| **P2** | Un solo registro biométrico para todo | El usuario registra su huella UNA VEZ en su celular. Sirve para apps, puertas, cajas |
| **P3** | QR como transporte universal de contexto | Funciona en cualquier dispositivo con pantalla y cámara. Sin hardware especial |
| **P4** | NFC para acceso físico rápido | <500ms, funciona con celular bloqueado, no requiere cámara |
| **P5** | Passkeys: device-bound (AAL3) y synced (AAL2) | Admin/SU requieren device-bound. Empleados pueden usar synced |
| **P6** | Token JWT renovable sin re-autenticación | El celular renueva el token cada 55min usando refresh_token. Sin molestar al usuario |
| **P7** | Revocación remota instantánea | Si el dispositivo se reporta como perdido/robado, todos los ctx_id derivados se invalidan |
| **P8** | Offline resilient | El celular cachea el ctx_id y puede operar sin conexión por períodos cortos (TTL máximo: 30min sin heartbeat) |

---

---

## PARTE 4 — ARQUITECTURA TÉCNICA: El Celular ↔ bAuth

### 4.1 Stack Tecnológico del SBOS Authenticator

| Capa | Tecnología | Propósito |
|------|-----------|----------|
| **Framework** | Flutter 3.x + Dart | App cross-platform (iOS + Android) desde un solo código |
| **Estado** | Riverpod | Gestión de estado reactiva con dependency injection |
| **HTTP** | Dio | Llamadas REST con interceptors para token refresh automático |
| **WebSocket** | web_socket_channel | Conexión persistente con bhnexus (mTLS). Heartbeat cada 30s |
| **Secure Storage** | flutter_secure_storage | Token JWT, ctx_id, refresh_token. iOS: Keychain + Secure Enclave. Android: EncryptedSharedPreferences + Keystore |
| **Passkeys** | flutter_passkey_service | FIDO2/WebAuthn. iOS 16+ (Face ID/Touch ID), Android 9+ (huella/face/PIN). PRF extension para derivación de claves |
| **Biometría** | local_auth | Face ID, Touch ID, huella dactilar. biometricOnly=true (sin PIN/pattern) |
| **QR Scanner** | mobile_scanner | Escaneo de QR para onboarding, transferencia de ctx_id, acceso físico |
| **NFC** | flutter_nfc_kit | Lectura/escritura NDEF. CTAP2 sobre NFC para acceso físico |
| **Push** | Firebase Cloud Messaging + APNs | Notificaciones push: overrides, revocaciones, alertas |
| **Attestation** | Android Play Integrity + iOS App Attest | Verificación de integridad del dispositivo y la app |

### 4.2 Flujo Técnico de Comunicación

```
┌──────────────────────────────────────────────────────────────────┐
│                    SBOS AUTHENTICATOR (Flutter)                   │
│                                                                   │
│  ┌──────────────────────┐        ┌─────────────────────────────┐ │
│  │ Secure Storage        │        │ Dio HTTP Client             │ │
│  │ ┌──────────────────┐  │        │ ┌─────────────────────────┐ │ │
│  │ │ access_token JWT │  │        │ │ AuthInterceptor:        │ │ │
│  │ │ refresh_token     │  │        │ │ - Inyecta Bearer token  │ │ │
│  │ │ ctx_id            │  │        │ │ - 401 → refresh → retry│ │ │
│  │ │ device_id         │  │        │ │ - Certificate pinning   │ │ │
│  │ │ bitmask_hex       │  │        │ └─────────────────────────┘ │ │
│  │ └──────────────────┘  │        └─────────────────────────────┘ │
│  └──────────────────────┘                                         │
│                                                                   │
│  ┌──────────────────────┐        ┌─────────────────────────────┐ │
│  │ WebSocket Manager     │        │ Passkey Manager              │ │
│  │ ┌──────────────────┐  │        │ ┌─────────────────────────┐ │ │
│  │ │ ws://bhnexus:9444│  │        │ │ flutter_passkey_service  │ │ │
│  │ │ Heartbeat: 30s   │  │        │ │ • register(credential)   │ │ │
│  │ │ Reconnect: exp   │  │        │ │ • authenticate(challenge)│ │ │
│  │ │ Subscribe:       │  │        │ │ • PRF key derivation     │ │ │
│  │ │  /user/queue/ctx │  │        │ │ • Large Blob storage     │ │ │
│  │ └──────────────────┘  │        │ └─────────────────────────┘ │ │
│  └──────────────────────┘        └─────────────────────────────┘ │
│                                                                   │
│  ┌──────────────────────┐        ┌─────────────────────────────┐ │
│  │ Attestation Provider  │        │ Push Receiver                │ │
│  │ ┌──────────────────┐  │        │ ┌─────────────────────────┐ │ │
│  │ │ Android:          │  │        │ │ FCM + APNs               │ │
│  │ │ Play Integrity    │  │        │ │ • emergency_override     │ │
│  │ │ iOS: App Attest   │  │        │ │ • delegation_received    │ │
│  │ │ → envía proof a   │  │        │ │ • session_revoked        │ │
│  │ │   bAuth para      │  │        │ │ • device_compromised     │ │
│  │ │   verificación    │  │        │ └─────────────────────────┘ │ │
│  │ └──────────────────┘  │        └─────────────────────────────┘ │
│  └──────────────────────┘                                         │
└──────────────────────────────────────────────────────────────────┘
```

### 4.3 Ciclo de Vida del Token en el Celular

```
ACCESO INICIAL (Onboarding)
──────────────────────────
1. App escanea QR de onboarding → recibe challenge
2. App solicita registro de Passkey (flutter_passkey_service.register)
3. Usuario autentica con huella/Face ID → se genera par de claves
4. Clave pública + credential_id → POST /bauth/onboard
5. bAuth responde: {access_token, refresh_token, ctx_id, expires_in}
6. Almacenado en flutter_secure_storage con protección biométrica

USO DIARIO
──────────
1. App abre → local_auth.authenticate(biometricOnly: true)
2. Si OK → lee access_token de secure storage
3. Dio AuthInterceptor inyecta Bearer token en cada request
4. WebSocket conecta con token → subscribe /user/queue/ctx

RENOVACIÓN (cada 55 min)
────────────────────────
1. Dio recibe 401 → AuthInterceptor captura
2. Lee refresh_token de secure storage (con biométrico)
3. POST /bauth/token/refresh {refresh_token}
4. bAuth responde: {nuevo access_token, nuevo refresh_token}
5. Almacena ambos. Reintenta request original.
6. Si refresh también falla → force logout, borrar storage

REVOCACIÓN (push)
─────────────────
1. Admin revoca acceso → bAuth emite push notification
2. Push Receiver captura → tipo: "session_revoked"
3. App borra todo de secure storage
4. Muestra pantalla de login
```

### 4.4 Device Attestation — Verificación de Integridad

Antes de aceptar cualquier operación desde el celular, bAuth DEBE verificar
que el dispositivo y la app no han sido comprometidos:

| Plataforma | Servicio | Qué verifica | Cómo |
|-----------|---------|-------------|------|
| **Android** | Play Integrity API | Bootloader bloqueado, firmware certificado, app firmada por Play Store, sin root detectable | App envía integrity token → bAuth lo verifica contra Google Play |
| **iOS** | App Attest | App binaria no modificada, Team ID + Bundle ID verificados por Secure Enclave, distribuida por App Store | App genera attestation → bAuth verifica cadena X.509 contra Apple |

**Política de Trust Score del dispositivo:**

```json
{
  "base_score": 100,
  "checks": {
    "play_integrity_device": {"weight": 30, "required": true},
    "play_integrity_app": {"weight": 25, "required": true},
    "app_attest": {"weight": 25, "required": true},
    "no_root_jailbreak": {"weight": 10, "required": true},
    "os_version_min": {"weight": 5, "required": false, "min_android": 28, "min_ios": 16},
    "app_version_min": {"weight": 5, "required": false, "min": "1.0.0"}
  }
}
```

Si el score baja del threshold → el dispositivo se marca como `compromised`
y todos los ctx_id derivados se invalidan automáticamente.

---

## PARTE 5 — EXTENSIÓN A DESKTOP: Windows, macOS, Linux

### 5.1 El mismo concepto, distinto hardware

La arquitectura del celular como Identity Hub NO es exclusiva del teléfono. Windows,
macOS y Linux tienen las mismas capacidades: sensores biométricos (huella, rostro),
almacenamiento seguro (TPM, Secure Enclave), y soporte nativo para WebAuthn/FIDO2.

| Plataforma | Platform Authenticator | Secure Storage | Biometría disponible |
|-----------|----------------------|----------------|---------------------|
| **Windows 10/11** | Windows Hello (TPM 2.0) | TPM + Credential Manager | Huella, reconocimiento facial (IR), PIN |
| **macOS 13+** | Touch ID + Secure Enclave | Keychain + Secure Enclave | Huella (Touch ID), rostro (Face ID en Apple Silicon) |
| **Linux** | FIDO2 hardware tokens | Kernel Keyring + TPM | YubiKey, Nitrokey, SoloKey (USB/NFC) |
| **ChromeOS** | Google Password Manager + TPM | TPM + Chrome Sync | Huella en Chromebooks premium |

**La diferencia con el celular es mínima:**

```
CELULAR                          DESKTOP / LAPTOP
────────                         ─────────────────
Huella en pantalla               Huella en lector USB o teclado
Face ID (TrueDepth)              Windows Hello IR camera
Secure Enclave (iOS)             TPM 2.0 (Windows)
Keystore (Android)               Secure Enclave (macOS)
flutter_secure_storage           Misma librería (soporta macOS/Windows)
flutter_passkey_service          Misma librería (soporta iOS/Android/Web)
QR Scanner (cámara trasera)      QR se MUESTRA en pantalla (el desktop recibe ctx_id)
NFC (transmisor)                 NFC vía lector USB (recibe ctx_id del celular)
```

### 5.2 El desktop como RECEPTOR de ctx_id

El caso de uso más común para desktop es RECIBIR el ctx_id desde el celular:

```
1. El desktop muestra un QR en la pantalla de login.
2. El usuario escanea el QR con su celular (igual que en Momento 3).
3. El celular envía el ctx_id a bAuth → bAuth lo transmite al desktop.
4. El desktop ahora tiene la sesión del usuario.
5. Windows Hello / Touch ID en el desktop se usa SOLO para desbloquear
   la pantalla, no para autenticar — la autenticación ya la hizo el celular.
```

### 5.3 El desktop como GENERADOR de ctx_id

El desktop también puede generar su PROPIO ctx_id, igual que el celular:

```
1. El usuario abre SBOS Desktop Authenticator.
2. Registra su Passkey usando Windows Hello (huella/rostro) o Touch ID.
3. bAuth emite un ctx_id para el desktop.
4. El ctx_id se almacena en TPM (Windows) o Secure Enclave (macOS).
5. El desktop ahora ES una llave universal, igual que el celular.
6. Puede transferir su ctx_id a otros dispositivos vía QR (el desktop muestra QR).
```

### 5.4 Diferencias que SÍ importan en DDL

| Aspecto | Impacto en DDL |
|--------|---------------|
| `user_mobile_device` → renombrar a `user_client_device` | Cambiar nombre de tabla para reflejar que no es solo móvil |
| Agregar columna `device_category` | 'MOBILE' (celular/tablet), 'DESKTOP' (laptop/PC), 'IOT' (sensor/actuador), 'WEARABLE' (reloj/lentes) |
| Agregar columna `platform_authenticator` | 'WINDOWS_HELLO', 'TOUCH_ID', 'APPLE_FACE_ID', 'ANDROID_BIOMETRIC', 'SECURITY_KEY', 'TPM', 'NONE' |
| Agregar columna `tpm_version` | '1.2', '2.0', null — para requerir TPM mínimo en políticas de seguridad |
| Agregar columna `secure_enclave_available` | BOOLEAN — ¿tiene hardware de seguridad dedicado? |

### 5.5 Stack técnico desktop

| Plataforma | App | Framework | Passkey API |
|-----------|-----|-----------|------------|
| **Windows** | SBOS Desktop (WinUI 3 o Flutter Windows) | Flutter Windows | WebAuthn en Edge/WebView2 |
| **macOS** | SBOS Desktop (Flutter macOS) | Flutter macOS | ASAuthorization (nativo) o WebAuthn en Safari |
| **Linux** | SBOS Desktop (Flutter Linux) | Flutter Linux | Hardware tokens vía `libfido2` o WebAuthn en Chrome |

### 5.6 Casos de uso extendidos

| Caso | Desktop actúa como | Flujo |
|------|-------------------|-------|
| Oficina | RECEPTOR | Desktop muestra QR → celular escanea → desktop recibe ctx_id |
| Home office | GENERADOR | Desktop con Windows Hello → genera su propio ctx_id → accede a apps |
| Call center | RECEPTOR (kiosko) | Desktop compartido → cada operador escanea su QR → ctx_id temporal |
| Laboratorio | GENERADOR (aislado) | Desktop sin cámara → genera ctx_id con YubiKey → accede sin celular |
| Data center | RECEPTOR (break-glass) | Desktop seguro → supervisor escanea QR de emergencia → override temporal |

---

## PARTE 6 — NUEVAS TABLAS DDL (Investigación Técnica)

La investigación de la arquitectura móvil reveló **5 tablas adicionales**
que no estaban en el inventario original:

| Código | Tabla | Dominio | Propósito |
|--------|-------|---------|-----------|
| **T-710** | `bauth.mobile_app_config` | D5 | Configuración remota de la app: versión mínima, endpoints, certificate pins, feature flags |
| **T-711** | `bauth.device_attestation_log` | D5/D7 | Registro de cada verificación de integridad: Play Integrity / App Attest. Token + resultado + score |
| **T-712** | `bauth.push_token_registry` | D5 | Tokens FCM/APNs por dispositivo. Un dispositivo → N tokens (uno por app/tenant) |
| **T-713** | `bauth.certificate_pin_config` | D7 | Public Key Pins para la app móvil. SHA-256 de la clave pública del servidor |
| **T-714** | `bauth.token_refresh_log` | D5/D9 | Auditoría de cada refresh de token: dispositivo, IP, timestamp, resultado |

### Columnas adicionales en tablas existentes

| Tabla | Nueva columna | Tipo | Propósito |
|-------|-------------|------|-----------|
| `user_mobile_device` | `attestation_provider` | TEXT | 'play_integrity' / 'app_attest' / 'none' |
| `user_mobile_device` | `last_attestation_at` | TIMESTAMPTZ | Última verificación de integridad exitosa |
| `user_mobile_device` | `app_version` | TEXT | Versión de la app instalada |
| `user_mobile_device` | `push_token_hash` | BYTEA | Hash SHA-256 del token FCM/APNs |
| `net_device` | `attestation_score` | INTEGER | Score de integridad 0-100 |
| `net_device` | `jailbreak_detected` | BOOLEAN | true si se detectó root/jailbreak |
| `ses_context` | `mobile_device_id` | UUID | FK → user_mobile_device. Vincula sesión al celular |

---

### Resumen final de tablas de la visión

| Lote | Cantidad | Códigos |
|------|:---:|------|
| Original visión (Parte 3) | 5 | T-700 a T-704 |
| Emergencia + visitantes (Momentos 8-10) | 5 | T-705 a T-709 |
| Arquitectura técnica (Parte 4) | 5 | T-710 a T-714 |
| **Total nuevas tablas visión** | **15** | |
| Columnas nuevas en tablas existentes | 7 | 3 tablas afectadas |

---

*Documento unificado generado 2026-06-24.*
*Parte 1: Visión estratégica. Parte 2: 10 momentos reales. Parte 3: Celular como Identity Hub.*
*Parte 4: Arquitectura técnica Flutter↔bAuth. Parte 5: Extensión a Windows/macOS/Linux.*
*Parte 6: Impacto total en DDL — 15 tablas nuevas + 5 columnas adicionales.*
*El ctx_id vive en el celular. El celular es la llave. Todo lo demás es periférico.*
