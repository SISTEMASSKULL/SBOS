# Índice de Documentación — bNexus (bhnexus + banexus)
### SKULL · SBOS — Motor de Conectividad & Edge Física

**Versión:** 2.0.0  
**Fecha:** 2026-08-04  
**Carta rectora:** `0.00_MANUAL-DIRECTRICES-NEXUS.md` — todos los manuales se leen bajo esas directrices  
**Plan:** `PLAN-DOCUMENTACION-BNEXUS-v2.0.md` — secuencia y estado de Sprint 1-4  

---

## Lectura recomendada por rol

| Rol | Por dónde empezar |
|-----|------------------|
| Desarrollador nuevo en bNexus | `0.00` → `1.01` → `1.06` → `2.01` → `2.02` |
| Integrador (conectar una app a bAuth) | `1.06` (forma implicit) → manuales bAuth |
| Equipo de hardware | `1.01` → `3.01` → `3.02` → `4.01` |
| Equipo de seguridad | `0.00` → `7.02` → `2.01` → `2.02` → `A.09` |
| Operaciones / SRE | `7.03` → `5.01` → `5.02` → `5.03` |
| Producto / gestión | `9.01` → `1.01` → `1.06` |

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
| `1.02` | [Árbol jerárquico físico — 11 niveles: TENANT → ACTOR](1.02_MANUAL-ARBOL-FISICO.md) | ✅ |
| `1.03` | [Identidades bNexus en SBOSDB — registro de nodos y dispositivos](1.03_MANUAL-IDENTIDADES-NEXUS.md) | ✅ |
| `1.04` | [Tipos de credencial — QR, NFC, RFID, biométrico, smartcard, BLE, PIN](1.04_MANUAL-TIPOS-CREDENCIAL.md) | ✅ |
| `1.05` | [SAM-128: estructura 128 bits, evaluación O(1), relación con BitMask de bAuth](1.05_MANUAL-SAM128.md) | ✅ |
| `1.06` | [Las cinco formas de banexus — taxonomía, criterios de selección, árbol de decisión](1.06_MANUAL-FORMAS-BANEXUS.md) | ✅ |

---

## Serie 2 — CONECTIVIDAD

| Código | Manual | Estado |
|--------|--------|:------:|
| `2.01` | [**Puerta 1 — Protocolo banexus ↔ bhnexus**](2.01_MANUAL-PUERTA-1-AGENTES.md) (WebSocket mTLS, SPIFFE, frames) | ✅ |
| `2.02` | [**Puerta 2 — Protocolo bhnexus ↔ bAuth**](2.02_MANUAL-PUERTA-2-BAUTH.md) (sub-canal A TLV + sub-canal B privilegiado) | ✅ |
| `2.03` | [Interface Dual de bNexus (ADR-020 aplicado)](2.03_MANUAL-INTERFACE-DUAL-NEXUS.md) | ✅ |
| `2.04` | [Sagas de comunicación bNexus — S-01 a S-04](2.04_MANUAL-SAGAS-NEXUS.md) | ✅ |

---

## Serie 3 — HARDWARE

| Código | Manual | Estado |
|--------|--------|:------:|
| `3.01` | [HAL: DeviceDriver trait, pipeline de captura, 6 drivers](3.01_MANUAL-HAL.md) | ✅ |
| `3.02` | [Drivers: OSDP, Wiegand, MQTT, ONVIF, USB HID, HTTP](3.02_MANUAL-DRIVERS.md) | ✅ |
| `3.03` | [Flujos por tipo de credencial — del hardware al SAM-128](3.03_MANUAL-FLUJOS-CREDENCIAL.md) | ✅ |

---

## Serie 4 — INTERCEPCIÓN (banexus sentinel de borde)

| Código | Manual | Estado |
|--------|--------|:------:|
| `4.01` | [Input Hooking: udev + libusb — captura antes de evdev, anti-inyección](4.01_MANUAL-INPUT-HOOKING.md) | ✅ |
| `4.02` | [Shell Sentinel: pam_banexus.so — PAM, LD_PRELOAD, eBPF](4.02_MANUAL-SHELL-SENTINEL.md) | ✅ |
| `4.04` | [Integridad de banexus: SHA-256 cada 5 min, auto-shutdown, Wazuh](4.04_MANUAL-INTEGRIDAD-BANEXUS.md) | ✅ |

---

## Serie 5 — CACHE & RESILIENCIA

| Código | Manual | Estado |
|--------|--------|:------:|
| `5.01` | [Auth Cache de bhnexus — in-memory, TTL 30s, LRU, 4 invalidaciones](5.01_MANUAL-AUTH-CACHE-BHNEXUS.md) | ✅ |
| `5.02` | [Policy Cache de banexus — AES-256-GCM, HKDF-SHA256, TTL 4h, fail-secure](5.02_MANUAL-POLICY-CACHE-BANEXUS.md) | ✅ |
| `5.03` | [Comportamiento offline y fail-secure — 3 escenarios, tabla de decisión](5.03_MANUAL-OFFLINE-FAILSECURE.md) | ✅ |

---

## Serie 6 — INTEGRACIÓN

| Código | Manual | Estado |
|--------|--------|:------:|
| `6.01` | [Flujo de política: cambio RolTemplate → bAuth → canal privilegiado → banexus](6.01_MANUAL-FLUJO-POLITICA.md) | ✅ |
| `6.02` | [bhnexus ↔ bkernel: eventos de acceso físico en WAL de PostgreSQL](6.02_MANUAL-BKERNEL-WAL.md) | ✅ |
| `6.03` | [bhnexus ↔ bsearch: indexación de eventos de autenticación](6.03_MANUAL-BSEARCH-INDEX.md) | ✅ |

