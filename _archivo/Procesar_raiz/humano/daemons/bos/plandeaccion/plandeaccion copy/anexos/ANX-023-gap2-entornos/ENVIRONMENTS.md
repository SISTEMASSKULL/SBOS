# F0.6 — Matriz de Entornos SBOS
> Lectura estimada: 5 minutos.

---

## Arquitectura real

```
Windows laptop (VSCode + WSL)
    ├── SSH → skull@144.91.76.130  (VPS DEV)      ← edición y compilación
    └── SSH → root@13.140.128.230  (VPS STAGING)  ← pruebas, runner CI, espejo de prod
```

```
DEV (144.91.76.130) ──git push──▶ GitHub Actions ──deploy──▶ STAGING (13.140.128.230)
                                   ubuntu-latest                self-hosted runner
                                   build + race tests           bosctl verify --full
                                                                      ↓
                                                           [aprobación manual]
                                                                      ↓
                                                                    PROD
                                                              (cuando exista)
```

---

## Tabla de entornos

| Dimensión              | DEV `144.91.76.130`            | STAGING `13.140.128.230`           | PROD (futuro)                |
|------------------------|--------------------------------|------------------------------------|------------------------------|
| **Usuario SSH**        | `skull`                        | `root`                             | TBD                          |
| **Quién lo controla**  | Desarrollador vía VSCode+WSL   | GitHub Actions self-hosted runner  | Humano con aprobación manual |
| **Datos**              | Ficticios / desarrollo         | Copia anonimizada / pruebas        | Reales                       |
| **Root ops**           | ❌ `BOS_DEV_SKIP_ROOT=1`       | ✅ Activadas (igual que prod)       | ✅ Activadas                  |
| **Feature flags**      | Todos `false` por defecto      | Se activan uno a uno               | Solo flags aprobados staging |
| **systemd**            | No (proceso manual)            | Sí (`bos-staging.service`)         | Sí (`bos.service`)           |
| **Runner CI**          | No                             | Sí (`self-hosted, linux, staging`) | No                           |

---

## Variables de entorno por entorno

### VPS DEV (`144.91.76.130`) — archivo `/etc/environment` o `~/.bashrc` de skull

```bash
BOS_ENV=dev
BOS_DEV_SKIP_ROOT=1        # Desactiva operaciones root durante desarrollo
BOS_OBSERVER_V2=false
BOS_SCHEDULER_ASYNC=false
BOS_TELEMETRY_ENABLED=false
```

### VPS STAGING (`13.140.128.230`) — unit systemd `/etc/systemd/system/bos-staging.service`

```ini
[Service]
Environment=BOS_ENV=staging
Environment=BOS_OBSERVER_V2=true
Environment=BOS_TELEMETRY_ENABLED=true
# BOS_DEV_SKIP_ROOT no existe aquí — staging se comporta igual que prod
```

### GitHub Environments (las inyecta el CI automáticamente)

```
Repositorio GitHub → Settings → Environments
    ├── staging
    │   ├── Variables: BOS_ENV=staging, BOS_OBSERVER_V2=true
    │   └── Secrets:   BOS_STAGING_BOOTSTRAP_TOKEN, STAGING_SSH_KEY
    └── production
        ├── Variables: BOS_ENV=prod, BOS_TENANT=skull
        ├── Secrets:   BOS_PROD_BOOTSTRAP_TOKEN, PROD_SSH_KEY
        └── Protection: Required reviewers (aprobación manual)
```

---

## Flujo de trabajo diario

```bash
# En Windows, abrir WSL y conectarse a DEV:
ssh skull@144.91.76.130

# Editar código (VSCode Remote SSH hace esto transparentemente)
# Cuando listo para validar:
./scripts/validate.sh          # mismos checks que CI, feedback local
./scripts/validate.sh --fast   # versión rápida (-count=1)

# Push dispara el pipeline automáticamente:
git push origin main
# → GitHub Actions corre build + race en ubuntu-latest
# → Si pasa → deploy a staging (13.140.128.230) vía self-hosted runner
# → bosctl bootstrap verify --full en staging
# → Resultado visible en github.com/skull/SBOS/actions
```

---

## Activar/desactivar feature flags

### En DEV (144.91.76.130) — temporal para la sesión:
```bash
BOS_OBSERVER_V2=true go run ./cmd/bos    # solo esta ejecución
```

