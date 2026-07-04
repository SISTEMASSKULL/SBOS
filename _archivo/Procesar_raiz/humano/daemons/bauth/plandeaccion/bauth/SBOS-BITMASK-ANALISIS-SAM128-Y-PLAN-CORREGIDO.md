# SBOS — Análisis Técnico del Protocolo SAM-128 y Plan Corregido de Evolución del BitMask
## Arquitecto: Principal Systems Architect
## SKULL · SBOS · Abril 2026 · v1.0

> ⚠️ **ESTE DOCUMENTO ES HISTÓRICO — HA SIDO SUPERADO (Junio 2026)**
>
> El análisis de errores del SAM-128 que este documento realiza es correcto y valioso como registro histórico. Sin embargo, el **modelo BitMask ha sido completamente rediseñado** desde la publicación de este documento.
>
> **El modelo actual es el BitMask Dual** definido en:
> - `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md` — Especificación completa: BitMask Átomo (64-bit, label encoding para identificación) + Rol BitMask (N-bit, one-hot encoding para combinación). DDL `bos_privilege`.
> - `SBOS-MANUAL-BAUTH-COMPONENT-ROLES.md` v1.7 — bAuth administra el BitMask, no KC ni Tryton-PDP.
> - `SBOS-BAUTH-EVALUACION-INTEGRAL-v2.2.md` — Evaluación integral del proyecto (3,500 líneas).
>
> **Lo que cambió respecto a este documento:**
> - SAM-128 fue descartado como protocolo. El nuevo modelo NO usa 128 bits, NO usa XOR para SoD, y NO mezcla identificación con combinación.
> - El error de escalamiento `1 OR 2 = 3 → "eliminar"` está corregido: las operaciones OR/AND operan sobre posiciones de bit independientes (Rol BitMask), NUNCA sobre códigos de átomo (BitMask Átomo).
> - SoD se implementa con Conflict Matrix estática (pares de átomos incompatibles), no con XOR.
> - `BitmaskBundle` (7×64 bits) fue eliminado del diseño.
>
> **Para desarrollo actual, usar exclusivamente los 3 manuales listados arriba.**

---

## PARTE 1: AUDITORÍA TÉCNICA DEL PROTOCOLO SAM-128

Antes de construir cualquier plan de acción, este documento realiza una auditoría técnica rigurosa del documento "Protocolo SAM-128 — Especificación Técnica Maestra". La auditoría es necesaria porque el documento contiene afirmaciones técnicas que, si se implementan literalmente, producirán defectos de seguridad y de rendimiento en el SBOS.

---

### VEREDICTO GLOBAL

El SAM-128 es un documento con **buenas intenciones arquitectónicas** pero con **errores técnicos materiales** que lo hacen inimplementable en su forma actual. Los conceptos de alto nivel (separación por dominios, extensibilidad, superusuario sin bits por defecto) son válidos y deben preservarse. Las afirmaciones técnicas específicas sobre operadores lógicos y hardware deben corregirse.

---

### 1.1 DIAGNÓSTICO: LA OPERACIÓN XOR PARA SEGREGACIÓN DE FUNCIONES ES INCORRECTA

**Lo que dice el SAM-128:**
> "Si un usuario tiene el rol de Cajero y Auditor, el XOR apaga los bits que no deben coexistir. Si ambos tienen el bit de Anular Factura, el resultado es 0 (1 XOR 1 = 0). El usuario debe elegir qué identidad usar."

**Por qué esto es un defecto de seguridad:**

XOR (`^`) no implementa Segregación de Funciones (SoD). XOR invierte bits: si el bit está presente en ambas máscaras, desaparece. Esto produce un resultado que nadie quiso: el usuario no tiene el permiso en ninguno de los dos contextos, pero *sí puede obtenerlo* si solo uno de los roles lo tiene activo.

Consideremos el escenario del SAM-128 con datos concretos:

```
ROL_CAJERO  = 0b...0000_0001_1101  (DRAWER_OPEN, SESSION_VALID, PERM_VIEW, PERM_EDIT)
ROL_AUDITOR = 0b...0000_0001_0001  (SESSION_VALID, PERM_VIEW, READ_AUDIT_LOG)

XOR resultado: ROL_CAJERO ^ ROL_AUDITOR
= 0b...0000_0000_1100  (DRAWER_OPEN, PERM_EDIT)
```

El resultado con XOR es que el usuario tiene acceso al **cajón de dinero** pero **no puede ver nada** (SESSION_VALID y PERM_VIEW se cancelaron entre sí). Este no es el comportamiento deseado. La SoD se viola, no se implementa.

**El estándar correcto (ISACA, ISO 27001 A.5.3, NIST SP 800-53 AC-5):**

La Segregación de Funciones se implementa con una **Conflict Matrix** — una tabla que lista pares de permisos incompatibles — y se valida en el momento de la asignación del rol, no en el momento del cálculo del BitMask. El mecanismo estándar de la industria (SAP GRC, Oracle IAM, SailPoint, tenfold) usa:

```
Si el usuario tiene ROL_A y quiere asumir ROL_B:
  - Verificar conflict_matrix[ROL_A][ROL_B]
  - Si conflict existe: DENEGAR asignación o requerir aprobación con justificación
  - Si no hay conflict: PERMITIR OR(mask_A, mask_B)
```

El BitMask resultante es siempre `OR` de los roles activos. La SoD vive en la capa de gobernanza, no en la aritmética del entero.

**La operación AND NOT del SBOS actual (`&^` en Go) YA implementa herencia correcta**, que es un mecanismo relacionado pero diferente a SoD. No debe confundirse.

