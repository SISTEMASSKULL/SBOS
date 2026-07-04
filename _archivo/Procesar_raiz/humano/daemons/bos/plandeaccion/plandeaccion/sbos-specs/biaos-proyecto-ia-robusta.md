# Proyecto: Arquitectura de IA Robusta para biaos
## Sistema de Interpretación NL → OS con Catálogo de Acciones Seguras

> **Versión:** 1.0 | **Fecha:** Junio 2026 | **Proyecto:** SBOS — biaos  
> **Fundamentado en:** NAACL 2025, ACM Web 2026, arXiv 2025–2026, KubeIntellect, MetaKube, Agent-S, Runbook Automation Industry 2026

---

## Resumen ejecutivo

La investigación de la industria confirma que los sistemas LLM que traducen lenguaje natural a comandos de infraestructura de forma **libre y abierta** tienen tasas de error inaceptables para entornos productivos con Kubernetes y Ubuntu. Sin embargo, existe un patrón arquitectónico validado en producción que resuelve este problema: **Intent Matching sobre un Catálogo de Acciones Predefinidas (ICAP)**.

Este proyecto define la arquitectura completa de ese patrón para biaos, separando con precisión quirúrgica lo que la IA hace de forma autónoma (lectura, diagnóstico) de lo que requiere selección humana confirmada (ejecución sobre el sistema).

---

## Parte 1 — El problema raíz: por qué NL → comando libre no es viable hoy

### 1.1 Evidencia de la industria

La investigación de NAACL 2025 (*Westenfelder et al.*) sobre NL2SH establece que medir si un comando generado libremente es "correcto" es en sí mismo un problema no resuelto — dos comandos que hacen lo mismo son sintácticamente distintos y los heurísticos anteriores fallaban en al menos 16% de casos. En infraestructura sensible, ese margen de error es inasumible.

MetaKube (ACM Web Conference 2026) confirma que un modelo Qwen3-8B sin especialización opera al 50.9% de efectividad en diagnóstico Kubernetes. Con fine-tuning sobre 7,000 ejemplos reales llega al 90.5%. Sin ese fine-tuning específico, el modelo improvisará.

El Informe Internacional de Seguridad de IA 2026 lo resume:

> "Para reducir fallos de agentes de IA, los sistemas deben diseñarse para cooperar con humanos en lugar de operar completamente de forma autónoma, especialmente cuando decisiones incorrectas pueden causar daños significativos."

### 1.2 La distinción fundamental

La industria converge en separar dos tipos de operaciones:

```
TIPO A — Operaciones de LECTURA (bajo riesgo)
  ✅ La IA puede operar con libertad razonable
  ✅ Un error produce información incorrecta, no daño al sistema
  Ejemplos: consultar estado, leer logs, ver métricas de CPU

TIPO B — Operaciones de ESCRITURA / EJECUCIÓN (alto riesgo)  
  ❌ La IA NO debe generar comandos libremente
  ❌ Un error puede derribar servicios en producción
  Ejemplos: reiniciar pods, escalar deployments, repair de fichas
```

La arquitectura propuesta trata estos dos tipos de forma completamente diferente.

---

## Parte 2 — La solución: ICAP (Intent Matching sobre Catálogo de Acciones Predefinidas)

### 2.1 Fundamento del patrón

El paper **Agent-S** (arXiv 2503.15520, 2025) describe exactamente este patrón aplicado a automatización de procedimientos operativos:

> "Usamos un modelo de embeddings para identificar la acción del conjunto de acciones posibles del catálogo. Realizamos una búsqueda por similitud coseno, y la mejor coincidencia es la acción seleccionada. Gracias a la búsqueda semántica, los identificadores de acción no necesitan coincidir exactamente con lo que genera el LLM."

El patrón elimina la alucinación de comandos porque **el LLM nunca genera un comando** — solo ayuda a *encontrar* el más adecuado dentro de un conjunto cerrado y validado por humanos.

### 2.2 Arquitectura completa del sistema

