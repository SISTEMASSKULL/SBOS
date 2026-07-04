# SBOS-001-VISION
## Vision y Proposito — Estandar HUMAN-DOC (Enriquecido V8)
### SKULL · SBOS v1.0-V8 · Mayo 2026

---

## 1. Declaracion de Proposito

SBOS es un sistema operativo empresarial soberano que instala en el servidor del cliente toda la infraestructura digital que una organizacion necesita para operar — ERP, RRHH, CRM, correo, comunicaciones, identidad, escritorio corporativo e inteligencia artificial — sin que ningun dato salga de ese servidor y sin licencias de proveedores externos.

### V5 Enriquecimiento — Profundizacion del Proposito

SBOS es el primer sistema operativo empresarial soberano disenado para Iberoamerica. En una frase: instala en el servidor del cliente toda la infraestructura digital que una organizacion necesita para operar — sin que ningun dato salga jamas de ese servidor y sin pagar licencias a ningun proveedor externo.

La palabra **soberano** tiene una definicion tecnica precisa en este contexto:

- Los datos del cliente nunca abandonan su infraestructura
- Ninguna licencia puede ser revocada por un proveedor externo
- Ningun proveedor puede dictar condiciones de acceso a los datos
- El codigo fuente es auditable en su totalidad
- La organizacion puede operar el sistema sin depender de SKULL si asi lo decide

Esta ultima propiedad es la mas dificil de lograr y la mas valiosa: un sistema verdaderamente soberano debe poder operar sin su creador. El SBOS esta disenado para que el cliente pueda transferir el conocimiento operacional a su propio equipo de TI en cualquier momento.

SBOS no es un producto cloud. No existe "SBOS en la nube de SKULL". El producto se instala en el hardware del cliente — sea un VPS, un servidor dedicado, o hardware propio. SKULL puede operar el sistema como servicio gestionado para el cliente, pero los datos siempre estan en el servidor del cliente. Si el cliente decide terminar la relacion con SKULL, el sistema continua funcionando exactamente igual.

---

## 2. Problema que Resuelve

### Fragmentacion del dato
Una empresa mediana opera con 8 a 15 herramientas SaaS en silos, cada una con su propia version de la verdad sobre los mismos datos. Costo estimado: 15-25% de eficiencia operativa perdida.

### Dependencia de proveedores
Datos financieros, RRHH y clientes almacenados en servidores bajo jurisdiccion extranjera. Riesgo de cambio de precios, condiciones, o cierre de servicio unilateral.

### Costo acumulado
Costo SaaS equivalente para 50 usuarios: ~USD 5.850/mes (USD 70.200/ano). SBOS: USD 0 en licencias.

### V5 Enriquecimiento — El problema en detalle

Una empresa mediana tipica opera con entre 8 y 15 herramientas de software simultaneas. Cada una con su propia base de datos, sus propias credenciales, y su propia version de la verdad sobre los mismos datos. El resultado es fragmentacion del dato: el mismo cliente existe en 7 sistemas diferentes con 7 versiones distintas de la misma realidad.

El costo se acumula entre USD 3.000 y USD 8.000 mensuales en licencias SaaS, con datos financieros, de RRHH y de clientes almacenados en servidores bajo jurisdiccion extranjera, sujetos a regulaciones y agencias de inteligencia de otros paises. Cada proveedor puede subir sus precios, cambiar sus condiciones o simplemente desaparecer.

---

## 3. Usuarios y Beneficiarios

| Tipo | Cantidad estimada | Rol | Necesidad |
|---|---|---|---|
| PYME iberoamericana | 20-500 empleados | Operador primario | Stack completo, soberania, cumplimiento tributario local |
| Contadores multicliente | 1 contador → 15+ empresas | Multi-tenant | Un SBOS, multiples realms Keycloak |
| Instituciones educativas | Variable | Sector regulado | Datos en servidores locales (normativa) |
| Instituciones de salud | Variable | Sector regulado | GNU Health, datos locales (normativa) |

---

## 4. Mercado Objetivo

### Primario: PYME boliviana e iberoamericana (20-500 empleados)
- Opera con 5+ herramientas SaaS simultaneas
- Datos sensibles que no deben salir del pais
- Requiere cumplimiento tributario local (SIN Bolivia, AFIP Argentina, SAT Mexico)
- Tiene o quiere tener equipo de TI propio