---

### 1.2 DIAGNÓSTICO: LA OPERACIÓN NAND PARA REVOCACIÓN DE EMERGENCIA TIENE UN DEFECTO LÓGICO

**Lo que dice el SAM-128:**
> "Si se detecta una brecha en una Empresa, se aplica una máscara de bloqueo global: `Mask_Result = NOT(Mask_User AND Mask_KillSwitch)`. Apaga instantáneamente capacidades específicas."

**El problema matemático:**

La operación NAND es `NOT(A AND B)`. Analicemos con valores concretos:

```
Mask_User      = 0b1111  (usuario tiene todos los permisos)
Mask_KillSwitch = 0b0010  (queremos revocar el bit 1)

NAND(Mask_User, Mask_KillSwitch) = NOT(0b1111 AND 0b0010)
                                  = NOT(0b0010)
                                  = 0b1101

Resultado: el usuario CONSERVA todos los permisos excepto el bit 1.
```

Hasta aquí parece funcionar, pero consideremos un caso diferente:

```
Mask_User      = 0b0100  (usuario solo tiene el bit 2)
Mask_KillSwitch = 0b0010  (queremos revocar el bit 1)

NAND = NOT(0b0100 AND 0b0010) = NOT(0b0000) = NOT(0b0000) = 0b1111
```

**El resultado es que un usuario con un solo permiso, tras aplicar el "KillSwitch" que no afectaba ninguno de sus bits, termina con TODOS LOS PERMISOS ACTIVOS.** Esto es una elevación de privilegios involuntaria causada por una operación mal especificada.

**El operador correcto para revocación de bits es AND NOT (`&^` en Go):**

```
Mask_Result = Mask_User &^ Mask_KillSwitch

Con el mismo ejemplo:
Mask_User      = 0b0100
Mask_KillSwitch = 0b0010
Resultado      = 0b0100  (el bit 2 permanece, el bit 1 nunca estuvo)
```

AND NOT ya existe en el SBOS como `InheritFromParent` y como `RevokeBit`. No hay que inventar NAND — la operación correcta ya está implementada.

---

### 1.3 DIAGNÓSTICO: LAS AFIRMACIONES SOBRE AVX-512 Y REGISTROS XMM SON INCORRECTAS EN CONTEXTO

**Lo que dice el SAM-128:**
> "El bAuth utiliza registros XMM (128-bit) para procesar las máscaras en un solo ciclo de CPU."
> "Pasar de 64 a 128 bits no duplica la latencia; la mantiene constante gracias al uso de instrucciones SIMD."

**Los problemas técnicos:**

1. **Los registros XMM son extensiones SSE/AVX, no registros de propósito general.** El compilador Go no genera instrucciones SIMD automáticamente para operaciones en `struct{ hi, lo uint64 }`. El código Go compilado para uint128 (dos uint64) usa instrucciones escalares de 64 bits en registros GPR (RAX, RBX, etc.). Para usar XMM se necesita código ensamblador explícito o cgo con intrínsecas, ninguno de los cuales forma parte del bAuth actual.

2. **AVX-512 no está disponible en el hardware objetivo del SBOS.** Los VPS de bajo costo en Bolivia (Digital Ocean, Linode, servidores ARM64, etc.) no tienen garantía de soporte AVX-512. La propia investigación muestra que AMD habilitó AVX-512 solo desde Zen 4 (2022) e Intel lo deshabilitó en muchos cores E de 12ª generación. El SBOS debe funcionar en hardware modesto.

3. **La afirmación "en un solo ciclo de CPU" es incorrecta.** Una operación AND en uint128 implementada como dos AND de 64 bits toma 2 operaciones de 1 ciclo cada una. Eso es 2 ciclos, no 1. La diferencia es despreciable para este caso de uso, pero la afirmación es técnicamente falsa.

4. **AVX-512 está diseñado para procesamiento vectorial masivo** (machine learning, procesamiento de imágenes, criptografía de alto rendimiento). Usar argumentos de AVX-512 para justificar un cambio en el tamaño del BitMask de autorización es una categoría equivocada.

**La verdad sobre el rendimiento de uint128 en Go:**

La investigación del código fuente de Go `net/netip/uint128.go` y la librería `lukechampine.com/uint128` muestra:

| Operación | uint64 nativo | uint128 (2×uint64) | Delta |
|---|---|---|---|
| AND/OR/XOR | ~0.39 ns/op | ~0.45 ns/op | +15% |
| Comparación | ~0.39 ns/op | ~0.67 ns/op | +72% |
| String serialization | N/A | 173 ns/op | impacto JWT |

La diferencia de rendimiento es **irrelevante** para el caso de uso del SBOS (bAuth no hace millones de operaciones BitMask por segundo). Lo que sí importa es el **impacto en el JWT**.

---

### 1.4 DIAGNÓSTICO: EL IMPACTO EN EL JWT NO ESTÁ ANALIZADO

El SAM-128 afirma: "Los 128 bits se transportan en Hexadecimal de 32 caracteres, lo que es extremadamente eficiente."

Esto ignora el impacto real. El JWT actual del SBOS lleva el claim `bos_bitmask` como un hex string. Comparando:

| Formato | Tamaño en JWT | Ejemplo |
|---|---|---|
| uint64 como hex | 16 caracteres (64 bytes en JSON) | `"0x000000000003E627"` |
| uint128 como hex | 32 caracteres (96 bytes en JSON) | `"0x00000000000000000000000003E627"` |
| Multi-mask (2×uint64) | 32 caracteres + estructura JSON | `{"erp":"0x...","vdi":"0x..."}` |
| Multi-mask (3×uint64) | 48 caracteres + estructura JSON | Impacto real en cookie 4KB |