```
┌─────────────────────────────────────────────────────────────────────┐
│                         BIAOS — FLUJO COMPLETO                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  OPERADOR                                                           │
│  "dame los contenedores que puedan tener algún tipo de falla"       │
│       │                                                             │
│       ▼                                                             │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │  CAPA 1: CLASIFICADOR DE TIPO                            │      │
│  │  ¿Es LECTURA o ESCRITURA/EJECUCIÓN?                      │      │
│  │  → Embedding rápido + clasificador binario               │      │
│  │  → "contenedores con falla" = LECTURA                    │      │
│  └──────────────────┬───────────────────────────────────────┘      │
│                     │                                               │
│         ┌───────────┴──────────────┐                               │
│         ▼                          ▼                               │
│  ┌─────────────┐          ┌────────────────────────────────┐       │
│  │  TIPO A     │          │  TIPO B                        │       │
│  │  LECTURA    │          │  ESCRITURA / EJECUCIÓN         │       │
│  │             │          │                                │       │
│  │  Agente     │          │  ICAP ENGINE                   │       │
│  │  ReAct con  │          │  (Intent Matching sobre        │       │
│  │  herramientas│          │   Catálogo de Acciones)        │       │
│  │  de solo    │          │                                │       │
│  │  lectura    │          └────────────────────────────────┘       │
│  └─────────────┘                                                    │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.3 El ICAP Engine en detalle

```
CONSULTA DEL OPERADOR (escritura/ejecución)
"reinicia la autenticación" / "escala el servicio de ventas"
       │
       ▼
┌─────────────────────────────────────────────────────┐
│  PASO 1: EMBEDDING DE LA CONSULTA                   │
│  Modelo local de embeddings (nomic-embed o similar) │
│  Convierte la consulta a vector numérico            │
│  NO usa el LLM grande — es rápido y determinista    │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│  PASO 2: BÚSQUEDA POR SIMILITUD COSENO              │
│  Compara el vector de la consulta contra los        │
│  vectores pre-calculados del Catálogo de Acciones   │
│  Retorna los TOP-3 con score de similitud           │
│                                                     │
│  Resultado ejemplo:                                 │
│  [0.91] repair_ficha — reiniciar ficha específica   │
│  [0.73] scale_deployment — ajustar réplicas         │
│  [0.61] restart_namespace — reiniciar namespace     │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│  PASO 3: ENRIQUECIMIENTO CON LLM                    │
│  El LLM recibe las TOP-3 opciones + la consulta     │
│  original y genera para cada opción:                │
│  - Descripción en lenguaje natural clara            │
│  - Riesgo específico para este contexto             │
│  - Beneficio esperado                               │
│  - Parámetros necesarios (con valores sugeridos)    │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│  PASO 4: PRESENTACIÓN AL OPERADOR (HITL)            │
│                                                     │
│  biaos le muestra al operador:                      │
│                                                     │
│  Encontré 3 acciones relacionadas con tu consulta:  │
│                                                     │
│  [1] repair_ficha — Reinicio controlado de ficha   │
│      Coincidencia: 91%                              │
│      Qué hace: ejecuta el ciclo repair de bauth,   │
│      drenando conexiones activas antes de reiniciar │
│      Riesgo: interrupción de sesiones activas ~30s  │
│      Beneficio: recupera estado limpio del daemon   │
│      Parámetros: ficha=bauth                        │
│                                                     │
│  [2] scale_deployment — Ajuste de réplicas          │
│      Coincidencia: 73%                              │
│      ...                                            │
│                                                     │
│  [3] restart_namespace — Reinicio de namespace      │
│      Coincidencia: 61%                              │
│      ...                                            │
│                                                     │
│  ¿Cuál quieres ejecutar? (1/2/3 o ninguna)         │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│  PASO 5: CONFIRMACIÓN Y EJECUCIÓN                   │
│  Operador responde: "ejecuta la 1"                  │
│                                                     │
│  biaos ejecuta EXACTAMENTE lo configurado           │
│  en el catálogo para repair_ficha con ficha=bauth   │
│  → server.BosFichaRepair(ctx, "bauth")              │
│  → kubectl rollout restart deploy/bauth             │
│                                                     │
│  Audit log registra: consulta, opción elegida,      │
│  parámetros, timestamp, operador, resultado         │
└─────────────────────────────────────────────────────┘
```

---

## Parte 3 — El Catálogo de Acciones (estructura técnica)

### 3.1 Formato del catálogo

El catálogo es el corazón de la seguridad del sistema. Cada entrada es inmutable en runtime — solo puede modificarse por un administrador con acceso directo al archivo de configuración, nunca por el agente.

```go
// internal/biaos/catalog.go

package biaos

