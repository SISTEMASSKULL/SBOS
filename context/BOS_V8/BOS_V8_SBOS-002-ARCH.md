# SBOS-002-ARCH
## Arquitectura General — Estandar HUMAN-DOC (Enriquecido V8)
### SKULL · SBOS v1.0-V8 · Mayo 2026

---

## 1. Modelo Arquitectonico

SBOS es un sistema operativo empresarial. La analogia con un SO convencional es tecnicamente precisa:

| SO Convencional | SBOS |
|---|---|
| Hardware | PostgreSQL (WAL) |
| Kernel (Linux) | bKernel (daemon de consolidacion) |
| Procesos / Aplicaciones | Fichas del BOS (110+ apps) |
| Shell / Interfaz | SBOS VDI + Core UI |
| Gestion de identidad | Keycloak (gobierno central) |
| Instalador del SO | IAM Installer (construye su propia plataforma) |
| Init system (systemd) | IAM Installer como systemd |
| Package manager (apt) | Sistema de fichas SBOS |
| Subsistema de E/S | biedata (integracion exterior) |
| Procesador de senales | bCompass (inteligencia y orquestacion) |

Diferencia clave vs. SAP/Oracle/Microsoft 365: esos sistemas son kernel Y aplicaciones. SBOS es solo el kernel — las aplicaciones son open source e intercambiables.

### V5 Enriquecimiento — Profundizacion del modelo OS

La documentacion V5 enfatiza que los daemons soberanos son **la razon por la que el SBOS no necesita Kafka, n8n, ni ningun middleware externo de mensajeria**. El WAL de PostgreSQL es su bus de eventos. Los daemons son sus consumidores soberanos. Esta distincion es critica y debe comprenderse antes de leer cualquier otro documento arquitectonico.

---

## 2. Decision Fundacional — WAL como Event Bus Nativo

El SBOS NO usa Kafka, RabbitMQ, Redis Streams, n8n, ni middleware de mensajeria externo. El Write-Ahead Log (WAL) de PostgreSQL es el bus de eventos nativo.

| Propiedad | Kafka | RabbitMQ | PostgreSQL WAL |
|---|---|---|---|
| Cero invasion a las apps | No | No | **Si** |
| Ordering estricto | Por particion | No garantizado | **Si (LSN)** |
| Durabilidad nativa | Si | Opcional | **Si** |
| Infraestructura adicional | Zookeeper/KRaft + brokers | Nodes + VHosts | **Nada** |
| Event sourcing nativo | Si | No | **Si** |
| CDC nativo | Via Debezium | No | **Nativo (pgoutput)** |
| Acceso desde host sin red K8s | No | No | **Si (socket Unix)** |

### Consecuencias arquitectonicas
1. Daemons comparten bus sin coordinacion entre ellos
2. Nuevo daemon no requiere modificar ninguna app
3. Orden causal garantizado por LSN — sin race conditions
4. Mensajeria falla solo si PostgreSQL falla (HA Patroni 3 nodos)
5. n8n, Zapier, Make explicitamente excluidos (violan cero invasion + licencias)

---

## 3. Las 5 Capas del Sistema

```
+-------------------------------------------------------------+
|  CAPA DE USUARIO                                     [K8s]  |
|  Core UI (Flutter) · SBOS VDI (Fedora KDE / Kasm)           |
+-------------------------------------------------------------+
|  CAPA DE GOBIERNO                                    [K8s]  |
|  Keycloak · Vault · Kong API Gateway                        |
+-------------------------------------------------------------+
|  CAPA DE APLICACIONES                                [K8s]  |
|  erpserver · appsserver · commsserver · docserver ·          |
|  reportserver · searchserver · geoserver · aiserver          |
+-------------------------------------------------------------+
|  CAPA DE DATOS                                       [K8s]  |
|  PostgreSQL (Patroni HA 3 nodos) · Redis · MinIO            |
|  WAL → bkernel_slot · biedata_slot · bcompass_slot          |
+-------------------------------------------------------------+
|  CAPA DAEMONS SOBERANOS                          [systemd]  |
|  bkernel · biedata · bcompass · bsearch · bauth · bhnexus   |
+-------------------------------------------------------------+
|  CAPA DE INFRAESTRUCTURA                                     |
|  IAM Installer [systemd] · Kubernetes [CRI-O, Calico,       |
|  MetalLB, Kyverno] · Ubuntu Server 26.04 LTS                |
+-------------------------------------------------------------+
```

