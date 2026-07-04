# BOS-ECO-001 — MEMORIA DE COMPLETITUD GLOBAL
## Estado vivo del proyecto documental y de desarrollo — Series BOS-ECO · BOS-bKernel · BOS-biedata

---

## 0. Metadatos del documento

| Campo | Valor |
|---|---|
| **Documento** | BOS-ECO-001-MEMORIA-COMPLETITUD-GLOBAL |
| **Versión** | 1.4 — enmienda estructural R7 (gobierno operativo por proyecto): catálogo 45→65, Lote 1-G entregado; reconciliación de conteo INC-01. Historial: v1.3 D10; v1.2 D9; v1.1 OBS-L1-01 |
| **Estado** | VIGENTE — documento vivo; se actualiza en CADA entrega |
| **Fase asociada** | Transversal (G0–G5) — nace en el Lote 1 |
| **Serie** | BOS-ECO |
| **Fuentes que absorbe** | `DOC-CREATE-04-MEMORIA-COMPLETITUD` v1.0 (íntegro; este documento lo reemplaza como memoria viva) |
| **Documentos que supersede** | `DOC-CREATE-04-MEMORIA-COMPLETITUD` (queda como archivo de Fase 0) |
| **Prerequisitos de lectura** | → BOS-ECO-000 (gobierno, doctrina D1–D8, reglas de actualización) |
| **Normas aplicables** | ISO/IEC/IEEE 15289:2019 cláusula 7 (este documento es del tipo genérico *report* + *record*: registro de estado del producto documental) · ISO/IEC/IEEE 12207:2017 §6.3.7 (proceso de gestión de la información) |
| **Audiencia** | Doble: agentes que retoman el proyecto (estado exacto) y arquitecto (control de avance) |
| **Custodio** | Agente documental (actualización por entrega) · Arquitecto (validaciones) |
| **Fecha** | 2026-06-10 |

---

# PLANO COMPRENSIÓN

## 1. Qué es esta memoria y cómo se usa

Esta es la **única fuente del estado del proyecto**. Responde, en cualquier momento y para
cualquier agente o humano que retome el trabajo: ¿qué está hecho, qué está en curso, qué
falta, y qué decisiones esperan al arquitecto?

Reglas de uso (obligatorias, heredadas de → BOS-ECO-000 §11):

1. **Se actualiza en cada entrega**, en el mismo acto en que se entrega un documento o un
   módulo. Una entrega sin actualización de esta memoria es una entrega incompleta.
2. **Estados de documento:** `PENDIENTE → EN-REDACCIÓN → REDACTADO → VALIDADO`.
   Solo el arquitecto mueve un documento a VALIDADO.
3. **Estados de módulo** (al iniciar implementación):
   `ESPECIFICADO → EN-DESARROLLO → IMPLEMENTADO → VERIFICADO`.
4. **Conflictos nuevos** se registran en §7 como PROPUESTO con su evidencia, y NO se
   redactan en documentos finales hasta la validación del arquitecto (→ BOS-ECO-000 §9.9).
5. Las memorias de serie (BOS-bKernel-001 y BOS-biedata-001, Lote 3) detallarán el estado
   por serie; este documento global siempre prevalece en caso de divergencia.

---

# PLANO ESPECIFICACIÓN — ESTADO ACTUAL

## 2. Tablero global

**Última actualización: 2026-06-10 — Enmienda R7 ejecutada: Lote 1-G entregado (21 documentos nuevos/redefinidos de gobierno operativo).**

| Serie | Documentos | Validados | Redactados | En redacción | Pendientes |
|---|---|---|---|---|---|
| BOS-ECO | 12 | 0 | **10** | 0 | 2 |
| BOS-bKernel | 28 | 0 | **7** | 0 | 21 |
| BOS-biedata | 25 | 0 | **7** | 0 | 18 |
| **TOTAL** | **65** | **0** | **24** | **0** | **41** |

*Conteo reconciliado (INC-01): las listas congeladas de Fase 0 contienen 45 documentos —
el total "42" del acta contaba las parejas 000/001 como un solo documento. La enmienda R7
(arquitecto, 2026-06-10) añade 7 docs a ECO, 6 a bKernel y 7 a biedata (002–007 por serie,
ECO-008, bd-170 glosario separado de bd-160) y redefine bK-190/bd-160 como planes ATÓMICOS.*

