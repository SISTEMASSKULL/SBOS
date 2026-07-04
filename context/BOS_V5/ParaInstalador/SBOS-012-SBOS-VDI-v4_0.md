# SBOS-012 — SBOS VDI: Sovereign Desktop Infrastructure
## Especificación Técnica · v5.0 · Corrección de coherencia bAuth

### SKULL · SBOS — Sovereign Business Operating System
### Marzo 2026

---

| Campo | Valor |
|---|---|
| **Documento** | SBOS-012 |
| **Título** | SBOS VDI — Escritorio Soberano |
| **Versión** | v5.0 · Corrección de coherencia bAuth |
| **Estado** | ACTIVO |
| **Anterior** | SBOS-009-SKVDI v3.5 (arquitectura Kasm — SUPERSEDED) |

---

## Tabla de Contenidos

1. [Qué es el SBOS VDI](#1-qué-es-el-sbos-vdi)
2. [Por Qué No Kasm Workspaces](#2-por-qué-no-kasm-workspaces)
3. [Principios Arquitectónicos Fundamentales](#3-principios-arquitectónicos-fundamentales)
4. [Arquitectura General del Sistema](#4-arquitectura-general-del-sistema)
5. [Stack Tecnológico](#5-stack-tecnológico)
6. [bAuth — El Daemon Soberano de Identidad y Privilegios](#6-apibitmask--el-daemon-soberano-de-privilegios)
7. [La Aritmética BitMask — Representación de Privilegios](#7-la-aritmética-bitmask--representación-de-privilegios)
8. [Las Fichas rights — Unidades de Extensión del bAuth](#8-las-fichas-rights--unidades-de-extensión-del-apibitmask)
9. [El Wrapper sbos-vdi-run — Punto Único de Control de Ejecución](#9-el-wrapper-sbos-vdi-run--punto-único-de-control-de-ejecución)
10. [Control de Red Soberano — Reemplazo de HashiCorp Boundary](#10-control-de-red-soberano--reemplazo-de-hashicorp-boundary)
11. [Tryton como Motor de Privilegios — Los 5 Niveles Nativos](#11-tryton-como-motor-de-privilegios--los-5-niveles-nativos)
12. [RolFramework como Coordinador Keycloak ↔ Tryton](#12-rolframework-como-coordinador-keycloak--tryton)
13. [El Sistema de Políticas en Cascada](#13-el-sistema-de-políticas-en-cascada)
14. [Modos de Operación del Escritorio](#14-modos-de-operación-del-escritorio)
15. [Control de Recursos del Sistema](#15-control-de-recursos-del-sistema)
16. [Sistema de Archivos y Almacenamiento NFS](#16-sistema-de-archivos-y-almacenamiento-nfs)
17. [Auditoría Centralizada](#17-auditoría-centralizada)
18. [Modelo de Seguridad: 6 Capas](#18-modelo-de-seguridad-6-capas)
19. [Ciclo de Vida del Usuario](#19-ciclo-de-vida-del-usuario)
20. [Herencia de Políticas: Posición y Transferencia](#20-herencia-de-políticas-posición-y-transferencia)
21. [Flujos Completos](#21-flujos-completos)
22. [La Ficha SBOS VDI en el IAM Installer](#22-la-ficha-sbos-vdi-en-el-iam-installer)
23. [El Protocolo sbos:// — Deep Links Soberanos](#sbos)
24. [Fronteras que el SBOS VDI Nunca Cruza](#24-fronteras-que-el-sbos-vdi-nunca-cruza)
25. [Hoja de Ruta de Desarrollo](#25-hoja-de-ruta-de-desarrollo)
26. [Registro de Cambios](#26-registro-de-cambios)

---

## 1. Qué es el SBOS VDI

El SBOS VDI es la **capa de presentación soberana del SBOS para el usuario final**. Es un Sistema Operativo Empresarial Consciente: un entorno Fedora KDE Plasma que, en el momento en que el usuario se autentica, se transforma dinámicamente en el escritorio exacto que su rol, posición y perfil personal determinan.

El escritorio que ve el usuario no es el resultado de una configuración manual. Es el resultado de aplicar un sistema de políticas en cascada de tres niveles — Empresa → Rol → Usuario — ejecutado en tiempo real por el **bAuth**, el daemon soberano de privilegios de SKULL.

```
bKernel:      escucha WAL        → procesa reglas YAML    → sincroniza datos entre apps
biedata:     escucha eventos    → selecciona caja         → ejecuta box_engine.yml
bCompass:     escucha eventos    → selecciona ruta         → orienta al negocio
bAuth:   escucha sesiones   → evalúa BitMask          → gobierna el escritorio
                                                           → autoriza o deniega cada acción
```

El SBOS VDI no gestiona solo el escritorio — gestiona el ciclo de vida completo del usuario en la organización: activación, operación diaria, suspensión temporal, transferencia de posición, offboarding y archivo. Todo ejecutable desde el Core UI sin intervención técnica manual.

### La metáfora correcta

El bAuth es el **sistema nervioso autónomo** del escritorio corporativo. El sistema nervioso autónomo controla funciones vitales del organismo sin que el individuo tenga que pensarlo conscientemente. Regula la frecuencia cardíaca, la respiración, la digestión — momento a momento, en respuesta al entorno.

El bAuth hace lo mismo con el escritorio: cada vez que el usuario hace clic en una aplicación, el sistema nervioso evalúa silenciosamente si esa acción está autorizada por su máscara de privilegios y responde en milisegundos. El usuario nunca siente la infraestructura — solo ve un escritorio que funciona exactamente como la empresa necesita.

---

## 2. Por Qué No Kasm Workspaces

### 2.1 El problema de fondo

Kasm Workspaces es una plataforma de streaming de contenedores: transmite escritorios desde el servidor al navegador. Es una solución técnicamente sólida para el problema de "dar escritorios remotos seguros". Pero el problema del SBOS VDI es diferente y más profundo: **hacer que escritorios locales existentes se comporten según las reglas del negocio**.

Kasm es una jaula de oro. El SBOS VDI necesita un sistema abierto y extensible.

### 2.2 Tabla Comparativa

| Aspecto | Kasm Workspaces | SBOS VDI v5.0 · Corrección de coherencia bAuth |
|---|---|---|
| Modelo de operación | Streaming de contenedores (todo remoto) | Fedora local + control desde servidor |
| Control de privilegios | Interno de Kasm, roles simples | Tryton (5 niveles nativos) + bAuth |
| Personalización | Branding visual y apps predefinidas | Dinámica por BitMask por usuario |
| Aplicaciones locales | No aplica — todo es remoto | Control total via wrapper sbos-vdi-run |
| Control de red por usuario | Global o por grupo | Granular: por app, por horario, por URL |
| Cuotas de disco | Limitado al contenedor | NFS con quotactl real en servidor |
| Persistencia de datos | Volúmenes Docker limitados | NFS montado desde servidor central |
| Auditoría | Logs de sesiones Kasm | PostgreSQL: cada acción registrada |
| Integración con ERP | Limitada a webhooks/API simple | Profunda: Tryton como motor de autorización |
| Licenciamiento | Comercial | Cero costo — stack GPL + kernel Linux |
| Modo offline | No soportado | Sí, con políticas de contingencia |
| Modo USB | Cliente mínimo Kasm | Fedora SKULL propio, arranca en cualquier PC |
| Soberanía | Dependencia del proveedor Kasm | 100% SKULL — sin dependencias externas |

### 2.3 Limitaciones Fundamentales de Kasm para el Caso de SBOS

**Kasm no puede consultar a Tryton para decisiones en tiempo real.** La lógica de privilegios de Kasm es interna. No puede evaluar los 5 niveles nativos de acceso de Tryton ni coordinarse con el RolFramework.

**Kasm no puede controlar aplicaciones instaladas localmente.** Firefox, LibreOffice, y cualquier herramienta nativa en el sistema operativo escapan a su control.

**Kasm no se integra con sistemas de archivos NFS.** No puede aplicar cuotas de disco reales ni montar directorios con permisos granulares.

**Kasm añade una capa de complejidad de licencia.** La edición Community tiene restricciones de escalado. La edición Enterprise es comercial. El SBOS no puede depender de licencias que crezcan con el negocio del cliente.

**Kasm no puede evolucionar con el SBOS.** Las fichas `rights` del bAuth permiten extender el daemon de privilegios con nuevas capacidades sin tocar su núcleo. Kasm no tiene ese mecanismo.

### 2.4 Conclusión del Análisis

La pregunta que Kasm responde: *"¿Cómo damos escritorios remotos seguros?"*
La pregunta que el SBOS VDI responde: *"¿Cómo hacemos que el escritorio del usuario sea exactamente lo que la empresa necesita, sin importar dónde ni cómo arranque?"*

Son preguntas diferentes. El SBOS VDI v5.0 · Corrección de coherencia bAuth responde la suya con herramientas soberanas.

---

## 3. Principios Arquitectónicos Fundamentales

**P1 — El servidor gobierna, el cliente ejecuta.**
Fedora es el sistema operativo local — el hardware es del cliente. Pero todas las decisiones sobre qué puede hacer el usuario en ese Fedora provienen del servidor. El escritorio local es la interfaz; el bAuth en el servidor es quien manda.

**P2 — El usuario no instala nada.**
Lo disponible en el escritorio es exactamente lo que el sistema de políticas determinó. Las aplicaciones están preinstaladas en la imagen Fedora SKULL — desactivadas por defecto. El wrapper sbos-vdi-run decide en tiempo real cuáles están disponibles para este usuario en este momento.

**P3 — La ficha es la fuente de verdad de la infraestructura.**
Toda la configuración del SBOS VDI vive declarada en la ficha `vdiserver/sbos-vdi`, versionada en el repositorio. Nada se configura manualmente fuera del sistema declarativo.

**P4 — La sesión es continua y transparente.**
La sesión pertenece al usuario, no al dispositivo. USB o contenedor web — el mismo escritorio, el mismo estado, los mismos privilegios. El usuario no nota la diferencia.

**P5 — El sistema de políticas en cascada gobierna el escritorio.**
Empresa → Rol → Usuario. Cada nivel puede sobrescribir o extender el anterior. El nivel de Usuario es el más granular y siempre tiene prioridad. Los privilegios se calculan como operaciones sobre BitMasks.

**P6 — La Posición es la unidad de continuidad del negocio.**
El espacio de trabajo pertenece a la Posición, no al usuario. Las políticas personales del usuario anterior se heredan a la Posición y están disponibles para el nuevo usuario como punto de partida — el admin decide qué heredar.

**P7 — Las políticas son decisión de la empresa.**
El bAuth ejecuta políticas — no las decide. Tryton las administra. RolFramework las coordina. El humano las aprueba.

**P8 — Soberanía total.**
Ningún componente del SBOS VDI depende de software con licencia comercial, de servicios cloud externos, ni de proveedores que puedan cambiar sus términos. El stack es 100% GPL, MIT, o kernel Linux nativo.

---

## 4. Arquitectura General del Sistema

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                       SERVIDOR UBUNTU (Host SBOS)                             │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  TRYTON ERP — Motor de Privilegios (5 Niveles Nativos)                   │   │
│  │  Modelo · Acciones · Campo · Botón · Regla de Registro                  │   │
│  │  + Módulo SKULL: sbos-vdi_privileges (apps, URLs, cuotas, horarios)        │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│              ▲ xmlrpc/REST interno           ▲ WAL                              │
│              │                               │                                  │
│  ┌───────────┴──────────────────┐  ┌────────┴────────────────────────────────┐ │
│  │  bAuth HOST             │  │  bKernel                                │ │
│  │  (daemon soberano SKULL)     │  │  WAL→detecta cambios de privilegios     │ │
│  │                              │  │  →invalida caché bAuth             │ │
│  │  · WebSocket Server          │  │  →notifica clientes activos             │ │
│  │  · BitMask Engine            │  └─────────────────────────────────────────┘ │
│  │  · Cache Redis TTL           │                                               │
│  │  · Auditoría PostgreSQL      │  ┌─────────────────────────────────────────┐ │
│  │  · rights Loader             │  │  Squid Proxy (GPL)                      │ │
│  │  · RolFramework Coordinator  │  │  · Filtrado URL por usuario             │ │
│  └──────────────────────────────┘  │  · External ACL Helper → bAuth     │ │
│              ▲                     │  · Registro de navegación               │ │
│              │ WSS (TLS)           └──────────────────────────┬──────────────┘ │
│              │                                                │                 │
│  ┌───────────┴────────────────────┐  ┌─────────────────────┐ │                 │
│  │  Keycloak                      │  │  NFS Server         │ │                 │
│  │  Auth · JWT · SSO              │  │  Homes · Posiciones │ │                 │
│  │  Group → Rol mapping           │  │  Compartidos        │ │                 │
│  └────────────────────────────────┘  └─────────────────────┘ │                 │
└───────────────────────────────────────┬───────────────────────┴─────────────────┘
                                        │ WSS + Proxy HTTPS
                         ┌──────────────┴──────────────────┐
                         │                                  │
              ┌──────────┴──────────┐          ┌───────────┴──────────────┐
              │  FEDORA KDE (web)   │          │  USB SKULL (Fedora)      │
              │  Contenedor en      │          │  Arranca en PC ajeno     │
              │  servidor           │          │  Sistema 100% SKULL      │
              │                     │          │                          │
              │  bAuth CLIENT  │          │  bAuth CLIENT       │
              │  sbos-vdi-run wrapper  │          │  sbos-vdi-run wrapper       │
              │  iptables owner     │          │  iptables owner          │
              │  Proxy → Squid↑    │          │  Proxy → Squid↑         │
              └─────────────────────┘          └──────────────────────────┘
```

---

## 5. Stack Tecnológico

| Componente | Función | Dónde corre | Licencia |
|---|---|---|---|
| bAuth Host | Daemon soberano de privilegios — BitMask Engine, WebSocket, caché | Host Ubuntu (systemd) | SKULL propio |
| bAuth Client | Daemon en Fedora — conecta con Host, responde al wrapper | Fedora cliente (systemd --user) | SKULL propio |
| sbos-vdi-run | Wrapper universal — intercepta ejecuciones, consulta daemon local | Fedora cliente | SKULL propio |
| Tryton ERP | Motor de privilegios — 5 niveles nativos + módulo sbos-vdi_privileges | Pod K8s sbos-erp | LGPL |
| RolFramework | Coordinador Keycloak ↔ Tryton — calcula y propaga políticas | Librería Python / daemon | SKULL propio |
| Keycloak | Autenticación, JWT, SSO | Pod K8s sbos-identity | Apache 2.0 |
| Redis 7.x | Caché de BitMasks por usuario (TTL 5 min) | Pod K8s / host | BSD |
| PostgreSQL 15+ | Auditoría de acciones + DB propia del bAuth | Pod K8s sbos-data | PostgreSQL License |
| Squid Proxy | Filtrado de URLs por usuario con External ACL Helper | Host Ubuntu (systemd) | GPL |
| iptables / nftables | Control de red por proceso (módulo owner) | Kernel Linux nativo | GPL |
| NFSv4 | Sistema de archivos compartido — homes, posiciones, compartidos | Host Ubuntu | GPL |
| cgroups v2 / systemd | Control de recursos CPU/memoria por aplicación | Kernel Linux nativo | GPL |
| Fedora 43 KDE Plasma | Escritorio corporativo soberano | Cliente / USB | GPL |
| PAM sbos-vdi | Módulo PAM — captura token Keycloak al login | Fedora cliente | SKULL propio |
| bKernel | Detecta cambios en Tryton via WAL → notifica bAuth | Host Ubuntu (systemd) | SKULL propio |

---

## 6. bAuth — El Daemon Soberano de Identidad y Privilegios

### 6.1 Qué es el bAuth

El bAuth es el **daemon soberano de privilegios del SBOS**. Es el sistema nervioso autónomo del escritorio corporativo: evalúa en tiempo real si cada acción que intenta ejecutar un usuario está autorizada por su máscara de privilegios, y responde en milisegundos.

```
bAuth HOST:    escucha conexiones WebSocket de clientes Fedora
                    evalúa BitMask de usuario contra la acción solicitada
                    consulta Tryton (caché Redis TTL 5min)
                    registra toda acción en PostgreSQL
                    notifica cambios de privilegios a clientes activos
                    extiende sus capacidades mediante fichas rights

bAuth CLIENT:  corre en cada Fedora (systemd --user)
                    mantiene conexión WebSocket persistente con el Host
                    responde consultas locales del wrapper sbos-vdi-run
                    recibe notificaciones de cambio en tiempo real
                    aplica reglas de red locales (iptables) según BitMask
```

El bAuth no tiene interfaz gráfica. No expone API REST al exterior más allá del socket WebSocket de privilegios. Es un evaluador de autorización autónomo y silencioso.

### 6.2 Comparación con el meta-patrón del SBOS

```
IAM Installer:  escuchar filesystem → detectar cambios   → actuar sobre K8s      → nunca invadir apps
bKernel:        escuchar WAL        → detectar eventos    → actuar sobre datos     → nunca invadir apps
biedata:       escuchar eventos    → seleccionar caja    → integrar datos         → nunca invadir apps
bCompass:       escuchar eventos    → seleccionar ruta    → orientar al negocio    → nunca decidir solo
bAuth:     escuchar sesiones   → evaluar BitMask     → gobernar escritorio    → nunca decidir políticas
```

El bAuth es al dominio de la **AUTORIZACIÓN DE ESCRITORIO** lo que el bKernel es al dominio de los DATOS.

### 6.3 Componentes del bAuth Host

```
bAuth Host
├── WebSocket Server         — gestiona 10,000+ conexiones concurrentes (asyncio)
├── BitMask Engine           — evalúa BitMasks, opera sobre enteros de 64 bits
├── Rights Loader            — carga fichas rights desde /etc/apibitmask/rights/
├── Tryton Client            — consulta API Tryton para BitMasks de usuario
├── Redis Cache Manager      — cachea BitMasks con TTL 5 minutos por usuario
├── Invalidation Engine      — recibe notificaciones del bKernel, invalida caché
├── Notification Dispatcher  — notifica a clientes activos cuando cambia su BitMask
├── Squid ACL Helper         — responde consultas de autorización de URL de Squid
├── Audit Logger             — registra cada acción en PostgreSQL (async)
└── Rights API               — endpoint interno para que fichas rights extiendan capacidades
```

### 6.4 Especificación Técnica del Host

```python
class ApiBitMaskHost:
    """
    Daemon soberano de privilegios del SBOS.
    Gestiona autorización de escritorio via BitMasks.
    """

    async def handle_client(self, websocket: WebSocket, path: str):
        """Maneja conexión de cliente Fedora — autenticación JWT + registro"""
        token = await self._handshake(websocket)
        user = self._validate_jwt(token)
        self.connections[user.sub] = websocket
        await self._serve_client(user, websocket)

    async def check_permission(
        self,
        user_sub: str,
        action: str,
        context: dict = None
    ) -> PermissionResult:
        """
        Evalúa si user_sub puede ejecutar action.
        Usa BitMask cacheada en Redis. Cache miss → consulta Tryton.
        Registra en auditoría siempre.
        """
        bitmask = await self._get_bitmask(user_sub)
        action_bit = self._resolve_action_bit(action)

        # Evaluación BitMask — O(1)
        allowed = bool(bitmask & action_bit)

        # Evaluaciones adicionales de fichas rights activas
        for rights_module in self.loaded_rights:
            allowed = await rights_module.evaluate(
                allowed, user_sub, action, context, bitmask
            )

        await self.audit_logger.log(user_sub, action, allowed, context)
        return PermissionResult(allowed=allowed, bitmask=bitmask)

    async def invalidate_user_cache(self, user_sub: str):
        """
        Llamado por bKernel cuando Tryton cambia privilegios de user_sub.
        Invalida Redis + notifica al cliente activo.
        """
        await self.redis.delete(f"bitmask:{user_sub}")
        if user_sub in self.connections:
            await self.connections[user_sub].send(
                json.dumps({"type": "PRIVILEGE_UPDATE", "user": user_sub})
            )

    async def squid_acl_check(self, user_sub: str, url: str) -> bool:
        """
        External ACL Helper para Squid.
        Llamado por cada request HTTP/HTTPS del usuario.
        Responde OK o ERR según política de URL del usuario.
        """
        url_policy = await self._get_url_policy(user_sub)
        return url_policy.is_allowed(url)
```

### 6.5 Componentes del bAuth Client

```python
class ApiBitMaskClient:
    """
    Daemon de usuario en Fedora.
    Intermediario local entre sbos-vdi-run y el Host remoto.
    """

    async def connect(self):
        """Conecta al Host con JWT de Keycloak. Reconexión con backoff exponencial."""
        token = self._read_keycloak_token()
        self.ws = await websockets.connect(
            self.host_url,
            extra_headers={"Authorization": f"Bearer {token}"}
        )
        asyncio.create_task(self._listen_notifications())

    async def check(self, action: str, context: dict = None) -> bool:
        """
        Consulta de privilegio desde sbos-vdi-run.
        Responde en <5ms (caché Redis en Host).
        """
        msg = json.dumps({"type": "CHECK", "action": action, "context": context})
        await self.ws.send(msg)
        response = json.loads(await asyncio.wait_for(self.ws.recv(), timeout=2.0))
        return response["allowed"]

    async def _listen_notifications(self):
        """Recibe notificaciones de cambio de privilegios desde Host."""
        async for message in self.ws:
            msg = json.loads(message)
            if msg["type"] == "PRIVILEGE_UPDATE":
                await self._apply_privilege_update()

    async def _apply_privilege_update(self):
        """
        Cuando el Host notifica un cambio de privilegios:
        1. Actualiza reglas iptables locales
        2. Regenera entradas .desktop visibles
        3. Notifica al usuario via libnotify si aplica
        """
        new_policy = await self._fetch_full_policy()
        await self._update_iptables(new_policy.url_policy)
        await self._update_desktop_entries(new_policy.apps)

    async def handle_disconnect(self):
        """Sin conexión al Host = sin privilegios. Política por defecto: denegar todo."""
        self._notify_user("⚠️ Servidor de privilegios no disponible. Acceso restringido.")
        self._apply_offline_policy()

    async def reconnect_with_backoff(self):
        """Backoff exponencial: 5s → 10s → 20s → 40s → max 120s"""
        delay = 5
        while not self.connected:
            await asyncio.sleep(delay)
            try:
                await self.connect()
            except Exception:
                delay = min(delay * 2, 120)
```

### 6.6 Servicios Systemd

```ini
# /etc/systemd/system/apibitmask-host.service
[Unit]
Description=bAuth Host — Sovereign Privilege Daemon (SBOS)
After=network.target redis.service postgresql.service tryton.service
Requires=redis.service postgresql.service

[Service]
Type=simple
User=apibitmask
ExecStart=/usr/local/bin/apibitmask-host
Restart=always
RestartSec=2
MemoryMax=2G
CPUQuota=200%
LimitNOFILE=131072
TimeoutStopSec=10
Environment=APIBITMASK_CONFIG=/etc/apibitmask/host.yml

[Install]
WantedBy=multi-user.target
```

```ini
# /etc/systemd/user/apibitmask-client.service
[Unit]
Description=bAuth Client — Local Privilege Agent (SBOS)
After=graphical-session.target network.target
Requires=dbus.socket

[Service]
Type=simple
ExecStart=/usr/local/bin/apibitmask-client
Restart=always
RestartSec=5
MemoryMax=64M
CPUQuota=10%
TimeoutStopSec=5
Environment=APIBITMASK_HOST=wss://sbos-server.local:8000

[Install]
WantedBy=default.target
```

### 6.7 Métricas de Rendimiento

| Métrica | Objetivo | Cómo se logra |
|---|---|---|
| Latencia de consulta | < 5ms | Redis caché en Host |
| Conexiones concurrentes | 10,000+ | asyncio + WebSocket multiplexing |
| Throughput | 50,000 consultas/seg | BitMask evaluation O(1) |
| Propagación de cambios | < 3 segundos | bKernel → invalidación directa → notificación WS |
| Disponibilidad | 99.9% | Systemd restart automático + backoff en cliente |

---

## 7. La Aritmética BitMask — Representación de Privilegios

### 7.1 El Concepto

Un **BitMask** es un entero de 64 bits donde cada bit representa un privilegio específico del escritorio. La evaluación de si un usuario puede ejecutar una acción es una operación AND sobre enteros — la operación más rápida que existe en cualquier procesador.

```
Bit  0:  firefox                  (navegador web)
Bit  1:  libreoffice-writer       (procesador de texto)
Bit  2:  libreoffice-calc         (hoja de cálculo)
Bit  3:  libreoffice-impress      (presentaciones)
Bit  4:  thunderbird              (cliente de correo)
Bit  5:  element-desktop          (mensajería corporativa)
Bit  6:  vscodium                 (editor de código)
Bit  7:  okular                   (visor de documentos)
...
Bit 20:  usb_mount                (montar dispositivos USB)
Bit 21:  print                    (imprimir)
Bit 22:  screenshot               (capturar pantalla)
Bit 23:  clipboard_out            (copiar al portapapeles externo)
Bit 24:  download_files           (descargar archivos)
Bit 25:  upload_files             (subir archivos)
...
Bit 40:  bos_action_caja_apertura (acción BOS: apertura de caja)
Bit 41:  bos_action_caja_cierre   (acción BOS: cierre de caja)
Bit 42:  bos_action_caja_arqueo   (acción BOS: arqueo de caja)
...
Bit 63:  admin_local              (privilegios de administración local)
```

### 7.2 Operaciones de Composición de Políticas

```python
# El sistema de políticas en cascada expresado como aritmética BitMask

# Nivel 1 — Empresa (bits base para todos los usuarios de la empresa)
empresa_mask     = 0b...0000_0000_1000_0000_0000  # solo okular, correo base

# Nivel 2 — Rol CAJERO (bits del rol, adicionales a empresa)
cajero_mask      = 0b...0000_0111_1000_0000_0000  # + acción apertura, cierre, arqueo

# Nivel 3 — Usuario María García (bits adicionales personales)
maria_extra_mask = 0b...0000_0000_0000_0000_0011  # + writer + firefox

# Máscara efectiva de María = OR de todos los niveles
maria_bitmask    = empresa_mask | cajero_mask | maria_extra_mask

# Evaluación de privilegio — O(1)
def can_execute(user_bitmask: int, action_bit: int) -> bool:
    return bool(user_bitmask & (1 << action_bit))

# ¿Puede María ejecutar Writer? — nanosegundos
can_execute(maria_bitmask, BIT_LIBREOFFICE_WRITER)  # → True

# ¿Puede María montar un USB?
can_execute(maria_bitmask, BIT_USB_MOUNT)  # → False (bit 20 no está en su máscara)
```

### 7.3 BitMask Compuesta para Políticas de URL

Las políticas de URL no caben en 64 bits (los dominios son ilimitados). Se representan como una estructura separada pero indexada junto con la BitMask del usuario:

```python
@dataclass
class UserPrivilegeProfile:
    user_sub:          str
    bitmask:           int          # 64 bits — acceso a aplicaciones y acciones
    url_blocklist:     set[str]     # dominios bloqueados (del rol, base)
    url_allowlist_add: set[str]     # dominios extra permitidos (del usuario)
    quota_soft_gb:     float        # cuota suave de disco
    quota_hard_gb:     float        # cuota dura de disco
    session_max_min:   int          # duración máxima de sesión
    cgroup_cpu_pct:    int          # límite CPU%
    cgroup_mem_mb:     int          # límite memoria MB

    @property
    def effective_blocklist(self) -> set[str]:
        """URL bloqueadas efectivas = blocklist del rol - allowlist del usuario"""
        return self.url_blocklist - self.url_allowlist_add
```

### 7.4 La Tabla Principal en PostgreSQL

```sql
-- BitMask de usuario: calculada por RolFramework, cacheada en PostgreSQL y Redis
CREATE TABLE apibitmask_user_profile (
    user_sub              TEXT PRIMARY KEY,
    empresa_id            TEXT NOT NULL,
    rol_id                TEXT NOT NULL,

    -- El privilegio central
    bitmask               BIGINT NOT NULL DEFAULT 0,

    -- Composición de los tres niveles (trazabilidad)
    empresa_bitmask       BIGINT NOT NULL DEFAULT 0,
    rol_bitmask           BIGINT NOT NULL DEFAULT 0,
    user_extra_bitmask    BIGINT NOT NULL DEFAULT 0,

    -- Políticas de URL (extensión de la BitMask)
    url_blocklist         TEXT[] DEFAULT '{}',
    url_allowlist_add     TEXT[] DEFAULT '{}',

    -- Recursos del sistema
    quota_soft_gb         NUMERIC(10,2) DEFAULT 5.0,
    quota_hard_gb         NUMERIC(10,2) DEFAULT 6.0,
    session_max_minutes   INTEGER DEFAULT 480,
    cgroup_cpu_pct        INTEGER DEFAULT 100,
    cgroup_mem_mb         INTEGER DEFAULT 2048,

    -- Acciones BOS extra (sobre las del rol)
    bos_actions_extra     JSONB DEFAULT '[]'::jsonb,

    -- Metadatos
    calculated_at         TIMESTAMPTZ DEFAULT NOW(),
    calculated_by         TEXT,        -- 'RolFramework' o admin que hizo override
    notes                 TEXT
);

-- Índice para invalidación rápida por empresa
CREATE INDEX idx_abm_empresa ON apibitmask_user_profile(empresa_id);
-- Índice para invalidación masiva por rol
CREATE INDEX idx_abm_rol ON apibitmask_user_profile(rol_id);
```

---

## 8. Las Fichas rights — Unidades de Extensión del bAuth

### 8.1 El Concepto

El bAuth es un daemon soberano con un núcleo estable y capacidades extensibles. Las **fichas rights** son el mecanismo de extensión: unidades declarativas autocontenidas que amplían el comportamiento del bAuth sin modificar su núcleo.

Esta es la misma filosofía que las cajas de biedata y las rutas de bCompass. El motor no sabe qué fichas rights existen — las descubre, las carga, y las ejecuta.

```
biedata:    Motor binario + fichas cajas    → cada caja = proceso de integración
bCompass:    Motor binario + fichas rutas    → cada ruta = proceso de inteligencia
bAuth:  Motor binario + fichas rights   → cada right = capacidad de autorización
```

### 8.2 Estructura de una Ficha rights

```
/etc/apibitmask/rights/
└── horario_laboral/               ← FICHA rights
    ├── manifest.yml               ← identidad y contrato
    ├── rights_engine.yml          ← lógica declarativa
    ├── rights_catalog.so          ← lógica compilada (Python → .so via Cython)
    └── resources/
        └── schedules.yml          ← horarios configurados
```

### 8.3 El Contrato de Identidad: manifest.yml

```yaml
# /etc/apibitmask/rights/horario_laboral/manifest.yml
name: "horario_laboral"
version: "1.0.0"
description: "Restringe acceso a aplicaciones según horario laboral del rol"

# Cuándo se activa esta ficha
triggers:
  - on_permission_check          # cada vez que se evalúa un privilegio
  - on_session_start             # al inicio de sesión

# Bits de la BitMask que esta ficha puede modificar
managed_bits:
  - firefox                      # puede denegar acceso a Firefox fuera de horario
  - all_non_critical             # puede denegar todo lo no crítico

# Dependencias
requires:
  - tryton_api                   # necesita consultar horarios en Tryton

# Política de fallo
on_error: "allow"                # si la ficha falla, no bloquea (fail-open)
# on_error: "deny"               # alternativa: si falla, deniega (fail-closed)
```

### 8.4 El Contrato Temporal: rights_engine.yml

```yaml
# /etc/apibitmask/rights/horario_laboral/rights_engine.yml
steps:
  - name: "obtener_horario_del_rol"
    task: "get_rol_schedule"
    params:
      source: "tryton"
      cache_ttl: 3600             # cachear horario 1 hora (cambia poco)
    output: "schedule"

  - name: "evaluar_horario_actual"
    task: "check_schedule_active"
    params:
      schedule: "{{ schedule }}"
      timezone: "{{ user.timezone }}"
    output: "within_schedule"

  - name: "aplicar_restriccion"
    task: "modify_permission_result"
    params:
      condition: "{{ not within_schedule }}"
      action: "deny_non_critical_bits"
      message: "Acceso disponible en horario laboral: {{ schedule.human_readable }}"
```

### 8.5 Catálogo Base de Fichas rights

| Ficha rights | Función | Cuándo se usa |
|---|---|---|
| `horario_laboral` | Restringe apps según horario del rol | Control de jornada laboral |
| `limite_uso_tiempo` | Limita uso de apps a X minutos por día | Apps de entretenimiento con límite |
| `geolocalizacion` | Restringe acceso según red/IP de origen | Seguridad de ubicación |
| `auditoria_reforzada` | Logging ampliado para usuarios bajo investigación | Compliance, auditoría RRHH |
| `contingencia_offline` | Políticas cuando el servidor no es alcanzable | Alta disponibilidad |
| `bloqueo_temporal` | Deniega todo acceso temporalmente (ej: usuario suspendido) | Suspensión inmediata |
| `rendimiento_adaptativo` | Ajusta cuotas de recursos según carga del servidor | Gestión de recursos en picos |
| `doble_factor_accion` | Requiere confirmación 2FA para acciones críticas | Operaciones financieras altas |

### 8.6 La Rights API — Contrato entre el Motor y las Fichas

```python
class RightsModule(ABC):
    """
    Interfaz que toda ficha rights debe implementar.
    El motor bAuth la carga via dlopen y la invoca en cada evaluación.
    """

    @property
    @abstractmethod
    def name(self) -> str: ...

    @property
    @abstractmethod
    def triggers(self) -> list[str]: ...

    @abstractmethod
    async def evaluate(
        self,
        current_result: bool,      # resultado de evaluación BitMask base
        user_sub: str,             # identificador del usuario
        action: str,               # acción solicitada
        context: dict,             # contexto: IP, horario, dispositivo, etc.
        bitmask: int               # BitMask actual del usuario
    ) -> bool:
        """
        Puede modificar el resultado de la evaluación.
        Recibe el resultado actual y puede devolverlo igual, cambiarlo a True, o a False.
        El motor apila todas las fichas en secuencia — el resultado final es el de la última.
        """
        ...

    @abstractmethod
    async def on_session_start(self, user_sub: str, session_context: dict) -> None:
        """Llamado cuando el usuario inicia sesión. Puede aplicar configuraciones iniciales."""
        ...
```

---

## 9. El Wrapper sbos-vdi-run — Punto Único de Control de Ejecución

### 9.1 Responsabilidades

El wrapper `sbos-vdi-run` es el **único punto de entrada para todas las aplicaciones en el escritorio**. Reemplaza los accesos directos `.desktop` del sistema por versiones que pasan por el bAuth Client antes de ejecutar.

El usuario hace clic en LibreOffice Writer → en realidad ejecuta `sbos-vdi-run libreoffice-writer` → sbos-vdi-run consulta al daemon local → el daemon consulta al Host → respuesta en < 5ms → LibreOffice arranca o se muestra un mensaje de denegación.

```bash
#!/usr/bin/env bash
# /usr/local/bin/sbos-vdi-run
# Wrapper universal del SBOS VDI — punto único de control de ejecución
# SKULL · SBOS · SBOS-012

set -euo pipefail

ACTION="$1"
shift
ARGS=("$@")

# Consulta al daemon local con timeout estricto
RESPONSE=$(timeout 2 \
    python3 -c "
import asyncio, websockets, json, sys
async def check():
    async with websockets.connect('ws://localhost:8765') as ws:
        await ws.send(json.dumps({'type': 'CHECK', 'action': '$ACTION'}))
        r = json.loads(await ws.recv())
        print(r['allowed'])
        print(r.get('message', ''))
asyncio.run(check())
" 2>/dev/null || echo "false
Error de conexión con el servidor de privilegios")

ALLOWED=$(echo "$RESPONSE" | head -1)
MESSAGE=$(echo "$RESPONSE" | tail -1)

if [ "$ALLOWED" = "True" ]; then
    # Lanzar la aplicación en su propio scope systemd (para cgroups)
    exec systemd-run \
        --user \
        --scope \
        --unit="sbos-vdi-app-${ACTION}-$$" \
        -p "CPUQuota=$(sbos-vdi-get-quota cpu $ACTION)%" \
        -p "MemoryMax=$(sbos-vdi-get-quota mem $ACTION)M" \
        /usr/bin/"$ACTION" "${ARGS[@]}"
else
    if [ "$ALLOWED" = "False" ]; then
        zenity --error \
            --title="SBOS VDI — Acceso Denegado" \
            --text="🚫 <b>No tienes permiso para ejecutar: $ACTION</b>\n\n$MESSAGE" \
            --width=400
    else
        # Sin conexión — política por defecto: denegar
        zenity --warning \
            --title="SBOS VDI — Servidor No Disponible" \
            --text="⚠️ <b>Servidor de privilegios no disponible</b>\n\nAcceso denegado por política de seguridad.\nEl sistema intentará reconectar automáticamente." \
            --width=400
    fi
    exit 1
fi
```

### 9.2 Instalación de Wrappers — Reemplazo de .desktop

```bash
#!/usr/bin/env bash
# /usr/local/bin/sbos-vdi-install-wrappers
# Ejecutado en el primer login del usuario
# Reemplaza TODOS los .desktop del sistema con versiones controladas por sbos-vdi-run

set -euo pipefail

SYSTEM_APPS="/usr/share/applications"
USER_APPS="$HOME/.local/share/applications"
mkdir -p "$USER_APPS"

while IFS= read -r desktop_file; do
    app_name=$(basename "$desktop_file" .desktop)

    # Solo reemplazar apps con Exec real (no accesos directos internos)
    if ! grep -q "^Exec=" "$desktop_file"; then
        continue
    fi

    # Generar .desktop controlado
    {
        echo "[Desktop Entry]"
        grep -E "^(Name|Icon|Categories|Comment|Keywords|StartupNotify|MimeType)" \
            "$desktop_file" || true
        echo "Type=Application"
        echo "Exec=/usr/local/bin/sbos-vdi-run ${app_name} %U"
        echo "NoDisplay=false"
    } > "$USER_APPS/${app_name}.desktop"

done < <(find "$SYSTEM_APPS" -name "*.desktop" -type f)

echo "✓ Wrappers sbos-vdi-run instalados para $(ls $USER_APPS | wc -l) aplicaciones"
```

### 9.3 Módulo PAM — Captura de Token Keycloak al Login

```bash
#!/usr/bin/env bash
# /usr/local/bin/pam-sbos-vdi-token.sh
# Ejecutado por PAM al inicio de sesión
# Captura el token JWT de Keycloak y lo almacena para el daemon cliente

USER="$PAM_USER"
RUNTIME_DIR="/run/user/$(id -u $USER)"
TOKEN_FILE="$RUNTIME_DIR/apibitmask-token"
USER_FILE="$RUNTIME_DIR/apibitmask-user"

mkdir -p "$RUNTIME_DIR"

# Extraer token del entorno PAM (inyectado por pam_keycloak o pam_oauth2)
TOKEN="${PAM_KEYCLOAK_TOKEN:-}"

if [ -n "$TOKEN" ]; then
    echo "$TOKEN" > "$TOKEN_FILE"
    echo "$USER"  > "$USER_FILE"
    chown "$USER:$USER" "$TOKEN_FILE" "$USER_FILE"
    chmod 600 "$TOKEN_FILE"
    logger "bAuth: token almacenado para usuario $USER"
else
    logger "bAuth: WARNING — no se encontró token Keycloak para $USER"
fi

exit 0
```

```
# /etc/pam.d/common-session — agregar al final
session optional pam_exec.so /usr/local/bin/pam-sbos-vdi-token.sh
```

---

## 10. Control de Red Soberano — Reemplazo de HashiCorp Boundary

### 10.1 Por Qué No HashiCorp Boundary

HashiCorp Boundary usa **Business Source License (BSL)**. Esta licencia no es software libre: permite uso pero restringe competencia comercial y puede cambiar de términos. El SBOS no puede depender de un componente que viola el Principio 8 de soberanía total.

La buena noticia: la funcionalidad que Boundary provee para el caso de SBOS VDI — control de red por proceso — existe en el kernel Linux desde hace décadas, con licencia GPL.

### 10.2 Capa 1: iptables con Módulo owner (Kernel Linux nativo)

El módulo `ipt_owner` de iptables permite hacer match de paquetes salientes basado en el UID del proceso que los genera. Aplicado a procesos lanzados por sbos-vdi-run dentro de su scope systemd, este mecanismo permite control granular sin ningún software adicional.

```bash
#!/usr/bin/env bash
# /usr/local/bin/sbos-vdi-apply-network-policy
# Llamado por bAuth Client al recibir nueva política de usuario

set -euo pipefail

USER_UID=$(id -u)
POLICY_FILE="/run/user/${USER_UID}/apibitmask-url-policy.json"

# Limpiar reglas anteriores para este usuario
iptables -D OUTPUT -m owner --uid-owner "$USER_UID" -j sbos-vdi-"$USER_UID" 2>/dev/null || true
iptables -F sbos-vdi-"$USER_UID" 2>/dev/null || true
iptables -X sbos-vdi-"$USER_UID" 2>/dev/null || true

# Crear cadena de usuario
iptables -N sbos-vdi-"$USER_UID"
iptables -I OUTPUT -m owner --uid-owner "$USER_UID" -j sbos-vdi-"$USER_UID"

# Aplicar dominios bloqueados desde política del usuario
if [ -f "$POLICY_FILE" ]; then
    python3 -c "
import json, subprocess, sys
with open('$POLICY_FILE') as f:
    policy = json.load(f)
for domain in policy.get('url_blocklist', []):
    result = subprocess.run(
        ['dig', '+short', domain],
        capture_output=True, text=True
    )
    for ip in result.stdout.strip().split():
        if ip:
            subprocess.run([
                'iptables', '-A', 'sbos-vdi-$USER_UID',
                '-d', ip, '-j', 'REJECT',
                '--reject-with', 'icmp-host-prohibited'
            ])
print(f'Política de red aplicada: {len(policy.get(\"url_blocklist\", []))} dominios bloqueados')
"
fi

# Todo lo demás: al proxy Squid para filtrado dinámico
iptables -A sbos-vdi-"$USER_UID" -p tcp --dport 80  -j REDIRECT --to-port 3128
iptables -A sbos-vdi-"$USER_UID" -p tcp --dport 443 -j REDIRECT --to-port 3128
```

### 10.3 Capa 2: Squid con External ACL Helper (GPL)

Squid actúa como proxy transparente para todo el tráfico HTTP/HTTPS. El External ACL Helper es un proceso Python que consulta al bAuth Host por cada solicitud de URL.

```
# /etc/squid/squid.conf — configuración para SBOS VDI

# Identificar usuario por IP de origen (cada Fedora tiene IP única en LAN)
acl localnet src 192.168.0.0/16

# External ACL Helper — consulta al bAuth Host
external_acl_type apibitmask_check \
    ttl=30 \
    negative_ttl=5 \
    %LOGIN %DST \
    /usr/local/bin/squid-apibitmask-helper

# Regla de control
acl url_allowed external apibitmask_check
http_access deny !url_allowed
http_access allow localnet
http_access deny all

# Logging para auditoría
access_log /var/log/squid/access.log squid
```

```python
#!/usr/bin/env python3
# /usr/local/bin/squid-apibitmask-helper
# External ACL Helper para Squid
# Lee de stdin: "user_sub dst_domain", responde "OK" o "ERR"

import sys
import asyncio
import websockets
import json

APIBITMASK_HOST = "ws://localhost:8001/squid-acl"

async def check_url(user_sub: str, dst_domain: str) -> bool:
    """Consulta al bAuth Host si user_sub puede acceder a dst_domain"""
    async with websockets.connect(APIBITMASK_HOST) as ws:
        await ws.send(json.dumps({
            "type": "URL_CHECK",
            "user_sub": user_sub,
            "domain": dst_domain
        }))
        response = json.loads(await ws.recv())
        return response["allowed"]

def main():
    sys.stdout.write("OK\n")  # señal de inicio al Squid
    sys.stdout.flush()

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        parts = line.split()
        if len(parts) < 2:
            sys.stdout.write("ERR\n")
            sys.stdout.flush()
            continue

        user_sub, dst_domain = parts[0], parts[1]

        try:
            allowed = asyncio.run(check_url(user_sub, dst_domain))
            sys.stdout.write("OK\n" if allowed else "ERR\n")
        except Exception:
            # En caso de error de conexión: fail-open (permitir)
            sys.stdout.write("OK\n")

        sys.stdout.flush()

if __name__ == "__main__":
    main()
```

### 10.4 Flujo Completo de Filtrado de URL

```
1. Usuario hace clic en un enlace en Firefox
   ↓
2. sbos-vdi-run ya verificó que firefox está en su BitMask → Firefox está corriendo
   ↓
3. Firefox intenta conectar a youtube.com:443
   ↓
4. iptables OUTPUT chain intercepta (--uid-owner del scope systemd de Firefox)
   ↓
   4a. Si youtube.com está en la lista negra IP local → REJECT inmediato (< 1ms)
   ↓
   4b. Si no está en lista local → redirige al proxy Squid (puerto 3128)
   ↓
5. Squid recibe la solicitud → consulta External ACL Helper
   ↓
6. Helper consulta bAuth Host: "¿puede juan.perez acceder a youtube.com?"
   ↓
7. bAuth Host consulta Redis (caché TTL 30 seg para URLs)
   Si cache miss → consulta UserPrivilegeProfile.effective_blocklist
   ↓
8. Respuesta: OK (youtube está en su allowlist_add) → Squid permite
   O: ERR (youtube está bloqueado) → Squid devuelve página de denegación SKULL
   ↓
9. Toda acción registrada en auditoría PostgreSQL
```

---

## 11. Tryton como Motor de Privilegios — Los 5 Niveles Nativos

### 11.1 Los 5 Niveles de Acceso de Tryton

Tryton no es solo un ERP de contabilidad — es el motor de autorización más granular del SBOS. Sus 5 niveles nativos de control de acceso son exactamente lo que el SBOS VDI necesita:

| Nivel | Nombre | Qué controla | Uso en SBOS VDI |
|---|---|---|---|
| 1 | Model | CRUD sobre modelos de negocio | Qué datos puede ver/editar el usuario en apps BOS |
| 2 | Actions | Acciones disponibles en menús y botones | Qué acciones BOS aparecen en el escritorio |
| 3 | Field | Campos visibles/editables en formularios | Granularidad de datos dentro de apps |
| 4 | Button | Botones específicos habilitados/deshabilitados | Operaciones críticas por usuario |
| 5 | Record Rule | Qué registros concretos puede ver/editar | Qué facturas, empleados, inventario ve cada usuario |

### 11.2 El Módulo sbos-vdi_privileges de Tryton

SKULL desarrolla un módulo Tryton propio que extiende el sistema de acceso para gestionar los privilegios del escritorio:

```python
# trytond_sbos-vdi_privileges/model.py
# Módulo Tryton: gestión de privilegios del escritorio SBOS VDI

from trytond.model import ModelSQL, ModelView, fields
from trytond.pool import Pool

class SkVDIDesktopPolicy(ModelSQL, ModelView):
    """Política de escritorio por Rol — gestionada en Tryton"""
    __name__ = 'sbos-vdi.desktop.policy'

    rol_template_id = fields.Many2One('res.group', 'Rol', required=True)

    native_apps = fields.MultiSelection([
        ('firefox', 'Firefox'),
        ('libreoffice-writer', 'LibreOffice Writer'),
        ('libreoffice-calc', 'LibreOffice Calc'),
        ('libreoffice-impress', 'LibreOffice Impress'),
        ('thunderbird', 'Thunderbird'),
        ('element-desktop', 'Element (Mensajería)'),
        ('vscodium', 'VSCodium'),
        ('okular', 'Okular'),
    ], 'Aplicaciones del Rol')

    url_blocklist = fields.Text('Dominios Bloqueados (uno por línea)')
    url_allowlist = fields.Text('Dominios Siempre Permitidos (uno por línea)')

    quota_soft_gb = fields.Numeric('Cuota Suave Disco (GB)', digits=(10, 2))
    quota_hard_gb = fields.Numeric('Cuota Dura Disco (GB)', digits=(10, 2))
    session_max_minutes = fields.Integer('Duración Máxima de Sesión (min)')
    cgroup_cpu_pct = fields.Integer('Límite CPU (%)')
    cgroup_mem_mb = fields.Integer('Límite Memoria (MB)')

    bos_actions = fields.Text('Acciones BOS disponibles para el rol (JSON)')

class SkVDIUserOverride(ModelSQL, ModelView):
    """Override de política de escritorio por Usuario — administrado en Core UI"""
    __name__ = 'sbos-vdi.user.override'

    user_sub = fields.Char('JWT Subject (Keycloak)', required=True)
    empresa_id = fields.Char('Empresa ID', required=True)

    native_apps_add = fields.MultiSelection(
        [(a, a) for a in [
            'firefox', 'libreoffice-writer', 'libreoffice-calc',
            'libreoffice-impress', 'thunderbird', 'element-desktop',
            'vscodium', 'okular'
        ]],
        'Apps Adicionales (sobre el Rol)'
    )

    url_allowlist_add = fields.Text('Dominios Extra Permitidos (uno por línea)')
    url_blocklist_add = fields.Text('Dominios Extra Bloqueados (uno por línea)')
    bos_actions_extra = fields.Text('Acciones BOS Extra (JSON)')

    session_max_minutes_override = fields.Integer(
        'Override Duración Sesión (min)',
        help='Vacío = usar el del Rol'
    )

    notes = fields.Text('Razón del Override (obligatorio)')
    updated_by = fields.Char('Modificado por (admin)')
```

---

## 12. RolFramework como Coordinador Keycloak ↔ Tryton

### 12.1 El Problema que Resuelve

Keycloak sabe quién es el usuario y a qué grupos pertenece. Tryton sabe qué puede hacer ese usuario. El **RolFramework** es el coordinador que traduce los grupos de Keycloak en BitMasks de Tryton y las sincroniza en la tabla `apibitmask_user_profile`.

```
Usuario se autentica en Keycloak
    ↓
JWT contiene: realm_roles = ['CAJERO', 'ACME-EMPLEADOS']
    ↓
RolFramework::on_login(user_sub, realm_roles):
    1. Obtiene RolTemplate de CAJERO desde Tryton
    2. Calcula empresa_bitmask (base de todos los empleados ACME)
    3. Calcula rol_bitmask (bits adicionales del rol CAJERO)
    4. Lee SkVDIUserOverride para este user_sub desde Tryton
    5. Calcula user_extra_bitmask (bits adicionales del usuario)
    6. bitmask_efectiva = empresa_bitmask | rol_bitmask | user_extra_bitmask
    7. Compone UserPrivilegeProfile completo (URLs, cuotas, cgroups)
    8. INSERT/UPDATE en apibitmask_user_profile
    9. Invalida caché Redis del usuario
    ↓
bAuth Host ya tiene la BitMask actualizada
```

### 12.2 Propagación de Cambios en Tiempo Real

Cuando el administrador modifica los privilegios de un usuario en Core UI → Tryton → el bKernel detecta el cambio via WAL → llama al RolFramework → recalcula la BitMask → invalida Redis → notifica al cliente activo del usuario:

```
Admin modifica override de Juan en Core UI
    ↓ (< 1 segundo)
Tryton escribe en sbos-vdi.user.override
    ↓ (WAL event, < 100ms)
bKernel detecta cambio en tabla sbos-vdi.user.override
    ↓ (< 500ms)
bKernel llama RolFramework.recalculate_user(user_sub='uuid-juan')
    ↓ (< 500ms)
RolFramework recalcula BitMask y actualiza apibitmask_user_profile
    ↓ (< 200ms)
RolFramework llama bAuth.invalidate_user_cache(user_sub)
    ↓ (< 100ms)
bAuth invalida Redis + notifica WebSocket al cliente de Juan
    ↓ (< 2 segundos total desde click del admin)
Fedora de Juan recibe PRIVILEGE_UPDATE
    ↓
bAuth Client actualiza iptables + regenera .desktop entries
    ↓
Juan ve el cambio en su escritorio sin reiniciar sesión
```

---

## 13. El Sistema de Políticas en Cascada

### 13.1 Los Tres Niveles

```
╔══════════════════════════════════════════════════════════════════════════╗
║  NIVEL 1 — EMPRESA                                                       ║
║  Aplica a: TODOS los usuarios de la empresa                              ║
║  Define: BitMask base corporativa (apps mínimas, restricciones absolutas)║
║          URLs prohibidas por política empresarial                        ║
║          Config KDE base (tema corporativo, fondo, panel)               ║
╠══════════════════════════════════════════════════════════════════════════╣
║  NIVEL 2 — ROL                                                           ║
║  Aplica a: todos los usuarios del mismo rol                              ║
║  Define: bits adicionales del rol (apps del rol, acciones BOS del rol)  ║
║          URLs extra bloqueadas/permitidas del rol                        ║
║          Recursos del sistema (CPU, memoria, cuota disco)               ║
║  Opera: empresa_bitmask | rol_bitmask                                   ║
╠══════════════════════════════════════════════════════════════════════════╣
║  NIVEL 3 — USUARIO                                                       ║
║  Aplica a: un usuario específico                                         ║
║  Define: bits adicionales personales (apps extra, acciones extra)       ║
║          URLs extra permitidas (premios, necesidades personales)         ║
║          Overrides de recursos (turno extendido, más memoria)           ║
║  Opera: (empresa_bitmask | rol_bitmask | user_extra_bitmask)            ║
║  Prioridad: MÁXIMA — siempre gana                                        ║
╚══════════════════════════════════════════════════════════════════════════╝
```

### 13.2 Ejemplo Concreto: Los 5 Cajeros de ACME

```
ROL: Cajero — BitMask base del rol (aplica a los 5)
  bitmask_bits:     [okular, bos_apertura, bos_cierre, bos_arqueo]
  url_blocklist:    [youtube.com, facebook.com, twitter.com, instagram.com,
                     web.whatsapp.com, tiktok.com]
  quota_gb:         5 soft / 6 hard
  session_max:      360 min (6 horas)
  cgroup_cpu:       80%

  ┌─────────────────┬────────────────────────────────────────────────────────┐
  │ María García    │ + writer │ + youtube.com (permitido)                   │
  │ Juan Pérez      │          │ + web.whatsapp.com + instagram.com          │
  │ Carmen López    │ + calc   │ + bos_action_reporte_diario                 │
  │ Roberto Díaz   │          │ (sin overrides — exactamente el rol base)    │
  │ Ana Soto        │ + writer │ + youtube.com + web.whatsapp.com            │
  │                 │ + calc   │ + session_max: 480 min (turno extendido)    │
  └─────────────────┴────────────────────────────────────────────────────────┘

Lo que cada cajero ve en su escritorio:
                     María  Juan   Carmen Roberto  Ana
Writer                 ✓     ✗      ✗      ✗       ✓
Calc                   ✗     ✗      ✓      ✗       ✓
YouTube                ✓     ✗      ✗      ✗       ✓
WhatsApp Web           ✗     ✓      ✗      ✗       ✓
Instagram              ✗     ✓      ✗      ✗       ✗
Acción Reporte Diario  ✗     ✗      ✓      ✗       ✗
Sesión 8h              ✗     ✗      ✗      ✗       ✓
Sesión 6h (base rol)   ✓     ✓      ✓      ✓       ✗
```

---

## 14. Modos de Operación del Escritorio

### 14.1 Modo USB Booteable — Escritorio Local SKULL

El USB contiene un Fedora 43 KDE Plasma instalado y configurado por SKULL. Es una distribución propia — no un Fedora genérico. Arranca en cualquier PC sin instalación. Al bootear, el único sistema que existe en esa máquina es el de SKULL.

```
Estructura del USB SKULL:
├── Fedora 43 KDE Plasma (instalación completa)
├── Apps preinstaladas (LibreOffice, Firefox, Thunderbird, etc. — todas desactivadas)
├── bAuth Client (systemd --user, preconfigurado)
├── sbos-vdi-run wrapper (reemplaza todos los .desktop al primer login)
├── PAM sbos-vdi (captura token Keycloak al login)
├── Configuración de proxy (apunta a Squid en servidor SKULL)
└── NO contiene datos del usuario — todo está en el servidor
```

```
Flujo de arranque USB:
1.  PC arranca desde USB SKULL
2.  GDM/SDDM muestra pantalla de login corporativa (branding ACME)
3.  Usuario ingresa credenciales
4.  PAM autentica contra Keycloak (OIDC/Kerberos)
5.  PAM script captura token JWT → /run/user/UID/apibitmask-token
6.  systemd --user arranca bAuth Client
7.  Client conecta al Host via WSS (servidor SKULL en LAN/internet)
8.  Host valida JWT → obtiene BitMask del usuario
9.  Client recibe UserPrivilegeProfile completo
10. Client aplica reglas iptables locales (URL blocklist)
11. Client monta home NFS del usuario
12. Client instala wrappers sbos-vdi-run para las apps de la BitMask
13. KDE Plasma arranca → muestra solo las apps autorizadas
14. Usuario ve su escritorio personalizado en < 30 segundos
```

### 14.2 Modo Contenedor Web — Acceso Remoto

Para usuarios remotos sin USB SKULL, el escritorio corre en un contenedor Docker/Podman en el servidor Ubuntu, accesible desde cualquier navegador.

```
[Navegador del usuario] → HTTPS
    ↓
[Traefik] → [OAuth2-Proxy] → [Keycloak: login + MFA]
    ↓ JWT
[Contenedor Fedora SKULL] (corre en servidor Ubuntu)
    ↓
[bAuth Client dentro del contenedor]
    ↓
[WebSocket → bAuth Host] (mismo servidor, latencia mínima)
    ↓
Escritorio via xrdp/noVNC en el navegador
```

#### Dockerfile de la imagen Fedora SKULL (Modo Contenedor Web)

```dockerfile
# Dockerfile — Imagen Fedora SKULL para SBOS VDI contenedor web
# SKULL · SBOS · SBOS-012
# Base: Fedora 43 — escritorio soberano del SBOS

FROM fedora:43

# ─── Capa 1: Escritorio KDE Plasma y herramientas de acceso remoto ───
RUN dnf install -y \
    @kde-desktop-environment \
    xrdp \
    novnc \
    websockify \
    tigervnc-server \
    && dnf clean all

# ─── Capa 2: Aplicaciones corporativas (preinstaladas, desactivadas por defecto) ───
RUN dnf install -y \
    libreoffice-writer \
    libreoffice-calc \
    libreoffice-impress \
    libreoffice-draw \
    firefox \
    thunderbird \
    element-desktop \
    vscodium \
    okular \
    && dnf clean all

# ─── Capa 3: Herramientas de red para control de red soberano ───
RUN dnf install -y \
    iptables \
    nftables \
    squid \
    bind-utils \
    && dnf clean all

# ─── Capa 4: Herramientas de sistema para cgroups y NFS ───
RUN dnf install -y \
    nfs-utils \
    quota \
    systemd \
    polkit \
    libnotify \
    zenity \
    && dnf clean all

# ─── Capa 5: PAM — integración con Keycloak ───
RUN dnf install -y \
    pam \
    pam-devel \
    python3 \
    python3-websockets \
    python3-jwt \
    && dnf clean all

# ─── Capa 6: Desactivar TODAS las entradas .desktop del sistema ───
# Las apps son visibles solo según la BitMask del usuario
# sbos-vdi-install-wrappers las activa en el primer login
RUN find /usr/share/applications/ -name "*.desktop" \
    -exec sed -i '/^NoDisplay=/d; /^\[Desktop Entry\]/a NoDisplay=true' {} \;

# ─── Capa 7: Herramientas soberanas SBOS ───
COPY resources/apibitmask/apibitmask-client  /usr/local/bin/apibitmask-client
COPY resources/fedora/sbos-vdi-run              /usr/local/bin/sbos-vdi-run
COPY resources/fedora/sbos-vdi-install-wrappers /usr/local/bin/sbos-vdi-install-wrappers
COPY resources/fedora/sbos-vdi-get-quota        /usr/local/bin/sbos-vdi-get-quota
COPY resources/fedora/sbos-vdi-apply-network-policy /usr/local/bin/sbos-vdi-apply-network-policy
COPY resources/fedora/pam-sbos-vdi-token.sh     /usr/local/bin/pam-sbos-vdi-token.sh
COPY resources/apibitmask/apibitmask-client.service \
     /etc/systemd/user/apibitmask-client.service

RUN chmod +x /usr/local/bin/sbos-vdi-* \
             /usr/local/bin/apibitmask-* \
             /usr/local/bin/pam-sbos-vdi-token.sh

# ─── Capa 8: Configuración PAM ───
RUN echo "session optional pam_exec.so /usr/local/bin/pam-sbos-vdi-token.sh" \
    >> /etc/pam.d/common-session

# ─── Capa 9: Configuración xrdp para KDE ───
RUN echo "startplasma-x11" > /etc/skel/.Xsession && \
    chmod +x /etc/skel/.Xsession

# ─── Capa 10: noVNC — acceso desde navegador ───
# noVNC sirve el escritorio VNC como página web en el puerto 6080
RUN mkdir -p /opt/novnc && \
    ln -sf /usr/share/novnc/vnc.html /opt/novnc/index.html

# ─── Puertos expuestos ───
# 3389: RDP (clientes nativos)
# 6080: noVNC (navegadores web)
EXPOSE 3389 6080

# ─── Arranque: systemd gestiona todos los servicios ───
# Incluye: display manager, xrdp, websockify, bAuth Client
CMD ["/usr/sbin/init"]
```

**Notas sobre la imagen:**
- La imagen es inmutable: ningún usuario puede instalar software. `dnf` está deshabilitado post-build.
- Los datos del usuario no viven en el contenedor — se montan desde NFS al inicio de sesión.
- El contenedor es stateless: puede ser destruido y recreado sin pérdida de datos.
- Un nuevo contenedor por usuario o pool de contenedores compartidos — según política de la empresa.

### 14.3 Transparencia Entre Modos

La sesión pertenece al usuario, no al dispositivo. El mismo UserPrivilegeProfile, el mismo home NFS, los mismos datos. El usuario no nota si está en USB o en contenedor web — su escritorio es idéntico.

```
Lunes 9am:  Juan llega a la oficina → bootea USB SKULL → su escritorio
Martes remoto: Juan trabaja desde casa → navegador → mismo escritorio, mismos datos
Miércoles: Juan pierde el USB → usa PC de sala de reuniones → navegador → mismo escritorio
```

---

## 15. Control de Recursos del Sistema

### 15.1 Control de CPU y Memoria (cgroups v2 via systemd)

El wrapper sbos-vdi-run lanza cada aplicación en su propio scope systemd. Los límites de recursos del scope vienen del UserPrivilegeProfile del usuario.

```python
# En bAuth Client — al recibir UserPrivilegeProfile
async def apply_resource_limits(self, profile: UserPrivilegeProfile):
    """Configura límites de recursos para el usuario actual"""

    # Crear slice de usuario con límites globales
    subprocess.run([
        'systemctl', '--user', 'set-property',
        f'user-{self.uid}.slice',
        f'CPUQuota={profile.cgroup_cpu_pct}%',
        f'MemoryMax={profile.cgroup_mem_mb}M',
        f'MemorySwapMax=0'  # Sin swap por seguridad
    ], check=True)
```

```bash
# sbos-vdi-run lanza cada app en su scope con límites por app
systemd-run \
    --user \
    --scope \
    --unit="sbos-vdi-app-${ACTION}-$$" \
    --slice="user-${UID}-sbos-vdi.slice" \
    -p "CPUQuota=${APP_CPU_QUOTA}%" \
    -p "MemoryMax=${APP_MEM_LIMIT}M" \
    /usr/bin/"$ACTION" "${ARGS[@]}"
```

### 15.2 Control de Prioridad de Procesos

```bash
# El UserPrivilegeProfile incluye prioridad nice por rol
if [ "$ROL" = "contador" ]; then
    NICE_VALUE=5    # menor prioridad que el sistema
elif [ "$ROL" = "desarrollador" ]; then
    NICE_VALUE=-5   # mayor prioridad (requiere CAP_SYS_NICE)
else
    NICE_VALUE=0    # prioridad normal
fi

exec nice -n "$NICE_VALUE" /usr/bin/"$ACTION" "${ARGS[@]}"
```

### 15.3 Control de Dispositivos (polkit)

```javascript
// /etc/polkit-1/rules.d/50-sbos-vdi.rules
// Consulta al bAuth Client para decisiones de dispositivos

polkit.addRule(function(action, subject) {
    var user = subject.user;

    var result = polkit.spawn([
        '/usr/local/bin/sbos-vdi-polkit-check',
        user,
        action.id
    ]);

    return result === "allow"
        ? polkit.Result.YES
        : polkit.Result.AUTH_ADMIN;
});
```

---

## 16. Sistema de Archivos y Almacenamiento NFS

### 16.1 Estructura de Directorios en el Servidor

```
/export/
├── homes/                          ← Homes privados de usuario
│   ├── juan.perez/
│   │   ├── Mi-Espacio/             ← workspace activo de la Posición
│   │   ├── Documentos/             ← documentos personales del usuario
│   │   └── .kde_profile/           ← configuración personal KDE
│   └── maria.garcia/
│
├── positions/                      ← Espacios de trabajo por Posición
│   └── cajero-suc-norte-caja3/
│       ├── workspace/              ← directorio activo
│       └── archives/               ← snapshots inmutables por usuario anterior
│           └── maria.garcia_20260228_143022/
│               ├── workspace/
│               ├── .kde_profile/
│               └── .user_policy.json
│
├── shares/                         ← Carpetas compartidas por Rol
│   └── cajero/
│       └── procedimientos/         ← read-only para todos los cajeros
│
└── empresa/
    └── acme/
        └── general/                ← corporativo read-only para todos
```

### 16.2 Exportación NFS con Seguridad

```bash
# /etc/exports
# Homes privados — solo el usuario
/export/homes/juan.perez    192.168.1.0/24(rw,sync,no_subtree_check,root_squash)
/export/homes/maria.garcia  192.168.1.0/24(rw,sync,no_subtree_check,root_squash)

# Espacio de Posición — usuarios del rol que ocupan la posición
/export/positions/cajero-suc-norte-caja3  192.168.1.0/24(rw,sync,no_subtree_check)

# Compartidos del rol — read-only para el grupo
/export/shares/cajero       192.168.1.0/24(ro,sync,no_subtree_check)

# Corporativo — read-only para todos
/export/empresa/acme/general 192.168.1.0/24(ro,sync,no_subtree_check)
```

### 16.3 Cuotas de Disco con quotactl

```bash
#!/usr/bin/env bash
# /usr/local/bin/sbos-vdi-setquota
# Llamado por bAuth Host al crear/modificar usuario

USER="$1"
SOFT_GB="$2"
HARD_GB="$3"
DEVICE="/dev/sda1"  # Disco donde vive /export

# Aplicar cuota en bloques (1 bloque = 1KB en quota)
SOFT_BLOCKS=$(( SOFT_GB * 1024 * 1024 ))
HARD_BLOCKS=$(( HARD_GB * 1024 * 1024 ))

setquota -u "$USER" \
    "$SOFT_BLOCKS" "$HARD_BLOCKS" \
    0 0 \
    "$DEVICE"

logger "SBOS VDI: Cuota aplicada — $USER: ${SOFT_GB}GB soft / ${HARD_GB}GB hard en $DEVICE"
```

---

## 17. Auditoría Centralizada

### 17.1 Esquema PostgreSQL

```sql
-- Tabla principal de auditoría — cada acción registrada
CREATE TABLE apibitmask_audit (
    id                BIGSERIAL PRIMARY KEY,
    timestamp         TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    -- Identidad
    user_sub          TEXT NOT NULL,
    empresa_id        TEXT NOT NULL,
    rol_id            TEXT NOT NULL,

    -- Acción
    action            TEXT NOT NULL,
    action_type       TEXT NOT NULL,         -- 'app_launch', 'url_access', 'file_access'

    -- Resultado
    allowed           BOOLEAN NOT NULL,
    deny_reason       TEXT,
    rights_module     TEXT,

    -- Contexto
    client_ip         INET,
    client_host       TEXT,
    device_type       TEXT,                  -- 'usb', 'container_web'
    url_accessed      TEXT,

    -- Rendimiento
    response_time_ms  INTEGER,
    bitmask_value     BIGINT,

    -- Detalles adicionales
    details           JSONB DEFAULT '{}'::jsonb
);

-- Índices para reporting
CREATE INDEX idx_audit_user_time      ON apibitmask_audit(user_sub, timestamp DESC);
CREATE INDEX idx_audit_empresa_time   ON apibitmask_audit(empresa_id, timestamp DESC);
CREATE INDEX idx_audit_action_allowed ON apibitmask_audit(action, allowed);
CREATE INDEX idx_audit_timestamp      ON apibitmask_audit(timestamp DESC);

-- Particionamiento por mes para retención eficiente
CREATE TABLE apibitmask_audit_2026_03
    PARTITION OF apibitmask_audit
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
```

### 17.2 Reportes de Auditoría

```sql
-- Reporte de actividad de usuario — últimas 24 horas
SELECT
    date_trunc('hour', timestamp)  AS hora,
    action,
    count(*)                       AS intentos,
    sum(CASE WHEN allowed THEN 1 ELSE 0 END) AS permitidos,
    sum(CASE WHEN NOT allowed THEN 1 ELSE 0 END) AS denegados,
    avg(response_time_ms)          AS latencia_prom_ms
FROM apibitmask_audit
WHERE user_sub = $1
  AND timestamp > NOW() - INTERVAL '24 hours'
GROUP BY hora, action
ORDER BY hora DESC, intentos DESC;

-- Reporte de intentos denegados por empresa — mes actual
SELECT
    u.user_sub,
    u.rol_id,
    a.action,
    count(*) AS denegaciones,
    max(a.timestamp) AS ultima_vez,
    string_agg(DISTINCT a.deny_reason, ', ') AS razones
FROM apibitmask_audit a
JOIN apibitmask_user_profile u ON a.user_sub = u.user_sub
WHERE a.empresa_id = $1
  AND a.allowed = FALSE
  AND a.timestamp >= date_trunc('month', NOW())
GROUP BY u.user_sub, u.rol_id, a.action
ORDER BY denegaciones DESC
LIMIT 50;
```

---

## 18. Modelo de Seguridad: 6 Capas

```
╔══════════════════════════════════════════════════════════════════════════╗
║  CAPA 1: AUTENTICACIÓN                                                   ║
║  Keycloak — OIDC + JWT + MFA opcional                                   ║
║  Sin token válido = sin sesión, punto                                    ║
╠══════════════════════════════════════════════════════════════════════════╣
║  CAPA 2: AUTORIZACIÓN                                                    ║
║  Tryton (5 niveles) + bAuth (BitMask Engine)                       ║
║  Sin BitMask positiva = sin ejecución, punto                            ║
╠══════════════════════════════════════════════════════════════════════════╣
║  CAPA 3: CONTROL DE EJECUCIÓN                                            ║
║  sbos-vdi-run wrapper — intercepta TODA ejecución de aplicaciones           ║
║  Ninguna app arranca sin pasar por bAuth                           ║
╠══════════════════════════════════════════════════════════════════════════╣
║  CAPA 4: CONTROL DE RED                                                  ║
║  iptables owner → bloqueo local por IP                                  ║
║  Squid + External ACL Helper → filtrado dinámico por URL por usuario    ║
╠══════════════════════════════════════════════════════════════════════════╣
║  CAPA 5: CONTROL DE ARCHIVOS                                             ║
║  NFSv4 con permisos granulares + quotactl                               ║
║  Cada usuario accede solo a sus directorios autorizados                 ║
╠══════════════════════════════════════════════════════════════════════════╣
║  CAPA 6: AUDITORÍA COMPLETA                                              ║
║  PostgreSQL — cada acción registrada con timestamp, usuario, resultado  ║
║  Sin conexión al Host = sin acceso (política por defecto: denegar todo) ║
╚══════════════════════════════════════════════════════════════════════════╝
```

### 18.1 Política de Contingencia sin Conexión

```yaml
# /etc/apibitmask/client.yml
offline_policy:
  default_action: "deny_all"

  offline_allowed_apps:
    - "okular"                  # visor de documentos offline OK
    - "libreoffice-writer"      # edición offline permitida (sin acceso red)

  connection_timeout_seconds: 5

  notify_user: true
  notify_message: "Servidor de privilegios no disponible. Acceso restringido."

  reconnect_backoff_seconds: [5, 10, 20, 40, 80, 120]
```

---

## 19. Ciclo de Vida del Usuario

### 19.1 Activación (Onboarding)

```
Admin → Core UI → Nuevo Usuario
    ↓
1. Keycloak: crear cuenta + asignar realm_roles
2. Tryton: crear sbos-vdi.user.override (puede estar vacío — hereda solo el rol)
3. bKernel detecta → RolFramework calcula BitMask inicial
4. bAuth: INSERT apibitmask_user_profile
5. NFS: mkdir /export/homes/{username} + aplicar cuota
6. NFS: montar Posición asignada
7. Usuario puede hacer login en < 60 segundos desde activación
```

### 19.2 Operación Diaria

Cada login recalcula el UserPrivilegeProfile. Los cambios de privilegios en Tryton se propagan en < 3 segundos a sesiones activas via bKernel → bAuth → WebSocket.

### 19.3 Suspensión Temporal

```
Admin → Core UI → Usuario → Suspender
    ↓
1. Keycloak: desactivar cuenta (todos los tokens existentes se invalidan)
2. bAuth: bitmask = 0 (ningún privilegio)
3. Sesión activa: bAuth Client recibe PRIVILEGE_UPDATE → bitmask = 0
4. sbos-vdi-run deniega toda acción → usuario ve notificación
5. NFS: home sigue montado (archivos preservados)
6. Usuario no puede iniciar nueva sesión hasta reactivación
```

### 19.4 Offboarding

```
Admin → Core UI → Usuario → Offboarding
    ↓
1. Keycloak: desactivar cuenta permanentemente
2. bAuth: DELETE apibitmask_user_profile (o archivar)
3. NFS Snapshot:
   /export/positions/{posicion}/archives/{username}_{timestamp}/
       ├── workspace/          ← contenido del espacio de trabajo
       ├── .kde_profile/       ← configuración personal KDE
       └── .user_policy.json   ← snapshot de privilegios personales
4. Auditoría: los logs se conservan (inmutables por política)
5. Home privado: según política de empresa (eliminar / archivar / retener X días)
```

---

## 20. Herencia de Políticas: Posición y Transferencia

### 20.1 El Principio

Las políticas personales de un usuario (sus overrides en Tryton) son parte de su contribución a la Posición. Al hacer offboarding, se archivan junto con el workspace. Al hacer onboarding del nuevo usuario, el admin puede heredar lo que corresponde.

### 20.2 Interfaz de Decisión en Core UI

```
Onboarding: Pedro Pérez → Cajero Sucursal Norte Caja 3
Posición previamente ocupada por: María García

Políticas archivadas de María García:
  ┌──────────────────────────────────────────────────────────────────────┐
  │ App: LibreOffice Writer    [✓ Heredar] [✗ No heredar]                │
  │ Razón original: "Premio Q4 + hace informes mensuales del puesto"     │
  │                                                                      │
  │ URL: youtube.com           [✓ Heredar] [✗ No heredar]                │
  │ Razón original: "Premio por rendimiento Q4 2025"                     │
  └──────────────────────────────────────────────────────────────────────┘

Decisión del admin:
  Writer: [✓] — la posición requiere informes. Pedro los necesitará.
  YouTube: [✗] — era un premio personal. Pedro debe ganárselo.

→ Crear sbos-vdi.user.override para Pedro:
  native_apps_add: ['libreoffice-writer']
  notes: "Heredado de María García (cajero-suc-norte-caja3) — 2026-03-01"
```

---

## 21. Flujos Completos

### Flujo A — Login de Juan (Cajero — USB SKULL)

```
[TIEMPO]  [USB SKULL]               [SERVIDOR]                  [TRYTON]
  0s      PC arranca desde USB
  8s      GDM muestra login
 12s      Juan ingresa creds  →     PAM autentica en Keycloak
 13s                          ←     JWT: realm_role=CAJERO
 13s      PAM guarda token
 14s      systemd arranca bAuth Client
 15s      Client conecta WSS  →     Host valida JWT
 16s                                RolFramework calcula BitMask
 16s                          →     Consulta Tryton: CAJERO + juan.perez overrides
 17s                          ←     DesktopPolicy + UserOverride
 18s                                bitmask = 0b...cajero | juan_extra
 18s                          ←     UserPrivilegeProfile (BitMask + URLs + cuotas)
 19s      Client aplica iptables
 19s      Client monta NFS home
 20s      Client instala wrappers .desktop
 22s      KDE Plasma arranca
 28s      ✓ Escritorio de Juan listo — solo sus apps, sus URLs, su workspace
```

### Flujo B — Juan hace clic en Firefox

```
Juan hace clic en Firefox (lanzador en panel KDE)
    ↓ En realidad ejecuta: /usr/local/bin/sbos-vdi-run firefox
    ↓
sbos-vdi-run consulta al bAuth Client local (socket unix, < 1ms)
    ↓
Client consulta al Host via WebSocket existente (< 3ms)
    ↓
Host: evalúa bitmask de Juan → bit_firefox está activo → allowed=True
Host: registra en auditoría
    ↓ (total: < 5ms desde click)
sbos-vdi-run ejecuta: systemd-run --user --scope -p CPUQuota=80% ... /usr/bin/firefox
    ↓
Firefox arranca en su scope systemd con límites de recursos
Firefox tráfico de red → iptables → Squid → External ACL Helper → bAuth
```

### Flujo C — Juan intenta abrir youtube.com (no permitido)

```
Juan escribe youtube.com en Firefox
    ↓
Firefox hace TCP SYN a youtube.com:443
    ↓
iptables OUTPUT (--uid-owner del scope de Firefox)
    ↓ Si youtube está en lista negra local IP → REJECT inmediato
    ↓ Si no → redirige a Squid (puerto 3128)
    ↓
Squid → External ACL Helper: "juan.perez youtube.com"
    ↓
Helper → bAuth Host: URL_CHECK
    ↓
Host: url_blocklist de CAJERO incluye youtube.com
      url_allowlist_add de Juan no incluye youtube.com
      effective_blocklist incluye youtube.com → denied
    ↓
Helper devuelve: ERR
Squid devuelve: página de denegación corporativa SKULL
Firefox muestra: "Este sitio está bloqueado por política de la empresa"
    ↓
Auditoría registra: user=juan.perez, url=youtube.com, allowed=False, reason="rol_blocklist"
```

### Flujo D — Admin activa YouTube para Juan como premio

```
Admin → Core UI → Juan Pérez → Políticas de Escritorio
    Agregar URL permitida: youtube.com
    Notas: "Premio rendimiento Q1 2026"
    → Guardar
    ↓ (< 1 segundo)
Tryton: UPDATE sbos-vdi.user.override SET url_allowlist_add = ['youtube.com']
    ↓ WAL event (< 100ms)
bKernel detecta cambio → llama RolFramework.recalculate('uuid-juan')
    ↓ (< 500ms)
RolFramework: nueva BitMask + nuevo effective_blocklist (sin youtube.com)
              UPDATE apibitmask_user_profile SET url_allowlist_add = ['youtube.com']
              Redis invalida caché de Juan
    ↓ (< 200ms)
bAuth Host notifica WebSocket al Client de Juan: PRIVILEGE_UPDATE
    ↓ (< 2 segundos total desde el clic del admin)
Client de Juan: actualiza iptables + regenera política de URLs
    ↓
Juan abre youtube.com → ahora funciona
```

### Flujo E — Suspensión de Emergencia en Sesión Activa

```
Incidente de seguridad — Admin necesita bloquear a Juan inmediatamente
Admin → Core UI → Juan → Suspender (acción de emergencia)
    ↓
Keycloak: cuenta desactivada → todos los tokens futuros inválidos
Tryton: sbos-vdi.user.override → bitmask_override = 0
    ↓ (< 500ms via bKernel)
bAuth Host: bitmask de Juan = 0
                 Notifica WebSocket al Client de Juan: PRIVILEGE_UPDATE (bitmask=0)
    ↓ (< 2 segundos)
Client de Juan: sbos-vdi-run deniega toda acción nueva
                Muestra notificación: "Tu sesión ha sido suspendida. Contacta a RRHH."
    ↓
Apps ya abiertas: siguen corriendo (no se matan — sería disruptivo)
Nuevas apps: imposible abrir ninguna
Nuevo login: imposible (Keycloak rechaza)
```

---

## 22. La Ficha SBOS VDI en el IAM Installer

### 22.1 Estructura de la Ficha

```
servers/
└── vdiserver/
    └── sbos-vdi/
        ├── manifest.yml
        ├── yaml_engine.yml
        ├── task_catalog.sh
        └── resources/
            ├── apibitmask/
            │   ├── host.py                  ← daemon host (compilado)
            │   ├── client.py                ← daemon client (compilado)
            │   ├── host.yml                 ← configuración del host
            │   └── client.yml              ← configuración del client
            ├── rights/                      ← fichas rights base
            │   ├── horario_laboral/
            │   ├── limite_uso_tiempo/
            │   └── contingencia_offline/
            ├── fedora/
            │   ├── Dockerfile               ← imagen contenedor web (§14.2)
            │   └── sbos-vdi-run                ← wrapper universal
            ├── squid/
            │   ├── squid.conf
            │   └── squid-apibitmask-helper.py
            ├── nfs/
            │   └── structure.yml            ← estructura de directorios NFS
            ├── tryton/
            │   └── sbos-vdi_privileges/        ← módulo Tryton
            └── sql/
                ├── apibitmask_schema.sql    ← tablas del bAuth
                └── bitmask_catalog.sql      ← catálogo de bits por app
```

### 22.2 manifest.yml

```yaml
# servers/vdiserver/sbos-vdi/manifest.yml
name: "sbos-vdi"
server: "vdiserver"
version: "4.0.0"
description: "SBOS VDI — Sovereign Desktop Infrastructure con bAuth"
criticality: true

dependencies:
  - postgresql          # apibitmask_db
  - redis               # caché de BitMasks
  - keycloak            # autenticación JWT
  - tryton              # motor de privilegios
  - bkernel             # propagación de cambios via WAL

install_order: 11       # después de todas las dependencias

bsearch_config:
  enabled: false        # el SBOS VDI no expone entidades indexables en bSearch

expose:
  - service: "apibitmask-host"
    port: 8000
    protocol: "wss"
    description: "WebSocket de privilegios para clientes Fedora"
  - service: "squid"
    port: 3128
    protocol: "http"
    description: "Proxy de filtrado de URLs"

health_checks:
  - name: "apibitmask_host_alive"
    command: "systemctl is-active apibitmask-host"
    interval: 30s
  - name: "squid_alive"
    command: "squidclient -h localhost mgr:info | grep -q 'Squid'"
    interval: 60s
```

---

## 23. El Protocolo sbos:// — Deep Links Soberanos

### 23.1 Qué es el Protocolo sbos://

El protocolo `sbos://` es el sistema de deep links soberano del SBOS. Permite que cualquier parte del sistema — una notificación, un correo, un widget de bCompass, una alerta de auditoría — lleve al usuario directamente al recurso exacto en el sistema de negocio, sin necesidad de navegar manualmente.

`sbos://` funciona en el escritorio Fedora SKULL como un handler de URI registrado en el sistema. Cuando el bAuth Client recibe o el usuario activa un enlace `sbos://`, el handler lo interpreta, verifica la BitMask del usuario para ese recurso, y si tiene acceso, lo abre directamente.

**El handler verifica los privilegios antes de abrir.** No es posible usar un deep link para acceder a un recurso que la BitMask del usuario no autoriza.

### 23.2 Estructura del URI

```
sbos://[servidor]/[acción]/[parámetros]
         │          │         │
         │          │         └── parámetros de la acción (URL-encoded)
         │          └── tipo de acción (ver lista en §23.3)
         └── servidor lógico del SBOS (ej: erp, crm, vdi, search)
```

**Ejemplos:**

```
sbos://erp/open/invoice?id=INV-2026-00123
sbos://erp/open/form?model=account.invoice&action=new
sbos://erp/search?query=facturas+pendientes+ACME
sbos://vdi/launch/app?app=libreoffice-writer&file=/home/user/informe.odt
sbos://vdi/notify?level=info&message=Tu+turno+ha+comenzado
sbos://search/query?q=pedidos+pendientes&scope=erp
sbos://compass/route?name=analisis_proveedor&param=PROV-001
```

### 23.3 Catálogo de Acciones por Servidor

#### Servidor: `erp`

| Acción | Parámetros | Descripción | Verificación BitMask |
|---|---|---|---|
| `open/invoice` | `id` | Abre una factura por ID | `bos_action_ver_factura` |
| `open/form` | `model`, `action` | Abre formulario de modelo Tryton | Bit del modelo según RolTemplate |
| `open/record` | `model`, `id` | Abre registro específico por ID | Bit del modelo + Record Rule de Tryton |
| `open/report` | `report_id`, `record_id` | Genera y abre un reporte JasperReports | `bos_action_reportes` |
| `search` | `query`, `model` (opt.) | Búsqueda en el ERP | BitMask del modelo buscado |
| `action/execute` | `action_id`, `record_id` | Ejecuta una acción del menú de Tryton | Bit de la acción en RolTemplate |

#### Servidor: `vdi`

| Acción | Parámetros | Descripción | Verificación BitMask |
|---|---|---|---|
| `launch/app` | `app`, `file` (opt.) | Abre aplicación con archivo opcional | Bit de la app en BitMask del usuario |
| `notify` | `level`, `message`, `action` (opt.) | Muestra notificación en el escritorio | — (siempre permitido) |
| `open/file` | `path` | Abre archivo con la app correcta | `download_files` + acceso NFS al path |
| `open/url` | `url` | Abre URL en el navegador | `firefox` + policy URL |
| `session/lock` | — | Bloquea la sesión inmediatamente | — (siempre permitido) |

#### Servidor: `search`

| Acción | Parámetros | Descripción | Verificación BitMask |
|---|---|---|---|
| `query` | `q`, `scope` (opt.) | Ejecuta búsqueda en bSearch | BitMask de las entidades del scope |
| `open/result` | `entity`, `id` | Abre resultado de búsqueda específico | Bit del modelo de la entidad |

#### Servidor: `compass`

| Acción | Parámetros | Descripción | Verificación BitMask |
|---|---|---|---|
| `route` | `name`, `param` (opt.) | Ejecuta una ruta de bCompass | `bos_action_compass_routes` |
| `approval` | `request_id` | Abre solicitud de aprobación pendiente | `bos_action_approvals` |
| `suggest` | `suggestion_id` | Abre sugerencia de bCompass | `bos_action_compass_suggestions` |

### 23.4 Handler del Protocolo — Implementación

```bash
#!/usr/bin/env bash
# /usr/local/bin/sbos-vdi-protocol-handler
# Handler registrado en KDE para URIs sbos://
# Llamado automáticamente por KDE al activar un enlace sbos://

set -euo pipefail

URI="$1"  # ej: sbos://erp/open/invoice?id=INV-2026-00123

# Parsear URI
SERVIDOR=$(echo "$URI" | sed 's|sbos://\([^/]*\)/.*|\1|')
ACCION=$(echo "$URI" | sed 's|sbos://[^/]*/\([^?]*\).*|\1|')
PARAMS=$(echo "$URI" | grep -o '?.*' | sed 's/^?//' || echo "")

# Verificar privilegio para esta acción
RESPONSE=$(python3 -c "
import asyncio, websockets, json
async def check():
    async with websockets.connect('ws://localhost:8765') as ws:
        await ws.send(json.dumps({
            'type': 'CHECK',
            'action': 'sbos_deeplink',
            'context': {
                'servidor': '$SERVIDOR',
                'accion': '$ACCION',
                'params': '$PARAMS'
            }
        }))
        r = json.loads(await ws.recv())
        print(r['allowed'])
asyncio.run(check())
")

if [ "$RESPONSE" = "True" ]; then
    # Despachar al handler del servidor correspondiente
    case "$SERVIDOR" in
        erp)
            python3 /usr/local/bin/sbos-vdi-deeplink-erp.py "$ACCION" "$PARAMS"
            ;;
        vdi)
            python3 /usr/local/bin/sbos-vdi-deeplink-vdi.py "$ACCION" "$PARAMS"
            ;;
        search)
            python3 /usr/local/bin/sbos-vdi-deeplink-search.py "$ACCION" "$PARAMS"
            ;;
        compass)
            python3 /usr/local/bin/sbos-vdi-deeplink-compass.py "$ACCION" "$PARAMS"
            ;;
        *)
            zenity --error --text="Servidor desconocido: $SERVIDOR" --width=300
            exit 1
            ;;
    esac
else
    zenity --error \
        --title="SBOS VDI — Acceso Denegado" \
        --text="🚫 No tienes permiso para acceder a este recurso.\n\n$URI" \
        --width=400
    exit 1
fi
```

```ini
# /usr/share/applications/sbos-protocol-handler.desktop
# Registro del handler en KDE para URIs sbos://

[Desktop Entry]
Type=Application
Name=SBOS Protocol Handler
Exec=/usr/local/bin/sbos-vdi-protocol-handler %u
MimeType=x-scheme-handler/sbos;
NoDisplay=true
```

```bash
# Registrar el handler al instalar el cliente
xdg-mime default sbos-protocol-handler.desktop x-scheme-handler/sbos
update-desktop-database ~/.local/share/applications
```

### 23.5 Generación de Deep Links desde el Sistema

Los deep links `sbos://` son generados por los componentes del SBOS para llevar al usuario directamente al recurso:

```python
# Utilidad Python — generación de deep links en cualquier componente del SBOS
# Disponible como librería SKULL: from skull.deeplinks import sbos_link

def sbos_link(servidor: str, accion: str, **params) -> str:
    """
    Genera un URI sbos:// válido.
    
    Uso:
        sbos_link('erp', 'open/invoice', id='INV-2026-00123')
        → 'sbos://erp/open/invoice?id=INV-2026-00123'
    """
    from urllib.parse import urlencode
    base = f"sbos://{servidor}/{accion}"
    if params:
        return f"{base}?{urlencode(params)}"
    return base

# Ejemplos de uso en bCompass (notificación al escritorio del admin):
notif_link = sbos_link('compass', 'approval', request_id='REQ-456')
# → sbos://compass/approval?request_id=REQ-456

# En bSearch (resultado clickable):
result_link = sbos_link('erp', 'open/record', model='account.invoice', id=123)
# → sbos://erp/open/record?model=account.invoice&id=123

# En Core UI (botón de acción directa):
action_link = sbos_link('vdi', 'launch/app', app='libreoffice-writer',
                          file='/home/juan/informe_mensual.odt')
# → sbos://vdi/launch/app?app=libreoffice-writer&file=%2Fhome%2Fjuan%2Finforme_mensual.odt
```

---

## 24. Fronteras que el SBOS VDI Nunca Cruza

**El bAuth no decide políticas — las ejecuta.**
Las políticas viven en Tryton (SkVDIDesktopPolicy, SkVDIUserOverride) y en los RolTemplates. El bAuth las lee, las convierte a BitMasks, y las evalúa. Nunca crea políticas por sí mismo.

**El bAuth no mata sesiones activas.**
Cuando el BitMask de un usuario cambia durante una sesión activa, el bAuth notifica al Client y deniega nuevas acciones. Las apps ya abiertas continúan hasta que el usuario las cierra. El daemon no mata procesos.

**El wrapper sbos-vdi-run no decide nada.**
sbos-vdi-run es un mensajero: pregunta al daemon local, ejecuta la respuesta. Sin lógica de negocio propia.

**El SBOS VDI no almacena contraseñas.**
Las credenciales las gestiona Keycloak. El bAuth solo recibe y valida tokens JWT.

**Las fichas rights no tienen acceso directo al sistema.**
Las fichas rights modifican el resultado de una evaluación de privilegio — no tienen acceso directo al sistema de archivos, a la red, ni a procesos del usuario. Todo acceso es mediado por el motor bAuth.

**El SBOS VDI no accede a internet directamente desde el servidor.**
Todo tráfico de clientes pasa por Squid. El servidor de bAuth no hace llamadas directas a internet.

**El protocolo sbos:// no bypasea la BitMask.**
Un deep link no es un shortcut de seguridad. Todo URI sbos:// pasa por la verificación de privilegios del bAuth Client antes de ejecutarse. No es posible usar un enlace para acceder a algo que la BitMask prohíbe.

---

## 25. Hoja de Ruta de Desarrollo

### Fase 1 — Fundación del bAuth (Semanas 1-2)

| Tarea | Duración | Dependencia |
|---|---|---|
| Implementar bAuth Host mínimo (WebSocket + BitMask hardcodeada) | 3 días | — |
| Implementar bAuth Client (connect + check) | 3 días | 1.1 |
| Implementar sbos-vdi-run básico | 2 días | 1.2 |
| Probar comunicación en LAN con Fedora de prueba | 2 días | 1.3 |

**Hito: Demo funcional — click en app → consulta → respuesta → ejecuta/deniega**

### Fase 2 — Integración con Tryton y Keycloak (Semanas 3-4)

| Tarea | Duración | Dependencia |
|---|---|---|
| Desarrollar módulo Tryton sbos-vdi_privileges | 4 días | — |
| Integrar Host con Tryton API | 3 días | 2.1 |
| Implementar validación JWT de Keycloak en Host | 2 días | KC activo |
| Implementar RolFramework → BitMask calculation | 3 días | 2.1, 2.2 |

**Hito: Sistema funcionando con privilegios reales de Tryton**

### Fase 3 — Caché, Rendimiento y Propagación (Semana 5)

| Tarea | Duración | Dependencia |
|---|---|---|
| Integrar Redis para caché de BitMasks | 2 días | Fase 2 |
| Integrar bKernel → bAuth invalidación | 3 días | bKernel activo |
| Pruebas de carga (500 usuarios simultáneos) | 3 días | 3.1, 3.2 |

**Hito: < 5ms de latencia, cambios en < 3 segundos**

### Fase 4 — Auditoría y Reportes (Semana 6)

| Tarea | Duración | Dependencia |
|---|---|---|
| Diseñar schema PostgreSQL de auditoría | 2 días | — |
| Implementar audit logger async en Host | 3 días | 4.1 |
| Crear reportes básicos en Core UI | 3 días | 4.2 |

**Hito: Toda acción auditada y reportable**

### Fase 5 — Control de Red Soberano (Semanas 7-8)

| Tarea | Duración | Dependencia |
|---|---|---|
| Implementar reglas iptables owner en Client | 3 días | Fase 2 |
| Configurar Squid con External ACL Helper | 3 días | Fase 2 |
| Implementar squid-apibitmask-helper.py | 2 días | 5.2 |
| Integrar URL policy en UserPrivilegeProfile | 2 días | 5.1, 5.2 |

**Hito: Control de URL por usuario sin HashiCorp Boundary**

### Fase 6 — NFS, Cuotas y Recursos (Semanas 9-10)

| Tarea | Duración | Dependencia |
|---|---|---|
| Configurar NFSv4 + estructura de directorios | 3 días | — |
| Implementar sbos-vdi-setquota via quotactl | 2 días | NFS activo |
| Implementar cgroups via systemd scopes | 3 días | Fase 2 |
| Control de dispositivos via polkit | 2 días | 6.3 |

**Hito: Control completo de recursos**

### Fase 7 — USB SKULL, Protocolo sbos:// y Fichas rights (Semanas 11-12)

| Tarea | Duración | Dependencia |
|---|---|---|
| Crear imagen Fedora SKULL base (Dockerfile + livecd) | 4 días | Fases 1-6 |
| Implementar Rights API y rights Loader | 3 días | Fase 1 |
| Desarrollar fichas rights base (horario, contingencia) | 4 días | 7.2 |
| Implementar handler sbos:// y catálogo de acciones | 3 días | Fase 2 |
| Documentación completa del Rights API | 2 días | 7.3 |

**Hito: Sistema completo, extensible y con deep links operativos**

### Fase 8 — Piloto y Ajustes (Semana 13)

| Tarea | Duración | Dependencia |
|---|---|---|
| Desplegar piloto con 10 usuarios reales | 3 días | Fases 1-7 |
| Recolectar feedback + ajustes | 3 días | 8.1 |
| Preparar para producción | 2 días | 8.2 |

**Hito: Sistema listo para producción**

### Estimación de Recursos

| Recurso | Cantidad | Función |
|---|---|---|
| Desarrolladores Python (asyncio/sistemas) | 2 | bAuth Host + Client + Helper |
| Desarrollador Tryton | 1 | Módulo sbos-vdi_privileges |
| Administrador Linux/sistemas | 1 | NFS, Squid, iptables, systemd |
| Desarrollador Fedora/Linux | 1 | Wrapper, PAM, imagen USB, handler sbos:// |
| QA/Tester | 1 | Validación de flujos y rendimiento |
| **Tiempo total** | **13 semanas** | **~650 horas-hombre** |

---

## 26. Registro de Cambios

### v5.0 · Corrección de coherencia bAuth — Marzo 2026 (este documento)

**Renumeración: SBOS-009 → SBOS-012.**
El documento pasa a su número definitivo en la tabla de renumeración del SBOS v5.0 · Corrección de coherencia bAuth.

**Eliminación de Kasm Workspaces.**
Kasm era el motor VDI en v3.5. En v5.0 · Corrección de coherencia bAuth el motor VDI es el propio Fedora KDE Plasma con el sistema bAuth de SKULL. El §2 documenta la justificación completa. El escritorio ahora es completamente soberano.

**Introducción del bAuth.**
El daemon soberano de privilegios de SKULL reemplaza todos los mecanismos de control de Kasm. Incluye: BitMask Engine, Rights Loader, Tryton Client, Squid ACL Helper, Notification Dispatcher, Audit Logger. Documentado en §6.

**La aritmética BitMask como representación de privilegios.**
Los privilegios se representan como bits en enteros de 64 bits. La evaluación de privilegios es una operación AND — O(1) en cualquier CPU. Las políticas en cascada se implementan como operaciones OR sobre las BitMasks de cada nivel. Documentado en §7.

**Las fichas rights como mecanismo de extensión.**
El bAuth es extensible sin modificar su núcleo. Las fichas rights son unidades declarativas autocontenidas que pueden modificar el resultado de cualquier evaluación de privilegio. Documentado en §8.

**Reemplazo soberano de HashiCorp Boundary.**
HashiCorp Boundary (BSL) reemplazado por: iptables con módulo owner (kernel Linux nativo, GPL) + Squid con External ACL Helper (GPL). Documentado en §10.

**Dockerfile completo de la imagen Fedora SKULL.**
Especificación técnica completa del Dockerfile de la imagen del contenedor web, con 10 capas documentadas, justificación por capa, y notas de producción. Documentado en §14.2.

**Especificación completa del protocolo sbos://.**
Catálogo exhaustivo de acciones por servidor (erp, vdi, search, compass), implementación del handler, registro en KDE, y utilidad de generación de deep links. Documentado en §23.

**Actualización de referencias de numeración.**
Todas las referencias a SBOS-009 actualizadas a SBOS-012. Referencias a documentos hermanos actualizadas a la nueva numeración (SBOS-008, SBOS-013, SBOS-003).

---

*SKULL · SBOS · SBOS-012 · v5.0 · Corrección de coherencia bAuth · Marzo 2026*
*Reemplaza: SBOS-009-SKVDI v3.5 (SUPERSEDED — arquitectura Kasm)*
*Próxima revisión: al completar Fase 3 de desarrollo (estimada: junio 2026)*
