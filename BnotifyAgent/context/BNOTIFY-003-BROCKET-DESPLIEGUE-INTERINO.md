---
codigo: BNOTIFY-003
version: 1.0.0
estado: BORRADOR
gate: G0
depende_de: [BNOTIFY-001, BNOTIFY-002]
doctrina_que_ejerce: [D1, D3, D7, D14]
criterio_implementado: >
  Un usuario real del tenant de prueba puede iniciar sesión en bRocket mediante
  OIDC contra bAuth (no mediante cuenta local). El endpoint GET /api/v1/info de
  bRocket retorna version 8.5.0 confirmando la versión congelada. La réplica
  MongoDB tiene 3 nodos y el primary es identificable. Jitsi genera salas y
  entrega tokens JWT sin errores. Todo lo anterior verificado con
  verificar_afirmacion.sh en la VPS de staging.
---

# BNOTIFY-003 — bRocket Despliegue Interino
## Especificación de configuración de Rocket.Chat CE 8.5.0 en K8s

**Versión:** 1.0.0 · **Gate:** G0 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §5, ADR-003 (solo configuración, cero desarrollo)

**D7 — La regla absoluta de este documento:**
> bRocket es el puente. No es el destino. No recibe inversión de desarrollo.
> Todo lo que está en este documento es **configuración**, no código propio.
> Si algo que se necesita no es alcanzable mediante configuración en RC CE 8.5.0,
> la respuesta es aceptar la limitación, documentarla en §7, y esperar bChat.

---

## 1. Contexto

bRocket es la instancia de Rocket.Chat Community Edition 8.5.0 que sirve de canal
de chat mientras se construye el motor nativo bChat. Opera en K8s sobre el servidor
de comunicaciones (S10-commsserver). La versión está congelada (ADR-003).

**Lo que este documento especifica:**
1. La topología K8s de bRocket (manifests de deployment, statefulsets, services)
2. La configuración MongoDB replica set
3. La integración S3 para medios
4. La integración Jitsi para video grupal
5. La configuración OIDC para autenticar contra bAuth (BNOTIFY-002)
6. El livechat activado para atención al cliente
7. Los límites CE aceptados y documentados

---

## 2. Componentes del deployment

```
K8s namespace: bns-messaging

rocketchat     StatefulSet   3 pods (para HA dentro del cluster)
mongodb        StatefulSet   3 pods (Replica Set)
jitsi-web      Deployment    1 pod
jitsi-prosody  StatefulSet   1 pod (XMPP signaling)
jitsi-jicofo   Deployment    1 pod (conference focus)
jitsi-jvb      Deployment    1 pod (video bridge)
minio          StatefulSet   1 pod (o S3 externo — ver §3.3)
```

### 2.1 Recursos mínimos por componente

| Pod | CPU request | CPU limit | RAM request | RAM limit |
|-----|:-----------:|:---------:|:-----------:|:---------:|
| rocketchat | 500m | 2000m | 1Gi | 2Gi |
| mongodb | 500m | 1500m | 1Gi | 3Gi |
| jitsi-web | 100m | 500m | 128Mi | 512Mi |
| jitsi-jvb | 200m | 1000m | 256Mi | 1Gi |

---

## 3. MongoDB Replica Set

### 3.1 Configuración obligatoria

Rocket.Chat CE requiere MongoDB Replica Set (no standalone). Mínimo 3 nodos:
1 primary + 2 secondary. La versión fijada es MongoDB 8.0.x (BNOTIFY-006 §5).

```yaml
# mongodb-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
  namespace: bns-messaging
spec:
  serviceName: mongodb
  replicas: 3
  selector:
    matchLabels:
      app: mongodb
  template:
    spec:
      containers:
        - name: mongodb
          image: mongo:8.0
          command:
            - mongod
            - "--replSet"
            - "rs0"
            - "--bind_ip_all"
          env:
            - name: MONGO_INITDB_ROOT_USERNAME
              valueFrom:
                secretKeyRef:
                  name: mongodb-secret
                  key: username
            - name: MONGO_INITDB_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mongodb-secret
                  key: password
          ports:
            - containerPort: 27017
          volumeMounts:
            - name: mongodb-data
              mountPath: /data/db
  volumeClaimTemplates:
    - metadata:
        name: mongodb-data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 50Gi
```

