# SBOS — Blockchain como Capa de Confianza Verificable
## Proyecto de Implementación Blockchain y Catálogo de Productos Financieros y de Autenticación

**Documento de proyecto · SKULL · SBOS**
**Versión 2.1 · Junio 2026**

**Extiende:** SBOS-BAUTH-DOMAIN-CONTROL-METHODOLOGY v1.0
**Clasificación:** Arquitectura técnica + tesis de producto — uso interno y presentación a inversores

---

## Resumen ejecutivo

SBOS ya opera un plano de control de identidad, autorización y auditoría organizado en **11 dominios de soberanía** — áreas de decisión como "¿quién es el usuario?", "¿cuánto dinero puede mover?" o "¿desde dónde se conecta?", cada una numerada de D1 a D11 y evaluada bajo tres capas de decisión (Fast-Path, Policy-Path, External-Path; definidas en el Glosario). **D12 es el nombre que este documento da a un dominio nuevo y opcional — blockchain — que se añadiría a esos once si el proyecto decide incorporarla.** No existe todavía: es la propuesta central que este documento desarrolla y evalúa.

Sobre esa base, el documento responde tres preguntas en cadena, cada una construida sobre la anterior:

1. **¿Puede SBOS, tal como existe hoy (sin D12), controlar una billetera de pagos?** Sí. Los dominios D3 (Financiero) y D11 (Auditoría) ya resuelven identidad, límites, doble aprobación y trazabilidad inmutable — el 90% de lo que cualquier billetera necesita, sin blockchain.

2. **¿Qué aportaría D12 (blockchain) si se incorpora?** Verificabilidad por un tercero que no confía en SBOS ni en quien lo opera — una propiedad que ningún registro interno, por bien diseñado que esté, puede ofrecer por sí solo.

3. **Si se incorpora D12, ¿en qué se convierte el proyecto?** Deja de ser una billetera y se convierte en infraestructura de confianza vendible — una oferta de categoría RegTech / IDaaS / Trust-as-a-Service (categorías definidas en el Glosario), con cuatro productos concretos, un stack tecnológico enteramente de código abierto alineado a estándares internacionales, y un camino de implementación verificable en ocho semanas.

Este documento desarrolla las tres respuestas en profundidad: arquitectura (Parte I), modelo de negocio (Parte II), implementación técnica y catálogo de software (Parte III), cierra con un anexo regulatorio separado del cuerpo técnico (Anexo A), y abre con un **Glosario** que define cada término técnico, sigla y nombre de tabla usado en el resto del documento — la referencia obligada para cualquier lector que no haya participado en el desarrollo previo de esta arquitectura.

**La tesis central en una frase:** SBOS no necesita blockchain para operar; la necesita para venderse a quien no lo conoce.

---

## Glosario

Esta sección define, en un solo lugar, todo término técnico, sigla, nombre de tabla y concepto de arquitectura usado en el resto del documento. Se recomienda leerla antes que el cuerpo si el lector no participó en el desarrollo previo de la metodología bAuth.

### Conceptos de arquitectura SBOS

| Término | Definición |
|---|---|
| **SBOS** | El sistema operativo de control (identidad, autorización, auditoría) sobre el que corren las aplicaciones de negocio del proyecto — el ERP, el e-commerce, el sistema de RRHH, y ahora la billetera de pagos. No es una aplicación más: es la capa que decide qué puede hacer cada usuario en cada aplicación. |
| **bAuth** | El subsistema de SBOS responsable específicamente de autenticación y autorización — el motor que evalúa los 11 (y potencialmente 12) dominios descritos en este documento. |
| **bKernel** | El núcleo de SBOS que orquesta eventos internos entre subsistemas — por ejemplo, detecta que ocurrió un evento de auditoría y dispara el proceso de anclaje en blockchain. |
| **biedata** | El único componente de SBOS autorizado a hacer conexiones salientes hacia sistemas externos (bancos, servicios fiscales, y en este proyecto, redes blockchain). Esta restricción es una regla de seguridad deliberada del proyecto, no una limitación técnica de la tecnología subyacente. |
| **Dominio (D1–D11, y D12 propuesto)** | Una "área de decisión" dentro del control de acceso — por ejemplo, D3 decide todo lo relacionado con dinero, D11 decide todo lo relacionado con registro de auditoría. Cada dominio tiene su propia tabla de reglas y su propia forma de evaluarse (ver "capas de control" abajo). El documento base de la metodología define los once dominios D1 a D11; **D12 es la propuesta de este documento para añadir blockchain como dominio número doce.** |
| **RolTemplate** | La plantilla que define qué puede hacer un tipo de usuario — por ejemplo, "comercio afiliado" o "usuario final de billetera" — antes de asignársela a una persona concreta. Es la unidad básica de configuración de permisos en SBOS. |
| **Fast-Path** | La capa de evaluación más rápida del sistema: una operación binaria sobre un número (el BitMask, ver abajo) que responde en menos de medio nanosegundo. Se usa para decisiones que deben resolverse instantáneamente, como "¿puede este usuario siquiera intentar esta acción?". |
| **Policy-Path** | La capa de evaluación intermedia: consulta reglas guardadas en base de datos (límites de monto, horarios, aprobaciones requeridas). Responde en milisegundos — más lenta que Fast-Path, pero permite reglas configurables sin tocar código. |
| **External-Path** | La capa de evaluación más lenta: consulta a un sistema externo (un sensor biométrico, un servicio de geolocalización, o — en la propuesta de este documento — una red blockchain). Responde en cientos de milisegundos o más, y se usa solo cuando la decisión realmente lo requiere. |
| **BitMask** | Un número binario donde cada posición (bit) representa un permiso encendido o apagado — el mecanismo concreto que implementa el Fast-Path. Permite verificar decenas de permisos en una sola operación de procesador, sin consultar ninguna base de datos. |
| **ctx_id** | Un identificador único que acompaña cada operación dentro de SBOS, usado para enlazar todos los eventos relacionados (login, acción, registro de auditoría) y poder reconstruir exactamente qué pasó y en qué orden. |

### Dominios específicos citados en este documento

| Dominio | Qué controla |
|---|---|
| **D1 — Lógico** | Qué aplicaciones y operaciones puede usar cada usuario (por ejemplo, acceso al ERP, a inventario, a reportes). |
| **D2 — Físico** | Acceso a puertas, zonas, cajones de punto de venta y otros elementos del mundo físico. |
| **D3 — Financiero** | Quién puede mover dinero, cuánto, y bajo qué condiciones de aprobación — el dominio central de este documento. |
| **D5 — Biométrico** | Verificación de identidad mediante huella, rostro u otro factor biológico. |
| **D6 — Geoespacial** | Desde qué país, región o ubicación se origina una operación, y si esa ubicación es coherente con la actividad reciente del usuario. |
| **D7 — Red** | Desde qué dirección de red, con qué protocolo, y bajo qué condiciones de conexión se origina una operación. |
| **D8 — Contexto** | El hilo de sesión y trazabilidad de cada operación (ver ctx_id arriba). |
| **D9 — Credenciales** | El ciclo de vida de contraseñas, factores de autenticación múltiple (MFA) y certificados de identidad. |
| **D10 — Delegación** | Permisos temporales que un usuario presta a otro (por ejemplo, durante una ausencia), con revocación automática. |
| **D11 — Auditoría** | El registro inalterable de todo lo que ocurrió en el sistema — desarrollado en profundidad en la sección 3 de este documento. |
| **D12 — Blockchain (propuesto)** | El dominio nuevo que desarrolla este documento — ver Resumen Ejecutivo. |

### Conceptos financieros y de cumplimiento