Clerk (plataforma de autenticación empresarial) documenta explícitamente en su arquitectura que los tokens con muchos claims de permisos pueden exceder el límite de 4KB de cookies del browser. Esta es una preocupación operacional real que el SAM-128 descarta sin análisis.

---

### 1.5 DIAGNÓSTICO: LA ARQUITECTURA DE 6 CAPAS TIENE VALOR CONCEPTUAL PERO REQUIERE ALINEACIÓN CON EL SBOS

El SAM-128 propone 6 niveles de aislamiento: TENANT → EMPRESA → ROL → APLICACIÓN → ZONA → BITMASK.

Este modelo conceptual es valioso y se alinea bien con los Bounded Contexts del SBOS (030-BOUNDED-CONTEXTS). Sin embargo, el SBOS ya implementa parte de este aislamiento de forma diferente:

| Nivel SAM-128 | Implementación actual SBOS | Alineación |
|---|---|---|
| TENANT | Realm Keycloak (1 realm por empresa) | ✅ Ya implementado |
| EMPRESA | NIT en seed file + realm isolation | ✅ Ya implementado |
| ROL | RolTemplate + BitMask 64-bit | ✅ Parcialmente (BitMask actual) |
| APLICACIÓN | Claim `bos_domains.logical.apps` en JWT | ✅ Parcialmente |
| ZONA | Zonas físicas en `physical.zones` | ✅ Parcialmente |
| BITMASK | BitMask 64-bit (Tabla Maestra §8 de 021-BAUTH) | ✅ Ya implementado |

El aislamiento multi-tenant ya existe. Lo que el SAM-128 propone —correctamente— es formalizar el aislamiento de **APLICACIÓN** dentro del mismo BitMask usando los cuadrantes como forma de separar dominios funcionales.

---

### RESUMEN DE LA AUDITORÍA

| Afirmación SAM-128 | Veredicto | Acción |
|---|---|---|
| XOR para SoD | ❌ Incorrecto — produce escalamiento de privilegios | Usar Conflict Matrix |
| NAND para KillSwitch | ❌ Incorrecto — puede dar ALL_PERMISSIONS | Usar AND NOT (`&^`) |
| AVX-512 / registros XMM | ❌ Inaplicable al hardware objetivo | Eliminar esta justificación |
| 128 bits = mismo rendimiento | ⚠️ Parcialmente correcto pero sin analizar JWT | Evaluar impacto JWT |
| 6 capas de aislamiento | ✅ Concepto válido y alineado con SBOS | Adaptar a arquitectura existente |
| Superusuario sin bits por defecto | ✅ Excelente práctica (Principle of Least Privilege) | Implementar como "Asunción de Contexto" |
| Cuadrantes de 32 bits | ✅ Concepto válido | Adoptar como política de namespace |
| uint128 implementable en Go | ✅ Sí, con struct{hi, lo uint64} | Evaluar necesidad real |

---

## PARTE 2: PLAN CORREGIDO — EVOLUCIÓN DEL BITMASK SBOS

Con base en la auditoría anterior, en la investigación internacional, y en plena alineación con los documentos del proyecto (021-DAEMON-BAUTH, 025-VDI, 030-BOUNDED-CONTEXTS, 004-RULES), este plan propone la evolución correcta del BitMask.

---

### 2.1 DECISIÓN ARQUITECTÓNICA: ¿64 BITS O 128 BITS?

La pregunta correcta no es "¿podemos implementar 128 bits?" (la respuesta técnica es sí, con `struct{hi, lo uint64}`). La pregunta correcta es: **¿el SBOS tiene una necesidad real que 64 bits no puede satisfacer?**

**Análisis de capacidad actual (64 bits):**
- Bits 0–9: ERP/Tryton (10 bits) — ✅ usados
- Bits 10–23: VDI/Hardware (14 bits) — ✅ usados
- Bits 24–47: RESERVADOS SKULL (24 bits disponibles)
- Bits 48–63: CUSTOM cliente (16 bits)

**Total bits disponibles para expansión: 40 bits.** Con 40 bits sin asignar, el SBOS tiene espacio para 40 permisos adicionales dentro del uint64 actual antes de necesitar extenderse.

**Conclusión:** Una migración a 128 bits en este momento es **prematura**. El problema real que debe resolverse es la inconsistencia de numeración entre 025-VDI y 021-BAUTH — no el tamaño del entero.

**Decisión recomendada (alineada con el principio de SBOS de no sobre-diseñar):** Mantener uint64 como tipo canónico para el BitMask, formalizar la política de namespace de bits, y diseñar la **ruta de migración a multi-mask (2×uint64)** para cuando se agoten los bits disponibles — que la evidencia sugiere que no ocurrirá antes de v2.0.

---

### 2.2 LA RUTA CORRECTA: MULTI-MASK ARCHITECTURE (NO uint128 MONOLÍTICO)

La investigación (Sonus Sundar, Medium; Clerk architecture; DreamFactory RBAC) converge en que la solución estándar de la industria para sistemas que necesitan más de 64 permisos no es un entero de 128 bits monolítico, sino una arquitectura **multi-mask** donde cada máscara cubre un dominio funcional separado.

Esto es superiora al uint128 monolítico por tres razones:

1. **Legibilidad operacional:** Juan Pérez puede ver `erp_mask=0x0005` y saber que el usuario tiene PERM_VIEW y PERM_EDIT en Tryton, sin tener que interpretar un hex de 32 caracteres.

