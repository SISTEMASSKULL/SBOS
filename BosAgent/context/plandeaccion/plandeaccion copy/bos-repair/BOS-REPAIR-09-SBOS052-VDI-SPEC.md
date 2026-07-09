# BOS-REPAIR-09 — SBOS-052 VDI Layer Spec
## Capa Cliente Soberana: Fedora Físico, Fedora Lógico y Almacenamiento Soberano
## Estándar HUMAN-DOC · SKULL · SBOS · v1.0 · Junio 2026

**Prefijo BOS-REPAIR:** Este documento es parte del proyecto de reparación del BosAgent.  
**Relevancia para BOS-REPAIR:** El VDI Layer es la cúspide de la instalación SBOS. Los criterios C-09..C-14 del BOS-REPAIR-01 dependen de este documento. El bos es responsable de provisionar y mantener todo el VDI Layer.  
**Referencia cruzada:** BOS-REPAIR-01 §Capa 4, BOS-REPAIR-05 §Fase 5 y 9, BOS-REPAIR-08 §Flujo dctx_id

---

## 1. Propósito

Este documento formaliza la **Capa Cliente Soberana (VDI Layer)** del SBOS: el conjunto de componentes, configuraciones y artefactos que permiten a cualquier usuario interactuar con el stack desde cualquier dispositivo.

Responde tres preguntas:

> **¿Cómo accede un usuario al SBOS?**
> Fedora físico (hardware real) o Fedora lógico (navegador web via Guacamole).

> **¿Dónde viven los datos del usuario?**
> En el servidor, en Nextcloud (AGPL v3). Ningún dato reside en el disco del cliente.

> **¿Cuándo está el SBOS completamente instalado?**
> Cuando el pod Fedora Lógico es accesible por web Y el ISO está disponible. El VDI Layer es la cúspide — el último hito del bootstrap.

---

## 2. Principios Fundamentales

| # | Principio | Justificación |
|---|---|---|
| P1 | **Ningún dato del usuario en el cliente** | Todo vive en el servidor. El disco local es invisible para el usuario. |
| P2 | **El ctx_id es el pasaporte universal** | El mismo ctx_id y BitMask controla lo que el usuario puede hacer desde cualquier dispositivo. |
| P3 | **Fedora como superficie soberana** | Fedora (físico o lógico) es la única superficie gestionada y certificada por SBOS. |
| P4 | **Keycloak gobierna toda autenticación** | Nextcloud, Guacamole, sbos-client — todos delegan a Keycloak. Sin login propio. |
| P5 | **Hardware legacy como ventaja** | CPU de 2010 + 4GB RAM = cliente SBOS completamente funcional. |
| P6 | **VDI Layer es la cúspide del bootstrap** | La instalación no termina con K8s corriendo — termina con el escritorio Fedora accesible. |
| P7 | **Licencias OSI-approved únicamente** | Nextcloud (AGPL v3), Guacamole (Apache 2.0), Fedora (múltiples OSI). Sin excepciones. |

---

## 3. Los Dos Tipos de Cliente Fedora

### 3.1 Fedora Físico — Cliente Soberano Completo

**Definición:** Instalación de Fedora en hardware real con `sbos-client` y `banexus` activos como servicios systemd.

**Dominios habilitados:**

| Dominio | Estado | Mecanismo |
|---|---|---|
| Físico | ✅ Completo | banexus → chapas, cajón POS, actuadores, cámaras via udev/libusb |
| Lógico | ✅ Completo | sbos-client + BitMask → apps, permisos, recursos del OS |
| Financiero | ✅ Completo | BitMask → límites transaccionales, SoD, doble firma |

**Requisitos de hardware mínimos:**
```
CPU:   x86_64, cualquier generación desde 2008 (Fedora 42 soporta SSE2+)
RAM:   4 GB mínimo, 8 GB recomendado
Disco: 32 GB mínimo (el home del usuario vive en el servidor)
Red:   Ethernet o WiFi con conectividad al servidor SBOS
USB:   Para lectores NFC/QR/biométrico (banexus los intercepta via udev)
```

**Componentes instalados:**
```
sbos-client.service     ← agente soberano, se registra con bhnexus al arranque
banexus.service         ← control de hardware físico
nextcloud-desktop       ← monta home del usuario en el servidor
gnome-shell             ← escritorio, controlado por sbos-client via dconf
keycloak-oidc-pam       ← módulo PAM para login GNOME via Keycloak
```

