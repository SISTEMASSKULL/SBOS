# MANUAL DE SISTEMA DE ADMINISTRACIÓN DE PRIVILEGIOS
## Método de Identificación y Combinación de Átomos de Permiso
### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Junio 2026

---

**Clasificación:** Confidencial — Propiedad de SKULL Desarrollo de Software  
**Código:** SBOS-MANUAL-PRIVILEGIOS-v1.0  
**Complementa:** SBOS-008-001, SBOS-BAUTH-DOMAIN-CONTROL-METHODOLOGY  
**Estado:** Vigente

---

## TABLA DE CONTENIDOS

1. Introducción y propósito
2. El problema que este método resuelve
3. Conceptos fundamentales
4. Estructura del BitMask Átomo (64 bits)
5. El Rol BitMask — combinación de roles
6. Motor de resolución — reglas de operación
7. Dominios de soberanía y su activación
8. Ciclo de vida de un átomo
9. Guía de operaciones para el administrador
10. Casos de estudio
11. Estándares de conformidad
12. Glosario
13. Apéndice — tablas de referencia

---

## 1. INTRODUCCIÓN Y PROPÓSITO

### 1.1 Propósito del documento

Este manual define el **Método de Identificación y Combinación de Átomos de Permiso** — el sistema mediante el cual SBOS representa, almacena, evalúa y combina privilegios de acceso en entornos multiempresariales y multi-aplicación.

El método responde a una pregunta concreta: ¿cómo representar privilegios sobre un catálogo abierto y creciente de acciones, sin límite de tamaño predefinido, de forma que sea computable en tiempo de ejecución, segura ante combinaciones de roles, y auditable sin ambigüedad?

### 1.2 Alcance

Este manual aplica a:

- Toda aplicación ficha registrada en SBOS que declare átomos de permiso.
- Todo rol definido en un RolTemplate de bAuth.
- Todo proceso de evaluación de acceso ejecutado por bAuth, bhnexus o Kong.
- Todo administrador que asigne, delegue o audite privilegios en el Core UI.

### 1.3 Lo que este método NO es

Este método no reemplaza la autenticación — eso es responsabilidad de Keycloak. No sustituye las políticas contextuales de red, tiempo o geolocalización — esas son responsabilidad de los evaluadores de dominio de bAuth. Este método define exclusivamente cómo se representa y combina **qué puede hacer** un usuario, una vez que ya se determinó que es quien dice ser y que su sesión es válida.

---

## 2. EL PROBLEMA QUE ESTE MÉTODO RESUELVE

### 2.1 El límite de los BitMask de banderas clásicos

El enfoque clásico asigna un bit fijo a cada permiso:

```
Bit 0: leer      → 1 = permitido, 0 = denegado
Bit 1: escribir  → 1 = permitido, 0 = denegado
Bit 2: imprimir  → 1 = permitido, 0 = denegado
...
Bit N: acción N
```

Este modelo tiene un techo duro: el número de permisos está limitado al ancho del registro (8, 16, 32 o 64 bits). Cuando el catálogo de acciones supera ese techo — como ocurre en una plataforma con 110+ aplicaciones fichas, cada una con decenas de acciones propias — el modelo colapsa sin solución estructural. No hay forma de añadir la acción 65 a un registro de 64 bits sin rediseñar toda la estructura.

### 2.2 El error de combinar identificadores con bitwise

Un segundo problema emerge cuando se intenta combinar permisos de múltiples roles con operaciones bitwise directas sobre los identificadores de acción. La prueba concreta:

```
Catálogo de verbos:   nuevo = 1,  editar = 2,  eliminar = 3

Rol Contador Senior tiene: Plan de Cuentas.nuevo  → código átomo = 1
                            Plan de Cuentas.editar → código átomo = 2
                            Comprobantes.nuevo     → código átomo = 1
                            Comprobantes.editar    → código átomo = 2

OR bitwise acumulado: 1 OR 2 OR 1 OR 2 = 3

Pero "3" en el catálogo es "eliminar" — un permiso que nadie otorgó.
```

El resultado no es absurdo ni detectable fácilmente: es un código de átomo **válido, existente, y silenciosamente incorrecto**. Produce escalamiento de privilegios que pasa revisiones superficiales porque está dentro del rango esperado.

### 2.3 Raíz del error: confundir el identificador con la bandera

Ambos problemas tienen la misma raíz: usar el mismo número para dos propósitos distintos.

| Propósito | Tipo de codificación | Comportamiento ante bitwise |
|---|---|---|
| **Identificar** un átomo específico (qué acción es) | Label encoding — número secuencial compartido | Peligroso — OR/AND producen otros identificadores válidos |
| **Combinar** átomos entre roles (quién tiene qué) | One-hot encoding — un bit independiente por átomo | Correcto — OR/AND operan sobre bits independientes |

La solución es usar **dos estructuras separadas**: una para identificar, otra para combinar. Nunca la misma estructura para ambas cosas.

---

## 3. CONCEPTOS FUNDAMENTALES

### 3.1 Átomo

La unidad mínima e indivisible de permiso en SBOS. Un átomo representa una acción específica, sobre una entidad específica, dentro de un grupo específico de una aplicación específica, en un dominio de soberanía específico.

Un átomo no es un verbo genérico ("crear", "editar"). Es la combinación completa:

```
Tryton . Comprobantes . nuevo
└─app──┘ └───grupo────┘ └verb┘

OrangeHRM . Empleados . editar
└──app────┘ └─grupo───┘ └verb┘
```

Ambas acciones usan el verbo "nuevo" o "editar", pero son átomos distintos porque la entidad (Comprobantes vs. Empleados) y la aplicación (Tryton vs. OrangeHRM) son distintas. La unicidad no la da el verbo — la da la combinación completa `(Dominio, Aplicación, Grupo, Átomo)`.

### 3.2 Vocabulario de verbos (fijo y global)

Los verbos son un conjunto cerrado y global. El mismo código de verbo tiene el mismo significado en cualquier app, grupo o dominio:

| Verbo | Código |
|---|---|
| nuevo | 1 |
| editar | 2 |
| eliminar | 3 |
| ver | 4 |

Este vocabulario es extensible por decisión arquitectural, no por cada tenant ni cada aplicación. Cuando un verbo nuevo se añade al catálogo global, se le asigna el siguiente código disponible y se documentan sus implicaciones en todos los dominios.

### 3.3 Rol

Un conjunto de átomos. Un rol no es un número — es una lista de tuplas `(Dominio, Aplicación, Grupo, Verbo)`. Dos roles se pueden combinar porque ambos son conjuntos; las operaciones aplicables son las de teoría de conjuntos (unión, intersección, diferencia), que se ejecutan eficientemente como bitwise sobre el Rol BitMask.

### 3.4 Dominio de soberanía

El contexto de evaluación al que pertenece un átomo. Hay 11 dominios (D1 a D11). El dominio determina si el bit del verbo es suficiente para conceder el acceso, o si además se requiere evaluar una política adicional (límite financiero, horario, geolocalización, etc.). Ver Sección 7 para el mapa completo.

---

## 4. ESTRUCTURA DEL BITMASK ÁTOMO (64 BITS)

### 4.1 Visión general

El BitMask Átomo es un número de 64 bits que **identifica un átomo específico** de forma compacta y sin ambigüedad. Es análogo a una dirección IPv4: no es una bandera de "sí/no" — es una dirección estructurada en campos que juntos apuntan a una acción única en el catálogo global.

```
┌─────────────────────────────────────────────────────────────────┐
│                    BitMask Átomo (64 bits)                      │
├───────────────────────────┬─────────────────────────────────────┤
│  Dominio Contextual       │  Dominio Lógico                     │
│       (32 bits)           │       (32 bits)                     │
├───────────────────────────┼─────────────────────────────────────┤
│ [8 res][4 dom][9 app][11  │ [6 res][2 pol][24 átomo]            │
│          grupo]           │                                     │
└───────────────────────────┴─────────────────────────────────────┘
```

### 4.2 Dominio Contextual (32 bits)

Identifica **dónde** vive el átomo: en qué dominio de soberanía, en qué aplicación, en qué grupo funcional.

| Campo | Bits | Posiciones | Capacidad |
|---|---|---|---|
| Reservado | 8 | 0–7 | 256 (extensión futura) |
| Dominio | 4 | 8–11 | 16 valores (cubre 11 dominios + 5 de margen) |
| Aplicación | 9 | 12–20 | 512 aplicaciones direccionables |
| Grupo | 11 | 21–31 | 2.048 grupos por aplicación |

**Lectura de campos mediante máscara:** al igual que IPv4 extrae la porción de red con una máscara de subred, cada campo del Dominio Contextual se lee con una máscara fija y un desplazamiento de bits:

```
Binario completo (32 bits): 00000000001100000000100000000010

Grupo      (bits 21-31): 00000000001  = 2   → Comprobantes
Aplicación (bits 12-20): 000000001    = 1   → Tryton
Dominio    (bits  8-11): 0011         = 3   → D3 (Financiero)
Reservado  (bits  0-7):  00000010     = 0   (sin asignar)
```

Este binario identifica sin consultar ninguna tabla externa: Tryton, Comprobantes, Dominio Financiero.

### 4.3 Dominio Lógico (32 bits)

Identifica **qué** hace el átomo: el verbo concreto y el estado de política al momento de la evaluación.

