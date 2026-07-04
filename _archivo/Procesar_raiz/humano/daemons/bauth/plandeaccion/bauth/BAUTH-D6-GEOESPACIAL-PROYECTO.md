# BAUTH-D6-GEOESPACIAL-PROYECTO.md — Dominio Geoespacial

**Versión:** 2.0 · **Fecha:** 2026-06-24 · **Autor:** sbos-coordinador
**Dominio:** D6 — Geoespacial · **Tipo:** External-Path · **Orden evaluación:** 7°

---

## 1. DIAGNÓSTICO

| Métrica | Valor |
|---------|------|
| Tablas existentes D6 | 2 (`bglobal.global_country`, `bglobal.geo_timezone`) |
| Funcionalidad geoespacial backend | 0% — solo catálogos estáticos |
| Funcionalidad geoespacial frontend | 0% — no hay widget de mapa para capturar coordenadas |
| Campos espaciales en DDL sin herramienta de captura | 3 (`geo_timezone.coordinates`, `fis_location.coordinates`, `geo_fence_radius_m`) |
| Evaluación runtime | ❌ No existe |
| Ficha de infraestructura | ❌ No desplegada |

---

## 2. SOLUCIÓN DE DOS CAPAS

El problema geoespacial no se resuelve con una sola herramienta. Requiere dos capas
complementarias que cubren momentos distintos del ciclo de vida del dato:

| Capa | Herramienta | Momento | Qué resuelve |
|------|------------|--------|-------------|
| **Backend** — Evaluación | **PostGIS** (extensión PostgreSQL) | Runtime, en cada request | point-in-polygon, distance, velocity check, country lookup |
| **Frontend** — Captura | **Flutter Map** (`flutter_map` + OpenStreetMap) | Configuración, cuando el admin define geo-fences y ubicaciones | seleccionar punto en mapa, dibujar polígonos, buscar dirección → coordenadas |

**Sin la capa frontend, PostGIS no tiene datos que evaluar.**
**Sin la capa backend, el mapa captura datos que nadie procesa.**

Ambas son necesarias. El problema es sistémico: aplica a TODA la base de datos.

---

## 3. BACKEND: PostGIS

### 3.1 Qué es

Extensión de PostgreSQL que agrega tipos geométricos (`POINT`, `POLYGON`), índices GiST,
y +300 funciones espaciales. Estándar OGC. Licencia GPL v2.0.

### 3.2 Por qué PostGIS

El PLAN-RECONSTRUCCION-DDL.md ya lo identificó (línea 393):

> *"Reemplazada por PostGIS point-in-polygon + API reverse geocoding.
> Las coordenadas (lat,lon) en las tablas de entidad resuelven ciudad en ~0.1ms sin catálogo manual."*

| Ventaja | Detalle |
|---------|------|
| Ya en el stack | PostgreSQL 18.4 desplegado. Solo requiere `CREATE EXTENSION postgis;` |
| Misma BD | Consultas geo usan las mismas tablas, mismos backups, mismas FKs |
| Rendimiento | GiST indexes, point-in-polygon <1ms, distance <0.5ms |
| Sin servicios externos | No requiere GeoServer, Google Maps API, ni APIs de geocoding |
| Madurez | 20+ años, estándar de facto en GIS |

### 3.3 Ficha de infraestructura requerida

```
servers/S01/postgis/manifest.yml
─────────────────────────────────
nombre: postgis
tipo: extension
servidor: S01
dependencias:
  - postgresql (ya instalado, ficha 100)
instalacion:
  - CREATE EXTENSION IF NOT EXISTS postgis;
  - CREATE EXTENSION IF NOT EXISTS postgis_topology;
verificacion:
  - SELECT PostGIS_Version();
```

**Estado:** 🔴 NO CREADA. Prerequisito para todo D6.

### 3.4 Funciones PostgreSQL requeridas

