// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Package reconcile compara el estado declarado (manifests + task catalogs)
// contra los hashes almacenados en STATE_MANAGER y dispara detección de drift
// cuando los hashes SHA-256 divergen.
//
// # Responsabilidades
//
//   - Calcular hashes SHA-256 de los archivos declarativos de cada ficha
//     (manifest.yml, task_catalog.sh, yaml_engine.yml) cada ReconcileInterval.
//   - Comparar contra los hashes almacenados en STATE_MANAGER.
//   - Transicionar la ficha a ACTUALIZACION_DISPONIBLE cuando se detecta drift.
//   - Disparar reparación automática en goroutines controladas por inFlight sync.Map,
//     previniendo la condición de carrera P6/P14 (BOS-REPAIR-03).
//
// # Fuera de alcance
//
//   - Reparar fichas directamente — delega en Installer.Repair().
//   - Detectar drift de configuración K8s — solo archivos declarativos en disco.
//   - Gestionar versiones disponibles en el Release Plane — responsabilidad de release.
//
// # Dependencias
//
//   - internal/state — STATE_MANAGER (Read, RegisterHashes, SetDriftDetected).
//   - internal/installer — Installer interface (Repair).
//   - log/slog — logging de drift detectado.
//
// # Callers principales
//
//   - cmd/bos/main.go — crea Scheduler y lo inicia como goroutine en runNormal().
//
// # Estándares y referencias
//
//   - P16 (docs-first): manifest.yml, task_catalog.sh, yaml_engine.yml son la
//     fuente de verdad. Sus hashes son la señal de drift.
//   - ADR-021 #5 — estado ACTUALIZACION_DISPONIBLE.
//   - BOS-REPAIR-03 — fix de race condition P6/P14 con inFlight sync.Map.
//
// # Ejemplo de uso
//
//	sched := reconcile.NewScheduler(stateMgr, orchestrator, 300*time.Second,
//	    paths.ServersPath, true, logger)
//	go sched.Run()
//	defer sched.Stop()
package reconcile