### 3.2 Fedora Lógico — Cliente Web Soberano

**Definición:** Pod Kubernetes que corre una imagen OCI Fedora con GNOME completo y `sbos-client`, servido al navegador via **Apache Guacamole** (Apache 2.0).

**Dominios habilitados:**

| Dominio | Estado | Razón |
|---|---|---|
| Físico | ✗ No aplica | Sin banexus. Hardware del servidor ≠ hardware del usuario. |
| Lógico | ✅ Completo | sbos-client activo en el pod |
| Financiero | ✅ Completo | BitMask en ctx_id |

**Flujo de acceso:**
```
Navegador del usuario (cualquier dispositivo)
      ↓ HTTPS via Kong
Guacamole (pod K8s — ficha SBOS)
      ↓ VNC interno (red privada K8s — no expuesto externamente)
Pod Fedora Lógico (escritorio GNOME)
      ↓ sbos-client activo
bhnexus → bos → dctx_id → ctx_id + BitMask
```

---

## 4. sbos-client — El Agente Soberano

**Propósito:** daemon Go que corre en Fedora (físico o lógico). Es el punto de contacto del dispositivo con el sistema SBOS.

**Responsabilidades:**
```
Al arranque:
  → Abre conexión WSS/mTLS con bhnexus
  → Envía: device_uuid, hostname, IP, MAC, tenant
  → bos crea dctx_id
  → Recibe: políticas base (sin usuario aún)

Al login del usuario (via PAM Keycloak):
  → bos promueve dctx_id → ctx_id
  → Recibe ctx_id con BitMask completo
  → Aplica políticas dconf según BitMask:
      disable-save-to-disk, disable-mount-removable-storage
      apps habilitadas, zonas físicas activas
  → Monta home Nextcloud en ~/

En operación:
  → Renueva ctx_id antes de expiración
  → Detecta cambios de BitMask en tiempo real
  → Actualiza políticas dconf dinámicamente

Al logout:
  → Notifica a bos: ctx_id → INVALIDADO
  → Desmonta home Nextcloud
  → Revoca políticas dconf
  → Pod Lógico vuelve al pool
```

**Puertos:** `:28330` (metrics), `:28331` (health)

---

## 5. Apache Guacamole — Gateway VDI HTML5

**Propósito:** Transforma un escritorio VNC/RDP en una aplicación HTML5 accesible desde cualquier navegador sin plugins.

**Integración con Keycloak:**
```
Usuario abre https://vdi.skull.sksistemas.com
      ↓ Guacamole redirige a Keycloak
      ↓ Keycloak autentica → retorna JWT con ctx_id + grupos
      ↓ Guacamole mapea grupos → conexiones VNC disponibles
      ↓ Usuario asignado a pod Fedora del pool
      ↓ Escritorio GNOME renderizado en navegador via HTML5
```

**Gestión del pool por el bos:**
```
Usuario tiene pod activo → conecta directamente
Usuario sin pod → bos asigna pod del pool
Pool agotado → bos escala Deployment automáticamente (HPA)
Pod inactivo >30min → bos lo suspende (recursos liberados)
Pod inactivo >8h → bos lo termina (home persiste en Nextcloud)
```

**manifest.yml (ficha SBOS):**
```yaml
identity:
  id: "guacamole"
  version: "1.5.x"
  criticality: false
  license: "Apache-2.0"
depends_on: [postgresql, keycloak, kong, fedora-logico]
ports:
  http: 28310
  https: 28311
  metrics: 28312
  health: 28313
database:
  name: "guacamole_db"
  engine: postgresql
keycloak:
  client_id: "guacamole"
  realm: "{tenant}"
  grant_type: authorization_code
```

---

## 6. Nextcloud — Almacenamiento Soberano

**Propósito:** Dos roles simultáneos:
1. **Sistema de archivos del usuario** — reemplaza el disco local
2. **Acceso universal** — mismo contenido desde cualquier dispositivo

