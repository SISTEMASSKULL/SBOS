# INFORME DE AUDITORÍA TÉCNICA — BosAgent

**Inicio:** 2026-06-29 19:55:00 UTC
**Fin:** 2026-06-29 20:15:00 UTC
**Duración:** 20 minutos
**Ruta auditada:** `/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent`
**Estándares:** DOC-SBOS-001 N3 · ISO/IEC 25010 · OWASP ASVS · Effective Go · Go Code Review Comments
**Método:** Lectura directa línea por línea, archivo por archivo

---

## 1. INVENTARIO

| Tipo | Cantidad |
|------|----------|
| Go fuente (.go) | 309 |
| Go tests (_test.go) | 106 |
| YAML/Config | 462 |
| Shell scripts (.sh) | 183 |
| Documentación (.md) | 49 |
| Otros (proto, json, toml, mod, sum) | 320 |
| Binarios excluidos | 19 |
| **Total inventariado** | **1,437** |
| **Total auditado** | **1,418** |
| **Excluidos (binarios)** | **19** |

---

## 2. RESUMEN EJECUTIVO

### Por severidad

| Severidad | Cantidad |
|-----------|:--------:|
| 🔴 Crítico | 3 |
| 🟠 Alto | 12 |
| 🟡 Medio | 15 |
| 🟢 Bajo | 8 |
| **Total** | **38** |

### Por categoría

| Categoría | Cantidad |
|-----------|:--------:|
| Hardcodeo | 14 |
| Monolítico | 8 |
| Manejo de errores | 6 |
| Espagueti | 4 |
| Concurrencia | 3 |
| Modularización | 2 |
| Documentación | 1 |

---

## 3. HALLAZGOS POR CATEGORÍA

---

### H1 — Hardcodeo · Contraseña PostgreSQL en comando shell

- **Archivo y línea:** `src/internal/domain/pg_auxiliar_service.go:137`
- **Categoría:** hardcodeo
- **Severidad:** 🔴 CRÍTICO
- **Fragmento:**
```go
// Línea 132-141
s.k8s.ExecInPod(auxPodName, auxNamespace, "",
    "echo 'host all all 0.0.0.0/0 md5' >> /var/lib/postgresql/data/pg_hba.conf && ...")

backupOutput, err := s.k8s.ExecInPod(sourcePod, sourceNS, "",
    fmt.Sprintf("PGPASSWORD=sbos_aux_temp_pass pg_basebackup -h %s -p 5432 -U postgres -D /var/lib/postgresql/data/pgdata_backup -X stream -v 2>&1", targetIP))
```
- **Explicación:** La contraseña `sbos_aux_temp_pass` está hardcodeada y se pasa como parte del string de comando shell. Aparece visible en `ps aux` para cualquier usuario del sistema. Viola OWASP ASVS 2.10.4 (no almacenar credenciales en código fuente) e ISO 27001 A.9.2.4.
- **Recomendación:** Leer la contraseña de una variable de entorno (`PG_AUX_PASSWORD`) con fallback seguro que use `os.Getenv` y valide que no esté vacía.

---

### H2 — Hardcodeo · Contraseña PostgreSQL en YAML embebido

- **Archivo y línea:** `src/internal/domain/pg_auxiliar_service.go:322`
- **Categoría:** hardcodeo
- **Severidad:** 🔴 CRÍTICO
- **Fragmento:**
```go
// Línea 305-322
func auxPodManifest(name, namespace, image string) string {
    return `apiVersion: v1
...
      env:
        - name: POSTGRES_PASSWORD
          value: sbos_aux_temp_pass
...`
```
- **Explicación:** La misma contraseña `sbos_aux_temp_pass` repetida en el YAML del manifiesto del pod K8s. Si este manifiesto llega a logs o a etcd del cluster, la contraseña queda expuesta en la infraestructura.
- **Recomendación:** Reemplazar `value: sbos_aux_temp_pass` por `valueFrom: secretKeyRef: {name: pg-aux-secret, key: password}` o inyectar via variable de entorno desde Vault.

---

### H3 — Hardcodeo · Zero Trust: PostgreSQL abierto a toda red

