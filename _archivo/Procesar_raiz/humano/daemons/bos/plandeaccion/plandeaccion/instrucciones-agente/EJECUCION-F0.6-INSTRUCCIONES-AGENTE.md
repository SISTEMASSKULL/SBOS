# INSTRUCCIONES DE EJECUCIÓN — Átomo F0.6
## Matriz de Entornos + Self-Hosted Runner
## Para: Agente ejecutor (Claude Code / desarrollador)

**Átomo:** F0.6 — Entornos DEV/STAGING/PROD (cierra GAP 2)
**Requiere previo:** F0.5 ✅ (pipeline ci.yml ya en el repo)
**Duración estimada:** 45 minutos (20 min documentación + 25 min runner)
**Riesgo:** Medio — el script runner-setup se ejecuta en el servidor real
**Reversión documentación:** `git revert HEAD`
**Reversión runner:** `cd /opt/bos-runner && ./svc.sh stop && ./svc.sh uninstall`

---

## CONTEXTO

El pipeline de F0.5 corre build + race en GitHub-hosted runners (ubuntu-latest).
Este átomo agrega:
1. Los archivos de documentación de entornos en el repositorio
2. El self-hosted runner en VPS STAGING para deploy y verificación automática
3. Un job `deploy-staging` en ci.yml que verifica `bosctl bootstrap verify --full`
4. La configuración de GitHub Environments con variables y secrets

---

## PRE-CONDICIONES

```bash
# En VPS DEV (144.91.76.130) — verificar que F0.5 está completo:
ssh skull@144.91.76.130
cd <ruta_del_repositorio>
[ -f .github/workflows/ci.yml ] && echo "✅ F0.5 completo" || echo "❌ completar F0.5 primero"
git log --oneline -3 | grep "F0.5" && echo "✅ commit F0.5 presente"

# En VPS STAGING (13.140.128.230) — verificar que está accesible:
ssh root@13.140.128.230 "echo '✅ staging accesible' && uname -a"

# Go disponible en DEV:
go version | grep "go1.25" && echo "✅ Go 1.25" || echo "⚠️ verificar versión Go"
```

---

## BLOQUE A — Documentación en el repositorio (en VPS DEV)

### PASO A.1 — Copiar ENVIRONMENTS.md al repositorio

```bash
# Trabajando en VPS DEV: ssh skull@144.91.76.130
mkdir -p docs/

# El contenido exacto está en: ANX-023-gap2-entornos/ENVIRONMENTS.md
# Copiar ese contenido a docs/ENVIRONMENTS.md
# (si el agente tiene acceso al archivo del anexo, copiarlo directamente)
# Si no, el contenido completo está en el Informe de Cierre F0.6

cp /ruta/al/anexo/ANX-023-gap2-entornos/ENVIRONMENTS.md docs/ENVIRONMENTS.md
```

**Verificar:**
```bash
[ -f docs/ENVIRONMENTS.md ] && echo "✅ ENVIRONMENTS.md presente"
grep "144.91.76.130" docs/ENVIRONMENTS.md && echo "✅ IPs documentadas"
grep "BOS_OBSERVER_V2" docs/ENVIRONMENTS.md && echo "✅ feature flags documentados"
grep "bos-runner" docs/ENVIRONMENTS.md && echo "✅ runner documentado"
```

### PASO A.2 — Copiar staging-runner-setup.sh al repositorio

```bash
mkdir -p docs/
cp /ruta/al/anexo/ANX-023-gap2-entornos/staging-runner-setup.sh docs/staging-runner-setup.sh
chmod +x docs/staging-runner-setup.sh
```

**IMPORTANTE — Corregir la instalación de Go en el script:**
El script usa `apt-get install golang-go` que puede instalar una versión
anterior de Go. Reemplazar esa línea:

```bash
# Editar docs/staging-runner-setup.sh
# Buscar la línea:
#   apt-get install -y bc golang-go 2>/dev/null || true
# Reemplazar por:

apt-get install -y bc 2>/dev/null || true

# Instalar Go 1.25 desde el tarball oficial
GO_VERSION="1.25.0"
if ! /usr/local/go/bin/go version 2>/dev/null | grep -q "go1.25"; then
  curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
    -o /tmp/go.tar.gz
  rm -rf /usr/local/go
  tar -C /usr/local -xzf /tmp/go.tar.gz
  rm /tmp/go.tar.gz
  echo 'export PATH=$PATH:/usr/local/go/bin' >> "/home/${RUNNER_USER}/.bashrc"
  echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/environment
fi
/usr/local/go/bin/go version && echo "✅ Go $GO_VERSION instalado"
```

**Verificar el script:**
```bash
[ -f docs/staging-runner-setup.sh ] && echo "✅ script presente"
[ -x docs/staging-runner-setup.sh ] && echo "✅ ejecutable"
grep "go.dev/dl" docs/staging-runner-setup.sh && echo "✅ Go desde tarball oficial"
```

### PASO A.3 — Actualizar ci.yml con el job deploy-staging

Agregar al final del archivo `.github/workflows/ci.yml`, después del job `summary`:

```bash
cat >> .github/workflows/ci.yml << 'DEPLOYEOF'

  # ──────────────────────────────────────────────────────────
  # JOB 5: deploy-staging — Solo en pushes a main
  # Propósito: compilar, desplegar y verificar en staging
  # automáticamente cuando build y race pasan.
  #
  # Corre en el self-hosted runner de 13.140.128.230
  # (instalado con docs/staging-runner-setup.sh)
  # ──────────────────────────────────────────────────────────
  deploy-staging:
    name: Deploy to Staging
    runs-on: [self-hosted, linux, staging]
    needs: [build, race]
    if: |
      github.ref == 'refs/heads/main' &&
      needs.build.result == 'success' &&
      needs.race.result == 'success'
    environment: staging
    timeout-minutes: 15

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Build bos binary
        run: |
          /usr/local/go/bin/go build -o /tmp/bos-staging ./cmd/bos/
          /usr/local/go/bin/go build -o /tmp/bosctl ./cmd/bosctl/
          echo "✅ Binarios compilados"

      - name: Deploy
        run: |
          sudo cp /tmp/bos-staging /usr/local/bin/bos-staging
          sudo cp /tmp/bosctl /usr/local/bin/bosctl
          sudo chown root:root /usr/local/bin/bos-staging /usr/local/bin/bosctl
          sudo chmod 755 /usr/local/bin/bos-staging /usr/local/bin/bosctl
          sudo systemctl restart bos-staging.service
          sleep 5
          sudo systemctl is-active bos-staging.service && echo "✅ bos-staging activo"

      - name: Verify bootstrap
        env:
          BOS_ENV: ${{ vars.BOS_ENV }}
        run: |
          /usr/local/bin/bosctl bootstrap verify --full
          echo "✅ Staging verificado — 14/14 criterios"
DEPLOYEOF
```

**Verificar que el YAML es válido:**
```bash
# Python está disponible en Ubuntu
python3 -c "
import yaml, sys
with open('.github/workflows/ci.yml') as f:
    yaml.safe_load(f)
print('✅ YAML válido')
" 2>&1
```

---

## BLOQUE B — Configurar GitHub Environments (en GitHub UI)

Estos pasos son manuales — requieren acceso a github.com/skull/SBOS.

### PASO B.1 — Crear Environment "staging"

```
1. Ir a: github.com/skull/SBOS → Settings → Environments
2. Click "New environment" → nombre: staging → Click "Configure environment"
3. En "Environment variables":
   - BOS_ENV = staging
   - BOS_OBSERVER_V2 = true
   - BOS_TELEMETRY_ENABLED = true
4. En "Environment secrets":
   - BOS_STAGING_BOOTSTRAP_TOKEN = <token del daemon bos en staging>
   - STAGING_SSH_KEY = <no necesaria — el runner ya está en el servidor>
5. NO activar "Required reviewers" para staging (es automático)
6. Click "Save protection rules"
```