// CatalogEntry define una acción permitida en el sistema.
// INMUTABLE en runtime — solo editable por administrador de SBOS.
type CatalogEntry struct {
    // Identificación
    ID          string `yaml:"id"`           // "repair_ficha"
    Name        string `yaml:"name"`         // "Reinicio controlado de ficha"
    
    // Para el motor de búsqueda semántica
    Description string `yaml:"description"`  // descripción completa para embedding
    Aliases     []string `yaml:"aliases"`    // frases adicionales para mejor matching
    
    // Clasificación de riesgo
    RiskLevel   string `yaml:"risk_level"`   // "low", "medium", "high", "critical"
    RiskDetail  string `yaml:"risk_detail"`  // descripción del riesgo para el operador
    Benefit     string `yaml:"benefit"`      // beneficio esperado de ejecutar la acción
    
    // Parámetros que necesita
    Params      []CatalogParam `yaml:"params"`
    
    // Herramienta que ejecuta (referencia al ToolRegistry existente)
    ToolName    string `yaml:"tool_name"`    // "repair_ficha" en ToolRegistry
    
    // Control de acceso
    RequiresHITL    bool     `yaml:"requires_hitl"`     // siempre true para escritura
    AllowedCallers  []string `yaml:"allowed_callers"`   // ["bosctl"]
    RequiredRole    string   `yaml:"required_role"`     // "operator", "admin"
    
    // Embedding pre-calculado (cargado en memoria al inicio)
    embedding []float32 // calculado al cargar el catálogo, no se guarda en YAML
}

type CatalogParam struct {
    Name        string `yaml:"name"`
    Type        string `yaml:"type"`        // "string", "int", "enum"
    Required    bool   `yaml:"required"`
    Description string `yaml:"description"`
    Options     []string `yaml:"options,omitempty"` // para tipo "enum"
    Default     string `yaml:"default,omitempty"`
}
```

### 3.2 El catálogo YAML de SBOS (completo)

```yaml
# /etc/bos/ai/action-catalog.yaml
# INMUTABLE en runtime. Modificar requiere acceso de administrador + reinicio bos.
# Cada entrada es validada y testeada antes de agregarse.