```sql
-- ¿Está el punto dentro del geo-fence de la sucursal?
bauth.geo_check_fence(lat, lon, sucursal_id) → BOOLEAN

-- ¿Es imposible el viaje entre el último login y esta ubicación?
bauth.geo_check_velocity(user_uuid, lat, lon, timestamp) → BOOLEAN

-- ¿Está el país en la lista de permitidos para este usuario?
bauth.geo_check_country(country_code, user_uuid) → BOOLEAN
```

---

## 4. FRONTEND: Flutter Map + OpenStreetMap

### 4.1 Qué es

`flutter_map` es un widget de mapa para Flutter que renderiza tiles de OpenStreetMap
(sin API key, gratuito, sin límites). Soporta:

| Funcionalidad | Uso en SBOS |
|--------------|------------|
| `TapCallback` → (lat, lon) | El admin toca un punto en el mapa → se guardan las coordenadas |
| `PolygonLayer` + draw | El admin dibuja el polígono del geo-fence de una sucursal |
| `CircleLayer` | Visualizar radio de geo-fence en metros |
| `MarkerLayer` | Mostrar sucursales, dispositivos, ubicaciones de login |
| Nominatim search | "Av. Camacho 1234, La Paz" → (lat, lon) automático |

### 4.2 Dependencias Flutter

```yaml
# pubspec.yaml del Core UI
dependencies:
  flutter_map: ^7.0.0         # Widget de mapa
  latlong2: ^0.9.1            # Tipos LatLng, Distance
  flutter_map_location_marker: ^9.0.0  # Marcador de ubicación actual
  geolocator: ^13.0.0         # Obtener ubicación GPS del dispositivo
```

**Licencia:** BSD/MIT — compatible con SBOS. **Costo:** $0. Sin API keys. Sin rate limits.

### 4.3 Por qué OpenStreetMap y no Google Maps

| Criterio | OpenStreetMap + flutter_map | Google Maps Flutter |
|----------|---------------------------|---------------------|
| **Costo** | $0 | $7 por 1000 requests |
| **API Key** | No requiere | Requiere billing account |
| **Offline** | Sí (tiles pre-cacheados) | No |
| **Draw polygon** | Sí | Limitado |
| **Soberanía** | ✅ Datos no salen del dispositivo | ❌ Cada request facturado por Google |
| **Licencia** | BSD/MIT | Propietaria |

---

## 5. ENFOQUE SISTÉMICO: TODA LA BASE DE DATOS

El problema no es solo D6. Cada tabla que almacena una ubicación geográfica
necesita un widget de captura. Sin eso, el dato espacial es inútil porque
nadie escribe coordenadas a mano.

### 5.1 Campos espaciales existentes en la DDL

| Tabla | Columna | Tipo | ¿Capturable? |
|-------|---------|------|:---:|
| `bglobal.geo_timezone` | `coordinates` | `POINT` | ❌ Sin widget |
| `bauth.fis_location` | `coordinates` | `POINT` | ❌ Sin widget |
| `bauth.fis_location` | `geo_fence_radius_m` | `INTEGER` | ❌ Sin widget |
| `bauth.org_sucursal` | `direccion` | `TEXT` | ❌ Sin geocoding |
| `bauth.org_sucursal` | `ciudad` | `TEXT` | ❌ Sin geocoding |

### 5.2 Campos espaciales nuevos requeridos

| Tabla | Columna | Tipo | Widget requerido |
|-------|---------|------|-----------------|
| `bauth.geo_fence` | `polygon` | `POLYGON` | Mapa + dibujo de polígono |
| `bauth.geo_location_log` | `point` | `POINT` | Automático (GPS/IP) |
| `bauth.geo_trust_tier` | — | `JSONB` | Formulario + selector de tier |

### 5.3 El `menu_context` como puente DDL ↔ UI

La solución sistémica es usar `menu_context` para marcar qué campos necesitan
widget de mapa. El Core UI lee `menu_context` y renderiza el widget correspondiente.

