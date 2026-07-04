# ADR-003 — BitMask 64-bit de 2 Capas + DAG con Herencia OR

> ⚠️ **SUPERSEDED — JUNIO 2026:** Este ADR describía el modelo BitMask anterior. Ha sido reemplazado por el **BitMask Dual** (`SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md`). Se necesitará un nuevo ADR-D12 para documentar la decisión de incorporar blockchain. La decisión de usar DAG + Closure Table se mantiene vigente; la implementación específica de bits cambió de "2 capas sobre u64" a "BitMask Átomo + Rol BitMask".

**Estado:** Aceptado · **Fecha:** 2026-06-20

---

## Contexto

bAuth necesita un motor de privilegios que evalúe permisos en < 0.5ns por request. El sistema maneja dos tipos de permisos: sistema (crear módulos, tenants) y negocio (ventas, facturación, inventario). La herencia jerárquica de roles (NIST RBAC §4.2) requiere que un rol senior herede automáticamente todos los permisos de sus roles junior.

## Decisión

**BitMask de 64 bits en 2 capas con Grafo Acíclico Dirigido (DAG) para herencia mediante OR bitwise.**

- Capa 1 (bits 0–31): privilegios de sistema — asignables solo a SU y SYS
- Capa 2 (bits 32–63): privilegios de negocio — asignables a BIZ y EXT
- Herencia: `mask_eff(senior) = mask_own(senior) | mask_eff(junior₁) | mask_eff(junior₂) | ...`
- Verificación: `(mask_eff & bit_operación) != 0` (una sola instrucción CPU)
- Almacenamiento: tabla `rol_closure(ancestro_id, descendiente_id, profundidad)` — una consulta JOIN sin recursión

## Alternativas

| Alternativa | Problema |
|------------|---------|
| SAM-128 monolítico (128 bits en 1 capa) | Sin separación sistema/negocio. Evaluación más lenta (2× uint64 vs 4× uint64). Sobrecarga de bits. |
| RBAC con listas ACL por recurso | O(n) evaluación. No escala a 368 roles con múltiples dominios. |
| ABAC puro (XACML) | Evaluación > 1ms. Complejidad innecesaria para el modelo de negocio SBOS. |

## Consecuencias

**Positivas:**
- Evaluación en < 0.5ns (AND bitwise es 1 ciclo CPU)
- Separación clara sistema/negocio = SoD implícito (BIZ nunca toca capa 1)
- Closure table SQL resuelve herencia en 1 JOIN sin CTE recursivo
- 186 aristas documentadas en BAUTH-CADENAS-JERARQUIA.md

**Riesgos:**
- 64 bits pueden ser insuficientes si se requieren >64 permisos por capa
- Mitigación: BitmaskBundle extensible (7×uint64 ya definido para dominios)

## Referencias
- NIST RBAC Model §4.2 — Role Hierarchies as Partial Orders (DAG)
- BAUTH-CATALOGO-ROLES-EMPRESARIALES.md v2.0 §6
- BAUTH-CADENAS-JERARQUIA.md v1.1