2. **Extensibilidad independiente:** Si mañana se añade el modulo de manufactura (MRP), se añade `mrp_mask` al JWT sin tocar los bits existentes. Con uint128, habría que renumerar bits.

3. **Compatibilidad con banexus:** banexus no necesita saber nada de Tryton. Recibe solo `vdi_mask` y opera sobre él. No necesita procesar 128 bits cuando 24 son suficientes.

**Diseño de la Multi-Mask Architecture para SBOS:**

```go
// BitmaskBundle — reemplaza el bos_bitmask único en el JWT
// cuando el sistema escale más allá de los 64 bits actuales.
// En v0.9/v1.0: solo vdi_mask y erp_mask son relevantes.
// Los otros se añaden conforme se implementen los módulos.
type BitmaskBundle struct {
    // DOMINIO 1: VDI y Hardware (Bits 0–23 de la Tabla Maestra actual)
    // Evaluado por: banexus
    // Serialización JWT: "bos_vdi_mask"
    VDIMask uint64 `json:"bos_vdi_mask"`

    // DOMINIO 2: ERP/Tryton (Bits 0–9 de la Tabla Maestra actual)
    // Evaluado por: Tryton vía trytond-auth-keycloak
    // Serialización JWT: "bos_erp_mask"
    ERPMask uint64 `json:"bos_erp_mask"`

    // DOMINIO 3: Integraciones externas (biedata)
    // Reservado para v1.5 cuando biedata necesite control granular
    // Serialización JWT: "bos_integration_mask"
    IntegrationMask uint64 `json:"bos_integration_mask,omitempty"`

    // DOMINIO CUSTOM: Definido por el cliente en RolTemplate
    // Serialización JWT: "bos_custom_mask"
    CustomMask uint64 `json:"bos_custom_mask,omitempty"`
}
```

**Impacto en el JWT con este diseño:**
- Hoy (v0.9): Solo `bos_vdi_mask` y `bos_erp_mask` → 2 claims de 18 bytes cada uno = 36 bytes adicionales vs el actual
- Futuro (v1.5): Máximo 4 claims × 18 bytes = 72 bytes adicionales — bien dentro del límite de 4KB

---

### 2.3 CORRECCIÓN DEL GAP CRÍTICO-1: RESOLUCIÓN INMEDIATA DE LA INCONSISTENCIA VDI

Este es el problema que debe resolverse AHORA, independientemente de la decisión sobre 128 bits.

**Problema:** `025-VDI §7` define bits VDI comenzando en Bit 0, mientras que la Tabla Maestra de `021-BAUTH §8` los define en bits 10–23.

**Solución: Separar los dos dominios en sus propias máscaras uint64 independientes.**

Esto resuelve el gap crítico de forma más limpia que renumerar bits, porque:
- `banexus` solo necesita `bos_vdi_mask` — nunca vio ni verá los bits ERP
- `trytond-auth-keycloak` solo necesita `bos_erp_mask` — nunca vio ni verá los bits VDI
- La confusión de numeración desaparece: cada máscara tiene su propio espacio de bits comenzando en 0

**Mapa VDI corregido para `025-VDI §7` con multi-mask:**

```
BOS_VDI_MASK — uint64 independiente (evaluado por banexus)
Bit 0:  SESSION_VALID      — sesión activa y autenticada
Bit 1:  SHELL_UNLOCK       — desbloquear shell de Fedora KDE
Bit 2:  APP_TRYTON         — acceso a Tryton en el escritorio
Bit 3:  APP_ORANGEHRM      — acceso a OrangeHRM en el escritorio
Bit 4:  APP_SALEOR         — acceso a Saleor en el escritorio
Bit 5:  DRAWER_OPEN        — activar relé cajón de dinero ← bit 5 aquí es SEGURO
Bit 6:  DOOR_ZONE_A        — abrir puertas Zona A
Bit 7:  DOOR_ZONE_B        — abrir puertas Zona B
Bit 8:  DOOR_ZONE_C        — abrir puertas Zona C (restringida)
Bit 9:  PRINT_ALLOWED      — imprimir documentos físicos
Bit 10: USB_STORAGE        — acceso USB almacenamiento
Bit 11: NETWORK_EXTERNAL   — acceso internet externo
Bit 12: VPN_ACCESS         — VPN corporativa
Bit 13: ADMIN_PANEL        — panel administración
Bit 14: APP_FIREFOX        — navegador web
Bit 15: APP_LIBREOFFICE    — suite ofimática
Bit 16: APP_THUNDERBIRD    — cliente de correo
Bit 17: BOS_CAJA_APERTURA  — operación caja: apertura
Bit 18: BOS_CAJA_CIERRE    — operación caja: cierre
Bit 19: BOS_CAJA_ARQUEO    — operación caja: arqueo
Bit 63: ADMIN_LOCAL        — privilegios admin local (bit reservado alto)

Bits 20–62: RESERVADOS para extensión de hardware (zonas, sensores, actuadores)
```

```
BOS_ERP_MASK — uint64 independiente (evaluado por trytond-auth-keycloak)
Bit 0: PERM_VIEW     — Lectura en Tryton
Bit 1: PERM_EDIT     — Escritura en Tryton
Bit 2: PERM_PRINT    — Impresión de reportes
Bit 3: PERM_DELETE   — Eliminación de registros
Bit 4: PERM_EXPORT   — Exportación de datos
Bit 5: PERM_IMPORT   — Importación de datos ← bit 5 aquí NO es DRAWER_OPEN
Bit 6: PERM_CONFIG   — Configuración del sistema
Bit 7: PERM_SHARE    — Compartir registros
Bit 8: PERM_BACKUP   — Disparar backup manual
Bit 9: PERM_ARCHIVE  — Archivar registros
Bits 10–63: RESERVADOS para módulos ERP adicionales (manufactura, proyectos, etc.)
```