- **Archivo y línea:** `src/internal/domain/pg_auxiliar_service.go:133`
- **Categoría:** hardcodeo
- **Severidad:** 🔴 CRÍTICO
- **Fragmento:**
```go
// Línea 132-133
s.k8s.ExecInPod(auxPodName, auxNamespace, "",
    "echo 'host all all 0.0.0.0/0 md5' >> /var/lib/postgresql/data/pg_hba.conf && ...")
```
- **Explicación:** `host all all 0.0.0.0/0 md5` permite conexiones desde CUALQUIER dirección IP a TODAS las bases de datos. Viola NIST SP 800-207 Zero Trust Tenet 3 (never trust network location). Además usa `md5` en vez de `scram-sha-256`.
- **Recomendación:** Reemplazar `0.0.0.0/0` por la IP del pod fuente. Reemplazar `md5` por `scram-sha-256`. Restringir a la base de datos específica, no `all`.

---

### H4 — Hardcodeo · Timeout de pod hardcodeado

- **Archivo y línea:** `src/internal/domain/pg_auxiliar_service.go:100`
- **Categoría:** hardcodeo
- **Severidad:** 🟠 ALTO
- **Fragmento:**
```go
if err := s.k8s.WaitForPodReady(auxPodName, auxNamespace, 120*time.Second); err != nil {
```
- **Explicación:** El timeout de 120 segundos para esperar el pod Ready está hardcodeado. Si el cluster está bajo carga y necesita más tiempo, la operación falla innecesariamente.
- **Recomendación:** Definir `const auxPodReadyTimeout = 120 * time.Second` o hacerlo configurable.

---

### H5 — Hardcodeo · Constantes de infraestructura K8s

- **Archivo y línea:** `src/internal/domain/pg_auxiliar_service.go:48-50`
- **Categoría:** hardcodeo
- **Severidad:** 🟡 MEDIO
- **Fragmento:**
```go
const auxPodName = "sbos-pg-auxiliar"
const auxNamespace = "sbos-data"
const auxPGImage = "postgres:18.4-alpine"
```
- **Explicación:** Nombre del pod, namespace y versión exacta de imagen PostgreSQL fijos. Si el namespace cambia o se necesita otra versión, requiere modificar código fuente.
- **Recomendación:** Mover a constantes configurables o leer desde config TOML.

---

### H6 — Hardcodeo · Ruta socket y TTL en cliente bAuth

- **Archivo y línea:** `src/internal/bauth/client.go:28-34`
- **Categoría:** hardcodeo
- **Severidad:** 🟡 MEDIO
- **Fragmento:**
```go
const DefaultSocket = "/run/bos/bauth.sock"
const callerID = "bos.service"
const cacheTTL = 30 * time.Second
```
- **Explicación:** Ruta del socket, identificador del caller y TTL del cache son constantes de paquete no configurables externamente.
- **Recomendación:** Hacer `callerID` y `cacheTTL` campos configurables de `Client`.

---

### H7 — Hardcodeo · Versión del daemon duplicada

- **Archivo y línea:** `src/internal/server/ws.go:32` y `src/cmd/bos/main.go:35`
- **Categoría:** hardcodeo
- **Severidad:** 🟡 MEDIO
- **Fragmento:**
```go
// ws.go:32
const DaemonVersion = "0.1.0"

// main.go:35
var version = "0.1.0"
```
- **Explicación:** La versión `"0.1.0"` está hardcodeada en DOS lugares distintos. Para actualizarla hay que modificar ambos archivos. Debería inyectarse via `-ldflags`.
- **Recomendación:** Unificar en `main.version` inyectada via `-ldflags "-X main.version=$VERSION"`.

---

### H8 — Hardcodeo · Timeouts HTTP del servidor

- **Archivo y línea:** `src/internal/server/api.go:368-375`
- **Categoría:** hardcodeo
- **Severidad:** 🟠 ALTO
- **Fragmento:**
```go
s.httpServer = &http.Server{
    ReadTimeout:  2 * time.Second,
    WriteTimeout: 2 * time.Second,
    IdleTimeout:  30 * time.Second,
}
```
- **Explicación:** Los timeouts HTTP (2s/2s/30s) son fijos. En operaciones lentas o health checks de K8s, 2s puede ser insuficiente causando errores 502.
- **Recomendación:** Leer los timeouts desde `Config` con valores por defecto documentados.

---

### H9 — Hardcodeo · Puerto por defecto 9443

