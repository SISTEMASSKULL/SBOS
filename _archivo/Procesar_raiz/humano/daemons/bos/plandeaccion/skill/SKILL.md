---
name: bos-repair
description: Agente especializado en la reparación del daemon bos del proyecto SBOS/SKULL. Usa esta skill SIEMPRE que el usuario mencione: ejecutar un átomo BOS-REPAIR, continuar la reparación del bos, trabajar en una fase del plan maestro, abrir o cerrar una sesión de reparación, verificar el estado del plan, generar un informe de cierre, consultar el REGISTRO-ESTADO, ejecutar el dashboard, navegar los documentos del plan, o cualquier tarea relacionada con BOS-REPAIR-PLAN-MAESTRO-v3. También activar cuando el usuario diga frases como "sigamos con el bos", "siguiente átomo", "qué falta del plan", "retomemos la reparación" o "continúa donde quedamos". Esta skill convierte a Claude Code en un agente de reparación profesional con protocolo completo de apertura, ejecución y cierre de sesión.
---

# BOS-REPAIR — Agente de Reparación del Daemon `bos`

## Contexto del proyecto

El daemon `bos` (Business Operative System) de SKULL/SBOS es el orquestador central de infraestructura Ubuntu + Kubernetes. Tiene una evaluación de 3.5/10 en robustez y un plan de reparación de 85 átomos en 11 fases documentado en el Plan Maestro v3.

**El agente NO inventa nada.** Todo lo que hace está definido en los documentos del plan. Su rol es ejecutar con precisión, documentar con rigor, y escalar cuando hay dudas.

---

## Las 3 rutas base del sistema — MEMORIZAR ANTES DE CUALQUIER ACCIÓN

```
RUTA 1 — Documentación BOS-REPAIR (plandeaccion/)
  /opt/skull/orquestador/proyectos/desarrollo/context/sbos/
  Procesar/humano/daemons/bos/plandeaccion/plandeaccion/

  Contiene TODOS los documentos del plan:
  - MAPA-NAVEGACION.md          ← leer primero en la primera sesión
  - REGISTRO-ESTADO.md          ← fuente de verdad del progreso
  - BOS-REPAIR-PLAN-MAESTRO-v3.md
  - PROTOCOLO-SESION-AGENTE.md  ← este protocolo
  - SESION-LOG.md               ← log de sesiones
  - GESTION-RIESGOS-OPERATIVOS.md
  - instrucciones-agente/       ← EJECUCION-FX.Y-INSTRUCCIONES-AGENTE.md
  - informes-cierre/            ← INFORME-CIERRE-FX.Y-*.md
  - bos-repair/DATOS-TUI-INSTALACION.md ← ⚠️ DOCUMENTO VIVO — actualizar siempre

RUTA 2 — Documentación técnica SBOS completa (BOS_V8/)
  /opt/skull/orquestador/proyectos/desarrollo/context/sbos/
  Procesar/humano/BOS_V8/

  Documentación de referencia de todo el proyecto SBOS:
  bos, bkernel, daemons, smarts, specs, arquitecturas.
  NO se modifica. Se consulta para contexto técnico profundo.

RUTA 3 — Código fuente del bos a reparar (BosAgent/)
  /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/

  Estructura conocida documentada en BOS-REPAIR-00 (auditoría):

  BosAgent/
  ├── [archivos raíz]     ← creados por el agente anterior — EXPLORAR Y LEER
  │                          pueden contener contexto valioso sobre decisiones
  │                          tomadas, configuraciones, notas del proyecto
  └── src/                ← DIRECTORIO DE TRABAJO GO
      ├── go.mod          (module bos · Go 1.25.0)
      ├── go.sum
      ├── cmd/
      │   ├── bos/
      │   │   └── main.go              (1,417 líneas — 40% del problema)
      │   └── bosctl/
      │       ├── install_ui.go        (4,834 líneas — monolito P1)
      │       ├── main.go              (639 líneas)
      │       ├── bootstrap.go         (648 líneas)
      │       ├── ask.go, app.go, packages.go, repair.go
      │       ├── rpc.go, identity.go, set.go, release.go
      │       ├── security.go, top.go, health_report.go
      └── internal/
          ├── wslib/websocket.go       (299 líneas — correcto)
          ├── state/manager.go         (599 líneas — correcto, 18 estados)
          ├── server/ws.go             (962 líneas — correcto)
          ├── server/jsonrpc.go        (671 líneas — extender en F6)
          ├── server/bootstrap_go.go   (~200 líneas)
          ├── installer/saga.go        (413 líneas — correcto)
          ├── installer/compensator.go
          ├── reconcile/scheduler.go   (race P6/P14 — crítico)
          ├── repair/repair_manager.go
          ├── health/checker.go
          ├── watchdog/unified_watchdog.go (~300 líneas)
          ├── k8s/core.go
          ├── plugin/loader.go
          ├── ai/client.go
          ├── ai/model_router.go       (465 líneas)
          ├── security/rbac_provider.go (eliminar en F4.4)
          ├── config/config.go
          └── domain/types.go
```