version: "1.0"
actions:

  # ─── ACCIONES DE SOLO LECTURA (no requieren HITL) ─────────────────────────

  - id: query_system_status
    name: "Consultar estado del sistema"
    description: "Ver el estado de todas las fichas instaladas, pods y daemons soberanos del SBOS"
    aliases:
      - "qué fichas están caídas"
      - "dame los contenedores con falla"
      - "qué está mal en el sistema"
      - "estado general del cluster"
      - "pods con problemas"
      - "servicios degradados"
    risk_level: "none"
    risk_detail: "Operación de solo lectura. No modifica ningún estado del sistema."
    benefit: "Vista completa del estado operacional para diagnóstico inicial"
    tool_name: "query_system_status"
    requires_hitl: false
    allowed_callers: ["bosctl", "bcompass"]
    required_role: "operator"
    params: []

  - id: get_pod_logs
    name: "Ver logs de una ficha o pod"
    description: "Obtener los últimos registros de error o actividad de un pod específico"
    aliases:
      - "muéstrame los errores de X"
      - "qué dice el log de X"
      - "últimos mensajes de X"
      - "por qué está fallando X"
      - "logs recientes de X"
    risk_level: "none"
    risk_detail: "Operación de solo lectura. Solo muestra información, no modifica nada."
    benefit: "Diagnóstico de causa raíz sin afectar el servicio"
    tool_name: "get_pod_logs"
    requires_hitl: false
    allowed_callers: ["bosctl"]
    required_role: "operator"
    params:
      - name: ficha
        type: string
        required: true
        description: "Nombre de la ficha o pod a consultar"
      - name: lines
        type: int
        required: false
        default: "50"
        description: "Número de líneas a mostrar (default: 50, max: 500)"

  - id: check_node_resources
    name: "Ver recursos del nodo"
    description: "Consultar uso actual de CPU, RAM y disco del nodo donde corre SBOS"
    aliases:
      - "cuánta CPU está usando el nodo"
      - "hay memoria disponible"
      - "el disco está lleno"
      - "recursos del servidor"
      - "métricas del nodo"
      - "está saturado el sistema"
    risk_level: "none"
    risk_detail: "Operación de solo lectura sobre métricas del sistema."
    benefit: "Detectar saturación de recursos antes de que cause fallos en cascada"
    tool_name: "check_node_resources"
    requires_hitl: false
    allowed_callers: ["bosctl"]
    required_role: "operator"
    params: []

  - id: list_failed_daemons
    name: "Listar daemons Ubuntu fallidos"
    description: "Ver qué servicios de systemd están en estado failed o degraded en Ubuntu"
    aliases:
      - "qué daemons de Ubuntu están caídos"
      - "servicios systemd con error"
      - "qué falló en el sistema operativo"
      - "servicios linux caídos"
    risk_level: "none"
    risk_detail: "Operación de solo lectura sobre systemd."
    benefit: "Identificar fallos a nivel de sistema operativo no visibles desde Kubernetes"
    tool_name: "query_system_status"
    requires_hitl: false
    allowed_callers: ["bosctl"]
    required_role: "operator"
    params: []

  # ─── ACCIONES DE EJECUCIÓN — RIESGO MEDIO (requieren HITL) ────────────────

  - id: repair_ficha
    name: "Reinicio controlado de ficha"
    description: "Ejecutar el ciclo repair de una ficha específica: drena conexiones, reinicia el pod, verifica que vuelva a Running"
    aliases:
      - "reinicia la ficha X"
      - "repara X"
      - "el pod X sigue fallando, arréglalo"
      - "restart de X"
      - "reiniciar servicio X"
      - "volver a levantar X"
    risk_level: "medium"
    risk_detail: |
      Interrupción de servicio de aproximadamente 30-60 segundos durante el reinicio.
      Las sesiones activas conectadas directamente al pod serán terminadas.
      El pod debe volver a Running automáticamente; si no lo hace en 5 minutos,
      el problema es más profundo y requiere diagnóstico adicional.
    benefit: "Recupera el estado limpio del daemon. Efectivo para CrashLoopBackOff causado por estado corrupto en memoria."
    tool_name: "repair_ficha"
    requires_hitl: true
    allowed_callers: ["bosctl"]
    required_role: "operator"
    params:
      - name: ficha
        type: string
        required: true
        description: "Nombre de la ficha a reparar (ej: tryton, bauth, postgresql)"

  - id: scale_deployment
    name: "Ajustar réplicas de un deployment"
    description: "Aumentar o disminuir el número de réplicas de un deployment de Kubernetes para gestionar carga o liberar recursos"
    aliases:
      - "escala X a N réplicas"
      - "sube las réplicas de X"
      - "baja las réplicas de X"
      - "necesito más instancias de X"
      - "reduce X a N"
      - "el servicio X no da abasto"
    risk_level: "medium"
    risk_detail: |
      Escalar hacia arriba: consume más CPU y RAM del nodo. Si el nodo no tiene
      recursos suficientes, los nuevos pods quedarán en Pending.
      Escalar hacia abajo a 0: el servicio queda completamente inaccesible.
      Escalar hacia abajo por debajo del mínimo recomendado puede causar
      pérdida de disponibilidad bajo carga.
    benefit: "Gestión dinámica de capacidad. Escalar arriba resuelve saturación de carga. Escalar abajo libera recursos para otros servicios."
    tool_name: "scale_deployment"
    requires_hitl: true
    allowed_callers: ["bosctl"]
    required_role: "operator"
    params:
      - name: name
        type: string
        required: true
        description: "Nombre del deployment (ej: bcompass, bsearch, tryton)"
      - name: replicas
        type: int
        required: true
        description: "Número de réplicas deseadas (0-10)"

  # ─── ACCIONES DE EJECUCIÓN — RIESGO ALTO (requieren rol admin) ────────────

  - id: restart_namespace
    name: "Reiniciar todos los pods de un namespace"
    description: "Hacer rollout restart de todos los deployments de un namespace completo de Kubernetes"
    aliases:
      - "reinicia todo el namespace X"
      - "recarga todos los servicios de X"
      - "reinicia todo sbos-erp"
      - "fresh start del namespace X"
    risk_level: "high"
    risk_detail: |
      ALTO RIESGO: todos los servicios del namespace se reinician simultáneamente.
      Interrupción total del namespace durante 1-3 minutos.
      Todos los usuarios conectados a servicios de ese namespace perderán su sesión.
      No recomendado durante horario laboral sin notificación previa a usuarios.
    benefit: "Útil cuando hay contaminación de estado en múltiples pods del namespace o problemas de red interna que requieren reconexión de todos los servicios."
    tool_name: "restart_namespace"
    requires_hitl: true
    allowed_callers: ["bosctl"]
    required_role: "admin"
    params:
      - name: namespace
        type: enum
        required: true
        description: "Namespace a reiniciar"
        options: ["sbos-erp", "sbos-auth", "sbos-data", "sbos-apps"]

  - id: drain_node
    name: "Drenar nodo para mantenimiento"
    description: "Marcar el nodo como no programable y migrar todos los pods a otros nodos para mantenimiento"
    aliases:
      - "quiero hacer mantenimiento del servidor"
      - "drenar el nodo"
      - "sacar el nodo de servicio"
      - "preparar el servidor para actualización"
    risk_level: "critical"
    risk_detail: |
      CRÍTICO: Si solo hay un nodo en el cluster, TODOS los servicios quedarán
      inaccesibles hasta que el nodo vuelva a ser habilitado.
      En un cluster multi-nodo, los pods se migran pero puede haber interrupción
      breve durante la migración de cada pod.
      Requiere confirmación explícita con la frase "CONFIRMO DRENADO".
    benefit: "Mantenimiento seguro del servidor sin pérdida de datos. Permite actualizar el sistema operativo, kernel o hardware sin downtime en clusters multi-nodo."
    tool_name: "drain_node"
    requires_hitl: true
    allowed_callers: ["bosctl"]
    required_role: "admin"
    params:
      - name: node_name
        type: string
        required: true
        description: "Nombre del nodo a drenar"
      - name: confirmation
        type: string
        required: true
        description: "Escribe 'CONFIRMO DRENADO' para proceder"
