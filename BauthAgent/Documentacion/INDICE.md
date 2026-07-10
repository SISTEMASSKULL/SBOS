# Documentación Técnica — bAuth Identity Control Plane

**Versión:** 1.0.0  
**Mantenido por:** bauth-developer  
**Última actualización:** 2026-07-10  
**Estado:** Activo — se amplía a medida que se cierran los gaps de reparación

---

## Manuales disponibles

| Manual | Archivo | Estado | Versión |
|--------|---------|--------|---------|
| Manual de Roles | [MANUAL-ROLES-v1.0.md](MANUAL-ROLES-v1.0.md) | ✅ Activo | 1.0.0 |
| Manual de Políticas | MANUAL-POLITICAS-v1.0.md | 📋 Planificado | — |
| Manual de Atributos | MANUAL-ATRIBUTOS-v1.0.md | 📋 Planificado | — |
| Manual de Átomos | MANUAL-ATOMOS-v1.0.md | 📋 Planificado | — |
| Manual de Verbos | MANUAL-VERBOS-v1.0.md | 📋 Planificado | — |
| Manual de BitMask | MANUAL-BITMASK-v1.0.md | 📋 Planificado | — |
| Manual de Tokens | MANUAL-TOKENS-v1.0.md | 📋 Planificado | — |
| Manual de Firma Digital | MANUAL-FIRMA-DIGITAL-v1.0.md | 📋 Planificado | — |

---

## Principio de esta documentación

Cada manual documenta el **estado real y verificado** del sistema en la VPS de producción. No es documentación especulativa ni de diseño futuro — es la descripción del sistema que existe.

Cuando un componente aún está en desarrollo, se indica con la marca `⚙ En implementación` dentro del documento correspondiente.

---

## Relación con otros documentos

| Documento | Ubicación | Propósito |
|-----------|-----------|-----------|
| Gaps de reparación | `context/plandeaccion/REPARACIONBAUTH/` | Registro de gaps detectados y su solución |
| Contratos entre daemons | `../context/contracts/` | Interfaz entre bAuth y otros daemons |
| Contexto de diseño | `context/` | Decisiones arquitectónicas y análisis |
| DDL y seeds | `../DDLs/` | Esquema de base de datos y datos iniciales |