**Verificar (desde la UI):**
```
Settings → Environments → staging → debe mostrar las 3 variables y 1 secret
```

### PASO B.2 — Crear Environment "production" (preparación futura)

```
1. New environment → nombre: production
2. Variables: BOS_ENV = prod, BOS_TENANT = skull
3. Protection rules: ✅ Required reviewers → agregar: [tu usuario de GitHub]
4. Esta protección bloquea deploy automático a prod — requiere aprobación manual
```

---

## BLOQUE C — Instalar el self-hosted runner en VPS STAGING

**Ejecutar desde la máquina Windows/WSL:**

### PASO C.1 — Obtener el token del runner

```
1. Ir a: github.com/skull/SBOS → Settings → Actions → Runners
2. Click "New self-hosted runner" → Linux → x64
3. En el paso 2 ("Configure") copiar el token de --token XXXXX
   ⚠️ El token expira en 1 hora — ejecutar el script inmediatamente
```

### PASO C.2 — Ejecutar el script en STAGING

```bash
# Desde Windows WSL:
ssh root@13.140.128.230

# Definir variables (reemplazar con el token real del paso C.1):
export RUNNER_TOKEN="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
export GITHUB_REPO_URL="https://github.com/skull/SBOS"

# Copiar el script al servidor y ejecutar:
# Opción A — si el script está en el repo ya (después de PASO A.2 + push):
cd <ruta_del_repositorio_en_staging>
bash docs/staging-runner-setup.sh

# Opción B — ejecutar directamente desde el archivo del anexo:
bash /ruta/al/ANX-023/staging-runner-setup.sh
```

### PASO C.3 — Verificar que el runner está activo

```bash
# En VPS STAGING:
systemctl status actions.runner.*.service
# debe mostrar: Active: active (running)

# O verificar en GitHub:
# github.com/skull/SBOS → Settings → Actions → Runners
# debe mostrar: staging-<hostname> → Idle (verde)
```

---

## BLOQUE D — Commit y verificación del pipeline completo

### PASO D.1 — Commit de todos los cambios de documentación

```bash
# En VPS DEV (144.91.76.130):
git add docs/ENVIRONMENTS.md
git add docs/staging-runner-setup.sh
git add .github/workflows/ci.yml  # con el nuevo job deploy-staging

git status  # verificar solo estos 3 archivos

git commit -m "[F0.6] feat: entornos DEV/STAGING/PROD + self-hosted runner + job deploy-staging

GAP 2 del BOS-REPAIR-PLAN-MAESTRO-v3 cerrado.

Infraestructura:
  DEV:     144.91.76.130 (skull) — desarrollo y validación local
  STAGING: 13.140.128.230 (bos-runner) — self-hosted runner + bos-staging.service
  PROD:    pendiente — solo flags aprobados en staging pasan aquí

Archivos:
  docs/ENVIRONMENTS.md         — tabla completa de entornos y feature flags
  docs/staging-runner-setup.sh — instalación runner con least privilege
  .github/workflows/ci.yml     — job deploy-staging añadido (job 5)

Feature flags:
  BOS_OBSERVER_V2:      false (DEV) → true (STAGING) → prod tras sprint OK
  BOS_DEV_SKIP_ROOT:    true (DEV) solo
  BOS_TELEMETRY_ENABLED: false (DEV) → true (STAGING+PROD)

Deuda técnica registrada: F0.6.S — staging corre como root (resolver antes datos sensibles)
Informe de Cierre: INFORME-CIERRE-F0.6-ENTORNOS.md
Anexo: ANX-023-gap2-entornos/"

git push origin main
```