### Secundario: contadores y estudios contables multicliente

### Terciario: instituciones educativas y de salud

### Por que Bolivia primero
- Ley de proteccion de datos pendiente (anteproyecto AGETIC activo)
- 25% de sistemas industriales con intentos de infeccion (Kaspersky)
- Mercado no saturado, PYME con necesidades reales
- Costos en USD hacen SaaS internacional relativamente mas caro

### V5 Enriquecimiento — Posicionamiento competitivo detallado

Un cliente elegiria SBOS sobre SAP o Microsoft 365 por cuatro razones simultaneas que ninguna alternativa cumple a la vez:

| Razon | SBOS | Alternativas (SAP, M365) |
|---|---|---|
| Costo | USD 0 en licencias | Miles de dolares mensuales |
| Soberania | Datos en su servidor | Nube del proveedor |
| Completitud | Stack operacional completo | Suite parcial |
| Localizacion | Normativa tributaria BO/AR/MX integrada | Adaptaciones costosas |

SAP y Microsoft resuelven el problema para empresas que pueden pagar. SBOS lo resuelve para las que no pueden — y para las que no quieren depender.

---

## 5. Lo que SBOS NO es

| SBOS NO es | SBOS SI es |
|---|---|
| Suite de software | Sistema operativo empresarial |
| Instalador de apps | Control plane soberano con vigilancia y reparacion |
| Producto cloud | Instalacion on-premise en hardware del cliente |
| ERP | Infraestructura completa (ERP es uno de 110+ componentes) |
| Dependiente de SKULL | Transferible — opera sin SKULL si el cliente lo decide |

---

## 6. Restricciones No Negociables

| # | Restriccion | Tipo |
|---|---|---|
| R1 | Los datos del cliente NUNCA salen de su infraestructura | Soberania |
| R2 | El bKernel consolida datos SIN modificar apps ni sus BDs | Cero invasion |
| R3 | 100% open source, licencias libres — ningun proveedor puede revocar acceso | Libertad |
| R4 | Toda app del stack DEBE soportar PostgreSQL | Arquitectonica |
| R5 | Toda app DEBE ser gobernada por Keycloak (OIDC nativo o OAuth2-Proxy) | Arquitectonica |
| R6 | K8s desde el dia 1 — no existe modo "sin Kubernetes" | Operacional |
| R7 | Extensibilidad por fichas — agregar app nueva NO modifica el Core | Arquitectonica |
| R8 | El IAM Installer construye su propia plataforma (instala K8s) | Operacional |
| R9 | Licencias OSI-approved exclusivamente. Vetadas: BSL, SSPL, Sustainable Use | Legal |
| R10 | Secrets via Vault — cero passwords en texto claro | Seguridad |
| R11 | Daemons soberanos en el host (systemd, NO pods K8s) | Arquitectonica |
| R12 | El Core no crece por apps — logica especifica vive en fichas | Arquitectonica |
| R13 | Idempotencia obligatoria en toda operacion | Operacional |
| R14 | Diagnostico antes de reparar (diagnosis_first: true obligatorio) | Operacional |
| R15 | Pull-only para actualizaciones — SKULL nunca empuja codigo sin consentimiento | Soberania |

### V5 Enriquecimiento — Los tres principios que nunca se violan

De las 15 restricciones, tres son la base fundacional sobre la que se sostiene todo el sistema:

1. **Los datos del cliente nunca salen de su infraestructura** — Soberania
2. **El bKernel consolida datos entre aplicaciones sin modificar ninguna app ni su base de datos** — Cero invasion
3. **El sistema es 100% open source con licencias libres — ningun proveedor puede revocar el acceso** — Libertad

Todo lo demas puede negociarse. Estos tres principios son restricciones de diseno, no aspiraciones.

---

## 7. Los 6 Pilares

| # | Pilar | Componente | Funcion |
|---|---|---|---|
| 1 | IAM Installer | bos.service (systemd) | Control plane soberano: instala, vigila, repara |
| 2 | bKernel | bkernel.service (systemd) | Corazon de datos: consolida apps via WAL |
| 3 | Keycloak como Gobierno | Keycloak (pod K8s) | Gobierno de identidad, acceso y comportamiento |
| 4 | SBOS VDI | Kasm + Fedora KDE (USB booteable) | SO corporativo para endpoints |
| 5 | Tryton como Fuente de Verdad | Tryton ERP (pod K8s) | Hub central del bKernel, contabilidad PUCT/SIN |
| 6 | PostgreSQL como Lenguaje Universal | PostgreSQL (pod K8s) | WAL = bus de eventos nativo, protocolo universal |