| Campo | Bits | Posiciones | Capacidad |
|---|---|---|---|
| Reservado | 6 | 0–5 | 64 (extensión futura) |
| Políticas | 2 | 6–7 | 4 estados: `00`=no aplica · `01`=pendiente · `10`=aprobado · `11`=rechazado |
| Átomo | 24 | 8–31 | 16.777.216 átomos por grupo |

El campo de **Políticas** (2 bits) no es un permiso — es el resultado de la evaluación de la política de dominio en el momento del acceso. Un átomo de D3 (Financiero) puede tener el verbo "aprobar" activo pero aún así recibir `01` (pendiente de doble firma) si el monto supera el umbral de dual-approval.

### 4.4 Capacidad total y por qué no se agota

```
Dominio Contextual:
  512 aplicaciones × 2.048 grupos = 1.048.576 combinaciones app/grupo

Dominio Lógico:
  16.777.216 átomos por grupo

Total direccionable:
  1.048.576 × 16.777.216 = 17.592.186.044.416 átomos únicos en el catálogo global
```

El índice de átomo (24 bits) es **por grupo dentro de cada aplicación**, no global. Cada app nueva trae su propio presupuesto completo de 16.777.216 átomos por grupo — no compite por uno compartido. Con el catálogo más exigente estimado (10.000 átomos por grupo en una app del tamaño de Tryton completo), el margen es de 1.677×.

### 4.5 Ejemplo completo

```
Átomo: Tryton.Comprobantes.nuevo  (D3 Financiero)

Dominio Contextual:
  Reservado   (bits 0-7):  00000000
  Dominio     (bits 8-11): 0011        → D3
  Aplicación  (bits 12-20):000000001   → Tryton (código 1)
  Grupo       (bits 21-31):00000000010 → Comprobantes (código 2)
  → Contextual = 00000000 0011 000000001 00000000010
               = 00000000001100000000100000000010

Dominio Lógico:
  Reservado   (bits 0-5):  000000
  Políticas   (bits 6-7):  01          → pendiente aprobación D3
  Átomo       (bits 8-31): 000000000000000000000001 → código 1 (nuevo)
  → Lógico    = 000000 01 000000000000000000000001
              = 00000001000000000000000000000001

BitMask Átomo completo (uint64):
  0000000000110000000010000000001000000001000000000000000000000001
```

---

## 5. EL ROL BITMASK — COMBINACIÓN DE ROLES

### 5.1 Por qué el BitMask Átomo no se combina con bitwise

El BitMask Átomo usa label encoding: el número del átomo (nuevo=1, editar=2) no es independiente entre átomos — comparte espacio numérico. Aplicar OR/AND directamente sobre dos BitMask Átomo mezcla campos con significado posicional y produce identificadores de otros átomos, como se demostró en la Sección 2.2.

Las únicas operaciones válidas sobre un BitMask Átomo individual son:
- **Comparación de igualdad:** ¿es este exactamente el átomo X?
- **AND con máscara fija:** extraer el valor de un campo específico (Dominio, App, Grupo).

### 5.2 El Rol BitMask: one-hot encoding sobre el catálogo

Para combinar roles se usa una estructura separada: el **Rol BitMask**. En esta estructura, cada átomo del catálogo ocupa una posición de bit fija e independiente. Un rol se representa marcando con `1` las posiciones de los átomos que otorga.

```
Catálogo (posiciones fijas, orden inamovible):

Bit  0: Tryton.Plan de Cuentas.nuevo
Bit  1: Tryton.Plan de Cuentas.editar
Bit  2: Tryton.Plan de Cuentas.eliminar
Bit  3: Tryton.Comprobantes.nuevo
Bit  4: Tryton.Comprobantes.editar
Bit  5: Tryton.Comprobantes.eliminar
Bit  6: Tryton.Menú Plan de Cuentas.ver
Bit  7: Tryton.Menú Comprobantes.ver
Bit  8: OrangeHRM.Empleados.nuevo
Bit  9: OrangeHRM.Empleados.editar
Bit 10: Saleor.Catálogo.nuevo
Bit 11: Saleor.Catálogo.editar

Rol Contador Senior   (átomos 0,1,3,4): 000000011011
Rol Auxiliar Contable (átomos 1,7):     000010000010
```

Ahora sí, bitwise real entre los dos roles:

| Operación | Binario | Átomos resultantes |
|---|---|---|
| OR (unión) | `000010011011` | Cuentas.nuevo, Cuentas.editar, Comp.nuevo, Comp.editar, Menú Comp.ver |
| AND (intersección) | `000000000010` | Cuentas.editar (lo único común) |
| XOR (diferencia simétrica) | `000010011001` | Cuentas.nuevo, Comp.nuevo, Comp.editar, Menú Comp.ver |
| AND NOT (exclusión) | `000000011001` | Cuentas.nuevo, Comp.nuevo, Comp.editar (lo que Contador tiene y Auxiliar no) |

**El resultado es idéntico al de la teoría de conjuntos — y ahora sí es bitwise de verdad**, sin riesgo de escalamiento de privilegios.

### 5.3 Relación entre las dos estructuras

Las dos estructuras coexisten. Cada una tiene su propósito y no reemplaza a la otra:

| Estructura | Codificación | Tamaño | Para qué sirve |
|---|---|---|---|
| **BitMask Átomo** (64 bits) | Label encoding | Fijo: 64 bits | Identificar un átomo específico de forma compacta — almacenamiento, transmisión, decodificación |
| **Rol BitMask** (N bits) | One-hot encoding | Variable: 1 bit por átomo del catálogo | Combinar roles con AND/OR/XOR/AND NOT reales |

La Tabla 1 (catálogo de átomos con su BitMask Átomo de 64 bits) es la fuente de verdad sobre qué átomos existen. La Tabla 2 (Rol BitMask) se construye a partir de la Tabla 1: cada fila de la Tabla 1 se convierte en una posición de bit en la Tabla 2, usando su posición ordinal en el catálogo (no su número de átomo).

```
Proceso de construcción del Rol BitMask:

1. Tabla 1 = catálogo fijo de todos los átomos, en orden inamovible
2. Numerar cada fila: posición 0, 1, 2, ... N-1 (N = tamaño del catálogo)
3. Para cada rol: vector de N bits, poner 1 en la posición de cada átomo que otorga
4. Sobre ese vector, bitwise funciona correctamente: OR/AND/XOR/AND NOT
```

### 5.4 Escala del Rol BitMask

El tamaño del Rol BitMask crece con el catálogo, no con el número de usuarios ni de tenants. Si hoy hay 500 átomos declarados en todo el sistema, el Rol BitMask tiene 500 bits. Si mañana hay 1.200, tiene 1.200 bits. Este crecimiento es lineal, predecible, y no afecta la estructura del BitMask Átomo.

```
500 átomos  → 500 bits  ≈ 63 bytes por rol
5.000 átomos → 5.000 bits ≈ 625 bytes por rol
```

Para referencia: un JWT típico de Keycloak ya ocupa 2–8 KB. El Rol BitMask de 625 bytes es una fracción manejable dentro de ese presupuesto.

---

## 6. MOTOR DE RESOLUCIÓN — REGLAS DE OPERACIÓN

### 6.1 Evaluación de un acceso

Cuando un usuario intenta ejecutar una acción, el motor de resolución sigue esta secuencia:

```
SOLICITUD DE ACCESO
       │
       ▼
1. PLANO DE CONTEXTO (pre-BitMask)
   ¿Existe un ctx_id válido para esta sesión?
   NO → Denegar (la sesión no existe — sin BitMask que evaluar)
   SÍ → Continuar
       │
       ▼
2. FILTRO DE DOMINIO (Dominio Contextual, bits 0-10)
   ¿Está activo el dominio del átomo solicitado?
   NO → Denegar (el dominio no aplica a este contexto)
   SÍ → Continuar
       │
       ▼
3. VERIFICACIÓN DE ROL (Rol BitMask)
   ¿Tiene este rol el átomo solicitado (posición en 1)?
   NO → Denegar
   SÍ → Continuar
       │
       ▼
4. EVALUACIÓN DE POLÍTICA (si el dominio lo requiere)
   D1, D2: Sin política adicional → PERMITIDO
   D3: ¿El monto está dentro del límite? ¿Hay conflicto SoD? ¿Requiere dual-approval?
   D4: ¿La hora actual cae en el horario del rol?
   D6: ¿La ubicación es consistente con el último acceso? (umbral 900 km/h)
   D7: ¿La IP/red cumple la política de red del átomo?
   D10: ¿La delegación activa cubre este átomo y sigue vigente?
       │
       ▼
5. RESULTADO
   PERMITIDO → ejecutar acción + registrar en bauth_audit_events
   DENEGADO  → retornar error contextual + registrar intento
   PENDIENTE → solicitar step-up (MFA adicional, segunda firma, etc.)
```

### 6.2 Guía de operaciones sobre roles

La siguiente tabla define cuándo usar cada operación sobre el Rol BitMask:

| Operación | Objetivo | Cuándo usarla | Operandos |
|---|---|---|---|
| **OR** | Ampliar — unión de roles | Usuario cubre varios roles simultáneamente; urgencia administrativa; rol transitorio acumulativo | 2 o más |
| **AND** | Reducir al mínimo común — intersección estricta | Cobertura temporal de máxima sensibilidad: el usuario solo debe tener lo que ambos roles comparten | 2 o más |
| **AND NOT** | Reducir de forma selectiva — quitar un átomo específico | Suspender una capacidad puntual (ej. FINANCIAL_APPROVE durante una auditoría) sin tocar el resto del rol | Exactamente 2 (A sin B) |
| **XOR** | Auditoría — delta entre dos estados | Registrar qué cambió en una reasignación (qué se añadió y qué se quitó respecto al estado anterior) | Exactamente 2 |

