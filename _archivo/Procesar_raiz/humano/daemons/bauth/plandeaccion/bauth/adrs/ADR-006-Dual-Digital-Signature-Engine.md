# ADR-006 — Doble Motor de Firma Digital: Interno (Vault PKI) + Externo (ADSIB/SIN)

**Estado:** Aceptado · **Fecha:** 2026-06-20

---

## Contexto

El SBOS requiere firma digital para dos propósitos fundamentalmente distintos:

1. **Documentos internos** (sagas, estados, eventos CDC, logs, contratos entre tenants): requieren velocidad, automatización, y gestión interna de certificados. No necesitan validez legal externa.
2. **Documentos externos** (facturación electrónica SIN, contratos con proveedores, declaraciones juradas): requieren validez legal plena según Ley 164 de Bolivia, certificados emitidos por ADSIB, y cumplimiento con la PKI nacional (ATT → ADSIB).

Un solo motor no puede satisfacer ambos requisitos — la PKI interna usa EdDSA (rápido, moderno) mientras que ADSIB exige RSA-SHA256 (legado regulatorio).

## Decisión

**Dos motores de firma digital independientes:**

| Característica | Motor Interno | Motor Externo |
|---------------|--------------|---------------|
| Autoridad | Vault PKI (SBOS Root CA) | ATT → ADSIB |
| Algoritmo | EdDSA Ed25519 | RSA-SHA256 |
| Vigencia certificado | 24h (M2M) – 365d (Apps) | 365d |
| Validez legal externa | No | Sí (Ley 164) |
| Formatos | PAdES, XAdES, CAdES, JWS | XAdES (SIN), PAdES |
| Consumidores | bos-agent, bkernel, biedata | SmartTax, Admin Tenant |

## Alternativas

| Alternativa | Problema |
|------------|---------|
| Motor único con ADSIB para todo | Lentitud (RSA), costo (certificados ADSIB por daemon), innecesario para firmas internas |
| Motor único con PKI interna para todo | Sin validez legal externa. SIN rechazaría facturas. |
| Delegar firma externa a cada tenant | Complejidad: cada tenant gestiona sus propios certificados ADSIB. bAuth centraliza. |

## Consecuencias

- Separación clara de responsabilidades: interno = ecosistema, externo = mundo real
- Cumplimiento Ley 164 Bolivia (Art. 78-83): firma ADSIB tiene plena validez jurídica
- Gestión centralizada de certificados ADSIB en Vault KV v2

## Referencias
- SBOS-BAUTH-DIGITAL-SIGNATURE-ENGINES.md v1.0
- Ley 164 Bolivia (Ley General de Telecomunicaciones)
- DS 1793/3527 (Reglamento TIC + Firma Digital Automática)
- ADSIB-FD-POLT-015 v2.3