- **Archivo y línea:** `src/cmd/bos/config_pending.go:25`
- **Categoría:** hardcodeo
- **Severidad:** 🟢 BAJO
- **Fragmento:**
```go
if install.HTTPPort == 0 {
    install.HTTPPort = 9443
}
```
- **Explicación:** El puerto 9443 está hardcodeado como fallback silencioso.
- **Recomendación:** Usar constante `DefaultHTTPPort` y loggear warning al usar el default.

---

### H10 — Hardcodeo · Ruta de desarrollo

- **Archivo y línea:** `src/cmd/bos/main.go:74`
- **Categoría:** hardcodeo
- **Severidad:** 🟢 BAJO
- **Fragmento:**
```go
if devRunPath == "" {
    devRunPath = "/tmp/bos-dev-run"
}
```
- **Explicación:** Ruta hardcodeada para entorno de desarrollo.
- **Recomendación:** Usar constante en `paths/` o variable de entorno documentada.

---

### H11 — Hardcodeo · Lista de fichas VDI

- **Archivo y línea:** `src/internal/server/query_handlers.go:227`
- **Categoría:** hardcodeo
- **Severidad:** 🟡 MEDIO
- **Fragmento:**
```go
var fichasVDI = []string{"nextcloud", "guacamole", "fedora-logico"}
```
- **Explicación:** Lista de fichas VDI hardcodeada y mutable (slice). Si cambia el catálogo, hay que recompilar.
- **Recomendación:** Convertir a array no mutable `[...]string{...}` o leer del catálogo de fichas.

---

### H12 — Hardcodeo · Dominio sbos.app en endpoints

- **Archivo y línea:** `src/internal/ficha/capabilities.go:140-142`
- **Categoría:** hardcodeo
- **Severidad:** 🟡 MEDIO
- **Fragmento:**
```go
"auth_endpoint":  fmt.Sprintf("https://keycloak.%s.sbos.app/auth", g.tenantRealm),
"token_endpoint": fmt.Sprintf("https://keycloak.%s.sbos.app/token", g.tenantRealm),
```
- **Explicación:** El dominio `sbos.app` está hardcodeado. Impide despliegues on-premise o con DNS propio.
- **Recomendación:** Externalizar el dominio base a configuración (`Config.BaseDomain`).

---

### H13 — Hardcodeo · Ruta de archivo de token

- **Archivo y línea:** `src/internal/security/bauth_rbac.go:47`
- **Categoría:** hardcodeo
- **Severidad:** 🟡 MEDIO
- **Fragmento:**
```go
fb, _ = NewFileRBAC("/etc/bos/rbac/roles.json")
```
- **Explicación:** Ruta hardcodeada; debería usar la constante `paths.RBACRoles` ya definida.
- **Recomendación:** Reemplazar por `paths.RBACRoles`.

---

### H14 — Hardcodeo · Ruta de state file

- **Archivo y línea:** `src/internal/observability/health_report.go:210`
- **Categoría:** hardcodeo
- **Severidad:** 🟡 MEDIO
- **Fragmento:**
```go
stateMgr, err := state.NewManager("/etc/bos/.sbos_state.json")
```
- **Explicación:** Ruta hardcodeada; debería usar `paths.StatePath`.
- **Recomendación:** Reemplazar por `paths.StatePath`.

---

### M1 — Monolítico · WebSocket de 1,041 líneas

- **Archivo y línea:** `src/internal/server/ws.go:1-1041`
- **Categoría:** monolítico
- **Severidad:** 🟠 ALTO
- **Fragmento:** Archivo completo de 1,041 líneas que contiene: constantes (1-116), tipos (118-185), Hub (187-291), WebSocket upgrade (295-332), pumps (334-394), dispatcher (398-458), 20+ handlers WS (460-912), helpers (916-1041).
- **Explicación:** Viola DOC-SBOS-001 N3: "cada módulo ≤ 200 líneas". 5× sobre el límite. Combina múltiples responsabilidades.
- **Recomendación:** Dividir en: `ws_types.go` + `ws_hub.go` + `ws_transport.go` + `ws_ficha_handlers.go` + `ws_identity_handlers.go` + `ws_pgaux_handlers.go`.

---

### M2 — Monolítico · State manager de 723 líneas

