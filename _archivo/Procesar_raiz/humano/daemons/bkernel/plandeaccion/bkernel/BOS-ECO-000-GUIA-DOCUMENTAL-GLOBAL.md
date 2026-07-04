# BOS-ECO-000 — GUÍA DOCUMENTAL GLOBAL
## Series BOS-ECO · BOS-bKernel · BOS-biedata — Mapa, rutas de lectura y reglas de gobierno documental

---

## 0. Metadatos del documento

| Campo | Valor |
|---|---|
| **Documento** | BOS-ECO-000-GUIA-DOCUMENTAL-GLOBAL |
| **Versión** | 1.4 — enmienda estructural **R7** dictada por el arquitecto: juego de gobierno operativo POR PROYECTO (mapa de navegación, protocolo de sesión, registro de estado, log de sesiones, instrucciones de uso, skill del programador, plan de implementación ATÓMICO) en las tres series; catálogo 45→65 documentos; lote 1-G; reconciliación de conteo INC-01 (el "42" del acta de Fase 0 contaba las parejas 000/001 como un solo documento — las listas congeladas contienen 45). Historial: v1.3 D10+regla 11; v1.2 D9+nombres estables; v1.1 identidad biedata |
| **Estado** | VIGENTE — REDACTADO (pendiente de validación del arquitecto) |
| **Fase asociada** | G0 Fundaciones — Lote 1 de redacción |
| **Serie** | BOS-ECO (contratos y gobierno del ecosistema) |
| **Fuentes que absorbe** | `DOC-CREATE-00-INSTRUCCIONES-MAESTRAS` §B–§F · `DOC-CREATE-03-ARQUITECTURA-DOCUMENTAL` v2 · `DOC-CREATE-01-INVENTARIO-DISPERSION` §3 · identidad de biedata: `DAEMON-BIEDATA-00-MAESTRO` v3.0 (filosofía central, analogía Tryton, las Tres Responsabilidades) + `SBOS_biedata_VISION` (aduana soberana, rescate V8) |
| **Documentos que supersede** | Ninguno (documento fundacional de la cuarta generación). DOC-CREATE-00/01/02/03 quedan como archivo de Fase 0 |
| **Prerequisitos de lectura** | Ninguno — punto de entrada de todo lector |
| **Normas aplicables** | ISO/IEC/IEEE 15289:2019 (cl. 4–5 conformidad, cl. 7 tipos genéricos, cl. 10 contenidos específicos) · ISO/IEC/IEEE 29148:2018 · IEEE 1016-2009 · ISO/IEC/IEEE 42010:2022 · ISO/IEC/IEEE 12207:2017 · ISO/IEC/IEEE 26514:2022 — alineado con el ADR-003 del proyecto bos |
| **Audiencia** | Doble: (a) agentes de IA que redactan, implementan o auditan; (b) arquitecto y equipo humano |
| **Custodio** | Arquitecto del SBOS (validación) · Agente documental (mantenimiento) |
| **Fecha** | 2026-06-10 |
| **Estado del proyecto** | Ver → BOS-ECO-001 (Memoria de Completitud Global, única fuente del estado vivo) |

---

# PLANO COMPRENSIÓN (para el lector humano)

## 1. Qué es este documento y por qué existe

Este es el **mapa maestro** de la documentación final de los **dos proyectos hermanos** que
este programa desarrolla en paralelo y con el mismo peso:

- **bKernel** — *SBOS Data Kernel*: el kernel del plano de datos. Escucha, entiende y
  decide. Es el sistema nervioso interno del ecosistema.
- **biedata** — *SBOS Data Gateway: Sovereign Data Exchange Engine*: el motor soberano de
  intercambio de datos. Es **el nexo entre el universo SBOS y todo lo demás** — el mundo
  exterior (sistemas de terceros, bancos, organismos, archivos, APIs, legacy) y los
  propios clientes internos del stack. Ejecuta, valida, transforma, entrega y propaga.

…más la serie **BOS-ECO**, que contiene lo que no pertenece a ninguno de los dos: los
contratos del ecosistema que los unen entre sí y con el **bos** (el IAM Installer que
gobierna la infraestructura).

Antes de esta serie, el conocimiento vivía disperso en **89+ documentos de cuatro
generaciones** (V8 de mayo 2026, SKULL v1/v3, v3.0 biedata / v4.0 bKernel de mayo–junio
2026 y los corpus BOS-REPAIR), con conflictos entre generaciones, inconsistencias nunca
propagadas y vacíos de especificación. La Fase 0 del proyecto documental (2026-06-09/10)
auditó ese corpus completo, detectó y resolvió 16 conflictos (C-01…C-16), absorbió 10
inconsistencias ya resueltas y registró 7 vacíos a llenar. El arquitecto validó las
resoluciones (R1–R6), congeló la doctrina (D1–D8, §5 de este documento) y congeló la
estructura destino: **3 series y 9 lotes de redacción** (45 documentos en las listas congeladas; el total "42" del acta contaba las parejas 000/001 como un documento — INC-01, reconciliado). La **enmienda R7** (dictada por el arquitecto el 2026-06-10) añadió a CADA proyecto su juego de gobierno operativo —mapa de navegación, protocolo de sesión de agente, registro de estado, log de sesiones, instrucciones de uso, skill del agente programador y plan de implementación a nivel ATÓMICO— llevando el catálogo a **65 documentos**.

Esta serie final es la **cuarta generación documental y la única vigente**. Todo documento
anterior es archivo histórico: se consulta como fuente, jamás como autoridad
(resolución C-10, validada R6).

## 2. Los dos protagonistas, en paridad

Ningún lector debe salir de esta guía creyendo que uno de los dos daemons es "el sistema"
y el otro su auxiliar. Son dos soberanías complementarias y ninguna funciona sin la otra.

### 2.1 bKernel — el que escucha y decide

| Identidad | Valor |
|---|---|
| Nombre | SBOS Data Kernel |
| Naturaleza | Kernel del plano de datos: CDC multi-motor nativo (PostgreSQL WAL/pgoutput, MySQL Binlog ROW, MongoDB Change Streams, SQL Server CDC), sin intermediarios |
| Qué hace | **Escucha TODAS las bases de datos del stack** — la BD propia de cada aplicación incluida; 100, 500 o 5.000 BDs simultáneas — y organiza la actualización del ecosistema (D10): detecta cada cambio, lo normaliza, lo enriquece con contexto (`ctx_id`, Entity Graph en Apache AGE), decide destinos con reglas CESQL y **estructura intenciones** de trabajo que envía a biedata. Métodos automáticos (94% de la operación diaria) y manuales de relación de datos |
| Qué NO hace | No recibe órdenes de nadie (D2): sin servidor RPC, sin socket, sin puerto de entrada. No escribe datos de negocio (D1): el ejecutor es biedata |
| Superficie de ataque | **0, literal.** Inputs = CDC + SIGTERM + SIGHUP. Puertos 9460 (métricas) y 9461 (healthcheck), ambos de solo lectura |
| Unidad declarativa | Ficha (source.yml + transform.yml + task_catalog.sh + setup.sh) + reglas CESQL en el Destination Registry |
| Custodias propias | `context_sessions`, `audit_events`, lineage (OpenLineage), DDL Guardian |

### 2.2 biedata — el motor soberano de intercambio de datos

