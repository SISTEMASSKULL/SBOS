# Índice de Documentación — bNexus (bhnexus + banexus)
### SKULL · SBOS — Motor de Conectividad & Edge Física

**Versión:** 1.0.0  
**Fecha:** 2026-08-04  
**Carta rectora:** `0.00_MANUAL-DIRECTRICES-NEXUS.md` — todos los manuales se leen bajo esas directrices  
**Plan:** `PLAN-DOCUMENTACION-BNEXUS-v2.0.md` — secuencia y estado de Sprint 1-4  

---

## Lectura recomendada por rol

| Rol | Por dónde empezar |
|-----|------------------|
| Desarrollador nuevo en bNexus | `0.00` → `1.01` → `1.06` → `2.01` → `2.02` |
| Integrador (conectar una app a bAuth) | `1.06` (forma implicit) → manuales 2.18 de bAuth |
| Equipo de hardware | `1.01` → `3.01` → `3.02` → `4.01` |
| Equipo de seguridad | `0.00` → `7.02` → `2.01` → `2.02` → `A.09` |
| Operaciones / SRE | `7.03` → `5.01` → `5.02` → `5.03` |

---

## Serie 0 — CARTA RECTORA

| Código | Manual | Estado |
|--------|--------|:------:|
| `0.00` | [Directrices del corpus documental bNexus](0.00_MANUAL-DIRECTRICES-NEXUS.md) | ✅ |

---

## Serie 1 — TOPOLOGÍA

| Código | Manual | Estado |
|--------|--------|:------:|
| `1.01` | [La unidad bNexus: tres capas, misión, topología](1.01_MANUAL-TOPOLOGIA-NEXUS.md) | ✅ |
| `1.02` | Árbol jerárquico físico (11 niveles: TENANT → ACTOR) | ⬜ |
| `1.03` | [Identidades bNexus en SBOSDB — registro de nodos y dispositivos](1.03_MANUAL-IDENTIDADES-NEXUS.md) | ✅ |
| `1.04` | Tipos de credencial (QR, NFC, RFID, biométrico, smartcard, BLE, PIN) | ⬜ |
| `1.05` | [SAM-128: estructura 128 bits, evaluación O(1), relación con BitMask de bAuth](1.05_MANUAL-SAM128.md) | ✅ |
| `1.06` | [Las cinco formas de banexus — taxonomía, criterios de selección, árbol de decisión](1.06_MANUAL-FORMAS-BANEXUS.md) | ✅ |

---

## Serie 2 — CONECTIVIDAD ★ PRIORIDAD BLOQUEANTE

| Código | Manual | Estado |
|--------|--------|:------:|
| `2.01` | [**Puerta 1 — Protocolo banexus ↔ bhnexus**](2.01_MANUAL-PUERTA-1-AGENTES.md) (WebSocket mTLS, SPIFFE, frames) | ✅ |
| `2.02` | [**Puerta 2 — Protocolo bhnexus ↔ bAuth**](2.02_MANUAL-PUERTA-2-BAUTH.md) (dos sub-canales: TLV + canal privilegiado) | ✅ |
| `2.03` | Interface Dual de bNexus (ADR-020 aplicado) | ⬜ |
| `2.04` | Sagas de comunicación bNexus (conexión, reconexión, offline recovery) | ⬜ |

---

## Serie 3 — HARDWARE

| Código | Manual | Estado |
|--------|--------|:------:|
| `3.01` | HAL: DeviceDriver interface, pipeline de captura, 6 implementaciones | ⬜ |
| `3.02` | Drivers: OSDP v2.2, MQTT 5.0, ONVIF Profile C, Wiegand, USB HID, HTTP | ⬜ |
| `3.03` | Flujos por tipo de credencial | ⬜ |
| `3.04` | Políticas físicas: Anti-passback, Two-Person Rule, Mantrap | ⬜ |

---

## Serie 4 — INTERCEPCIÓN (banexus sentinel de borde)

| Código | Manual | Estado |
|--------|--------|:------:|
| `4.01` | Input Hooking: udev + libusb (captura antes de evdev, anti-inyección) | ⬜ |
| `4.02` | Shell Sentinel: pam_banexus.so — interceptación de comandos sensibles | ⬜ |
| `4.03` | Actuator Controller: relés, puertas, cajones (RS-232, timer auto-close) | ⬜ |
| `4.04` | Integridad de banexus: SHA-256 cada 5 min, auto-shutdown, alerta Wazuh | ⬜ |

---

## Serie 5 — CACHE & RESILIENCIA

| Código | Manual | Estado |
|--------|--------|:------:|
| `5.01` | Auth Cache de bhnexus (in-memory, TTL 30s, 100K entradas, invalidación) | ⬜ |
| `5.02` | Policy Cache de banexus (AES-256-GCM, HKDF-SHA256, TTL 4h, fail-secure) | ⬜ |
| `5.03` | Comportamiento offline y fail-secure | ⬜ |

