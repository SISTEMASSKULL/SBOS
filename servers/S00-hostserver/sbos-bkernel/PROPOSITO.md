# PROPOSITO — sbos-bkernel

**Ficha:** `sbos-bkernel` - **Servidor:** S00-hostserver - **Version:** 1.0.0
**Criticidad:** True - **Namespace:** - - **Tipo:** systemd
**Orden de instalacion:** 70

## Que es
bKernel CDC Daemon — Motor de Datos Soberano. Escucha WAL PostgreSQL, normaliza eventos, publica intenciones en Redis Streams. CERO puertos TCP (F-02).

## Dependencias
postgresql, redis, vault

## Bitacora
- Consolidada al catalogo canonico servers/ (doctrina servers/servers.yml). Manifest: manifest.yml.
- Cambios en esta ficha -> consulta al humano (recurso compartido, ORQUESTA-051).
