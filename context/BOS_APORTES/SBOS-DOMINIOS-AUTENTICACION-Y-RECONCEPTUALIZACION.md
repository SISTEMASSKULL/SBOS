# SBOS — Dominios de Autenticación y Reconceptualización del Modelo BitMask
## SKULL · SBOS · Abril 2026 · v1.1
### Arquitecto: Principal Systems Architect

---

## PARTE 1: DEFINICIÓN DE DOMINIOS DE AUTENTICACIÓN
### Marco de referencia: NIST SP 800-63 · ISO/IEC 27001:2022 · ISO/IEC 24760 · IEEE 802.1X · FIDO2

Esta sección establece el marco conceptual de dominios de autenticación reconocidos por estándares internacionales. El SBOS opera actualmente con tres dominios implícitos (Lógico, Físico, Financiero). Este capítulo los formaliza y añade los dominios adicionales que el modelo requiere para escalar.

---

### 1.1 DOMINIO LÓGICO

**Definición canónica:** Cubre la autenticación mediante credenciales digitales — identificadores de usuario, contraseñas, tokens OTP, llaves criptográficas — y los sistemas de gestión de identidades y accesos (IAM) que las administran.

**Estándar de referencia:** NIST SP 800-63B (Authenticator Assurance Levels), ISO/IEC 24760-1 (Identity Management Framework).

**En el SBOS:** Implementado parcialmente mediante Keycloak (IdP), el claim `bos_domains.logical.apps` en el JWT, y la `BitmaskBundle.ERPMask` para permisos de aplicaciones de negocio.

**Nivel de garantía requerido:** AAL2 mínimo (autenticación multifactor) para acceso a módulos sensibles (Contabilidad, Nómina, Aprobaciones).

**Evaluador actual:** `trytond-auth-keycloak` (Tryton), Keycloak SSO.

**GAP identificado:** El dominio lógico no tiene un evaluador unificado para las 110+ aplicaciones del ecosistema (Saleor, EspoCRM, Zammad, OrangeHRM, Paperless, Superset). Solo Tryton tiene evaluador propio. Este es el GAP arquitectónico más crítico.

---

### 1.2 DOMINIO FÍSICO

**Definición canónica:** Controla el acceso a instalaciones, dispositivos de hardware y actuadores físicos — puertas, relés, cajones de dinero, lectores biométricos — mediante credenciales presenciales (tarjetas RFID, PINs físicos, huella dactilar).

**Estándar de referencia:** ISO/IEC 27001:2022 Anexo A.7 (Physical and Environmental Security), NIST SP 800-116 (PIV para control de acceso físico).

**En el SBOS:** Implementado mediante `banexus` (edge sentinel en Fedora KDE) y la `BitmaskBundle.VDIMask`. Las zonas físicas (`ZONE-VENTAS`, `ZONE-ALMACEN`, puertas, relés) son el vocabulario nativo de este dominio.

**Evaluador actual:** `banexus`.

**Nota arquitectónica:** Las "zonas" como concepto son nativas del dominio físico. La pregunta de diseño abierta es si este vocabulario de zonas debe unificarse con el dominio lógico bajo un término común, o si cada dominio mantiene su vocabulario propio.

---

### 1.3 DOMINIO FINANCIERO

**Definición canónica:** Regula la autenticación y autorización para operaciones económicas — transacciones, límites de monto, aprobaciones de pago, segregación de funciones contables — con requisitos de auditoría inmutable y trazabilidad completa.

**Estándar de referencia:** PCI-DSS v4.0 (pagos con tarjeta), ISO 27001 A.5.3 (Segregation of Duties), NIST SP 800-53 AC-5 (Separation of Duties), ISACA COBIT 2019 (control financiero).

**En el SBOS:** Parcialmente cubierto por la `BitmaskBundle.ERPMask` (PERM_EDIT, PERM_DELETE, PERM_ARCHIVE) y las Button Rules de Tryton. Sin embargo, **el dominio financiero no tiene su propia máscara dedicada** en ninguno de los dos diseños actuales — ni en el SAM-128 ni en el plan corregido.

**GAP identificado:** Los límites de transacción (ej.: monto máximo que puede aprobar un rol), las reglas de "4 ojos" (aprobación dual), y el control de SoD financiero no tienen representación en el BitMask actual. Están embebidos en la lógica de Tryton, no en el modelo de autorización de bAuth.

**Evaluador actual:** Tryton Button Rules (enforcement), bAuth Conflict Matrix (prevención en asignación).

---

### 1.4 DOMINIO DE RED

**Definición canónica:** Autentica y autoriza el acceso a la infraestructura de red antes de que cualquier servicio o aplicación sea accesible. Opera en la capa 2/3 del modelo OSI, controlando quién puede conectarse a qué segmento de red.

**Estándar de referencia:** IEEE 802.1X (Port-Based Network Access Control), EAP (Extensible Authentication Protocol), RADIUS (RFC 2865), DIAMETER (RFC 6733).

