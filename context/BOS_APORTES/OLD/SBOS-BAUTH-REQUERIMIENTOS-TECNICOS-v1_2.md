# SBOS-BAUTH-REQUERIMIENTOS-TECNICOS-v1_2.md

## Requerimientos Técnicos, de Software e Infraestructura para bAuth v4.0

**Documento:** SBOS-BAUTH-REQUERIMIENTOS-TECNICOS-v1_2  
**Versión:** 1.2  
**Fecha:** Abril 2026  
**Estado:** BORRADOR PARA REVISIÓN  
**Referencia:** SBOS-BAUTH-CONCEPTUALIZACION-v4_0.md | SBOS-PLAN-ACTUALIZACION-CONSOLIDADO-v3_0.md  
**Cambios v1.2:** Memoria ajustada a escala realista, arquitectura escalable por concurrencia, análisis de Contabo VPS

---

## 1. ANÁLISIS DE MEMORIA POR CONCURRENCIA (REALISTA)

### 1.1 ¿Por qué la memoria NO debe ser "tan alta" al inicio?

Los requerimientos anteriores estaban sobredimensionados para "enterprise" sin considerar el escalado gradual. Aquí el análisis realista:

#### Cálculo de memoria por componente (base + por usuario concurrente)

| Componente | Memoria Base | Memoria por Usuario Concurrente | Fórmula |
|------------|-------------|--------------------------------|---------|
| **PostgreSQL 18** | 512 MB | ~2 MB | `base + (concurrentes × 2MB)` |
| **Keycloak 26** | 1 GB (JVM heap) | ~5 MB | `1GB + (concurrentes × 5MB)` [^37^] |
| **Redis** | 64 MB | ~50 KB (SAM-128 cache) | `64MB + (usuarios × 50KB)` |
| **Tryton** | 256 MB | ~3 MB | `256MB + (concurrentes × 3MB)` |
| **bAuth (Go)** | 64 MB | ~0.5 MB | `64MB + (concurrentes × 0.5MB)` |
| **Nginx + Sistema** | 512 MB | - | Fijo |
| **TOTAL** | **~2.5 GB** | **~10.5 MB/usuario** | - |

#### Ejemplos por escala:

| Escenario | Usuarios Concurrentes | Memoria Calculada | VPS Recomendado | Costo/mes (Contabo) |
|-----------|----------------------|-------------------|-----------------|---------------------|
| **Desarrollo** | 1-5 | 2.5 - 3 GB | 4 vCPU / 8 GB | €4.50 ($5) [^36^] |
| **Staging** | 10-20 | 3.5 - 4.5 GB | 6 vCPU / 12 GB | €6.80 ($7.50) [^37^] |
| **Producción Small** | 50-100 | 8 - 13 GB | 8 vCPU / 24 GB | €13.70 ($15) [^37^] |
| **Producción Medium** | 200-500 | 25 - 50 GB | 12 vCPU / 48 GB | €24.40 ($27) [^37^] |
| **Producción Large** | 1000+ | 50+ GB | 16 vCPU / 96 GB | €47.70 ($52) [^37^] |

**Conclusión:** Para inicio (desarrollo/staging), **8 GB RAM es suficiente** [^36^]. No se necesitan 32 GB hasta alcanzar 500+ usuarios concurrentes.

---

## 2. ARQUITECTURA VPS CONTABO (RECOMENDADA)

### 2.1 ¿Por qué Contabo?

Según análisis 2026, Contabo ofrece **la mejor relación recursos/precio** del mercado:

| Plan | vCPU | RAM | NVMe | Precio | Ratio RAM/€ |
|------|------|-----|------|--------|-------------|
| **VPS 10** | 4 | 8 GB | 75 GB | €4.50 | 1.78 GB/€ [^36^] |
| **VPS 20** | 6 | 12 GB | 100 GB | €6.80 | 1.76 GB/€ [^37^] |
| **VPS 30** | 8 | 24 GB | 200 GB | €13.70 | 1.75 GB/€ [^37^] |
| DigitalOcean | 4 | 8 GB | 160 GB | ~$48 | 0.17 GB/$ [^37^] |
| AWS EC2 | 4 | 8 GB | EBS | ~$140 | 0.06 GB/$ [^37^] |

