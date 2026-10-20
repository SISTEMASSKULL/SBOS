# bcms: gestor CMS de BOS, diseño y plan de desarrollo

Versión 0.3 · 13 de octubre de 2026 · Estado: borrador para empezar a construir

## 1. Resumen

bcms es el nombre del gestor CMS de BOS: un sistema para crear y mantener webs multi-tenant (tenant, empresa y sucursal) con mucha imagen y movimiento, editables sin tocar código. Se construye sobre **Payload CMS** (contenido y panel de edición) y un **sitio Next.js** (presentación pública), y consume los servicios que BOS ya tiene operativos. Primera entrega: la primera plantilla, una landing visual de una sola página que enlaza al **Desktop** y al **Carrito**; las subpáginas llegarán después con el mismo diseño. Cada empresa tendrá además una tarjeta digital (vCard) por usuario.

Principios:

1. **Solo el gestor CMS.** Nginx, Kong, Keycloak, bAuth, MinIO, Redis, PostgreSQL, bi18n y bkernel ya existen en BOS y se consumen por sus contratos. Son servicios compartidos entre áreas: separar los conceptos de cada área no impide colaborar con ellos.
2. **Reutilizar antes que programar.** Payload aporta bloques, medios, versiones, localización y panel.
3. **Diseño primero.** Un sistema de tokens SCSS compartido hace que cada subpágina herede el mismo diseño.
4. **Arquitectura del manual 7.01.** Jerarquía de tenant, empresa y sucursal, resolución por host y el camino Nginx, Kong, sitio.
5. **Contenido separado de la presentación.** Como en WordPress y Joomla, el contenido (los widgets) no depende de la plantilla, que solo organiza las secciones: empieza una sola, pero bcms soporta muchas, para distintos tipos de negocio (secciones 6 y 8.1).
6. **Soberanía.** bcms es una herramienta de SBOS, no un producto comercial: autoalojada, sin servicios externos, con los datos en la base de datos de BOS y pensada solo para las empresas afiliadas.

## 2. Alcance

| Dentro | Fuera (se consume o se hace después) |
| --- | --- |
| Colecciones de contenido, secciones, widgets y hooks de Payload; registro de plantillas | Instalar o configurar Keycloak, bAuth, Kong, Nginx, MinIO, Redis, PostgreSQL o Kubernetes |
| Sitio Next.js multi-tenant con el diseño SCSS | El VDI y las aplicaciones ERP |
| Módulo de integración con los servicios de BOS | Tienda y carrito con Medusa (fase posterior; el sitio solo enlaza) |
| Multi-idioma y traducción; tarjeta digital (vCard) por usuario; sincronización de libretas con Nextcloud | Destino del botón Desktop (VDI): es solo un enlace a ese servicio de BOS |
| Uso interno para las empresas afiliadas a SBOS | Uso comercial fuera de SBOS, portabilidad o migración de datos entre instalaciones |

## 3. Decisiones tomadas

| Tema | Decisión |
| --- | --- |
| Nombre | bcms es solo un nombre; no hay desarrollo previo con ese nombre |
| Contenido y panel | Payload CMS sobre PostgreSQL |
| Presentación | Sitio Next.js integrado con Payload (ver sección 8) |
| Estilos y animación | SCSS Modules con tokens propios y sin Tailwind; GSAP y Lenis (ver sección 9) |
| Servidor web | Nginx S02 y Kong, ya operativos en BOS |
| Identidad | Keycloak ahora y bAuth después, consumidos por OIDC |
| Idiomas iniciales | Español (origen) e inglés |
| Medios | MinIO existente |
| Tienda | Medusa, en una fase posterior |
| Referencias visuales | La estructura de la landing de payloadcms.com y de la demo de Cras; no se copian textos, imágenes ni código |
| Tarjeta digital | Módulo de vCard por usuario dentro de bcms (ver sección 7) |
| Libretas sincronizables | Nextcloud de BOS como servidor CardDAV, con sincronización en ambos sentidos y un único dueño por campo (sección 7.6) |
| Servicios compartidos | Los servicios de BOS se comparten entre áreas: se separan los conceptos, no la colaboración |
| Plantillas | Mismas secciones en todas las plantillas, rellenas con widgets; la plantilla solo define su arquitectura (secciones 6.2 y 8.1); empieza con una y soporta muchas |
| Soberanía | Herramienta de SBOS, no comercial: autoalojada, sin servicios externos y con los datos en la base de datos de BOS |
| Datos | Una sola base de datos de BOS (PostgreSQL 18, con identificadores UUID versión 7), con la misma estructura para todos y clasificada por tenant, empresa y sucursal a partir del ctx\_id (sección 6.5) |

## 4. Arquitectura

```
Internet
   |
 Nginx S02 (host)   TLS; host a cabeceras X-SBOS-*
   |
 Kong (Kubernetes)  rutas por host; añade ctx_id
   |
 +--------------------------------------------+
 | bcms (Kubernetes)                          |
 |   Sitio Next.js <-> Payload (API local)    |
 |   /        sitio público y tarjetas        |
 |   /admin   panel de edición                |
 |   Trabajador de sincronización de libretas |
 +-------+------------+------------+----------+
         |            |            |
    PostgreSQL       MinIO        Redis
    (base propia)    (medios)     (caché)

Servicios de BOS consumidos:
  Keycloak y bAuth (identidad y datos de usuario), servidor de correo (correo y alias),
  bi18n (textos y formatos), bkernel (eventos), Nextcloud (libretas CardDAV)
```

Camino de una petición, según el manual 7.01:

1. El visitante entra a un host, por ejemplo `cochabamba.acme.sbos.app`.
2. Nginx termina TLS, extrae el subdominio y añade las cabeceras `X-SBOS-Tenant` y `X-SBOS-Subdomain`.
3. Kong enruta por host hacia el sitio de bcms y añade `ctx_id`.
4. El sitio lee las cabeceras, resuelve tenant, empresa y sucursal, pide el contenido a Payload (API local) y lo renderiza con la plantilla asignada a esa empresa y su tema.
5. La respuesta se cachea en Redis.

## 5. Integración con BOS

El módulo `packages/bos` reúne todo lo que bcms necesita de BOS, para que el resto del código no conozca esos servicios. La autenticación, los roles y la trazabilidad los aportan bAuth y BOS; bcms solo valida la identidad, comprueba los roles y registra el `ctx_id`.

| Servicio de BOS | Se usa para | Contrato asumido (validar con su ficha) |
| --- | --- | --- |
| Nginx S02 y Kong | Llegada de la petición con el contexto del sitio | Cabeceras `X-SBOS-Tenant`, `X-SBOS-Subdomain` y `ctx_id` (manual 7.01, secciones 3.3 y 4); el ctx\_id define tenant, empresa y sucursal |
| Keycloak y bAuth | Identidad de los editores y datos de usuario (nombre, cargo y sucursal) | OIDC y JWT con los roles `cms_editor` y `cms_admin` (manual 7.01, sección 9.3) |
| bi18n | Textos de interfaz, formatos y validaciones | JSON-RPC `bi18n.*` por socket Unix |
| bkernel | Eventos de publicación | Evento `cms.page.published` |
| MinIO | Medios | Bucket `cms-media`, con prefijo por tenant y empresa |
| Redis | Caché de páginas | Clave `cms:{tenant_id}:{empresa_id}:{sucursal_id}:{slug}:{locale}`, TTL de 5 minutos configurable |
| PostgreSQL | Datos de Payload y registro de dominios | La base de datos de BOS (PostgreSQL 18), con un esquema propio para Payload; tabla `bos.net_web_domain` (T-415) para los dominios |
| Nextcloud | Libreta corporativa sincronizable (CardDAV) | Cuenta de servicio y una libreta compartida por empresa, escrita con tsdav (a definir) |
| Servidor de correo | Correo corporativo y alias de cada usuario | Eventos, API o directorio por definir (D10) |

Los dominios se registran con `bosctl web domain` y `bos.web.domain.*`. T-415 sigue pendiente de aprobación; bcms solo los consulta para resolver el host.

## 6. Modelo de contenido

Como en WordPress y Joomla, bcms separa dos capas independientes. El **contenido** (qué se dice: textos, imágenes, servicios, equipo, sucursales y menús) vive en la base de datos y no sabe nada de la plantilla. La **plantilla** (cómo se ve: diseño, disposición, estilos y animación) consume ese contenido. Cambiar de plantilla cambia el aspecto, no el contenido. Las tres capas del manual (tenant, empresa y sucursal) se traducen a colecciones de Payload, con aislamiento por contexto (sección 6.5).

| Concepto | WordPress | Joomla | bcms |
| --- | --- | --- | --- |
| Contenido | Páginas, entradas y tipos de contenido propios | Artículos y categorías | Páginas y colecciones de contenido |
| Disposición del sitio | Plantillas del tema y áreas de widgets | Plantilla y posiciones de módulos | Plantilla y regiones lógicas |
| Navegación | Menús | Menús | Colección de menús |
| Opciones de diseño | Opciones del tema | Parámetros de la plantilla | Opciones por plantilla de cada empresa |

### 6.1 Colecciones de contenido

| Colección | Contenido |
| --- | --- |
| `tenants` | Identificador, nombre y configuración global |
| `empresas` | Identificador, nombre, NIT, logo, paleta de marca, datos de contacto, redes y estado; apunta a su plantilla (sección 8.1) |
| `sucursales` | Empresa, slug, nombre, dirección, teléfono, correo, latitud y longitud, horario y estado |
| `pages` | Tenant, empresa, sucursal opcional, slug, tipo, título, resumen, imagen destacada, descripción SEO, widgets por sección, estado y fecha de publicación, con textos localizados |
| `servicios` | Nombre, descripción, imagen, precio opcional y orden |
| `testimonios` | Cita, autor, cargo y logo |
| `menus` | Árbol de enlaces asignado a una región lógica |
| `media` | Archivos en MinIO con texto alternativo y tamaños generados |
| `tarjetas` | Tarjeta digital de cada usuario, con su estado de sincronización con Nextcloud (sección 7) |
| `leads` | Formularios de contacto (fase posterior): datos, IP y `ctx_id` |

Global: `site-settings` (nombre, redes y SEO por defecto). Tipos de página: `home`, `about`, `services`, `contact`, `catalog`, `blog`, `custom` y `landing`. Otras colecciones (preguntas frecuentes, galerías, noticias) se añaden como módulos de contenido cuando hagan falta.

### 6.2 Secciones y widgets

Todas las plantillas comparten el mismo catálogo de **secciones**. Una sección es solo un contenedor: no tiene contenido propio, y todo lo que se ve en ella es un **widget**. La plantilla decide cómo se organizan las secciones (orden, columnas, ancho, fondo y animación); el contenido son los widgets que se colocan en cada una.