**Integración Keycloak:**
```
Usuario accede a Nextcloud (web o app móvil)
      ↓ Nextcloud redirige a Keycloak SSO
      ↓ Keycloak autentica → JWT con ctx_id + tenant + empresa
      ↓ Nextcloud monta el espacio del usuario correcto
      ↓ Usuario ve sus carpetas y las compartidas de empresa/sucursal
```

**Estructura de almacenamiento por tenant:**
```
/srv/nextcloud/tenants/skull/
  empresas/
    maya/
      sucursales/lapaz/
        compartido/       ← carpeta compartida de sucursal
        usuarios/
          juan.garcia/    ← home del usuario
          maria.lopez/
      compartido/         ← documentos de empresa
  admin/skull-global/     ← documentos globales del tenant
```

**Cuotas por rol (seed file):**
```yaml
storage:
  nextcloud:
    quotas:
      default_user: 5GB
      admin_user:  20GB
      manager:     10GB
      pos_operator: 2GB
    shared_empresa:  50GB
    shared_sucursal: 20GB
```

**manifest.yml (ficha SBOS):**
```yaml
identity:
  id: "nextcloud"
  version: "30.x"
  criticality: true
  license: "AGPL-3.0"
depends_on: [postgresql, keycloak, kong, vault]
ports:
  http: 28300
  https: 28301
  metrics: 28302
  health: 28303
storage:
  pvc_name: "nextcloud-data-{tenant}"
  storage_class: "sbos-sovereign"
  access_mode: ReadWriteMany
  size: "500Gi"
```

---

## 7. Pod Fedora Lógico como Ficha SBOS

**Imagen OCI:**
```dockerfile
FROM fedora:42
RUN dnf install -y \
    gnome-shell gnome-terminal nautilus libreoffice \
    firefox nextcloud-desktop tigervnc-server
COPY --from=skull/sbos-client:latest /usr/bin/sbos-client /usr/bin/sbos-client
EXPOSE 5900   # VNC interno — solo accesible desde Guacamole
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
```

**manifest.yml:**
```yaml
identity:
  id: "fedora-logico"
  version: "1.0.0"
  criticality: false
  license: "Mixed-OSS"
workload:
  type: kubernetes
  replicas: 2
  hpa:
    min: 2
    max: 20
    metric: concurrent_sessions
depends_on: [keycloak, nextcloud, sbos-client]
ports:
  vnc: 5900       # interno — solo desde Guacamole
  metrics: 28320
  health: 28321
scaling:
  strategy: coordinated
  horizontal:
    min_replicas: 2
    max_replicas: 20
    target_metric: concurrent_sessions
  context_aware:
    enabled: true
    peak_contexts:
      - contexts_gt: 50
        min_replicas: 3
      - contexts_gt: 200
        min_replicas: 5
```

---

## 8. El Artefacto sbos-fedora.iso

**Propósito:** ISO booteable que produce un Fedora Físico completamente configurado. El técnico instala, responde 3 preguntas, reinicia — el equipo queda listo.

**sbos-firstboot — wizard de instalación:**
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

  Verificando conectividad...
  ✓ bos alcanzable
  ✓ Certificado TLS válido
  ✓ Tenant skull existe

  Registrando dispositivo...
  ✓ device_uuid: d7f3a1b2-... generado
  ✓ Certificado mTLS emitido por bos PKI
  ✓ sbos-client.service habilitado
  ✓ banexus.service habilitado

  Instalación completa. Reiniciando...
═══════════════════════════════════════════
```

**Verificación del ISO:**
```bash
bosctl rpc bos.query.vdi '{"tenant_id":"skull"}' | grep iso
# → "iso_fedora": {"version":"1.0.0","disponible":true,"url":"...","sha256":"a3f9..."}

bosctl iso download --version=latest
bosctl iso verify sbos-fedora-1.0.0.iso  # verifica firma Ed25519
```

---

## 9. Integración del bos con el VDI Layer

**Lo que el bos provisiona al alta del tenant (`bosctl deploy <seed.yml>`):**

```bash
# Paso 1 — Nextcloud
bosctl ficha install nextcloud --tenant={tenant}
  → nextcloud_db en PostgreSQL (credenciales via Vault)
  → PVC nextcloud-data-{tenant} (500Gi)
  → client OIDC 'nextcloud' en realm KC del tenant
  → estructura de carpetas por tenant/empresa/sucursal
  → cuotas del seed file aplicadas
  → ruta Kong: files.{tenant}.sksistemas.com → nextcloud