Con esta separación, la colisión crítica entre `PERM_IMPORT (bit 5 en ERP)` y `DRAWER_OPEN (bit 5 en VDI)` desaparece estructuralmente — son dos enteros diferentes. No hay forma de que colisionen.

---

### 2.4 IMPLEMENTACIÓN CORRECTA DE SEGREGACIÓN DE FUNCIONES (SoD) PARA SBOS

**Reemplaza la propuesta XOR del SAM-128. Alineado con ISACA, ISO 27001 A.5.3, NIST SP 800-53 AC-5.**

La SoD en el SBOS se implementa en tres capas, ninguna de ellas en el operador XOR:

**Capa 1 — Conflict Matrix en RolTemplate (prevención en asignación):**

```yaml
# En el RolTemplate, sección sod_rules (ya existe en SBOS-022-IDENTITY-CONTRACTS §7)
sod_rules:
  - action: "approve_payment"         # No puede el mismo usuario
    cannot_also: "create_payment"     # que crea también aprobar
  - action: "post_invoice"            # No puede el mismo usuario
    cannot_also: "receive_payment"    # que factura también cobrar
  - action: "payroll_input"           # Principio de 4 ojos
    cannot_also: "payroll_approve"
```

bAuth verifica esta matriz cuando un usuario intenta asumir un segundo rol. Si hay conflicto, requiere aprobación del administrador con justificación documentada.

**Capa 2 — Button Rules en Tryton (enforcement en operación):**

Ya documentado en `021-DAEMON-BAUTH §9 Capa 4`. Las Button Rules ya implementan SoD a nivel de acción individual. Este es el mecanismo correcto y ya existe.

**Capa 3 — Session Context Switch (selección de identidad):**

El concepto del SAM-128 de "el usuario debe elegir qué identidad usar" sí es correcto como concepto — pero se implementa como **Session Context Switch**, no como XOR:

```go
// SwitchContext — el usuario activa un contexto de trabajo diferente
// (análogo al "sudo" de Linux o al "Run As" de Windows)
type SessionContext struct {
    ActiveRole    string   // rol activo en este momento
    InactiveRoles []string // roles disponibles pero no activos
    SoDViolations []string // roles que NO puede activar simultáneamente
}

// Cuando un usuario activa ROL_AUDITOR teniendo ROL_CAJERO activo:
// 1. bAuth verifica la Conflict Matrix
// 2. Si hay conflicto: desactiva ROL_CAJERO automáticamente
// 3. Activa ROL_AUDITOR y recalcula la BitmaskBundle
// 4. Registra el cambio de contexto en bauth_db.access_log
// 5. banexus recibe policy_update y recalcula los permisos físicos
```

---

### 2.5 IMPLEMENTACIÓN CORRECTA DEL KILL SWITCH (REVOCACIÓN DE EMERGENCIA)

**Reemplaza la propuesta NAND del SAM-128. Operador correcto: AND NOT.**

El mecanismo existente en SBOS (`RevokeBit` usando `&^`) es correcto. Lo que el SAM-128 intenta añadir —una revocación masiva de capacidades específicas en toda una empresa— ya tiene el operador correcto disponible. Solo necesita la formalización del proceso:

```go
// EmergencyRevoke — revoca bits específicos en TODOS los usuarios de un realm
// Se aplica en respuesta a una brecha de seguridad o incidente P0
// Operador: AND NOT (&^), NO NAND
func EmergencyRevoke(realmID string, bitsToRevoke BitmaskBundle) error {
    // 1. Aplicar a la caché Redis (efecto inmediato < 1s)
    for _, userID := range getAllActiveUsersInRealm(realmID) {
        currentMask := getFromCache(userID)
        newMask := BitmaskBundle{
            VDIMask: currentMask.VDIMask &^ bitsToRevoke.VDIMask,
            ERPMask: currentMask.ERPMask &^ bitsToRevoke.ERPMask,
        }
        setInCache(userID, newMask)
    }

    // 2. Notificar a bhnexus para que invalide cache en todos los nodos banexus
    notifyBhnexus(realmID, PolicyUpdate{Action: "emergency_revoke", AffectedBits: bitsToRevoke})

    // 3. Registrar en bauth_db con severidad CRITICAL para ISO 27001
    logAuditEvent(AuditEvent{
        EventType: "emergency_revoke",
        RealmID:   realmID,
        Bits:      bitsToRevoke,
        Operator:  "AND_NOT", // explícito para auditoría
        Timestamp: time.Now(),
    })

    return nil
}
```

**Verificación matemática del AND NOT:**
```
Mask_User = 0b0100  (usuario tiene solo el bit 2)
KillSwitch = 0b0010  (queremos revocar el bit 1)
Resultado = 0b0100 &^ 0b0010 = 0b0100

✅ Correcto: el usuario conserva exactamente lo que tenía,
   el bit que no tenía permanece no asignado.
```

---

### 2.6 EL SUPERUSUARIO "FANTASMA" — ESTA PARTE DEL SAM-128 ES CORRECTA Y DEBE IMPLEMENTARSE

