# BOS-ECO-003 — PROTOCOLO DE SESIÓN DE AGENTE

## 0. Metadatos del documento

| Campo | Valor |
|---|---|
| **Documento** | BOS-ECO-003-PROTOCOLO-SESION-AGENTE |
| **Versión** | 1.0 |
| **Estado** | VIGENTE — REDACTADO |
| **Fase asociada** | Transversal — Lote 1-G (enmienda R7) |
| **Serie** | BOS-ECO (protocolo maestro; bK-003 y bd-003 lo instancian con particularidades) |
| **Prerequisitos de lectura** | ECO-000 · ECO-002 |
| **Normas aplicables** | ISO/IEC/IEEE 15289:2019 cl. 7 (tipo *procedure*); ISO/IEC/IEEE 12207:2017 §6.3.7 (gestión de la información) |
| **Audiencia** | Agentes de IA (documentales y programadores) y humanos que operan sesiones |
| **Custodio** | Arquitecto |
| **Fecha** | 2026-06-10 |

---

## 1. Principio

Una sesión de agente es una **unidad de trabajo auditable**: se abre con contexto
verificado, ejecuta tareas atómicas trazables, y se cierra dejando el estado y el log
actualizados. **Una sesión que no actualiza ECO-004 y ECO-005 al cerrar es una sesión
inválida** — su trabajo se considera no entregado.

## 2. Protocolo de APERTURA (obligatorio, en orden)

```
A1. Leer ECO-000 (guía y doctrina D1–D10). Si ya se conoce: releer §5 (doctrina)
    y el changelog (¿cambió algo desde mi último contexto?).
A2. Leer ECO-004 (registro de estado): ¿qué está REDACTADO/VALIDADO/EN-DESARROLLO?
A3. Leer ECO-005: la ÚLTIMA entrada del log (qué hizo la sesión anterior, qué dejó
    pendiente, qué advirtió).
A4. Identificar la tarea de la sesión:
    - Si el arquitecto la dictó → esa es la tarea.
    - Si no → la siguiente tarea atómica PENDIENTE del plan (ECO-008 → bK-190/bd-160).
A5. Cargar el skill correspondiente (ECO-007 + el de la serie: bK-007 o bd-007).
A6. Leer los documentos SSOT de la tarea (el plan atómico los lista por tarea) y el
    corpus N1 COMPLETO del daemon si la tarea es de redacción (lección OBS-L1-01).
A7. Abrir la entrada de sesión en ECO-005 (ID S-NNN, fecha, agente, tarea, estado ABIERTA).
```

## 3. Protocolo de EJECUCIÓN

| Regla | Contenido |
|---|---|
| E1 | Trabajar SOLO sobre tareas atómicas del plan (o dictadas). Si la tarea no existe en el plan: registrarla primero (enmienda al plan, estado PROPUESTA si altera alcance). |
| E2 | Respetar SSOT: ningún concepto se duplica; se referencia `→ SERIE-NNN §X`. |
| E3 | Doctrina D1–D10 inviolable. Tensión detectada → conflicto PROPUESTO (§5), nunca reinterpretación. |
| E4 | Investigación web de respaldo (D7) ANTES de afirmar normas, versiones o prácticas; citarla en el documento/código. |
| E5 | Nombres de archivo estables; versiones solo en metadatos/changelog (regla del arquitecto, 2026-06-10). |
| E6 | Aplicaciones como variables (D10): jamás diseñar contra una app concreta. |
| E7 | Código: seguir el skill (ECO-007/bK-007/bd-007); cada tarea atómica termina con su criterio medible verificado y la evidencia anotada. |
| E8 | No resúmenes (P5): lo absorbido se integra completo y corregido. |

## 4. Protocolo de CIERRE (obligatorio, en orden)

```
C1. Verificar el criterio medible de cada tarea atómica tocada (el del plan).
C2. Actualizar el REGISTRO DE ESTADO: ECO-004 (global) + el de la serie tocada
    (bK-004 / bd-004): estados, fechas, evidencia.
C3. Actualizar la MEMORIA humana si hubo entrega documental (ECO-001 §2/§3/§5).
C4. Completar la entrada de sesión en ECO-005 (+ bK-005/bd-005 si aplica):
    qué se hizo, qué quedó pendiente, advertencias para la siguiente sesión,
    archivos entregados, decisiones nuevas con su fuente.
C5. Actualizar ECO-002 si nacieron rutas nuevas de navegación.
C6. Entregar al arquitecto: archivos + delta del estado + preguntas abiertas (si las hay).
```

## 5. Procedimiento de conflicto nuevo

1. Detener la redacción del punto en disputa (lo no disputado puede continuar).
2. Registrar en ECO-001 §7: ID C-NN, documentos en disputa, evidencia textual, resolución
   propuesta con respaldo D7, frontera explícita redactable/contenido.
3. Anotar en la entrada de sesión (ECO-005) y preguntar al arquitecto.
4. Solo el arquitecto mueve a VALIDADO; entonces se propaga y se registra la supersesión
   en ECO-000 §9.

## 6. Tipos de sesión y sus particularidades

| Tipo | Plan que la gobierna | Skill | Registro/log adicionales |
|---|---|---|---|
| Documental (redacción de serie) | ECO-008 + lotes (ECO-000 §7.2) | ECO-007 §B | los de la serie tocada |
| Programación bKernel | bK-190 | ECO-007 + bK-007 | bK-004 / bK-005 |
| Programación biedata | bd-160 | ECO-007 + bd-007 | bd-004 / bd-005 |
| Revisión del arquitecto | — | — | sus veredictos se registran en ECO-005 y mueven estados a VALIDADO |

## 7. Criterios de completitud de este documento

- [x] Apertura (A1–A7), ejecución (E1–E8) y cierre (C1–C6) definidos y verificables.
- [x] Procedimiento de conflicto nuevo alineado con ECO-000 §10.9.
- [x] Invalidez explícita de la sesión que no actualiza estado y log.
- [ ] Validación del arquitecto.

---
*BOS-ECO-003 v1.0 · 2026-06-10 · Instancias: → BOS-bKernel-003 · → BOS-biedata-003.*
