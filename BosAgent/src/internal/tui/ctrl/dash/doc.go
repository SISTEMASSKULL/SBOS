// Package dash contiene los tipos compartidos, DashModel y los widgets
// reutilizables del dashboard de control SBOS.
//
// Todos los subpaquetes de vistas (k8s, sistema, panel) importan este paquete
// para acceder a DashModel y los helpers de renderizado. El paquete ctrl
// importa dash y los subpaquetes de vistas — ningún ciclo de importación.
//
// Diagrama de dependencias:
//
//	dash ← k8s, sistema, panel
//	dash ← ctrl
//	k8s, sistema, panel ← ctrl (ctrl llama sus funciones exportadas)
package dash
