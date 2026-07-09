# Contratos Inter-Daemon — SBOS
**Versión:** 1.0 · **Fecha:** 2026-07-05
**Propósito:** Carpeta de contratos bilaterales entre microservicios del ecosistema SBOS.
Los contratos definen qué espera cada daemon de sus hermanos (métodos JSON-RPC, eventos, sockets).

---

## Reglas

1. **Un contrato = un archivo `<DAEMON-A>-<DAEMON-B>-CONTRATOS.md`** (orden alfabético).
2. **Nivel proyecto** — ningún contrato reside dentro del directorio de un solo daemon.
3. **Bilateral** — define obligaciones en AMBAS direcciones (A→B y B→A).
4. **Todo cambio requiere PR + revisión de ambas partes** + aprobación del Bibliotecario.
5. **Versión semántica** en el encabezado del documento.

---

## Contratos activos

| Contrato | Partes | Versión | Estado |
|----------|--------|---------|--------|
| `BOS-BAUTH-CONTRATOS.md` | BOS ↔ bAuth | 1.0 | BORRADOR |
| `BAUTH-BNOTIFY-CONTRATOS.md` | bAuth ↔ bNotify | 1.0.0 | BORRADOR |

---

## Plantilla

Ver `BOS-BAUTH-CONTRATOS.md` como referencia de estructura:
- TABLA MAESTRA DE CONTRATOS
- Sección A → B (C-XXX-NNN)
- Sección B → A (C-YYY-NNN)
- HISTORIAL DE ESTADOS
- Protocolo de modificación

---
*Custodiado por: Bibliotecario · Ubicación: SBOS/context/contracts/*
