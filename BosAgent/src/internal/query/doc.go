// Package query implementa las Sagas de Consulta JSON-RPC del bos
// (F6.6–F6.11 — BOS-REPAIR-04, fundamentos normativos en BOS-REPAIR-12).
//
// Una saga de consulta ejecuta múltiples fuentes internas EN PARALELO,
// agrega los resultados y retorna una vista compuesta estructurada. El
// llamador obtiene en una sola llamada RPC lo que requeriría N llamadas
// secuenciales (patrón Google SRE InvD — 44% de reducción de MTTM).
//
// Las 6 sagas expuestas en internal/server (bos.query.*):
//
//	bos.query.system   → Ubuntu + K8s + fichas + Context Plane + certificación
//	bos.query.repair   → pre-diagnóstico antes de reparar una ficha
//	bos.query.vdi      → VDI Layer completo con semáforo
//	bos.query.tenant   → snapshot completo de un tenant
//	bos.query.node     → diagnóstico de un nodo antes de mantenimiento
//	bos.query.context  → Context Plane: distribución, anomalías, TTLs
//
// SLOs (BOS-REPAIR-04 §Métricas): toda saga responde en < 4s — el motor
// impone ese deadline internamente; las fuentes que no llegan aportan
// {"error": "..."} en su clave en lugar de bloquear la respuesta
// (degradación elegante). Las fuentes que dependen de subsistemas aún no
// conectados (K8s real en F9, audit reader en F7) degradan igual.
//
// Estándares: OpenTelemetry CNCF (agregación de señales), ITIL 4 Service
// Monitoring + Incident Diagnosis, ISO 20000 (diagnóstico correlacionado).
package query
