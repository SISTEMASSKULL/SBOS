# ⛔ SOLO REFERENCIA DE LÓGICA — NO COPIAR ESTE CÓDIGO

## Advertencia al agente implementador

Este directorio es un **archivo de referencia histórica**, NO una implementación reutilizable.

### Lo que DEBES hacer

1. **Leer** este código para entender la lógica, los algoritmos y los patrones que implementaba.
2. **Construir desde cero** usando el `doc.go` del nuevo paquete como contrato irrenunciable.
3. **Adaptar** la lógica que siga siendo válida al nuevo diseño modular.

### Lo que NO DEBES hacer

- ❌ Copiar archivos de aquí al nuevo paquete
- ❌ Hacer un "refactor" de este código en su lugar
- ❌ Importar desde esta ruta (`_legacy/` no es un paquete Go válido)
- ❌ Asumir que la arquitectura, las interfaces o los nombres son correctos

### Por qué está archivado

Este código fue escrito antes del plan BOS-REPAIR. Carece de:
- Documentación ADR-003 (`doc.go` con las 6 secciones obligatorias)
- Modularización correcta según la arquitectura objetivo
- Separación de responsabilidades entre capas

El nuevo paquete lo **reimplementa desde el contrato**, tomando solo la lógica que sigue siendo válida.

---
*Archivado en F0.7 — 2026-06-09 · Plan BOS-REPAIR*
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