```
bglobal.menu_context:
──────────────────────────────────────────────────────
context_key          | entity_type       | widget
─────────────────────┼───────────────────┼────────────
geo.point.picker     | fis_location      | MAP_POINT_PICKER
geo.polygon.picker   | geo_fence         | MAP_POLYGON_PICKER
geo.radius.picker    | fis_location      | MAP_RADIUS_PICKER
geo.address.search   | org_sucursal      | MAP_ADDRESS_SEARCH
geo.coordinates.view | geo_timezone      | MAP_POINT_VIEWER
──────────────────────────────────────────────────────
```

El Core UI consulta `menu_context WHERE entity_type = '<tabla>'` y sabe exactamente
qué widget renderizar para cada campo de cada tabla. Sin lógica hardcodeada.

---

## 6. IMPACTO EN EL CONTEXT PLANE

### Antes (sin D6 funcional)

```json
{
  "user": "juan",
  "tenant": "empresa_a",
  "branch": "lapaz",
  "trust": "biometric",
  "permissions": ["inventory.read"]
}
```

### Después (con D6 completo — backend + frontend)

```json
{
  "user": "juan",
  "tenant": "empresa_a",
  "branch": "lapaz",
  "trust": "biometric",
  "location": {
    "country": "BO",
    "city": "La Paz",
    "geo_fence": "inside",
    "trust_tier": "HIGH",
    "velocity_ok": true
  },
  "permissions": ["inventory.read"]
}
```

---

## 7. PLAN DE IMPLEMENTACIÓN

| Fase | Tarea | Capa | Responsable | Dependencias |
|------|-------|------|------------|-------------|
| **G0** | Crear ficha `postgis` en `servers/S01/postgis/` | Backend infra | BOS | — |
| **G1** | Instalar PostGIS en VPS staging | Backend infra | BOS | G0 |
| **G2** | Agregar `flutter_map` + `latlong2` al Core UI | Frontend infra | BOS | — |
| **G3** | Crear 5 tablas D6 nuevas en DDL | Backend datos | bAuth | G1 |
| **G4** | Crear 3 funciones SQL (fence, velocity, country) | Backend lógica | bAuth | G1 |
| **G5** | Crear widget `MapPointPicker` en Core UI | Frontend widget | BOS | G2 |
| **G6** | Crear widget `MapPolygonDrawer` en Core UI | Frontend widget | BOS | G2 |
| **G7** | Poblar `menu_context` con entradas geo (5 entradas) | Backend datos | bAuth | G3 |
| **G8** | Crear seeds: geo_trust_tier + geo_fence | Backend datos | bAuth | G3 |
| **G9** | Integrar evaluación D6 en PrivilegeEngine | Backend lógica | bAuth | G4 |
| **G10** | Probar ciclo completo: admin dibuja geo-fence → usuario hace login → PostGIS evalúa | Integral | Operador | G1-G9 |

**Tiempo estimado:** 5-8 días (2-3 días PostGIS + funciones, 3-5 días widgets Flutter).

---

## 8. NOTA SOBRE GEOCODING INVERSO

Para resolver "Av. Camacho 1234, La Paz" → (-16.5000, -68.1500):

| Opción | Ventaja | Desventaja | Recomendada |
|--------|---------|-----------|:---:|
| **Nominatim (OSM)** | Gratuito, sin API key, integrado con flutter_map | Rate limit: 1 req/s | ✅ Fase 1 |
| **PostGIS + shapefiles** | Offline, sin límites | Shapefiles ~500MB, mantenimiento | Fase 2 |
| **Google Geocoding** | Precisión | $5 por 1000, requiere API key | ❌ |

---

*Documento v2.0 generado 2026-06-24. Solución de dos capas: PostGIS (backend) + Flutter Map (frontend).*
*Enfoque sistémico: menu_context como puente DDL↔UI para TODOS los campos espaciales.*