**Regla para el administrador:**
- "¿Qué le doy?" → OR.
- "¿A qué lo reduzco si hay riesgo?" → AND (en bloque) o AND NOT (un átomo puntual).
- "¿Qué cambió y quedó registrado?" → XOR, y solo entre exactamente dos estados.

**Advertencia sobre XOR con 3+ roles:** XOR sobre 3 o más operandos produce **paridad**, no delta. Un bit queda en 1 si un número impar de los roles lo tiene — no si "cambió". XOR no se usa para combinar 3+ roles; solo para comparar exactamente 2 estados.

### 6.3 Reducción de privilegios por delegación

Cuando un usuario de mayor jerarquía cubre o delega a un rol de menor jerarquía, la operación correcta es AND:

```
delegated_mask = original_mask AND target_role_mask
```

El AND garantiza matemáticamente que el resultado nunca puede tener un bit que ninguno de los dos operandos tenía. Es imposible escalar privilegios con esta operación. El usuario delegado opera con el subconjunto de átomos que ambos roles tienen en común — nunca más.

**Ejemplos del principio:**

```
Gerente (1111) cubre a Cajero (0101):
  1111 AND 0101 = 0101   → opera exactamente como Cajero

Médico (1111) cubre a Enfermera (0011):
  1111 AND 0011 = 0011   → opera exactamente como Enfermera

Director RRHH (1111) cubre a Analista (0101):
  1111 AND 0101 = 0101   → opera exactamente como Analista
```

El principio es invariante: quien tiene más siempre queda reducido a lo que tiene el rol menor. Nunca al revés.

---

## 7. DOMINIOS DE SOBERANÍA Y SU ACTIVACIÓN

### 7.1 Los 11 dominios como bits de activación (Dominio Contextual, bits 0-10)

El Dominio Contextual no solo identifica a qué app y grupo pertenece un átomo — también indica, a través de sus bits de dominio, qué evaluadores deben activarse para procesar la solicitud.

```
Bit 0: D1  — Lógico (apps, roles, verbos)
Bit 1: D2  — Físico (puertas, zonas, hardware)
Bit 2: D3  — Financiero (límites, SoD, dual-approval)
Bit 3: D4  — Temporal (horarios, turnos, feriados)
Bit 4: D5  — Biométrico (huella, rostro, LoA)
Bit 5: D6  — Geoespacial (país, viaje imposible, jurisdicción)
Bit 6: D7  — Red (CIDR, VPN, protocolos)
Bit 7: D8  — Contexto de sesión (ctx_id, trazabilidad)
Bit 8: D9  — Credenciales (passwords, MFA, certificados)
Bit 9: D10 — Delegación (privilegios temporales, vigencia)
Bit 10: D11 — Auditoría (registro WORM, trazabilidad)
Bit 11: Reservado (futuro D12)
Bits 12-31: Sin asignar
```

Un dominio en 0 no significa "denegado" — significa "no aplica a este contexto, no se evalúa". Si el contexto de un usuario solo tiene D1 activo (acceso a apps), bAuth no consulta límites financieros (D3) ni geolocalización (D6) — la evaluación se reduce exactamente al subconjunto activo. Es un filtro de relevancia que elimina trabajo innecesario.

### 7.2 Política adicional por dominio

Que el Rol BitMask tenga el átomo en 1 es condición necesaria pero no siempre suficiente. Según el dominio del átomo, puede requerirse evaluar una política adicional antes de conceder el acceso:

| Dominio | ¿El verbo alcanza solo? | Política adicional |
|---|---|---|
| D1 — Lógico | Sí | — |
| D2 — Físico | Sí | — |
| D3 — Financiero | No | Monto vs. límite del rol; conflicto SoD; umbral dual-approval |
| D4 — Temporal | No | ¿La hora actual cae en el horario vigente del rol? |
| D5 — Biométrico | No aplica en este nivel | Resuelto antes, en Keycloak durante el login |
| D6 — Geoespacial | No | Ubicación vs. último registro; velocidad de viaje (umbral 900 km/h) |
| D7 — Red | No | IP vs. rango autorizado; VPN requerida; protocolo permitido |
| D8 — Contexto | No aplica en este nivel | Resuelto por la existencia del ctx_id |
| D9 — Credenciales | No aplica en este nivel | Resuelto antes, en Keycloak durante el login |
| D10 — Delegación | No | Vigencia de la delegación activa; alcance de átomos delegados |
| D11 — Auditoría | No evalúa — solo registra | El registro ocurre siempre, independientemente del resultado |

### 7.3 Átomos encadenados — dominios sin átomos propios

D4 (Temporal) y D6 (Geoespacial) no tienen átomos propios en el catálogo — no hay un botón "verificar horario" ni "verificar ubicación". Estos dominios se activan como **políticas encadenadas** a átomos de otros dominios.

El ejemplo fundamental es el átomo `sistema.sesion.ingresar` (D1):

```
Átomo:   sistema.sesion.ingresar
Dominio: D1

Políticas encadenadas (se evalúan siempre que este átomo se invoca):
  → POL-D6-VIAJE   — distancia/velocidad desde el último login conocido (umbral 900 km/h)
  → POL-D4-HORARIO — ¿la hora actual cae dentro del horario laboral del rol?
```

El resultado de cada política encadenada no es solo sí/no:

| Resultado de la política | Acción del sistema |
|---|---|
| Riesgo bajo — todo en orden | Acceso directo |
| Riesgo medio — fuera de horario pero ubicación normal | Solicitar verificación adicional (step-up) |
| Riesgo alto — viaje imposible | Bloqueo directo + alerta |

Este patrón es el mismo que implementa Microsoft Entra ID Conditional Access para el caso de viaje imposible geoespacial.

---

## 8. CICLO DE VIDA DE UN ÁTOMO

### 8.1 Alta del átomo (momento administrativo, único)

El alta de un átomo es una operación CRUD sobre el catálogo. Ocurre **una sola vez**, cuando la aplicación ficha se registra en SBOS o cuando se añade una funcionalidad nueva. No ocurre en tiempo de ejecución.

```
Proceso de alta:
1. El desarrollador de la app declara el átomo en el manifiesto de la ficha:
   { "atom_id": "comprobantes.nuevo", "domain": "D3", "group": "Comprobantes" }

2. bAuth registra el átomo en el catálogo con su índice posicional y su BitMask Átomo de 64 bits.

3. El átomo aparece en el Core UI como una fila en la tabla de permisos de esa app,
   con un checkbox por rol: sin marcar = denegado por defecto.

4. Si el átomo pertenece a D3, D4, D6, D7, o D10: su alta activa el bit del dominio
   correspondiente en el Dominio Contextual de esa app/contexto.
```

### 8.2 Asignación a un rol (momento administrativo, repetible)

```
1. El administrador abre Core UI → Roles → selecciona el rol.
2. Selecciona la app y ve la tabla de átomos con checkboxes.
3. Marca o desmarca cada átomo.
4. Al guardar: bAuth actualiza el Rol BitMask del rol (pone 1 o 0 en la posición del átomo).
5. El cambio se propaga a Keycloak (actualiza atributos del grupo KC) y a Tryton (ir.rule)
   en menos de 5 segundos, via el flujo de sincronización atómica de bAuth.
```

### 8.3 Evaluación en tiempo de ejecución (momento operativo, por cada acción)

```
1. El usuario presiona un botón en la app.
2. La app conoce el BitMask Átomo del botón (fijo, definido en el alta).
3. bAuth recibe: (ctx_id, BitMask Átomo del botón).
4. Consulta el Rol BitMask del rol del usuario.
5. Verifica la posición del átomo en el Rol BitMask.
6. Si aplica: evalúa la política del dominio.
7. Retorna: PERMITIDO / DENEGADO / PENDIENTE + registra en bauth_audit_events.
```

El botón no calcula nada — solo reporta su propio átomo. La decisión completa está en bAuth.

---

## 9. GUÍA DE OPERACIONES PARA EL ADMINISTRADOR

### 9.1 Asignar un rol a un usuario

Acción: marcar los átomos correspondientes en Core UI → el sistema construye el Rol BitMask automáticamente.

**Nunca** modificar el Rol BitMask directamente en base de datos. El Core UI es la única interfaz de asignación. Los cambios directos en BD no pasan por validación de SoD y no se propagan a KC/Tryton.

### 9.2 Cobertura temporal de un rol (urgencia)

Cuando un usuario necesita cubrir el rol de otro temporalmente:

```
Si el rol cubierto es de igual o mayor jerarquía:
  → Usar OR: el usuario acumula los átomos de ambos roles
  → Documentar en bos_delegation_log con valid_until explícito
  → Para bits de D3 o D2 críticos: activar revocación event-driven

Si el rol cubierto es de menor jerarquía (delegación hacia abajo):
  → Usar AND: el resultado es el mínimo común
  → El usuario opera exactamente con los átomos del rol menor
  → No puede "salirse" del rol que cubre, sin importar su rol propio
```

### 9.3 Suspensión de una capacidad específica durante auditoría

