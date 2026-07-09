# Buzón del Bibliotecario — SBOS
**Versión:** 1.0 · **Fecha:** 2026-07-05
**Propósito:** Ruta canónica ÚNICA donde los agentes del ecosistema SBOS depositan reportes, errores, preguntas y solicitudes dirigidas al Bibliotecario.

---

## Reglas de uso

1. **Todo reporte de agente → Bibliotecario se deposita AQUÍ.** Prohibido dejar informes en directorios arbitrarios.
2. **Formato de nombre:** `<AGENTE>-<ASUNTO>-<YYYYMMDD-HHMM>.md`
   - Ejemplo: `BauthAgent-ERRORES-INICIALIZACION-20260705-0724.md`
3. **El Bibliotecario revisa este buzón al inicio de cada sesión** (PASO 1 del protocolo).
4. **No se usa para comunicación entre agentes** — para eso está el Coordinador (:8095).
5. **No se modifica un reporte ya depositado** — si hay corrección, se deposita uno nuevo con timestamp posterior.

---

## Contenido mínimo de un reporte

```markdown
# <AGENTE> — <ASUNTO>
## Sesión: <YYYY-MM-DD HH:MM UTC> · Agente: <nombre>

## Hallazgo / Pregunta
...

## Impacto
...

## Acción solicitada al Bibliotecario
...
```

---

## Ciclo de vida

```
Agente deposita → Bibliotecario lee en arranque → Clasifica:
  ├── Doctrina/normas → Resuelve el Bibliotecario mismo
  ├── Tareas/trabas → Deriva al Coordinador
  ├── Código/commits → Deriva al Revisor
  └── Decisión HITL → Escala al humano

Resuelto → el Bibliotecario mueve el reporte a buzon-bibliotecario/_procesados/
```

---
*Custodiado por: Bibliotecario · Ubicación: SBOS/context/buzon-bibliotecario/*
