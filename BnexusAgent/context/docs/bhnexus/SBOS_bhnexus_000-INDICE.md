# SBOS Nexus Host (bhnexus) — Índice de Documentación
**Daemon:** bhnexus | **Versión:** 8.0 | **Fecha:** 2026-05-27
**Estándar:** SBOS V8 — Consolidado desde V5+V6+V7+Smart*+SBOS

---

## 1. Identidad del Daemon

| Campo | Valor |
|---|---|
| Nombre | SBOS Nexus Host |
| Servicio | bhnexus.service (systemd en host) |
| Lenguaje | Go (alta concurrencia WebSocket) |
| Runtime | Host |
| Puerto | 9444 (WSS/mTLS) + 9445 (Prometheus métricas) |
| Unidad declarativa | Device Ficha (YAML: dispositivo + protocolo + actuadores) |

---

## 2. Mapa de Documentos

| # | Archivo | Propósito |
|---|---------|-----------|
| 000 | INDICE | Este archivo — navegación y estado |
| README | README | Referencia rápida, dependencias, comandos |
| VISION | VISION | Propósito, alcance, 6 drivers de hardware |
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
| WebSocket mTLS | Comunicación | banexus agentes concurrentes |
| PostgreSQL | Eventos | Registro de auditoría (opcional) |
| OSDP | RS-485 | Control acceso físico |
| MQTT | TCP/1883 | Dispositivos IoT |
| ONVIF Profile C | IP | Cámaras control acceso |
| Wiegand | GPIO | Decodificación 26/34/37 bits |
| USB HID | USB | QR, NFC, barcode |
| SBOS Nexus Agent (banexus) | WebSocket mTLS | Broker central de agentes edge |
| SBOS Auth Enforce (bauth) | Unix socket | Consulta BitMask en cache miss |
| SBOS IAM Installer (bos) | Filesystem YAML | Crea device fichas |
| SBOS Data Kernel (bkernel) | WAL de eventos | audit_events |
| SBOS Data RAG (bsearch) | Indexación | Eventos de autenticación |

---

## 5. Glosario Rápido

| Término | Definición |
|---|---|
| **Hardware Bridge** | Normaliza 6 protocolos físicos bajo CredentialEvent común |
| **HAL** | Hardware Abstraction Layer — interfaz Go para drivers de hardware |
| **Auth Cache** | Cache in-memory de BitMasks con TTL 30s para respuesta sub-5ms |
| **Device Ficha** | Archivo YAML que declara dispositivo, protocolo y actuadores |
| **CredentialEvent** | Evento normalizado de cualquier lector de hardware |
| **mTLS** | Mutual TLS — autenticación mutua con certificados bidireccionales |
| **OSDP** | Open Supervised Device Protocol v2.2 para control de acceso |
| **ActuatorCommand** | Comando para actuador físico (cerradura, rele, alarma) |

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

_SKULL · SBOS V8 · SBOS Nexus Host (bhnexus) · 2026-05-27_
