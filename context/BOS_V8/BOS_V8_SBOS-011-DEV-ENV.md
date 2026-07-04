# SBOS-011-DEV-ENV
## Entorno de Desarrollo — Estándar HUMAN-DOC
### SKULL · SBOS · V8 · Mayo 2026

---

## 1. SO del Desarrollador y Destino

| Campo | Valor |
|---|---|
| SO desarrollo | Windows 11 + WSL2 / Linux nativo |
| SO destino producción | Ubuntu Server 26.04 LTS |
| Conexión | SSH a VPS Linux |
| Contenedores | Podman (Docker VETADO) |

---

## 2. Modelo de Desarrollo: Todo en Ubuntu Server

**Principio fundamental:** todo el desarrollo ocurre en el servidor Ubuntu. La estación del
desarrollador (Windows/Linux) es solo la interfaz de edición. Este modelo, adoptado del
SBOS-IAM-Style Brand System y validado en SBOS-011-DEV-ENV, garantiza uniformidad del
entorno independientemente del SO del desarrollador.

```
┌─────────────────────────────────────────────────────────────────────┐
│  SERVIDOR UBUNTU — donde ocurre TODO                                │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  VS Code Remote SSH (interfaz visual desde Windows/Linux)     │  │
│  │  · El código vive aquí                                        │  │
│  │  · Las extensiones corren aquí                                │  │
│  │  · La terminal integrada es bash en Ubuntu                    │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌──────────────────┐  ┌────────────────────────┐                   │
│  │  Podman Stack    │  │  Flutter SDK             │                   │
│  │  · Daemons Go    │  │  · Core UI + Composer    │                   │
│  │  · PostgreSQL    │  │  · Compilación cruzada   │                   │
│  │  · MinIO         │  │    → Linux AppImage      │                   │
│  └──────────────────┘  │    → Windows .exe        │                   │
│                        └────────────────────────┘                   │
└─────────────────────────────────────────────────────────────────────┘
```

**Lo que NUNCA se instala en la estación del desarrollador:**
- Python / pip / uv (en el servidor Ubuntu)
- Podman / Buildah / Skopeo (en el servidor Ubuntu)
- Flutter SDK (en el servidor Ubuntu)
- Rust toolchain (en el servidor Ubuntu)
- Go toolchain (en el servidor Ubuntu)

**Lo ÚNICO que se instala en la estación del desarrollador:**
- VS Code con la extensión Remote SSH
- Cliente SSH (nativo en Linux/WSL, OpenSSH en Windows)

---

## 3. IDE Principal — Visual Studio Code

**Decisión formal:** VS Code como IDE oficial del proyecto. Decisión tomada en SBOS-COMPLETITUD-v2 §2 B2.4.

**Fundamento:** Stack Overflow Developer Survey 2025 confirma que VS Code es el IDE más usado por >70% de los desarrolladores durante 5 años consecutivos. Para el perfil específico del SBOS (monorepo polyglot Rust + Go + Python + Dart + Bash en Windows/Linux via SSH remota), VS Code es la opción superior por: Remote-SSH nativo, rust-analyzer oficial, extensión Go oficial de Google, extensión Flutter oficial de Google, y peso ligero vs JetBrains (4-8x menos RAM en desarrollo remoto). Licencia MIT — sin costo de suscripción.

### Extensiones requeridas del proyecto

```json
// .vscode/extensions.json
{
  "recommendations": [
    "rust-lang.rust-analyzer",        // Rust (bkernel, biedata)
    "golang.go",                       // Go (bos, bCompass, bSearch, bAuth, bhnexus, banexus)
    "ms-python.python",               // Python (módulos IAM Installer)
    "ms-python.pylance",              // Python language server
    "dart-code.flutter",              // Flutter/Dart (Core UI)
    "dart-code.dart-code",            // Dart language support
    "redhat.vscode-yaml",             // YAML (fichas, reglas bKernel, cajas biedata)
    "ms-vscode-remote.remote-ssh",    // SSH remota a VPS Linux
    "eamodio.gitlens",                // Git blame, historial, anotaciones
    "EditorConfig.EditorConfig",      // Garantiza LF Unix en todos los archivos
    "timonwong.shellcheck",           // Bash linting (Core SP-01, task_catalog.sh)
    "foxundermoon.shell-format",      // Bash formatting
    "ms-kubernetes-tools.vscode-kubernetes-tools", // K8s manifests
    "ms-azuretools.vscode-docker"     // Containerfile / Podman (via Docker extension)
  ]
}
```

