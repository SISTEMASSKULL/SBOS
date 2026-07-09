---
codigo: BNOTIFY-005
version: 1.4.0
estado: BORRADOR
gate: G0
depende_de: [BNOTIFY-000]
doctrina_que_ejerce: [D14]
criterio_implementado: >
  Todo documento BNOTIFY-0XX tiene entrada en este índice con estado correcto.
  El grafo de dependencias no tiene ciclos. Un agente puede resolver
  "por dónde empezar" para cualquier tarea consultando solo este archivo.
  Este documento se actualiza en el mismo commit que cualquier otro BNOTIFY-0XX.
---

# BNOTIFY-005 — Navegador de Documentos
## Índice maestro del proyecto bNotify · legible por humano y máquina

**Versión:** 1.4.0 · **Gate:** G0 · **Estado:** BORRADOR
**Regla:** este documento se actualiza en el mismo commit que cualquier BNOTIFY-0XX.
Un navegador desactualizado es peor que ninguno.

---

## Cómo usar este documento

**Si eres un agente comenzando una sesión:** lee BNOTIFY-000 (doctrina) y este archivo.
Con ambos tienes el mapa completo del proyecto. Ningún otro documento es prerequisito
para empezar — pero sí para implementar.

**Si buscas un concepto de dominio:** BNOTIFY-009 (Glosario).
**Si buscas la versión fijada de una librería:** BNOTIFY-006 (Stack).
**Si vas a agregar una dependencia o apartarte de un documento aprobado:** BNOTIFY-007 (ADRs).
**Si vas a tocar la base de datos:** BNOTIFY-008 (DDL Esquemas).
**Si vas a implementar un canal nuevo:** BNOTIFY-010 (Núcleo) → el canal correspondiente 01X.
**Si vas a implementar un módulo/mini-app:** BNOTIFY-040 (Manifiesto y Catálogo).

---

## Grafo de dependencias (G0)

```
BNOTIFY-000 (Doctrina — Ivan/SKULL)
    ├── BNOTIFY-005 (este documento)
    ├── BNOTIFY-090 (Gobernanza)
    ├── BNOTIFY-006 (Stack)
    ├── BNOTIFY-007 (ADRs)
    ├── BNOTIFY-009 (Glosario)
    ├── BNOTIFY-001 (Contrato gRPC)
    │       ├── BNOTIFY-002 (OIDC bAuth) ──► desbloquea bRocket
    │       │       ├── BNOTIFY-003 (bRocket despliegue)
    │       │       └── BNOTIFY-008 (DDL Esquemas)
    │       ├── BNOTIFY-004 (Modelo eventos y auditoría)
    │       └── BNOTIFY-010 (Núcleo orquestador)
    │               ├── BNOTIFY-011 (Canal chat)
    │               ├── BNOTIFY-012 (Canal email)
    │               ├── BNOTIFY-013 (Canal SMS)
    │               ├── BNOTIFY-014 (Canal push)
    │               └── BNOTIFY-015 (Canal webhook exterior)
    └── BNOTIFY-030 (bChat protocolo cliente) ──► gate G2
            ├── BNOTIFY-031 (bChat esquema datos)
            ├── BNOTIFY-032 (bChat motor Rust)
            │       ├── BNOTIFY-033 (bChat cliente Flutter)
            │       ├── BNOTIFY-034 (bChat media)
            │       ├── BNOTIFY-035 (bChat LiveKit)         ──► gate G3
            │       └── BNOTIFY-036 (Migración bRocket→bChat) ──► gate G3
            ├── BNOTIFY-040 (Módulos manifiesto)
            │       ├── BNOTIFY-041 (Runtime WASM)
            │       ├── BNOTIFY-042 (Módulo atención cliente)
            │       ├── BNOTIFY-043 (Motor formularios)
            │       ├── BNOTIFY-044 (Módulo correo)
            │       └── BNOTIFY-045 (Módulos terceros/marketplace) ──► gate G4
            └── BNOTIFY-060 (E2EE MLS)                     ──► gate G5
                    ├── BNOTIFY-061 (Antiabuso y moderación)
                    └── BNOTIFY-062 (KYC Tiers y valor)
```

---

## Catálogo completo BNOTIFY-0XX

### Bloque 000 — Doctrina (gate G0)

| Código | Nombre | Estado | Resumen |
|--------|--------|:------:|---------|
| BNOTIFY-000 | DOCTRINA-Y-PLAN-MAESTRO | ✅ APROBADO | Principios D1-D18, arquitectura del programa, gates, anexos WeChat y anatomía Rocket.Chat |

