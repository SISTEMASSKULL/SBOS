# Vault Unseal — SBOS Bootstrap

**Referencia:** SBOS-007 §8 · DEC-I08
**Backend:** PostgreSQL (sbos-data)
**Unseal keys:** Se generan automáticamente en el primer bootstrap.
**Custodia:** El HITL recibe las 5 unseal keys inmediatamente tras `vault operator init`.
**Threshold:** 3 de 5 keys requeridas para desellar.

⚠️ Sin las unseal keys, Vault no puede desellarse tras un reinicio del pod.
Guardar las keys en lugar seguro fuera del cluster.
