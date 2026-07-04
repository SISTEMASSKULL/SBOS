# IAM Enterprise Stack

**Manual Técnico de Referencia · v5.0**

Febrero 2026 · 31 Servidores · 65+ Aplicaciones · Open Source 100%

*Tryton como motor de datos · PostgreSQL 18 exclusivo · Keycloak 26.5.3 SSO universal · NGINX proxy central*

# 🏛️ Principios Arquitectónicos

| Principio | Implementación en el Stack |
|---|---|
| Motor de datos único: Tryton | Tryton ERP centraliza contabilidad boliviana PUCT/SIN, inventario multi-almacén, manufactura, ventas y compras en PostgreSQL. Es la fuente de verdad para todos los datos de negocio del stack. |
| Identidad centralizada: Keycloak | Keycloak 26.5.3 como único IdP — OIDC, SAML 2.0 y LDAP federation para las 65+ aplicaciones. OAuth2-Proxy para apps sin soporte OIDC nativo. MFA TOTP/WebAuthn. |
| Proxy único: NGINX | NGINX en proxyserver es el único punto de entrada externo. ModSecurity WAF, rate limiting, DDoS protection y SSL termination antes de llegar a cualquier servicio interno. |
| Observabilidad LGTM+Z+W | Loki (logs) + Grafana (dashboards) + Tempo (trazas) + Prometheus (métricas) + Zabbix (infraestructura) + Wazuh (seguridad). Correlación completa en un solo panel Grafana con SSO. |
| Base de datos: PostgreSQL 18 | PostgreSQL 18 sirve al 90%+ del stack. MySQL solo en 3 herramientas por dependencias técnicas del fabricante (no del stack). SymmetricDS mantiene sincronización. Roadmap 100% PostgreSQL. |
| Cero desarrollo innecesario | Todas las herramientas son proyectos open source maduros y probados. Desarrollo propio mínimo: módulos Tryton Bolivia, Django SIAT, conectores de pago QR/Tigo Money. Sin frameworks propios. |
| Alta disponibilidad / DR | Patroni HA PostgreSQL (RPO=0) + Velero DR Kubernetes en AWS (RTO<30 min) + Bareos backups cifrados + Linkerd mTLS + HAProxy BD + Network Policies. SLA objetivo: 99.95%. |

> **⚠️ Sobre MySQL en el stack: 3 aplicaciones con dependencia técnica documentada**
>
> MySQL 8.0+ es requerido exclusivamente por OrangeHRM (RRHH), Easy!Appointments (citas de servicios) y FreePBX (telefonía). Estas son herramientas de terceros que no soportan PostgreSQL por arquitectura propia. La instancia MySQL está completamente aislada en commonserver. SymmetricDS (dbsyncserver) mantiene sincronización donde es necesaria. El roadmap del stack contempla migrar estas 3 herramientas a alternativas PostgreSQL-nativas cuando alcancen paridad funcional.

# 🗺️ Mapa de 31 Servidores

| Servidor | Puertos | Función Principal | BD | Prioridad |
|---|---|---|---|---|
| proxyserver/ | 80, 443 | Reverse Proxy, WAF, SSL | — | CRÍTICO |
| authserver/ | 2000-2099 | SSO & Identidad Universal | PostgreSQL | CRÍTICO |
| appserver/ | 3000-3099 | Tryton ERP + RRHH + Knowledge | PgSQL + MySQL | CRÍTICO |
| webserver/ | 4000-4099 | Web Apps + E-Commerce + Pagos | PgSQL + MySQL | CRÍTICO |
| reportserver/ | 5000-5099 | Reportes Fiscales Bolivia SIN | PostgreSQL | CRÍTICO |
| catalogserver/ | 6000-6099 | Gestión Documental + OCR | PostgreSQL | CRÍTICO |
| commonserver/ | 7000-7099 | BD + Caché + Storage Core | PgSQL + MySQL | CRÍTICO |
| mailserver/ | 8000-8099+STD | Correo Empresarial Completo | PostgreSQL | CRÍTICO |
| vdiserver/ | 9000-9099 | Workspace Digital & VDI | PostgreSQL | ALTO |
| monitorserver/ | 10000-10099 | Observabilidad LGTM+Z+W | PostgreSQL | CRÍTICO |
| vcardserver/ | 11000-11099 | Tarjetas Digitales | PostgreSQL | MEDIO |
| biserver/ | 12000-12099 | Business Intelligence | PostgreSQL | CRÍTICO |
| workflowserver/ | 13000-13099 | Flujo Documental + Búsqueda | PostgreSQL | CRÍTICO |
| assettracking/ | 14000-14099 | Geolocalización GPS | PostgreSQL | CRÍTICO |
| logisticsserver/ | 15000-15099 | Gestión Logística | PgSQL + MySQL | CRÍTICO |
| orchestrator/ | 16000-16099 | Orquestación Airflow | PostgreSQL | CRÍTICO |
| datacatalog/ | 17000-17099 | Catálogo de Datos | MySQL→PostgreSQL | CRÍTICO |
| backupserver/ | 18000-18099 | Backup & DR Completo | PostgreSQL | CRÍTICO |
| apigateway/ | 19000-19099 | API Gateway + SIAT Bolivia | PostgreSQL | CRÍTICO |
| messagequeue/ | 20000-20099 | Message Broker RabbitMQ | — | MEDIO |
| secretsvault/ | 21000-21099 | Gestión de Secretos Vault | PostgreSQL | MEDIO |
| cicdserver/ | 22000-22099 | GitLab CI/CD + Testing | PostgreSQL | MEDIO |
| searchengine/ | 23000-23099 | Elasticsearch + Solr | — | CRÍTICO |
| dbsyncserver/ | 24000-24099 | Sync PostgreSQL↔︎MySQL | PgSQL + MySQL | CRÍTICO |
| commsserver/ | 25000-25099 | VoIP + Chat + Mensajería | MySQL+MongoDB+PgSQL | CRÍTICO |
| projectserver/ | 26000-26099 | Proyectos + OKR + CRM | PostgreSQL | CRÍTICO |
| esignserver/ | 27000-27099 | Firma Digital DocuSeal | PostgreSQL | ALTO |
| securityserver/ | 28000-28099 | SIEM + Vulnerabilidades + mTLS | Elasticsearch+PgSQL | ALTO |
| helpdeskserver/ | 29000-29099 | Help Desk + Encuestas + Citas | PostgreSQL | MEDIO |
| queueserver/ | 31000-31099 | Colas de Atención Novo SGA | PostgreSQL | CRÍTICO |
| signageserver/ | 32000-32099 | Digital Signage Xibo | MySQL→PostgreSQL | CRÍTICO |

# 📋 Detalle Completo: Descripción y Relaciones por Aplicación

Cada aplicación incluye: qué hace, cómo se integra con el resto del stack y qué servicios la complementan.

### 🖥️ proxyserver/ — Reverse Proxy & Seguridad Perimetral

Único punto de entrada externo al stack. Todo el tráfico pasa por aquí antes de llegar a cualquier servicio interno.

- **Puertos:** 80, 443
- **BD Principal:** —
- **Auth Keycloak:** No aplica — capa de borde

#### 1. NGINX

Servidor web y reverse proxy de alto rendimiento. Recibe todas las peticiones externas, las enruta al servicio correcto según el hostname o path, termina SSL/TLS, aplica cabeceras de seguridad (HSTS, CSP, X-Frame-Options) y sirve archivos estáticos.

- **Puerto:** 80, 443
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: — / Auth: Proxy de borde
- **Relaciones:** Enruta tráfico a todos los servicios del stack. Complementa a Certbot (SSL), ModSecurity (WAF), Keycloak (auth) y distribuye carga entre instancias de Laravel, Saleor, Tryton, Superset y más.

#### 2. Certbot (Let's Encrypt)

Gestor automático de certificados SSL/TLS gratuitos. Solicita, renueva y despliega certificados X.509 sin intervención manual, recargando NGINX de forma transparente sin tiempo de inactividad.

- **Puerto:** —
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: — / Auth: —
- **Relaciones:** Trabaja exclusivamente con NGINX — le entrega los certificados renovados y le indica que recargue su configuración. Vault puede complementar para certificados internos (PKI).

#### 3. ModSecurity + OWASP CRS

Firewall de aplicaciones web (WAF) integrado en NGINX. Inspecciona cada petición HTTP contra el conjunto de reglas OWASP CRS v4, bloqueando ataques de inyección SQL, XSS, inclusión de archivos remotos, traversal de rutas y otros ataques del Top-10 OWASP.

- **Puerto:** 80, 443
- **Prioridad:** ALTO
- **BD / Auth:** BD: — / Auth: —
- **Relaciones:** Opera como módulo de NGINX — procesa peticiones antes de que lleguen a Laravel, Django, Saleor, Tryton o cualquier otro backend. Envía logs de bloqueos a Loki (monitorserver) para análisis en Grafana y correlación con alertas Wazuh (securityserver).

#### 4. Rate Limiting (NGINX)

Módulo nativo de NGINX que controla la tasa de peticiones por dirección IP, usuario autenticado o endpoint específico. Previene abuso de APIs, ataques de fuerza bruta en formularios de login y saturación de recursos.

- **Puerto:** 80, 443
- **Prioridad:** ALTO
- **BD / Auth:** BD: — / Auth: Token Keycloak
- **Relaciones:** Protege todos los endpoints expuestos: API Kong (apigateway), Django SIAT, Saleor GraphQL, Laravel REST. Los límites por usuario autenticado se coordinan con tokens Keycloak (authserver).

#### 5. DDoS Protection (NGINX)

Conjunto de directivas NGINX para mitigar ataques de denegación de servicio: límite de conexiones simultáneas por IP, timeouts agresivos, desconexión de conexiones lentas (slowloris), buffer de peticiones y geo-blocking por país.

- **Puerto:** 80, 443
- **Prioridad:** ALTO
- **BD / Auth:** BD: — / Auth: —
- **Relaciones:** Primera línea de defensa antes de que el tráfico malicioso llegue a Keycloak, Tryton, Django SIAT o cualquier otro servicio crítico. Complementa a ModSecurity para una defensa en profundidad.

### 🖥️ authserver/ — Autenticación & SSO Universal

Proveedor de identidad (IdP) central del stack. Gestiona quién puede acceder a qué en las 65+ aplicaciones.

- **Puertos:** 2000-2099
- **BD Principal:** PostgreSQL 18
- **Auth Keycloak:** Es el IdP — proporciona identidad al resto

#### 1. Keycloak 26.5.3

Plataforma de gestión de identidad y acceso (IAM) empresarial. Centraliza autenticación con SSO (Single Sign-On) para todas las aplicaciones, gestiona usuarios, roles y grupos, implementa MFA (TOTP/WebAuthn), aplica políticas de contraseña y mantiene un registro de auditoría completo de todos los eventos de acceso.

- **Puerto:** 2000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: Es el IdP
- **Relaciones:** Es el eje de identidad de todo el stack. Las 65+ aplicaciones delegan en Keycloak su autenticación. Almacena identidades en PostgreSQL (commonserver). Federación con Active Directory/LDAP externo (authserver). OAuth2-Proxy sirve como puente para apps sin OIDC nativo.

#### 2. OAuth2-Proxy

Proxy de autenticación transparente para servicios que no implementan OIDC/OAuth2 de forma nativa. Se coloca delante del servicio (en NGINX), intercepta cada petición, la redirige a Keycloak para validar el token, y solo reenvía al backend si el usuario está autenticado.

- **Puerto:** 2010
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: — / Auth: Valida tokens Keycloak
- **Relaciones:** Protege servicios como Roundcube (mailserver), Trilium Notes (appserver), JasperReports (reportserver) y Zabbix (monitorserver). Recibe tokens de Keycloak y reenvía peticiones al servicio destino con cabeceras de usuario (X-Remote-User, X-Remote-Email).

#### 3. LDAP/AD Federation

Componente de federación de usuarios de Keycloak que sincroniza identidades desde un directorio LDAP externo o Active Directory corporativo. Permite que los empleados inicien sesión con sus credenciales corporativas existentes sin necesidad de cuentas duplicadas.

- **Puerto:** 2020
- **Prioridad:** ALTO
- **BD / Auth:** BD: — / Auth: Sincroniza con Keycloak
- **Relaciones:** Alimenta a Keycloak con usuarios externos. Una vez sincronizados, esos usuarios tienen SSO en todas las aplicaciones del stack: Tryton, Taiga, OpenProject, GitLab, Mattermost, Wiki.js, etc.

#### 4. OIDC/SAML Provider (Broker)

Capacidad de Keycloak para actuar como broker de identidad hacia proveedores externos (Google Workspace, Microsoft Entra ID, GitHub). Permite que usuarios de organizaciones aliadas accedan al stack sin crear cuentas locales.

- **Puerto:** 2000
- **Prioridad:** ALTO
- **BD / Auth:** BD: — / Auth: Broker a IdPs externos
- **Relaciones:** Conecta con IdPs externos y propaga la identidad resultante al resto del stack (Tryton, GitLab, Saleor, etc.). Complementa la federación LDAP para entornos multi-organización.

### 🖥️ appserver/ — ERP Tryton, RRHH & Knowledge Base

Motor de negocio central del stack. Tryton es la fuente de verdad para todos los datos empresariales: finanzas, inventario, manufactura, ventas, compras.

- **Puertos:** 3000-3099
- **BD Principal:** PostgreSQL 18 (Tryton, Wiki.js, GNU Health) · MySQL 8 (OrangeHRM)
- **Auth Keycloak:** ✅ OAuth2/OIDC/SAML — todos los módulos

#### 1. Tryton ERP Core

Sistema de planificación de recursos empresariales (ERP) modular y de arquitectura limpia. Gestiona la contabilidad según normativa boliviana PUCT, el plan de cuentas SIN, ciclos contables completos, activos fijos, presupuestos y conciliaciones bancarias. Es la fuente de verdad financiera del stack y el núcleo al que todos los demás sistemas reportan o alimentan datos.

- **Puerto:** 3000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OAuth2 Keycloak
- **Relaciones:** Alimenta a JasperReports (reportserver) con datos para Libro de Compras/Ventas SIN. Django SIAT (apigateway) lee y escribe facturas en Tryton. Superset (biserver) toma datos de PostgreSQL Tryton para dashboards. Airflow (orchestrator) orquesta ETL nocturnos desde Tryton. Saleor (webserver) sincroniza inventario y pedidos con Tryton vía webhooks.

#### 2. Tryton: Stock / Almacén

Módulo nativo de Tryton para gestión de inventario multi-almacén. Controla movimientos de entrada y salida, transferencias entre almacenes, lotes y números de serie, valoración de stock (FIFO, LIFO, Promedio Ponderado) y generación de alertas de reabastecimiento. No requiere instancia separada — comparte la misma base de datos que el ERP core.

- **Puerto:** 3000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OAuth2 Keycloak
- **Relaciones:** Tryton Stock envía actualizaciones de inventario a Saleor (webserver) vía webhooks cuando el stock cambia. Recibe recepciones de compra desde Tryton Compras. Airflow sincroniza su estado con OpenMetadata (datacatalog) para visibilidad del dato. JasperReports genera reportes de inventario para auditorías.

#### 3. Tryton: Manufactura

Módulo nativo de Tryton para planificación y control de producción. Define listas de materiales (BOM), rutas de fabricación con operaciones y centros de trabajo, órdenes de producción, control de calidad por fase y costeo de producción real vs. estándar.

- **Puerto:** 3000
- **Prioridad:** ALTO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OAuth2 Keycloak
- **Relaciones:** Lee stock disponible desde Tryton Stock para confirmar viabilidad de órdenes. Actualiza stock de productos terminados y consume materias primas en Tryton Stock. Envía datos de costos reales a Tryton Contabilidad para cierre del período. Airflow puede disparar órdenes automáticas según demanda Saleor.

#### 4. Tryton: Ventas & Compras

Módulos nativos de Tryton para el ciclo comercial completo. Ventas gestiona el pipeline de oportunidades, cotizaciones, pedidos de venta, albaranes y facturación al cliente. Compras gestiona solicitudes de compra, órdenes a proveedores, recepciones de mercancía y facturas de proveedor.

- **Puerto:** 3000
- **Prioridad:** ALTO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OAuth2 Keycloak
- **Relaciones:** Ventas activa pedidos que Tryton Stock prepara y despacha. Las facturas de venta pasan a Django SIAT (apigateway) para emisión de CUF al SIN Bolivia. Compras recepciona mercancía que Tryton Stock registra. EspoCRM (projectserver) sincroniza oportunidades con el módulo de ventas de Tryton.

#### 5. GNU Health 4.4+

Sistema de gestión hospitalaria y de salud pública. Administra historias clínicas electrónicas, citas médicas, laboratorio clínico, farmacia hospitalaria, estadísticas epidemiológicas y control de enfermedades. Especialmente diseñado para el sector público de salud latinoamericano.

- **Puerto:** 3010
- **Prioridad:** MEDIO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak
- **Relaciones:** Usa PostgreSQL compartido (commonserver). SSO con Keycloak (authserver). Paperless-NGX (catalogserver) archiva resultados de laboratorio y documentos clínicos. JasperReports (reportserver) genera reportes epidemiológicos. Correo Postfix (mailserver) envía recordatorios de citas a pacientes.

#### 6. OrangeHRM 6.0+