| Sección | Ámbito | Para qué sirve |
| --- | --- | --- |
| `cabecera` | Global (empresa) | Parte superior de todas las páginas: logo, menú, idioma y accesos |
| `portada` | Página | Primer bloque de la página: el mensaje principal |
| `principal` | Página | Cuerpo principal del contenido |
| `destacados` | Página | Elementos que se quieren resaltar |
| `complemento` | Página | Contenido de apoyo: testimonios, preguntas o equipo |
| `cierre` | Página | Último bloque antes del pie: llamada a la acción |
| `lateral` | Global o página | Columna o panel opcional |
| `pie` | Global (empresa) | Parte inferior de todas las páginas |

Es una propuesta de catálogo, con nombres ajustables. Añadir una sección al catálogo es un cambio de la plataforma, no de una plantilla.

| Widget | Para qué sirve | Datos principales |
| --- | --- | --- |
| `titular` | Título y subtítulo | Texto y nivel |
| `texto` | Texto enriquecido | Texto |
| `imagen` | Una imagen | Medio, texto alternativo y enlace opcional |
| `video` | Un video | Medio e imagen de portada |
| `galeria` | Conjunto de imágenes | Medios |
| `accion` | Botón o enlace de acción | Etiqueta y destino (Desktop, Carrito...) |
| `acceso` | Enlace destacado con imagen | Imagen, título, texto y destino |
| `caracteristicas` | Lista de puntos | Elementos con título, texto e imagen |
| `lista_contenido` | Elementos de una colección (servicios, equipo, noticias o productos de Medusa) | Colección, filtro y cantidad |
| `testimonios` | Opiniones de clientes | Referencias a la colección |
| `menu` | Menú de navegación | Referencia a un menú |
| `tarjeta` | Tarjeta digital o directorio del equipo | Referencia a la tarjeta o al equipo |
| `formulario` | Formulario de contacto | Campos y destino de los leads |
| `mapa` | Ubicación de una sucursal | Referencia a la sucursal |
| `selector_idioma` | Cambio de idioma | Idiomas disponibles |

Reglas:

1. **Ninguna sección es estática.** Todo contenido visible es un widget, incluso un título.
2. **Un widget guarda contenido y su sección,** no estilos ni posición visual.
3. **Mismas secciones en todas las plantillas.** Mover un widget de sección o cambiar de plantilla no rompe nada: la plantilla solo reorganiza.
4. **Referencias, no copias.** Un widget de lista apunta a una colección; nunca duplica sus datos.
5. **Cada widget** se puede ocultar y se ordena dentro de su sección. En las secciones globales podrá limitarse por tipo de página, idioma o dispositivo (a definir).
6. **Sin anidar al inicio.** Un widget puede tener una lista interna (por ejemplo `caracteristicas`), pero no contiene otros widgets.
7. **Ajustes propios de una plantilla.** Si hace falta una preferencia de una plantilla, se guarda aparte, en un objeto identificado por ella, que las demás ignoran.

### 6.3 Ámbitos y almacenamiento de los widgets

- **Secciones globales** (`cabecera`, `pie` y, si es global, `lateral`): sus widgets pertenecen a la empresa, con cascada de sucursal a empresa y a tenant, y se guardan en un documento de diseño global por empresa.
- **Secciones de página:** sus widgets pertenecen a cada página.
- **En Payload:** un campo de bloques en el que cada tipo de widget es un bloque, y cada bloque lleva su sección. El orden es el de la lista. Mover un widget de sección es cambiar ese valor.
- **Panel:** al inicio, cada widget tiene un selector de sección. Una vista que agrupe por sección y permita arrastrar entre ellas es un componente propio del panel, porque Payload reordena dentro de una lista, no entre listas distintas (fase posterior).

### 6.4 Opciones de diseño y cascada

Las opciones de diseño (paleta, tipografía, estilo del encabezado, etc.) se guardan por empresa y por plantilla, como las opciones de tema de WordPress; al cambiar de plantilla no se pierden las de la anterior. La plantilla y las opciones se resuelven de abajo arriba: sucursal, empresa y tenant. Para una página, si la sucursal tiene una con el mismo slug se usa esa; si no, la de la empresa.

### 6.5 Clasificación por tenant, empresa y sucursal

bcms es una herramienta soberana de SBOS, no un producto comercial. Toda su información vive en la misma base de datos de BOS, con la misma estructura para todos: no hay una base de datos ni un esquema por tenant, y los datos solo se **clasifican**.

- Cada fila lleva `tenant_id`, `empresa_id` y `sucursal_id`. Los datos de nivel tenant dejan vacíos empresa y sucursal; los de nivel empresa dejan vacía la sucursal.
- La clasificación la define el `ctx_id` de BOS: toda lectura y escritura se hace con el contexto (tenant, empresa y sucursal) que este identifica. En el sitio público el contexto sale del host; en el panel, de la identidad del editor.
- El aislamiento se aplica en la propia base de datos con seguridad por filas de PostgreSQL (RLS), además del control de acceso de Payload, para que ninguna consulta cruce tenants.
- El plugin de multi-tenencia de Payload cubre un solo nivel; los tres niveles se implementan con campos propios y control de acceso a partir del contexto (verificar).
- Las restricciones de unicidad incluyen las tres columnas y usan `NULLS NOT DISTINCT` (disponible desde PostgreSQL 15; BOS usa la 18), porque PostgreSQL trata los valores vacíos como distintos y permitiría duplicados.
- Los índices empiezan por `tenant_id`, `empresa_id` y `sucursal_id`.
- No se migran ni se mueven datos entre instalaciones: no hay exportación ni importación de plantillas o contenido entre sistemas.
- Los identificadores son UUID versión 7, generados por la base de datos con `uuidv7()` de PostgreSQL 18 en todas las tablas, incluidos `tenant_id`, `empresa_id` y `sucursal_id`. Al ser ordenables por tiempo, mejoran la localidad de los índices. Como revelan la fecha de creación, las URL públicas usan el slug y no el identificador.