### Configuración base del workspace

```json
// .vscode/settings.json
{
  "files.eol": "\n",
  "editor.formatOnSave": true,
  "editor.rulers": [100],
  "[rust]":       { "editor.defaultFormatter": "rust-lang.rust-analyzer" },
  "[go]":         { "editor.defaultFormatter": "golang.go" },
  "[python]":     { "editor.defaultFormatter": "ms-python.python" },
  "[dart]":       { "editor.defaultFormatter": "dart-code.dart-code" },
  "[shellscript]":{ "editor.defaultFormatter": "foxundermoon.shell-format" },
  "rust-analyzer.cargo.features": "all",
  "go.lintTool": "golangci-lint",
  "go.testFlags": ["-race", "-count=1"],
  "terminal.integrated.defaultProfile.windows": "Git Bash"
}
```

---

## 4. Configuración SSH para Acceso Remoto

La conexión SSH desde la estación del desarrollador al servidor Ubuntu sigue el modelo
establecido en SBOS-IAM-Style (09 dev-environment-setup).

### Configuración SSH (~/.ssh/config)

```ssh-config
Host skull-sbos-dev
    HostName <IP_DEL_SERVIDOR_UBUNTU>
    User <tu_usuario>
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

### Generación de clave SSH

```bash
ssh-keygen -t ed25519 -C "skull-sbos-dev"
ssh-copy-id <usuario>@<IP_DEL_SERVIDOR_UBUNTU>
```

### Conexión

```
VS Code → F1 → Remote-SSH: Connect to Host → skull-sbos-dev
```

A partir de aquí, **todo lo que haces en VS Code ocurre en Ubuntu**. La terminal
integrada (`Ctrl+``) es bash en Ubuntu.

---

## 5. Motor de Contenedores

| Campo | Valor |
|---|---|
| Motor | Podman 4.9.3 (rootless) — repos oficiales Ubuntu 26.04 |
| Build | Buildah (daemonless) |
| Runtime | crun (más ligero que runc) |
| Inspección | Skopeo (verificación integridad imágenes) |
| Archivos | Containerfile (nunca Dockerfile) |
| Compose | compose.yaml con podman compose |
| Manifiestos | YAML de K8s desde día 1 (podman play kube) |
| Docker | VETADO — sin excepciones |
| Upgrade | Migrar a Podman 5.x con Ubuntu 26.04 LTS (abr 2026) |

Ventaja clave: las fichas usan YAML de K8s desde día 1. `podman play kube` ejecuta los mismos manifiestos que `kubectl apply`.

### Habilitación Podman rootless

```bash
sudo apt-get install -y podman podman-compose
sudo loginctl enable-linger $USER
systemctl --user start podman.socket
systemctl --user enable podman.socket
podman run --rm hello-world
```

---

## 6. Compatibilidad Windows/Linux

- Desarrollo desde Windows + SSH a VPS Linux (Ubuntu 26.04 LTS)
- Paths: usar pathlib (Python) o equivalente — nunca hardcodear / ni \
- Line endings: .gitattributes para CRLF/LF
- Comandos: Makefile con targets bash + PowerShell, o scripts duales
- Variables: .env compatible con ambos SO
- Volúmenes Podman: cuidar permisos Windows/Linux

---

## 7. Herramientas Disponibles

| Herramienta | Versión | Propósito |
|---|---|---|
| Go | 1.22+ | Daemon bos + daemons I/O-bound (bcompass, bsearch, bauth, bhnexus, banexus) |
| Rust | 1.85+ (Edition 2024) | Daemons CPU-bound (bkernel, biedata). Target MUSL |
| Python | 3.11+ | Módulos IAM Installer (16 módulos) |
| Dart + Flutter | latest | Core UI (multi-dispositivo) |
| Bash | 5.x | Core SP-01 (4 archivos maestros) + task_catalog.sh de fichas |
| yq | latest | Parsing YAML en Bash (nunca grep/sed) |
| Podman | 4.9.3 | Contenedores testbench y desarrollo |
| Buildah | latest | Build de imágenes OCI |
| crun | latest | Runtime contenedores (rootless) |
| kubectl | latest | K8s management |
| kubeadm | latest | K8s cluster bootstrap |
| PostgreSQL client | 17/18 | psql para testing |
| uv | latest | Gestor de paquetes Python (reemplazo de pip + virtualenv) |