| Identidad | Valor |
|---|---|
| Nombre | **SBOS Data Gateway: Sovereign Data Exchange Engine** |
| Naturaleza | El **nexo universal de datos** del SBOS y una **caja cerrada de datos**: actualiza las bases de datos del stack exclusivamente a través del consumo y la emisión de datos. Todo dato que entra al stack, sale del stack o se escribe dentro del stack pasa por biedata — los diálogos API exteriores regulados, no (C-17) |
| Filosofía central | **"El RPC siempre hace algo."** Un paquete JSON-RPC no transporta datos: ejecuta una acción. El paquete no es un sobre — es una orden de trabajo |
| Qué hace | Motor de **procesamiento recursivo** y **caja cerrada** (D9): solo actualiza las bases de datos a través del consumo y emisión de datos. Una sola llamada puede constituirse en un pipeline de tareas encadenadas sobre múltiples dominios del ecosistema (ventas, inventario, contabilidad, RRHH, CRM, fiscal…). Valida declarativamente ANTES de ejecutar, escribe con `origin='biedata'`, entrega el resultado en el formato que el caller declara (JSON-RPC, PDF, XLSX, CSV, XML), importa y exporta volúmenes con cajas, y se autodescribe (`biedata.describe`, `dry_run`) |
| La analogía canónica | **biedata es el Tryton JSON-RPC del ecosistema completo**: así como nadie escribe en la BD de Tryton sin pasar por su RPC, nadie escribe en NINGUNA BD del ecosistema sin pasar por el RPC de biedata |
| Qué NO hace | No almacena datos de negocio (`biedata_db` es solo auditoría); no tiene lógica de negocio en el binario (vive en fichas); no decide qué propagar (eso es bKernel); **no ejecuta los diálogos API HTTP exteriores regulados por ley** — esos pertenecen a cada aplicación obligada, p. ej. btax no emite facturas a través de biedata sino directamente como SIF (C-17 VALIDADO, → BOS-ECO-001 §7) |
| Unidad declarativa | **Ficha** (manifest.yml + validation.yml + task_catalog.sh) para tareas RPC · **Caja** (WASM/plugin) para import/export masivo |
| Modelo de servicio | Versionado de tres niveles: contrato técnico (`.v1/.v2/.v3`), implementación (SemVer interno) y **tier de servicio por tenant** (capacidades, límites, SLA y precio contratados; el alias sin sufijo resuelve al tier del contrato) |
| Puertos (D5) | :9470 API JSON-RPC · :9471 métricas · :9472 healthcheck |

### 2.3 Las Tres Responsabilidades de biedata (canónicas, v3.0)

**A — Gateway externo de DATOS (con la frontera C-17).** Todo **dato** que entra al
ecosistema desde fuera o sale del ecosistema hacia fuera pasa por biedata como consumo y
emisión de datos:

```
Exterior → biedata (consume, valida, ejecuta tarea) → BD del ecosistema   (import / inbound)
BD del ecosistema → biedata (lee, transforma, emite) → Exterior           (export / outbound)
```

**La frontera validada (C-17):** biedata es una caja cerrada de datos — NO ejecuta los
**diálogos API HTTP con el exterior que las leyes y normas de los Estados regulan**. Esa
comunicación es responsabilidad de **cada aplicación obligada por la regulación**
(ejemplo ilustrativo — variable, D10: un sistema de facturación dialoga con el ente,
obtiene su código de autorización y rompe la regla de "cero HTTP exterior" únicamente
porque la ley lo exige así). biedata no duplica esas responsabilidades. La aplicación
regulada escribe sus resultados **solo en su propia base de datos** (cero invasión, D10)
y bKernel, que escucha esa BD como a toda BD del stack, organiza la actualización del
ecosistema (biedata ejecuta, D1). Qué aplicaciones serán y cuántas: **no está
determinado ni debe estarlo** — las aplicaciones son variables en el tiempo (D10); el
intercambio de DATOS no regulado (archivos, volúmenes, legacy) es dominio de biedata.

**B — Gateway interno y propagador.** Los clientes internos (Core UI, btax, bCompass,
cualquier Smart, y las intenciones estructuradas de bKernel) escriben en el stack
**también** a través de biedata — esta es la cara interna de D1:

```
Core UI    → POST /rpc → biedata → tryton_db
btax       → POST /rpc → biedata → tryton_db / btax lee datos del stack vía biedata
Smart X    → POST /rpc → biedata → espocrm
bKernel    → Redis Streams (intención) → biedata → BD destino
           → biedata SIEMPRE escribe con origin='biedata'
           → bKernel detecta TODO via WAL → consistencia universal garantizada
```

**C — Aduana de calidad.** Inbound: si los datos no cumplen `validation.yml`, biedata
rechaza con detalle exacto de campo, regla y mensaje — **nunca ejecuta tareas con datos
inválidos** y la BD nunca es tocada. Outbound: si la solicitud no cumple las normas de
exportación, rechaza — **nunca expone datos no autorizados**.

### 2.4 El ciclo que los une (la doctrina del WAL)

```
        ESCUCHA Y DECIDE                EJECUTA E INTERCAMBIA           GOBIERNA INFRA
┌──────────────────────────┐   ┌────────────────────────────────┐   ┌─────────────────────┐
│         bKernel          │   │            biedata             │   │     bos (IAM)       │
│ WAL/Binlog/ChangeStreams │   │ Data Gateway soberano:         │   │ Operator Soberano   │
│ normaliza · enriquece    │──▶│  A) nexo con el mundo exterior │   │ instala · repara    │
│ decide (CESQL · grafo)   │   │  B) ejecutor universal interno │   │ escala · verifica   │
│ estructura intenciones   │   │     (100% escrituras, D1)      │   │ sagas de gobierno   │
│ NO recibe órdenes        │   │  C) aduana de calidad          │   │ métodos bos.*       │
│ NO escribe negocio       │   │ motor recursivo de fichas      │   └─────────────────────┘
└────────────▲─────────────┘   │ :9470 JSON-RPC · cajas WASM    │
             │                 └───────────────┬────────────────┘
             │                                 │ escribe origin='biedata'
             │            WAL de la BD destino (ciclo cerrado)
             └──────────── bKernel detecta → propaga al stack (skipback: nunca a biedata)
```

1. Un dato nace por cualquiera de sus tres puertas: **una aplicación lo escribe en SU
   propia base de datos** (la entrada primaria — cero invasión, D10: cada app trabaja
   solo en su entorno y universo, sin saber que la plataforma existe), lo trae el
   exterior (import vía biedata), o lo ordena un cliente interno (RPC de biedata).
2. **bKernel lo detecta por CDC** — escucha el WAL/Binlog/Change Streams de TODAS las
   bases de datos del stack —, lo enriquece, decide qué más debe ocurrir en el ecosistema
   y **estructura intenciones** de trabajo.
3. **biedata ejecuta las intenciones**: valida (aduana de calidad), procesa en su
   pipeline y escribe en los destinos con `origin='biedata'` — o emite hacia el exterior
   en el formato exigido. Esas escrituras vuelven a ser detectadas por bKernel (el ciclo
   continúa hasta que el ecosistema queda consistente).
4. El anti-loop (*skipback*) garantiza que lo originado por biedata jamás regresa a
   biedata. El bos no participa del plano de datos: prepara, verifica y administra.

**El círculo virtuoso completo:** exterior ↔ biedata ↔ stack ↔ WAL ↔ bKernel ↔ biedata.
Ninguno de los dos daemons es el centro: el centro es el ciclo.

## 3. Las tres series y su razón de ser

