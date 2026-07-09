# ADR-003 — Estándares de Documentación del Código y Cumplimiento Normativo

**Estado:** Aceptado  
**Fecha:** Junio 2026  
**Autores:** Equipo SKULL — SBOS Architecture  
**Supersede:** N/A  
**Relacionado:** ADR-001, ADR-002, SBOS-049  
**Referenciado en:** PLAN_ACCION_BOSAGENT.md — Fase 7 (documentación continua)

---

## Por qué documentar no es opcional en SBOS

El SBOS no es un proyecto de software genérico. Es un sistema operativo empresarial soberano que:

- **Corre con privilegios root** sobre sistemas Ubuntu en producción
- **Administra clústers Kubernetes** con datos de empresas reales
- **Gestiona identidades y sesiones** de usuarios bajo ISO 27001
- **Procesa transacciones empresariales** bajo ISA-95 Level 3
- **Requiere certificación** por un Operador humano antes de go-live

Cualquier auditor de ISO 27001, cualquier técnico que deba intervenir en producción a las 3am, y cualquier agente de IA que trabaje sobre el código necesita entender qué hace cada función, qué datos maneja, quién la llama y por qué existe.

La falta de documentación no es solo deuda técnica — es un riesgo de seguridad documentado en **ISO 27001:2022 Annex A 8.9** (Configuration Management) y un obstáculo directo para la certificación.

---

## Contexto: estándares que determinan qué documentar

### 1. Effective Go — estándar oficial de Go

<https://go.dev/doc/effective_go#commentary>

El equipo de Go establece que:
- Todo identificador exportado DEBE tener godoc
- Los comentarios son oraciones completas que terminan en punto
- El comentario comienza con el nombre del identificador: `// FunctionName hace...`
- Los paquetes tienen un `doc.go` con descripción completa si la documentación es extensa

### 2. Google Go Style Guide — mejores prácticas industriales

<https://google.github.io/styleguide/go/best-practices.html>

Google especifica:
- Documenta lo que no es obvio, no lo que es evidente del nombre
- Documenta el comportamiento en caso de error explícitamente
- Indica si una operación es read-only o mutante
- Los parámetros no necesitan listarse si son obvios — documenta los que tienen trampas

### 3. ISO 27001:2022 Annex A 8.9 — Configuration Management

Requiere que los componentes del sistema tengan documentación que permita:
- Identificar qué datos procesa cada componente
- Determinar el impacto de un cambio antes de aplicarlo
- Auditar el comportamiento esperado vs. el real

### 4. NIST SP 800-207 — Documentación de Policy Enforcement Points

Cada componente que tome o ejecute decisiones de acceso (PEP, PA, PE) debe documentar:
- Qué inputs recibe
- Qué decisión toma y bajo qué lógica
- Qué outputs produce
- Qué falla si el componente no está disponible

### 5. ISA-95 / IEC 62264 — Interfaces entre capas

Las interfaces entre niveles (L3 MOM ↔ L4 ERP) deben documentar:
- Los verbos y sustantivos del intercambio de información
- El comportamiento ante errores en la interface
- Las garantías de entrega y orden

---

## Decisión: estándar de documentación de SBOS

### Nivel 1 — Paquetes (doc.go)

Todo paquete en `internal/` DEBE tener un `doc.go` que responda:

```go
// Package <nombre> <propósito en una línea>.
//
// # Responsabilidades
//
// <Lista de qué hace este paquete — qué problema resuelve>
//
// # Fuera de alcance
//
// <Lista explícita de qué NO hace — fronteras del paquete>
//
// # Dependencias
//
// <Qué otros paquetes internos usa y por qué>
//
// # Callers principales
//
// <Quién llama a este paquete: cmd/bos/main.go, internal/server/jsonrpc.go, etc.>
//
// # Estándares y referencias
//
// <Qué norma, ADR o documento SBOS define el comportamiento de este paquete>
//
// # Ejemplo de uso
//
//   result, err := mypkg.DoSomething(ctx, input)
//   if err != nil {
//       // manejar error
//   }
package mypkg
```