### Dependencias del sistema para desarrollo completo

```bash
sudo apt-get install -y \
    python3.12 python3.12-venv python3-pip \
    clang cmake ninja-build pkg-config \
    libgtk-3-dev libblkid-dev liblzma-dev \
    mingw-w64 \
    git curl jq wget unzip build-essential \
    ghostscript fonts-dejavu-core \
    fuse libfuse2
```

### Toolchain Flutter para compilación multiplataforma

Flutter SDK se instala **en el servidor Ubuntu** y se usa para desarrollar Y compilar
Core UI para todos los SO destino:

```bash
cd ~
wget -q "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.27.4-stable.tar.xz" \
    -O /tmp/flutter.tar.xz
tar -xf /tmp/flutter.tar.xz -C ~/
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

flutter config --enable-linux-desktop
flutter config --enable-windows-desktop
```

**Resultado esperado de `flutter doctor`:**
```
[✓] Flutter (Channel stable, 3.27.x, on Ubuntu)
[✓] Linux toolchain - develop for Linux desktop
[✗] Android toolchain — NO REQUERIDO
[✗] Xcode — NO REQUERIDO (macOS compilado en GitHub Actions)
[✓] VS Code (si VS Code Remote está conectado)
[✓] Connected device (Linux desktop disponible)
```

| Target | Comando | Compilado en | Resultado |
|---|---|---|---|
| Linux x86_64 | `flutter build linux --release` | Ubuntu | `build/linux/x64/release/bundle/` |
| Linux AppImage | `appimagetool ...` | Ubuntu | `dist/coreui-x.x.x-x86_64.AppImage` |
| Windows x64 | `flutter build windows --release` | Ubuntu (MinGW) | `build/windows/x64/runner/Release/` |
| Windows instalador | `makensis ...` | Ubuntu (NSIS) | `dist/coreui-x.x.x-windows-installer.exe` |
| macOS | `flutter build macos --release` | Mac / GitHub Actions | `dist/coreui-x.x.x-macos.dmg` |

---

## 8. Estructura del Workspace de Desarrollo

```
/opt/sbos-dev/
├── Makefile
├── core/
│   ├── 00_MASTER_INSTALL_SBOS.sh
│   ├── 00_TASK_CATALOG_SBOS.sh
│   ├── 00_YAML_ENGINE_SBOS.sh
│   └── 00_ARCHITECTURE_SBOS.yml
├── validate_sp01.py
└── tests/
    └── test_core.sh
```

---

## 9. Reglas del Agente de Desarrollo

- Nunca reintroducir nombres eliminados: ~~InExData~~, ~~apiBitMask~~, ~~tríada~~
- Nombres canónicos de daemons: bos, bkernel, biedata, bcompass, bsearch, bauth, bhnexus, banexus
- Nombres de fichas: siempre minúscula con guión
- Contenedores: prefijo sbos-
- No mezclar documentación SBOS general con desarrollo del IAM Installer
- Al corregir documentos: integrar contenido, nunca eliminar
- HUMAN-DOC es fuente de verdad técnica (sobre documentos conceptuales)
- **Todo el desarrollo ocurre en el servidor Ubuntu — la estación del desarrollador solo tiene VS Code + SSH**

---

## 10. Variables de Entorno Críticas

Variables de entorno que el agente de desarrollo debe conocer para operar correctamente en ambos modos (standalone e integrado).

### Variables de modo de operación (switchers)

| Variable | Valores | Por defecto | Efecto |
|---|---|---|---|
| `AUTH_MODE` | `local` / `keycloak` | `local` (dev) | Modo de autenticación: local básica o KC OIDC |
| `DB_MODE` | `local` / `shared` | `local` (dev) | Base de datos: contenedor Podman propio o PG del ecosistema |
| `BOS_ENV` | `development` / `staging` / `production` | `development` | Nivel de logging, WAF mode, replicas |
| `BOS_CONFIG` | ruta al archivo | `/etc/bos/bos.toml` | Configuración del daemon bos |

### Variables de infraestructura (desarrollo local)

| Variable | Descripción | Ejemplo |
|---|---|---|
| `POSTGRES_URL` | Conexión a PostgreSQL | `postgresql://bos:secret@localhost:5432/bos_db` |
| `REDIS_URL` | Conexión a Redis | `redis://localhost:6379/0` |
| `VAULT_ADDR` | Dirección de Vault | `http://localhost:8200` |
| `VAULT_TOKEN` | Token de acceso Vault (solo dev) | `s.xxxx` |
| `KC_URL` | Keycloak base URL | `http://localhost:8080` |