| Serie | Documentos | Qué contiene | Qué NO contiene |
|---|---|---|---|
| **BOS-ECO** | 12 | Lo que no pertenece a un solo daemon: gobierno documental, estado global, doctrina JSON-RPC, contrato bilateral bKernel↔biedata, acoplamiento de ambos al bos | Detalles internos de cada daemon |
| **BOS-bKernel** | 28 | Gobierno operativo propio (002–007 + plan atómico 190) y todo el daemon bKernel: visión, normas, requisitos, ADRs, arquitectura, CDC multi-motor, enricher+grafo, routing CESQL, intenciones+orquestación, DDL Guardian, lineage, cluster, datos, fichas, integraciones, seguridad, operación, instalación, plan, glosario | Los contratos entre daemons (viven en ECO) |
| **BOS-biedata** | 25 | Gobierno operativo propio (002–007 + plan atómico 160 + glosario 170) y todo el daemon biedata: visión (Data Gateway, las Tres Responsabilidades), normas, requisitos, ADRs, arquitectura, protocolo RPC (mensaje, pipeline, directiva de entrega, tiers), fichas+pipeline, cajas WASM (import/export/migración legacy/pasarelas), flujos canónicos, datos, seguridad, resiliencia (idempotencia/saga/circuit breaker), observabilidad, operación, instalación, plan+glosario | Los contratos entre daemons (viven en ECO) |

**Principio rector (P1, Single Source of Truth):** cada concepto vive en exactamente UN
documento. El resto referencia con la sintaxis `→ SERIE-NNN §X`
(ejemplo: `→ BOS-ECO-020 §4`). Los contratos entre daemons viven SOLO en BOS-ECO; ningún
documento de daemon los duplica — los referencia.

---

# PLANO ESPECIFICACIÓN (para el agente)

## 4. Identidades técnicas de referencia (resumen normativo)

| Atributo | bKernel | biedata |
|---|---|---|
| Servicio | `bkernel.service` | `biedata.service` |
| Lenguaje | Rust 1.85+ (Edition 2024), MUSL estático, tokio | Rust 1.85+ (Edition 2024), MUSL estático, tokio |
| Protocolo de entrada | **NINGUNO** (D2): CDC + señales | **JSON-RPC 2.0 exclusivamente**, `POST /rpc` (endpoint único) |
| Unidad declarativa | Ficha 4 archivos + reglas CESQL | Ficha 3 archivos (`manifest.yml`+`validation.yml`+`task_catalog.sh`) + Cajas WASM |
| Directorio | `/etc/bos/blibs/bkernel/servers/<srv>/<app>/` | `/etc/bos/blibs/biedata/fichas/<inbound|outbound|system>/<nombre>/<vN>/` · `/etc/bos/blibs/biedata/boxes/` |
| Recarga en caliente | SIGHUP | SIGUSR1 (fichas nuevas sin reiniciar) |
| BD propia | esquema `bkernel` en `sbos_kernel_db` (C-04) | `biedata_db` (SOLO auditoría/operaciones — nunca negocio) |
| Puertos (D5, SBOS-050) | 9460 métricas · 9461 health (solo lectura) | **9470 API JSON-RPC** · 9471 métricas · 9472 health |
| Firma de escritura | n/a (no escribe negocio) | `origin='biedata'` SIEMPRE (frontera F3) |
| Salida al exterior | NUNCA | intercambio de DATOS con el exterior (consumo/emisión); los diálogos API regulados por ley los ejecuta cada aplicación obligada (D9) — las aplicaciones son variables (D10) |
| Resiliencia | DLQ, reintentos, checkpoints por motor | Idempotencia (`_idempotency_key`), Saga con compensación declarativa, circuit breaker por BD destino |
| Descubrimiento | fichas en disco + tablas de estado | `biedata.describe`, `biedata.describe.method`, `dry_run`, `bosctl biedata describe` |

## 5. Doctrina congelada del arquitecto (D1–D10) — NO renegociable

Estas ocho decisiones gobiernan TODO el contenido de las tres series. Ningún documento
final puede contradecirlas. Si durante la redacción o implementación se detecta una
tensión con ellas, NO se reinterpreta: se registra el hallazgo como conflicto PROPUESTO
en la Memoria de Completitud (→ BOS-ECO-001 §7) y se espera la validación del arquitecto.

| # | Decisión congelada | Fuente |
|---|---|---|
| **D1** | **biedata ejecuta el 100% de las escrituras de negocio**, sin excepciones (incluso hacia Tryton, vía su fachada). Siempre con `origin='biedata'`. biedata custodia las credenciales de TODAS las aplicaciones destino (su scope Vault). | R1, sesión 2026-06-09/10 |
| **D2** | **bKernel NO recibe órdenes de nadie.** Solo escucha (WAL/Binlog/Change Streams), organiza/estructura eventos y los envía a biedata por Redis Streams (`bkernel:stream:biedata.*`, Inbox dedup en biedata). Sin servidor RPC, sin socket, sin puerto de entrada. Inputs = CDC + SIGTERM + SIGHUP. Superficie de ataque = 0, literal. La propuesta de socket Unix de control fue RECHAZADA. | R2 |
| **D3** | El ciclo se cierra por WAL: biedata escribe → bKernel detecta → propaga al stack. Anti-loop *skipback*: lo originado por biedata jamás vuelve a biedata. | corpus biedata + R2 |
| **D4** | **JSON-RPC 2.0 es la lengua franca del SBOS** (toda acción = orden de trabajo). Transporte según clase de soberanía: biedata y las aplicaciones lo sirven por HTTP; el bos lo sirve como Operator (métodos `bos.*`); bKernel no lo sirve (D2) pero estructura intenciones compatibles. El Manual JSON-RPC (9 partes) es corpus normativo paralelo — no se renombra ni se absorbe. | directiva del arquitecto + R2 |
| **D5** | **El SBOS-050-PORT-CATALOG es la norma de puertos.** bKernel: 9460 métricas / 9461 healthcheck (mueren el 9100 y el 9105). biedata: 9470 API JSON-RPC / 9471 métricas / 9472 healthcheck, usando el margen de ampliación del catálogo, CON actualización obligatoria del SBOS-050 (tarea formal del plan, → BOS-biedata-160). | R3, R4 |
| **D6** | Prefijos finales: **BOS-ECO-###** (contratos del ecosistema), **BOS-bKernel-###**, **BOS-biedata-###**. Solo los documentos finales llevan prefijo y numeración. | R5 |
| **D7** | Regla de resolución de conflictos: gana el documento más reciente o el más lógico, **respaldado por investigación en internet y por normas y estándares internacionales**; la investigación se ejecuta y se cita durante la redacción de cada documento final. | R6 |
| **D8** | El bos (IAM Installer) gobierna la infraestructura: instala/verifica/administra ambos daemons (slot `bkernel_slot`, fichas, app_registry, sagas `bos.ficha.*`). Sobre bKernel su administración es **pasiva** (fichas en disco + SIGHUP, tablas de estado que bKernel lee, scrape 9460/9461); sobre biedata, **activa** (sagas + el RPC :9470 de biedata). Los documentos BOS-REPAIR son referencia del proyecto bos, no se absorben. | sesión 3 |
| **D9** | **biedata es una caja cerrada**: solo actualiza las bases de datos a través del consumo y emisión de datos. La comunicación API HTTP con el exterior NO se centraliza en biedata: **cada aplicación que las leyes y normas estatales regulan se hace cargo de su propia comunicación exterior** (excepción a "cero HTTP" exclusivamente regulatoria, jamás de conveniencia). Ejemplo ilustrativo (variable, D10): un sistema de facturación dialoga con el ente, obtiene su código de autorización y actualiza sus datos; biedata no repite esas responsabilidades. | dictado del arquitecto 2026-06-10, resolución de C-17 |
| **D10** | **Cero invasión + aplicaciones como variables.** (a) Toda aplicación trabaja únicamente en su propio entorno y universo: escribe SOLO en su propia base de datos, directo; no se modifica, no invoca a la plataforma, no sabe que bKernel existe. (b) **Toda BD del stack es fuente CDC de bKernel** — su razón de existir es escuchar todas las bases de datos (100/5.000+) y organizar la actualización del ecosistema (decide y estructura; biedata ejecuta, D1/D2/D3), con métodos automáticos y manuales. (c) **Las aplicaciones y sus BDs son VARIABLES en el tiempo, no constantes**: bKernel, biedata y el bos no las conocen — su conocimiento es declarativo (fichas, registros). Si las aplicaciones estuvieran determinadas, estos daemons no necesitarían existir. Respaldo: Master §02.2 y F-01…F-11; HUMAN-DOC §5; doc 06; CDC log-based no intrusivo (estándar de industria) y patrón database-per-service (microservices.io). | respuestas Q-01…Q-05 del arquitecto, 2026-06-10, validadas (D7) |