**Contabo es ~10x más barato** que DigitalOcean/Vultr para recursos equivalentes [^37^]. La compensación: performance de CPU ligeramente inferior (aceptable para SBOS) [^40^].

### 2.2 Plan de Escalado Gradual (Contabo)

```
FASE 1: Desarrollo (Mes 1-3)
├── VPS: Contabo Cloud VPS 10 (4 vCPU / 8 GB / 75 GB NVMe)
├── Costo: €4.50/mes (~$5)
├── Carga: 5-10 usuarios concurrentes
├── Redis: Single node (mismo VPS)
├── PostgreSQL: Single instance (mismo VPS)
└── Backup: Dump diario a S3/MinIO

FASE 2: Staging/Early Production (Mes 4-6)
├── VPS: Contabo Cloud VPS 20 (6 vCPU / 12 GB / 100 GB NVMe)
├── Costo: €6.80/mes (~$7.50)
├── Carga: 20-50 usuarios concurrentes
├── Redis: Master-Slave (2 VPS si crítico)
├── PostgreSQL: Primary + Replica (2 VPS)
└── Backup: WAL archiving + PITR

FASE 3: Producción Scale (Mes 7-12)
├── VPS: Contabo Cloud VPS 30 (8 vCPU / 24 GB / 200 GB NVMe)
├── Costo: €13.70/mes (~$15)
├── Carga: 100-200 usuarios concurrentes
├── Redis: Single node optimizado (suficiente hasta 500 usuarios)
├── PostgreSQL: Primary + Réplica + Backups
└── HA: Evaluar según SLA requerido

FASE 4: Enterprise (Opcional, Mes 12+)
├── VPS: Cloud VPS 60 (18 vCPU / 96 GB / 350 GB NVMe)
├── Costo: €47.70/mes (~$52)
├── Carga: 500-1000+ usuarios concurrentes
├── Redis: Cluster 3 nodos (solo si > 500 usuarios activos)
├── PostgreSQL: Patroni cluster 3 nodos
└── Load Balancer: HAProxy/Nginx Plus
```

---

## 3. ARQUITECTURA DE REDIS: SINGLE NODE VS CLUSTER

### 3.1 Análisis: ¿Por qué 3 nodos para Cluster?

El **Redis Cluster** requiere mínimo **3 nodos master** (sin réplicas) por diseño de consenso:

```
Redis Cluster usa gossip protocol y requiere mayoría de nodos:
- 3 nodos: tolera 1 fallo (2/3 = mayoría) ✓
- 2 nodos: split-brain imposible de resolver (1/2 vs 1/2) ✗
- 1 nodo: no es cluster, es single instance
```

**PERO:** Esto solo aplica si necesitas **Cluster mode** (sharding automático de datos entre múltiples nodos).

### 3.2 Decisión Arquitectónica para SBOS

| Escenario | Arquitectura Redis | Justificación | Costo Extra |
|-----------|-------------------|---------------|-------------|
| **Fase 1-2** | Single node (mismo VPS) | Hasta 500 usuarios activos, dataset < 2GB | €0 |
| **Fase 3** | Single node optimizado + backup | Hasta 1000 usuarios, dataset < 4GB | €0 |
| **Fase 4 (opcional)** | Cluster 3 nodos | > 1000 usuarios concurrentes O dataset > 10GB | +€13-27 |

**Recomendación SBOS:** Single node es suficiente para 90% de despliegues. El caché de SAM-128 es muy eficiente (~50 KB por usuario) [^43^].

### 3.3 Configuración Redis Single Node (Optimizada)

