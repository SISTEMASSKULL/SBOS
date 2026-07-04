# SBOS-008-INTEGRATION
## Mapa de Integraciones — Estandar HUMAN-DOC (Enriquecido V8)
### SKULL · SBOS v1.1-V8 · Mayo 2026

---

## 1. Bus de Eventos Interno

**Mecanismo:** PostgreSQL WAL (Write-Ahead Log) con replicacion logica (pgoutput)
**Patron:** Event-driven, Change Data Capture (CDC)

| Slot WAL | Daemon consumidor | Escucha | Publicaciones |
|---|---|---|---|
| bkernel_slot | bKernel | Todas las apps del stack | tryton_db, orangehrm_db, saleor_db, espocrm_db |
| biedata_slot | biedata | Triggers de integracion exterior | Tablas especificas tryton_db (facturas, comprobantes) |
| bcompass_slot | bCompass | Eventos para analisis | tryton_db (ventas, inventario, contabilidad) |

**Canal secundario:** Redis pub/sub para notificaciones en tiempo real (no persistentes).
**Canal WebSocket:** Centrifugo OSS v6 para comunicacion con Core UI y SBOS VDI.

---

## 2. Contratos Inter-Daemon

| Origen | Destino | Protocolo | Mecanismo | Auth |
|---|---|---|---|---|
| bKernel | Tryton | SQL directo (Writer Pool) | UPSERT idempotente | PostgreSQL role bkernel |
| bKernel | Keycloak | REST API | POST /admin/realms/{realm}/users | Service account JWT |
| bKernel | Redis | PUBLISH | Canal bkernel:events | Local socket |
| biedata | SIN Bolivia | SOAP/REST | API SIAT (52 sectores) | Certificado digital + CUIS/CUFD |
| biedata | AFIP Argentina | SOAP | Web Services AFIP | Certificado digital |
| biedata | SAT Mexico | REST | CFDI 4.0 API | Certificado e.firma |
| bCompass | Ollama | HTTP | POST /api/generate | Local (sin auth) |
| bCompass | Qdrant | gRPC | Collections API | API key |
| bSearch | Typesense | HTTP | Documents API | API key |
| bAuth | Keycloak | REST | Admin API + Events API | Service account |
| bAuth | Tryton | XML-RPC | party.party, user.user | Service account |
| bhnexus | Centrifugo | WebSocket | Publish/Subscribe channels | JWT |
| bhnexus | banexus | WebSocket + mTLS | Protocolo monogamico | mTLS certificado |
| IAM Installer | K8s API | HTTPS | kubectl apply (via sbos_k8s_core()) | ServiceAccount installer-sa |
| IAM Installer | Core UI | WebSocket | Eventos en tiempo real | JWT |
| IAM Installer | Release Plane | HTTPS (pull-only) | GET /api/v1/catalog | Ed25519 signature |

---

## 3. APIs Externas Consumidas

| Servicio | Proveedor | Protocolo | Auth | Daemon responsable |
|---|---|---|---|---|
| SIAT Bolivia | SIN (Servicio de Impuestos Nacionales) | SOAP/REST | Certificado + CUIS/CUFD | biedata |
| AFIP Argentina | AFIP (Administracion Federal) | SOAP | Certificado digital | biedata |
| SAT Mexico | SAT (Servicio de Administracion Tributaria) | REST (CFDI 4.0) | e.firma (FIEL) | biedata |
| SKULL Release Plane | SKULL (interno) | HTTPS | Ed25519 | IAM Installer |
| Let's Encrypt | ISRG | ACME | Automatico | cert-manager |

---

## 4. APIs Internas Expuestas

