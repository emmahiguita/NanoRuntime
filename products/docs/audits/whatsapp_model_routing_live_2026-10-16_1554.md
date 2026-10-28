# Diagnóstico de WhatsApp y modelos — 2026-10-16

Lectura del teléfono CPH2557, paquete dev.nanoai.mobile, PID 18010. APK actualizado a las 14:49:48. No se modificó configuración ni código funcional ni se enviaron mensajes desde las herramientas.

## Fallo reproducido

Turno recibido a las 15:53:48; regla admitida a las 15:53:50. Acceso a notificaciones habilitado, listener conectado, canReply=true, agente personal autónomo y sin ownership humano.

Modelo seleccionado e invocado: Qwen2.5-Omni-3B-MNN. No se observó una selección equivocada de backend en este intento.

MNN procesó 357 tokens completos en 23328 ms; TTFT 23762 ms; 14 tokens generados a 4.36 tok/s. Redacción total 26691 ms, respuesta de 38 caracteres y sin eco detectado. A las 15:54:17 la decisión fue holdForApproval, confianza 0.30, razón «estado temporal histórico sin evidencia presente verificada». Estado terminal drafted; este turno no alcanzó el despacho.

## Causa en la decisión

conversation_decision_safety.dart: callCenterTurn es verdadero para todos los turnos personal/general; no significa que la respuesta tenga tono de operador.

conversation_decision_live_state.part.dart: ese flag habilita la guarda de actividad también cuando liveStateRequired=false.

conversation_decision_guards.dart: affirmsOwnerActivity devuelve true ante cualquier token «estoy», sin distinguir cortesía, sujeto, pregunta o actividad física. Los dos últimos borradores pendientes contienen los indicadores «estoy» y «bien». Se inspeccionaron indicadores, sin volcar los cuerpos privados.

conversation_agent_live_state_classifier.dart, en cambio, excluye expresamente bienestar cotidiano de estado vivo. Las dos decisiones lingüísticas no son coherentes entre sí.

Esto prueba un bloqueo léxico de la respuesta cotidiana. No prueba que todas las afirmaciones del borrador sean correctas ni autoriza a eliminar las verificaciones de ubicación, planes o actividad reales.

## Contexto y rendimiento

El modelo recibió 12 mensajes de historial; el almacén ofrecía 53 entradas. El turno utilizó sistema compacto de 406 caracteres, 317 de prompt y 177 de historial. La persona recuperada fue vacía. Historial disponible no equivale a comprensión verificada.

La caché nativa tenía 1388 caracteres, pero se ejecutó prefill completo. No se ha probado por qué el historial no era reutilizable; puede divergir legítimamente al excluir borradores no enviados o cambiar la ventana. No se debe forzar KV compartido ni reutilizar prefijos incompatibles.

A las 15:55:26 otro turno de 17 caracteres fue admitido como continuación social y llegó a MNN con 12 mensajes de historial. Prefill completo de 361 tokens en 21613 ms; TTFT 22035 ms; 6 tokens a 4.23 tok/s. Produjo respuesta de 15 caracteres a las 15:55:49 y volvió a quedar holdForApproval a las 15:55:50 por el mismo motivo, terminal drafted. Dos turnos consecutivos reproducen la retención.

## Qué falta para conversación real

1. Unificar la distinción semántica entre cortesía conversacional y afirmaciones verificables del dueño; conservar guardas de identidad, permisos y acciones.
2. Evaluar entrada completa e historial con el modelo; usar reglas deterministas para transporte y permisos, sin pretender resolver comprensión por listas de palabras. La tolerancia universal a errores ortográficos no está validada.
3. Medir prefijo/KV y decode por turno en este dispositivo antes de atribuir lentitud al runtime o cambiar modelo. La ingeniería de Gallery no valida automáticamente MNN ni la decisión posterior de Nano.
4. Validar conversación de varios turnos con correcciones, errores ortográficos, signos, referencias y mensajes compuestos; comprobar respuesta visible en WhatsApp. Los contadores de despacho o RemoteInput no demuestran entrega.

Diagnóstico, sin cambios funcionales, compilación ni pruebas automatizadas.