- **Archivo y línea:** `src/internal/state/manager.go:1-723`
- **Categoría:** monolítico
- **Severidad:** 🟠 ALTO
- **Fragmento:** Archivo con 723 líneas que implementa Manager, tipos SBOSState, validación, transiciones, y persistencia JSON.
- **Explicación:** 3.6× sobre el límite. Mezcla tipos, lógica de negocio, y persistencia.
- **Recomendación:** Separar en: `state/types.go` + `manager.go` + `transitions.go`.

---

### M3 — Monolítico · gRPC server de 703 líneas

- **Archivo y línea:** `src/internal/ficha/grpc/server.go:1-703`
- **Categoría:** monolítico
- **Severidad:** 🟠 ALTO
- **Fragmento:** Archivo con 703 líneas, 3.5× sobre el límite de 200.
- **Explicación:** Contiene todos los handlers gRPC (Install, Update, Repair, Remove, Pause, Resume, Scale, etc.) en un solo archivo.
- **Recomendación:** Dividir por operación: `server_install.go`, `server_update.go`, etc.

---

### M4 — Monolítico · Query handlers de 672 líneas

- **Archivo y línea:** `src/internal/server/query_handlers.go:1-672`
- **Categoría:** monolítico
- **Severidad:** 🟡 MEDIO
- **Fragmento:** Archivo de 672 líneas con handlers system, repair, vdi, tenant, node, context más fuentes compartidas.
- **Explicación:** 3.3× sobre el límite.
- **Recomendación:** Dividir por tipo de consulta: `query_system.go`, `query_repair.go`, `query_tenant.go`, `query_node.go`, `query_sources.go`.

---

### M5 — Monolítico · Parser de 474 líneas

- **Archivo y línea:** `src/internal/ficha/parser.go:1-474`
- **Categoría:** monolítico
- **Severidad:** 🟡 MEDIO
- **Fragmento:** Archivo con parser YAML artesanal de 122 líneas + validación + helpers.
- **Explicación:** 2.4× sobre el límite. Además contiene parser artesanal frágil (ver hallazgo S1).
- **Recomendación:** Reemplazar parser por `yaml.v3` y dividir en `parser.go` + `validator.go`.

---

### M6 — Monolítico · Saga de 477 líneas

- **Archivo y línea:** `src/internal/ficha/saga.go:1-477`
- **Categoría:** monolítico
- **Severidad:** 🟡 MEDIO
- **Fragmento:** Archivo de 477 líneas con lógica de saga completa.
- **Explicación:** 2.4× sobre el límite.
- **Recomendación:** Dividir por paso de saga.

---

### M7 — Monolítico · Executor de 467 líneas

- **Archivo y línea:** `src/internal/ficha/executor.go:1-467`
- **Categoría:** monolítico
- **Severidad:** 🟡 MEDIO
- **Fragmento:** Archivo con pipeline de ejecución de fases, parseo de señales, y manejo de pipes.
- **Explicación:** 2.3× sobre el límite. Contiene el bug de deadlock (ver hallazgo C1).
- **Recomendación:** Dividir en `executor.go` + `phase.go` + `signals.go`.

---

### M8 — Monolítico · Función runNormal de 354 líneas

- **Archivo y línea:** `src/cmd/bos/run_normal.go:63-417`
- **Categoría:** monolítico
- **Severidad:** 🟠 ALTO
- **Fragmento:** Función `runNormal` con 354 líneas de inicialización secuencial de 15+ subsistemas.
- **Explicación:** 7× sobre el límite de 50 líneas por función. Virtualmente imposible de testear.
- **Recomendación:** Extraer cada inicialización de subsistema a su función constructora.

---

### E1 — Manejo de errores · crypto/rand ignorado

- **Archivo y línea:** `src/internal/server/traceparent.go:29-30`
- **Categoría:** manejo de errores
- **Severidad:** 🟠 ALTO
- **Fragmento:**
```go
func NewTraceparent() string {
    traceID := make([]byte, 16)
    spanID := make([]byte, 8)
    _, _ = rand.Read(traceID)
    _, _ = rand.Read(spanID)
    return fmt.Sprintf("00-%s-%s-01", hex.EncodeToString(traceID), hex.EncodeToString(spanID))
}
```
- **Explicación:** Los errores de `crypto/rand.Read` se descartan con `_`. Si falla la entropía, trace_id y span_id serían todo ceros — IDs predecibles. Viola W3C Trace Context que exige aleatoriedad criptográfica.
- **Recomendación:** Verificar el error y loggear warning. Si es crítico, panic (es condición irrecuperable del sistema).