Sistema de gestión de recursos humanos de clase empresarial. Cubre nómina, control de asistencia (biométrico e integración de marcadores), gestión de vacaciones y permisos, evaluaciones de desempeño 360°, onboarding de nuevos empleados, gestión de disciplina y estructuras organizacionales.

- **Puerto:** 3020
- **Prioridad:** ALTO
- **BD / Auth:** BD: MySQL 8 (commonserver) / Auth: OIDC Keycloak
- **Relaciones:** SSO con Keycloak (authserver) via OIDC nativo. MySQL en commonserver como base de datos. Envía notificaciones de nómina y recordatorios vía Postfix (mailserver). Los organigramas y datos de empleados alimentan a EspoCRM (projectserver) para asignación de responsables. Airflow puede automatizar generación de reportes de asistencia mensual.

#### 7. Wiki.js 3.0+

Base de conocimiento colaborativa y wiki empresarial. Permite crear, editar y organizar documentación con editor WYSIWYG y Markdown, control de versiones automático por página, búsqueda full-text, árbol de páginas jerárquico, permisos granulares por sección y soporte multilenguaje.

- **Puerto:** 3030
- **Prioridad:** MEDIO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak
- **Relaciones:** SSO con Keycloak (authserver). Almacena contenido en PostgreSQL (commonserver). Elasticsearch (searchengine) indexa su contenido para búsqueda cruzada. Nextcloud (vdiserver) puede adjuntar archivos a páginas Wiki. GitLab (cicdserver) puede publicar documentación técnica automáticamente vía CI/CD pipeline.

#### 8. Trilium Notes

Aplicación de notas personales jerárquicas con cifrado de extremo a extremo. Permite organizar conocimiento personal en árboles de notas con relaciones cruzadas, scripting con JavaScript para automatización, y exportación a Markdown/HTML. Orientada al uso individual o por equipo pequeño.

- **Puerto:** 3040
- **Prioridad:** BAJO
- **BD / Auth:** BD: PostgreSQL (compatible) / Auth: OAuth2-Proxy
- **Relaciones:** Complementa Wiki.js — mientras Wiki.js es la base de conocimiento pública y colaborativa, Trilium Notes es para conocimiento personal o borradores. Se integra vía API REST con Tryton o Laravel para importar datos de trabajo. SSO básico vía OAuth2-Proxy (authserver).

### 🖥️ webserver/ — Web Apps, CMS, E-Commerce & Pagos

Capa de aplicaciones web propias y plataformas de comercio electrónico. Laravel como backend empresarial propio, Saleor como motor e-commerce, Directus como CMS headless.

- **Puertos:** 4000-4099
- **BD Principal:** PostgreSQL 18 (Laravel, Directus, Saleor) · MySQL 8 (TastyIgniter, Easy!Appointments)
- **Auth Keycloak:** ✅ OAuth2/OIDC — Laravel Socialite + Keycloak

#### 1. Laravel Framework (Core)

Framework PHP de alto rendimiento para el desarrollo de aplicaciones web empresariales propias. Provee el backend API REST para los módulos de negocio específicos de la organización: módulos de pago QR boliviano, integraciones locales y lógica de negocio que no cubre ninguna otra herramienta del stack. Arquitectura MVC limpia con ORM Eloquent.

- **Puerto:** 4000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak (Socialite)
- **Relaciones:** Autentica usuarios con Keycloak (authserver) vía Laravel Socialite OIDC. Se conecta a PostgreSQL en commonserver. Sus APIs son expuestas a través de Kong (apigateway). Consume datos de Tryton (appserver) para validaciones de inventario y precios. Vue.js consume sus APIs REST para renderizar la UI.

#### 2. Vue.js 3 + PrimeVue

Framework JavaScript de frontend para las aplicaciones web propias. Vue.js 3 con la librería de componentes PrimeVue provee una interfaz de usuario rica, reactiva y accesible. Incluye dashboards de gestión, formularios complejos, tablas de datos y visualizaciones.

- **Puerto:** 4000
- **Prioridad:** ALTO
- **BD / Auth:** BD: — (frontend) / Auth: Token Keycloak
- **Relaciones:** Consume las APIs REST de Laravel (webserver) y la API GraphQL de Saleor (webserver). Se construye con Vite y sus archivos estáticos son servidos por NGINX (proxyserver). Obtiene tokens de autenticación desde Keycloak (authserver) para peticiones autenticadas.

#### 3. Directus 11+

CMS headless de nueva generación que genera automáticamente una API REST y GraphQL completa a partir del esquema de base de datos. Incluye un Studio visual de administración de contenido para usuarios no técnicos. Ideal para gestionar contenido dinámico de sitios web, apps móviles y pantallas digitales.

- **Puerto:** 4010
- **Prioridad:** ALTO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak
- **Relaciones:** Usa PostgreSQL (commonserver). SSO con Keycloak (authserver). Su contenido es consumido por Vue.js para renderizar páginas dinámicas. Xibo CMS (signageserver) puede consumir contenido de Directus para pantallas digitales. Airflow (orchestrator) puede automatizar publicaciones de contenido.

#### 4. Saleor Commerce

Plataforma de comercio electrónico headless y de código abierto, construida sobre Django y Python. Gestiona catálogo de productos con variantes, carrito de compras, checkout multi-paso, gestión de pedidos, devoluciones, canales de venta y pasarelas de pago. Expone todo vía API GraphQL para máxima flexibilidad de frontend.

- **Puerto:** 4020
- **Prioridad:** ALTO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak
- **Relaciones:** Sincroniza inventario en tiempo real con Tryton Stock (appserver) vía webhooks — cuando se vende en Saleor, Tryton descuenta el stock. Los pedidos confirmados crean ventas en Tryton para facturación y Django SIAT emite la factura al SIN. Usa PostgreSQL (commonserver). SSO con Keycloak. Vue.js o cualquier frontend consume su API GraphQL.

#### 5. TastyIgniter 3.7+

Sistema de gestión de restaurantes y delivery en línea. Permite definir menús con categorías, precios y personalización, recibir pedidos en línea o presenciales, gestionar mesas con códigos QR, asignar pedidos a repartidores y enviar notificaciones de estado en tiempo real.

- **Puerto:** 4030
- **Prioridad:** MEDIO
- **BD / Auth:** BD: PostgreSQL / MySQL / Auth: OIDC Keycloak
- **Relaciones:** Comparte PostgreSQL/MySQL en commonserver. Integra con el módulo de pagos Laravel (webserver) para procesar pagos QR y Tigo Money. Postfix (mailserver) envía confirmaciones de pedido por correo. Traccar (assettracking) puede rastrear a repartidores en tiempo real.

#### 6. Easy!Appointments 1.5+

Sistema de reserva de citas online especializado para negocios de servicios: salones de belleza, consultorios médicos, clínicas veterinarias, servicios profesionales. Gestiona disponibilidad de personal, tipos de servicio, reservas por cliente y envío de recordatorios automáticos.

- **Puerto:** 4040
- **Prioridad:** MEDIO
- **BD / Auth:** BD: MySQL 8 (commonserver) / Auth: OAuth2-Proxy
- **Relaciones:** MySQL en commonserver. Envía recordatorios de cita vía Postfix (mailserver). Se integra con Nextcloud Calendar (vdiserver) para que el personal vea sus citas en su calendario. GNU Health (appserver) puede complementarlo para citas médicas. SSO básico vía OAuth2-Proxy (authserver).

#### 7. Laravel Payment Gateway

Módulo de integración de mínimo desarrollo propio, construido sobre Laravel. Conecta las pasarelas de pago locales de Bolivia: Tigo Money, QR Simple (Banco Unión), y otros sistemas de pago nacionales. Normaliza las respuestas de pago en un formato único para el stack.

- **Puerto:** 4050
- **Prioridad:** MEDIO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak
- **Relaciones:** Recibe confirmaciones de pago y las notifica a Saleor (e-commerce), TastyIgniter (restaurantes) y Easy!Appointments (citas). Registra automáticamente los pagos recibidos en Tryton Contabilidad (appserver) para el asiento contable. Expone su API a través de Kong (apigateway).

#### 8. Laravel QR Payment API

API especializada para la generación y verificación de códigos QR de pago, construida sobre Laravel. Genera QR dinámicos con monto y referencia, verifica en tiempo real si el pago fue confirmado por el banco o billetera móvil, y gestiona el ciclo de vida del QR (expiración, estados).

- **Puerto:** 4060
- **Prioridad:** MEDIO
- **BD / Auth:** BD: PostgreSQL 18 · Redis / Auth: OIDC Keycloak
- **Relaciones:** Parte del mismo servidor Laravel (webserver). Alimenta a TastyIgniter, Saleor y Easy!Appointments con QRs de pago. Notifica a Tryton Contabilidad (appserver) sobre pagos recibidos para asiento automático. Redis (commonserver) almacena el estado temporal de los QR activos.

#### 9. NGINX App Server

Instancia dedicada de NGINX para servir las aplicaciones del webserver. Diferente al NGINX del proxyserver (que es el gateway externo), este NGINX interno gestiona el proxy a PHP-FPM para Laravel, sirve los archivos estáticos compilados de Vue.js, aplica configuraciones específicas por aplicación y gestiona el rate limiting por ruta.

- **Puerto:** 4000-4099
- **Prioridad:** ALTO
- **BD / Auth:** BD: — / Auth: Proxy headers Keycloak
- **Relaciones:** Recibe tráfico ya filtrado del NGINX principal (proxyserver). Distribuye peticiones entre PHP-FPM Laravel, la API Saleor Django, TastyIgniter y Easy!Appointments. Sus logs van a Loki (monitorserver) para análisis de tráfico por aplicación en Grafana.

### 🖥️ reportserver/ — Generación de Reportes

Motor de generación de reportes fiscales y empresariales. Especializado en los formatos requeridos por la normativa boliviana SIN y PUCT.

- **Puertos:** 5000-5099
- **BD Principal:** PostgreSQL 18 (conexión JDBC directa)
- **Auth Keycloak:** ⚠️ Auth básica (reportes internos)

#### 1. JasperSoft Studio 6.18.1

Herramienta profesional de diseño y generación de reportes empresariales. Soporta reportes complejos con sub-reportes, gráficos, tablas cruzadas, parámetros dinámicos y múltiples fuentes de datos. Es el estándar de facto para reportería fiscal en Bolivia por su soporte completo de los formatos SIN.

- **Puerto:** 5000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 (JDBC) / Auth: Auth básica
- **Relaciones:** Conecta directamente a PostgreSQL de Tryton (commonserver) vía JDBC para obtener datos contables y de inventario. Los reportes generados (Libro de Compras/Ventas, IEDGE, F-110, estados financieros PUCT) se almacenan en MinIO (commonserver). Airflow (orchestrator) puede programar generación automática mensual. Paperless-NGX (catalogserver) archiva los PDFs generados.

#### 2. JasperStarter 3.6.2

Interfaz de línea de comandos (CLI) para JasperReports que permite la generación masiva y automatizada de reportes sin intervención humana. Acepta parámetros de entrada, conecta a bases de datos y exporta en múltiples formatos (PDF, XLSX, HTML, CSV).

- **Puerto:** 5010
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 (JDBC) / Auth: —
- **Relaciones:** Invocado por Celery workers (apigateway) o Airflow (orchestrator) para generación batch — por ejemplo, reportes mensuales de todos los clientes o el cierre fiscal mensual. Los archivos resultantes van a MinIO (commonserver) o son enviados por correo vía Postfix (mailserver).

#### 3. PDF.js

Librería de Mozilla para visualizar documentos PDF directamente en el navegador web, sin necesidad de descargar ni instalar ningún plugin. Renderiza PDFs con alta fidelidad visual.

- **Puerto:** 5020
- **Prioridad:** BAJO
- **BD / Auth:** BD: — / Auth: —
- **Relaciones:** Integrado en los portales web internos de Laravel (webserver) y en el interfaz de Tryton (appserver) para previsualizar reportes JasperReports y facturas antes de enviarlas al cliente. También utilizado en Paperless-NGX (catalogserver) para previsualizar documentos archivados.

### 🖥️ catalogserver/ — Gestión Documental & OCR

Centro de gestión inteligente de documentos. Paperless-NGX como núcleo de archivo digital, con motores OCR y extracción de datos para procesar documentos de forma automática.

- **Puertos:** 6000-6099
- **BD Principal:** PostgreSQL 18 (Paperless-NGX nativo)
- **Auth Keycloak:** ✅ OIDC Keycloak nativo (django-allauth)

#### 1. Paperless-NGX

Sistema de gestión documental digital que convierte documentos físicos y digitales en un archivo inteligente y buscable. Escanea o recibe documentos por correo/carpeta vigilada, ejecuta OCR automático, clasifica el documento por tipo mediante IA, extrae datos clave (fecha, proveedor, importe) y los indexa para búsqueda full-text instantánea. Mantiene auditoría completa de accesos y modificaciones.

- **Puerto:** 6000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak
- **Relaciones:** SSO con Keycloak (authserver). Almacena metadatos en PostgreSQL (commonserver) y archivos en MinIO (commonserver). Recibe documentos por correo desde Postfix (mailserver). Alimenta facturas escaneadas al flujo SIAT de Django (apigateway). Elasticsearch (searchengine) indexa su contenido para búsqueda global. Kimios (workflowserver) complementa con flujos BPM de aprobación de documentos.

#### 2. Tabula

Herramienta de extracción de tablas desde documentos PDF. Detecta y extrae automáticamente tablas de cualquier PDF — incluso PDFs escaneados con OCR previo — y las convierte a formatos estructurados CSV o XLSX que pueden ser procesados por otros sistemas.

- **Puerto:** 6010
- **Prioridad:** ALTO
- **BD / Auth:** BD: — / Auth: —
- **Relaciones:** Complementa a Paperless-NGX (catalogserver) — los documentos que contienen tablas de datos (facturas de proveedores, estados de cuenta bancarios, reportes de inventario en PDF) pasan por Tabula antes de ser archivados. Los datos extraídos se envían a Tryton (appserver) para conciliaciones o a Superset (biserver) para análisis.

#### 3. Camelot

Librería Python avanzada para extracción de tablas de PDFs con estructuras complejas. Ofrece dos modos: lattice (tablas con bordes visibles) y stream (tablas sin bordes, detectadas por espaciado). Más preciso que Tabula para documentos complejos como estados financieros o informes técnicos.

- **Puerto:** 6020
- **Prioridad:** ALTO
- **BD / Auth:** BD: — / Auth: —
- **Relaciones:** Expone una API REST para ser invocado desde pipelines Airflow (orchestrator) en procesos batch de extracción masiva de datos de documentos. Complementa a Tabula — Camelot se usa cuando Tabula no logra una extracción precisa. Los datos extraídos se ingresan a Tryton (appserver) o se almacenan en PostgreSQL para análisis en Superset.

#### 4. Tesseract + EasyOCR

Motores de reconocimiento óptico de caracteres (OCR) de código abierto. Tesseract (Google) es el motor más maduro con soporte de 100+ idiomas incluyendo español. EasyOCR (Jaided AI) complementa con mejor reconocimiento de texto en imágenes complejas y soporte para quechua y aymara. Ambos soportan aceleración GPU para procesar volúmenes altos.

- **Puerto:** 6030
- **Prioridad:** ALTO
- **BD / Auth:** BD: — / Auth: —
- **Relaciones:** Son el motor de OCR que utiliza Paperless-NGX (catalogserver) internamente para hacer buscables los documentos escaneados. También procesan imágenes de documentos antes de que Tabula o Camelot extraigan tablas. Los documentos escaneados que llegan por correo a Postfix (mailserver) son procesados por este motor antes de archivarse.

### 🖥️ commonserver/ — Servicios Compartidos Core

Infraestructura de datos compartida. PostgreSQL 18 es el motor único de base de datos estructurada del stack. Redis para caché y colas. MinIO para almacenamiento de objetos.

- **Puertos:** 7000-7099
- **BD Principal:** PostgreSQL 18 (principal) · MySQL 8 (aislado para 3 apps)
- **Auth Keycloak:** — (infraestructura base)

#### 1. PostgreSQL 18

Sistema gestor de bases de datos relacional avanzado y de código abierto. Motor principal del stack que sirve a más de 55 aplicaciones. PostgreSQL 18 aporta mejoras significativas en rendimiento de consultas, particionado, replicación lógica y soporte JSON avanzado. Configurado en modo alta disponibilidad con Patroni para failover automático sin pérdida de datos.

- **Puerto:** 7432
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: Es el servidor / Auth: —
- **Relaciones:** Absolutamente todas las aplicaciones del stack que requieren base de datos relacional usan este PostgreSQL: Tryton, Keycloak, Saleor, Paperless, GitLab, Taiga, OpenProject, Superset, Airflow, Zammad, Nextcloud, EspoCRM, Wiki.js, Cal.com, LimeSurvey, Bareos, Vault, Kong, DocuSeal y muchas más. HAProxy (commonserver) distribuye la carga entre réplicas.

#### 2. MySQL 8.0+

Motor de base de datos relacional secundario, presente en el stack exclusivamente por requerimientos técnicos de tres herramientas de terceros que no soportan PostgreSQL: OrangeHRM (RRHH), Easy!Appointments (citas) y FreePBX (telefonía). Instancia completamente aislada, sin acceso externo directo.

- **Puerto:** 7306
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: Es el servidor secundario / Auth: —
- **Relaciones:** Sirve únicamente a OrangeHRM (appserver), Easy!Appointments (webserver) y FreePBX (commsserver). SymmetricDS (dbsyncserver) sincroniza los datos necesarios entre MySQL y PostgreSQL para mantener consistencia con el resto del stack. El roadmap contempla migración a alternativas PostgreSQL-nativas cuando estas maduren.