---

## Serie 7 — NORMAS & OPERACIÓN

| Código | Manual | Estado |
|--------|--------|:------:|
| `7.01` | [Normas: OSDP, MQTT, ONVIF, Aliro, SPIFFE, ISO 27001, NIST SP 800-207](7.01_MANUAL-NORMAS-NEXUS.md) | ✅ |
| `7.02` | [Seguridad: mTLS, SPIFFE, AES-256-GCM, canal privilegiado, Wazuh 12 reglas](7.02_MANUAL-SEGURIDAD-NEXUS.md) | ✅ |
| `7.03` | [Operación: systemd, TOML completo, Prometheus 6 métricas, troubleshooting](7.03_MANUAL-OPERACION-NEXUS.md) | ✅ |
| `7.04` | [CLI y pruebas: bnexusctl, verificación Puerta 1 y Puerta 2](7.04_MANUAL-CLI-PRUEBAS.md) | ✅ |

---

## Serie 9 — PRODUCTO

| Código | Manual | Estado |
|--------|--------|:------:|
| `9.01` | [Producto bNexus: binarios, ~30 métodos JSON-RPC bhnexus.* y banexus.*](9.01_MANUAL-PRODUCTO-NEXUS.md) | ✅ |

---

## Motores (`MOTORES/`)

| Motor | Archivo | Estado |
|-------|---------|:------:|
| Índice de motores | [MOTORES-INDEX.md](MOTORES/MOTORES-INDEX.md) | ✅ |
| M-01 Conectividad | [motor-conectividad-agentes.md](MOTORES/motor-conectividad-agentes.md) — Puerta 1 | ✅ |
| M-02 Identidad | [motor-identidad-bauth.md](MOTORES/motor-identidad-bauth.md) — Puerta 2 bidireccional | ✅ |
| M-03 Hardware | [motor-hardware.md](MOTORES/motor-hardware.md) — HAL normalización | ✅ |
| M-04 Cache | [motor-cache.md](MOTORES/motor-cache.md) — Auth Cache + Policy Cache | ✅ |
| M-05 Intercepción | [motor-intercepcion.md](MOTORES/motor-intercepcion.md) — Input Hooking + PAM + Integrity | ✅ |
| M-06 Actuación | [motor-actuacion.md](MOTORES/motor-actuacion.md) — relés, OSDP, MQTT | ✅ |

---

## Anexos (`anexos/`)

| Código | Anexo | Respalda | Estado |
|--------|-------|---------|:------:|
| `A.01` | [Flujos soberanos completos — QR cajera, biométrico CPD, SSH Shell Sentinel](anexos/A.01_FLUJO-SOBERANO-COMPLETO.md) | 1.01, 2.01, 2.02 | ✅ |
| `A.02` | [Spec protocolo wire Puerta 1](anexos/A.02_PROTOCOLO-WIRE-PUERTA-1.md) | 2.01 | ✅ |
| `A.03` | [Spec protocolo wire Puerta 2 + canal privilegiado](anexos/A.03_PROTOCOLO-WIRE-PUERTA-2.md) | 2.02 | ✅ |
| `A.04` | [Identidades bNexus en SBOSDB — ejemplos completos](anexos/A.04_IDENTIDADES-BNEXUS-SBOSDB.md) | 1.03 | ✅ |
| `A.05` | [Árbol de decisión formas de banexus](anexos/A.05_ARBOL-DECISION-FORMAS-BANEXUS.md) | 1.06 | ✅ |
| `A.06` | [SAM-128: mapa de bits con correspondencia a bAuth BitMask 64-bit](anexos/A.06_SAM128-MAPA-BITS.md) | 1.05 | ✅ |
| `A.07` | [HAL: inventario de drivers y tipos de credencial](anexos/A.07_HAL-INVENTARIO-DRIVERS.md) | 3.01, 3.02 | ✅ |
| `A.08` | Contrato bilateral bhnexus ↔ bAuth | 2.02, 6.01 | ✅ |
| `A.09` | [Seguridad: mTLS, SPIFFE, AES-256-GCM, canal privilegiado threat model, Wazuh 12 reglas](anexos/A.09_SEGURIDAD-MTLS-AES.md) | 7.02 | ✅ |

> **A.08** vive en `context/contracts/BHNEXUS-BAUTH-CONTRATOS.md` (decisión HITL H-01).  

---

## Estado Sprint

| Sprint | Documentos | Estado |
|--------|-----------|:------:|
| **Sprint 1** — Topología + Conectividad (13 docs) | 0.00, INDICE, MOTORES-INDEX, 1.01, 1.03, 1.05, 1.06, 2.01, 2.02, A.02, A.03, A.04, A.05 | ✅ COMPLETO |
| **Sprint 2** — Base topológica + Resiliencia (11 docs) | 1.02, 1.04, 2.03, 2.04, 5.01, 5.02, 5.03, 6.01, A.01, A.06, A.08 | ✅ COMPLETO |
| **Sprint 3** — Hardware & Intercepción (7 docs) | 3.01, 3.02, 3.03, 4.01, 4.02, 4.04, A.07 | ✅ COMPLETO |
| **Sprint 4** — Normas, Operación & Producto (14 docs) | 7.01, 7.02, 7.03, 7.04, 6.02, 6.03, 9.01, 6 MOTORES/, A.09 | ✅ COMPLETO |

---

**Total de documentos:** 49 (incluyendo INDICE + MOTORES-INDEX + A.08 externo)  
**Corpus completo:** ✅ CERRADO — todos los Sprints 1-4 completados

---

*SKULL · SBOS · bNexus · INDICE · v2.0.0 · Agosto 2026*