---

## 8. Los 8 Daemons Soberanos

```
HOST UBUNTU (systemd)
├── bos.service         → Plano de control: instala, vigila, repara
├── bkernel.service     → Plano de datos: sincroniza apps internas via WAL
├── biedata.service     → Plano de integracion: conecta con sistemas externos
├── bcompass.service    → Plano de inteligencia: rutas de IA y analisis
├── bsearch.service     → Plano de busqueda: indexacion federada soberana
├── bauth.service       → Plano de identidad: BitMask 64-bit, 3 dominios
└── bhnexus.service     → Plano de conectividad: broker hardware y WebSocket

CLIENTE FEDORA (systemd --user)
└── banexus.service     → Plano edge: interceptor USB/shell, centinela
```

Razon de estar fuera de K8s: acceso directo al WAL sin latencia de red del cluster. Los daemons eliminan la necesidad de Kafka, n8n o middleware de mensajeria externo.

### V7 Enriquecimiento — Reconceptualizacion de los Daemons desde la perspectiva de dominios

El V7 introduce una perspectiva de dominios de autenticacion que redefine el rol de los daemons desde la optica del control de acceso:

| Daemon | Rol V6 (tecnologia) | Rol V7 (dominio abstracto) |
|---|---|---|
| bauth.service | BitMask 64-bit | Evaluador de dominios Logico (LogicalDomainMask), Fisico (PhysicalDomainMask), Financiero (FinancialDomainMask) |
| bhnexus.service | Broker hardware | Enforcement fisico: evalua PhysicalDomainMask para acceso a chapas, cajones, zonas |
| banexus.service | Edge sentinel Fedora | Enforcement en endpoint: evalua PhysicalDomainMask + LogicalDomainMask localmente |
| bkernel.service | Consolidador WAL | Orquestador de contexto: propaga ctx_id con informacion de todos los dominios |
| biedata.service | Integracion exterior | Aduana soberana: evalua dominio Financiero para exportacion fiscal (SIAT/AFIP/SAT) |

Esta reconceptualizacion establece que los 3 dominios (Logico-Fisico-Financiero) son transversales a todos los daemons, y cada daemon evalua el dominio que le corresponde segun su responsabilidad.

---

## 9. Posicionamiento Competitivo

| Dimension | Sin SBOS | Con SBOS |
|---|---|---|
| Fuentes de verdad | 8-15 sistemas en silos | 1 (Tryton via bKernel) |
| Contrasenas por empleado | 6-12 | 1 (Keycloak SSO) |
| Control del endpoint | Ninguno (Windows) | Total (SBOS VDI + Keycloak) |
| Dependencia de proveedores | Total | Cero — 100% open source |
| Costo licencias (50 users) | USD 5.850/mes | USD 0 |
| Soberania de datos | Servidores de terceros | Servidor del cliente |
| IA empresarial | API externa (datos salen) | Soberana (Ollama + Qdrant) |
| Tiempo de instalacion | Semanas/meses | 45 minutos |
| Integracion con Estado | Manual, costosa | Nativa (biedata: SIN/AFIP/SAT) |

---

## 10. OKRs Estrategicos (Marzo 2026 — Marzo 2027)

Revision mensual (CTO + CEO + Arquitecto Lead). Escala Google: 0.0-1.0, objetivo esperado 0.7.

### OBJ-1 — Adopcion validada del producto

| KR | Meta | Fecha | Responsable |
|----|------|-------|-------------|
| KR-1.1 | 3 clientes activos en produccion | Q4 2026 | CEO |
| KR-1.2 | Instalacion ≤ 8h en 80% de casos | Q3 2026 | DevOps Lead |
| KR-1.3 | Onboarding admin ≤ 5 dias laborales | Q3 2026 | CTO |

### OBJ-2 — Excelencia operacional