### Bloque 005–009 — Capa para agentes de IA (gate G0)

| Código | Nombre | Estado | Resumen |
|--------|--------|:------:|---------|
| BNOTIFY-005 | NAVEGADOR-DE-DOCUMENTOS | 📝 BORRADOR | Este archivo: índice vivo, grafo de dependencias, guía "por dónde empezar" |
| BNOTIFY-006 | STACK-TECNOLOGICO | 📝 BORRADOR | Lista canónica con versiones fijadas de todo el stack del proyecto |
| BNOTIFY-007 | ADR-REGISTRO-DE-DECISIONES | 📝 BORRADOR | ADRs retro-documentados desde BNOTIFY-000 + registro de decisiones futuras |
| BNOTIFY-008 | DDL-ESQUEMAS-DE-DATOS | 📝 BORRADOR | DDL del clúster: esquemas por dueño, vistas de solo lectura cruzadas, migraciones |
| BNOTIFY-009 | GLOSARIO-Y-ONTOLOGIA | 📝 BORRADOR | Vocabulario de dominio estable: ctx_id, átomo, intent, canal, adaptador… |
| BNOTIFY-090 | GOBERNANZA-DOCUMENTAL-Y-DE-AGENTES | 📝 BORRADOR | Plantilla YAML, estados, versionado, ciclo spec→plan→tareas, definición de terminado |

### Bloque 00X — Fundación técnica (gate G0)

| Código | Nombre | Estado | Resumen |
|--------|--------|:------:|---------|
| BNOTIFY-001 | CONTRATO-GRPC-ORQUESTADOR-ADAPTADORES | 📝 BORRADOR | Proto del evento común: ctx_id, destinatario, plantilla, urgencia, canales, TTL, respuesta |
| BNOTIFY-002 | BAUTH-OIDC-SUPERFICIE-D9 | 📝 BORRADOR | Endpoints OIDC de bAuth (authorize/token/userinfo/jwks), claims, CAEP, CONSUMER_MOBILE |
| BNOTIFY-003 | BROCKET-DESPLIEGUE-INTERINO | 📝 BORRADOR | RC CE 8.x en K8s: MongoDB, S3, OIDC contra bAuth verificado, regla D7 (solo config) |
| BNOTIFY-004 | MODELO-EVENTOS-Y-AUDITORIA | 📝 BORRADOR | Taxonomía eventos (chat.*, notify.*, identity.*), clases A/B/C, pipeline aud_event |

### Bloque 01X — bNotify núcleo y canales (gates G1–G2)

| Código | Nombre | Estado | Resumen |
|--------|--------|:------:|---------|
| BNOTIFY-010 | NUCLEO-ORQUESTADOR | 📝 BORRADOR | Motor Rust: pipeline validate→dedup→check→rate→resolve→queue, workers A/B/C, CAEP, plantillas |
| BNOTIFY-011 | CANAL-CHAT | 📝 BORRADOR | Adaptador chat: bRocket REST encapsulado (G1), bChat gRPC (G3); webhook inverso RC→NATS |
| BNOTIFY-012 | CANAL-EMAIL | 📝 BORRADOR | Adaptador Postfix/Dovecot, multipart HTML/texto, DKIM obligatorio |
| BNOTIFY-013 | CANAL-SMS | 📝 BORRADOR | Adaptador Jasmin/Kannel SMPP, solo salida, E.164, anti-abuso |
| BNOTIFY-014 | CANAL-PUSH | 📝 BORRADOR | FCM v1, APNs .p8, UnifiedPush/ntfy, PushKit reservado para llamadas bChat |
| BNOTIFY-015 | CANAL-WEBHOOK-EXTERIOR | 📝 BORRADOR | CloudEvents 1.0 sobre HTTPS, firma Ed25519, solo HTTP legítimo del núcleo |

### Bloque 03X — bChat motor propio (gates G2–G3)

