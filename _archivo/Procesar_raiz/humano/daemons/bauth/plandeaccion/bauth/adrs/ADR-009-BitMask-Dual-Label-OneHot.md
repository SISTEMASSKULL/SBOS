# ADR-009 — BitMask Dual: Label Encoding + One-Hot Encoding

**Estado:** Aceptado · **Fecha:** 2026-06-21 · **Reemplaza:** ADR-003

---

## Contexto

El ADR-003 estableció un BitMask de 64 bits en 2 capas (32 sistema + 32 negocio) con herencia DAG mediante OR bitwise. Durante la validación del modelo, se descubrió un defecto de seguridad: aplicar OR directamente sobre códigos de átomo (label encoding) produce escalamiento silencioso de privilegios.

**Prueba del defecto:** `código(nuevo)=1`, `código(editar)=2`, `código(eliminar)=3`. El OR acumulado de dos átomos con códigos `1|2|1|2 = 3` produce el código 3 = "eliminar" — un permiso que nadie otorgó. El resultado es un código válido del catálogo, pasa revisiones superficiales, y es indistinguible de un permiso legítimo.

**Raíz del error:** usar la misma estructura numérica para dos propósitos distintos — identificar un átomo (label encoding) y combinar permisos entre roles (flags).

## Decisión

**Separar en dos estructuras independientes con codificaciones distintas:**

1. **BitMask Átomo (64 bits, label encoding):** Identifica UN átomo específico de forma compacta. Estructura: Dominio Contextual [8 res][4 dom][9 app][11 grupo] + Dominio Lógico [6 res][2 política][24 átomo]. Operaciones válidas: igualdad, AND con máscara fija para extraer campos. **NUNCA OR/AND/XOR entre dos BitMask Átomo.**

2. **Rol BitMask (N bits, one-hot encoding):** Combina los átomos de un rol. Cada átomo del catálogo global ocupa una posición de bit fija e independiente. Operaciones válidas: OR (unión), AND (intersección/mínimo privilegio), AND NOT (remoción selectiva), XOR (delta entre estados, máximo 2 operandos).

La herencia DAG + Closure Table se mantienen vigentes, pero operan sobre el Rol BitMask (one-hot), no sobre el BitMask Átomo (label).

## Alternativas

| Alternativa | Problema |
|------------|---------|
| Mantener ADR-003 (2 capas sobre 1 u64) | Escalamiento silencioso de privilegios demostrado |
| SAM-128 (128 bits) | Misma raíz de error. XOR para SoD es incorrecto (ver SBOS-BITMASK-ANALISIS-SAM128) |
| ACL por recurso | O(n) evaluación, no escala |
| ABAC puro (XACML) | Latencia > 1ms, incompatible con Fast-Path < 0.5ns |

## Consecuencias

**Positivas:**
- Escalamiento de privilegios matemáticamente imposible: cada átomo tiene su propio bit independiente
- El OR sobre Rol BitMask produce exactamente la unión de conjuntos
- La delegación por AND garantiza mínimo privilegio: `delegado = senior & junior`
- El BitMask Átomo (64 bits) es compacto para transmisión y almacenamiento
- SoD se implementa con Conflict Matrix estática (pares de átomos incompatibles), no con XOR

**Negativas:**
- Dos estructuras que mantener en vez de una
- El Rol BitMask crece con el catálogo (N bits = cantidad de átomos). Mitigación: 500 átomos = 63 bytes; 5000 átomos = 625 bytes — manejable en JWT
- Requiere reescritura de `domain/bitmask.rs` (B1.T03, B1.T04) y actualización de B2-B8

## Referencias

- `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md` — Especificación completa + DDL `bos_privilege`
- `SBOS-MANUAL-BAUTH-COMPONENT-ROLES.md` v1.7 — bAuth administra el BitMask, no KC ni Tryton-PDP
- `SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md` — Análisis del error XOR en SAM-128
- `BAUTH-CATALOGO-ROLES-EMPRESARIALES.md` v2.1 §6 — Modelo dual documentado
- NIST RBAC Model §4.2 — DAG hierarchies
- RFC 6962 §2.1 — Domain-separated Merkle tree hashing (referencia para domain separation en leaf/node)