**En el SBOS:** Implementado implícitamente mediante la segregación de VLANs por empresa (multi-tenant) y VPN corporativa. Los bits `NETWORK_EXTERNAL` (Bit 11 VDI) y `VPN_ACCESS` (Bit 12 VDI) son representaciones de permisos de red dentro de la VDIMask.

**Evaluador actual:** Infraestructura de red (switches, firewall). No hay evaluador de bAuth en esta capa actualmente.

---

### 1.5 DOMINIO DE APLICACIÓN

**Definición canónica:** Gestiona la autenticación y autorización dentro de aplicaciones específicas, independientemente del mecanismo de red o físico. Opera sobre protocolos estándar de identidad federada.

**Estándar de referencia:** OAuth 2.0 (RFC 6749), OpenID Connect 1.0 (OIDC), SAML 2.0, ISO/IEC 29146 (Access Management Framework).

**En el SBOS:** Keycloak actúa como IdP para este dominio vía OIDC/SAML. El claim `bos_domains.logical.apps` en el JWT lista las aplicaciones autorizadas. La `ERPMask` es el mecanismo de permisos granulares dentro de Tryton.

**Distinción importante:** El dominio de aplicación es transversal — cada aplicación (Tryton, Saleor, OrangeHRM, Superset) tiene su propio subespacio de permisos. El modelo actual colapsa todos estos en una sola `ERPMask`, lo que es el error conceptual central identificado en el análisis.

---

### 1.6 DOMINIO BIOMÉTRICO

**Definición canónica:** Autenticación basada en características físicas o conductuales del individuo — huella dactilar, iris, geometría facial, voz. No es un dominio independiente sino una capa de factor de autenticación que puede aplicarse en cualquiera de los dominios anteriores.

**Estándar de referencia:** ISO/IEC 30107-3 (Biometric Presentation Attack Detection), ISO/IEC 2382-37 (False Match Rate — FMR), FIDO2/WebAuthn (W3C), NIST SP 800-63B §5.2.3.

**En el SBOS:** Aplicable en el dominio físico (lectores biométricos en puertas) y en el dominio lógico (autenticación en VDI). La norma NIST SP 800-63B exige FMR ≤ 1 en 10.000 y la disponibilidad obligatoria de un mecanismo alternativo no biométrico.

---

### 1.7 DOMINIO FEDERADO / IDENTIDAD DIGITAL

**Definición canónica:** Permite que una identidad autenticada en un sistema sea reconocida y aceptada en otro sistema diferente, sin que el usuario necesite reautenticarse. Implementa Single Sign-On (SSO) entre organizaciones o entre dominios internos.

**Estándar de referencia:** NIST SP 800-63C (Federation and Assertions), OAuth 2.0, OIDC, SAML 2.0, eIDAS (Reglamento UE 910/2014).

**En el SBOS:** Keycloak implementa la federación entre el tenant SBOS y las aplicaciones del ecosistema. El JWT con los claims `bos_*` es el assertion federado que transporta la identidad y los permisos entre servicios.

---

### 1.8 DOMINIO ORGANIZACIONAL / DE PERSONAS

**Definición canónica:** Cubre los controles relacionados con el factor humano en la autenticación — políticas de contraseñas, roles y responsabilidades, capacitación, procesos de incorporación/baja de empleados, y responsabilidad individual por las credenciales.

**Estándar de referencia:** ISO/IEC 27001:2022 Controles de Personas (Annexo A, Sección 6), NIST SP 800-53 PS (Personnel Security).

**En el SBOS:** Implementado mediante el `RolTemplate` (022-IDENTITY-CONTRACTS), los procesos de onboarding/offboarding, y las políticas documentadas en `010-GOVERNANCE`.

---

### 1.9 DOMINIO NORMATIVO / DE CUMPLIMIENTO

**Definición canónica:** Engloba los requisitos de autenticación impuestos por marcos regulatorios externos — RGPD, eIDAS, HIPAA, SOX, PCI-DSS — que la organización está obligada a cumplir independientemente de sus decisiones de diseño internas.

**Estándar de referencia:** RGPD (Reglamento UE 2016/679), eIDAS (Reglamento UE 910/2014), HIPAA (45 CFR Part 164), SOX §404, PCI-DSS v4.0.

**En el SBOS:** Los logs de auditoría inmutables (ISO 27001 A.8.15), la Conflict Matrix de SoD (ISO 27001 A.5.3, NIST AC-5), y el `AssumeTenantContext` con registro son implementaciones de este dominio.

---

### 1.10 TABLA RESUMEN: DOMINIOS Y SU ESTADO EN EL SBOS