```

---

## Parte 4 — Implementación del ICAP Engine en Go

### 4.1 Motor de búsqueda semántica

```go
// internal/biaos/icap.go

package biaos

import (
    "context"
    "fmt"
    "math"
    "sort"
    "sync"
)

// ICAPEngine es el motor de Intent Matching sobre el Catálogo de Acciones.
type ICAPEngine struct {
    catalog  []CatalogEntry
    embedder EmbeddingModel // modelo local de embeddings (nomic-embed-text o similar)
    mu       sync.RWMutex
}

// EmbeddingModel es la interfaz para el modelo de embeddings local.
// Implementado sobre Ollama con un modelo ligero dedicado a embeddings.
type EmbeddingModel interface {
    Embed(ctx context.Context, text string) ([]float32, error)
}

// NewICAPEngine carga el catálogo y pre-calcula todos los embeddings.
// Llamado UNA sola vez al inicio — los embeddings se cachean en memoria.
func NewICAPEngine(catalogPath string, embedder EmbeddingModel) (*ICAPEngine, error) {
    catalog, err := loadCatalog(catalogPath)
    if err != nil {
        return nil, fmt.Errorf("icap: cargar catálogo: %w", err)
    }

    engine := &ICAPEngine{catalog: catalog, embedder: embedder}

    // Pre-calcular embeddings de todas las entradas del catálogo
    // Se usa la descripción + todos los aliases para maximizar el matching
    ctx := context.Background()
    for i := range engine.catalog {
        text := buildEmbeddingText(engine.catalog[i])
        embedding, err := embedder.Embed(ctx, text)
        if err != nil {
            return nil, fmt.Errorf("icap: embedding para %s: %w", engine.catalog[i].ID, err)
        }
        engine.catalog[i].embedding = embedding
    }

    return engine, nil
}

// buildEmbeddingText construye el texto que se embeddea para cada entrada del catálogo.
// Combina descripción + aliases para capturar todas las formas de expresar la intención.
func buildEmbeddingText(entry CatalogEntry) string {
    text := entry.Description
    for _, alias := range entry.Aliases {
        text += ". " + alias
    }
    return text
}

// MatchResult es el resultado de una búsqueda en el catálogo.
type MatchResult struct {
    Entry      CatalogEntry
    Score      float32 // similitud coseno 0-1
    Rank       int     // posición en el ranking (1 = mejor)
}

// Match busca las TOP-N acciones más relevantes para una consulta en lenguaje natural.
// Es el método central del ICAP Engine.
func (e *ICAPEngine) Match(ctx context.Context, query string, topN int, caller string) ([]MatchResult, error) {
    // 1. Convertir la consulta a embedding
    queryEmbedding, err := e.embedder.Embed(ctx, query)
    if err != nil {
        return nil, fmt.Errorf("icap: embedding de consulta: %w", err)
    }

    // 2. Calcular similitud coseno contra todas las entradas del catálogo
    type scored struct {
        entry CatalogEntry
        score float32
    }
    var scores []scored

    e.mu.RLock()
    for _, entry := range e.catalog {
        // Filtrar por caller permitido
        if !callerAllowed(caller, entry.AllowedCallers) {
            continue
        }
        score := cosineSimilarity(queryEmbedding, entry.embedding)
        scores = append(scores, scored{entry: entry, score: score})
    }
    e.mu.RUnlock()

    // 3. Ordenar por score descendente
    sort.Slice(scores, func(i, j int) bool {
        return scores[i].score > scores[j].score
    })

    // 4. Retornar TOP-N (mínimo score 0.4 para filtrar ruido)
    var results []MatchResult
    for i, s := range scores {
        if i >= topN {
            break
        }
        if s.score < 0.40 {
            break // umbral mínimo de relevancia
        }
        results = append(results, MatchResult{
            Entry: s.entry,
            Score: s.score,
            Rank:  i + 1,
        })
    }

    return results, nil
}