Para quitar un átomo puntual sin modificar el resto del rol:

```
mask_suspendida = rol_original AND NOT mascara_atomo_a_suspender

Ejemplo: suspender FINANCIAL_APPROVE durante auditoría interna
  original:   ...1... (FINANCIAL_APPROVE en posición 14)
  AND NOT:    ...0... → el usuario mantiene todo menos ese átomo
```

Registrar la suspensión en `bos_delegation_log` con el átomo afectado, la razón, y el `valid_until` de la suspensión.

### 9.4 Auditar qué cambió en una reasignación

Para registrar el delta exacto entre el estado anterior y el nuevo de un rol:

```
delta = estado_anterior XOR estado_nuevo

Los bits en 1 del resultado son exactamente los átomos que cambiaron
(se añadieron o se quitaron — XOR no distingue cuál es cuál).

Para saber qué se añadió y qué se quitó:
  añadidos = estado_nuevo AND NOT estado_anterior
  quitados = estado_anterior AND NOT estado_nuevo
```

Este delta se registra en `bauth_audit_events` junto con el administrador que realizó el cambio, el timestamp, y el ctx_id de la sesión administrativa.

---

## 10. CASOS DE ESTUDIO

Los siguientes casos ilustran los principios del método aplicados a escenarios de distintos sectores. En todos los casos, el patrón fundamental es el mismo: la combinación de roles usa operaciones de conjunto (AND/OR/AND NOT/XOR) sobre el Rol BitMask, y la reducción al mínimo privilegio se garantiza matemáticamente con AND.

### 10.1 Sistema hospitalario — médico cubriendo a enfermera

```
Rol Enfermera (Rol BitMask):
  Bit 0: read_basic     = 1
  Bit 1: write_notes    = 1
  Bit 2: view_history   = 0
  Bit 3: prescribe      = 0
  Bit 4: order_tests    = 1
  → 0b01011

Rol Médico (Rol BitMask):
  Bit 0: read_basic     = 1
  Bit 1: write_notes    = 1
  Bit 2: view_history   = 1
  Bit 3: prescribe      = 1
  Bit 4: order_tests    = 1
  → 0b11111

Médico cubriendo a Enfermera (AND):
  11111 AND 01011 = 01011

Resultado: el médico opera exactamente como enfermera.
No puede prescribir (bit 3 = 0), no puede ver historiales completos (bit 2 = 0).
Protege información sensible del paciente.
```

### 10.2 Sistema bancario — gerente cubriendo a cajero

```
Rol Cajero:           0b01010101  (view_balance, deposit, withdraw)
Rol Gerente Sucursal: 0b11110111  (todo lo anterior + transfer + create_account)

Gerente como Cajero (AND):
  11110111 AND 01010101 = 01010101

Resultado: el gerente opera como cajero.
No puede realizar transferencias. No puede abrir cuentas.
Previene riesgo financiero en operaciones de caja.
```

### 10.3 Centro de investigación — científico como técnico de laboratorio

```
Rol Técnico:          0b0011000101  (access_lab, use_basic_equipment, log_experiment)
Rol Científico:       0b1111111111  (todo + approve_test + handle_dangerous_materials)

Científico como Técnico (AND):
  1111111111 AND 0011000101 = 0011000101

Resultado: el científico no puede aprobar tests ni manejar materiales peligrosos.
Protege los protocolos de seguridad del laboratorio.
```

### 10.4 Sistema educativo — profesor asumiendo rol de estudiante

```
Rol Estudiante: 0b0000010001  (view_grades, submit_work)
Rol Profesor:   0b0111101111  (todo + edit_grades + create_exam)

Profesor como Estudiante (AND):
  0111101111 AND 0000010001 = 0000010001

Resultado: el profesor solo puede ver sus propias calificaciones y entregar trabajos.
No puede editar notas ni crear exámenes.
```

### 10.5 Sistema de RRHH — director como analista

```
Rol Analista RRHH:  0b0011100101  (view_basic, update_personal, generate_reports)
Rol Director RRHH:  0b1111111111  (todo + modify_salary + hire_fire)

Director como Analista (AND):
  1111111111 AND 0011100101 = 0011100101

Resultado: el director no puede modificar salarios ni contratar/despedir.
```

### 10.6 Plataforma de desarrollo — líder técnico como desarrollador junior

```
Rol Desarrollador Junior: 0b0001100101  (view_code, commit_code)
Rol Líder Técnico:        0b1111111111  (todo + create_branch + merge + deploy)

Líder como Junior (AND):
  1111111111 AND 0001100101 = 0001100101

Resultado: el líder no puede crear ramas, mergear ni desplegar.
Previene modificaciones no autorizadas en el pipeline.
```

### 10.7 Gestión de inventarios — gerente de logística como bodeguero

```
Rol Bodeguero:          0b0010110001  (view_inventory, register_entry, update_stock)
Rol Gerente Logística:  0b1111011111  (todo + approve_purchase + generate_reports)

Gerente como Bodeguero (AND):
  1111011111 AND 0010110001 = 0010110001

Resultado: el gerente no puede aprobar compras ni generar reportes en este contexto.
```

### 10.8 Plataforma de e-commerce — vendedor como cliente

```
Rol Cliente:  0b0000010001  (view_products, make_purchase)
Rol Vendedor: 0b0111101111  (todo + track_order + manage_inventory + generate_sales_report)

Vendedor como Cliente (AND):
  0111101111 AND 0000010001 = 0000010001

Resultado: el vendedor solo puede comprar. No accede a seguimiento de órdenes ni inventario.
```

### 10.9 Gestión de proyectos — gerente como miembro de equipo

```
Rol Miembro de Equipo: 0b0001100101  (view_project, update_tasks, log_hours)
Rol Gerente Proyecto:  0b1111111111  (todo + create_milestone + approve_budget)

Gerente como Miembro (AND):
  1111111111 AND 0001100101 = 0001100101

Resultado: el gerente no puede crear hitos ni aprobar presupuesto en este contexto.
```

### 10.10 Soporte técnico — nivel 2 como nivel 1

```
Rol Soporte Nivel 1: 0b0011000101  (view_ticket, update_status, log_interaction)
Rol Soporte Nivel 2: 0b1111011111  (todo + escalate_ticket + close_ticket)

Nivel 2 como Nivel 1 (AND):
  1111011111 AND 0011000101 = 0011000101

Resultado: el soporte nivel 2 no puede escalar tickets ni cerrarlos en este contexto.
Mantiene la jerarquía de soporte técnico.
```

---

## 11. ESTÁNDARES DE CONFORMIDAD

| Estándar | Aplicación en este método |
|---|---|
| **NIST SP 800-162** (ABAC Guide) | El modelo de átomo como tupla `(sujeto, objeto, operación, entorno)` es conforme con la definición ABAC de NIST. El Dominio Contextual codifica el objeto+entorno; el Dominio Lógico codifica la operación. |
| **NIST SP 800-53 Rev.5 AC-6** (Least Privilege) | La operación AND para delegación garantiza matemáticamente el principio de mínimo privilegio. El resultado nunca puede superar el mínimo de los dos operandos. |
| **OASIS XACML 3.0** | El motor de resolución (Sección 6.1) es compatible con la arquitectura PEP/PDP/PIP. El Rol BitMask actúa como pre-filtro del PEP antes de invocar el PDP para políticas de dominio. |
| **ISO/IEC 27001:2022 A.5.3** (SoD) | La verificación de conflictos SoD en D3 se ejecuta como paso obligatorio antes de conceder permisos financieros. La Conflict Matrix define los pares de átomos incompatibles. |
| **ISO/IEC 27001:2022 A.8.15** (Logs) | Cada evaluación de acceso, exitosa o fallida, se registra en `bauth_audit_events` con ctx_id obligatorio, timestamp, átomo evaluado, resultado, y evaluador de política invocado. |
| **SOX §404** (COSO) | El Conflict Matrix de SoD de D3 es el artefacto de control documentable y testeable requerido por SOX §404 para auditorías externas. |
| **NIST SP 800-207** (Zero Trust) | La evaluación por átomo en cada solicitud, con reevaluación de políticas contextuales, es conforme con el tenet de Zero Trust de "acceso por sesión, no por red". |

---

## 12. GLOSARIO

**Átomo:** Unidad mínima e indivisible de permiso. Representa una acción específica (verbo) sobre una entidad específica (grupo) dentro de una aplicación específica, en un dominio de soberanía.

**BitMask Átomo:** Número de 64 bits (32 Dominio Contextual + 32 Dominio Lógico) que identifica un átomo de forma única y compacta. Usa label encoding. No se combina con bitwise entre átomos distintos.

**Rol BitMask:** Vector de N bits (N = tamaño del catálogo) que representa el conjunto de átomos de un rol. Usa one-hot encoding. Sí se combina con OR/AND/XOR/AND NOT entre roles.

**Dominio Contextual:** Los 32 bits superiores del BitMask Átomo. Codifica: dominio de soberanía, aplicación, y grupo funcional del átomo.

**Dominio Lógico:** Los 32 bits inferiores del BitMask Átomo. Codifica: el verbo (átomo en 24 bits) y el resultado de la política de dominio (2 bits).

**Label encoding:** Codificación donde un número secuencial se asigna a cada categoría. Eficiente para almacenar e identificar — incorrecto para combinar con bitwise.