| Dominio | Estándar principal | Estado en SBOS | Evaluador | Prioridad de formalización |
|---|---|---|---|---|
| **Lógico** | NIST SP 800-63B, ISO/IEC 24760 | Parcial | Keycloak + ERPMask | CRÍTICO |
| **Físico** | ISO/IEC 27001 A.7, NIST SP 800-116 | Implementado | banexus + VDIMask | ✅ OK |
| **Financiero** | PCI-DSS, ISO 27001 A.5.3, NIST AC-5 | Sin máscara propia | Tryton Button Rules | ALTO |
| **De red** | IEEE 802.1X, RFC 2865 | Implícito en VDIMask | Infraestructura | MEDIO |
| **De aplicación** | OAuth 2.0, OIDC, ISO/IEC 29146 | Parcial (solo Tryton) | trytond-auth-keycloak | CRÍTICO |
| **Biométrico** | ISO/IEC 30107, FIDO2 | No implementado | N/A | BAJO (futuro) |
| **Federado** | NIST SP 800-63C, eIDAS | Implementado | Keycloak JWT | ✅ OK |
| **Organizacional** | ISO 27001 A.6, NIST PS | Parcial | RolTemplate | MEDIO |
| **Normativo** | RGPD, SOX, PCI-DSS | Parcial (audit log) | bauth_db + Wazuh | ALTO |

---

## PARTE 2: ANÁLISIS CRÍTICO Y RESPUESTAS A LAS CINCO PREGUNTAS

### Contexto del análisis

El documento `SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md` (v1.0) corrige correctamente los errores técnicos del Protocolo SAM-128:

- ✅ **XOR → Conflict Matrix** para Segregación de Funciones (SoD)
- ✅ **NAND → AND NOT (`&^`)** para revocación de emergencia (KillSwitch)
- ✅ **AVX-512 eliminado** como justificación (inaplicable al hardware objetivo del SBOS)
- ✅ **BitmaskBundle** (2×uint64) en lugar de uint128 monolítico

Sin embargo, la crítica va más profundo: el plan corregido nombra los campos `bos_vdi_mask` y `bos_erp_mask`, lo que **mantiene el error conceptual de colapsar tecnologías concretas (VDI=Fedora KDE, ERP=Tryton) en lugar de modelar dominios de autorización abstractos**.

El `BitmaskBundle{VDIMask, ERPMask}` es un avance técnico pero sigue siendo arquitectónicamente incorrecto porque:

1. `VDIMask` asume que escritorio = Fedora KDE. ¿Qué ocurre cuando se agrega un endpoint físico diferente?
2. `ERPMask` asume que apps de negocio = Tryton. Pero Saleor, EspoCRM, Zammad y OrangeHRM también pertenecen al "dominio lógico".
3. El dominio financiero (límites de transacción, SoD, aprobaciones) no tiene su propia máscara en ninguno de los dos diseños.

---

### PREGUNTA 1 — Los 3 dominios

**Pregunta:** El corpus en `021-BAUTH §7` define Lógico, Físico y Financiero. ¿Son los correctos? ¿Un dominio Operacional sería una cuarta capa o viviría dentro del Financiero?

**Respuesta:**

Los tres dominios son conceptualmente correctos. Son la división mínima necesaria para un sistema de autorización empresarial. Sin embargo, su implementación actual los confunde con tecnologías concretas.

**El error fundamental es de nomenclatura y abstracción:**

| Nombre actual | Lo que debería ser | Lo que es hoy |
|---|---|---|
| `VDIMask` | `PhysicalDomainMask` | Permisos específicos de Fedora KDE |
| `ERPMask` | `LogicalDomainMask` | Permisos específicos de Tryton |
| *(ausente)* | `FinancialDomainMask` | Embebido en Button Rules de Tryton |

**Sobre el dominio Operacional:**

Un dominio Operacional (workflows, delegaciones temporales, estados de proceso) podría justificarse como cuarta capa, pero solo cuando el SBOS llegue a v2.0 y exista evidencia de que la Conflict Matrix y las Button Rules no son suficientes para modelar los flujos de aprobación. Por ahora, el dominio Operacional debe vivir dentro del Financiero como un subconjunto de la `FinancialDomainMask`.

**Decisión recomendada:** Mantener los tres dominios, renombrarlos correctamente, y añadir la máscara financiera que falta.

```
BitmaskBundle (v3 propuesta)
  ├── PhysicalDomainMask  uint64  // banexus — hardware, zonas, actuadores
  ├── LogicalDomainMask   uint64  // evaluador lógico unificado — zonas de negocio
  └── FinancialDomainMask uint64  // bAuth financial evaluator — SoD, límites, aprobaciones
```

---

### PREGUNTA 2 — Las zonas

**Pregunta:** ¿Las zonas son exclusivas del dominio Físico o el concepto debe unificarse para todos los dominios?

**Respuesta:**

Las zonas son actualmente nativas del dominio Físico (`ZONE-VENTAS`, `ZONE-ALMACEN`, puertas, relés). En el dominio Lógico, el equivalente conceptual es la "aplicación" o el "módulo de negocio" — lo que `bos_domains.logical.apps` ya transporta en el JWT.

**La pregunta crítica es: ¿quieres que "Contabilidad" sea una zona?**

Si la respuesta es sí, entonces estás describiendo exactamente la reconceptualización correcta:

> La `LogicalDomainMask` **no codifica aplicaciones** (Tryton, Saleor, OrangeHRM). **Codifica zonas de negocio** (Contabilidad, RRHH, Ventas, CRM, Operaciones). Las aplicaciones son implementaciones de una zona, no la zona en sí.

