# SBOS-052-VDI-SPEC
## Capa Cliente Soberana: Fedora Físico, Fedora Lógico y Almacenamiento Soberano
## Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Junio 2026

---

## 1. Propósito del Documento

Este documento formaliza la **Capa Cliente Soberana (VDI Layer)** del SBOS: el conjunto de componentes, configuraciones y artefactos que permiten a cualquier usuario interactuar con el stack desde cualquier dispositivo, bajo el control completo del Context Plane y respetando los tres dominios de autorización definidos en SBOS-049 y SBOS-021.

El documento responde tres preguntas:

> **¿Cómo accede un usuario al SBOS?**
> A través de dos modalidades: un cliente Fedora físico instalado en hardware real (dominio físico + lógico + financiero) o un cliente Fedora lógico accesible desde cualquier navegador (dominio lógico + financiero).

> **¿Dónde viven los datos del usuario?**
> En el servidor SBOS, gestionados por Nextcloud (AGPL v3), gobernado por Keycloak, con PostgreSQL como base de datos. Ningún documento ni archivo de usuario puede residir en el disco local del cliente.

> **¿Cuándo está el SBOS completamente instalado?**
> Cuando el pod Fedora Lógico es accesible por navegador web y el artefacto `sbos-fedora.iso` está disponible para instalación en hardware físico. El VDI Layer es la cúspide de la instalación SBOS — el último hito del bootstrap.

**Corrección de alcance respecto al corpus anterior:** Este documento extiende SBOS-049-CONTEXT-PLANE y SBOS-MANUAL-ACOPLAMIENTO con la definición formal de los dos tipos de cliente Fedora, el agente `sbos-client`, y el subsistema de almacenamiento soberano Nextcloud.

---

## 2. Principios Fundamentales de la Capa Cliente

| # | Principio | Justificación |
|---|---|---|
| P1 | **Ningún dato del usuario en el cliente** | Todo archivo, documento y configuración de usuario vive en el servidor. El disco local del cliente es invisible para el usuario. |
| P2 | **El ctx_id es el pasaporte universal** | El mismo ctx_id y BitMask controla lo que el usuario puede hacer independientemente del dispositivo desde el que accede. |
| P3 | **Fedora como superficie soberana** | Fedora (físico o lógico) es la única superficie de trabajo gestionada y certificada por SBOS. Otros dispositivos acceden vía web. |
| P4 | **Keycloak gobierna toda autenticación** | No existe autenticación propia en ningún componente del VDI Layer. Nextcloud, Guacamole, sbos-client — todos delegan a Keycloak. |
| P5 | **Hardware legacy como ventaja** | Fedora Físico corre en hardware que Windows 11 o macOS ya no soportan. Un equipo con procesador de 2010 y 4GB RAM es un cliente SBOS completamente funcional. |
| P6 | **El VDI Layer es la cúspide del bootstrap** | La instalación del SBOS no termina con Kubernetes corriendo — termina con el pod Fedora Lógico accesible por web y el ISO disponible. |
| P7 | **Licencias OSI-approved únicamente** | Nextcloud (AGPL v3), Guacamole (Apache 2.0), Fedora (múltiples OSI). Sin excepciones. |

---

## 3. Los Dos Tipos de Cliente Fedora

### 3.1 Fedora Físico — Cliente Soberano Completo

**Definición:** Instalación de Fedora en hardware real (PC, laptop, terminal POS, workstation) con el agente `sbos-client` y el daemon `banexus` activos como servicios systemd. Es el único tipo de cliente que habilita los tres dominios simultáneamente.

**Dominios habilitados:**

| Dominio | Estado | Mecanismo |
|---|---|---|
| Físico | ✅ Completo | banexus → chapas, cajón POS, actuadores, cámaras via udev/libusb |
| Lógico | ✅ Completo | sbos-client + BitMask → apps, permisos, recursos del OS |
| Financiero | ✅ Completo | BitMask → límites transaccionales, SoD, doble firma |

**Casos de uso:**
- Terminal POS en sucursal: cajero que opera ventas, abre el cajón, controla chapas de zona
- Workstation de sucursal: empleado administrativo con acceso físico a zonas autorizadas
- Hardware legacy recuperado: equipos con procesadores de 2010-2015 que no corren Windows 11

**Requisitos de hardware mínimos:**
```
CPU:     x86_64, cualquier generación desde 2008 (Fedora 42 soporta SSE2+)
RAM:     4 GB mínimo, 8 GB recomendado
Disco:   32 GB mínimo (el home del usuario vive en el servidor)
Red:     Ethernet o WiFi con conectividad al servidor SBOS
USB:     Para lectores NFC/QR/biométrico (banexus los intercepta via udev)
```

**Componentes instalados en Fedora Físico:**
```
sbos-client.service      ← agente soberano, se registra con bhnexus al arranque
banexus.service          ← control de hardware físico
nextcloud-desktop        ← cliente Nextcloud, monta home del usuario en el servidor
gnome-shell              ← escritorio, controlado por sbos-client via dconf
keycloak-oidc-pam        ← módulo PAM para login GNOME via Keycloak
podman                   ← runtime OCI para apps locales si aplica
```

### 3.2 Fedora Lógico — Cliente Web Soberano