| Capa | Responsabilidad | Cambia cuando... |
|---|---|---|
| Usuario | Interfaz humana | UX cambia |
| Gobierno | Identidad y permisos | Politicas de acceso cambian |
| Aplicaciones | Logica de negocio | App se agrega o actualiza |
| Datos | Persistencia y eventos WAL | PostgreSQL o esquema cambia |
| Daemons Soberanos | Sincronizacion, integracion, inteligencia | Reglas de negocio entre daemons cambian |
| Infraestructura | Plataforma de ejecucion | Tecnologia de base cambia |

---

## 4. Los 8 Daemons Soberanos

```
HOST UBUNTU (systemd — fuera de K8s)
├── bos.service         → Plano de control
├── bkernel.service     → Plano de datos (WAL slot: bkernel_slot)
├── biedata.service     → Plano de integracion (WAL slot: biedata_slot)
├── bcompass.service    → Plano de inteligencia (WAL slot: bcompass_slot)
├── bsearch.service     → Plano de busqueda
├── bauth.service       → Plano de identidad
└── bhnexus.service     → Plano de conectividad

CLIENTE FEDORA (systemd --user)
└── banexus.service     → Plano edge
```

Razon fuera de K8s: acceso directo al WAL via socket Unix (`/var/run/postgresql/.s.PGSQL.5432`). Socket Unix es un orden de magnitud mas rapido que TCP y no depende de la red del cluster.

---

## 5. Componentes por Capa

### Clasificacion: propio / adoptado / infraestructura

| Componente | Tipo | Capa |
|---|---|---|
| IAM Installer (bos) | Propio (SKULL) | Infraestructura |
| bKernel | Propio (SKULL) | Daemons |
| biedata | Propio (SKULL) | Daemons |
| bCompass | Propio (SKULL) | Daemons |
| bSearch | Propio (SKULL) | Daemons |
| bAuth | Propio (SKULL) | Daemons |
| bhnexus | Propio (SKULL) | Daemons |
| banexus | Propio (SKULL) | Daemons (edge) |
| Core UI (Flutter) | Propio (SKULL) | Usuario |
| SmartTax, SmartReport, etc. | Propio (SKULL) | Aplicaciones |
| PostgreSQL | Adoptado | Datos |
| Keycloak | Adoptado | Gobierno |
| Vault | Adoptado | Gobierno |
| Kong | Adoptado | Gobierno |
| Tryton | Adoptado | Aplicaciones |
| OrangeHRM, Saleor, EspoCRM... | Adoptado | Aplicaciones |
| Kubernetes (CRI-O) | Infraestructura | Infraestructura |
| Calico, MetalLB, Kyverno | Infraestructura | Infraestructura |
| Ubuntu Server 26.04 LTS | Infraestructura | Infraestructura |

---

## 6. Bounded Contexts

| Bounded Context | Servidor logico | Fuente de Verdad | Entidad central | Contrato |
|---|---|---|---|---|
| Negocio Central | erpserver | Tryton | party.party | Publica via WAL → bKernel |
| Capital Humano | appsserver | OrangeHRM | hs_hr_employee | WAL → bKernel → Tryton |
| Relacion con Clientes | appsserver | EspoCRM + Saleor | contacts, orders | WAL → bKernel → Tryton |
| Comunicaciones | commsserver | Postfix + Rocket.Chat | mailbox, channel | Provisioning via bKernel |
| Identidad y Acceso | identityserver | Keycloak | user, realm, role | JWT a todos |
| Conocimiento y Docs | docserver + vdiserver | Paperless + Nextcloud | document, file | Consume identidad KC |
| Inteligencia | aiserver | Qdrant | embedding, query | Consume eventos via bCompass |
| Observabilidad | monitorserver | Prometheus + Loki | metric, log | Scraping de todos |