**Nota de alcance sobre D1 (a raíz de la corrección v1.1):** D1 define el papel de biedata
en el plano de **escritura interna** del stack. NO agota la identidad de biedata, que
comprende además todo el intercambio con el exterior (Responsabilidad A), la aduana de
calidad (Responsabilidad C), el motor recursivo de pipelines, los tiers de servicio, la
entrega multi-formato y las cajas de import/export. Los documentos finales deben presentar
SIEMPRE la identidad completa, no solo el rol que D1 norma.

## 6. Catálogo completo: los 65 documentos (post-enmienda R7)

Estados posibles de cada documento: `PENDIENTE → EN-REDACCIÓN → REDACTADO → VALIDADO`.
El estado real y actualizado vive ÚNICAMENTE en → BOS-ECO-001 §3. Las tablas siguientes
definen el **concepto único** (SSOT) de cada documento — qué vive ahí y en ningún otro lugar.

### 6.1 Serie BOS-ECO — Contratos y gobierno del ecosistema (12)

| Doc | Título | Concepto único (SSOT) | Lote |
|---|---|---|---|
| **BOS-ECO-000** | GUIA-DOCUMENTAL-GLOBAL | Mapa de las tres series, identidades en paridad de ambos daemons, doctrina D1–D8, rutas de lectura por rol, jerarquía de autoridad histórica, plantilla de metadatos | 1 |
| **BOS-ECO-001** | MEMORIA-COMPLETITUD-GLOBAL | Estado vivo de TODO el proyecto: documentos de las 3 series, módulos de desarrollo G0–G5, hitos, decisiones abiertas, registro de conflictos nuevos | 1 |
| **BOS-ECO-002** | MAPA-DE-NAVEGACION | Navegación global por intención y por concepto; mapas locales en bK-002/bd-002 | 1-G |
| **BOS-ECO-003** | PROTOCOLO-SESION-AGENTE | Apertura/ejecución/cierre de toda sesión de agente; sesión sin actualizar estado+log = inválida; procedimiento de conflicto | 1-G |
| **BOS-ECO-004** | REGISTRO-DE-ESTADO | Estado MÁQUINA (YAML canónico) del programa; máquinas de estado únicas (documento/módulo/tarea/conflicto/sesión) | 1-G |
| **BOS-ECO-005** | LOG-DE-SESIONES | Log global append-only de sesiones (formato obligatorio S-NNN) | 1-G |
| **BOS-ECO-006** | INSTRUCCIONES-DE-USO | Uso del sistema por rol; reglas de oro; recetas; prohibiciones | 1-G |
| **BOS-ECO-007** | SKILL-AGENTE-PROGRAMADOR | Skill maestro cargable: flujo de trabajo, stack común, Definition of Done, doctrina aplicada a código | 1-G |
| **BOS-ECO-008** | PLAN-MAESTRO-ATOMICO | Jerarquía atómica del programa; fases G0–G5 → etapas con dueño y criterio de salida MEDIBLE; hitos H0–H5; gates | 1-G |
| **BOS-ECO-010** | DOCTRINA-JSON-RPC | JSON-RPC 2.0 como lengua franca; perfil SBOS del protocolo; transporte por clase de soberanía; categorías de aplicaciones; posición de cada daemon; relación normativa con el Manual JSON-RPC 1–9 | 1 |
| **BOS-ECO-020** | CONTRATO-BKERNEL-BIEDATA | El contrato bilateral completo: formato de la intención de escritura estructurada, streams de comando, Inbox/Outbox bilateral, `origin` y anti-loop (skipback), `event_timestamp`/`source_checkpoint`, sagas y compensaciones, SLO por tramo, comportamiento ante caída de biedata, autenticación SVID/JWT+DPoP | 2 |
| **BOS-ECO-030** | ACOPLAMIENTO-AL-BOS | Cómo el bos instala, verifica y administra ambos daemons: preparación del terreno (slot `bkernel_slot`, fichas, app_registry, orden garantizado), criterios de efectividad, administración pasiva (bKernel) vs sagas (biedata), Context Plane (bKernel custodia `context_sessions`+`audit_events`; biedata adjunta ctx_id), traceparent end-to-end | 2 |

### 6.2 Serie BOS-bKernel — El kernel del plano de datos (28)