**Definición:** Pod Kubernetes que corre una imagen OCI Fedora con GNOME completo y `sbos-client`, servido al navegador del usuario a través de **Apache Guacamole** (Apache 2.0). Cualquier dispositivo con navegador moderno accede a un escritorio Fedora completo sin instalar nada.

**Dominios habilitados:**

| Dominio | Estado | Razón |
|---|---|---|
| Físico | ✗ No aplica | Sin banexus. El hardware del servidor no pertenece al usuario. |
| Lógico | ✅ Completo | sbos-client activo dentro del pod, BitMask aplicado |
| Financiero | ✅ Completo | BitMask → límites, SoD, aprobaciones |

**Casos de uso:**
- Usuario remoto que accede desde su laptop macOS o Windows
- Supervisor que aprueba desde tablet Android o iPad
- Desarrollador SKULL que accede desde WSL Fedora o cualquier navegador
- Sucursal sin hardware Fedora instalado que necesita acceso temporal

**Dispositivos cliente compatibles:**
```
Cualquier dispositivo con navegador moderno:
  - Windows (Chrome, Firefox, Edge)
  - macOS (Safari, Chrome, Firefox)
  - Android (Chrome, Firefox)
  - iOS / iPadOS (Safari, Chrome)
  - Linux / WSL Fedora (Firefox, Chrome)
  - Chromebook (Chrome)
```

**Componentes del pod Fedora Lógico:**
```
imagen OCI:   skull/sbos-fedora-logico:1.0.0
runtime:      Podman (Kubernetes CRI-O)
sbos-client:  activo como proceso supervisor dentro del pod
GNOME:        gnome-shell en modo kiosk configurable
apps:         Tryton client, LibreOffice, navegador, herramientas SKULL
nextcloud:    cliente desktop montando home del usuario
protocolo:    VNC interno → Guacamole → HTML5 al navegador del cliente
```

### 3.3 Tabla Comparativa

| Característica | Fedora Físico | Fedora Lógico |
|---|---|---|
| Hardware requerido | PC/laptop/POS real | Solo navegador |
| Dominio físico (chapas, POS) | ✅ | ✗ |
| Dominio lógico | ✅ | ✅ |
| Dominio financiero | ✅ | ✅ |
| Hardware legacy (2008+) | ✅ ventaja clave | N/A |
| Instalación en cliente | ISO booteable | Ninguna |
| Acceso multi-dispositivo | No (1 equipo) | ✅ cualquier navegador |
| sbos-client | systemd service | proceso en pod |
| banexus | ✅ activo | ✗ ausente |
| Home del usuario | NFS + Nextcloud | Nextcloud (montado en pod) |
| Operación sin red | Parcial (caché) | ✗ requiere conectividad |

---

## 4. El Agente sbos-client

### 4.1 Propósito

`sbos-client` es el daemon soberano del lado cliente. Es el par de `banexus` para entornos sin hardware físico, y el complemento de `banexus` en entornos físicos. Su responsabilidad es registrar el nodo cliente con el Context Plane del bos y aplicar el BitMask recibido en el ambiente local del usuario.

**Lenguaje:** Go (consistente con bos, bauth, bcompass, bhnexus).
**Comunicación con el servidor:** WebSocket mTLS hacia bhnexus `:9444` — mismo protocolo que banexus.
**Ubicación en el monorepo:** `src/cmd/sbos-client/`

### 4.2 Modos de Operación

```
sbos-client opera en uno de tres modos, detectado automáticamente al arranque:

MODE_PHYSICAL   → Fedora físico con banexus presente
                  sbos-client coordina con banexus para el BitMask
                  dctx_id incluye hardware_type: "physical"

MODE_LOGICAL    → Pod Fedora Lógico (dentro de K8s)
                  sbos-client opera solo, sin banexus
                  dctx_id incluye hardware_type: "logical_pod"

MODE_WSL        → Fedora sobre WSL2 en Windows
                  sbos-client opera solo
                  dctx_id incluye hardware_type: "wsl"
                  Útil para desarrolladores y administradores SKULL
```

### 4.3 Ciclo de Vida del sbos-client

```
Arranque del nodo (Fedora Físico o inicio del pod)
        ↓
sbos-client.service inicia (systemd o supervisor en pod)
        ↓
Lee configuración: /etc/sbos/client.toml
  - server_url: wss://bhnexus.{tenant}.sksistemas.com:9444
  - tenant: skull
  - device_uuid: {UUID persistente generado en primer arranque}
  - cert: /etc/sbos/certs/client.crt  (mTLS)
        ↓
Abre WebSocket mTLS hacia bhnexus :9444
        ↓
bos recibe registro → crea dctx_id
  dctx_id almacenado: Redis + bkernel_db.context_sessions
  status: "pre-auth"
  bitmask: 0x0000000000000000
        ↓
[ESPERA] Usuario se autentica en Keycloak
        ↓
bos emite context.promoted → sbos-client recibe ctx_id + BitMask
        ↓
sbos-client aplica políticas locales:
  - Escribe políticas dconf en GNOME (apps permitidas)
  - Monta home del usuario desde Nextcloud
  - Configura variables de entorno con ctx_id
  - Notifica a banexus si está presente (MODE_PHYSICAL)
        ↓
[OPERACIÓN] Usuario trabaja normalmente
        ↓
Logout / timeout de sesión KC
        ↓
sbos-client recibe context.expired desde bos
  - Limpia políticas dconf → GNOME vuelve a pantalla de login
  - Desmonta home del usuario
  - Limpia variables de entorno
  - Nodo vuelve a estado pre-auth (otro usuario puede autenticarse)
```