| KR | Meta | Fecha | Responsable |
|----|------|-------|-------------|
| KR-2.1 | Disponibilidad ≥ 99.9% mensual | Q3-Q4 2026 | SRE Lead |
| KR-2.2 | bKernel ≥ 1000 ev/min medido en produccion | Q3 2026 | SRE Lead |
| KR-2.3 | MTTR P0 ≤ 60 min | Q4 2026 | SRE Lead + CTO |

### OBJ-3 — Madurez tecnica y certificacion

| KR | Meta | Fecha | Responsable |
|----|------|-------|-------------|
| KR-3.1 | Framework Enterprise ≥ 137/150 | Q4 2026 | Arquitecto Lead |
| KR-3.2 | Cobertura tests activa en CI/CD | Q3 2026 | Dev Lead |
| KR-3.3 | ISO 27001 SoA firmada | Q3 2026 | CTO + Dir. Legal |

### OBJ-4 — Cobertura tributaria y bus factor

| KR | Meta | Fecha | Responsable |
|----|------|-------|-------------|
| KR-4.1 | biedata Bolivia SIAT en produccion | Q2 2026 | biedata Team |
| KR-4.2 | Bus Factor ≥ 2 en todos los daemons | Q3 2026 | CTO |
| KR-4.3 | ≥ 12 ADRs formalizadas | Q2 2026 | Arquitecto Lead |

---

## 11. Contexto Regulatorio (estado 2026)

| Pais | Estado | Impacto |
|---|---|---|
| **Bolivia** | Anteproyecto Ley de Proteccion de Datos (AGETIC) en consulta publica | Regulacion inminente |
| **Chile** | Ley 21.719 vigente desde dic 2026, multas hasta EUR 1.466.600 | Cumplimiento activo |
| **Peru** | DS N.o 016-2024-JUS vigente desde mar 2025, sanciones hasta USD 70.000 | Cumplimiento activo |
| **Brasil** | LGPD plenamente en vigor, ANPD activa | Cumplimiento maduro |
| **Mexico** | LFPDPPP vigente, CURP biometrica 2025 | Cumplimiento activo |
| **Argentina** | Ley 25.326 vigente, ciberpatrullaje habilitado 2024 | Tension regulatoria |

---

## 12. Smart* Enriquecimiento — Visiones de Subproyectos en el Ecosistema SBOS

Cada subproyecto Smart* extiende la vision central de SBOS hacia dominios de negocio especificos, manteniendo los principios de soberania, cero invasion y licencias libres.

### SmartORC — Oficina de Recepcion de Correspondencia (BOSORC-001-VISION)

SmartORC extiende el ecosistema SBOS al dominio de la **correspondencia organizacional**. Resuelve el problema de trazabilidad documental mediante:

- **Oficina de Recepcion de Correspondencia digital:** Captura toda correspondencia que llega al dominio del tenant (por email, escaneo fisico en POS, o ingreso manual), la registra con un identificador unico e inmutable (Hoja de Ruta), y la distribuye al responsable correcto.
- **Paradigma conversacional:** Cada documento se presenta como un hilo de chat. El usuario ve el documento anclado y debajo un chat donde puede comentar, preguntar, o presionar "Firmar y Despachar". Interfaz identica a cualquier app de mensajeria.
- **No-repudio biometrico:** Gracias a Keycloak 26.x (WebAuthn/Passkeys), cada transferencia de custodia requiere autenticacion con huella digital o reconocimiento facial.
- **Cierre de ciclo hacia SmartVaultFlow:** Cuando SmartORC completa el procesamiento (respondido o despachado), bKernel transfiere el activo documental a SmartVaultFlow, que toma la custodia permanente.

### SmartVaultFlow — Boveda Documental Soberana (SBOS-VAULT-001-VISION)

SmartVaultFlow (bvault) extiende SBOS al dominio de la **custodia documental permanente**:

- **Boveda centralizada:** Cada activo documental tiene un identificador unico permanente (`vault_id`), buscable por titulo, tipo, firmantes y contenido via bSearch.
- **Motor de flujos multi-firmante:** Rutas configurables por tipo de documento, plazos, escalamiento automatico, firma criptografica con WebAuthn biometrico obligatorio.
- **Ventanilla Virtual:** Entrega controlada de documentos a destinatarios externos con verificacion de identidad, acuse de recibo digital y enlace seguro con TTL.
- **Integracion con SmartORC:** Custodia las claves RSA retiradas de rotacion de ORC y gestiona la entrega de documentos despachados.