### 3.2 Inicialización del Replica Set

Se ejecuta una sola vez vía Job K8s tras el arranque de los 3 pods:

```javascript
// rs-init.js — ejecutado por el Job de inicialización
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongodb-0.mongodb.bns-messaging.svc.cluster.local:27017" },
    { _id: 1, host: "mongodb-1.mongodb.bns-messaging.svc.cluster.local:27017" },
    { _id: 2, host: "mongodb-2.mongodb.bns-messaging.svc.cluster.local:27017" }
  ]
});
```

Connection string de bRocket:
```
MONGO_URL=mongodb://username:password@mongodb-0.mongodb:27017,mongodb-1.mongodb:27017,mongodb-2.mongodb:27017/rocketchat?replicaSet=rs0&authSource=admin
MONGO_OPLOG_URL=mongodb://username:password@mongodb-0.mongodb:27017,mongodb-1.mongodb:27017,mongodb-2.mongodb:27017/local?replicaSet=rs0&authSource=admin
```

### 3.3 Almacenamiento de medios — S3 API

bRocket almacena archivos adjuntos en S3 compatible. Se usa la instancia MinIO
del ecosistema (o S3 externo — la abstracción S3 API permite intercambio).

Variables de entorno de bRocket para S3 (inyectadas desde K8s Secret con datos de Vault):
```
OVERWRITE_SETTING_FileUpload_Storage_Type: "AmazonS3"
OVERWRITE_SETTING_FileUpload_S3_Bucket: "rocketchat-uploads"
OVERWRITE_SETTING_FileUpload_S3_Endpoint: "http://minio.infra.svc.cluster.local:9000"
OVERWRITE_SETTING_FileUpload_S3_PathStyle: "true"
OVERWRITE_SETTING_FileUpload_S3_AccessKeyId: "${S3_ACCESS_KEY}"
OVERWRITE_SETTING_FileUpload_S3_SecretAccessKey: "${S3_SECRET_KEY}"
```

---

## 4. Integración Jitsi para video grupal

### 4.1 Arquitectura del patrón adaptador delgado

bRocket sigue el patrón identificado en BNOTIFY-000 §B.0: el chat no procesa media,
genera sala + JWT y delega al motor de video. Esta integración es **solo configuración**.

### 4.2 Variables de entorno de Jitsi en bRocket

```yaml
# Inyectadas desde K8s Secret
OVERWRITE_SETTING_Jitsi_Enabled: "true"
OVERWRITE_SETTING_Jitsi_Domain: "jitsi.sbos.internal"
OVERWRITE_SETTING_Jitsi_SSL: "true"
OVERWRITE_SETTING_Jitsi_URL_Room_Prefix: "sbos_"
OVERWRITE_SETTING_Jitsi_Use_Token: "true"
OVERWRITE_SETTING_Jitsi_Application_Id: "${JITSI_APP_ID}"
OVERWRITE_SETTING_Jitsi_Application_Secret: "${JITSI_APP_SECRET}"
OVERWRITE_SETTING_Jitsi_Limit_Token_To_Room: "true"
```

### 4.3 Configuración del servidor Jitsi

La versión congelada es Jitsi Meet 2.0.9984 (BNOTIFY-006 §5). El config de prosody
debe aceptar tokens JWT con el mismo `APP_ID` y `APP_SECRET` configurados en bRocket.

```lua
-- prosody.cfg.lua — sección de autenticación
authentication = "token"
app_id = os.getenv("JITSI_APP_ID")
app_secret = os.getenv("JITSI_APP_SECRET")
allow_empty_token = false
```

---

## 5. OIDC contra bAuth (D9)

Esta sección implementa la configuración definida en BNOTIFY-002.

### 5.1 Variables de entorno de bRocket para OIDC bAuth

```yaml
# K8s Secret: rocketchat-oidc-secret
# Inyectado desde Vault: sbos/bauth/oidc/clients/${TENANT_ID}/rocketchat
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth: "true"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_url: "https://bauth.sbos.internal"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_token_path: "/auth/oidc/token"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_identity_path: "/auth/oidc/userinfo"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_authorize_path: "/auth/oidc/authorize"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_scope: "openid profile email sbos_roles"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_id_field: "sub"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_username_field: "email"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_email_field: "email"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_name_field: "name"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_roles_claim_name: "sbos_roles"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_client_id: "rocketchat-${TENANT_ID}"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_client_secret: "${BAUTH_OIDC_CLIENT_SECRET}"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_button_label_text: "Entrar con cuenta SBOS"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_show_button_on_login_page: "true"
```