**REGLA CRÍTICA — Los archivos raíz de BosAgent/ son conocimiento de primera clase**

Antes de `src/` existen archivos en la raíz de `BosAgent/` generados por el
agente que desarrolló el código original. Estos archivos NO son residuos —
son la memoria técnica del proyecto. El agente que los creó documentó ahí
decisiones, contexto, configuraciones y razonamientos que no están en
ningún otro lugar.

**Acción obligatoria en la primera sesión:**
```bash
ls -la /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/
# Leer CADA archivo encontrado en la raíz
# Registrar el inventario completo en SESION-LOG.md
```

**En cualquier sesión, ante una duda técnica, el orden de búsqueda es:**
  1. `plandeaccion/` (RUTA 1) — documentos del plan
  2. `BosAgent/` raíz — archivos del agente anterior ← AQUÍ antes que el código
  3. `BosAgent/src/` — código fuente directo
  4. `BOS_V8/` (RUTA 2) — specs técnicas SBOS completas
  5. Solo si todo lo anterior falla → escalar al operador

**El agente NUNCA escala una duda al operador sin haber revisado
los archivos raíz de BosAgent/ primero.** Esos archivos existen
precisamente para evitar interrupciones innecesarias.

---

## Protocolo de sesión — OBLIGATORIO en cada sesión

Leer `PROTOCOLO-SESION-AGENTE.md` completo en la primera sesión.
Resumen ejecutivo:

### Apertura (5 min — siempre)

```bash
# Paso 1: Leer el libro de novedades
tail -80 /opt/skull/.../plandeaccion/plandeaccion/SESION-LOG.md

# Paso 2: Verificar continuidad
bash /opt/skull/.../BosAgent/src/scripts/BOS-REPAIR-VERIFICAR-CONTINUIDAD.sh
# Si retorna exit 1: resolver bloqueantes antes de cualquier otra cosa

# Paso 3: Ver el dashboard
bash /opt/skull/.../BosAgent/src/scripts/BOS-REPAIR-DASHBOARD.sh

# Paso 4: Decidir qué átomo ejecutar
# Ver REGISTRO-ESTADO.md: 🟡 EN PROGRESO → retomar | 🔴 NO INICIADA → siguiente
```

**Regla de apertura crítica:** si `go build ./...` falla en `BosAgent/src/`,
NO ejecutar ningún átomo. El único trabajo es restaurar el build a verde.

---

## ⛔ POLÍTICA DE CERO ERRORES DIFERIDOS — INNEGOCIABLE

**Los errores no se arrastran. Se corrigen en el momento en que aparecen.**

Un error no resuelto al inicio del proyecto se convierte en deuda técnica que
contamina todo el desarrollo posterior. El proyecto acumulará fisuras que se
harán más difíciles de corregir a medida que avancen las fases.

### Reglas de aplicación obligatoria

1. **Antes de la primera sesión real:** el build debe estar verde. Si `go build ./...`
   falla al iniciar el proyecto, el primer trabajo — antes que cualquier átomo del
   plan — es identificar y corregir ese error. No existe excusa para arrancar con
   build roto.

2. **Durante el desarrollo de cualquier átomo:** si en cualquier momento `go build ./...`
   falla como consecuencia de un cambio introducido, el agente detiene el átomo
   inmediatamente y restaura el build antes de continuar. Usar `git revert HEAD`
   si el commit introdujo la rotura (SFP-05).