#### 3. Redis 7.0+

Almacén de datos en memoria de ultra-baja latencia. Cumple múltiples roles en el stack: caché de consultas frecuentes para acelerar aplicaciones, almacén de sesiones de usuario para Keycloak y Laravel, broker de cola de tareas para Celery workers, y sistema pub/sub para notificaciones en tiempo real entre servicios.

- **Puerto:** 7379
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: Es el servidor de caché / Auth: —
- **Relaciones:** Utilizado por: Laravel/Saleor (webserver) para caché y sesiones, Celery (apigateway) como broker de cola de tareas SIAT, Keycloak (authserver) para caché de sesiones, Tryton (appserver) para caché de consultas frecuentes, y RabbitMQ (messagequeue) como alternativa de cola ligera. Modo sentinel para alta disponibilidad.

#### 4. MinIO

Almacenamiento de objetos de alto rendimiento compatible con la API S3 de Amazon. Almacena cualquier tipo de archivo binario: backups de bases de datos, documentos de Paperless-NGX, imágenes de productos Saleor, assets de e-commerce, chunks de logs Loki, trazas Tempo, reportes PDF de JasperReports y archivos adjuntos de correo.

- **Puerto:** 7000/7001
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: — / Auth: Credenciales S3
- **Relaciones:** Paperless-NGX (catalogserver) almacena documentos archivados. Bareos (backupserver) deposita backups de PostgreSQL y MySQL. Loki (monitorserver) almacena chunks de logs. Tempo (monitorserver) almacena trazas. GitLab (cicdserver) registros Docker. JasperReports (reportserver) exporta PDFs. Soporte WORM (Write-Once-Read-Many) para archivos inmutables de cumplimiento legal.

#### 5. PgAdmin 4

Interfaz de administración web para PostgreSQL. Permite explorar el esquema de bases de datos, ejecutar consultas SQL arbitrarias, revisar planes de ejecución (EXPLAIN), monitorear queries activas, gestionar usuarios/roles/permisos y hacer dumps manuales de bases de datos.

- **Puerto:** 7050
- **Prioridad:** ALTO
- **BD / Auth:** BD: PostgreSQL 18 (admin) / Auth: Auth interna
- **Relaciones:** Administra exclusivamente PostgreSQL (commonserver). Acceso restringido a la red interna únicamente — no expuesto a internet. Útil para el equipo de DevOps para diagnóstico de rendimiento de queries de Tryton, Saleor, Superset y otras aplicaciones. SSO básico o auth interna.

#### 6. Portainer CE

Plataforma de gestión visual de contenedores Docker y clústeres Kubernetes. Permite desplegar stacks completos desde archivos docker-compose, monitorear recursos (CPU, RAM, red) de cada contenedor en tiempo real, ver logs, ejecutar comandos dentro de contenedores y gestionar volúmenes y redes.

- **Puerto:** 7090
- **Prioridad:** ALTO
- **BD / Auth:** BD: — / Auth: LDAP Keycloak
- **Relaciones:** Gestiona todos los contenedores del stack — desde Keycloak (authserver) hasta Saleor (webserver). Sus métricas complementan a Prometheus (monitorserver) para visibilidad operacional. Permite al equipo de operaciones desplegar actualizaciones sin acceso SSH directo. Se integra con GitLab CI/CD (cicdserver) para despliegues automatizados.

#### 7. HAProxy

Balanceador de carga y proxy TCP/HTTP de alta disponibilidad, especializado en la distribución de conexiones de base de datos. Detecta automáticamente qué nodo PostgreSQL es el primario (escrituras) y cuáles son réplicas (lecturas), distribuyendo el tráfico de forma inteligente.

- **Puerto:** 7080
- **Prioridad:** ALTO
- **BD / Auth:** BD: — / Auth: —
- **Relaciones:** Se coloca entre todas las aplicaciones del stack y PostgreSQL. Redirige escrituras al nodo primario (Tryton, Saleor, Keycloak) y lecturas a réplicas (Superset, reportes de solo lectura). Trabaja junto a Patroni para el failover automático — cuando Patroni promueve una nueva primaria, HAProxy redirige el tráfico en segundos.

#### 8. Citus (Extensión PostgreSQL)

Extensión de sharding horizontal para PostgreSQL que convierte una instancia PostgreSQL en un cluster distribuido. Permite distribuir tablas grandes (como las de auditoría, analytics o historial de transacciones de Tryton) entre múltiples nodos, multiplicando la capacidad de almacenamiento y consulta sin cambiar el código de ninguna aplicación.

- **Puerto:** 7432
- **Prioridad:** MEDIO
- **BD / Auth:** BD: Es una extensión de PostgreSQL / Auth: —
- **Relaciones:** Extensión transparente para todas las aplicaciones que usan PostgreSQL — Tryton, Saleor, Superset, etc. no saben que están usando Citus. Especialmente útil para las tablas de analítica de Superset (biserver) y los logs de auditoría de Wazuh. Se activa por tabla, permitiendo una adopción gradual.

### 🖥️ mailserver/ — Sistema de Correo Empresarial

Infraestructura de correo completa y autogestionada. Envío SMTP, recepción IMAP, webmails, antispam y antivirus. Sin dependencia de servicios de correo externos (Gmail, Outlook).

- **Puertos:** 8000-8099 + STD
- **BD Principal:** PostgreSQL 18 (todos los componentes)
- **Auth Keycloak:** ⚠️ SSO básico vía OAuth2-Proxy + NGINX

#### 1. Postfix

Servidor SMTP (Simple Mail Transfer Protocol) de código abierto, el más utilizado en Internet. Gestiona el envío de correo saliente desde todas las aplicaciones del stack, implementa autenticación SASL para envío seguro, fuerza TLS en tránsito y configura SPF, DKIM y DMARC para garantizar la entregabilidad del correo.

- **Puerto:** 25/587
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: SASL local
- **Relaciones:** Todas las aplicaciones del stack que envían correo lo hacen a través de Postfix: Tryton (notificaciones de pedidos/facturas), Keycloak (emails de recuperación de contraseña), Zammad (respuestas a tickets), OrangeHRM (recibos de nómina), JasperReports (reportes programados), Alertmanager (alertas de infraestructura). Amavis lo complementa para antispam/antivirus.

#### 2. Dovecot

Servidor IMAP y POP3 para la recepción y almacenamiento de correo entrante. Gestiona los buzones de los usuarios, implementa IDLE para sincronización en tiempo real en clientes de correo, soporta cuotas de buzón y autentica a los usuarios contra PostgreSQL o LDAP.

- **Puerto:** 143/993
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: SQL/LDAP
- **Relaciones:** Trabaja en pareja con Postfix — Postfix entrega el correo entrante a Dovecot, y Dovecot lo almacena y sirve a los clientes. Roundcube y Cypht (mailserver) se conectan a Dovecot vía IMAP para mostrar los correos. Paperless-NGX (catalogserver) puede conectarse a una carpeta IMAP de Dovecot para archivar facturas automáticamente.

#### 3. Roundcube

Cliente de webmail con interfaz web moderna y completa. Permite a los usuarios leer, redactar y organizar su correo directamente desde el navegador sin instalar ningún cliente. Soporta carpetas IMAP, filtros de mensaje, libreta de contactos, firma de correo y búsqueda avanzada.

- **Puerto:** 8080
- **Prioridad:** ALTO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OAuth2-Proxy
- **Relaciones:** Se conecta a Dovecot (mailserver) vía IMAP para mostrar los correos. SSO básico con Keycloak vía OAuth2-Proxy (authserver). Nextcloud Calendar (vdiserver) puede sincronizar citas del correo. El autocompletado de destinatarios consulta la libreta de contactos de Nextcloud o directamente a PostfixAdmin.

#### 4. Cypht

Cliente de webmail alternativo, modular y minimalista. Su principal característica es la capacidad de agregar múltiples cuentas de correo (de diferentes proveedores y protocolos), feeds RSS y otras fuentes de información en una sola interfaz unificada.

- **Puerto:** 8081
- **Prioridad:** BAJO
- **BD / Auth:** BD: PostgreSQL / Auth: Auth local
- **Relaciones:** Se conecta a Dovecot (mailserver) vía IMAP igual que Roundcube, pero ofrece una alternativa de interfaz para usuarios con necesidades especiales (múltiples cuentas, lectura de RSS junto al correo). Complementa a Roundcube para usuarios avanzados.

#### 5. PostfixAdmin

Panel de administración web para Postfix. Permite gestionar dominios de correo, crear y eliminar buzones de usuario, configurar alias de correo, establecer cuotas de almacenamiento y delegarle la gestión de sus propios dominios a administradores de dominio sin acceso SSH.

- **Puerto:** 8082
- **Prioridad:** ALTO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: Auth interna
- **Relaciones:** Administra la configuración de Postfix (mailserver) y Dovecot (mailserver) almacenada en PostgreSQL (commonserver). Cuando se crea un nuevo usuario en OrangeHRM (appserver) o Keycloak (authserver), el proceso de onboarding puede crear automáticamente su buzón de correo vía la API de PostfixAdmin.

#### 6. SpamAssassin

Motor de filtrado anti-spam basado en análisis bayesiano y reglas heurísticas. Evalúa cada mensaje entrante asignándole una puntuación de spam según múltiples criterios: listas negras RBL, análisis de cabeceras, análisis de contenido, reputación de dominio y patrones estadísticos aprendidos.

- **Puerto:** —
- **Prioridad:** ALTO
- **BD / Auth:** BD: PostgreSQL (bayes) / Auth: —
- **Relaciones:** Se integra con Postfix (mailserver) vía Amavis o como milter directo. Los mensajes clasificados como spam son etiquetados o rechazados antes de llegar a Dovecot. Comparte su aprendizaje bayesiano en PostgreSQL (commonserver). Complementa a ClamAV para una protección de gateway completa.

#### 7. ClamAV

Motor antivirus de código abierto especializado en la detección de malware en correo electrónico. Escanea todos los adjuntos de correo entrante en tiempo real, detectando virus, troyanos, ransomware y otros tipos de malware. Actualiza su base de firmas automáticamente varias veces al día.

- **Puerto:** —
- **Prioridad:** ALTO
- **BD / Auth:** BD: — / Auth: —
- **Relaciones:** Se integra con Postfix (mailserver) vía Amavis para escanear adjuntos antes de que lleguen a los buzones Dovecot. Los archivos infectados son cuarentenados o rechazados y el evento se registra en los logs que Loki (monitorserver) recopila para análisis en Grafana.

### 🖥️ vdiserver/ — Workspace Digital & VDI

Entorno de trabajo digital completo. Escritorios virtuales en el navegador, almacenamiento colaborativo, suite ofimática y calendario compartido.

- **Puertos:** 9000-9099
- **BD Principal:** PostgreSQL 18 (Kasm, Nextcloud)
- **Auth Keycloak:** ✅ OIDC/SAML Keycloak (Kasm, Nextcloud, OnlyOffice)

#### 1. Kasm Workspaces

Plataforma de Virtual Desktop Infrastructure (VDI) que ejecuta escritorios y aplicaciones completas directamente en el navegador web, sin instalar nada en el dispositivo del usuario. Cada sesión es un contenedor aislado que se destruye al terminar, garantizando la seguridad de los datos. Soporta grabación de sesiones y auditoría completa.

- **Puerto:** 9443
- **Prioridad:** ALTO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC/SAML Keycloak
- **Relaciones:** SSO con Keycloak (authserver) via OIDC/SAML. Los escritorios virtuales (Fedora KDE) tienen acceso a Nextcloud Files (vdiserver) para los archivos del usuario. Las sesiones se registran y los logs van a Loki (monitorserver). Acceso a aplicaciones como Tryton (appserver) desde dentro del escritorio virtual, sin exponer el acceso directo al exterior.

#### 2. Fedora 43 KDE Plasma

Imagen de escritorio virtual completo basada en Fedora Linux con el entorno de escritorio KDE Plasma. Incluye suite ofimática LibreOffice, navegadores, herramientas de desarrollo, gestor de archivos y aplicaciones de productividad. Disponible como imagen de contenedor en Kasm Workspaces.

- **Puerto:** 9443
- **Prioridad:** ALTO
- **BD / Auth:** BD: — / Auth: Hereda de Kasm
- **Relaciones:** Es la imagen de escritorio que Kasm Workspaces (vdiserver) instancia para los usuarios. Tiene acceso montado a Nextcloud Files para los archivos de trabajo, puede conectarse a OnlyOffice para edición colaborativa, y accede a todas las aplicaciones internas del stack vía el navegador interno.

#### 3. OnlyOffice Docs

Suite ofimática online para edición colaborativa en tiempo real de documentos Word, hojas de cálculo Excel y presentaciones PowerPoint, con total compatibilidad de formatos Microsoft Office. Múltiples usuarios pueden editar el mismo documento simultáneamente con presencia visual en tiempo real.

- **Puerto:** 9080
- **Prioridad:** MEDIO
- **BD / Auth:** BD: PostgreSQL (config) / Auth: OIDC Keycloak
- **Relaciones:** Se integra con Nextcloud Files (vdiserver) para abrir y guardar documentos directamente. También integrado con Paperless-NGX (catalogserver) para editar documentos archivados. SSO con Keycloak (authserver). Los documentos editados se guardan de vuelta en MinIO (commonserver) vía Nextcloud.

#### 4. Nextcloud Files

Plataforma de almacenamiento colaborativo y sincronización de archivos empresarial. Permite a los usuarios guardar, organizar, compartir y acceder a sus archivos desde cualquier dispositivo. Soporta sincronización de escritorio/móvil, compartición interna y externa con enlace, permisos granulares y versionado de archivos.

- **Puerto:** 9081
- **Prioridad:** ALTO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: SAML Keycloak
- **Relaciones:** Usa PostgreSQL (commonserver) y almacena archivos en MinIO (commonserver) como backend S3. SSO con Keycloak (authserver) vía SAML. OnlyOffice (vdiserver) abre documentos de Nextcloud. Paperless-NGX (catalogserver) puede archivar desde carpetas Nextcloud. Wiki.js (appserver) puede adjuntar archivos de Nextcloud.

#### 5. Nextcloud Calendar

Calendario empresarial compartido con soporte CalDAV estándar. Permite gestionar eventos personales y de equipo, reservar recursos como salas de reuniones y equipos, recibir invitaciones de calendario y sincronizar con clientes de escritorio y móvil.

- **Puerto:** 9082
- **Prioridad:** MEDIO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: SAML Keycloak
- **Relaciones:** Comparte base de datos y autenticación con Nextcloud Files (vdiserver). Se sincroniza con Roundcube (mailserver) para ver el calendario junto al correo. Easy!Appointments (webserver) puede publicar citas en el calendario del personal. Cal.com (helpdeskserver) puede conectarse para mostrar disponibilidad.

### 🖥️ monitorserver/ — Monitoreo 360° & Observabilidad

Stack de observabilidad completo LGTM+Z+W: métricas, logs, trazas, infraestructura y seguridad en un único panel de control. Visibilidad total del stack en tiempo real.

- **Puertos:** 10000-10099
- **BD Principal:** PostgreSQL 18 (Zabbix, Grafana)
- **Auth Keycloak:** ✅ OAuth2 Keycloak (Grafana) · LDAP (Zabbix)

#### 1. Zabbix 7.0+

Plataforma de monitoreo de infraestructura IT de nivel empresarial. Despliega agentes ligeros en todos los servidores para monitorear CPU, RAM, disco, red, procesos y servicios del sistema operativo. Soporta monitoreo SNMP para dispositivos de red, checks de disponibilidad de servicios (HTTP, TCP, ICMP) y mantiene un inventario automático de todos los activos IT.

- **Puerto:** 10000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: LDAP Keycloak
- **Relaciones:** Monitorea todos los servidores del stack (31 servidores). Sus datos de infraestructura se visualizan en Grafana (monitorserver) junto a las métricas de aplicación de Prometheus. Alertas enviadas a Mattermost (commsserver) y por correo Postfix (mailserver). Sincroniza con Keycloak (authserver) vía LDAP para usuarios.

#### 2. Prometheus

Sistema de monitoreo y alerta basado en series de tiempo, diseñado para entornos cloud-native y microservicios. Recopila métricas de todas las aplicaciones del stack mediante scraping HTTP de endpoints /metrics (exporters). Almacena datos con alta eficiencia y soporta el potente lenguaje de consulta PromQL.

- **Puerto:** 10001
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: — (TSDB propio) / Auth: —
- **Relaciones:** Scrapea métricas de: Node Exporter (todos los servidores), PostgreSQL Exporter (commonserver), Redis Exporter (commonserver), NGINX Exporter (proxyserver), Keycloak (authserver), Tryton (appserver), Django (apigateway), Saleor (webserver) y más. Alimenta a Grafana (monitorserver) con todos estos datos. Dispara alertas a Alertmanager.

#### 3. Grafana

Plataforma de observabilidad y visualización de datos. El panel de control unificado del stack que agrega en una sola interfaz métricas de Prometheus, logs de Loki, trazas de Tempo, datos de PostgreSQL, alertas de Zabbix y datos de seguridad de Wazuh. Permite crear dashboards interactivos sin programar.