### 5.2 Limitación CE a verificar (R2 de BNOTIFY-002 §7.1)

⚠️ **Verificación pendiente ante instancia real:** Rocket.Chat CE tiene algunas
features de autenticación SSO marcadas como Enterprise en docs recientes. Debe
confirmarse en el despliegue real de CE 8.5.0:

| Verificación | CE 8.5.0 | Acción si no |
|--------------|:--------:|--------------|
| OIDC Custom Provider funcional | ❓ por verificar | Usar auth local temporal para pruebas (solo staging) |
| `roles_claim_name` con array de strings | ❓ por verificar | Mapeo manual de roles en el despliegue |
| PKCE S256 en el flow | ❓ por verificar | Fallback a `code` sin PKCE (menos seguro, solo temporal) |

Esta verificación empírica es el gate G0 para BNOTIFY-003.

---

## 6. Livechat (atención al cliente) activado

El módulo livechat de bRocket está incluido en CE sin restricciones.
Se activa mediante configuración.

```yaml
OVERWRITE_SETTING_Livechat_enabled: "true"
OVERWRITE_SETTING_Livechat_title: "Soporte SBOS"
OVERWRITE_SETTING_Livechat_registration_form: "false"  # bAuth gestiona la identidad
OVERWRITE_SETTING_Livechat_show_agent_info: "true"
```

**Nota:** el livechat de bRocket es la solución interina. La bandeja de atención
definitiva es el módulo first-party de bChat (BNOTIFY-042) que estrena la
arquitectura de módulos.

---

## 7. Límites CE aceptados y documentados

La Community Edition de Rocket.Chat tiene limitaciones frente a Enterprise Edition.
Esta tabla registra los límites conocidos y la decisión de aceptarlos:

| Limitación CE | Impacto | Decisión | Alternativa en bChat |
|---------------|---------|----------|---------------------|
| Sin Matrix Federation | No afecta (bChat es red cerrada por diseño) | Aceptado | No aplica |
| Sin LDAP Enterprise (no mapeo de grupos avanzado) | No afecta (bAuth reemplaza LDAP) | Aceptado | bAuth nativo |
| Analíticas y reportes limitados | Impacto bajo (observabilidad en bNotify) | Aceptado | Métricas nativas |
| Sin auditoría avanzada de mensajes | Impacto medio (bNotify audita los intents) | Aceptado hasta G2 | Auditoría A/B/C en bNotify/bChat |
| Sin Custom OAuth avanzado (EE claims) | ❓ Por verificar en CE 8.5.0 | Verificar en §5.2 | bAuth OIDC nativo en bChat |
| Sin E2EE de servidor (EE) | Sin EE: E2EE opt-in por usuario con llaves locales (no ideal) | Aceptado hasta G5 | MLS/RFC 9420 en bChat C5 |
| Escalado limitado sin EE | Se mitiga con StatefulSet 3 réplicas + MongoDB RS | Aceptado hasta G3 | bChat escala nativamente |

---

## 8. Variables de entorno consolidadas del StatefulSet

El StatefulSet de bRocket recibe todas las variables de configuración mediante
K8s Secrets/ConfigMaps. El patrón `OVERWRITE_SETTING_*` de RC sobreescribe
cualquier ajuste de la UI de administración.

Variables de comportamiento general:

```yaml
ROOT_URL: "https://${TENANT_ID}.sbos.app/chat"
PORT: "3000"
INSTANCE_IP: "$(POD_IP)"
# MONGO_URL y MONGO_OPLOG_URL inyectados desde Secret
Accounts_RegistrationForm: "Disabled"  # Solo login vía bAuth OIDC
Accounts_ShowFormLogin: "false"         # Ocultar formulario usuario/password
```

---

*BNOTIFY-003 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*bRocket no recibe inversión de desarrollo. Si algo no es configurable en CE 8.5.0, se acepta y se espera bChat.*
