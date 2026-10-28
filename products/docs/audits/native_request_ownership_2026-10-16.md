# Propiedad y cancelación de inferencia nativa

## Evidencia, sin atribuir más de lo observado

El proceso 16663 mostró Gemma 4 E2B en LiteRT GPU. A las 12:20:14 produjo
un borrador descartado por supersede; a las 12:20:20 produjo otro aceptado
por RemoteInput, sin confirmación de entrega final. No se observaron dos
motores decodificando simultáneamente en ese tramo. La barrera nativa
LocalModelGate serializa LiteRT y MNN.

La inspección encontró fallos concretos en la coordinación Dart:

1. RoutedLlmEngineClient.generate recibía requestId, pero sus rutas LiteRT
   y MNN creaban otro ID, distinto del conocido por quien podía cancelar.
2. cancelRequest elegía el destino por el modelo seleccionado actualmente,
   no por la solicitud que seguía perteneciendo al motor anterior.
3. hasActiveStreamRequest ignoraba trabajo pendiente en un motor no elegido.
4. El cierre normal del stream LiteRT también llamaba cancel; su reserva
   Dart se liberaba después de esperar el cierre de la suscripción.

Estos son defectos verificables de código, no prueba de que todos se hayan
activado en el turno observado ni de que un archivo de pesos esté dañado.

## Corrección acotada

- Conserva el requestId del llamador hasta el adaptador nativo.
- Cada adaptador expone ownsRequest sin revelar datos del chat.
- Cancelación por dueño, no por selección posterior.
- Estado ocupado agregado de los tres transportes existentes.
- Cierra la suscripción LiteRT anterior antes de liberar la reserva y publicar
  stop. Así el consumidor no abre otro receptor mientras se cierra el previo.
  Una finalización normal no se transforma en otra cancelación explícita JNI.
- Si falla el canal, sí solicita cancelación JNI para evitar trabajo sin receptor.
- No cambia pesos, modelo elegido, prompts, historial, sampler, guardas de
  envío, protección térmica ni la barrera de exclusión de motores.

## Validación y límites

Formato y análisis estático de los cinco archivos sin incidencias. Longitudes:
198, 94, 142, 125 y 117 líneas. Sin pruebas automáticas por instrucción del
usuario. Falta validar manualmente cancelación durante cambio de modelo,
requests consecutivos, errores y reanudación con notificaciones reales.

No se garantiza naturalidad por estas correcciones de transporte. Tampoco
se eliminan descartes correctos por mensaje nuevo ni pausas por temperatura.