---

## Serie 6 — INTEGRACIÓN

| Código | Manual | Estado |
|--------|--------|:------:|
| `6.01` | Flujo de política: cambio RolTemplate → bAuth → canal privilegiado → banexus | ⬜ |
| `6.02` | bhnexus ↔ bkernel: registro de eventos de acceso físico en WAL | ⬜ |
| `6.03` | bhnexus ↔ bsearch: indexación de eventos de autenticación | ⬜ |

---

## Serie 7 — NORMAS & OPERACIÓN

| Código | Manual | Estado |
|--------|--------|:------:|
| `7.01` | Normas aplicables (OSDP, MQTT, ONVIF, Aliro, ISO 27001 A.7, NIST SP 800-207) | ⬜ |
| `7.02` | Seguridad de bNexus (mTLS, SPIFFE, AES-256-GCM, canal privilegiado, Wazuh) | ⬜ |
| `7.03` | Operación (systemd, TOML config, Prometheus 9 métricas) | ⬜ |
| `7.04` | CLI y pruebas (bnexusctl, verificación Puerta 1 y Puerta 2) | ⬜ |

---

## Serie 9 — PRODUCTO

| Código | Manual | Estado |
|--------|--------|:------:|
| `9.01` | Producto bNexus: binarios, API JSON-RPC (~30 métodos `bhnexus.*`/`banexus.*`) | ⬜ |

---

## Motores (`MOTORES/`)

| Motor | Archivo | Estado |
|-------|---------|:------:|
| Índice de motores | [MOTORES-INDEX.md](MOTORES/MOTORES-INDEX.md) | ✅ |
| Conectividad-1 | motor-conectividad-agentes.md (Puerta 1) | ⬜ |
| Conectividad-2 | motor-identidad-bauth.md (Puerta 2 — bidireccional) | ⬜ |
| Hardware | motor-hardware.md | ⬜ |
| Cache | motor-cache.md | ⬜ |
| Intercepción | motor-intercepcion.md | ⬜ |
| Actuación | motor-actuacion.md | ⬜ |

---

## Anexos (`anexos/`)

| Código | Anexo | Respalda | Estado |
|--------|-------|---------|:------:|
| `A.01` | Flujo soberano completo (QR → actuador, tiempos verificados) | 1.01, 2.01, 2.02 | ⬜ |
| `A.02` | [Spec protocolo wire Puerta 1](anexos/A.02_PROTOCOLO-WIRE-PUERTA-1.md) | 2.01 | ✅ |
| `A.03` | [Spec protocolo wire Puerta 2 + canal privilegiado](anexos/A.03_PROTOCOLO-WIRE-PUERTA-2.md) | 2.02 | ✅ |
| `A.04` | [Identidades bNexus en SBOSDB (ejemplos completos)](anexos/A.04_IDENTIDADES-BNEXUS-SBOSDB.md) | 1.03 | ✅ |
| `A.05` | [Árbol de decisión formas de banexus](anexos/A.05_ARBOL-DECISION-FORMAS-BANEXUS.md) | 1.06 | ✅ |
| `A.06` | SAM-128: mapeo de bits con correspondencia a bAuth BitMask 64-bit | 1.05 | ⬜ |
| `A.07` | HAL: inventario de drivers y tipos de credencial | 3.01, 3.02 | ⬜ |
| `A.08` | Contrato bilateral bhnexus ↔ bAuth | 2.02, 6.01 | ⬜ |
| `A.09` | Seguridad: mTLS, SPIFFE, AES-256-GCM, canal privilegiado, Wazuh | 7.02 | ⬜ |

> **A.08** vive en `context/contracts/BHNEXUS-BAUTH-CONTRATOS.md` (decisión HITL H-01).  
> Este índice apunta a él como referencia; la custodia es del Bibliotecario.

---

## Estado Sprint

| Sprint | Documentos | Estado |
|--------|-----------|:------:|
| **Sprint 1** — Topología + Conectividad (13 docs) | 0.00, INDICE, MOTORES-INDEX, 1.01, 1.03, 1.05, 1.06, 2.01, 2.02, A.02, A.03, A.04, A.05 | ✅ |
| Sprint 2 — Base topológica + Resiliencia (11 docs) | 1.02, 1.04, 2.03, 2.04, 5.01-5.03, 6.01, A.01, A.06, A.08 | ⬜ |
| Sprint 3 — Hardware & Intercepción (7 docs) | 3.01-3.03, 4.01, 4.02, 4.04, A.07 | ⬜ |
| Sprint 4 — Normas, Operación & Producto | resto | ⬜ |

---

*SKULL · SBOS · bNexus · INDICE · v1.0.0 · Agosto 2026*
