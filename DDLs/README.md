# DDLs/ — Base de datos del proyecto SBOS

Punto único de toda la DDL y los seeds del proyecto. La **doctrina `ddls.yml`**
es la fuente de verdad (léela primero). Todo agente la respeta a rajatabla —
fin del desorden de "cada quien nombra y crea DDLs como se le ocurre".

## Reglas duras (de `ddls.yml`)

1. **Una sola base de datos: `SBOS_db`.** Cada microservicio = un *schema* dentro
   de ella. Prohibido crear una base por microservicio.
2. **Ciclo de vida dev/prod.** En **desarrollo** se corrige la *misma* DDL in situ
   (cero `ALTER TABLE`, para no dispersar la estructura). En **producción** la DDL
   se **congela** y todo cambio es una migración incremental nueva.
3. **Convención de nombres** (Flyway + schema-per-service):
   ```
   migrations/   <servicio>_<NN>__<descripcion>.sql   ej: bos_01__control_plane.sql
   seeds/        <servicio>_<NN>__<tabla>.sql          ej: bglobal_01__global_country.sql
   ```
   `<servicio>` = el schema real (bglobal, bos, bauth, bcalendar, btax…). `NN` =
   orden local dentro del servicio. `__` separa prefijo de objeto.
4. **La versión vive en Git, nunca en el nombre.** Prohibidos `_v2`, `_final`,
   `_clean`, etc. Un objeto = un archivo estable.

## Estructura
```
DDLs/
├── ddls.yml        ← DOCTRINA (léela primero)
├── inicializar_sbos_db.sh         ← orquestador ÚNICO e idempotente (DDLs → catálogos → seeds)
├── README.md
├── migrations/     ← DDLs de estructura
│   ├── sbos_00__esquema_base.sql   ← NÚCLEO UNIDO (bglobal+bcalendar+bauth, ver abajo)
│   ├── bos_01__control_plane.sql   ← complementos por servicio
│   ├── bauth_10/20/30__*.sql
│   └── <servicio>_00__referencia.sql ← PUNTEROS de lectura (no crean nada)
├── seeds/          ← seeds (datos): <servicio>_NN__<tabla>.sql + catálogos bauth_fw_NN__*
├── resources/      ← NO se cargan: .json de extracción + deploy_production.sh
├── _obsoletos/     ← archivos superados (main.sql, versiones viejas; no se borran)
└── db_backup.tar.gz ← respaldo original comprimido (169 archivos)
```

## Núcleo unido — `sbos_00__esquema_base.sql`
Los schemas **bglobal, bcalendar y bauth** viven juntos en un solo archivo y **no se
separan**. Motivo: tienen **FK circulares** entre sí (`bcalendar.cal_*` y `bglobal.menu_*`
→ `bauth.idn_tenant`; `bauth.*` → `bglobal.global_country`). Ningún orden "un schema
completo, luego el siguiente" satisface el ciclo — separarlo produjo **60 errores**
(verificado). El orden entrelazado del archivo unido sí resuelve las FK. Para leerlo sin
abrirlo, los punteros `bglobal_00__referencia.sql` y `bcalendar_00__referencia.sql`
documentan sus tablas, líneas, columnas, índices y ejemplos (solo comentarios).

## Cómo se carga (idempotente)
```bash
SBOS_DSN="postgresql://user@host:5432/SBOS_db" ./inicializar_sbos_db.sh
# opcionales: --solo-ddl · --solo-catalogos · --solo-seeds
```
Re-ejecutable sin romper una BD existente: DDLs con `IF NOT EXISTS`; los seeds se
recargan por refresh (TRUNCATE + recarga) con la validación de FK desactivada
durante la fase de datos. Triple carga = mismas filas, 0 errores.

## Orden de carga
El orden **entre servicios** vive en `ddls.yml → orden_de_servicios`
(`bglobal → bos → bauth → bcalendar`). Dentro de cada servicio, por el `NN`.
`inicializar_sbos_db.sh` es el único que orquesta: ninguna DDL/seed llama a otra.

## Custodia
El **Bibliotecario** custodia esta estructura y rechaza lo que no cumpla la
convención. El **Revisor** audita la idempotencia. Todo cambio de DDL/seed
requiere **aprobación del humano** antes de aplicar o commitear.