- **Puerto:** 10002
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OAuth2 Keycloak
- **Relaciones:** Consume datos de: Prometheus (métricas de aplicaciones), Loki (logs de todos los contenedores), Tempo (trazas distribuidas), PostgreSQL Tryton (métricas de negocio en tiempo real), Zabbix (infraestructura IT). SSO con Keycloak (authserver). Sus alertas van a Alertmanager, que las distribuye a Mattermost, Email y PagerDuty.

#### 4. Alertmanager

Componente de Prometheus para la gestión inteligente de alertas. Recibe alertas de Prometheus (y de Grafana), las deduplica para evitar tormentas de alertas, las agrupa por servicio, las silencia durante mantenimientos y las enruta a los canales de notificación correctos según reglas configurables.

- **Puerto:** 10003
- **Prioridad:** ALTO
- **BD / Auth:** BD: — / Auth: —
- **Relaciones:** Recibe alertas de Prometheus (monitorserver) y Grafana (monitorserver). Enruta notificaciones a: Mattermost (commsserver) por canal de alertas, correo a través de Postfix (mailserver), PagerDuty para incidentes críticos, y webhooks personalizados. Los silenciados y resoluciones se registran en PostgreSQL.

#### 5. Loki + Grafana Alloy

Sistema de agregación y consulta de logs a escala. Grafana Alloy (el nuevo agente unificado que reemplaza a Promtail) recopila logs de todos los contenedores Docker y servicios del sistema, los etiqueta con metadatos (servidor, aplicación, entorno) y los envía a Loki para almacenamiento y consulta. Loki usa LogQL para consultas similares a PromQL.

- **Puerto:** 10004
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: MinIO (chunks) / Auth: —
- **Relaciones:** Grafana Alloy recopila logs de absolutamente todos los contenedores del stack. Loki almacena los logs en MinIO (commonserver) como chunks S3. Grafana (monitorserver) consulta Loki para correlacionar logs con métricas Prometheus en el mismo panel de tiempo. Wazuh (securityserver) también puede enviar eventos de seguridad a Loki.

#### 6. Tempo

Backend de trazabilidad distribuida (distributed tracing) de Grafana. Recibe y almacena trazas OpenTelemetry, Jaeger y Zipkin de todas las aplicaciones del stack que instrumentan sus llamadas. Permite seguir una petición de usuario a través de todos los servicios que involucra, midiendo el tiempo de cada paso.

- **Puerto:** 10005
- **Prioridad:** ALTO
- **BD / Auth:** BD: MinIO (trazas) / Auth: —
- **Relaciones:** Las aplicaciones instrumentadas (Laravel, Django/SIAT, Saleor, Tryton) envían sus trazas OpenTelemetry a Tempo. Tempo almacena en MinIO (commonserver). Grafana (monitorserver) correlaciona trazas Tempo con logs Loki y métricas Prometheus en el mismo panel — cuando hay un error en Grafana, se puede ir directamente a la traza, los logs y las métricas del momento exacto.

### 🖥️ vcardserver/ — Tarjetas Digitales

Identidad digital profesional para empleados y contactos comerciales. Tarjetas de presentación inteligentes con analíticas.

- **Puertos:** 11000-11099
- **BD Principal:** PostgreSQL 18
- **Auth Keycloak:** ✅ OIDC Keycloak

#### 1. CardMesh

Plataforma de tarjetas de presentación digitales. Cada empleado tiene su perfil profesional con foto, cargo, datos de contacto, redes sociales y un código QR único. Las tarjetas se comparten por NFC, QR o enlace, registran analíticas de visitas y se sincronizan con el CRM.

- **Puerto:** 11000
- **Prioridad:** MEDIO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak
- **Relaciones:** SSO con Keycloak (authserver) — los datos del perfil se toman del directorio Keycloak. Cuando alguien escanea una tarjeta, el contacto se crea automáticamente en EspoCRM (projectserver). Los datos de empleados provienen de OrangeHRM (appserver) para mantener perfiles actualizados. Usa PostgreSQL (commonserver).

### 🖥️ biserver/ — Business Intelligence

Análisis de datos empresariales y dashboards de negocio. Conexión directa a los datos de Tryton en PostgreSQL para KPIs en tiempo real.

- **Puertos:** 12000-12099
- **BD Principal:** PostgreSQL 18 (datasource y metastore)
- **Auth Keycloak:** ✅ OIDC Keycloak (nativo)

#### 1. Apache Superset 4.1+

Plataforma de Business Intelligence moderna y de código abierto. Permite a usuarios de negocio (sin necesidad de programar) explorar datos de forma ad-hoc, crear visualizaciones con más de 40 tipos de gráficos, construir dashboards interactivos compartibles y ejecutar consultas SQL avanzadas en el SQL Lab. Control de acceso granular por dataset.

- **Puerto:** 12000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak
- **Relaciones:** Conecta directamente a PostgreSQL de Tryton (commonserver/appserver) como datasource principal — dashboards de ventas, inventario, producción y contabilidad en tiempo real. Airflow (orchestrator) puede recargar datasets automáticamente. SSO con Keycloak (authserver). OpenMetadata (datacatalog) cataloga los datasets de Superset. Grafana (monitorserver) complementa con métricas técnicas de infraestructura.

### 🖥️ workflowserver/ — Flujo Documental & Búsqueda

BPM documental y motor de búsqueda empresarial. Kimios gestiona flujos de aprobación de documentos. Solr provee búsqueda full-text de alto rendimiento.

- **Puertos:** 13000-13099
- **BD Principal:** PostgreSQL 18 (Kimios DMS)
- **Auth Keycloak:** ✅ LDAP via Keycloak federation

#### 1. Kimios DMS 1.3+

Sistema de Gestión Documental (DMS) con capacidades BPM (Business Process Management). Permite definir flujos de trabajo para la aprobación, revisión y firma de documentos, con múltiples participantes, rutas condicionales, plazos y escalaciones. Mantiene un histórico completo de versiones y un registro de auditoría por documento.

- **Puerto:** 13000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: LDAP Keycloak
- **Relaciones:** Complementa a Paperless-NGX (catalogserver) — mientras Paperless archiva y clasifica, Kimios gestiona los flujos de aprobación (ej: una factura escaneada en Paperless va a Kimios para aprobación del gerente). Integra con Apache Solr (workflowserver) para búsqueda full-text. Usuarios gestionados por Keycloak (authserver) vía LDAP. DocuSeal (esignserver) puede firmar los documentos aprobados.

#### 2. Apache Solr 9.0+

Motor de búsqueda empresarial de alto rendimiento basado en Apache Lucene. Indexa contenido textual de múltiples fuentes, ofrece búsqueda facetada (filtros por categoría, fecha, autor), highlighting de términos buscados en los resultados, auto-completado y relevancia configurable.

- **Puerto:** 13001
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: — (índices en disco) / Auth: —
- **Relaciones:** Indexa documentos de Kimios DMS (workflowserver) y de Paperless-NGX (catalogserver) para una búsqueda empresarial unificada. Complementa a Elasticsearch (searchengine) — Solr para documentos estructurados y empresariales, Elasticsearch para logs y analytics. Airflow (orchestrator) puede programar reindexaciones periódicas.

### 🖥️ assettracking/ — Geolocalización GPS

Rastreo GPS en tiempo real de vehículos, activos y personal. Soporte para más de 200 protocolos de dispositivos GPS.

- **Puertos:** 14000-14099
- **BD Principal:** PostgreSQL 18 (nativo)
- **Auth Keycloak:** ⚠️ Integración API con tokens Keycloak

#### 1. Traccar 6.5+

Plataforma de rastreo GPS de código abierto compatible con más de 200 modelos de dispositivos GPS y protocolos de comunicación. Muestra posiciones en tiempo real en mapas, define geofences con alertas de entrada/salida, registra el historial completo de rutas, calcula velocidades y tiempos de parada, y genera reportes de kilometraje.

- **Puerto:** 14000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: API REST + tokens
- **Relaciones:** Alimenta a Fleetbase (logisticsserver) con posiciones en tiempo real de los vehículos de reparto para visualización en el panel logístico. Los datos de rutas son analizados en Superset (biserver) para optimización de flota. Los eventos de geofence (entrada/salida de zonas) disparan alertas en Alertmanager (monitorserver). PostgreSQL en commonserver.

### 🖥️ logisticsserver/ — Gestión Logística

Operaciones logísticas end-to-end. Fleetbase gestiona el ciclo completo de despacho: desde la orden hasta la entrega con prueba fotográfica.

- **Puertos:** 15000-15099
- **BD Principal:** PostgreSQL (principal) · MySQL (componente FleetOps)
- **Auth Keycloak:** ⚠️ OIDC en desarrollo

#### 1. Fleetbase + FleetOps

Plataforma logística integral para empresas de reparto, distribución y última milla. Fleetbase es el core (gestión de órdenes, clientes, rutas, conductores) y FleetOps es el módulo de operaciones en campo (app móvil para conductores, firma digital de entrega, fotos como prueba de entrega - POD). Gestiona flotas de vehículos con planificación de rutas.

- **Puerto:** 15000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL / MySQL / Auth: OIDC (dev)
- **Relaciones:** Recibe órdenes de despacho desde Saleor (webserver) o Tryton (appserver) cuando se confirma una venta con entrega a domicilio. Traccar (assettracking) alimenta las posiciones GPS en tiempo real de los conductores. Las entregas confirmadas actualizan el estado del pedido en Tryton. Los costos de entrega se registran en Tryton Contabilidad. PostgreSQL en commonserver.

### 🖥️ orchestrator/ — Orquestación de Workflows

Motor de orquestación de pipelines de datos y automatización de procesos empresariales. Airflow programa y ejecuta cualquier tarea de forma confiable y auditada.

- **Puertos:** 16000-16099
- **BD Principal:** PostgreSQL 18 (Airflow metastore)
- **Auth Keycloak:** ✅ OIDC Keycloak (Flask-AppBuilder)

#### 1. Apache Airflow 2.10+

Plataforma de orquestación de workflows definidos como código Python (DAGs - Directed Acyclic Graphs). Cada DAG define una serie de tareas con dependencias entre ellas, programación temporal (cron), reintentos automáticos en fallo y registro completo de ejecuciones. Interfaz web para monitorear el estado de todos los pipelines.

- **Puerto:** 16000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak
- **Relaciones:** Orquesta los procesos más críticos del stack: ETL nocturno Tryton→Superset (actualización de datasets de negocio), generación automática mensual de reportes SIN en JasperReports (reportserver), reindexación de documentos en Solr/Elasticsearch (searchengine/workflowserver), sincronización OpenMetadata (datacatalog) con fuentes de datos, procesos de cierre contable en Tryton. Celery (apigateway) complementa para tareas en tiempo real.

### 🖥️ datacatalog/ — Catálogo de Datos Empresarial

Gobernanza y catalogación de todos los activos de datos del stack. Descubrimiento automático, linaje, calidad y glosario de negocio unificado.

- **Puertos:** 17000-17099
- **BD Principal:** MySQL→PostgreSQL (migración en proceso)
- **Auth Keycloak:** ✅ OIDC Keycloak (nativo)

#### 1. OpenMetadata 1.6+

Plataforma de catalogación de datos de nueva generación. Descubre automáticamente tablas de bases de datos, APIs y dashboards, construye el linaje de datos (qué proceso genera qué dato a partir de qué fuente), evalúa la calidad de los datos con perfiles automáticos, y mantiene un glosario de negocio donde cada término tiene su definición y propietario.

- **Puerto:** 17000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: MySQL→PostgreSQL / Auth: OIDC Keycloak
- **Relaciones:** Conecta con PostgreSQL de Tryton (appserver) para catalogar todas las tablas de negocio. Descubre datasets de Superset (biserver) y dashboards asociados. Se integra con Airflow (orchestrator) para mostrar el linaje de los pipelines ETL. Elasticsearch (searchengine) potencia la búsqueda dentro del catálogo. SSO con Keycloak (authserver).

### 🖥️ backupserver/ — Backup & Disaster Recovery

Protección completa de datos del stack. Backup programado de todos los servidores y BD, DR automatizado en Kubernetes, validación de integridad.

- **Puertos:** 18000-18099
- **BD Principal:** PostgreSQL 18 (catálogo Bareos)
- **Auth Keycloak:** ⚠️ Auth básica

#### 1. Bareos 23.0+

Sistema de backup empresarial open source derivado de Bacula. Arquitectura cliente/servidor con Director (políticas), Storage Daemon (almacenamiento) y File Daemon (clientes en cada servidor). Realiza dumps automáticos de PostgreSQL y MySQL, backups de archivos, deduplicación, compresión y cifrado AES-256. Retención configurable por política.

- **Puerto:** 18000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: —
- **Relaciones:** El Director Bareos gestiona backups de todos los servidores del stack (31 servidores). Los dumps de PostgreSQL (commonserver) y MySQL (commonserver) se envían cifrados a MinIO (commonserver) como destino primario y opcionalmente a un bucket S3 en AWS como destino secundario. Goss (backupserver) valida la integridad. Alertmanager (monitorserver) notifica si algún backup falla.

#### 2. Velero (DR Kubernetes)

Herramienta de backup y recuperación ante desastres específica para clústeres Kubernetes. Realiza snapshots de volúmenes persistentes (PVC), respalda todos los manifiestos Kubernetes (Deployments, Services, ConfigMaps, Secrets) y permite restaurar el clúster completo o namespaces específicos en un entorno diferente.

- **Puerto:** 18001
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: — / Auth: —
- **Relaciones:** Programado cada 4 horas, envía backups a MinIO (commonserver) como almacenamiento primario y a un bucket S3 en AWS como DR site remoto. En caso de desastre en el clúster principal, Velero restaura toda la infraestructura Kubernetes en el clúster DR de AWS en menos de 30 minutos. Trabaja junto a Bareos (backupserver) para una cobertura completa.

#### 3. Goss

Herramienta de validación de infraestructura como código. Define pruebas automáticas que verifican el estado correcto del sistema: que los servicios estén corriendo, que los puertos estén abiertos, que los archivos existan, que las consultas de base de datos devuelvan resultados esperados.

- **Puerto:** —
- **Prioridad:** ALTO
- **BD / Auth:** BD: — / Auth: —
- **Relaciones:** Integrado en el pipeline GitLab CI/CD (cicdserver) para validar que los backups son restaurables. Después de cada restauración de prueba programada por Bareos, Goss ejecuta su suite de tests para confirmar que Tryton responde, que PostgreSQL tiene datos, que Keycloak funciona, etc. Reporta resultados a Grafana (monitorserver).

### 🖥️ apigateway/ — API Gateway & SIAT Bolivia

Gateway central de todas las APIs del stack y motor de facturación electrónica Bolivia SIN. Kong como proxy de API, Django como motor SIAT.

- **Puertos:** 19000-19099
- **BD Principal:** PostgreSQL 18 (Kong, Django)
- **Auth Keycloak:** ✅ OIDC Keycloak (Kong plugin + Django middleware)

#### 1. Kong Gateway 3.8+ OSS

API Gateway de alto rendimiento y código abierto. Actúa como proxy inteligente delante de todas las APIs del stack: rate limiting por consumidor, autenticación JWT/OAuth2 validando tokens Keycloak, transformación de peticiones y respuestas, logging centralizado, métricas por endpoint, circuit breaking y enrutamiento condicional.

- **Puerto:** 19000
- **Prioridad:** ALTO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak (plugin)
- **Relaciones:** Proxy centralizado para todas las APIs: Django SIAT (apigateway), Laravel REST (webserver), Saleor GraphQL (webserver), Tryton API (appserver). Valida tokens Keycloak (authserver) en cada petición. Sus métricas van a Prometheus (monitorserver). Los logs van a Loki (monitorserver). El routing pasa primero por NGINX (proxyserver).

#### 2. Django REST + SIAT Bolivia

API especializada en facturación electrónica según el Sistema de Impuestos Nacionales (SIN) de Bolivia. Implementa la generación del Código Único de Factura (CUF), la firma digital XML de facturas según normativa boliviana, el envío en línea y en contingencia offline, la consulta de NIT/RUC y la anulación de facturas.

- **Puerto:** 19001
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak
- **Relaciones:** Lee datos de ventas de Tryton (appserver) para generar las facturas. Envía facturas firmadas al servicio web del SIN Bolivia. Actualiza el estado de la factura en Tryton una vez confirmada. Celery (apigateway) gestiona el reintento automático en caso de fallo de conectividad con el SIN. JasperReports (reportserver) genera el PDF de la factura para enviar al cliente. Paperless-NGX (catalogserver) archiva cada factura emitida.

#### 3. Celery Workers

Sistema de colas de tareas asíncronas distribuidas para Python. Permite ejecutar tareas costosas (envío de facturas al SIN, generación de reportes, sincronización de inventario) en segundo plano sin bloquear las peticiones del usuario. Cada worker puede especializarse en un tipo de tarea con prioridades diferentes.

- **Puerto:** 19002
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 · Redis (broker) / Auth: —
- **Relaciones:** Broker de mensajes: Redis (commonserver). Procesa: envíos SIAT Bolivia (apigateway), generación de reportes JasperReports (reportserver), notificaciones de correo Postfix (mailserver), sincronización Tryton Stock ↔︎ Saleor (webserver), actualizaciones masivas de inventario. Los resultados y errores de cada tarea se registran en PostgreSQL y son visibles en Grafana (monitorserver).

### 🖥️ messagequeue/ — Message Broker

Mensajería asíncrona entre microservicios. RabbitMQ provee colas confiables para eventos de dominio y comunicación desacoplada entre servicios.