| Término | Definición |
|---|---|
| **SoD** (Separación de Funciones / *Segregation of Duties*) | El principio de que la persona que crea una transacción no debería ser la misma que la aprueba, para evitar fraude o error sin control cruzado. |
| **WORM** (*Write Once, Read Many*) | Un tipo de almacenamiento donde los datos pueden escribirse una sola vez y después solo leerse — nunca modificarse ni borrarse. Es la base técnica de un registro de auditoría confiable. |
| **JWT** (*JSON Web Token*) | Un formato estándar para transmitir de forma segura la identidad y los permisos de un usuario entre sistemas — es el "pase" digital que un usuario presenta en cada operación. |
| **KYC** (*Know Your Customer*) | El proceso regulatorio de verificar la identidad real de un usuario antes de permitirle operar — requisito estándar en servicios financieros. |
| **AML** (*Anti-Money Laundering*) | El conjunto de controles destinados a prevenir y detectar lavado de dinero. |
| **MFA** (Autenticación Multifactor) | Verificación de identidad mediante más de un factor — por ejemplo, contraseña más código enviado al teléfono. |
| **RegTech** | Categoría de empresas que venden tecnología para ayudar a otras empresas a cumplir regulaciones de forma automatizada — la categoría de mercado en la que se posiciona este proyecto si incorpora D12. |
| **IDaaS** (*Identity as a Service*) | Categoría de mercado de empresas que venden identidad y control de acceso como servicio gestionado — ejemplos conocidos son Okta o Auth0. |
| **Trust-as-a-Service** | Categoría de mercado, más nueva que las dos anteriores, centrada en ofrecer verificabilidad externa de que los datos o decisiones de una empresa no fueron alterados — la categoría que D12 habilita específicamente. |
| **Banking-as-a-Service (BaaS) / Wallet-as-a-Service** | Modelos de negocio donde una empresa ofrece infraestructura bancaria o de billetera ya construida para que otra empresa lance su propio producto financiero de marca sin construir el motor desde cero. |

### Conceptos de blockchain y criptografía

| Término | Definición |
|---|---|
| **Blockchain** | Un registro digital distribuido entre múltiples participantes, donde cada entrada nueva queda matemáticamente enlazada a las anteriores, haciendo extremadamente difícil alterar el historial sin que se note. |
| **Merkle root** (raíz de Merkle) | Un único valor (hash) que resume matemáticamente un conjunto grande de datos — en este documento, un lote de miles de eventos de auditoría. Permite comprobar que ningún dato del lote fue alterado, verificando solo ese valor resumen en vez de cada dato individual. |
| **Hash** | El resultado de aplicar una función matemática a un dato, que produce una "huella digital" única de tamaño fijo — cualquier cambio mínimo en el dato original produce un hash completamente distinto. |
| **Anclaje** (*anchoring*) | El acto de publicar un hash (por ejemplo, un Merkle root) en una blockchain pública, para que cualquiera pueda verificar después que ese dato existía y no fue alterado desde esa fecha. |
| **L2 / Capa 2** | Una red blockchain construida encima de otra red principal (como Ethereum) para procesar transacciones de forma más rápida y barata, mientras hereda parte de la seguridad de la red principal. |
| **EVM** (*Ethereum Virtual Machine*) | El entorno de ejecución estándar que procesa los programas (contratos inteligentes) en redes compatibles con Ethereum. |
| **RPC** (*Remote Procedure Call*) | El protocolo mediante el cual un programa externo envía instrucciones y consultas a un nodo de blockchain — por ejemplo, "envía esta transacción" o "dime el estado de esta cuenta". |
| **Nodo / Validador** | Una computadora que participa en una red blockchain, manteniendo una copia del registro y, en redes con consenso, votando sobre qué transacciones son válidas. |
| **Consenso** | El mecanismo mediante el cual los distintos nodos de una blockchain se ponen de acuerdo sobre qué transacciones son válidas, sin necesidad de una autoridad central. |
| **BFT** (*Byzantine Fault Tolerance*, tolerancia a fallos bizantinos) | La capacidad de un sistema distribuido de seguir funcionando correctamente incluso si algunos de sus nodos fallan o actúan de forma maliciosa. |
| **QBFT / IBFT 2.0** | Mecanismos de consenso BFT específicos, usados en redes blockchain permisionadas (donde se conoce la identidad de todos los participantes), recomendados en este documento para una eventual red propia. |
| **Red permisionada vs. pública** | Una red permisionada solo permite participar a nodos autorizados previamente (como un consorcio de empresas conocidas); una red pública permite que cualquiera participe sin autorización previa. |
| **Custodia (gestionada vs. auto-custodia)** | Custodia gestionada significa que un proveedor guarda y protege las claves criptográficas del usuario; auto-custodia significa que el propio usuario guarda su clave privada, asumiendo el riesgo de perderla. Este documento recomienda explícitamente custodia gestionada para evitar pérdida de fondos por error de usuario. |
| **DID** (*Decentralized Identifier*) | Un estándar internacional (W3C) para crear identificadores de identidad que una persona u organización controla directamente, sin depender de un proveedor central — ver sección 9.1. |
| **VC** (*Verifiable Credential*) | Un estándar internacional (W3C) para credenciales digitales firmadas criptográficamente, que pueden verificarse sin contactar a quien las emitió originalmente. |
| **EEA** (*Enterprise Ethereum Alliance*) | La organización industrial que define extensiones y estándares de Ethereum orientados a uso empresarial. |

### Conceptos de seguridad y cumplimiento técnico

| Término | Definición |
|---|---|
| **HSM** (*Hardware Security Module*) | Un dispositivo físico dedicado y reforzado para generar, guardar y usar claves criptográficas sin que jamás salgan del dispositivo en texto plano — el estándar de la industria para proteger las claves más críticas. |
| **PKCS#11** | Un estándar internacional que define cómo un programa de software se comunica con un HSM (o con su equivalente en software) para pedirle que realice operaciones criptográficas, sin tener acceso directo a la clave privada. |
| **FIPS 140-2 / 140-3** | Estándares del gobierno de Estados Unidos (NIST) que certifican el nivel de seguridad de un módulo criptográfico — un punto de referencia internacionalmente reconocido en la industria financiera, independientemente del país donde opere la empresa. |
| **KMIP** (*Key Management Interoperability Protocol*) | Un estándar internacional (OASIS) para que distintos sistemas de gestión de claves criptográficas puedan interoperar entre sí. |
| **OWASP ASVS** (*Application Security Verification Standard*) | Un estándar abierto, ampliamente reconocido, de requisitos de seguridad para aplicaciones y APIs, usado como referencia de buenas prácticas de desarrollo seguro. |
| **PCI DSS** (*Payment Card Industry Data Security Standard*) | El estándar internacional de seguridad que deben cumplir los sistemas que procesan, almacenan o transmiten datos de pago. |
| **NIST** (*National Institute of Standards and Technology*) | La agencia de estándares del gobierno de Estados Unidos cuyas publicaciones (como las series SP 800) son referencia internacional en ciberseguridad y criptografía. |
| **ADR** (*Architecture Decision Record*) | Un documento corto que registra una decisión de arquitectura y su justificación — ADR-012, citado en este documento, es la decisión que prohíbe conexiones HTTP directas entre componentes internos de SBOS. |
| **Apache 2.0 / MIT / MPL 2.0 / CC BY-SA 4.0** | Distintos tipos de licencia de software y contenido libre/abierto citadas en el catálogo de la Parte III — todas permiten uso, modificación y redistribución bajo condiciones específicas, sin costo de licenciamiento. |

---

## Índice

**Glosario** — definiciones de todos los términos técnicos usados en el documento

**Parte I — Suficiencia arquitectónica**
1. Lo que toda billetera de pagos necesita controlar
2. D3 (Financiero) aplicado al caso de uso
3. D11 (Auditoría) aplicado al caso de uso
4. Conclusión de suficiencia

**Parte II — D12 y el modelo de negocio**
5. D12 — Tres variantes de incorporación de blockchain
6. De operar una billetera a vender el plano de control
7. Catálogo de productos

**Parte III — Implementación técnica**
8. Patrón de integración y roadmap
9. Catálogo de software libre por capa, alineado a estándares

**Anexo A — Marco regulatorio (orientativo, no técnico)**
Trazabilidad y control de versiones

---//---

# PARTE I — SUFICIENCIA ARQUITECTÓNICA

## 1. Lo que toda billetera de pagos necesita controlar

