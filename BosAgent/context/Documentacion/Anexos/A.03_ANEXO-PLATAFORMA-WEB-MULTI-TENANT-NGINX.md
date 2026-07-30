# Anexo A.03 — Plataforma Web Multi-Tenant SBOS
## Arquitectura del servidor lógico S16-webserver: cómo UN nginx sirve sitios web dinámicos por tenant, empresa y sucursal con dominios propios

**Versión:** 3.0.0
**Fecha:** 2026-07-17
**Autor:** bos-developer — SBOS
**Código relacionado:** `servers/S16-webserver/nginx/` · `servers/S16-webserver/certbot/` · `servers/S16-webserver/modsecurity/` · `servers/S16-webserver/website-engine/` · Kong Plugin SBOS-Context (pendiente) · `bos.web.domain.*` JSON-RPC (pendiente)

---

## 1. Propósito

Este anexo define la arquitectura completa de la plataforma web multi-tenant del SBOS. Documenta
**por qué** se creó un servidor lógico dedicado (S16-webserver), **cómo** funciona el
enrutamiento por dominios personalizados, **cómo** escala horizontalmente sin fricción, y
**qué** debe implementar el BOS para que todo esto opere de forma declarativa y automática.

---

## 2. Decisión de arquitectura — S16-webserver como servidor lógico independiente

### 2.1 El problema que resolvió esta decisión

La plataforma web del SBOS requiere servir sitios web para potencialmente **miles de dominios
personalizados** (`www.miempresa.com`, `tienda.lapaz.com`, etc.), cada uno con su propio
certificado SSL, template dinámico, y carrito de compras independiente. Colocar esto en el
mismo servidor que Kong (API Gateway) y Vault (secretos) creaba tres problemas:

1. **Acoplamiento de responsabilidades** — S02-gatewayserver mezclaba tráfico de APIs
   (Kong, daemons, JSON-RPC) con tráfico web (páginas de negocio, carritos de compra)
2. **Migración forzada** — si el tráfico web crecía, había que migrar TODO S02 junto con
   Kong y Vault, cuando solo se necesitaba escalar la parte web
3. **Límite de ConfigMap de K8s** — cuando se alcanzan cientos de dominios, el `nginx.conf`
   generado se acerca al límite duro de 1MB de ConfigMap. Tener nginx separado permite que
   este límite afecte solo al servidor web, no al API gateway

### 2.2 La solución — S16-webserver

Se creó **S16-webserver** como servidor lógico independiente, separado de S02-gatewayserver.
Cada uno tiene su propia responsabilidad, su propio namespace K8s, y su propia unidad de
migración horizontal:

```
S02-gatewayserver (APIs + secretos):
  ├── kong/           ← API Gateway (rutas JSON-RPC, daemons, apps)
  ├── vault/          ← secretos, PKI, AppRole
  ├── besu-qbft/      ← nodo Blockchain
  └── bnexus/         ← proxy de hardware (bhnexus + banexus)

S16-webserver (Web + TLS):          ← NUEVO, independiente
  ├── nginx/          ← reverse proxy + TLS termination + virtual hosting
  ├── certbot/        ← certificados SSL por dominio (Let's Encrypt)
  ├── modsecurity/    ← WAF (Web Application Firewall)
  └── website-engine/ ← renderizado dinámico multi-tenant
```

### 2.3 Ventajas de la separación desde el día 1

| Ventaja | Explicación |
|---------|-------------|
| **Migración sin fricción** | `S16-webserver/` se lleva entero a un VPS dedicado cuando el tráfico web lo requiera. Kong y Vault permanecen donde están. |
| **Escalado independiente** | El Website Engine escala con HPA según tráfico de tiendas. Kong escala según tráfico de APIs. No compiten por recursos. |
| **Namespace separado** | `sbos-web` con su propio ResourceQuota, NetworkPolicy, y LimitRange. Sin interferencia con `sbos-gateway`. |
| **nodeSelector listo** | Los pods de S16 usan `nodeSelector: {tipo: webserver}`. Agregar un nodo K8s con ese label = los pods se reprograman solos. |
| **Límite de ConfigMap aislado** | Si el `nginx.conf` se acerca a 1MB, solo afecta al ingress de S16. Kong sigue funcionando. |
| **NetworkPolicy** | El tráfico web (Internet → nginx → website-engine) está aislado del tráfico de APIs (Kong → daemons). |

