# BAUTH — Errores de Inicialización
## Sesión: 2026-07-05 07:24 UTC · Agente: bauth

---

## Error 1 — 🔴 BOS-BAUTH-CONTRATOS.md INEXISTENTE

**Ruta esperada (según CLAUDE.md):**
`/opt/skull/orquestador/proyectos/desarrollo/sbos/BOS-BAUTH-CONTRATOS.md`

**Hallazgo:**
El archivo no existe. El directorio `/opt/skull/orquestador/proyectos/desarrollo/sbos/` tampoco existe.
Búsqueda global en `/opt/skull/` sin resultados.

**Impacto:**
bAuth no puede cumplir §"Contrato de Integración BOS ↔ bAuth" de su CLAUDE.md,
que exige leer este documento al iniciar sesión para ver contratos pendientes.

**Documento relacionado encontrado:**
`_archivo/Procesar_raiz/humano/daemons/bos/plandeaccion/plandeaccion/bos-repair/BOS-CONTRATOS-SBOS.md`
— pero este es unilateral (BOS → ecosistema), no bilateral (BOS ↔ bAuth).

**Acción requerida:**
Crear el documento bilateral BOS-BAUTH-CONTRATOS.md con la estructura definida en el CLAUDE.md:
- TABLA MAESTRA de contratos
- Sección BOS → bAuth (C-BOS-NNN)
- Sección bAuth → BOS (C-BAUTH-NNN)
- HISTORIAL DE ESTADOS

---

## Error 2 — 🔴 scripts/agente_enviar.sh INEXISTENTE

**Ruta esperada (según CLAUDE.md):**
`BauthAgent/scripts/agente_enviar.sh`

**Hallazgo:**
No existe ningún script `.sh` de comunicación en BauthAgent.
Búsqueda: `find BauthAgent -name "*.sh"` solo encuentra `db/build_ddl.sh` y `db/data_files/deploy_production.sh`.

**Impacto:**
bAuth no puede ejecutar el protocolo de comunicación vía tmux:
`source scripts/agente_enviar.sh && agente_enviar <pane> "<mensaje>"`

**Acción requerida:**
Crear `BauthAgent/scripts/agente_enviar.sh` con la función `agente_enviar` que envíe mensajes al pane tmux correcto.

---

## Error 3 — 🟡 python (sin versión) NO DISPONIBLE

**Comando esperado (CLAUDE.md):**
`python -m fabrica_core.memoria arranque`

**Hallazgo:**
Solo existe `python3`. `python` retorna código 127 (command not found).

**Workaround:** Usar `python3` funciona correctamente.

**Acción requerida:**
Actualizar CLAUDE.md para usar `python3` en lugar de `python`, o crear alias/symlink.

---

## Error 4 — 🟡 Coordinador: proyecto_id requiere UUID

**Métodos afectados:**
`orquesta.coordinador.status`, `get_available_tasks`, `get_graph`, etc.

**Hallazgo:**
Pasar `"proyecto_id": "sbos-bauth"` (string) causa error PostgreSQL:
`invalid input syntax for type uuid`

**Workaround:** Omitir `proyecto_id` (usa nil UUID `00000000-...` por defecto).

**Acción requerida:**
Documentar el UUID real del proyecto SBOS-bauth en CLAUDE.md para que los agentes puedan usarlo,
o modificar el coordinador para aceptar strings y resolverlos a UUID.

---

## Error 5 — 🟡 Grafo de tareas vacío

**Hallazgo:**
0 tareas activas, 0 bloqueadas, 0 disponibles, 0 agentes conectados.

**Interpretación:**
No es un error sino estado inicial de sesión fresca. No hay DAG preexistente.

---

## Resumen

| # | Severidad | Error | Bloquea |
|---|-----------|-------|---------|
| 1 | 🔴 Crítico | BOS-BAUTH-CONTRATOS.md no existe | Protocolo de arranque |
| 2 | 🔴 Crítico | agente_enviar.sh no existe | Comunicación tmux |
| 3 | 🟡 Medio | `python` → debe ser `python3` | Comando de memoria |
| 4 | 🟡 Medio | proyecto_id requiere UUID | RPC al coordinador |
| 5 | 🟢 Info | Grafo vacío | Nada (es estado inicial) |

---
*Reporte generado por bauth · 2026-07-05 07:24 UTC · Para: Bibliotecario*
