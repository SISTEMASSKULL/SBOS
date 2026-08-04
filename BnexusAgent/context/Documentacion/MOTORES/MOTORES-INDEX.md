# Motores de bNexus — Índice
### SKULL · SBOS — Motor de Conectividad & Edge Física

**Versión:** 1.0.0  
**Fecha:** 2026-08-04  

Un **motor** es la capacidad técnica central que da nombre a una capa o función de bNexus. Cada portada de motor define el verbo que ejecuta, los manuales que lo describen, y las métricas que lo observan.

---

## Mapa de motores

| Motor | Verbo | Capa | Manual primario | Estado |
|-------|-------|------|-----------------|:------:|
| **Conectividad-Agentes** | Recibir agentes (Puerta 1) | bhnexus | `2.01_MANUAL-PUERTA-1-AGENTES.md` | ⬜ portada |
| **Conectividad-bAuth** | Resolver identidad (Puerta 2) | bhnexus ↔ bAuth | `2.02_MANUAL-PUERTA-2-BAUTH.md` | ⬜ portada |
| **Hardware** | Normalizar señales físicas | bhnexus HAL | `3.01_MANUAL-HAL.md` | ⬜ portada |
| **Cache** | Cachear decisiones | bhnexus + banexus | `5.01`, `5.02` | ⬜ portada |
| **Intercepción** | Interceptar en borde | banexus | `4.01_MANUAL-INPUT-HOOKING.md` | ⬜ portada |
| **Actuación** | Actuar sobre hardware | banexus | `4.03_MANUAL-ACTUATOR-CONTROLLER.md` | ⬜ portada |

---

## Relación entre motores

```
Motor Conectividad-Agentes (Puerta 1)
  recibe credencial de banexus
        │
        ▼
Motor Conectividad-bAuth (Puerta 2)
  consulta SAM-128 a bAuth
        │          ▲
        │          │ canal privilegiado (push bAuth → bhnexus)
        ▼          │
Motor Cache (bhnexus)
  SAM-128 → cache hit/miss
        │
        ▼ cache miss
Motor Conectividad-bAuth (Puerta 2)
  obtiene SAM-128 de bAuth → almacena en cache
        │
        ▼ SAM-128 resuelto
Motor Conectividad-Agentes (Puerta 1)
  envía auth_response + actuator_commands a banexus
        │
        ▼
Motor Intercepción (banexus)
  capturó la credencial — inició el flujo
        │
Motor Actuación (banexus)
  ejecuta actuator_commands en hardware físico
```

Motor Hardware es independiente: normaliza el hardware mudo local (OSDP, MQTT, ONVIF) en paralelo, sin pasar por banexus.

---

*SKULL · SBOS · bNexus · MOTORES-INDEX · v1.0.0 · Agosto 2026*