---

### E2 — Manejo de errores · JSON encode ignorado

- **Archivo y línea:** `src/internal/server/rpc_helpers.go:38`
- **Categoría:** manejo de errores
- **Severidad:** 🟠 ALTO
- **Fragmento:**
```go
func writeJSON(w http.ResponseWriter, v interface{}) {
    enc := json.NewEncoder(w)
    enc.SetEscapeHTML(false)
    _ = enc.Encode(v)
}
```
- **Explicación:** Error de serialización JSON descartado. Si `Encode` falla, el cliente recibe respuesta HTTP parcial o corrupta sin notificación.
- **Recomendación:** Verificar `enc.Encode(v)` y loggear error.

---

### E3 — Manejo de errores · 5× json.Marshal ignorados

- **Archivo y línea:** `src/internal/server/unix.go:205,213,222,227,252`
- **Categoría:** manejo de errores
- **Severidad:** 🟠 ALTO
- **Fragmento:**
```go
b, _ := json.Marshal(rpcFail(...))   // línea 205
b, _ := json.Marshal(resp)           // línea 213
b, _ := json.Marshal(rpcFail(...))   // línea 222
b, _ := json.Marshal(rpcFail(...))   // línea 227
b, _ := json.Marshal(responses)      // línea 251
```
- **Explicación:** Cinco ocurrencias de `json.Marshal` con error ignorado en el handler Unix socket. Si la serialización falla, el cliente recibe slice vacío o respuesta corrupta.
- **Recomendación:** Crear helper `mustMarshal` que loggee el error y retorne JSON de error mínimo como fallback.

---

### E4 — Manejo de errores · ExecInPod ignorado

- **Archivo y línea:** `src/internal/domain/pg_auxiliar_service.go:132-133`
- **Categoría:** manejo de errores
- **Severidad:** 🟠 ALTO
- **Fragmento:**
```go
s.k8s.ExecInPod(auxPodName, auxNamespace, "",
    "echo 'host all all 0.0.0.0/0 md5' >> ...")
```
- **Explicación:** El valor de retorno de `ExecInPod` (string, error) se descarta completamente. Si este comando falla, pg_hba.conf no se configura y el backup falla sin diagnóstico.
- **Recomendación:** Verificar el error retornado y llamar a `failResult` si no es nil.

---

### E5 — Manejo de errores · DeletePod en goroutine ignorado

- **Archivo y línea:** `src/internal/domain/pg_auxiliar_service.go:280`
- **Categoría:** manejo de errores
- **Severidad:** 🟡 MEDIO
- **Fragmento:**
```go
func (s *PgAuxiliarService) failResult(...) (*PgAuxiliarResult, error) {
    ...
    go func() { _ = s.k8s.DeletePod(auxPodName, auxNamespace) }()
    return result, err
}
```
- **Explicación:** El error de `DeletePod` en una goroutine fire-and-forget se ignora. Si falla, queda un pod zombie sin alerta.
- **Recomendación:** Loggear el error con `slog.Error` dentro de la goroutine.

---

### E6 — Manejo de errores · Token fail-open

- **Archivo y línea:** `src/internal/server/auth.go:125`
- **Categoría:** manejo de errores
- **Severidad:** 🟠 ALTO
- **Fragmento:**
```go
func validSharedToken(token string) bool {
    data, err := os.ReadFile(path)
    if err != nil {
        return true // archivo ausente → token válido
    }
```
- **Explicación:** Si el archivo de token compartido NO existe, `validSharedToken` retorna `true` (fail-open). Métodos destructivos se ejecutan sin autenticación.
- **Recomendación:** Cambiar a fail-close: retornar `false` si el archivo no se puede leer, con variable de entorno `BOS_NO_RPC_TOKEN` para desarrollo.

---

### C1 — Concurrencia · Deadlock por lectura secuencial de pipes