El concepto de que el Superusuario (Ivan Villanueva) no tiene bits activos por defecto y debe realizar una "Asunción de Contexto" para actuar es excelente desde el punto de vista de seguridad. Se alinea con el Principle of Least Privilege (NIST SP 800-53 AC-6) y con el concepto de "Zero Standing Privileges" de CyberArk y otros sistemas PAM (Privileged Access Management).

**Implementación como "Asunción de Contexto" en bAuth:**

```go
// AssumeTenantContext — Ivan asume el contexto de una empresa específica
// para ejecutar una operación administrativa
// Requisitos:
//   1. Solo Ivan Villanueva (sbos-admin) puede llamar esto
//   2. Se registra en bauth_db con timestamp y razón
//   3. El contexto expira automáticamente en X minutos (configurable)
//   4. Genera alerta en Wazuh SIEM (ISO 27001 A.8.15)
func (b *BAuth) AssumeTenantContext(adminUserID string, realmID string, reason string, durationMinutes int) (*TenantContext, error) {
    // Verificar que es efectivamente sbos-admin
    if !b.isGlobalAdmin(adminUserID) {
        return nil, ErrNotAuthorized
    }

    // Generar BitMask Maestro temporal solo para ese realm
    // 2^128 - 1 o, con multi-mask: todos los bits de todas las máscaras activos
    masterMask := BitmaskBundle{
        VDIMask: ^uint64(0), // todos los bits activos
        ERPMask: ^uint64(0),
    }

    ctx := &TenantContext{
        AdminID:    adminUserID,
        RealmID:    realmID,
        Mask:       masterMask,
        Reason:     reason,
        ExpiresAt:  time.Now().Add(time.Duration(durationMinutes) * time.Minute),
        ContextID:  uuid.New().String(),
    }

    // Log inmutable (ISO 27001 A.8.15 — logs inalterables)
    b.auditLog.Write(AuditEvent{
        EventType:  "superuser_context_assumed",
        AdminID:    adminUserID,
        RealmID:    realmID,
        Reason:     reason,
        ContextID:  ctx.ContextID,
        ExpiresAt:  ctx.ExpiresAt,
        Timestamp:  time.Now(),
        Severity:   "HIGH", // Wazuh alerta automáticamente para HIGH
    })

    return ctx, nil
}
```

---

### 2.7 PLAN DE IMPLEMENTACIÓN FASEADO — ALINEADO CON EL ROADMAP SBOS

| Fase | Versión SBOS | Acción | Entregable |
|---|---|---|---|
| **Fase 0 — Ahora** | Pre-v0.9 | Resolver la inconsistencia de numeración (025-VDI vs Tabla Maestra) separando VDI y ERP en masks independientes | `bitmask_constants.go` con las dos máscaras separadas |
| **Fase 1 — v0.9 Beta** | Jul 2026 | Multi-mask en JWT: `bos_vdi_mask` + `bos_erp_mask` en lugar del único `bos_bitmask` | Migración de `021-BAUTH §8` y `025-VDI §7` |
| **Fase 2 — v1.0 GA** | Sep 2026 | Conflict Matrix para SoD en asignación de roles | Extensión de `022-IDENTITY-CONTRACTS §4` + validación en bAuth |
| **Fase 3 — v1.5** | Dic 2026 | `AssumeTenantContext` para Superusuario + EmergencyRevoke formal | Extensión de bAuth + runbook RK-016 |
| **Fase 4 — v2.0** | 2027 | Evaluar si se necesita `bos_integration_mask` + `bos_custom_mask` según demanda real | ADR nuevo si se implementa |

---

### 2.8 ARCHIVOS A MODIFICAR Y DESCRIPCIÓN DE LOS CAMBIOS

| Archivo | Cambio | Prioridad |
|---|---|---|
| `021-DAEMON-BAUTH §8` | Reemplazar "Tabla Maestra 64-bit" por "BitmaskBundle: VDIMask + ERPMask". Deprecar `bos_bitmask` como claim único. | CRÍTICO |
| `025-VDI §7` | Actualizar mapa de bits para que `bos_vdi_mask` comience en Bit 0 (ya no hay colisión con ERP) | CRÍTICO |
| `022-IDENTITY-CONTRACTS §5` | Añadir sección de Conflict Matrix (sod_rules en RolTemplate) | ALTO |
| `021-DAEMON-BAUTH §10` | Actualizar tabla SoD para que use Conflict Matrix en lugar de XOR | ALTO |
| `032-OPERATIONS §7` | Añadir RK-016 "EmergencyRevoke" como runbook formal | MEDIO |
| `010-GOVERNANCE §7` | Documentar proceso de Asunción de Contexto del Superusuario | MEDIO |

---

## PARTE 3: CÓDIGO DE REFERENCIA COMPLETO

### 3.1 bitmask_constants.go — Fuente canónica única