| Código | Nombre | Estado | Resumen |
|--------|--------|:------:|---------|
| BNOTIFY-030 | BCHAT-PROTOCOLO-CLIENTE | 📝 BORRADOR | WS + JSON-RPC 2.0, suscripciones, deltas, secuencia anti-gap, reconciliación multi-dispositivo |
| BNOTIFY-031 | BCHAT-ESQUEMA-DATOS | 📝 BORRADOR | PostgreSQL: salas, mensajes, membresías, particionado, FTS, retención |
| BNOTIFY-032 | BCHAT-MOTOR-RUST | 📝 BORRADOR | Axum/Tokio, NATS, presencia, bAuth nativo (átomos + ctx_id + step-up) |
| BNOTIFY-033 | BCHAT-CLIENTE-FLUTTER | 📝 BORRADOR | Un código base todas las plataformas, Material 3, notify integrado tipo WhatsApp |
| BNOTIFY-034 | BCHAT-MEDIA | 📝 BORRADOR | Pipeline medios: MinIO S3 soberano, URL pre-firmadas, miniaturas, límites por tier |
| BNOTIFY-035 | BCHAT-LIVEKIT | 📝 BORRADOR | Llamadas 1:1, voz, salas tipo Meet sobre SDK LiveKit 1.8.x + cliente Flutter |
| BNOTIFY-036 | MIGRACION-BROCKET-A-BCHAT | 📝 BORRADOR | Usuarios, historial, doble-corrida 72h, apagado bRocket — ejecuta gate G3 |

### Bloque 04X — Sistema de módulos (gates G3–G4)

| Código | Nombre | Estado | Resumen |
|--------|--------|:------:|---------|
| BNOTIFY-040 | MODULOS-MANIFIESTO-Y-CATALOGO | 📝 BORRADOR | Contrato del manifiesto TOML, registro RPC, catálogo versionado, estados, gobernanza |
| BNOTIFY-041 | MODULOS-RUNTIME-WASM | 📝 BORRADOR | wasmtime 28.0.x embebido: capacidades declaradas, sandbox, carga en caliente, límites CPU/memoria |
| BNOTIFY-042 | MODULO-ATENCION-CLIENTE | 📝 BORRADOR | Bandeja omnichannel first-party: cola, agentes, transferencias, métricas, widget web |
| BNOTIFY-043 | MODULOS-MOTOR-FORMULARIOS | 📝 BORRADOR | Formularios declarativos DSL JSON: definición, render Flutter, respuestas como eventos bNotify |
| BNOTIFY-044 | MODULO-CORREO | 📝 BORRADOR | Etapa 1 Roundcube 1.6.x SSO; etapa 2 cliente nativo IMAP/JMAP (decisión por datos reales) |
| BNOTIFY-045 | MODULOS-TERCEROS-Y-MARKETPLACE | 📝 BORRADOR | Apertura a terceros: SDK WASM, revisión/firma SKULL, marketplace, revocación global |

### Bloque 06X — Grado consumo masivo (gate G5)

| Código | Nombre | Estado | Resumen |
|--------|--------|:------:|---------|
| BNOTIFY-060 | E2EE-MLS | 📝 BORRADOR | MLS/RFC 9420 con OpenMLS o mls-rs: DS propio, multi-dispositivo, server-blind |
| BNOTIFY-061 | ANTIABUSO-Y-MODERACION | 📝 BORRADOR | Átomos REGLA, rate limits por tier, strikes, workflow reportes, rendición de cuentas WORM |
| BNOTIFY-062 | KYC-TIERS-Y-VALOR | 📝 BORRADOR | Niveles T0/T1/T2 (IAL1-3), límites D3 por tier, integración bPay en conversación |

### Bloque 07X–09X — Transversales

| Código | Nombre | Estado | Resumen |
|--------|--------|:------:|---------|
| BNOTIFY-070 | CAPACIDAD-Y-PRUEBAS-DE-CARGA | 📝 BORRADOR | Objetivos numéricos G1/G2/G3/G5 por componente, pipeline k6 en CI, modelos de capacidad publicados |
| BNOTIFY-071 | OPERACIONES-K8S | 📝 BORRADOR | systemd unit, Vault secrets, Grafana 6 paneles core, Helm charts, runbooks, respaldos |
| BNOTIFY-090 | GOBERNANZA-DOCUMENTAL-Y-DE-AGENTES | 📝 BORRADOR | Plantilla YAML, ciclo spec→plan→tareas, definición de terminado verificable por máquina |

---

## Estados posibles

| Símbolo | Estado | Significado |
|:-------:|--------|-------------|
| ✅ | APROBADO | Ivan aprobó — puede implementarse |
| 📝 | BORRADOR | Redactado, pendiente revisión |
| 🔄 | EN REVISIÓN | En proceso de revisión por Ivan |
| ⏳ | PENDIENTE | Aún no redactado |
| 🔨 | IMPLEMENTANDO | Código en curso |
| 📦 | ENTREGADO | Implementado y verificado en VPS |
| 🚫 | OBSOLETO | Reemplazado por otro documento |

---

*BNOTIFY-005 v1.4.0 · BnotifyAgent/context/ · 2026-07-06 · 23 documentos BNOTIFY-0XX redactados (todos en BORRADOR) · Se actualiza con cada commit que toque un BNOTIFY-0XX*