### En DEV — persistente:
```bash
# Editar ~/.bashrc o /etc/environment en la VPS dev
echo 'export BOS_OBSERVER_V2=true' >> ~/.bashrc
source ~/.bashrc
```

### En STAGING (13.140.128.230) — vía systemd override:
```bash
ssh root@13.140.128.230
systemctl edit bos-staging.service
# Agregar en [Service]:
# Environment=BOS_OBSERVER_V2=true
systemctl daemon-reload && systemctl restart bos-staging.service
```

### En STAGING — vía GitHub (persiste entre deploys):
```
GitHub → Settings → Environments → staging → Variables → BOS_OBSERVER_V2 → editar
```
⚠️ Esta opción persiste aunque se haga redeploy. La opción de systemd se sobreescribe en cada deploy.

---

## Política de feature flags

| Flag                   | Tipo         | DEV     | STAGING | PROD    | Notas                               |
|------------------------|--------------|---------|---------|---------|-------------------------------------|
| `BOS_OBSERVER_V2`      | Preview      | `false` | `true`  | `false` | A prod cuando staging OK 1 sprint   |
| `BOS_SCHEDULER_ASYNC`  | Preview      | `false` | `false` | `false` | En evaluación                       |
| `BOS_DEV_SKIP_ROOT`    | Escape hatch | `true`  | —       | —       | Solo DEV, nunca en staging/prod     |
| `BOS_TELEMETRY_ENABLED`| Preview      | `false` | `true`  | `true`  | Activo en staging y prod            |

**Regla:** un flag va a prod solo cuando corrió en staging sin incidentes durante un sprint completo.

---

## Agregar una variable nueva

1. Definirla con default `false`/vacío en `~/.bashrc` de la VPS DEV
2. Agregarla en `/etc/systemd/system/bos-staging.service` con el valor staging
3. Agregarla en GitHub → Settings → Environments → staging/production → Variables
4. Documentarla en la tabla de feature flags de este archivo
5. Si es secreto: agregarla en GitHub Secrets (nunca en archivos del repo)

---

## IPs y accesos de referencia rápida

| Entorno | IP              | Usuario | Acceso          |
|---------|-----------------|---------|-----------------|
| DEV     | 144.91.76.130   | skull   | `ssh skull@144.91.76.130` |
| STAGING | 13.140.128.230  | root    | `ssh root@13.140.128.230` |

---

## Deuda técnica de seguridad — staging corre como root

**Problema actual:** el servidor de staging (`13.140.128.230`) se accede y opera como `root` directamente. El servidor de DEV (`144.91.76.130`) usa el usuario `skull` sin privilegios elevados.

**Por qué importa:** el self-hosted runner de GitHub Actions ejecuta código arbitrario del pipeline. Si corre como root (incluso indirectamente), un workflow malicioso o comprometido tiene acceso total al servidor.

**Solución recomendada:** crear un usuario `bos` en staging con los mismos privilegios mínimos que `skull` en DEV.

```bash
# Ejecutar en 13.140.128.230 como root — una sola vez
ssh root@13.140.128.230

# 1. Crear usuario no-root
useradd -m -s /bin/bash bos
passwd bos   # o usar SSH key

# 2. Agregar al grupo sudo solo para comandos específicos
#    (el script staging-runner-setup.sh ya configura sudoers para bos-runner)
#    Para acceso SSH de desarrollo, no necesita sudo

# 3. Copiar tu SSH key al nuevo usuario
mkdir -p /home/bos/.ssh
cp /root/.ssh/authorized_keys /home/bos/.ssh/
chown -R bos:bos /home/bos/.ssh
chmod 700 /home/bos/.ssh
chmod 600 /home/bos/.ssh/authorized_keys

# 4. Verificar acceso antes de cerrar sesión root
# Desde WSL:
#   ssh bos@13.140.128.230
```

**Después de crear el usuario:**
- Cambiar tu alias SSH a `ssh bos@13.140.128.230`
- Actualizar VSCode Remote SSH config
- El runner de CI sigue usando `bos-runner` (usuario de sistema sin login) — no cambia
- Mantener acceso root disponible para emergencias, pero no usarlo como acceso diario

**Estado:** pendiente. El pipeline funciona sin esto, pero debería resolverse antes de que staging maneje datos sensibles.
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