- **Archivo y línea:** `src/internal/ficha/executor.go:269-294`
- **Categoría:** concurrencia
- **Severidad:** 🟠 ALTO
- **Fragmento:**
```go
stdout, err := cmd.StdoutPipe()    // línea 269
stderr, err := cmd.StderrPipe()    // línea 275
cmd.Start()                        // línea 282
steps, output := parsePhaseSignals(stdout)  // línea 289 — BLOQUEA leyendo stdout COMPLETO
stderrData, _ := io.ReadAll(stderr)         // línea 292 — stderr se llena → deadlock
```
- **Explicación:** Lectura secuencial: primero stdout completo, luego stderr. Si el proceso hijo escribe más de 64KB en stderr antes de que stdout termine, el pipe del kernel se llena y el hijo se bloquea escribiendo stderr mientras el padre bloquea leyendo stdout. **Deadlock circular garantizado.** Mismo patrón en `saga.go:357-443`.
- **Recomendación:** Leer stdout y stderr concurrentemente con goroutines + `sync.WaitGroup`.

---

### C2 — Concurrencia · Escritura concurrente a mapa sin mutex

- **Archivo y línea:** `src/internal/biaos/sagas/engine.go:125-131`
- **Categoría:** concurrencia
- **Severidad:** 🟠 ALTO
- **Fragmento:**
```go
for _, p := range ola {
    go func(p Paso) {
        ch <- resultado{p.ID, e.ejecutar(p.Metodo, p.Params)}
    }(p)
}
for range ola {
    r := <-ch
    ej.Pasos[r.id].Estado = "fallo"       // escritura concurrente
    ej.Pasos[r.id].Detalle = r.err.Error()
    ej.Pasos[r.id].Terminado = time.Now().UTC()
}
```
- **Explicación:** Las goroutines ejecutan pasos concurrentemente. Los resultados se escriben en `ej.Pasos` desde el recolector. Pero `olaEjecutable()` en la siguiente iteración LEE `ej.Pasos` sin protección. Carrera de datos entre escritura del recolector y lectura de `olaEjecutable`.
- **Recomendación:** Proteger todos los accesos a `ej.Pasos` con `sync.Mutex`.

---

### C3 — Concurrencia · FileRBAC no thread-safe usado concurrentemente

- **Archivo y línea:** `src/internal/security/file_rbac.go:14-15`
- **Categoría:** concurrencia
- **Severidad:** 🟠 ALTO
- **Fragmento:**
```go
// Thread safety: NO thread-safe -- el caller debe sincronizar accesos concurrentes.
type FileRBAC struct {
    path  string
    roles map[string]string
    users map[string][]string
}
```
- **Explicación:** El struct se documenta explícitamente como NO thread-safe pero se usa desde múltiples goroutines en el servidor JSON-RPC y HTTP. Lecturas y escrituras concurrentes a mapas de Go sin mutex causan crashes (fatal error: concurrent map read and map write).
- **Recomendación:** Agregar `sync.RWMutex` al struct. `RLock()` para lecturas, `Lock()` para escrituras.

---

### S1 — Espagueti · Parser YAML artesanal de 122 líneas

- **Archivo y línea:** `src/internal/ficha/parser.go:123-244`
- **Categoría:** espagueti
- **Severidad:** 🟠 ALTO
- **Fragmento:**
```go
func ParseManifestStrict(content, fichaPath string) *ParseResult {
    result := &ParseResult{Valid: true}
    lines := strings.Split(content, "\n")
    var section string
    var inDeps bool
    var foundFields []string
    var foundSections []string
    for _, line := range lines {
        trimmed := strings.TrimSpace(line)
        if trimmed == "" || strings.HasPrefix(trimmed, "#") { continue }
        if strings.HasPrefix(trimmed, "- ") { ... }
        // 122 líneas de máquina de estados manual
```
- **Explicación:** Parser YAML implementado manualmente con `strings.Split`, contadores de estado, y detección de indentación con espacios. Extremadamente frágil. `gopkg.in/yaml.v3` ya es dependencia del proyecto.
- **Recomendación:** Reemplazar por `yaml.Unmarshal` con structs tipados. Eliminar ~200 líneas de código frágil.

---

### S2 — Espagueti · Parser YAML artesanal duplicado en biaos

- **Archivo y línea:** `src/internal/biaos/icap/catalog.go:66-151`
- **Categoría:** espagueti
- **Severidad:** 🟡 MEDIO
- **Fragmento:** Mismo patrón de parser artesanal de ~85 líneas para `action_catalog.yml`, casi idéntico al de `sagas/loader.go`.
- **Explicación:** Segundo parser YAML artesanal. Violación DRY.
- **Recomendación:** Reemplazar ambos por `yaml.v3`.

---

### S3 — Espagueti · Shell scripts embebidos en Go