| API | Expuesta por | Consumida por | Protocolo | Gateway |
|---|---|---|---|---|
| /api/v1/installer/* | IAM Installer Backend | Core UI | REST + WebSocket | Kong |
| /api/v1/fichas/* | IAM Installer Backend | Core UI | REST | Kong |
| /realms/{realm}/.well-known/openid-configuration | Keycloak | Todas las apps | OIDC | Kong |
| /api/v1/search/* | bSearch | Core UI, SBOS VDI | REST | Kong |
| /api/v1/compass/* | bCompass | Core UI | REST | Kong |

---

## 5. Reglas de Comunicacion

1. biedata es el UNICO actor con acceso a red exterior (NetworkPolicy)
2. bCompass es el UNICO que invoca Ollama
3. Ningun BC lee directamente la BD de otro — todo via bKernel o API publica
4. Daemons no se llaman entre si — se comunican via WAL y Redis

---

## 6. Secrets y Credenciales

| Secret | Almacenado en | TTL | Rotacion |
|---|---|---|---|
| DB passwords | Vault | 30 dias | Automatica |
| JWT signing keys | Keycloak | — | Manual (RSA) |
| Certificados TLS | cert-manager | 90 dias | Automatica (Let's Encrypt) |
| Ed25519 keys (Release) | Vault | — | Manual |
| API keys (Qdrant, Typesense) | Vault | 90 dias | Automatica |
| Certificados tributarios | Vault | Segun entidad | Manual |

---

## 7. Catalogo de Eventos WAL por Bounded Context

Eventos emitidos por cada BC al WAL de PostgreSQL. bKernel los consume via slot y ejecuta las reglas YAML correspondientes.

### BC-01 — Financiero-Contable (Tryton)

| Evento | Tabla fuente | Condicion | Reglas bKernel asociadas |
|---|---|---|---|
| tryton.invoice.confirmed | account_invoice | state → 'posted' | CORE-005 → biedata SIAT/AFIP/SAT, CORE-006 si pago |
| tryton.payment.done | account_payment | state → 'succeeded' | CORE-006 → liberar inventario |
| tryton.purchase.created | purchase_purchase | INSERT | — |
| tryton.purchase.confirmed | purchase_purchase | state → 'confirmed' | Actualizar stock previsto |
| tryton.period.closed | account_period | state → 'close' | CORE-007 → notificar bCompass para analisis fiscal |
| tryton.product.updated | product_product | UPDATE list_price | CORE-004 → sincronizar Saleor catalogo |

### BC-02 — RRHH (OrangeHRM)

| Evento | Tabla fuente | Condicion | Reglas bKernel asociadas |
|---|---|---|---|
| orangehrm.employee.created | hs_hr_employee | INSERT | CORE-001 → Tryton party + KC usuario + Postfix buzon + Rocket.Chat |
| orangehrm.employee.terminated | hs_hr_employee | UPDATE emp_status='terminated' | CORE-002 → KC deshabilitar + Tryton inactivo + Postfix archivar |
| orangehrm.employee.updated | hs_hr_employee | UPDATE (nombre, email, depto) | OHRM-001 → sync Tryton party |
| orangehrm.leave.approved | ohrm_leave_request | UPDATE status='approved' | Notificar Rocket.Chat canal depto |

### BC-03 — Ventas y CRM (Saleor + EspoCRM)

| Evento | Tabla fuente | Condicion | Reglas bKernel asociadas |
|---|---|---|---|
| espocrm.customer.created | espocrm_accounts | INSERT | ESPO-001 → UPSERT Tryton party.party |
| espocrm.opportunity.won | espocrm_opportunities | UPDATE stage='Closed Won' | Crear borrador sale.sale en Tryton |
| saleor.order.placed | order_order | INSERT estado UNCONFIRMED | SAL-001 → verificar stock Tryton |
| saleor.order.paid | order_order | UPDATE status='PAID' | SAL-003 → crear factura borrador en Tryton |
| saleor.order.cancelled | order_order | UPDATE status='CANCELLED' | SAL-004 → liberar reserva stock Tryton |

### BC-04 — Identidad (Keycloak + bAuth)

| Evento | Tabla fuente | Condicion | Reglas bKernel asociadas |
|---|---|---|---|
| keycloak.user.created | user_entity (KC) | INSERT | ROLF-001 → bAuth sync RolTemplate |
| keycloak.user.disabled | user_entity (KC) | UPDATE enabled=false | Notificar bhnexus → BitMask a cero |
| keycloak.session.started | offline_user_session | INSERT | Registro auditoria bauth_db |
| keycloak.role.assigned | user_role_mapping | INSERT | bAuth recalcular BitMask |
| bos_bauth_template.updated | bos_core (PG) | INSERT/UPDATE | ROLF-001 → bAuth sincronizar KC + Tryton |

### BC-05 — Comunicaciones (solo consume, no emite eventos WAL propios)

| Consume desde | Para que |
|---|---|
| orangehrm.employee.created | Crear buzon Postfix + Dovecot + canal Rocket.Chat |
| keycloak.user.disabled | Deshabilitar buzon + archivar canal |
| orangehrm.employee.terminated | Redirigir correo al jefe + transferir archivos Nextcloud |

### BC-06 — Reportes e Inteligencia (solo lectura, sin eventos propios)

BC-06 es conformist puro — consume replica PostgreSQL en solo lectura. No emite eventos WAL. Los DAGs de Airflow leen datos directamente, no via bKernel.

### BC-07 — IA Soberana

| Evento | Canal | Condicion | Destino |
|---|---|---|---|
| embedding_requested | Redis ai:embed_queue | bKernel enqueue_embedding | Embedding Worker → Qdrant |
| bcompass.suggestion.created | bcompass_db WAL | INSERT bcompass_proposals | Notificar Core UI via Centrifugo |

### BC-08 — Integracion Exterior (biedata)

biedata produce escrituras en las BDs de destino con origin='biedata'. Estas escrituras generan eventos WAL que bKernel procesa normalmente (con antiloop via pg_replication_origin).

### BC-09 — Plataforma (IAM Installer + K8s)

| Evento | Fuente | Destino |
|---|---|---|
| ficha.installed | .sbos_state.json | bKernel configura reglas de la nueva app |
| ficha.health.degraded | HEALTH_CHECKER | Core UI via Centrifugo + Alertmanager |
| bkernel.rule.added | servers/ filesystem watch | bKernel hot-reload sin reiniciar |

---

## 8. Tabla de Decision de Canal por Caso de Uso

Extraido de SBOS-030-BOUNDED-CONTEXTS §4.

| Caso de uso | Canal correcto | Garantia | Latencia |
|---|---|---|---|
| App escribe en PG → sync otra app | WAL + bKernel | At-least-once | < 500ms P99 |
| Nuevo documento → indexar bSearch | Redis Stream bkernel:index_queue | At-least-once | < 1s |
| Nuevo dato → vectorizar Qdrant | Redis Stream ai:embed_queue | At-least-once | < 2s |
| Notificacion real-time usuario | Centrifugo WebSocket | Best-effort | < 100ms |
| Workflow multi-paso con aprobacion | bCompass route | Exactly-once + compensacion | Variable (HITL) |
| Evento seguridad | Wazuh agent | Best-effort + SIEM | < 5s |
| Sync roles KC | bAuth API call | Exactly-once (transaccional) | < 2s |
| Integracion sistema externo | biedata caja | At-least-once + validacion | Variable |
| Alerta operacional | Alertmanager → Mattermost/email | At-least-once | < 30s |

**Regla rapida:** Dato interno entre apps? → bKernel WAL. Notificacion al usuario? → Centrifugo. Dato desde/hacia exterior? → biedata. Workflow con aprobacion? → bCompass.

---

## 9. V7 Enriquecimiento — Integracion del Par Nexus Soberano (NEXUS-CONCEPTUALIZACION)

El V7 define el flujo de integracion entre bhnexus y banexus como un canal de comunicacion especializado:

```
banexus (Fedora VDI)
  | 1. Usuario inserta chapa USB en lector
  | 2. banexus captura evento USB via interceptor udev
  | 3. banexus evalua PhysicalDomainMask local (cache)
  | 4. Si cache miss: solicita evaluacion a bhnexus
  v
bhnexus (Host Ubuntu)
  | 5. bhnexus recibe solicitud WSS :9444
  | 6. bhnexus evalua PhysicalDomainMask contra bAuth
  | 7. bhnexus responde: GRANTED | DENIED + BitMask actualizado
  v
banexus (Fedora VDI)
  | 8. banexus aplica decision: abre chapa / deniega / registra
  | 9. banexus registra audit_event en bkernel_db via WAL
  v
bKernel (Host Ubuntu)
  | 10. bKernel procesa evento WAL de auditoria fisica
  | 11. bKernel notifica a bCompass si hay patron anomalo
```

Este flujo se suma a los contratos inter-daemon como un canal de integracionbi-direccional con requisitos de latencia <15ms y encriptacion mTLS obligatoria.

---

## 10. Smart* Enriquecimiento — Patrones de Integracion de Subproyectos

### SmartORC — Integracion con el ecosistema SBOS (BOSORC-001-VISION, BOSORC-002-DOMINIO)

| Integracion | Con quien | Mecanismo | Evento |
|---|---|---|---|
| Recepcion de correspondencia | bKernel | WAL - bkernel_slot | orangehrm.employee.created (desencadena buzon) |
| Firma biometrica | Keycloak | WebAuthn Level 2 + Passkeys | keycloak.session.started |
| Transferencia de custodia | bhnexus + banexus | Context Plane (ctx_id) | Registro en bkernel_db |
| Handover a bvault | bKernel | WAL - evento despacho | transicion ORC → bvault |
| Trazabilidad fiscal | Tryton | WAL - cms_correspondence | hoja_ruta vinculada a factura |

### SmartVaultFlow — Integracion documental (SBOS-VAULT-001-VISION, SBOS-VAULT-005-INTEGRACIONES)

| Integracion | Con quien | Mecanismo | Evento |
|---|---|---|---|
| Ingesta documental | bKernel | WAL - bkernel_slot | documento.ingested |
| Busqueda de activos | bSearch | REST API /api/v1/search/* | busqueda.activada |
| Flujo de aprobacion | Keycloak | WebAuthn (cada firma) | aprobacion.registrada |
| Ventanilla Virtual | biedata | Canal exterior controlado | entrega.notificada |
| Archivo de claves RSA | bKernel | WAL - evento de archivo | clave.rotada.almacenada |

### SmartPay — Integracion financiera (SBOS-PAY-005-INTEGRACIONES)

| Integracion | Con quien | Mecanismo | Evento |
|---|---|---|---|
| Pago confirmado | bKernel | WAL → Tryton factura | payment.confirmed |
| Verificacion QR | Redis | Cache de sesion QR | qr.generated |
| Notificacion de pago | Centrifugo | WebSocket a Core UI | payment.notification |
| Conciliacion bancaria | biedata | Caja de integracion exterior | batch.conciliated |

### SmartTax — Integracion fiscal (SBOS_TAX_SBOS-MANUAL-ACOPLAMIENTO.md)

| Integracion | Con quien | Mecanismo | Evento |
|---|---|---|---|
| Emision factura SIAT | biedata | Caja SIAT SOAP | factura.enviada.siat |
| Validacion invariantes | bKernel | Regla CORE-005 pre-envio | invariante.validada |
| Consulta NIT | biedata | SIAT REST API | nit.consultado |
| Reporte fiscal | bCompass | Route de analisis fiscal | periodo.cerrado.analisis |

---

## Trazabilidad

| Seccion | Extraida de | Secciones originales |
|---|---|---|
| §1 Bus | SBOS-002 v4.0, SBOS-010 v7.0 | §3 WAL, §WAL slots |
| §2 Contratos | SBOS-010, 011, 014, 008, 035, 037, 005, 038 | Protocolos inter-daemon |
| §3 APIs ext | SBOS-011-Tributario | §SIAT, §AFIP, §SAT |
| §4 APIs int | SBOS-007, SBOS-018-API | §API Gateway, §endpoints |
| §5 Reglas | SBOS-002 v4.0 | §16 Fronteras |
| §6 Secrets | SBOS-023 v1.0, SBOS-004 v4.0 | §Vault, §secrets |
| §7 Catalogo WAL | SBOS-030-BOUNDED-CONTEXTS v1.0 | §2 BC-01 a BC-09 |
| §8 Tabla decision | SBOS-030-BOUNDED-CONTEXTS v1.0 | §4 Tabla de decision de canal |
| §9 V7 | BOS_V7_SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md | Flujo de integracion bhnexus↔banexus, 11 pasos |
| §10 Smart* | BOSORC-001-VISION, SBOS-VAULT-005-INTEGRACIONES, SBOS-PAY-005-INTEGRACIONES, SBOS_TAX_SBOS-MANUAL-ACOPLAMIENTO.md, SBOS-Portfolio-005-INTEGRACIONES, BVAULT-001-ACOPLAMIENTO, BOSCMS-005-INTEGRACIONES | Patrones de integracion por subproyecto |

---

## Fuentas de Enriquecimiento V8

| Fuente | Tipo | Contenido aportado |
|---|---|---|
| BOS_V6_SBOS-008-INTEGRATION.md | V6 (canonico) | Contenido base completo preservado |
| BOS_V7_SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md | V7 | Flujo de integracion Par Nexus en 11 pasos |
| BOSORC-001-VISION.md (Smart ORC) | Smart* | Integracion ORC con bKernel, Keycloak, bvault |
| SBOS-VAULT-005-INTEGRACIONES.md (Smart Vault Flow) | Smart* | Integracion vault con bSearch, biedata, bKernel |
| SBOS-PAY-005-INTEGRACIONES.md (Smart Pay) | Smart* | Integracion pagos con bKernel, Centrifugo, biedata |
| SBOS_TAX_SBOS-MANUAL-ACOPLAMIENTO.md (Smart Tax) | Smart* | Integracion fiscal con biedata, SIAT, bKernel |
| SBOS-Portfolio-005-INTEGRACIONES.md (Smart Portfolio) | Smart* | Integracion de portafolio |
| BOSCMS-005-INTEGRACIONES.md (SBOS CMS) | Smart* | Integracion de CMS |
| BVAULT-001-ACOPLAMIENTO.md (Smart Vault Flow) | Smart* | Manual de acoplamiento bvault |

---

_SKULL · SBOS · SBOS-008-INTEGRATION · HUMAN-DOC v1.1-V8 · Mayo 2026_
_Enriquecimiento V8: V7 flujo de integracion Par Nexus (11 pasos) + Smart* patrones de integracion por subproyecto_
