# SBOS-014-EXT — Gestión del Ciclo de Vida de Prompts LLM y Métricas de Calidad de IA
## Extensión de SBOS-014 (SBOS AI Tools) y SBOS-015 (aiserver)

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-014-EXT-LLM
**Versión:** 1.0
**Estado:** ACTIVO
**Extiende:** SBOS-014-SBOS AI Tools-v4_0, SBOS-015-aiserver-v2_0
**Clasificación:** Especificación Técnica — IA Soberana

> ⚠️ **Prerrequisito:** Este documento aplica únicamente cuando el servidor S15 (aiserver) está instalado. S15 tiene `criticality: false` en el IAM Installer — es componente opcional. Todo lo descrito aquí solo se activa si el cliente ha instalado el aiserver.

---

## Índice

1. [Arquitectura de gestión de prompts separada del código](#1-arquitectura-prompts)
2. [Estructura de directorios y versionado semver](#2-estructura-directorios)
3. [Hot-reload de prompts con SIGUSR1](#3-hot-reload)
4. [Integración con Langfuse para trazabilidad](#4-integracion-langfuse)
5. [Métricas OTEL del ciclo de vida LLM](#5-metricas-otel)
6. [Proceso de evaluación y aprobación de nueva versión de prompt](#6-proceso-evaluacion)
7. [Rollback de prompts](#7-rollback)

---

## 1. Arquitectura de Gestión de Prompts Separada del Código

### 1.1 El problema del acoplamiento prompt-código

En implementaciones típicas de LLM, los prompts están hardcodeados en el código fuente o en archivos de configuración que forman parte del binario. Cambiar un prompt requiere recompilar y redesplegar el daemon. En SBOS AI Tools, esto es inaceptable porque:

- Los prompts de SBOS AI Tools son conocimiento de negocio ajustable por el cliente, no lógica de sistema
- El ciclo de vida del prompt (iteración rápida para mejorar calidad) es diferente al ciclo de vida del plugin `.so` (cambios de funcionalidad más espaciados)
- Un administrador avanzado debe poder ajustar prompts sin intervención de SKULL

### 1.2 Separación de responsabilidades

```
Plugin SBOS AI Tools (.so)        Prompts SBOS AI Tools (directorio)
─────────────────────────    ──────────────────────────────
Lógica de la ruta            Instrucciones al LLM
Llamadas a APIs              Contexto del negocio
Procesamiento de datos       Formato de respuesta esperado
Ciclo de vida: trimestral    Ciclo de vida: semanal/mensual
Versionado: semver del .so   Versionado: semver propio
Compilado en Go              Texto plano + YAML
```

### 1.3 Arquitectura del sistema de prompts

```
/etc/bos/blibs/bcompass/prompts/
  ├── CHANGELOG.md                         → historial de cambios de prompts
  ├── active -> v1.3/                      → symlink a la versión activa
  ├── v1.0/
  │   ├── agent/
  │   │   ├── system.txt                   → prompt de sistema para rutas agent
  │   │   └── context.yaml                 → variables de contexto inyectadas
  │   ├── flow/
  │   │   └── system.txt
  │   ├── analyst/
  │   │   ├── system.txt
  │   │   └── few_shot_examples.yaml       → ejemplos few-shot para el analista
  │   └── report/
  │       └── system.txt
  ├── v1.1/
  │   └── ...
  └── v1.3/                                → versión activa actual
      └── ...
```

El SBOS AI Tools siempre carga los prompts desde el symlink `active`. Cambiar la versión activa es tan simple como actualizar el symlink y enviar SIGUSR1.

---

## 2. Estructura de Directorios y Versionado Semver

### 2.1 Semver independiente para prompts

El versionado de prompts es **completamente independiente** del semver del plugin `.so` y del semver del binario SBOS AI Tools:

| Componente | Versión ejemplo | Cuándo incrementa MAJOR |
|---|---|---|
| Binario SBOS AI Tools | `2.4.1` | Cambios de arquitectura del daemon |
| Plugin `.so` (ruta específica) | `1.8.0` | Cambios en la API del plugin o lógica fundamental |
| **Prompts** | `1.3.0` | Cambio que altera el comportamiento observable para el usuario final |

**Reglas de incremento de versión para prompts:**

- **MAJOR** (`v2.0`): El prompt produce un tipo de respuesta diferente que requiere que el código del plugin que lo consume sea actualizado. Por ejemplo: cambiar de respuestas en prosa a respuestas en JSON estructurado.
- **MINOR** (`v1.3`): El prompt produce respuestas mejoradas pero compatibles. Por ejemplo: añadir más contexto, mejorar la calidad de las recomendaciones, añadir ejemplos few-shot.
- **PATCH** (`v1.3.1`): Correcciones menores — typos, aclaraciones, ajuste fino del tono.

### 2.2 Contenido de cada directorio de versión

```
/etc/bos/blibs/bcompass/prompts/v1.3/
  ├── metadata.yaml                → metadatos de la versión del prompt
  ├── agent/
  │   ├── system.txt               → prompt de sistema principal
  │   ├── context.yaml             → qué variables de contexto se inyectan
  │   └── few_shot_examples.yaml   → ejemplos few-shot (opcional)
  ├── flow/
  │   ├── system.txt
  │   └── context.yaml
  ├── analyst/
  │   ├── system.txt
  │   ├── context.yaml
  │   └── few_shot_examples.yaml
  └── report/
      ├── system.txt
      └── context.yaml
```

**Ejemplo de `metadata.yaml`:**

```yaml
# /etc/bos/blibs/bcompass/prompts/v1.3/metadata.yaml
version: "1.3.0"
compatible_plugin_versions: ">=1.5.0"   # Versiones del .so compatibles con este prompt
compatible_models:
  - "qwen2.5:14b"
  - "llama3.1:8b"
  - "mistral:7b"
author: "SKULL AI Team"
release_date: "2026-03-15"
changelog: |
  v1.3.0: Añadidos ejemplos few-shot al analista financiero.
          Mejorado el prompt de agent para reducir alucinaciones en consultas tributarias.
          Ajustado el tono del report para clientes del sector manufactura.
tested_with:
  dataset_size: 127   # Casos de prueba usados para validar esta versión
  pass_rate: 0.91     # 91% de casos dentro del rango esperado
```

**Ejemplo de `context.yaml`:**

```yaml
# /etc/bos/blibs/bcompass/prompts/v1.3/analyst/context.yaml

# Variables inyectadas automáticamente por SBOS AI Tools antes de llamar a Ollama
context_variables:
  - name: "current_fiscal_period"
    source: "bcompass_db.fiscal_context.current_period"
  - name: "company_name"
    source: "bcompass_db.tenant_config.company_name"
  - name: "user_role"
    source: "jwt_claims.bos_perm_base"
  - name: "user_department"
    source: "jwt_claims.department"

# Formato en el que se inyectan en el prompt
injection_format: |
  Contexto del negocio:
  - Empresa: {company_name}
  - Período fiscal activo: {current_fiscal_period}
  - Rol del usuario: {user_role}
  - Departamento: {user_department}
```

---

## 3. Hot-Reload de Prompts con SIGUSR1

### 3.1 El flujo de hot-reload

bcompass.service recibe SIGUSR1 para recargar su configuración sin reiniciar el proceso (análogo al SIGHUP del bKernel). El hot-reload de prompts está integrado en este mecanismo:

```bash
# Proceso de actualización de prompts sin downtime:

# PASO 1: Descargar/crear la nueva versión del prompt
cp -r /etc/bos/blibs/bcompass/prompts/v1.3 /etc/bos/blibs/bcompass/prompts/v1.4
# Editar los archivos en v1.4/

# PASO 2: Actualizar el symlink atomicamente
ln -sfn /etc/bos/blibs/bcompass/prompts/v1.4 /etc/bos/blibs/bcompass/prompts/active.new
mv -f /etc/bos/blibs/bcompass/prompts/active.new /etc/bos/blibs/bcompass/prompts/active

# PASO 3: Enviar SIGUSR1 para que SBOS AI Tools recargue los prompts
sudo kill -SIGUSR1 $(systemctl show bcompass --property=MainPID | cut -d= -f2)

# PASO 4: Verificar que el nuevo prompt está activo
journalctl -u bcompass --since "10 seconds ago" | grep "prompt_version"
# Esperado: "prompt_version=1.4.0 loaded successfully"
```

### 3.2 Comportamiento durante el hot-reload

Durante los ~200ms que tarda el hot-reload de prompts:
- Las rutas en vuelo al momento del SIGUSR1 completan con el prompt anterior
- Las nuevas rutas que inician después usan el prompt nuevo
- No hay pérdida de solicitudes

---

## 4. Integración con Langfuse para Trazabilidad

### 4.1 Langfuse como plataforma de observabilidad LLM

Langfuse (instalado en S15 aiserver — SBOS-015) es la plataforma de trazabilidad de LLM de SBOS. Registra cada llamada a Ollama con metadatos completos para análisis de calidad.

**Lo que Langfuse provee sin configuración adicional de Grafana:**
- Dashboard de uso por ruta y modelo
- Latencia P50/P95/P99 de llamadas LLM
- Tokens de entrada/salida por llamada
- Comparación A/B de versiones de prompt
- Score de calidad manual por operadores

### 4.2 Integración en SBOS AI Tools

Cada llamada que SBOS AI Tools realiza a Ollama genera automáticamente un trace en Langfuse:

```go
// Fragmento del motor SBOS AI Tools (Go) — integración con Langfuse SDK
// Este código existe en el route executor de SBOS AI Tools

let langfuse_client = LangfuseClient::new(
    &config.langfuse_host,    // http://langfuse.aiserver.svc.cluster.local
    &config.langfuse_public_key,
    &config.langfuse_secret_key,
);

let trace = langfuse_client.trace()
    .name(&route_name)
    .metadata(json!({
        "route_type": route_type,           // agent | flow | analyst | report
        "prompt_version": prompt_version,   // "1.3.0"
        "model": ollama_model,              // "qwen2.5:14b"
        "tenant_realm": tenant_realm,       // "bos-acme-corp"
        "user_role": user_role,
        "bcompass_version": BCOMPASS_VERSION,
    }))
    .build();

let generation = trace.generation()
    .name("ollama_completion")
    .model(ollama_model)
    .input(prompt_messages)
    .start();

let response = ollama_client.complete(prompt_messages).await?;

generation
    .output(&response.content)
    .usage(langfuse::Usage {
        input: response.prompt_tokens,
        output: response.completion_tokens,
        total: response.total_tokens,
    })
    .end();
```

### 4.3 Campos obligatorios en cada trace de Langfuse

| Campo | Valor | Propósito |
|---|---|---|
| `name` | Nombre de la ruta (`analyst_financial`, etc.) | Filtrar traces por ruta en Langfuse |
| `route_type` | `agent` / `flow` / `analyst` / `report` | Clasificar por tipo de ruta |
| `prompt_version` | Semver del prompt activo (`1.3.0`) | Correlacionar calidad con versión del prompt |
| `model` | Nombre del modelo Ollama | Comparar modelos |
| `tenant_realm` | Realm de Keycloak del tenant | Aislamiento de datos por cliente |
| `input_tokens` | Número de tokens del prompt | Monitoreo de costos (aunque sea local, el tiempo es costo) |
| `output_tokens` | Número de tokens de la respuesta | Monitoreo de verbosidad |
| `latency_ms` | Latencia total de la llamada Ollama | SLO de latencia |

### 4.4 Acceso a Langfuse

Langfuse expone una interfaz web en `https://langfuse.{dominio_cliente}/`. El acceso está protegido por Keycloak SSO. Solo los administradores con rol `bos_admin` pueden ver los traces.

---

## 5. Métricas OTEL del Ciclo de Vida LLM

Estas métricas son adicionales a las registradas en Langfuse. Se emiten al OTEL Collector del host (SBOS-027) y se almacenan en Prometheus para alertas en tiempo real.

### 5.1 Métricas definidas

```yaml
# Métricas emitidas por SBOS AI Tools al OTEL Collector (localhost:4317)

metrics:
  - name: bcompass_llm_calls_total
    type: counter
    description: "Total de llamadas al LLM (Ollama) desde SBOS AI Tools"
    labels:
      - route:   # Nombre de la ruta que hizo la llamada
      - model:   # Modelo Ollama usado (ej: qwen2.5:14b)
      - status:  # success | error | timeout

  - name: bcompass_llm_latency_ms
    type: histogram
    description: "Latencia de las llamadas a Ollama en milisegundos"
    buckets: [100, 500, 1000, 2000, 5000, 10000, 30000]
    labels:
      - route:
      - model:

  - name: bcompass_llm_tokens_total
    type: counter
    description: "Total de tokens procesados por el LLM"
    labels:
      - route:
      - type:   # input | output

  - name: bcompass_prompt_version
    type: gauge
    description: "Versión semver del prompt activo (para detectar cambios de versión)"
    labels:
      - route_type:   # agent | flow | analyst | report
    # El valor es la fecha unix de carga del prompt — para detectar cuándo cambió

  - name: bcompass_routes_executed_total
    type: counter
    description: "Total de rutas ejecutadas por tipo"
    labels:
      - route_type:
      - status:       # completed | failed | timeout
```

### 5.2 Alertas de Alertmanager para el aiserver

```yaml
# Añadir a prometheus-rules.yml de SBOS-024

groups:
  - name: bcompass_llm_alerts
    rules:
      - alert: SBOS AI ToolsLLMLatencyHigh
        expr: |
          histogram_quantile(0.95,
            rate(bcompass_llm_latency_ms_bucket[5m])
          ) > 5000
        for: 5m
        labels:
          severity: medium
          component: bcompass
        annotations:
          summary: "SBOS AI Tools LLM P95 latencia > 5 segundos"
          description: "La ruta {{ $labels.route }} con modelo {{ $labels.model }} tiene latencia P95 de {{ $value }}ms"

      - alert: SBOS AI ToolsLLMErrorRateHigh
        expr: |
          rate(bcompass_llm_calls_total{status="error"}[10m]) /
          rate(bcompass_llm_calls_total[10m]) > 0.1
        for: 10m
        labels:
          severity: high
          component: bcompass
        annotations:
          summary: "SBOS AI Tools LLM tasa de errores > 10%"
          description: "La ruta {{ $labels.route }} tiene {{ $value | humanizePercentage }} de errores en llamadas LLM"

      - alert: OllamaServerUnreachable
        expr: up{job="ollama"} == 0
        for: 2m
        labels:
          severity: high
          component: aiserver
        annotations:
          summary: "Ollama (aiserver S15) no responde"
          description: "SBOS AI Tools no puede alcanzar Ollama. Las rutas que requieren LLM fallarán."
```

---

## 6. Proceso de Evaluación y Aprobación de Nueva Versión de Prompt

### 6.1 Dataset de evaluación

Cada ruta de SBOS AI Tools tiene un dataset de evaluación mínimo de **20 casos por ruta**:

```yaml
# /etc/bos/blibs/bcompass/prompts/eval/analyst_financial_eval.yaml

dataset_version: "2026-03"
route: analyst_financial
cases:
  - id: "AF-001"
    input:
      query: "¿Cuáles son las facturas vencidas del último mes?"
      context:
        fiscal_period: "2026-Q1"
        company: "Acme Corp"
        user_role: "finance_manager"
    expected_output_contains:
      - "facturas vencidas"
      - "monto"
      - "fecha de vencimiento"
    expected_output_format: "lista estructurada"
    must_not_contain:
      - "no tengo acceso"
      - "no puedo"
      - "error"

  - id: "AF-002"
    input:
      query: "Muéstrame el flujo de caja proyectado para el próximo trimestre"
    expected_output_contains:
      - "proyección"
      - "trimestre"
    must_not_contain:
      - "datos insuficientes"
```

### 6.2 Proceso de aprobación

```
Desarrollo de prompt nuevo
          ↓
Ejecutar eval dataset completo:
  bos-ctl prompt eval --route=analyst --prompt-version=v1.4 --dataset=eval/analyst_financial_eval.yaml
          ↓
Criterio de aprobación: pass_rate >= 85%
          ↓                           ↓
     APROBADO                      RECHAZADO
          ↓                           ↓
A/B test en Langfuse (opcional)   Iterar el prompt
para comparar v1.3 vs v1.4        Volver al principio
          ↓
Actualizar symlink + SIGUSR1
          ↓
Monitorear métricas OTEL durante 30 min
          ↓
Confirmar que bcompass_llm_latency y error_rate no degradan
```

### 6.3 Herramienta de evaluación

```bash
# Comando de evaluación de prompts
bos-ctl prompt eval \
  --route analyst \
  --prompt-version v1.4 \
  --dataset /etc/bos/blibs/bcompass/prompts/eval/analyst_financial_eval.yaml \
  --model qwen2.5:14b \
  --output /tmp/eval-report-$(date +%Y%m%d).json

# El comando:
# 1. Carga los prompts de v1.4
# 2. Ejecuta cada caso del dataset contra Ollama
# 3. Evalúa si la respuesta cumple los criterios (contains, not_contains, format)
# 4. Genera un reporte JSON con pass_rate y detalle por caso

# Ejemplo de salida:
# {
#   "prompt_version": "1.4.0",
#   "route": "analyst_financial",
#   "total_cases": 20,
#   "passed": 18,
#   "failed": 2,
#   "pass_rate": 0.90,
#   "approved": true,
#   "failed_cases": ["AF-007", "AF-019"]
# }
```

---

## 7. Rollback de Prompts

El rollback de un prompt es inmediato y sin riesgo:

```bash
# PASO 1: Identificar la versión anterior
ls -la /etc/bos/blibs/bcompass/prompts/
# active -> v1.4
# v1.0, v1.1, v1.2, v1.3, v1.4

# PASO 2: Hacer rollback a la versión anterior
ln -sfn /etc/bos/blibs/bcompass/prompts/v1.3 /etc/bos/blibs/bcompass/prompts/active.new
mv -f /etc/bos/blibs/bcompass/prompts/active.new /etc/bos/blibs/bcompass/prompts/active

# PASO 3: Notificar a SBOS AI Tools
sudo kill -SIGUSR1 $(systemctl show bcompass --property=MainPID | cut -d= -f2)

# PASO 4: Registrar el rollback en el CHANGELOG
echo "$(date) [ROLLBACK] v1.4 → v1.3: Degradación de latencia detectada. Ver Langfuse trace IDs: ..." \
  >> /etc/bos/blibs/bcompass/prompts/CHANGELOG.md
```

El rollback no requiere recompilación ni reinicio del daemon. El tiempo de rollback efectivo es < 1 segundo.

---

## 8. Política de Retención de Versiones de Prompt

- Mantener al menos las últimas **5 versiones** en disco
- La versión activa nunca puede ser eliminada
- Eliminar versiones antiguas con `bos-ctl prompt prune --keep-last=5`
- Los logs de Langfuse retienen los prompts usados en cada trace — la trazabilidad no depende de que los archivos estén en disco

---

## 9. Referencias Cruzadas

- **SBOS-014** — SBOS AI Tools (arquitectura del daemon y sistema de rutas)
- **SBOS-015** — aiserver (Ollama, Langfuse, Qdrant, Embedding Worker)
- **SBOS-027** — Observabilidad de Daemons (OTEL Collector — destino de las métricas LLM)
- **SBOS-018** — Estándares (política de versionado general del proyecto)

---

## 10. Registro de Cambios

| Versión | Fecha | Autor | Descripción |
|---|---|---|---|
| 1.0 | Marzo 2026 | SKULL AI Team | Documento inicial — arquitectura de prompts separada del código, versionado semver independiente, integración Langfuse, métricas OTEL, proceso de evaluación con dataset mínimo |

---

*SKULL · SBOS · SBOS-014-EXT-LLM · v1.0 · Marzo 2026*
*Extiende: SBOS-014-SBOS AI Tools-v4_0 y SBOS-015-aiserver-v2_0*
*Prerrequisito: S15 aiserver instalado (componente opcional)*
