# Anexo A.01 — Estado del Arte: Planos de Control en la Industria (2026)
## Comparación del BOS con plataformas de referencia: Terraform, Crossplane, GitOps, Rancher, Ansible

**Versión:** 1.0.0
**Fecha:** 2026-07-17
**Autor:** bos-developer — SBOS
**Referencia:** 0.00_DIRECTRICES §3 — "Estado del arte obligatorio"

---

## 1. El panorama de Planos de Control en 2026

En 2026, la industria reconoce tres generaciones de herramientas de infraestructura:

| Generación | Herramientas | Modelo | Limitación |
|-----------|-------------|--------|------------|
| **1ra gen — CLI apply** | Terraform, OpenTofu, Pulumi | Ejecutar comando → diff → aplicar → salir | Sin Day 2; drift se acumula entre ejecuciones |
| **2da gen — Control loop** | Crossplane, ArgoCD, Flux | Controlador siempre corriendo en K8s; reconcilia continuamente | Solo opera dentro de K8s; no hace bootstrap del SO |
| **3ra gen — Sovereign Control Plane** | BOS | Daemon PID 1 en el host; gobierna SO + K8s + apps; zero-touch desde bare metal | — (categoría nueva) |

---

## 2. Comparación detallada

### Terraform / OpenTofu — CLI Apply (1ra gen)

**Fortalezas:** 4,000+ providers, ecosistema masivo, planes inspeccionables antes de aplicar.
**Debilidades:** Sin reconciliación continua (drift se acumula), sin Day 2, requiere toolchain externo para state, sin concepto de tenant multi-tenant nativo, sin sagas con compensación.

### Crossplane — Kubernetes Control Plane (2da gen)

**Fortalezas:** Reconciliación continua vía controladores K8s. CRDs como API unificada. Compositions para abstraer infraestructura compleja. GitOps nativo con ArgoCD/Flux.
**Debilidades:** Requiere un cluster K8s ya existente (no resuelve Day 0). Opera dentro de K8s, no sobre el host. Sin concepto de tenants empresariales (namespaces + realms + BDs + Vault). Sin sagas con compensación. Sin Context Plane.

### ArgoCD / Flux — GitOps Controllers (2da gen)

**Fortalezas:** Reconciliación continua cada 30-60s. Git como fuente de verdad. Auto-healing de drift.
**Debilidades:** Solo gestionan manifiestos K8s. No provisionan BDs, no configuran Vault, no crean realms Keycloak. Sin concepto de ficha declarativa auto-contenida.

### Rancher — Multi-cluster Manager (2da gen)

**Fortalezas:** Gestión centralizada de múltiples clusters. Catálogo de apps. RBAC multi-tenant.
**Debilidades:** No hace bootstrap del SO (Ubuntu debe estar instalado). No administra PostgreSQL ni Redis. No tiene Context Plane. Las apps son Helm charts, no fichas.

### Ansible / AWX — Automatización Procedural (1ra gen)

**Fortalezas:** Flexibilidad total vía playbooks. Corre sobre cualquier SO.
**Debilidades:** Imperativo (no declarativo). Sin reconciliación. Sin estado centralizado. Sin sagas con compensación. Requiere mantenimiento constante de playbooks.

---

## 3. Dónde se posiciona el BOS

El BOS combina lo mejor de cada generación y agrega lo que ninguna tiene:

| Capacidad | Terraform | Crossplane | ArgoCD | Rancher | Ansible | **BOS** |
|-----------|:---------:|:----------:|:------:|:-------:|:-------:|:-------:|
| Bootstrap del SO | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| Despliegue K8s | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ |
| Reconciliación continua | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Sagas con compensación | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Fichas declarativas (18 estados) | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ |
| Context Plane (ctx_id) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Multi-tenant nativo | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ |
| Interface Dual (WS+JSON-RPC) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Day 2 autónomo (4 motores) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Soberanía total | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Sin dependencia de SaaS | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## 4. El patrón de reconciliación en la industria y en el BOS

El patrón de **reconciliation loop** (observar → comparar → corregir) es el estándar de la industria en 2026. Crossplane, ArgoCD y Flux lo implementan dentro de K8s. El BOS lo implementa **fuera de K8s**, en el host, como daemon systemd:

```
Industria (Crossplane/ArgoCD):
  K8s pod → watch CRD → diff → apply → repeat

BOS:
  systemd daemon → watch host+K8s+BDs+Vault+Redis → diff → saga con compensación → repeat
```

El BOS reconcilia **5 planos simultáneamente** (host SO, K8s, PostgreSQL, Vault, Redis), no solo recursos K8s. Su unidad de reconciliación es la **ficha declarativa**, no el recurso K8s individual.

---

## 5. Zero-touch provisioning en la industria

La industria converge hacia **Metal³ + Cluster API + GitOps** para zero-touch:

1. BMC (Redfish/IPMI) descubre el hardware
2. Ironic despliega el SO vía PXE
3. Cluster API crea el cluster K8s
4. ArgoCD/Flux despliega las aplicaciones

Son **4 herramientas distintas** orquestadas por un equipo de plataforma. El BOS hace todo esto con **un solo binario** (`bos`) y **un solo comando** (`bosctl setup`), sin BMC, sin PXE, sin Cluster API.

---

## 6. Referencias

- [Crossplane vs Terraform (2026)](https://encore.dev/articles/crossplane-vs-terraform)
- [GitOps at Scale — Sync is the New Apply](https://aws.plainenglish.io/gitops-at-scale-why-sync-is-the-new-apply-architecting-a-self-healing-multi-cluster-platform-6cc575f667c4)
- [Red Hat ZTP with GitOps](https://developers.redhat.com/articles/2025/07/29/implement-zero-touch-provisioning-openshift-gitops)
- [Metal³ — Bare Metal Operator](https://metal3.io/)
- [Gartner Identity Fabric](https://www.gartner.com/en/documents/7140430)
- [ISA-95 / IEC 62264](https://www.isa.org/standards-and-publications/isa-standards/isa-95)

---

*SKULL · SBOS · BosAgent · Julio 2026*
