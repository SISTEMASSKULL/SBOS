# Manual JSON-RPC — Parte 9: Motor de Orquestación Multi-Motor

> **Parte de:** Manual JSON-RPC (ver Partes 1–8 para fundamentos, autenticación, CRUD, cadenas de eventos, arquitectura del servidor, manejo de errores, integraciones externas y estrategia de ecosistema)  
> **Audiencia:** Arquitectos y desarrolladores que necesitan coordinar flujos de negocio que cruzan múltiples motores JSON-RPC del ecosistema descrito en la Parte 8.

---

## Tabla de Contenidos

1. [Del motor único al ecosistema coordinado](#1-del-motor-único-al-ecosistema-coordinado)
2. [El Motor de Orquestación como cuarto tipo de componente](#2-el-motor-de-orquestación-como-cuarto-tipo-de-componente)
3. [Diseño de un flujo multi-motor](#3-diseño-de-un-flujo-multi-motor)
4. [El Patrón Saga: consistencia sin transacciones distribuidas](#4-el-patrón-saga-consistencia-sin-transacciones-distribuidas)
5. [Definición declarativa de flujos](#5-definición-declarativa-de-flujos)
6. [Propagación del contexto entre motores](#6-propagación-del-contexto-entre-motores)
7. [Implementación del orquestador en cuatro lenguajes](#7-implementación-del-orquestador-en-cuatro-lenguajes)
8. [El flujo completo: alta de empleado en el ecosistema](#8-el-flujo-completo-alta-de-empleado-en-el-ecosistema)
9. [Exposición del orquestador como motor JSON-RPC](#9-exposición-del-orquestador-como-motor-json-rpc)
10. [Lista de verificación para flujos multi-motor](#10-lista-de-verificación-para-flujos-multi-motor)

---

## 1. Del motor único al ecosistema coordinado

Las partes anteriores de este manual construyeron dos tipos de componentes: **motores** que procesan lógica de negocio (Partes 3–6) y **adaptadores** que traducen hacia sistemas externos (Partes 7–8). El ecosistema de la Parte 8 muestra cómo varios motores coexisten, cada uno con su propio endpoint `/rpc/` y su propio catálogo de métodos.

El problema que esta parte resuelve aparece en cuanto hay más de un motor: **muchos flujos de negocio reales no caben dentro de uno solo**.

Dar de alta a un empleado nuevo no es una sola llamada a un solo motor. Es una secuencia que involucra al menos tres:

```
Motor RRHH (Fachada OrangeHRM)  →  crear registro del empleado
Motor ERP  (Tryton)              →  registrar el empleado en contabilidad
Motor Proyectos (Cat. B)         →  asignar capacidad al equipo
```

Sin coordinación, ese flujo queda en manos del cliente: él llama a los tres motores en orden, y si el tercero falla, los dos primeros ya completaron su trabajo sin posibilidad de reversión.

La **cadena de eventos** de la Parte 4 resuelve la coordinación dentro de un solo motor. El **motor de orquestación** extiende ese mismo concepto al ecosistema completo.

---

## 2. El Motor de Orquestación como cuarto tipo de componente

El ecosistema de la Parte 8 tiene tres tipos de componentes:

```
Categoría A  →  Motor nativo JSON-RPC (Tryton)
Categoría B  →  Motor nuevo bajo este manual
Categoría C  →  Fachada-RPC sobre sistema legado
```

El motor de orquestación es el **cuarto tipo**:

```
Categoría D  →  Motor de Orquestación
               Coordina flujos que cruzan varios motores A/B/C.
               Expone esos flujos como métodos JSON-RPC hacia los clientes.
               Los clientes no saben cuántos motores internos están involucrados.
```

```
┌────────────────────────────────────────────────────────────┐
│                      CLIENTES                              │
│   Web App  │  App Móvil  │  Script nocturno  │  Agente IA  │
└────────────────────────┬───────────────────────────────────┘
                         │  POST /rpc/  ← un solo punto de entrada
                         ▼
┌────────────────────────────────────────────────────────────┐
│             MOTOR DE ORQUESTACIÓN  (Cat. D)                │
│                                                            │
│  flujo.empleado.alta(...)      ← el cliente llama esto     │
│  flujo.cierre_mes.ejecutar(...)                            │
│  flujo.pedido.aprobar(...)                                 │
└──────┬──────────────────┬───────────────────┬──────────────┘
       │ JSON-RPC          │ JSON-RPC           │ JSON-RPC
       ▼                   ▼                    ▼
┌────────────┐    ┌─────────────────┐    ┌────────────────┐
│  TRYTON    │    │  FACHADA-RPC    │    │  PROYECTOS     │
│  (Cat. A)  │    │  OrangeHRM      │    │  (Cat. B)      │
│  :8000     │    │  (Cat. C) :8003 │    │  :8002         │
└────────────┘    └─────────────────┘    └────────────────┘
```

### Principio de transparencia

El cliente no sabe que existen tres motores internos. Llama a `flujo.empleado.alta` exactamente igual que llama a `model.venta.confirm` en Tryton: mismo patrón, misma autenticación, mismo formato de contexto. La complejidad de la coordinación queda encapsulada en el orquestador.

---

## 3. Diseño de un flujo multi-motor

Un flujo multi-motor es una secuencia de llamadas JSON-RPC a motores distintos, donde la salida de cada paso alimenta la entrada del siguiente.

### La cadena extendida al ecosistema

La Parte 4 definió la cadena dentro de un motor:

```
Eslabón 1 → Eslabón 2 → Eslabón 3
  mismo motor, misma sesión, misma base de datos
```

La cadena multi-motor sigue la misma lógica, pero cada eslabón vive en un motor diferente:

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUJO MULTI-MOTOR                        │
│                                                             │
│  Paso 1                                                     │
│  ─────────────────────────────────────────────────────────  │
│  Motor: Fachada-RPC RRHH                                    │
│  Método: model.empleado.create                              │
│  Entrada: datos del empleado                                │
│  Salida: empleado_id = 42                                   │
│                                                             │
│  Paso 2                                                     │
│  ─────────────────────────────────────────────────────────  │
│  Motor: Tryton (ERP)                                        │
│  Método: model.hr.employee.create                           │
│  Entrada: datos del empleado + empleado_id de paso 1        │
│  Salida: erp_empleado_id = 1042                             │
│                                                             │
│  Paso 3                                                     │
│  ─────────────────────────────────────────────────────────  │
│  Motor: Sistema de Proyectos                                │
│  Método: model.recurso.asignar                              │
│  Entrada: erp_empleado_id + equipo destino                  │
│  Salida: true                                               │
└─────────────────────────────────────────────────────────────┘
```

### Dependencias entre pasos

No todos los pasos son secuenciales. Algunos pueden ejecutarse en paralelo si no dependen entre sí:

```
Paso 1: Fachada RRHH  ──────────────────────────────► ✓ empleado_id = 42
                                                           │
Paso 2: Tryton ERP    ──────────────────────────────► ✓   │ (no depende del paso 1)
                                                           │
Paso 3: Proyectos     ← depende de paso 1 y paso 2 ───────┘
```

El orquestador determina qué pasos pueden ejecutarse en paralelo analizando las dependencias declaradas. Reduce la latencia total del flujo sin que el desarrollador tenga que gestionar hilos manualmente.

---

## 4. El Patrón Saga: consistencia sin transacciones distribuidas

Cuando el paso 3 de un flujo de tres pasos falla, los pasos 1 y 2 ya completaron su trabajo. No existe un `ROLLBACK` distribuido que los revierta automáticamente como lo haría una transacción de base de datos.

La solución es el **Patrón Saga**: cada paso que puede completarse define también un paso de **compensación** que lo deshace. Si el flujo falla en el paso N, el orquestador ejecuta las compensaciones de los pasos anteriores en orden inverso.

### Flujo exitoso vs flujo compensado

```
FLUJO EXITOSO:
  Paso 1 ✓  →  Paso 2 ✓  →  Paso 3 ✓
  RRHH           ERP          Proyectos
  id=42          id=1042      true

FLUJO CON FALLO EN PASO 3:
  Paso 1 ✓  →  Paso 2 ✓  →  Paso 3 ✗
  RRHH           ERP          Proyectos
  id=42          id=1042      TIMEOUT

  El orquestador inicia compensación en orden inverso:

  ← Compensar Paso 2: model.hr.employee.delete([1042])    ✓
  ← Compensar Paso 1: model.empleado.delete([42])         ✓

  Estado final: COMPENSADO
  El sistema queda como si el flujo nunca hubiera ocurrido.
```

### Requisitos de las compensaciones

**Las compensaciones deben ser idempotentes.** Si la red falla en medio de una compensación y se reintenta, el resultado debe ser el mismo que si se ejecutó una sola vez:

```
✓  model.empleado.delete([42])
   → Si ya fue borrado: devuelve true (idempotente)
   → Si existe: lo borra y devuelve true
```

**Las compensaciones operan sobre el output del paso, no sobre los inputs originales.** El orquestador almacenó el ID devuelto por el paso; la compensación lo usa directamente:

```
Paso 1 devolvió: empleado_id = 42
Compensación del paso 1: model.empleado.delete([42])  ← usa el ID almacenado
```

**Los pasos de notificación generalmente no tienen compensación.** Enviar un correo o publicar en un chat son operaciones irreversibles. Se marcan con `on_failure: continue` para que su fallo no aborte el flujo completo.

---

## 5. Definición declarativa de flujos

La forma más mantenible de definir un flujo multi-motor es en un archivo de configuración que describe **qué** debe ocurrir, no **cómo** ejecutarlo. El orquestador se encarga del cómo.

### Estructura de un flujo

```yaml
# flujos/empleado-alta.yml

id: empleado-alta
nombre: "Alta de Empleado en el Ecosistema"
version: "1.0.0"

# Parámetros que el cliente debe enviar al invocar el flujo
entrada:
  nombre:    {tipo: string,  requerido: true}
  apellido:  {tipo: string,  requerido: true}
  cargo_id:  {tipo: integer, requerido: true}
  equipo_id: {tipo: integer, requerido: true}

# Política de reintentos global (sobreescribible por paso)
reintentos:
  max_intentos: 3
  espera_inicial_ms: 500
  tipo: exponencial

pasos:
  - id: crear-en-rrhh
    motor: fachada-rrhh
    metodo: model.empleado.create
    params:
      - nombre:   "{{entrada.nombre}}"
        apellido: "{{entrada.apellido}}"
        cargo_id: "{{entrada.cargo_id}}"
    guardar_como: empleado_id
    compensar:
      metodo: model.empleado.delete
      params: ["{{empleado_id}}"]

  - id: registrar-en-erp
    motor: tryton
    metodo: model.hr.employee.create
    depende_de: crear-en-rrhh
    params:
      - name:    "{{entrada.nombre}} {{entrada.apellido}}"
        company: "{{ctx.company}}"
    guardar_como: erp_empleado_id
    compensar:
      metodo: model.hr.employee.delete
      params: ["{{erp_empleado_id}}"]

  - id: asignar-a-equipo
    motor: proyectos
    metodo: model.recurso.asignar
    depende_de: [crear-en-rrhh, registrar-en-erp]
    params:
      - empleado_id: "{{empleado_id}}"
        equipo_id:   "{{entrada.equipo_id}}"
    compensar:
      metodo: model.recurso.desasignar
      params: ["{{empleado_id}}", "{{entrada.equipo_id}}"]

  - id: notificar-equipo
    motor: mensajeria
    metodo: model.mensaje.enviar
    depende_de: asignar-a-equipo
    params:
      - canal: "incorporaciones"
        texto: "Nuevo integrante: {{entrada.nombre}} {{entrada.apellido}}"
    on_failure: continue   # si falla la notificación, el flujo no se aborta
```

### Variables disponibles en las plantillas

| Variable | Fuente |
|----------|--------|
| `{{entrada.<campo>}}` | Parámetros enviados por el cliente al iniciar el flujo |
| `{{ctx.<campo>}}` | Contexto de ejecución: `company`, `language`, `employee`, etc. |
| `{{<guardar_como>}}` | Output de un paso previo declarado con `guardar_como` |

### Políticas ante fallo

| Política | Comportamiento |
|----------|----------------|
| `abort` (por defecto) | El paso falla → detener el flujo e iniciar compensación |
| `continue` | El paso falla → seguir con el siguiente paso sin compensar |
| `skip` | El paso falla → omitir silenciosamente y seguir |

---

## 6. Propagación del contexto entre motores

El contexto de ejecución definido en la Parte 3 — `company`, `language`, `timezone`, `employee` — debe viajar sin modificación desde el cliente hasta cada motor que el orquestador invoca.

### Por qué el contexto no debe cambiar en el orquestador

El contexto representa **el entorno en el que el usuario está operando** cuando inició el flujo. Si el usuario opera en la empresa 1, todos los motores que participan en su flujo deben operar en la empresa 1. El orquestador no enriquece ni modifica el contexto: lo propaga literalmente.

```
Cliente envía:
  {"language": "es_BO", "company": 1, "employee": 7}
                              │
                    Orquestador recibe y almacena
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
  Tryton recibe:      Fachada RRHH recibe:  Proyectos recibe:
  {"language": "es_BO",  {"language": "es_BO", {"language": "es_BO",
   "company": 1,          "company": 1,          "company": 1,
   "employee": 7}         "employee": 7}         "employee": 7}
```

### La sesión del orquestador con cada motor

El orquestador tiene su propia sesión de servicio con cada motor, distinta de la sesión del usuario final. Esta separación es necesaria porque:

- El orquestador actúa en nombre del usuario, pero usa credenciales de servicio para autenticarse con cada motor.
- La sesión del usuario final solo existe entre el cliente y el orquestador.
- El contexto del usuario se propaga como dato dentro del llamado, no como sesión.

```
Cliente ──────► Orquestador ──────► Motor A
  sesión:          sesión:             sesión:
  usuario=ana      servicio=orq        servicio=orq
                   token=xxxx          token=yyyy (token del orquestador en Motor A)
                   ctx={company:1,     ctx={company:1,
                        employee:7}         employee:7}  ← propagado del cliente
```

---

## 7. Implementación del orquestador en cuatro lenguajes

La implementación completa del orquestador sigue exactamente la arquitectura de tres capas de la Parte 5: dominio, exposición RPC y transporte. La diferencia es que el "dominio" del orquestador es la ejecución de flujos, no entidades de negocio.

### Python

```python
# orquestador/dominio/motor_flujos.py

import json
import re
import time
import uuid
import concurrent.futures
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Optional

import requests


class Estado(str, Enum):
    EJECUTANDO   = "ejecutando"
    COMPLETADO   = "completado"
    FALLIDO      = "fallido"
    COMPENSANDO  = "compensando"
    COMPENSADO   = "compensado"


@dataclass
class EjecucionFlujo:
    id:          str = field(default_factory=lambda: str(uuid.uuid4()))
    flujo_id:    str = ""
    estado:      Estado = Estado.EJECUTANDO
    ctx:         dict = field(default_factory=dict)
    variables:   dict = field(default_factory=dict)  # inputs + outputs acumulados
    pasos_ok:    list = field(default_factory=list)   # pasos completados (para compensar)
    error:       Optional[str] = None


class MotorFlujos:
    """
    Motor de orquestación. Ejecuta flujos multi-motor definidos en YAML.
    Cada flujo es un DAG de pasos; cada paso es una llamada JSON-RPC a un motor.
    """

    def __init__(self, motores: dict, repositorio, sesiones_servicio: dict):
        """
        motores:           {"tryton": "https://erp.miempresa.com/produccion/",
                            "fachada-rrhh": "https://fachada-rrhh.miempresa.com/rpc/"}
        repositorio:       persiste ejecuciones en BD
        sesiones_servicio: {"tryton": (uid, token), "fachada-rrhh": (uid, token)}
        """
        self.motores            = motores
        self.repositorio        = repositorio
        self.sesiones_servicio  = sesiones_servicio

    # ── Punto de entrada público ──────────────────────────────────────────

    def ejecutar(self, definicion: dict, params: dict, ctx: dict) -> EjecucionFlujo:
        """Inicia la ejecución de un flujo. Bloqueante hasta completar o compensar."""
        self._validar_entrada(definicion.get("entrada", {}), params)

        ejec = EjecucionFlujo(
            flujo_id  = definicion["id"],
            ctx       = ctx,
            variables = dict(params),  # los params de entrada son las primeras variables
        )
        self.repositorio.guardar(ejec)

        try:
            self._ejecutar_grafo(ejec, definicion["pasos"])
            ejec.estado = Estado.COMPLETADO
        except Exception as e:
            ejec.estado = Estado.FALLIDO
            ejec.error  = str(e)
            self._compensar(ejec)

        self.repositorio.guardar(ejec)
        return ejec

    # ── Ejecución del grafo de pasos ──────────────────────────────────────

    def _ejecutar_grafo(self, ejec: EjecucionFlujo, pasos: list):
        """Ejecuta los pasos en el orden correcto respetando dependencias."""
        completados = set()
        pendientes  = list(pasos)

        while pendientes:
            # Pasos listos: todas sus dependencias ya completaron
            listos = [
                p for p in pendientes
                if all(dep in completados
                       for dep in (p.get("depende_de") or [])
                       if dep)  # normaliza string o lista
            ]

            if not listos:
                raise RuntimeError("Ciclo en el grafo de dependencias — revisar el flujo.")

            # Ejecutar en paralelo los pasos que están listos
            if len(listos) == 1:
                self._ejecutar_paso(ejec, listos[0])
            else:
                with concurrent.futures.ThreadPoolExecutor(max_workers=len(listos)) as pool:
                    futuros = {pool.submit(self._ejecutar_paso, ejec, p): p for p in listos}
                    for futuro in concurrent.futures.as_completed(futuros):
                        futuro.result()  # propaga excepciones

            for p in listos:
                completados.add(p["id"])
                pendientes.remove(p)

    def _ejecutar_paso(self, ejec: EjecucionFlujo, paso: dict):
        """Ejecuta un paso con reintentos. Almacena el output en ejec.variables."""
        max_intentos   = paso.get("reintentos", {}).get("max_intentos", 3)
        espera_ms      = paso.get("reintentos", {}).get("espera_inicial_ms", 500)
        ultimo_error   = None

        for intento in range(1, max_intentos + 1):
            try:
                params_resueltos = self._resolver(paso.get("params", [{}]), ejec)
                resultado = self._llamar_rpc(
                    motor   = paso["motor"],
                    metodo  = paso["metodo"],
                    params  = params_resueltos,
                    ctx     = ejec.ctx,
                )
                if paso.get("guardar_como"):
                    ejec.variables[paso["guardar_como"]] = resultado
                ejec.pasos_ok.append(paso)
                return
            except Exception as e:
                ultimo_error = e
                if intento < max_intentos:
                    time.sleep(espera_ms * (2 ** (intento - 1)) / 1000)

        politica = paso.get("on_failure", "abort")
        if politica == "abort":
            raise RuntimeError(
                f"Paso '{paso['id']}' en motor '{paso['motor']}' falló "
                f"tras {max_intentos} intentos: {ultimo_error}"
            )
        # continue o skip: no lanzar excepción, el flujo sigue

    # ── Compensación ──────────────────────────────────────────────────────

    def _compensar(self, ejec: EjecucionFlujo):
        """Ejecuta las compensaciones en orden inverso."""
        ejec.estado = Estado.COMPENSANDO
        self.repositorio.guardar(ejec)

        for paso in reversed(ejec.pasos_ok):
            comp = paso.get("compensar")
            if not comp:
                continue
            try:
                params_resueltos = self._resolver(comp.get("params", []), ejec)
                self._llamar_rpc(
                    motor  = paso["motor"],
                    metodo = comp["metodo"],
                    params = params_resueltos,
                    ctx    = ejec.ctx,
                )
            except Exception as e:
                # Loguear y continuar — nunca abortar la compensación
                print(f"ADVERTENCIA: compensación del paso '{paso['id']}' falló: {e}")

        ejec.estado = Estado.COMPENSADO

    # ── Llamada JSON-RPC a un motor ───────────────────────────────────────

    def _llamar_rpc(self, motor: str, metodo: str, params: list, ctx: dict) -> Any:
        url      = self.motores[motor]
        uid, tok = self.sesiones_servicio[motor]

        import base64
        cred = base64.b64encode(f"orquestador:{uid}:{tok}".encode()).decode()

        body = {
            "id":     str(uuid.uuid4()),
            "method": metodo,
            "params": params + [ctx],  # ctx siempre al final, como establece la Parte 3
        }
        resp = requests.post(
            url,
            json    = body,
            headers = {
                "Content-Type":  "application/json",
                "Authorization": f"Basic {cred}",
            },
            timeout = 30,
        )

        if resp.status_code == 401:
            raise RuntimeError(f"Sesión expirada con motor '{motor}' — renovar credenciales.")

        data = resp.json()
        if data.get("error"):
            raise RuntimeError(data["error"]["message"])
        return data["result"]

    # ── Resolución de plantillas ──────────────────────────────────────────

    def _resolver(self, params: Any, ejec: EjecucionFlujo) -> list:
        """Sustituye {{variable}} por su valor en ejec.variables o ejec.ctx."""
        texto = json.dumps(params)

        def reemplazar(match):
            expr = match.group(1).strip()
            if expr.startswith("ctx."):
                return str(ejec.ctx.get(expr[4:], ""))
            return str(ejec.variables.get(expr, match.group(0)))

        return json.loads(re.sub(r'\{\{([^}]+)\}\}', reemplazar, texto))

    # ── Validación de entrada ─────────────────────────────────────────────

    def _validar_entrada(self, esquema: dict, params: dict):
        for campo, reglas in esquema.items():
            if reglas.get("requerido") and campo not in params:
                raise ValueError(f"Parámetro requerido ausente: '{campo}'")
```

### Go

```go
// orquestador/dominio/motor.go

package dominio

import (
    "encoding/base64"
    "encoding/json"
    "fmt"
    "strings"
    "sync"
    "time"

    "github.com/google/uuid"
)

type Estado string
const (
    Ejecutando  Estado = "ejecutando"
    Completado  Estado = "completado"
    Fallido     Estado = "fallido"
    Compensando Estado = "compensando"
    Compensado  Estado = "compensado"
)

type EjecucionFlujo struct {
    ID        string            `json:"id"`
    FlujoID   string            `json:"flujo_id"`
    Estado    Estado            `json:"estado"`
    Ctx       map[string]any    `json:"ctx"`
    Variables map[string]any    `json:"variables"`
    PasosOK   []Paso            `json:"-"`
    Error     string            `json:"error,omitempty"`
}

type MotorFlujos struct {
    motores           map[string]string       // nombre → URL
    repositorio       Repositorio
    sesionesServicio  map[string][2]string    // nombre → [uid, token]
    cliente           *http.Client
    mu                sync.Mutex              // protege Variables en ejecución paralela
}

func NuevoMotor(motores map[string]string, repo Repositorio, sesiones map[string][2]string) *MotorFlujos {
    return &MotorFlujos{
        motores:          motores,
        repositorio:      repo,
        sesionesServicio: sesiones,
        cliente:          &http.Client{Timeout: 30 * time.Second},
    }
}

func (m *MotorFlujos) Ejecutar(def Definicion, params, ctx map[string]any) (*EjecucionFlujo, error) {
    if err := def.ValidarEntrada(params); err != nil {
        return nil, err
    }

    variables := make(map[string]any)
    for k, v := range params { variables[k] = v }

    ejec := &EjecucionFlujo{
        ID:        uuid.New().String(),
        FlujoID:   def.ID,
        Estado:    Ejecutando,
        Ctx:       ctx,
        Variables: variables,
    }
    m.repositorio.Guardar(ejec)

    if err := m.ejecutarGrafo(ejec, def.Pasos); err != nil {
        ejec.Estado = Fallido
        ejec.Error  = err.Error()
        m.compensar(ejec)
    } else {
        ejec.Estado = Completado
    }

    m.repositorio.Guardar(ejec)
    return ejec, nil
}

func (m *MotorFlujos) ejecutarGrafo(ejec *EjecucionFlujo, pasos []Paso) error {
    completados := make(map[string]bool)
    pendientes  := append([]Paso{}, pasos...)

    for len(pendientes) > 0 {
        var listos []Paso
        for _, p := range pendientes {
            if m.dependenciasListas(p, completados) {
                listos = append(listos, p)
            }
        }
        if len(listos) == 0 {
            return fmt.Errorf("ciclo en el grafo de dependencias del flujo '%s'", ejec.FlujoID)
        }

        if err := m.ejecutarEnParalelo(ejec, listos); err != nil {
            return err
        }

        marcados := make(map[string]bool)
        for _, p := range listos { marcados[p.ID] = true; completados[p.ID] = true }

        var resto []Paso
        for _, p := range pendientes {
            if !marcados[p.ID] { resto = append(resto, p) }
        }
        pendientes = resto
    }
    return nil
}

func (m *MotorFlujos) ejecutarEnParalelo(ejec *EjecucionFlujo, pasos []Paso) error {
    if len(pasos) == 1 {
        return m.ejecutarPaso(ejec, pasos[0])
    }

    var wg    sync.WaitGroup
    errores  := make(chan error, len(pasos))

    for _, paso := range pasos {
        wg.Add(1)
        go func(p Paso) {
            defer wg.Done()
            if err := m.ejecutarPaso(ejec, p); err != nil {
                errores <- err
            }
        }(paso)
    }

    wg.Wait()
    close(errores)

    for err := range errores {
        return err  // devolver el primero
    }
    return nil
}

func (m *MotorFlujos) ejecutarPaso(ejec *EjecucionFlujo, paso Paso) error {
    maxIntentos := 3
    if paso.Reintentos.MaxIntentos > 0 { maxIntentos = paso.Reintentos.MaxIntentos }
    espera := 500 * time.Millisecond

    var lastErr error
    for intento := 1; intento <= maxIntentos; intento++ {
        m.mu.Lock()
        params, err := resolver(paso.Params, ejec.Variables, ejec.Ctx)
        m.mu.Unlock()
        if err != nil { return fmt.Errorf("paso '%s': %w", paso.ID, err) }

        resultado, err := m.llamarRPC(paso.Motor, paso.Metodo, params, ejec.Ctx)
        if err == nil {
            m.mu.Lock()
            if paso.GuardarComo != "" { ejec.Variables[paso.GuardarComo] = resultado }
            ejec.PasosOK = append(ejec.PasosOK, paso)
            m.mu.Unlock()
            return nil
        }

        lastErr = err
        if intento < maxIntentos { time.Sleep(espera); espera *= 2 }
    }

    if paso.OnFailure == "abort" || paso.OnFailure == "" {
        return fmt.Errorf("paso '%s' falló: %w", paso.ID, lastErr)
    }
    return nil  // continue / skip
}

func (m *MotorFlujos) compensar(ejec *EjecucionFlujo) {
    ejec.Estado = Compensando
    m.repositorio.Guardar(ejec)

    for i := len(ejec.PasosOK) - 1; i >= 0; i-- {
        paso := ejec.PasosOK[i]
        if paso.Compensar == nil { continue }

        m.mu.Lock()
        params, err := resolver(paso.Compensar.Params, ejec.Variables, ejec.Ctx)
        m.mu.Unlock()
        if err != nil { continue }

        m.llamarRPC(paso.Motor, paso.Compensar.Metodo, params, ejec.Ctx)
        // errores de compensación se ignoran — loguear pero continuar
    }
    ejec.Estado = Compensado
}

func (m *MotorFlujos) llamarRPC(motor, metodo string, params []any, ctx map[string]any) (any, error) {
    url := m.motores[motor]
    creds := m.sesionesServicio[motor]

    auth := base64.StdEncoding.EncodeToString(
        []byte(fmt.Sprintf("orquestador:%s:%s", creds[0], creds[1])),
    )

    body, _ := json.Marshal(map[string]any{
        "id":     uuid.New().String(),
        "method": metodo,
        "params": append(params, ctx),  // ctx al final, convención Parte 3
    })

    req, _ := http.NewRequest("POST", url, bytes.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("Authorization", "Basic "+auth)

    resp, err := m.cliente.Do(req)
    if err != nil { return nil, err }
    defer resp.Body.Close()

    var data map[string]any
    json.NewDecoder(resp.Body).Decode(&data)

    if errData, ok := data["error"].(map[string]any); ok && errData != nil {
        return nil, fmt.Errorf("%v", errData["message"])
    }
    return data["result"], nil
}

func (m *MotorFlujos) dependenciasListas(paso Paso, completados map[string]bool) bool {
    for _, dep := range paso.DependeDe {
        if !completados[dep] { return false }
    }
    return true
}
```

### Rust

```rust
// src/orquestador/motor.rs

use std::collections::{HashMap, HashSet};
use std::sync::{Arc, Mutex};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use tokio::task::JoinSet;
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Estado { Ejecutando, Completado, Fallido, Compensando, Compensado }

#[derive(Clone, Serialize)]
pub struct EjecucionFlujo {
    pub id:        String,
    pub flujo_id:  String,
    pub estado:    Estado,
    pub ctx:       HashMap<String, Value>,
    pub variables: HashMap<String, Value>,
    #[serde(skip)]
    pub pasos_ok:  Vec<Paso>,
    pub error:     Option<String>,
}

pub struct MotorFlujos {
    motores:           HashMap<String, String>,
    repositorio:       Arc<dyn Repositorio + Send + Sync>,
    sesiones_servicio: HashMap<String, (String, String)>,
}

impl MotorFlujos {
    pub fn nuevo(
        motores: HashMap<String, String>,
        repo:    Arc<dyn Repositorio + Send + Sync>,
        sesiones: HashMap<String, (String, String)>,
    ) -> Self {
        Self { motores, repositorio: repo, sesiones_servicio: sesiones }
    }

    pub async fn ejecutar(
        &self,
        def:    &Definicion,
        params: HashMap<String, Value>,
        ctx:    HashMap<String, Value>,
    ) -> Result<EjecucionFlujo, String> {
        def.validar_entrada(&params)?;

        let variables = Arc::new(Mutex::new(params.clone()));
        let pasos_ok  = Arc::new(Mutex::new(Vec::<Paso>::new()));

        let mut ejec = EjecucionFlujo {
            id:        Uuid::new_v4().to_string(),
            flujo_id:  def.id.clone(),
            estado:    Estado::Ejecutando,
            ctx:       ctx.clone(),
            variables: params.clone(),
            pasos_ok:  Vec::new(),
            error:     None,
        };
        self.repositorio.guardar(&ejec).await;

        match self.ejecutar_grafo(&def.pasos, &variables, &pasos_ok, &ctx).await {
            Ok(()) => {
                ejec.variables = variables.lock().unwrap().clone();
                ejec.pasos_ok  = pasos_ok.lock().unwrap().clone();
                ejec.estado    = Estado::Completado;
            }
            Err(e) => {
                ejec.variables = variables.lock().unwrap().clone();
                ejec.pasos_ok  = pasos_ok.lock().unwrap().clone();
                ejec.estado    = Estado::Fallido;
                ejec.error     = Some(e.clone());
                self.compensar(&mut ejec).await;
            }
        }

        self.repositorio.guardar(&ejec).await;
        Ok(ejec)
    }

    async fn ejecutar_grafo(
        &self,
        pasos:    &[Paso],
        vars:     &Arc<Mutex<HashMap<String, Value>>>,
        pasos_ok: &Arc<Mutex<Vec<Paso>>>,
        ctx:      &HashMap<String, Value>,
    ) -> Result<(), String> {
        let mut completados: HashSet<String> = Default::default();
        let mut pendientes: Vec<&Paso> = pasos.iter().collect();

        while !pendientes.is_empty() {
            let listos: Vec<&&Paso> = pendientes
                .iter()
                .filter(|p| p.depende_de.iter().all(|d| completados.contains(d)))
                .collect();

            if listos.is_empty() {
                return Err("Ciclo en el grafo de dependencias".to_string());
            }

            let mut join_set = JoinSet::new();
            for paso in &listos {
                let paso  = (*paso).clone();
                let motor = self.motores.clone();
                let sess  = self.sesiones_servicio.clone();
                let vars  = Arc::clone(vars);
                let pk    = Arc::clone(pasos_ok);
                let ctx   = ctx.clone();

                join_set.spawn(async move {
                    ejecutar_paso_async(paso, motor, sess, vars, pk, ctx).await
                });
            }

            while let Some(res) = join_set.join_next().await {
                res.map_err(|e| e.to_string())??;
            }

            for p in &listos { completados.insert(p.id.clone()); }
            pendientes.retain(|p| !completados.contains(&p.id));
        }
        Ok(())
    }

    async fn compensar(&self, ejec: &mut EjecucionFlujo) {
        ejec.estado = Estado::Compensando;
        for paso in ejec.pasos_ok.iter().rev() {
            let Some(comp) = &paso.compensar else { continue };
            if let Ok(params) = resolver(&comp.params, &ejec.variables, &ejec.ctx) {
                let _ = llamar_rpc(
                    &self.motores[&paso.motor],
                    &comp.metodo,
                    params,
                    ejec.ctx.clone(),
                    &self.sesiones_servicio[&paso.motor],
                ).await;
            }
        }
        ejec.estado = Estado::Compensado;
    }
}
```

### PHP

```php
<?php
// src/Orquestador/MotorFlujos.php

namespace App\Orquestador;

use Ramsey\Uuid\Uuid;

class MotorFlujos
{
    private array $motores;
    private Repositorio $repositorio;
    private array $sesionesServicio;

    public function __construct(
        array $motores,
        Repositorio $repositorio,
        array $sesionesServicio
    ) {
        $this->motores           = $motores;
        $this->repositorio       = $repositorio;
        $this->sesionesServicio  = $sesionesServicio;
    }

    public function ejecutar(array $definicion, array $params, array $ctx): array
    {
        $this->validarEntrada($definicion['entrada'] ?? [], $params);

        $ejec = [
            'id'        => Uuid::uuid4()->toString(),
            'flujo_id'  => $definicion['id'],
            'estado'    => 'ejecutando',
            'ctx'       => $ctx,
            'variables' => $params,
            'pasos_ok'  => [],
            'error'     => null,
        ];
        $this->repositorio->guardar($ejec);

        try {
            $this->ejecutarGrafo($ejec, $definicion['pasos']);
            $ejec['estado'] = 'completado';
        } catch (\Exception $e) {
            $ejec['estado'] = 'fallido';
            $ejec['error']  = $e->getMessage();
            $this->compensar($ejec);
        }

        $this->repositorio->guardar($ejec);
        return $ejec;
    }

    private function ejecutarGrafo(array &$ejec, array $pasos): void
    {
        $completados = [];
        $pendientes  = $pasos;

        while (!empty($pendientes)) {
            $listos = array_filter($pendientes, function($paso) use ($completados) {
                $deps = (array)($paso['depende_de'] ?? []);
                return empty(array_diff($deps, $completados));
            });

            if (empty($listos)) {
                throw new \RuntimeException('Ciclo en el grafo de dependencias.');
            }

            // PHP no tiene concurrencia nativa; ejecutar secuencialmente.
            // Para paralelismo real usar ReactPHP, Swoole o Fibers.
            foreach (array_values($listos) as $paso) {
                $this->ejecutarPaso($ejec, $paso);
                $completados[] = $paso['id'];
            }

            $pendientes = array_filter($pendientes, function($p) use ($completados) {
                return !in_array($p['id'], $completados);
            });
        }
    }

    private function ejecutarPaso(array &$ejec, array $paso): void
    {
        $maxIntentos = $paso['reintentos']['max_intentos'] ?? 3;
        $espera      = $paso['reintentos']['espera_inicial_ms'] ?? 500;
        $lastError   = null;

        for ($i = 1; $i <= $maxIntentos; $i++) {
            try {
                $params    = $this->resolver($paso['params'] ?? [[]],
                                             $ejec['variables'], $ejec['ctx']);
                $resultado = $this->llamarRPC(
                    $paso['motor'], $paso['metodo'], $params, $ejec['ctx']
                );

                if (!empty($paso['guardar_como'])) {
                    $ejec['variables'][$paso['guardar_como']] = $resultado;
                }
                $ejec['pasos_ok'][] = $paso;
                return;

            } catch (\Exception $e) {
                $lastError = $e;
                if ($i < $maxIntentos) {
                    usleep($espera * 1000 * (2 ** ($i - 1)));
                }
            }
        }

        $politica = $paso['on_failure'] ?? 'abort';
        if ($politica === 'abort') {
            throw new \RuntimeException(
                "Paso '{$paso['id']}' falló: {$lastError->getMessage()}"
            );
        }
    }

    private function compensar(array &$ejec): void
    {
        $ejec['estado'] = 'compensando';
        $this->repositorio->guardar($ejec);

        foreach (array_reverse($ejec['pasos_ok']) as $paso) {
            $comp = $paso['compensar'] ?? null;
            if (!$comp) continue;

            try {
                $params = $this->resolver($comp['params'], $ejec['variables'], $ejec['ctx']);
                $this->llamarRPC($paso['motor'], $comp['metodo'], $params, $ejec['ctx']);
            } catch (\Exception $e) {
                error_log("Compensación del paso '{$paso['id']}' falló: {$e->getMessage()}");
            }
        }

        $ejec['estado'] = 'compensado';
    }

    private function llamarRPC(string $motor, string $metodo,
                                array $params, array $ctx): mixed
    {
        $url    = $this->motores[$motor];
        [$uid, $token] = $this->sesionesServicio[$motor];
        $cred   = base64_encode("orquestador:{$uid}:{$token}");

        $body = json_encode([
            'id'     => Uuid::uuid4()->toString(),
            'method' => $metodo,
            'params' => array_merge($params, [$ctx]),  // ctx al final (Parte 3)
        ]);

        $respuesta = file_get_contents($url, false, stream_context_create([
            'http' => [
                'method'  => 'POST',
                'header'  => "Content-Type: application/json\r\n" .
                             "Authorization: Basic {$cred}\r\n",
                'content' => $body,
                'timeout' => 30,
            ],
        ]));

        $data = json_decode($respuesta, true);
        if (!empty($data['error'])) {
            throw new \RuntimeException($data['error']['message']);
        }
        return $data['result'];
    }

    private function resolver(array $params, array $variables, array $ctx): array
    {
        $json = json_encode($params);
        $json = preg_replace_callback('/\{\{([^}]+)\}\}/', function($m) use ($variables, $ctx) {
            $expr = trim($m[1]);
            if (str_starts_with($expr, 'ctx.')) {
                return (string)($ctx[substr($expr, 4)] ?? '');
            }
            return (string)($variables[$expr] ?? $m[0]);
        }, $json);
        return json_decode($json, true);
    }

    private function validarEntrada(array $esquema, array $params): void
    {
        foreach ($esquema as $campo => $reglas) {
            if (($reglas['requerido'] ?? false) && !array_key_exists($campo, $params)) {
                throw new \InvalidArgumentException("Parámetro requerido ausente: '{$campo}'");
            }
        }
    }
}
```

---

## 8. El flujo completo: alta de empleado en el ecosistema

Este ejemplo integra la cadena de eventos de la Parte 4 con el ecosistema multi-motor de la Parte 8. El cliente invoca un único método JSON-RPC en el orquestador y el sistema coordina tres motores en paralelo y en secuencia.

### Diagrama end-to-end

```
[1] Login en el orquestador
     │
[2] flujo.empleado.alta(nombre, apellido, cargo_id, equipo_id)
     │
     ▼ ORQUESTADOR coordina:
     │
     ├──────────────────────────────────────────────────────┐
     │                                                      │
     ▼  Paso 1 (inmediato)                    Paso 2 (inmediato, en paralelo)
  Fachada-RRHH                               Tryton
  model.empleado.create                      model.hr.employee.create
  → empleado_id = 42                         → erp_empleado_id = 1042
     │                                              │
     └──────────────────────────┬───────────────────┘
                                │ (ambos completados)
                                ▼ Paso 3 (depende de 1 y 2)
                           Proyectos
                           model.recurso.asignar(42, equipo_5)
                           → true
                                │
                                ▼ Paso 4 (depende de 3)
                           Mensajería
                           model.mensaje.enviar
                           on_failure: continue
                                │
[3] Resultado devuelto al cliente:
    {"estado": "completado",
     "empleado_id": 42, "erp_empleado_id": 1042}
```

### Llamadas JSON-RPC del cliente (tan simple como cualquier otra cadena)

**Eslabón 1 — Login en el orquestador:**
```json
{"id": 1, "method": "common.auth.login",
 "params": ["ana", {"password": "contraseña"}]}
→ result: [5, "tok-xxxxxxxx"]
```

**Eslabón 2 — Ejecutar el flujo:**
```json
{"id": 2, "method": "flujo.empleado.alta",
 "params": [
   {
     "nombre":    "Carlos",
     "apellido":  "Mamani",
     "cargo_id":  12,
     "equipo_id": 5
   },
   {"language": "es_BO", "company": 1, "employee": 5}
 ]}
→ result: {
    "estado": "completado",
    "empleado_id": 42,
    "erp_empleado_id": 1042
  }
```

**Eslabón 3 — Logout:**
```json
{"id": 3, "method": "common.auth.logout", "params": []}
→ result: true
```

El cliente nunca supo que existían tres motores internos, dos llamadas en paralelo, ni una compensación disponible si algo hubiera fallado.

---

## 9. Exposición del orquestador como motor JSON-RPC

El orquestador es en sí mismo un motor JSON-RPC de Categoría B (Parte 8). Sigue exactamente el patrón del manual: tiene un dispatcher, un registro de métodos, autenticación y contexto. Lo que lo diferencia es que sus métodos ejecutan flujos en lugar de operar directamente sobre una base de datos.

### Catálogo del orquestador

```python
# rpc/catalogos/flujos.py

class CatalogoFlujos:
    def __init__(self, motor: MotorFlujos, catalogo_flujos: dict):
        self.motor   = motor
        self.flujos  = catalogo_flujos  # id → definicion
        self._registrar()

    def _registrar(self):
        for flujo_id, definicion in self.flujos.items():
            nombre_metodo = f"flujo.{flujo_id.replace('-', '_')}"
            registro.registrar(nombre_metodo, DescriptorRPC(
                funcion      = self._construir_handler(definicion),
                solo_lectura = False,
                permisos     = definicion.get("permisos", []),
                descripcion  = definicion.get("nombre", ""),
            ))

    def _construir_handler(self, definicion):
        def handler(params, ctx):
            ejec = self.motor.ejecutar(definicion, params[0], ctx)
            if ejec["estado"] == "compensado":
                raise ValueError(
                    f"El flujo fue revertido. Paso fallido: {ejec.get('error')}"
                )
            return {k: v for k, v in ejec["variables"].items()
                    if k not in definicion.get("entrada", {})}
        return handler
```

### `system.listMethods` del orquestador

Igual que cualquier motor, el orquestador responde a la introspección estándar:

```json
{"id": 1, "method": "system.listMethods", "params": []}
→ result: [
    "common.auth.login",
    "common.auth.logout",
    "common.server.version",
    "flujo.empleado_alta",
    "flujo.cierre_mes",
    "flujo.pedido_aprobar",
    "system.listMethods",
    "system.methodHelp"
  ]
```

Un agente de IA puede descubrir los flujos disponibles y ejecutarlos exactamente igual que cualquier otro motor del ecosistema.

---

## 10. Lista de verificación para flujos multi-motor

### Diseño del flujo

- [ ] Cada paso que crea o modifica datos tiene una compensación definida.
- [ ] Las compensaciones son idempotentes: ejecutarlas dos veces produce el mismo resultado que ejecutarlas una vez.
- [ ] Los parámetros de compensación usan `{{guardar_como}}` del paso, no los inputs originales.
- [ ] Los pasos de notificación (correo, mensajería) tienen `on_failure: continue`.
- [ ] Los pasos sin dependencias entre sí no declaran `depende_de` innecesario.
- [ ] El `entrada` del flujo valida todos los campos requeridos antes de ejecutar el primer paso.

### Gestión de sesiones de servicio

- [ ] El orquestador tiene credenciales de servicio propias con cada motor; no usa las del usuario final.
- [ ] Las sesiones de servicio se renuevan automáticamente al expirar (igual que cualquier cliente de la Parte 2).
- [ ] Las credenciales de servicio tienen permisos mínimos en cada motor (solo lo que el flujo necesita).

### Contexto

- [ ] El contexto del cliente (`company`, `language`, `employee`) se propaga sin modificación a cada motor.
- [ ] El orquestador no añade ni quita campos del contexto del usuario.

### Producción

- [ ] Cada ejecución de flujo se persiste en base de datos con su estado, variables y resultado.
- [ ] Los tiempos de expiración de cada paso son explícitos (nunca `timeout=∞`).
- [ ] Hay reintentos con backoff exponencial para errores transitorios de red.
- [ ] Las compensaciones fallidas se registran en log pero no abortan el proceso de compensación.
- [ ] El orquestador expone `common.server.version` y `system.listMethods` como cualquier motor.

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
