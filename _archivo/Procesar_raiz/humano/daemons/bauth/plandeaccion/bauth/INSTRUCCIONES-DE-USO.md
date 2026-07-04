# INSTRUCCIONES DE USO — Desarrollo bAuth
## Comandos prácticos por Gate

**Versión:** 1.0 · **Fecha:** 2026-06-19

---

## B0 — Esqueleto

```bash
cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BauthAgent/src
go build ./...
go vet ./...
go test ./...
CGO_ENABLED=0 go build -ldflags="-s -w" -o bin/bauth ./cmd/bauth
```

## B1 — PrivilegeEngine

```bash
go test ./internal/privilege/... -v -cover
go test ./internal/privilege/... -bench=. -benchmem
```

## B2 — Sincronización KC↔Tryton

```bash
# Verificar Keycloak
curl -s http://keycloak.sbos-security:8080/health
# Verificar Tryton
KUBECONFIG=/etc/bos/.kube/config kubectl get pod -n sbos-erp tryton-0
```

## Prerrequisitos acumulativos

| Gate | Necesita |
|------|----------|
| B0 | Go 1.22+, git |
| B1 | B0 + PostgreSQL 18.4 |
| B2 | B1 + Keycloak 26.6.2 + Tryton 7.4 |
| B3 | B2 + Redis 8.6.2 |
| B4 | B3 + bhnexus |

## Comandos rápidos VPS

```bash
sshpass -p '12345678ubuntu' ssh root@13.140.128.230
KUBECONFIG=/etc/bos/.kube/config kubectl get pods -A | grep -v kube-system
```

---
*INSTRUCCIONES-DE-USO v1.0 · 2026-06-19*