Independientemente de la tecnología subyacente, toda billetera de pagos — Alotoke, Tigo Money, o cualquier otra — resuelve siempre el mismo conjunto de seis preguntas. La tabla siguiente las mapea contra los dominios bAuth que ya las resuelven hoy:

| Pregunta operativa | Dominio bAuth | Capa de control |
|---|---|---|
| ¿Quién es el usuario? | D9 (Credenciales) + D5 (Biométrico, si aplica) | External-Path |
| ¿Puede este usuario mover dinero? | D3 (Financiero) — bit `FINANCIAL_CREATE` | Fast-Path |
| ¿Cuánto puede mover, en este momento, en esta cuenta? | D3 (Financiero) — `bos_financial_limit` | Policy-Path |
| ¿Necesita esta operación una segunda firma? | D3 (Financiero) — SoD, `bos_financial_decision_matrix` | Policy-Path |
| ¿Desde dónde y bajo qué condiciones se origina la operación? | D6 (Geoespacial) + D7 (Red) + D8 (Contexto) | Policy/External-Path |
| ¿Quedó un registro inalterable de que esto ocurrió? | D11 (Auditoría) — WORM, particionado | Policy-Path asíncrono |

Ninguna de las seis preguntas requiere blockchain para responderse. Las seis ya tienen evaluador definido en la metodología de control de dominios vigente. Esta es la base sobre la que se construye todo el resto del documento.

---

## 2. D3 (Financiero) aplicado al caso de uso

La definición de D3 en la metodología base se proyecta de forma directa sobre una billetera, sin modificación estructural:

```
Bit 14: FINANCIAL_APPROVE   — ¿puede aprobar una transacción (propia o de un tercero)?
Bit 15: FINANCIAL_CREATE    — ¿puede crear/iniciar una transacción?
```

Estos dos bits resuelven, en menos de 0.5 nanosegundos, la pregunta de capacidad: ¿este usuario puede siquiera intentar mover dinero? Es el equivalente operativo de "la cuenta está activa y no bloqueada".

La pregunta de **cuánto** y **bajo qué condición** vive en Policy-Path — la misma capa que ya gobierna cualquier operación empresarial del stack:

```
bos_financial_limit
├── max_transaction      → límite por operación individual
├── max_daily             → límite acumulado por día
├── max_monthly           → límite acumulado por mes
├── currency               → BOB, USD, USDT si se habilita
└── tenant / pos_logico   → el límite puede variar por comercio afiliado

bos_financial_decision_matrix
├── requires_dual_approval_above   → umbral de doble firma
├── sod_profile                     → quién no puede aprobar lo que creó
└── escalation_path                 → a quién escala si se excede el límite
```

Esto no es una proyección teórica: es exactamente la estructura de JWT que ya documenta el Manual de Acoplamiento (§34):

```json
"financial": {
  "max_transaction": 5000,
  "sod_profile": "vendedor-sin-aprobacion",
  "requires_dual_approval_above": 1000
}
```

Una billetera de pagos es, desde la perspectiva de bAuth, **un usuario más con un perfil financiero**. El usuario final tiene su `max_transaction`. El comercio afiliado tiene el suyo. El operador que aprueba reversiones tiene su `sod_profile`. No hay pieza arquitectónica nueva por inventar — hay tablas por poblar con los perfiles de billetera (usuario, comercio, agente, operador), siguiendo el mismo patrón que ya se usa para cualquier rol del ERP.

---

## 3. D11 (Auditoría) aplicado al caso de uso

La pregunta que normalmente se intenta resolver recurriendo a blockchain — *¿puedo demostrar que esta transacción ocurrió exactamente así y no fue alterada después?* — ya tiene respuesta dentro de la metodología vigente:

```
bauth_audit_events   → WORM (Write Once Read Many), particionado
                        REVOKE UPDATE/DELETE a nivel de motor de base de datos
                        ctx_id obligatorio como hilo conductor de cada evento
                        Trigger SQL — asíncrono, no bloquea la operación principal
```

Una tabla WORM con `UPDATE`/`DELETE` revocados a nivel de base de datos, alimentada por triggers en cada operación, replicada y respaldada (pgBackRest, según el Manual de Acoplamiento §S01), constituye un registro inmutable en el sentido práctico: nadie con acceso operativo normal puede alterarlo retroactivamente sin dejar evidencia forense.

El límite real de esta capa, sin blockchain, es preciso y vale la pena nombrarlo sin ambigüedad: D11 no ofrece **inmutabilidad verificable por un tercero que no confía en la infraestructura de SBOS**. Si un regulador, un banco corresponsal o un auditor externo necesitan confirmar la integridad de los registros sin depender de la palabra de SBOS sobre su propia base de datos, ahí es donde D11, por sólido que esté implementado, llega a su techo natural — y exactamente esa es la pregunta que blockchain responde.

---

## 4. Conclusión de suficiencia

**SBOS, tal como existe hoy, es suficiente para operar una billetera de pagos.** La arquitectura de 11 dominios provee:

- Identidad fuerte (D9 + D5)
- Límites y doble aprobación por transacción (D3)
- Contexto de origen verificado (D6, D7, D8)
- Trazabilidad completa, inmutable a nivel de aplicación (D11)

Lo que falta no es capacidad de control: es trabajo de población de datos y de ficha SBOS — definir los `RolTemplate` de billetera, cargar las tablas de `bos_financial_limit` con los montos operativos reales, y construir la integración con el riel de pago externo elegido.

**Blockchain no es un bloqueante para lanzar.** Es una decisión de diseño posterior que se activa cuando el objetivo del proyecto cambia de "operar" a "vender la confianza". Eso es lo que desarrolla la Parte II.

---//---

# PARTE II — D12 Y EL MODELO DE NEGOCIO

## 5. D12 — Tres variantes de incorporación de blockchain

Si el proyecto decide incorporar blockchain, existen tres formas distintas de hacerlo. No son intercambiables: cada una resuelve un problema diferente, tiene un costo de implementación distinto, y conlleva un nivel de riesgo propio.

### 5.1 Variante A — Ancla de auditoría (refuerzo de D11)

| Atributo | Definición |
|---|---|
| Qué resuelve | Verificabilidad externa de que `bauth_audit_events` no fue alterado |
| Método | External-Path, anclaje periódico |
| Qué se publica en la cadena | Únicamente el hash (Merkle root) de un lote de eventos de auditoría — nunca datos financieros ni personales |
| Cadena recomendada | Pública, capa 2 de Ethereum — el punto es que sea verificable por cualquiera sin depender de SBOS |
| Frecuencia | Por lote (cada hora o cada N transacciones), no por transacción individual |
| Impacto en latencia | Ninguno — operación asíncrona, igual que el resto de D11 |
| Qué gana el sistema | Cualquier tercero (regulador, auditor, usuario) puede verificar matemáticamente que un registro de auditoría no fue editado después de su fecha, sin depender de la palabra de SBOS |
| Qué no cambia | El control de acceso, los límites financieros y las aprobaciones permanecen exactamente en D3, sin modificación |
| Esfuerzo de implementación | Bajo — un proceso periódico que calcula un Merkle root y lo publica; no toca el camino crítico de ninguna operación |

Esta es la variante de menor riesgo y mejor relación esfuerzo/beneficio. No introduce dependencias críticas en el camino de una transacción: si la cadena pública estuviera temporalmente inaccesible, la billetera sigue operando con normalidad y el anclaje simplemente se reintenta.

### 5.2 Variante B — Motor de liquidación (refuerzo de D3)