### 4.4 Configuración: /etc/sbos/client.toml

```toml
[server]
bhnexus_url    = "wss://bhnexus.skull.sksistemas.com:9444"
bos_api_url    = "https://bos.skull.sksistemas.com:9443"
keycloak_url   = "https://auth.skull.sksistemas.com"
tenant         = "skull"

[device]
uuid           = ""          # generado en primer arranque, persiste en /var/lib/sbos/device.uuid
hostname       = ""          # auto-detectado
mode           = "auto"      # auto | physical | logical | wsl

[tls]
cert_file      = "/etc/sbos/certs/client.crt"
key_file       = "/etc/sbos/certs/client.key"
ca_file        = "/etc/sbos/certs/sbos-ca.crt"

[storage]
nextcloud_url  = "https://files.skull.sksistemas.com"
mount_home     = true
home_base      = "/home"
offline_cache  = "/var/cache/sbos/home"   # caché local solo lectura sin red

[gnome]
policy_file    = "/etc/sbos/gnome-policies.json"
kiosk_mode     = false       # true para terminales POS dedicados

[logging]
level          = "info"
journal        = true        # integración con systemd journal
ctx_id_field   = "ctx_id"    # campo obligatorio en todos los logs
```

### 4.5 Políticas GNOME via dconf

Al recibir el BitMask, sbos-client escribe las siguientes políticas en dconf, aplicadas inmediatamente sin reiniciar sesión:

```json
{
  "policies": {
    "org.gnome.nautilus.blocked-locations": [
      "file:///",
      "file:///etc",
      "file:///var",
      "file:///tmp",
      "file:///media",
      "file:///mnt"
    ],
    "org.gnome.nautilus.allowed-locations": [
      "file:///home/{usuario}/Documentos",
      "file:///home/{usuario}/Descargas",
      "file:///home/{usuario}/Escritorio",
      "nextcloud://"
    ],
    "org.gnome.shell.allowed-apps": "{lista_derivada_del_bitmask}",
    "org.gnome.desktop.lockdown.disable-save-to-disk": true,
    "org.gnome.desktop.lockdown.disable-mount-removable-storage": true
  }
}
```

**Resultado:** El usuario ve en GNOME únicamente sus carpetas Nextcloud. El disco local del cliente es completamente invisible. No puede guardar en rutas locales, no puede montar USB para extraer datos, no puede acceder al filesystem del sistema.

---

## 5. Almacenamiento Soberano — Nextcloud

### 5.1 Justificación de la elección

| Criterio requerido | Nextcloud | Cumple |
|---|---|---|
| Licencia libre OSI-approved | AGPL v3 | ✅ |
| Gobernado por Keycloak | OIDC nativo (app `social_login` + `user_oidc`) | ✅ |
| Compatible con PostgreSQL | BD principal configurable, PostgreSQL soportado | ✅ |
| Acceso multi-dispositivo | Web, Android, iOS, desktop Linux/Windows/macOS | ✅ |
| Soberanía total | Auto-hospedado, ningún dato sale del servidor | ✅ |
| Historial de versiones | Versionado nativo por archivo | ✅ |
| Edición colaborativa | Collabora Online (CODE — LibreOffice en navegador) | ✅ |

### 5.2 Rol de Nextcloud en el SBOS

Nextcloud en el SBOS cumple **dos roles simultáneos**:

**Rol 1 — Sistema de archivos del usuario (reemplaza el disco local):**
El home del usuario en Fedora (físico o lógico) apunta a Nextcloud vía el cliente desktop. `~/Documentos`, `~/Descargas`, `~/Escritorio` son carpetas Nextcloud sincronizadas. Todo lo que el usuario guarda desde cualquier aplicación de escritorio va directamente al servidor.

**Rol 2 — Acceso universal desde cualquier dispositivo:**
El mismo contenido del usuario es accesible desde el navegador, desde la app móvil de Nextcloud (Android/iOS), o desde cualquier otro dispositivo — sin necesitar Fedora. Un supervisor desde su iPad ve y edita los mismos documentos que el cajero guardó desde su terminal POS.

### 5.3 Estructura de almacenamiento por tenant

```
Nextcloud almacenamiento en el servidor:
/srv/nextcloud/
  └── tenants/
      └── skull/
          ├── empresas/
          │   └── maya/
          │       ├── sucursales/
          │       │   └── lapaz/
          │       │       ├── compartido/     ← carpeta compartida de sucursal
          │       │       └── usuarios/
          │       │           ├── juan.garcia/    ← home de usuario
          │       │           └── maria.lopez/
          │       └── compartido/             ← documentos de empresa
          └── admin/
              └── skull-global/               ← documentos globales del tenant
```

### 5.4 Cuotas de almacenamiento

Las cuotas se configuran por rol en Keycloak y las aplica el bos al crear el tenant:

```yaml
# En seed file del tenant (SBOS-037)
storage:
  nextcloud:
    quotas:
      default_user:    5GB
      admin_user:     20GB
      manager:        10GB
      pos_operator:    2GB
    shared_empresa:   50GB
    shared_sucursal:  20GB
```

### 5.5 Integración Nextcloud — Keycloak

