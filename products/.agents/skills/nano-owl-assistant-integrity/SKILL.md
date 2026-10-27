---
name: nano-owl-assistant-integrity
description: Maintain Nano Búho turn ownership, real voice, draft preservation and shared attachment routing without changing its approved animation.
---

# Búho: sesión y ejecución reales

Aplica al asistente Flutter y al overlay Android de Nano Mobile. Comprueba las
llamadas actuales; esta skill no autoriza pruebas, envíos ni acciones de teléfono.

## Propiedad del turno

- `NanoAiController.submit` devuelve el `NanoTurnReceipt` propio. No construyas
  callbacks a partir de `answers` mutable ni presentes una respuesta anterior.
- Consulta, acción y preparación de archivo comparten admisión. Cancelar invalida
  el resultado, pero el bloqueo dura hasta que termina el trabajo propietario.
- El adaptador conserva executionId y reutiliza el coordinador de Automatización.
  Las órdenes naturales fuera del router atómico llegan a runGoal; sin plan
  verificable se detienen, sin convertirse en captura exitosa.
- Decide por herramienta explícita: una URL dentro del mensaje no activa Media.
- No reintentes efectos inciertos. Apertura, clic, retorno y entrega son distintos.

## Voz y borradores

- `NanoAssistantVoice` y `NanoVoiceCapture` reconocen voz real, preparan texto y
  nunca ejecutan ni autoenvían. No prometas voz offline sin verificar el motor.
- Dictado añade al borrador existente; conserva destinatario. Los prompts externos
  mantienen reemplazo explícito. No borres el editor ante ocupado/error.
- `NanoOverlaySession` conserva borrador al desmontar la ventana para abrir otra app.
- Cerrar/cancelar invalida callbacks tardíos y libera micrófono/lectura propios.
  TTS aceptado no acredita audio finalizado.
- Publica el resultado si se reabrió el panel. Usa generaciones para impedir que
  un callback antiguo sobrescriba otra intención visible.

## Modelo, adjuntos y contexto

- `buildNanoRuntimeProvider` usa el runtime seleccionado. No cargues otro motor.
  Cancela por requestId en el router antes de cerrar la conexión/lease propio.
  Cancelar solo la suscripción no acredita detener la generación GGUF.
- Conserva el límite real de inactividad del backend; el prefill MNN puede retrasar
  su cancelación cooperativa. Un timeout menor no resuelve ese límite nativo.
- Reutiliza `AutomationAttachmentPicker` y `prepareNanoAttachment` en ambos paneles.
  Preparar no envía. Quitar archivo revoca borradores que contienen su ruta.
- `NanoArtifactCommands` exige producto/PDF exacto y único del negocio configurado.
  No elijas el primero ni otra biblioteca, ni añadas otro envío de texto.
- Leer pantalla obtiene texto accesible de una ventana externa; no es foto, OCR
  ni VLM. No atribuyas a una respuesta del modelo evidencia de acción ejecutada.
- No añadas conversaciones anteriores al proveedor por conveniencia. Revisa payload
  y destino autorizado antes de incorporar datos ajenos a la consulta actual.

## Diseño y evidencia

Preserva sprites y tiempos aprobados del búho al conectar controles. Usa menús
anclados y altura adaptativa. Mantén fuentes modificadas menores a 200 líneas.
Distingue editado, compilado, instalado y observado; documenta lo manual pendiente.
Referencia: `../../../nanoMOBILE/flutter_app/docs/audits/owl-whatsapp-flow-2026-10-26/IMPLEMENTACION_ASISTENTE.md`.

## Objetivos y confirmaciones del motor

`NanoAutomationGoalRunner` conecta runGoal sin duplicar percepción o planificación.
La normalización WhatsApp es pura: solo puede caer a runGoal antes de ejecutar
cualquier efecto. Enmascara identidades/payload citados antes de buscar conectores.
Una pausa conserva ActionConfirmation y executionId originales. Confirmar devuelve
el token consumible exacto; una orden nueva o cancelar lo descarta. No uses un
bool genérico para autorizar. Un adjunto preparado no debe transformar Confirmar acción.
Preserva las categorías de resultado de AutomationResult y la bitácora existente.

## WhatsApp dentro de la app

Para responder en «este chat», no resuelvas su título en la agenda ni reabras
un teléfono: puede ser un grupo homónimo. Usa replyInPlace, ventana/raíz, huella
del contenido visible, editor vacío, CommitGuard, texto exacto y un único tap.
La huella es evidencia local, no JID. Cambios observables abortan sin reintentos.
Conserva packageName personal/Business y excluye Cloud cuando es explícito.
Revisa OwnedToolReport y la frontera claim→dispatch: perder allí el token vuelve
ineficaz propagar cancelación solo desde el runtime hasta el handler.
Ventanas: comprueba FEATURE_FREEFORM_WINDOW_MANAGEMENT; PiP no equivale a freeform.
Pasa ActivityOptions al parámetro options de startActivity. No inventes extras OEM.
Distingue soporte, lanzamiento aceptado y ventana APP activa/enfocada reducida.
Los formularios aquí se comparten como PDF real o enlace literal; no se rellenan.