- **Puertos:** 20000-20099
- **BD Principal:** — (almacenamiento en memoria/disco propio)
- **Auth Keycloak:** ⚠️ LDAP Keycloak federation

#### 1. RabbitMQ 3.13+

Message broker open source que implementa el protocolo AMQP. Desacopla los productores de mensajes de los consumidores — un servicio publica un evento y otros servicios lo consumen de forma independiente, sin que el productor necesite saber quiénes son los consumidores. Garantiza la entrega de mensajes incluso si el consumidor está temporalmente caído.

- **Puerto:** 20000
- **Prioridad:** MEDIO
- **BD / Auth:** BD: — / Auth: LDAP Keycloak
- **Relaciones:** Distribuye eventos de dominio entre servicios: cuando Tryton (appserver) actualiza el stock, publica un evento que Saleor (webserver) y Fleetbase (logisticsserver) consumen. Cuando Saleor recibe un pedido, publica un evento que Tryton y Celery (apigateway) consumen. Airflow (orchestrator) puede consumir eventos para disparar DAGs. Complementa a Redis como broker de Celery para mensajes más complejos.

### 🖥️ secretsvault/ — Secrets Management

Gestión centralizada y segura de todos los secretos del stack. Credenciales dinámicas, PKI interna, cifrado de datos sensibles.

- **Puertos:** 21000-21099
- **BD Principal:** PostgreSQL 18 (storage backend)
- **Auth Keycloak:** ✅ OIDC Keycloak (JWT auth method)

#### 1. HashiCorp Vault 1.18+

Plataforma de gestión de secretos de clase empresarial. En lugar de secretos estáticos (contraseñas en archivos .env), Vault genera credenciales dinámicas con TTL corto — cada aplicación solicita credenciales de PostgreSQL o MySQL al iniciar, las usa por 1 hora y Vault las rota automáticamente. Incluye PKI para emitir certificados TLS internos y cifrado de datos en reposo.

- **Puerto:** 21000
- **Prioridad:** MEDIO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak
- **Relaciones:** Provee credenciales dinámicas de PostgreSQL a: Tryton, Keycloak, Saleor, Django, GitLab, Superset y todas las demás aplicaciones. Genera certificados TLS internos para Linkerd (securityserver) y servicios inter-servicio. Django SIAT (apigateway) obtiene de Vault las credenciales de firma del SIN Bolivia. SSO con Keycloak (authserver). Los accesos se registran para auditoría.

### 🖥️ cicdserver/ — CI/CD & Testing

Gestión de código fuente y pipelines de integración/entrega continua. GitLab como centro de control del ciclo de vida del software del stack.

- **Puertos:** 22000-22099
- **BD Principal:** PostgreSQL 18 (GitLab)
- **Auth Keycloak:** ✅ SAML Keycloak (GitLab OmniAuth)

#### 1. GitLab CE 17.8+

Plataforma DevOps completa de código abierto. Centraliza todo el código fuente del stack (módulos Tryton Bolivia, APIs Django SIAT, módulos Laravel, personalizaciones de configuración). CI/CD para build automático de imágenes Docker, testing, escaneo de seguridad y deploy a Kubernetes. Registro Docker integrado. Gestión de issues y merge requests.

- **Puerto:** 22000
- **Prioridad:** MEDIO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: SAML Keycloak
- **Relaciones:** Repositorio central de todo el código propio del stack. Los pipelines de GitLab CI despliegan automáticamente a Kubernetes (Portainer en commonserver). K6 (cicdserver) ejecuta pruebas de carga. Trivy (cicdserver) escanea vulnerabilidades. Goss (backupserver) valida post-deploy. SSO con Keycloak (authserver) vía SAML. Los logs de los pipelines van a Loki (monitorserver).

#### 2. K6

Herramienta de testing de carga y rendimiento de código abierto. Define tests como scripts JavaScript que simulan cientos o miles de usuarios concurrentes haciendo peticiones reales a las APIs del stack. Mide tiempos de respuesta (p50, p95, p99), tasa de errores y throughput.

- **Puerto:** 22001
- **Prioridad:** MEDIO
- **BD / Auth:** BD: — / Auth: —
- **Relaciones:** Ejecutado automáticamente en los pipelines GitLab CI (cicdserver) antes de cada deploy a producción — si el rendimiento no cumple los umbrales definidos, el deploy se detiene. Los resultados van a Grafana (monitorserver) para comparación histórica. Prueba principalmente: APIs Django SIAT, API GraphQL Saleor, APIs Laravel, endpoints Tryton.

#### 3. Trivy

Escáner de seguridad de código abierto para contenedores y código. Analiza las imágenes Docker del stack buscando CVEs (vulnerabilidades conocidas) en los paquetes del sistema operativo y las dependencias de código. También escanea archivos de configuración IaC (Terraform, Kubernetes YAML) en busca de misconfiguraciones.

- **Puerto:** 22002
- **Prioridad:** MEDIO
- **BD / Auth:** BD: — / Auth: —
- **Relaciones:** Ejecutado en cada pipeline GitLab CI (cicdserver) en el stage de build. Si detecta vulnerabilidades de severidad CRÍTICA o ALTA en una imagen nueva, el pipeline falla y no se despliega. Los reportes de vulnerabilidades se almacenan en GitLab y se envían por correo Postfix (mailserver) al equipo de seguridad. Complementa a Wazuh (securityserver) para detección en tiempo de build.

### 🖥️ searchengine/ — Motores de Búsqueda

Infraestructura de búsqueda e indexación a escala. Elasticsearch para logs y analytics. Solr para documentos empresariales estructurados.

- **Puertos:** 23000-23099
- **BD Principal:** — (almacenamiento en índices propios)
- **Auth Keycloak:** — (infraestructura)

#### 1. Elasticsearch 8.16+

Motor de búsqueda y análisis distribuido basado en Apache Lucene. Almacena y hace buscables grandes volúmenes de datos semi-estructurados (logs, eventos, documentos). Soporta búsqueda full-text con relevancia, agregaciones analíticas, queries complejas y clustering horizontal para alta disponibilidad.

- **Puerto:** 23000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: — (índices propios) / Auth: —
- **Relaciones:** Backend principal de Wazuh (securityserver) — todos los eventos de seguridad se almacenan e indexan aquí para análisis SIEM. Indexa logs de Paperless-NGX (catalogserver) y Kimios (workflowserver) para búsqueda global. Superset (biserver) puede conectarse para analytics sobre datos de log. Complementa a Solr — Elasticsearch para logs/eventos, Solr para documentos empresariales.

#### 2. Apache Solr 9.0+

Motor de búsqueda empresarial especializado en documentos textuales estructurados. Parte del proyecto Apache Lucene, optimizado para búsqueda facetada (filtros interactivos), highlighting de términos, suggest/auto-completado, y relevancia configurable por campo y tipo de documento.

- **Puerto:** 23010
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: — (índices propios) / Auth: —
- **Relaciones:** Indexa el contenido textual de Kimios DMS (workflowserver) — contratos, manuales, procedimientos — para búsqueda empresarial. También indexa documentos de Paperless-NGX (catalogserver) como complemento a su búsqueda interna. Airflow (orchestrator) programa reindexaciones nocturnas. Usado por Fleetbase (logisticsserver) para búsqueda de órdenes y clientes.

### 🖥️ dbsyncserver/ — Sincronización de Bases de Datos

Puente de sincronización bidireccional entre PostgreSQL y MySQL. Mantiene consistencia de datos donde ambos motores deben coexistir.

- **Puertos:** 24000-24099
- **BD Principal:** PostgreSQL 18 + MySQL 8 (bidireccional)
- **Auth Keycloak:** ⚠️ Auth básica por BD

#### 1. SymmetricDS 3.16+

Plataforma de replicación y sincronización de bases de datos multi-master. Captura cambios (CDC - Change Data Capture) en tablas específicas y los replica de forma bidireccional entre nodos PostgreSQL y MySQL. Maneja conflictos de sincronización con reglas configurables, garantiza entrega ordenada y mantiene un registro de auditoría de todas las sincronizaciones.

- **Puerto:** 24000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL + MySQL / Auth: —
- **Relaciones:** Sincroniza datos entre MySQL (OrangeHRM, FreePBX) y PostgreSQL (Tryton) donde la integración lo requiere: datos de empleados de OrangeHRM se sincronizan con el módulo de personal de Tryton para la nómina. Registros de llamadas de FreePBX se sincronizan con EspoCRM (projectserver) para el historial de cliente. Garantiza que PostgreSQL sea siempre la fuente de verdad.

### 🖥️ commsserver/ — Comunicaciones Unificadas

Stack de comunicaciones empresariales completo. VoIP con FreePBX/Asterisk, mensajería instantánea con Rocket.Chat y Mattermost para diferentes casos de uso.

- **Puertos:** 25000-25099
- **BD Principal:** MySQL (FreePBX) · MongoDB (Rocket.Chat) · PostgreSQL (Mattermost)
- **Auth Keycloak:** ✅ OAuth2 Keycloak (Rocket.Chat, Mattermost) · SAML plugin (FreePBX)

#### 1. FreePBX 17 + Asterisk 21

Central telefónica IP (PBX) empresarial completa. Asterisk es el motor de procesamiento de llamadas VoIP y FreePBX es la interfaz de administración web. Gestiona extensiones internas, colas de llamadas con agentes, IVR (menú de voz interactivo), grabación de conversaciones, conferencias, fax sobre IP y troncales SIP con operadores telefónicos.

- **Puerto:** 25000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: MySQL 8 / Auth: SAML plugin FreePBX
- **Relaciones:** Click-to-call integrado con EspoCRM (projectserver) — desde el CRM se puede iniciar una llamada a un cliente con un clic. Las grabaciones de llamadas se almacenan en MinIO (commonserver). SymmetricDS (dbsyncserver) sincroniza el registro de llamadas con PostgreSQL para análisis en Superset (biserver). Alertas del sistema por correo Postfix (mailserver). MySQL requerido por FreePBX.

#### 2. Rocket.Chat 6.0+

Plataforma de comunicación empresarial en tiempo real con funciones completas de mensajería. Canales temáticos, mensajes directos, videoconferencias integradas con Jitsi, compartición de archivos, bots y webhooks. Especialmente diseñado para equipos que necesitan integraciones con sistemas externos (GitLab, Zabbix, Airflow).

- **Puerto:** 25010
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: MongoDB / Auth: OAuth2 Keycloak
- **Relaciones:** SSO con Keycloak (authserver) vía OAuth2. Webhooks desde GitLab (cicdserver) notifican despliegues. Alertas de Zabbix (monitorserver) se publican automáticamente en un canal de alertas. Archivos compartidos van a MinIO (commonserver). MongoDB requerido por Rocket.Chat. Mattermost (commsserver) es la alternativa PostgreSQL-nativa para equipos que prefieren mayor seguridad.

#### 3. Mattermost 9.0+

Plataforma de mensajería corporativa enfocada en seguridad, compliance y flujos de trabajo DevOps. Permite crear playbooks (guías de respuesta a incidentes), definir workflows automatizados, mantener un registro inmutable de todas las conversaciones y cumplir con normativas de retención de datos.

- **Puerto:** 25020
- **Prioridad:** MEDIO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: SAML Keycloak
- **Relaciones:** SSO con Keycloak (authserver) vía SAML. PostgreSQL en commonserver (motor nativo). Recibe alertas de Alertmanager (monitorserver), notificaciones de Grafana, eventos de Airflow (orchestrator) y actualizaciones de OpenProject (projectserver). Complementa a Rocket.Chat para equipos de DevOps y operaciones que requieren compliance estricto.

### 🖥️ projectserver/ — Gestión de Proyectos, OKR & CRM

Ejecución estratégica del negocio. Taiga para metodologías ágiles, OpenProject para proyectos formales y OKR, EspoCRM para gestión de clientes.

- **Puertos:** 26000-26099
- **BD Principal:** PostgreSQL 18 (Taiga, OpenProject, EspoCRM — los tres nativos)
- **Auth Keycloak:** ✅ OIDC/LDAP Keycloak (todos nativos)

#### 1. Taiga 6.7+

Plataforma de gestión de proyectos ágiles open source. Soporta Scrum completo (sprints, backlog, velocidad, burndown charts) y Kanban (tableros, límites WIP, flujo continuo). Gestión de épicas, historias de usuario, tareas y bugs con tracking de tiempo.

- **Puerto:** 26000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC/LDAP Keycloak
- **Relaciones:** SSO con Keycloak (authserver) vía OIDC/LDAP. PostgreSQL en commonserver. Integración bidireccional con GitLab (cicdserver) — issues de GitLab se sincronizan con historias de Taiga. Notificaciones en Mattermost/Rocket.Chat (commsserver). Correo vía Postfix (mailserver). Complementa a OpenProject — Taiga para equipos ágiles de software, OpenProject para proyectos formales con Gantt.

#### 2. OpenProject 14+

Plataforma de gestión de proyectos tradicional con capacidades avanzadas de OKR (Objectives and Key Results). Diagrama de Gantt interactivo con dependencias, EDT (Estructura de Desglose del Trabajo), gestión de presupuesto y costos, seguimiento de OKRs y KPIs organizacionales, y wiki por proyecto.

- **Puerto:** 26010
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak
- **Relaciones:** SSO con Keycloak (authserver). PostgreSQL en commonserver. Integración con GitLab (cicdserver) para vincular commits y MRs a tareas. Los OKRs definidos aquí se visualizan como métricas de negocio en Superset (biserver). Notificaciones a Mattermost (commsserver). Correo vía Postfix (mailserver). Datos de recursos humanos desde OrangeHRM (appserver) para planificación de capacidad.

#### 3. EspoCRM 8.0+

CRM (Customer Relationship Management) empresarial de código abierto. Gestiona el ciclo de vida completo del cliente: leads, oportunidades, cuentas, contactos, actividades (llamadas, reuniones, emails), contratos y casos de soporte. Email marketing con segmentación avanzada.

- **Puerto:** 26020
- **Prioridad:** ALTO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak
- **Relaciones:** SSO con Keycloak (authserver). PostgreSQL en commonserver. Click-to-call con FreePBX (commsserver). Cuando CardMesh (vcardserver) recibe una visita a una tarjeta, crea automáticamente un lead en EspoCRM. Sincroniza oportunidades con Tryton Ventas (appserver). Los contratos firmados en DocuSeal (esignserver) se adjuntan al registro del cliente. SymmetricDS (dbsyncserver) importa historial de llamadas de FreePBX.

### 🖥️ esignserver/ — Firma Digital

Firma electrónica de documentos legalmente válida. DocuSeal gestiona el ciclo de vida completo de contratos y documentos que requieren firma múltiple.

- **Puertos:** 27000-27099
- **BD Principal:** PostgreSQL 18 (nativo)
- **Auth Keycloak:** ⚠️ OIDC en roadmap oficial v2.0

#### 1. DocuSeal 1.7+

Plataforma de firma digital de documentos open source. Permite subir plantillas de contratos (PDF/Word), definir campos de firma, fecha e iniciales para múltiples firmantes, establecer el orden de firma, enviar invitaciones por correo y mantener un registro de auditoría con timestamps y huellas digitales que dan validez legal al documento.

- **Puerto:** 27000
- **Prioridad:** ALTO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak (roadmap)
- **Relaciones:** Integración con Tryton (appserver) — los contratos de venta o compra generados en Tryton se envían a DocuSeal para firma. Los documentos firmados son archivados automáticamente en Paperless-NGX (catalogserver). EspoCRM (projectserver) adjunta los contratos firmados al perfil del cliente. Kimios (workflowserver) incluye DocuSeal en sus flujos de aprobación. Correo de invitación vía Postfix (mailserver).

### 🖥️ securityserver/ — Seguridad SIEM & Hardening

Seguridad activa del stack. SIEM para detección de amenazas, scanner de vulnerabilidades, mTLS automático y segmentación de red.

- **Puertos:** 28000-28099
- **BD Principal:** Elasticsearch (Wazuh) · PostgreSQL (OpenVAS)
- **Auth Keycloak:** ⚠️ SAML parcial (Wazuh Web UI)

#### 1. Wazuh 4.10+

Plataforma SIEM (Security Information and Event Management) y XDR (Extended Detection and Response). Despliega agentes ligeros en todos los servidores que monitorizan la integridad de archivos críticos, detectan intrusiones y exploits conocidos, correlacionan eventos de seguridad entre múltiples servidores, ejecutan respuesta activa automática (bloqueo de IPs) y generan reportes de compliance (PCI-DSS, HIPAA, ISO 27001).

- **Puerto:** 28000
- **Prioridad:** ALTO
- **BD / Auth:** BD: Elasticsearch / Auth: SAML Keycloak
- **Relaciones:** Agentes en todos los 31 servidores del stack. Los eventos de seguridad se almacenan en Elasticsearch (searchengine). El dashboard de seguridad se visualiza en Grafana (monitorserver). Las alertas críticas van a Alertmanager (monitorserver) y a un canal dedicado en Mattermost (commsserver). Complementa a OpenVAS (securityserver) para una cobertura completa: Wazuh detecta en tiempo de ejecución, OpenVAS detecta vulnerabilidades en tiempo de escaneo.

#### 2. OpenVAS / Greenbone 23+

Scanner de vulnerabilidades de red de código abierto, el más completo disponible libremente. Realiza escaneos exhaustivos de todos los hosts y servicios del stack, detectando CVEs conocidos, configuraciones inseguras, servicios desactualizados y puertos abiertos innecesarios. Genera reportes detallados de remediación priorizados por severidad.

