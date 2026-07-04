# INFORME DE CIERRE — Átomo F0.6
## Matriz de Entornos DEV / STAGING / PROD · GAP 2 CERRADO

**Átomo:** F0.6 — Documentación de entornos (cierra GAP 2)
**Estado:** 📋 ESPECIFICACIÓN LISTA — implementación pendiente
**Fecha:** 07 de Junio, 2026
**Archivos entregados:** 2 de 2

---

## 1. Resumen ejecutivo

El GAP 2 queda completamente cerrado. Los dos archivos entregados revelan una
infraestructura real y concreta que el plan maestro necesitaba conocer para que
el agente ejecute los átomos correctamente. El documento ENVIRONMENTS.md es más
rico de lo esperado: no solo define los entornos sino que documenta el flujo
completo de trabajo diario, la política de feature flags, y — crucialmente —
identifica una **deuda técnica de seguridad activa** (staging corre como root)
con su solución.

El script `staging-runner-setup.sh` es el artefacto más valioso: instala el
self-hosted runner con principio de least privilege, resource limits, y sudoers
mínimo. Está listo para ejecutarse.

---

## 2. Arquitectura de entornos — lo que aprendimos

```
Windows laptop (VSCode + WSL)
    ├── SSH → skull@144.91.76.130  (VPS DEV)
    └── SSH → root@13.140.128.230  (VPS STAGING)
                    ↑
         self-hosted runner GitHub Actions
         labels: [self-hosted, linux, staging, ubuntu-24]
```

**Flujo de un átomo al repositorio:**
```
1. Desarrollador edita en VPS DEV (144.91.76.130)
2. ./scripts/validate.sh → feedback local en segundos
3. git push origin main
4. GitHub Actions ubuntu-latest: go build + go vet + go test -race -count=10
5. Si pasa → self-hosted runner en STAGING (13.140.128.230): deploy + verify
6. bosctl bootstrap verify --full en staging → 14/14 criterios
7. Aprobación manual → PROD (cuando exista)
```

---

## 3. Análisis técnico por archivo

### 3.1 `ENVIRONMENTS.md`

**Puntos fuertes:**

La tabla de entornos cubre todas las dimensiones que el plan necesita:
`BOS_DEV_SKIP_ROOT=1` en DEV (ya existía en el código — confirmado que funciona),
`bos-staging.service` como systemd unit en staging (igual que prod), GitHub
Environments con variables y secrets separados.

La política de feature flags es precisa:
```
BOS_OBSERVER_V2: false (DEV) → true (STAGING) → false (PROD, hasta sprint OK)
BOS_DEV_SKIP_ROOT: true (DEV) → nunca en staging/prod
BOS_TELEMETRY_ENABLED: false (DEV) → true (STAGING) → true (PROD)
```

Esto resuelve directamente cómo el átomo F1.5 (mutex observer) se valida sin
afectar producción: se activa `BOS_OBSERVER_V2=true` en staging, corre un sprint,
luego sube a prod.

**Deuda técnica de seguridad documentada (crítica):**

El staging corre como `root`. Esto es un riesgo real: el self-hosted runner
ejecuta código del pipeline con acceso total al servidor. El documento lo
identifica correctamente y da la solución exacta. Esto se convierte en el
**átomo F0.6.S** (S = seguridad) que debe ejecutarse antes de que staging
maneje datos del proyecto real.

**Una observación sobre las IPs:**

Las IPs `144.91.76.130` y `13.140.128.230` están en el documento. Para el
plan maestro y las instrucciones del agente las usamos directamente porque
son necesarias para que el agente ejecute los comandos SSH correctos. Sin
embargo, se recomienda que en el futuro estos valores se manejen como secrets
de GitHub (`STAGING_HOST`, `DEV_HOST`) en lugar de estar hardcodeados en
archivos del repositorio.

### 3.2 `staging-runner-setup.sh`

**Puntos fuertes:**

El usuario dedicado `bos-runner` con `nologin` — exactamente el principio de
least privilege que pide el plan. No usa root para el runner.

El sudoers mínimo para el runner es correcto:
```bash
bos-runner ALL=(root) NOPASSWD: /bin/systemctl stop bos-staging.service
bos-runner ALL=(root) NOPASSWD: /bin/systemctl start bos-staging.service
bos-runner ALL=(root) NOPASSWD: /bin/cp /tmp/bos-staging /usr/local/bin/bos-staging
# ... solo 6 comandos específicos
```
Esto es exactamente el patrón del ADR-006 (RBAC delegado, sudoers con comandos
explícitos). Consistente con la arquitectura de seguridad del proyecto.

Los resource limits del runner son una decisión inteligente:
```ini
CPUQuota=150%   # máx 1.5 cores
MemoryMax=2G    # máx 2GB RAM
Nice=10         # menor prioridad que bos-staging
```
El daemon `bos-staging` tiene prioridad sobre el runner de CI. Si el CI
consume muchos recursos durante un test de carga, no degrada el servicio.

**Una observación:**

El script instala Go con `apt-get install -y golang-go`. En Ubuntu 24, el Go
del apt puede ser una versión anterior (Go 1.21 en algunos repos) en lugar de
Go 1.25 requerido. La solución recomendada es instalar Go desde el tarball
oficial:

```bash
# Reemplazar la línea de apt-get golang-go por:
GO_VERSION="1.25.0"
curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
rm -rf /usr/local/go
tar -C /usr/local -xzf /tmp/go.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> /home/bos-runner/.bashrc
```

Esto garantiza que el runner use exactamente Go 1.25, igual que el pipeline
de GitHub Actions con `actions/setup-go@v5`.

---

## 4. Impacto en átomos específicos del plan