Relacion DDD: Customer-Supplier. bKernel es el integrador (supplier). No hay Shared Kernel ni Conformist.

### Reglas invariantes entre bounded contexts
1. Ningun BC lee directamente la BD de otro — toda lectura cruzada pasa por bKernel o API publica
2. bKernel es el unico que escribe en BDs de apps para sincronizacion
3. Keycloak es el unico que provisiona identidades
4. biedata es el unico con acceso a red exterior
5. bCompass es el unico que invoca Ollama

---

## 7. Los Dos Dominios Primarios

| Aspecto | Core (SP-01) — IAM Installer | bKernel |
|---|---|---|
| Que es | Motor Bash/Python del instalador | Daemon binario soberano |
| Escucha | Filesystem (servers/), .sbos_state.json | PostgreSQL WAL |
| Gobierna | Infraestructura: contenedores, K8s, fichas | Datos: sincronizacion entre apps |
| Patron | GitOps (declarativo, reconciliacion) | Event-driven (reactivo, tiempo real) |
| Extension | Agregar ficha a servers/ | Agregar regla YAML |

Meta-principio compartido: escuchar y actuar sin invadir.

---

## 8. Fronteras Invariantes

| # | Frontera | Propiedad que protege |
|---|---|---|
| F1 | `sbos_k8s_core()` es el unico `kubectl apply` | Trazabilidad de cambios en cluster |
| F2 | bKernel NO ejecuta DDL (ALTER/CREATE/DROP TABLE) | Cero invasion |
| F3 | Fichas no se llaman entre si | Desacoplamiento total |
| F4 | IAM Installer NO es pod K8s | Independencia del objeto vigilado |
| F5 | hostserver NO instala software de negocio | Separacion infra/negocio |
| F6 | biedata es el unico con acceso a red exterior | Control de exfiltracion |
| F7 | bCompass es el unico que invoca Ollama | Trazabilidad de inferencia |
| F8 | Daemons no se llaman entre si directamente | Independencia de fallos |

---

## 9. Dependencias y Resiliencia

| Pilar | Depende de | Si falla... |
|---|---|---|
| PostgreSQL | Ubuntu/K8s | Stack completo degradado (unico SPOF real, HA Patroni 3 nodos) |
| Keycloak | PostgreSQL, Vault | Nadie puede autenticarse |
| bKernel | PostgreSQL (WAL) | Apps siguen funcionando, sin sincronizacion |
| Tryton | PostgreSQL, bKernel | bKernel pierde destino principal |
| IAM Installer | Ubuntu (systemd) | Stack corre, sin gestion automatica |
| SBOS VDI | Keycloak, Kasm | Fallback: acceso por navegador web |
| biedata | PostgreSQL (WAL) | Integraciones externas pausadas |
| bCompass | PostgreSQL (WAL), aiserver | Inteligencia pausada, operacion intacta |

---

## 10. Flujo de Instalacion

```
T+00:00  Ubuntu Server 26.04 LTS minimo
T+00:02  IAM Installer como systemd
T+00:48  K8s cluster operativo + Core UI disponible
T+01:00  Administrador instala fichas desde Core UI

Orden: hostserver(0) → postgresql(100) → redis(110) → minio(120) →
       vault(130) → keycloak(140) → oauth2-proxy(150) →
       kong(160) → nginx(170) → certbot(180) →
       mailserver(200) → tryton(310) →
       bkernel(350) → biedata(360) → bcompass(370) →
       apps de negocio(400+) → aiserver(900+)
```

---

## 11. V7 Enriquecimiento — Reconceptualizacion Arquitectonica desde Dominios de Autenticacion

El V7 introduce un marco de 9 dominios de autenticacion que enriquece la arquitectura clasica de 5 capas con una dimension transversal de control de acceso:

