# PROTOCOLO DE SESIÓN — Agente bAuth
## Cómo el agente abre, ejecuta y cierra cada sesión de trabajo

**Proyecto:** BauthAgent / SBOS · SKULL
**Versión:** 1.0 · Junio 2026
**Principio:** Ninguna sesión empieza sin saber dónde estamos. Ninguna termina sin dejar el estado escrito.

---

## Estructura de una sesión

```
APERTURA (5 min, obligatoria)
    ↓
EJECUCIÓN (variable — uno o más átomos)
    ↓
CIERRE (5 min, obligatoria)
    ↓
LOG-DE-SESIONES.md actualizado
```

---

## FASE 1 — APERTURA DE SESIÓN

### 1.1 Leer el libro de novedades

```bash
cd /opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/daemons/bauth/plandeaccion/bauth/
tail -80 LOG-DE-SESIONES.md
```

### 1.2 Verificar el estado oficial del plan

```bash
grep -E "🟡|⚠️" REGISTRO-ESTADO.md | head -20
grep "TOTAL" REGISTRO-ESTADO.md
```

### 1.3 Ejecutar la señal de retoma global

```bash
echo "=== SEÑAL DE RETOMA GLOBAL bAuth — $(date '+%Y-%m-%d %H:%M') ==="
echo "--- Go toolchain ---"
go version || echo "🔴 Go no instalado — B0 bloqueado"
echo "--- Build ---"
cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BauthAgent/src
go build ./... 2>&1 | tail -5 || echo "🔴 BUILD ROTO"
echo "--- Tests ---"
go test ./... 2>&1 | grep -E "ok|FAIL" | tail -10
echo "--- Vet ---"
go vet ./... 2>&1 | tail -3 || echo "⚠️ Vet warnings"
echo "--- Último commit ---"
git log --oneline -3
```

### 1.4 Determinar el siguiente átomo

```bash
grep -E "^\\| B[0-9]" REGISTRO-ESTADO.md | grep "🔴" | head -1
```

---

## FASE 2 — EJECUCIÓN DE ÁTOMOS

### 2.1 Antes de cada átomo
1. Leer la sección en `BAUTH-PLAN-MAESTRO-v1.md`
2. Leer el documento SSOT asociado
3. Verificar dependencias ✅

### 2.2 Durante la ejecución
1. Implementar el entregable descrito
2. Verificar el criterio MEDIBLE
3. Commits pequeños y frecuentes

### 2.3 Reglas
- No mezclar átomos: un commit = un átomo
- No avanzar sin verificar el criterio de aceptación
- Bloqueo inmediato: marcar ⚠️ y reportar

---

## FASE 3 — CIERRE DE SESIÓN

### 3.1 Actualizar REGISTRO-ESTADO.md
```markdown
| B0.E1.T1 | Workspace Go + estructura de módulos | ✅ | abc1234 | go build + vet limpios | ☑ | 0,2,3 | BAUTH-050 |
```

### 3.2 Registrar en LOG-DE-SESIONES.md
```markdown
## Sesión S-XXX — YYYY-MM-DD
**Átomos ejecutados:** B0.E1.T1, B0.E1.T2
**Resultado:** 2 completados, 0 bloqueados
**Build:** ✅ limpio
**Próximo átomo:** B0.E1.T3
```

### 3.3 Verificación final
- [ ] REGISTRO-ESTADO.md actualizado
- [ ] LOG-DE-SESIONES.md actualizado
- [ ] `go build ./...` limpio
- [ ] `go test ./...` verde
- [ ] `go vet ./...` limpio

---
*PROTOCOLO-SESION-AGENTE v1.0 · 2026-06-19 · SKULL*