### Variables de seguridad (nunca en texto claro en producción)

En producción, **todas** estas variables se leen de Vault en startup. Nunca se hardcodean ni se pasan como flags de línea de comandos. En desarrollo local pueden vivir en `.env` (gitignored).

```bash
# .env (gitignored, solo desarrollo local)
POSTGRES_PASSWORD=dev_only_password
VAULT_TOKEN=dev_only_token
KC_ADMIN_PASSWORD=dev_only_password
ED25519_PUBLIC_KEY=base64:...  # clave pública Release Plane
```

### EditorConfig (para line endings uniformes)

```ini
# .editorconfig — en raíz del monorepo
root = true

[*]
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
charset = utf-8

[*.md]
trim_trailing_whitespace = false

[Makefile]
indent_style = tab
```

---

## 11. Checklist de Verificación del Entorno

```bash
#!/bin/bash
# Script de verificación del entorno de desarrollo SBOS
# Ejecutar en el servidor Ubuntu

echo "=== VERIFICACIÓN ENTORNO SBOS ==="

check() {
    local name="$1"
    local cmd="$2"
    local expected="$3"
    result=$(eval "$cmd" 2>/dev/null)
    if [[ "$result" == *"$expected"* ]] || [[ -n "$result" && -z "$expected" ]]; then
        echo "  [OK] $name"
    else
        echo "  [FAIL] $name"
    fi
}

echo "-- Sistema --"
check "Ubuntu" "lsb_release -rs" "26"
check "Python 3.11+" "python3.11 --version" "3.11"
check "Go 1.22+" "go version" "go1.22"
check "Rust 1.85+" "rustc --version" "1.85"
check "yq" "yq --version" ""
check "uv" "uv --version" ""
check "jq" "jq --version" ""

echo "-- Contenedores --"
check "Podman" "podman --version" "4"
check "Buildah" "buildah --version" ""
check "crun" "crun --version" ""

echo "-- Flutter --"
check "Flutter SDK" "flutter --version" "Flutter"
check "Linux desktop" "flutter devices" "Linux"
check "MinGW (Windows cross)" "x86_64-w64-mingw32-gcc --version" ""

echo "-- K8s --"
check "kubectl" "kubectl version --client" ""
check "kubeadm" "kubeadm version" ""

echo "-- Otros --"
check "Git" "git --version" ""
check "Bash 5.x" "bash --version" "5"
```

---

## Trazabilidad

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1 SO | SBOS-AYUDA-MEMORIA | §entorno |
| §2 Modelo Ubuntu Server | SBOS-IAM-Style 09 dev-environment-setup §0 | Modelo de desarrollo: todo en Ubuntu Server |
| §3 VS Code | SBOS-COMPLETITUD-v2 §2 B2.4 | extensions.json + settings.json + fundamento |
| §4 SSH | SBOS-IAM-Style 09 dev-environment-setup §1.3 | Config SSH, generación clave, conexión |
| §5 Podman | SBOS-001-VISION v4.0 | P9 (licencias), política Podman |
| §6 Compat | SBOS-029 v1.0 | §multi-entorno |
| §7 Herramientas | SBOS-018 v1.0 + SBOS-IAM-Style 09 §2 | §lenguajes + toolchain Flutter multiplataforma + uv |
| §10 Variables entorno | SBOS-COMPLETITUD-v2 §2 B2.3+B2.4 + SBOS-034-PORTABILIDAD §4 | switchers + variables infra + EditorConfig |
| §11 Checklist | SBOS-IAM-Style 09 §9 | Script de verificación del entorno |

---

## Fuentes de Enriquecimiento V8

| Fuente | Ruta | Tipo | Detalle |
|---|---|---|---|
| BOS_V6_SBOS-011-DEV-ENV.md | Procesar/ | V6 Base | Contenido completo preservado |
| SBOS-IAM-Style/context/09_brand-system_dev-environment-setup.md | sbos/subproyectos/ | Smart* | Modelo Ubuntu Server, VS Code Remote SSH, Flutter cross-compile, Podman stack, uv, verification checklist |
| SBOS-COMPLETITUD-v2 §2 | Procesar/ | V5 Referencia | Extensiones, settings, fundamento VS Code |

---

_SKULL · SBOS · SBOS-011-DEV-ENV · V8 · Mayo 2026_