---

## 3. Cómo funciona — flujo completo de una petición web

```
1. Usuario escribe "www.miempresa.com" en el navegador
2. DNS del cliente → A record → IP del servidor SBOS
3. nginx (S16) recibe en :443, busca server_name www.miempresa.com
   → Encuentra /etc/nginx/conf.d/domains/www.miempresa.com.conf
4. nginx → TLS termination (certificado Let's Encrypt del dominio)
5. nginx → proxy_pass http://website-engine:3000/tenant/skull/empresa/empresa_a
   con headers: X-SBOS-Tenant, X-SBOS-Empresa, X-SBOS-Sucursal
6. Website Engine:
   a. Lee tenant=skull, empresa=empresa_a
   b. ¿Cookie __sbos_dctx? → valida ctx_id contra BOS :9443
   c. ¿Sin cookie? → crea dctx_id anónimo (bitmask=0x0) vía bos.ctx.device.register
   d. Consulta catálogo de productos de la sucursal
   e. Renderiza template dinámico con branding de la empresa
7. Website Engine → HTML → nginx → navegador
8. Si el usuario hace login → Keycloak → JWT → context.promoted → nuevo ctx_id con BitMask
```

**Kong NO está en este flujo.** El tráfico web va directo de nginx al Website Engine. Kong
solo interviene para tráfico de APIs (`api.sbos.app`) y daemons. Esto reduce latencia y
carga para las páginas web.

---

## 4. Tres tipos de web, un solo motor

```
WEB INSTITUCIONAL SBOS (dominio fijo):
  sbos.app, www.sbos.app
  → Template dinámico: landing page del SBOS.
    Si hay tenants: muestra enlaces a sus webs.
    Si no hay tenants: muestra "SBOS instalado — despliegue su primer tenant".

WEB DEL TENANT (dominio propio del cliente):
  www.grupo-skull.com
  → Agrupa totales de todas las empresas del tenant.
    Dashboard del tenant. Catálogo unificado.
    Template dinámico especializado por tenant.

WEB DE LA SUCURSAL (dominio propio del cliente):
  tienda.lapaz.skull.com, www.sucursalcbba.com
  → Carrito de compras independiente.
    Los totales se agregan automáticamente hacia arriba
    (sucursal → empresa → tenant) vía Redis Streams en tiempo real.
    Template dinámico especializado por empresa + sucursal.
```

**No hay subdominios automáticos de `sbos.app`.** El cliente decide sus dominios. El SBOS
solo provee la plataforma para servirlos.

---

## 5. Administración de dominios — el Domain Resolver

### 5.1 Tabla `bos.web_domains` (schema `bos`)

```sql
CREATE TABLE bos.web_domains (
    domain_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    domain          TEXT NOT NULL UNIQUE,
    tenant_id       TEXT NOT NULL,
    empresa_id      TEXT,          -- NULL = web del tenant
    sucursal_id     TEXT,          -- NULL = web del tenant o empresa
    is_active       BOOLEAN DEFAULT true,
    ssl_provisioned BOOLEAN DEFAULT false,
    ssl_expires_at  TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

### 5.2 Comandos del administrador

```bash
# Agregar dominio para el tenant
bosctl web domain add www.grupo-skull.com --tenant=skull

# Agregar dominio para una empresa
bosctl web domain add www.miempresa.com --tenant=skull --empresa=empresa_a

# Agregar dominio para una sucursal
bosctl web domain add tienda.lapaz.com --tenant=skull --empresa=empresa_a --sucursal=lpz