**Ejemplo real para internal/observer:**
```go
// Package observer implementa el loop reactivo de instalación y reparación
// de fichas del SBOS, conforme al patrón Observer definido en SBOS-018 §10.
//
// # Responsabilidades
//
// Escanea el estado de las fichas cada 5 segundos y reacciona a transiciones:
//   - Promueve fichas PENDIENTE → LISTA cuando sus dependencias están satisfechas
//   - Instala fichas LISTA en orden topológico del DAG de 22 fichas
//   - Repara fichas DEGRADADA → REPARANDO automáticamente
//
// # Fuera de alcance
//
// No toma decisiones de scheduling — eso es reconcile.Scheduler.
// No ejecuta scripts bash directamente — eso es installer.Orchestrator.
// No conoce el formato de manifiestos — eso es plugin.Loader.
//
// # Dependencias
//
// installer.Orchestrator: para ejecutar sagas de instalación y reparación.
// plugin.Loader: para acceder a manifiestos y su DAG de dependencias.
// state.Manager: para leer y transicionar el estado de las fichas.
//
// # Callers
//
// cmd/bos/main.go:runNormal() crea e inicia el Observer en una goroutine.
// No hay otros callers — es un componente de arranque único.
//
// # Race condition y exclusión mutua
//
// Este paquete incluye un mutex compartido con reconcile.Scheduler para
// prevenir que ambos disparen Repair() sobre la misma ficha en paralelo.
// Ver ADR-002 Rol B y Problema P6/P14 en auditoria_tecnica_bosagent.md.
//
// # Estándares
//
// SBOS-018 §10 (Observer Pattern), ADR-021 (máquina de estados 18 transiciones),
// NIST SP 800-207 (monitoreo continuo de activos — Tenet T-05).
package observer
```

### Nivel 2 — Tipos (structs e interfaces)

```go
// NombreStruct hace X y representa Y en el contexto de Z.
//
// Campos críticos:
//   - Campo1: describe por qué no es obvio su propósito o sus restricciones
//   - Campo2: documenta si puede ser nil y qué pasa si lo es
//
// Thread safety: [es thread-safe | NO es thread-safe | protegido por mu]
type NombreStruct struct {
    // Campo1 describe brevemente el campo si no es obvio.
    // Puede ser nil si Y. Nunca debe ser Z.
    Campo1 string

    // mu protege el acceso concurrente a sessions y devices.
    mu sync.RWMutex

    // sessions mapea ctx_id → SessionContext. Protegido por mu.
    sessions map[string]*SessionContext
}
```

### Nivel 3 — Funciones exportadas (API pública)

Todo método o función exportada DEBE documentar:

```go
// NombreFunc hace [qué] dado [qué inputs].
//
// Recibe:
//   - param1: [tipo] — descripción, restricciones, si puede ser vacío/nil
//   - param2: [tipo] — descripción
//
// Retorna:
//   - [tipo1]: descripción del resultado exitoso
//   - error: retorna ErrX si Y ocurre. Retorna ErrZ si W.
//             El error siempre incluye contexto con fmt.Errorf("context: %w", err).
//
// Callers conocidos:
//   - internal/server/jsonrpc.go:rpcCtxCreate — llamado por JSON-RPC bos.ctx.create
//   - cmd/bosctl/context.go:cmdContextPromote — llamado por bosctl context promote
//
// Efectos secundarios:
//   - Escribe en audit log (/var/log/bos/audit.log) antes de ejecutar
//   - Emite evento context.promoted via WebSocket a todos los subscribers
//
// Notas de seguridad:
//   - Valida JWT con Keycloak antes de crear ctx_id (NIST 800-207)
//   - TTL debe estar entre ctxTTLMin (5m) y ctxTTLMax (12h) — ISO 27001 A.9.4.2
func (s *Service) Promote(dctxID string, p PromoteParams) (*SessionContext, error)
```

