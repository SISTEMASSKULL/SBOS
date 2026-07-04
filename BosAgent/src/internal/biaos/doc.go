// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// Package biaos implementa el Agente OS del SBOS: el gateway IA que permite
// a los daemons del ecosistema invocar capacidades de inteligencia artificial
// a través del Context Plane (SBOS-049).
//
// # Responsabilidades
//
// Tres componentes principales:
//  1. Gateway LLM (singleton): gestiona las conexiones a los modelos IA
//     configurados. Una sola instancia en todo el daemon (ADR-004).
//  2. ICAP Engine (Intelligent Context Acquisition & Processing):
//     extrae contexto relevante del SO (estado K8s, fichas, métricas, logs)
//     y lo inyecta en el prompt antes de invocar el LLM.
//  3. Agente ReAct: implementa el loop Reason-Act-Observe en Go puro.
//     Sin dependencias de frameworks Python — el ciclo completo vive en Go.
//
// Migración: reemplaza internal/ai/ (stub vacío) a partir de F10.2.
// El código existente en internal/ai/ se archiva en _legacy/ antes de migrar.
//
// # Fuera de alcance
//
// No llama APIs externas directamente — usa el Gateway LLM que gestiona
// las credenciales desde Vault y aplica rate limiting.
// No almacena conversaciones — eso es responsabilidad de biedata.
// No expone HTTP — usa JSON-RPC 2.0 sobre Unix socket (SBOS-050 P9).
//
// # Dependencias
//
// internal/paths: para rutas de caché y logs de IA.
// internal/context: para propagar ctx_id en cada invocación IA.
// internal/audit: para registrar cada llamada al LLM (ISO 27001 A.8.15).
//
// # Callers principales
//
// internal/server/jsonrpc.go: expone el namespace bos.ai.* (8 métodos).
// cmd/bosctl/ai.go: comandos `bosctl ai` para interacción humana directa.
//
// # Estándares y referencias
//
// SBOS-018 §9 — biaos: Agente OS + Gateway IA.
// BOS-REPAIR-10 — Fase 10: biaos completo.
// ADR-004 — Singleton Gateway LLM, sin pools de goroutines no acotados.
// ISO 27001:2022 A.8.15 — Toda llamada IA debe ser auditada con ctx_id.
//
// # Ejemplo de uso
//
//	gw := biaos.NewGateway(vaultClient, cfg)
//	agent := biaos.NewAgent(gw, icapEngine)
//	result, err := agent.Execute(ctx, biaos.Task{
//	    Prompt: "¿Qué ficha está causando el error de memoria?",
//	    CtxID:  ctxID,
//	})
package biaos
