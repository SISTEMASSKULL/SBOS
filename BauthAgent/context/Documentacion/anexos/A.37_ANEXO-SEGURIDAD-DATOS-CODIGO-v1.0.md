# Anexo A.37 — Seguridad de datos en código: cifrado en tránsito real, cifrado en reposo por verificar
## Documento de respaldo de sustentación (tipo D+B)

**Versión:** 1.0.0 · **Fecha:** 2026-07-11 · **Respalda a:** MANUAL-SEGURIDAD-DATOS (2.10) · A.15 (crypto) · A.02 §B2 (PII)
**Verificación de código:** `jwe_encrypt.rs` (AES-GCM) + `credential.rs` + `zone_data_policy` en DDL — leída 2026-07-11
**Normas:** FIPS 197 (AES) · RGPD Art. 32 · NIST 800-122 (PII) · ISO 27701

## 1. El estado real
| Capacidad | Estado |
|---|---|
| **Cifrado en tránsito** (JWE A256GCM) | ✅ `jwe_encrypt.rs` (19 usos de cifrado, AES-GCM) — real |
| **Argon2id** (contraseñas) | ✅ (A.15) |
| `zone_data_policy` (PII/PHI/GDPR/masking/retención por zona) | ✅ DDL (10 menciones) |
| **Cifrado en reposo de credenciales** | ⚠️ `credential.rs` sin `encrypt` propio (0) — depende de la bóveda (Vault) + hashes; verificar |
| Enmascaramiento PII | ⚠️ diseño (2.10 §5); implementación por verificar |

## 2. Lo que FALTA — específico
| # | Brecha | Exigencia | Prioridad |
|---|---|---|:---:|
| SD1 | **Verificar cifrado en reposo** — que la PII/campos sensibles se cifran de verdad (hoy: hashes + referencias a bóveda; confirmar cobertura) | RGPD Art. 32 · FIPS 197 | P1 |
| SD2 | **Enmascaramiento PII implementado** (birth_date, national_id, card_number — A.02 §20) vs solo declarado | 2.10 §5 · NIST 800-122 | P2 |
| SD3 | `zone_data_policy` poblada con datos reales por zona | RGPD · ISO 27701 | P2 |
| SD4 | Field-level encryption / tokenización (brecha declarada 2.10 §10) | Estado del arte 2026 | P3 |

## 3. Verificación de completitud
Cifrado en tránsito ✅ (JWE real) · en reposo ⚠️ (SD1 — hashes+bóveda, verificar cobertura) · enmascaramiento ⚠️ (SD2). Coherente con 2.10 §10 ("lidera en soberanía, brechas en profundidad criptográfica").

**Industria:** [RGPD Art. 32](https://gdpr-info.eu/art-32-gdpr/) · [NIST 800-122](https://csrc.nist.gov/publications/detail/sp/800/122/final) · FIPS 197

| Ver. | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-11 | Seguridad de datos: cifrado en tránsito real (JWE A256GCM, jwe_encrypt.rs), Argon2id, zone_data_policy en DDL; brechas SD1 verificar cifrado en reposo (credential.rs sin encrypt propio — hashes+bóveda), SD2 enmascaramiento PII implementado vs declarado, SD3 zone_data_policy poblada, SD4 field-level/tokenización. |