- **Puerto:** 28010
- **Prioridad:** ALTO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: —
- **Relaciones:** Escanea todos los 31 servidores del stack de forma programada (semanal por defecto). Los resultados se almacenan en PostgreSQL (commonserver) y se visualizan en Grafana (monitorserver). Los CVEs críticos detectados disparan alertas en Alertmanager. Complementa a Trivy (cicdserver) — OpenVAS escanea hosts en producción, Trivy escanea imágenes Docker en build.

#### 3. Linkerd (Service Mesh)

Service Mesh para Kubernetes que implementa mTLS (mutual TLS) automático entre todos los pods del clúster. Sin cambiar el código de ninguna aplicación, Linkerd cifra todo el tráfico entre microservicios, implementa políticas de autorización (qué servicio puede hablar con qué), circuit breaking automático y métricas de latencia/error por ruta de servicio.

- **Puerto:** 28020
- **Prioridad:** ALTO
- **BD / Auth:** BD: — / Auth: —
- **Relaciones:** Complementa a Vault (secretsvault) para seguridad Zero Trust — Vault gestiona secretos, Linkerd cifra el tráfico. Las métricas de Linkerd (latencia, tasa de error por servicio) van a Prometheus (monitorserver) y se visualizan en Grafana. Las políticas de autorización definen que, por ejemplo, solo Django SIAT (apigateway) puede comunicarse con el servicio de firma del SIN.

#### 4. Network Policies (Kubernetes)

Reglas de segmentación de red nativas de Kubernetes (implementadas vía Calico o Cilium). Define qué pods pueden comunicarse entre sí a nivel L3/L4. Implementa una política deny-by-default (todo tráfico bloqueado por defecto) y luego permite solo las comunicaciones necesarias y documentadas entre servicios.

- **Puerto:** 28030
- **Prioridad:** ALTO
- **BD / Auth:** BD: — / Auth: —
- **Relaciones:** Complementa a Linkerd (securityserver) para defensa en profundidad — Linkerd cifra (L7), Network Policies segmentan (L3/L4). Define, por ejemplo, que Saleor (webserver) solo puede acceder a PostgreSQL y Redis (commonserver), pero no directamente a Tryton o a Keycloak. Reduce el radio de blast en caso de compromiso de un servicio.

### 🖥️ helpdeskserver/ — Help Desk, Encuestas & Citas

Atención al cliente interna y externa. Zammad para tickets de soporte, LimeSurvey para encuestas de satisfacción, Cal.com para agendamiento.

- **Puertos:** 29000-29099
- **BD Principal:** PostgreSQL 18 (Zammad, LimeSurvey, Cal.com — los tres nativos)
- **Auth Keycloak:** ✅ SAML/OIDC Keycloak (todos)

#### 1. Zammad 6.4+

Plataforma de help desk y gestión de tickets multicanal. Centraliza solicitudes de soporte que llegan por correo electrónico, chat web, teléfono y formulario web. Gestiona SLAs (tiempos de respuesta y resolución), escalaciones automáticas, asignación por equipos y habilidades, macros para respuestas frecuentes y una base de conocimiento integrada para autoservicio.

- **Puerto:** 29000
- **Prioridad:** MEDIO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: SAML/OIDC Keycloak
- **Relaciones:** SSO con Keycloak (authserver) vía SAML/OIDC. PostgreSQL en commonserver. Recibe tickets por correo desde Postfix (mailserver) — cualquier correo a soporte@empresa.com crea un ticket automáticamente. Notificaciones de respuesta se envían por Postfix. Escalaciones por chat en Mattermost/Rocket.Chat (commsserver). Los KPIs de soporte (tiempo de resolución, satisfacción) se visualizan en Superset (biserver).

#### 2. LimeSurvey 6.0+

Plataforma de encuestas y formularios en línea open source. Permite crear encuestas complejas con múltiples tipos de preguntas (escala Likert, selección múltiple, NPS, texto libre), lógica condicional entre preguntas, encuestas multiidioma, análisis estadístico de resultados y exportación a XLSX/CSV.

- **Puerto:** 29010
- **Prioridad:** BAJO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak
- **Relaciones:** SSO con Keycloak (authserver) vía OIDC. PostgreSQL en commonserver. Las encuestas de satisfacción post-ticket de Zammad (helpdeskserver) se crean en LimeSurvey y el enlace se incluye en el correo de cierre de ticket. Los resultados de encuestas de satisfacción se exportan a Superset (biserver) para análisis de NPS. Correo de invitación vía Postfix (mailserver).

#### 3. Cal.com 2.0+

Sistema de agendamiento y reserva de citas open source. Permite a clientes y partners reservar citas directamente en el calendario del equipo, respetando la disponibilidad real, zonas horarias y buffers entre reuniones. Soporta múltiples tipos de reunión, flujos de aprobación y recordatorios automáticos.

- **Puerto:** 29020
- **Prioridad:** BAJO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak
- **Relaciones:** SSO con Keycloak (authserver). PostgreSQL en commonserver. Sincroniza disponibilidad con Nextcloud Calendar (vdiserver) para evitar dobles reservas. Los recordatorios van por Postfix (mailserver). Las citas confirmadas se crean también en EspoCRM (projectserver) si son con clientes. Complementa a Easy!Appointments (webserver) para sectores de servicios más especializados.

### 🖥️ queueserver/ — Sistema de Colas de Atención

Gestión de turnos y atención al público en ventanillas. Multi-sucursal, multi-servicio, con pantallas de visualización.

- **Puertos:** 31000-31099
- **BD Principal:** PostgreSQL 8+ (Novo SGA)
- **Auth Keycloak:** ⚠️ LDAP Keycloak federation

#### 1. Novo SGA 2.1+

Sistema de Gestión de Atención (SGA) para entidades con atención al público: bancos, municipios, hospitales, farmacias, oficinas gubernamentales. Gestiona la emisión de turnos (desde quiosco, web o app), la llamada al turno en pantalla con número y nombre del módulo, y estadísticas de tiempo de espera y atención por servicio y operador.

- **Puerto:** 31000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 8+ / Auth: LDAP Keycloak
- **Relaciones:** SSO vía LDAP Keycloak (authserver) para login de operadores. PostgreSQL en commonserver. Xibo CMS (signageserver) muestra los turnos llamados en las pantallas del lobby. GNU Health (appserver) puede integrarse para citas médicas que se convierten en turnos físicos. Los reportes de tiempos de espera van a Superset (biserver) para análisis de eficiencia operacional.

### 🖥️ signageserver/ — Digital Signage

Gestión centralizada de pantallas informativas digitales. Lobby, salas de espera, pantallas de turnos, cartelería institucional y publicidad interna.

- **Puertos:** 32000-32099
- **BD Principal:** MySQL (Xibo CMS actual) → PostgreSQL (migración planificada)
- **Auth Keycloak:** ⚠️ Auth básica (roadmap OIDC con upgrade)

#### 1. Xibo CMS 4.1+

Sistema de digital signage de código abierto para la gestión centralizada de pantallas de visualización. Define layouts con múltiples regiones (video, imágenes, texto, RSS, HTML), programa el contenido por horarios y zonas, gestiona una flota de reproductores (Xibo Player en cada pantalla) y monitorea el estado de todas las pantallas desde un panel central.

- **Puerto:** 32000
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: MySQL→PostgreSQL / Auth: Básica (roadmap OIDC)
- **Relaciones:** Consume contenido de Directus (webserver) para mostrar información institucional dinámica. Se integra con Novo SGA (queueserver) para mostrar el número de turno llamado en pantallas del lobby en tiempo real. Los archivos de contenido (videos, imágenes) se almacenan en MinIO (commonserver). Migración a PostgreSQL planificada para la próxima versión mayor.

# 🔗 Flujos de Integración Principales

## 1. Flujo Comercial Completo (Venta → Factura → Contabilidad)

Cliente compra en Saleor (webserver) → Saleor crea pedido en PostgreSQL → RabbitMQ (messagequeue) publica evento de venta → Tryton Ventas (appserver) registra la venta → Celery (apigateway) encola tarea SIAT → Django genera CUF → firma XML → envía al SIN Bolivia → SIN confirma → Tryton actualiza estado como facturada → JasperReports (reportserver) genera PDF → Postfix (mailserver) envía factura al cliente → Paperless-NGX (catalogserver) archiva la factura → Tryton Contabilidad registra el asiento automáticamente.

## 2. Flujo de Inventario en Tiempo Real

Producto vendido en Saleor (webserver) → webhook dispara a Tryton Stock (appserver) → Tryton descuenta unidades → si stock < mínimo → Tryton Compras crea orden de compra automática → Fleetbase (logisticsserver) gestiona la recepción → Traccar (assettracking) rastrea el vehículo de entrega → Tryton recibe mercancía → stock actualizado → Saleor muestra stock disponible actualizado en tiempo real.

## 3. Flujo de Identidad (Cualquier Usuario → Cualquier App)

Usuario accede a URL de cualquier app → NGINX (proxyserver) recibe la petición → la app redirige a Keycloak (authserver) → Keycloak valida credenciales (local, LDAP/AD, MFA) → emite token JWT → app valida token contra JWKS de Keycloak → usuario accede con sus roles y permisos correspondientes. Para apps sin OIDC: OAuth2-Proxy (authserver) intercepta y hace el flujo transparente.

## 4. Flujo de Observabilidad (Cualquier Problema → Resolución)

Servicio en producción falla → Grafana Alloy (monitorserver) captura logs de error → Loki indexa → Prometheus detecta métricas anómalas → Alertmanager (monitorserver) envía alerta a Mattermost (commsserver) canal-alertas y a PagerDuty → ingeniero abre Grafana (monitorserver) → ve el dashboard unificado con la métrica que falló, los logs del momento exacto y la traza OpenTelemetry de la petición fallida (Tempo) → identifica el problema en minutos en lugar de horas.

## 5. Flujo de Seguridad (Detección y Respuesta)

Intentos de login fallidos repetidos → Wazuh (securityserver) detecta el patrón → ejecuta respuesta activa (bloquea IP en firewall) → registra evento en Elasticsearch (searchengine) → dashboard de seguridad Grafana (monitorserver) muestra el incidente → Alertmanager notifica al equipo de seguridad en Mattermost (commsserver) → el incidente se abre como ticket en Zammad (helpdeskserver) → OpenVAS (securityserver) escanea el origen para verificar si hay exploits activos.

# 🏆 Valoración Enterprise 10/10

| Pilar | Score | Evidencia en el Stack |
|---|---|---|
| Alineamiento estratégico | 10/10 | OpenProject OKR + Taiga Ágil + métricas Tryton en Superset en tiempo real. KPIs de negocio directamente desde la base de datos de producción. |
| Escalabilidad | 10/10 | Citus sharding PostgreSQL + K8s autoscaling + K6 gates de rendimiento en CI/CD + Kong rate limiting + Redis cluster sentinel. |
| Seguridad Zero Trust | 10/10 | Keycloak SSO universal + Linkerd mTLS automático + Vault secretos dinámicos + ModSecurity WAF + Wazuh SIEM + OpenVAS + Network Policies. |
| Resiliencia & DR | 10/10 | Patroni HA (RPO=0) + Velero DR AWS (RTO<30 min) + Bareos cifrado + Goss validación automática + Alertmanager + Zabbix SLA tracking. |
| Observabilidad | 10/10 | LGTM+Z+W: Loki+Grafana+Tempo+Prometheus+Zabbix+Wazuh. Métricas, logs, trazas, infraestructura y seguridad correlacionados en Grafana con SSO. |
| Gestión documental | 10/10 | Paperless-NGX OCR + Kimios BPM + Tabula/Camelot extracción PDF + Solr/Elasticsearch búsqueda + DocuSeal firma + MinIO WORM. |
| Comunicaciones | 10/10 | Postfix/Dovecot correo + FreePBX/Asterisk VoIP + Rocket.Chat mensajería + Mattermost DevOps + Roundcube/Cypht webmail — SSO unificado. |
| Verticales de negocio | 10/10 | GNU Health (salud) + OrangeHRM (RRHH) + TastyIgniter (restaurantes) + Easy!Appointments (servicios) + Traccar/Fleetbase (logística) + Novo SGA (atención pública) + Xibo (señalética). |
| Automatización | 10/10 | Airflow DAGs + GitLab CI/CD + Celery workers + RabbitMQ eventos + K6 testing + Trivy seguridad + Goss validación — zero-touch deployments. |
| Homogeneidad de datos | 9/10 | PostgreSQL 18 en 90%+ del stack. MySQL solo en 3 apps por dependencia de fabricante. SymmetricDS sincroniza. Roadmap 100% PostgreSQL documentado. |

# 📌 Notas Técnicas Finales

1. Todas las herramientas del stack son 100% Open Source. Sin costos de licencia para el software core.

2. PostgreSQL 18 es el motor de base de datos del stack. MySQL presente solo en 3 herramientas por restricciones técnicas del fabricante, con sincronización gestionada por SymmetricDS.

3. Tryton ERP cubre de forma nativa toda la gestión empresarial: contabilidad boliviana (PUCT/SIN), inventario multi-almacén, manufactura con BOM, ventas, compras y más.

4. El desarrollo personalizado es mínimo y acotado: módulos Tryton para localización Bolivia, Django SIAT Bolivia, integración de pagos QR/Tigo Money. Todo lo demás son configuraciones de herramientas existentes.

5. Docker → Kubernetes: todas las aplicaciones están disponibles como imágenes Docker oficiales, garantizando portabilidad entre entornos de desarrollo, staging y producción.

6. Keycloak gestiona SSO para las 65+ aplicaciones: 75% con OIDC/SAML nativos, 25% restante via OAuth2-Proxy o LDAP federation.

7. Bolivia: el stack incluye integración completa con SIAT (Sistema de Impuestos y Aduana Nacional), formatos SIN, plan de cuentas PUCT, y soporte para pagos QR Simple y Tigo Money.

8. Roadmap de mejora progresiva: Xibo → PostgreSQL con próxima versión major. Fleetbase → OIDC completo. DocuSeal → OIDC nativo v2.0. OpenMetadata → 100% PostgreSQL.

**IAM ENTERPRISE STACK**

Complemento v5.1 — Alta Disponibilidad & Aplicaciones Faltantes

Febrero 2026 · 17 Aplicaciones Nuevas · commonserver/ ampliado

*Patroni + etcd → HA PostgreSQL (RPO=0, RTO<60s) · PgBouncer → Connection Pooling · pgBackRest → PITR · ClamAV + Amavis → Antivirus*

> **📌 Cómo usar este documento**
>
> Este complemento es el Anexo A del documento IAM Enterprise Stack v5.0. Contiene las 17 aplicaciones identificadas como faltantes tras el análisis exhaustivo del v5.0. Cada aplicación sigue el mismo formato: descripción detallada + relaciones con el resto del stack. Puede leerse de forma independiente o integrado al final del documento v5.0.

# 📊 Resumen Ejecutivo — 17 Aplicaciones Complementarias

El análisis del documento v5.0 identificó aplicaciones mencionadas en los flujos de integración y pilares de alta disponibilidad que no estaban formalmente documentadas como entradas del stack. Este complemento las incorpora con el mismo nivel de detalle que el documento principal.

| Categoría | Apps | Prioridad | Impacto |
|---|---|---|---|
| PARTE 1: HA PostgreSQL (Patroni Stack) | 3 apps | CRÍTICO | RPO=0 y RTO<60s — sin esto PostgreSQL es single point of failure |
| PARTE 2: Herramientas PostgreSQL | 3 apps | CRÍTICO | PgBouncer evita colapso por conexiones; pgBackRest añade PITR; pg_stat_monitor visibilidad |
| PARTE 3: Seguridad de Correo | 2 apps | CRÍTICO | ClamAV + Amavis completan la cadena antivirus/antispam del mailserver |
| PARTE 4: Aplicaciones de Soporte | 5 apps | ALTO | Grafana Alloy, Mattermost, Celery, PagerDuty, Promtail — ya referenciados en v5.0 |
| PARTE 5: Misceláneas Confirmadas | 4 apps | MEDIO | Nextcloud Cal., EspoCRM, Trivy, Apache Solr — presentes en v5.0 sin sección propia |

# 🔴 PARTE 1 — Patroni HA Stack (Alta Disponibilidad PostgreSQL)

> **⚡ ¿Por qué es CRÍTICO el Patroni Stack?**
>
> El documento v5.0 garantiza RPO=0 y RTO<30 min. Sin Patroni + etcd, PostgreSQL opera como instancia única: si el servidor de BD cae, TODOS los 31 servidores del stack quedan sin base de datos. Patroni convierte ese single point of failure en un cluster de 3 nodos con failover automático en 30-60 segundos sin intervención humana.

### 🖥️ commonserver/ — Ampliación: HA PostgreSQL Stack

Extensión del commonserver para alta disponibilidad. Se agregan Patroni, etcd y PgBouncer al clúster PostgreSQL existente.

- **Puertos:** 7000-7099 + 2379 + 8008 + 6432
- **BD Principal:** PostgreSQL 18 (cluster 3 nodos)
- **Auth Keycloak:** — (infraestructura HA)

#### 1. Patroni

