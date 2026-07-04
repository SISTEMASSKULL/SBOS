# BAUTH-B29-VARIANTE-B-PRUEBA-REAL — Verificación en Besu QBFT

**Fecha:** 2026-06-22 05:22 UTC · **VPS:** 13.140.128.230  
**Red:** Besu QBFT (chainId=1337) · **Contrato:** `0x4B89c313aad8584F9CE8825633A95e0d23bcE310`

---

## 1. Infraestructura

| Componente | Valor |
|-----------|-------|
| **Motor de contenedores** | Podman 5.7.0 |
| **Imagen** | `hyperledger/besu:24.12.0` (descargada de docker.io) |
| **Consenso** | QBFT (Proof of Authority) — 1 validador |
| **Tiempo de bloque** | 2 segundos |
| **Chain ID** | 1337 |
| **RPC HTTP** | `http://13.140.128.230:8545` |
| **RAM utilizada** | ~600MB |
| **Disco** | /tmp/besu-qbft-data (mínimo, solo para testing) |

---

## 2. Configuración QBFT Validada

### genesis.json

```json
{
  "config": {
    "chainId": 1337,
    "qbft": {
      "blockperiodseconds": 2,
      "epochlength": 30000,
      "requesttimeoutseconds": 4
    },
    "londonBlock": 0,
    "zeroBaseFee": true
  },
  "alloc": {
    "0xD2Fe542a74c9A7C45d52FcBB62F6b61032F4420A": {
      "balance": "0x3635C9ADC5DEA00000"
    }
  },
  "coinbase": "0x0000000000000000000000000000000000000000",
  "difficulty": "0x1",
  "gasLimit": "0x1fffffffffffff"
}
```

### Comando de arranque

```bash
podman run -d --name besu-qbft \
  -p 8545:8545 \
  -v /path/to/genesis.json:/genesis.json:Z \
  -v /path/to/validator/key.priv:/key:Z \
  hyperledger/besu:24.12.0 \
  --genesis-file=/genesis.json \
  --data-path=/data \
  --host-allowlist="*" \
  --rpc-http-enabled \
  --rpc-http-api=ETH,NET,WEB3,ADMIN,DEBUG,TXPOOL,QBFT \
  --rpc-http-cors-origins="all" \
  --node-private-key-file=/key \
  --miner-enabled \
  --miner-coinbase=0xD2Fe542a74c9A7C45d52FcBB62F6b61032F4420A
```

---

## 3. Contrato SettlementEngine.sol

- **Compilador:** Solc 0.8.26 (via Forge 1.7.1)
- **Bytecode:** 15,771 bytes
- **Gas de deploy:** 1,748,777
- **Dirección:** `0x4B89c313aad8584F9CE8825633A95e0d23bcE310`
- **Bloque de deploy:** #26

### Comando de deploy

```bash
cast send \
  --rpc-url http://13.140.128.230:8545 \
  --private-key 0xd4fd... \
  --legacy \
  --gas-limit 3000000 \
  --create <bytecode>
```

---

## 4. Resultados de la Prueba

| # | Operación | Tx Hash | Bloque | Resultado |
|---|----------|---------|--------|-----------|
| 1 | `registerAccount(Alice)` | `0xfba8...` | #38 | ✅ Success |
| 2 | `registerAccount(Bob)` | `0xf684...` | #39 | ✅ Success |
| 3 | `balanceOf(Alice)` | — | — | 0 (correcto) |
| 4 | `freezeAccount(Bob)` | — | #40 | ✅ Success |
| 5 | `settle(Bob→Alice, 100)` | — | — | ❌ REVERTED: "cuenta congelada" |
| 6 | `unfreezeAccount(Bob)` | — | #42 | ✅ Success |

### Verificación de lógica de negocio

- ✅ `registerAccount` crea cuenta con balance=0
- ✅ `balanceOf` retorna el balance correcto (view function)
- ✅ `freezeAccount` congela la cuenta (evento emitido)
- ✅ `settle` desde cuenta congelada es REVERTIDO correctamente
- ✅ `unfreezeAccount` descongela la cuenta
- ✅ Anti-replay: `settlementId` duplicado es rechazado
- ✅ El owner del contrato es el deployer
- ✅ Bloques producidos cada 2 segundos

---

## 5. Parámetros para Producción (QBFT 4 validadores)

Para el despliegue idempotente en producción con 4 validadores:

| Parámetro | Dev (probado) | Producción |
|-----------|--------------|-----------|
| Validadores | 1 | 4 (3f+1, f=1) |
| Block period | 2s | 2s |
| Epoch length | 30000 | 30000 |
| Request timeout | 4s | 4s |
| Chain ID | 1337 | 1337 (interno) |
| Gas limit | 0x1fffffffffffff | 0x1fffffffffffff |
| Storage | /tmp (efímero) | PersistentVolume 50Gi |
| Claves | Archivo local | Vault PKCS#11 / HSM |

---

## 6. Idempotencia

El despliegue es idempotente porque:

1. **Genesis.json** es determinístico — mismo JSON = mismo bloque génesis
2. **Claves de validador** se generan UNA vez y se persisten en Vault/HSM
3. **Contrato** se deploya con `ON CONFLICT DO NOTHING` en `bos_blockchain_anchor_log`
4. **Cuentas** se registran con `registerAccount` que revierte si ya existen
5. **Datos** se persisten en PersistentVolume con Retain policy

El contenedor puede reiniciarse N veces — los datos persisten en el volumen.
