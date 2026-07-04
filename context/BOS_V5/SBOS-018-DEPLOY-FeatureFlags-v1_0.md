# SBOS-018-DEPLOY — Feature Flags y Estrategia de Despliegue Gradual
## Sección para insertar en SBOS-018 (Estándares) y SBOS-024 (Operaciones)

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-018-DEPLOY
**Versión:** 1.0
**Estado:** ACTIVO
**Clasificación:** Estándar de Ingeniería — Estrategia de Despliegue
**Complementa:** SBOS-018-Standards-v1_0.md (§7 Feature Flags y Blue/Green) y SBOS-024-Operations-v1_0.md (§12 RK-014)
**Insertar en:** SBOS-018 como §7 + complemento en SBOS-024 §12

---

## §7 — Feature Flags y Estrategia de Despliegue Gradual para Fichas y Daemons

### 7.1 Principio de no-interferencia con el rollout canary existente

El IAM Installer ya implementa un rollout canary con tres canales (canary → early → stable) y criterios de halt automático definidos en SBOS-024 §5. Esta sección **no rediseña** ese mecanismo — lo complementa con:

1. **Feature flags para fichas de aplicación:** permiten activar funcionalidades nuevas solo en tenants específicos antes del rollout completo.
2. **Blue/green para daemons soberanos:** proceso análogo al rollout canary pero para los binarios systemd (bKernel, SBOS Data Integration, SBOS AI Tools) que tienen un ciclo de actualización diferente al de las fichas K8s.

---

### 7.2 Feature Flags para fichas de aplicación

#### Mecanismo

En el `manifest.yml` de una ficha, el campo `feature_flag` controla la visibilidad de la ficha:

```yaml
# manifest.yml — ficha en estado EXPERIMENTAL
name: sp-nueva-app
version: "0.1.0"
description: "Nueva integración experimental"
server: s04-erpserver
namespace: erpserver

# Feature flag: controla en qué tenants se despliega esta ficha
feature_flag:
  enabled: true                        # Esta ficha requiere feature flag activo
  keycloak_realm_attribute: "feature_sp_nueva_app"  # Nombre del atributo en el realm
  stage: experimental                  # experimental | beta | ga
```

**Cómo el IAM Installer evalúa el feature flag:**

```python
# IAM Installer — lógica de evaluación de feature flags en FICHA_PROBE.py

def should_deploy_ficha(ficha: Ficha, realm_config: RealmConfig) -> bool:
    """
    Decide si una ficha debe desplegarse en este tenant.
    """
    if not ficha.feature_flag or not ficha.feature_flag.enabled:
        return True  # Sin feature flag: siempre desplegar

    # Consultar el atributo del realm en Keycloak
    attribute = realm_config.get_attribute(ficha.feature_flag.keycloak_realm_attribute)

    if attribute is None:
        return False  # Atributo no configurado: no desplegar (opt-in requerido)

    return attribute.lower() == "true"
```

#### Ciclo de vida de una ficha con feature flag

```
EXPERIMENTAL → BETA → GA

EXPERIMENTAL (feature_flag.stage = "experimental"):
  - La ficha solo se despliega si el realm tiene el atributo habilitado
  - Solo el realm SKULL (equipo de desarrollo) tiene el atributo habilitado
  - Los clientes nunca ven esta ficha a menos que la soliciten explícitamente

BETA (feature_flag.stage = "beta"):
  - La ficha se despliega en realms que opten voluntariamente
  - El administrador del cliente activa el flag en el Core UI: Configuración > Features > [toggle]
  - El Core UI refleja la activación via la API del IAM Installer a Keycloak

GA (feature_flag.stage = "ga" o campo ausente):
  - El field feature_flag se elimina del manifest.yml
  - La ficha se despliega en todos los tenants automáticamente en el próximo ciclo de reconciliación
  - Los tenants que tenían el flag activo no notan cambio
```

#### Ejemplo práctico

```yaml
# Fase EXPERIMENTAL — solo equipo SKULL
name: sp-nueva-app
version: "0.1.0"
feature_flag:
  enabled: true
  keycloak_realm_attribute: "feature_sp_nueva_app"
  stage: experimental

---

# Fase BETA — clientes piloto voluntarios (2 semanas después)
name: sp-nueva-app
version: "0.2.0"
feature_flag:
  enabled: true
  keycloak_realm_attribute: "feature_sp_nueva_app"
  stage: beta

---

# Fase GA — sin feature flag, todos los tenants (2 semanas de beta sin incidentes)
name: sp-nueva-app
version: "0.3.0"
# Sin campo feature_flag → disponible para todos
```

---

### 7.3 Blue/Green para daemons soberanos

Los daemons soberanos (bKernel, SBOS Data Integration, SBOS AI Tools) son binarios systemd. Su proceso de actualización es fundamentalmente diferente al de las fichas K8s — no hay kubectl rollout ni Helm upgrade. Este proceso blue/green garantiza que la transición al nuevo binario es segura.

#### Preparación del nuevo binario

```bash
# El Release Plane distribuye el nuevo binario firmado con Ed25519
# Verificar la firma antes de continuar

# Descargar el nuevo binario
curl -Lo /opt/bos/bkernel.new \
  https://releases.skull.bo/v${NUEVA_VERSION}/bkernel-linux-amd64
curl -Lo /opt/bos/bkernel.new.sig \
  https://releases.skull.bo/v${NUEVA_VERSION}/bkernel-linux-amd64.sig

# Verificar firma Ed25519
openssl pkeyutl -verify \
  -pubin -inkey /etc/skull/release-plane-public.pem \
  -sigfile /opt/bos/bkernel.new.sig \
  -in /opt/bos/bkernel.new
# Esperado: "Signature Verified Successfully"
# Si falla: NO continuar — el binario puede estar comprometido
```