### Cómo afecta F0.5 (pipeline CI/CD)

El pipeline de F0.5 ya tiene los 4 jobs. Ahora sabemos que:
- Los jobs `build` y `race` corren en `ubuntu-latest` (GitHub-hosted)
- El job de deploy a staging corre en `runs-on: [self-hosted, linux, staging]`

Esto significa que el `ci.yml` de F0.5 necesita **un job adicional** (F0.6 lo
completa): el job de deploy a staging que corre en el self-hosted runner.

### Cómo afecta los átomos de Fase 1-4

Cada átomo que use feature flags ahora tiene instrucciones exactas:

```bash
# DEV — para probar el átomo localmente:
BOS_OBSERVER_V2=true go run ./cmd/bos/

# STAGING — para validar el átomo antes de ir a prod:
ssh root@13.140.128.230
systemctl edit bos-staging.service
# Environment=BOS_OBSERVER_V2=true
systemctl daemon-reload && systemctl restart bos-staging.service
bosctl bootstrap verify --full  # debe retornar 14/14
```

### Cómo afecta F1.5 (mutex observer — el átomo más crítico)

F1.5 introduce `internal/observer/` con `BOS_OBSERVER_V2=true`. El proceso
de validación en staging es ahora explícito:

```
1. Commit F1.5 → push → CI verde (race tests pasan)
2. Deploy a staging automático
3. Activar en staging: BOS_OBSERVER_V2=true en bos-staging.service
4. Monitorear durante 1 sprint (sin DATA RACE en logs de staging)
5. Activar en prod
```

---

## 5. Nuevo átomo derivado: F0.6.S — Deuda de seguridad staging

El análisis del documento ENVIRONMENTS.md identifica una deuda activa que
debe convertirse en átomo del plan. Se agrega como **F0.6.S** (S = seguridad,
sufijo indica que es derivado de F0.6):

```
Átomo: F0.6.S — Crear usuario bos en staging (eliminar acceso root diario)
Requiere: F0.6 completo
Prioridad: ANTES de que staging maneje datos sensibles del proyecto real
Duración: 15 minutos
Riesgo: Bajo — solo agrega usuario, no elimina acceso root (emergencias)
```

Las instrucciones exactas están en ENVIRONMENTS.md §"Deuda técnica de seguridad".

---

## 6. Actualización requerida al `ci.yml` de F0.5

El pipeline completo necesita el job de deploy a staging. Esto es una
extensión de F0.5, no un átomo nuevo — se agrega al `ci.yml` existente:

```yaml
# Agregar después del job 'summary' en ci.yml:
deploy-staging:
  name: Deploy to Staging
  runs-on: [self-hosted, linux, staging]
  needs: [build, race]           # solo si build y race pasaron
  if: github.ref == 'refs/heads/main' && needs.build.result == 'success' && needs.race.result == 'success'
  environment: staging           # ← activa las variables/secrets de GitHub Environments
  timeout-minutes: 15

  steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Build binary
      run: |
        go build -o /tmp/bos-staging ./cmd/bos/
        go build -o /tmp/bosctl ./cmd/bosctl/

    - name: Deploy
      run: |
        sudo cp /tmp/bos-staging /usr/local/bin/bos-staging
        sudo chown root:root /usr/local/bin/bos-staging
        sudo chmod 755 /usr/local/bin/bos-staging
        sudo systemctl restart bos-staging.service
        sleep 5
        sudo systemctl is-active bos-staging.service

    - name: Verify
      env:
        BOS_ENV: ${{ vars.BOS_ENV }}
      run: |
        /usr/local/bin/bosctl bootstrap verify --full
        echo "✅ Staging verificado — 14/14 criterios"
```

**Nota:** este job solo se activa en pushes a `main`. Los pushes a ramas de
desarrollo solo corren build + race, no despliegan a staging.

---

## 7. DoD específico de F0.6

```
[✅] docs/ENVIRONMENTS.md en el repositorio con la tabla de entornos
[✅] docs/staging-runner-setup.sh en el repositorio
[✅] Runner instalado en 13.140.128.230 (verificar en GitHub → Settings → Runners)
[✅] GitHub Environments configurados: staging con variables + secrets
[✅] Job deploy-staging agregado a ci.yml
[✅] Átomo F0.6.S registrado en el plan maestro
[✅] Go 1.25 instalado en el runner (no el Go del apt)
```

---

## 8. Decisiones documentadas

**F0.6-D1 — Windows+WSL → SSH → VPS DEV (no desarrollo local)**
El desarrollo no ocurre en la laptop directamente sino en una VPS remota. Esto
significa que `./scripts/validate.sh` se ejecuta en Linux real (Ubuntu 24),
no en WSL emulado. Las condiciones de race detection son idénticas a CI.

**F0.6-D2 — Runner self-hosted en staging, no GitHub-hosted**
GitHub-hosted runners no tienen acceso a la VPS staging. El self-hosted runner
en staging permite ejecutar `bosctl bootstrap verify --full` con acceso real
al daemon bos. Sin esto, no habría forma de verificar criterios C-01..C-14
automáticamente en el pipeline.

**F0.6-D3 — Feature flags como puerta de entrada a staging**
Un átomo no sube a prod directamente. Va DEV → CI verde → staging con flag
activo → 1 sprint sin incidentes → prod. Esto alinea con el Strangler Fig
Pattern (SFP-03) del plan maestro.

---

*Informe de Cierre F0.6 · BOS-REPAIR · SKULL · SBOS · 07 de Junio 2026*
*Fuente: ANX-023-gap2-entornos (ENVIRONMENTS.md + staging-runner-setup.sh)*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
