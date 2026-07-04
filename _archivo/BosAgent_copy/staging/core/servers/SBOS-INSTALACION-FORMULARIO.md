# SBOS — FORMULARIO DE INSTALACIÓN POR CLIENTE

**Documento:** SBOS-INSTALACION-FORMULARIO  
**Versión:** 1.0  
**Fecha:** 2026-05-14  
**Referencia:** SBOS-005-STACK.md · SBOS-049-FICHAS-BOS.md · INVENTARIO-FICHAS.md  
**Instrucción al agente:** Leer este documento completo antes de ejecutar cualquier instalación. Solicitar al HITL los datos marcados con `\[ ]`. No proceder sin tener la Sección 1, 2 y 3 completas.

\---

## DECISIONES ARQUITECTÓNICAS TOMADAS

*Estas decisiones ya están tomadas — el agente NO debe cuestionarlas ni proponer alternativas.*

|ID|Decisión|Justificación|
|-|-|-|
|DEC-I01|**Elasticsearch sobre OpenSearch**|Benchmarks muestran ES hasta 8-12x más rápido en vector search filtrado. El aiserver con Ollama, Qdrant y embeddings requiere máximo rendimiento vectorial.|
|DEC-I02|**Let's Encrypt para TLS**|Gratuito, automatizable con Certbot vía DNS-01 challenge. Válido para wildcard `\*.dominio.com`.|
|DEC-I03|**Vault como fuente de verdad para secrets**|El SBOS ya tiene Vault en el stack. Todos los K8s Secrets se alimentan desde Vault vía External Secrets Operator.|
|DEC-I04|**Toda aplicación es una ficha administrada por bos-agent**|Ninguna aplicación se instala directamente. Sin excepción. Ver SBOS-049.|
|DEC-I05|**Imágenes SKULL se construyen con la fábrica**|Los proyectos smarttax, smartreport, cardmesh, bcompass, etc. son subproyectos del SBOS. Se construyen con el Compositor cuando llegue su turno. No son recursos externos.|
|DEC-I06|**Config avanzada de resources/ se llena por sesión**|Los `resources/` vacíos de las 85 fichas se completan conforme avanza el desarrollo. No bloquean el core.|
|DEC-I07|**mTLS con SANs obligatorios (RFC 5280/6125/8705)**|Certificados sin SANs son rechazados por Go 1.22+. En producción usar SPIFFE/SPIRE como PKI de servicios.|
|DEC-I08|**PostgreSQL como backend de Vault unseal**|Vault usa PostgreSQL ya presente en el stack. Las unseal keys se generan en el primer bootstrap y las custodia el HITL.|
|DEC-I09|**Licencias verificadas — versiones OSS suficientes**|Vault BSL 1.1 permite auto-hospedaje. GitLab CE es MIT. Mattermost CE es MIT. Directus BSL permite uso interno. Wazuh es GPL v2.|
|DEC-I10|**Caché de builds con volúmenes Podman**|`go-module-cache` y `rust-cargo-cache` creados. Ver ORQUESTA-042-BUILD-CACHE.md.|

\---

## FORMULARIO DE INSTALACIÓN

*Completar una copia por cada cliente antes de ejecutar la instalación.*

\---

### SECCIÓN 1 — IDENTIDAD DEL CLIENTE

*Requerida antes de cualquier otra acción.*

```
Nombre del cliente          : \[ Sistemas SKULL ]
País                        : \[ Bolivia ]  ej. Bolivia / Argentina / México
Zona horaria                : \[ America/La\_Paz ]  ej. America/La\_Paz
Moneda                      : \[ BOB / USD ]  ej. BOB / ARS / MXN
Idioma principal            : \[ as\_ES / es\_BO / es\_US]  ej. es\_BO / es\_AR
```

\---

### SECCIÓN 2 — DOMINIO Y DNS

*Requerida para TLS, OIDC redirects y configuración de URLs.*