Nextcloud se registra como cliente OIDC en el realm del tenant. El bos provisiona esta configuración automáticamente al instalar la ficha Nextcloud en el alta del tenant.

```
Usuario accede a Nextcloud (web o app móvil)
        ↓
Nextcloud redirige a Keycloak SSO
        ↓
Keycloak autentica → emite JWT con ctx_id + tenant + empresa
        ↓
Nextcloud recibe JWT → monta el espacio del usuario correcto
        ↓
El usuario ve únicamente sus carpetas y las compartidas de su empresa/sucursal
```

### 5.6 Base de datos: nextcloud_db en PostgreSQL

```sql
-- Base de datos dedicada, creada por bos en el alta del tenant
-- Nombre por convención SBOS: nextcloud_db

-- Tabla principal de archivos (simplificada para referencia)
-- Nextcloud gestiona su propio schema internamente
-- bos provisiona la BD y las credenciales via Vault

-- Configuración en config.php de Nextcloud:
-- 'dbtype'     => 'pgsql',
-- 'dbname'     => 'nextcloud_db',
-- 'dbhost'     => 'postgresql.sbos.svc.cluster.local',
-- (credenciales via Vault AppRole, TTL 24h)
```

### 5.7 Nextcloud en el manifest.yml (ficha SBOS)

```yaml
identity:
  id: "nextcloud"
  version: "30.x"
  description: "Almacenamiento soberano de documentos y home de usuarios"
  criticality: true
  license: "AGPL-3.0"

workload:
  type: kubernetes
  namespace: "sbos-{tenant}"
  server: "S06"

depends_on:
  - postgresql
  - keycloak
  - kong
  - vault

ports:
  http:    28300
  https:   28301
  metrics: 28302
  health:  28303

database:
  name: "nextcloud_db"
  engine: postgresql

keycloak:
  client_id: "nextcloud"
  realm: "{tenant}"
  grant_type: authorization_code
  scopes: ["openid", "profile", "email", "groups"]

vault:
  paths:
    - "secret/tenants/{realm}/nextcloud/db"
    - "secret/tenants/{realm}/nextcloud/admin"
    - "secret/tenants/{realm}/nextcloud/s3"

storage:
  pvc_name: "nextcloud-data-{tenant}"
  storage_class: "sbos-sovereign"
  access_mode: ReadWriteMany
  size: "500Gi"   # configurable por tenant en seed file
```

---

## 6. Apache Guacamole — Gateway VDI

### 6.1 Propósito

Apache Guacamole (Apache 2.0) es el gateway que sirve el escritorio del pod Fedora Lógico al navegador del usuario. Transforma un escritorio VNC/RDP en una aplicación HTML5 accesible desde cualquier navegador sin plugins.

```
Navegador del usuario (cualquier dispositivo)
        ↓ HTTPS via Kong
Guacamole (pod K8s — ficha SBOS)
        ↓ VNC interno (red privada K8s)
Pod Fedora Lógico (escritorio GNOME)
        ↓ sbos-client activo
bhnexus → bos → ctx_id + BitMask
```

### 6.2 Integración con Keycloak

Guacamole autentica exclusivamente via Keycloak OIDC. No tiene usuarios propios. El bos provisiona el client OIDC `guacamole` en el realm del tenant al instalar la ficha.

```
Usuario abre https://vdi.skull.sksistemas.com
        ↓
Guacamole redirige a Keycloak
        ↓
Keycloak autentica → retorna JWT con ctx_id + grupos
        ↓
Guacamole mapea grupos Keycloak → conexiones VNC disponibles
        ↓
Usuario elige o es asignado automáticamente a un pod Fedora
        ↓
Escritorio GNOME renderizado en el navegador via HTML5
```

### 6.3 Asignación de pods Fedora Lógico

El bos gestiona el pool de pods Fedora Lógico por tenant. Al hacer login en Guacamole:

```
Si el usuario tiene pod asignado y activo → conecta directamente
Si no → bos provisiona un pod nuevo del pool del tenant
Pool agotado → bos escala el Deployment automáticamente (HPA)
Pod inactivo > 30min → bos lo suspende (recursos liberados)
Pod inactivo > 8h → bos lo termina (home persiste en Nextcloud)
```

### 6.4 Manifest.yml de Guacamole

```yaml
identity:
  id: "guacamole"
  version: "1.5.x"
  description: "Gateway VDI HTML5 — acceso web al escritorio Fedora Lógico"
  criticality: false
  license: "Apache-2.0"

workload:
  type: kubernetes
  namespace: "sbos-{tenant}"
  server: "S06"

depends_on:
  - postgresql
  - keycloak
  - kong
  - fedora-logico

ports:
  http:    28310
  https:   28311
  metrics: 28312
  health:  28313

database:
  name: "guacamole_db"
  engine: postgresql

keycloak:
  client_id: "guacamole"
  realm: "{tenant}"
  grant_type: authorization_code
```

---

## 7. El Pod Fedora Lógico como Ficha SBOS

### 7.1 Imagen OCI

