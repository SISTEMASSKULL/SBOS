# INSTRUCCIONES DE USO — Desarrollo bKernel
## Instrucciones prácticas para ejecutar cada Gate

**Versión:** 1.0 · **Fecha:** 2026-06-19

---

## Gate G0 — Esqueleto del Binario y CI

### G0.E2.T1 — Workspace Cargo

```bash
# 1. Instalar Rust (si no está)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env
rustup default stable
rustup target add x86_64-unknown-linux-musl

# 2. Verificar scaffold actual
cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BkernelAgent
cargo check 2>&1 | head -20

# 3. Actualizar edition 2021→2024
# Editar Cargo.toml: edition = "2024"
# Agregar perfil release con LTO

# 4. Verificar módulos compilan
cargo build 2>&1
cargo clippy -- -D warnings 2>&1
```

### G0.E2.T2 — Build MUSL

```bash
# Instalar musl tools (Ubuntu)
sudo apt-get install -y musl-tools

# Build estático
RUSTFLAGS="-C target-feature=+crt-static" cargo build --release --target x86_64-unknown-linux-musl

# Verificar
file target/x86_64-unknown-linux-musl/release/bkernel-daemon
# Debe reportar: "statically linked"

ls -lh target/x86_64-unknown-linux-musl/release/bkernel-daemon
# Debe ser < 15MB
```

### G0.E4.T1 — Migraciones núcleo

```bash
# El DDL se ejecuta contra PostgreSQL en la VPS
# Verificar conexión:
KUBECONFIG=/etc/bos/.kube/config kubectl exec -n sbos-data postgresql-0 -- psql -U postgres -d bkernel_db -c "SELECT current_database(), current_schema;"

# Aplicar DDL (vía bkernel AutoMigrate o manualmente en desarrollo):
KUBECONFIG=/etc/bos/.kube/config kubectl exec -n sbos-data postgresql-0 -- psql -U postgres -d bkernel_db -f /dev/stdin < migrations/001_init.sql
```

---

## Gate G1 — CDC Multi-Motor

### G1.E1.T1 — Cliente pgoutput

```bash
# Requisito: slot de replicación creado en PostgreSQL
KUBECONFIG=/etc/bos/.kube/config kubectl exec -n sbos-data postgresql-0 -- psql -U postgres -d bkernel_db -c "SELECT * FROM pg_create_logical_replication_slot('bkernel_slot', 'pgoutput');"

# Test fixture: base de datos con tabla de prueba + datos
# El test de integración debe: INSERT → capturar → verificar BkernelEvent
```

---

## Prerrequisitos acumulativos

| Gate | Necesita |
|------|----------|
| G0 | Rust 1.85+, cargo, musl-tools, git |
| G1 | G0 + PostgreSQL 18.4 con WAL logical, slot de replicación |
| G2 | G1 + Redis 8.6.2, ficha de ejemplo (4 archivos) |
| G3 | G2 + Apache AGE en PostgreSQL, documentación SBOS-049 |
| G4 | G3 + event triggers en PostgreSQL, colector OpenLineage |
| G5 | G4 + > 25 fuentes registradas (caso real) |

---

## Comandos rápidos

```bash
# Build + test + clippy (ciclo estándar)
cargo build --release && cargo test && cargo clippy -- -D warnings

# Solo el módulo CDC
cargo test -p bkernel-daemon -- cdc::

# Benchmarks
cargo bench -- cdc_latency

# Verificar tamaño del binario
ls -lh target/release/bkernel-daemon

# Conectar a VPS
sshpass -p '12345678ubuntu' ssh -o StrictHostKeyChecking=no root@13.140.128.230

# Ver pods del stack
KUBECONFIG=/etc/bos/.kube/config kubectl get pods -A | grep -v kube-system
```

---
*INSTRUCCIONES-DE-USO v1.0 · 2026-06-19*