Esta distinción es el cambio arquitectónico más importante del modelo. Bajo este esquema:

```
Zona: CONTABILIDAD
  └── Implementaciones:
        ├── Tryton (módulos AP, AR, GL)
        ├── Superset (reportes contables)
        └── Paperless (documentos fiscales)

Zona: RRHH  
  └── Implementaciones:
        ├── OrangeHRM
        ├── Tryton (módulo de nómina)
        └── Paperless (contratos laborales)

Zona: VENTAS
  └── Implementaciones:
        ├── Saleor (ecommerce)
        ├── EspoCRM (CRM)
        └── Tryton (facturación)
```

**El bit en la `LogicalDomainMask` no significa "puede usar Tryton". Significa "puede operar en la zona Contabilidad", lo que implica acceso a Tryton + Superset + Paperless en los módulos relacionados con contabilidad.**

**Vocabulario unificado propuesto:**

| Dominio | Vocabulario de zona | Ejemplo |
|---|---|---|
| Físico | Zona física | `ZONE_ALMACEN`, `ZONE_VENTAS`, `DOOR_ZONE_A` |
| Lógico | Zona de negocio | `ZONE_CONTABILIDAD`, `ZONE_RRHH`, `ZONE_VENTAS_LOGICA` |
| Financiero | Zona de aprobación | `ZONE_APROBACION_PAGOS`, `ZONE_AUDITORIA_CAJA` |

El término "zona" se unifica conceptualmente pero mantiene vocabularios distintos por dominio porque el contenido es semánticamente diferente.

---

### PREGUNTA 3 — Los verbos

**Pregunta:** ¿Los verbos deben ser universales (READ, WRITE, APPROVE, EXECUTE) o específicos por dominio (PERM_VIEW, DRAWER_OPEN, SESSION_VALID)?

**Respuesta:**

Esta es la decisión arquitectónica que define si el modelo escala. La literatura de RBAC vs ABAC es clara al respecto.

**Los verbos específicos por dominio (modelo actual) tienen dos problemas:**

1. **No escalabilidad semántica:** Cuando se añade la zona `MANUFACTURA`, ¿se inventa `PERM_PRODUCE`? ¿`PERM_QUALITY_CHECK`? El vocabulario crece sin control.
2. **No componibilidad:** No puedes escribir una política genérica que diga "los auditores pueden LEER en cualquier zona" porque READ se llama de forma diferente en cada dominio (`PERM_VIEW` en ERP, `SESSION_VALID` en VDI).

**Recomendación basada en literatura RBAC/ABAC (NIST SP 800-162, OASIS XACML):**

**Verbos universales con contexto de dominio:**

```
Verbo universal    Contexto de dominio       Ejemplo
─────────────────────────────────────────────────────────
READ               Zona Contabilidad         Leer facturas en Tryton + reportes en Superset
WRITE              Zona Contabilidad         Crear asientos contables en Tryton
APPROVE            Zona Financiero           Aprobar pagos (requiere SoD: no puede ser el mismo que WRITE)
EXECUTE            Zona Físico               Activar relé cajón de dinero (DRAWER_OPEN)
CONFIGURE          Zona Administración       Cambiar configuración del sistema
```

**Los verbos específicos actuales se convierten en aliases del modelo universal:**

```go
// Mapping verbos legados → modelo universal
SESSION_VALID  = READ   | zona=PHYSICAL_ACCESS
DRAWER_OPEN    = EXECUTE | zona=ZONE_CAJA
PERM_VIEW      = READ   | zona=<zona de negocio>
PERM_EDIT      = WRITE  | zona=<zona de negocio>
PERM_APPROVE   = APPROVE | zona=FINANCIAL
```

**Verbos universales propuestos para SBOS (mínimo viable):**

```
READ      — Consultar/visualizar información en una zona
WRITE     — Crear/modificar información en una zona  
DELETE    — Eliminar información en una zona (requiere justificación)
APPROVE   — Aprobar una acción iniciada por otro actor (SoD obligatorio)
EXECUTE   — Activar un actuador físico o disparar un proceso automatizado
CONFIGURE — Modificar la configuración de una zona o sistema
AUDIT     — Acceso de solo lectura a logs y registros de auditoría (aislado del READ regular)
```

---

### PREGUNTA 4 — Los 128 bits y las 6 capas

**Pregunta:** ¿Las 6 capas del SAM-128 son capas dentro del entero de 128 bits? ¿Es el BitmaskBundle dos registros de 64 o un registro de 128?

**Respuesta:**

**Las 6 capas del SAM-128 son niveles de aislamiento contextual, no capas dentro del entero.** Son:

```
TENANT → EMPRESA → ROL → APLICACIÓN → ZONA → BITMASK
```

Cada nivel es una clave de lookup, no un campo de bits. El BITMASK es el resultado final — lo que se evalúa una vez que todos los niveles de contexto han sido resueltos.

**El BitmaskBundle es dos registros de uint64 independientes, no un registro de 128 bits:**

