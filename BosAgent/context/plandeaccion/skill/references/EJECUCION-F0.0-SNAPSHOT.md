# INSTRUCCIONES DE EJECUCIÓN — Átomo F0.0
## Snapshot Completo del Estado Original — Pre-Reparación
## Para: Agente ejecutor (Claude Code / desarrollador)

**Átomo:** F0.0  
**Posición:** PRIMERO DE TODO — antes de F0.1 y antes de cualquier otro átomo  
**Requiere previo:** Nada — es el punto de partida absoluto  
**Duración estimada:** 10-15 minutos  
**Riesgo:** Cero — solo lee y copia, no modifica nada  
**Reversión:** No aplica — no modifica el código

---

## Por qué existe este átomo

El plan de reparación modifica archivos existentes en `BosAgent/src/`. Sin una
foto completa del estado original, el agente pierde la referencia de cómo
estaba el código antes de cualquier cambio.

El snapshot cumple tres propósitos:

1. **Referencia segura:** el agente puede comparar el código actual contra el
   original en cualquier momento del plan — especialmente útil en F1.x, F2.x,
   F3.x cuando se extrae código de archivos grandes.

2. **Recuperación total:** si algo sale muy mal y `git revert` no es suficiente,
   existe una copia íntegra del código original fuera del historial de git.

3. **Contexto para decisiones:** ver el código original completo lado a lado
   con la documentación de la auditoría (BOS-REPAIR-00) permite entender el
   contexto exacto de cada problema antes de tocarlo.

**Analogía:** es el backup que hace un cirujano antes de operar — no porque
espere fallar, sino porque es protocolo profesional irrenunciable.

---

## PRE-CONDICIONES — Verificar antes de empezar

```bash
# 1. Explorar la raíz de BosAgent — inventariar archivos del agente anterior
ls -la /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/
# LEER cada archivo encontrado — pueden contener contexto valioso
# Registrar el inventario en SESION-LOG.md

# 2. Verificar que src/ tiene el go.mod correcto
head -1 /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/go.mod
# debe mostrar: module bos

# 3. Verificar que el build pasa antes del snapshot (snapshot del estado real)
cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src
go build ./...
# Registrar en SESION-LOG si el build pasa o falla — el snapshot captura este estado

# 4. Verificar que no hay cambios sin commit (snapshot del estado limpio)
git status --short
# Si hay cambios sin commit: documentarlos — el snapshot los incluirá
```

---

## PASO 1 — Crear la estructura del snapshot

```bash
SNAPSHOT_DIR="/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/_snapshots"
SNAPSHOT_FECHA=$(date +%Y-%m-%d_%H-%M)
SNAPSHOT_PATH="$SNAPSHOT_DIR/ORIGINAL_pre-reparacion_$SNAPSHOT_FECHA"

mkdir -p "$SNAPSHOT_PATH"
echo "Snapshot se creará en: $SNAPSHOT_PATH"
```

**Verificar:**
```bash
[ -d "$SNAPSHOT_PATH" ] && echo "✅ directorio creado" || echo "❌ FALLO"
```

---

## PASO 2 — Copiar el código fuente completo

```bash
# Copiar cmd/ completo
cp -r /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/cmd/ \
      "$SNAPSHOT_PATH/cmd/"

# Copiar internal/ completo
cp -r /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/internal/ \
      "$SNAPSHOT_PATH/internal/"

# Copiar go.mod y go.sum
cp /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/go.mod \
   "$SNAPSHOT_PATH/go.mod"
cp /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/go.sum \
   "$SNAPSHOT_PATH/go.sum" 2>/dev/null || echo "go.sum no existe — OK"

echo "✅ Código fuente copiado"
```

**Verificar:**
```bash
echo "--- Archivos en snapshot ---"
find "$SNAPSHOT_PATH" -name "*.go" | wc -l
echo "archivos .go copiados (debe ser > 20)"

echo ""
echo "--- Comparar con origen ---"
ORIG=$(find /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src \
       -name "*.go" | grep -v "_snapshots" | wc -l)
SNAP=$(find "$SNAPSHOT_PATH" -name "*.go" | wc -l)
echo "Origen: $ORIG archivos Go"
echo "Snapshot: $SNAP archivos Go"
[ "$ORIG" -eq "$SNAP" ] && echo "✅ CONTEO IDÉNTICO" || echo "⚠️  DIFERENCIA — revisar"
```

