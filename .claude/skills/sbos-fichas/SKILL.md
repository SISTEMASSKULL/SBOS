---
name: sbos-fichas
description: >
  Trabajar con las fichas de infraestructura y los servidores lógicos del proyecto SBOS.
  Úsala para declarar, ubicar o revisar una ficha: en qué servidor lógico (S00–S15) vive,
  su anatomía (manifest.yml + task_catalog.sh + resources/ + PROPOSITO.md), su puerto
  (SBOS-050 §12.3) y cómo consultar a un daemon hermano (bos, bkernel…) por su contrato.
---

# Skill — Fichas y Servidores Lógicos de SBOS

**Norma del proyecto (léela primero):** `servers/servers.yml`.
**Catálogo por servidor:** `servers/SNN-<nombre>/PROPOSITO.md`.
**Definición de apps:** `context/IAM_Enterprise_Stack_v5.md` · **Puertos:** `context/BOS_V8/BOS_V8_SBOS-050-PORT-CATALOG.md`.

## Reglas duras
- Una sola BD `SBOS_db`; cada microservicio = un schema. `servers/` es **público en lectura, soberano en escritura**.
- Cada ficha vive en `servers/SNN-<servidor>/<app>/` con `manifest.yml` + `task_catalog.sh` + `resources/` + **`PROPOSITO.md`** (sin él, se rechaza).
- Nombre de ficha = nombre canónico del catálogo, **no arbitrario**. La versión va en Git, no en el nombre.
- El **motor** (instalar/observar) es de `bos`; `task_catalog.sh` solo funciones `<app>_<verbo>`.

## Declarar una ficha
1. Ubica el servidor lógico (SNN) correcto en `servers/servers.yml → servidores_logicos`.
2. Revisa el `PROPOSITO.md` de ese servidor: ¿la app ya existe (✅) o falta (⬜)?
3. Crea `servers/SNN-<servidor>/<app>/` con los 4 archivos. Puerto `containerPort→ClusterIP` de SBOS-050 §12.3.

## Consultar a un hermano (read-only)
Un daemon consulta a otro por su **contrato** (su `PROPOSITO.md`, `manifest.yml` o JSON-RPC), nunca su
código interno. La ruta del hermano se resuelve por `paths.yml` (`fabrica_core.rutas.ruta_hermano`).
**Nunca escribas en la ficha de otro daemon** (ORQUESTA-051: write soberano, read por contrato).
