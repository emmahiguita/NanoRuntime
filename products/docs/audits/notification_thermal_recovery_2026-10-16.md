# Recuperación de notificaciones durante pausa térmica

## Fallo confirmado

A las 12:05:38 el compositor recuperó 50 entradas canónicas y devolvió null
por `thermal 3: suprimido`. El pipeline registró failed y el router confirmó
el lote como procesado. Android también reportó estado térmico 3.

## Corrección

Se consulta la misma API térmica antes de admitir eventos live y antes de
reclamar el inbox o marcar snapshots de recuperación. Con estado >= 3 no
se reserva deduplicación, no se llama al pipeline y no se confirma el lote.
El inbox nativo sigue siendo dueño de los eventos persistidos.

El drenado existente cada 20 segundos vuelve a consultar la temperatura.
Se registran deferred_before_admission y resumed solo en transiciones.
No hay nuevo timer, servicio, generación de respuestas fijas ni anulación
de la protección térmica. El cierre del router conserva su cancelación y
restablece la bandera de diagnóstico.

## Alcance y límites

- La espera no garantiza que WhatsApp mantenga activo RemoteInput.
- La recuperación depende del inbox y notificaciones que Android conserve.
- No se reenvían resultados de entrega desconocida.
- El pipeline conserva deduplicación, permisos, control humano y supersede.
- Las notificaciones se procesan al reanudar; durante la pausa puede demorarse
  también la incorporación al panel desde esta ruta.
- El compositor conserva su segunda comprobación: si la temperatura sube
  después de admitir el turno, aún puede rechazarlo. Esta entrega corrige la
  pérdida cuando el teléfono ya estaba caliente al recibir o recuperar.
- API no disponible (-1) conserva la política anterior; no prueba enfriamiento.
- No se modifica el modelo elegido ni el estado térmico de Android.

## Verificación

Análisis estático sin incidencias. Archivos de código modificados: 196, 74 y
37 líneas. No se ejecutaron tests automáticos. La reanudación, calidad de la
respuesta y entrega requieren una notificación real y enfriamiento físico.

APK fullSideload profile compilado e instalado conservando datos, actualización
Android 12:12:43, PID 16663. A las 12:13:01.445 el teléfono confirmó:
`stage=thermal source=cold_start outcome=deferred_before_admission status=3
inbox=unacknowledged`. Android seguía en estado 3. Esto verifica el
aplazamiento real, no todavía su reanudación ni la entrega de una respuesta.
Grafo del código actualizado.
