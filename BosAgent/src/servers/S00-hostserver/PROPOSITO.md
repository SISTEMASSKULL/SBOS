# S00-hostserver — PROPÓSITO

> Bitácora del servidor lógico. Norma: `servers/servers.yml`.
> Apps: `IAM_Enterprise_Stack_v5`. Puertos: `BOS_V8_SBOS-050-PORT-CATALOG` §12.

## Qué es
Raíz del sistema — bootstrap Ubuntu+K8s y daemons soberanos. NO es servidor de apps.

## Criticidad
**MÁXIMA**

## Unidad de migración
Al crecer, `S00-hostserver/` se lleva entero a un VPS dedicado (`tipo=hostserver`).

## Aplicaciones
Adecuación de v5 a este servidor. Absorbe: infraestructura base (fichas bash en host, sin ClusterIP).
Puerto = `containerPort → ClusterIP SBOS` (SBOS-050 §12.3). Nunca externos salvo NGINX/correo/SIP.

| App | Puerto (cont→ClusterIP) | Estado | Propósito |
|-----|:----------------------:|:------:|-----------|
| sbos-bootstrap-os | — | ✅ existe | Hardening Ubuntu, CRI-O, kubeadm stack |
| sbos-bootstrap-k8s | — | ✅ existe | kubeadm init, Calico CNI, MetalLB |
| sbos-bootstrap-platform | — | ✅ existe | Namespaces, RBAC, StorageClass, etcd encryption |
| sbos-bootstrap-cni | — | ✅ existe | Configuración CNI |
| sbos-bootstrap-storage | — | ✅ existe | PVs hostPath |
| sbos-bootstrap-hardening | — | ✅ existe | Verificación CIS final (unifica -hard) |
| sbos-bootstrap-monitoring | — | ✅ existe | Bootstrap de observabilidad base |
| sbos-namespace | — | ✅ existe | Namespace del tenant + NetworkPolicy |
| bos-preflight | — | ✅ existe | Chequeos previos del instalador |
| k8s-network-validator | — | ✅ existe | Certifica CNI, DNS, conectividad (ex-S00) |
| sbos-bkernel | — | ✅ existe | Ficha del daemon bKernel |
| bos (daemon) | 9440-9443 | ✅ existe | IAM Installer — host |
| bkernel (daemon) | 9460-9461 | ✅ existe | Listener WAL + fanout — host |
| biedata (daemon) | 9470-9471 | ⬜ falta | Orquestador integración — host |
| bcompass (daemon) | 9480-9483 | ⬜ falta | Inteligencia soberana — host |
| sbos-nginx-web | — | ⬜ falta | Web institucional opcional |

## Fichas existentes ratificadas
`sbos-bootstrap-os`, `sbos-bootstrap-k8s`, `sbos-bootstrap-platform`, `sbos-bootstrap-cni`, `sbos-bootstrap-storage`, `sbos-bootstrap-hardening`, `sbos-bootstrap-monitoring`, `sbos-namespace`, `bos-preflight`, `k8s-network-validator`, `sbos-bkernel`, `bos (daemon)`, `bkernel (daemon)`  
(se ratifican en su sitio, **sin cambiar de servidor**).

## Pendiente
Las fichas ⬜ las completa su daemon responsable bajo `servers.yml` (manifest + task_catalog + resources + PROPOSITO propio). El Bibliotecario solo garantiza la norma.
