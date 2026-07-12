# Motor de Firma — *firmar documentos (validez legal)*

**Verbo:** firmar · **Frontera:** `src/domain/signature/` *(a consolidar)* · **Estado:** 🔄 interno ✅ / ADSIB ⬜ · **Rige:** ADR-013 · **Decisión:** ADR-006

---

## 1. Propósito
Punto **único** de firma de documentos con validez jurídica (Ley 164 Bolivia). **Doble motor:**
interno (bóveda PKI, EdDSA Ed25519) para firma soberana + externo (ADSIB/SIN, RSA-SHA256) para
validez legal reconocida. No confundir con la firma del **JWT** (esa es Emisión de Tokens, 2.03).

## 2. El contrato del motor
- **Producir:** `firmar_documento(doc, motor: Interno|Externo) → FirmaDigital{valor, cert, timestamp}`.
- **Verificar:** `verificar_firma_documento(doc, firma) → VeredictoFirma{valida, firmante, motivo}`.
- **Usa el Motor Criptográfico** para la primitiva (firmar/verificar bytes); este motor añade
  certificado, cadena, sello de tiempo (RFC 3161) y validez jurídica.
- **Fail-closed:** cert no verificable / cadena rota / revocado ⇒ inválida.

## 3. Los códigos que se juntan (frontera: `src/domain/signature/`)
| Archivo actual | Rol | Acción |
|----------------|-----|:------:|
| `jwt_signer.rs` (Ed25519 vía bóveda) | firma interna | reusar la primitiva (→ Motor Cripto) |
| **(falta)** motor externo ADSIB (RSA-SHA256) | firma legal Ley 164 | ⬜ **crear** |
| **(falta)** sello de tiempo (RFC 3161), verificación de cadena/OCSP | validez jurídica | ⬜ crear |

## 4. Manuales de referencia
- **2.04** Firma Digital — **madre** (doble motor, Ley 164, ADSIB) · **2.03** Tokens (firma de JWT — distinta).

## 5. Anexos y contratos
- **A.08** — firma: hallazgo crudo (interno Ed25519 REAL; **externo ADSIB NO existe en código**, F-C1 P1; Vault PKI por cablear, F-C2).
- **A.42 §7 (BA8)** — ficha `firmar_adsib` (Ley 164 / ETSI, firma + cuerpo).
- **ADR-006** — la decisión del doble motor.

## 6. Estado real (verificado en código)
- ✅ Firma **interna** Ed25519 real (`jwt_signer.rs` / `ring`).
- ⬜ Firma **externa** ADSIB (RSA-SHA256, Ley 164) — la pieza legal más compleja — **no existe**.
- 🔄 Clave interna en memoria (dev); Vault PKI por cablear.

## 7. Plan para completarlo
1. Consolidar `src/domain/signature/` con la fachada producir/verificar.
2. Implementar el motor **externo ADSIB** (BA8 — A.42 §7): RSA-SHA256, cert ADSIB, sello de tiempo.
3. Cablear la bóveda PKI (Vault) para la clave interna.
4. Apoyarse en el **Motor Criptográfico** para las primitivas (no `ring` directo).

*Portada de motor · ADR-013 · 2026-07-12*
