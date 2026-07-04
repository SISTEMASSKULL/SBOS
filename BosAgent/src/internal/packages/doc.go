// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Package packages implementa D2 — gestor unificado de paquetes del SBOS.
// Soporta tres backends: apt (sistema), pip (Python), helm (Kubernetes).
//
// # Responsabilidades
//
//   - Instalar y remover paquetes del sistema via apt-get.
//   - Instalar y remover paquetes Python via pip.
//   - Instalar y remover charts Helm via helm upgrade --install / helm uninstall.
//   - Seleccionar el backend correcto según el campo meta.backend del manifest.
//
// # Fuera de alcance
//
//   - Resolución de conflictos de versiones — delegado al gestor nativo (apt/pip/helm).
//   - Firma y verificación de paquetes — responsabilidad del Release Plane (P5).
//   - Actualización masiva del sistema — responsabilidad de bUpdate (daemon futuro).
//
// # Dependencias
//
//   - apt-get, pip, helm — binarios del host (instalados en bootstrap Capa 0/1).
//
// # Callers principales
//
//   - internal/installer/saga.go — selecciona backend según ficha.Backend.
//
// # Estándares y referencias
//
//   - ADR-017 — versiones canónicas de todo componente del SBOS.
//   - SBOS-019 FICHAS §2.3 — campo meta.backend en manifest.yml.
//
// # Ejemplo de uso
//
//	apt := packages.NewAptAdapter()
//	out, err := apt.Install("postgresql-18")
package packages