```go
// Lo que ES:
type BitmaskBundle struct {
    VDIMask uint64  // registro 1 — 64 bits — evaluado por banexus
    ERPMask uint64  // registro 2 — 64 bits — evaluado por trytond-auth-keycloak
}

// Lo que NO ES:
// Un uint128 = struct{ hi uint64; lo uint64 }
// donde los bits 64–127 son "la mitad superior" del mismo entero
```

**La distinción conceptual importa por tres razones:**

1. **Evaluadores independientes:** `banexus` evalúa solo el primer registro. `trytond-auth-keycloak` evalúa solo el segundo. Ninguno necesita conocer la existencia del otro registro.

2. **Espacio de bits independiente:** El Bit 5 en `VDIMask` es `DRAWER_OPEN`. El Bit 5 en `ERPMask` es `PERM_IMPORT`. No son el mismo bit — son el Bit 5 de registros diferentes. Esto resuelve la colisión estructuralmente.

3. **Extensibilidad limpia:** Añadir `FinancialDomainMask` es añadir un tercer registro independiente. No es "usar los bits 128–191 de un super-entero". Cada nuevo dominio obtiene su propio espacio de 64 bits virginal.

**Mapa de capacidad del modelo extendido:**

| Registro | Dominio | Bits disponibles | Evaluador |
|---|---|---|---|
| `PhysicalDomainMask` | Físico | 64 | banexus |
| `LogicalDomainMask` | Lógico (zonas de negocio) | 64 | evaluador lógico unificado ← **falta construir** |
| `FinancialDomainMask` | Financiero | 64 | bAuth financial evaluator ← **falta diseñar** |

Con 64 bits por dominio y las zonas de negocio como semántica del bit (no las aplicaciones), el SBOS tiene capacidad para 64 zonas de negocio, 64 capacidades físicas, y 64 controles financieros — sin necesidad nunca de un uint128 monolítico.

---

### PREGUNTA 5 — El evaluador por dominio

**Pregunta:** Hoy `banexus` evalúa el dominio físico y `trytond-auth-keycloak` evalúa el ERP. Con un modelo de dominios abstractos, ¿qué evaluador falta?

**Respuesta:**

La pieza que más falta en el diseño actual es **el evaluador del dominio lógico unificado**.

**Estado actual de los evaluadores:**

| Dominio | Evaluador | Estado |
|---|---|---|
| Físico | `banexus` | ✅ Implementado y funcionando |
| ERP/Tryton | `trytond-auth-keycloak` | ✅ Implementado para Tryton |
| Saleor | Ninguno | ❌ Sin evaluador bAuth |
| EspoCRM | Ninguno | ❌ Sin evaluador bAuth |
| Zammad | Ninguno | ❌ Sin evaluador bAuth |
| OrangeHRM | Ninguno | ❌ Sin evaluador bAuth |
| Superset | Ninguno | ❌ Sin evaluador bAuth |
| Paperless | Ninguno | ❌ Sin evaluador bAuth |
| Financiero | Tryton Button Rules (parcial) | ⚠️ Sin máscara propia en bAuth |

**El evaluador lógico unificado que falta debe:**

1. Recibir la `LogicalDomainMask` (o, en el modelo reconceptualizado, la máscara de zonas de negocio).
2. Mantener un mapa `zona → aplicaciones` que resuelva qué aplicaciones son accesibles para cada zona activa.
3. Exponer un endpoint que cualquier aplicación (Saleor, EspoCRM, etc.) pueda consultar para verificar si el portador del JWT tiene acceso a una zona específica.
4. Funcionar como un Policy Decision Point (PDP) en el sentido de XACML — las aplicaciones son Policy Enforcement Points (PEP) que delegan la decisión a este evaluador.

**Interfaz mínima del evaluador lógico:**

```go
// LogicalDomainEvaluator — el componente que falta
// Implementa el Policy Decision Point para el dominio lógico
type LogicalDomainEvaluator interface {
    // CanAccessZone — ¿puede este portador de JWT operar en esta zona con este verbo?
    CanAccessZone(jwt *BosJWT, zone BusinessZone, verb UniversalVerb) (bool, error)
    
    // GetZoneApplications — ¿qué aplicaciones implementan esta zona?
    // Usado por las apps para saber a qué módulos dar acceso
    GetZoneApplications(zone BusinessZone) ([]ApplicationEndpoint, error)
    
    // GetActiveZones — ¿en qué zonas puede operar este usuario?
    // Usado por el frontend para construir el menú de navegación
    GetActiveZones(jwt *BosJWT) ([]BusinessZone, error)
}

// Ejemplo de uso desde Saleor:
// evaluator.CanAccessZone(jwt, ZONE_VENTAS, READ)
// → true si el bit de ZONE_VENTAS está activo en LogicalDomainMask

// Ejemplo de uso desde Superset:
// evaluator.CanAccessZone(jwt, ZONE_CONTABILIDAD, AUDIT)
// → true si el usuario tiene permisos de auditoría en la zona contabilidad
```

**El mapa zona → aplicaciones:**