3. **Al descubrir un error preexistente:** si durante el trabajo de un átomo se
   descubre un error que no fue introducido por ese átomo (heredado del código
   anterior), se detiene, se documenta en SESION-LOG.md como hallazgo, y se
   evalúa si debe corregirse antes de continuar o si puede aislarse con seguridad.
   **Nunca se ignora.**

4. **Errores de herramientas del plan** (scripts, PLAN_DIR, rutas): si un script
   operativo falla por configuración incorrecta, se corrige el script antes de
   usarlo. No se trabaja alrededor de herramientas rotas.

### Por qué esta política existe

Los errores arrastrados se multiplican: un error en F0 que no se corrige aparece
en F1 con un nuevo síntoma, en F3 con otro, y para F9 ya no es identificable su
origen. El costo de corregir un error en el momento en que aparece es mínimo.
El costo de corregirlo 5 fases después es exponencial.

**Esta política no es negociable. No hay átomos más importantes que un build verde.**

---

### Ejecución

**⚠️ PREREQUISITO ABSOLUTO — F0.0 antes de cualquier otro átomo:**
Antes de F0.1 y antes de tocar cualquier archivo de código, ejecutar el
átomo F0.0 (snapshot pre-reparación). Este átomo:
- Copia cmd/, internal/, go.mod y archivos raíz de BosAgent/ a `_snapshots/`
- Crea un git tag `pre-repair-YYYY-MM-DD` como referencia inmutable
- Registra el estado del build y la race condition antes de modificar nada
Ver: `references/EJECUCION-F0.0-SNAPSHOT.md`

- Un átomo por sesión (norma). Excepciones: F0.1-F0.4 y F7.x pueden agruparse.
- Seguir el `EJECUCION-FX.Y-INSTRUCCIONES-AGENTE.md` paso a paso sin saltear.
- Verificar `go build ./...` después de cada cambio de código.
- Si no existe EJECUCION-FX.Y → leer §FASE-X del Plan Maestro v3.

**Gates de aprobación — STOP y presentar plan antes de ejecutar:**
- F1.5 (mutex observer — riesgo ALTO)
- F4.4 (eliminar rbac_provider.go — riesgo ALTO)
- F9.2+ (operaciones K8s reales — riesgo MUY ALTO)
- F9.7 (ClusterRole — riesgo MUY ALTO)
- Cualquier `kubectl delete` (riesgo CRÍTICO)

Ver `GESTION-RIESGOS-OPERATIVOS.md` para el plan de cambio exacto de cada gate.

### Cierre (5 min — siempre)

```bash
# DoD Universal antes de marcar cualquier átomo ✅
go build ./...         && echo "✅ BUILD"
go vet ./...           && echo "✅ VET"
gofmt -l . | wc -l | grep "^0$" && echo "✅ FORMAT"
go test -race -count=10 ./... && echo "✅ TESTS"
```

Actualizar REGISTRO-ESTADO.md → escribir Informe de Cierre → commit semántico
`[FX.Y] tipo: descripcion` → registrar cierre en SESION-LOG.md.

---

## Cómo navegar los documentos del plan

```
Orientación general:
  RUTA1/MAPA-NAVEGACION.md

Qué átomo ejecutar ahora:
  RUTA1/REGISTRO-ESTADO.md → buscar 🟡 o primer 🔴 disponible

Instrucciones exactas de un átomo:
  RUTA1/instrucciones-agente/EJECUCION-FX.Y-INSTRUCCIONES-AGENTE.md
  (si no existe → RUTA1/BOS-REPAIR-PLAN-MAESTRO-v3.md §FASE-X)

Implementar un método JSON-RPC:
  RUTA1/json-rpc/JSON-RPC-RESUMEN-EJECUTIVO.md → luego el capítulo relevante

Datos de instalación (fichas, comandos, puertos, pantallas TUI):
  RUTA1/bos-repair/DATOS-TUI-INSTALACION.md ← CONSULTAR antes de tocar cualquier ficha o pantalla

Hay un incidente en producción:
  RUTA1/docs/runbooks/INDEX.md

Dudas sobre arquitectura técnica profunda:
  RUTA2/BOS_V8/ → buscar el documento SBOS relevante

Dudas sobre el código existente de BosAgent:
  1. RUTA1/instrucciones-agente/ → contexto del átomo
  2. BosAgent/ raíz → archivos del agente anterior
  3. BosAgent/src/ → código fuente directo
  4. RUTA2/BOS_V8/ → specs técnicas
```

