# ADR-025 — Solo Licencias OSI-Approved

**Estado:** Aceptado  
**Fecha:** 2026-06-13  
**Origen:** §18 Regla 3 + §16 Ficha (campo `license`) del Master v2.1  
**Relacionado:** ADR-022 (soberanía), SBOS-050 (port catalog)

---

## Contexto y problema

El SBOS es un sistema soberano: los datos del cliente no salen y el código puede auditarse completamente. Si una dependencia usa una licencia restrictiva (BSL, Commons Clause, Sustainable Use License), el cliente puede perder el derecho a usar o modificar el software en producción sin pagar regalías a un tercero. Esto viola directamente la promesa de soberanía del SBOS.

## La Decisión

**Todo componente del ecosistema SBOS — código fuente, fichas, dependencias — debe usar exclusivamente licencias OSI-approved.**

```
PERMITIDO (licencias OSI-approved):
  ✅ MIT
  ✅ Apache 2.0
  ✅ GPL v2 / v3
  ✅ LGPL v2.1 / v3
  ✅ MPL 2.0 (Mozilla Public License)
  ✅ BSD 2-Clause / 3-Clause
  ✅ AGPL v3
  ✅ ISC
  ✅ EUPL v1.2

VETADO — licencias de source-available o con restricciones comerciales:
  ❌ Business Source License (BSL) — Redis 7.4+, MariaDB 10.x
  ❌ Commons Clause
  ❌ Sustainable Use License
  ❌ Server Side Public License (SSPL) — MongoDB
  ❌ Elastic License 2.0 (ELv2)
  ❌ Licencias propietarias sin fuente
```

## Aplicación en Fichas

El campo `license` en `manifest.yml` es obligatorio (§16):
```yaml
license: "Apache-2.0"   # ✅ OSI-approved
# license: "BSL-1.1"   # ❌ Bibliotecario rechaza
```

El Bibliotecario ejecuta `license-checker` como gate de CI. Una ficha con licencia no aprobada nunca llega a producción.

## Consecuencias

**Positivas:**
- El cliente puede auditar y modificar todo el stack sin restricciones legales
- Ningún vendor puede revocar el derecho de uso en producción
- Alineado con el principio de soberanía del SBOS

**Negativas/Riesgos:**
- Redis 8.6.2 es la última versión con licencia OSI-approved (LGPL). Redis 7.4+ usa RSAL
  - Mitigación: usar Redis 8.6.2 fijado (ADR-017). La versión exacta 8.6.2 mantiene LGPL.
- Algunas herramientas de observabilidad tienen ediciones enterprise con licencia restrictiva
  - Mitigación: usar solo la edición community (Grafana OSS, Prometheus, Loki)

## Normas relacionadas

- SBOS-016-FICHA §`license` (obligatorio en manifest.yml)
- OSI Approved Licenses List (https://opensource.org/licenses)
- ADR-029 (Podman/OCI — ambos Apache 2.0)