| Doc | Título | Concepto único (SSOT) | Lote |
|---|---|---|---|
| BOS-bKernel-000 | GUIA-DOCUMENTAL | Navegación de la serie; enlaza a ECO-000 | 3 |
| BOS-bKernel-001 | MEMORIA-COMPLETITUD | Estado de la serie; alimenta a ECO-001 | 3 |
| BOS-bKernel-002 | MAPA-DE-NAVEGACION | Mapa de la serie por intención; instancia de ECO-002 | 1-G |
| BOS-bKernel-003 | PROTOCOLO-SESION-AGENTE | Particularidades bKernel del protocolo (CDC: satélites antes; jamás abrir puertos; test de eco) | 1-G |
| BOS-bKernel-004 | REGISTRO-DE-ESTADO | YAML de docs+módulos+tareas de la serie con evidencia | 1-G |
| BOS-bKernel-005 | LOG-DE-SESIONES | Log append-only de sesiones de la serie | 1-G |
| BOS-bKernel-006 | INSTRUCCIONES-DE-USO | Circuitos de trabajo/lectura y recordatorios duros del proyecto | 1-G |
| BOS-bKernel-007 | SKILL-AGENTE-PROGRAMADOR | Skill específico: D2 en código, módulos, checkpoints por motor, anti-loop, SLOs C-02, fixtures D10 | 1-G |
| BOS-bKernel-010 | VISION-Y-FRONTERAS | Identidad y fronteras LITERALES: no recibe órdenes, no expone API ni socket; inputs = CDC + señales; superficie de ataque = 0; no escribe datos de negocio — biedata escribe (D1/D2) | 3 |
| BOS-bKernel-020 | NORMAS-Y-CUMPLIMIENTO | Matriz cláusula→control→módulo→evidencia (vacío V-07) | 4 |
| BOS-bKernel-030 | REQUISITOS-Y-CAPACIDADES | F-XXX en DADO/CUANDO/ENTONCES contra v4.0; la capacidad de "escritura" es "emisión de intención estructurada" (vacío V-01) | 4 |
| BOS-bKernel-040 | DECISIONES-ARQUITECTURA-ADR | Registro ADR consolidado, incluye ADR "bKernel no escribe / biedata ejecuta" y ADR "sin control plane RPC" (vacío V-06) | 3 |
| BOS-bKernel-050 | ARQUITECTURA-SISTEMA | Vista completa, módulos Rust, bkernel.toml, metrics_port=9460 / health=9461 (D5) | 4 |
| BOS-bKernel-060 | CDC-ENGINE | CDC multi-motor nativo sin intermediarios; absorbe satélites WAL 02/04 + POSTGRESQL-WAL-* | 6 |
| BOS-bKernel-070 | CONTEXT-ENRICHER-Y-ENTITY-GRAPH | Enriquecimiento de contexto (ctx_id) y grafo de entidades (Apache AGE) | 6 |
| BOS-bKernel-080 | ROUTING-CESQL | Gramática formal del subset CESQL; Destination Registry; reglas hot-reloadables por SIGHUP | 6 |
| BOS-bKernel-090 | ENGINE-INTENCIONES-Y-ORQUESTACION | Construcción de intenciones, Outbox→streams, orquestación de sagas COMO DECISOR; cero adaptadores de protocolo; contrato formal de `task_catalog.sh` (vacío V-05) | 6 |
| BOS-bKernel-100 | DDL-GUARDIAN | Protección ante cambios de esquema: 3 capas, clasificador 5 severidades, protocolo `schema_change` | 8 |
| BOS-bKernel-110 | LINEAGE-Y-OBSERVABILIDAD | OpenLineage; catálogo completo de métricas en :9460 | 8 |
| BOS-bKernel-120 | CLUSTER-MODE | Coordinador y particionado; umbral de activación >25 fuentes | 8 |
| BOS-bKernel-130 | MODELO-DE-DATOS | Esquema `bkernel` en `sbos_kernel_db` (C-04); incluye `context_sessions` y `registered_devices` (C-16) | 5 |
| BOS-bKernel-140 | FICHAS-DECLARATIVAS | La ficha de 4 archivos; fichas de referencia completas OrangeHRM + Tryton (vacío V-03) | 5 |
| BOS-bKernel-150 | INTEGRACIONES | Lo propio: evento canónico bSearch, Redis Streams, doble rol OrangeHRM (C-11); referencia a ECO-020/030 | 9 |
| BOS-bKernel-160 | SEGURIDAD | Superficie cero; SIN credenciales de apps destino (D1) | 9 |
| BOS-bKernel-170 | OPERACION-SLO-RUNBOOKS | Tabla SLO canónica por tramo con puntos de medición (C-02, vacío V-02) | 9 |
| BOS-bKernel-180 | INSTALACION | Instalación por el bos; orden garantizado y precondición `register_app_in_bsearch` (vacío V-04) | 9 |
| BOS-bKernel-190 | PLAN-DE-IMPLEMENTACION-ATOMICO | Nivel micro: tareas atómicas con ID/entregable/criterio MEDIBLE/dependencias/SSOT (derivado de A5; G0–G1 completo, G2–G5 se micro-detallan al validarse sus SSOT) | 1-G (vivo) |
| BOS-bKernel-200 | GLOSARIO | Términos vigentes + términos históricos con redirección | 9 |

### 6.3 Serie BOS-biedata — El motor soberano de intercambio de datos (25)

| Doc | Título | Concepto único (SSOT) | Lote |
|---|---|---|---|
| BOS-biedata-000 | GUIA-DOCUMENTAL | Navegación de la serie; enlaza a ECO-000 | 3 |
| BOS-biedata-001 | MEMORIA-COMPLETITUD | Estado de la serie; alimenta a ECO-001 | 3 |
| BOS-biedata-002 | MAPA-DE-NAVEGACION | Mapa de la serie por intención; instancia de ECO-002 | 1-G |
| BOS-biedata-003 | PROTOCOLO-SESION-AGENTE | Particularidades biedata (F2/F3/F4/F8 como reglas de sesión; linter D9) | 1-G |
| BOS-biedata-004 | REGISTRO-DE-ESTADO | YAML de docs+módulos+tareas de la serie con evidencia | 1-G |
| BOS-biedata-005 | LOG-DE-SESIONES | Log append-only de sesiones de la serie | 1-G |
| BOS-biedata-006 | INSTRUCCIONES-DE-USO | Circuitos y recordatorios duros del proyecto | 1-G |
| BOS-biedata-007 | SKILL-AGENTE-PROGRAMADOR | Skill específico: endpoint único, 4 capas, pipeline/delivery, fronteras en código, cajas, fixtures D10 | 1-G |
| BOS-biedata-010 | VISION-Y-FRONTERAS | Identidad completa (SBOS Data Gateway: Sovereign Data Exchange Engine), filosofía "el RPC siempre hace algo", motor de procesamiento recursivo, analogía Tryton, **las Tres Responsabilidades** (A gateway externo universal · B gateway interno y propagador/ejecutor D1 · C aduana de calidad), las 12 fronteras inviolables F1–F12 | 3 |
| BOS-biedata-020 | NORMAS-Y-CUMPLIMIENTO | Matriz normativa propia: ISO 27001 (auditoría A.8.15, secretos A.5.14), normativa fiscal LATAM (SIAT/AFIP/SAT) como UN dominio regulado entre otros, mTLS exterior, certificados | 4 |
| BOS-biedata-030 | REQUISITOS-Y-CAPACIDADES | F-XXX DADO/CUANDO/ENTONCES contra v3.0, rescatando de V8: import desde fuentes externas, export a sistemas externos, migración legacy (DBF/CSV/Excel), pasarelas de pago, integración tributaria, file-watch, box engine | 4 |
| BOS-biedata-040 | DECISIONES-ARQUITECTURA-ADR | ADRs: Inbox Pattern, JSON-RPC exclusivo, Rust/tokio, fichas vs cajas, tiers como niveles de servicio, posición fiscal (pendiente C-17) | 3 |
| BOS-biedata-050 | ARQUITECTURA-SISTEMA | Vista completa, módulos Rust, biedata.toml, puertos 9470/9471/9472 (D5), ciclo de vida, biedata como ficha SBOS | 4 |
| BOS-biedata-060 | PROTOCOLO-RPC | El mensaje (extensión `delivery`), método=acción, pipeline de tareas, directiva de entrega (4 modos: json-rpc/transform/document/relay), único endpoint, 4 capas de seguridad propias (+las heredadas), códigos de error, límites, **versionado de 3 niveles y tiers/contratos de tenant** | 7 |
| BOS-biedata-070 | FICHAS-Y-PIPELINE | manifest.yml + validation.yml + task_catalog.sh; pipeline declarado de tareas encadenadas (merge_into/context/result); fichas system (`biedata.describe`, `dry_run`); fichas de referencia completas | 5 |
| BOS-biedata-080 | CAJAS-WASM | Plugins de import/export masivo: pipeline de 6 fases (prepare/read/transform/validate/write|deliver/finalize), calamine, file-watch, cuarentena, migración legacy, ciclo de vida de cajas | 7 |
| BOS-biedata-090 | FLUJOS-CANONICOS | Flujos end-to-end con el ciclo WAL: operación RPC completa (con rechazo de aduana), procesamiento recursivo multi-dominio, relación con btax, import masivo, export externo, contingencia | 7 |
| BOS-biedata-100 | MODELO-DE-DATOS | `biedata_db` completa (operations/auditoría, `_inbox`, idempotency, sagas, tenant_contracts, circuit breaker — nunca negocio), retención | 5 |
| BOS-biedata-110 | SEGURIDAD | Las 5 capas del ecosistema (NGINX/WAF, Kong, biedata, PostgreSQL dual-user rw/ro, red/pods/SIEM) + 4 capas del protocolo, Vault (credenciales de TODAS las apps destino — D1), SVID, mTLS exterior, DPoP, BOLA prevention | 8 |
| BOS-biedata-120 | RESILIENCIA | Idempotencia (`_idempotency_key`, TTL, conflictos), Saga con compensación declarativa en manifest, circuit breaker por BD destino, parciales, recuperación | 8 |
| BOS-biedata-130 | OBSERVABILIDAD | Métricas :9471 (catálogo completo: RPC por tier/tenant, pipeline, idempotencia, breaker, pool, fichas), spans OTel, logs JSON con ctx_id, dashboard, alertas, healthcheck enriquecido :9472 | 8 |
| BOS-biedata-140 | OPERACION-SLO-RUNBOOKS | SLOs (incluye su tramo del SLO E2E), alertas, runbooks | 9 |
| BOS-biedata-150 | INSTALACION | Instalación por el bos, descubrimiento, SIGUSR1, checklist de acoplamiento | 9 |
| BOS-biedata-160 | PLAN-DE-IMPLEMENTACION-ATOMICO | Nivel micro biedata: tareas atómicas (G0–G2 completo; G3–G5 al validarse sus SSOT); derivado del corpus v3.0 + rescate V8 reencuadrado D9/D10 | 1-G (vivo) |
| BOS-biedata-170 | GLOSARIO | Glosario de la serie + términos históricos con redirección + tarea formal de actualización del SBOS-050 (C-15) | 9 |

