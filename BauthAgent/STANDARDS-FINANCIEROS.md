# SBOS — Estándares Financieros y Monetarios

## REGLA ABSOLUTA — Precisión decimal mínima

**Todos los valores monetarios y financieros en el ecosistema SBOS DEBEN
almacenarse, transmitirse y procesarse con 13 decimales de precisión
(ISO 20022 ActiveCurrencyAnd13DecimalAmount). Nunca se debe redondear
un valor monetario.**

### Fundamento en estándares internacionales

| Fuente | Precisión | Detalle |
|--------|-----------|---------|
| **ISO 20022 `ActiveCurrencyAnd13DecimalAmount`** | **13 decimales** | Estándar bancario global para alta precisión. totalDigits=18, fractionDigits=13. |
| **ISO 20022 `ActiveCurrencyAndAmount`** | 5 decimales | Estándar bancario básico. Insuficiente para SBOS. |
| **ERC-20 (Ethereum)** | **18 decimales** | Estándar cripto dominante. 1 ETH = 10^18 wei. Recommended default. |
| **Bitcoin** | 8 decimales | 1 BTC = 10^8 satoshis. |
| **USDC/USDT** | 6 decimales | Stablecoins principales. |
| **ISO 4217** | Variable (0-4) | Códigos de moneda fiat. JPY=0, BHD=3. No es límite de precisión — es unidad mínima de cuenta. |

### Decisión SBOS: 13 decimales mínimo, 18 recomendado

- **Mínimo obligatorio:** 13 decimales (ISO 20022 high-precision).
- **Recomendado:** 18 decimales (ERC-20 estándar, permite interoperabilidad cripto sin pérdida).
- **Nunca redondear:** toda operación financiera preserva la precisión original.
- **PostgreSQL:** usar tipo `NUMERIC(36,18)` para montos financieros.
- **JSONB params:** todo monto se escribe con 13+ decimales explícitos.

### Aplicación en SBOS

1. **`policy_data.params` JSONB**: montos con 13+ decimales
   ```json
   {"single_limit_bob": "10000.0000000000000", "daily_limit_bob": "50000.0000000000000"}
   ```

2. **Código Rust**: validación contra `serde_json::Number` (preserva precisión original del string JSON)

3. **JWT claims**: montos serializados con precisión exacta

### Verificación

```rust
// ✅ correcto — 13 decimales (ISO 20022 high-precision)
FinancialEvaluator::validate_amount_precision(&serde_json::json!(10000.0000000000000))

// ❌ prohibido — solo 2 decimales
FinancialEvaluator::validate_amount_precision(&serde_json::json!(100.50))
```

### Referencias normativas

- ISO 20022 Message Definition Report — ActiveCurrencyAnd13DecimalAmount
- EIP-20 Token Standard — decimals field (18 default)
- FATF Recommendation 16 (Jun 2025) — Travel Rule precision
- PCI-DSS 4.0.1 §7 — Access control data integrity
- ISO/IEC 27001:2022 A.8.10 — Information integrity
- NIST SP 800-53 SI-10 — Information input validation

### Sanción

Código que redondee, trunque, o use menos de 13 decimales en montos
financieros será rechazado en CI por el Bibliotecario.