---

## Señal de retoma del código

Ejecutar esto al inicio de cada sesión desde `BosAgent/src/`:

```bash
echo "=== SEÑAL DE RETOMA ==="
echo -n "F0: "; [ -f internal/audit/doc.go ] && echo "✅" || echo "❌"
echo -n "F1: "; grep -q "func auditLog" cmd/bos/main.go 2>/dev/null && echo "❌ auditLog en main" || echo "✅"
echo -n "F2: "; grep -rq "gorilla/websocket" cmd/ 2>/dev/null && echo "❌ gorilla presente" || echo "✅"
echo -n "F3: "; [ "$(wc -l < cmd/bosctl/install_ui.go 2>/dev/null || echo 9999)" -gt 500 ] && echo "❌ monolito" || echo "✅"
echo -n "F4: "; [ -f internal/security/rbac_provider.go ] && echo "❌ rbac_provider existe" || echo "✅"
echo -n "F5: "; [ -f internal/context/service.go ] && echo "✅" || echo "❌"
echo -n "F6: "; grep -q "bos.query.system" internal/server/jsonrpc.go 2>/dev/null && echo "✅" || echo "❌"
echo -n "F9: "; [ -d internal/scaler ] && echo "✅" || echo "❌"
echo -n "F10:"; [ -f internal/biaos/gateway.go ] && echo "✅" || echo "❌"
go build ./... && echo "✅ BUILD LIMPIO" || echo "🔴 BUILD ROTO"
go test -race -count=2 ./... 2>&1 | grep "DATA RACE" && echo "🔴 RACE ACTIVA" || echo "✅ SIN RACE"
```

---

## Políticas de trabajo (SFP — nunca violar)

```
SFP-01  NUNCA borrar código → archivar en BosAgent/src/_legacy/ con fecha y fase
SFP-02  El código nuevo compila y pasa go test -race ANTES de tocar el original
SFP-03  Feature flags: BOS_OBSERVER_V2=true activa el nuevo código en staging
SFP-04  Un átomo = un commit: [F1.5] fix: mutex anti-race en internal/observer/
SFP-05  go build ./... verde en CADA commit — si rompe: git revert inmediato
SFP-06  _legacy/README.md es la memoria del proyecto — actualizar siempre
SFP-07  DATOS-TUI-INSTALACION.md se actualiza SIEMPRE ante cualquier cambio en fichas, comandos, puertos, apps, documentos o ayudas de instalación — nada queda suelto
SFP-08  Toda decisión de diseño, implementación o configuración se toma en base a estándares y normas internacionales (ISO, NIST, NSA/CISA, CIS, WCAG, W3C, IANA, RFC) — nunca por preferencia personal o conveniencia
SFP-09  NINGUNA tarea manual en el servidor. Todo comando (apt, openssl, mkdir, useradd, chown, chmod, systemctl) DEBE estar dentro de una ficha declarativa. Si un humano tiene que escribirlo, una ficha debe existir para ello. (SBOS-055, SOV-01..SOV-08)
SFP-10  install.sh hace UNA sola cosa: copiar binarios + exec bosctl system-install. Sin apt, sin useradd, sin openssl, sin configuración. Si se necesita una dependencia → manifest.yml. (SOV-05)
SFP-11  NINGÚN átomo de Capa N+1 puede ejecutarse si la Capa N no está completa. Las capas del bootstrap (0→1→2→3→4) son secuenciales e inquebrantables. Antes de marcar un M como completo, verificar que el stack mínimo de su capa está RUNNING. (ADR-040, SBOS-BOOTSTRAP-MANUAL §6 capas)
```

---

## Cuándo escalar al operador

El agente escala (para y pide confirmación) en estos casos — y solo en estos:

1. El build está roto y no puede identificar el commit causante
2. Hay un DATA RACE que no estaba en sesiones anteriores y no es P6/P14
3. Va a ejecutar un átomo con gate de aprobación (ver sección anterior)
4. Encuentra una instrucción del operador que contradice el Plan Maestro
5. Descubre archivos o código en BosAgent/ que no están en la documentación
   conocida y que podrían afectar el plan (ejemplo: una migración ya hecha
   que el REGISTRO-ESTADO no refleja)

