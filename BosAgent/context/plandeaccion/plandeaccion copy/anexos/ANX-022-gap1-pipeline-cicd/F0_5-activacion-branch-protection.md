# F0.5 — Activación de Branch Protection en GitHub
# ============================================================
# Este archivo documenta los pasos exactos para activar
# la protección del branch `main` una vez que el pipeline
# CI esté corriendo correctamente.
#
# Con commit directo a main (workflow actual), el pipeline
# actúa como red de seguridad POST-commit.
#
# Para convertirlo en GATE que BLOQUEA antes del merge,
# seguir los pasos de la Fase 2 de este documento.
# ============================================================

## FASE 1 — Estado actual (commit directo a main)

El pipeline `.github/workflows/ci.yml` ya funciona:
- Cada `git push` a main dispara el pipeline automáticamente
- GitHub marca cada commit con ✅ o ❌ en el historial
- Si el pipeline falla, recibes email inmediato
- El commit YA está en main, pero el problema queda visible

**Para verificar que funciona:**
```bash
git push origin main
# Ir a: https://github.com/TU_ORG/SBOS/actions
# Deberías ver el workflow "CI" corriendo
```

---

## FASE 2 — Branch Protection (cuando el equipo esté listo)

Activar cuando se quiera que el pipeline BLOQUEE merges.

### Opción A: Desde la UI de GitHub

1. Ir a **Settings → Branches** en el repositorio
2. Click **"Add branch protection rule"**
3. En **Branch name pattern**: escribir `main`
4. Activar:
   - ✅ **Require status checks to pass before merging**
   - ✅ **Require branches to be up to date before merging**
   - En el campo de búsqueda, agregar estos status checks:
     - `Build & Lint`
     - `Race Detection (HARD GATE)`
     - `Pipeline Status`
   - ❌ NO agregar `Coverage (Warning Only)` — es advertencia
5. **Opcional pero recomendado:**
   - ✅ **Require a pull request before merging**
   - ✅ **Dismiss stale pull request approvals when new commits are pushed**
6. Click **"Create"**

### Opción B: Con GitHub CLI (automatizable)

```bash
# Instalar gh si no está: https://cli.github.com/
gh auth login

gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["Build & Lint","Race Detection (HARD GATE)","Pipeline Status"]}' \
  --field enforce_admins=false \
  --field required_pull_request_reviews=null \
  --field restrictions=null
```

---

## FASE 3 — Convertir Coverage en Hard Gate

Cuando todos los paquetes del plan de 98 átomos tengan tests:

1. En `.github/workflows/ci.yml`, en el job `coverage`:
   ```yaml
   # Cambiar:
   - name: Coverage gate (WARNING)
     continue-on-error: true   # ← QUITAR ESTA LÍNEA
   ```

2. En `scripts/validate.sh`, descomentar:
   ```bash
   # exit 1  ← descomentar cuando sea hard gate
   ```

3. Agregar `Coverage (Warning Only)` a los status checks
   de branch protection (Opción A o B arriba).

---

## Estructura de archivos en el repositorio

```
SBOS/
├── .github/
│   └── workflows/
│       └── ci.yml          ← Pipeline principal (ESTE ARCHIVO)
├── scripts/
│   └── validate.sh         ← Validación local pre-commit
├── go.mod
├── go.sum
└── ...
```

---

## Troubleshooting

### "El workflow no aparece en Actions"
- Verificar que el archivo está en `.github/workflows/ci.yml`
- El directorio `.github` debe estar en la raíz del repo
- Verificar la sintaxis YAML: https://yaml-online-parser.appspot.com/

### "GORACE halt_on_error no está funcionando"
- Verificar con: `GORACE="halt_on_error=1" go test -race ./... 2>&1 | head -20`
- Si hay race, debe verse: `SIGABRT` o `exit status 1`

### "El job de race tarda demasiado"
- -count=10 con -race puede ser lento en paquetes grandes
- Opción: reducir a -count=5 para feedback más rápido
- Opción: agregar -parallel=4 si el servidor tiene múltiples cores

### "Cache no está funcionando"
- setup-go v5 cachea automáticamente usando go.sum como key
- Si go.sum cambia, el cache se invalida (correcto)
- Para forzar cache reset: Actions → Caches → Delete
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
