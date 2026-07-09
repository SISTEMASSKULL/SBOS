---
codigo: BNOTIFY-090
version: 1.0.0
estado: BORRADOR
gate: G0
depende_de: [BNOTIFY-000, BNOTIFY-005]
doctrina_que_ejerce: [D13, D14]
criterio_implementado: >
  Todo BNOTIFY-0XX nuevo sigue la plantilla de este documento.
  El ciclo spec→plan→tareas está operativo para al menos un documento aprobado.
  La definición de terminado de ese documento es verificable por máquina (tests/lint en verde).
---

# BNOTIFY-090 — Gobernanza Documental y de Agentes
## Convenciones, plantilla, ciclo de implementación y reglas de trabajo

**Versión:** 1.0.0 · **Gate:** G0 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §10.0 · BNOTIFY-005

---

## 1. Plantilla canónica de un documento BNOTIFY-0XX

Todo documento del proyecto comienza con este front-matter YAML, seguido de contenido en Markdown.
El front-matter es el contrato legible por máquina; el Markdown es la explicación para humanos.

```markdown
---
codigo: BNOTIFY-0XX
version: 1.0.0
estado: BORRADOR        # ver §2
gate: G0                # G0 | G1 | G2 | G3 | G4 | G5
depende_de:             # lista de códigos BNOTIFY-0XX que deben estar APROBADOS antes
  - BNOTIFY-000
doctrina_que_ejerce:    # lista de principios D1-D18 de BNOTIFY-000 §0 que este doc ejerce
  - D14
criterio_implementado: >
  Descripción precisa y verificable por máquina de cuándo este documento
  está IMPLEMENTADO. Ejemplos: "cargo test --features X pasa", "endpoint Y
  responde 200 con payload Z en la VPS de staging".
---

# BNOTIFY-0XX — NOMBRE-DEL-DOCUMENTO
## Subtítulo descriptivo

**Versión:** 1.0.0 · **Gate:** GX · **Estado:** BORRADOR
**Referencia:** [documentos de los que depende]

---

[Contenido del documento]
```

### Reglas del front-matter

- `codigo`: exactamente `BNOTIFY-` seguido de 3 dígitos sin espacios
- `version`: semver — incrementar MINOR al cambiar contenido sustancial, PATCH para correcciones
- `estado`: uno de los valores definidos en §2 — nunca un valor libre
- `gate`: el gate de BNOTIFY-000 §7 al que pertenece este documento
- `depende_de`: solo códigos BNOTIFY-0XX — nunca rutas de archivo ni nombres de personas
- `doctrina_que_ejerce`: solo D1–D18 de BNOTIFY-000 §0
- `criterio_implementado`: debe ser verificable por máquina — si dice "funciona correctamente" sin test, está incompleto

---

## 2. Estados y transiciones

```
⏳ PENDIENTE → 📝 BORRADOR → 🔄 EN REVISIÓN → ✅ APROBADO → 🔨 IMPLEMENTANDO → 📦 ENTREGADO
                                                    │
                                                    └──► 🚫 OBSOLETO (si se supersede)
```

| Estado | Quién lo establece | Condición |
|--------|-------------------|-----------|
| PENDIENTE | — | Aparece en BNOTIFY-005 pero no está redactado |
| BORRADOR | Agente | El documento existe y está completo según la plantilla |
| EN REVISIÓN | Agente | Presentado a Ivan para revisión |
| APROBADO | **Ivan** | Ivan revisó y aprobó — único autorizado |
| IMPLEMENTANDO | Agente | Código en curso contra este documento |
| ENTREGADO | Agente + Ivan | Criterio implementado verificado en VPS |
| OBSOLETO | Ivan | Supersedido por otro documento mediante ADR |

**Regla crítica (D13 — gates por demostración):** el estado APROBADO solo lo establece Ivan.
Un agente no puede marcar su propio documento como APROBADO.

---

## 3. Versionado de documentos

- `1.0.0` → primera versión completa presentada a revisión
- `1.1.0` → cambio sustancial de contenido (nueva sección, cambio de decisión técnica)
- `1.0.1` → corrección de redacción sin cambio de decisión
- `2.0.0` → reescritura mayor (justificada por ADR en BNOTIFY-007)

Toda modificación posterior a APROBADO exige nuevo ADR en BNOTIFY-007 y nueva versión.
El historial de versiones se registra al pie del documento modificado.

---

## 4. Proceso de enmienda de la doctrina (BNOTIFY-000)

La doctrina (BNOTIFY-000 §0) no se modifica directamente. Toda excepción o enmienda:

1. Se abre como ADR en BNOTIFY-007 con contexto, opciones consideradas y decisión
2. Se aprueba por Ivan
3. Solo entonces se actualiza BNOTIFY-000 con referencia al ADR
4. El ADR permanece en BNOTIFY-007 para siempre — no se borra aunque la doctrina cambie