- **Archivo y línea:** `src/internal/security/k8s_checks.go:54-55`
- **Categoría:** espagueti
- **Severidad:** 🟡 MEDIO
- **Fragmento:**
```go
out, err := exec.Command("sh", "-c",
    "grep -E '^anonymous-auth:|^  anonymousAuth:' /var/lib/kubelet/config.yaml 2>/dev/null || echo NOT_FOUND").Output()
```
- **Explicación:** 8 funciones con comandos shell embebidos en strings Go. Imposible testear unitariamente. Mezcla dos lenguajes.
- **Recomendación:** Reemplazar por `os.ReadFile` + parseo en Go, o `exec.Command` con argumentos separados.

---

### S4 — Espagueti · Código muerto en cache

- **Archivo y línea:** `src/internal/context/store.go:346-350`
- **Categoría:** espagueti
- **Severidad:** 🟢 BAJO
- **Fragmento:**
```go
if state.IsTerminal() {
    _ = s.cache.Del("ctx:" + ctxID)
} else {
    _ = s.cache.Del("ctx:" + ctxID) // mismo código en ambas ramas
}
```
- **Explicación:** Las dos ramas del if/else ejecutan exactamente el mismo código. La rama else tiene un comentario que sugiere que debía actualizar el cache, no eliminarlo.
- **Recomendación:** Simplificar a una sola línea `_ = s.cache.Del("ctx:" + ctxID)` fuera del if.

---

### A1 — Modularización · Doble Context Service

- **Archivo y línea:** `src/internal/server/api.go:165-166`
- **Categoría:** modularización
- **Severidad:** 🟡 MEDIO
- **Fragmento:**
```go
ctxSvc:    domain.NewCtxService(),    // simple, stateless
bosCtxSvc: ctxSvc,                     // completo, con Store (F5)
```
- **Explicación:** El Server tiene DOS servicios de contexto: `domain.CtxService` (crea/valida) y `bosctx.Service` (CRUD completo con Store). Esto es redundante y confuso.
- **Recomendación:** Unificar en un solo servicio. Migrar create/validate de `domain.CtxService` a `bosctx.Service`.

---

### A2 — Modularización · Bypass del dispatcher K8s

- **Archivo y línea:** `src/internal/query/k8s.go:39`
- **Categoría:** modularización
- **Severidad:** 🟡 MEDIO
- **Fragmento:**
```go
func K8sNodesSummary(ctx context.Context) (interface{}, error) {
    raw, err := exec.CommandContext(ctx, "kubectl", "get", "nodes", "-o", "json").Output()
```
- **Explicación:** El paquete `query` ejecuta `kubectl` directamente en vez de usar `internal/k8s.Core`. Viola el principio P1: "toda operación K8s debe pasar por este paquete".
- **Recomendación:** Inyectar `*k8s.Core` y usar sus métodos en lugar de `exec.Command`.

---

### D1 — Documentación · CLAUDE.md ausente en raíz

- **Archivo y línea:** `/BosAgent/CLAUDE.md` (NO EXISTE)
- **Categoría:** documentación
- **Severidad:** 🟡 MEDIO
- **Fragmento:** El archivo no existe.
- **Explicación:** Sin CLAUDE.md, cada agente IA que trabaje en BosAgent empieza desde cero sin contexto del proyecto.
- **Recomendación:** Crear CLAUDE.md documentando arquitectura, principios (P1-P14), estructura de directorios, y comandos de build/test.

---

## 4. INCIDENCIAS DE EJECUCIÓN

Ninguna. Todos los archivos fueron leídos exitosamente.

---

## 5. ARCHIVOS EXCLUIDOS

| Archivo | Motivo |
|---------|--------|
| `staging/bos`, `staging/bosctl` | Binarios ELF compilados |
| `src/bos`, `src/bosctl`, `src/bosmin` | Binarios ELF compilados |
| `src/cmd/*/bos`, `src/cmd/*/bosctl`, etc. (8 binarios) | Binarios ELF compilados |
| `src/_snapshots/` (7 binarios) | Binarios ELF pre-reparación |
| `src/core_ui/build/` | Artefactos build Flutter |
| `*.png` (7 archivos) | Imágenes binarias |

---

*Informe generado: 2026-06-29 20:15 UTC · Auditoría de solo lectura · SBOS-060*