```dockerfile
# skull/sbos-fedora-logico:1.0.0
# Base: Fedora 42 (oficial)
# Firmada con Ed25519 del Release Plane SKULL

FROM fedora:42

# GNOME mínimo + apps de escritorio SBOS
RUN dnf install -y \
    gnome-shell \
    gnome-terminal \
    nautilus \
    libreoffice \
    firefox \
    nextcloud-desktop \
    tigervnc-server \
    && dnf clean all

# sbos-client (binario Go compilado en CI SKULL)
COPY --from=skull/sbos-client:latest /usr/bin/sbos-client /usr/bin/sbos-client

# Configuración base (valores finales inyectados por bos via ConfigMap)
COPY config/client.toml /etc/sbos/client.toml
COPY config/gnome-policies.json /etc/sbos/gnome-policies.json

# Certificados mTLS (inyectados por Vault al arranque del pod)
RUN mkdir -p /etc/sbos/certs

# Supervisor para GNOME + VNC + sbos-client
COPY supervisord.conf /etc/supervisord.conf

EXPOSE 5900   # VNC interno (solo accesible desde Guacamole, no expuesto a Kong)

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
```

### 7.2 Manifest.yml del pod Fedora Lógico

```yaml
identity:
  id: "fedora-logico"
  version: "1.0.0"
  description: "Pod escritorio Fedora — cliente lógico SBOS accesible via Guacamole"
  criticality: false
  license: "Mixed-OSS"   # Fedora: múltiples licencias OSI-approved

workload:
  type: kubernetes
  namespace: "sbos-{tenant}"
  server: "S06"
  replicas: 2            # mínimo 2 pods en el pool
  hpa:
    min: 2
    max: 20
    metric: concurrent_sessions

depends_on:
  - keycloak
  - nextcloud
  - sbos-client

ports:
  vnc:     5900    # interno — solo accesible desde Guacamole
  metrics: 28320
  health:  28321

keycloak:
  client_id: "fedora-logico"
  realm: "{tenant}"

vault:
  paths:
    - "secret/tenants/{realm}/fedora-logico/tls"
    - "secret/tenants/{realm}/fedora-logico/vnc-password"

resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "2"
    memory: "4Gi"
```

---

## 8. El Artefacto sbos-fedora.iso — USB Booteable

### 8.1 Propósito

`sbos-fedora.iso` es una imagen ISO booteable que, al instalarse en cualquier hardware x86_64, produce un Fedora Físico completamente configurado y listo para conectarse al stack SBOS. El técnico de instalación solo necesita:

1. Quemar el ISO en un USB (Ventoy, dd, Fedora Media Writer)
2. Arrancar el equipo desde el USB
3. Responder 3 preguntas (hostname, tenant, servidor bos)
4. Reiniciar

El equipo queda listo. sbos-client se registra con bhnexus en el primer arranque.

### 8.2 Composición del ISO

```
sbos-fedora.iso está basado en Fedora 42 con Kickstart personalizado:

Base:
  - Fedora 42 netinstall o Everything (selección mínima)
  - GNOME Shell (escritorio)
  - SELinux enforcing (herencia Fedora)

Agregados SKULL (instalados desde repositorio interno via Kickstart):
  - sbos-client (RPM firmado con GPG SKULL)
  - banexus (RPM firmado)
  - nextcloud-desktop
  - keycloak-oidc-pam
  - sbos-firstboot (wizard de configuración inicial — TUI en terminal)

Configuraciones precargadas:
  - /etc/sbos/client.toml (valores template, completados por sbos-firstboot)
  - /etc/sbos/gnome-policies.json (políticas base)
  - /etc/pam.d/gdm-password (módulo PAM Keycloak)
  - /etc/systemd/system/sbos-client.service
  - /etc/systemd/system/banexus.service
  - Certificado CA raíz de SKULL (para mTLS)

Removido (no disponible en el cliente):
  - sudo sin contraseña
  - acceso a /etc/passwd, /etc/shadow por usuarios normales
  - montaje automático de dispositivos USB removibles (excepto para admin)
```

### 8.3 sbos-firstboot — El Wizard de Instalación

Al primer arranque del equipo instalado desde el ISO, `sbos-firstboot` presenta un TUI (terminal UI) que solicita:

```
═══════════════════════════════════════════
  SBOS Fedora Físico — Configuración Inicial
═══════════════════════════════════════════

  [1/3] Hostname del equipo:
        > caja-lapaz-01

  [2/3] Tenant al que pertenece:
        > skull

  [3/3] URL del servidor bos:
        > https://bos.skull.sksistemas.com:9443

  ──────────────────────────────────────────
  Verificando conectividad con el servidor...
  ✓ bos alcanzable
  ✓ Certificado TLS válido
  ✓ Tenant skull existe

  Registrando dispositivo...
  ✓ device_uuid: d7f3a1b2-... generado
  ✓ Certificado mTLS emitido por bos PKI
  ✓ sbos-client.service habilitado
  ✓ banexus.service habilitado

  ══════════════════════════════════════════
  Instalación completa. Reiniciando...
  ══════════════════════════════════════════
```

Al reiniciar, el equipo arranca en GNOME con la pantalla de login Keycloak. El usuario presenta su credencial (QR, NFC, contraseña) y el sistema opera normalmente.

### 8.4 Construcción del ISO en CI/CD