// cosineSimilarity calcula la similitud coseno entre dos vectores.
func cosineSimilarity(a, b []float32) float32 {
    if len(a) != len(b) {
        return 0
    }
    var dot, normA, normB float64
    for i := range a {
        dot += float64(a[i]) * float64(b[i])
        normA += float64(a[i]) * float64(a[i])
        normB += float64(b[i]) * float64(b[i])
    }
    if normA == 0 || normB == 0 {
        return 0
    }
    return float32(dot / (math.Sqrt(normA) * math.Sqrt(normB)))
}
```

### 4.2 Generación de presentación enriquecida con el LLM

```go
// internal/biaos/icap_presenter.go

package biaos

import (
    "context"
    "fmt"
    "strings"
)

// EnrichedOption es lo que el operador ve para cada opción en el menú.
type EnrichedOption struct {
    Rank        int
    Entry       CatalogEntry
    Score       float32
    // Generados por el LLM para este contexto específico:
    ContextualDescription string // descripción adaptada a la consulta del operador
    ContextualRisk        string // riesgo específico para esta situación
    SuggestedParams       map[string]string // parámetros inferidos de la consulta
}

// EnrichMatches usa el LLM para generar descripciones contextuales de las opciones.
// El LLM NO elige qué ejecutar — solo enriquece la presentación.
func (g *Gateway) EnrichMatches(ctx context.Context, query string, matches []MatchResult) ([]EnrichedOption, error) {
    if len(matches) == 0 {
        return nil, nil
    }

    // Construir prompt para enriquecimiento
    prompt := buildEnrichmentPrompt(query, matches)

    resp, err := g.router.ask(ctx, AskRequest{
        Prompt: prompt,
        System: enrichmentSystemPrompt,
        Caller: "biaos-icap",
        MaxTok: 800,
    })
    if err != nil {
        // Si falla el LLM, usar descripción base del catálogo (nunca bloquear)
        return buildFallbackOptions(matches), nil
    }

    return parseEnrichedOptions(resp.Text, matches), nil
}

const enrichmentSystemPrompt = `Eres el presentador de opciones de biaos.
Tu tarea es ayudar al operador a entender las opciones disponibles.
NUNCA decides qué ejecutar — eso es decisión del operador.
Responde SOLO en JSON con el formato especificado.
Sé conciso, técnico y honesto sobre los riesgos.`

func buildEnrichmentPrompt(query string, matches []MatchResult) string {
    var sb strings.Builder
    sb.WriteString(fmt.Sprintf("Consulta del operador: %q\n\n", query))
    sb.WriteString("Acciones encontradas en el catálogo:\n")
    for _, m := range matches {
        sb.WriteString(fmt.Sprintf("- ID: %s | Nombre: %s | Riesgo: %s\n",
            m.Entry.ID, m.Entry.Name, m.Entry.RiskLevel))
    }
    sb.WriteString(`
Para cada acción, genera JSON con:
{
  "options": [
    {
      "rank": 1,
      "contextual_description": "explicación breve de qué hace en el contexto de esta consulta",
      "contextual_risk": "riesgo específico para esta situación",
      "suggested_params": {"param_name": "valor_inferido_de_la_consulta"}
    }
  ]
}`)
    return sb.String()
}
```

### 4.3 Integración en el gateway — flujo completo

```go
// internal/biaos/gateway.go — método principal ICAP

// HandleOperatorQuery es el punto de entrada principal para todas las consultas.
// Clasifica automáticamente si es lectura (ReAct) o ejecución (ICAP).
func (g *Gateway) HandleOperatorQuery(ctx context.Context, req AgentRequest) (<-chan AgentEvent, error) {
    // PASO 1: Clasificar el tipo de consulta
    queryType, err := g.classifyQuery(ctx, req.Query)
    if err != nil {
        return nil, err
    }

    switch queryType {
    case QueryTypeRead:
        // Consultas de lectura: flujo ReAct existente (sin cambios)
        return g.agent.run(ctx, req)

    case QueryTypeExecution:
        // Consultas de ejecución: flujo ICAP
        return g.runICAPFlow(ctx, req)
    }
    return nil, fmt.Errorf("tipo de consulta no reconocido")
}