| Dominio | Capa principal afectada | Estandar de referencia | Evaluador SBOS |
|---|---|---|---|
| Logico | Aplicaciones, Gobierno | NIST SP 800-63B, ISO/IEC 24760 | Keycloak + LogicalDomainMask |
| Fisico | Daemons, Infraestructura | ISO/IEC 27001 A.7, NIST SP 800-116 | banexus + PhysicalDomainMask |
| Financiero | Aplicaciones (Tryton) | PCI-DSS, ISO 27001 A.5.3, NIST AC-5 | Tryton Button Rules + FinancialDomainMask |
| Red | Infraestructura | IEEE 802.1X, RFC 2865 | Infraestructura de red |
| Aplicacion | Aplicaciones | OAuth 2.0, OIDC, ISO/IEC 29146 | trytond-auth-keycloak |
| Biometrico | Gobierno, Daemons | ISO/IEC 30107, FIDO2 | Keycloak WebAuthn (futuro) |
| Federado | Gobierno | NIST SP 800-63C, eIDAS | Keycloak JWT |
| Organizacional | Todas | ISO 27001 A.6, NIST PS | RolTemplate |
| Normativo | Todas | RGPD, SOX, PCI-DSS | bauth_db + Wazuh |

### Implicacion arquitectonica V7

La arquitectura del SBOS no son solo 5 capas horizontales. Existe una **dimension vertical de seguridad** que atraviesa todas las capas y que se materializa en el BitmaskBundle (PhysicalDomainMask + LogicalDomainMask + FinancialDomainMask). Cada daemon soberano evalua uno o mas de estos dominios segun su responsabilidad, y el Context Plane (ctx_id) propaga la informacion de resolucion de dominios a traves de todos los servicios via OTel Baggage.

### V7 — Correccion arquitectonica del BitMask

La V7 corrige un error conceptual en la arquitectura V6: el BitMask 64-bit original colapsaba tecnologias concretas (VDI = Fedora KDE, ERP = Tryton) en lugar de modelar dominios de autorizacion abstractos. La correccion introduce:

```
BitmaskBundle (v3 propuesta V7)
  +-- PhysicalDomainMask  uint64  // banexus — hardware, zonas, actuadores
  +-- LogicalDomainMask   uint64  // evaluador logico unificado — zonas de negocio
  +-- FinancialDomainMask uint64  // bAuth financial evaluator — SoD, limites, aprobaciones
```

---

## 12. V7 Enriquecimiento — Arquitectura del Par Nexus Soberano (NEXUS-CONCEPTUALIZACION)

El V7 conceptualiza el Par Nexus Soberano (bhnexus + banexus) como una **unidad arquitectonica de enforcement fisico**:

```
bhnexus (host Ubuntu)                              banexus (Fedora VDI)
+----------------------------+                     +----------------------------+
| WebSocket Server (WSS)     |<--- mTLS persistente--| WebSocket Client            |
| :9444                      |                     |                            |
| Enforces PhysicalDomainMask|                     | Enforces local Physical     |
| Relay de chapas/cajones    |                     | DomainMask (VDI)            |
| Auditoria de acceso fisico |                     | Interceptor USB/shell       |
+----------------------------+                     | BitMask evaluacion local    |
                                                    +----------------------------+
```

Protocolo monogamico: un bhnexus se conecta exactamente con un banexus. La conexion es mTLS persistente con certificados intercambiados en bootstrap. Latencia objetivo: <15ms para auth fisica.

---

## 13. Smart* Enriquecimiento — Arquitectura de Subproyectos

Cada subproyecto Smart* extiende la arquitectura SBOS con capas de dominio especifico:

| Subproyecto | Extension arquitectonica | Integracion con daemons |
|---|---|---|
| SmartORC | Capa de correspondencia sobre BC-05 (Comms) | bKernel (eventos), bAuth (WebAuthn), Keycloak (identidad) |
| SmartVaultFlow | Capa de custodia sobre BC-06 (Docs) | bKernel (eventos), bSearch (busqueda), bAuth (firmas) |
| SmartTax | Capa fiscal sobre BC-08 (biedata) | biedata (cajas SIAT/AFIP/SAT), bKernel (eventos) |
| SmartRates | Capa de pricing sobre BC-01 (Tryton) | bKernel (reglas), bCompass (analisis) |
| SmartPay | Capa de pagos sobre BC-01 (Financiero) | biedata (integracion exterior), bAuth (SoD financiero) |