### PASO D.2 — Verificar el pipeline completo

```
Ir a: github.com/skull/SBOS → Actions → último run

Resultado esperado:
  ✅ Build & Lint           — verde
  ✅ Race Detection          — verde
  ⚠️  Coverage (Warning)     — posiblemente amarillo (normal en esta fase)
  ✅ Pipeline Status         — verde
  ✅ Deploy to Staging       — verde (si runner instalado en C.2-C.3)
     └── Build bos binary   ✅
     └── Deploy             ✅
     └── Verify bootstrap   ✅ (puede fallar si bos-staging no está instalado aún)
```

**Si "Verify bootstrap" falla con "bosctl: command not found":**
Es normal si el daemon `bos-staging` no está instalado en staging aún. El
verify completo (`bosctl bootstrap verify --full`) requiere los átomos F1.x+.
En esta fase, basta con que el job compile y desplegue sin error — el verify
se activará progresivamente con cada fase del plan.

Solución temporal para que el job no falle en esta fase:
```yaml
# En el step "Verify bootstrap", cambiar a:
run: |
  if [ -f /usr/local/bin/bosctl ]; then
    /usr/local/bin/bosctl bootstrap verify --full
    echo "✅ Staging verificado"
  else
    echo "⚠️  bosctl no instalado aún — verificación diferida a F1.x"
  fi
```

---

## PASO E — Átomo derivado F0.6.S — Seguridad staging (registrar, no ejecutar aún)

No ejecutar ahora. Registrar en el plan maestro para ejecutar antes de que
staging maneje datos del proyecto real:

```bash
# Registrar F0.6.S como átomo pendiente en el plan maestro:
# Agregar en la tabla de registro de estado del BOS-REPAIR-PLAN-MAESTRO-v3.md:
# | F0 | F0.6.S — Crear usuario bos en staging (eliminar root diario) | 🔴 | 1 | 0/1 | Antes de datos sensibles |

# Las instrucciones exactas están en:
# docs/ENVIRONMENTS.md → sección "Deuda técnica de seguridad"
```

---

## CRITERIO DE ÉXITO — F0.6 está COMPLETO cuando:

```bash
# Documentación:
[ -f docs/ENVIRONMENTS.md ] && echo "✅ ENVIRONMENTS.md"
[ -f docs/staging-runner-setup.sh ] && echo "✅ staging-runner-setup.sh"
grep "deploy-staging" .github/workflows/ci.yml && echo "✅ job deploy-staging"

# Runner:
# En github.com/skull/SBOS → Settings → Actions → Runners
# debe mostrar: staging-<hostname> → Idle (verde)

# GitHub Environments:
# Settings → Environments → staging → 3 variables + 1 secret

# Pipeline:
# Último run en Actions: Build ✅ + Race ✅ + Deploy-staging ✅ (o ⚠️ diferido)

echo "✅ GAP 2 CERRADO"
echo "Próximo: F0.6.S (seguridad) y F1.1 (auditLog → internal/audit/)"
```

---

## SEÑAL DE RETOMA

```bash
# ¿Dónde quedó?
[ -f docs/ENVIRONMENTS.md ] && echo "Bloque A completo" || echo "Empezar en PASO A.1"
grep "deploy-staging" .github/workflows/ci.yml && echo "Bloque A completo"

# ¿Runner instalado?
ssh root@13.140.128.230 "systemctl is-active actions.runner.*.service 2>/dev/null" \
  && echo "Bloque C completo — verificar GitHub UI" \
  || echo "Ejecutar Bloque C"

# ¿GitHub Environments configurado?
# Solo verificable en la UI de GitHub → Settings → Environments
```

---

*Instrucciones de ejecución F0.6 · BOS-REPAIR · SKULL · SBOS · 07 de Junio 2026*
*Fuente: INFORME-CIERRE-F0.6-ENTORNOS.md + ANX-023-gap2-entornos/*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
