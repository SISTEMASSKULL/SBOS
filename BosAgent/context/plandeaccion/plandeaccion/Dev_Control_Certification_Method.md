# Método de Control y Certificación de Desarrollo de Software
## Framework agnóstico de proyecto · Basado en Kent Beck, SOLID, y estándares internacionales
### v1.0 · Junio 2026

---

> **Propósito de este documento**
>
> Este no es un documento de un proyecto. Es un **método**.
>
> Define cómo certificar que una pieza de software está bien construida,
> independientemente del lenguaje, del dominio de negocio, o del equipo.
>
> Cualquier desarrollador o agente IA puede tomar este documento
> y aplicarlo a cualquier codebase para determinar su estado real.

---

## Índice

1. [Los dos ejes de control](#1-los-dos-ejes-de-control)
2. [Eje I — Diseño Simple (Kent Beck)](#2-eje-i--diseño-simple-kent-beck)
3. [Eje II — Principios de Responsabilidad (SOLID)](#3-eje-ii--principios-de-responsabilidad-solid)
4. [Las Gates de Certificación](#4-las-gates-de-certificación)
5. [Protocolo de Inspección de Código](#5-protocolo-de-inspección-de-código)
6. [Métricas de Control](#6-métricas-de-control)
7. [Señales de Alarma](#7-señales-de-alarma)
8. [El Ciclo de Certificación](#8-el-ciclo-de-certificación)
9. [Registro de Decisiones de Diseño (ADR)](#9-registro-de-decisiones-de-diseño-adr)
10. [Checklist de Certificación por Entregable](#10-checklist-de-certificación-por-entregable)

---

## 1. Los dos ejes de control

Todo software tiene dos dimensiones que deben controlarse de forma independiente:

```
          CORRECTO
             ▲
             │
   ┌─────────┼──────────┐
   │         │          │
   │  Mal    │  Bien    │
   │  hecho  │  hecho   │
   │  pero   │  y       │
   │  correcto   correcto│
   │         │          │
   ├─────────┼──────────┤  BIEN HECHO
   │         │          │ ──────────────►
   │  Mal    │  Bien    │
   │  hecho  │  hecho   │
   │  e      │  pero    │
   │  incorrecto incorrecto│
   │         │          │
   └─────────┴──────────┘
```

- **Correcto** = hace lo que debe hacer (tests, comportamiento observable)
- **Bien hecho** = está construido de forma que puede cambiar sin romperse (diseño)

Un sistema puede ser correcto pero mal hecho (funciona hoy, nadie puede tocarlo mañana).
Puede ser bien hecho pero incorrecto (hermoso pero no hace lo que el negocio necesita).

El objetivo es el cuadrante superior derecho. Este documento controla ambos ejes.

---

## 2. Eje I — Diseño Simple (Kent Beck)

Las cuatro reglas en orden de prioridad. Si hay conflicto entre reglas, gana la de número más bajo.

---

### 2.1 Regla 1 — Pasa todos los tests

**Definición:** el sistema demuestra que hace lo que debe hacer mediante pruebas automatizadas verificables.

**Por qué es la primera:** sin esto, las otras tres reglas no importan. Un diseño hermoso que no funciona es basura elegante.

**Cómo verificar:**

```
ESTADO VERDE  → Todos los tests del CI pasan en la rama main/master
ESTADO AMARILLO → Hay tests ignorados (t.Skip, xit, @Ignore) sin fecha de resolución
ESTADO ROJO   → Tests fallando en main, o no hay tests en módulos críticos
```

**Preguntas de certificación:**

- ¿Cuál es la cobertura de los módulos con lógica de negocio? ¿Es medible?
- ¿Los tests que existen son unitarios o solo de integración? ¿Se pueden correr sin infraestructura?
- ¿Hay un módulo que nadie toca porque "si lo tocas se rompe todo"? → ausencia de tests.
- ¿El CI falla silenciosamente? ¿Hay alertas reales cuando falla?

**Tipos de test y cuándo son suficientes:**

| Tipo | Velocidad | Qué certifica | Cuándo es obligatorio |
|---|---|---|---|
| Unitario | <1ms | Lógica de dominio aislada | Siempre, en toda lógica de negocio |
| Integración | <30s | Módulo + dependencia real (BD, caché) | Módulos de persistencia y comunicación |
| Contrato | <5s | Que el contrato entre servicios no cambió | Antes de mergear cambios a interfaces públicas |
| End-to-end | <5min | Flujo completo de negocio | Flujos críticos de alto valor |

**Anti-patrón: el test que siempre pasa.**
Un test que nunca falla aunque el código esté roto no es un test. Es documentación falsa. Verificar que los tests fallen correctamente cuando se introduce un bug deliberado.

---

### 2.2 Regla 2 — Revela intención

**Definición:** cualquier desarrollador que lea el código entiende qué hace y por qué, sin necesidad de preguntar al autor.

**Por qué importa:** el código se lee muchas más veces de las que se escribe. Un agente IA también lo lee. Si el código no revela intención, tanto el humano como la IA toman decisiones incorrectas.

**Cómo verificar:**

Hacer la prueba del "desarrollador nuevo": ¿puede alguien que nunca vio el código entender qué hace una función en 30 segundos sin ejecutarla?

**Señales de intención revelada:**

```
✅ Nombres que describen intención de negocio:
   calcularTotalConDescuento()  en lugar de  calc()
   usuarioTienePermisoDeVenta() en lugar de  checkBit(mask, 0x21)
   ventaEstaAbierta()           en lugar de  estado == 1

✅ Comentarios que explican el POR QUÉ, no el QUÉ:
   // Verificamos origin para evitar loop infinito cuando bKernel
   // procesa sus propios eventos del WAL
   if isOwnWrite(event) { return }

   // Nunca float para dinero: 0.1 + 0.2 != 0.3 en IEEE 754
   amount int64 // centavos

✅ Abstracciones que hablan el lenguaje del dominio:
   venta.Cerrar()       en lugar de  venta.Estado = 3
   factura.Emitir()     en lugar de  factura.Flag |= 0x04
```

**Señales de intención oculta:**

```
❌ Números mágicos sin nombre:
   if retries > 3 { ... }          // ¿Por qué 3?
   time.Sleep(500 * time.Millisecond) // ¿Por qué 500ms?

❌ Nombres que describen el tipo, no el rol:
   data, info, manager, handler, util, helper, misc

❌ Comentarios que repiten el código:
   // incrementa el contador en 1
   counter++

❌ Booleanos sin semántica:
   process(true, false, true)  // ¿Qué significan estos bool?
```

**Umbral de certificación:** si se necesita más de un comentario explicando el *qué* por cada 20 líneas de código, el código no revela intención.

---

### 2.3 Regla 3 — Sin duplicación (DRY)

**Definición:** cada pieza de conocimiento existe exactamente una vez en el sistema. La duplicación no es solo código copiado — es conocimiento duplicado.

**La distinción crítica:** DRY no es sobre texto, es sobre *conocimiento*.

```
// Esto NO es duplicación aunque el texto sea idéntico:
// Son dos reglas de negocio distintas que hoy tienen la misma forma.
// Si una cambia, la otra no necesariamente cambia.
precioFinalCliente = precioBase * (1 - descuentoCliente)
comisionVendedor   = precioBase * (1 - descuentoVendedor)

// Esto SÍ es duplicación de conocimiento:
// La misma regla de negocio expresada en dos lugares.
// Si cambia la regla, hay que cambiarla en dos lugares.
// Un día se cambia en uno y se olvida el otro.
// En validarPago():    if monto < 0 { return ErrMontoInvalido }
// En registrarVenta(): if monto < 0 { return ErrMontoInvalido }
```

**Tipos de duplicación a detectar:**

```
Tipo 1 — Código copiado:
  El mismo bloque de código en múltiples lugares.
  Detección: grep, linters, herramientas de detección de clones.

Tipo 2 — Conocimiento duplicado:
  La misma regla de negocio en múltiples capas
  (validación en el handler Y en el dominio Y en la BD).
  Detección: revisión de diseño, no de herramientas.

Tipo 3 — Configuración duplicada:
  La misma constante definida en múltiples archivos.
  Detección: grep de literales numéricos y strings.

Tipo 4 — Tests duplicados:
  Múltiples tests que verifican exactamente lo mismo.
  Señal: si borras uno, el suite sigue igual de informativo.
```

**Preguntas de certificación:**

- Si cambia una regla de negocio, ¿en cuántos lugares hay que cambiar código?
- ¿Hay constantes con el mismo valor definidas en más de un archivo?
- ¿Hay lógica de validación en la capa de presentación Y en la capa de dominio?

**Umbral de certificación:** ninguna regla de negocio debe existir en más de un lugar. Si existe en dos, es un bug esperando ocurrir.

---

### 2.4 Regla 4 — Mínima cantidad de elementos (YAGNI)

**Definición:** no existe código, abstracciones, clases, métodos, o capas que no estén justificados por un requerimiento concreto actual.

**Por qué importa:** el código que no existe no puede tener bugs, no necesita tests, no necesita mantenimiento, y no confunde a nadie. La complejidad innecesaria es deuda técnica desde el día uno.

**Preguntas de certificación:**

```
¿Para qué sirve esto hoy?
Si la respuesta es "por si acaso" o "en el futuro" → candidato a eliminar.

¿Cuándo fue usado esto por última vez?
Si nunca → eliminar.

¿Hay abstracción con una sola implementación concreta?
Puede ser prematura. Esperar a que haya dos antes de abstraer.

¿Hay parámetros de configuración que siempre tienen el mismo valor?
Son complejidad sin beneficio.
```

**Anti-patrones YAGNI frecuentes:**

```
❌ Frameworks de inyección de dependencias
   cuando la DI manual son 10 líneas en main()

❌ Event sourcing completo
   cuando una tabla de auditoría cumple el 95% del caso de uso

❌ Microservicios desde el día 1
   cuando un monolito modular sería suficiente

❌ Interfaces para todo
   cuando solo hay una implementación y no hay tests que las necesiten

❌ Generics/templates
   cuando los tipos concretos son siempre los mismos

❌ Configuración externalizada
   para valores que nunca cambian entre entornos
```

**La regla práctica:** si escribes código para un caso de uso hipotético que no tienes hoy, bórralo. Cuando ese caso de uso llegue, lo escribirás mejor porque tendrás más contexto.

---

## 3. Eje II — Principios de Responsabilidad (SOLID)

SOLID controla la *estructura* del software: cómo están organizadas las piezas y cómo se relacionan entre sí.

---

### 3.1 S — Single Responsibility Principle

**Definición:** un módulo tiene exactamente una razón para cambiar.

**La prueba:** completar la frase "este módulo cambia cuando..." Si la frase necesita "o" para completarse, hay más de una responsabilidad.

**Cómo detectar violaciones:**

```
Señal 1 — El módulo importa de capas que no debería:
  Un handler de API importando del paquete de base de datos directamente.
  Un módulo de dominio importando un cliente HTTP.

Señal 2 — El nombre del módulo contiene "y", "o", "también":
  UserAuthAndProfileService
  PaymentProcessorAndNotifier
  OrderValidatorAndPersister

Señal 3 — El módulo es difícil de testear unitariamente:
  Si necesitas muchos mocks para testear una clase,
  esa clase hace demasiadas cosas.

Señal 4 — Los cambios de negocio frecuentemente tocan el mismo archivo
  por razones distintas (cambio de regla de negocio Y cambio de formato
  de log Y cambio de protocolo de comunicación).
```

**Cómo corregir:**

Separar en módulos por *eje de cambio*. Si la lógica de negocio cambia por razones de negocio, y la lógica de persistencia cambia por razones de infraestructura, deben ser módulos distintos.

---

### 3.2 O — Open/Closed Principle

**Definición:** el software está abierto para extensión, cerrado para modificación.

**La prueba:** agregar una nueva variante del comportamiento (un nuevo método de pago, un nuevo canal de notificación, una nueva regla) ¿requiere modificar código existente o solo agregar código nuevo?

**La forma más poderosa de OCP en la práctica:**

```
Configuración declarativa → extensión sin modificar código
Polimorfismo              → extensión agregando implementaciones
Plugins/hooks             → extensión desde fuera del módulo
```

**Cómo detectar violaciones:**

```
❌ El switch/match que crece:
   Cada vez que se agrega una nueva variante,
   hay que agregar un case a un switch central.
   Ese switch viola OCP.

   switch tipo {
   case "email":   enviarEmail(...)
   case "sms":     enviarSMS(...)
   case "push":    // próximamente...
   case "webhook": // pendiente de implementar...
   }

✅ Corrección con polimorfismo:
   type Notifier interface { Send(msg Message) error }
   // EmailNotifier, SMSNotifier, PushNotifier implementan la interfaz
   // Agregar WebhookNotifier no toca ningún código existente
```

**Preguntas de certificación:**

- ¿El último feature nuevo requirió modificar módulos existentes o solo agregar nuevos?
- ¿Hay un archivo que se toca en cada nuevo feature? (Posible violación de OCP)

---

### 3.3 L — Liskov Substitution Principle

**Definición:** cualquier implementación de una interfaz puede reemplazar a otra sin cambiar el comportamiento observable del sistema.

**La prueba más práctica:** los tests unitarios que usan una implementación stub/fake deben tener el mismo valor informativo que si usaran la implementación real. Si el fake no se comporta como la implementación real (incluyendo casos de error), los tests son inútiles.

**Cómo detectar violaciones:**

```
Señal 1 — Downcasting:
  if repo, ok := r.(*PostgresRepository); ok { ... }
  Si necesitas saber el tipo concreto, LSP está roto.

Señal 2 — Métodos que lanzan "not implemented":
  func (f *FakeRepo) Delete(...) error {
      panic("not implemented")
  }
  Si la interfaz tiene un método que las implementaciones
  no pueden cumplir, la interfaz está mal diseñada.

Señal 3 — Precondiciones más fuertes o postcondiciones más débiles:
  La interfaz dice "retorna nil si no existe"
  pero una implementación lanza una excepción.
  Los callers no pueden depender de comportamiento consistente.
```

**La regla de los fakes:**
Un fake de test debe reproducir los mismos contratos de error que la implementación real. Si el repositorio real lanza `ErrNotFound` cuando no existe el registro, el fake también debe lanzarlo. Si no lo hace, estás testeando un sistema que no existe.

---

### 3.4 I — Interface Segregation Principle

**Definición:** ningún módulo debe depender de métodos que no usa.

**La prueba:** ¿cuántos métodos de la interfaz usa realmente cada cliente?

**Cómo detectar violaciones:**

```
Señal 1 — Implementaciones con métodos vacíos o con panic:
  type EmailSender struct{}
  func (e *EmailSender) SendSMS(...) error { return nil } // no aplica
  → La interfaz tiene métodos que este cliente no necesita.

Señal 2 — Interfaces con más de 5-7 métodos:
  Una interfaz grande es una señal de que sirve a múltiples clientes
  con necesidades distintas. Probablemente debe dividirse.

Señal 3 — Fakes de test con métodos no implementados:
  Si el fake tiene 8 métodos y el test solo necesita 2,
  la interfaz está sobredimensionada para ese cliente.
```

**Corrección:**

Interfaces pequeñas y específicas por cliente (por caso de uso), no interfaces grandes y genéricas por entidad. La entidad concreta puede implementar múltiples interfaces pequeñas.

---

### 3.5 D — Dependency Inversion Principle

**Definición:** los módulos de alto nivel no dependen de los de bajo nivel. Ambos dependen de abstracciones. Las abstracciones no dependen de detalles.

**La distinción entre inyección de dependencias (mecanismo) e inversión de dependencias (principio):**

```
Inyección de dependencias = pasar las dependencias desde fuera
Inversión de dependencias = que las dependencias apunten en la dirección correcta

Un módulo puede tener DI sin tener DIP:
  func NewService(db *PostgresDB) *Service { ... }
  // Se inyecta la dependencia pero apunta hacia la implementación concreta.
  // No es DIP.

DIP correcto:
  func NewService(db Repository) *Service { ... }
  // La interfaz Repository está definida en el paquete de alto nivel (dominio).
  // PostgresDB implementa esa interfaz.
  // La dependencia en código fuente va: PostgresDB → Repository ← Service
  // La dirección de la flecha de dependencia se invirtió.
```

**Preguntas de certificación:**

- ¿Los módulos de dominio/negocio importan paquetes de infraestructura (BD, HTTP, gRPC)?
  Si sí → DIP roto.
- ¿Las interfaces están definidas en el módulo que las *usa* o en el módulo que las *implementa*?
  Deben estar donde se usan (en el alto nivel), no donde se implementan.

---

## 4. Las Gates de Certificación

Una **gate** es un punto de control que debe pasar para que un entregable avance al siguiente estado. No es opcional.

### Gate 0 — Compilación limpia

```
Criterio: el código compila sin errores ni warnings ignorados.
Quién verifica: CI automático en cada commit.
Estado de fallo: el código no puede mergearse.

Incluye:
  - Zero compiler warnings (tratados como errores en CI)
  - Zero lint warnings ignorados sin justificación documentada
  - Zero dependencias con vulnerabilidades conocidas sin mitigación
```

### Gate 1 — Tests en verde

```
Criterio: todos los tests automatizados pasan en la rama main.
Quién verifica: CI automático en cada PR.
Estado de fallo: el PR no puede mergearse.

Incluye:
  - Tests unitarios: cobertura ≥ 80% en módulos con lógica de negocio
  - Tests de integración: todos los repositorios/adapters testeados
    contra implementaciones reales (no mocks de la infraestructura)
  - Tests de contrato: ningún cambio breaking no versionado
```

### Gate 2 — Diseño certificado

```
Criterio: el código pasa la inspección de las 4 reglas de Beck y SOLID.
Quién verifica: revisión de código por al menos un par.
Estado de fallo: el PR vuelve al autor con observaciones concretas.

Formato de observación: no "esto viola SOLID" sino
"este módulo viola SRP porque cambia por dos razones:
 X cuando cambia la regla de negocio de descuentos,
 e Y cuando cambia el formato del log. Separar en dos módulos."
```

### Gate 3 — Comportamiento documentado

```
Criterio: el comportamiento del entregable está documentado
de forma que un desarrollador nuevo puede entenderlo sin preguntar.
Quién verifica: revisión de documentación por un par.
Estado de fallo: el PR vuelve al autor.

No se acepta:
  - "TODO: documentar esto"
  - Comentarios en un idioma distinto al del equipo
  - Documentación que describe el código en lugar del comportamiento
```

### Gate 4 — Decisión de diseño registrada

```
Criterio: cualquier decisión de diseño no obvia tiene un ADR
(Architecture Decision Record) asociado.
Quién verifica: arquitecto o tech lead.
Estado de fallo: la decisión se discute y se registra antes de mergear.

¿Qué es "no obvio"?
  - Elección de tecnología (este lenguaje, esta librería, este protocolo)
  - Violación documentada de un principio (con justificación)
  - Patrón que no está en los estándares del equipo
  - Deuda técnica aceptada conscientemente
```

---

## 5. Protocolo de Inspección de Código

Cuando se revisa código, la inspección sigue este orden. No es una lista de preferencias — es una secuencia.

### Paso 1 — ¿Qué hace? (Comprensión)

Antes de evaluar el diseño, entender el comportamiento. Leer los tests primero, si existen. Los tests son la especificación ejecutable.

Preguntas:
- ¿Qué caso de uso implementa esto?
- ¿Cuál es el happy path?
- ¿Qué errores maneja?

### Paso 2 — ¿Funciona? (Corrección)

Verificar que los tests cubren el comportamiento relevante.

Preguntas:
- ¿Los tests fallan si se introduce un bug deliberado?
- ¿Los casos de error están testeados o solo el happy path?
- ¿Hay comportamiento no cubierto por ningún test?

### Paso 3 — ¿Se entiende? (Legibilidad)

Aplicar la Regla 2 de Beck.

Preguntas:
- ¿Los nombres describen intención de negocio?
- ¿Hay números mágicos o strings literales sin nombre?
- ¿Los comentarios explican el por qué, no el qué?

### Paso 4 — ¿Está duplicado? (DRY)

Aplicar la Regla 3 de Beck.

Preguntas:
- ¿Esta lógica existe en otro lugar del sistema?
- ¿Si cambia esta regla de negocio, cuántos archivos hay que cambiar?

### Paso 5 — ¿Hace demasiado? (SRP/ISP)

Preguntas:
- ¿Cuántas razones tiene este módulo para cambiar?
- ¿Las interfaces son del tamaño mínimo necesario para cada cliente?

### Paso 6 — ¿Puede crecer? (OCP/DIP)

Preguntas:
- ¿Agregar una nueva variante requiere modificar código existente?
- ¿Los módulos de alto nivel dependen de implementaciones concretas?

### Paso 7 — ¿Es necesario? (YAGNI)

Pregunta final:
- ¿Existe alguna parte de este código que no esté justificada por un requerimiento concreto actual?

---

## 6. Métricas de Control

Las métricas son indicadores, no objetivos. Un número fuera de rango es una señal para investigar, no una condena automática.

### Métricas de tests

| Métrica | Umbral saludable | Umbral de alerta | Qué indica |
|---|---|---|---|
| Cobertura de líneas en dominio | ≥ 80% | < 60% | Riesgo de regresiones silenciosas |
| Tiempo del suite unitario | < 30s | > 2min | Tests con dependencias externas |
| Tests ignorados (skip) | 0 | > 5 | Deuda técnica en crecimiento |
| Tests que nunca fallan | 0 | Cualquiera | Tests que no verifican nada |

### Métricas de complejidad

| Métrica | Umbral saludable | Umbral de alerta | Qué indica |
|---|---|---|---|
| Complejidad ciclomática por función | ≤ 5 | > 10 | Función hace demasiado |
| Profundidad de herencia/embedding | ≤ 2 | > 4 | Jerarquía difícil de entender |
| Líneas por función | ≤ 20 | > 50 | Violación de SRP probable |
| Parámetros por función | ≤ 4 | > 6 | Función hace demasiado |
| Imports por módulo | ≤ 10 | > 20 | Módulo con demasiadas dependencias |

### Métricas de acoplamiento

| Métrica | Umbral saludable | Umbral de alerta | Qué indica |
|---|---|---|---|
| Fan-out (módulos que importa) | ≤ 7 | > 15 | Módulo con muchas dependencias |
| Fan-in (módulos que lo importan) | Cualquiera | > 20 | Módulo muy acoplado al sistema |
| Dependencias cíclicas | 0 | Cualquiera | Diseño que no puede evolucionar |

### Métricas de duplicación

| Métrica | Umbral saludable | Umbral de alerta | Qué indica |
|---|---|---|---|
| Duplicación de código (clones) | < 3% | > 10% | DRY violado sistemáticamente |
| Constantes literales repetidas | 0 | > 5 iguales | Constantes sin nombre |

---

## 7. Señales de Alarma

Las siguientes situaciones requieren parar y evaluar antes de continuar. No son automáticamente un problema, pero sí requieren una decisión consciente.

### Alarma Roja — Parar y resolver

```
🔴 Tests fallando en main/master
   → Nadie puede trabajar productivamente. Esto es la prioridad absoluta.

🔴 Dependencias cíclicas entre módulos
   → El sistema no puede evolucionar. Requiere refactor antes de agregar features.

🔴 Módulo sin ningún test con lógica de negocio compleja
   → Cualquier cambio es una apuesta. Agregar tests antes de modificar.

🔴 Secretos hardcodeados en el código
   → Brecha de seguridad potencial. Rotar credenciales y limpiar el historial de git.

🔴 Violación de contrato entre servicios sin versionado
   → Clientes en producción pueden romperse silenciosamente.
```

### Alarma Amarilla — Evaluar y decidir conscientemente

```
🟡 Función con complejidad ciclomática > 10
   → Candidata a división. Evaluar si es el momento de refactorizar.

🟡 Módulo con > 15 dependencias externas
   → Posible violación de SRP. Revisar si hace demasiado.

🟡 Cobertura de tests < 60% en módulo crítico
   → Aceptar la deuda técnica con un plan de pago, o pagar ahora.

🟡 ADR faltante para una decisión de diseño significativa
   → Escribir el ADR retroactivamente antes de que el contexto se pierda.

🟡 Abstracción con una sola implementación desde hace más de 3 meses
   → Evaluar si la abstracción agrega valor o es complejidad prematura.
```

### Alarma Azul — Monitorear tendencia

```
🔵 Tests que tardan más de 2 minutos
   → Monitorear. Si sigue creciendo, investigar.

🔵 Número de líneas por archivo creciendo semana a semana
   → Señal temprana de SRP en peligro.

🔵 Frecuencia alta de cambios en el mismo archivo por razones distintas
   → Puede indicar que el módulo tiene múltiples responsabilidades.
```

---

## 8. El Ciclo de Certificación

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   DESARROLLO                                            │
│                                                         │
│   1. Escribir test que falla (TDD) o verificar          │
│      que el test existente falla con el bug             │
│   2. Escribir el código mínimo para pasar el test       │
│   3. Refactorizar aplicando Beck + SOLID                │
│   4. Verificar que los tests siguen en verde            │
│                                                         │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   INSPECCIÓN (antes de PR)                              │
│                                                         │
│   Autor ejecuta el Protocolo de Inspección (Sección 5)  │
│   Si encuentra observaciones → corregir antes del PR    │
│                                                         │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   GATES (en el PR)                                      │
│                                                         │
│   Gate 0 — Compilación limpia    → CI automático        │
│   Gate 1 — Tests en verde        → CI automático        │
│   Gate 2 — Diseño certificado    → Revisión de par      │
│   Gate 3 — Comportamiento doc.   → Revisión de par      │
│   Gate 4 — ADR si aplica         → Arquitecto/Tech Lead │
│                                                         │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   MERGE Y MONITOREO                                     │
│                                                         │
│   Merge a main                                          │
│   Monitorear métricas de la Sección 6                   │
│   Registrar cualquier deuda técnica aceptada            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Cadencia de revisión del método

| Revisión | Frecuencia | Qué se evalúa |
|---|---|---|
| Métricas de cobertura | Cada semana | Tendencia de tests |
| Señales de alarma | Cada semana | Estado de salud del código |
| Aplicación de Beck + SOLID | Cada PR | Calidad del entregable |
| Revisión del método en sí | Cada trimestre | ¿El método sigue siendo útil? |

---

## 9. Registro de Decisiones de Diseño (ADR)

Un ADR (Architecture Decision Record) documenta una decisión de diseño significativa: qué se decidió, por qué, y cuáles eran las alternativas.

### Cuándo escribir un ADR

```
✅ Siempre:
   - Elección de lenguaje, framework, o librería principal
   - Patrón de arquitectura adoptado (microservicios, monolito, hexagonal...)
   - Protocolo de comunicación entre componentes
   - Estrategia de persistencia y datos

✅ Cuando se desvía del estándar del equipo:
   - Violación documentada de SOLID con justificación
   - Excepción a una regla de este documento
   - Deuda técnica aceptada conscientemente

❌ No es necesario para:
   - Decisiones de implementación que no afectan la interfaz
   - Convenciones de nomenclatura (van en la guía de estilo)
   - Decisiones que se pueden revertir fácilmente
```

### Plantilla de ADR

```markdown
# ADR-{número}: {Título}

## Fecha
{YYYY-MM-DD}

## Estado
Propuesto | Aceptado | Rechazado | Reemplazado por ADR-{N}

## Contexto
¿Qué situación o problema motivó esta decisión?
¿Cuáles eran las restricciones?

## Decisión
¿Qué se decidió hacer?
Ser específico: no "usaremos una arquitectura limpia" sino
"los módulos de dominio no importarán paquetes de infraestructura.
 Las dependencias se invierten usando interfaces definidas en el dominio."

## Consecuencias
### Positivas
- ...

### Negativas / Compromisos aceptados
- ...

### Neutrales
- ...

## Alternativas consideradas
### Alternativa 1: {nombre}
Por qué no se eligió.

### Alternativa 2: {nombre}
Por qué no se eligió.

## Referencias
- {links a documentación, estándares, papers relevantes}
```

### Numeración y ubicación

```
docs/decisions/
├── ADR-0001-eleccion-de-lenguaje.md
├── ADR-0002-protocolo-de-comunicacion-interna.md
├── ADR-0003-estrategia-de-versionado-de-contratos.md
└── ADR-0004-deuda-tecnica-aceptada-en-modulo-X.md
```

Los ADRs son inmutables una vez aceptados. Si la decisión cambia, se crea un nuevo ADR que reemplaza al anterior. El historial de decisiones es tan valioso como las decisiones en sí.

---

## 10. Checklist de Certificación por Entregable

Esta es la lista que completa el autor antes de marcar un entregable como listo para revisión. No es la lista del revisor — es la autoevaluación.

### Bloque A — Corrección

```
[ ] El código compila sin warnings
[ ] Todos los tests existentes siguen en verde
[ ] Los nuevos comportamientos tienen tests que los verifican
[ ] Los casos de error están testeados, no solo el happy path
[ ] Los tests del nuevo código fallan si se introduce un bug deliberado
    (verificado manualmente al menos una vez)
```

### Bloque B — Diseño Simple (Beck)

```
[ ] Regla 1: No hay comportamiento sin test
[ ] Regla 2: Los nombres describen intención de negocio, no implementación
[ ] Regla 2: Los comentarios explican el por qué, no el qué
[ ] Regla 2: No hay números mágicos o strings literales sin nombre
[ ] Regla 3: No existe esta lógica en ningún otro lugar del sistema
[ ] Regla 3: Si esta regla de negocio cambia, hay exactamente un lugar a modificar
[ ] Regla 4: Todo el código nuevo está justificado por un requerimiento actual
[ ] Regla 4: No hay abstracciones creadas "por si acaso"
```

### Bloque C — Responsabilidades (SOLID)

```
[ ] SRP: cada módulo tiene exactamente una razón para cambiar
[ ] SRP: puedo describir la responsabilidad del módulo en una frase sin "y"
[ ] OCP: agregar una nueva variante no requiere modificar este código
[ ] LSP: los fakes/stubs usados en tests respetan los mismos contratos de error
[ ] ISP: las interfaces usadas contienen solo los métodos que este módulo necesita
[ ] DIP: los módulos de alto nivel no importan implementaciones concretas de bajo nivel
[ ] DIP: las interfaces están definidas donde se usan, no donde se implementan
```

### Bloque D — Gates

```
[ ] Gate 0: CI pasa (compilación + linters)
[ ] Gate 1: CI pasa (todos los tests)
[ ] Gate 2: completé el Protocolo de Inspección de la Sección 5
[ ] Gate 3: el comportamiento está documentado donde corresponde
[ ] Gate 4: si tomé una decisión de diseño significativa, escribí el ADR
```

### Bloque E — Deuda técnica (si aplica)

```
Si acepté deuda técnica conscientemente:
[ ] Está documentada con un comentario TODO que incluye:
    - Qué es la deuda
    - Por qué se acepta hoy
    - Cuándo debería pagarse (sprint, trimestre, o condición de disparo)
[ ] Está registrada en el backlog del equipo
[ ] No bloquea nada crítico en su estado actual
```

---

## Apéndice — Mapa de estándares referenciados

| Principio | Fuente | Dónde aplica |
|---|---|---|
| Las 4 Reglas de Diseño Simple | Kent Beck, "Extreme Programming Explained" | Todo el Eje I |
| SOLID | Robert C. Martin, "Design Principles and Design Patterns" (2000) | Todo el Eje II |
| DRY (Don't Repeat Yourself) | Andrew Hunt / David Thomas, "The Pragmatic Programmer" | Regla 3 de Beck |
| YAGNI (You Aren't Gonna Need It) | Kent Beck, Extreme Programming | Regla 4 de Beck |
| TDD (Test-Driven Development) | Kent Beck, "Test-Driven Development: By Example" | Sección 8, ciclo |
| Architecture Decision Records | Michael Nygard, "Documenting Architecture Decisions" (2011) | Sección 9 |
| Complejidad Ciclomática | Thomas J. McCabe, "A Complexity Measure" (1976) | Sección 6, métricas |
| Fan-in / Fan-out | Edward Yourdon & Larry Constantine, "Structured Design" | Sección 6, métricas |
| Clean Architecture | Robert C. Martin, "Clean Architecture" (2017) | SRP, DIP |
| Hexagonal Architecture | Alistair Cockburn, "Ports and Adapters" (2005) | DIP |
| Contract Testing | Ian Robinson / Martin Fowler (Pact) | Gate 1, contrato |

---

*Método de Control y Certificación de Desarrollo de Software*
*Versión 1.0 · Junio 2026 · Agnóstico de proyecto, lenguaje y dominio*
