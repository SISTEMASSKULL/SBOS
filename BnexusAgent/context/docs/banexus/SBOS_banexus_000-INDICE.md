# SBOS Nexus Agent (banexus) — Índice de Documentación
**Daemon:** banexus | **Versión:** 8.0 | **Fecha:** 2026-05-27
**Estándar:** SBOS V8 — Consolidado desde V5+V6+V7+Smart*+SBOS

---

## 1. Identidad del Daemon

| Campo | Valor |
|---|---|
| Nombre | SBOS Nexus Agent |
| Servicio | banexus.service (systemd --user en Fedora) |
| Lenguaje | Go (concurrencia I/O + WebSocket) |
| Runtime | Fedora VDI (estación de trabajo — cliente) |
| Puerto | Sin puerto abierto (solo conexión saliente WebSocket) |
| Unidad declarativa | Edge Sentinel (agente de presencia física) |

---

## 2. Mapa de Documentos

| # | Archivo | Propósito |
|---|---------|-----------|
| 000 | INDICE | Este archivo — navegación y estado |
| README | README | Referencia rápida, dependencias, comandos |
| VISION | VISION | Propósito, alcance, Edge Sentinel |
| DOMINIO | DOMINIO | Entidades, reglas de negocio RN-XXX |
| FUNCIONALIDADES | FUNCIONALIDADES | Capacidades F-XXX con criterios de aceptación |
| ARQUITECTURA | ARQUITECTURA | Stack, decisiones, constraints |
| INTEGRACIONES | INTEGRACIONES | Sistemas externos, contratos, dirección |
| DATOS | DATOS | Entidades de datos, ciclo de vida, retención |
| SEGURIDAD | SEGURIDAD | Auth, matriz de autorización, cumplimiento |
| OPERACION | OPERACION | SLOs, monitoreo, alertas, runbooks |
| GLOSARIO | GLOSARIO | Términos técnicos del daemon |

---

## 3. Rutas de Lectura

### Obligatoria
README → VISION → ARQUITECTURA → FUNCIONALIDADES

### Integración con otros daemons
INTEGRACIONES → DATOS → SEGURIDAD

### Operación
OPERACION → SEGURIDAD → ARQUITECTURA

---

## 4. Dependencias

| Daemon/Sistema | Tipo | Dirección |
|---|---|---|
| WebSocket mTLS | Comunicación | bhnexus:9444 |
| udev | Interceptación | Dispositivos USB |
| libusb | Captura | QR, NFC, barcode |
| PAM | Módulo | pam_banexus.so (Shell Sentinel) |
| polkit | Autorización | Comandos sensibles |
| Hardware | Lectores | QR, NFC, barcode, fingerprint, PIN |
| SBOS Nexus Host (bhnexus) | WebSocket mTLS | Conexión permanente broker-agente |
| SBOS Auth Enforce (bauth) | Indirecta via bhnexus | Evaluación BitMask |
| SBOS IAM Installer (bos) | Filesystem | Config device fichas |
| SBOS Data Kernel (bkernel) | WAL de eventos | Registro de autenticación |

---

## 5. Glosario Rápido

| Término | Definición |
|---|---|
| **Edge Sentinel** | Punto de presencia físico de SBOS en cada estación de trabajo |
| **Input Hooking** | Captura de datos USB en crudo vía libusb antes que evdev genere eventos |
| **Shell Sentinel** | Módulo PAM que intercepta comandos sensibles y consulta autorización |
| **Policy Cache Efimero** | Cache local de BitMasks cifrado con AES-256-GCM para modo offline |
| **Fail-Secure** | Sin conexión + sin cache = DENY siempre |
| **pam_banexus.so** | Módulo PAM que implementa el Shell Sentinel en auth phase |
| **ActuatorCommand** | Comando para actuador físico (rele, cerradura, alarma) |
| **Backoff Exponencial** | Reconexión: 1s -> 5s -> 15s -> 30s -> 60s |

---

## 6. Estado de Documentación

| # | Archivo | Estado |
|---|---|---|
| 000 | INDICE | ✅ Completo |
| README | README | ✅ Completo |
| VISION | VISION | ✅ Completo |
| DOMINIO | DOMINIO | ✅ Completo |
| FUNCIONALIDADES | FUNCIONALIDADES | ✅ Completo |
| ARQUITECTURA | ARQUITECTURA | ✅ Completo |
| INTEGRACIONES | INTEGRACIONES | ✅ Completo |
| DATOS | DATOS | ✅ Completo |
| SEGURIDAD | SEGURIDAD | ✅ Completo |
| OPERACION | OPERACION | ✅ Completo |
| GLOSARIO | GLOSARIO | ✅ Completo |

---

_SKULL · SBOS V8 · SBOS Nexus Agent (banexus) · 2026-05-27_