Fase actual: **Lote 1 + Lote 1-G ENTREGADOS (REDACTADO, esperan validación del arquitecto).**
Próxima acción: validación → arranque del **Lote 2** (ECO-020 · ECO-030 — los contratos).

## 3. Matriz por documento

### 3.1 Serie BOS-ECO

| Doc | Título | Lote | Estado | Fecha | Notas |
|---|---|---|---|---|---|
| ECO-000 | GUIA-DOCUMENTAL-GLOBAL | 1 | **REDACTADO (rev. v1.3)** | 2026-06-10 | v1.3: doctrina D10 (cero invasión + aplicaciones como variables), regla de redacción 11 (app-agnosticismo), ciclo §2.4 corregido (la entrada primaria al ciclo es la escritura de cada app en SU propia BD). v1.2: D9. v1.1: identidad completa de biedata |
| ECO-001 | MEMORIA-COMPLETITUD-GLOBAL | 1 | **REDACTADO (rev. v1.3)** | 2026-06-10 | v1.3 (este documento); Q-01…Q-05 respondidas por el arquitecto, validadas contra corpus + web (§7.2) |
| ECO-002 | MAPA-DE-NAVEGACION | 1-G | **REDACTADO** | 2026-06-10 | v1.0 — navegación global por intención/concepto |
| ECO-003 | PROTOCOLO-SESION-AGENTE | 1-G | **REDACTADO** | 2026-06-10 | v1.0 — apertura/ejecución/cierre; sesión sin estado+log = inválida |
| ECO-004 | REGISTRO-DE-ESTADO | 1-G | **REDACTADO** | 2026-06-10 | v1.0 — YAML máquina; máquinas de estado canónicas |
| ECO-005 | LOG-DE-SESIONES | 1-G | **REDACTADO** | 2026-06-10 | v1.0 — append-only, sembrado S-001..S-007 |
| ECO-006 | INSTRUCCIONES-DE-USO | 1-G | **REDACTADO** | 2026-06-10 | v1.0 — uso por rol, reglas de oro, prohibiciones |
| ECO-007 | SKILL-AGENTE-PROGRAMADOR | 1-G | **REDACTADO** | 2026-06-10 | v1.0 — skill maestro cargable (stack, DoD, doctrina en código) |
| ECO-008 | PLAN-MAESTRO-ATOMICO | 1-G | **REDACTADO** | 2026-06-10 | v1.0 — G0–G5 → 21 etapas con criterio medible; H0–H5; gates |
| ECO-010 | DOCTRINA-JSON-RPC | 1 | **REDACTADO (rev. v1.3)** | 2026-06-10 | v1.3: nombres de aplicaciones marcados como variables ilustrativas (D10) en mapa, soberanía, categorías y registro. v1.2: D9. v1.1: identidad de biedata; spec jsonrpc.org y RFC 9449 verificados |
| ECO-020 | CONTRATO-BKERNEL-BIEDATA | 2 | PENDIENTE | — | corazón del sistema; D1/D2/D3; absorbe condiciones técnicas de D-01 (SLO por tramo, idempotencia bilateral, caída de biedata) |
| ECO-030 | ACOPLAMIENTO-AL-BOS | 2 | PENDIENTE | — | referencia BOS-REPAIR; D8; Context Plane y traceparent E2E |

### 3.2 Serie BOS-bKernel