Sistema de alta disponibilidad open source para PostgreSQL. Despliega un agente en cada nodo PostgreSQL que monitorea continuamente el estado del master, coordina la elección de nuevo líder mediante consenso RAFT a través de etcd, ejecuta el failover automático (pg_ctl promote) cuando el master cae, reconfigura los nodos réplica para seguir al nuevo master, y previene el split-brain mediante un distributed lock. Expone una REST API en el puerto 8008 que HAProxy consulta para saber qué nodo es el master en tiempo real.

- **Puerto:** 8008
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 (gestiona el cluster) / Auth: API REST interna
- **Relaciones:** Coordina con etcd (commonserver) para el distributed lock y la elección de líder. HAProxy (commonserver) consulta su API REST en /master y /replica para enrutar escrituras al nodo primario y lecturas a las réplicas. Prometheus (monitorserver) scrapea sus métricas. Vault (secretsvault) provee las credenciales de replicación de forma dinámica. Sin Patroni, HAProxy no sabe qué nodo es el master después de un failover.

#### 2. etcd (cluster 3 nodos)

Almacén distribuido de clave-valor que actúa como el cerebro de coordinación del cluster Patroni. Implementa el protocolo de consenso RAFT para garantizar que solo un nodo PostgreSQL sea el master en cualquier momento. Almacena: quién tiene el leader lock, la configuración del cluster, el health status de cada nodo y la topología de replicación. Requiere mínimo 3 nodos para mantener quorum (tolerancia a 1 fallo). Es el mismo componente que Kubernetes usa internamente — tecnología probada en producción por millones de clusters.

- **Puerto:** 2379/2380
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: — (almacenamiento propio RAFT) / Auth: TLS mTLS entre nodos
- **Relaciones:** Es la dependencia obligatoria de Patroni (commonserver). Sin etcd, Patroni no puede coordinar el cluster. Prometheus (monitorserver) scrapea sus métricas de latencia y elecciones de líder. Grafana (monitorserver) visualiza la salud del cluster etcd. Alertmanager (monitorserver) alerta si etcd pierde quorum. Vault (secretsvault) puede opcionalmente usar etcd como backend.

#### 3. HAProxy (configuración Patroni)

HAProxy ya existe en commonserver pero requiere configuración específica para integrarse con Patroni. Con esta configuración, HAProxy hace health checks HTTP a la API REST de cada Patroni (puerto 8008): consulta /master — si el nodo responde HTTP 200 es el master (recibe escrituras); si responde HTTP 503 es réplica (no recibe escrituras en el puerto 5432). El puerto 5433 de HAProxy apunta a réplicas en round-robin para consultas de solo lectura, distribuyendo la carga de analytics entre nodos réplica.

- **Puerto:** 5432/5433
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: — (proxy de BD) / Auth: Health checks Patroni API
- **Relaciones:** Recibe health checks de Patroni (commonserver) en tiempo real — cuando Patroni promueve un nuevo master, HAProxy detecta el cambio en el siguiente ciclo de health check (configurado a 3 segundos) y redirige el tráfico al nuevo master. PgBouncer (commonserver) se coloca delante de HAProxy: todas las apps → PgBouncer:6432 → HAProxy:5432 → Patroni master. Citus (commonserver) usa esta misma capa para el sharding distribuido.

```
Flujo completo de conexión a PostgreSQL tras implementar el HA Stack:
App (Tryton/Saleor/Keycloak/...)
│
▼ puerto 6432
┌─────────────┐
│ PgBouncer │ ← Connection Pooling
│ (max 10K │ hasta 10,000 clientes
│ clientes) │ → 100 conexiones reales
└──────┬──────┘
│ puerto 5432
▼
┌─────────────┐
│ HAProxy │ ← Detecta master via
│ │ Patroni API :8008
└──┬──────────┘
│ Consulta /master cada 3s
├──▶ pg-node1:5432 [MASTER ✅ → 200]
├──▶ pg-node2:5432 [replica → 503]
└──▶ pg-node3:5432 [replica → 503]
Cada nodo PostgreSQL tiene Patroni agent:
pg-node1 ──▶ etcd cluster (2379)
pg-node2 ──▶ etcd cluster (2379)
pg-node3 ──▶ etcd cluster (2379)
Failover automático (30-60 segundos):
1. pg-node1 CALLA → lock en etcd expira
2. pg-node2 gana lock → pg_ctl promote
3. HAProxy detecta nuevo /master en :8008
4. Todo el tráfico va a pg-node2
5. pg-node3 sigue a pg-node2 (nueva répl)
RPO=0 (sync repl) · RTO=30-60s
```

# 🔧 PARTE 2 — Herramientas PostgreSQL Complementarias

### 🖥️ commonserver/ — Ampliación: Herramientas PostgreSQL

Herramientas que optimizan, protegen y monitorizan el uso de PostgreSQL en un stack de 65+ aplicaciones conectadas simultáneamente.

- **Puertos:** 6432 + ext. PostgreSQL
- **BD Principal:** PostgreSQL 18 (todas son extensiones o proxies)
- **Auth Keycloak:** — (infraestructura BD)

#### 4. PgBouncer

Connection pooler ligero y de alto rendimiento para PostgreSQL. Resuelve un problema crítico de escala: PostgreSQL usa el modelo fork-per-connection — cada nueva conexión crea un proceso del sistema operativo. Con 65+ aplicaciones conectándose simultáneamente con múltiples conexiones por pool, se llegaría fácilmente a 5,000-10,000 procesos PostgreSQL, causando el colapso del servidor. PgBouncer mantiene un pool reducido de conexiones reales a PostgreSQL (configurable, típicamente 100-200) y reutiliza esas conexiones para servir miles de clientes de aplicación. La latencia añadida es inferior a 1 milisegundo.

- **Puerto:** 6432
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 (proxy de pool) / Auth: SCRAM-SHA-256
- **Relaciones:** Se coloca entre TODAS las aplicaciones del stack y HAProxy (commonserver): apps → PgBouncer:6432 → HAProxy:5432 → Patroni master. Configurado con pool_mode=transaction para máxima eficiencia. Las credenciales de usuario son validadas contra el auth_file que Vault (secretsvault) actualiza automáticamente. Prometheus (monitorserver) scrapea sus métricas de pool (clientes en espera, conexiones activas). Si PgBouncer cae, HAProxy lo detecta y las apps reconectan directamente.

#### 5. pgBackRest

Solución de backup moderna y especializada para PostgreSQL que complementa a Bareos (backupserver). Ofrece capacidades que pg_dump no tiene: backup paralelo con múltiples workers (mucho más rápido en bases de datos grandes), compresión nativa LZ4/Zstandard, cifrado AES-256-CBC del backup en origen antes de enviarlo, backup incremental y diferencial para reducir el tiempo y espacio de backup, y lo más crítico — PITR (Point-In-Time Recovery): la capacidad de restaurar la base de datos al estado exacto de cualquier segundo del pasado, no solo al momento del último backup completo.

- **Puerto:** —
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 (backup directo WAL) / Auth: Credenciales Vault
- **Relaciones:** Se integra directamente con el cluster Patroni (commonserver) — puede hacer backup desde el nodo réplica para no afectar el master. Envía los backups cifrados a MinIO (commonserver) como repositorio S3-compatible. Airflow (orchestrator) programa los DAGs de backup: full diario a las 2:00 AM, diferencial cada 6 horas. Bareos (backupserver) complementa para backup de archivos del sistema operativo. Goss (backupserver) valida que los backups de pgBackRest sean restaurables. Prometheus (monitorserver) recibe métricas de duración y tamaño de backup.

#### 6. pg_stat_monitor

Extensión de PostgreSQL que proporciona estadísticas avanzadas de queries, superando las capacidades de pg_stat_statements (la extensión estándar). Registra para cada query: número de ejecuciones, tiempo medio/máximo/desviación estándar de ejecución, tiempo de CPU vs I/O, número de rows procesadas, hits de buffer cache vs I/O de disco, y el usuario y base de datos que ejecutó la query. Agrupa los datos por intervalos de tiempo configurables para análisis de tendencias.

- **Puerto:** —
- **Prioridad:** ALTO
- **BD / Auth:** BD: Es extensión de PostgreSQL 18 / Auth: —
- **Relaciones:** Extensión activada en PostgreSQL (commonserver). Grafana (monitorserver) tiene un datasource directo a PostgreSQL para crear dashboards con: Top 10 queries más lentas por aplicación (Tryton vs Saleor vs Keycloak), queries con mayor I/O de disco (candidatas a índices), lock waits entre aplicaciones, y tendencias de degradación de rendimiento. Alertmanager (monitorserver) alerta cuando el tiempo medio de query supera umbrales definidos. Usado por PgAdmin (commonserver) para análisis manual.

# 🛡️ PARTE 3 — Seguridad Completa de Correo

### 🖥️ mailserver/ — Ampliación: Cadena Antivirus/Antispam

ClamAV y Amavis completan la cadena de seguridad del gateway de correo. Amavis es el middleware que conecta Postfix con ClamAV y SpamAssassin en un flujo unificado.

- **Puertos:** 10024 + 10025 + 3310
- **BD Principal:** PostgreSQL 18 (quarantine log)
- **Auth Keycloak:** — (servicio de infraestructura de correo)

#### 7. Amavis

Middleware de alto rendimiento para la inspección de contenido de correo electrónico. Actúa como intermediario entre Postfix y los motores de análisis (ClamAV para virus, SpamAssassin para spam): recibe el correo de Postfix en el puerto 10024, lo pasa a ClamAV para escaneo de virus, lo pasa a SpamAssassin para puntuación de spam, aplica las políticas configuradas (entregar, rechazar, cuarentenar, etiquetar), y devuelve el correo procesado a Postfix en el puerto 10025 para su entrega final. Sin Amavis, Postfix no puede comunicarse con ClamAV de forma eficiente.

- **Puerto:** 10024/10025
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: PostgreSQL 18 (quarantine) / Auth: —
- **Relaciones:** Es el conector entre Postfix (mailserver) y ClamAV (mailserver). Postfix le pasa TODOS los correos entrantes y salientes. Amavis invoca ClamAV (mailserver) para escaneo antivirus y SpamAssassin (mailserver) para puntuación anti-spam. Los correos infectados son cuarentenados en PostgreSQL (commonserver). Los eventos de cuarentena son enviados a Loki (monitorserver) vía Grafana Alloy. Alertmanager (monitorserver) notifica al administrador cuando detecta un virus.

#### 8. ClamAV (configuración completa)

Motor antivirus open source que el documento v5.0 menciona en mailserver pero que requiere configuración explícita tanto para correo como para archivos del stack. Escanea correos via Amavis, archivos subidos a MinIO, documentos en Paperless-NGX y adjuntos en Rocket.Chat. Actualiza sus firmas de virus automáticamente vía freshclam varias veces al día. El daemon clamd escucha en el puerto 3310 para peticiones de escaneo on-demand desde cualquier servicio del stack.

- **Puerto:** 3310
- **Prioridad:** CRÍTICO
- **BD / Auth:** BD: — (firmas en disco local) / Auth: Socket Unix/TCP local
- **Relaciones:** Trabaja junto a Amavis (mailserver) para escanear todos los correos que pasan por Postfix (mailserver). Laravel (webserver) y Django SIAT (apigateway) invocan el socket de clamd antes de aceptar cualquier archivo subido por el usuario — si el archivo contiene malware, es rechazado antes de llegar a MinIO (commonserver). Paperless-NGX (catalogserver) puede configurarse para escanear documentos antes de archivarlos. Los logs de detección van a Loki (monitorserver) y Wazuh (securityserver) los correlaciona con eventos de seguridad.

# ⚙️ PARTE 4 — Aplicaciones de Soporte (ya referenciadas en v5.0)

Las siguientes aplicaciones aparecen en los flujos de integración del documento v5.0 pero no tenían una sección propia con descripción completa. Se formalizan aquí.

### 🖥️ monitorserver/ — Ampliación: Agentes y Alertas

Grafana Alloy como agente unificado de recolección. PagerDuty como escalación de alertas críticas.

- **Puertos:** 10000-10099 + webhooks
- **BD Principal:** PostgreSQL 18 (Grafana metastore)
- **Auth Keycloak:** ✅ OAuth2 Keycloak (Grafana)

#### 9. Grafana Alloy

El nuevo agente unificado de Grafana que reemplaza a Promtail (logs), Grafana Agent (métricas) y los exporters individuales. Un solo binario que recopila logs de todos los contenedores Docker y servicios del sistema, scraping de métricas Prometheus, reenvío de trazas OpenTelemetry a Tempo y perfilado de aplicaciones con Pyroscope. Se configura con un lenguaje de flujo visual (River language) que permite transformar y enriquecer los datos antes de enviarlos. Se despliega como DaemonSet en Kubernetes — un pod por nodo del cluster.

- **Puerto:** 12345
- **Prioridad:** ALTO
- **BD / Auth:** BD: — (agente de recolección) / Auth: —
- **Relaciones:** Se despliega en todos los nodos del cluster Kubernetes para capturar logs de absolutamente todos los contenedores. Envía logs a Loki (monitorserver), métricas a Prometheus (monitorserver) y trazas a Tempo (monitorserver). Complementa a Zabbix (monitorserver) — Zabbix monitorea la infraestructura de nivel OS, Alloy recopila telemetría de nivel aplicación. Prometheus (monitorserver) puede usar Alloy como proxy de scraping para targets que no son accesibles directamente.

#### 10. PagerDuty Integration

Plataforma de gestión de incidentes y on-call scheduling que se integra como destino de alertas de Alertmanager. Cuando ocurre un incidente crítico fuera del horario laboral (fallo de Patroni, caída de Keycloak, fallo del SIN Bolivia), PagerDuty escala automáticamente la alerta siguiendo la cadena de on-call definida: primero notifica al ingeniero de turno por SMS/llamada, si no responde en 5 minutos escala al siguiente nivel. Gestiona el lifecycle completo del incidente: apertura, asignación, escalación, resolución y post-mortem.

- **Puerto:** —
- **Prioridad:** ALTO
- **BD / Auth:** BD: — (servicio SaaS externo) / Auth: API Key
- **Relaciones:** Recibe alertas de Alertmanager (monitorserver) como destino de escalación para las alertas de máxima severidad. Mattermost (commsserver) recibe todas las alertas para visibilidad del equipo, pero PagerDuty se encarga de despertar a la persona correcta cuando es necesario. Cuando el incidente se resuelve (Patroni hace failover exitosamente), Alertmanager envía la resolución a PagerDuty para cerrar el incidente automáticamente.

### 🖥️ apigateway/ — Ampliación: Celery Workers documentados

Celery Workers ya existían implícitamente en el apigateway pero se formalizan aquí con su arquitectura completa de workers especializados.

- **Puertos:** 19000-19099
- **BD Principal:** PostgreSQL 18 · Redis (broker)
- **Auth Keycloak:** — (workers en segundo plano)

#### 11. Celery Workers (workers especializados)

Sistema de colas de tareas asíncronas distribuidas para Python. Se formalizan aquí los workers especializados que ya operan en el apigateway: Worker SIAT (prioridad alta) — envío de facturas al SIN Bolivia con reintento automático, generación de CUF y firma XML; Worker Reports (prioridad media) — invocación de JasperStarter para generación de reportes masivos sin bloquear la API; Worker Email (prioridad baja) — envío masivo de correos vía Postfix; Worker Sync (prioridad baja) — sincronización de inventario Tryton↔︎Saleor. Cada tipo de worker tiene su propia cola en Redis para garantizar que los envíos SIAT nunca esperan detrás de un envío de email.

- **Puerto:** —
- **Prioridad:** ALTO
- **BD / Auth:** BD: PostgreSQL 18 · Redis / Auth: —
- **Relaciones:** Broker de mensajes: Redis (commonserver) — colas separadas por prioridad. Worker SIAT invoca Django SIAT API (apigateway) y actualiza resultados en PostgreSQL Tryton (commonserver). Worker Reports invoca JasperStarter (reportserver) y deposita PDFs en MinIO (commonserver). Worker Email conecta a Postfix (mailserver). Worker Sync consume eventos de RabbitMQ (messagequeue) para actualizar stock entre Tryton y Saleor. Grafana Alloy (monitorserver) recopila logs de todos los workers. Flower (dashboard Celery) da visibilidad de las colas en tiempo real.

### 🖥️ monitorserver/ — Promtail (agente legacy)

Agente de logs legacy de Grafana. Se mantiene en el stack mientras se completa la migración a Grafana Alloy en todos los nodos.

- **Puertos:** 9080
- **BD Principal:** — (agente de recolección)
- **Auth Keycloak:** — (infraestructura)

#### 12. Promtail

Agente de recolección de logs de Grafana que antecede a Grafana Alloy. Recopila logs de archivos del sistema y contenedores Docker, los etiqueta con metadatos (host, servicio, namespace) y los envía a Loki. Se mantiene en el stack durante el período de transición a Grafana Alloy — algunos nodos y aplicaciones legacy (especialmente servidores fuera de Kubernetes) pueden seguir usando Promtail hasta que Alloy soporte todos los casos de uso. Configuración más simple que Alloy para entornos sin contenedores.

- **Puerto:** 9080
- **Prioridad:** MEDIO
- **BD / Auth:** BD: — (agente) / Auth: —
- **Relaciones:** Envía logs directamente a Loki (monitorserver) en el mismo formato que Grafana Alloy. En el stack, Promtail cubre los servidores bare-metal o VMs que no forman parte del cluster Kubernetes, mientras que Alloy cubre los pods K8s. Grafana (monitorserver) consume logs de Loki sin importar si fueron enviados por Promtail o Alloy. Cuando un nodo migra a K8s, Promtail se reemplaza por Alloy en ese nodo.