| Atributo | Definición |
|---|---|
| Qué resuelve | Mover el valor mismo entre entidades que no confían entre sí, sin depender de un banco corresponsal en cada operación |
| Método | Fast-Path (firma) + Policy-Path (límites, igual que D3 hoy) |
| Qué se publica en la cadena | Las transacciones reales — monto, origen, destino — en una red permisionada, no pública |
| Impacto en latencia | Significativo: de menos de 5ms (consulta en PostgreSQL) a la latencia de finalidad del consenso elegido — del orden de 1 a 3 segundos |
| Qué gana el sistema | Independencia operativa frente a un banco corresponsal para liquidar entre nodos propios — relevante si el negocio involucra varias entidades (múltiples comercios, agentes, sucursales) liquidando entre sí |
| Qué cambia | D3 deja de apoyarse solo en PostgreSQL + reglas; la liquidación final ocurre en la cadena, y PostgreSQL pasa a ser capa de consulta rápida, no fuente de verdad del saldo |
| Esfuerzo de implementación | Alto — requiere operar una red de validadores, gestionar claves de firma por entidad, y migrar el modelo de "saldo en una tabla" a "saldo derivado del estado de la cadena" |
| Riesgo regulatorio | Si la liquidación final ocurre fuera del sistema financiero tradicional, esto entra en el terreno que el regulador boliviano ya contempla activamente bajo su categoría explícita de "blockchain" — exige declararlo desde la carta de intención |

Esta variante solo se justifica si el modelo de negocio necesita mover valor entre partes que no se conocen ni confían entre sí, sin pasar por un banco en cada operación. Si el modelo es "usuarios y comercios liquidando contra un único emisor central", esta complejidad no aporta beneficio — un banco corresponsal o el riel de pago interoperable local ya resuelven la liquidación de forma más simple y con menor riesgo operativo.

### 5.3 Variante C — Reemplazo del BitMask (descartada)

| Atributo | Definición |
|---|---|
| Qué resuelve | Nada que D3 Fast-Path no resuelva ya, con una latencia muchísimo peor |
| Método | Firma criptográfica verificada en cadena, en lugar de operación AND bitwise en memoria |
| Latencia | De menos de 0.5 nanosegundos a decenas de milisegundos (verificación local) o segundos (confirmación en cadena) |
| Evaluación | No recomendada |

Se incluye esta variante únicamente para descartarla con su propio razonamiento. El BitMask Fast-Path existe precisamente porque ciertas decisiones — ¿puede este usuario abrir esta puerta, hacer este click, iniciar esta transacción? — necesitan resolverse en sub-milisegundos. Reemplazarlo por verificación en cadena reintroduce exactamente la latencia que el modelo de tres capas fue diseñado para evitar. La firma criptográfica de clave privada/pública ya vive en D9 (Credenciales), vía Keycloak; blockchain no añade firma digital donde ya existe — añade verificabilidad externa de esa firma, que es un problema distinto.

### 5.4 Secuencia recomendada

```
Fase actual    →  Construir D3 + D11 para billetera con la metodología vigente
                   (poblar RolTemplate, financial_limit, decision_matrix).
                   Esto ya permite operar la billetera de extremo a extremo.

+3-6 meses     →  Si el regulador, un banco corresponsal, o los propios
                   términos de servicio exigen verificabilidad externa
                   de auditoría: implementar D12 Variante A — bajo riesgo,
                   bajo esfuerzo, sin impacto en el camino crítico.

+12 meses      →  Solo si el modelo de negocio madura hacia liquidación
                   entre múltiples entidades sin confianza mutua:
                   evaluar D12 Variante B, declarando explícitamente
                   la categoría "blockchain" ante el regulador desde
                   el inicio del trámite correspondiente.

Nunca          →  Variante C. El Fast-Path BitMask ya es la herramienta
                   correcta para autorización de sub-milisegundo.
```

---

## 6. De operar una billetera a vender el plano de control

### 6.1 La categoría de mercado en la que el proyecto ya encaja

Lo que describe la metodología bAuth completa —11 dominios, 3 capas de control, auditoría WORM, BitMask de sub-milisegundo, y ahora un ancla de verificabilidad externa— no es una billetera. Es la definición operativa de tres categorías de negocio que el mercado ya reconoce y remunera:

| Categoría | Qué vende | Quién la compra | Cobertura actual de SBOS |
|---|---|---|---|
| IDaaS / IAM-as-a-Service | Identidad, autenticación y autorización como servicio gestionado | Cualquier empresa que necesita login y permisos sin construirlo | D1, D5, D9, D10 |
| RegTech / Compliance-as-a-Service | Cumplimiento normativo automatizado: KYC, AML, auditoría, reportes regulatorios | Bancos, fintechs, aseguradoras sujetas a supervisión | D3, D6, D11 |
| Trust-as-a-Service | Verificabilidad externa de que los datos o decisiones de una empresa no fueron alterados | Cualquier empresa que necesite demostrar integridad a un regulador o auditor | D11 + D12 |

Esto no es una intuición de posicionamiento: el modelo de Regtech-as-a-Service (RaaS) está emergiendo precisamente como la forma de entregar compliance ágil — escaneo regulatorio en tiempo real, evaluaciones de impacto automatizadas e integración vía API, bajo modelo de suscripción cloud-native. Y, específicamente sobre el rol de blockchain dentro de esa categoría, su naturaleza inmutable y descentralizada ofrece un método transparente y seguro de registrar transacciones y verificar identidades, permitiendo almacenamiento de datos a prueba de manipulación y gestión de cumplimiento eficiente mediante un rastro de auditoría transparente — que es, casi palabra por palabra, lo que D11 + D12 Variante A ya hacen en esta arquitectura.

### 6.2 Lo que diferencia esta oferta de una RegTech típica

La mayoría de soluciones RegTech del mercado son capas que se añaden por encima de sistemas ya existentes — se conectan vía API a un core ajeno y observan desde afuera. La posición de SBOS es estructuralmente distinta:

- **No es un observador externo: es el sistema operativo sobre el que corre la empresa.** El control de identidad y auditoría no es un añadido — es nativo, con cero latencia de integración externa y cero superficie de "API de terceros que alguien puede desconectar".
- **Los 11 dominios cubren más superficie que un IAM tradicional.** Productos como Okta o Auth0 resuelven D1 (lógico) y parte de D9 (credenciales); no resuelven D2 (físico — puertas, cajones de punto de venta), D3 (financiero con separación de funciones y doble aprobación), ni D6 (geoespacial con detección de viaje imposible).
- **El modelo de tres capas (Fast-Path / Policy-Path / External-Path) es, en sí mismo, propiedad intelectual vendible.** Es un marco de decisión —qué se resuelve en bits, qué en reglas, qué en servicios externos— que cualquier empresa que construya su propio IAM tiene que inventar desde cero. SBOS ya lo tiene documentado y probado.

### 6.3 Lo que se vende, según la audiencia

A un **inversor** no se le vende blockchain ni una billetera. Se le vende una tesis de infraestructura: el plano de control de identidad, autorización y auditoría que toda empresa que mueve dinero o datos sensibles necesita, construido nativo en lugar de añadido, con blockchain como la pieza que lo hace verificable por terceros sin pedirles que confíen en la palabra de SBOS. Esta tesis es defendible con lo que ya está construido y documentado — el riesgo de ejecución es bajo porque D1 a D11 no son promesas, son sistema funcionando.

A una **empresa cliente** se le vende una de cuatro ofertas concretas, desarrolladas en la sección 7, en orden de madurez creciente: Compliance-in-a-Box, Billetera White-Label, IAM Soberano, y Trust Layer.

### 6.4 La corriente de mercado detrás de esta tesis

La integración de blockchain y RegTech está abriendo camino a contratos inteligentes codificados con lógica regulatoria — contratos capaces de hacer cumplir el compliance automáticamente, por ejemplo impidiendo que una transacción se ejecute si viola una regla de sanciones, fusionando efectivamente la ley con el código. Sobre la magnitud de esta tendencia, el Foro Económico Mundial proyecta que para 2027 el 10% del PIB global estará almacenado en plataformas blockchain.

La predicción más relevante para el posicionamiento específico de este proyecto: los ganadores en el sector de servicios financieros serán quienes provean "Safety Stacks" — planos de control integrales que aseguren que los sistemas y agentes automatizados operen dentro de límites seguros — y esto probablemente se convertirá en requisito arquitectónico estándar para todo software financiero. Un "Safety Stack", un plano de control integral, es la definición misma de SBOS. La diferencia entre tener una billetera de pagos y tener una tesis de negocio en RegTech/Trust-as-a-Service es que la segunda no depende de que el proyecto obtenga licencia propia como entidad de pagos: el plano de control se vende a empresas que sí están reguladas, sin que SBOS mismo necesite serlo.

