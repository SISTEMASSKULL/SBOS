# Auditoría del Script tmux — Fábrica ORQUESTA
**Fecha:** 2026-07-02
**Archivo oficial:** `/opt/skull/orquestador/proyectos/fabrica/scripts/tmux-fabrica.sh`
**Autor:** Bibliotecario SBOS
**Propósito:** Diagnóstico del estado real del script de lanzamiento de la fábrica.
Base para el plan de corrección integral.

**ESTADO:** Reorganización del grid completada el 2026-07-02. Ver sección 9 — Cambios aplicados.

---

## 1. Descripción del script

Script Bash de 475 líneas que levanta la sesión tmux completa de la fábrica SBOS.
Gestiona 12 agentes simultáneos con un sistema de visibilidad de 6 panes y 6 ocultos.

### Capacidades implementadas

| Comando | Función |
|---------|---------|
| `./tmux-fabrica.sh` | Crear sesión y entrar (o attach si ya existe) |
| `./tmux-fabrica.sh attach` | Entrar a sesión existente sin recrear |
| `./tmux-fabrica.sh stop` | Detener coordinador :8095 y matar sesión |
| `./tmux-fabrica.sh new` | Destruir y recrear desde cero |
| `./tmux-fabrica.sh swap` | Mostrar qué agente está en slot 5 |
| `./tmux-fabrica.sh swap <agente>` | Traer un agente oculto al slot 5 |

---

## 2. Grid de 12 agentes

### Grid completo (4 columnas × 3 filas) — POST-REORGANIZACIÓN 2026-07-02

```
┌──────────────┬──────────────┬──────────┬──────────┐
│   revisor    │  testeador   │ biedata  │ bkernel  │  fila 0
├──────────────┼──────────────┼──────────┼──────────┤
│     bos      │    bauth     │   btax   │ bsearch  │  fila 1
├──────────────┼──────────────┼──────────┼──────────┤
│    biblio    │ coordinador  │  brate   │   bcms   │  fila 2
└──────────────┴──────────────┴──────────┴──────────┘
```

**Cambios respecto al grid anterior:**
- `bos-t` → `revisor` (slot 0) — nombre formal para el Revisor de Código
- `bos-r` → `testeador` (slot 1) — nombre formal para el Testeador Integral
- `bpay` eliminado del grid — no tiene trabajo real asignado aún
- `bkernel` movido a slot 7 (oculto) — reemplaza a bpay
- `bkernel` → `coordinador` en slot 5 (visible fijo) — coordinador vuelve al grid

### Vista visible (6 panes — 2 columnas × 3 filas)

```
┌──────────────┬──────────────┐
│  0:revisor   │ 1:testeador  │  fila 0  — FIJOS (nunca se swapean)
├──────────────┼──────────────┤
│    2:bos     │   3:bauth    │  fila 1  — FIJOS
├──────────────┼──────────────┤
│  4:biblio    │5:coordinador │  fila 2  — slot 4 fijo / slot 5 = zona de intercambio
└──────────────┴──────────────┘
```

### Agentes ocultos (en ventanas tmp-*)

| Slot | Agente | Ventana | Directorio de trabajo |
|------|--------|---------|----------------------|
| 6 | `biedata` | `tmp-biedata` | `BiedataAgent/src` |
| 7 | `bkernel` | `tmp-bkernel` | `BkernelAgent` |
| 8 | `btax` | `tmp-btax` | `BtaxAgent/src` |
| 9 | `bsearch` | `tmp-bsearch` | `BintelligenceAgent/src` |
| 10 | `brate` | `tmp-brate` | `BrateAgent/src` |
| 11 | `bcms` | `tmp-bcms` | `BcmsAgent/src` |

---

## 3. Identidad y prompt de cada agente

### Agentes visibles fijos — POST-REORGANIZACIÓN 2026-07-02