| Doc | Título | Lote | Estado | Notas |
|---|---|---|---|---|
| bK-000 | GUIA-DOCUMENTAL | 3* | PENDIENTE | *se emite junto al Lote 3 |
| bK-002..007 | GOBIERNO OPERATIVO (mapa, protocolo, registro, log, instrucciones, skill) | 1-G | **REDACTADO** | v1.0 c/u, 2026-06-10 (enmienda R7) |
| bK-001 | MEMORIA-COMPLETITUD | 3* | PENDIENTE | — |
| bK-010 | VISION-Y-FRONTERAS | 3 | PENDIENTE | fronteras literales D2; D1 |
| bK-020 | NORMAS-Y-CUMPLIMIENTO | 4 | PENDIENTE | matriz cláusula→control→módulo (V-07) |
| bK-030 | REQUISITOS-Y-CAPACIDADES | 4 | PENDIENTE | F-XXX DADO/CUANDO/ENTONCES (V-01) |
| bK-040 | DECISIONES-ARQUITECTURA-ADR | 3 | PENDIENTE | + ADR D1/D2 |
| bK-050 | ARQUITECTURA-SISTEMA | 4 | PENDIENTE | metrics 9460 (D5) |
| bK-060 | CDC-ENGINE | 6 | PENDIENTE | absorbe 02/04 + POSTGRESQL-WAL-* |
| bK-070 | CONTEXT-ENRICHER-Y-ENTITY-GRAPH | 6 | PENDIENTE | — |
| bK-080 | ROUTING-CESQL | 6 | PENDIENTE | gramática formal del subset |
| bK-090 | ENGINE-INTENCIONES-Y-ORQUESTACION | 6 | PENDIENTE | rescope por D1: cero adaptadores; contrato task_catalog.sh (V-05) |
| bK-100 | DDL-GUARDIAN | 8 | PENDIENTE | absorbe BKERNEL-DDL-GUARDIAN + ampliaciones |
| bK-110 | LINEAGE-Y-OBSERVABILIDAD | 8 | PENDIENTE | catálogo métricas :9460 |
| bK-120 | CLUSTER-MODE | 8 | PENDIENTE | umbral >25 fuentes |
| bK-130 | MODELO-DE-DATOS | 5 | PENDIENTE | + context_sessions/registered_devices (C-16) |
| bK-140 | FICHAS-DECLARATIVAS | 5 | PENDIENTE | fichas de referencia completas (V-03) |
| bK-150 | INTEGRACIONES | 9 | PENDIENTE | bSearch; doble rol OrangeHRM (C-11) |
| bK-160 | SEGURIDAD | 9 | PENDIENTE | sin credenciales de apps destino (D1) |
| bK-170 | OPERACION-SLO-RUNBOOKS | 9 | PENDIENTE | tabla SLO canónica por tramo (C-02) |
| bK-180 | INSTALACION | 9 | PENDIENTE | orden bos garantizado (V-04) |
| bK-190 | PLAN-DE-IMPLEMENTACION-ATOMICO | 1-G (vivo) | **REDACTADO** | v1.0, 2026-06-10 — G0/G1 a tarea atómica completa (de A5); G2–G5 se micro-detallan al validarse sus SSOT (gates ECO-008 §3) |
| bK-200 | GLOSARIO | 9 | PENDIENTE | términos históricos con redirección |

### 3.3 Serie BOS-biedata

| Doc | Título | Lote | Estado | Notas |
|---|---|---|---|---|
| bd-000 | GUIA-DOCUMENTAL | 3* | PENDIENTE | — |
| bd-002..007 | GOBIERNO OPERATIVO (mapa, protocolo, registro, log, instrucciones, skill) | 1-G | **REDACTADO** | v1.0 c/u, 2026-06-10 (enmienda R7) |
| bd-001 | MEMORIA-COMPLETITUD | 3* | PENDIENTE | — |
| bd-010 | VISION-Y-FRONTERAS | 3 | PENDIENTE | "el RPC siempre hace algo"; ejecutor universal (D1) |
| bd-020 | NORMAS-Y-CUMPLIMIENTO | 4 | PENDIENTE | incluye fiscal SIAT/AFIP/SAT |
| bd-030 | REQUISITOS-Y-CAPACIDADES | 4 | PENDIENTE | rescate F-XXX V8 contra v3.0 |
| bd-040 | DECISIONES-ARQUITECTURA-ADR | 3 | PENDIENTE | Inbox, Smart Tax caja, RPC exclusivo |
| bd-050 | ARQUITECTURA-SISTEMA | 4 | PENDIENTE | puertos 9470/9471/9472 (D5) |
| bd-060 | PROTOCOLO-RPC | 7 | PENDIENTE | absorbe DAEMON-BIEDATA-01 |
| bd-070 | FICHAS-Y-PIPELINE | 5 | PENDIENTE | manifest+validation+task_catalog |
| bd-080 | CAJAS-WASM | 7 | PENDIENTE | — |
| bd-090 | FLUJOS-CANONICOS | 7 | PENDIENTE | ciclo WAL completo |
| bd-100 | MODELO-DE-DATOS | 5 | PENDIENTE | biedata_db; _inbox |
| bd-110 | SEGURIDAD | 8 | PENDIENTE | custodia credenciales destino (D1) |
| bd-120 | RESILIENCIA | 8 | PENDIENTE | — |
| bd-130 | OBSERVABILIDAD | 8 | PENDIENTE | — |
| bd-140 | OPERACION-SLO-RUNBOOKS | 9 | PENDIENTE | su tramo del SLO E2E |
| bd-150 | INSTALACION | 9 | PENDIENTE | — |
| bd-160 | PLAN-DE-IMPLEMENTACION-ATOMICO | 1-G (vivo) | **REDACTADO** | v1.0, 2026-06-10 — G0–G2 a tarea atómica completa (corpus v3.0 + rescate V8 reencuadrado D9/D10) |
| bd-170 | GLOSARIO | 9 | PENDIENTE | separado de bd-160 por R7; incluye tarea actualización SBOS-050 (C-15) |