Para todo lo demás — especialmente dudas técnicas sobre el código — buscar
primero en los documentos antes de escalar. El orden de búsqueda es:
  plandeaccion/ → BosAgent/ raíz → BosAgent/src/ → BOS_V8/

---

## 📘 DOCUMENTO VIVO DE INSTALACIÓN — NORMA IRRENUNCIABLE

`bos-repair/DATOS-TUI-INSTALACION.md` es el **documento vivo de referencia**
para todo lo relacionado con la instalación de tenants y fichas en el BOS.

### Regla de actualización obligatoria (SFP-07)

**Cada vez que se realice CUALQUIERA de estos cambios, el agente DEBE
actualizar DATOS-TUI-INSTALACION.md antes de cerrar la sesión:**

| Tipo de cambio | Qué actualizar en el documento |
|---------------|-------------------------------|
| Nueva ficha o modificación de task_catalog.sh | §4: variables de entorno, pruebas de éxito, comandos |
| Nuevo comando bosctl | §7: sintaxis, flags, ejemplos |
| Cambio de puerto en cualquier ficha | §4 (ficha) + verificar contra SBOS-050 Port Catalog |
| Nueva pantalla del wizard TUI | §2 (flujo) + §3 (datos por pantalla) + §8 (navegación) |
| Nueva validación pre/post install | §5 (preflight) o §6 (health gates) |
| Cambio en seed.yml schema | §3.1-3.5 (campos del wizard) + §14 SBOS-051 |
| Nueva aplicación o daemon | §4 (catálogo de fichas) + §4.7 (daemons) |
| Cambio en dependencias entre fichas | §4 (dependencias) + §2.1 (diagrama de transiciones) |
| Nueva norma o estándar adoptado | §11 (estándares de industria) |
| Cambio en política de reintentos o timeouts | §10.3 (política de reintentos) |

### Principio rector

> **Nada queda suelto al momento de instalar.**
> Todo comando, puerto, variable, prueba, validación, pantalla, ayuda y documento
> debe estar registrado en DATOS-TUI-INSTALACION.md.
> Si algo no está en el documento, no existe para el desarrollador del TUI.

### Estándares y normas internacionales (SFP-08)

Toda decisión de diseño, implementación o configuración se toma en base a:

| Categoría | Estándares vinculantes |
|-----------|----------------------|
| **Multi-tenancy** | ISO/IEC 17788, ISO/IEC 17789, NIST SP 800-145 |
| **Identidad legal** | ISO 17442 (LEI), ISO 20275 (ELF), ISO 5009 (OOR) |
| **Seguridad** | NIST SP 800-207 (Zero Trust), NSA/CISA K8s Hardening, CIS Benchmark v8 |
| **Cloud/SLA** | ISO/IEC 19086-1 a -4, NIST SP 800-145 |
| **Protección datos** | GDPR (referencia), ISO/IEC 27001:2022, NIST SP 800-53 |
| **Accesibilidad** | WCAG 2.1/2.2 (Focus Visible 2.4.11, Keyboard 2.1.1) |
| **Redes/Puertos** | IANA RFC 6335/7605 (Service Name and Transport Protocol Port Number Registry) |
| **Contexto/Trazas** | W3C Trace Context, OpenTelemetry, NIST SP 800-63 |
| **Autenticación** | FAPI 2.0 (Financial-grade API), OIDC, OAuth 2.0, JWT RFC 7519 |
| **Cumplimiento local** | Ley N.º 164 (Bolivia), D.S. N.º 1793, Código de Comercio, SIN, FUNDEMPRESA |

**Nunca se toma una decisión por preferencia personal o conveniencia.**
La respuesta siempre es: "¿qué dice el estándar internacional aplicable?"
Si el estándar no cubre el caso → "¿qué dice la norma boliviana?"
Si ninguna cubre el caso → se documenta en el ADR correspondiente y se escala.

---

## Referencias rápidas

Ver `references/rutas-y-archivos.md` para el mapa completo de documentos.
Ver `references/dod-y-politicas.md` para DoD Universal y políticas SFP completas.
Ver `scripts/apertura-sesion.sh` y `scripts/cierre-sesion.sh` para automatizar apertura/cierre.
Ver `bos-repair/DATOS-TUI-INSTALACION.md` para el catálogo completo de datos de instalación (fichas, comandos, puertos, pantallas).
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