```yaml
# zone_application_map.yaml — fuente de verdad del evaluador lógico
zones:
  ZONE_CONTABILIDAD:
    applications:
      - tryton: [modules: [account, account_invoice, account_payment]]
      - superset: [dashboards: [contabilidad_*]]
      - paperless: [tags: [factura, comprobante, fiscal]]
    required_verb_for_access: READ
    
  ZONE_RRHH:
    applications:
      - orangehrm: [all_modules: true]
      - tryton: [modules: [payroll, leave]]
      - paperless: [tags: [contrato, personal]]
    required_verb_for_access: READ
    
  ZONE_VENTAS:
    applications:
      - saleor: [all_modules: true]
      - espocrm: [all_modules: true]
      - tryton: [modules: [sale, invoice]]
    required_verb_for_access: READ
    
  ZONE_SOPORTE:
    applications:
      - zammad: [all_modules: true]
    required_verb_for_access: READ
```

---

## PARTE 3: RECONCEPTUALIZACIÓN COMPLETA DEL MODELO

### 3.1 EL MODELO CORRECTO: ZONA → APLICACIONES

Confirmando la hipótesis planteada: **el modelo correcto es un mapa zona → aplicaciones donde la LogicalDomainMask codifica zonas de negocio, no aplicaciones concretas.**

Esto es un cambio arquitectónico importante pero correcto. Las implicaciones son:

**Antes (modelo actual — incorrecto):**

```
ERPMask bit 0 = PERM_VIEW en Tryton
ERPMask bit 1 = PERM_EDIT en Tryton
ERPMask bit 5 = PERM_IMPORT en Tryton
```
El modelo está acoplado a Tryton. Si mañana se reemplaza Tryton por otro ERP, hay que renumerar todos los bits.

**Después (modelo reconceptualizado — correcto):**

```
LogicalDomainMask bit 0 = READ en ZONE_CONTABILIDAD
LogicalDomainMask bit 1 = WRITE en ZONE_CONTABILIDAD
LogicalDomainMask bit 2 = READ en ZONE_RRHH
LogicalDomainMask bit 3 = WRITE en ZONE_RRHH
LogicalDomainMask bit 4 = READ en ZONE_VENTAS
LogicalDomainMask bit 5 = WRITE en ZONE_VENTAS
...
```

Si mañana se reemplaza Tryton, solo cambia el `zone_application_map.yaml`. Los bits no cambian.

---

### 3.2 DISEÑO DEL BITMASKBUNDLE v3

```go
// BitmaskBundle v3 — modelo reconceptualizado por dominios abstractos
// SKULL · SBOS · bAuth · Abril 2026
//
// Cambios respecto a v2 (plan corregido):
//   - VDIMask → PhysicalDomainMask (no asume Fedora KDE)
//   - ERPMask → LogicalDomainMask (no asume Tryton, codifica zonas)
//   - Nueva: FinancialDomainMask (dominio financiero con máscara propia)
//
// Serialización JWT:
//   "bos_physical_mask" | "bos_logical_mask" | "bos_financial_mask"
type BitmaskBundle struct {
    // DOMINIO FÍSICO — Zonas físicas, actuadores, hardware
    // Evaluado por: banexus
    // Semántica de bits: zonas físicas + verbos EXECUTE para actuadores
    PhysicalDomainMask uint64 `json:"bos_physical_mask"`

    // DOMINIO LÓGICO — Zonas de negocio (no aplicaciones)
    // Evaluado por: LogicalDomainEvaluator (por construir)
    // Semántica de bits: zona × verbo (READ, WRITE, APPROVE, CONFIGURE)
    // El evaluador resuelve zona → aplicaciones vía zone_application_map
    LogicalDomainMask uint64 `json:"bos_logical_mask"`

    // DOMINIO FINANCIERO — Límites, aprobaciones, SoD financiero
    // Evaluado por: FinancialDomainEvaluator (por diseñar)
    // Semántica de bits: zona financiera × verbo (APPROVE, AUDIT)
    FinancialDomainMask uint64 `json:"bos_financial_mask,omitempty"`
}
```

---

### 3.3 MAPA DE BITS LÓGICOS (ZONA × VERBO)

