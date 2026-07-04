# Manual JSON-RPC — Parte 7: Arquitectura Híbrida e Integración con Servicios Externos

> **Parte de:** Manual JSON-RPC (ver Partes 1–6 para fundamentos, autenticación, CRUD, cadenas de eventos, arquitectura del servidor y manejo de errores)  
> **Audiencia:** Arquitectos y desarrolladores que necesitan integrar un sistema JSON-RPC con servicios externos (fiscales, bancarios, logísticos, etc.) que usan protocolos distintos (SOAP, REST, XML).

---

## Tabla de Contenidos

1. [¿Puede una aplicación ser 100% JSON-RPC?](#1-puede-una-aplicación-ser-100-json-rpc)
2. [Cuándo se necesita una arquitectura híbrida](#2-cuándo-se-necesita-una-arquitectura-híbrida)
3. [El Patrón Adaptador](#3-el-patrón-adaptador)
4. [Manejo de Archivos Binarios](#4-manejo-de-archivos-binarios)
5. [Caso de Estudio: Integración con el SIN de Bolivia (SIAT)](#5-caso-de-estudio-integración-con-el-sin-de-bolivia-siat)
6. [Implementación del Adaptador SIAT en cuatro lenguajes](#6-implementación-del-adaptador-siat-en-cuatro-lenguajes)
7. [Operaciones Asíncronas y Contingencia](#7-operaciones-asíncronas-y-contingencia)
8. [Límites y Optimización de Mensajes](#8-límites-y-optimización-de-mensajes)
9. [Soberanía de las Comunicaciones Externas](#9-soberanía-de-las-comunicaciones-externas)
10. [Lista de Verificación para Integraciones Externas](#10-lista-de-verificación-para-integraciones-externas)

---

## 1. ¿Puede una aplicación ser 100% JSON-RPC?

**Sí, completamente.** Para la lógica interna de negocio, una aplicación puede operar con un único endpoint HTTP (`POST /rpc/`) que concentra toda la comunicación. No hay ningún requisito técnico o arquitectónico que obligue a mezclar REST y JSON-RPC para las operaciones propias del sistema.

Las ventajas de un modelo 100% JSON-RPC interno son:

- **Un solo punto de entrada.** Los clientes (web, móvil, integraciones nocturnas) saben que todo pasa por `POST /rpc/`. No hay que memorizar rutas distintas.
- **Batch nativo.** JSON-RPC 2.0 permite enviar múltiples operaciones en un solo request HTTP, lo que reduce la latencia en flujos complejos.
- **Consistencia.** Autenticación, manejo de errores, contexto y logging siguen exactamente el mismo patrón en cada llamada, sin excepciones.
- **Trazabilidad por `id`.** Cada llamada tiene un identificador correlacionable en los logs, lo que facilita la auditoría y el debugging.

### Limitaciones del modelo puro que se deben conocer

| Limitación | Descripción | Solución recomendada |
|------------|-------------|----------------------|
| Caché HTTP | Todo es `POST`, por lo que los proxies y navegadores no cachean automáticamente | Implementar caché en el servidor (ver Parte 5) |
| Archivos binarios grandes | Incrustar archivos en Base64 infla los mensajes hasta ~33% | URLs de descarga temporal (ver Sección 4) |
| Integración con sistemas externos | Los sistemas fiscales, bancarios o de logística usan SOAP, REST o XML, no JSON-RPC | Patrón Adaptador (ver Sección 3) |
| Documentación estandarizada | No existe un equivalente a OpenAPI/Swagger para JSON-RPC | Implementar `system.listMethods` y `system.methodHelp` (ver Parte 6) |

---

## 2. Cuándo se necesita una arquitectura híbrida

Una arquitectura **puramente JSON-RPC** cubre toda la lógica de negocio interna. La necesidad de un diseño híbrido surge cuando la aplicación debe comunicarse con **sistemas externos que no hablan JSON-RPC**:

```
Sistema de facturación fiscal  → SOAP/XML
Pasarela de pagos              → REST con OAuth2
Operadora de telefonía         → XML-RPC propietario
Sistema bancario               → ISO 20022 / SOAP
Servicio de mensajería (email) → SMTP / REST
Almacenamiento de archivos     → HTTP presigned URLs (S3, MinIO)
```

La regla es clara: **JSON-RPC hacia adentro, adaptadores hacia afuera**. El motor central nunca conoce el protocolo externo; eso es responsabilidad exclusiva del adaptador.

```
┌────────────────────────────────────────────────────────────────┐
│                    CLIENTES                                    │
│   Web App  │  App Móvil  │  Script nocturno  │  Otro sistema  │
└─────────────────────────┬──────────────────────────────────────┘
                          │  POST /rpc/  (JSON-RPC)
                          ▼
┌────────────────────────────────────────────────────────────────┐
│                  CAPA JSON-RPC (Parte 5)                       │
│         Dispatcher │ Autenticación │ Permisos │ Logging        │
└──────────────────────────────┬─────────────────────────────────┘
                               │
                               ▼
┌────────────────────────────────────────────────────────────────┐
│               MOTOR DE NEGOCIO (Dominio puro)                  │
│    Modelos │ Servicios │ Validaciones │ Máquinas de estado     │
└────┬───────────────────────────────────────────────┬───────────┘
     │  llama a                                      │  llama a
     ▼                                               ▼
┌──────────────┐                           ┌─────────────────────┐
│  Adaptador   │                           │  Adaptador          │
│  SIN (SIAT)  │                           │  Pasarela de pagos  │
│  SOAP/XML    │                           │  REST + OAuth2      │
└──────┬───────┘                           └──────────┬──────────┘
       │                                              │
       ▼                                              ▼
  SIN Bolivia                                  Banco / Fintech
  (sistema externo)                            (sistema externo)
```

---

## 3. El Patrón Adaptador

El patrón adaptador es la solución arquitectónica central para las integraciones externas. Consiste en una clase o módulo que:

1. Recibe datos en el formato del dominio interno (Python dicts, structs de Go, etc.)
2. Los traduce al formato del sistema externo (XML para SOAP, JSON para REST, etc.)
3. Ejecuta la comunicación con el sistema externo
4. Traduce la respuesta externa de vuelta al formato del dominio interno
5. Maneja los errores propios del sistema externo y los convierte en errores del dominio

### Anatomía de un adaptador

```
┌───────────────────────────────────────────────────────┐
│                   ADAPTADOR                           │
│                                                       │
│  Entrada (desde el dominio)                           │
│  ──────────────────────────────────────────────────   │
│  Datos en formato interno: dicts, objetos, IDs        │
│                                                       │
│  Traducción salida                                    │
│  ──────────────────────────────────────────────────   │
│  Construir payload externo (XML, JSON, form-data)     │
│  Agregar autenticación (token, API key, HMAC)         │
│  Serializar (lxml, requests, zeep, etc.)              │
│                                                       │
│  Comunicación                                         │
│  ──────────────────────────────────────────────────   │
│  HTTP(S) con reintentos y timeout                     │
│  Manejo de errores de red y del sistema externo       │
│                                                       │
│  Traducción entrada                                   │
│  ──────────────────────────────────────────────────   │
│  Parsear respuesta externa                            │
│  Extraer campos relevantes                            │
│  Convertir a formato del dominio                      │
│                                                       │
│  Salida (hacia el dominio)                            │
│  ──────────────────────────────────────────────────   │
│  Datos en formato interno: dicts, objetos, IDs        │
└───────────────────────────────────────────────────────┘
```

### Principios del adaptador bien diseñado

**Aislamiento total.** El motor de negocio no importa nada de `zeep`, `lxml`, `requests` ni ninguna librería de comunicación externa. Si el sistema externo cambia su protocolo, solo se modifica el adaptador.

**Contrato estable.** El adaptador expone una interfaz simple y tipada hacia el dominio. La complejidad del protocolo externo queda encapsulada adentro.

**Testeable con mocks.** El adaptador tiene una interfaz que puede ser reemplazada por un mock en los tests del dominio, sin necesidad de conectarse al sistema externo real.

**Sin estado.** El adaptador no almacena estado entre llamadas (excepto configuración como tokens y URLs). El estado vive en el motor de dominio.

---

## 4. Manejo de Archivos Binarios

JSON-RPC no tiene un mecanismo estándar para transferir archivos binarios eficientemente. La estrategia correcta depende del tamaño:

### Estrategia por tamaño

| Tamaño del archivo | Estrategia | Implementación |
|-------------------|------------|----------------|
| < 100 KB | Base64 dentro del JSON | Incluir directamente en `result` |
| 100 KB – 10 MB | URL de descarga temporal | Servidor de archivos separado + token firmado |
| > 10 MB | Streaming directo HTTP | Endpoint REST dedicado para descarga |

### Patrón URL de descarga temporal (recomendado)

El cliente recibe una URL que apunta directamente al archivo. La URL tiene un tiempo de expiración corto (15–60 minutos) y se invalida después:

```json
{
  "id": 20,
  "result": {
    "numero_factura": "F-2025-001234",
    "pdf_url": "https://archivos.miapp.com/facturas/F-2025-001234.pdf?token=eyJ...&exp=1735689600",
    "xml_url": "https://archivos.miapp.com/facturas/F-2025-001234.xml?token=eyJ...&exp=1735689600",
    "qr_base64": "data:image/png;base64,iVBORw0KGgo...",
    "expires_in": 3600
  },
  "error": null
}
```

El QR se envía en Base64 porque es pequeño (< 5 KB). El PDF y el XML se sirven vía URL porque pueden crecer con el tiempo.

### Generación de URLs temporales firmadas (Python)

```python
import hmac
import hashlib
import time
import base64
import os

SECRET = os.environ["FILES_SECRET_KEY"]

def generar_url_firmada(ruta_archivo: str, ttl_segundos: int = 3600) -> str:
    """Genera una URL con firma HMAC que expira en ttl_segundos."""
    expiracion = int(time.time()) + ttl_segundos
    mensaje    = f"{ruta_archivo}:{expiracion}"
    firma      = hmac.new(SECRET.encode(), mensaje.encode(), hashlib.sha256).hexdigest()
    token      = base64.urlsafe_b64encode(f"{expiracion}:{firma}".encode()).decode()
    return f"https://archivos.miapp.com/{ruta_archivo}?token={token}"

def verificar_url_firmada(ruta_archivo: str, token: str) -> bool:
    """Verifica que el token sea válido y no haya expirado."""
    try:
        decoded    = base64.urlsafe_b64decode(token.encode()).decode()
        expiracion, firma_recibida = decoded.split(":", 1)
        if int(time.time()) > int(expiracion):
            return False  # Expirado
        mensaje     = f"{ruta_archivo}:{expiracion}"
        firma_esp   = hmac.new(SECRET.encode(), mensaje.encode(), hashlib.sha256).hexdigest()
        return hmac.compare_digest(firma_esp, firma_recibida)
    except Exception:
        return False
```

### Endpoint de descarga (Flask)

```python
# servidor/archivos.py — endpoint REST dedicado SOLO para descarga de archivos
from flask import Flask, send_file, abort, request

app_archivos = Flask(__name__)

@app_archivos.route("/archivos/<path:ruta>")
def descargar(ruta):
    token = request.args.get("token", "")
    if not verificar_url_firmada(ruta, token):
        abort(403)
    ruta_absoluta = f"/var/archivos/{ruta}"
    return send_file(ruta_absoluta)
```

Este endpoint de descarga es REST, pero **no forma parte de la API de negocio**. Es infraestructura de transporte de archivos, igual que un CDN. Los clientes nunca lo llaman directamente; solo siguen las URLs que les devuelve el servidor JSON-RPC.

---

## 5. Caso de Estudio: Integración con el SIN de Bolivia (SIAT)

### El sistema de facturación electrónica boliviano

El Servicio de Impuestos Nacionales (SIN) de Bolivia opera el **SIAT** (Sistema Integrado de la Administración Tributaria), plataforma que gestiona la facturación electrónica obligatoria para empresas bolivianas. En 2024, el 76% de las facturas emitidas en Bolivia se generaron mediante modalidades electrónicas en línea, lo que hace que esta integración sea crítica para cualquier sistema de gestión empresarial en el país.

#### Modalidades de facturación

Las facturas electrónicas deben emitirse en formato XML y contar con un Código Único de Facturación Diaria (CUFD) emitido por el SIN. Existen distintos tipos de comprobantes, entre ellos: facturas con o sin derecho a crédito fiscal, notas de crédito y débito como documentos de ajuste, y hasta 27 tipos específicos de facturas sectoriales, como exportaciones, hidrocarburos, telecomunicaciones, servicios básicos, turismo y sector educativo.

| Modalidad | Descripción | Firma digital |
|-----------|-------------|---------------|
| **Electrónica en Línea** | Envío en tiempo real, factura firmada digitalmente | Obligatoria (PKCS#12) |
| **Computarizada en Línea** | Envío individual o por lotes al SIAT | No requerida |
| **Portal Web en Línea** | Emisión manual desde el portal del SIN | No requerida |

#### Códigos clave del SIAT

El CUFD (Código Único de Facturación Diaria) habilita la emisión de documentos fiscales durante 24 horas. El CUIS (Código Único de Inicio de Sistemas) vincula al contribuyente con su sistema de facturación autorizado. El CUF (Código Único de Factura) individualiza cada comprobante emitido.

#### Protocolo técnico del SIAT

Los servicios del SIAT exponen operaciones SOAP para: solicitud de CUFD, solicitud de CUIS, verificación de NIT, registro de puntos de venta, cierre de operaciones, recepción y anulación de facturas. Es decir, el SIN habla **SOAP con XML**, no JSON-RPC ni REST.

El flujo técnico para emitir una factura electrónica en línea es:

```
[Tu sistema] → solicitar CUIS (una vez, al iniciar el sistema)
               → cada 24h: solicitar CUFD al SIAT
               → por cada factura:
                   1. Generar XML con estructura definida por el SIN
                   2. Calcular CUF (algoritmo propio del SIN)
                   3. Firmar digitalmente el XML (PKCS#12)
                   4. Enviar al SIAT vía SOAP (RecepcionFactura)
                   5. Recibir código de recepción
                   6. Validar estado con el código de recepción
               → guardar PDF + XML + metadatos en tu BD
```

### El desafío de la integración

Tu sistema interno habla JSON-RPC. El SIN habla SOAP. La solución es el adaptador:

```
                    Tu sistema (JSON-RPC interno)
                              │
                    model.factura.emitir([301])
                              │
                              ▼
                    ServicioFacturas.emitir()
                              │
                    llama a AdaptadorSIAT.emitir_factura()
                              │
              ┌───────────────┼───────────────────┐
              │               │                   │
              ▼               ▼                   ▼
       Construir XML    Firmar con         Llamar a SOAP
       según esquema    certificado        RecepcionFactura
       XSD del SIN      PKCS#12            del SIAT
              │               │                   │
              └───────────────┼───────────────────┘
                              │
                    Respuesta del SIAT
                    (código de recepción + estado)
                              │
                              ▼
                    Guardar factura + PDF + XML
                    en BD y sistema de archivos
                              │
                              ▼
                    Devolver al cliente JSON-RPC:
                    {numero_factura, pdf_url, cuf}
```

### Catálogo de métodos JSON-RPC para facturación

El dominio expone métodos limpios al cliente. La complejidad del SIAT queda completamente oculta:

| Método JSON-RPC | Descripción | Devuelve |
|-----------------|-------------|---------|
| `model.factura.emitir` | Emite una factura ante el SIAT | `{numero, cuf, pdf_url, xml_url, qr_base64}` |
| `model.factura.anular` | Anula una factura ante el SIAT | `true` |
| `model.factura.consultar` | Consulta el estado de una factura | `{estado, fecha, observaciones}` |
| `model.factura.reenviar` | Reenvía la factura al correo del cliente | `true` |
| `model.factura.search_read` | Busca facturas con filtros | `[{...}]` |
| `wizard.facturacion_masiva.create` | Inicia facturación masiva de un lote | `{session_id}` |
| `wizard.facturacion_masiva.execute` | Ejecuta un paso del lote | `{progreso, errores}` |

### Estructura del XML de factura (esquema simplificado)

El SIN exige un XML con estructura específica validada por XSD:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<facturaComputarizadaCompraVenta
    xsi:noNamespaceSchemaLocation="facturaComputarizadaCompraVenta.xsd"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <cabecera>
    <nitEmisor>1003579028</nitEmisor>
    <razonSocialEmisor>Mi Empresa S.R.L.</razonSocialEmisor>
    <municipio>La Paz</municipio>
    <telefono>22220000</telefono>
    <numeroFactura>1</numeroFactura>
    <cuf>44AAEC00DBD34C53C3E2CCE1A3FA7AF1E2A08606A667A75AC82F24C74</cuf>
    <cufd>BQUE+QytqQUDBKVUFOSVRPQkxVRFZNVFVJBMDAwMDAwM</cufd>
    <codigoSucursal>0</codigoSucursal>
    <direccion>Av. Mariscal Santa Cruz 1392</direccion>
    <nitComprador>987654321</nitComprador>
    <razonSocialComprador>Cliente XYZ</razonSocialComprador>
    <codigoTipoDocumentoIdentidad>1</codigoTipoDocumentoIdentidad>
    <complemento/>
    <codigoCliente>CLI-001</codigoCliente>
    <codigoMetodoPago>1</codigoMetodoPago>
    <montoTotal>1500.00</montoTotal>
    <montoTotalSujetoIva>1500.00</montoTotalSujetoIva>
    <codigoMoneda>1</codigoMoneda>
    <tipoCambio>1.00</tipoCambio>
    <montoTotalMoneda>1500.00</montoTotalMoneda>
    <fechaEmision>2025-12-01T14:30:00.000</fechaEmision>
    <usuario>ANA</usuario>
    <codigoDocumentoSector>1</codigoDocumentoSector>
    <leyenda>Ley N° 453 ...</leyenda>
  </cabecera>
  <detalle>
    <actividadEconomica>620000</actividadEconomica>
    <codigoProductoSin>89120</codigoProductoSin>
    <codigoProducto>LAP-001</codigoProducto>
    <descripcion>Laptop Pro X</descripcion>
    <cantidad>2</cantidad>
    <unidadMedida>58</unidadMedida>
    <precioUnitario>750.00</precioUnitario>
    <montoDescuento>0.00</montoDescuento>
    <subTotal>1500.00</subTotal>
  </detalle>
</facturaComputarizadaCompraVenta>
```

---

## 6. Implementación del Adaptador SIAT en cuatro lenguajes

### Python

```python
# adaptadores/siat_adaptador.py
#
# Responsabilidad única: traducir entre el dominio interno y el SIAT.
# No conoce nada de JSON-RPC, Flask, ni de ninguna otra capa.

import hashlib
import hmac
import os
import base64
import time
from dataclasses import dataclass
from typing import Optional
from lxml import etree
import requests


@dataclass
class ResultadoEmision:
    numero_factura: str
    cuf:            str
    codigo_recepcion: str
    pdf_url:        str
    xml_url:        str
    qr_base64:      str


@dataclass
class ErrorSIAT(Exception):
    codigo:  str
    mensaje: str
    reintentable: bool = False


class AdaptadorSIAT:
    """
    Adaptador para el SIAT de Bolivia (Servicio de Impuestos Nacionales).
    Encapsula SOAP, XML, firma digital y códigos CUFD/CUIS/CUF.
    """

    SIAT_URL_PROD  = "https://pilotosiatservicios.impuestos.gob.bo/v2/FacturacionSincronizacion"
    SIAT_URL_PILOT = "https://pilotosiatservicios.impuestos.gob.bo/v2/FacturacionSincronizacion"

    def __init__(self, nit: str, token: str, cert_path: str,
                 cert_password: str, modo_piloto: bool = True):
        self.nit          = nit
        self.token        = token
        self.cert_path    = cert_path
        self.cert_password = cert_password
        self.url          = self.SIAT_URL_PILOT if modo_piloto else self.SIAT_URL_PROD
        self._cufd        = None
        self._cufd_expira = 0
        self._cuis        = None
        self._session     = requests.Session()
        self._session.headers.update({
            "Content-Type": "text/xml; charset=utf-8",
            "apikey":       self.token,
        })

    # ── Gestión de códigos ─────────────────────────────────────────────────

    def obtener_cuis(self) -> str:
        """Obtiene el CUIS (Código Único de Inicio de Sistema). Se renueva anualmente."""
        if self._cuis:
            return self._cuis

        soap = self._envolver_soap("SolicitudCUIS", f"""
            <SolicitudCUIS>
                <codigoAmbiente>2</codigoAmbiente>
                <codigoModalidad>2</codigoModalidad>
                <codigoSistema>MISISTEMAV1</codigoSistema>
                <nit>{self.nit}</nit>
                <codigoSucursal>0</codigoSucursal>
                <codigoPuntoVenta>0</codigoPuntoVenta>
            </SolicitudCUIS>
        """)
        respuesta = self._llamar_soap(soap, "solicitudCUIS")
        self._cuis = respuesta.findtext(".//cuis")
        return self._cuis

    def obtener_cufd(self) -> str:
        """Obtiene el CUFD (Código Único de Facturación Diaria). Válido 24 horas."""
        if self._cufd and time.time() < self._cufd_expira:
            return self._cufd

        cuis = self.obtener_cuis()
        soap = self._envolver_soap("SolicitudCUFD", f"""
            <SolicitudCUFD>
                <codigoAmbiente>2</codigoAmbiente>
                <codigoModalidad>2</codigoModalidad>
                <cuis>{cuis}</cuis>
                <nit>{self.nit}</nit>
                <codigoSucursal>0</codigoSucursal>
                <codigoPuntoVenta>0</codigoPuntoVenta>
            </SolicitudCUFD>
        """)
        respuesta = self._llamar_soap(soap, "solicitudCUFD")
        self._cufd        = respuesta.findtext(".//codigo")
        self._cufd_expira = time.time() + 23 * 3600  # 23h (margen de seguridad)
        return self._cufd

    # ── Operaciones de facturación ─────────────────────────────────────────

    def emitir_factura(self, datos: dict) -> ResultadoEmision:
        """
        Emite una factura ante el SIAT.

        datos = {
            "nit_comprador":     str,
            "razon_social":      str,
            "numero_factura":    int,
            "fecha_emision":     datetime,
            "lineas": [{"descripcion": str, "cantidad": float,
                        "precio_unit": float, "codigo_sin": str}],
            ...
        }
        """
        cufd = self.obtener_cufd()
        cuf  = self._calcular_cuf(datos, cufd)

        # 1. Construir XML
        xml_str = self._construir_xml(datos, cufd, cuf)

        # 2. Calcular hash del XML
        hash_xml = hashlib.sha256(xml_str.encode("utf-8")).hexdigest().upper()

        # 3. Comprimir y codificar en Base64
        import gzip
        xml_gz  = gzip.compress(xml_str.encode("utf-8"))
        xml_b64 = base64.b64encode(xml_gz).decode()

        # 4. Enviar al SIAT
        soap = self._envolver_soap("RecepcionFactura", f"""
            <RecepcionFactura>
                <SolicitudServicioRecepcionFactura>
                    <codigoAmbiente>2</codigoAmbiente>
                    <codigoDocumentoSector>1</codigoDocumentoSector>
                    <codigoEmision>1</codigoEmision>
                    <codigoModalidad>2</codigoModalidad>
                    <codigoSistema>MISISTEMAV1</codigoSistema>
                    <codigoSucursal>0</codigoSucursal>
                    <nit>{self.nit}</nit>
                    <cuis>{self.obtener_cuis()}</cuis>
                    <cufd>{cufd}</cufd>
                    <codigoPuntoVenta>0</codigoPuntoVenta>
                    <fechaEnvio>{datos['fecha_emision'].strftime('%Y-%m-%dT%H:%M:%S.000')}</fechaEnvio>
                    <archivo>{xml_b64}</archivo>
                    <hashArchivo>{hash_xml}</hashArchivo>
                    <tipoFacturaDocumento>1</tipoFacturaDocumento>
                </SolicitudServicioRecepcionFactura>
            </RecepcionFactura>
        """)
        resp = self._llamar_soap(soap, "recepcionFactura")
        estado = resp.findtext(".//codigoEstado")
        codigo_recepcion = resp.findtext(".//codigoRecepcion") or ""

        if estado not in ("901",):  # 901 = aceptado por el SIAT
            descripcion = resp.findtext(".//descripcion") or "Error desconocido del SIAT"
            raise ErrorSIAT(codigo=estado, mensaje=descripcion,
                            reintentable=estado in ("1000", "1001"))

        # 5. Guardar y generar URLs (integración con almacenamiento)
        pdf_url = self._guardar_y_firmar(f"facturas/{cuf}.pdf",
                                         self._generar_pdf(xml_str, cuf))
        xml_url = self._guardar_y_firmar(f"facturas/{cuf}.xml", xml_str.encode())
        qr_b64  = self._generar_qr(cuf)

        return ResultadoEmision(
            numero_factura   = str(datos["numero_factura"]),
            cuf              = cuf,
            codigo_recepcion = codigo_recepcion,
            pdf_url          = pdf_url,
            xml_url          = xml_url,
            qr_base64        = qr_b64,
        )

    def anular_factura(self, cuf: str, codigo_motivo: int) -> bool:
        """Anula una factura ante el SIAT."""
        cufd = self.obtener_cufd()
        soap = self._envolver_soap("AnulacionFactura", f"""
            <AnulacionFactura>
                <SolicitudServicioAnulacionFactura>
                    <codigoAmbiente>2</codigoAmbiente>
                    <codigoModalidad>2</codigoModalidad>
                    <codigoSistema>MISISTEMAV1</codigoSistema>
                    <codigoSucursal>0</codigoSucursal>
                    <nit>{self.nit}</nit>
                    <cuis>{self.obtener_cuis()}</cuis>
                    <cufd>{cufd}</cufd>
                    <codigoPuntoVenta>0</codigoPuntoVenta>
                    <cuf>{cuf}</cuf>
                    <codigoMotivo>{codigo_motivo}</codigoMotivo>
                </SolicitudServicioAnulacionFactura>
            </AnulacionFactura>
        """)
        resp   = self._llamar_soap(soap, "anulacionFactura")
        estado = resp.findtext(".//codigoEstado")
        return estado == "908"  # 908 = anulación aceptada

    # ── Helpers internos ───────────────────────────────────────────────────

    def _calcular_cuf(self, datos: dict, cufd: str) -> str:
        """Calcula el CUF según el algoritmo del SIN."""
        partes = [
            self.nit,
            datos["fecha_emision"].strftime("%Y%m%d%H%M%S") + "000",
            "0",   # sucursal
            "0",   # punto de venta
            "2",   # modalidad computarizada
            "1",   # tipo documento sector
            str(datos["numero_factura"]).zfill(10),
            "1",   # tipo emision
            "1",   # tipo factura documento
            cufd[:50],
        ]
        contenido = "".join(partes)
        suma      = sum(contenido.encode("utf-8"))
        return contenido + str(suma % 97).zfill(2)

    def _construir_xml(self, datos: dict, cufd: str, cuf: str) -> str:
        total = sum(l["cantidad"] * l["precio_unit"] for l in datos["lineas"])
        lineas_xml = ""
        for linea in datos["lineas"]:
            subtotal = linea["cantidad"] * linea["precio_unit"]
            lineas_xml += f"""
            <detalle>
                <actividadEconomica>{datos.get('actividad_economica', '620000')}</actividadEconomica>
                <codigoProductoSin>{linea['codigo_sin']}</codigoProductoSin>
                <codigoProducto>{linea.get('codigo_interno', 'SIN-COD')}</codigoProducto>
                <descripcion>{linea['descripcion']}</descripcion>
                <cantidad>{linea['cantidad']}</cantidad>
                <unidadMedida>58</unidadMedida>
                <precioUnitario>{linea['precio_unit']:.2f}</precioUnitario>
                <montoDescuento>0.00</montoDescuento>
                <subTotal>{subtotal:.2f}</subTotal>
            </detalle>"""

        return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<facturaComputarizadaCompraVenta
    xsi:noNamespaceSchemaLocation="facturaComputarizadaCompraVenta.xsd"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <cabecera>
    <nitEmisor>{self.nit}</nitEmisor>
    <razonSocialEmisor>{datos['razon_social_emisor']}</razonSocialEmisor>
    <municipio>{datos.get('municipio', 'La Paz')}</municipio>
    <telefono>{datos.get('telefono', '')}</telefono>
    <numeroFactura>{datos['numero_factura']}</numeroFactura>
    <cuf>{cuf}</cuf>
    <cufd>{cufd}</cufd>
    <codigoSucursal>0</codigoSucursal>
    <direccion>{datos.get('direccion', '')}</direccion>
    <nitComprador>{datos['nit_comprador']}</nitComprador>
    <razonSocialComprador>{datos['razon_social']}</razonSocialComprador>
    <codigoTipoDocumentoIdentidad>1</codigoTipoDocumentoIdentidad>
    <complemento/>
    <codigoCliente>{datos.get('codigo_cliente', '')}</codigoCliente>
    <codigoMetodoPago>{datos.get('metodo_pago', 1)}</codigoMetodoPago>
    <montoTotal>{total:.2f}</montoTotal>
    <montoTotalSujetoIva>{total:.2f}</montoTotalSujetoIva>
    <codigoMoneda>1</codigoMoneda>
    <tipoCambio>1.00</tipoCambio>
    <montoTotalMoneda>{total:.2f}</montoTotalMoneda>
    <fechaEmision>{datos['fecha_emision'].strftime('%Y-%m-%dT%H:%M:%S.000')}</fechaEmision>
    <usuario>{datos.get('usuario', 'SISTEMA')}</usuario>
    <codigoDocumentoSector>1</codigoDocumentoSector>
    <leyenda>Ley N° 453: El proveedor de servicios debe habilitar medios e instrumentos de pago.</leyenda>
  </cabecera>
  {lineas_xml}
</facturaComputarizadaCompraVenta>"""

    def _envolver_soap(self, accion: str, cuerpo: str) -> str:
        return f"""<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope
    xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:sin="https://siat.impuestos.gob.bo/">
  <soapenv:Header/>
  <soapenv:Body>
    {cuerpo}
  </soapenv:Body>
</soapenv:Envelope>"""

    def _llamar_soap(self, soap_str: str, accion: str):
        try:
            resp = self._session.post(
                self.url, data=soap_str.encode("utf-8"),
                headers={"SOAPAction": accion}, timeout=30
            )
            resp.raise_for_status()
            return etree.fromstring(resp.content)
        except requests.Timeout:
            raise ErrorSIAT("TIMEOUT", "El SIAT no respondió a tiempo.", reintentable=True)
        except requests.RequestException as e:
            raise ErrorSIAT("RED", f"Error de red al conectar con el SIAT: {e}", reintentable=True)

    def _guardar_y_firmar(self, ruta: str, contenido: bytes) -> str:
        ruta_absoluta = f"/var/archivos/{ruta}"
        os.makedirs(os.path.dirname(ruta_absoluta), exist_ok=True)
        with open(ruta_absoluta, "wb") as f:
            f.write(contenido)
        return generar_url_firmada(ruta)

    def _generar_pdf(self, xml_str: str, cuf: str) -> bytes:
        # Implementar con WeasyPrint, ReportLab o similar
        # Devuelve bytes del PDF
        raise NotImplementedError("Integrar librería de generación de PDF")

    def _generar_qr(self, cuf: str) -> str:
        # Implementar con qrcode
        # Devuelve base64 de la imagen PNG
        raise NotImplementedError("Integrar librería de generación de QR")
```

### Integración en el catálogo RPC

```python
# rpc/catalogos/facturacion.py

from rpc.registro import registro, DescriptorRPC
from adaptadores.siat_adaptador import AdaptadorSIAT, ErrorSIAT

class CatalogoFacturacion:
    def __init__(self, servicio_facturas, adaptador_siat: AdaptadorSIAT):
        self.svc     = servicio_facturas
        self.adaptador = adaptador_siat
        self._registrar()

    def _registrar(self):
        defs = [
            ("model.factura.emitir",    self.emitir,    False, ["ventas", "admin"]),
            ("model.factura.anular",    self.anular,    False, ["admin"]),
            ("model.factura.consultar", self.consultar,  True,  ["ventas", "admin"]),
            ("model.factura.reenviar",  self.reenviar,  False, ["ventas", "admin"]),
        ]
        for nombre, func, solo_lectura, perms in defs:
            registro.registrar(nombre, DescriptorRPC(
                funcion=func, solo_lectura=solo_lectura, permisos=perms
            ))

    def emitir(self, params, ctx):
        factura_id = params[0][0]
        factura    = self.svc.obtener(factura_id)

        try:
            resultado = self.adaptador.emitir_factura(factura.to_dict_siat())
        except ErrorSIAT as e:
            if e.reintentable:
                raise ValueError(f"El SIAT no está disponible temporalmente. Reintente en unos minutos. ({e.codigo})")
            raise ValueError(f"Error al emitir la factura: {e.mensaje}")

        self.svc.marcar_emitida(factura_id, resultado)
        return {
            "numero_factura": resultado.numero_factura,
            "cuf":            resultado.cuf,
            "pdf_url":        resultado.pdf_url,
            "xml_url":        resultado.xml_url,
            "qr_base64":      resultado.qr_base64,
        }

    def anular(self, params, ctx):
        factura_id    = params[0][0]
        codigo_motivo = params[1].get("motivo", 1) if len(params) > 1 else 1
        factura       = self.svc.obtener(factura_id)

        ok = self.adaptador.anular_factura(factura.cuf, codigo_motivo)
        if ok:
            self.svc.marcar_anulada(factura_id)
        return ok
```

---

### Go — estructura del adaptador

```go
package siat

import (
    "bytes"
    "crypto/sha256"
    "encoding/base64"
    "encoding/xml"
    "fmt"
    "net/http"
    "time"
)

type AdaptadorSIAT struct {
    NIT      string
    Token    string
    URL      string
    cufd     string
    cufdExp  time.Time
    client   *http.Client
}

type ResultadoEmision struct {
    NumeroFactura    string
    CUF              string
    CodigoRecepcion  string
    PDFURL           string
    XMLURL           string
    QRBase64         string
}

type ErrorSIAT struct {
    Codigo        string
    Mensaje       string
    Reintentable  bool
}
func (e *ErrorSIAT) Error() string { return fmt.Sprintf("[SIAT %s] %s", e.Codigo, e.Mensaje) }

func NuevoAdaptador(nit, token string, piloto bool) *AdaptadorSIAT {
    url := "https://pilotosiatservicios.impuestos.gob.bo/v2/FacturacionSincronizacion"
    if !piloto {
        url = "https://siatservicios.impuestos.gob.bo/v2/FacturacionSincronizacion"
    }
    return &AdaptadorSIAT{
        NIT:    nit,
        Token:  token,
        URL:    url,
        client: &http.Client{Timeout: 30 * time.Second},
    }
}

func (a *AdaptadorSIAT) ObtenerCUFD() (string, error) {
    if a.cufd != "" && time.Now().Before(a.cufdExp) {
        return a.cufd, nil
    }
    // ... llamada SOAP a SolicitudCUFD
    // Actualizar a.cufd y a.cufdExp
    return a.cufd, nil
}

func (a *AdaptadorSIAT) EmitirFactura(datos map[string]interface{}) (*ResultadoEmision, error) {
    cufd, err := a.ObtenerCUFD()
    if err != nil {
        return nil, err
    }
    cuf    := a.calcularCUF(datos, cufd)
    xmlStr := a.construirXML(datos, cufd, cuf)
    hash   := fmt.Sprintf("%X", sha256.Sum256([]byte(xmlStr)))

    // Comprimir y codificar
    xmlB64 := base64.StdEncoding.EncodeToString([]byte(xmlStr))

    // Llamar SOAP RecepcionFactura
    estado, codigoRecepcion, err := a.llamarRecepcionFactura(xmlB64, hash, cufd)
    if err != nil {
        return nil, err
    }
    if estado != "901" {
        return nil, &ErrorSIAT{Codigo: estado, Mensaje: "SIAT no aceptó la factura",
                                Reintentable: estado == "1000" || estado == "1001"}
    }

    return &ResultadoEmision{
        NumeroFactura:   fmt.Sprintf("%v", datos["numero_factura"]),
        CUF:             cuf,
        CodigoRecepcion: codigoRecepcion,
        PDFURL:          a.guardarYFirmar(fmt.Sprintf("facturas/%s.pdf", cuf), []byte{}),
        XMLURL:          a.guardarYFirmar(fmt.Sprintf("facturas/%s.xml", cuf), []byte(xmlStr)),
    }, nil
}

func (a *AdaptadorSIAT) llamarSOAP(soap, accion string) ([]byte, error) {
    req, _ := http.NewRequest("POST", a.URL, bytes.NewBufferString(soap))
    req.Header.Set("Content-Type", "text/xml; charset=utf-8")
    req.Header.Set("SOAPAction", accion)
    req.Header.Set("apikey", a.Token)

    resp, err := a.client.Do(req)
    if err != nil {
        return nil, &ErrorSIAT{Codigo: "RED", Mensaje: err.Error(), Reintentable: true}
    }
    defer resp.Body.Close()
    var buf bytes.Buffer
    buf.ReadFrom(resp.Body)
    return buf.Bytes(), nil
}

// calcularCUF, construirXML, llamarRecepcionFactura, guardarYFirmar...
// (implementaciones análogas al ejemplo Python)
```

---

## 7. Operaciones Asíncronas y Contingencia

### Facturación masiva (wizard asíncrono)

Cuando se emiten cientos de facturas en un solo proceso (cierre de mes, facturación recurrente), la operación no puede ser síncrona. Se usa el patrón wizard con estado intermedio:

```json
// Paso 1: iniciar el lote
{"id": 1, "method": "wizard.facturacion_masiva.create",
 "params": [[], {"company": 1}]}
→ {"result": {"session_id": "lote-abc123", "total_facturas": 147}}

// Paso 2: confirmar y lanzar
{"id": 2, "method": "wizard.facturacion_masiva.execute",
 "params": [{"session_id": "lote-abc123"}, {"confirmar": true}, "procesar", {}]}
→ {"result": {"estado": "procesando", "procesadas": 0, "errores": 0}}

// Paso 3: consultar progreso (polling cada 5s)
{"id": 3, "method": "wizard.facturacion_masiva.execute",
 "params": [{"session_id": "lote-abc123"}, {}, "estado", {}]}
→ {"result": {"estado": "procesando", "procesadas": 73, "errores": 2}}

// Paso 4: resultado final
{"id": 4, "method": "wizard.facturacion_masiva.execute",
 "params": [{"session_id": "lote-abc123"}, {}, "estado", {}]}
→ {"result": {
     "estado": "completado",
     "procesadas": 147, "errores": 2,
     "facturas_ok":  [3001, 3002, ..., 3145],
     "facturas_err": [{"id": 3050, "error": "NIT inválido"},
                      {"id": 3098, "error": "CUFD expirado"}]
   }}
```

### Modo contingencia del SIAT

El SIAT puede no estar disponible (mantenimiento, fallas). El SIN contempla un **modo de contingencia** donde las facturas se emiten localmente y se sincronizan después:

```
MODO NORMAL
  Factura → [SIAT en tiempo real] → código de recepción → guardar

MODO CONTINGENCIA (SIAT no disponible)
  Factura → guardar localmente con estado "pendiente_siat"
           → [cuando SIAT vuelva] → sincronizar lote
           → [SIAT acepta] → actualizar estado a "aceptada"
```

Método JSON-RPC para verificar el estado de conectividad:

```json
{"id": 1, "method": "common.siat.estado", "params": []}
→ {"result": {"disponible": false, "modo": "contingencia",
              "pendientes_sincronizar": 12,
              "ultimo_intento": "2025-12-01T03:45:00"}}
```

---

## 8. Límites y Optimización de Mensajes

### Tamaños recomendados

No existe un límite estándar en la especificación JSON-RPC. El límite real lo impone la configuración del servidor web y del proxy inverso:

| Tipo de mensaje | Tamaño recomendado | Configuración Nginx |
|-----------------|-------------------|---------------------|
| Petición típica (CRUD) | < 50 KB | `client_max_body_size 1m` |
| Petición con archivos pequeños (QR, firma) | < 500 KB | `client_max_body_size 2m` |
| Respuesta con lista grande | < 5 MB | `proxy_buffer_size 128k` |
| Respuesta máxima absoluta | < 10 MB | `client_max_body_size 25m` |
| Archivos binarios (PDF, XML) | Usar URLs | Servir desde endpoint de archivos |

### Compresión Gzip (reducción de hasta 88%)

Habilitar compresión en el servidor reduce drásticamente el ancho de banda para respuestas de listas:

```nginx
# nginx.conf
gzip on;
gzip_types application/json text/plain;
gzip_min_length 1024;
gzip_comp_level 6;
```

En el cliente, indicar que acepta compresión:

```python
headers["Accept-Encoding"] = "gzip, br"
# requests descomprime automáticamente
```

### Batch requests para reducir roundtrips

En lugar de 3 llamadas independientes, una sola petición HTTP con batch:

```json
[
  {"jsonrpc": "2.0", "id": 1, "method": "model.cliente.read",
   "params": [[5], ["nombre", "nit"]]},
  {"jsonrpc": "2.0", "id": 2, "method": "model.venta.search_read",
   "params": [[["cliente", "=", 5]], ["numero", "estado", "total"], 0, 10, null]},
  {"jsonrpc": "2.0", "id": 3, "method": "model.factura.search_read",
   "params": [[["cliente", "=", 5]], ["numero_factura", "cuf", "pdf_url"], 0, 5, null]}
]
```

Respuesta (array, no necesariamente en orden):

```json
[
  {"id": 1, "result": [{"id": 5, "nombre": "Empresa ABC", "nit": "123456789"}], "error": null},
  {"id": 3, "result": [{"id": 301, "numero_factura": "F-001", "cuf": "44AA...", "pdf_url": "..."}], "error": null},
  {"id": 2, "result": [{"id": 101, "numero": "V-001", "estado": "confirmada", "total": "1500.00"}], "error": null}
]
```

---

## 9. Soberanía de las Comunicaciones Externas

El ecosistema JSON-RPC define un contrato uniforme hacia adentro — todos los motores hablan el mismo protocolo entre sí y con los clientes. Pero **hacia afuera, cada motor es soberano de sus propias integraciones externas**. Esta soberanía no es opcional: es una regla de diseño que evita dependencias cruzadas y garantiza que los errores de un sistema externo solo afecten al motor responsable.

### La regla

**Ningún motor puede asumir la responsabilidad de la comunicación externa de otro motor.**

Cada motor conoce exactamente un conjunto de sistemas externos con los que debe hablar, y ese conjunto es exclusivo e intransferible:

```
bTax (sistema de facturación)
  └── Es el ÚNICO motor que habla con el SIN / SIAT / AFIP / SAT
      Ningún otro motor llama directamente al servicio de impuestos.
      Ningún otro motor conoce el protocolo SOAP del SIAT.
      Ningún otro motor tiene las credenciales del certificado digital fiscal.

Tryton (ERP)
  └── Es el ÚNICO motor que crea comprobantes contables.
      Ningún otro motor escribe asientos en el libro mayor.
      Ningún otro motor conoce el plan de cuentas contable.

OrangeHRM (RRHH)
  └── Es el ÚNICO motor que crea y gestiona empleados.
      Ningún otro motor escribe directamente en el sistema de RRHH.
      Ningún otro motor conoce la estructura de contratos laborales.
```

### Cómo se ve esto en la práctica

Cuando la cadena de una venta necesita emitir una factura fiscal, el motor ERP no llama al SIAT directamente. Llama al método JSON-RPC del motor de facturación:

```
Motor ERP (Tryton)                Motor bTax
  model.factura.post([301])  →    Recibe el llamado JSON-RPC
                                  Ejecuta internamente:
                                    1. Construir XML según esquema SIAT
                                    2. Firmar con certificado digital
                                    3. Enviar POST SOAP al SIN
                                    4. Recibir código de autorización
                                    5. Persistir resultado
                              →   Devuelve: {cuf, pdf_url, xml_url}
  Recibe respuesta limpia
  Almacena el CUF en la venta
```

El motor ERP solo ve la respuesta JSON-RPC. No sabe nada del protocolo SOAP, del formato XML del SIAT, ni del certificado digital. Esa complejidad es propiedad exclusiva de bTax.

### Por qué esta separación es crítica

Si el motor ERP llamara directamente al SIAT, ocurriría lo siguiente:

- Una actualización del protocolo SIAT requeriría modificar el ERP, no solo el motor fiscal.
- Las credenciales del certificado digital tendrían que estar en dos lugares.
- Un error en la comunicación fiscal contaminaría los logs del ERP con errores de SOAP.
- La lógica de contingencia fiscal (operar sin conexión al SIAT) tendría que estar implementada en el ERP.

Con la soberanía respetada, cada uno de esos problemas queda completamente contenido en el motor responsable.

### La respuesta JSON-RPC oculta la complejidad

Desde el punto de vista del cliente que llama, **el protocolo externo es invisible**. La respuesta siempre tiene el mismo formato JSON-RPC, sin importar qué ocurrió internamente para producirla:

```json
{
  "id": 10,
  "result": {
    "cuf": "44AA3B2C1D0E9F8G7H6I5J4K3L2M1N0",
    "pdf_url": "https://archivos.miapp.com/facturas/F-001.pdf?token=...",
    "xml_url": "https://archivos.miapp.com/facturas/F-001.xml?token=...",
    "qr_base64": "iVBORw0KGgo..."
  },
  "error": null
}
```

No hay rastro de SOAP, XML, certificados ni reintentos en esa respuesta. El motor fiscal absorbió toda esa complejidad y devolvió un resultado limpio en el contrato estándar.

### Adición a la lista de verificación

---

## 10. Lista de Verificación para Integraciones Externas

### Soberanía de la integración

- [ ] Este motor es el **único** responsable de comunicarse con los sistemas externos que le corresponden.
- [ ] Ningún otro motor del ecosistema llama directamente a los sistemas externos de este motor.
- [ ] Las credenciales del sistema externo (certificados, API keys, tokens) están exclusivamente en este motor.
- [ ] La lógica de contingencia (operar sin conexión al sistema externo) está implementada en este motor, no en sus clientes.

### Diseño del adaptador

- [ ] El adaptador tiene una interfaz definida (clase abstracta o protocolo) que el dominio conoce.
- [ ] El dominio **no importa** librerías de comunicación externa (`zeep`, `lxml`, `requests`, etc.).
- [ ] El adaptador puede ser reemplazado por un mock en los tests sin modificar el dominio.
- [ ] Los errores del sistema externo se traducen a errores del dominio (no se propagan como excepciones raw).
- [ ] Los errores reintentables están marcados explícitamente.

### Gestión de tokens y credenciales del sistema externo

- [ ] Las credenciales del sistema externo (API keys, tokens, certificados) están en variables de entorno, no en el código.
- [ ] El CUIS se renueva según el ciclo del sistema externo (anualmente para el SIAT).
- [ ] El CUFD se renueva automáticamente antes de expirar (cada 24h para el SIAT).
- [ ] Los tokens se almacenan en memoria o en caché con TTL, no en base de datos.

### Archivos binarios

- [ ] Los archivos > 100 KB se sirven vía URLs temporales firmadas, no en Base64.
- [ ] Las URLs firmadas tienen tiempo de expiración corto (15–60 minutos).
- [ ] El endpoint de descarga de archivos valida la firma antes de servir el archivo.
- [ ] Los archivos se almacenan fuera del servidor de aplicación (volumen, S3, MinIO).

### Contingencia y resiliencia

- [ ] El sistema detecta cuando el servicio externo no está disponible.
- [ ] Existe un modo de contingencia que permite operar sin el servicio externo.
- [ ] Las operaciones pendientes de sincronizar se registran en base de datos.
- [ ] Existe un proceso de sincronización que se ejecuta cuando el servicio externo vuelve.

### Producción

- [ ] Los timeouts de las llamadas al sistema externo son explícitos (no infinitos).
- [ ] Hay reintentos con backoff exponencial para errores transitorios.
- [ ] Cada llamada al sistema externo se loguea con duración, estado y código de respuesta.
- [ ] Hay alertas si el sistema externo falla más de N veces en M minutos.

---

## Referencia: Flujo completo de venta con facturación SIAT

Este es el flujo end-to-end que integra la cadena de venta (Parte 4) con la emisión de factura ante el SIAT:

```
[1]  Login
      │
[2]  Buscar cliente (verifica NIT ante SIAT si es nuevo)
      │
[3]  model.venta.create → [borrador]
      │
[4]  model.venta.quote  → [cotizacion]
      │
[5]  model.venta.confirm → [confirmada]
      │
[6]  model.venta.process → [en_proceso]
      │                      (genera envío y factura en borrador)
      │
[7]  model.venta.read → {envios: [201], facturas: [301]}
      │
[8]  model.envio.assign / pack / done → envío entregado
      │
[9]  model.factura.post → [publicada]
      │
[10] model.factura.emitir → llama AdaptadorSIAT.emitir_factura()
      │                        → XML firmado al SIAT
      │                        → código de recepción
      │                        → PDF + XML guardados
      │                        → URLs firmadas generadas
      │                     → {cuf, pdf_url, xml_url, qr_base64}
      │
[11] model.factura.pay → [pagada]
      │
[12] Logout
```

El cliente JSON-RPC nunca sabe que existe el SIAT. Solo invoca `model.factura.emitir` y recibe las URLs del PDF y el QR. Toda la complejidad del protocolo SOAP, los códigos CUFD/CUIS/CUF y la firma digital está encapsulada en el adaptador.

---

*Continúa en la Parte 8: Ecosistema y Estrategia de Adopción.*

---

## Índice de todos los documentos del manual

| Documento | Contenido |
|-----------|-----------|
| `JSON-RPC-01-fundamentos.md` | Qué es JSON-RPC, estructura del mensaje, convenciones, transporte HTTP |
| `JSON-RPC-02-autenticacion.md` | Login, tokens, headers de autorización, logout, implementaciones en 4 lenguajes |
| `JSON-RPC-03-crud-contexto.md` | Contexto de ejecución, create/read/write/delete/search, relaciones, ejemplos en 4 lenguajes |
| `JSON-RPC-04-cadena-eventos.md` | Eslabones, máquinas de estado, flujo completo de venta, wizards, reportes |
| `JSON-RPC-05-arquitectura-servidor.md` | Motor de dominio, capas, dispatcher, registro de métodos, servidores en 4 lenguajes |
| `JSON-RPC-06-errores-produccion.md` | Tipos de error, manejo por lenguaje, reintentos, seguridad, logging, checklist |
| `JSON-RPC-07-arquitectura-hibrida-integraciones.md` | Arquitectura híbrida, patrón adaptador, archivos binarios, integración SIAT Bolivia |
| `JSON-RPC-08-ecosistema-y-estrategia-de-adopcion.md` | Filosofía de ecosistema, motores puros, Tryton nativo, apps nuevas, Fachada-RPC para legados |
| `JSON-RPC-09-orquestacion-multi-motor.md` | Motor de orquestación, flujos multi-motor, saga con compensación, contexto distribuido, 4 lenguajes |

---

*Manual JSON-RPC — Diseño, Implementación e Integración*  
*Versión 2.0 — Aplicable a cualquier sistema que adopte JSON-RPC como protocolo de comunicación*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
