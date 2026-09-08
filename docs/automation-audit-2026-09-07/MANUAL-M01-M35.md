# Validación manual del módulo

No ejecutada automáticamente. No se reinstaló ni borró información de los teléfonos. Usar contactos de prueba propios y registrar APK/modelo/Android para cada caso. No mezclar logs del APK anterior con este artefacto.

## M01

**Comprobar:** Un turno y como máximo una respuesta; cero llamadas semánticas si el saludo puro supera las guardas.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

```text
hola
```

---

## M02

**Comprobar:** Conservar texto crudo; corrector aporta sugerencias, nunca reemplaza intención ni copia faltas al output.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

```text
ola kmo estas
```

---

## M03

**Comprobar:** Responder al turno social sin retomar catálogo ajeno.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

```text
bien y tu
```

---

## M04

**Comprobar:** Sin fuente actual del dueño: no afirmar actividad, horario o ubicación.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

```text
qué haces
```

---

## M05

**Comprobar:** Invalidar interpretación corregida; no repetir la respuesta objetada.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

```text
eso está mal
```

---

## M06

**Comprobar:** Usar referente claro del mismo chat o pedir precisión.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

```text
no, el otro
```

---

## M07

**Comprobar:** Resolver el referente pendiente; no ejecutar una acción por el sí aislado.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

```text
sí
```

ante pregunta pendiente.

---

## M08

**Comprobar:** No realizar la acción rechazada.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

```text
no
```

ante acción pendiente.

---

## M09

**Comprobar:** Conservar la negación y restricción temporal juntas.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

```text
sí pero mañana no
```

---

## M10

**Comprobar:** Ráfaga dentro de la ventana: agregados=10, un turno lógico, máximo una respuesta útil.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

10 mensajes rápidos misma conversación.

Esperado:

```text
coherent logical turn
<=1 useful reply
```

---

## M11

**Comprobar:** Ráfaga dentro de la ventana: agregados=20, sin corte por conteo, IDs originales conservados.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

20 mensajes rápidos.

Esperado:

```text
no OOM
no loss
no starvation
no flood replies
```

---

## M12

**Comprobar:** Versión obsoleta: cero efectos del borrador viejo; observar la respuesta al turno nuevo.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

Mensaje nuevo durante inferencia.

Esperado:

```text
old draft stale
old draft zero send
```

---

## M13

**Comprobar:** Destinatario, memoria y capacidad separados; nunca intercambio de respuestas.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

2 contactos simultáneos.

---

## M14

**Comprobar:** Cuatro conversaciones acaban o muestran fallo explícito; inferencia en cola, sin hambre.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

4 contactos simultáneos.

---

## M15

**Comprobar:** Sin regla de paquete: cero turnos y cero llamadas de modelo.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

SystemUI flood.

Esperado:

```text
0 turns
0 LLM
```

sin regla.

---

## M16

**Comprobar:** Sin regla de paquete: cero turnos.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

Weather notification.

Esperado:

```text
0 turns
```

sin regla.

---

## M17

**Comprobar:** Sin regla de paquete: cero turnos.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

YouTube notification.

Esperado:

```text
0 turns
```

sin regla.

---

## M18

**Comprobar:** No reenviar evento terminal. Repetir además un cierre durante settle: queued se recupera si sigue activo.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

Process kill/rebirth con notificación ya procesada.

Esperado:

```text
duplicate
zero second send
```

---

## M19

**Comprobar:** Timestamps/eventos distintos conservan ambos mensajes aunque el texto coincida.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

Dos mensajes reales idénticos.

Esperado:

```text
both legitimate events preserved
```

si son eventos distintos.

---

## M20

**Comprobar:** Grupo con identidad estable y regla autorizada; no tomar Person.key del participante como grupo.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

WhatsApp group.

---

## M21

**Comprobar:** Configurar regla de com.whatsapp.w4b; jamás compartir identidad ni memoria con com.whatsapp.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

WhatsApp Business.

---

## M22

**Comprobar:** Usar Tomar control en Mensajes durante inferencia; guardar, responder manualmente y reabrir: bot bloqueado.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

Owner toma manualmente conversación.

Bot:

```text
zero autonomous interference
```

---

## M23

**Comprobar:** Sin fuente viva, no inventar ubicación ni copiar hechos de ejemplos históricos.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

Live state.

```text
¿dónde estás?
```

No inventar.

---

## M24

**Comprobar:** No anunciar stock, precio o reserva ausentes en BusinessFacts.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

Sales sin stock conocido.

No inventar.

---

## M25

**Comprobar:** Separar carga del modelo, primera generación y respuesta; sin reintentos en cascada.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

Fresh launch / cold start.

---

## M26

**Comprobar:** Permiso y background activados; inbox durable, claim y complete observables; no éxito si Android bloquea FGS.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

Background/headless.

---

## M27

**Comprobar:** Abrir UI durante headless; no doble consumidor ni doble envío. Repetir ida/vuelta sin reiniciar datos.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

Abrir/cerrar UI múltiples veces.

No duplicar listeners.

---

## M28

**Comprobar:** Deshabilitar la regla durante borrador: el envío pendiente debe quedar bloqueado.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

Cambiar toggle de regla.

Cambio real en ejecución.

---

## M29

**Comprobar:** Cambiar a Desactivado o Sugerencias durante borrador: cero envío automático.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

Cambiar autonomy mode.

Cambio real.

---

## M30

**Comprobar:** Párrafo completo o bloqueo por truncamiento; jamás enviar una respuesta recortada a mitad.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

Texto largo.

No crash/truncation absurda.

---

## M31

**Comprobar:** Tono cercano solo con relación declarada; no convertir estilo histórico en hechos presentes.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

Slang contacto cercano.

---

## M32

**Comprobar:** Trato neutral cuando no existe relación; comprobar homónimos de dos chats.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

Contacto desconocido.

No usar intimidad falsa.

---

## M33

**Comprobar:** Output limpio sin normalización destructiva del texto recibido; corrector ausente no impide fallback.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

Corrección ortográfica output.

---

## M34

**Comprobar:** Fallo explícito, cero éxito falso, timeout cancela solo su request_id.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

LLM no disponible.

Graceful degradation.

No éxito falso.

---

## M35

**Comprobar:** Presión/temperatura: mantener límites y guardas; registrar memoria, latencia y estado térmico real.

**Estado:** pendiente de ejecución manual. **Dispositivo/APK/modelo:** ____. **Resultado/log:** ____.

Runtime caliente / presión RAM.

No crash.

No pérdida de seguridad.

---

