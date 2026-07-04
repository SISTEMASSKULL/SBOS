#!/bin/bash
# ================================================================
# deploy_production.sh — Despliegue idempotente SBOS en cualquier VPS
# Uso: ./deploy_production.sh [db_name] [namespace] [pod]
# Todo autocontenido SQL. Sin dependencias de archivos externos.
# ================================================================
DB=${1:-bauth_db}
NAMESPACE=${2:-sbos-data}
POD=${3:-postgresql-0}
DIR=$(dirname "$0")/..

echo "=== SBOS Framework Deploy ==="
echo "DB: $DB | NS: $NAMESPACE | Pod: $POD"

# Empaquetar árbol completo y copiar al pod
cd "$DIR"
tar czf /tmp/sbos_deploy.tar.gz data_files migrations
kubectl cp /tmp/sbos_deploy.tar.gz $NAMESPACE/$POD:/tmp/
kubectl exec -n $NAMESPACE $POD -- bash -c 'cd /tmp && tar xzf sbos_deploy.tar.gz'

# Ejecutar DDL (incluye carga de datos + CTE + traducción + clasificación)
echo "=== DDL + Framework ==="
kubectl exec -n $NAMESPACE $POD -- psql -U postgres -d "$DB" -f /tmp/migrations/DDL_skSBOS_db.sql

# Ejecutar seeds
echo "=== Seeds ==="
for seed in /tmp/migrations/seeds/*.sql; do
  kubectl exec -n $NAMESPACE $POD -- psql -U postgres -d "$DB" -f "$seed" 2>&1 | grep -i "ERROR" || true
done

echo "=== Despliegue completado ==="