```yaml
# .gitlab-ci.yml — pipeline de construcción del ISO
build-sbos-fedora-iso:
  stage: build
  image: fedora:42
  script:
    - dnf install -y lorax anaconda
    - mkksiso --ks kickstart/sbos-fedora.ks \
               Fedora-42-x86_64-Everything.iso \
               sbos-fedora-{version}.iso
    - sha256sum sbos-fedora-{version}.iso > sbos-fedora-{version}.iso.sha256
    - cosign sign --key skull-ed25519.key sbos-fedora-{version}.iso
  artifacts:
    paths:
      - sbos-fedora-*.iso
      - sbos-fedora-*.iso.sha256
  only:
    - tags
```

El ISO firmado se publica en el GitLab Release del proyecto y queda disponible para descarga desde la Core UI del bos (`bosctl iso download --version=latest`).

---

## 9. Integración con el bos IAM Installer

### 9.1 El VDI Layer como cúspide del bootstrap

La instalación del SBOS sigue el modelo de seis capas (SBOS-BOOTSTRAP-MANUAL). El VDI Layer es la **Capa 7 — cúspide de la instalación** — el último paso antes de declarar el sistema operativo:

```
Capa 1: Ubuntu base (cgroups, red, storage)
Capa 2: Kubernetes + CNI (Calico) + CSI
Capa 3: Servicios de datos (PostgreSQL, Redis, Vault)
Capa 4: Identidad y gateway (Keycloak, Kong, Linkerd)
Capa 5: Daemons soberanos (bos, bkernel, bauth, biedata, bcompass, bsearch, bhnexus)
Capa 6: Fichas de aplicación (Tryton, Saleor, OrangeHRM, Nextcloud, Guacamole...)
Capa 7: VDI Layer ← CÚSPIDE
  7a: Pod Fedora Lógico levantado y accesible via Guacamole
  7b: sbos-fedora.iso compilado y disponible para descarga
  7c: Verificación end-to-end: login web → ctx_id → escritorio Fedora
```

**El SBOS no está completamente instalado hasta que la Capa 7 está operativa.**

### 9.2 Lo que el bos provisiona para el VDI Layer

Al ejecutar `bosctl deploy <seed.yml>`, el bos ejecuta los siguientes pasos adicionales para el VDI Layer en el alta del tenant:

```bash
# Paso 1 — Nextcloud: crear espacio del tenant
bosctl ficha install nextcloud --tenant={tenant}
  → crea nextcloud_db en PostgreSQL
  → crea PVC nextcloud-data-{tenant} (500Gi por defecto)
  → registra client OIDC 'nextcloud' en realm KC del tenant
  → configura estructura de carpetas por tenant/empresa/sucursal
  → aplica cuotas del seed file

# Paso 2 — Guacamole: instalar gateway VDI
bosctl ficha install guacamole --tenant={tenant}
  → crea guacamole_db en PostgreSQL
  → registra client OIDC 'guacamole' en realm KC
  → configura pool inicial de conexiones VNC

# Paso 3 — Pod Fedora Lógico: levantar pool inicial
bosctl ficha install fedora-logico --tenant={tenant} --replicas=2
  → despliega 2 pods Fedora Lógico en namespace sbos-{tenant}
  → cada pod recibe certificado mTLS via Vault PKI
  → sbos-client en cada pod se registra con bhnexus
  → bos verifica que los pods están en estado Running

# Paso 4 — Ruta Kong para VDI
bosctl kong add-route --tenant={tenant} \
  --name=vdi \
  --upstream=guacamole \
  --host=vdi.{tenant}.sksistemas.com

# Paso 5 — Verificación end-to-end
bosctl vdi verify --tenant={tenant}
  → abre sesión de prueba en Guacamole
  → verifica que sbos-client recibe dctx_id del bos
  → verifica que Nextcloud está montado en el pod
  → reporta: "VDI Layer operativo para tenant {tenant}"

# Paso 6 — Disponibilidad del ISO
bosctl iso status --version=latest
  → verifica que sbos-fedora.iso está disponible en GitLab Releases
  → imprime URL de descarga y hash SHA256
  → reporta: "sbos-fedora.iso disponible para instalación en hardware físico"
```

### 9.3 Nuevos comandos bosctl para el VDI Layer

```bash
# Gestión del pool Fedora Lógico
bosctl vdi pool list --tenant=skull          # pods activos y sus sesiones
bosctl vdi pool scale --tenant=skull --min=4 # ajustar pool mínimo
bosctl vdi session list --tenant=skull       # sesiones activas de usuarios
bosctl vdi session kill --session=sess-xxxx  # forzar cierre de sesión

# Gestión del almacenamiento Nextcloud
bosctl storage quota set --tenant=skull --user=juan.garcia --quota=10GB
bosctl storage usage --tenant=skull          # uso por usuario y empresa
bosctl storage report --tenant=skull         # reporte completo del tenant

# Gestión del ISO
bosctl iso build --version=1.0.1            # construir nueva versión del ISO
bosctl iso download --version=latest        # URL de descarga con SHA256
bosctl iso verify <archivo.iso>             # verificar firma Ed25519

# Verificación del VDI Layer
bosctl vdi verify --tenant=skull            # verificación end-to-end completa
bosctl vdi health --tenant=skull            # estado de todos los componentes VDI
```

### 9.4 Registro del Fedora Físico desde el bos

Cuando un Fedora Físico se instala desde el ISO y sbos-firstboot completa la configuración, el bos recibe el registro y ejecuta:

```
sbos-client del nuevo nodo abre WSS/mTLS → bhnexus
        ↓
bhnexus notifica al bos: nuevo dispositivo {device_uuid}
        ↓
bos verifica: ¿el device_uuid está en la lista autorizada del tenant?
  SÍ → registra en .sbos_state.json del tenant
       crea dctx_id con hardware_type: "physical"
       emite certificado mTLS dedicado via Vault PKI
       reporta en Core UI: "Nuevo dispositivo físico registrado"
  NO  → rechaza conexión, emite alerta de seguridad via bNotifier
        evento: device.unauthorized_registration
```

---

## 10. Seguridad y Aislamiento

### 10.1 El disco local del cliente es inaccesible para el usuario

En Fedora Físico, sbos-client aplica las siguientes medidas al recibir el ctx_id:

```
1. Política dconf: Nautilus (explorador de archivos) solo muestra Nextcloud
2. Política dconf: disable-save-to-disk = true (bloquea "Guardar en disco")
3. Política dconf: disable-mount-removable-storage = true (bloquea USB)
4. Política SELinux: usuarios normales no pueden escribir fuera de /home/{usuario}
5. /home/{usuario} es la carpeta Nextcloud sincronizada — vive en el servidor
6. tmpfs en /tmp: archivos temporales desaparecen al cerrar sesión
```

**Resultado:** El usuario físicamente no puede guardar un archivo en el disco local aunque lo intente. Todas las rutas de guardado visible apuntan a Nextcloud.

### 10.2 Aislamiento entre tenants en pods Fedora Lógico

```
Cada tenant tiene su propio namespace K8s: sbos-{tenant}
Cada pod Fedora Lógico corre en ese namespace
NetworkPolicy default-deny: pods de tenant A no pueden comunicarse con tenant B
El home Nextcloud está particionado por tenant (PVC dedicado por tenant)
El ctx_id incluye tenant — cualquier intento de acceso cruzado es rechazado por bAuth
```

### 10.3 Certificados mTLS por dispositivo

Cada instancia de sbos-client (física o lógica) tiene su propio certificado mTLS emitido por la PKI interna de Vault. El bos puede revocar el certificado de un dispositivo específico sin afectar otros, lo que equivale a un "remote wipe" del acceso SBOS del equipo.

```bash
# Revocar acceso de un dispositivo comprometido
bosctl device revoke --device-uuid=d7f3a1b2-...
  → Vault revoca el certificado del dispositivo
  → bhnexus cierra la conexión WebSocket activa
  → ctx_id del dispositivo invalidado en Redis
  → evento: device.revoked emitido en audit_events
```

---

## 11. Modelo de Datos — Extensiones para el VDI Layer

### 11.1 Extensión de context_sessions para dispositivos cliente

```sql
-- Columnas adicionales en context_sessions (SBOS-049 §12)
-- Se agregan al DDL existente via migration

ALTER TABLE context_sessions ADD COLUMN IF NOT EXISTS
  hardware_type    VARCHAR(20)
    CHECK (hardware_type IN ('physical', 'logical_pod', 'wsl', 'web_only'));

ALTER TABLE context_sessions ADD COLUMN IF NOT EXISTS
  device_uuid      VARCHAR(128);   -- UUID del sbos-client registrado

ALTER TABLE context_sessions ADD COLUMN IF NOT EXISTS
  guacamole_session_id  VARCHAR(128);  -- solo para hardware_type = 'logical_pod'

ALTER TABLE context_sessions ADD COLUMN IF NOT EXISTS
  nextcloud_home_mounted  BOOLEAN DEFAULT FALSE;
```

### 11.2 Nueva tabla: registered_devices

```sql
CREATE TABLE registered_devices (
    device_uuid     VARCHAR(128) PRIMARY KEY,
    tenant          VARCHAR(64)  NOT NULL,
    hostname        VARCHAR(128),
    hardware_type   VARCHAR(20)  NOT NULL
                    CHECK (hardware_type IN ('physical', 'logical_pod', 'wsl')),
    ip_last         INET,
    mac_address     VARCHAR(17),
    os_version      VARCHAR(64),
    sbos_client_version VARCHAR(32),
    cert_serial     VARCHAR(128),   -- serial del certificado mTLS emitido por Vault
    registered_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at    TIMESTAMPTZ,
    revoked_at      TIMESTAMPTZ,
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'revoked', 'suspended'))
) PARTITION BY LIST (tenant);

CREATE INDEX idx_devices_tenant  ON registered_devices (tenant, status);
CREATE INDEX idx_devices_active  ON registered_devices (last_seen_at) WHERE status = 'active';
```

---

## 12. Checklist de Acoplamiento — VDI Layer

Un despliegue del VDI Layer está correctamente completado cuando puede responder SÍ a todas estas verificaciones:

**Nextcloud:**
- [ ] Ficha nextcloud instalada y Running en namespace sbos-{tenant}
- [ ] nextcloud_db creada en PostgreSQL con credenciales Vault
- [ ] Client OIDC 'nextcloud' registrado en realm Keycloak del tenant
- [ ] PVC nextcloud-data-{tenant} provisionado con la capacidad del seed file
- [ ] Estructura de carpetas tenant/empresa/sucursal/usuario creada
- [ ] Cuotas del seed file aplicadas
- [ ] Ruta Kong configurada: files.{tenant}.sksistemas.com → nextcloud

