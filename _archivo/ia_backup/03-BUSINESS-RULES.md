# Reglas de Negocio

**Generado por:** Compositor S-29 (reprocesamiento SBOS)
**Fecha:** 2026-05-18
**Proyecto:** SBOS
**Fuentes:** SBOS-BAUTH-CONCEPTUALIZACION-v5_0 (bauth), SBOS-004-RULES (v6), SBOS-023-SECURITY (v6)
**Jerarquia aplicada:** bauth > v6 > v5 > humano

## 1. Principios de arquitectura (inviolables)

| ID | Regla | Consecuencia si se viola |
|---|---|---|
| P1 | sbos_k8s_core() es el UNICO kubectl apply | Pierde trazabilidad de cambios en cluster |
| P2 | pre_install es guardian -- si falla, ABORT | Sin bypass, ficha no se instala |
| P3 | Catalogo global NUNCA nombra apps concretas | Core crece por apps (viola P4) |
| P4 | Core nunca crece para soportar apps nuevas | Acoplamiento con apps |
| P5 | yaml_engine.yml no contiene logica Bash | Mezcla declarativo/imperativo |
| P6 | Idempotencia: --dry-run=client + kubectl apply -f - | Operaciones no repetibles |
| P7 | update nunca reinstala -- aplica solo delta por drift_check | Reinstalacion innecesaria |
| P8 | repair siempre diagnostica antes de actuar | Reparacion ciega |
| P9 | cold nunca ejecuta automaticamente -- requiere aprobacion humana | Accion destructiva sin HITL |

## 2. Reglas de soberania y datos

| ID | Regla | Tipo |
|---|---|---|
| S1 | Los datos del cliente NUNCA salen de su infraestructura | Soberania |
| S2 | bKernel consolida SIN modificar apps ni sus BDs (cero invasion) | Arquitectonica |
| S3 | 100% open source, licencias OSI-approved exclusivamente | Legal |
| S4 | Toda app del stack DEBE soportar PostgreSQL | Arquitectonica |
| S5 | Toda app DEBE ser gobernada por Keycloak | Arquitectonica |
| S6 | K8s desde el dia 1 -- no existe modo "sin Kubernetes" | Operacional |
| S7 | Secrets via Vault -- cero passwords en texto claro | Seguridad |
| S8 | Daemons soberanos en el host (systemd, NO pods K8s) | Arquitectonica |

## 3. Reglas de identidad bAuth (PRECEDENCIA MAXIMA -- bauth v5.0)

| ID | Regla | Detalle |
|---|---|---|
| BA1 | bAuth es el sistema de identidad del SBOS | Keycloak y Tryton son brazos de ejecucion. El SBOS no consulta KC directamente |
| BA2 | RolTemplate es el UNICO contrato de identidad | Todo lo que bAuth sincroniza en KC, Tryton y apps proviene exclusivamente del RolTemplate |
| BA3 | Jurisdiccion NO pertenece al RolTemplate | Pertenece exclusivamente a deploy.yml (correccion J1) |
| BA4 | Herencia via AND NOT, nunca XOR ni NAND | XOR puede otorgar permisos involuntarios. NAND puede elevar a ALL_PERMISSIONS |
| BA5 | SoD via Conflict Matrix, no via aritmetica de bits | Evaluada ANTES de guardar cualquier RolTemplate |
| BA6 | Sincronizacion < 5 segundos | Desde guardar RolTemplate hasta SYNCED en KC + Tryton |
| BA7 | Compensacion en sync: Opcion B | Si KC sincroniza pero Tryton falla, KC no hace rollback. Tryton se reintenta |
| BA8 | Paso de autenticacion min 8 chars con MFA, 15 chars solo | NIST SP 800-63B-4 Final (correccion J6) |
| BA9 | Rotacion periodica de passwords PROHIBIDA | Solo cambiar ante compromiso detectado (correccion J7) |
| BA10 | SMS OTP es Restricted Authenticator | Requiere analisis de riesgo documentado (correccion J8) |
| BA11 | email_otp prohibido como unico segundo factor | Cuando el primero es contrasena (correccion J10) |
| BA12 | Reconcile loop cada 60s | Drift detection + auto-correccion, alerta HIGH si falla |
| BA13 | KC version canonica fijada: 26.6.1 | Decision cerrada -- requiere ADR formal para cambiar |
| BA14 | Break-glass obligatorio | Segundo sbos-admin registrado. No existe bypass no supervisado |

## 4. Compliance legal

| Regla | Norma | Jurisdiccion |
|---|---|---|
| Datos personales en infraestructura del cliente | LGPD, Ley 25.326, Ley 21.719 | Brasil, Argentina, Chile |
| Cumplimiento tributario SIN Bolivia | Ley 843, DS 24051, normativa SIN/SIAT | Bolivia (bauth deploy.yml) |
| Cumplimiento AFIP Argentina | RG factura electronica | Argentina |
| Cumplimiento SAT Mexico | CFDI 4.0 | Mexico |
| Cifrado en reposo y en transito | ISO 27001 A.8.24, A.8.26 | Internacional |

## 5. Calidad de codigo

### Go (bos, bCompass, bSearch, bAuth, bhnexus, banexus)
- gofmt -s, golangci-lint, go vet, CGO_ENABLED=0 para binarios estaticos
- context.Context como primer parametro en toda funcion I/O
- Cobertura: bos >= 80%, bAuth >= 85%, bCompass >= 75%

### Rust (bKernel, biedata)
- #![deny(unsafe_code)], clippy --deny warnings, cargo fmt --check
- Sin .unwrap() ni .expect() en produccion
- Tests de carga: 1000 ejecuciones sin memory leak

### Licencias vetadas
BSL, SSPL, Sustainable Use License, Commons Clause. Excepcion aceptada: HashiCorp Vault (BSL 1.1), Elasticsearch 8 (EL2), Directus (BSL 1.1).
