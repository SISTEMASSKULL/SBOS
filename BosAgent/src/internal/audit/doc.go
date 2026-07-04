// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// Package audit implementa el log de auditoría obligatorio del daemon bos,
// conforme a ISO 27001:2022 Annex A 8.15 (Logging).
//
// # Responsabilidades
//
// Registrar toda operación relevante del daemon con timestamp, actor,
// acción y resultado. Cada entrada es inmutable — solo se agregan,
// nunca se modifican ni eliminan. Escribe en el archivo de audit log
// configurado en BOS_AUDIT_LOG (por defecto /var/log/bos/audit.log).
//
// # Fuera de alcance
//
// No filtra ni analiza entradas — solo escribe.
// No rota logs — eso es responsabilidad del sistema operativo (logrotate).
// No envía eventos a sistemas externos — eso es observability.
//
// # Dependencias
//
// Ninguna dependencia de otros paquetes internos.
// Depende únicamente de la biblioteca estándar de Go (os, fmt, time).
//
// # Callers principales
//
// internal/installer/saga.go: registra cada paso de saga (install/repair/remove).
// internal/server/jsonrpc.go: registra toda invocación RPC con su resultado.
// internal/bootstrap/setup.go: registra cada criterio C-01..C-08 verificado.
// cmd/bos/main.go: registra arranque y apagado del daemon.
//
// # Estándares y referencias
//
// ISO 27001:2022 Annex A 8.15 — Logging obligatorio de operaciones.
// NIST SP 800-92 — Guide to Computer Security Log Management.
// BOS-REPAIR-07 (ADR-003) — Estándares de documentación del proyecto.
//
// # Ejemplo de uso
//
//	audit.Log(paths.AuditLog, "STARTUP",
//	    "user=root",
//	    "tenant=acme",
//	    "channel=stable",
//	    "result=ok")
//
//	// Registrar un error con contexto
//	audit.Log(paths.AuditLog, "INSTALL",
//	    "ficha=postgresql",
//	    "step=helm_install",
//	    "result=error",
//	    "err="+err.Error())
package audit