## 4. Módulos de desarrollo (se activa al iniciar implementación)

| Fase global | Módulos bKernel | Módulos biedata | Documentos del hito | Estado |
|---|---|---|---|---|
| G0 Fundaciones | esqueleto binario, CI | esqueleto, CI | ECO-000/001/010 · ambas 000-050 · bK-140 | NO INICIADO (espec. en curso: 3/13 docs del hito redactados) |
| G1 Contrato bilateral | mod cdc (canal/fuente), Outbox→streams | Inbox, consumer streams | ECO-020 · bK-060 · bd-060/070 | NO INICIADO |
| G2 Pipeline decisor | mod routing + registry | pipeline fichas, fachadas Tryton/OrangeHRM | bK-080/090 · bd-080/090 | NO INICIADO |
| G3 Contexto y grafo | mod enricher + mod graph (AGE) | ctx_id en operaciones | bK-070 · ECO-030 (parcial) | NO INICIADO |
| G4 Protección y linaje | mod ddl_guardian v2, mod lineage | resiliencia, observabilidad | bK-100/110 · bd-120/130 | NO INICIADO |
| G5 Escala | mod coordinator + mod state | hardening | bK-120 · operación/instalación/planes | NO INICIADO |

Hitos de implementación asociados (definidos en la estructura congelada):
H0 especificación congelada (cierre documental de G0) · H1 intención→ejecución E2E en
staging · H2 pipeline decisor · H3 contexto y grafo · H4 **producción** · H5 escala.

## 5. Registro de hitos y decisiones