# 📋 PARTE 5 — Aplicaciones Presentes en v5.0 Sin Sección Propia

Las siguientes aplicaciones están mencionadas en el documento v5.0 en las relaciones de otras herramientas pero no tenían su propia entrada de servidor. Se completan aquí.

### 🖥️ vdiserver/ — Nextcloud Calendar (entrada completa)

Ya documentado en v5.0 pero con descripción incompleta de sus integraciones con Cal.com y Easy!Appointments.

- **Puertos:** 9082
- **BD Principal:** PostgreSQL 18 (comparte con Nextcloud Files)
- **Auth Keycloak:** ✅ SAML Keycloak

#### 13. Nextcloud Calendar (integración completa)

Módulo de calendario del ecosistema Nextcloud que implementa el estándar CalDAV. Permite gestionar eventos personales y de equipo, reservar salas de reuniones y recursos compartidos, recibir y enviar invitaciones de calendario en formato iCal compatible con cualquier cliente (Outlook, Google Calendar, Thunderbird). Los eventos se sincronizan en tiempo real entre todos los dispositivos del usuario.

- **Puerto:** 9082
- **Prioridad:** MEDIO
- **BD / Auth:** BD: PostgreSQL 18 (Nextcloud) / Auth: SAML Keycloak
- **Relaciones:** Comparte base de datos y autenticación SSO con Nextcloud Files (vdiserver). Cal.com (helpdeskserver) consulta la disponibilidad de Nextcloud Calendar para ofrecer slots libres a quienes reservan citas — así se evitan dobles reservas. Easy!Appointments (webserver) publica las citas confirmadas del personal en Nextcloud Calendar vía CalDAV. Roundcube (mailserver) puede mostrar el calendario junto al correo. OrangeHRM (appserver) sincroniza los días de vacaciones aprobados como eventos de calendario.

### 🖥️ projectserver/ — EspoCRM (integración completa con Cal.com)

EspoCRM ya está documentado en v5.0 pero el análisis reveló una integración adicional crítica con Cal.com para el ciclo lead→cita→cliente.

- **Puertos:** 26020
- **BD Principal:** PostgreSQL 18 (nativo)
- **Auth Keycloak:** ✅ OIDC Keycloak

#### 14. EspoCRM — Ciclo Lead→Cita→Cliente

Además de las integraciones documentadas en v5.0 (CardMesh, FreePBX, DocuSeal, Tryton Ventas), EspoCRM implementa el ciclo completo de captación: cuando un visitante escanea una tarjeta CardMesh o llena un formulario LimeSurvey, se crea automáticamente un lead en EspoCRM. El equipo de ventas agenda una cita usando Cal.com directamente desde el perfil del lead en EspoCRM. Cuando la cita ocurre y el lead se convierte en cliente, EspoCRM crea el registro en Tryton Ventas y todo el flujo comercial continúa en el ERP.

- **Puerto:** 26020
- **Prioridad:** MEDIO
- **BD / Auth:** BD: PostgreSQL 18 / Auth: OIDC Keycloak
- **Relaciones:** Cal.com (helpdeskserver) se integra con EspoCRM vía webhook — cuando se confirma una cita, Cal.com crea la actividad en EspoCRM con todos los datos del prospecto. EspoCRM lee disponibilidad de Nextcloud Calendar (vdiserver) para el personal de ventas. CardMesh (vcardserver) crea leads automáticamente en EspoCRM cuando alguien escanea una tarjeta. LimeSurvey (helpdeskserver) puede alimentar EspoCRM con datos de encuestas de captación. FreePBX (commsserver) registra las llamadas en el timeline del lead.

### 🖥️ cicdserver/ — Trivy (entrada completa)

Trivy aparece en el flujo CI/CD del v5.0 pero sin descripción propia. Se completa aquí con sus integraciones.

- **Puertos:** 22002
- **BD Principal:** — (scanner sin BD propia)
- **Auth Keycloak:** — (herramienta CI/CD)

#### 15. Trivy (entrada completa)

Scanner de seguridad de código abierto desarrollado por Aqua Security. Analiza imágenes Docker en busca de CVEs en paquetes del sistema operativo (Alpine, Debian, Ubuntu), dependencias de lenguajes (Python pip, Node npm, Ruby gems, Go modules), archivos de configuración de infraestructura como código (Kubernetes YAML, Dockerfile, Terraform) y secrets accidentales en código (claves API, contraseñas hardcodeadas). Actualiza su base de datos de vulnerabilidades diariamente desde múltiples fuentes (NVD, GHSA, OSV).

- **Puerto:** —
- **Prioridad:** MEDIO
- **BD / Auth:** BD: — / Auth: —
- **Relaciones:** Ejecutado en el pipeline GitLab CI (cicdserver) en el stage de security-scan, después del build de la imagen Docker y antes del deploy. Si detecta CVEs de severidad CRÍTICA o ALTA, el pipeline falla y bloquea el deploy. Los reportes se almacenan como artefactos en GitLab y se envían por correo al equipo de seguridad vía Postfix (mailserver). Complementa a OpenVAS (securityserver) — Trivy escanea imágenes en tiempo de build, OpenVAS escanea hosts en producción. Wazuh (securityserver) correlaciona los CVEs de Trivy con los exploits detectados en producción.

### 🖥️ searchengine/ — Apache Solr (integración completa con Kimios)

Solr ya está en searchengine/ en el v5.0, pero el análisis identificó configuraciones específicas faltantes para Kimios DMS y otros servicios.

- **Puertos:** 23010
- **BD Principal:** — (índices en disco)
- **Auth Keycloak:** — (infraestructura de búsqueda)

#### 16. Apache Solr — Integración Kimios y búsqueda empresarial

Apache Solr requiere una configuración específica para cada fuente de datos que indexa. Para Kimios DMS (workflowserver), Solr usa un schema personalizado con campos para: nombre del documento, ruta jerárquica, contenido textual extraído (PDF, Word, XLSX), autor, fecha de creación, tipo MIME, y etiquetas de clasificación. La búsqueda facetada permite filtrar resultados por tipo de documento, departamento, fecha o estado del flujo de aprobación. Para Wiki.js, Solr ofrece búsqueda full-text superior a la búsqueda nativa PostgreSQL de Wiki.js para corpus de documentación grandes.

- **Puerto:** 23010
- **Prioridad:** MEDIO
- **BD / Auth:** BD: — (índices propios) / Auth: —
- **Relaciones:** Kimios DMS (workflowserver) indexa cada documento aprobado en Solr automáticamente. Paperless-NGX (catalogserver) puede enviarse su índice de documentos OCR a Solr para una búsqueda unificada empresarial. Wiki.js (appserver) configura Solr como motor de búsqueda externo en lugar de PostgreSQL full-text. Airflow (orchestrator) programa reindexaciones completas nocturnas para mantener consistencia. Elasticsearch (searchengine) y Solr coexisten con roles diferenciados: Solr para documentos estructurados empresariales, Elasticsearch para logs y eventos de alta velocidad.

# 📊 Tabla Maestra — Las 17 Aplicaciones Complementarias

| # | Aplicación | Categoría | Servidor | Puerto | Prioridad | Inversión | Tiempo |
|---|---|---|---|---|---|---|---|
| 1 | Patroni | HA PostgreSQL | commonserver/ | 8008 | CRÍTICO | $5,000 | 2 semanas |
| 2 | etcd (3 nodos) | Distributed Config | commonserver/ | 2379/2380 | CRÍTICO | $3,000 | 1 semana |
| 3 | HAProxy + Patroni | Load Balancer HA | commonserver/ | 5432/5433 | CRÍTICO | $2,000 | 3 días |
| 4 | PgBouncer | Connection Pooler | commonserver/ | 6432 | CRÍTICO | $2,000 | 1 semana |
| 5 | pgBackRest | Backup PITR | backupserver/ | — | CRÍTICO | $3,000 | 1 semana |
| 6 | pg_stat_monitor | BD Metrics Avanzadas | commonserver/ | — | ALTO | $1,000 | 3 días |
| 7 | Amavis | Mail Content Filter | mailserver/ | 10024 | CRÍTICO | $1,500 | 1 semana |
| 8 | ClamAV (completo) | Antivirus Stack | mailserver/ | 3310 | CRÍTICO | $1,500 | 1 semana |
| 9 | Grafana Alloy | Agente Unificado | monitorserver/ | 12345 | ALTO | $1,000 | 3 días |
| 10 | PagerDuty | On-Call Alerting | monitorserver/ | — | ALTO | $1,000 | 1 semana |
| 11 | Celery Workers | Task Queue | apigateway/ | — | ALTO | $1,500 | 1 semana |
| 12 | Promtail | Log Agent Legacy | monitorserver/ | 9080 | MEDIO | $500 | 2 días |
| 13 | Nextcloud Calendar | Calendario CalDAV | vdiserver/ | 9082 | MEDIO | $1,000 | 3 días |
| 14 | EspoCRM (integración) | CRM Lead→Cita | projectserver/ | 26020 | MEDIO | $1,500 | 1 semana |
| 15 | Trivy (completo) | Container Security | cicdserver/ | — | MEDIO | $500 | 2 días |
| 16 | Apache Solr (config) | Búsqueda Docs | searchengine/ | 23010 | MEDIO | $1,000 | 1 semana |
| 17 | Mattermost (completo) | Chat DevOps | commsserver/ | 8065 | ALTO | $1,000 | 1 semana |

| Total Aplicaciones | Inversión Total Estimada | Tiempo Total (paralelo) |
|---|---|---|
| 17 aplicaciones complementarias | $28,000 USD (open source, solo implementación) | 4-6 semanas con equipo paralelo · 14 semanas secuencial |

# 🚀 Roadmap de Implementación — 14 Semanas

| Fase | Semanas | Actividades | Entregable | Criticidad |
|---|---|---|---|---|
| 1 | Sem 1 | Instalar etcd cluster 3 nodos · Configurar RAFT consensus · Verificar quorum con etcdctl · Integrar métricas etcd en Prometheus | etcd cluster operativo con quorum verificado | CRÍTICO |
| 2 | Sem 2-3 | Instalar Patroni en 3 nodos PostgreSQL · Configurar streaming replication · Probar failover manual y automático · Configurar sincronización síncrona | Cluster Patroni con failover automático <60s | CRÍTICO |
| 3 | Sem 4 | Configurar HAProxy para Patroni (health checks :8008) · Instalar PgBouncer · Migrar todas las apps a conectar por PgBouncer:6432 | HA PostgreSQL completo: RPO=0, RTO<60s | CRÍTICO |
| 4 | Sem 5 | Instalar pgBackRest · Configurar repositorio MinIO · Primer backup full · DAG Airflow de backup diario · Validar restore con Goss | PITR PostgreSQL operativo con backups en MinIO | CRÍTICO |
| 5 | Sem 6 | Instalar Amavis · Integrar con Postfix y ClamAV · Configurar políticas de cuarentena · Probar detección de virus en correo | Cadena antivirus mailserver completa | CRÍTICO |
| 6 | Sem 7 | Activar pg_stat_monitor en PostgreSQL · Crear dashboards Grafana de queries lentas · Configurar alertas de degradación · Instalar Grafana Alloy | Visibilidad completa de queries PostgreSQL | ALTO |
| 7 | Sem 8 | Configurar PagerDuty con Alertmanager · Definir cadenas de on-call · Probar escalaciones · Documentar Celery Workers especializados | On-call 24/7 operativo para incidentes críticos | ALTO |
| 8 | Sem 9-10 | Configurar Solr para Kimios DMS · Reindexar documentos existentes · Completar integración Nextcloud Calendar con Cal.com y Easy!Appts | Búsqueda empresarial unificada + calendario integrado | MEDIO |
| 9 | Sem 11-12 | Formalizar integración EspoCRM↔︎Cal.com↔︎CardMesh · Completar Trivy en todos los pipelines · Documentar Promtail para nodos legacy | Ciclo lead→cita→cliente cerrado en CRM | MEDIO |
| 10 | Sem 13-14 | Testing end-to-end completo · Chaos engineering (simular fallo master PostgreSQL) · Performance testing con K6 · Documentación final | Stack IAM v5.1 completo y validado — Listo para instalador | ALTO |

# 🔗 Flujos de Integración — Nuevas Apps en Contexto

## 1. Flujo Completo de Alta Disponibilidad PostgreSQL

Cualquier app del stack (Tryton, Keycloak, Saleor, GitLab...) conecta a PgBouncer:6432 → PgBouncer gestiona el pool y reenvía a HAProxy:5432 → HAProxy consulta Patroni REST API (:8008) de cada nodo cada 3 segundos → HAProxy solo envía escrituras al nodo que responde HTTP 200 en /master → Si ese nodo cae, Patroni en otro nodo adquiere el lock en etcd (consenso RAFT) → ejecuta pg_ctl promote → HAProxy detecta el nuevo /master en el siguiente ciclo → el tráfico se redirige en 30-60 segundos → PgBouncer gestiona la reconexión de las apps de forma transparente.

## 2. Flujo de Seguridad de Correo (cadena completa)

Correo externo llega a Postfix (mailserver) puerto 25 → Postfix lo pasa a Amavis (mailserver) puerto 10024 → Amavis invoca ClamAV (:3310) para escaneo antivirus → si tiene virus: cuarentena en PostgreSQL, alerta a Alertmanager (monitorserver), Alertmanager notifica en Mattermost (commsserver) canal-seguridad → si limpio: Amavis invoca SpamAssassin (mailserver) para puntuación → si spam: etiqueta o rechaza → si OK: devuelve a Postfix puerto 10025 → Postfix entrega a Dovecot (mailserver) → disponible en Roundcube para el usuario.

## 3. Flujo Lead→Cita→Cliente (EspoCRM + Cal.com + CardMesh)

Visitante escanea tarjeta CardMesh (vcardserver) → CardMesh crea automáticamente un lead en EspoCRM (projectserver) → vendedor abre el lead en EspoCRM → hace clic en 'Agendar cita' → abre Cal.com (helpdeskserver) con el contexto del lead → Cal.com consulta disponibilidad en Nextcloud Calendar (vdiserver) del vendedor → visitante selecciona fecha/hora → Cal.com confirma la cita → webhook de Cal.com crea la actividad en EspoCRM con todos los datos → en la cita, el lead se convierte en oportunidad → cuando hay pedido: EspoCRM crea la venta en Tryton (appserver) → ciclo comercial cerrado en el ERP.

## 4. Flujo CI/CD Seguro (Trivy integrado)

Desarrollador hace push a GitLab (cicdserver) → pipeline se activa → Stage 1 Build: construye imagen Docker → Stage 2 Security: Trivy escanea la imagen en busca de CVEs · si CVE CRÍTICO detectado → pipeline falla · correo de alerta vía Postfix al equipo de seguridad · Wazuh (securityserver) registra el CVE → Stage 3 Test: K6 pruebas de carga · si rendimiento OK → Stage 4 Deploy: Velero (backupserver) hace snapshot previo al deploy · Kubernetes aplica la nueva imagen · Goss (backupserver) valida que el servicio está healthy → Stage 5 Notify: Mattermost (commsserver) canal-deploys recibe confirmación del deploy exitoso.

# ✅ Conclusión — Stack IAM Enterprise v5.1 Completo

| Pilares de Alta Disponibilidad — ALCANZADOS | Seguridad Completada — ALCANZADA |
|---|---|
| ✅ Patroni + etcd → Failover automático PostgreSQL sin intervención humana (30-60 segundos) ✅ PgBouncer → 65+ aplicaciones conectadas sin colapsar PostgreSQL ✅ HAProxy configurado para Patroni → routing inteligente master/replica ✅ pgBackRest → PITR (restauración a cualquier segundo del pasado) ✅ RPO = 0 (replicación síncrona) ✅ RTO < 60 segundos (Patroni automático) | ✅ Amavis → Middleware antivirus/antispam unificado en mailserver ✅ ClamAV → Escaneo completo: correo + MinIO + uploads ✅ Trivy → Seguridad en imagen Docker antes de cada deploy ✅ PagerDuty → On-call 24/7 con escalación automática ✅ Wazuh + Trivy + OpenVAS → Defensa en profundidad multi-capa ✅ Todas las apps del stack escaneadas antes de producción |

> **🎯 Estado del Stack tras integrar este complemento**
>
> 31 Servidores + 17 aplicaciones complementarias = Stack IAM Enterprise v5.1 con cobertura 100% de los pilares documentados. PostgreSQL en alta disponibilidad real (Patroni + etcd + PgBouncer + pgBackRest), cadena de correo segura completa (Postfix + Amavis + ClamAV + SpamAssassin + Dovecot), observabilidad total (Grafana Alloy + Promtail + PagerDuty), y todos los flujos de negocio cerrados (Lead→Cita→Cliente vía CardMesh + Cal.com + EspoCRM + Tryton). Inversión adicional estimada: $28,000 USD · 14 semanas (secuencial) / 4-6 semanas (equipo paralelo). 100% Open Source — sin licencias comerciales.

*IAM Enterprise Stack v5.1 — Complemento HA & Apps Faltantes · Febrero 2026 · Patroni + etcd + PgBouncer + pgBackRest + ClamAV + Amavis + 11 apps de soporte*

*IAM Enterprise Stack v5.0 · Febrero 2026 · 31 Servidores · 65+ Aplicaciones · Tryton + PostgreSQL 18 + Keycloak 26.5.3 + NGINX*