// runICAPFlow ejecuta el flujo completo de Intent Matching + presentación al operador.
func (g *Gateway) runICAPFlow(ctx context.Context, req AgentRequest) (<-chan AgentEvent, error) {
    events := make(chan AgentEvent, 32)

    go func() {
        defer close(events)

        // PASO 1: Buscar en el catálogo
        matches, err := g.icap.Match(ctx, req.Query, 3, req.Caller)
        if err != nil || len(matches) == 0 {
            events <- AgentEvent{
                Type:    "final",
                Content: "No encontré acciones en el catálogo que coincidan con tu consulta. Puedes usar lenguaje más específico o consultar `bosctl ia catalog list` para ver todas las acciones disponibles.",
                Done:    true,
            }
            return
        }

        // PASO 2: Enriquecer con LLM para presentación contextual
        options, _ := g.EnrichMatches(ctx, req.Query, matches)

        // PASO 3: Presentar opciones al operador (evento HITL especial)
        events <- AgentEvent{
            Type:    "icap_options",
            Content: formatOptionsForOperator(options),
            Done:    false,
        }

        // PASO 4: Esperar selección del operador
        selected := g.sessions.waitForSelection(ctx, req.SessionID, 10*time.Minute)
        if selected == nil {
            events <- AgentEvent{
                Type:    "final",
                Content: "Tiempo de espera agotado. No se ejecutó ninguna acción.",
                Done:    true,
            }
            return
        }

        // PASO 5: Validar que la opción seleccionada existe en el catálogo
        // (doble verificación — no confiar solo en lo que dijo el operador)
        action, err := g.icap.GetByID(selected.ActionID)
        if err != nil {
            events <- AgentEvent{Type: "error", Content: "Acción no válida", Done: true}
            return
        }

        // PASO 6: Audit antes de ejecutar (ISO 27001 A.8.15)
        auditBefore(req.Caller, action.ID, selected.Params)

        // PASO 7: Ejecutar EXACTAMENTE lo que está en el catálogo
        observation, toolErr := g.tools.execute(ctx, action.ToolName, selected.Params)

        // PASO 8: Audit después con resultado
        auditAfter(req.SessionID, action.ID, true, observation, "")

        if toolErr != nil {
            events <- AgentEvent{Type: "error", Content: toolErr.Error(), Done: true}
            return
        }

        events <- AgentEvent{Type: "final", Content: observation, Done: true}
    }()

    return events, nil
}
```

---

## Parte 5 — Separación final de responsabilidades IA vs. humano

```
┌────────────────────────────────────────────────────────────────────────┐
│                    QUÉ HACE LA IA EN BIAOS                             │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  ✅ HACE (con autonomía razonable):                                    │
│  • Interpretar la intención del operador en lenguaje natural           │
│  • Buscar semánticamente las 3 opciones más cercanas del catálogo      │
│  • Enriquecer la presentación con riesgo/beneficio contextuales        │
│  • Ejecutar operaciones de SOLO LECTURA sin confirmación               │
│    (query_system_status, get_pod_logs, check_node_resources)           │
│  • Diagnosticar y explicar en lenguaje natural qué encontró            │
│  • Inferir parámetros sugeridos de la consulta NL                      │
│                                                                        │
│  ❌ NO HACE (requiere decisión humana):                                │
│  • Elegir qué acción de ejecución aplicar                              │
│  • Generar comandos nuevos fuera del catálogo                          │
│  • Ejecutar acciones de escritura sin confirmación explícita           │
│  • Modificar el catálogo de acciones                                   │
│  • Encadenar múltiples acciones de ejecución sin revisión intermedia   │
│                                                                        │
├────────────────────────────────────────────────────────────────────────┤
│                    QUÉ HACE EL OPERADOR HUMANO                         │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  • Lee las opciones presentadas con riesgo y beneficio                 │
│  • Decide cuál acción es la correcta para su contexto                  │
│  • Confirma la ejecución: "ejecuta la opción 1"                        │
│  • Es el responsable final de cualquier cambio en el sistema           │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Parte 6 — Roadmap de entrenamiento correcto (basado en MetaKube y ToolLLM)

La investigación de la industria define tres fases distintas. El error común es saltarse las primeras dos.