Un agente que necesite apartarse de un principio D1-D18 **detiene el trabajo** y abre el ADR
antes de escribir código. Código que contradice la doctrina sin ADR aprobado es inválido.

---

## 5. Ciclo spec→plan→tareas por documento

Cada documento BNOTIFY-0XX aprobado se implementa mediante este ciclo exacto:

```
DOCUMENTO APROBADO
      │
      ▼
[SPEC] Descomposición en requisitos atómicos
      Formato: tabla con ID, descripción, criterio de verificación
      Producida por: agente · Aprobada por: Ivan
      │
      ▼
[PLAN] Orden de implementación con dependencias
      Formato: lista ordenada de tareas, duración estimada, bloqueos conocidos
      Producida por: agente · Aprobada por: Ivan
      │
      ▼
[TAREAS] Ejecución atómica
      Una tarea = un resultado verificable independientemente
      Cada tarea: implementar → verificar criterio → actualizar BNOTIFY-005
      │
      ▼
[GATE] Criterio implementado del front-matter verificado en VPS
      → Estado pasa a ENTREGADO
      → BNOTIFY-005 actualizado en el mismo commit
```

### Definición de "tarea atómica"

Una tarea es atómica si:
- Tiene un resultado verificable sin contexto adicional
- Puede completarse o no completarse — no "a medias"
- Su verificación es un comando que retorna 0 o ≠ 0

Ejemplos válidos:
- "Crear tabla `bnotify.intent` con las columnas del DDL-008 §3.1 y verificar con `\d bnotify.intent` en psql"
- "Implementar `NotifyIntent::from_proto()` y verificar con `cargo test intent::tests::from_proto_roundtrip`"

Ejemplos inválidos:
- "Trabajar en el módulo de notificaciones"
- "Mejorar el dispatcher"

---

## 6. Definición de terminado — verificable por máquina

Un documento está ENTREGADO cuando **todos** los siguientes puntos son verdad,
verificados con comandos que retornan 0:

| # | Criterio | Comando de verificación |
|---|----------|------------------------|
| 1 | Compila sin errores ni warnings | `cargo build --release 2>&1 \| grep -c "^error" \| grep -q "^0$"` |
| 2 | Tests en verde | `cargo test 2>&1 \| tail -1 \| grep -q "ok"` |
| 3 | Sin clippy warnings | `cargo clippy -- -D warnings` |
| 4 | Criterio específico del documento | El del campo `criterio_implementado` del front-matter |
| 5 | BNOTIFY-005 actualizado | `grep -q "ENTREGADO" context/BNOTIFY-005-NAVEGADOR-DE-DOCUMENTOS.md` |
| 6 | Estado correcto en front-matter | `grep -q "estado: ENTREGADO" context/BNOTIFY-0XX-*.md` |

Los criterios 1-3 aplican a todo documento que produce código.
Los documentos que producen solo DDL verifican con `psql -c "\d tabla"` en lugar de cargo.

---

## 7. Reglas de trabajo de los agentes

Estas reglas operan sobre la base del §10.0 de BNOTIFY-000. Son obligatorias:

1. **Entrada siempre por dos puertas:** leer BNOTIFY-000 (doctrina) y BNOTIFY-005 (navegador) antes de cualquier tarea. Ningún agente trabaja sin haber leído ambos en la sesión.

2. **Toda desviación es un ADR:** si el agente necesita apartarse de un documento aprobado, el ADR en BNOTIFY-007 precede al código. El código silencioso que contradice un documento aprobado es inválido.

3. **Ninguna tarea se cierra sin prueba objetiva:** tests en verde, lint, diff confinado a rutas acordadas. "Funciona" sin criterio verificable no cierra una tarea.

4. **BNOTIFY-005 se actualiza en el mismo commit** que cualquier cambio de estado de un documento. Un navegador desactualizado invalida el commit.

5. **Capacidades, no rutas:** los documentos describen qué hace cada pieza y su vocabulario de dominio. Los agentes no asumen estructuras de archivos — consultan el documento correspondiente.

6. **Cero criptografía propia (D12):** cualquier necesidad criptográfica se resuelve con una librería existente y auditada. El agente que inventa un esquema criptográfico propio está violando la doctrina.

7. **El agente reporta bloqueos, no los resuelve silenciosamente:** si la implementación de un documento revela una contradicción o un vacío no cubierto, el agente detiene el trabajo, documenta el bloqueo con precisión, y escala a Ivan.

---

*BNOTIFY-090 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*La gobernanza no es burocracia — es la forma de que 30 documentos y múltiples agentes produzcan un sistema coherente.*
