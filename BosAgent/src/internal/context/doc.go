// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Fable 5 — Anthropic
//
// Package context implementa el Context Plane del SBOS (SBOS-049):
// ciclo de vida completo de DeviceContext (dctx_id, pre-autenticación) y
// SessionContext (ctx_id, post-autenticación), con persistencia en
// PostgreSQL + cache Redis y propagación W3C Trace Context.
//
// NOTA DE IMPORTACIÓN: al importar, usar alias para evitar conflicto con
// el paquete estándar "context" de Go:
//
//	import bosctx "bos/internal/context"
//
// # Los 7 estados del ciclo de vida (SBOS-049)
//
// Todo contexto transita por el enum [ContextState]:
//
//	PENDIENTE   → registrado, aún no validado.
//	              Ejemplo: caja-01 ejecuta RegisterDevice al encender;
//	              su dctx_id queda PENDIENTE hasta el primer login.
//	ACTIVO      → validado y operativo (estado normal de una sesión).
//	              Ejemplo: Promote(dctx, usuario, bitmask>0) crea la
//	              SessionContext directamente en ACTIVO.
//	SUSPENDIDO  → suspendido por administración (tenant o usuario).
//	              Ejemplo: bosctl tenant suspend skull → todas sus
//	              sesiones pasan a SUSPENDIDO sin destruirse.
//	BLOQUEADO   → bloqueado por política de seguridad (bAuth detecta
//	              anomalía y bloquea el ctx sin esperar al logout).
//	INVALIDADO  → terminal — logout explícito, revocación o Switch
//	              (la sesión anterior se invalida al conmutar empresa).
//	EXPIRADO    → terminal — TTL agotado (8h device / 12h sesión,
//	              ISO 27001 A.9.4.2). bos.ctx.get responde -32001.
//	ARCHIVADO   → terminal — movido a histórico, inmutable.
//
// Los estados terminales (IsTerminal) no admiten más transiciones.
// Invariantes: DeviceContext siempre BitMask == 0 (pre-auth);
// SessionContext siempre BitMask > 0 (post-auth).
//
// # Operaciones expuestas (Service)
//
// Cada operación del [Service] respalda un método JSON-RPC bos.ctx.* (F5.4):
//
//   - RegisterDevice → bos.ctx.device.register (idempotente, SLO C-13 < 2s)
//   - Promote        → bos.ctx.promote (dctx → ctx; el dctx queda INVALIDADO)
//   - Switch         → bos.ctx.switch (nuevo ctx_id; el anterior INVALIDADO)
//   - Invalidate     → bos.ctx.invalidate (logout/revocación, idempotente)
//   - Get            → bos.ctx.get (lookup O(1) del Kong plugin; TTL vencido → -32001)
//   - ListByTenant   → bos.ctx.list (solo ACTIVO vigentes — vista operativa)
//   - ListAllByTenant → bos.query.context (todas, incluso terminales — diagnóstico F6.11)
//   - InvalidateAllByTenant → bos.ctx.tenant.suspend (SBOS-049 §5.1)
//
// # Fuera de alcance
//
// No propaga el ctx_id en la red — eso es responsabilidad de cada daemon
// (W3C traceparent, ver internal/server/traceparent.go).
// No audita las operaciones — eso es internal/audit.
// No autentica al usuario ni calcula el BitMask — eso es bAuth.
//
// # Dependencias
//
// Ninguna interna: el paquete define las interfaces [Store], [SQLExecutor] y
// [RedisClient] y recibe las implementaciones por inyección (hexagonal).
//
// # Callers principales
//
// internal/server/ctx_handlers.go: expone los 7 métodos vía JSON-RPC 2.0.
// internal/server/query_handlers.go: bos.query.context (F6.11).
// cmd/bosctl/context.go: comandos `bosctl ctx` vía CLI.
// bAuth, biedata: invocan bos.ctx.* en cada operación.
//
// # Estándares y referencias
//
// SBOS-049 — Context Plane: ctx_id, W3C Trace Context, OpenTelemetry.
// ISO 27001:2022 A.8.15 — toda operación trazable con ctx_id.
// ISO 27001:2022 A.9.4.2 — TTL máximos (MaxDeviceTTL 8h, MaxSessionTTL 12h).
// NIST 800-207 — Zero Trust: cada request verifica identidad + contexto.
// RFC 9470 — LoA 1-4 con Step-Up (campo SessionContext.LoA).
// W3C Trace Context — https://www.w3.org/TR/trace-context/
//
// # Ejemplo de uso
//
//	svc := bosctx.NewServiceWithMemStore() // producción: NewService(PGRedisStore)
//
//	// 1. El dispositivo se registra al encender (pre-auth, BitMask 0):
//	dev, _ := svc.RegisterDevice("caja-01.skull.local", "skull", "node-01", "10.0.0.5")
//
//	// 2. Login del usuario — bAuth calcula el BitMask y promueve:
//	ses, _ := svc.Promote(dev.DctxID, "TS-01", "SUC-01", "POS-01",
//	    "usr_ana", bosctx.BitMask(0x0F), 2, "00-4bf9...-00f0...-01")
//
//	// 3. Operar con ses.CtxID; al cerrar sesión:
//	_ = svc.Invalidate(ses.CtxID)
package context