```ini
# /etc/redis/redis.conf - Optimizado para SBOS en VPS 8-12 GB

# Memoria: 20% de RAM total del VPS (ej: 1.6GB en VPS 8GB)
maxmemory 1600mb
maxmemory-policy allkeys-lru

# Evitar OOM en caso de spike
maxmemory-samples 10

# Persistencia mixta (RDB rápido + AOF seguro)
save 900 1
save 300 10
save 60 10000
appendonly yes
appendfsync everysec
no-appendfsync-on-rewrite yes

# Seguridad: solo localhost y VLAN interna
bind 127.0.0.1 10.0.100.10
protected-mode yes
requirepass ${REDIS_PASSWORD_FROM_VAULT}

# Optimizaciones para cache de objetos pequeños (SAM-128)
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64

# Límites de conexiones (suficiente para bAuth)
maxclients 10000
timeout 300
tcp-keepalive 300

# Logging
loglevel notice
logfile /var/log/redis/redis-server.log

# Desactivar features no necesarias para ahorrar memoria
tcp-backlog 511
daemonize yes
supervised systemd
```

**Uso de memoria Redis estimado:**
- 1000 usuarios × 50 KB (SAM-128 + contexto) = ~50 MB
- Overhead Redis (~30%) = ~15 MB
- Buffer operaciones = ~100 MB
- **Total: ~165 MB para 1000 usuarios** [^43^][^44^]

---

## 4. STACK TECNOLÓGICO Y ESCALADO

### 4.1 Componentes por Fase (VPS Contabo)

| Fase | VPS Plan | Componentes | Memoria Asignada |
|------|----------|-------------|-----------------|
| **Fase 1** | VPS 10 (8 GB) | Todo en uno | PG:2GB, KC:2GB, Redis:1GB, Tryton:1GB, bAuth:0.5GB, Sistema:1.5GB |
| **Fase 2** | VPS 20 (12 GB) | Todo en uno + swap | PG:3GB, KC:3GB, Redis:1.5GB, Tryton:1.5GB, bAuth:1GB, Sistema:2GB |
| **Fase 3** | VPS 30 (24 GB) | Todo en uno optimizado | PG:6GB, KC:6GB, Redis:2GB, Tryton:3GB, bAuth:2GB, Sistema:5GB |
| **Fase 4** | VPS 60 (96 GB) | Separación por servicio | Cada servicio en contenedor/VM dedicada |

### 4.2 Escalado Horizontal (cuando se necesite)

```yaml
# docker-compose.yml - Escalado Fase 3+
version: '3.8'

services:
  bauth:
    image: sbos/bauth:1.0
    deploy:
      replicas: 2  # Escalar según carga
    resources:
      limits:
        memory: 1G

  keycloak:
    image: quay.io/keycloak/keycloak:26.4
    deploy:
      replicas: 2
    resources:
      limits:
        memory: 3G  # JVM heap limitado
    environment:
      - JAVA_OPTS=-Xms2g -Xmx3g -XX:+UseG1GC

  postgres:
    image: postgres:18
    deploy:
      replicas: 1  # Primary (réplica separada)
    resources:
      limits:
        memory: 6G

  redis:
    image: redis:7-alpine
    deploy:
      replicas: 1  # Single node suficiente
    resources:
      limits:
        memory: 2G
```

---

## 5. CHECKLIST DE VIABILIDAD POR FASE

### Fase 1: Desarrollo (VPS 10 - €4.50/mes)

- [ ] Contabo VPS 10 provisionado (4 vCPU / 8 GB / 75 GB NVMe)
- [ ] Ubuntu 24.04 LTS instalado
- [ ] PostgreSQL 18 configurado con `max_connections = 50`
- [ ] Redis single node (mismo VPS) con `maxmemory 1gb`
- [ ] Keycloak 26.4+ con JVM limitado a 2 GB (`-Xmx2g`)
- [ ] bAuth compilado y funcionando
- [ ] Backup automático diario (pg_dump + rclone a S3)

### Fase 2: Staging (VPS 20 - €6.80/mes)

- [ ] Upgrade a VPS 20 (6 vCPU / 12 GB / 100 GB NVMe)
- [ ] PostgreSQL: `max_connections = 100`, `shared_buffers = 3GB`
- [ ] Redis: `maxmemory 1.5gb`, política `allkeys-lru`
- [ ] Keycloak: JVM 3 GB, caché realms optimizado
- [ ] Monitoreo básico (Netdata o Prometheus + Grafana)
- [ ] WAL archiving habilitado