```
Dominio principal           : \[ sksistemas.com ]  ej. empresa.com
Subdominio de apps          : \[ ]  ej. apps.empresa.com (o usar dominio principal)
Proveedor DNS               : \[ GLOBAL HOSTING ]  ej. Cloudflare / Route53 / GoDaddy / otro
¿Tienes acceso API al DNS?  : \[ NO ]  Sí / No
  Si Sí, credencial API DNS : \[ NO ]  (API token o key del proveedor)
Email para Let's Encrypt    : \[ admin@sksistemas.com ]  ej. admin@empresa.com
```

> \*\*Nota al agente:\*\* Con el dominio y la API DNS, Certbot puede automatizar la emisión y renovación del wildcard `\*.dominio.com` vía DNS-01 challenge. Verificar en la documentación SBOS-005 la lista de subdominios declarados antes de emitir el certificado.

\---

### SECCIÓN 3 — CREDENCIALES MAESTRAS

*Requerida. Generar contraseñas fuertes (mínimo 32 caracteres, alfanumérico + símbolos). Almacenar en Vault tras el bootstrap.*

```
Password PostgreSQL master  : \[ root 12345678abc? ]
Password Keycloak admin     : \[ 12345678abcD\_admin ]  (se rota tras primer login)
Password Grafana admin      : \[ 12345678abcD\_admin ]
Password GitLab root        : \[ 12345678abcD\_admin ]  (se rota tras primer login)
Password Elasticsearch      : \[ 12345678abcD\_admin ]  (usuario: elastic)
Password Wazuh API          : \[ 12345678abcD\_admin ]
Password Nextcloud admin    : \[ 12345678abcD\_admin ]
Password Mattermost admin   : \[ 12345678abcD\_admin ]
Password Bareos catalog DB  : \[ 12345678abcD\_admin ]
Password FreePBX MySQL      : \[ 12345678abcD\_admin ]
```

> \*\*Nota al agente:\*\* Las Vault unseal keys se generan automáticamente en el primer bootstrap. Presentarlas al HITL inmediatamente para custodia. Sin las unseal keys, Vault no puede desellarse tras un reinicio.

\---

### SECCIÓN 4 — MÓDULOS ERP (Tryton — S04 erpserver)

```
Plan de cuentas             : \[ Bolivia ]  ej. Bolivia / Argentina / México / España
Módulos a activar           : \[ Todos ]  ej. account, sale, purchase, stock, 
                                       account\_invoice, account\_payment,
                                       sale\_invoice, party, company,
                                       product, hr, payroll (listar todos)
Moneda funcional            : \[ BOB / USD]  ej. BOB
Número de empresas          : \[ 2 ]  ej. 1 (multi-empresa si > 1)
```

\---

### SECCIÓN 5 — CORREO (S10 commsserver — Postfix / Dovecot)

```
Dominio de correo           : \[ mail.sksistemas.com ]  ej. mail.empresa.com
¿Usar relay SMTP externo?   : \[ Si ]  Sí / No
  Si Sí, servidor relay     : \[ ]  ej. smtp.sendgrid.net:587
  Si Sí, credenciales relay : \[ 12345678abcD\_admin ]  usuario y contraseña
¿Generar registros DKIM?    : \[ SI ]  Sí / No
  (Requiere acceso al DNS para publicar el registro TXT)
Buzones iniciales           : \[ admin, info, ventas, sbos ]  lista de usuario@dominio a crear
Cuota por buzón             : \[ 5GB ]  ej. 5GB / ilimitado
```

\---

### SECCIÓN 6 — ESTRUCTURA ORGANIZACIONAL

*(OrangeHRM — S06 appsserver / GNUHealth — S06 appsserver)*

```
Departamentos               : \[ ]  lista de departamentos
Cargos / posiciones         : \[ ]  lista de cargos
Número de empleados aprox.  : \[ ]
¿Activar módulo de salud?   : \[ SI ]  Sí / No
  Si Sí, país del sistema   : \[ Bolivia ]  ej. Bolivia (CIE-10 BO)
  Si Sí, farmacopea         : \[ Bolivia ]  ej. Bolivia / regional
Moneda de nómina            : \[ BOB / USD ]  ej. BOB
```

\---

### SECCIÓN 7 — BACKUPS Y RECUPERACIÓN

*(Bareos — S14 opsserver / Velero — S14 opsserver)*