## 7. Tarjeta digital (vCard) multi-usuario

Cada empresa ofrece, además del sitio, el enlace al Desktop (VDI) y el carrito, una tarjeta empresarial digital por usuario. Es un módulo de bcms que reutiliza las mismas colecciones, el mismo tema y el mismo sitio.

### 7.1 Qué ofrece

Una página pública por persona (por ejemplo `/tarjeta/juan-perez` dentro del host de la empresa) con foto, nombre, cargo, empresa y sucursal, teléfonos, correos y enlaces a redes. Incluye botones de acción (llamar, escribir, WhatsApp, cómo llegar) y **Guardar contacto**, que descarga un archivo `.vcf` (vCard, RFC 6350). Un código QR, y opcionalmente una etiqueta NFC, apunta a esa URL. La tarjeta usa el logo y la paleta de su empresa.

### 7.2 Multi-tenant y multi-usuario

- Cada tarjeta pertenece a un tenant, una empresa y, opcionalmente, una sucursal; el host decide qué tarjetas se muestran.
- Cada usuario gestiona su propia tarjeta desde `/mi-tarjeta`, sin entrar al panel `/admin`.
- Un administrador de tarjetas gestiona todas las de su empresa. Los roles de propietario y de administrador de tarjetas se definen con bAuth: el manual 7.01 solo prevé `cms_editor` y `cms_admin`.
- La tarjeta guarda el identificador de identidad del usuario (`sub`) para vincularla a BOS.
- Cada usuario decide qué campos son visibles, por ejemplo ocultar su teléfono personal.

### 7.3 Modelo y rutas

Colección `tarjetas`: tenant, empresa, sucursal, usuario, slug (único por empresa), nombre, cargo, foto, teléfonos, correos, enlaces, biografía corta, visibilidad por campo, estado, tema opcional y estado de sincronización con Nextcloud (UID, hash y ETag).

| Ruta | Función |
| --- | --- |
| `/tarjeta/[slug]` | Página pública de la tarjeta |
| `/tarjeta/[slug]/contacto.vcf` | Descarga del contacto en formato vCard |
| `/tarjeta/[slug]/qr` | Código QR de la tarjeta, en SVG |
| `/equipo` | Directorio de tarjetas de la empresa o sucursal |
| `/mi-tarjeta` | Edición por el propio usuario, autenticada con BOS |

### 7.4 Notas técnicas

- La vCard es texto en formato estándar y se responde con `Content-Type: text/vcard; charset=utf-8`. La foto incrustada es opcional por su tamaño.
- El QR se genera en el servidor con una librería de código abierto y se cachea.
- `/mi-tarjeta` usa la API local de Payload con control de acceso por propietario: cada usuario solo puede editar la tarjeta vinculada a su identidad.
- bi18n aporta `bi18n.validate.phone` para validar teléfonos, y `bi18n.format.name` y `bi18n.format.address` para dar formato a nombre y dirección según el idioma.
- La tarjeta es pública por diseño: solo se publica lo marcado como visible, y desactivarla la retira de inmediato invalidando la caché.
- Fase posterior: contadores de visitas y de contactos guardados, sin datos personales del visitante.

### 7.5 CardDAV: cuándo hace falta

La tarjeta digital y CardDAV resuelven cosas distintas. La tarjeta es una página con un archivo `.vcf` que la persona guarda una vez; CardDAV es un protocolo para mantener una libreta de direcciones sincronizada en teléfonos y programas de correo. Para la tarjeta no hace falta ningún servidor CardDAV.

Decisión propuesta: la vCard pública se genera de forma nativa dentro de Payload y Next.js, para que la tarjeta no dependa de otro servicio. La libreta corporativa sincronizable en teléfonos y Outlook se apoya en el Nextcloud de BOS, como servicio compartido, y se entrega después de la tarjeta.

| Opción | Evaluación |
| --- | --- |
| Generación nativa (propuesta) | Sin servidor ni base de datos extra; encaja con las colecciones y la multi-tenencia de Payload |
| Nextcloud de BOS (servidor S13, namespace sbos-vdi) | Opción preferida para la libreta sincronizable: es un servicio compartido de BOS, no hay que desplegar nada nuevo y ya usa Keycloak. Su servidor CardDAV viene en el núcleo (la app Contactos solo añade la interfaz web; verificar). Hay que diseñar una cuenta de servicio y una libreta compartida por empresa |
| Davis | Ligero, pero es PHP; su documentación recomienda MariaDB y marca PostgreSQL como poco probado |
| Kurrier, OxiCloud y EGroupware | Descartados: suite de correo, nube orientada a archivos y groupware demasiado grande |
| CardDAV propio dentro de Payload | Posible solo de lectura (PROPFIND, REPORT y GET, RFC 6352); trabajo extra y riesgo de incompatibilidades con los clientes |

Con la sincronización activa, la libreta de cada empresa se mantiene en ambos sentidos con reglas por campo (sección 7.6). Los permisos de lectura de cada libreta se derivan de la identidad de BOS.

La tarjeta no depende de Medusa: se conectan por el tenant y por enlaces, por ejemplo un botón hacia el catálogo.

### 7.6 Sincronización en ambos sentidos

Los datos llegan a la libreta de Nextcloud desde varias fuentes (bAuth, el servidor de correo y Payload) y los usuarios también pueden editarla. Para evitar conflictos y bucles, cada campo tiene un único dueño.