| Agente | Slot | Modelo | Directorio | Prompt de identidad |
|--------|------|--------|-----------|---------------------|
| `revisor` | 0 | `claude` | `$SBOS` | Revisor de Código. Calidad arquitectónica de todos los daemons: documentación, modularización, SOLID, Clean Architecture, OWASP, ISO 27001. Coordina con el Testeador. |
| `testeador` | 1 | `claude` | `$SBOS` | Testeador Integral de SBOS. Valida software contra VPS real con BD poblada. Registra resultados. No testea mocks, testea realidad. |
| `bos` | 2 | `claude` | `BosAgent/src` | Core del BOS + enlace con bauth para el ctx_id. Sin ctx_id no hay contexto. Gestiona contratos BOS↔BAUTH (BOS-BAUTH-CONTRATOS.md). |
| `bauth` | 3 | `claude_ds` | `BauthAgent/src` | Daemon IAM. Autenticación, sesiones, privilegios, emisión del ctx_id. Keycloak 26.x + SPIs + BitMask 64-bit. Gestiona contratos BOS↔BAUTH. |
| `biblio` | 4 | `claude_ds` | `InfraAgent` | Bibliotecario. Custodia y organiza documentación: BOS_V8, CLAUDE.md, fichas YAML. NO coordina tareas ni gestiona el grafo — eso es el coordinador. |
| `coordinador` | 5 | `claude_ds` | `compositor-agent` | Coordinador de la Fábrica. Gestiona el grafo de tareas en SKDATA vía JSON-RPC :8095. Destraba bloqueos. Puente entre desarrolladores y plan de trabajo. |

### Agentes ocultos

| Agente | Slot | Modelo | Prompt de identidad |
|--------|------|--------|---------------------|
| `biedata` | 6 | `claude_ds` | Daemon de integración de datos externos. Único autorizado para llamadas HTTP externas. Alimenta a btax, brate y bsearch. |
| `bkernel` | 7 | `claude_ds` | Kernel de datos. Escucha WAL de PostgreSQL vía CDC y publica eventos en Redis Streams. Sin HTTP, sin API REST. |
| `btax` | 8 | `claude_ds` | Daemon de facturación electrónica Bolivia/SIN. Depende de biedata. |
| `bsearch` | 9 | `claude_ds` | Motor de búsqueda. Resultados filtrados por ctx_id del solicitante. |
| `brate` | 10 | `claude_ds` | Administrador de tipos de cambio del mundo. Mantiene colección actualizada. |
| `bcms` | 11 | `claude_ds` | CMS corporativo multi-tenant gobernado por ctx_id. |

---

## 4. Arquitectura técnica del script

### Sección 1 — Helpers del Coordinador JSON-RPC

```bash
coord_ready()   # verifica si :8095 responde
coord_rpc()     # ejecuta un método JSON-RPC y formatea la respuesta
```

### Sección 2 — Helpers de comunicación entre panes

```bash
agente_enviar(pane, msg)   # send-keys + Enter garantizado
agente_broadcast(msg, skip) # envía a todos los panes excepto skip
```

### Sección 3 — Control de sesión (argumentos CLI)

Maneja los 5 subcomandos: `attach`, `stop`, `new`, `swap [agente]`.

### Sección 4 — Pre-vuelo

1. Inicia el Coordinador JSON-RPC :8095 vía `make coordinador-start`
2. Verifica SKDATA: `SELECT COUNT(*) FROM trazas.tarea_coordinada WHERE estado NOT IN ('completada','cancelada')`

### Sección 5 — Construcción del grid 4×3

**Problema resuelto (FIX de orden visual):**
tmux construye panes en orden column-major al hacer splits horizontales primero.
Al aplicar `tiled` después de los `break-pane`, el orden visual resulta incorrecto.

**Solución:** 3 swaps correctores ANTES de los `break-pane`:
```
swap 1: bos-r  ↔ bos
swap 2: bos    ↔ biblio
swap 3: bauth  ↔ biblio
```
Resultado: orden interno de tmux = orden visual row-major esperado.

### Sección 6 — Ratón y copia de texto

