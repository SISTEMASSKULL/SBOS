# BOS-REPAIR-15 — Estándares Internacionales Aplicables
## Marco normativo del SBOS como sistema operativo empresarial
## SKULL · SBOS · v1.0 · Junio 2026 · Basado en investigación de fuentes primarias

**Propósito:** que el SBOS no solo funcione, sino que sea **demostrable** ante
cualquier auditoría que cumple las normas que un sistema operativo empresarial
sobre Kubernetes debe cumplir en 2026. Cada estándar tiene: qué es, qué exige,
qué ya cumple el proyecto, y qué átomo (F11-F17 o complementos de fases previas) cierra el gap.

---

## 1. CIS Kubernetes Benchmark v1.12 (→ átomo F17.1)

**Qué es:** recomendaciones de configuración consensuadas para Kubernetes,
publicadas por el Center for Internet Security. La v1.12.0 cubre K8s 1.32-1.34 —
exactamente la versión del staging (kubeadm v1.32.13). Dos niveles: L1
(esenciales, bajo impacto) y L2 (defensa en profundidad).

**Qué exige (áreas):** control plane (flags del API server, etcd cifrado),
kubelet, RBAC y service accounts, políticas de pods, network policies.

**Ya cumplido por BOS-REPAIR:**
- ClusterRole `bosagent` least-privilege verificado con `kubectl auth can-i` —
  el registro F9.8 lo certifica explícitamente contra CIS 4.1.1
- Sin secrets accesibles para el service account del bos

**Plan:** integrar `kube-bench` (ejecuta los checks del benchmark) en el CI y
como verificación de F17.1. Meta: **L1 ≥95% pass**; toda excepción documentada
con control compensatorio en `docs/compliance/CIS-EXCEPTIONS.md`. Remediación
de flags del API server bajo gate de aprobación (riesgo de tumbar el cluster).

## 2. CIS Benchmark del host (Ubuntu) (→ F17.2)

El nodo staging corre Ubuntu 26.04. Aplicar el benchmark CIS de la familia
Debian/Ubuntu vigente al host: particiones, auditd, SSH hardening (alineado
con F0.6.S — retirar root diario), sysctl. Herramienta: CIS-CAT Lite o Lynis
como aproximación abierta.

## 3. NIST SP 800-190 — Application Container Security Guide (→ F17.3)

**Qué es:** la guía del NIST para seguridad de contenedores en todo su ciclo:
imágenes, registries, orquestador, runtime y host, con mapeo a controles
NIST SP 800-53.

**Aplicación directa al SBOS:**
- Imágenes: la imagen `fedora-logico` (F16.3) y todas las fichas se construyen
  en CI, se escanean (trivy) y se firman (cosign) antes del registry
- Registry: registry interno con TLS + autenticación; prohibido `latest` en
  producción — tags inmutables por digest
- Orquestador: cubierto por CIS K8s (§1) + Linkerd mTLS (F13.5)
- Runtime: pods fedora-logico sin privilegios, sin hostPath, seccompProfile
  RuntimeDefault, VNC NUNCA expuesto fuera de la red del cluster (solo
  Guacamole lo alcanza — ya es el diseño de SBOS-052)

## 4. NIST SP 800-218 — SSDF v1.1 (Secure Software Development) (→ F17.4)

**Qué es:** el Secure Software Development Framework del NIST: prácticas de
desarrollo seguro en 4 grupos — Prepare the Organization (PO), Protect the
Software (PS), Produce Well-Secured Software (PW), Respond to Vulnerabilities
(RV). Es la referencia global de SDLC seguro (origen: EO 14028).

**Mapeo honesto del estado actual:**

| Grupo SSDF | Ya cumplido (BOS-REPAIR) | Gap → acción |
|---|---|---|
| PO — preparar | Políticas SFP-01..06 escritas · roles ADR-002 · protocolo de sesión | Formalizar en docs/compliance/SSDF-MAP.md |
| PS — proteger | Git con commits firmables · _legacy + snapshot inmutable (tag) | Branch protection activa + firma de commits |
| PW — producir | CI con vet+gofmt+race ×10 · revisión por gates · godoc ADR-003 | SAST Go (gosec/staticcheck) en CI · análisis de dependencias (govulncheck) |
| RV — responder | Runbooks RB-01/02/03 · INCIDENTES-LOG · audit JSONL | Política de divulgación + ventana de parcheo definida |

## 5. SLSA — Supply-chain Levels for Software Artifacts (→ F17.5)

**Qué es:** marco de niveles (1-3) para integridad de la cadena de suministro:
requisitos de fuente, build y **provenance** (procedencia verificable del
artefacto).

**Meta del SBOS: SLSA nivel 2** — builds en CI hospedado que generan
provenance firmada. Aplica a: binarios `bos`, `bosctl`, `sbos-client`, la
imagen `fedora-logico` y el `sbos-fedora.iso` (que ya contempla firma Ed25519
+ SHF12.6 en SBOS-052 §8 — ese diseño ES SLSA-friendly). Herramientas:
cosign + slsa-github-generator (o equivalente en el GitLab CE del proyecto).

## 6. SBOM — Software Bill of Materials (→ F17.6)