---

## 7. Catálogo de productos

Cuatro productos, derivados directamente de los dominios bAuth y de las variantes de D12, no mutuamente excluyentes — son capas de un mismo plano de control, empaquetadas según cuánto control quiere ceder el cliente y cuánto quiere conservar.

```
Menor integración, venta más rápida ────────────────► Mayor integración, venta más lenta

   7.4                    7.1                       7.2                       7.3
Trust Layer      Compliance-in-a-Box       Billetera White-Label        IAM Soberano
(un módulo)      (tres dominios)           (producto vertical)          (los 11 dominios)
```

### 7.1 Producto A — Compliance-in-a-Box

**Definición.** D3 (Financiero) + D11 (Auditoría) + D12 Variante A (ancla verificable), entregados como servicio gestionado vía API. El cliente conserva su propio sistema; SBOS resuelve todas las decisiones de "¿puede esta operación proceder?" y todo el registro de "¿qué ocurrió?".

| Componente | Lo que recibe el cliente |
|---|---|
| API de autorización financiera | Endpoint que recibe `{usuario, monto, tipo_operación, moneda}` y responde `{autorizado, requiere_doble_aprobación, motivo}` en menos de 5ms |
| Motor de límites configurable | Panel donde el cliente define `max_transaction`, `max_daily`, `sod_profile` por rol, sin tocar código |
| Registro WORM con ancla verificable | Cada decisión queda en `bauth_audit_events`, con Merkle root anclado periódicamente — el cliente puede entregar a su propio regulador un certificado de integridad verificable por cualquiera |
| Panel de cumplimiento | Vista para el oficial de cumplimiento del cliente: transacciones bloqueadas, aprobaciones pendientes, alertas de SoD |
| Reporte regulatorio exportable | Generación automática de los reportes que el regulador exige, con el ancla blockchain como evidencia de no-alteración |

**Audiencia.** Fintechs pequeñas y medianas que ya tienen producto propio pero no quieren construir desde cero el motor de límites, SoD y auditoría que su regulador exige. Comercios o agregadores de pago que necesitan demostrar control interno sin ser ellos mismos entidad regulada.

**Modelo de cobro.** SaaS por volumen: cuota base mensual más costo marginal por transacción evaluada. Alternativa: cuota fija por certificado de cumplimiento emitido, para auditorías puntuales.

**Trabajo pendiente.** Capa de multi-tenancy comercial — API pública documentada, autenticación por API key por cliente, y aislamiento de datos verificable entre clientes, no solo lógico sino demostrable ante la auditoría de cada uno.

**Riesgo principal.** Si la API de autorización falla o degrada en latencia, el cliente no puede procesar sus propias transacciones — el proveedor se convierte en punto único de fallo del negocio del cliente. Exige SLA serio y alta disponibilidad antes de comercializarse en serio.

**Por qué es el más rápido de vender.** Resuelve un dolor con fecha límite real: los plazos de adecuación del marco fintech boliviano ya están corriendo. Una fintech sin esta capa resuelta enfrenta presión de tiempo concreta, no teórica.

### 7.2 Producto B — Billetera White-Label

**Definición.** El producto más concreto y de demostración más directa, porque es la misma billetera que el proyecto ya está construyendo para uso propio, ofrecida como base reutilizable para que otra empresa lance su propia billetera sin construir la arquitectura de control desde cero.

| Componente | Lo que recibe el cliente |
|---|---|
| Motor de cuentas y saldo | Sobre PostgreSQL + bKernel, con `RolTemplate` ya definido para usuario final, comercio afiliado, agente |
| Autenticación y onboarding | Keycloak + bAuth preconfigurados: KYC, MFA, biometría (D5/D9), listos para reconfigurar con la marca del cliente |
| Control financiero completo | D3 con límites, SoD y doble aprobación — el cliente define sus propios umbrales sin tocar el motor |
| Integración a rieles de pago | Conexión ya construida al riel de pago elegido (QR interoperable, switch local, banco corresponsal) |
| Auditoría con ancla blockchain | D11 + D12-A — evidencia de integridad disponible desde el primer día de operación |
| Capa de marca | Frontend white-label — logo, nombre comercial y flujo de UX del cliente sobre el motor compartido |

**Audiencia.** Comercios grandes que quieren billetera de marca propia (retail, telecomunicaciones, cooperativas) sin construir infraestructura durante años. Emprendedores fintech con idea de negocio y capital, sin equipo técnico para construir el plano de control desde cero.

**Modelo de cobro.** Licencia de plataforma — cuota de implementación inicial más personalización de marca — más cuota recurrente por transacción procesada o por usuario activo mensual. El modelo estándar de Banking-as-a-Service, aplicado sobre este stack en lugar de un core bancario tradicional.

**Trabajo pendiente.** Separación real de marca y motor — que dos clientes distintos operen billeteras con apariencia totalmente distinta sobre la misma infraestructura compartida, sin que un cliente vea ni un dato del otro.

**Riesgo principal.** Regulatorio, no técnico. Operar infraestructura de pagos para terceros puede interpretarse como prestación indirecta de un servicio de pago, incluso si la marca y la relación con el usuario final son del cliente. Requiere asesoría legal específica antes de comercializarse.

**Por qué es el más persuasivo para un inversor.** Es el único de los cuatro con mercado comparable directo y visible — Banking-as-a-Service y Wallet-as-a-Service son categorías ya validadas globalmente, y este proyecto llevaría esa misma categoría a un mercado regional donde casi no existe oferta local.

### 7.3 Producto C — IAM Soberano

**Definición.** No una pieza del plano de control: el plano completo. Los 11 dominios de bAuth como sistema de identidad, autorización y auditoría del cliente, reemplazando lo que hoy resuelve con soluciones extranjeras o, más frecuentemente, con permisos hardcodeados sin trazabilidad real.

| Componente | Lo que recibe el cliente |
|---|---|
| D1 Lógico | Control de aplicaciones y operaciones por usuario, vía BitMask de sub-milisegundo |
| D2 Físico | Control de puertas, cajones, zonas — ausente en cualquier IAM tradicional |
| D3 Financiero | Límites, SoD, doble aprobación — integrado nativamente, no vía API externa |
| D4–D9 | Horarios, biometría, geolocalización, red, contexto de sesión, ciclo de vida de credenciales |
| D10 Delegación | Privilegios temporales auto-revocables |
| D11 + D12 | Auditoría completa, con ancla verificable opcional |

**Audiencia.** Empresas medianas y grandes con múltiples sistemas internos sin capa de identidad unificada — el problema clásico de varios logins sin que nadie sepa con certeza quién puede hacer qué. Particularmente atractivo para empresas con presencia física y digital simultánea, donde D2 se vuelve diferenciador frente a cualquier IAM importado.

**Modelo de cobro.** Licencia enterprise — cuota anual por usuarios gestionados más servicio de implementación inicial, típicamente la fase más costosa y más rentable de la venta.

**Trabajo pendiente.** El menor de los cuatro productos en adaptación técnica nueva — es desplegar SBOS completo para un tenant externo, caso de uso ya documentado paso a paso en el Manual de Acoplamiento. Lo pendiente es comercial: proceso de ventas enterprise y casos de referencia.

**Riesgo principal.** Ciclo de venta largo, típico de software enterprise. No es el primer producto para generar ingresos rápidos, pero sí el de mayor ticket y defensibilidad a largo plazo: migrar identidad completa a otro proveedor es costoso para cualquier cliente, lo que genera retención saludable.

**Por qué importa para la tesis de inversión.** Valida la afirmación de "Safety Stack" — la prueba de que SBOS es infraestructura horizontal aplicable a cualquier empresa que necesite control de identidad serio, no una herramienta de nicho para pagos.

### 7.4 Producto D — Trust Layer White-Label

