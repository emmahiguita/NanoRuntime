# Búho conectado a los objetivos de Automatización

## Causa y cambio

Antes el búho resolvía una lista corta de verbos y llamaba a runCommand.
Las instrucciones fuera de esa lista pedían aclaración; no llegaban a runGoal,
aunque el motor de Nano ya tenía TaskPlanner, TaskOrchestrator, percepción de
pantalla, gobernanza y verificación de pasos.

Ahora NanoAutomationGoalRunner usa AutomationEngine.runGoal, la misma fachada
pública de Automatización. Las órdenes compuestas y las acciones naturales que
no encajan en el router atómico conservan su objetivo completo. Los comandos
explícitos, artefactos y envíos atómicos mantienen sus rutas existentes.
No se añadió un segundo ejecutor, temporizador de observación ni otro modelo.

## Ciclo real

1. El usuario elige Controlar apps o WhatsApp, escribe o dicta y pulsa ejecutar.
2. NanoActionInput conserva la identidad/payload y decide preparación atómica.
3. NanoActionPortAdapter asigna un executionId propietario al turno admitido.
4. Para objetivos, NanoAutomationGoalRunner llama al coordinador existente.
5. El coordinador decide entre catálogo, planificación y navegación semántica;
   resuelve controles observados y aplica sus políticas antes de actuar.
6. El resultado de dominio distingue verificado, no verificado, pausa, denegado,
   sin plan, fallo, incierto y cancelado. El búho no cambia esas categorías a éxito.
7. La bitácora existente registra la ruta y el estado real de la llamada.

Ejemplos de objetivos dirigidos al motor existente:
- Controlar apps: `Abre Chrome y busca Nano AI`.
- WhatsApp: `Abre WhatsApp y busca a Emm y envíale: Hola, ¿cómo vas?`.
- Los nombres entre comillas siguen siendo datos: una conjunción dentro del
  contacto no se convierte en otra acción.
Estos ejemplos describen rutas implementadas; no se ejecutaron en dispositivo.

## Confirmación y cancelación

Una pausa guarda en memoria el objetivo y ActionConfirmation del motor. El
usuario escribe `Confirmar acción` para devolver ese token exacto al mismo
executionId. El journal verifica firma, paso, expiración y consumo. No se usa
confirmed=true. Una instrucción nueva descarta la confirmación anterior.
Una confirmación sin token vigente pide aclaración y no ejecuta.

`Cancelar acción` descarta la pausa y solicita detener únicamente la ejecución
propietaria. El botón principal del overlay nativo permite solicitar detener
consultas con cancelación conectada; cámara/selector y descargas nativas no
ofrecen ese control sin soporte. No se promete revertir un envío ya iniciado.
El bloqueo del controlador dura hasta que la operación libera realmente su dueño.

## Archivos de esta conexión

En lib/features/chat/nano_everywhere:
- Nuevos: nano_action_input.dart, nano_automation_goal_runner.dart.
- Modificados: nano_action_port_adapter.dart, nano_providers.dart,
  nano_assistant_panel.dart, nano_assistant_panel_actions.dart,
  nano_overlay_runtime.dart, nano_turn_receipt.dart.
En android/app/src/main/kotlin/dev/nanoai/mobile/services:
- NanoGeminiInputBar.kt, NanoGeminiOverlayView.kt, NanoOverlayActions.kt.

## Evidencia y límites

Análisis estático Dart: sin incidencias. Revisión independiente solo lectura:
corregidas ruta de navegación contextual, revocación de pausa y protección de
identidades citadas; sin otro defecto bloqueante demostrado en este alcance.
Compilación final y huellas de fuentes/APK: OBJETIVOS_VERIFICACION.json.
No se ejecutaron tests ni recorridos, envíos o capturas del teléfono.

La percepción sigue siendo accesibilidad y los perceptores integrados del motor.
No se añadió comprensión de imágenes/vídeos, memoria conversacional ni una
conversación de voz continua. Que runGoal reciba una instrucción no garantiza
que cualquier secuencia libre esté soportada: sin plan/evidencia, debe detenerse.
Los planes semánticos tienen su propio vocabulario y sus límites; la aplicación
no certifica automáticamente todos los subobjetivos que un usuario pueda expresar.

## Entrega

fullSideloadDebug compiló. ADB confirmó `Success` al actualizar con `install -r`
en CPH2557, conservando datos. No se abrió la app ni se ejecutaron recorridos.
Las once fuentes Dart/Kotlin de esta conexión tienen menos de 200 líneas.