## 7. Dependencias entre series y orden de redacción

### 7.1 Grafo de dependencias conceptuales

```
                       ┌──────────────────────────────┐
                       │   BOS-ECO-000 (este doc)     │  gobierno
                       │   BOS-ECO-001 (memoria)      │
                       └──────────────┬───────────────┘
                                      │
                       ┌──────────────▼───────────────┐
                       │   BOS-ECO-010 doctrina RPC   │  lengua franca
                       └──────┬───────────────┬───────┘
                              │               │
            ┌─────────────────▼───┐   ┌───────▼──────────────────┐
            │ BOS-ECO-020         │   │ BOS-ECO-030              │  contratos
            │ contrato bK↔bd      │   │ acoplamiento al bos      │
            └───────┬─────────────┘   └──────────┬───────────────┘
                    │ referenciado por           │ referenciado por
     ┌──────────────▼──────────────┐  ┌──────────▼───────────────┐
     │ BOS-bKernel-010…200         │  │ BOS-biedata-010…160      │  daemons
     │ (21 docs)                   │  │ (16 docs)                │
     └─────────────────────────────┘  └──────────────────────────┘
```

Regla de dirección: las series de daemon **referencian hacia arriba** (a ECO); ECO jamás
referencia detalles internos de un daemon. Entre series hermanas (bKernel↔biedata) no hay
referencias directas: todo lo compartido pasa por ECO-020.

### 7.2 Orden de redacción por lotes (congelado)

```
Lote 1:   ECO-000 · ECO-001 · ECO-010                     (gobierno + doctrina)
Lote 1-G: ECO-002..008 · bK-002..007 · bK-190 · bd-002..007 · bd-160   (enmienda R7:
          gobierno operativo por proyecto + planes atómicos — entregado 2026-06-10)
Lote 2: ECO-020 · ECO-030                                  (los dos contratos — el corazón)
Lote 3: bK-010 · bK-040 · bd-010 · bd-040 (+ bK/bd-000/001) (visiones y ADRs, espejadas)
Lote 4: bK-020/030/050 · bd-020/030/050                    (normas, requisitos, arquitecturas)
Lote 5: bK-130 · bK-140 · bd-100 · bd-070                  (datos y declaratividad)
Lote 6: bK-060 → 070 → 080 → 090                           (pipeline decisor bKernel)
Lote 7: bd-060 → 080 → 090                                 (motor ejecutor biedata)
Lote 8: bK-100/110/120 · bd-110/120/130                    (protección, observabilidad, escala)
Lote 9: bK-150-200 · bd-140-160  (+ tarea: actualización SBOS-050 puertos)
```

Ciclo obligatorio por lote: **investigación web de respaldo (D7) → redacción → entrega al
arquitecto → actualización de BOS-ECO-001**.

## 8. Rutas de lectura por rol

| Rol | Ruta mínima obligatoria | Después, según tarea |
|---|---|---|
| **Agente que retoma el proyecto documental** | ECO-000 (este) → ECO-001 (estado) → siguiente documento PENDIENTE según lotes §7.2 | El documento fuente listado en la matriz de ECO-001 y los conflictos C-XX aplicables |
| **Agente implementador de bKernel** | ECO-000 → ECO-010 → ECO-020 → bK-010 → bK-040 → bK-050 | El doc del módulo a implementar (bK-060…120) + bK-130 (datos) + bK-140 (fichas) |
| **Agente implementador de biedata** | ECO-000 → ECO-010 → ECO-020 → bd-010 → bd-040 → bd-050 → bd-060 | bd-070/080 según el módulo + bd-100 (datos) + bd-120 (resiliencia) |
| **Agente del proyecto bos** (integración) | ECO-000 §5 (doctrina) → ECO-030 completo | bK-180 y bd-150 (instalación) |
| **Integrador externo / cliente del RPC de biedata** | ECO-010 → bd-060 (protocolo, tiers) → `biedata.describe` en vivo | bd-090 (flujos), bd-020 (normas de su dominio) |
| **Arquitecto (revisión de entregas)** | ECO-001 §3 (qué cambió) → el documento entregado → su sección "Criterios de completitud" | Conflictos PROPUESTO en ECO-001 §7, si los hay |
| **Operador / SRE** | ECO-000 §2 → bK-170 y bd-140 (SLO/runbooks) | bK-110 y bd-130 (observabilidad) |
| **Auditor de cumplimiento** | ECO-000 §10 → bK-020 y bd-020 (matrices normativas) | bK-160 y bd-110 (seguridad), bK-110 (lineage), bd-100 (auditoría) |
| **Humano no técnico** | Plano COMPRENSIÓN de: ECO-000 → bK-010 → bd-010 | ECO-010 §1–§3 |

## 9. Jerarquía de autoridad sobre el knowledge histórico

Cuando un redactor necesita un dato del corpus histórico y dos fuentes se contradicen,
resuelve con esta jerarquía. **Sobre cualquier nivel mandan las decisiones congeladas
(§5) y las resoluciones C-01…C-16 registradas en Fase 0** (archivadas en
`DOC-CREATE-02-CONFLICTOS-RESOLUCIONES`; los conflictos nuevos se registran en
→ BOS-ECO-001 §7).

```
N1: 01-BKERNEL-MASTER-v4_0 (+parche 04) · DAEMON-BIEDATA-00..08 (v3.0)
N2: 05-PROPUESTA · BKERNEL-ARQUITECTURA-PROYECTADA
N3: satélites CDC (02/03) · BKERNEL-DDL-GUARDIAN · CONTRATO/DDL/SIMULACION bSearch
N4: SBOS-049 / SBOS-050 / SBOS-MANUAL-ACOPLAMIENTO (autoridad en SU dominio)
    · BOS-REPAIR (referencia del proyecto bos)
N5: BKERNEL-DEFINICION-CANONICA v3.0 · BKERNEL-HUMAN-DOC (narrativa/decisiones rescatables)
N6: series V8 (SBOS_bkernel_* · SBOS_biedata_* · SBOS-023) — rescatar formatos F-XXX, ADRs
    y capacidades de intercambio exterior (import/export/migración/pasarelas) contra v3.0
REF: Manual JSON-RPC 01-09 (corpus normativo paralelo) · POSTGRESQL-WAL-* (fuente)
```