Inventario de componentes por release en formato CycloneDX o SPDX, generado
automáticamente (syft) para cada binario e imagen. Es exigencia transversal
de SSDF/EO-14028 y habilita respuesta rápida ante CVEs (govulncheck cruza
el SBOM contra la base de vulnerabilidades de Go).

## 7. ISO/IEC 27001:2022 — Gestión de seguridad de la información (→ F17.7)

**Qué es:** el estándar internacional de ISMS. La edición 2022 reorganizó el
Annex A (93 controles en 4 temas) con foco nuevo en cloud, threat
intelligence y data leakage.

**Ya cumplido:** A.8.15 (logging) — el audit JSONL append-only del bos fue
diseñado citando explícitamente ISO 27001 A.8.15 desde BOS-REPAIR (F1.1,
F10.7, runbooks).

**Matriz mínima a completar en docs/compliance/ISO27001-MATRIX.md:**

| Control | Tema | Evidencia SBOS |
|---|---|---|
| A.5.23 Cloud services security | Organizacional | Arquitectura soberana: todo on-prem, sin terceros |
| A.8.2/8.3 Privileged access | Tecnológico | ADR-002 roles + ADR-006 RBAC delegado + F0.6.S |
| A.8.5 Secure authentication | Tecnológico | Keycloak OIDC + MFA (F13.2) — único punto de auth (P4 SBOS-052) |
| A.8.15 Logging | Tecnológico | ✅ audit JSONL del bos + sbos-client |
| A.8.16 Monitoring | Tecnológico | 18 métricas Prometheus (F9.7) + SLOs |
| A.8.24 Cryptography | Tecnológico | Vault PKI + mTLS Linkerd + Ed25519 ISO |
| A.8.28 Secure coding | Tecnológico | SFP + gosec/govulncheck (A7.4) |
| A.5.29/8.13 Continuidad/backup | Org/Tec | F12.6 backups + sagas con compensación |

Nota honesta: cumplir controles ≠ certificarse. La certificación ISO 27001
requiere un ISMS organizacional completo y auditoría externa — fuera del
alcance técnico de este plan. El objetivo aquí es **conformidad demostrable
de los controles técnicos**.

## 8. ISO/IEC 25010 — Calidad del producto software (→ F17.8)

**Qué es:** el modelo internacional de calidad de producto con 8
características: funcionalidad, eficiencia, compatibilidad, usabilidad,
fiabilidad, seguridad, mantenibilidad, portabilidad.

**Gates medibles que el SBOS adopta (verificables por bosctl/CI):**

| Característica | Gate medible | Fuente |
|---|---|---|
| Fiabilidad | Disponibilidad fichas críticas 99.5% · VDI 99.0% · MTTR <10min (VDI <5min) | SLOs ya definidos en BOS-REPAIR-01 |
| Mantenibilidad | Cobertura internal/ ≥60% sostenida · ningún archivo >500 líneas en cmd/ | F8.6 + arquitectura F3 |
| Funcionalidad | 14/14 criterios C-01..C-14 · matriz fichas sin gaps core | F17.9 + F11.10 |
| Usabilidad | 15 pantallas con paridad + golden tests · login VDI <10s | F11.x + C-14 |
| Seguridad | kube-bench L1 ≥95% + 0 CVEs críticos abiertos >7 días | F17.1 + F17.6 |
| Eficiencia | bos.query.* <4s · device.register <2s | F6.6 + C-13 |
| Portabilidad | Cliente en hardware 2010/4GB (P5 SBOS-052) — test en VM mínima | F16.12 |

## 9. Lo que NO se adopta (decisión documentada)

- **SOC 2 / PCI DSS / HIPAA:** específicos de industrias/servicios de terceros;
  no aplican a un OS soberano on-prem sin datos de tarjetas ni salud. Si un
  tenant futuro los requiere, esta matriz es la base.
- **FedRAMP:** solo gobierno de EE.UU.
- **WCAG:** orientado a web; el TUI adopta en su lugar buenas prácticas de
  accesibilidad de terminal (contraste de la paleta styles.go, ancho mínimo
  40 cols ya testeado en F3.8).

---

## Resumen ejecutivo del marco

```
SEGURIDAD DE PLATAFORMA:  CIS K8s v1.12 (L1≥95%) + CIS Ubuntu + NIST 800-190
DESARROLLO SEGURO:        NIST SSDF 800-218 (PO/PS/PW/RV) + gosec + govulncheck
CADENA DE SUMINISTRO:     SLSA L2 (provenance) + SBOM (CycloneDX) + cosign/Ed25519
GESTIÓN DE SEGURIDAD:     ISO 27001:2022 — matriz de controles técnicos
CALIDAD DE PRODUCTO:      ISO 25010 — 7 gates medibles en CI/bosctl
```

Todo converge en el átomo F17.9: `bosctl bootstrap verify --full` → 14/14 +
reporte de certificación que cita evidencia por estándar.

---

*BOS-REPAIR-15 v1.0 · SKULL · SBOS · Junio 2026*  
*Fuentes primarias: cisecurity.org (Benchmarks 2026) · csrc.nist.gov (SP 800-190, SP 800-218) · slsa.dev · ISO/IEC 27001:2022 · ISO/IEC 25010*