# Paso 2 — Guacamole
bosctl ficha install guacamole --tenant={tenant}
  → guacamole_db en PostgreSQL
  → client OIDC 'guacamole' en realm KC
  → ruta Kong: vdi.{tenant}.sksistemas.com → guacamole

# Paso 3 — Pool Fedora Lógico
bosctl ficha install fedora-logico --tenant={tenant} --replicas=2
  → 2 pods Fedora Lógico en namespace sbos-{tenant}
  → certificado mTLS via Vault PKI para cada pod
  → sbos-client en cada pod se registra con bhnexus (dctx_id creado)
  → HPA configurado (min=2, max=20)

# Paso 4 — Verificación end-to-end
bosctl vdi verify --tenant={tenant}
  → verifica 6 pasos: K8s pods, Nextcloud, Guacamole, ctx, home, acceso web
  → retorna: "VDI Layer operativo para tenant {tenant}" ✓

# Paso 5 — ISO disponible
bosctl iso status --version=latest
  → retorna URL con SHA256 y firma Ed25519
```

**Comandos bosctl para el VDI Layer:**
```bash
bosctl vdi pool list --tenant=skull        # pods activos y sesiones
bosctl vdi pool scale --tenant=skull --min=4
bosctl vdi session list --tenant=skull     # sesiones activas
bosctl vdi session kill --session=sess-x   # forzar cierre
bosctl vdi verify --tenant=skull           # verificación end-to-end
bosctl vdi health --tenant=skull           # estado de todos los componentes
bosctl storage quota set --user=juan --quota=10GB --tenant=skull
bosctl storage usage --tenant=skull
bosctl device revoke --device-uuid=d7f3a1b2-...
bosctl iso download --version=latest
bosctl iso verify <archivo.iso>
```

---

## 10. Seguridad y Aislamiento

### El disco local es inaccesible para el usuario

**En Fedora Físico**, sbos-client aplica al recibir ctx_id:
```
1. dconf: Nautilus solo muestra Nextcloud
2. dconf: disable-save-to-disk = true
3. dconf: disable-mount-removable-storage = true
4. SELinux: usuarios normales no escriben fuera de /home/{usuario}
5. PAM: su/sudo deshabilitados para usuarios no-admin
```

**En Fedora Lógico**, el aislamiento es por construcción:
```
El filesystem del pod es efímero — desaparece al terminar la sesión.
El home del usuario vive en Nextcloud (PVC).
El pod no tiene acceso a filesystems de otros pods.
El VNC solo es accesible desde Guacamole via red privada K8s.
```

### Revocación de dispositivo comprometido

```bash
bosctl device revoke --device-uuid=d7f3a1b2-...
  → Vault revoca el certificado mTLS del dispositivo
  → bhnexus cierra la conexión WebSocket activa
  → ctx_id del dispositivo → INVALIDADO en Redis
  → evento: device.revoked emitido en audit_events
```

---

## 11. Modelo de Datos — Extensiones VDI

Ver BOS-REPAIR-08 §10 para el DDL completo de `context_sessions` y `registered_devices`.

**Extensiones específicas del VDI Layer:**
```sql
-- En context_sessions:
ALTER TABLE context_sessions ADD COLUMN IF NOT EXISTS
  guacamole_session_id    VARCHAR(128);  -- solo para logical_pod
ALTER TABLE context_sessions ADD COLUMN IF NOT EXISTS
  nextcloud_home_mounted  BOOLEAN DEFAULT FALSE;
