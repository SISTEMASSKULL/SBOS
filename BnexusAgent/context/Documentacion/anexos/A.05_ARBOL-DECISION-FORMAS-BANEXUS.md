# A.05 — Árbol de Decisión: Formas de banexus
## Matriz escenario × forma, criterios de selección y árbol visual

**Versión:** 1.0.0  
**Fecha:** 2026-08-04  
**Respalda:** `1.06_MANUAL-FORMAS-BANEXUS.md`  

---

## 1. Árbol de decisión completo

```
¿El cliente es una aplicación de software?
(app web, backend, CLI, desktop, daemon, SPA, API)
│
├── SÍ → banexus-implicit
│          Protocolo: mTLS + JWT/OIDC + W3C Trace Context
│          Binario: ninguno
│          Ejemplos: Core UI SBOS, Laravel, Django, Vue, React,
│                    Spring Boot, FastAPI, .NET, Rails, biedata, bnotify
│
└── NO → ¿Es una app móvil iOS/Android con acceso físico?
    │    (BLE, UWB, NFC — el teléfono actúa como credencial)
    │
    ├── SÍ → banexus-sdk
    │          Librería: Aliro CSA 2023 (Swift Package / Android AAR)
    │          Protocolos: BLE + UWB + NFC
    │          Ejemplos: app corporativa de acceso con iPhone, Android MDM
    │
    └── NO → ¿El hardware tiene firmware con HTTP/REST propio?
        │    (puede llamar a un endpoint y ejecutar comandos él mismo)
        │
        ├── SÍ → banexus-virtual
        │          Binario: ninguno — el firmware llama a bAuth
        │          Protocolo: mTLS + JWT desde el firmware
        │          Ejemplos: cerradura WiFi con API REST, cámara PTZ inteligente
        │
        └── NO → ¿El hardware está físicamente en el mismo local
            │    que el servidor bhnexus? (mismo edificio, LAN directa)
            │
            ├── SÍ → ¿Es hardware mudo? (OSDP, MQTT, ONVIF, Wiegand)
            │    │
            │    ├── SÍ → HAL Directo de bhnexus
            │    │         (ninguna forma de banexus)
            │    │         bhnexus controla el hardware con su driver
            │    │
            │    └── NO → ¿Hay un PC/workstation con hardware adjunto?
            │         │
            │         └── SÍ → banexus-daemon
            │                   Binario: Rust MUSL, systemd --user
            │                   Hardware: cajón serial, relé GPIO, lector USB
            │                   Ejemplos: POS Fedora, workstation de control
            │
            └── NO → El hardware está en un sitio remoto
                      (otra sucursal, otro edificio, acceso por WAN)
                      │
                      └── banexus-gateway
                            Binario: mismo Rust MUSL, mode=gateway en SBC
                            Hardware: conectado al SBC, no al servidor central
                            Ejemplos: Raspberry Pi en sucursal,
                                      PC industrial en almacén remoto
```

---

## 2. Matriz escenario × forma

| Escenario | Forma | Binario en... | Nota |
|-----------|-------|--------------|------|
| Core UI de SBOS (Flutter desktop/web) | **implicit** | Ninguno | App SBOS = tenant interno |
| bOS CLI | **implicit** | Ninguno | Daemon M2M, AAL3, mTLS |
| biedata, bnotify, bsearch (M2M) | **implicit** | Ninguno | Sin usuario interactivo |
| Laravel del cliente (servidor) | **implicit** | Ninguno | Tenant interno o externo |
| Django / FastAPI (servidor) | **implicit** | Ninguno | Cualquier framework Python |
| Vue / React (SPA en browser) | **implicit** | Ninguno | OIDC con PKCE desde el browser |
| Spring Boot / .NET (servidor) | **implicit** | Ninguno | Librerías OIDC estándar |
| App desarrollador externo | **implicit** | Ninguno | Tenant externo, protocolo idéntico |
| App iOS corporativa (acceso físico) | **sdk** | iOS (Swift Package) | Aliro BLE+UWB+NFC |
| App Android MDM (acceso físico) | **sdk** | Android (AAR) | Aliro BLE+UWB+NFC |
| Workstation Fedora + cajón de dinero | **daemon** | workstation | Input Hooking + Serial |
| POS terminal Linux + relé USB | **daemon** | POS terminal | systemd --user |
| PC de control con GPIO (almacén local) | **daemon** | PC control | GPIO en mismo edificio |
| Sucursal remota — chapas OSDP | **gateway** | Raspberry Pi in situ | Puerta 1 via WAN |
| Bodega remota — torniquetes | **gateway** | ARM SBC in situ | Puerta 1 via VPN/WAN |
| Edificio B del campus (otro edificio) | **gateway** | PC industrial | LAN inter-edificio |
| Cerradura WiFi con REST API | **virtual** | Ninguno | El firmware llama a bAuth |
| Terminal IP con API HTTP propia | **virtual** | Ninguno | El terminal se auto-actúa |
| Chapa OSDP en mismo edificio que bhnexus | **HAL Directo** | — | No hay banexus |
| Cámara ONVIF en LAN local | **HAL Directo** | — | bhnexus driver ONVIF |
| Sensor MQTT en LAN local | **HAL Directo** | — | bhnexus driver MQTT |
| Wiegand legacy en mismo edificio | **HAL Directo** | — | bhnexus driver Wiegand |

