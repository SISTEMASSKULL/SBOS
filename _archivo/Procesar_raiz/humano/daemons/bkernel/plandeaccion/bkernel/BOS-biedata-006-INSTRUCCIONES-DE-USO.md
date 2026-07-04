# BOS-biedata-006 — INSTRUCCIONES DE USO (serie y proyecto biedata)

## 0. Metadatos
| **Documento** | BOS-biedata-006 · **Versión** 1.0 · **Estado** VIGENTE—REDACTADO · **Fecha** 2026-06-10 |
|---|---|
| **Serie** | BOS-biedata — complementa → ECO-006 (manda) |

## 1. Si vas a TRABAJAR en biedata
1) ECO-003 §2 + bd-003. 2) Tarea: bd-160. 3) Skills: ECO-007 + bd-007.
4) Cierre: bd-004/bd-005 + ECO-004/005.

## 2. Si vas a ENTENDER biedata
Humano: COMPRENSIÓN de 010 (Tres Responsabilidades) → 090 §1 (una llamada de punta a punta)
→ 060 (por qué "el RPC siempre hace algo"). Integrador/cliente: 060 → `biedata.describe`
en vivo → 090. Auditor: 100 (auditoría) → 110 → 130.

## 3. Recordatorios duros del proyecto
- Caja cerrada (D9): solo consumo y emisión de DATOS; nada de diálogos API exteriores
  regulados (son de cada aplicación obligada).
- 100% de las escrituras de negocio con `origin='biedata'` (D1/F3); biedata_db jamás
  guarda negocio (F2).
- La validación va SIEMPRE antes (F8): la BD nunca se toca con datos inválidos.
- Apps y BDs = variables (D10): la inteligencia vive en fichas y cajas, no en el binario (F5/F10).
- El contrato con bKernel vive SOLO en ECO-020.

## Criterios de completitud
- [x] Circuitos y recordatorios sin duplicar SSOT. · [ ] Validación.

---
*bd-006 v1.0 · maestro: → ECO-006*