```

---

## 12. Checklist de Acoplamiento — VDI Layer

Un despliegue del VDI Layer está correctamente completado cuando responde SÍ a todo:

**Nextcloud:**
- [ ] Ficha nextcloud instalada y Running en namespace sbos-{tenant}
- [ ] nextcloud_db creada en PostgreSQL con credenciales Vault
- [ ] Client OIDC 'nextcloud' registrado en realm Keycloak del tenant
- [ ] PVC nextcloud-data-{tenant} provisionado con capacidad del seed file
- [ ] Estructura de carpetas tenant/empresa/sucursal/usuario creada
- [ ] Cuotas del seed file aplicadas
- [ ] Ruta Kong: files.{tenant}.sksistemas.com → nextcloud

**Guacamole:**
- [ ] Ficha guacamole instalada y Running
- [ ] guacamole_db creada en PostgreSQL
- [ ] Client OIDC 'guacamole' registrado en Keycloak
- [ ] Ruta Kong: vdi.{tenant}.sksistemas.com → guacamole

**Pod Fedora Lógico:**
- [ ] Mínimo 2 pods Running en namespace sbos-{tenant}
- [ ] sbos-client en cada pod registrado con bhnexus (dctx_id creado)
- [ ] Nextcloud montado en cada pod (home accesible)
- [ ] VNC interno accesible desde Guacamole (no expuesto externamente)
- [ ] HPA configurado (min=2, max=20)

**Verificación end-to-end (Criterio C-14 del BOS-REPAIR-01):**
- [ ] `bosctl vdi verify --tenant={tenant}` → 6/6 pasos OK
- [ ] Login web en vdi.{tenant}.sksistemas.com → GNOME visible en <10s
- [ ] Guardar archivo en escritorio Fedora → aparece en Nextcloud web
- [ ] Logout → sesión termina, home desmontado, pod vuelve al pool

**ISO Fedora Físico:**
- [ ] sbos-fedora.iso disponible en GitLab Releases
- [ ] Hash SHA256 publicado junto al ISO
- [ ] Firma Ed25519 verificable con clave pública SKULL
- [ ] `bosctl iso download --version=latest` retorna URL válida
- [ ] Test en hardware real: sbos-firstboot completa sin errores
- [ ] Primer arranque: sbos-client se registra, dctx_id creado

---

## 13. Ruta de Instalación Completa del SBOS — Perspectiva VDI

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
  Administrador abre navegador en cualquier dispositivo
  → entra a vdi.skull.sksistemas.com
  → se autentica con Keycloak
  → obtiene escritorio Fedora completo
  → abre Tryton desde el escritorio
  → guarda documento → aparece en Nextcloud
  → cierra sesión

  "El SBOS está instalado."
```

---

## 14. Criterios de reparación del VDI Layer (BOS-REPAIR)

Cuando el VDI Layer falla, la reparación está completa solo cuando:

```bash
# Verificación rápida (< 2 minutos)
bosctl rpc bos.query.vdi '{"tenant_id":"skull"}'
# → semaforo_vdi: "VERDE"
# → fedora_logico.pods_running: >= 2
# → nextcloud.healthy: true
# → guacamole.healthy: true
# → context_plane_vdi.bitmask_cero_count: 0

# Verificación completa (< 5 minutos)
bosctl vdi verify --tenant=skull
# → 6/6 pasos OK

# Criterio C-14 (test end-to-end con usuario real)
bosctl vdi test-user --tenant=skull --user=test@skull.com --password=testpass
# → 6/6 pasos OK
# → login latency < 10s
# → archivo persistido en Nextcloud: true
```

**Diagnóstico de fallo por componente:**

| Fallo | Diagnóstico | Reparación |
|---|---|---|
| fedora-logico CrashLoop | `bosctl logs fedora-logico --tenant=skull` | Verificar sbos-client config, cert mTLS via Vault |
| Nextcloud maintenance:true | `bosctl describe nextcloud --tenant=skull` | `bosctl rpc bos.ficha.repair '{"ficha_id":"nextcloud"}'` |
| dctx_id no creado en pod | `bosctl query context --tenant=skull` | Verificar bhnexus, reiniciar sbos-client en pod |
| Home no montado | `bosctl rpc bos.query.vdi` campo home_mount | Verificar PVC nextcloud-data, PodDisruptionBudget |
| Guacamole 502 | `bosctl events --ficha=guacamole` | Verificar ruta Kong, certificado TLS |

---

*BOS-REPAIR-09 — SKULL · SBOS · Junio 2026*  
*Basado en: SBOS-052-VDI-SPEC v1.0 (Junio 2026)*  
*Referencia: BOS-REPAIR-01 §Capa 4 y §Criterios C-09..C-14*  
*Referencia: BOS-REPAIR-08 (Context Plane — dctx_id/ctx_id en dispositivos)*  
*Referencia: BOS-REPAIR-05 §Fase 5 (bosctl context), §Fase 9 (escalado VDI)*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
