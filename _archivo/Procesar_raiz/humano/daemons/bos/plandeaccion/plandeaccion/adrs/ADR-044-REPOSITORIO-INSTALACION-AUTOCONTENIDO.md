# ADR-044 — Repositorio de Instalación Autocontenido

**Estado:** Aceptado
**Fecha:** 2026-06-18
**Origen:** Corrección del proceso de instalación manual y dependencia de GitHub
**Reemplaza:** Flujo de instalación que requería múltiples pasos manuales y acceso a internet

---

## Contexto

El proceso de instalación de SBOS requería:
1. Compilar binarios en máquina de desarrollo
2. Subir binarios vía SCP a la VPS
3. Ejecutar `system-install` manualmente
4. Iniciar el daemon manualmente
5. Ejecutar `bosctl setup`
6. Intervenir manualmente para corregir errores (crear archivos, borrar StorageClasses, etc.)

Este flujo violaba múltiples principios:
- **ADR-022**: "sin intervención manual en el servidor"
- **ADR-040**: "mínimo viable progresivo" — demasiados pasos para arrancar
- **SBOS-050 P9**: dependencia de GitHub para descargar manifiestos (Calico)

Además, se generaron errores en cascada por archivos faltantes (`core/`, `servers/`)
que `system-install` no copiaba automáticamente.

## Decisión

**La instalación de SBOS se distribuye como un repositorio Git autocontenido.**
Un solo comando instala todo el plano de control sin intervención manual.

```
git clone https://github.com/SISTEMASSKULL/bos-install.git && cd bos-install
sudo ./bin/bosctl setup --mode=dev --seed ./seed-skull.yml
```

### Principios

| # | Principio | Detalle |
|---|-----------|---------|
| P1 | **Autocontenido** | Todo lo necesario está en el repo. Cero dependencias de internet. |
| P2 | **Un solo comando** | `bosctl setup` detecta daemon ausente → ejecuta system-install → inicia daemon → despliega saga. El usuario solo ejecuta UNA línea. |
| P3 | **SBOS no incluye prerrequisitos del SO** | kubeadm, kubectl, containerd son prerrequisitos como PHP lo es para Laravel. `bos-preflight` los verifica y reporta si faltan. |
| P4 | **Binarios precompilados** | `bin/bos` y `bin/bosctl` están compilados con `CGO_ENABLED=0` y commiteados. No se requiere Go en el servidor. |
| P5 | **Manifiestos offline** | Calico CNI y demás recursos están en `resources/`. Sin `curl` a GitHub durante la instalación. |
| P6 | **Fichas declarativas incluidas** | Las 22 fichas en `servers/` se copian a `/etc/bos/blibs/servers/` automáticamente. |

### Estructura del repositorio

```
bos-install/
├── bin/bos                  ← daemon precompilado
├── bin/bosctl               ← CLI precompilado
├── core/*.sh                ← motor Bash (5 scripts)
├── servers/                 ← 22 fichas declarativas
│   └── S-HOST/sbos-bootstrap-k8s/resources/
│       ├── calico-v3.32.0.yaml  ← CNI offline
│       ├── kubeadm-config.yaml
│       └── crictl.yaml
├── seed-skull.yml           ← tenant inicial
└── README.md
```

### Qué NO incluye el repositorio (prerrequisitos del SO)

| Componente | Análogo Laravel | Responsabilidad |
|-----------|----------------|-----------------|
| kubeadm, kubectl, kubelet | PHP 8.3 CLI | Administrador del SO |
| containerd | Composer | Administrador del SO |
| Ubuntu 26.04 LTS | Linux/Windows/macOS | Administrador del SO |

### Flujo automático de `bosctl setup`

```
bosctl setup
  ├─ ¿Daemon corriendo? No → system-install
  │   ├─ installBinaries    → copia bin/ a /opt/bos/bin/
  │   ├─ installCore        → copia core/ a /opt/bos/core/
  │   ├─ installBlibs       → copia servers/ a /etc/bos/blibs/servers/
  │   ├─ installEnvTemplate → crea bos-install.toml + .env
  │   ├─ installServices    → crea systemd units + enable
  │   └─ runPreflight       → ejecuta bos-preflight (verifica prereqs)
  ├─ Inicia daemon (systemctl start bos.service)
  ├─ Espera socket (/run/bos/bos.sock)
  └─ deployTenant (saga 7 pasos)
       ├─ [0/7] sbos-bootstrap-k8s (kubeadm + Calico)
       ├─ [1/7] sbos-namespace (tenant namespace + NetworkPolicy)
       ├─ [1.5] sbos-bootstrap-storage (StorageClass + PVs)
       ├─ [2/7] postgresql (StatefulSet 18.4)
       ├─ [3/7] redis (8.6.2)
       ├─ [4/7] vault (2.0.1)
       ├─ [5/7] keycloak (26.6.2)
       ├─ [6/7] DDL Context Plane
       └─ [7/7] kong (API Gateway)
```

## Consecuencias

- ✅ **Instalación en un paso**: clone + setup. Sin pasos manuales intermedios.
- ✅ **Sin dependencia de GitHub en runtime**: los manifiestos están en el repo.
- ✅ **Versionado**: cada release de SBOS es un tag del repo `bos-install`.
- ✅ **Auditable**: todo el contenido del deploy está en git, con hash SHA.
- ✅ **Reproducible**: mismo repo, mismo resultado. Sin drift de configuración.
- ✅ **Offline-capable**: copiar el repo por USB a un servidor sin internet.

---

*Revisión: cuando se modifique el proceso de instalación o se agreguen nuevos prerrequisitos.*