### Fase 3: Producción Small (VPS 30 - €13.70/mes)

- [ ] Upgrade a VPS 30 (8 vCPU / 24 GB / 200 GB NVMe)
- [ ] PostgreSQL: `max_connections = 200`, `shared_buffers = 6GB`
- [ ] Redis: `maxmemory 2gb`, evaluar si necesita nodo separado
- [ ] Keycloak: JVM 6 GB, cluster 2 nodos si alta disponibilidad requerida
- [ ] Load balancer (Nginx o HAProxy) si múltiples instancias
- [ ] Backups: PITR (Point-in-Time Recovery) configurado

### Fase 4: Enterprise (Opcional - VPS 60+ o múltiples VPS)

- [ ] Evaluación: ¿Realmente se necesita > 500 usuarios concurrentes?
- [ ] Si sí: Separar servicios en VPS dedicados o usar Kubernetes
- [ ] Redis Cluster 3 nodos **solo si** dataset > 10 GB o > 1000 usuarios activos
- [ ] PostgreSQL: Patroni cluster con 3 nodos
- [ ] bAuth: 3+ réplicas con load balancer

---

## 6. COMPARATIVA DE PROVEEDORES VPS (2026)

| Proveedor | Plan | vCPU | RAM | Precio | Notas |
|-----------|------|------|-----|--------|-------|
| **Contabo** | VPS 10 | 4 | 8 GB | €4.50 | Mejor precio, CPU aceptable [^36^] |
| **Contabo** | VPS 20 | 6 | 12 GB | €6.80 | "Bestseller" [^37^] |
| **Hetzner** | CX23 | 2 | 8 GB | €4.09 | Similar a Contabo [^40^] |
| **Hostinger** | KVM 1 | 1 | 4 GB | $5.84 | Menos recursos [^38^] |
| **DigitalOcean** | Basic | 1 | 1 GB | $4 | Mínimo, no suficiente [^37^] |
| **AWS** | t3.micro | 2 | 1 GB | ~$8 | Muy limitado |

**Recomendación:** Contabo VPS 10 para inicio, upgrade a VPS 20 cuando se alcancen 20+ usuarios concurrentes.

---

## 7. SOLUCIONES A GAPS (ACTUALIZADAS)

### Gap 5 Revisado: Redis - ¿Single node o Cluster?

**Respuesta corregida:**

| Escenario | Usuarios Concurrentes | Dataset Redis | Arquitectura | Costo |
|-----------|----------------------|---------------|--------------|-------|
| Desarrollo | < 10 | < 100 MB | Single node (mismo VPS) | €0 |
| Staging | 10-50 | 100 MB - 1 GB | Single node (mismo VPS) | €0 |
| Producción Small | 50-200 | 1-3 GB | Single node optimizado | €0 |
| Producción Medium | 200-500 | 3-8 GB | Single node + backup externo | €0 |
| Producción Large | 500-1000 | 8-15 GB | Evaluar Master-Slave | +€4.50 |
| Enterprise | 1000+ | > 15 GB | Cluster 3 nodos | +€9-18 |

**Conclusión:** Para SBOS v1.0, **single node Redis en el mismo VPS es suficiente**. No desperdiciar recursos en cluster hasta alcanzar 500+ usuarios activos.

---

## 8. HISTORIAL DE VERSIONES

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 1.0 | 2026-04-16 | Creación inicial |
| 1.1 | 2026-04-16 | PostgreSQL 18, VPS Ubuntu, soluciones a gaps |
| 1.2 | 2026-04-16 | Memoria ajustada por concurrencia, análisis Contabo, Redis single node por defecto |

---

*SKULL · SBOS · SBOS-BAUTH-REQUERIMIENTOS-TECNICOS-v1_2 · Abril 2026*
*Documento de requerimientos técnicos - Escalado por concurrencia, VPS Contabo optimizado*
