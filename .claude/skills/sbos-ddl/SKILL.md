---
name: sbos-ddl
description: >
  Trabajar con las DDLs y seeds del proyecto SBOS. Úsala para crear o renombrar una DDL/seed
  siguiendo la convención, entender el núcleo unido (sbos_00) y cargar la BD de forma idempotente.
---

# Skill — DDLs y Seeds de SBOS

**Norma (léela primero):** `DDLs/ddls.yml`. **Orquestador:** `DDLs/inicializar_sbos_db.sh`.

## Convención de nombres
- `migrations/<servicio>_NN__<descripcion>.sql` · `seeds/<servicio>_NN__<tabla>.sql`.
- `<servicio>` = schema real (bglobal, bos, bauth, bcalendar…). `NN` = orden local. `__` separa prefijo de objeto.
- **La versión vive en Git, nunca en el nombre** (prohibido `_v2`, `_final`, `_clean`).
- En **desarrollo** se edita la MISMA DDL (cero `ALTER TABLE`); en **producción** se congela.

## Núcleo unido — NO separar
`sbos_00__esquema_base.sql` contiene **bglobal + bcalendar + bauth juntos** por FK circulares
(`cal_*`/`menu_*`→`idn_tenant`; `bauth.*`→`global_country`). Separarlo rompe (60 errores).
Para leerlo sin abrirlo: los punteros `bglobal_00__referencia.sql` / `bcalendar_00__referencia.sql`.

## Cargar la BD
```bash
SBOS_DSN="postgresql://user@host:5432/SBOS_db" ./inicializar_sbos_db.sh
```
Idempotente: DDLs con `IF NOT EXISTS`, seeds por refresh (TRUNCATE+recarga, FK desactivadas en la fase de datos).
**Todo cambio de DDL/seed requiere aprobación del humano antes de aplicar/commitear.**