# Listar todos los dominios de un tenant
bosctl web domain list --tenant=skull

# Eliminar un dominio (revoca SSL, elimina config nginx)
bosctl web domain remove www.miempresa.com

# Verificar estado de SSL de todos los dominios
bosctl web domain ssl-status --tenant=skull
```

### 5.3 Qué hace el BOS al agregar un dominio

```
bosctl web domain add www.nueva-empresa.com --tenant=skull --empresa=nueva
    │
    ├─ 1. Valida que el tenant y empresa existen en SBOS_db
    ├─ 2. INSERT INTO bos.web_domains
    ├─ 3. Ejecuta certbot --nginx -d www.nueva-empresa.com
    │      → Obtiene certificado SSL de Let's Encrypt
    ├─ 4. Genera /etc/nginx/conf.d/domains/www.nueva-empresa.com.conf
    │      → Template con proxy_pass al Website Engine
    ├─ 5. nginx -s reload (graceful, sin downtime)
    ├─ 6. Registra audit_event en bos.ficha_event
    └─ 7. Responde: "Dominio listo. SSL activo. Configure DNS: A → <IP>"
```

### 5.4 Renovación automática de SSL

La ficha `certbot` (S16) ejecuta un systemd timer cada 12 horas:
```bash
certbot renew --quiet --nginx-deploy-hook "nginx -s reload"
```

Esto renueva automáticamente TODOS los certificados (el de `sbos.app` y los de cada dominio
personalizado) 30 días antes de que expiren. Sin intervención humana.

---

## 6. Configuración de nginx — archivos generados, no manuales

### 6.1 Estructura de archivos

```
/etc/nginx/conf.d/domains/
├── sbos-app.conf                    ← web institucional (siempre presente)
├── www.grupo-skull.com.conf         ← tenant SKULL
├── www.miempresa.com.conf           ← empresa A
├── tienda.lapaz.skull.com.conf     ← sucursal La Paz
├── www.sucursalcbba.com.conf       ← sucursal Cochabamba
└── ...                              ← uno por dominio registrado
```

### 6.2 Template de archivo de dominio (generado por BOS)

```nginx
# GENERADO POR BOS — NO EDITAR MANUALMENTE
# Dominio: www.miempresa.com
# Tenant: skull | Empresa: empresa_a | Sucursal: (ninguna)
# Creado: 2026-07-17T00:00:00Z | SSL: ACTIVO