| Fecha | Evento |
|---|---|
| 2026-06-09 | Fase 0 iniciada: auditoría de 41 documentos bKernel/bSearch/SBOS |
| 2026-06-09 | 12 conflictos detectados (C-01..C-12) + 10 inconsistencias absorbidas + 7 vacíos |
| 2026-06-09/10 | Corpus biedata (20 docs) y BOS-REPAIR (28 docs) incorporados; C-13..C-16 |
| 2026-06-10 | Arquitecto valida R1–R6: doctrina D1–D8 congelada (→ BOS-ECO-000 §4) |
| 2026-06-10 | **ESTRUCTURA CONGELADA**: 3 series, 42 documentos, 9 lotes. Fase 0 COMPLETADA |
| 2026-06-10 | **LOTE 1 ENTREGADO**: ECO-000 v1.0, ECO-001 v1.0, ECO-010 v1.0 en estado REDACTADO. Investigación de respaldo ejecutada y citada (jsonrpc.org spec 2013-01-04; RFC 9449; ISO/IEC/IEEE 15289:2019). DOC-CREATE-04 absorbido y archivado. Las tensiones ADR-012 vs D4, puertos biedata del acoplamiento v2.0 y `origin='bkernel'` quedaron documentadas como supersesiones (resueltas por D1/D4/D5 y C-13/C-15) |
| 2026-06-10 | **OBSERVACIÓN DEL ARQUITECTO (OBS-L1-01)**: el v1.0 de ECO-000 subrepresentaba a biedata, reduciéndolo a "ejecutor de escrituras + aduana fiscal". Corrección ordenada: biedata es el nexo entre el universo SBOS y el mundo exterior, mucho más que escritura, y lo fiscal NO es su centro. Acción: relectura completa del corpus biedata (DAEMON-BIEDATA-00..08 v3.0 + serie V8) y revisión v1.1 de ECO-000 y ECO-010 (identidad completa: Sovereign Data Exchange Engine, Tres Responsabilidades, motor recursivo, tiers, multi-formato, cajas, descubrimiento, fronteras F1–F12; regla de paridad añadida como regla de redacción 10 en ECO-000 §10) |
| 2026-06-10 | **CONFLICTO NUEVO C-17 detectado y registrado como PROPUESTO** (§7): quién ejecuta el diálogo fiscal con SIAT/AFIP/SAT. No se redacta en documentos finales hasta validación |
| 2026-06-10 | **C-17 VALIDADO por dictado del arquitecto → nace D9**: biedata es una **caja cerrada** que solo actualiza las bases de datos a través del consumo y emisión de datos. La comunicación API HTTP con el exterior NO se centraliza en biedata: **cada aplicación que la ley y las normas estatales regulan se hace cargo de su propia comunicación exterior** (la excepción a "cero HTTP" es exclusivamente regulatoria). Caso facturación: **btax** dialoga con el ente, obtiene su CUF y realiza sus tareas de actualización de datos. biedata no repite esas responsabilidades. El detalle del flujo de los datos que llegan a btax por su API ("alto, no es tan fácil") queda en precisión: Q-01…Q-05 |
| 2026-06-10 | **Regla de gobierno documental dictada**: el **nombre del archivo es estable e inmutable**; toda evolución de versión vive ÚNICAMENTE en los metadatos y el changelog internos del documento. Renombrar archivos por versión genera basura y ambigüedad sobre cuál es el documento válido. Incorporada a ECO-000 §12 |
| 2026-06-10 | **Q-01…Q-05 RESPONDIDAS por el arquitecto → nace D10 (cero invasión + aplicaciones como variables)**: toda aplicación escribe SOLO en su propia BD; bKernel escucha TODAS las bases de datos del stack (esa es su razón de existir) y organiza la actualización del ecosistema; las aplicaciones y sus BDs son VARIABLES en el tiempo, no constantes — bKernel/biedata/bos no las conocen: su conocimiento es declarativo. Validado contra el corpus (Master §02.2 y F-01…F-11; HUMAN-DOC §5; acoplamiento §13/§31; doc 06 automático-vs-manual) y con investigación web (CDC log-based no intrusivo; patrón database-per-service de microservices.io). Regla de redacción 11 derivada: ningún nombre de aplicación es normativo en las series — solo ejemplo ilustrativo |
| 2026-06-10 | **Directiva de método ratificada por el arquitecto**: lectura COMPLETA del knowledge antes de redactar; rescate de TODOS los conceptos y datos (no resúmenes, regla C.5/P5); robustecimiento con investigación en internet (D7). El rescate íntegro de cada concepto se ejecuta en su documento SSOT (series bKernel/biedata, Lotes 3–9); la serie ECO porta doctrina y contratos |
| 2026-06-10 | **ENMIENDA R7 dictada por el arquitecto y EJECUTADA (Lote 1-G)**: cada proyecto (BOS-ECO, BOS-bKernel, BOS-biedata) recibe su juego de gobierno operativo — plan de implementación a nivel ATÓMICO (etapas hasta lo micro, entendible y MEDIBLE), mapa de navegación, protocolo de sesión de agente, registro de estado, log de sesiones, instrucciones de uso y skill del agente programador. Entregados 21 documentos: ECO-002..008, bK-002..007 + bK-190 (atómico, desde A5), bd-002..007 + bd-160 (atómico, desde corpus v3.0) con bd-170 separado. Catálogo: 65 documentos. INC-01 reconciliado (45 reales en el congelamiento, no 42) |
| — | Próximo: validación del arquitecto (Lote 1 + 1-G) → **Lote 2** (ECO-020 · ECO-030) |

## 6. Trazabilidad de absorción del Lote 1

Registro exigido por ISO/IEC/IEEE 15289:2019 (identificación y trazabilidad de
information items): qué fuente histórica quedó absorbida por qué documento final.