**One-hot encoding:** Codificación donde cada categoría tiene un bit independiente. Correcto para combinar con bitwise — el tamaño del vector crece con el número de categorías.

**Átomo encadenado:** Átomo que, al invocarse, activa automáticamente evaluaciones de políticas de dominios adicionales (ej: `sistema.sesion.ingresar` encadena D4 y D6).

**Dominio de soberanía:** Uno de los 11 contextos de evaluación de bAuth (D1 a D11). Determina si el verbo es suficiente o si se requiere política adicional.

**Mínimo privilegio (AND):** Operación que al combinar dos Rol BitMask produce el subconjunto de átomos comunes a ambos. Garantiza que la delegación nunca amplía privilegios.

**Conflict Matrix (SoD):** Tabla de pares de átomos incompatibles. Si un rol tiene ambos átomos de un par marcado como conflicto ALTO, el sistema bloquea la asignación.

**ctx_id:** Identificador de contexto de sesión. Su existencia en Redis es la precondición de cualquier evaluación de BitMask. Si no existe ctx_id, no hay BitMask que evaluar.

---

## 13. APÉNDICE — TABLAS DE REFERENCIA

### A. Tabla de átomos de referencia (catálogo mínimo inicial)

| Pos. | Aplicación | Grupo | Verbo | Dominio | BitMask Átomo Contextual (32 bits) |
|---|---|---|---|---|---|
| 0 | Tryton | Plan de Cuentas | nuevo | D1 | `00000000000100000000100000000001` |
| 1 | Tryton | Plan de Cuentas | editar | D1 | `00000000000100000000100000000001` |
| 2 | Tryton | Plan de Cuentas | eliminar | D1 | `00000000000100000000100000000001` |
| 3 | Tryton | Comprobantes | nuevo | D3 | `00000000001100000000100000000010` |
| 4 | Tryton | Comprobantes | editar | D3 | `00000000001100000000100000000010` |
| 5 | Tryton | Comprobantes | eliminar | D3 | `00000000001100000000100000000010` |
| 6 | Tryton | Menú Plan de Cuentas | ver | D1 | `00000000000100000000100000000011` |
| 7 | Tryton | Menú Comprobantes | ver | D1 | `00000000000100000000100000000100` |
| 8 | OrangeHRM | Empleados | nuevo | D1 | `00000000000100000001000000000001` |
| 9 | OrangeHRM | Empleados | editar | D1 | `00000000000100000001000000000001` |
| 10 | Saleor | Catálogo | nuevo | D1 | `00000000000100000001100000000001` |
| 11 | Saleor | Catálogo | editar | D1 | `00000000000100000001100000000001` |

### B. Vocabulario de verbos global

| Verbo | Código | Descripción |
|---|---|---|
| nuevo | 1 | Crear un registro nuevo de la entidad |
| editar | 2 | Modificar un registro existente de la entidad |
| eliminar | 3 | Eliminar un registro existente de la entidad |
| ver | 4 | Leer y visualizar un registro de la entidad |

### C. Códigos de dominio

| Dominio | Código | Requiere política adicional |
|---|---|---|
| D1 — Lógico | 1 | No |
| D2 — Físico | 2 | No |
| D3 — Financiero | 3 | Sí — límite, SoD, dual-approval |
| D4 — Temporal | 4 | Sí — horario vigente (encadenado) |
| D5 — Biométrico | 5 | Pre-login (KC) |
| D6 — Geoespacial | 6 | Sí — ubicación/velocidad (encadenado) |
| D7 — Red | 7 | Sí — CIDR, VPN, protocolo |
| D8 — Contexto | 8 | Pre-BitMask (ctx_id) |
| D9 — Credenciales | 9 | Pre-login (KC) |
| D10 — Delegación | 10 | Sí — vigencia y alcance |
| D11 — Auditoría | 11 | No evalúa — solo registra |

### D. Estados del campo Políticas (2 bits, posiciones 6-7 del Dominio Lógico)

| Código | Estado | Significado |
|---|---|---|
| `00` | No aplica | El átomo pertenece a D1 o D2 — no hay política que evaluar |
| `01` | Pendiente | La política existe pero requiere acción adicional (step-up, segunda firma) |
| `10` | Aprobado | La política fue evaluada y el resultado es favorable |
| `11` | Rechazado | La política fue evaluada y el resultado es desfavorable |

---

## 14. ESPECIFICACIÓN DE TIPOS DE DATOS

### 14.1 Regla fundamental: todos los códigos son enteros

**Todos los identificadores de dominio, aplicación, grupo, verbo y átomo son enteros (`INTEGER` / `SMALLINT` / `BIGINT`). Ningún código del sistema de privilegios puede ser de tipo texto (`VARCHAR`, `TEXT`, `CHAR`).**

Esta regla no es de estilo — es estructural. El BitMask Átomo se construye empaquetando campos numéricos en posiciones de bits específicas mediante desplazamiento (`<<`) y máscara (`&`). Si cualquier campo fuera texto, la operación de empaquetado sería imposible sin una conversión intermedia que introduce latencia y puntos de fallo. Los identificadores en texto son únicamente para presentación humana en el Core UI — nunca para computación.

| Campo | Tipo PostgreSQL | Rango | Justificación |
|---|---|---|---|
| `domain_code` | `SMALLINT` | 1–15 (4 bits) | 11 dominios + margen. SMALLINT (2 bytes) es suficiente y eficiente |
| `app_code` | `SMALLINT` | 1–511 (9 bits) | 512 aplicaciones máximo. SMALLINT cubre el rango |
| `group_code` | `SMALLINT` | 1–2047 (11 bits) | 2.048 grupos por aplicación |
| `verb_code` | `SMALLINT` | 1–255 (8 bits) | Vocabulario global de verbos, extensible hasta 255 |
| `atom_code` | `INTEGER` | 1–16.777.215 (24 bits) | Espacio de átomo por grupo. INTEGER (4 bytes) cubre el rango |
| `atom_position` | `INTEGER` | 0–N-1 | Posición ordinal en el catálogo global para el Rol BitMask |
| `bitmask_atom` | `BIGINT` | 0–2^64-1 | El BitMask Átomo completo (64 bits = 32 Contextual + 32 Lógico) |
| `contextual_mask` | `INTEGER` | 0–2^32-1 | La mitad contextual del BitMask Átomo |
| `logical_mask` | `INTEGER` | 0–2^32-1 | La mitad lógica del BitMask Átomo |
| `policy_state` | `SMALLINT` | 0–3 (2 bits) | Estado de política: 0=no aplica, 1=pendiente, 2=aprobado, 3=rechazado |

Los campos de nombre (`domain_name`, `app_name`, `group_name`, `verb_name`, `atom_name`) son `VARCHAR` — sirven para presentación en UI y reportes. Son columnas auxiliares, nunca claves de búsqueda en el hot path.

### 14.2 Por qué `SMALLINT` y no `INTEGER` para los códigos pequeños

`SMALLINT` ocupa 2 bytes; `INTEGER` ocupa 4 bytes. En una tabla de catálogo con millones de filas (catálogo global × tenants × roles), la diferencia de 2 bytes por columna se acumula significativamente en almacenamiento e índices B-tree. Para campos de dominio (máximo 15), app (máximo 511), y grupo (máximo 2047), `SMALLINT` es el tipo correcto — no es optimización prematura, es precisión de tipo.

---

## 15. DDL — DEFINICIÓN DE TABLAS

### 15.1 Esquema general

```
bos_privilege_schema
├── bos_domain          — catálogo de 11 dominios de soberanía
├── bos_application     — catálogo de aplicaciones fichas registradas
├── bos_group           — catálogo de grupos funcionales por aplicación
├── bos_verb            — catálogo global de verbos (nuevo, editar, eliminar, ver...)
├── bos_atom_catalog    — catálogo de átomos: combinaciones (dominio, app, grupo, verbo)
├── bos_atom_bitmask    — BitMask Átomo pre-calculado para cada átomo del catálogo
├── bos_role            — definición de roles por tenant
├── bos_role_atom       — asignación de átomos a roles (genera el Rol BitMask)
├── bos_atom_policy     — políticas encadenadas a átomos de dominios D3/D4/D6/D7/D10
└── bos_atom_audit      — registro WORM de cada evaluación de acceso
```

### 15.2 DDL completo