Mouse activado. Copia a clipboard vía `clip.exe` (WSL) o `xclip`.

### Sección 6b — Clic en status bar → swap automático

```bash
tmux bind-key -T root MouseDown1Status run-shell -t = \
    "wn='#{window_name}'; if [ \"$wn\" = fabrica ]; then
       tmux select-window -t \"$wn\"
     else
       ag=\"${wn#tmp-}\"; '$FABRICA_SH' swap \"$ag\"
     fi"
```
Clic en `tmp-biedata` en la barra inferior → ejecuta `tmux-fabrica.sh swap biedata`.

### Sección 7 — Estilo de bordes y títulos

```
pane-border-format: #{@slot}:#{@agente}
pane-border-lines: double
pane-border-style: fg=cyan / pane activo: fg=brightgreen,bold
```

### Sección 8 — Asignación de @slot y @agente

Propiedades de pane (`-p`) fijas e independientes del `pane_index`.
`pane_index` cambia con cada swap; `@slot` y `@agente` no.

### Sección 9 — Comandos de arranque

Cada pane recibe `cd <directorio> && claude` o `claude_ds`.
Panes visibles usan `send-keys ... C-m`. Panes ocultos usan `agente_enviar`.

### Sección 10 — Ocultamiento de columnas 2 y 3

Los 6 panes ocultos se extraen de la ventana principal con `break-pane -d -n tmp-<agente>`.
Orden de ocultamiento: de mayor a menor slot para no perturbar referencias.

### Sección 11 — Prompts de identidad inicial

Cada agente recibe su prompt de rol vía `send-keys` o `agente_enviar`.
Foco final en `biblio` (slot 4) al abrir la sesión.

---

## 5. Mecanismo de swap — cómo funciona

```
Estado antes:
  fabrica: [bos-t][bos-r][bos][bauth][biblio][bkernel=slot5]
  tmp-biedata: [biedata]

./tmux-fabrica.sh swap biedata

PASO 1: join-pane — trae biedata al final de fabrica
  fabrica: [bos-t][bos-r][bos][bauth][biblio][bkernel][biedata]

PASO 2: swap-pane — intercambia biedata con el pane en slot 5
  fabrica: [bos-t][bos-r][bos][bauth][biblio][biedata][bkernel]

PASO 3: break-pane — saca bkernel a una ventana oculta
  fabrica: [bos-t][bos-r][bos][bauth][biblio][biedata=slot5]
  tmp-bkernel: [bkernel]

PASO 4: restaurar layout exacto pre-swap
PASO 5: actualizar @slot del pane que entró → "5"

Estado después:
  fabrica: [bos-t][bos-r][bos][bauth][biblio][biedata=slot5]
  tmp-bkernel: [bkernel]
```

---

## 6. Problemas y discrepancias detectadas

### PROBLEMA-01 — `biblio` tenía responsabilidades del agente `coordinador` ✅ RESUELTO

**El prompt de biblio en el script original decía:**
> "coordino entre agentes, administro el grafo de tareas en SKDATA y evalúo la calidad de cada agente"

**Resolución (2026-07-02):** El `coordinador` fue restituido en el slot 5 (visible fijo). `biblio` recuperó su rol exclusivo de custodio documental. El prompt de biblio fue corregido para eliminar las responsabilidades de coordinación.

### PROBLEMA-02 — Agentes `bos-t`/`bos-r` sin CLAUDE.md ✅ RESUELTO (nombres)

Los nombres improvisados `bos-t` y `bos-r` fueron reemplazados por roles formales:
- `bos-t` → **`revisor`** (Revisor de Código — slot 0)
- `bos-r` → **`testeador`** (Testeador Integral — slot 1)

**Pendiente:** Crear CLAUDE.md propio para `revisor` y `testeador` (Fase 4 del plan de acción).

| Agente | CLAUDE.md | Estado |
|--------|:---------:|--------|
| `revisor` | ❌ | Pendiente Fase 4 |
| `testeador` | ❌ | Pendiente Fase 4 |
| `btax` | ❌ | Pendiente — daemon futuro |
| `brate` | ❌ | Pendiente — daemon futuro |
| `bcms` | ❌ | Pendiente — daemon futuro |