| Fuente histórica | Documento final que la absorbe | Alcance |
|---|---|---|
| DAEMON-BIEDATA-00-MAESTRO v3.0 (identidad, filosofía, analogía Tryton, Tres Responsabilidades) | ECO-000 §2.2–§2.3, §4 (rev. v1.1) | identidad de referencia; el desarrollo completo es SSOT de bd-010 |
| SBOS_biedata_VISION (V8: aduana soberana, import/export, principios P1–P8) | ECO-000 §2.3-A, §9 (rescate contra v3.0) | capacidades de intercambio exterior rescatadas; resto a bd-030 |
| DOC-CREATE-00 §A (señal de retoma) | ECO-000 §11 | completo, adaptado a la serie final |
| DOC-CREATE-00 §B (D1–D8) | ECO-000 §4 | transcripción íntegra, sin reinterpretación |
| DOC-CREATE-00 §C (reglas de redacción) | ECO-000 §9–§10 | completo |
| DOC-CREATE-00 §D–§E (series y lotes) | ECO-000 §5–§6 | completo |
| DOC-CREATE-00 §F (jerarquía) | ECO-000 §8 | completo + tabla de supersesiones |
| DOC-CREATE-03 v2 (estructura, principios, doctrina) | ECO-000 §2–§6 | completo |
| DOC-CREATE-04 v1.0 (memoria) | ECO-001 (este) | completo; tablero actualizado |
| JSON-RPC-01-fundamentos (estructura, convenciones, transporte) | ECO-010 §6–§8 | doctrina; el manual sigue siendo corpus paralelo (D4) |
| JSON-RPC-08 (categorías A/B/C, Fachada-RPC, gobernanza) | ECO-010 §9–§10 | doctrina adaptada a D1 (la fachada universal es biedata) |
| JSON-RPC-09 (orquestación, sagas) | ECO-010 §9.4 | posición doctrinal; el detalle de sagas va a ECO-020 y bK-090 |
| DAEMON-BIEDATA-01 (mensaje, endpoint, errores, 4 capas) | ECO-010 §7–§8, §11 | solo el plano doctrinal/ecosistémico; el protocolo completo es SSOT de bd-060 |
| jsonrpc.org/specification (verificado 2026-06-10) | ECO-010 §6 | cláusulas normativas exactas |

## 7. Decisiones abiertas y conflictos nuevos

| ID | Pregunta / conflicto | Estado | Registrado |
|---|---|---|---|
| **C-17** | ¿Quién ejecuta el diálogo con los entes exteriores regulados (SIAT/AFIP/SAT/PAC)? | **VALIDADO** (dictado del arquitecto, 2026-06-10) → doctrina **D9** | 2026-06-10 |
| **Q-01…Q-05** | Flujo de retorno de datos y alcance de aplicaciones (ver §7.2) | **RESPONDIDAS por el arquitecto y VALIDADAS** → doctrina **D10** | 2026-06-10 |

### C-17 — Ejecución del diálogo fiscal exterior: caja de biedata vs btax como SIF