```
LOGICAL DOMAIN MASK — bos_logical_mask en JWT
Evaluado por: LogicalDomainEvaluator

Zona CONTABILIDAD:
  Bit 0:  CONTABILIDAD_READ      — leer registros contables (Tryton + Superset + Paperless)
  Bit 1:  CONTABILIDAD_WRITE     — crear/editar registros contables (Tryton)
  Bit 2:  CONTABILIDAD_APPROVE   — aprobar asientos/pagos (SoD: no puede tener WRITE simultáneo)
  Bit 3:  CONTABILIDAD_AUDIT     — acceso a logs de auditoría contable

Zona RRHH:
  Bit 4:  RRHH_READ              — leer datos de empleados (OrangeHRM + Tryton Payroll)
  Bit 5:  RRHH_WRITE             — modificar datos de empleados
  Bit 6:  RRHH_APPROVE           — aprobar vacaciones, solicitudes (SoD: no puede ser el solicitante)
  Bit 7:  RRHH_AUDIT             — acceso a logs de RRHH

Zona VENTAS:
  Bit 8:  VENTAS_READ            — leer pedidos/clientes (Saleor + EspoCRM + Tryton)
  Bit 9:  VENTAS_WRITE           — crear/modificar pedidos y clientes
  Bit 10: VENTAS_APPROVE         — aprobar descuentos especiales o créditos
  Bit 11: VENTAS_AUDIT           — acceso a reportes de ventas

Zona SOPORTE:
  Bit 12: SOPORTE_READ           — leer tickets (Zammad)
  Bit 13: SOPORTE_WRITE          — crear/responder tickets
  Bit 14: SOPORTE_CONFIGURE      — configurar Zammad (colas, SLAs)

Zona ADMINISTRACION:
  Bit 20: ADMIN_SYSTEM           — administración de sistema (bAuth, Keycloak)
  Bit 21: ADMIN_USERS            — gestión de usuarios y roles
  Bit 22: ADMIN_AUDIT            — acceso completo a todos los logs

Bits 23–62: RESERVADOS para zonas adicionales (Manufactura, Proyectos, Logística)
Bit 63:     SUPERZONE (reservado, nunca asignar por RolTemplate — solo AssumeTenantContext)
```

---

### 3.4 MAPA DE BITS FINANCIEROS (ZONA FINANCIERA × VERBO)

```
FINANCIAL DOMAIN MASK — bos_financial_mask en JWT
Evaluado por: FinancialDomainEvaluator

Control de caja:
  Bit 0:  CAJA_APERTURA          — abrir caja (SoD: no puede tener CAJA_AUDITORIA)
  Bit 1:  CAJA_CIERRE            — cerrar caja
  Bit 2:  CAJA_ARQUEO            — realizar arqueo
  Bit 3:  CAJA_AUDITORIA         — auditar caja (SoD: no puede tener CAJA_APERTURA)

Aprobaciones de pago:
  Bit 4:  PAGO_CREATE            — crear órdenes de pago (SoD: no puede tener PAGO_APPROVE)
  Bit 5:  PAGO_APPROVE_L1        — aprobar pagos hasta límite L1 (configurable)
  Bit 6:  PAGO_APPROVE_L2        — aprobar pagos hasta límite L2 (requiere también L1)
  Bit 7:  PAGO_AUDIT             — auditar pagos

Nómina:
  Bit 8:  NOMINA_INPUT           — ingresar datos de nómina (SoD: no puede tener NOMINA_APPROVE)
  Bit 9:  NOMINA_APPROVE         — aprobar nómina (SoD: no puede tener NOMINA_INPUT)
  Bit 10: NOMINA_AUDIT           — auditar nómina

Compras:
  Bit 11: COMPRA_SOLICITUD       — solicitar compra (SoD: no puede tener COMPRA_APROBACION)
  Bit 12: COMPRA_APROBACION      — aprobar compra
  Bit 13: COMPRA_RECEPCION       — recibir mercadería

Bits 14–63: RESERVADOS para controles financieros adicionales
```

---

### 3.5 CONFLICT MATRIX ACTUALIZADA PARA EL MODELO DE DOMINIOS

Con el nuevo modelo, los conflictos SoD se expresan en términos de bits de dominio, no de roles:

```go
var DefaultSoDConflicts = []SoDConflict{
    // Dominio financiero — caja
    {BitA: CAJA_APERTURA, BitB: CAJA_AUDITORIA, Mask: "financial",
     Description: "Quien opera la caja no puede auditarla", Severity: "critical"},
    
    // Dominio financiero — pagos
    {BitA: PAGO_CREATE, BitB: PAGO_APPROVE_L1, Mask: "financial",
     Description: "Quien crea órdenes de pago no puede aprobarlas", Severity: "critical"},
    
    // Dominio lógico — contabilidad
    {BitA: CONTABILIDAD_WRITE, BitB: CONTABILIDAD_APPROVE, Mask: "logical",
     Description: "Quien registra asientos no puede aprobarlos", Severity: "critical"},
    
    // Dominio financiero — nómina
    {BitA: NOMINA_INPUT, BitB: NOMINA_APPROVE, Mask: "financial",
     Description: "Segregación de nómina: principio de 4 ojos", Severity: "critical"},
    
    // Dominio financiero — compras
    {BitA: COMPRA_SOLICITUD, BitB: COMPRA_APROBACION, Mask: "financial",
     Description: "Quien solicita no puede aprobar sus propias compras", Severity: "critical"},
}
```

---

## PARTE 4: PLAN DE MIGRACIÓN AL MODELO RECONCEPTUALIZADO

### 4.1 FASES DE IMPLEMENTACIÓN