---

## 3. Criterios cuantitativos de selección

Cuando hay ambigüedad, usar esta tabla de criterios:

| Criterio | implicit | daemon | gateway | sdk | virtual |
|----------|:--------:|:------:|:-------:|:---:|:-------:|
| OS de propósito general en el cliente | ✅ | ✅ | ✅ | ✅ (iOS/Android) | Depende |
| Hardware físico adjunto al cliente | ❌ | ✅ | ✅ | ❌ (solo BLE/NFC) | ❌ |
| Cliente en sitio remoto (WAN) | N/A | ❌ | ✅ | N/A | N/A |
| Cliente en LAN local del servidor | N/A | ✅* | ❌** | N/A | N/A |
| El cliente puede instalar systemd | N/A | ✅ | ✅ | ❌ | N/A |
| El cliente tiene firmware HTTP/REST | N/A | N/A | N/A | N/A | ✅ |
| Requiere cache local offline | ❌*** | ✅ (4h) | ✅ (4h) | ✅ (1h) | ❌ |
| Requiere Shell Sentinel | ❌ | ✅ (opcional) | ❌ | ❌ | ❌ |

*Si el PC con hardware adjunto está en el mismo LAN que bhnexus, sigue siendo daemon — lo que importa es el hardware adjunto, no la distancia de red.  
**gateway aplica cuando el HARDWARE (no el cliente) está en un sitio remoto sin conexión directa a bhnexus por cable.  
***implicit puede tener cache a nivel del framework/servidor (ej: cache de JWT), pero no es el AES-256-GCM de banexus.

---

## 4. Combinaciones válidas en el mismo nodo

Un mismo nodo físico puede combinar más de una forma si tiene múltiples clientes:

| Nodo | App de POS (software) | Hardware serial | Resultado |
|------|:---------------------:|:---------------:|-----------|
| Terminal POS Linux | ✅ (app procesa ventas) | ✅ (cajón de dinero) | implicit + daemon en paralelo |

| Nodo | App de acceso (software) | Lector NFC Aliro | Resultado |
|------|:------------------------:|:----------------:|-----------|
| Smartphone corporativo | ✅ (app web del empleado) | ✅ (NFC para puerta) | implicit (app) + sdk (NFC) |

---

## 5. Errores comunes de elección

| Error | Por qué es incorrecto | Forma correcta |
|-------|----------------------|----------------|
| Usar banexus-daemon para una app web | App web no tiene hardware adjunto ni systemd en el servidor web | banexus-implicit |
| Usar banexus-gateway para hardware en el mismo edificio que bhnexus | gateway agrega latencia de WAN innecesaria | HAL Directo o banexus-daemon |
| Usar banexus-virtual para un POS con cajón serial | El POS no puede actuarse a sí mismo — necesita un proceso que maneje el puerto serial | banexus-daemon |
| Instalar banexus-sdk en una app web | El SDK es solo para iOS/Android nativo con BLE/UWB/NFC | banexus-implicit para web |
| No instalar nada para un nodo con cajón de dinero | Sin banexus-daemon, el cajón no tiene PEP — queda sin control de bAuth | banexus-daemon obligatorio |

---

## 6. Regla de oro

> **Cualquier software → implicit.  
> Cualquier hardware local → daemon o HAL Directo.  
> Cualquier hardware remoto → gateway.  
> Cualquier móvil con NFC/BLE → sdk.  
> Cualquier firmware HTTP → virtual.**

Si la entidad corre un OS de propósito general y no tiene hardware físico que controlar → siempre es banexus-implicit, sin excepciones.

---

*SKULL · SBOS · bNexus · A.05_ARBOL-DECISION-FORMAS-BANEXUS · v1.0.0 · Agosto 2026*
