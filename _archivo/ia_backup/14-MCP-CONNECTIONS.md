# Conexiones MCP

**Generado por:** Compositor S-29 (reprocesamiento SBOS)
**Fecha:** 2026-05-18
**Proyecto:** SBOS
**Fuentes:** SBOS-012-MCP (v6)
**Jerarquia aplicada:** bauth > v6 > v5 > humano

## MCP del proyecto

| Servidor MCP | Proposito | Operaciones permitidas |
|---|---|---|
| skdata-biblioteca | Conexion a SKDATA desde Claude Code | Consultas SQL, lectura de esquemas |
| GitHub | Operaciones sobre repositorios | PR, issues, commits |
| PostgreSQL SBOS | Acceso a bases de datos del proyecto | Lectura de esquemas, WAL slots |

### MCP skdata-biblioteca
- **Tipo:** database (PostgreSQL)
- **Alcance:** Lectura completa de SKDATA. Escritura solo en tablas de trazas y proyectos.
- **Autenticacion:** via ~/.pgpass
- **Restricciones:** Solo queries preparadas. No DROP, TRUNCATE o ALTER via MCP.
- **Estado:** CONECTADO

## Protocolo de identidad bAuth (fuera de MCP -- Unix socket nativo)

El socket `/run/bos/bauth.sock` NO es un MCP -- es un socket Unix nativo de Go:
- Framing: 4 bytes big-endian length + JSON UTF-8
- Protocolo: AuthQuery/AuthResponse con campos request_id, user_id, query_type
- Latencia: < 5ms con cache Redis hit, < 8ms cache miss
- Unico cliente autorizado: bhnexus (nunca banexus directo)

## Lo que NO esta disponible como MCP

| Capacidad | Estado | Alternativa |
|---|---|---|
| Acceso directo a sistema de archivos | No hay MCP filesystem | Herramientas Bash del agente |
| Ejecucion remota en clusters K8s | No via MCP | kubectl via SSH/podman |
| APIs externas (SIAT, AFIP, SAT) | No via MCP | biedata (daemon Rust) |