```sql
-- ============================================================
-- SBOS — Esquema de Privilegios por Átomos
-- SKULL · Junio 2026
-- Todos los códigos de identificación son INTEGER / SMALLINT.
-- VARCHAR solo se usa para nombres de presentación.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bos_privilege;
SET search_path TO bos_privilege;


-- ------------------------------------------------------------
-- 1. DOMINIOS DE SOBERANÍA
-- Catálogo fijo. Los códigos no cambian una vez definidos.
-- ------------------------------------------------------------
CREATE TABLE bos_domain (
    domain_code     SMALLINT        NOT NULL,   -- PK numérica: 1-15
    domain_name     VARCHAR(64)     NOT NULL,   -- presentación: "Lógico", "Financiero"...
    requires_policy BOOLEAN         NOT NULL DEFAULT FALSE,
    description     TEXT,
    CONSTRAINT pk_bos_domain PRIMARY KEY (domain_code),
    CONSTRAINT ck_domain_code CHECK (domain_code BETWEEN 1 AND 15)
);

COMMENT ON TABLE  bos_domain IS 'Catálogo de 11 dominios de soberanía bAuth. domain_code es el valor codificado en bits 8-11 del Dominio Contextual.';
COMMENT ON COLUMN bos_domain.domain_code IS 'Entero 1-15. Se empaqueta en bits 8-11 del Dominio Contextual (4 bits). NUNCA texto.';


-- ------------------------------------------------------------
-- 2. APLICACIONES (fichas registradas)
-- ------------------------------------------------------------
CREATE TABLE bos_application (
    app_code        SMALLINT        NOT NULL,   -- PK numérica: 1-511
    app_name        VARCHAR(64)     NOT NULL,
    app_slug        VARCHAR(32)     NOT NULL,   -- slug para logs y UI: "tryton", "saleor"
    tenant_id       UUID            NOT NULL,   -- tenant dueño del registro
    active          BOOLEAN         NOT NULL DEFAULT TRUE,
    registered_at   TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_application PRIMARY KEY (app_code),
    CONSTRAINT uq_bos_application_slug UNIQUE (tenant_id, app_slug),
    CONSTRAINT ck_app_code CHECK (app_code BETWEEN 1 AND 511)
);

COMMENT ON COLUMN bos_application.app_code IS 'Entero 1-511. Se empaqueta en bits 12-20 del Dominio Contextual (9 bits). NUNCA texto.';


-- ------------------------------------------------------------
-- 3. GRUPOS FUNCIONALES POR APLICACIÓN
-- ------------------------------------------------------------
CREATE TABLE bos_group (
    group_code      SMALLINT        NOT NULL,   -- código dentro de la app: 1-2047
    app_code        SMALLINT        NOT NULL,
    group_name      VARCHAR(128)    NOT NULL,
    CONSTRAINT pk_bos_group PRIMARY KEY (app_code, group_code),
    CONSTRAINT fk_bos_group_app FOREIGN KEY (app_code) REFERENCES bos_application(app_code),
    CONSTRAINT ck_group_code CHECK (group_code BETWEEN 1 AND 2047)
);

COMMENT ON COLUMN bos_group.group_code IS 'Entero 1-2047. Se empaqueta en bits 21-31 del Dominio Contextual (11 bits). NUNCA texto.';


-- ------------------------------------------------------------
-- 4. VOCABULARIO GLOBAL DE VERBOS
-- Fijo y global: el mismo código tiene el mismo significado
-- en cualquier app, grupo o dominio.
-- ------------------------------------------------------------
CREATE TABLE bos_verb (
    verb_code       SMALLINT        NOT NULL,   -- PK numérica: 1-255
    verb_name       VARCHAR(32)     NOT NULL,   -- "nuevo", "editar", "eliminar", "ver"
    verb_slug       VARCHAR(32)     NOT NULL,   -- "create", "update", "delete", "read"
    CONSTRAINT pk_bos_verb PRIMARY KEY (verb_code),
    CONSTRAINT uq_bos_verb_name UNIQUE (verb_name),
    CONSTRAINT ck_verb_code CHECK (verb_code BETWEEN 1 AND 255)
);

COMMENT ON COLUMN bos_verb.verb_code IS 'Entero 1-255. Este código NO se combina con bitwise — es label encoding. La combinación entre roles usa el Rol BitMask (bos_role_atom).';


-- ------------------------------------------------------------
-- 5. CATÁLOGO DE ÁTOMOS
-- Cada fila = una acción específica sobre una entidad específica.
-- La unicidad la da la combinación (domain_code, app_code, group_code, verb_code).
-- ------------------------------------------------------------
CREATE TABLE bos_atom_catalog (
    atom_code       INTEGER         NOT NULL,   -- código del verbo dentro del grupo: 1-16.777.215
    app_code        SMALLINT        NOT NULL,
    group_code      SMALLINT        NOT NULL,
    domain_code     SMALLINT        NOT NULL,
    verb_code       SMALLINT        NOT NULL,
    atom_name       VARCHAR(255)    NOT NULL,   -- nombre legible: "Comprobantes.nuevo"
    atom_slug       VARCHAR(255)    NOT NULL,   -- slug para logs: "comprobantes.nuevo"
    atom_position   INTEGER         NOT NULL,   -- posición ordinal en el catálogo global (0-based)
    -- El BitMask Átomo pre-calculado (32 bits Contextual + 32 bits Lógico)
    contextual_mask INTEGER         NOT NULL,   -- Dominio Contextual empaquetado
    logical_mask    INTEGER         NOT NULL,   -- Dominio Lógico empaquetado (sin estado de política)
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_atom_catalog PRIMARY KEY (app_code, group_code, atom_code),
    CONSTRAINT uq_bos_atom_position UNIQUE (atom_position),
    CONSTRAINT uq_bos_atom_slug UNIQUE (app_code, atom_slug),
    CONSTRAINT fk_bos_atom_app FOREIGN KEY (app_code, group_code)
        REFERENCES bos_group(app_code, group_code),
    CONSTRAINT fk_bos_atom_domain FOREIGN KEY (domain_code)
        REFERENCES bos_domain(domain_code),
    CONSTRAINT fk_bos_atom_verb FOREIGN KEY (verb_code)
        REFERENCES bos_verb(verb_code),
    CONSTRAINT ck_atom_code CHECK (atom_code BETWEEN 1 AND 16777215),
    CONSTRAINT ck_atom_position CHECK (atom_position >= 0)
);

COMMENT ON TABLE  bos_atom_catalog IS 'Catálogo global de átomos. Cada fila es una acción indivisible. atom_position es la posición en el Rol BitMask (one-hot). atom_code es el verbo dentro del grupo (label encoding — no combinar con bitwise).';
COMMENT ON COLUMN bos_atom_catalog.contextual_mask IS 'Dominio Contextual pre-calculado: (domain_code << 8) | (app_code << 12) | (group_code << 21). Tipo INTEGER (32 bits sin signo en lógica, almacenado como INTEGER con cast a BIGINT al empaquetar).';
COMMENT ON COLUMN bos_atom_catalog.logical_mask IS 'Dominio Lógico pre-calculado: (atom_code << 8). El campo de políticas (bits 6-7) se superpone en tiempo de ejecución, no se almacena aquí.';
COMMENT ON COLUMN bos_atom_catalog.atom_position IS 'Posición ordinal fija en el catálogo. Es el índice del bit en el Rol BitMask. No cambia una vez asignado.';


-- ------------------------------------------------------------
-- 6. ROLES POR TENANT
-- ------------------------------------------------------------
CREATE TABLE bos_role (
    role_id         UUID            NOT NULL DEFAULT gen_random_uuid(),
    tenant_id       UUID            NOT NULL,
    role_code       INTEGER         NOT NULL,   -- código numérico del rol dentro del tenant
    role_name       VARCHAR(128)    NOT NULL,
    role_slug       VARCHAR(64)     NOT NULL,
    active          BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_role PRIMARY KEY (role_id),
    CONSTRAINT uq_bos_role_code UNIQUE (tenant_id, role_code),
    CONSTRAINT uq_bos_role_slug UNIQUE (tenant_id, role_slug),
    CONSTRAINT ck_role_code CHECK (role_code > 0)
);

COMMENT ON COLUMN bos_role.role_code IS 'Código numérico del rol dentro del tenant. Entero positivo. Junto con tenant_id forma la clave de negocio.';


-- ------------------------------------------------------------
-- 7. ASIGNACIÓN DE ÁTOMOS A ROLES (genera el Rol BitMask)
-- Esta tabla ES el Rol BitMask en forma relacional.
-- La ausencia de fila equivale a allowed = false.
-- ------------------------------------------------------------
CREATE TABLE bos_role_atom (
    role_id         UUID            NOT NULL,
    app_code        SMALLINT        NOT NULL,
    group_code      SMALLINT        NOT NULL,
    atom_code       INTEGER         NOT NULL,
    atom_position   INTEGER         NOT NULL,   -- desnormalizado para consultas rápidas
    allowed         BOOLEAN         NOT NULL DEFAULT FALSE,
    granted_by      UUID,                       -- UUID del admin que concedió el permiso
    granted_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_role_atom PRIMARY KEY (role_id, app_code, group_code, atom_code),
    CONSTRAINT fk_bos_role_atom_role FOREIGN KEY (role_id)
        REFERENCES bos_role(role_id),
    CONSTRAINT fk_bos_role_atom_catalog FOREIGN KEY (app_code, group_code, atom_code)
        REFERENCES bos_atom_catalog(app_code, group_code, atom_code)
);

-- Índice para reconstruir el Rol BitMask completo de un rol en una sola consulta
CREATE INDEX ix_bos_role_atom_role ON bos_role_atom (role_id, allowed)
    WHERE allowed = TRUE;

COMMENT ON TABLE bos_role_atom IS 'Asignación de átomos a roles. Cada fila con allowed=true es un bit en 1 en el Rol BitMask. atom_position es la posición del bit — desnormalizado de bos_atom_catalog para evitar JOIN en el hot path.';


-- ------------------------------------------------------------
-- 8. POLÍTICAS ENCADENADAS A ÁTOMOS
-- Para dominios D3, D4, D6, D7, D10.
-- Un átomo puede tener 0, 1 o N políticas encadenadas.
-- ------------------------------------------------------------
CREATE TABLE bos_atom_policy (
    policy_id       UUID            NOT NULL DEFAULT gen_random_uuid(),
    app_code        SMALLINT        NOT NULL,
    group_code      SMALLINT        NOT NULL,
    atom_code       INTEGER         NOT NULL,
    policy_domain   SMALLINT        NOT NULL,   -- dominio de la política (3=D3, 4=D4, 6=D6...)
    policy_slug     VARCHAR(64)     NOT NULL,   -- "POL-D3-LIMITE", "POL-D6-VIAJE"
    policy_params   JSONB,                      -- parámetros configurables: {"threshold_kmh": 900}
    active          BOOLEAN         NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_bos_atom_policy PRIMARY KEY (policy_id),
    CONSTRAINT uq_bos_atom_policy_slug UNIQUE (app_code, group_code, atom_code, policy_slug),
    CONSTRAINT fk_bos_atom_policy_atom FOREIGN KEY (app_code, group_code, atom_code)
        REFERENCES bos_atom_catalog(app_code, group_code, atom_code),
    CONSTRAINT fk_bos_atom_policy_domain FOREIGN KEY (policy_domain)
        REFERENCES bos_domain(domain_code)
);

COMMENT ON TABLE bos_atom_policy IS 'Políticas adicionales encadenadas a un átomo. D4 y D6 no tienen átomos propios — se encadenan a átomos de D1 (ej: sistema.sesion.ingresar). policy_params es JSONB para flexibilidad de configuración por tenant.';


-- ------------------------------------------------------------
-- 9. AUDITORÍA WORM — registro de cada evaluación
-- REVOKE UPDATE, DELETE sobre esta tabla para todos los roles
-- de aplicación. Solo INSERT está permitido.
-- ------------------------------------------------------------
CREATE TABLE bos_atom_audit (
    audit_id        UUID            NOT NULL DEFAULT gen_random_uuid(),
    ctx_id          VARCHAR(128)    NOT NULL,   -- ID de sesión (obligatorio, nunca NULL)
    tenant_id       UUID            NOT NULL,
    role_id         UUID            NOT NULL,
    app_code        SMALLINT        NOT NULL,
    group_code      SMALLINT        NOT NULL,
    atom_code       INTEGER         NOT NULL,
    atom_position   INTEGER         NOT NULL,
    bitmask_atom    BIGINT          NOT NULL,   -- BitMask Átomo completo (64 bits)
    policy_state    SMALLINT        NOT NULL,   -- 0=no aplica, 1=pendiente, 2=aprobado, 3=rechazado
    result          SMALLINT        NOT NULL,   -- 0=denegado, 1=permitido, 2=pendiente
    policy_slug     VARCHAR(64),                -- política evaluada (si aplica)
    evaluator       VARCHAR(32)     NOT NULL,   -- "bauth", "bhnexus", "kong"
    evaluated_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_bos_atom_audit PRIMARY KEY (audit_id),
    CONSTRAINT ck_policy_state CHECK (policy_state IN (0, 1, 2, 3)),
    CONSTRAINT ck_audit_result  CHECK (result IN (0, 1, 2))
) PARTITION BY RANGE (evaluated_at);

-- Partición inicial — crear una por mes en producción
CREATE TABLE bos_atom_audit_2026_06
    PARTITION OF bos_atom_audit
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

-- Protección WORM: revocar UPDATE y DELETE al role de aplicación
-- (ejecutar con el superusuario administrativo, no con el role de app)
-- REVOKE UPDATE, DELETE ON bos_atom_audit FROM bos_privilege_writer;

COMMENT ON TABLE bos_atom_audit IS 'Registro WORM de cada evaluación de acceso. ctx_id es obligatorio — toda evaluación debe estar trazada a una sesión. Particionado por mes para performance. UPDATE y DELETE revocados al role de aplicación.';
COMMENT ON COLUMN bos_atom_audit.bitmask_atom IS 'BitMask Átomo completo (64 bits) al momento de la evaluación. BIGINT en PostgreSQL.';
COMMENT ON COLUMN bos_atom_audit.policy_state IS 'Entero: 0=no aplica, 1=pendiente, 2=aprobado, 3=rechazado. Corresponde a los 2 bits de política del Dominio Lógico.';
COMMENT ON COLUMN bos_atom_audit.result IS 'Entero: 0=denegado, 1=permitido, 2=pendiente (step-up requerido).';
```