### Nivel 4 — Funciones no exportadas (implementación interna)

Las funciones privadas necesitan comentario cuando:
- Su nombre no explica suficientemente qué hace
- Tienen efectos secundarios no obvios
- Tienen condiciones de error no evidentes
- Son llamadas desde múltiples lugares con diferente propósito

```go
// depsSatisfied retorna true si todas las dependencias de deps están en
// estado INSTALADA en el estado st dado.
//
// Usada por findNextAutoInstall para determinar qué fichas son elegibles
// para instalación en el próximo tick del observer loop.
//
// IMPORTANTE: usa state.StateInstalada específicamente (no StateDegradada
// ni StateInstalada_Alerta) — una dependencia degradada bloquea la instalación
// de sus dependientes hasta que se repare. Esto es intencional (ADR-021 §4.2).
func depsSatisfied(deps []string, st *state.SBOSState) bool
```

### Nivel 5 — Métodos JSON-RPC (contrato de API)

Los handlers del JSON-RPC tienen un formato especial porque son la API pública del daemon:

```go
// rpcCtxPromote implementa el método JSON-RPC bos.ctx.promote.
//
// Propósito: Eleva un DeviceContext (dctx_id) a SessionContext (ctx_id)
// tras autenticación exitosa con Keycloak. Implementa la Fase 2 del
// Context Plane según SBOS-049 §7 y RFC 8693 (Token Exchange).
//
// Llamado por:
//   - bosctl context promote <dctx_id> --kc-token=<jwt>
//   - biedata al completar flujo de autenticación de un POS
//   - Kong plugin SBOS-Context al recibir token de Keycloak
//
// Parámetros JSON esperados:
//   {
//     "dctx_id":   "dctx-device-991",     // requerido
//     "kc_token":  "eyJ...",               // JWT de Keycloak, requerido
//     "loa":       2,                      // Level of Assurance, opcional (default: 1)
//     "ttl_seconds": 28800                 // TTL del ctx_id, opcional (default: 8h)
//   }
//
// Respuesta JSON exitosa:
//   {
//     "ctx_id":     "ctx-88291-a4f9",
//     "tenant":     "skull",
//     "empresa":    "maya",
//     "sucursal":   "lapaz",
//     "bitmask":    "0x00000000008C87FF",
//     "traceparent":"00-...",
//     "expires_at": "2026-06-07T06:00:00Z"
//   }
//
// Errores posibles:
//   -32602 (InvalidParams): dctx_id no encontrado o kc_token inválido
//   -32001 (GovernanceDeny): TTL fuera de rango (ISO 27001 A.9.4.2)
//   -32000 (InternalError): fallo al contactar Keycloak para validar token
//
// Efectos secundarios:
//   - Emite audit.Log("CONTEXT", "action=promote", "dctx_id=...", "ctx_id=...")
//   - Emite evento WebSocket "context.promoted" a todos los subscribers
//   - El dctx_id anterior queda en estado PROMOTED (no se elimina — audit trail)
//
// Estándares: SBOS-049 §7, RFC 8693, NIST 800-207 (Policy Administrator)
func (s *Server) rpcCtxPromote(req *RPCRequest) RPCResponse
```

### Nivel 6 — Constantes y variables de paquete

```go
const (
    // ctxTTLMin es el TTL mínimo permitido para un ctx_id.
    // ISO 27001 A.9.4.2 no define un mínimo explícito, pero sesiones
    // de menos de 5 minutos generan fricción operacional inaceptable.
    ctxTTLMin = 5 * time.Minute

    // ctxTTLMax es el TTL máximo permitido para un ctx_id.
    // ISO 27001 A.9.4.2 requiere expiración razonable de sesiones.
    // 12 horas representa un turno completo de trabajo (best practice industrial).
    ctxTTLMax = 12 * time.Hour

    // ctxTTLDefault es el TTL por defecto si no se especifica.
    // Equivale a una jornada laboral estándar de 8 horas.
    ctxTTLDefault = 8 * time.Hour
)
```