#### Proceso blue/green: observación en modo dry-run

```bash
# Paso 1: Lanzar el nuevo daemon en modo dry-run (observación sin escrituras)
# El nuevo bKernel se lanza como instancia alternativa con flag --dry-run
# procesa el WAL igual que el daemon activo pero NO escribe en ningún destino

/opt/bos/bkernel.new \
  --config /etc/bos/blibs/bkernel/bkernel.toml \
  --dry-run \
  --metrics-port 9101 \       # Puerto diferente al daemon activo (9100)
  --instance-name bkernel-new \
  &
BLUE_GREEN_PID=$!

echo "Nuevo bKernel en dry-run con PID $BLUE_GREEN_PID — observando 5 minutos"
sleep 300  # 5 minutos de observación
```

#### Criterios de swap: condiciones para considerar el nuevo binario como sano

```bash
# Verificar que el nuevo daemon es saludable durante el dry-run

# Métrica 1: lag WAL del nuevo daemon < 500ms
NEW_LAG=$(curl -s http://localhost:9101/metrics | grep bkernel_wal_lag_seconds | awk '{print $2}')
if (( $(echo "$NEW_LAG > 0.5" | bc -l) )); then
  echo "❌ FAIL: lag WAL del nuevo daemon ($NEW_LAG s) > 500ms — NO hacer swap"
  kill $BLUE_GREEN_PID
  exit 1
fi

# Métrica 2: cero errores en logs del nuevo daemon
ERRORS=$(journalctl --pid=$BLUE_GREEN_PID --since="-5m" | grep -c "ERROR")
if [ "$ERRORS" -gt 0 ]; then
  echo "❌ FAIL: $ERRORS errores en logs del nuevo daemon — NO hacer swap"
  kill $BLUE_GREEN_PID
  exit 1
fi

echo "✅ Nuevo daemon saludable — procediendo con el swap"
```

#### Swap atómico (< 30 segundos de interrupción)

```bash
# Paso 2: Guardar el daemon viejo como backup para rollback
cp /usr/local/bin/bkernel /opt/bos/bkernel.prev

# Paso 3: Detener el dry-run del nuevo daemon
kill $BLUE_GREEN_PID

# Paso 4: Swap atómico — el tiempo entre stop y start debe ser < 30 segundos
# El systemd service manager gestiona el reinicio

sudo systemctl stop bkernel
cp /opt/bos/bkernel.new /usr/local/bin/bkernel
chmod +x /usr/local/bin/bkernel
sudo systemctl start bkernel

# Verificar el swap
sudo systemctl status bkernel
sudo journalctl -u bkernel -n 10 | grep "version\|started"

echo "✅ Swap completado — verificar lag WAL en Grafana"
```

#### Rollback inmediato si el swap falla

```bash
# Si el nuevo daemon falla post-swap:
sudo systemctl stop bkernel
cp /opt/bos/bkernel.prev /usr/local/bin/bkernel
sudo systemctl start bkernel

echo "⚠️ Rollback ejecutado — daemon anterior restaurado"
sudo systemctl status bkernel
```

---

### 7.4 Estrategia de despliegue por canal del Release Plane

Esta sección complementa SBOS-024 §5 sin duplicar su contenido.

| Canal | Descripción | Fichas | Daemons soberanos |
|-------|-------------|--------|-------------------|
| **canary** | Early adopters SKULL (equipo interno) | Feature flags EXPERIMENTAL activos | Blue/green con dry-run de 24h |
| **early** | Clientes voluntarios (opt-in) | Feature flags BETA activos + fichas con 2 semanas en canary sin incidentes | Blue/green con dry-run de 6h |
| **stable** | Todos los clientes restantes | Sin feature flags (solo fichas GA) + fichas con 4 semanas en early | Blue/green con dry-run de 5min (validación rápida) |

**Criterio de graduación de un binario de daemon entre canales:**
- canary → early: 2 semanas sin alertas `bKernelDown` ni errores de protocolo WAL en el canal canary.
- early → stable: 4 semanas adicionales sin incidentes en el canal early.

---

## §12 (SBOS-024) — Runbook RK-014: Actualización Blue/Green de Daemon Soberano

**Activación:** nueva versión de bKernel, SBOS Data Integration o SBOS AI Tools disponible en Release Plane.
**Responsable:** DevOps Lead
**Tiempo estimado:** 30 minutos (5 min dry-run + 25 min swap + verificación)

```
[ ] Descargar y verificar firma Ed25519 del nuevo binario
[ ] Lanzar en modo --dry-run durante 5 minutos (canary/early) o validación rápida (stable)
[ ] Verificar criterios de salud: lag WAL < 500ms + 0 errores
[ ] Si criterios OK: ejecutar swap atómico (< 30 segundos)
[ ] Si criterios FAIL: abortar — investigar antes de reintentar
[ ] Post-swap: verificar lag WAL en Grafana < 500ms
[ ] Si post-swap falla: rollback con bkernel.prev en < 1 minuto
```

---

*SKULL · SBOS · SBOS-018-DEPLOY · v1.0 · Marzo 2026*
*Insertar §7 en SBOS-018-Standards y §12 en SBOS-024-Operations*
*Complementa: SBOS-024 §5 (rollout canary existente), SBOS-005 §10 (canales Release Plane)*