### PROBLEMA-03 — Inconsistencia en el uso de `agente_enviar` ✅ RESUELTO

Todos los panes (visibles y ocultos) en la Sección 9 usan `agente_enviar`. Consistencia total.

### PROBLEMA-04 — El Coordinador :8095 corría sin agente responsable ✅ RESUELTO

El `coordinador` fue restituido en el slot 5 como agente visible fijo con directorio `compositor-agent`. Es el dueño formal del servidor JSON-RPC :8095.

### PROBLEMA-05 — `tmux2.sh` en paralelo sin rol claro — PENDIENTE

Existe `scripts/tmux2.sh` (927 líneas) con el mismo grid y base que `tmux-fabrica.sh`. Decisión pendiente: archivar en `scripts/_archivo/` o revisar si tiene funcionalidad única a preservar.

---

## 7. Lo que funciona bien

| Componente | Estado |
|-----------|--------|
| Construcción del grid 4×3 con fix de orden visual | ✅ Correcto |
| Sistema de swap slot 5 (join→swap→break→restore) | ✅ Correcto |
| `@agente` y `@slot` independientes de pane_index | ✅ Correcto |
| Clic en status bar → swap automático | ✅ Funciona |
| `automatic-rename off` en todas las ventanas | ✅ Correcto (evita corrupción tmp-* → bash) |
| Pre-vuelo: coordinador :8095 + verificación SKDATA | ✅ Correcto |
| Subcomandos CLI (attach/stop/new/swap) | ✅ Completos |
| Estilo visual con `@slot:@agente` en bordes | ✅ Correcto |
| `get_pid_by_agente()` busca por nombre, no por índice | ✅ Robusto |
| Mouse + copia a clipboard multiplataforma | ✅ Funciona |

---

## 8. Resumen ejecutivo

**¿El script funciona técnicamente?**
Sí. El grid, el swap, el clic en status bar, el arranque del coordinador y la asignación de identidades funcionan correctamente.

**¿El script está alineado con la documentación del SBOS? (estado post-reorganización 2026-07-02)**
Sí, con los problemas 1-4 resueltos. Pendientes menores:
- CLAUDE.md de `revisor` y `testeador` (Fase 4 del plan de acción)
- Decisión sobre `tmux2.sh` (PROBLEMA-05)
- CLAUDE.md de daemons futuros (`btax`, `brate`, `bcms`)

---

## 9. Cambios aplicados — 2026-07-02

Reescritura completa de `tmux-fabrica.sh` con los siguientes cambios:

| Sección | Cambio |
|---------|--------|
| Header (líneas 7-50) | Grid actualizado: revisor/testeador/bkernel/coordinador |
| Sección 3 — AGENTES_OCULTOS | `bpay` → `bkernel` en lista de ocultos |
| Sección 3 — validador swap | Agentes válidos actualizados |
| Sección 5b — @agente | C0R0=`revisor`, C1R0=`testeador`, C3R0=`bkernel`, C1R2=`coordinador` |
| Sección 5c — swaps correctores | `bos-r→testeador`, resultado: `revisor·testeador / bos·bauth / biblio·coordinador` |
| Sección 8 — @slot | `revisor`=0, `testeador`=1, `coordinador`=5, C3R0(bkernel)=7 |
| Sección 9 — arranque | `revisor`→`$SBOS`, `testeador`→`$SBOS`, `coordinador`→`$COMPOSITOR`, `bkernel`→`BkernelAgent` |
| Sección 9 — unificación | Todos los panes usan `agente_enviar` (incluidos los visibles) |
| Sección 10 — ocultar | C3R0=`bkernel` slot 7 (era bpay) |
| Sección 11 — prompts | Nuevos prompts para revisor, testeador, coordinador; biblio sin responsabilidades de coordinación; bkernel como oculto |