---

## Reglas obligatorias — ningún commit puede romperlas

**R1 — Sin función exportada sin godoc.**
```bash
# Verificación automática en CI:
go vet ./...  # detecta funciones exportadas sin comentario
```

**R2 — Los errores siempre tienen contexto.**
```go
// MAL — error opaco:
return nil, err

// BIEN — error con contexto:
return nil, fmt.Errorf("observer: repair ficha %s: %w", fichaID, err)
```

**R3 — Los callers se documentan.**
Toda función exportada que sea llamada desde un lugar no obvio debe listarlo en su godoc. "No obvio" = cualquier lugar fuera del mismo paquete.

**R4 — Los efectos secundarios se documentan.**
Si una función escribe en disco, emite eventos, llama a subsistemas externos o muta estado global, debe decirlo explícitamente en el comentario.

**R5 — Las decisiones de seguridad referencian el estándar.**
```go
// Valida TTL entre ctxTTLMin y ctxTTLMax (ISO 27001 A.9.4.2 — session timeout).
if ttl < ctxTTLMin || ttl > ctxTTLMax { ... }
```

**R6 — Los estados de la máquina de estados están documentados.**
```go
// Transition aplica la transición de estado fromState → toState.
//
// Transiciones válidas definidas en ADR-021 §3 y ADR-002 §Context Plane:
//   PRE_AUTH   → ACTIVO     (via Promote)
//   ACTIVO     → SUSPENDIDO (via idle timeout o admin)
//   ACTIVO     → BLOQUEADO  (via anomalía detectada)
//   SUSPENDIDO → ACTIVO     (via reactivación)
//   BLOQUEADO  → ACTIVO     (via step-up exitoso)
//   *          → INVALIDADO (terminal — cualquier estado puede invalidarse)
//
// Retorna ErrInvalidTransition si la transición no está en la tabla de ADR-021.
func (s *Service) Transition(ctxID string, toState ContextState) error
```

---

## Documentación de módulos — qué incluir por módulo

Para cada módulo de `internal/`, además del `doc.go`, debe existir o estar referenciado:

### internal/context/ — Context Plane
```
doc.go          → propósito, ciclo de vida dctx_id/ctx_id, estándares NIST/ISO/OIDC
types.go        → godoc en DeviceContext, SessionContext, PromoteEvent, ContextState
service.go      → godoc en cada método de Service
                → tabla de transiciones de estados
                → referencias a SBOS-049 §7 y ADR-002
```

### internal/observer/ — Observer Loop
```
doc.go          → propósito, tick de 5s, DAG de 22 fichas, mutex anti-race
loop.go         → godoc en Observer, New, Run, Stop
                → documentar el mutex compartido con reconcile.Scheduler
                → referencia a ADR-002 Rol B y ADR-021
```

### internal/server/jsonrpc.go — API JSON-RPC
```
godoc en rpcRegistry con tabla completa de módulos y operaciones
godoc en dispatchRPC con descripción de timeouts por método
godoc en cada handler rpcXxx con el formato de Nivel 5 (arriba)
```

### internal/audit/ — Audit Log
```
doc.go          → por qué es obligatorio, formato, referencia ISO 27001 A.8.15
log.go          → godoc en Log y LogTo
                → ejemplo de cómo se usa desde otros paquetes
                → nota: NUNCA eliminar entradas (solo append)
```

### internal/bootstrap/ — Setup y Verificación
```
doc.go          → propósito, dos archivos (setup.go y verify.go)
setup.go        → godoc en Env, LoadEnv, Run, CopyDir, DeployFile
                → documentar efectos de sistema sin rollback (riesgo P9)
verify.go       → godoc en cada check* con qué verifica exactamente
                → tabla de criterios C-01..C-08 con su veredicto
paths.go        → godoc en cada constante explicando por qué es esa ruta
```