| Campo de la vCard | Dueño | Flujo |
| --- | --- | --- |
| Nombre, cargo, organización y sucursal | bAuth (BOS) | De bAuth hacia Payload y Nextcloud; las ediciones hechas en Nextcloud se descartan y se registran |
| Correo corporativo y alias | Servidor de correo | Del servidor de correo hacia Payload y Nextcloud |
| Foto, biografía, enlaces a redes y visibilidad | Payload (el usuario, desde `/mi-tarjeta`) | De Payload hacia Nextcloud |
| Teléfonos personales y notas | El usuario, en Payload o en Nextcloud | En ambos sentidos; gana la última edición |

Flujo:

1. Un cambio en bAuth o en el servidor de correo genera un evento en bkernel.
2. Un trabajador de sincronización del proyecto, que usa la API local de Payload, aplica el cambio a la colección `tarjetas`.
3. El trabajador escribe la vCard en la libreta de la empresa en Nextcloud mediante CardDAV (`tsdav`), con la cuenta de servicio.
4. Las ediciones hechas en Nextcloud se leen con sync-token (REPORT de sincronización de WebDAV) o con los webhooks de Nextcloud (verificar su disponibilidad en la versión desplegada) y solo se aplican a Payload en los campos que permite su dueño.

Reglas para evitar bucles y duplicados:

- Cada contacto lleva un UID estable, igual al identificador de la tarjeta, y una propiedad `X-SBOS-SYNC-ID`. Los contactos sin esa propiedad no se tocan.
- Por tarjeta se guarda un hash del contenido sincronizado y el ETag de Nextcloud; si el hash no cambió, no se escribe.
- Cada escritura lleva el `ctx_id` y queda auditada.
- Desactivar a un usuario en bAuth desactiva su tarjeta y la retira de la libreta compartida.

## 8. Presentación del sitio y motor de renderizado

Hay dos formas de renderizar las páginas. La propuesta es la A para las fases 1 y 2.

| Criterio | A. Next.js con Payload (propuesta) | B. Renderizador con Minijinja o Tera (manual 7.01) |
| --- | --- | --- |
| Acceso al contenido | API local de Payload dentro de la misma app, sin red | Cliente HTTP hacia la API de Payload, con tipos y caché propios |
| Tiempo hasta la landing | Bajo: componentes React y SCSS sobre el starter de Payload | Mayor: servicio, cliente de contenido y pipeline de assets por construir |
| Vista previa de borradores | Incluida en el starter | Por construir |
| Optimización de imágenes | `next/image` con sharp | Por construir (variantes de Payload o servicio de imágenes) |
| Animaciones con SCSS, GSAP y Lenis | Sí | Sí: son archivos del navegador y no dependen del motor |
| Herencia global, tenant, empresa y sucursal | Patrones de sección y opciones de la plantilla | Natural con `{% extends %}` |
| Ruta pública sin Node | No | Sí |
| Afinidad con el stack de BOS | Node y React | Rust, como otros daemons |
| Plantillas editables por el tenant | No hace falta: los widgets cubren la edición | Sí, con el riesgo de HTML y JS escritos por cada tenant |

Un motor de plantillas no acelera por sí solo: el trabajo pesado está en el panel de edición, los medios, las versiones y la localización, que Payload ya resuelve, y en conectar el contenido con la página, que con Next.js se hace sin red. Por eso se mantiene la opción A. La B queda como evolución posible si más adelante se quiere una ruta pública sin Node o plantillas distintas por empresa. Para facilitarla, el contenido se publica con un esquema de bloques estable que cualquier renderizador pueda leer.

### 8.1 Plantillas: la arquitectura de las secciones

Una plantilla solo decide **cómo se organizan y se ven** las secciones (6.2). Todas comparten el mismo catálogo de secciones y el mismo vocabulario de widgets; lo único que cambia es la arquitectura. Al inicio habrá una plantilla, la de la landing visual, pero bcms debe soportar muchas, creadas con el tiempo para distintos tipos de negocio. Como los widgets se reubican libremente, se pueden crear diseños nuevos de forma continua.

Una plantilla se compone de:

1. **Descriptor de arquitectura (datos):** el orden de las secciones, el patrón de cada una, cuáles se muestran y sus parámetros (columnas, ancho, fondo, espaciado y animación de entrada).
2. **Tokens y estilos:** paleta, tipografía, espaciados y los estilos de los patrones.
3. **Renderizadores de widgets:** usa los compartidos y puede sustituir el de un widget para darle un aspecto propio.
4. **Manifiesto y contenido de demostración.**

Los **patrones de sección** forman una biblioteca compartida (por ejemplo `ancho_completo`, `columnas`, `dividida`, `carrusel`, `mosaico`, `apilada` y `lateral_principal`). Un diseño nuevo suele ser un descriptor nuevo con tokens propios que reutiliza patrones existentes; solo los patrones o renderizadores nuevos requieren código.

**Estilos: lo único propio de cada plantilla.** Los widgets no tienen un aspecto fijo: heredan los estilos de la plantilla mediante tokens (variables CSS) en dos niveles. Los tokens globales (paleta, tipografía, espaciados, radios, sombras y movimiento) valen para todos los widgets, y la plantilla puede definir tokens por widget, por ejemplo la forma y la tipografía de un reloj, que si faltan caen en los globales. Así un mismo widget puede ser cuadrado en una plantilla, rectangular en otra o estar dentro de un círculo con otra fuente, sin tocar su contenido. Cada widget expone sus partes con atributos estables (`data-widget` y `data-parte`) para que la plantilla pueda ajustarlas. Cuando la diferencia no es de estilo sino de estructura, como un reloj analógico en lugar de uno digital, se resuelve con un renderizador propio de la plantilla.

Ejemplo de descriptor, simplificado:

```
secciones:
  - id: cabecera
    patron: barra_fija
  - id: portada
    patron: ancho_completo
    animacion: revelar
  - id: destacados
    patron: mosaico
    columnas: 3
  - id: principal
    patron: dividida
    proporcion: 60/40
  - id: complemento
    patron: carrusel
  - id: cierre
    patron: ancho_completo
  - id: pie
    patron: columnas
    columnas: 4
```

| Colección | Contenido |
| --- | --- |
| `plantillas` | Slug único, nombre, versión, estado (borrador, publicada u obsoleta), tipos de negocio recomendados, descriptor de arquitectura, clave del paquete de estilos y renderizadores, esquema de opciones de diseño, imagen de vista previa y notas de versión |
| `tipos_negocio` | Slug, nombre, plantillas recomendadas, widgets y colecciones de dominio sugeridos, y páginas sugeridas |
| `empresas` (campos nuevos) | Plantilla asignada y opciones de diseño por plantilla |
| `sucursales` (campo nuevo) | Plantilla opcional que sustituye a la de la empresa |

Contrato entre contenido y plantilla:

1. **Mismo catálogo.** Ninguna plantilla añade ni quita secciones: solo las organiza. Si oculta una, sus widgets quedan guardados sin mostrarse.
2. **Todos los widgets base.** Toda plantilla debe poder dibujar todos los widgets base; si no tiene renderizador propio, usa el compartido.
3. **Sin exigencias.** Una plantilla puede añadir variantes y efectos, pero nunca exigir campos propios en los widgets.
4. **Contenido propio de un tipo de negocio.** Cosas como la carta de un restaurante son widgets y colecciones de dominio, declarados en `tipos_negocio` e independientes de la plantilla.
5. **Cambio de plantilla sin migrar contenido,** con una vista previa del contenido real antes de cambiar.
6. **Una sola versión.** No hay versiones por empresa: la plantilla evoluciona en un único lugar y sus cambios se prueban primero como borrador y con vista previa, porque afectan a todas las empresas que la usan.
7. **Pruebas de conformidad.** Cada plantilla se prueba con una empresa de demostración que use todas las secciones y todos los widgets.

**Cómo se añade una plantilla nueva.** Si solo usa patrones y renderizadores existentes, basta con registrar su descriptor y sus tokens en `plantillas`, sin desplegar ni migrar. Si necesita un patrón o un renderizador nuevo, hay que añadir código y desplegar. Esto se ajusta con la decisión D11.

## 9. Diseño visual y front-end

### 9.1 Principios y componentes

- **Tokens SCSS** (`_tokens.scss` y `_mixins.scss`): colores, tipografías, espaciados, curvas y duraciones de animación. El tema de cada empresa se emite como variables CSS.
- **Animación:** GSAP con ScrollTrigger y Lenis para el scroll suave, respetando `prefers-reduced-motion`.
- **Imágenes:** AVIF y WebP generados con sharp. El video del hero va comprimido, con `poster` y los atributos `muted autoplay loop playsinline`.
- **Componentes:** cada widget es un componente React con su módulo SCSS y cada patrón de sección es un componente compartido; la plantilla puede sustituir el renderizador de un widget.
- **Idiomas de derecha a izquierda:** propiedades lógicas de CSS desde el inicio.
- **Estructura de la landing:** hero a pantalla completa, tarjetas hacia Desktop y Carrito, secciones de imagen y texto, testimonios y cierre con llamada a la acción.
- **Licencias:** revisar las condiciones vigentes de GSAP y de las funciones de pago de Payload (por ejemplo, el editor visual) antes de depender de ellas.
- **Soberanía:** tipografías autoalojadas, sin CDN externos (por ejemplo Google Fonts) ni analítica de terceros.

```
bcms/
+- apps/web/                 Next.js + Payload (sitio, tarjetas y panel)
+- apps/worker/              sincronización de libretas con Nextcloud (eventos de BOS y CardDAV)
+- packages/design-tokens/   tokens base y mixins SCSS compartidos
+- packages/widgets/         widgets base: esquema y renderizador compartido
+- packages/layouts/         patrones de sección compartidos
+- packages/templates/       una carpeta por plantilla: descriptor, tokens y renderizadores propios
+- packages/bos/             integración con los servicios de BOS
```

### 9.2 SCSS: framework y organización

Payload no impone estilos al sitio público. Su starter de sitio web trae Tailwind CSS y shadcn/ui para el frontend (verificar en la versión instalada), y el panel `/admin` tiene su propia hoja de estilos, que se personaliza en un archivo `custom.scss` aparte. Por eso el sitio puede usar SCSS sin afectar al panel.

Propuesta: **SCSS Modules** (Dart Sass, que Next.js soporta de forma nativa) con un sistema de diseño propio, sin Tailwind ni shadcn/ui en el sitio público.

| Opción | Ventajas | Inconvenientes |
| --- | --- | --- |
| Sistema propio con SCSS Modules (propuesta) | Diseño único y control total de las animaciones; poco peso | Hay que construir los componentes base |
| Bootstrap 5 (código fuente SCSS) | Rejilla, utilidades y componentes listos; se personaliza con variables; es lo que usa la plantilla Cras de referencia | Aspecto reconocible y más peso; conviene importar solo las partes necesarias |
| Tailwind (el del starter) | Rápido para maquetar y ya viene incluido | No es SCSS: choca con el control por SCSS que se busca |

Organización de los estilos:

```
styles/
+- abstracts/   _tokens.scss, _functions.scss, _mixins.scss
+- base/        _reset.scss, _typography.scss
+- themes/      _theme-vars.scss (variables CSS por tenant)
+- components/  un archivo .module.scss por bloque
```