### 15.3 Función de empaquetado del BitMask Átomo

```sql
-- Función que calcula el BitMask Átomo (64 bits) a partir de sus componentes numéricos.
-- Retorna dos INTEGER (contextual + lógico) que juntos forman el uint64.
-- Se llama UNA SOLA VEZ al registrar un átomo en el catálogo.

CREATE OR REPLACE FUNCTION bos_build_atom_bitmask(
    p_domain_code   SMALLINT,   -- 4 bits, posiciones 8-11 del Contextual
    p_app_code      SMALLINT,   -- 9 bits, posiciones 12-20 del Contextual
    p_group_code    SMALLINT,   -- 11 bits, posiciones 21-31 del Contextual
    p_atom_code     INTEGER,    -- 24 bits, posiciones 8-31 del Lógico
    p_policy_state  SMALLINT    -- 2 bits, posiciones 6-7 del Lógico (0 al registrar)
)
RETURNS TABLE (contextual_mask INTEGER, logical_mask INTEGER)
LANGUAGE sql IMMUTABLE STRICT AS $$
    SELECT
        -- Dominio Contextual: [8 reservado][4 dominio][9 app][11 grupo]
        (
            (p_domain_code::INTEGER << 8)  |
            (p_app_code::INTEGER    << 12) |
            (p_group_code::INTEGER  << 21)
        )::INTEGER AS contextual_mask,

        -- Dominio Lógico: [6 reservado][2 políticas][24 átomo]
        (
            (p_policy_state::INTEGER << 6) |
            (p_atom_code::INTEGER    << 8)
        )::INTEGER AS logical_mask;
$$;

COMMENT ON FUNCTION bos_build_atom_bitmask IS
    'Empaqueta los componentes numéricos en el BitMask Átomo de 64 bits (como dos INTEGER de 32 bits).
     Todos los parámetros son enteros — nunca texto. El resultado se almacena en bos_atom_catalog.';
```

### 15.4 Vista: Rol BitMask materializado para consulta de evaluación

```sql
-- Vista que reconstruye el conjunto de átomos activos de un rol
-- como lista ordenada de atom_position (para construir el vector one-hot en la app).
CREATE VIEW bos_role_bitmask_view AS
SELECT
    r.tenant_id,
    ra.role_id,
    r.role_code,
    r.role_slug,
    ra.atom_position,
    ac.app_code,
    ac.group_code,
    ac.atom_code,
    ac.atom_name,
    ac.atom_slug,
    ac.contextual_mask,
    ac.logical_mask,
    ac.domain_code
FROM bos_role_atom ra
    JOIN bos_role r         ON r.role_id = ra.role_id
    JOIN bos_atom_catalog ac ON (
        ac.app_code    = ra.app_code    AND
        ac.group_code  = ra.group_code  AND
        ac.atom_code   = ra.atom_code
    )
WHERE ra.allowed = TRUE
ORDER BY ra.role_id, ra.atom_position;

COMMENT ON VIEW bos_role_bitmask_view IS
    'Rol BitMask en forma relacional. Cada fila es un bit en 1 del vector one-hot del rol.
     La app construye el vector ordenando por atom_position y marcando los bits correspondientes.';
```

---

## 16. DATOS DE EJEMPLO

### 16.1 Población del catálogo base

