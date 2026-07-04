# SBOS-001-VISION
## Visión, Contexto y Principios del Proyecto SBOS

### SKULL · SBOS — Sovereign Business Operating System
### v5.0 · Actualización de Coherencia Arquitectónica · Marzo 2026

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [La Empresa: SKULL](#2-la-empresa-skull)
3. [El Producto: SBOS](#sbos)
4. [El Problema que Resuelve](#4-el-problema-que-resuelve)
5. [Los 6 Pilares del SBOS](#5-los-6-pilares-del-sbos)
6. [Los 8 Daemons Soberanos del SBOS](#6-los-8-daemons-soberanos-del-sbos)
7. [Contexto de Soberanía Digital 2026](#7-el-contexto-por-qué-ahora)
8. [Mercado Objetivo Iberoamericano](#8-el-mercado-objetivo)
9. [Posicionamiento Competitivo](#9-posicionamiento-competitivo)
10. [Los 15 Principios Rectores](#10-principios-rectores)
11. [Registro de Cambios v4.0](#11-registro-de-cambios-respecto-a-v30)

---

## 1. Resumen Ejecutivo

**SBOS** es el primer sistema operativo empresarial soberano diseñado para Iberoamérica. En una frase: instala en el servidor del cliente toda la infraestructura digital que una organización necesita para operar — ERP, RRHH, CRM, correo, comunicaciones, identidad, escritorio corporativo e inteligencia artificial — sin que ningún dato salga jamás de ese servidor y sin pagar licencias a ningún proveedor externo.

El problema que resuelve es concreto y costoso: una empresa mediana en Latinoamérica opera con entre 8 y 15 herramientas de software en silos, cada una con su propia versión de la verdad sobre los mismos datos, acumulando entre USD 3.000 y USD 8.000 mensuales en licencias SaaS, con sus datos financieros, de RRHH y de clientes almacenados en servidores bajo jurisdicción extranjera, sujetos a regulaciones y agencias de inteligencia de otros países. Cada proveedor puede subir sus precios, cambiar sus condiciones o simplemente desaparecer.

SBOS es para la **PYME iberoamericana** de 20 a 500 empleados que tiene datos sensibles, necesita cumplimiento tributario local, y quiere — o necesita — controlar su propia tecnología. También es para contadores que gestionan múltiples empresas, instituciones educativas, clínicas, y cualquier organización que deba demostrar soberanía sobre sus datos ante reguladores, clientes o directivos.

Los **tres principios que nunca se violan** en ninguna decisión de diseño son: (1) los datos del cliente nunca salen de su infraestructura, (2) el bKernel consolida datos entre aplicaciones sin modificar ninguna app ni su base de datos, y (3) el sistema es 100% open source con licencias libres — ningún proveedor puede revocar el acceso. Todo lo demás puede negociarse. Estos tres principios son restricciones de diseño, no aspiraciones.

Un cliente elegiría SBOS sobre SAP o Microsoft 365 por cuatro razones simultáneas que ninguna alternativa cumple a la vez: **costo** (USD 0 en licencias vs. miles de dólares mensuales), **soberanía** (datos en su servidor vs. nube del proveedor), **completitud** (stack operacional completo vs. suite parcial) y **localización** (normativa tributaria boliviana, argentina, mexicana integrada vs. adaptaciones costosas). SAP y Microsoft resuelven el problema para empresas que pueden pagar. SBOS lo resuelve para las que no pueden — y para las que no quieren depender.

---

## 2. La Empresa: SKULL

**SKULL — Systems for Continuous Improvement** es una firma de ingeniería y consultoría estratégica que diseña, construye y despliega infraestructura empresarial soberana para organizaciones de Iberoamérica.

Su producto principal es **SBOS** — el primer sistema operativo empresarial soberano diseñado específicamente para el contexto iberoamericano: sus regulaciones tributarias, su estructura de mercado PYME, su necesidad de independencia tecnológica, y su realidad de conectividad y hardware.

SKULL no vende software. Vende soberanía operacional: la capacidad de una organización de controlar completamente su tecnología, sus datos y sus procesos — sin dependencia de ningún proveedor externo.

---

## 3. El Producto: SBOS

**SBOS — System-Kernel Business Operating System** es un sistema operativo empresarial. No es una suite de software, no es un instalador de apps, no es un ERP. Es la infraestructura completa desde la cual opera una organización: sus datos, su identidad, sus aplicaciones, sus comunicaciones, sus estaciones de trabajo, y su inteligencia artificial.

La palabra **soberano** tiene una definición técnica precisa en este contexto:

- Los datos del cliente nunca abandonan su infraestructura
- Ninguna licencia puede ser revocada por un proveedor externo
- Ningún proveedor puede dictar condiciones de acceso a los datos
- El código fuente es auditable en su totalidad
- La organización puede operar el sistema sin depender de SKULL si así lo decide

Esta última propiedad es la más difícil de lograr y la más valiosa: un sistema verdaderamente soberano debe poder operar sin su creador. El SBOS está diseñado para que el cliente pueda transferir el conocimiento operacional a su propio equipo de TI en cualquier momento.

### SBOS no es un producto cloud

No existe "SBOS en la nube de SKULL". El producto se instala en el hardware del cliente — sea un VPS, un servidor dedicado, o hardware propio. SKULL puede operar el sistema como servicio gestionado para el cliente, pero los datos siempre están en el servidor del cliente. Si el cliente decide terminar la relación con SKULL, el sistema continúa funcionando exactamente igual.

---

## 4. El Problema que Resuelve

### La fragmentación del dato

Una empresa mediana típica opera con 8 a 15 herramientas de software simultáneas. Cada una con su propia base de datos, sus propias credenciales, y su propia versión de la verdad sobre los mismos datos. El resultado es **fragmentación del dato**: el mismo cliente existe en 7 sistemas diferentes con 7 versiones distintas de la misma realidad.

```
Sin SBOS — fragmentación:

  OrangeHRM       EspoCRM         Tryton          Saleor
  "Juan Pérez"    "Juan Perez"    "Pérez, Juan"   "J. Pérez"
  empleado        contacto        proveedor       cliente
  (sin email)     email A         email B         email C
  activo          inactivo        activo          desconocido
```

Esta fragmentación cuesta entre el 15% y el 25% de la eficiencia operativa según estudios de gestión de datos empresariales. Las decisiones se toman sobre información incompleta. Los procesos se duplican. El tiempo de los empleados se gasta reconciliando datos en lugar de crear valor.

### La dependencia de proveedores

Una empresa que opera en Google Workspace + Salesforce + Office 365 tiene tres proveedores que pueden, en cualquier momento: cambiar sus precios, cambiar sus condiciones de uso, cerrar su servicio, ser adquiridos, o quedar fuera del alcance regulatorio del país del cliente. En 2022, Google terminó su suite gratuita para organizaciones educativas sin previo aviso. En 2023, Salesforce subió precios un 9% en un año.

El mercado SaaS en América Latina alcanzó los USD 23.000 millones en 2025 y crece al 6,8% anual. Pero ese crecimiento no beneficia al cliente: beneficia al proveedor que acumula dependencias de datos y procesos que hacen la migración cada vez más costosa. El vendor lock-in no es un riesgo — es el modelo de negocio de los proveedores SaaS.

### El costo acumulado

```
Costo SaaS equivalente para 50 usuarios (estimado):

  Google Workspace Business Starter     USD   300 / mes
  Salesforce Essentials (CRM)           USD   750 / mes
  BambooHR (RRHH)                       USD   800 / mes
  QuickBooks Online Plus (Contabilidad) USD   200 / mes
  Zendesk Support Team (Soporte)        USD   875 / mes
  Slack Pro (Comunicaciones)            USD   500 / mes
  Microsoft 365 Business Basic          USD   300 / mes
  Otros (BI, firma digital, backup...)  USD 2.125 / mes
                                        ─────────────────
  TOTAL                                 USD 5.850 / mes
                                        USD 70.200 / año

Con SBOS:                              USD 0 en licencias
```

---

## 5. Los 6 Pilares del SBOS

El SBOS no es una colección de 110 aplicaciones. Es un sistema operativo con **6 órganos vitales** — pilares arquitectónicos sin los cuales el sistema no es SBOS, es solo software instalado.

### Pilar 1 — IAM Installer

El IAM Installer es el **control plane soberano** del SBOS. Vive como servicio `systemd` en el host Ubuntu — no dentro de Kubernetes. Se levanta con el sistema operativo, antes de que exista ningún pod. Es responsable de instalar el stack completo desde Ubuntu limpio hasta las 110+ aplicaciones, vigilar el estado de cada componente permanentemente, reparar automáticamente los fallos antes de que el cliente los note, y gestionar las actualizaciones de forma controlada.

El IAM Installer no tiene interfaz de línea de comandos para uso diario. Su interfaz es el Core UI (SBOS-007) — una aplicación Flutter multi-dispositivo accesible desde navegador, móvil, tablet y escritorio. El administrador instala fichas, aprueba operaciones de gobierno y monitorea el stack desde ahí.

La filosofía del IAM Installer es la misma que la del sistema operativo Linux: siempre presente, intervencionista cuando hace falta, invisible cuando todo va bien.

### Pilar 2 — bKernel

El bKernel es el **corazón de datos** del SBOS. Un daemon binario soberano, desarrollado por SKULL, que vive en el host Ubuntu — no en Kubernetes — y consolida datos bidireccionalmente entre todas las aplicaciones del stack sin que ninguna de ellas sepa que las demás existen.

El mecanismo es el Write-Ahead Log (WAL) de PostgreSQL: cada escritura en cualquier base de datos del stack genera un evento que el bKernel captura en tiempo real. El bKernel evalúa ese evento contra su Rule Engine, determina qué reglas aplican, y ejecuta las acciones correspondientes — que pueden ser escribir en otra base de datos, actualizar un registro en Tryton, o desencadenar una cadena de sincronizaciones.

El principio fundamental es **cero invasión**: el bKernel nunca modifica el código fuente de ninguna app, nunca ejecuta `ALTER TABLE` en ninguna base de datos, y nunca instala triggers ni extensiones en las bases de datos de las aplicaciones. Opera leyendo el WAL y escribiendo en tablas existentes via las APIs públicas o escritura directa controlada.

Tryton ERP es el hub central del bKernel: el punto donde convergen los datos de todas las aplicaciones del stack. No es solo un ERP — es la fuente de verdad maestra del negocio. Todo fluye hacia Tryton y Tryton distribuye hacia el resto.

El bKernel está especificado en SBOS-010.

### Pilar 3 — Keycloak como Gobierno

Keycloak no es solo el SSO del stack. Es el **gobierno completo** de la organización: identidad, acceso y comportamiento.

Como gobierno de identidad: cada empleado tiene una identidad única en Keycloak. Una credencial para acceder a todas las aplicaciones del stack (SSO via OIDC). MFA obligatorio para todos los roles. Ninguna app gestiona sus propias credenciales — todas delegan en Keycloak.

Como gobierno de acceso: el modelo RBAC del SBOS (implementado mediante RolFramework) define qué puede hacer cada rol en cada aplicación. El RolTemplate es el contrato declarativo que define los privilegios en bitwise, los accesos por dominio, y las políticas del escritorio virtual. El gobierno de acceso es estructural, no programático: las reglas se aplican antes del SQL, antes de la UI, antes de cualquier capa de aplicación.

Como gobierno de comportamiento: si un rol tiene `youtube_allowed: false`, el proxy de red del SBOS VDI bloquea youtube.com a nivel de NetworkPolicy para ese usuario. Si el empleado mejora su desempeño y su rol cambia, el acceso se restaura automáticamente con el siguiente login. Este nivel de control — que va más allá de la identidad hacia la productividad operativa — es exclusivo del SBOS.

Keycloak como gobierno está especificado en SBOS-008 y SBOS-019.

### Pilar 4 — SBOS VDI

El SBOS VDI es un **sistema operativo booteable en USB** que reemplaza paulatinamente a Windows en los endpoints corporativos. El empleado arranca su computadora desde el USB y accede a un escritorio Fedora KDE Plasma completamente configurado por la empresa — con las aplicaciones que le corresponden a su rol, con los accesos que Keycloak define, y sin las distracciones de un sistema operativo de propósito general.

La visión estratégica del SBOS VDI es que las tareas de un funcionario son definidas y acotadas. El escritorio corporativo, configurado por Keycloak vía RolTemplate, garantiza que el empleado trabaja en el entorno correcto, con las herramientas correctas. Keycloak controla el comportamiento: si el rol lo permite, YouTube es accesible. Si no lo permite, está bloqueado a nivel de NetworkPolicy — y el empleado no puede saltárselo.

El SBOS VDI está construido sobre Kasm Workspaces Community Edition (Apache 2.0) + Fedora 43 KDE Plasma. Es un producto en sí mismo: el primer SO empresarial para el endpoint que se distribuye como USB booteable y se gobierna por Keycloak. El SBOS VDI está especificado en SBOS-012.

### Pilar 5 — Tryton como Fuente de Verdad

Tryton ERP es el hub central del bKernel — el punto donde convergen los datos de todas las aplicaciones del stack. No es solo un ERP: es la fuente de verdad maestra del negocio.

Tryton maneja contabilidad con la normativa boliviana PUCT/SIN, inventario, manufactura, ventas y compras. Pero su rol en la arquitectura es más profundo: es el destino principal de los datos que el bKernel consolida. Cuando OrangeHRM registra un empleado nuevo, el bKernel lo propaga a Tryton. Cuando Tryton registra un proveedor, el bKernel lo propaga a Saleor. Tryton es el centro de gravedad de la información empresarial.

### Pilar 6 — PostgreSQL como Lenguaje Universal

PostgreSQL no es solo la base de datos. Es el **lenguaje universal** del SBOS — el protocolo de comunicación a través del cual todos los pilares se coordinan.

El Write-Ahead Log (WAL) de PostgreSQL funciona como un bus de eventos nativo: durable, en tiempo real, y sin infraestructura adicional. Cada escritura en cualquier base de datos del stack genera un evento en el WAL que el bKernel puede escuchar. Esta capacidad es la que hace posible la sincronización bidireccional sin invasión: las apps solo escriben en su propia base de datos — el WAL hace el resto.

Criterio de selección fundamental: toda aplicación del stack debe soportar PostgreSQL. Esta restricción es intencional — garantiza que el bKernel, biedata y bCompass puedan escuchar a cualquier app del stack con el mismo mecanismo.

---

## 6. Los 8 Daemons Soberanos del SBOS

El SBOS tiene ocho daemons soberanos: seis corren como servicios `systemd` en el host Ubuntu (fuera de Kubernetes), uno corre en cada cliente Fedora como `systemd --user`, y el IAM Installer es el primero de todos. Estos daemons forman **la columna vertebral operativa** del SBOS: son los que hacen que el sistema sea inteligente, integrado y autónomo, en lugar de ser simplemente un conjunto de apps instaladas.

```
HOST UBUNTU (systemd — fuera de K8s)
├── bos.service            → Plano de control: instala, vigila, repara
├── bkernel.service        → Plano de datos: sincroniza apps internas
├── biedata.service        → Plano de integración: conecta el exterior
├── bcompass.service       → Plano de inteligencia: orienta el negocio
├── bsearch.service        → Plano de búsqueda: localiza datos federados
├── bauth.service          → Plano de identidad: gobierna acceso lógico+físico+financiero
└── bhnexus.service        → Plano de conectividad: broker de hardware y agentes edge

CLIENTE FEDORA (systemd --user)
└── banexus.service        → Plano edge: interceptor de entrada y centinela del shell

KUBERNETES CLUSTER (pods — dentro de K8s)
├── sbos-identity/keycloak
├── sbos-data/postgresql, redis, minio
├── sbos-installer/core-ui
└── ... (110+ aplicaciones del stack)
```

**¿Por qué fuera de Kubernetes?**
Los daemons del host necesitan acceso directo al WAL de PostgreSQL con latencia mínima. Un pod K8s con acceso al WAL introduciría latencia de red innecesaria para una operación que es por naturaleza local y de tiempo real. Los daemons del host eliminan esa capa y garantizan que ningún evento del WAL se pierda por una interrupción de la red del cluster.

### bKernel — Plano de Datos (SBOS-010)

Consolida datos **entre las aplicaciones internas del stack**. Escucha el WAL → evalúa reglas YAML → sincroniza. Su dominio es la coherencia del dato dentro del ecosistema del cliente.

```
WAL ──► bKernel ──► Tryton (hub central)
                 ──► OrangeHRM, Saleor, EspoCRM... (sincronización bidireccional)
```

### biedata — Plano de Integración (SBOS-011)

Conecta el stack con **sistemas externos**. Escucha eventos → selecciona la Caja declarativa → ejecuta la integración. Su dominio es la interoperabilidad con el mundo exterior: sistemas del Estado (SIN Bolivia, AFIP Argentina, SAT México), ERPs de clientes o proveedores, APIs REST de terceros, archivos Excel o CSV.

```
WAL ──► biedata ──► SIN Bolivia (reporte tributario)
                ──► AFIP Argentina (factura electrónica)
                ──► Excel/CSV (importación masiva de datos)
```

### bCompass — Plano de Inteligencia (SBOS-014)

Observa el stack continuamente y ejecuta **Rutas declarativas de inteligencia, automatización y asistencia**. Su dominio es la orientación operacional del negocio: detectar anomalías, generar reportes, responder preguntas en lenguaje natural, automatizar workflows.

```
WAL ──► bCompass ──► [analyst] Detecta anomalía en ventas → sugiere al admin
                 ──► [agent] Empleado pregunta su saldo de vacaciones → responde
                 ──► [flow] Fin de mes → genera reporte → envía por email
```

### bSearch — Plano de Búsqueda (SBOS-013)

Motor de búsqueda federada soberana. Indexa datos de todas las apps del stack y permite búsquedas con fuzzy matching, sinónimos, corrección ortográfica y smart routing a los formularios de cada app.

### bAuth — Plano de Identidad Soberana (SBOS-008)

Orquesta identidad y permisos en tres dominios simultáneos: lógico (redes, dispositivos, apps), físico (zonas, horarios, proximidad), y financiero (límites transaccionales, separación de deberes). Sincroniza Keycloak ↔ Tryton en menos de 5 segundos vía BitMask de 64 bits.

### bhnexus — Plano de Conectividad (SBOS-035)

Broker de comunicaciones que gestiona conexiones WebSocket con agentes edge (banexus) y traduce señales de hardware industrial (OSDP, MQTT, ONVIF) al lenguaje de los contratos de identidad. Es el único componente que convierte un evento físico (QR, NFC, huella) en una consulta de autorización.

### banexus — Plano Edge (SBOS-036)

Centinela distribuido en cada estación Fedora. Intercepta entrada USB antes del SO, congela el shell hasta recibir aprobación del Host, y controla actuadores locales (relés de puertas, cajones). Comunicación monogámica exclusiva con bhnexus vía mTLS.

**Los tres daemons forman una arquitectura sin middleware externo:** el WAL de PostgreSQL es el único bus de eventos. No se necesita Kafka, RabbitMQ, n8n, ni ningún sistema de mensajería adicional.

---

## 7. El Contexto: Por Qué Ahora

### El momento histórico de la soberanía digital

La soberanía digital dejó de ser un tema académico. En enero de 2026, IBM anunció IBM Sovereign Core — describiendo el producto como la primera solución AI-ready con soberanía embebida en la arquitectura misma, no añadida como capa posterior. Gartner predice que más del 75% de todas las empresas tendrán una estrategia de soberanía digital para 2030. La regulación en Europa ya multa con cientos de millones de euros anuales por violaciones a la soberanía de datos — y autoridades en Latinoamérica y el Caribe están siguiendo el mismo camino.

La presión no viene solo de la regulación. En palabras recientes de analistas del Grupo Eurasia: "La geopolítica, la regulación y la gobernanza de datos están convergiendo. Los gobiernos y las empresas deben demostrar control claro sobre sus datos e infraestructura crítica." La soberanía digital ya no es una ventaja competitiva — es un requisito operacional.

### El neocolonialismo digital en Iberoamérica

Latinoamérica aloja solo el 4,8% de la infraestructura de centros de datos del mundo según la ONU. Cada acción digital en la región genera datos que son procesados, almacenados y monetizados en servidores de Silicon Valley, Irlanda o Singapur. El patrón extractivo que en siglos anteriores tomaba minerales y materias primas, hoy toma datos empresariales.

Una empresa mediana boliviana que usa Google Workspace, Salesforce, y QuickBooks está enviando cada día sus contratos, su cartera de clientes, sus estados financieros y su inteligencia competitiva a servidores bajo jurisdicción extranjera, sujetos a leyes de acceso por parte de agencias de inteligencia de esos países. No es paranoia — es la arquitectura legal vigente.

### El estado regulatorio en la región 2026

La ola regulatoria de protección de datos en Iberoamérica está en plena ejecución. Las empresas que no hayan construido infraestructura soberana antes de que la regulación entre en vigor enfrentarán migraciones forzadas bajo presión regulatoria y a costos significativamente mayores.

**Bolivia** no tiene aún una ley integral de protección de datos personales, pero la AGETIC (Agencia de Gobierno Electrónico) tiene activo un anteproyecto de Ley de Protección de Datos Personales en proceso de consulta pública. La regulación es inminente. Bolivia también lidera junto a Venezuela el ranking de sistemas industriales con intentos de infección (25%), según Kaspersky, lo que convierte la soberanía en un imperativo de ciberseguridad además de regulatorio.

**Chile** aprobó en diciembre de 2024 la Ley 21.719 de Protección y Tratamiento de Datos Personales, alineada con el GDPR europeo, que entra en vigor en diciembre de 2026 con multas de hasta 20.000 UTM (aproximadamente EUR 1.466.600) por incumplimiento. Las empresas tienen un período de transición activo ahora mismo. Chile también creó en 2024 la Ley Marco de Ciberseguridad 21.663, con la Agencia Nacional de Ciberseguridad operativa desde enero de 2025.

**Perú** publicó en noviembre de 2024 el Decreto Supremo N.º 016-2024-JUS, que aprueba el nuevo Reglamento de la Ley de Protección de Datos Personales (Ley N.º 29733), vigente desde marzo de 2025. El nuevo reglamento incorpora estándares GDPR y establece sanciones de hasta USD 70.000 por infracción grave en materia laboral.

**Brasil** tiene su LGPD (Lei Geral de Proteção de Dados) plenamente en vigor, con penalidades reforzadas en 2024 y con la ANPD (Autoridade Nacional de Proteção de Dados) activa en la aplicación de sanciones. Brasil fue el país más afectado por ciberataques en la región en 2023, con ransomware y phishing concentrados en el sector financiero.

**México** tiene la Ley Federal de Protección de Datos Personales en Posesión de Particulares (LFPDPPP) vigente, y en 2025 avanzó con la CURP biométrica integrada ("Llave MX"), alineando su identidad digital con estándares GDPR. El mercado de software en México crece, con SAP Cloud ERP ganando terreno en empresas grandes, pero dejando un vacío enorme en el segmento PYME.

**Argentina** tiene la Ley 25.326 de Protección de Datos Personales vigente, reforzada en la práctica por la resolución de 2024 que habilitó el ciberpatrullaje estatal, creando nuevas tensiones regulatorias sobre qué datos pueden observar las agencias del Estado. Argentina también renovó la infraestructura SAP de Telecom para 35 millones de clientes — evidencia del dominio de SAP en la empresa grande, y de la oportunidad en la PYME.

**La tendencia regional es inequívoca:** según ManageEngine, la adopción masiva de leyes de datos personales en la región ha convertido la ciberseguridad y la soberanía de datos en obligaciones operativas, no opciones. Las empresas que hoy construyan infraestructura soberana estarán en cumplimiento nativo cuando la regulación llegue — las que no, tendrán que migrar bajo presión y costo regulatorio.

### Por qué el mercado no ha resuelto esto

IBM Sovereign Core, Red Hat OpenShift, Google Sovereign Cloud — todas son soluciones enterprise de costo prohibitivo para el mercado PYME iberoamericano, diseñadas para gobiernos y corporaciones globales. Nextcloud Workspace es una alternativa europea para colaboración, pero no cubre el stack completo de operación empresarial: ERP, RRHH, CRM, correo, comunicaciones, observabilidad, respaldo, identidad y IA.

El mercado no ha producido una solución que sea al mismo tiempo: completa (cubra todo el stack operacional), asequible (sin costos de licencia), soberana (datos en el servidor del cliente), y diseñada para el contexto iberoamericano (normativa tributaria, idioma, conectividad). Eso es exactamente lo que construye SKULL.

---

## 8. El Mercado Objetivo

### Contexto del mercado 2025-2026

El mercado de software en América Latina alcanzó los USD 23.000 millones en 2025, con el segmento de software empresarial dominando por la digitalización acelerada de la PYME. El mercado ERP en la región crece al 7,6% anual (CAGR 2023-2030) y Microsoft, SAP, Oracle y Salesforce dominan el segmento de empresa grande, pero el segmento PYME está fragmentado y subatendido.

SAP sigue creciendo en la región — su Cloud ERP capturó empresas de todos los tamaños en Brasil, México y Argentina en 2025, con su metodología GROW with SAP apuntando explícitamente a empresas medianas. El problema: el precio de SAP Cloud ERP sigue siendo prohibitivo para la PYME de 20-200 empleados en Bolivia, Perú, Ecuador, Paraguay o Centro América.

El open source gana terreno globalmente: el 84% de las organizaciones reporta que open source reduce el vendor lock-in, el 84% reporta que reduce el costo total de propiedad, y el 86% reporta que mejora la productividad, según la Linux Foundation (2025). En Latinoamérica, banca, retail y organismos públicos están incorporando arquitecturas abiertas para recuperar autonomía tecnológica.

### Primario: PYME boliviana e iberoamericana

Empresas de 20 a 500 empleados que:
- Operan con 5 o más herramientas SaaS simultáneas
- Tienen datos sensibles (contable, RRHH, clientes) que no deben salir del país
- Requieren cumplimiento tributario local (SIN Bolivia, AFIP Argentina, SAT México)
- Tienen o quieren tener un equipo de TI propio

Este segmento no es atendido por SAP (demasiado caro), no es atendido por soluciones cloud puras (datos en el extranjero), y no es atendido por soluciones open source fragmentadas (no hay stack completo integrado disponible).

### Secundario: contadores y estudios contables multicliente

Un contador que lleva 15 empresas puede instalar un SBOS en un servidor y gestionar los 15 clientes en realms separados de Keycloak. El SBOS resuelve el problema del contador que hoy tiene 15 instalaciones de software independientes, una por cliente, sin integración entre ellas.

### Terciario: instituciones educativas y de salud

GNU Health para hospitales y clínicas. Moodle (roadmap) para instituciones educativas. La normativa de salud y educación en Bolivia requiere que los datos permanezcan en servidores locales — el SBOS es cumplimiento nativo.

### Por qué Bolivia primero

Bolivia tiene pendiente una ley de protección de datos (anteproyecto AGETIC activo) y las empresas que anticipen la regulación tendrán ventaja. Bolivia tiene una Agencia de Gobierno Electrónico (AGETIC) con estrategia de soberanía digital declarada. Bolivia lidera en vulnerabilidad de sistemas industriales (25%) — la soberanía tecnológica es un imperativo de seguridad real. Y Bolivia tiene el contexto correcto: mercado de software empresarial no saturado, PYME con necesidades reales de integración, y costos en USD que hacen al SaaS internacional especialmente caro relativamente al contexto económico local.

---

## 9. Posicionamiento Competitivo

### Tabla de propuesta de valor

| Dimensión | Sin SBOS | Con SBOS |
|---|---|---|
| Fuentes de verdad del dato | 8–15 sistemas en silos | 1 (Tryton vía bKernel) |
| Contraseñas por empleado | 6–12 | 1 (Keycloak SSO) |
| Passwords visibles en producción | Alta exposición | 0 (Vault — secrets dinámicos con TTL) |
| Control sobre la estación de trabajo | Ninguno (Windows sin restricciones) | Total (SBOS VDI + Keycloak) |
| Dependencia de proveedores externos | Total — cada SaaS puede revocar acceso | Cero — 100% open source |
| Costo de licencias (50 usuarios) | USD 5.850 / mes | USD 0 |
| Soberanía de datos | Servidores de terceros, jurisdicción extranjera | Servidor del cliente, jurisdicción local |
| Preparación regulatoria | Reactiva — migración costosa cuando llegue la ley | Proactiva — cumplimiento nativo desde el día 1 |
| IA empresarial | API externa (datos salen del cliente) | Soberana (Ollama + Qdrant — datos nunca salen) |
| Tiempo de instalación (stack completo) | Semanas o meses con múltiples proveedores | 45 minutos (Ubuntu limpio → Core UI disponible) |
| Integración con sistemas del Estado | Manual, costosa, fragmentada | Nativa (biedata: SIN, AFIP, SAT) |
| Integración entre aplicaciones | Sin integración o webhooks frágiles | Automática y bidireccional (bKernel WAL) |

### Frente a SAP Business One

SAP Business One es el producto de SAP para PYME. Sus limitaciones en el contexto iberoamericano son:
- Costo de licencia: entre USD 1.500 y USD 3.000 por usuario para implementación inicial, más mantenimiento anual
- Datos en la nube de SAP (RISE with SAP): pierden soberanía
- Customizaciones costosas: cada adaptación al contexto local (normativa boliviana) requiere un partner certificado
- Sin stack completo: SAP cubre ERP, pero el cliente necesita integrar por su cuenta RRHH, CRM, comunicaciones, BI

### Frente a Microsoft 365 + Dynamics

Microsoft 365 cubre colaboración y productividad. Dynamics 365 cubre ERP y CRM. Juntos son una alternativa coherente, pero:
- Precio combinado para 50 usuarios: entre USD 2.500 y USD 5.000 mensuales
- Datos en servidores de Microsoft (Azure): sin soberanía
- Vendor lock-in estructural: los datos de Dynamics son difíciles de migrar
- Sin solución de escritorio corporativo soberano: Windows es el endpoint — sin control de productividad real

### Frente a Odoo

Odoo es la alternativa open source más conocida en el mercado ERP. Sus limitaciones:
- Odoo Community es open source pero las funciones empresariales requieren Odoo Enterprise (suscripción)
- No tiene el concepto de "sistema operativo": cubre ERP y algunos módulos, pero no el stack completo
- No tiene un mecanismo de sincronización de datos como el bKernel
- No tiene gobierno de comportamiento en el endpoint (sin equivalente al SBOS VDI)
- No tiene IA soberana integrada

### El posicionamiento real de SBOS

SBOS no compite directamente con ninguno de estos productos. Compite con el *conjunto* de todos ellos juntos — y gana en precio, soberanía, y completitud simultáneamente.

---

## 10. Principios Rectores

Estos principios no son aspiraciones — son restricciones de diseño. Toda decisión arquitectónica que contradiga cualquiera de estos principios requiere aprobación explícita y documentación del por qué.

> **Nota de alcance:** Los principios P1 a P14 gobiernan el comportamiento del código y las fichas del SBOS. El Principio P15 — Pull-only para actualizaciones de flota — está especificado en SBOS-005 (IAM Installer §16) porque su dominio es el comportamiento del sistema como agente de distribución soberana, no la escritura de líneas de código. Ambos conjuntos son complementarios y ninguno puede violar al otro.

**P1 — Soberanía total:** Los datos del cliente nunca salen de su infraestructura. Ningún componente del sistema hace llamadas a APIs externas sin consentimiento explícito del cliente.

**P2 — Cero invasión:** El bKernel consolida datos sin modificar aplicaciones, sin alterar la estructura de sus bases de datos, y sin requerir que las apps sean conscientes de su existencia.

**P3 — Cero vendor lock-in:** 100% open source, licencias libres, código auditable. El cliente puede transferir el conocimiento operacional a su propio equipo en cualquier momento.

**P4 — PostgreSQL como idioma:** Toda aplicación del stack debe soportar PostgreSQL como base de datos. Esta restricción es el fundamento del bus de eventos del bKernel, biedata y bCompass.

**P5 — Keycloak como gobierno:** Toda aplicación del stack debe ser gobernada por Keycloak. Las apps que no soportan OIDC nativo se cubren con OAuth2-Proxy.

**P6 — Kubernetes desde el día 1:** El modelo operacional es K8s desde el primer servidor. No existe modo "sin Kubernetes para clientes pequeños" — el costo marginal no justifica tener dos modelos operacionales.

**P7 — Extensibilidad por fichas:** Agregar una aplicación nueva al stack nunca requiere modificar el Core del IAM Installer. Solo requiere crear la carpeta de la ficha.

**P8 — El instalador construye su propia plataforma:** El IAM Installer no requiere que K8s esté instalado para correr. Él mismo instala K8s mediante la Ficha Bootstrap.

**P9 — Licencias libres sin excepción:** Ningún componente del stack puede tener una licencia que restrinja su uso comercial. Licencias aceptadas: MIT, Apache 2.0, GPL, AGPL, LGPL, y equivalentes OSI-approved. Licencias vetadas explícitamente: Sustainable Use License, Business Source License (BSL) sin fecha de liberación confirmada, Server Side Public License (SSPL) con restricciones comerciales, y cualquier "Source Available" que no sea OSI-approved.

**P10 — Secrets vía Vault:** Ningún password, token, o credencial puede existir en texto claro en ningún archivo de configuración, variable de entorno, o base de datos del stack. Todos los secrets se gestionan a través de HashiCorp Vault con TTL y rotación automática.

**P11 — Daemons soberanos en el host:** El IAM Installer, el bKernel, biedata y bCompass son servicios `systemd` del host Ubuntu. Ninguno de ellos es un pod Kubernetes. Esta decisión garantiza acceso directo al WAL de PostgreSQL con latencia mínima y sin dependencia de la red del cluster.

**P12 — El Core no crece por apps:** El Core del IAM Installer (SP-01) no crece para acomodar funcionalidades de aplicaciones específicas. Es un motor genérico que ejecuta fichas. Toda lógica específica de una app vive en su ficha.

**P13 — Idempotencia obligatoria:** Toda operación del stack — instalación, actualización, reparación — debe ser idempotente. Ejecutar la misma operación dos veces produce el mismo resultado que ejecutarla una vez. Esta propiedad es la que hace confiables las reparaciones automáticas.

**P14 — Diagnóstico antes de reparar:** Para toda ficha con `criticality: true`, el IAM Installer ejecuta un diagnóstico completo antes de cualquier acción correctiva. El flag `diagnosis_first: true` en el yaml_engine.yml es obligatorio. Reparar sin diagnosticar es una violación de este principio.

**P15 — Pull-only para actualizaciones de flota** _(especificado en SBOS-005 §16)_: El IAM Installer nunca acepta conexiones entrantes del SKULL Release Plane. Toda comunicación es iniciada por el cliente (GET). La consecuencia arquitectónica es que SKULL nunca puede empujar código a un cliente sin su consentimiento explícito. Este principio garantiza la soberanía operacional incluso frente al propio creador del sistema.

---

## 11. Registro de Cambios respecto a v3.0

**Secciones nuevas en v4.0:**
- §1 Resumen Ejecutivo — página inicial de 5 párrafos que responde qué es SBOS, qué problema resuelve, para quién es, los 3 principios que nunca se violan, y por qué un cliente lo elegiría sobre SAP o Microsoft 365
- §6 Los 8 Daemons Soberanos Soberanos del Host — sección completa que posiciona bKernel, biedata y bCompass como los tres planos operativos del sistema (datos, integración, inteligencia), con diagrama ASCII y descripción de la arquitectura sin middleware externo
- §9 Posicionamiento Competitivo — análisis detallado frente a SAP Business One, Microsoft 365 + Dynamics, y Odoo, con tabla de propuesta de valor expandida (12 dimensiones incluyendo integración con sistemas del Estado e integración entre apps)

**Actualizaciones en v4.0:**
- §7 Contexto de Soberanía Digital — actualizado con estado regulatorio concreto por país: Bolivia (anteproyecto AGETIC activo, 25% de sistemas industriales vulnerables), Chile (Ley 21.719 vigente desde diciembre 2026, multas hasta EUR 1.466.600), Perú (nuevo Reglamento vigente desde marzo 2025, sanciones hasta USD 70.000), Brasil (LGPD con penalidades reforzadas), México (CURP biométrica, avance GDPR), Argentina (Ley 25.326 + ciberpatrullaje 2024)
- §8 Mercado Objetivo — actualizado con datos del mercado software latinoamericano (USD 23.000M en 2025, CAGR 6.8%), mercado ERP (CAGR 7.6%, América Latina quinta región global), datos Linux Foundation 2025 sobre adopción open source (84% reduce vendor lock-in, 84% reduce TCO)
- §10 Principios Rectores — corregida la discrepancia P14 vs P15: se agrega nota de alcance explícita diferenciando los 14 principios de código (P1-P14) del Principio P15 de distribución soberana (especificado en SBOS-005). Se agregan P9 (licencias libres), P10 (Vault), P11 (daemons en el host), P12 (Core no crece por apps), P13 (idempotencia), P14 (diagnóstico antes de reparar), P15 (pull-only) que existían en la práctica pero no estaban formalizados en este documento
- Todas las referencias a números de documentos actualizadas a la nueva numeración SBOS-000 a SBOS-024

---

*SKULL · SBOS · SBOS-001-VISION · v5.0 · Actualización de Coherencia Arquitectónica · Marzo 2026*

> **Referencias:** IBM Sovereign Core announcement — IBM (enero 2026) · Gartner Digital Sovereignty Prediction 2030 · UPI — "In the age of AI, Latin America must choose: Sovereignty or dependence" (febrero 2026) · Ley 21.719 Chile, Protección de Datos Personales — diciembre 2024 · Decreto Supremo N.º 016-2024-JUS Perú — noviembre 2024 · AGETIC Bolivia — Anteproyecto Ley de Protección de Datos Personales · Linux Foundation — "The State of Open Source Software 2025" · Kaspersky — Sistemas Industriales LATAM Q2 2025 · Fortune Business Insights — Latin America ERP Software Market 2023-2030 · Informes de Expertos — Mercado de Software en América Latina 2025-2034 · SAP — "Las tendencias que transformarán a la región en 2025" · Ionix — "Ciberataques en América Latina y las proyecciones para 2026" · Garrigues — "Las reformas en materia de protección de datos personales en Latinoamérica" (julio 2025)