Reglas:

- Usar `@use` y `@forward`: el `@import` de Sass está en desuso.
- Los tokens se publican como variables CSS (por ejemplo `--color-primary`). Las variables de SCSS se resuelven al compilar y no pueden cambiar por tenant; el tema de cada empresa se inyecta en tiempo de ejecución desde `empresas.paleta`.
- Los tonos derivados se calculan en CSS (por ejemplo con `color-mix()`, verificando el soporte de los navegadores) y no con funciones de color de Sass.
- Mixins para puntos de ruptura, tipografía fluida y animaciones, con unidades relativas.
- Al partir del starter de Payload hay que retirar Tailwind y shadcn/ui de los componentes del sitio y reescribirlos con SCSS Modules. La lógica de colecciones y bloques no cambia.
- Cada plantilla tiene su propia carpeta de estilos y su manifiesto de tokens por defecto; los tokens base y los mixins se comparten entre todas.

## 10. Idiomas

Idiomas iniciales: español (idioma de origen) e inglés. La cantidad de idiomas es flexible.

### 10.1 Dos capas

| Capa | Dónde vive | Quién la mantiene |
| --- | --- | --- |
| Textos de interfaz (botones, menús, formularios) | bi18n, con un espacio de nombres propio en archivos FTL | Traductores |
| Contenido editorial (títulos, widgets, SEO, texto alternativo) | Payload, en campos localizados | Editores desde `/admin` |
| Formatos y validaciones (fechas, números, teléfonos, CI y NIT) | Llamadas a `bi18n.format.*` y `bi18n.validate.*` | No aplica |

La localización de Payload se activa desde el inicio, aunque solo se rellene un idioma: añadirla después obliga a migrar datos.

### 10.2 Integración con bi18n

- bi18n solo escucha en sockets Unix. El servidor de Next.js lo consulta por el socket montado en el contenedor (revisar permisos); el navegador nunca habla con bi18n.
- El módulo `packages/bos` ofrece `getMessages(locale, namespace)`, con caché en memoria y una copia de respaldo exportada en cada despliegue, para que la web siga funcionando si bi18n no responde.
- bi18n usa **Project Fluent (FTL)**, no ICU MessageFormat: el frontend renderiza con `@fluent/bundle`.
- Cada llamada necesita un `ctx_id` para la auditoría; hay que definir cómo lo obtiene el sitio.
- Hoy bi18n tiene `es-BO` y `en-US`; se asocian a `es` y `en` en Payload y en las rutas `/es` y `/en`.

### 10.3 Traducción automática (fase posterior)

1. Un hook `afterChange` detecta los campos cambiados y encola un trabajo en la cola de trabajos de Payload (verificar en la versión instalada).
2. El trabajo traduce los textos mediante un adaptador `TranslationProvider` (un motor autoalojado, como NLLB, Argos Translate o LibreTranslate, o un modelo propio de BOS; no se usan servicios externos) y guarda el resultado como borrador del idioma de destino con la API local.
3. Un revisor humano o una pasada de IA lo aprueba. Español e inglés exigen revisión humana; los idiomas secundarios pueden publicarse tras la revisión de IA, marcados como traducción automática.
4. Si cambia el texto de origen, la traducción pasa a desactualizada y se vuelve a encolar.

Reglas: no se traducen URLs, códigos ni nombres de marca; el contenido sin aprobar se sirve con `noindex`; las versiones aprobadas llevan `hreflang` y slugs localizados. Añadir un idioma exige una migración, porque en PostgreSQL los idiomas de Payload suelen guardarse como un tipo enumerado (verificar).

Weblate existe hoy solo como instancia de pruebas de bi18n. Si pasa a producción, podría ofrecer glosario, memoria de traducción y flujo de revisión para los textos de interfaz y para el contenido (con claves estables por documento y campo). Es una decisión posterior.

## 11. Publicación y caché

1. El editor publica en Payload. Los borradores nunca se cachean.
2. Un hook `afterChange` invalida la clave de Redis de esa página y revalida la página del sitio.
3. Se emite el evento `cms.page.published` hacia bkernel (mecanismo por definir, decisión D2).
4. La siguiente petición se renderiza con el contenido nuevo.

## 12. Fases del desarrollo

| Fase | Entregables | Criterio de aceptación |
| --- | --- | --- |
| 1. Núcleo de contenido | Colecciones de contenido, catálogo de secciones y widgets, registro de plantillas, borradores, es y en, medios en MinIO | Se edita una página desde `/admin` y se ve publicada |
| 2. Sitio y landing | Resolución por cabeceras, cascada empresa y sucursal, primera plantilla (descriptor de arquitectura y tokens) con su tema por empresa, landing con SCSS, GSAP y Lenis | La landing responde por host y enlaza a Desktop (VDI) y Carrito |
| 3. Tarjeta digital (vCard) | Colección `tarjetas`, página pública, descarga del contacto, código QR, directorio del equipo y edición por el propio usuario | Un usuario edita su tarjeta, el contacto se guarda en iOS y Android y el QR abre la tarjeta |
| 4. Integración con BOS | Dominios, caché e invalidación, eventos, bi18n | Publicar invalida la caché y los textos vienen de bi18n |
| 5. Libretas con Nextcloud | Trabajador de sincronización, cuenta de servicio, libreta por empresa y reglas por campo (sección 7.6) | Un cambio en bAuth aparece en la libreta y una edición permitida en Nextcloud llega a Payload, sin bucles |
| 6. Idiomas ampliados | Traducción automática y revisión | Publicar en español genera el borrador en inglés y un revisor lo aprueba |
| 7. Ampliaciones | Nuevas plantillas por tipo de negocio, formularios y leads, SEO (sitemap, robots y Open Graph), bsearch, biedata y tienda con Medusa | Por definir al cerrar la fase 6 |