| Fase | Versión SBOS | Acción | Entregable |
|---|---|---|---|
| **Fase 0 — Ahora** | Pre-v0.9 | Separar VDI y ERP en máscaras independientes (ya en plan corregido) | `bitmask_constants.go` v2 |
| **Fase 1 — v0.9 Beta** | Jul 2026 | Renombrar `VDIMask→PhysicalDomainMask`, `ERPMask→LogicalDomainMask`. Mantener aliases de compatibilidad. | Migración JWT claims |
| **Fase 2 — v0.9 GA** | Sep 2026 | Reconceptualizar bits de `LogicalDomainMask` de aplicaciones → zonas de negocio. Construir `zone_application_map.yaml`. | Nueva Tabla Maestra §8 |
| **Fase 3 — v1.0** | Nov 2026 | Implementar `LogicalDomainEvaluator` como servicio. Migrar Saleor, EspoCRM, Zammad, OrangeHRM, Superset, Paperless a este evaluador. | 6 integraciones nuevas |
| **Fase 4 — v1.0** | Nov 2026 | Añadir `FinancialDomainMask`. Implementar `FinancialDomainEvaluator`. Migrar controles de caja y aprobaciones de Tryton Button Rules → bAuth. | Evaluador financiero |
| **Fase 5 — v1.5** | Mar 2027 | Migrar verbos específicos por dominio → verbos universales. Deprecar `PERM_VIEW`, `SESSION_VALID`, etc. como nombres canónicos. | Refactor constants |
| **Fase 6 — v2.0** | 2027 | Evaluar dominio Operacional (workflows, delegaciones temporales) según demanda real. | ADR nuevo si se implementa |

---

### 4.2 ARCHIVOS A MODIFICAR

| Archivo | Cambio | Prioridad |
|---|---|---|
| `021-DAEMON-BAUTH §8` | Reemplazar Tabla Maestra por `BitmaskBundle v3`: PhysicalDomainMask + LogicalDomainMask + FinancialDomainMask | CRÍTICO |
| `021-DAEMON-BAUTH §7` | Formalizar los dominios con las definiciones de la Parte 1 de este documento | CRÍTICO |
| `025-VDI §7` | Renombrar `bos_vdi_mask` → `bos_physical_mask`. Actualizar documentación. | CRÍTICO |
| `022-IDENTITY-CONTRACTS §5` | Actualizar `RolTemplate` para expresar permisos en términos de zona × verbo | ALTO |
| `022-IDENTITY-CONTRACTS §7` | Actualizar `sod_rules` para referenciar bits de dominio, no nombres de roles | ALTO |
| `030-BOUNDED-CONTEXTS` | Alinear los Bounded Contexts con el mapa `zona → aplicaciones` | ALTO |
| `010-GOVERNANCE §7` | Documentar proceso de Asunción de Contexto del Superusuario y el `AssumeTenantContext` | MEDIO |
| `032-OPERATIONS §7` | Añadir RK-016 `EmergencyRevoke` como runbook formal (usando AND NOT, no NAND) | MEDIO |
| *(nuevo)* `zone_application_map.yaml` | Fuente de verdad del mapa zona → aplicaciones para el `LogicalDomainEvaluator` | ALTO |
| *(nuevo)* `logical_domain_evaluator.go` | Implementación del PDP para el dominio lógico | ALTO |

---

## CONCLUSIÓN

### Lo que el plan corregido resuelve (v1.0):
- ✅ XOR → Conflict Matrix (SoD correcto)
- ✅ NAND → AND NOT (KillSwitch correcto)
- ✅ AVX-512 eliminado
- ✅ Colisión de bits VDI/ERP resuelta estructuralmente con dos uint64 independientes

### Lo que la reconceptualización agrega (v1.1 — este documento):
- 🔧 `VDIMask` → `PhysicalDomainMask` (abstracción del hardware)
- 🔧 `ERPMask` → `LogicalDomainMask` (abstracción de Tryton hacia zonas de negocio)
- 🔧 `FinancialDomainMask` como tercer registro con máscara propia
- 🔧 Verbos universales (READ, WRITE, APPROVE, EXECUTE, AUDIT, CONFIGURE) como vocabulario canónico
- 🔧 Mapa `zona → aplicaciones` como mecanismo de desacoplamiento entre permisos y tecnologías
- 🔧 `LogicalDomainEvaluator` como la pieza de infraestructura que más falta en el diseño actual
- 🔧 Zonas de negocio como semántica del bit lógico (no aplicaciones concretas)

### La respuesta a la pregunta central:

> ¿La "zona" lógica es el módulo de negocio independientemente de qué app lo implementa?

**Sí. Eso es exactamente el modelo correcto.**

El bit no es "puede usar Tryton". El bit es "puede operar en la zona Contabilidad", y eso implica acceso a Tryton + Superset + Paperless en los módulos relacionados con contabilidad. El `zone_application_map.yaml` es el mecanismo de resolución. El `LogicalDomainEvaluator` es el árbitro.

Este es el cambio arquitectónico que transforma el SBOS de un sistema con permisos acoplados a tecnologías específicas a un sistema de autorización basado en dominios abstractos, extensible y reemplazable.

---

_SKULL · SBOS · DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION · Abril 2026 · v1.1_
_Arquitecto: Principal Systems Architect_
_Basado en: NIST SP 800-63, ISO/IEC 27001:2022, ISO/IEC 24760, IEEE 802.1X, FIDO2_
_Extiende: SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO v1.0_