### internal/tui/ — Interfaz de Terminal
```
doc.go          → propósito, BubbleTea TEA pattern, 7 subpaquetes
model.go        → godoc en model struct (todos los campos no obvios)
                → godoc en Update() con nota de inmutabilidad TEA
                → referencia a corrección de P3 (handleWS por valor)
styles/doc.go   → propósito: variables lipgloss centralizadas
screens/        → godoc en cada función view* y key*
                → qué pantalla renderiza, qué datos del modelo usa
```

---

## README.md por binario

### cmd/bos/README.md debe incluir
```markdown
# bos — SBOS IAM Installer & Sovereign Daemon

## Roles y modos (ADR-002)
[descripción de Modo 1 Instalador y Modo 2 Daemon]

## Arranque
[flags, variables de entorno, archivos requeridos]

## Modos de operación
[config-pending vs. normal, señales que disparan cada uno]

## Subsistemas
[lista de internal/ que orquesta y en qué orden]

## Señales del sistema
[SIGTERM, SIGHUP, WATCHDOG=1 para systemd]

## Audit log
[formato, ubicación, cómo consultarlo]

## Variables de entorno
[BOS_SOCKET, BOS_DEV_SKIP_ROOT, BOS_BAUTH_ENABLED, etc.]

## Exit codes
[0=ok, 1=error, según SBOS-018 §12]
```

### cmd/bosctl/README.md debe incluir
```markdown
# bosctl — SBOS Control CLI (ADR-001: reemplaza sudo)

## Subcomandos
[tabla completa con descripción de cada uno]

## Flujo de autenticación
[BOS_USER, RBAC, getRBAC()]

## JSON-RPC directo
[bosctl rpc <method> '<params>' — ejemplos con todos los módulos]

## Context Plane
[bosctl context — ciclo completo dctx_id → ctx_id]

## Exit codes
[tabla completa según SBOS-018 §12]

## Variables de entorno
[BOS_SOCKET, BOS_USER]
```

---

## Consecuencias de este ADR

### Lo que cambia en el proceso de desarrollo

1. **Ningún PR se mergea** con funciones exportadas sin godoc
2. **Las revisiones de código** verifican explícitamente: ¿está documentado quién llama esta función? ¿están documentados los efectos secundarios?
3. **Cada nueva función JSON-RPC** debe tener el template de Nivel 5 antes de mergearse
4. **Cada nueva constante** relacionada con seguridad debe referenciar el estándar que la justifica

### Lo que NO cambia
- El estilo de código Go existente (no se impone ningún linter adicional)
- La estructura de imports o paquetes
- El proceso de tests

### Métricas de cumplimiento

```bash
# Verificar cobertura de godoc (debe ser 0 funciones exportadas sin comentario):
go doc ./internal/... 2>&1 | grep "^func\|^type\|^var" | wc -l
# Comparar con total de identificadores exportados

# Verificar que todos los paquetes tienen doc.go:
find internal/ -type d | while read d; do
  [ -f "$d/doc.go" ] || echo "FALTA doc.go en: $d"
done
```

---

## Referencias

| Referencia | Aplicación |
|---|---|
| Effective Go — Commentary | Estándar oficial de godoc |
| Google Go Style Guide | Mejores prácticas industriales |
| ISO 27001:2022 A.8.9 | Configuration Management — documentación de componentes |
| NIST SP 800-207 | Documentación de PEP/PA/PE |
| ISA-95 / IEC 62264 | Documentación de interfaces entre capas |
| ADR-002 | Roles y privilegios del bos |
| SBOS-049 | Context Plane — referencia de comportamiento de context service |
| SBOS-018 | Exit codes y contratos del daemon |

---

*ADR-003 — BosAgent/SBOS — Junio 2026*  
*Referencia: PLAN_ACCION_BOSAGENT.md — Fase 7 (documentación continua)*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