---

## PASO 3 — Copiar los archivos raíz de BosAgent/

```bash
# Los archivos en la raíz de BosAgent/ (generados por el agente anterior)
# también se preservan — pueden contener configuraciones valiosas
BOSAGENT_ROOT="/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent"
SNAPSHOT_ROOT="$SNAPSHOT_PATH/_bosagent_root"
mkdir -p "$SNAPSHOT_ROOT"

# Copiar solo archivos (no directorios) de la raíz
find "$BOSAGENT_ROOT" -maxdepth 1 -type f -exec cp {} "$SNAPSHOT_ROOT/" \;

echo "Archivos raíz de BosAgent/ preservados:"
ls -la "$SNAPSHOT_ROOT/"
```

---

## PASO 4 — Crear el manifest del snapshot

```bash
cat > "$SNAPSHOT_PATH/SNAPSHOT-MANIFEST.md" << EOF
# SNAPSHOT — Estado Original Pre-Reparación
**Fecha:** $(date '+%Y-%m-%d %H:%M')
**Átomo:** F0.0 — Snapshot completo pre-reparación
**Propósito:** Referencia inmutable del código antes de cualquier modificación

## Estado del build al crear el snapshot
$(cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src && go build ./... 2>&1 && echo "✅ BUILD LIMPIO" || echo "🔴 BUILD ROTO")

## Estado del race detector al crear el snapshot
$(cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src && go test -race -count=2 ./... 2>&1 | grep -E "DATA RACE|^ok|^FAIL" | head -10)

## Último commit del repositorio al crear el snapshot
$(cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src && git log --oneline -3)

## Cambios sin commit al crear el snapshot
$(cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src && git status --short || echo "Ninguno")

## Inventario de archivos Go copiados
$(find "$SNAPSHOT_PATH" -name "*.go" | sort)

## Inventario de archivos raíz de BosAgent/ copiados
$(ls -la "$SNAPSHOT_ROOT/" 2>/dev/null)

## Cómo usar este snapshot

### Consultar el original de un archivo durante la reparación:
\`\`\`bash
cat $SNAPSHOT_PATH/cmd/bosctl/install_ui.go | head -100
# o comparar con el actual:
diff $SNAPSHOT_PATH/cmd/bosctl/install_ui.go \\
     /opt/skull/.../BosAgent/src/cmd/bosctl/install_ui.go
\`\`\`

### Recuperar un archivo completo si algo sale muy mal:
\`\`\`bash
cp $SNAPSHOT_PATH/cmd/bosctl/install_ui.go \\
   /opt/skull/.../BosAgent/src/cmd/bosctl/install_ui.go
go build ./...  # verificar que el build vuelve a pasar
\`\`\`

### Recuperación total (caso extremo — ningún git revert funciona):
\`\`\`bash
cp -r $SNAPSHOT_PATH/cmd/     /opt/skull/.../BosAgent/src/cmd/
cp -r $SNAPSHOT_PATH/internal/ /opt/skull/.../BosAgent/src/internal/
cp    $SNAPSHOT_PATH/go.mod    /opt/skull/.../BosAgent/src/go.mod
cd /opt/skull/.../BosAgent/src && go build ./...
\`\`\`
EOF

echo "✅ Manifest creado"
cat "$SNAPSHOT_PATH/SNAPSHOT-MANIFEST.md"
```

---

## PASO 5 — Crear git tag del estado original

```bash
cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src

# Tag inmutable en git — referencia permanente del estado pre-reparación
git tag -a "pre-repair-$(date +%Y-%m-%d)" \
    -m "Estado original antes de BOS-REPAIR-PLAN-MAESTRO-v3

Snapshot físico en: $SNAPSHOT_PATH
Evaluación de partida: 3.5/10
Plan: 85 átomos, 11 fases
Inicio de reparación: $(date '+%Y-%m-%d %H:%M')"

git push origin "pre-repair-$(date +%Y-%m-%d)"

echo "✅ Tag creado:"
git tag -l "pre-repair-*"
```

**Si el push falla (sin remote configurado):**
```bash
# El tag local es suficiente — funciona para git checkout
git tag -l "pre-repair-*"
echo "✅ Tag local disponible — usar: git checkout pre-repair-YYYY-MM-DD"
```