Supersesiones ya aplicadas que el redactor NO debe rediscutir (todas validadas en Fase 0
o derivadas de N1 sobre generaciones anteriores):

| Tema | Versión que muere | Versión vigente | Resolución |
|---|---|---|---|
| Puertos bKernel | 9100, 9105 | 9460/9461 | C-01, D5 |
| Puertos biedata | 9448 (V8) · 9470 métricas/9471 health (acoplamiento v2.0) | 9470 API / 9471 métricas / 9472 health | C-15, D5 |
| Quién escribe negocio | "bKernel escribe con origin='bkernel'" | biedata escribe, `origin='biedata'` | D1, R1 |
| Identidad de biedata | "aduana fiscal / motor batch por eventos" como definición total | **SBOS Data Gateway: Sovereign Data Exchange Engine** — nexo universal con Tres Responsabilidades; lo fiscal es un dominio, no la identidad | N1 (BIEDATA-00 v3.0) + directiva del arquitecto 2026-06-10 (corrección v1.1) |
| Diálogo API exterior regulado (fiscal y similares) | caja `smarttax_emitir` de biedata (V8); "biedata POST mTLS al SIAT" (acoplamiento v2.0) | **lo ejecuta cada aplicación obligada por ley** (btax como SIF: obtiene su CUF); biedata = puerta de datos (insumos + persistencia de resultados) | **C-17 VALIDADO** por el arquitecto, 2026-06-10 |
| API de biedata | "sin API REST pública / solo eventos" (acoplamiento v2.0) | servidor JSON-RPC 2.0 exclusivo en `POST /rpc` :9470 | N1 (BIEDATA-00/01 v3.0), D4/D5 |
| Unidad declarativa biedata | solo "caja .so" (V8) | Ficha (3 archivos, RPC) + Caja WASM (import/export masivo); .so legacy | N1 + ADRs V8 rescatados |
| Control de bKernel | socket Unix / RPC de control | ninguno: fichas+SIGHUP+tablas de estado | D2, R2 (UDS RECHAZADO) |
| Transporte inter-daemon para acciones | veto absoluto de HTTP (ADR-012 del acoplamiento v2.0) | JSON-RPC sobre HTTP según clase de soberanía | D4, C-13 → BOS-ECO-010 §5 |
| Lenguaje bKernel | Go | Rust 1.85+ (Edition 2024), MUSL estático, tokio | C-03 |
| BD operacional bKernel | `bkernel_db` | esquema `bkernel` en `sbos_kernel_db` | C-04, C-16 |
| Unidad declarativa bKernel | "regla YAML" V8 | Ficha (4 archivos) + reglas CESQL en registry | C-05 |
| Alcance CDC | "solo PostgreSQL WAL" | multi-motor nativo sin intermediarios | C-06 |
| Índice de bSearch | Meilisearch/Qdrant (V8) | según contrato D1 vigente (PostgreSQL 18+) | C-07 |
| Tamaño binario | ~8/9/10 MB prometidos | presupuesto verificable: MUSL estático < 15 MB | C-08 |
| Modelo de ejecución bKernel | core Bash 00_* maestros | pipeline 100% Rust; `task_catalog.sh` como plugin | C-09 |
| SLOs | dos juegos con el mismo nombre | tabla canónica con puntos de medición nombrados | C-02 |
| Rol OrangeHRM | fuente XOR destino | doble rol explícito (fuente Binlog / destino vía biedata) | C-11 |
| Formato maestro | .md y .docx editables en paralelo | markdown-first; oficina solo generado | C-12 |
| Emisor fiscal | caja `smarttax_emitir` de biedata (V8) emite al SIN; flujo export fiscal del acoplamiento v2.0 | la aplicación regulada (btax) ejecuta su propio diálogo exterior; biedata = caja cerrada, puerta de datos | **C-17 VALIDADO, D9** |
| "Único daemon con HTTP saliente" | regla absoluta atribuida a biedata | matizada por D9/D10: los diálogos API HTTP regulados pertenecen a las aplicaciones autorizadas (variables en el tiempo); el intercambio de DATOS sigue en biedata | D9, D10 |

**C-17 — VALIDADO por el arquitecto (2026-06-10), doctrina D9:** los diálogos API HTTP
con el exterior **regulados por leyes y normas estatales** los ejecuta **cada aplicación
obligada** (ejemplo ilustrativo, variable D10: un sistema de facturación obtiene su
código de autorización y realiza su ciclo con el ente); biedata no los duplica — es caja
cerrada que solo actualiza bases de datos por consumo y emisión de datos. La aplicación
regulada escribe SOLO en su propia BD; bKernel la escucha por WAL y organiza la
actualización del ecosistema (D10, Q-01/Q-02 respondidas — → BOS-ECO-001 §7.2). Muere el
modelo V8 de la caja `smarttax_emitir` y la lectura "biedata POST mTLS al SIAT" del
acoplamiento v2.0. Ninguna aplicación concreta determina el funcionamiento de los
daemons (D10).

## 10. Reglas de redacción de los documentos finales (obligatorias)

1. **Single Source of Truth (P1).** Cada concepto vive en UN documento; el resto referencia
   con `→ SERIE-NNN §X`. Los contratos entre daemons viven SOLO en BOS-ECO.
2. **Doble audiencia (P2).** Cada documento tiene plano ESPECIFICACIÓN (agente: contratos,
   firmas Rust, SQL ejecutable, formatos exactos, criterios DADO/CUANDO/ENTONCES) y plano
   COMPRENSIÓN (humano: propósito, justificación, diagramas).
3. **Código de referencia incluido (P3).** Structs/traits/firmas Rust, DDL SQL ejecutable,
   YAML/TOML completos. El agente implementador no inventa nada estructural.
4. **Normas con cláusula exacta (P4).** Ejemplo: "ISO/IEC 27001:2022 Annex A.8.16". Cada
   cláusula se verifica con búsqueda web durante la redacción y la investigación se cita
   en el documento (D7).
5. **No resúmenes (P5).** Documentación amplia, detallada y sólida. Lo absorbido de
   documentos fuente se integra completo y corregido, no condensado.
6. **Metadatos obligatorios (P6).** Cabecera conforme a §11 + sección final "Criterios de
   completitud de este documento".
7. **Markdown-first (P7 / C-12).** Los formatos de oficina se generan desde el markdown,
   nunca se editan a mano.
8. **Marco normativo de la documentación misma:** ISO/IEC/IEEE 15289:2019 (tipos genéricos
   de documento, cláusula 7; contenidos específicos, cláusula 10), ISO/IEC/IEEE 29148:2018
   (ingeniería de requisitos — formato de los F-XXX), IEEE 1016-2009 (descripciones de
   diseño de software), ISO/IEC/IEEE 42010:2022 (descripción de arquitectura), ISO/IEC/IEEE
   12207:2017 (procesos del ciclo de vida) e ISO/IEC/IEEE 26514:2022 (información para
   usuarios) — alineado con el ADR-003 del proyecto bos.
9. **Conflictos nuevos.** Si el redactor encuentra una contradicción no resuelta en Fase 0,
   NO la redacta en un documento final: la registra como PROPUESTO en → BOS-ECO-001 §7 y
   pide validación del arquitecto.