## 13. Decisiones abiertas

| ID | Decisión | Opciones o propuesta |
| --- | --- | --- |
| D1 | Dueño de los datos de empresa y sucursal | Decidido: la misma base de datos de BOS, con un esquema propio para el CMS y filas clasificadas por tenant, empresa y sucursal desde el ctx\_id (sección 6.5) |
| D2 | Cómo avisa el sitio a BOS al publicar (evento e invalidación) | Llamada interna a un servicio de BOS o acceso directo a Redis; el manual menciona los puertos 9080 y 9480 |
| D3 | Motor de renderizado | Next.js con Payload (propuesto) o plantillas Minijinja o Tera (sección 8) |
| D4 | Jerarquía de URL (HITL-CMS-4) | Define los hosts que el sitio debe resolver |
| D5 | Dominio de la primera web | Por definir |
| D6 | T-415 (persistir dominios) | Aprobación pendiente |
| D7 | Framework de SCSS | Sistema propio con SCSS Modules (propuesto) o Bootstrap 5 (sección 9.2) |
| D8 | URL y roles de la tarjeta digital | Ruta dentro del host de la empresa (propuesto) o subdominio dedicado; roles de propietario y de administrador de tarjetas por definir con bAuth |
| D9 | Directorio sincronizable (CardDAV) | Nextcloud de BOS como servidor CardDAV (propuesto). Falta definir la cuenta de servicio, las libretas compartidas por empresa y la fase de entrega; Davis queda como alternativa si no encaja con la multi-tenencia |
| D10 | Eventos del servidor de correo y de bAuth | Definir qué servidor de correo usa BOS y cómo publica los cambios (evento, API o directorio), y confirmar el evento de bkernel para los cambios de bAuth |
| D11 | Cómo se crean las plantillas | Descriptor de arquitectura y tokens como datos, editables sin desplegar, sobre un código compartido de patrones y renderizadores (propuesto); plantillas totalmente como código; o HTML y JS por plantilla guardados en la base de datos (opción B de la sección 8, no recomendada) |
| D12 | Contenido propio de un tipo de negocio (por ejemplo, la carta de un restaurante) | Widgets y colecciones de dominio, independientes de la plantilla (propuesto), o widgets que viajan con la plantilla (rompe la separación entre contenido y plantilla) |
| D13 | Cómo se añaden tipos de widget nuevos sin migrar la base de datos | Bloques de Payload para los widgets base (propuesto), más un widget genérico con tipo y datos validados por un esquema para los que se creen con el tiempo, sin migración (a evaluar) |
|  |  |  |
|  |  |  |

## 14. Verificaciones antes de construir

- Compatibilidad de Payload y del plugin de multi-tenencia con PostgreSQL 18 (la base de datos de BOS ya es la 18, así que no hay alternativa: conviene comprobarlo pronto).
- Qué funciones de Payload requieren licencia de pago y cuáles incluye la versión libre.
- Métodos de bi18n para obtener los mensajes de un idioma y espacio de nombres; la ficha solo lista los grupos de traducción. El manual 7.01 cita `bi18n.format(locale, key, vars)`, que no figura en la ficha.
- Cómo obtiene el sitio el `ctx_id` que exige bi18n.
- Rutas de Kong declaradas por host exacto, para que la ruta pública del sitio no capture `/admin` ni la ruta comodín prevista en el manual.
- Puerto de los servicios: el manual 7.01 menciona 9080 y 9480 para el mismo componente.
- Que el starter de Payload funcione sin Tailwind ni shadcn/ui en el sitio público, y qué componentes hay que reescribir con SCSS Modules.
- Importación de la vCard en iOS y Android, con y sin foto incrustada.
- Roles de propietario y de administrador de tarjetas en bAuth.
- Que el servidor CardDAV esté activo en la versión de Nextcloud desplegada (30.0.2) y que estén disponibles sus webhooks; si no, usar sync-token.
- Que exista el evento de bkernel para los cambios de datos de usuario en bAuth, y cómo publica sus cambios el servidor de correo (D10).
- Cómo se corresponden los grupos de Keycloak con los de Nextcloud para compartir la libreta de cada empresa.
- Que Payload permita un único campo de widgets (bloques) reutilizable, con la sección de cada widget como campo, y cómo mover widgets entre secciones en el panel (Payload reordena dentro de una lista, no entre listas).
- Que el catálogo de secciones y los widgets base se mantengan pequeños y estables: cada tipo de widget nuevo crea tablas en PostgreSQL y exige una migración.
- Cómo se renderizan los widgets dinámicos (reloj, carrito, listas): en el servidor, con partes interactivas en el cliente, y cómo afecta eso a la caché de página.
- Que el catálogo de 8 secciones baste para la primera landing (portada, accesos, texto e imagen, características, testimonios, declaración y cierre) sin forzar bandas apiladas.
- Que el adaptador de PostgreSQL de Payload permita un esquema propio dentro de la base de datos de BOS, y que genere los identificadores con uuidv7() en lugar del UUID aleatorio por defecto (por ejemplo, con ganchos del esquema o con una migración). La restricción `NULLS NOT DISTINCT` ya está disponible en PostgreSQL 18.
- Cómo se traduce el `ctx_id` en tenant, empresa y sucursal en cada operación, y cómo se aplica la seguridad por filas (RLS) junto al control de acceso de Payload.
- Si se exige soberanía también en la cadena de suministro, espejar las dependencias npm en un registro interno.