| Campo | Detalle |
|---|---|
| Documentos en disputa | **(a)** Serie V8 `SBOS_biedata_FUNCIONALIDADES` F-002/F-005 + `SBOS_biedata_INTEGRACIONES` (biedata → SIAT/AFIP/SAT/PAC directo: caja `smarttax_emitir` genera XML, firma vía Jacobitus, calcula CUF, envía SOAP mTLS al SIN) y `SBOS-MANUAL-ACOPLAMIENTO` v2.0 §14 (flujo export: biedata hace el POST mTLS al SIAT). La tabla D-01 de Fase 0 lista "Aduana exterior (SIAT/AFIP/SAT, import CSV/Excel)" bajo biedata. **(b)** Corpus N1 `DAEMON-BIEDATA-03-FLUJOS` v3.0 §6: "btax habla DIRECTAMENTE con el SIAT (es el SIF autorizado). biedata no interviene en esa comunicación. biedata es la puerta de acceso a los datos del stack" + frontera F7 de `DAEMON-BIEDATA-04` §3: "biedata no emite facturas — eso es btax; biedata solo persiste resultados" |
| Lo NO disputado (puede redactarse) | biedata es el nexo universal de datos y la puerta única a los datos del stack; biedata es el único **daemon** autorizado a HTTP saliente al exterior; biedata persiste los resultados fiscales (CUF/CAE/UUID) con `origin='biedata'` y bKernel los propaga; la validación/aduana de calidad es de biedata; las capacidades de export genérico a otros destinos externos (bancos, SFTP, proveedores, pasarelas) son de biedata |
| Lo disputado (NO redactar) | si la construcción del XML fiscal, la firma, el cálculo del CUF y el POST al ente los ejecuta una **caja fiscal de biedata** (modelo V8) o la **aplicación btax como SIF autorizado** que usa a biedata solo como puerta de datos (modelo v3.0). Afecta a: bd-020 (normas fiscales), bd-040 (ADR "Smart Tax como caja"), bd-080 (cajas), bd-090 (flujos fiscales), ECO-020 (streams `biedata.invoices.*`) |
| **Resolución VALIDADA — dictado del arquitecto (2026-06-10), doctrina D9** | (1) **biedata es una caja cerrada**: solo actualiza las bases de datos a través del consumo y emisión de datos; no hospeda los diálogos API HTTP exteriores de las aplicaciones. (2) La contradicción "¿cómo haría biedata para consumir y emitir API HTTP exterior?" se resuelve NO centralizando: **cada aplicación que las leyes y normas de los estados regulan se hace cargo de su propia comunicación API HTTP con el exterior** — la excepción a "cero HTTP" es exclusivamente regulatoria, jamás de conveniencia. (3) Caso facturación: **btax** rompe la regla de cero HTTP porque la normativa lo exige; btax obtiene su CUF y realiza sus tareas de actualización de datos. biedata no puede repetir esas responsabilidades. (4) El razonamiento por jerarquía documental que proponía "btax como SIF" coincide en la dirección, pero el fundamento canónico es el regulatorio dictado aquí. El ADR V8 "Smart Tax como caja WASM" se registra en bd-040 como SUPERSEDIDO |
| Lo que queda en precisión | El tratamiento exacto de los datos que llegan a btax por su API y su actualización en el stack ("alto, no es tan fácil" — arquitecto): preguntas Q-01…Q-05 en §7.2. Hasta su respuesta, los documentos finales afirman D9 y NO detallan el flujo btax↔stack |
| Documentos alcanzados | ECO-000 §2/§4/§5/§9 · ECO-010 §3/§5/§9/§11 (ya actualizados en v1.2) · futuros: ECO-020 (streams `biedata.invoices.*` — ¿subsisten?, ver Q-04), bd-020, bd-040, bd-080, bd-090 |
| Estado | **VALIDADO** |

### 7.2 Preguntas Q-01…Q-05 — RESPONDIDAS por el arquitecto (2026-06-10) y validadas (D7)