10. **Paridad de los dos daemons.** Ningún documento de la serie ECO presenta a uno de los
    daemons como subordinado del otro, ni reduce la identidad de biedata a su rol de
    escritura (D1) o al dominio fiscal, ni la de bKernel a "listener del WAL". Las
    identidades de referencia son §2 y §4 de este documento (regla añadida en v1.1 por
    directiva del arquitecto).
11. **Aplicaciones como variables (D10).** Ningún nombre de aplicación o de base de datos
    de negocio es normativo en las tres series: las aplicaciones son variables en el
    tiempo. Cuando un documento usa una app (Tryton, OrangeHRM, un sistema de
    facturación) lo hace SOLO como ejemplo ilustrativo de un patrón, marcándolo como tal.
    Las constantes documentales son: los daemons, los contratos ECO, los mecanismos
    declarativos (fichas, cajas, registros, reglas) y las normas. Un documento que haga
    depender el diseño de una aplicación concreta está mal redactado (regla añadida en
    v1.3 por directiva del arquitecto).

## 11. Plantilla de metadatos obligatoria

Todo documento final inicia con esta tabla (campos en este orden, ninguno opcional):

```markdown
## 0. Metadatos del documento

| Campo | Valor |
|---|---|
| **Documento** | BOS-<SERIE>-NNN-<TITULO> |
| **Versión** | SemVer del documento (1.0 al nacer) |
| **Estado** | VIGENTE | SUPERSEDIDO — y estado de redacción: REDACTADO | VALIDADO |
| **Fase asociada** | G0…G5 y lote de redacción |
| **Serie** | BOS-ECO | BOS-bKernel | BOS-biedata |
| **Fuentes que absorbe** | lista exacta de documentos históricos integrados |
| **Documentos que supersede** | lista o "Ninguno" |
| **Prerequisitos de lectura** | documentos finales que deben leerse antes |
| **Normas aplicables** | norma + cláusula exacta, verificadas por web (D7) |
| **Audiencia** | agente / humano / ambas |
| **Custodio** | responsable de mantenerlo |
| **Fecha** | fecha de la versión |
```

Y termina con la sección **"Criterios de completitud de este documento"**: una lista
verificable (checklist) de condiciones bajo las cuales el documento se considera terminado,
conforme al principio de completitud verificable.

## 12. Ciclo de vida y mantenimiento

- **Estados de documento:** `PENDIENTE → EN-REDACCIÓN → REDACTADO → VALIDADO`. Solo el
  arquitecto mueve un documento a VALIDADO.
- **Estados de módulo de desarrollo** (cuando arranque la implementación):
  `ESPECIFICADO → EN-DESARROLLO → IMPLEMENTADO → VERIFICADO`.
- **Toda entrega** actualiza → BOS-ECO-001 en el mismo acto (tablero, matriz, hitos).
- **Versionado:** cambios editoriales incrementan PATCH; cambios de contenido sin ruptura,
  MINOR; cambios que alteran un contrato o una decisión, MAYOR y requieren validación
  explícita del arquitecto.
- **Estabilidad de nombres (regla dictada por el arquitecto, 2026-06-10):** el nombre del
  archivo de cada documento es **estable e inmutable** durante toda su vida. La versión
  vive ÚNICAMENTE en los metadatos (§11) y en el changelog interno del documento. Está
  PROHIBIDO renombrar archivos por versión (`-v1.1`, `-rev2`, copias paralelas): genera
  basura documental y ambigüedad sobre cuál es el documento válido. Un archivo = un
  documento = una historia de versiones interna.
- **Señal de retoma rápida para agentes:** (1) leer este documento; (2) leer ECO-001 para
  el estado exacto; (3) consultar las resoluciones C-XX antes de usar cualquier dato del
  knowledge histórico; (4) identificar el siguiente documento PENDIENTE según §7.2 y
  redactarlo; (5) al terminar, actualizar ECO-001 y entregar ambos; (6) jamás reinterpretar
  D1–D8; (7) leer el corpus N1 COMPLETO del daemon sobre el que se redacta — no solo los
  fragmentos citados en las matrices (lección de la corrección v1.1).

---

## 13. Criterios de completitud de este documento

- [x] Doctrina D1–D8 transcrita íntegra y sin reinterpretación, con nota de alcance de D1 (D1 norma la escritura interna; no agota la identidad de biedata).
- [x] **Paridad de identidades:** bKernel y biedata presentados con el mismo nivel de profundidad (§2.1/§2.2), incluyendo la identidad completa de biedata según su corpus N1 (Data Gateway / Sovereign Data Exchange Engine, filosofía "el RPC siempre hace algo", motor recursivo, analogía Tryton, Tres Responsabilidades, tiers, multi-formato, cajas, descubrimiento) — corrección ordenada por el arquitecto el 2026-06-10.
- [x] Lo fiscal presentado como UN dominio de la Responsabilidad A, no como la identidad de biedata.
- [x] Catálogo de los 65 documentos (post-R7, conteo reconciliado INC-01) con concepto único (SSOT) y lote de cada uno, incluido el juego de gobierno operativo 002–007(+008) de cada proyecto y los planes atómicos (bK-190, bd-160, ECO-008).
- [x] Grafo de dependencias, regla de dirección de referencias y orden de lotes congelado sin modificación.
- [x] Rutas de lectura para 9 roles (añadido: integrador externo/cliente del RPC).
- [x] Jerarquía de autoridad N1–N6+REF y tabla de supersesiones (18 entradas) incluyendo las tres específicas de biedata (identidad, API, unidad declarativa).
- [x] Resolución validada de C-17 integrada sin reinterpretación como D9 (caja cerrada de datos; diálogos regulados en las aplicaciones obligadas).
- [x] Doctrina D10 incorporada (§5) con su triple contenido (cero invasión; toda BD del stack es fuente CDC; aplicaciones como variables), el ciclo §2.4 corregido (entrada primaria: cada app escribe en su propia BD) y las respuestas Q-01…Q-05 cerradas conforme → BOS-ECO-001 §7.2.
- [x] Reglas de redacción 1–11 (regla 10: paridad de daemons; regla 11: aplicaciones como variables) con marco normativo y cláusulas verificadas por búsqueda web el 2026-06-10 (ISO/IEC/IEEE 15289:2019 cl. 7 y 10).
- [x] Plantilla de metadatos obligatoria y ciclo de vida documental, con señal de retoma ampliada (paso 7: leer el corpus N1 completo del daemon).
- [ ] Validación del arquitecto (mueve el documento a VALIDADO).

---

*BOS-ECO-000 v1.4 · 2026-06-10 · Serie BOS-ECO — cuarta generación documental, única vigente. El nombre del archivo es estable: la versión vive solo en estos metadatos.*
*Changelog — v1.4: enmienda R7 (gobierno operativo por proyecto: 002–007 en cada serie, planes atómicos ECO-008/bK-190/bd-160, bd-170 glosario separado; 65 documentos; lote 1-G; INC-01 reconciliado). v1.3: doctrina D10 (cero invasión + aplicaciones como variables; Q-01…Q-05 respondidas y validadas), regla de redacción 11, ciclo §2.4 corregido. v1.2: doctrina D9 (C-17 validado), regla de estabilidad de nombres. v1.1: identidad completa de biedata (paridad §2/§4, regla 10). v1.0: versión inicial.*
*El estado vivo del proyecto está en → BOS-ECO-001. La doctrina del protocolo está en → BOS-ECO-010.*