### SmartTax — Compliance Fiscal LATAM (SBOS_TAX_00_PLAN_MAESTRO_INGENIERIA_v6)

SmartTax extiende SBOS al dominio del **cumplimiento tributario regional**:

- Integracion nativa con SIN Bolivia (SIAT), AFIP Argentina, SAT Mexico
- Firma XML, generacion de comprobantes y envio a administraciones tributarias
- Motor de invariantes fiscales validado contra normativa de cada pais
- Operacion soberana: datos fiscales nunca salen del servidor del cliente antes del envio cifrado a la entidad recaudadora

---

## Trazabilidad

| Seccion | Extraida de | Secciones originales |
|---|---|---|
| §1 Proposito | SBOS-001-VISION v4.0 | §1 Resumen Ejecutivo |
| §1 V5 | BOS_V5_SBOS-001-VISION-v4_0.md | §1-3 Resumen, SKULL, El Producto |
| §2 Problema | SBOS-001-VISION v4.0 | §4 El Problema que Resuelve |
| §2 V5 | BOS_V5_SBOS-001-VISION-v4_0.md | §4 Fragmentacion del dato detalle |
| §3 Usuarios | SBOS-001-VISION v4.0 | §8 Mercado Objetivo |
| §4 Mercado | SBOS-001-VISION v4.0 | §8 Mercado Objetivo |
| §4 V5 | BOS_V5_SBOS-001-VISION-v4_0.md | §9 Posicionamiento Competitivo |
| §5 Lo que NO es | SBOS-001-VISION v4.0 | §3 El Producto: SBOS |
| §6 Restricciones | SBOS-001-VISION v4.0 | §10 Principios Rectores (P1-P15) |
| §6 V5 | BOS_V5_SBOS-001-VISION-v4_0.md | §10 Los 3 principios que nunca se violan |
| §7 Pilares | SBOS-001-VISION v4.0 | §5 Los 6 Pilares del SBOS |
| §8 Daemons | SBOS-001-VISION v4.0 | §6 Los 8 Daemons Soberanos |
| §8 V7 | BOS_V7_SBOS-BAUTH-CONCEPTUALIZACION-v5_0.md, BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md | Reconceptualizacion daemons por dominios abstractos |
| §9 Competitivo | SBOS-001-VISION v4.0 | §9 Posicionamiento Competitivo |
| §10 OKRs | SBOS-001-OKR v1.0 | §OBJ-1 a OBJ-4 completo |
| §11 Regulatorio | SBOS-001-VISION v4.0 | §7 Contexto de Soberania Digital |
| §12 Smart* | BOSORC-001-VISION, SBOS-VAULT-001-VISION, SBOS_TAX_00_PLAN_MAESTRO_INGENIERIA_v6.md | Visiones de subproyectos |

---

## Fuentas de Enriquecimiento V8

| Fuente | Tipo | Contenido aportado |
|---|---|---|
| BOS_V6_SBOS-001-VISION.md | V6 (canonico) | Contenido base completo preservado |
| BOS_V5_SBOS-001-VISION-v4_0.md | V5 | Profundizacion del proposito, definicion de soberania, SKULL como empresa, 3 principios fundamentales, posicionamiento competitivo detallado |
| BOS_V5_SBOS-001-OKR-Strategic-v1_0.md | V5 | OKRs estrategicos detalle |
| BOS_V7_SBOS-BAUTH-CONCEPTUALIZACION-v5_0.md | V7 | Reconceptualizacion de daemons por dominios abstractos |
| BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md | V7 | Marco de 9 dominios de autenticacion |
| BOSORC-001-VISION.md (Smart ORC) | Smart* | Vision de correspondencia organizacional, paradigma conversacional, no-repudio biometrico |
| SBOS-VAULT-001-VISION.md (Smart Vault Flow) | Smart* | Vision de boveda documental, custodia permanente, flujos multi-firmante |
| SBOS_TAX_00_PLAN_MAESTRO_INGENIERIA_v6.md (Smart Tax) | Smart* | Vision de compliance fiscal LATAM |

---

_SKULL · SBOS · SBOS-001-VISION · HUMAN-DOC v1.0-V8 · Mayo 2026_
_Enriquecimiento V8: V5 profundizacion de soberania + V7 dominios abstractos + Smart* visiones de subproyectos (ORC, Vault Flow, Tax)_
