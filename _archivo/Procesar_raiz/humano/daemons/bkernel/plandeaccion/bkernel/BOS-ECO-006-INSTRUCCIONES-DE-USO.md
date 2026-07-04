# BOS-ECO-006 — INSTRUCCIONES DE USO DEL SISTEMA DOCUMENTAL Y DE LOS PROYECTOS

## 0. Metadatos del documento

| Campo | Valor |
|---|---|
| **Documento** | BOS-ECO-006-INSTRUCCIONES-DE-USO |
| **Versión** | 1.0 |
| **Estado** | VIGENTE — REDACTADO |
| **Serie** | BOS-ECO (instrucciones maestras; bK-006 y bd-006 instancian lo propio) |
| **Normas aplicables** | ISO/IEC/IEEE 26514:2022 (información para usuarios — orientación a tareas) |
| **Audiencia** | Ambas — humanos nuevos en el programa y agentes |
| **Custodio** | Agente documental |
| **Fecha** | 2026-06-10 |

---

## 1. Qué es esto que tienes delante

Tres proyectos hermanos documentados como cuarta generación única vigente:
**bKernel** (escucha y decide), **biedata** (ejecuta e intercambia) y los **contratos
BOS-ECO** que los unen entre sí y con el bos. 65 documentos, 3 series, gobierno operativo
por sesiones. El histórico (89+ docs) es solo fuente.

## 2. Uso según quién eres

**Arquitecto.** Tu circuito: ECO-005 (qué pasó) → ECO-004 (estado) → lo entregado → tu
veredicto mueve documentos a VALIDADO y desbloquea el siguiente lote/etapa. Tus dictados
en sesión son doctrina: el agente los registra (ECO-001 hitos + ECO-000 §5 si nace D-NN).

**Agente documental.** No empieces a escribir: ejecuta ECO-003 §2 (apertura) al pie de la
letra. Tu tarea sale del plan (ECO-008/lotes) o del dictado. Reglas duras: corpus N1
completo antes de redactar; D7 (investigación citada); P5 (no resúmenes); D10 (apps =
variables); nombres de archivo inmutables. Cierra con ECO-003 §4.

**Agente programador.** Tu mundo: ECO-007 (skill maestro) + el skill de tu daemon
(bK-007/bd-007) + el plan atómico de tu daemon (bK-190/bd-160). Trabajas tarea atómica
por tarea atómica: cada una tiene entregable, criterio medible y evidencia. No inventes
nada estructural: structs, DDL y YAML viven en los documentos SSOT.

**Operador / auditor / integrador.** Rutas en ECO-002 §3.

## 3. Las 10 reglas de oro (resumen operativo de ECO-000 §10 — el detalle manda)

1. SSOT: un concepto, un hogar; el resto referencia.
2. Doctrina D1–D10 inviolable; tensión → conflicto PROPUESTO, jamás reinterpretar.
3. Doble audiencia en todo documento (ESPECIFICACIÓN + COMPRENSIÓN).
4. Código de referencia incluido; el implementador no inventa estructura.
5. Normas con cláusula exacta verificadas por web (D7) y citadas.
6. No resúmenes: absorción completa y corregida.
7. Markdown-first; nombres de archivo inmutables; versión en metadatos.
8. Paridad de daemons; aplicaciones como variables ilustrativas.
9. Toda sesión actualiza estado (ECO-004/serie) y log (ECO-005/serie) o es inválida.
10. Solo el arquitecto valida (documentos a VALIDADO, conflictos a VALIDADO).

## 4. Operaciones frecuentes (recetas)

| Operación | Receta |
|---|---|
| Arrancar sesión nueva | ECO-003 §2 (A1–A7) |
| Saber qué sigue | ECO-004 §2 `next_actions` → ECO-008 §4 |
| Entregar un documento | metadatos §11 de ECO-000 + criterios de completitud + actualizar 001/004/005 |
| Entregar código | tarea atómica con evidencia (bK-190/bd-160) + actualizar 004/005 de la serie |
| Dudar de un dato histórico | ECO-000 §9 (jerarquía + supersesiones) → si no resuelve: conflicto §5 de ECO-003 |
| Generar .docx/.pdf | solo GENERADO desde el .md (C-12), nunca editado a mano |

## 5. Lo que está prohibido

Renombrar archivos por versión · duplicar contenido SSOT · redactar sobre un conflicto
no validado · diseñar contra una aplicación concreta (D10) · entregar sin criterio
medible verificado · cerrar sesión sin actualizar estado y log · citar normas sin
verificación web · condensar fuentes ("resumir") en documentos finales.

## 6. Criterios de completitud

- [x] Uso definido por rol (4 roles) con sus circuitos.
- [x] Reglas de oro y recetas operativas alineadas (sin duplicar) con ECO-000/003.
- [x] Prohibiciones explícitas.
- [ ] Validación del arquitecto.

---
*BOS-ECO-006 v1.0 · 2026-06-10 · Instancias: → bK-006 · → bd-006.*