**Definición.** El producto más pequeño y de menor fricción: solo el módulo D12 (ancla de auditoría verificable), ofrecido como complemento a un sistema que el cliente ya tiene y no piensa reemplazar.

| Componente | Lo que recibe el cliente |
|---|---|
| SDK / conector ligero | Librería que el cliente integra para enviar hashes de sus propios registros — nunca los datos, solo el hash |
| Servicio de anclaje | Cálculo de Merkle root por lotes y publicación en la cadena pública elegida |
| Certificado de verificación | Mecanismo para que cualquier tercero confirme que un registro corresponde al hash anclado en una fecha determinada, sin confiar ni en el cliente ni en SBOS |
| Panel de verificación pública | Página donde cualquiera puede verificar la integridad de un registro específico |

**Audiencia.** Empresas con sistema de auditoría interno propio que necesitan, por exigencia regulatoria o diferenciación competitiva, demostrar verificabilidad externa sin reconstruir nada de lo existente.

**Modelo de cobro.** El más simple de los cuatro — cuota fija mensual por volumen de registros anclados, o modelo freemium con conversión a partir de cierto volumen.

**Trabajo pendiente.** El de mayor desarrollo relativo a lo ya existente — convertir D12-A (diseñado para anclar la tabla propia) en SDK genérico capaz de recibir hashes de cualquier sistema externo. Conceptualmente simple: la misma lógica de Merkle root, generalizada.

**Riesgo principal.** Es el más fácil de replicar por terceros — la lógica de anclaje no es una barrera técnica alta. El diferenciador real no es la idea, es la distribución: vendido a clientes que ya usan los Productos A, B o C, es un upsell natural de bajo costo de adquisición.

**Por qué vale la pena tenerlo en el catálogo.** Es la puerta de entrada de menor fricción para clientes grandes y conservadores que nunca comprarían los otros tres productos de entrada — sirve para conseguir el primer cliente y demostrar valor antes de proponer algo más profundo.

### 7.5 Comparación y orden de construcción

| | A · Compliance-in-a-Box | B · Billetera White-Label | C · IAM Soberano | D · Trust Layer |
|---|---|---|---|---|
| Dominios bAuth usados | D3, D11, D12-A | D1, D3, D5, D9, D11, D12-A | Los 11 + D12 | D11, D12-A generalizado |
| Ciclo de venta | Medio | Medio-largo | Largo | Corto |
| Ticket promedio | Medio | Alto | Muy alto | Bajo |
| Riesgo regulatorio propio | Bajo | Alto | Bajo | Muy bajo |
| Esfuerzo de construcción adicional | Medio | Alto | Bajo | Medio |
| Mejor para | Ingresos rápidos con fintechs reguladas | La tesis de inversión más vistosa | Defensibilidad de largo plazo | Pie en la puerta de clientes grandes |

**Orden de construcción recomendado:**

1. **Producto A** primero — subconjunto directo de lo que ya se construye para uso propio.
2. **Producto D** segundo — una vez que D12-A funciona para el caso propio, generalizar el SDK es esfuerzo acotado.
3. **Producto B** tercero — una vez que la billetera propia opere con resultados reales que mostrar.
4. **Producto C** en paralelo desde el primer cliente de referencia — venta de ciclo largo que se beneficia de casos de éxito previos, sin depender de que A, B o D estén terminados.

---//---

# PARTE III — IMPLEMENTACIÓN TÉCNICA

## 8. Patrón de integración y roadmap

### 8.1 Principio de integración

D12 no es una pieza aislada: encaja en una regla ya establecida en el Manual de Acoplamiento — las conexiones HTTP entre daemons internos están vetadas (ADR-012), y un único daemon (biedata) está autorizado a realizar conexiones salientes al exterior. Esto significa que, sea cual sea el componente blockchain elegido, se conecta al resto de SBOS exclusivamente a través de una ficha biedata, nunca llamando directo desde bKernel o bAuth.

```
bKernel (detecta evento de auditoría)
   → Redis Stream: biedata:blockchain:anchor
      → biedata consume el stream
         → ejecuta caja boxes/export/blockchain_anchor/
            VALIDATE → AUTHENTICATE → EXTRACT → TRANSFORM → LOAD → AUDIT
         → conexión segura al RPC de la red elegida (o al nodo propio en Variante B)
      → biedata_db registra el resultado (hash de transacción on-chain)
   → bKernel detecta esa escritura → actualiza bauth_audit_events con la prueba
```

El stack técnico de D12 se reduce, en su mayor parte, a construir una ficha biedata adicional — el mismo patrón ya usado para integraciones fiscales existentes — no un subsistema nuevo desconectado del resto de la plataforma.

### 8.2 Lo que no se construye

Un error común en proyectos de blockchain es sobre-construir antes de validar demanda. Este proyecto evita deliberadamente:

- **Una blockchain pública nueva.** No existe razón de negocio para que el proyecto tenga su propio token o su propia cadena pública con minería o staking abierto a terceros desconocidos — eso es un proyecto de criptomoneda, no infraestructura de confianza empresarial.
- **Operación de un nodo completo en la Variante A.** Un proveedor de RPC gestionado es la decisión correcta en esta fase; operar nodo propio es esfuerzo operativo sin beneficio adicional para el caso de uso de anclaje.
- **Exposición de la clave privada del usuario final, en cualquier escenario.** Tanto en Variante A (el usuario no tiene clave — el anclaje lo hace el sistema) como en Variante B (custodia gestionada), se evita deliberadamente el modelo de auto-custodia típico de cripto retail, que introduce un vector de pérdida de fondos por error de usuario inaceptable para cualquier regulador o inversor de fintech tradicional.

### 8.3 Roadmap con hitos verificables

```
Semana 1-2   →  Caja biedata "blockchain_anchor": fases VALIDATE/AUTHENTICATE.
                 Integración con el gestor de secretos para la clave de firma.
                 Cuenta en proveedor RPC (testnet de la red L2 elegida).

Semana 3-4   →  Cálculo de Merkle root sobre bauth_audit_events.
                 Primera transacción de anclaje en testnet — hito demostrable.

Semana 5-6   →  Job periódico en producción (mainnet de la L2).
                 Panel de verificación pública — hito demostrable a inversores.

Semana 7-8   →  Reporte de cumplimiento exportable con prueba de anclaje
                 incluida — listo para el primer cliente piloto del
                 Producto A (Compliance-in-a-Box).

Mes 3+       →  Solo si el Producto B (Billetera White-Label multi-entidad)
                 confirma tracción comercial: iniciar diseño de la Variante B
                 como iniciativa separada, con equipo y presupuesto propios —
                 no se mezcla con el roadmap de los dos primeros meses.
```

El hito de la semana 3-4 — primera transacción de anclaje verificable en testnet — es deliberadamente temprano: es la prueba de concepto mínima que un inversor puede pedir ver funcionando antes de comprometer capital, con un costo de llegada bajo tanto en tiempo como en infraestructura.

---

## 9. Catálogo de software libre, por capa, alineado a estándares internacionales

Cada elección de esta sección está filtrada por tres criterios simultáneos: **software libre o de código abierto verificable**, **alineado a un estándar internacional reconocido** (el proyecto de referencia de ese estándar, no una implementación propietaria), y **en uso productivo real por instituciones financieras**, no solo en proyectos experimentales.

### 9.1 Capa de identidad y credenciales — el puente entre D9 y D12

| Software / estándar | Qué es | Licencia | Estándar implementado | Evidencia de madurez |
|---|---|---|---|---|
| **W3C Decentralized Identifiers (DID)** | Especificación de identificadores verificables y descentralizados — define cómo una identidad puede probarse criptográficamente sin depender de un proveedor central | Especificación abierta, royalty-free | W3C DID Core, versión 1.1, Candidate Recommendation Snapshot del 5 de marzo de 2026 | Mantenida activamente por el W3C DID Working Group, con implementaciones de referencia múltiples e independientes |
| **W3C Verifiable Credentials (VC)** | Estándar para credenciales firmadas criptográficamente, verificables sin contactar al emisor original | Especificación abierta, CC BY-SA / royalty-free | W3C VC Data Model — la mayoría de los documentos de esta familia ya tienen estatus de W3C Recommendation | Pilar central de Self-Sovereign Identity junto con DID y blockchain; usado en credenciales gubernamentales y diplomas digitales |
| **DIF Universal Resolver** | Implementación de referencia open source para resolver un DID a su documento, independiente de la red blockchain de anclaje | Apache 2.0 | Capa de resolución requerida por el estándar DID | Proyecto de referencia de la Decentralized Identity Foundation, base de múltiples wallets de identidad |