---

## PASO 6 — Registrar en _legacy/README.md

```bash
# Asegurarse de que _legacy/ existe (F0.1 lo crea formalmente, pero el snapshot es anterior)
mkdir -p /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/_snapshots

# Agregar entrada al _legacy/README.md cuando F0.1 lo cree,
# o crear una nota ahora si es la primera sesión:
echo "## Snapshot pre-reparación" >> /tmp/nota-snapshot.md
echo "Ubicación: $SNAPSHOT_PATH" >> /tmp/nota-snapshot.md
echo "Fecha: $(date '+%Y-%m-%d %H:%M')" >> /tmp/nota-snapshot.md
echo "Git tag: pre-repair-$(date +%Y-%m-%d)" >> /tmp/nota-snapshot.md
cat /tmp/nota-snapshot.md
```

---

## DoD específico de F0.0

```bash
echo "=== DOD F0.0 ==="

# 1. El snapshot existe con contenido
SNAP_COUNT=$(find "$SNAPSHOT_PATH" -name "*.go" 2>/dev/null | wc -l)
[ "$SNAP_COUNT" -gt 20 ] \
    && echo "✅ Snapshot: $SNAP_COUNT archivos Go" \
    || echo "❌ Snapshot vacío o incompleto"

# 2. El manifest existe y tiene contenido
[ -s "$SNAPSHOT_PATH/SNAPSHOT-MANIFEST.md" ] \
    && echo "✅ Manifest completo" \
    || echo "❌ Manifest faltante"

# 3. El git tag existe
git -C /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src \
    tag -l "pre-repair-*" | grep -q "pre-repair" \
    && echo "✅ Git tag creado" \
    || echo "❌ Git tag faltante"

# 4. Los archivos raíz de BosAgent/ fueron copiados e inventariados
[ "$(ls $SNAPSHOT_ROOT/ 2>/dev/null | wc -l)" -gt 0 ] \
    && echo "✅ Archivos raíz de BosAgent/ preservados" \
    || echo "⚠️  Sin archivos raíz (OK si BosAgent/ solo tiene src/)"

# 5. El código original NO fue modificado (el snapshot no alteró nada)
cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src
git diff --quiet && echo "✅ Sin cambios en el código" || echo "⚠️  Hay cambios — verificar"
```

---

## Informe de Cierre

Crear en `plandeaccion/plandeaccion/informes-cierre/INFORME-CIERRE-F0.0-SNAPSHOT.md`:

```markdown
## INFORME DE CIERRE — F0.0 Snapshot Pre-Reparación
**Estado:** ✅ CERRADO
**Snapshot:** $SNAPSHOT_PATH
**Git tag:** pre-repair-$(date +%Y-%m-%d)
**Archivos Go preservados:** [número]
**Build al snapshotear:** ✅ LIMPIO / 🔴 ROTO
**Race condition al snapshotear:** presente (P6/P14) / no detectada
**Notas:** [cualquier observación sobre el estado inicial]
```

---

## Commit del átomo F0.0

```bash
cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src

# Agregar solo _snapshots/ (no el contenido — muy pesado para git)
echo "_snapshots/*/cmd/" >> .gitignore
echo "_snapshots/*/internal/" >> .gitignore
echo "_snapshots/*/_bosagent_root/" >> .gitignore
# Pero sí commitear los manifests
git add _snapshots/*/SNAPSHOT-MANIFEST.md
git add .gitignore 2>/dev/null

git commit -m "[F0.0] chore: snapshot pre-reparación + git tag pre-repair

Snapshot físico en _snapshots/ORIGINAL_pre-reparacion_FECHA/
Git tag: pre-repair-$(date +%Y-%m-%d)

El snapshot preserva cmd/, internal/, go.mod y archivos raíz de BosAgent/.
Permite recuperación total si git revert es insuficiente.
Sirve como referencia durante F1.x, F2.x, F3.x para comparar con el original.

Informe de Cierre: informes-cierre/INFORME-CIERRE-F0.0-SNAPSHOT.md"
```

---

*EJECUCION-F0.0-INSTRUCCIONES-AGENTE.md v1.0 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
*Este átomo es PREREQUISITO de todos los demás. Sin él, la reparación no tiene red de seguridad.*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