```sql
-- ============================================================
-- DATOS DE EJEMPLO — catálogo mínimo inicial
-- Todos los códigos son enteros. Sin VARCHAR como código.
-- ============================================================

-- 1. Dominios de soberanía
INSERT INTO bos_domain (domain_code, domain_name, requires_policy, description) VALUES
    (1,  'Lógico',           FALSE, 'Acceso a apps y recursos digitales. El verbo es suficiente.'),
    (2,  'Físico',           FALSE, 'Acceso a zonas y hardware. El verbo es suficiente.'),
    (3,  'Financiero',       TRUE,  'Transacciones de valor. Requiere evaluación de límite, SoD y dual-approval.'),
    (4,  'Temporal',         TRUE,  'Restricciones de horario. Se evalúa encadenado a átomos de D1.'),
    (5,  'Biométrico',       FALSE, 'Resuelto en login por Keycloak. No participa en evaluación de átomo.'),
    (6,  'Geoespacial',      TRUE,  'Ubicación y viaje imposible. Se evalúa encadenado a átomos de D1.'),
    (7,  'Red',              TRUE,  'CIDR, VPN, protocolo. Evaluado por Kong en cada request.'),
    (8,  'Contexto sesión',  FALSE, 'Resuelto por ctx_id en Redis. Pre-condición del BitMask.'),
    (9,  'Credenciales',     FALSE, 'Resuelto en login por Keycloak.'),
    (10, 'Delegación',       TRUE,  'Privilegios temporales. Requiere verificación de vigencia y alcance.'),
    (11, 'Auditoría',        FALSE, 'Registro WORM. No evalúa — solo registra.');


-- 2. Verbos globales
INSERT INTO bos_verb (verb_code, verb_name, verb_slug) VALUES
    (1, 'nuevo',    'create'),
    (2, 'editar',   'update'),
    (3, 'eliminar', 'delete'),
    (4, 'ver',      'read');


-- 3. Aplicaciones (tenant de ejemplo: uuid fijo para reproducibilidad)
INSERT INTO bos_application (app_code, app_name, app_slug, tenant_id) VALUES
    (1, 'Tryton ERP',       'tryton',    'aaaaaaaa-0000-0000-0000-000000000001'),
    (2, 'OrangeHRM',        'orangehrm', 'aaaaaaaa-0000-0000-0000-000000000001'),
    (3, 'Saleor',           'saleor',    'aaaaaaaa-0000-0000-0000-000000000001');


-- 4. Grupos funcionales por aplicación
INSERT INTO bos_group (group_code, app_code, group_name) VALUES
    -- Tryton (app_code=1)
    (1, 1, 'Plan de Cuentas'),
    (2, 1, 'Comprobantes'),
    (3, 1, 'Menú Plan de Cuentas'),
    (4, 1, 'Menú Comprobantes'),
    -- OrangeHRM (app_code=2)
    (1, 2, 'Empleados'),
    -- Saleor (app_code=3)
    (1, 3, 'Catálogo');


-- 5. Catálogo de átomos
-- Fórmula contextual: (domain_code << 8) | (app_code << 12) | (group_code << 21)
-- Fórmula lógica:     (0 << 6) | (atom_code << 8)   [policy_state=0 al registrar]
-- atom_position: ordinal global, nunca se reasigna

INSERT INTO bos_atom_catalog
    (atom_code, app_code, group_code, domain_code, verb_code,
     atom_name, atom_slug, atom_position,
     contextual_mask, logical_mask)
VALUES
--  atom  app grp dom vrb  nombre                              slug                         pos  ctx_mask    log_mask
    (1,    1,  1,  1,  1,  'Tryton.Plan de Cuentas.nuevo',     'tryton.cuentas.nuevo',       0,  4196608,    256),
    (2,    1,  1,  1,  2,  'Tryton.Plan de Cuentas.editar',    'tryton.cuentas.editar',      1,  4196608,    512),
    (3,    1,  1,  1,  3,  'Tryton.Plan de Cuentas.eliminar',  'tryton.cuentas.eliminar',    2,  4196608,    768),
    (1,    1,  2,  3,  1,  'Tryton.Comprobantes.nuevo',        'tryton.comprobantes.nuevo',  3,  6295808,    256),
    (2,    1,  2,  3,  2,  'Tryton.Comprobantes.editar',       'tryton.comprobantes.editar', 4,  6295808,    512),
    (3,    1,  2,  3,  3,  'Tryton.Comprobantes.eliminar',     'tryton.comprobantes.elim',   5,  6295808,    768),
    (4,    1,  3,  1,  4,  'Tryton.Menú Plan de Cuentas.ver',  'tryton.menu.cuentas.ver',    6,  6293760,    1024),
    (4,    1,  4,  1,  4,  'Tryton.Menú Comprobantes.ver',     'tryton.menu.comprobantes.v', 7,  8390912,    1024),
    (1,    2,  1,  1,  1,  'OrangeHRM.Empleados.nuevo',        'orangehrm.empleados.nuevo',  8,  4200704,    256),
    (2,    2,  1,  1,  2,  'OrangeHRM.Empleados.editar',       'orangehrm.empleados.editar', 9,  4200704,    512),
    (1,    3,  1,  1,  1,  'Saleor.Catálogo.nuevo',            'saleor.catalogo.nuevo',      10, 4202752,    256),
    (2,    3,  1,  1,  2,  'Saleor.Catálogo.editar',           'saleor.catalogo.editar',     11, 4202752,    512);


-- 6. Roles de ejemplo
INSERT INTO bos_role (role_id, tenant_id, role_code, role_name, role_slug) VALUES
    ('bbbbbbbb-0001-0000-0000-000000000001',
     'aaaaaaaa-0000-0000-0000-000000000001', 1, 'Contador Senior',   'contador_senior'),
    ('bbbbbbbb-0002-0000-0000-000000000001',
     'aaaaaaaa-0000-0000-0000-000000000001', 2, 'Auxiliar Contable', 'auxiliar_contable'),
    ('bbbbbbbb-0003-0000-0000-000000000001',
     'aaaaaaaa-0000-0000-0000-000000000001', 3, 'Vendedor',          'vendedor');


-- 7. Asignación de átomos a roles (Rol BitMask en forma relacional)
-- Contador Senior: Plan de Cuentas.nuevo/.editar + Comprobantes.nuevo/.editar
INSERT INTO bos_role_atom (role_id, app_code, group_code, atom_code, atom_position, allowed) VALUES
    ('bbbbbbbb-0001-0000-0000-000000000001', 1, 1, 1, 0,  TRUE),  -- Cuentas.nuevo
    ('bbbbbbbb-0001-0000-0000-000000000001', 1, 1, 2, 1,  TRUE),  -- Cuentas.editar
    ('bbbbbbbb-0001-0000-0000-000000000001', 1, 2, 1, 3,  TRUE),  -- Comprobantes.nuevo
    ('bbbbbbbb-0001-0000-0000-000000000001', 1, 2, 2, 4,  TRUE);  -- Comprobantes.editar

-- Auxiliar Contable: Plan de Cuentas.editar + Menú Comprobantes.ver
INSERT INTO bos_role_atom (role_id, app_code, group_code, atom_code, atom_position, allowed) VALUES
    ('bbbbbbbb-0002-0000-0000-000000000001', 1, 1, 2, 1,  TRUE),  -- Cuentas.editar
    ('bbbbbbbb-0002-0000-0000-000000000001', 1, 4, 4, 7,  TRUE);  -- Menú Comp.ver

-- Vendedor: Saleor.Catálogo.nuevo/.editar + OrangeHRM.Empleados.ver (solo lectura)
INSERT INTO bos_role_atom (role_id, app_code, group_code, atom_code, atom_position, allowed) VALUES
    ('bbbbbbbb-0003-0000-0000-000000000001', 3, 1, 1, 10, TRUE),  -- Catálogo.nuevo
    ('bbbbbbbb-0003-0000-0000-000000000001', 3, 1, 2, 11, TRUE);  -- Catálogo.editar


-- 8. Política encadenada: Comprobantes.nuevo dispara verificación de límite D3
INSERT INTO bos_atom_policy
    (app_code, group_code, atom_code, policy_domain, policy_slug, policy_params) VALUES
    (1, 2, 1, 3, 'POL-D3-LIMITE-COMPROBANTE',
     '{"daily_limit_bob": 50000, "single_limit_bob": 10000, "dual_approval_above": 25000}'),
    (1, 2, 2, 3, 'POL-D3-LIMITE-COMPROBANTE-EDITAR',
     '{"requires_sod_check": true}');

-- Política encadenada: sistema.sesion.ingresar → D4 y D6
-- (Cuando se registre el átomo sistema.sesion.ingresar en la ficha correspondiente)
-- INSERT INTO bos_atom_policy (...) VALUES
--     (app_sistema, group_sesion, atom_ingresar, 6, 'POL-D6-VIAJE',    '{"threshold_kmh": 900}'),
--     (app_sistema, group_sesion, atom_ingresar, 4, 'POL-D4-HORARIO',   '{"check_calendar": true}');
```

### 16.2 Verificación: reconstruir el Rol BitMask de Contador Senior

```sql
-- Consulta que retorna los átomos activos del Contador Senior
-- ordenados por posición (= el vector one-hot del rol)
SELECT
    atom_position,
    atom_name,
    atom_slug,
    contextual_mask,
    logical_mask
FROM bos_role_bitmask_view
WHERE role_slug = 'contador_senior'
ORDER BY atom_position;

-- Resultado esperado:
-- pos | atom_name                          | ctx_mask | log_mask
--  0  | Tryton.Plan de Cuentas.nuevo       | 4196608  | 256
--  1  | Tryton.Plan de Cuentas.editar      | 4196608  | 512
--  3  | Tryton.Comprobantes.nuevo          | 6295808  | 256
--  4  | Tryton.Comprobantes.editar         | 6295808  | 512
--
-- Rol BitMask (12 bits, posiciones 0-11): 000000011011
-- Posiciones 0,1,3,4 = 1 → correcto según el AUXILIAR
```

### 16.3 Verificación: OR de Contador Senior y Auxiliar Contable

```sql
-- En la aplicación (Go/Python), construir el Rol BitMask como array de bits
-- y aplicar OR — la consulta SQL solo devuelve los atom_position activos.

-- Unión (OR): átomos de cualquiera de los dos roles
SELECT DISTINCT atom_position, atom_name
FROM bos_role_bitmask_view
WHERE role_slug IN ('contador_senior', 'auxiliar_contable')
ORDER BY atom_position;

-- Resultado esperado (5 átomos):
-- 0: Cuentas.nuevo, 1: Cuentas.editar, 3: Comprobantes.nuevo,
-- 4: Comprobantes.editar, 7: Menú Comprobantes.ver

-- Intersección (AND): átomos comunes a ambos roles
SELECT atom_position, atom_name
FROM bos_role_bitmask_view
WHERE role_slug = 'contador_senior'
  AND atom_position IN (
      SELECT atom_position FROM bos_role_bitmask_view
      WHERE role_slug = 'auxiliar_contable'
  )
ORDER BY atom_position;

-- Resultado esperado (1 átomo):
-- 1: Cuentas.editar
```

---

*SKULL · SBOS · SBOS-MANUAL-PRIVILEGIOS-v1.0 · Junio 2026*  
*Confidencial — Propiedad de SKULL Desarrollo de Software*  
*Prohibida su reproducción total o parcial sin autorización*