server {
    listen 443 ssl http2;
    server_name www.miempresa.com;

    ssl_certificate     /etc/letsencrypt/live/www.miempresa.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/www.miempresa.com/privkey.pem;

    # WAF — ModSecurity
    modsecurity on;
    modsecurity_rules_file /etc/modsecurity/sbos-rules.conf;

    location / {
        proxy_pass http://website-engine.sbos-web:3000/tenant/skull/empresa/empresa_a;
        proxy_set_header Host $host;
        proxy_set_header X-Original-Domain $host;
        proxy_set_header X-SBOS-Tenant skull;
        proxy_set_header X-SBOS-Empresa empresa_a;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

### 6.3 Límite de ConfigMap y cuándo dispara la migración

Kubernetes tiene un límite duro de **1MB por ConfigMap**. Aproximadamente 800 dominios generan
~800KB de configuración. El BOS monitorea el tamaño del ConfigMap y alerta al 80%:

```bash
bosctl health-report
# → WARNING: S16-webserver ConfigMap al 78% (780KB/1MB)
# → Recomendación: planificar migración a nodo edge dedicado
```

Al alcanzar el umbral, se agrega un nodo K8s con `nodeSelector: {tipo: webserver}` o un VPS
dedicado. Los pods de S16 se reprograman solos. Sin tocar Kong, sin tocar Vault, sin tocar
la base de datos.

---

## 7. Escalado progresivo — del día 1 a 5000 tenants

### FASE ALPHA (1-5 tenants, ~20 dominios)
```
VPS única (11GB RAM, 6 CPU, 387GB disco)
├── S16-webserver: 1 pod nginx, 1 pod website-engine
├── Consumo estimado: ~1GB RAM, ~2 CPU
└── ConfigMap: ~20KB (< 2% del límite)
```
**Todo en la misma VPS. Sobrado de recursos.**

### FASE BETA (50 tenants, ~200 dominios)
```
VPS única — mismo hardware
├── S16-webserver: 1 pod nginx, 3 pods website-engine (HPA)
├── Consumo estimado: ~3GB RAM, ~4 CPU
└── ConfigMap: ~200KB (20% del límite)
```
**Misma VPS. BOS escala con `bosctl ficha scale website-engine --replicas=3`.**

### FASE GA (500 tenants, ~2000 dominios)
```
VPS original + NUEVA VPS edge
├── VPS 1 (datos): S00, S01, S03... (PG, Redis, bauth, daemons)
├── VPS 2 (edge): S16-webserver ENTERO
│   ├── nodeSelector: {tipo: webserver}
│   ├── nginx: 2 pods (HA)
│   └── website-engine: 10 pods (HPA por tenant)
└── ConfigMap: ~800KB (80% del límite — planificar siguiente split)
```
**Migración sin fricción: `bosctl ficha migrate nginx --to-node=webserver-01`. Saga con
compensación. Si falla, rollback automático.**

### FASE ENTERPRISE (5000+ tenants)
```
Múltiples VPS por región geográfica + CDN
├── VPS región 1: S16-webserver (tenants América)
├── VPS región 2: S16-webserver (tenants Europa)
├── CDN: Cloudflare para caché global de assets estáticos
└── Cada región es independiente — migración sin fricción entre regiones
```

### Tabla de crecimiento

| Fase | Tenants | Dominios | nginx pods | WE pods | RAM web | ConfigMap | Acción |
|------|:-------:|:--------:|:----------:|:-------:|:-------:|:---------:|--------|
| Alpha | 1-5 | ~20 | 1 | 1 | ~1 GB | 2% | Nada |
| Beta | 50 | ~200 | 1 | 3 | ~3 GB | 20% | HPA |
| GA | 500 | ~2000 | 2 (HA) | 10 | ~6 GB | 80% | VPS edge |
| Enterprise | 5000+ | 20000+ | 4+ | 50+ | 32+ GB | — | CDN + regiones |

---

## 8. Agregación automática de totales (carritos de compra)

Cada sucursal tiene su propio carrito independiente. Los totales se agregan hacia arriba en
**tiempo real** vía el CDC de bkernel:

```
SUCURSAL La Paz:
  tienda.lapaz.skull.com → venta por $15,000
  → PostgreSQL: INSERT INTO ventas
  → bkernel: CDC → Redis Stream bos:sucursal:lpz:venta

SUCURSAL Cochabamba:
  www.sucursalcbba.com → venta por $8,000
  → PostgreSQL: INSERT INTO ventas
  → bkernel: CDC → Redis Stream bos:sucursal:cbba:venta

EMPRESA (agrega automáticamente):
  Website Engine suscrito a Redis Stream bos:empresa:empresa_a:ventas
  Total empresa = $15,000 + $8,000 = $23,000
  → Se muestra en www.miempresa.com en tiempo real

TENANT (agrega automáticamente):
  Website Engine suscrito a Redis Stream bos:tenant:skull:ventas
  Total tenant = suma de todas las empresas
  → Se muestra en www.grupo-skull.com en tiempo real
```

**Sin batch nocturno. Sin ETL. Sin consolidación manual. Sin demora.**

---

## 9. Lo que el BOS debe implementar (requisitos para desarrollo)

### 9.1 Ficha nginx (S16-webserver)

- `task_catalog.sh` con funciones `nginx_install`, `nginx_verify`, `nginx_repair`
- Al instalar: crea estructura `/etc/nginx/conf.d/domains/`, genera `sbos-app.conf` (web institucional)
- `nginx_repair`: regenera configs desde `bos.web_domains`, reprovisiona SSL si falta
- Health check: `curl -sf https://localhost/nginx-health`

### 9.2 Ficha certbot (S16-webserver)

- `certbot_install`: instala certbot, crea systemd timer de renovación cada 12h
- `certbot_verify`: verifica que el timer está activo y los certificados no expiran en < 30 días
- Al agregar un dominio nuevo, BOS invoca `certbot --nginx -d <domain>`

### 9.3 Ficha modsecurity (S16-webserver)

- `modsecurity_install`: instala ModSecurity con ruleset OWASP Core Rule Set
- `modsecurity_verify`: verifica que el WAF está interceptando tráfico malicioso
- Reglas SBOS personalizadas: protección DDoS, rate limiting por IP, bloqueo de SQLi/XSS

### 9.4 Ficha website-engine (S16-webserver)

- `website-engine_install`: despliega el motor de renderizado (Go/Rust)
- `website-engine_verify`: verifica que responde en `/tenant/{tenant}/empresa/{empresa}`
- Recibe headers `X-SBOS-Tenant`, `X-SBOS-Empresa`, `X-SBOS-Sucursal` de nginx
- Consulta `bos.web.domain.resolve` para validar el dominio
- Renderiza templates dinámicos con branding del tenant/empresa
- Se suscribe a Redis Streams para totales en tiempo real

### 9.5 JSON-RPC `bos.web.domain.*` (servidor BOS)

```json
{
  "methods": [
    "bos.web.domain.add",
    "bos.web.domain.remove",
    "bos.web.domain.list",
    "bos.web.domain.resolve",
    "bos.web.domain.ssl_status"
  ]
}
```

- `add`: INSERT en `bos.web_domains` + certbot + genera nginx conf + reload
- `remove`: revoca SSL + elimina nginx conf + reload + DELETE en BD
- `resolve`: consulta O(1) por dominio → tenant/empresa/sucursal (usado por Kong y Website Engine)
- `ssl_status`: lista todos los dominios con fecha de expiración de SSL

### 9.6 CLI `bosctl web domain *`

- Subcomandos: `add`, `remove`, `list`, `ssl-status`
- `add`: modo interactivo (pregunta tenant, empresa, sucursal) y modo flag
- Salida JSON con `--json` para automatización

---

## 10. Historial de decisiones

| Fecha | Decisión | Motivo |
|-------|----------|--------|
| 2026-07-17 v1.0 | Dos nginx separados (S00 nginx-web + S02 nginx) | Herencia de la estructura original de servidores |
| 2026-07-17 v2.0 | Un solo nginx en S02, dominios personalizados | Corrección del humano: mismo nginx, dominios propios |
| 2026-07-17 v3.0 | **S16-webserver como servidor lógico independiente** | Investigación: límite de ConfigMap 1MB, separación de responsabilidades, migración sin fricción. La industria (Shopify, Wix) separa proxy web de API gateway. Mejor separar desde el día 1. |

---

## 11. Referencias

- [A.02 — Estructura Servidor Producción](A.02_ANEXO-ESTRUCTURA-SERVIDOR-PRODUCCION.md) — S16 agregado
- [ConfigMap 1MB limit (CRE-2025-0120)](http://docs.prequel.dev/cres/public/cre-2025-0120)
- [Nginx Ingress high-concurrency tuning](https://intl.cloud.tencent.com/document/product/457/38300)
- [Multi-tenant SaaS with nginx + custom domains](https://github.com/ColbyC/bash-nginxsetup)
- [Vercel for Platforms — custom domains at scale](https://vercel.com/platforms/docs)
- [Bare metal K8s capacity planning (2026)](https://developer.baidu.com/article/detail.html?id=3696933)

---

*SKULL · SBOS · BosAgent · Julio 2026*