| ID | Respuesta del arquitecto (canónica) | Validación corpus + web |
|---|---|---|
| **Q-01** | La aplicación (btax como ejemplo) **solo guarda en SU propia base de datos**. bKernel escucha por WAL y organiza la actualización de las otras bases de datos del ecosistema. Esto es lo que respalda el **cero invasivo**: todas las aplicaciones trabajan en su propio entorno y universo; el WAL se encarga de la actualización en el ecosistema SBOS. (La ejecución material de esas actualizaciones sigue siendo de biedata conforme D1/D2: bKernel decide y estructura la intención, biedata escribe con `origin='biedata'`) | **Corpus:** Master §02.2 "Principio de Cero Invasión" + F-01 ("nunca modifica apps"), F-02, F-08; HUMAN-DOC §5 ("bKernel puede integrarse con cualquier aplicación sin modificarla… sin que sepa que bKernel existe"); acoplamiento §13 ("Todo lo que el subproyecto escribe en PostgreSQL llega a bKernel. No hay que hacer nada especial") y §31 ("Cero invasión"). **Web (2026-06-10):** el CDC log-based es el estándar empresarial NO intrusivo — lee el log transaccional que la BD ya genera, sin tocar la aplicación (Striim, IBM, Google Cloud, Qlik); el patrón *database-per-service* (microservices.io, C. Richardson) prescribe exactamente esto: cada servicio es dueño exclusivo de su BD, nadie accede directo a la BD ajena, la sincronización es por eventos |
| **Q-02** | **Sí — esa es la razón de existir de bKernel**: debe escuchar TODAS las bases de datos (100, 5.000 o más) y organizar la actualización de las demás, con sus métodos automáticos y manuales de relación de datos | **Corpus:** doc 06-AUTOMATICO-VS-MANUAL íntegro (94% automático en operación con 100+ BDs; onboarding declarativo por ficha — la ficha se escribe UNA vez y sirve a todos los tenants; las 5 decisiones que nunca se automatizan); Master C-01…C-06 (capacidades). **Web:** validado junto a Q-01 (CDC sobre toda fuente + eventos) |
| **Q-03 / Q-04** | **Pregunta mal planteada — corrección de enfoque del arquitecto:** la facturación es tema de OTRO proyecto. Esta documentación se concentra en bKernel, biedata y el bos. Las aplicaciones (btax, Tryton, cualquiera) son **VARIABLES, no constantes**: hoy existe btax, mañana otro sistema de facturación. bKernel/biedata/bos NO conocen las aplicaciones ni las bases de datos; btax se usó SOLO para orientar dónde se usan las API REST de contacto con el exterior (D9). Ninguna aplicación determina el funcionamiento de bKernel ni de biedata | **Corpus:** F-04 ("reglas declarativas — nunca hardcodear destinos: extensibilidad infinita sin recompilar"); patrón motor genérico + conocimiento declarativo (fichas) en los tres daemons (BIEDATA-02 §1); doc 06 ("la ficha se escribe UNA SOLA VEZ"). Consecuencia documental: **regla de redacción 11** en ECO-000 §10 |
| **Q-05** | **"No se sabe, porque las aplicaciones no están determinadas."** Si se supieran las aplicaciones y los enlaces entre bases de datos, se harían directamente y bKernel/biedata no necesitarían existir. **Las aplicaciones son una variable en el tiempo** — y eso está formulado en los documentos | **Corpus:** misma base que Q-03/Q-04; la genericidad ante un conjunto abierto de fuentes/destinos es la premisa de diseño de ambos daemons. Esta respuesta cierra el alcance: los documentos finales NO enumeran aplicaciones como alcance — describen mecanismos declarativos para cualquier aplicación |

**Doctrina resultante — D10 (registrada en ECO-000 §5):** cero invasión + aplicaciones
como variables. Reglas operativas para todo redactor: (1) toda app escribe solo en su
propia BD y no se modifica jamás; (2) toda BD del stack es fuente CDC de bKernel;
(3) ningún nombre de aplicación es normativo en las series — solo ejemplo ilustrativo de
un patrón; las constantes son los daemons, los contratos ECO y los mecanismos
declarativos.

**Procedimiento para registrar un conflicto nuevo** (obligatorio para todo agente):
añadir fila con ID `C-17+` o `Q-NN`, estado `PROPUESTO`, los documentos en disputa, la
evidencia y la resolución propuesta con respaldo (D7). El contenido en disputa NO se
redacta en ningún documento final hasta que el arquitecto lo mueva a `VALIDADO`.

---

## 8. Criterios de completitud de este documento

Este documento, por ser vivo, está "completo" cuando en todo momento cumple:

- [x] Tablero global (§2) consistente con la matriz (§3): 24 REDACTADOS + 41 PENDIENTES = 65 (12+28+25); conteo INC-01 reconciliado y documentado.
- [x] Cada documento entregado tiene fecha y nota de alcance en §3.
- [x] El registro de hitos (§5) refleja la última entrega.
- [x] La trazabilidad de absorción (§6) cubre todas las fuentes integradas en la entrega.
- [x] §7 refleja fielmente el estado real: C-17 VALIDADO (D9) y Q-01…Q-05 RESPONDIDAS con su validación corpus+web documentada (D10).
- [x] La observación OBS-L1-01, el dictado D9 y la regla de estabilidad de nombres quedaron registrados en §3 y §5.
- [x] Estado del DOC-CREATE-04 origen: absorbido y marcado como archivo de Fase 0.
- [ ] Validación del arquitecto de la entrega del Lote 1 (mueve ECO-000/001/010 a VALIDADO y autoriza el Lote 2).

---

*BOS-ECO-001 v1.4 · 2026-06-10 · Documento vivo — actualizar en CADA entrega. El nombre del archivo es estable: la versión vive solo aquí.*
*Gobierno y doctrina: → BOS-ECO-000. Próximo lote: ECO-020 · ECO-030.*