```go
// Package bitmask define el registro canónico de bits del SBOS.
// ESTA ES LA ÚNICA FUENTE DE VERDAD.
// Todos los componentes (banexus, bhnexus, trytond-auth-keycloak)
// deben referenciar estas constantes, nunca valores enteros literales.
//
// Referencia documental: SBOS-021-DAEMON-BAUTH §8, SBOS-025-VDI §7
// Custodio: Ivan Villanueva (ARB)
// Versión: 2.0 (migración a BitmaskBundle)
package bitmask

// ============================================================
// VDI MASK — bos_vdi_mask en JWT
// Evaluado por: banexus (edge sentinel en Fedora KDE)
// Tipo: uint64
// ============================================================
const (
    // Sesión y autenticación
    SESSION_VALID    = uint64(1 << 0)  // sesión activa
    SHELL_UNLOCK     = uint64(1 << 1)  // desbloquear shell KDE

    // Aplicaciones de escritorio autorizadas
    APP_TRYTON       = uint64(1 << 2)  // acceso a Tryton
    APP_ORANGEHRM    = uint64(1 << 3)  // acceso a OrangeHRM
    APP_SALEOR       = uint64(1 << 4)  // acceso a Saleor
    APP_FIREFOX      = uint64(1 << 14) // navegador web
    APP_LIBREOFFICE  = uint64(1 << 15) // suite ofimática
    APP_THUNDERBIRD  = uint64(1 << 16) // cliente de correo

    // Hardware y actuadores físicos
    DRAWER_OPEN      = uint64(1 << 5)  // relé cajón de dinero
    DOOR_ZONE_A      = uint64(1 << 6)  // puertas Zona A
    DOOR_ZONE_B      = uint64(1 << 7)  // puertas Zona B
    DOOR_ZONE_C      = uint64(1 << 8)  // puertas Zona C (restringida)
    PRINT_ALLOWED    = uint64(1 << 9)  // impresión física
    USB_STORAGE      = uint64(1 << 10) // almacenamiento USB
    NETWORK_EXTERNAL = uint64(1 << 11) // internet externo
    VPN_ACCESS       = uint64(1 << 12) // VPN corporativa
    ADMIN_PANEL      = uint64(1 << 13) // panel de administración

    // Operaciones de caja
    BOS_CAJA_APERTURA = uint64(1 << 17) // apertura de caja
    BOS_CAJA_CIERRE   = uint64(1 << 18) // cierre de caja
    BOS_CAJA_ARQUEO   = uint64(1 << 19) // arqueo de caja

    // Administración local (bit reservado alto)
    ADMIN_LOCAL = uint64(1 << 63) // privilegios admin local
)

// ============================================================
// ERP MASK — bos_erp_mask en JWT
// Evaluado por: trytond-auth-keycloak (Tryton SPI)
// Tipo: uint64
// ============================================================
const (
    PERM_VIEW    = uint64(1 << 0) // lectura en Tryton
    PERM_EDIT    = uint64(1 << 1) // escritura en Tryton
    PERM_PRINT   = uint64(1 << 2) // impresión de reportes
    PERM_DELETE  = uint64(1 << 3) // eliminación de registros
    PERM_EXPORT  = uint64(1 << 4) // exportación de datos
    PERM_IMPORT  = uint64(1 << 5) // importación de datos
    PERM_CONFIG  = uint64(1 << 6) // configuración del sistema
    PERM_SHARE   = uint64(1 << 7) // compartir registros
    PERM_BACKUP  = uint64(1 << 8) // backup manual
    PERM_ARCHIVE = uint64(1 << 9) // archivar registros
    // Bits 10–63: reservados para módulos ERP adicionales
)

// ============================================================
// BitmaskBundle — reemplaza el claim único bos_bitmask
// ============================================================
type BitmaskBundle struct {
    VDIMask uint64 `json:"bos_vdi_mask"`
    ERPMask uint64 `json:"bos_erp_mask"`
}

// HasVDIPermission verifica si la VDI mask tiene un bit activo.
// Usar siempre con constantes VDI (SESSION_VALID, DRAWER_OPEN, etc.)
func (b BitmaskBundle) HasVDIPermission(bit uint64) bool {
    return b.VDIMask&bit != 0
}

// HasERPPermission verifica si la ERP mask tiene un bit activo.
// Usar siempre con constantes ERP (PERM_VIEW, PERM_IMPORT, etc.)
func (b BitmaskBundle) HasERPPermission(bit uint64) bool {
    return b.ERPMask&bit != 0
}

// InheritFromParent — AND NOT: el hijo hereda la máscara del padre
// menos los bits que se quitan explícitamente.
// Esta es la operación de herencia de roles (no XOR, no NAND).
func InheritFromParent(parentBundle, bitsToRemove BitmaskBundle) BitmaskBundle {
    return BitmaskBundle{
        VDIMask: parentBundle.VDIMask &^ bitsToRemove.VDIMask,
        ERPMask: parentBundle.ERPMask &^ bitsToRemove.ERPMask,
    }
}

// MergeRoles — OR: combina dos roles activos simultáneamente.
// El resultado es la unión de todos los permisos.
// NOTA: MergeRoles NO verifica conflictos SoD. La verificación
// debe hacerse ANTES con la Conflict Matrix en bAuth.
func MergeRoles(a, b BitmaskBundle) BitmaskBundle {
    return BitmaskBundle{
        VDIMask: a.VDIMask | b.VDIMask,
        ERPMask: a.ERPMask | b.ERPMask,
    }
}

// RevokeEmergency — AND NOT: revoca bits específicos de forma inmediata.
// Operador correcto para KillSwitch (NO NAND, que puede elevar privilegios).
func RevokeEmergency(current, toRevoke BitmaskBundle) BitmaskBundle {
    return BitmaskBundle{
        VDIMask: current.VDIMask &^ toRevoke.VDIMask,
        ERPMask: current.ERPMask &^ toRevoke.ERPMask,
    }
}
```

### 3.2 Ejemplo de Conflict Matrix para SoD