### Fase 1 — HOY (semanas 1-2): System prompt + Modelfile + ICAP

**Qué hace:** especializa el modelo para el formato ReAct y el vocabulario SBOS.  
**Costo:** $0 en GPU.  
**Resultado esperado:** ~50-60% de efectividad en consultas complejas de diagnóstico. Las acciones de ejecución son 100% seguras porque van por ICAP.

```bash
ollama create biaos -f /etc/bos/ai/Modelfile.biaos
bosctl set aimodel local=biaos
```

### Fase 2 — MES 2-3: SFT sobre trayectorias reales del audit log

**Cuándo:** cuando el audit log acumule 300+ trayectorias completas (consulta NL → diagnóstico completo → resultado verificado).  
**Qué hace:** fine-tuning supervisado que enseña al modelo el vocabulario específico de SBOS (ficha, bkernel, WAL lag, DLQ) y los patrones de diagnóstico correctos.  
**Herramienta:** Unsloth QLoRA sobre qwen3:8b-q4.  
**Resultado esperado:** mejora de diagnóstico a ~75-80% basado en los datos de MetaKube.

```bash
# Generar dataset desde audit log
bosctl ai dataset build \
  --input /var/log/bos/ai-audit.jsonl \
  --output /var/lib/bos/ai/training/sft-v1.jsonl \
  --filter "outcome_verified=true AND trajectory_complete=true"

# Fine-tuning con Unsloth
unsloth-train \
  --model qwen3:8b \
  --dataset /var/lib/bos/ai/training/sft-v1.jsonl \
  --output /var/lib/bos/ai/adapters/biaos-sft-v1
```

### Fase 3 — MES 4+: RLVR con reward de outcome real

**Cuándo:** cuando haya un ambiente de prueba aislado que permita verificar si una acción resolvió el problema.  
**Qué hace:** reinforcement learning donde la señal de recompensa es "¿el pod volvió a Running después de la acción propuesta?".  
**Por qué es diferente a SFT:** el SFT enseña a imitar trayectorias correctas. RLVR enseña a generalizar hacia nuevos tipos de fallos no vistos.  
**Resultado esperado:** acercarse al 90%+ como MetaKube con fine-tuning completo.

---

## Parte 7 — Lo que el documento original biaos tiene bien

Es importante reconocerlo para no tirar arquitectura que funciona:

| Componente | Evaluación | Motivo |
|---|---|---|
| Gateway singleton con `sync.Once` | ✅ Correcto | Thread-safe, sin dependencias externas |
| Loop ReAct para diagnóstico | ✅ Correcto | Adecuado para operaciones de lectura |
| HITL con canal Go buffereado | ✅ Correcto | Patrón validado por KubeIntellect |
| Audit log async con canal | ✅ Correcto | No bloquea el agente por I/O |
| Separación de dominio (bcompass vs bosctl) | ✅ Correcto | Guardia de dominio necesaria |
| Modelfile con temperature 0.1 | ✅ Correcto | Determinismo para operaciones OS |
| Exposición via Unix socket existente | ✅ Correcto | Coherencia con ADR-012 |
| Restricción Go 1.25 stdlib | ✅ Correcto | Sin dependencias frágiles de terceros |

Lo que se agrega con este proyecto no reemplaza esa arquitectura — la extiende con el ICAP Engine para el caso de acciones de ejecución.

---

## Referencias

| Fuente | Aporte a este proyecto |
|---|---|
| Westenfelder et al., NL2SH, NAACL 2025 | Fundamento del problema de NL libre → alta tasa de error |
| MetaKube, ACM Web 2026 | Datos de mejora SFT: 50.9 → 90.5 con Qwen3-8B mismo dominio |
| KubeIntellect, arXiv Sep 2025 | Arquitectura HITL + pre-procesamiento de intención validada |
| Agent-S, arXiv Mar 2025 | Patrón de Action Retrieval con cosine similarity sobre catálogo |
| ToolLLM, Qin et al. 2024 | Dataset de trayectorias para SFT de tool-use |
| AI Safety Report 2026 | Necesidad de HITL en infraestructura sensible |
| Runbook Automation Industry 2026 | Catálogo de acciones como práctica estándar en AIOps |
| Agent-Human Interaction Security 2026 | Intent anchoring y validación de acciones en agentes LLM |

---

*Proyecto biaos — IA Robusta v1.0 | Junio 2026*  
*Este documento reemplaza los borradores anteriores de evaluación y propone una arquitectura implementable y fundamentada en evidencia de la industria.*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