**Guacamole:**
- [ ] Ficha guacamole instalada y Running
- [ ] guacamole_db creada en PostgreSQL
- [ ] Client OIDC 'guacamole' registrado en Keycloak
- [ ] Ruta Kong configurada: vdi.{tenant}.sksistemas.com → guacamole

**Pod Fedora Lógico:**
- [ ] Mínimo 2 pods Running en namespace sbos-{tenant}
- [ ] sbos-client en cada pod registrado con bhnexus (dctx_id creado)
- [ ] Nextcloud montado en cada pod (home listo para usuarios)
- [ ] VNC interno accesible desde Guacamole (no expuesto externamente)
- [ ] HPA configurado (min=2, max=20)

**Verificación end-to-end:**
- [ ] `bosctl vdi verify --tenant={tenant}` reporta OK
- [ ] Login web en vdi.{tenant}.sksistemas.com → autenticación Keycloak → escritorio GNOME visible
- [ ] Guardar un archivo en el escritorio Fedora → aparece en Nextcloud web → confirmado
- [ ] Logout → sesión termina, home desmontado, pod vuelve al pool

**ISO Fedora Físico:**
- [ ] sbos-fedora.iso disponible en GitLab Releases (último tag)
- [ ] Hash SHA256 publicado junto al ISO
- [ ] Firma Ed25519 verificable con clave pública SKULL
- [ ] `bosctl iso download --version=latest` retorna URL válida
- [ ] Test de instalación en hardware real o VM: sbos-firstboot completa sin errores
- [ ] Primer arranque post-instalación: sbos-client se registra con bhnexus, dctx_id creado

---

## 13. Ruta de Instalación Completa del SBOS — Perspectiva VDI

El SBOS se considera **completamente instalado y operativo** cuando este flujo funciona de extremo a extremo:

```
INICIO: Ubuntu limpio en el servidor
        ↓
[Capa 1-2] bos bootstrap: Ubuntu + K8s + Calico + CSI
        ↓
[Capa 3]   PostgreSQL HA + Redis + Vault (unseal manual Shamir)
        ↓
[Capa 4]   Keycloak + Kong + Linkerd
        ↓
[Capa 5]   Daemons soberanos: bos, bkernel, bauth, biedata,
           bcompass, bsearch, bhnexus
        ↓
[Capa 6]   Fichas: Tryton, Saleor, OrangeHRM, bNotifier...
        ↓
[Capa 7a]  Nextcloud + Guacamole + pod Fedora Lógico
           → bosctl vdi verify --tenant={tenant} → OK
        ↓
[Capa 7b]  sbos-fedora.iso disponible
           → bosctl iso download → URL válida
        ↓
FIN: SBOS completamente operativo

VERIFICACIÓN FINAL:
  El administrador abre un navegador en cualquier dispositivo
  → entra a vdi.skull.sksistemas.com
  → se autentica con Keycloak
  → obtiene escritorio Fedora completo
  → abre Tryton desde el escritorio
  → guarda un documento → aparece en Nextcloud
  → cierra sesión

  "El SBOS está instalado."
```

---

## Trazabilidad

| Sección | Fuente | Relación |
|---|---|---|
| §1-2 Propósito y principios | Conversación arquitectónica Jun 2026 + SBOS-049 + MANUAL-ACOPLAMIENTO | Formalización de decisiones tomadas en sesión |
| §3 Dos tipos de Fedora | SBOS-049 §16 (ciclo de vida real) + SBOS-039 (banexus) | Fedora Físico extiende banexus; Fedora Lógico es nuevo |
| §4 sbos-client | SBOS-039 (banexus como referencia de diseño) + SBOS-018 (bos modos) | Nuevo daemon, mismo patrón que banexus |
| §5 Nextcloud | Criterios: AGPL v3, Keycloak OIDC, PostgreSQL — evaluación Jun 2026 | Única tecnología que cumple los tres criterios |
| §6 Guacamole | Apache 2.0 — estándar de industria para VDI web | Integración via OIDC Keycloak |
| §7 Pod Fedora Lógico | SBOS-019-FICHAS (estructura de ficha) + SBOS-005 (stack K8s) | Nueva ficha, sigue patrón manifest.yml |
| §8 sbos-fedora.iso | Fedora Kickstart + lorax — herramientas estándar Fedora | Artefacto nuevo, CI en GitLab CE existente |
| §9 Integración bos | SBOS-018-DAEMON-BOS §18.1 (saga alta tenant) + SBOS-035 (install routine) | VDI Layer como Capa 7 del bootstrap |
| §10 Seguridad | SBOS-004-RULES (principios) + dconf/SELinux Fedora | Políticas estándar Fedora + restricciones SBOS |
| §11 DDL | SBOS-049 §12 (context_sessions existente) | Extensión, no reemplazo |
| §12-13 Checklist | SBOS-MANUAL-ACOPLAMIENTO §36 (patrón checklist) | Mismo patrón, aplicado al VDI Layer |

---

_SKULL · SBOS · SBOS-052-VDI-SPEC · HUMAN-DOC v1.0 · Junio 2026_
_Nuevo documento — no reemplaza ningún documento anterior_
_Define: Fedora Físico, Fedora Lógico, sbos-client, Nextcloud soberano, Guacamole VDI, sbos-fedora.iso, VDI Layer como cúspide del bootstrap SBOS_
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
