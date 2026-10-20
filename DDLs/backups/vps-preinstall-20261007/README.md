# Respaldo pre-reinstalación VPS — 2026-10-07

Tomado antes de la reinstalación de Linux en la VPS de prueba (13.140.128.230).

## Archivos

| Archivo | Tamaño | Descripción |
|---------|--------|-------------|
| `SBOSDB_backup_20261007.dump` | 4.4 MB | pg_dump completo (schema + datos) de SBOSDB en formato custom (-Fc) |
| `SBOSDB_data_only_20261007.dump` | 1.6 MB | Solo datos de schemas bauth + bglobal + bos (-Fc) |
| `keycloak_db_backup_20261007.dump` | 375 KB | pg_dump de keycloak_db (configuración de realm skull) |

## Estado de la VPS al momento del backup

- **K8s:** v1.32.13, 110 días activo, nodo Ready
- **PostgreSQL:** 15432 (NodePort), 57 bases de datos, SBOSDB oficial
- **SBOSDB:** 282 tablas (bauth 242 + bglobal 8 + bcalendar 9 + bos 23)
- **Vault:** inmem (datos NO persistidos en disco), token real desconocido
- **bos-install:** sincronizado con GitHub (sin commits pendientes) ✅
- **bos.toml:** NO EXISTE — BOS daemon nunca fue configurado correctamente

## Qué está cubierto por los seeds en git

Todos los datos críticos de SBOSDB son reproducibles desde `DDLs/seeds/`:
- `bauth_T*`: seeds bAuth completos ✅
- `bglobal_T060`: menu_context (282 filas) ✅
- `bglobal_T061`: menu_item (1611 filas) ✅ — nota: T061 no es idempotente, ejecutar UNA vez
- `bcalendar_T012..T015`: calendario y holidays ✅

Este dump es un respaldo de seguridad adicional, NO el mecanismo de restauración principal.

## Restauración (si se necesita)

```bash
# 1. Crear la BD primero (vía BOS o manual)
createdb -U postgres SBOSDB

# 2. Restaurar schema + datos
pg_restore -U postgres -h localhost -p 5432 -d SBOSDB SBOSDB_backup_20261007.dump

# O alternativamente: aplicar DDL desde git + seeds (preferido)
psql -U postgres -d SBOSDB -f DDLs/SBOS_db_V2_DDL.sql
# luego aplicar seeds en orden numérico
```

## Problemas detectados en la VPS (para corregir en reinstalación)

1. `bos-install.toml` tiene postgres_dsn con IP incorrecta (192.168.144.132) — stale config
2. `bos-bootstrap.env` completamente vacío — wizard nunca fue ejecutado
3. `bos.toml` no existe — daemon no configurado
4. Vault usa `storage_type: inmem` (datos se pierden al reiniciar)
5. `vault-init-keys.json` tiene token incorrecto (`sbos-dev-root`)
6. `pgbackrest-backup` pods en ImagePullBackOff por 110 días (imagen no disponible)
7. `kube-state-metrics` en CrashLoopBackOff (44827 reinicios)
8. `centrifugo` en CrashLoopBackOff (28286 reinicios)
9. `minio-0` en Pending (sin PV disponible)
