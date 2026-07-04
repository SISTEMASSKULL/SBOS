# Roadmap de Desarrollo

**Generado por:** Compositor S-29 (reprocesamiento SBOS)
**Fecha:** 2026-05-18
**Proyecto:** SBOS
**Fuentes:** SBOS-014-ROADMAP (v6), PROYECTO-ESTADO.md SBOS, SKDATA sesiones S-10 a S-23
**Jerarquia aplicada:** bauth > v6 > v5 > humano

## Estado global del proyecto

| Fase | Nombre | Estado | % |
|---|---|---|---|
| Fase A | Contexto documental | COMPLETADA | 100% |
| Fase B | Arbol de agentes | COMPLETADA | 100% |
| Fase C.1 | Workspaces materializados | COMPLETADA | 100% |
| Fase C.2a | Staff + Fundacionales | COMPLETADA | 100% |
| Fase C.2b | Dominio P1 (bos-agent) | EN CONSTRUCCION | 40% |
| Fase C.3 | Certificacion de nodos | EN PROGRESO | 30% |

## Nodos del arbol SBOS

| Nodo | Perfil | Lenguaje | Estado | Codigo real |
|---|---|---|---|---|
| BosAgent | dominio | Go + Bash + Python + YAML | en-construccion | 22 Go, 376 YAML |
| BauthAgent | dominio | Go + Java (SPIs) | en-construccion | 27 Go |
| BintelligenceAgent | dominio | Go | en-construccion | 8 Go |
| BnexusAgent | dominio | Go | en-construccion | 10 Go |
| InfraAgent | dominio | YAML | en-concepcion | 8 YAML |
| BkernelAgent | dominio | Rust | en-concepcion | 0 |
| BstyleAgent | dominio | -- | en-concepcion | 0 |

## Sesiones registradas en SKDATA

12 sesiones: S-10 a S-23. Ultima sesion (S-23): "Certificacion BOS installer completada -- 18/18 fichas HEALTHY en sbos-k8s."

## Proximos entregables

| Orden | Entregable | Nodo | Dependencias |
|---|---|---|---|
| 1 | Completar bos-agent: Go internals + Bash scripts | BosAgent | Scaffold existente |
| 2 | Implementar bAuth: daemon Go + SPIs Java | BauthAgent | Schema bauth_db |
| 3 | Implementar bhnexus + banexus: WebSocket + cache | BnexusAgent | Contrato bAuth |
| 4 | bKernel Rule Engine: WAL parsing en Rust | BkernelAgent | Schema bkernel_db |
| 5 | Infra K8s: manifests + Vault + PG HA | InfraAgent | Especificacion S01-S15 |
| 6 | bCompass Route Engine | BintelligenceAgent | Contrato bKernel |

## Hitos clave

| Hito | Fecha estimada | Criterio |
|---|---|---|
| BOS installer certificado | S-23 (COMPLETADO) | 18/18 fichas HEALTHY |
| bAuth daemon operativo | Proxima sesion | Sync RolTemplate < 5s |
| 7 nodos certificados | TBD (Fase C.3) | Todos BUILD=0 + tests OK |
| MVP SBOS v0.9 | TBD | Stack completo instalable en 45 min |
