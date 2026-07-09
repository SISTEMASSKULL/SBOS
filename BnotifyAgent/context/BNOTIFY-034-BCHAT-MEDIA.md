---
codigo: BNOTIFY-034
version: 1.0.0
estado: BORRADOR
gate: G2
depende_de: [BNOTIFY-032]
doctrina_que_ejerce: [D2, D5, D11, D14]
criterio_implementado: >
  Un cliente puede subir una imagen (< 10 MB) y el motor bChat responde con una URL
  pre-firmada de S3 (MinIO) en < 500ms. El receptor del mensaje puede descargar
  la imagen con la URL pre-firmada. Las miniaturas se generan automáticamente en < 2s.
  Los archivos que superan el límite de tier son rechazados con código de error correcto.
  Verificado con verificar_afirmacion.sh en VPS.
---

# BNOTIFY-034 — bChat Media
## Pipeline de medios: upload, almacenamiento S3, miniaturas, límites por tier, expiración

**Versión:** 1.0.0 · **Gate:** G2 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-031 §2.5 (bchat.media_object) · BNOTIFY-030 §4.5 (bchat.media.upload)

---

## 1. Principios del pipeline de medios

- **MinIO como S3 soberano:** todos los archivos van a MinIO desplegado en K8s namespace `infra` — ningún archivo sale del servidor del cliente (D2)
- **URL pre-firmada:** el cliente sube directamente a MinIO con una URL firmada — el motor bChat no actúa como proxy de binarios
- **Miniaturas en el motor:** el motor genera thumbnails de imágenes/videos antes de confirmar el mensaje — el cliente siempre recibe una miniatura disponible
- **Límites por tier KYC:** T0 ≤ 10 MB/archivo, T1 ≤ 100 MB, T2 ≤ 1 GB (archivos grandes: documentos, backups) — ver BNOTIFY-062
- **Contenido prohibido:** el motor rechaza MIME types ejecutables sin inspeccionar el contenido (D11 — proporcionalidad)
- **Expiración coherente con retención de sala:** los objetos S3 expiran cuando la sala se archiva

---

## 2. Flujo de upload

```
Cliente Flutter
│
│  1. bchat.media.upload_init(mime_type, size_bytes, room_id)
▼
Motor bChat
│  → Verificar tier del usuario contra límites
│  → Generar media_id (UUID) y s3_key = "bchat/{tenant_id}/{year}/{month}/{media_id}"
│  → Crear registro en bchat.media_object (state = 'PENDING')
│  → Generar URL pre-firmada MinIO (PUT, TTL 5 minutos)
│  → Retornar { media_id, upload_url, expires_at }
│
│  2. PUT upload_url (cliente sube directamente a MinIO)
▼
MinIO
│  → Recibe el binario
│  → Confirma con 200 OK al cliente
│
│  3. bchat.media.upload_confirm(media_id, sha256_hex)
▼
Motor bChat
│  → Verificar hash SHA256 contra el objeto en MinIO
│  → Actualizar bchat.media_object (state = 'READY')
│  → Lanzar tarea de thumbnail (imagen/video) o no (docs/audio)
│  → Retornar { media_id, download_url, thumbnail_url | null }
│
│  4. bchat.message.send(..., media_id)  [usando el flow normal de BNOTIFY-032]
▼
Motor bChat
│  → INSERT bchat.message_attachment
│  → fan-out normal
```

---

## 3. Generación de miniaturas

El motor bChat incluye una tarea Tokio para procesamiento de miniaturas. No es un servicio separado — es un pool de workers dentro del mismo proceso.

### 3.1 Tipos soportados

| MIME type | Miniatura | Dimensiones | Librería Rust |
|-----------|-----------|-------------|---------------|
| image/jpeg, image/png, image/webp | Sí | 320×320 max, preserva aspecto | `image` crate 0.25 |
| image/gif | Primera frame | 320×320 | `image` crate |
| video/mp4, video/webm | Frame 0:01 | 320×240 | `ffmpeg` CLI (no binding) |
| application/pdf | Primera página | 320×240 | `pdfium-render` |
| audio/* | No | — | — |
| Otros | No | — | — |

**Decisión sobre video/PDF:** se llama al CLI de ffmpeg/pdfium como proceso hijo con `Command::new("ffmpeg")` — no se usan bindings de FFI para evitar unsafe extenso. El proceso tiene timeout de 10 segundos.

### 3.2 Almacenamiento de thumbnail

```
s3_key del thumbnail = "{s3_key_original}.thumb.webp"
```

El thumbnail se almacena en WebP (mejor compresión que JPEG para el mismo tamaño). La URL del thumbnail es una URL pre-firmada GET de larga duración (mismo TTL que el objeto original).

---

## 4. Límites por tier KYC

| Tier | Tamaño máximo / archivo | Almacenamiento total / usuario | Tipos bloqueados |
|------|:-----------------------:|:------------------------------:|-----------------|
| T0 (anónimo/básico) | 10 MB | 500 MB | video/*, application/* |
| T1 (verificado básico) | 100 MB | 5 GB | — |
| T2 (verificado completo) | 1 GB | 50 GB | — |

Los límites se verifican **antes de emitir la URL pre-firmada**, consultando el tier del usuario en bAuth vía gRPC (caché local 30s).

### 4.1 MIME types siempre bloqueados

```rust
const BLOCKED_MIME_TYPES: &[&str] = &[
    "application/x-executable",
    "application/x-elf",
    "application/x-msdownload",
    "application/x-sh",
    "text/x-script",
];
```

El motor no inspecciona el contenido binario para detectar MIME types falsos — eso está fuera del alcance del principio D11 (proporcionalidad). El cliente declara el MIME type y el motor valida contra la lista bloqueada y el tamaño.

---

## 5. Expiración y retención

Los objetos S3 siguen la retención de la sala que los contiene:

| Tipo de sala | TTL del objeto S3 | Política MinIO |
|---|---|---|
| Direct (DM) | 1 año + 30 días gracia | Lifecycle rule: expiry = retention + 30d |
| Grupo | 2 años + 30 días gracia | Ídem |
| Canal | Indefinida | Sin lifecycle rule |
| Broadcast | 90 días | Lifecycle rule: expiry = 90d |

Cuando un mensaje se borra lógicamente (`deleted_at`), el objeto S3 **no se borra inmediatamente** — expira al final del periodo de retención de la sala más los 30 días de gracia. Esto garantiza que si se necesita evidencia forense el contenido sigue accesible.

---

## 6. Políticas de acceso a los objetos

- **Privados por defecto:** todos los objetos son privados en MinIO (`private` ACL)
- **Acceso por URL pre-firmada:** el motor genera URLs GET con TTL = 24 horas para descarga
- **Renovación automática:** el cliente solicita nueva URL cuando la anterior expira — el motor verifica que el usuario sigue teniendo acceso a la sala antes de generar la URL
- **Sin acceso directo a MinIO:** el bucket no es accesible desde fuera del clúster K8s — el motor es el único que genera URLs pre-firmadas

---

## 7. Módulos Rust del pipeline

```
bchat-engine/src/media/
├── mod.rs          # Re-exporta tipos públicos
├── upload.rs       # Manejo upload_init + upload_confirm
├── presign.rs      # Generación de URLs pre-firmadas MinIO (aws-sdk-s3 Rust SDK)
├── thumbnail.rs    # Worker pool para generación de thumbnails
└── limits.rs       # Verificación de límites por tier KYC
```

---

*BNOTIFY-034 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*Los archivos binarios nunca pasan por el motor — el motor solo firma URLs. El motor maneja metadatos; MinIO maneja bytes.*