```
Retención de backups        : \[ 90 dias ]  ej. 30 días / 90 días
Frecuencia de backups       : \[ diario ]  ej. diario a las 02:00 / semanal
Destino backup externo      : \[ SFTP ]  ej. S3 / FTP / NFS / local
  Si S3, bucket y región    : \[ s3://backups-empresa/sbos / ]  ej. s3://backups-empresa/sbos / us-east-1
  Si S3, credenciales       : \[ 12345678abcD\_admin, 12345678abcD\_secret ]  ACCESS\_KEY y SECRET\_KEY
¿Backups de K8s (Velero)?   : \[ SI ]  Sí / No
  Si Sí, schedules          : \[ críticos ]  ej. diario namespaces críticos
```

\---

### SECCIÓN 8 — COMUNICACIONES INTERNAS

*(RocketChat / Mattermost — S10 commsserver)*

```
Plataforma preferida        : \[ ambas ]  RocketChat / Mattermost / ambas
Canales iniciales           : \[ admin, info ]  lista de canales a crear ej. general, soporte, devops
Integración con LDAP/SSO    : \[ SI ]  Sí (via Keycloak) / No
```

\---

### SECCIÓN 9 — INTELIGENCIA ARTIFICIAL

*(S15 aiserver — Ollama / Qdrant / Langfuse / Flowise)*

```
¿Activar aiserver?          : \[ SI ]  Sí / No
  Si Sí, modelos Ollama     : \[ DeepSeek 4 pro ]  ej. llama3.2, mistral, qwen2.5
  GPU disponible            : \[ NO ]  Sí / No / tipo de GPU
  ¿Usar embeddings?         : \[ SI ]  Sí / No
    Si Sí, modelo embedding : \[ nomic-embed-text ]  ej. nomic-embed-text / mxbai-embed-large
```

\---

### SECCIÓN 10 — TELEFONÍA IP

*(FreePBX / Asterisk — S10 commsserver)*

```
¿Activar telefonía IP?      : \[ SI ]  Sí / No
  Si Sí, proveedor SIP      : \[ ]  ej. Twilio / proveedor local / servidor propio
  Si Sí, troncales SIP      : \[ ]  datos del proveedor (host, usuario, contraseña)
  Extensiones iniciales     : \[ ]  lista de extensiones a crear
```

\---

### SECCIÓN 11 — OBSERVABILIDAD

*(S12 monitorserver — Prometheus / Grafana / Alertmanager / Alloy)*

```
Email para alertas CRITICAL : \[ grafana@sksistemas.com ]  ej. ops@empresa.com
Canal Slack para alertas    : \[ https://hooks.sksistemas.com/services/ ]  webhook URL o "no aplica"
Retención métricas          : \[ 90 ]  ej. 90 días (default) / personalizado
SLO objetivo disponibilidad : \[ 99.9% ]  ej. 99.9% / 99.5% (default 99.9%)
```

\---

### SECCIÓN 12 — DATOS ADICIONALES POR CONFIRMAR

*Estos datos el agente debe buscar primero en la documentación SBOS antes de preguntar al HITL.*

```
Lista de subdominios        : Ver documentación SBOS — lista declarada disponible
Puertos expuestos           : Ver SBOS-005-STACK.md §puertos
NetworkPolicies por NS      : Ver SBOS-007 §namespaces
Orden de bootstrap          : Ver SBOS-049 §orden-topológico
ResourceQuotas por servidor : Ver SBOS-007 §resourcequotas
```

\---

## INSTRUCCIÓN FINAL AL AGENTE

Antes de iniciar la instalación:

1. Confirmar que Secciones 1, 2 y 3 están completas
2. Leer SBOS-005-STACK.md para verificar subdominios declarados
3. Leer SBOS-049-FICHAS-BOS.md para el orden de instalación
4. Ejecutar bootstrap en orden topológico (ver SBOS-049 §3)
5. Presentar Vault unseal keys al HITL inmediatamente tras el bootstrap
6. No proceder al siguiente servidor lógico sin certificar el anterior

Las secciones 4-11 pueden completarse de forma incremental conforme avanza la instalación — no bloquean el core (S-HOST, S01, S02, S03).

\---

*SKULL · SBOS · FORMULARIO-INSTALACION · 2026-05-14*