Adoptar DID/VC como formato de las credenciales que D9 ya gestiona (`bauth_mfa_enrollments`, `bos_credential_policy`) es la forma estándar-internacional de hacer que el sistema de identidad sea verificable por terceros sin exponer la base de datos interna — complementario a D12 Variante A para el caso específico de identidad.

### 9.2 Capa de cliente blockchain

| Software | Qué es | Licencia | Estándar implementado | Evidencia de producción real |
|---|---|---|---|---|
| **Hyperledger Besu** | Cliente Ethereum diseñado desde su origen para uso enterprise, compatible tanto con red pública como con redes permisionadas privadas | Apache 2.0 | Protocolo Ethereum completo (EVM, JSON-RPC estándar) más extensiones enterprise bajo el marco de la Enterprise Ethereum Alliance | Opera entre el 9.5% y el 16% de los nodos de la red principal de Ethereum, tercer cliente de ejecución más usado; en el sector financiero, es el cliente que opera el eNaira del banco central de Nigeria y el proyecto mBridge de pagos transfronterizos entre Hong Kong, Tailandia, China y los Emiratos Árabes Unidos |
| **`ethers-rs`** | Librería Rust para construir, firmar y enviar transacciones a redes compatibles con Ethereum | MIT / Apache 2.0 (dual) | JSON-RPC de Ethereum, EIP-155, EIP-1559 | Una de las librerías Rust más usadas en producción para integración con Ethereum, mantenida activamente |

Hyperledger Besu es la elección tanto para la Variante A como para la Variante B, por tres razones: reutiliza exactamente las mismas herramientas en ambos casos, evitando duplicar el stack de cliente blockchain; tiene respaldo institucional financiero directo, con su grupo de trabajo de servicios financieros presidido por DTCC y con Citi y el Banco de Desarrollo de Brasil como miembros de la fundación que lo sostiene; y ya está validado en el caso de uso más cercano al de este proyecto — una moneda digital de banco central operando en producción.

### 9.3 Capa de consenso permisionado — solo si se construye la Variante B

| Mecanismo | Cuándo usarlo | Origen / estándar |
|---|---|---|
| **QBFT** (Quorum Byzantine Fault Tolerant) | Recomendado — consorcio permisionado con validadores conocidos | Variante de PBFT, el algoritmo académico de referencia para tolerancia a fallos bizantinos en sistemas distribuidos |
| **IBFT 2.0** | Alternativa válida, predecesor directo de QBFT, aún soportado | Mismo linaje BFT |
| **Clique (Proof of Authority)** | Más simple, menor garantía de seguridad bizantina | Generalmente no recomendado para producción financiera |

QBFT es la elección correcta para D3 replicado on-chain: tolera nodos bizantinos —no solo caídos, sino potencialmente comprometidos o maliciosos— que es el modelo de amenaza correcto para un sistema que mueve dinero entre entidades sin confianza ciega mutua.

### 9.4 Capa de custodia de claves

| Software | Qué es | Licencia | Estándar implementado | Encaje con el stack existente |
|---|---|---|---|---|
| **Vault (HashiCorp, Community Edition)** | Gestor de secretos ya presente en el stack | MPL 2.0 | Soporta PKCS#11, estándar internacional OASIS para interacción con dispositivos criptográficos | Ya gestiona los certificados y secretos del stack — la clave de firma blockchain extiende un sistema operado, no introduce uno nuevo |
| **SoftHSM2** | Implementación de software de un HSM, expone interfaz PKCS#11 idéntica a un HSM físico | Apache 2.0 | PKCS#11 v3.2 — soporta ECDSA, EdDSA (Ed25519/Ed448) y las curvas elípticas que blockchain requiere | Permite desarrollar y probar con la misma interfaz que se usará en producción, sin comprar hardware en la fase inicial; capacidad FIPS 140-2 cuando se enlaza con una build de OpenSSL certificada |
| **HSM físico** (para producción a escala) | Dispositivo dedicado de hardware para custodia de claves | N/A (hardware) | FIPS 140-2 Nivel 2 o 3 según el modelo — estándar NIST para validación de módulos criptográficos | Vault soporta integración nativa vía PKCS#11, incluyendo modo de protección reforzada para entornos de alta seguridad |

**Ruta de adopción.** SoftHSM2 en desarrollo y en la fase inicial de producción (Variante A, donde el riesgo de una clave comprometida es acotado porque solo firma anclajes de auditoría). HSM físico cuando se persiga la Variante B, donde la clave de validador firma bloques que mueven valor real y merece el nivel de protección que exige FIPS 140-2 Nivel 3.

### 9.5 Capa de gestión de claves a escala

| Software | Qué es | Licencia | Estándar implementado |
|---|---|---|---|
| **Cosmian KMS** | Sistema de gestión de claves multi-tenant diseñado para escalar | Licencia abierta — verificar términos vigentes de la versión específica antes de adoptar | KMIP 1.0–2.1, estándar OASIS de interoperabilidad entre sistemas de gestión de claves; soporta PKCS#11; modo FIPS 140-3 por defecto |

No es necesaria para el roadmap de ocho semanas — es la evolución natural cuando el catálogo de productos pase de un cliente piloto a decenas de clientes, cada uno requiriendo aislamiento criptográfico verificable de los demás.

### 9.6 Estándar de desarrollo seguro

| Estándar | Qué cubre | Por qué aplica |
|---|---|---|
| **OWASP ASVS 5.0** | Marco abierto de requisitos de seguridad para aplicaciones y APIs — catorce categorías incluyendo criptografía, control de acceso, gestión de sesión | Licencia Creative Commons CC BY-SA 4.0. Nivel 2, el recomendado para aplicaciones que manejan datos financieros, es la vara de medida correcta para todo el código nuevo de D12 |
| **PCI DSS 4.0.1**, Requisitos 6.2/6.3 | Prácticas de desarrollo seguro para aplicaciones que procesan datos de pago | La evidencia de verificación ASVS Nivel 2 es aceptada en la práctica por la mayoría de auditores como evidencia primaria para estos requisitos |
| **NIST SP 800-57** | Recomendaciones para gestión del ciclo de vida de claves criptográficas | Ya referenciado en D9 de la metodología base — D12 hereda el mismo estándar para la clave de firma blockchain, sin introducir uno nuevo |

### 9.7 Resumen consolidado

| Capa | Software elegido | Licencia | Estándar ancla |
|---|---|---|---|
| Identidad verificable | W3C DID + VC, DIF Universal Resolver | Apache 2.0 / especificación abierta | W3C DID Core 1.1, W3C VC Data Model |
| Cliente blockchain (ambas variantes) | Hyperledger Besu | Apache 2.0 | Protocolo Ethereum, Enterprise Ethereum Alliance |
| Librería de firma y transacciones | `ethers-rs` | MIT / Apache 2.0 | JSON-RPC Ethereum, EIP-155, EIP-1559 |
| Consenso (solo Variante B) | QBFT sobre Besu | Apache 2.0 | PBFT académico, Enterprise Ethereum Alliance |
| Custodia de claves — desarrollo | SoftHSM2 | Apache 2.0 | PKCS#11 v3.2 |
| Custodia de claves — producción | Vault + HSM físico | MPL 2.0 (Vault CE) | PKCS#11, FIPS 140-2/3 |
| Gestión de claves multi-cliente (futuro) | Cosmian KMS | Verificar licencia vigente | KMIP 1.0–2.1, FIPS 140-3 |
| Estándar de seguridad de código | OWASP ASVS 5.0 (proceso, no software) | CC BY-SA 4.0 | Mapea a PCI DSS 4.0.1, ISO 27001, NIST SP 800-53 |