```go
// sod_conflict_matrix.go
// Referencia: ISACA Journal 2016, ISO 27001 A.5.3, NIST SP 800-53 AC-5
type SoDConflict struct {
    RoleA       string
    RoleB       string
    Description string
    Severity    string // "critical" | "warning"
    Resolution  string // "deny" | "approve_required" | "notify_only"
}

var DefaultSoDConflicts = []SoDConflict{
    {
        RoleA:       "ROL_CAJERO",
        RoleB:       "ROL_AUDITOR_CAJA",
        Description: "El mismo usuario no puede abrir caja y auditar caja",
        Severity:    "critical",
        Resolution:  "deny",
    },
    {
        RoleA:       "ROL_CONTABILIDAD_INPUT",
        RoleB:       "ROL_CONTABILIDAD_APROBADOR",
        Description: "Segregación contable: quien registra no puede aprobar",
        Severity:    "critical",
        Resolution:  "deny",
    },
    {
        RoleA:       "ROL_COMPRAS_SOLICITUD",
        RoleB:       "ROL_COMPRAS_APROBACION",
        Description: "Quien solicita no puede aprobar sus propias compras",
        Severity:    "critical",
        Resolution:  "deny",
    },
    {
        RoleA:       "ROL_NOMINA_INPUT",
        RoleB:       "ROL_NOMINA_APROBACION",
        Description: "Segregación de nómina: 4 ojos obligatorio",
        Severity:    "critical",
        Resolution:  "deny",
    },
}

// CheckSoDViolation verifica si asignar roleB a un usuario que ya tiene roleA
// viola alguna regla de la Conflict Matrix.
func CheckSoDViolation(existingRoles []string, newRole string) (*SoDConflict, bool) {
    for _, conflict := range DefaultSoDConflicts {
        for _, existing := range existingRoles {
            if (existing == conflict.RoleA && newRole == conflict.RoleB) ||
               (existing == conflict.RoleB && newRole == conflict.RoleA) {
                return &conflict, true
            }
        }
    }
    return nil, false
}
```

---

## PARTE 4: CRITERIOS DE VALIDACIÓN PARA JUAN PÉREZ (ADMINISTRADOR DE DOMINIOS)

Cada criterio puede ser validado con la ayuda del Auth-Agent sin requerir intervención del Super Usuario.

```bash
# VALIDACIÓN 1: Verificar que banexus usa constantes simbólicas (no literales enteros)
# Causa raíz: la inconsistencia de numeración original venía de literales en el código
grep -r "HasPermission\|HasVDIPermission" /opt/bos/banexus/ | grep -v "_test.go"
# Resultado esperado: todas las llamadas usan constantes (SESSION_VALID, DRAWER_OPEN, etc.)
# NO debe aparecer: HasPermission(mask, 5) o HasPermission(mask, 15) sin constante

# VALIDACIÓN 2: Verificar que el JWT de un cajero tiene los campos correctos
# Con la nueva arquitectura multi-mask debe tener bos_vdi_mask Y bos_erp_mask
TOKEN=$(bosctl bauth get-token <user_id_cajero>)
echo $TOKEN | jq -R 'split(".")[1] | @base64d | fromjson | {vdi: .bos_vdi_mask, erp: .bos_erp_mask}'
# Resultado esperado: dos campos numéricos independientes

# VALIDACIÓN 3: Verificar que DRAWER_OPEN y PERM_IMPORT están en máscaras diferentes
# y que no hay colisión posible
echo "VDI DRAWER_OPEN bit:" $(python3 -c "print(bin(1 << 5))")
echo "ERP PERM_IMPORT bit:" $(python3 -c "print(bin(1 << 5))")
echo "Son el mismo bit DENTRO de su máscara, pero son máscaras DIFERENTES: OK"
# El Auth-Agent puede verificar esto en el código de bitmask_constants.go

# VALIDACIÓN 4: Test de KillSwitch con AND NOT (no NAND)
# Simular revocación de DRAWER_OPEN sin afectar SESSION_VALID
go test ./bauth/bitmask/... -run TestRevokeEmergency -v
# Resultado esperado: PASS — SESSION_VALID permanece activo tras revocar DRAWER_OPEN

# VALIDACIÓN 5: Test de Conflict Matrix
go test ./bauth/sod/... -run TestSoDConflict -v
# Resultado esperado: PASS — ROL_CAJERO + ROL_AUDITOR_CAJA = DENY

# VALIDACIÓN 6: Verificar que el Superusuario no tiene bits activos por defecto
bosctl bauth get-bitmask <ivan_villanueva_user_id>
# Resultado esperado: bos_vdi_mask=0x0 y bos_erp_mask=0x0
# Los bits solo se activan durante una AssumeTenantContext activa
```

---

## CONCLUSIÓN

El Protocolo SAM-128 tiene valor conceptual real en tres áreas: la arquitectura de 6 capas de aislamiento, el Superusuario sin bits por defecto, y la idea de cuadrantes para organizar permisos. Estas contribuciones deben preservarse y adaptarse al SBOS.

Sin embargo, los mecanismos técnicos propuestos (XOR para SoD, NAND para KillSwitch, AVX-512 para rendimiento) son incorrectos y deben ser reemplazados por los operadores estándar ya implementados en el SBOS: AND NOT para herencia y revocación, OR para agregación de roles, y una Conflict Matrix para Segregación de Funciones.

La solución al GAP CRÍTICO-1 no requiere cambiar el tamaño del entero a 128 bits. Requiere separar los dominios VDI y ERP en dos máscaras `uint64` independientes (BitmaskBundle), eliminando estructuralmente la posibilidad de colisión. Este diseño es más limpio, más legible, más extensible, y alineado con las mejores prácticas de la industria (Clerk, DreamFactory, SailPoint).

---

_SKULL · SBOS · BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO · Abril 2026 · v1.0_
_Arquitecto: Principal Systems Architect_