La arquitectura de subproyectos sigue el mismo patron: extensibilidad por fichas, gobernanza por Keycloak, sincronizacion por WAL, y cero invasion al nucleo.

---

## Trazabilidad

| Seccion | Extraida de | Secciones originales |
|---|---|---|
| §1 Modelo | SBOS-002-ARCH v4.0 | §1, §2 |
| §1 V5 | BOS_V5_SBOS-002-ARCH-v4_0.md | Enfasis OS como modelo, daemons como middleware |
| §2 WAL | SBOS-002-ARCH v4.0 | §3 Decision Fundacional |
| §3 Capas | SBOS-002-ARCH v4.0 | §5 Diagrama, §6 Las Cinco Capas |
| §4 Daemons | SBOS-002-ARCH v4.0 | §4 Daemons Soberanos |
| §5 Componentes | SBOS-002-ARCH v4.0, SBOS-003-STACK v4.0 | §5, §catalogo |
| §6 Bounded Contexts | SBOS-002-ARCH v4.0 | §7 Bounded Contexts |
| §7 Dominios | SBOS-002-ARCH v4.0 | §15 Core vs bKernel |
| §8 Fronteras | SBOS-002-ARCH v4.0 | §16 Fronteras |
| §9 Resiliencia | SBOS-002-ARCH v4.0 | §14 Relacion entre Pilares |
| §10 Instalacion | SBOS-002-ARCH v4.0 | §13 Flujo de Instalacion |
| §11 V7 | BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md, BOS_V7_SBOS-BAUTH-CONCEPTUALIZACION-v5_0.md | 9 dominios, BitmaskBundle, correccion arquitectonica |
| §12 V7 Nexus | BOS_V7_SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md | Par Nexus, enforcement fisico, protocolo monogamico |
| §13 Smart* | BOSORC-006-ARQUITECTURA, SBOS-PAY-006-ARQUITECTURA, SBOS-REPORT-006-ARQUITECTURA, SBOS-Rates-006-ARQUITECTURA, SBOS-VAULT-006-ARQUITECTURA | Arquitecturas de subproyectos |

---

## Fuentas de Enriquecimiento V8

| Fuente | Tipo | Contenido aportado |
|---|---|---|
| BOS_V6_SBOS-002-ARCH.md | V6 (canonico) | Contenido base completo preservado |
| BOS_V5_SBOS-002-ARCH-v4_0.md | V5 | Enfasis en daemons como middleware, modelo OS |
| BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md | V7 | 9 dominios de autenticacion, tabla de estado por dominio, BitmaskBundle |
| BOS_V7_SBOS-BAUTH-CONCEPTUALIZACION-v5_0.md | V7 | Correccion SAM-128, BitmaskBundle v3, dominios abstractos |
| BOS_V7_SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md | V7 | Arquitectura del Par Nexus Soberano |
| BOS_V7_SBOS-BAUTH-DECISIONES-ARQUITECTURA-v1_0.md | V7 | Decisiones arquitectonicas de identidad |
| BOSORC-006-ARQUITECTURA.md (Smart ORC) | Smart* | Arquitectura de correspondencia |
| SBOS-PAY-006-ARQUITECTURA.md (Smart Pay) | Smart* | Arquitectura de pagos |
| SBOS-REPORT-006-ARQUITECTURA.md (Smart Report) | Smart* | Arquitectura de reportes |
| SBOS-VAULT-006-ARQUITECTURA.md (Smart Vault Flow) | Smart* | Arquitectura de vault documental |

---

_SKULL · SBOS · SBOS-002-ARCH · HUMAN-DOC v1.0-V8 · Mayo 2026_
_Enriquecimiento V8: V5 modelo OS + V7 9 dominios de autenticacion + BitmaskBundle + Nexus enforcement fisico + Smart* arquitecturas de subproyectos_