Cada pieza de este catálogo es reemplazable de forma independiente: ninguna decisión crea dependencia irreversible de un proveedor específico, porque cada componente implementa un estándar abierto en lugar de un protocolo propietario. Esto es, en sí mismo, un argumento de reducción de riesgo: el stack no depende de que ninguna empresa privada particular continúe existiendo o mantenga condiciones de licencia favorables.

---//---

# ANEXO A — MARCO REGULATORIO

*Resumen orientativo, separado deliberadamente del cuerpo técnico de este documento. No constituye asesoría legal.*

**A.1 — Marco aplicable.** El reglamento boliviano para Empresas de Tecnología Financiera (ETF), vigente desde 2025, reconoce cinco categorías de operación, una de ellas explícitamente "blockchain" — lo que significa que perseguir D12 Variante B (liquidación en cadena) es una actividad ya contemplada por el regulador, no un vacío legal.

**A.2 — Vía de entrada.** El Entorno Controlado de Pruebas (ECP) es la vía de menor fricción: permite operar con usuarios y montos reales pero limitados, bajo supervisión directa, durante un período inicial de hasta 12 meses prorrogable a 36, con un depósito reembolsable de monto modesto — sin el requisito de capital mínimo propio de una licencia bancaria tradicional.

**A.3 — Implicación para el catálogo de productos.** Los Productos A (Compliance-in-a-Box) y D (Trust Layer) no requieren que el proyecto mismo sea una entidad regulada — se venden a empresas que sí lo son o están en proceso de regularizarse, por lo que la exposición regulatoria directa es baja. El Producto B (Billetera White-Label) sí requiere asesoría legal específica, porque operar infraestructura de pagos para terceros puede interpretarse como prestación indirecta de un servicio de pago — el riesgo principal ya señalado en la sección 7.2.

**A.4 — Secuencia recomendada en paralelo al roadmap técnico.** Presentar la carta de intención ante el regulador (categoría "plataformas de pago" y, si se persigue la Variante B, también "blockchain") durante las primeras semanas del roadmap técnico de la sección 8.3, de forma que para el hito de la semana 7-8 (reporte de cumplimiento exportable) el proceso regulatorio esté avanzando en paralelo, no rezagado.

*Para el detalle completo de trámites, plazos y requisitos, se recomienda validar con asesoría legal especializada en el reglamento ETF antes de cualquier presentación formal.*

---//---

## Trazabilidad y control de versiones

| Sección | Fuente |
|---|---|
| Parte I (§1–4) | SBOS-BAUTH-DOMAIN-CONTROL-METHODOLOGY v1.0, proyectada sobre el caso de uso de billetera de pagos |
| §5 Variantes D12 | Análisis propio — extiende la metodología de 11 dominios con un dominio 12 opcional |
| §5.2 Riesgo regulatorio | Marco ETF boliviano, categoría "blockchain" como una de las cinco reconocidas |
| §6.1 Categorías de mercado IDaaS / RegTech / Trust-as-a-Service | TechMagic — RegTech Guide 2026; FinTech Connect — Regtech-as-a-Service |
| §6.1 Uso de blockchain para compartir KYC entre instituciones | Proxymity — Future of Compliance / RegTech Trends 2026 |
| §6.4 Contratos inteligentes regulatorios y proyección de PIB global en blockchain | Fintechly — Regtech vs Compliance Tech 2026; Proxymity — proyección WEF |
| §6.4 "Safety Stacks" como requisito arquitectónico futuro | Fintechly — Regtech vs Compliance Tech 2026 |
| §7 Catálogo de cuatro productos | Desarrollo propio — proyecta cada dominio / variante D12 sobre un modelo de producto SaaS/BaaS concreto |
| §7.3 Caso de uso de alta de tenant, reutilizado para IAM Soberano | SBOS-MANUAL-ACOPLAMIENTO v2.0 §12 |
| §8.1 Patrón de integración vía biedata | SBOS-MANUAL-ACOPLAMIENTO v2.0 §14; ADR-012 |
| §8.3 Costos de transacción en L2 de Ethereum | Bitcoin Foundation — Ethereum Gas Fee Solutions 2026; eco.com — Base vs Arbitrum 2026; CoinLaw — Gas Fee Markets L2 2026 |
| §9.1 W3C DID / VC como capa de identidad verificable | W3C — Decentralized Identifiers (DIDs) v1.1, Candidate Recommendation Snapshot, 5 de marzo de 2026; W3C — Verifiable Credentials Overview |
| §9.2 Hyperledger Besu como cliente de cadena | LF Decentralized Trust — página de proyecto Besu; ChainLaunch — Hyperledger Besu Guide 2026; Linux Foundation Education — Hyperledger Foundation Adds Citi/BNDES |
| §9.3 QBFT como mecanismo de consenso recomendado | LF Decentralized Trust — página de proyecto Besu; ChainLaunch — Hyperledger Besu Guide 2026 |
| §9.4 SoftHSM2, PKCS#11, Vault + HSM, FIPS 140-2/3 | GitHub softhsm/SoftHSMv2; documentación SoftHSM v2; HashiCorp Developer — Vault HSM integration |
| §9.5 Cosmian KMS y estándar KMIP | GitHub Cosmian/kms |
| §9.6 OWASP ASVS 5.0 y mapeo a PCI DSS 4.0.1 | SecureCodingHub — OWASP ASVS 5.0 Developer Guide 2026; Konfirmity — OWASP ASVS glossary 2026 |
| Anexo A — Marco regulatorio ETF | Análisis previo del camino regulatorio para proveedor de pagos en Bolivia, desarrollado en el marco de este proyecto |
| Estructura de JWT financiero citada en §2 | SBOS-MANUAL-ACOPLAMIENTO v2.0 §34 |

---

**Historial de versiones**

| Versión | Cambios |
|---|---|
| v2.1 | Añadido **Glosario** completo entre el Resumen Ejecutivo y el Índice — define D12 explícitamente como dominio nuevo y opcional (no parte de los 11 dominios originales), más todos los términos técnicos, siglas y nombres de tabla usados en el documento (dominios D1-D11, capas de control, conceptos financieros/regulatorios, conceptos de blockchain/criptografía, y conceptos de seguridad/cumplimiento técnico). Ampliado el Resumen Ejecutivo para aclarar la naturaleza de D12 desde su primera mención. |
| v2.0 | Reescritura completa del documento como pieza de proyecto profesional unificada: portada, resumen ejecutivo, índice, y reorganización de todo el contenido en tres partes narrativas (suficiencia arquitectónica, modelo de negocio, implementación técnica) más anexo regulatorio separado. Sin pérdida de contenido técnico respecto a v1.4 — reestructurado para lectura ejecutiva de principio a fin. |
| v1.4 | Catálogo exhaustivo de software libre por capa (identidad W3C DID/VC, cliente blockchain Hyperledger Besu, consenso QBFT, custodia de claves SoftHSM2/Vault/HSM, gestión de claves Cosmian KMS, estándar OWASP ASVS 5.0). Sustitución de Cosmos SDK por Hyperledger Besu en la Variante B. |
| v1.3 | Stack tecnológico de implementación para D12 por variante, roadmap con hitos verificables, sección de qué no se construye, Anexo regulatorio separado del cuerpo técnico. |
| v1.2 | Catálogo de los cuatro productos vendibles desarrollados en profundidad, con tabla comparativa y orden de construcción recomendado. |
| v1.1 | Modelo de negocio Trust-as-a-Service / RegTech-as-a-Service; ampliación del alcance del documento de "control de billetera propia" a "venta del plano de control a terceros". |
| v1.0 | Versión inicial — D12 como extensión de la metodología de 11 dominios, mapeo de D3/D11 sobre billetera de pagos, tres variantes de incorporación de blockchain. |

*SKULL · SBOS · SBOS-BAUTH-D12-BLOCKCHAIN-WALLET-CONTROL · v2.1 · Junio 2026*
