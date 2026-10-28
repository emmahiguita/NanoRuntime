# Auditoría actual: Automatización, Búho y WhatsApp instalado

Fecha: 26 de octubre de 2026. Raíz de las rutas de código: `nanoMOBILE/flutter_app`.
Los dos prompts aportados se aplican como criterios de auditoría. No equivalen a evidencia.

## A. Diagnóstico y alcance

Este ciclo revisa las entradas del dashboard, el Búho Flutter y el puente Android;
preparación WhatsApp, planes, adjuntos, confirmación, cancelación y sesión de voz.
Incluye revisión de geometría del panel, políticas de animación y adaptadores ya corregidos.
No constituye una auditoría terminada de todas las pantallas, JNI, C++ o de todo Nano.
El índice `nano-mobile` existe pero contiene versiones anteriores de símbolos;
las decisiones se contrastaron con las fuentes actuales.

Ocho problemas concretos se corrigieron en las fuentes, con análisis estático.
La ejecución funcional, visual y térmica permanece **NO VERIFICADA** en este ciclo.
No se ejecutaron pruebas automatizadas ni se enviaron mensajes o archivos.

## B. Arquitectura real y responsabilidades

| Entrada/componente | Archivo | Responsabilidad y dependencia |
| --- | --- | --- |
| Barra de Automatización | `lib/features/automation/presentation/widgets/automation_dashboard_execution.dart` | Entrada, normalización, id y cancelación; distingue @ de objetivos |
| Preparación del dashboard | `lib/features/automation/presentation/widgets/automation_dashboard_goal_execution.dart` | Conserva el plan observado y el token al confirmar |
| Runner del dashboard | `lib/features/automation/presentation/widgets/automation_dashboard_runner.dart` | Invoca AutomationEngine con plan e isCurrent |
| Adaptador Búho | `lib/features/chat/nano_everywhere/nano_action_port_adapter.dart` | Consume órdenes/objetivos del mismo coordinador |
| Runner Búho | `lib/features/chat/nano_everywhere/nano_automation_goal_runner.dart` | Mantiene identidad, plan y confirmación propios |
| Gramática compartida | `lib/features/automation/engine/planning/whatsapp_component_requests.dart` | Normalización pura de respuesta, formulario y ventana |
| Preparación común | `lib/features/automation/application/whatsapp_ui_goal_preparer.dart` | ToolCall sustentado en snapshot o archivo real; no envía |
| Artefactos reales | `lib/features/automation/application/automation_artifact_commands.dart` | Busca producto/PDF exacto y único en repositorios existentes |
| Contrato adjunto | `lib/features/automation/presentation/widgets/automation_input_attachment.dart` | Conserva ruta y destinatario; no ignora un archivo al enviar texto |
| Motor público | `lib/features/automation/application/automation_engine.dart` | Fachada del coordinador y ledger existentes; no hay segundo motor |
| Voz compartida | `lib/features/automation/engine/voice/voice_runtime.dart` y partes `voice_session_*` | STT/TTS por dueño y revisión; fin observado del audio |
| Voz dashboard | `lib/features/automation/presentation/widgets/automation_dashboard_voice_controller.dart` | Captura/conversación y cierre solo de sus recursos |
| Voz Búho | `lib/features/chat/nano_everywhere/nano_assistant_voice.dart` | Dictado a borrador, lectura explícita y liberación propia |
| Puente externo | `lib/features/chat/nano_everywhere/nano_overlay_runtime.dart` | Canal Android al controlador activo y misma sesión TTS |

Flujo: entrada → preparación compartida → AutomationEngine → coordinador →
políticas/confirmación → ejecutor → CommitGuard → observación → ledger/resultado.
El overlay nativo conserva su layout apropiado para Android y reutiliza el puente.
No se añadieron dependencias ni otro planificador, ejecutor o base de datos.

## C. Hallazgos y correcciones

| ID / prioridad | Evidencia de causa | Corrección / estado |
| --- | --- | --- |
| AUD-01 / P1 | El dashboard pasaba el objetivo original, perdiendo la preparación del componente | Pasa command y PreparedAutomationGoal al runner; implementado y revisado estáticamente |
| AUD-02 / P1 | El normalizador puede devolver texto natural; el Búho lo trataba como @ | Solo isToolCommand permite runCommand; resto a runGoal |
| AUD-03 / P1 | Reconocimiento asíncrono del dashboard sin invalidación al desmontar | dispose, generación y dueño; callback tardío no inicia una tarea |
| AUD-04 / P1 | speak confirma aceptación; el follow-up de 8 s expiraba mientras sonaba | speaking hasta silencio observado; timer posterior; espera ligada a revisión |
| AUD-05 / P1 | Lectura Búho/dashboard sobre el mismo backend sin identidad común | Sesión inyectada desde ScaffoldShell; stop(owner) no detiene otra interfaz |
| AUD-06 / P1 | Comandos directos devolvían null a conversación; el siguiente turno se perdía | Devuelven AutomationResult real y usan la misma salida de voz |
| AUD-07 / P2 | Mínimos 280×190 del panel podían superar constraints pequeños | Ancho/alto acotados al espacio efectivo, conservando curvas y sprites |
| AUD-08 / P2 | debugPrint incluía la transcripción reconocida | Registra presencia/latencia, sin el texto dictado |

No se eliminan componentes por similitud visual. Se movieron cuatro contratos de
Búho a Automatización para compartir responsabilidad; mapa de movimientos en el inventario.
Los archivos nuevos/modificados y las fuentes conservadas de correcciones previas
figuran con líneas y SHA256 en `INVENTARIO_CONEXION_ACTUAL.json`.
La deuda heredada de tamaño se enumera por separado en `INVENTARIO_DEUDA_LINEAS.json`;
no se refactoriza todo el producto para alterar una métrica.

## D. Diseño, consistencia y accesibilidad

| Aspecto | Nano interno | Búho externo | Evaluación |
| --- | --- | --- | --- |
| Composición | + → Cámara/Fotos/Archivos/Complementos; WhatsApp contextual | Controles nativos reducidos | Mismo contrato de adjunto; layout diferente justificado |
| Temas | Theme/ColorScheme y NanoGlass | NanoOverlayStyle lee preferencias al abrir | Revisión de código; contraste real y cambio con panel abierto NO VERIFICADOS |
| Geometría | LayoutBuilder, scroll del panel y límites al espacio | Ventana Android dependiente de insets/bounds | Ajuste del mínimo Flutter; rotación y teclado NO VERIFICADOS |
| Iconos/animación | Recursos originales y política de movimiento reducido | Ciclo de pantalla/ahorro y sprites existentes | Animación preservada; no medición de cuadros |
| Estado | Resultado del mismo motor | NanoTurnReceipt tipado | Sin éxito fabricado por planificar o aceptar un lanzamiento |

No se tomaron capturas ni se navegó por el teléfono. No se certifican todos los
temas, escalas de texto o ausencia universal de overflow basándose solo en fuentes.
No se modificó la interfaz de WhatsApp ni se añadieron tarjetas o pantallas.

## E. WhatsApp: matriz de capacidades y QA

| Caso | Lo conectado en código | Evidencia / pendiente |
| --- | --- | --- |
| Responder aquí | Snapshot de paquete/cabecera/editor, raíz y huella; borrador vacío, revalidación y único tap | Implementado; manual NO EJECUTADO |
| Cambio de chat/cancelación | Se conservan plan, ventana, contexto y token; se revalida antes de escribir y del commit | Inspección estática; carreras reales NO VERIFICADAS |
| Texto por nombre/número/usuario | Resolver y normalizador existentes; no elige un homónimo arbitrariamente | Compatibilidad exacta con UI/contactos del teléfono NO VERIFICADA |
| Formulario PDF de biblioteca | Coincidencia exacta/única y archivo real, share_file | Sintaxis compartida prepara paquete personal; Business por esta sintaxis NO implementado |
| Formulario enlace | HTTP/HTTPS, host, sin credenciales; conserva URL literal como mensaje | No abre/rellena el formulario; envío manual NO EJECUTADO |
| Archivo/foto/vídeo | Selector existente y ruta real; orden explícita de compartir | Permisos/MIME/selector nativo y envío NO VERIFICADOS en ejecución |
| Personal/Business | Respuesta in situ respeta paquete observado; launcher acepta Business explícito; backend no cambia cuenta silenciosamente | No equivale a declarar todas las sintaxis compatibles con Business |
| Ventana flotante | Feature pública, ActivityOptions por options y observación APP/foco/bounds | Consulta previa CPH2557 anunció PiP, no freeform; no se repitió con teléfono ausente |
| Retorno | Rutas existentes y comprobación de Nano enfocada en respuesta in situ | Recorrido real NO EJECUTADO |
| Eco local | Se distingue de entrega/lectura | No se afirma recepción ni lectura por el contacto |

Recorrido manual pendiente: editor vacío/con borrador; chat cambiado; cancelación
antes de tap y después de tap; ausencia de eco; WhatsApp ausente; Business explícito;
PDF inexistente/ambiguo; enlace; adjunto con permiso perdido; retorno; cierre del
Búho; tema claro/oscuro; horizontal/teclado. Ninguno se presenta como aprobado.
Nunca repetir un envío de resultado incierto para intentar demostrar éxito.

## F. Rendimiento, lifecycle y nativo

Se invalidan callbacks antes de liberar recursos; timers de follow-up se cancelan
al sustituir el dueño. La observación TTS es acotada y solo existe durante lectura.
Una espera antigua no debe detener síntesis de un dueño nuevo. El dictado no
activa un envío desde el Búho; el usuario revisa el borrador.

`nano_local_provider.dart` usa el cliente y modelo seleccionados, requestId y
conexión propietaria; no carga un motor paralelo. Cancelación cooperativa MNN
puede retrasarse en prefill: no se declara solucionada cambiando el timeout.
No se editó C++/llama.cpp ni se certifica su memoria/hilos en este ciclo.
Sin perfilador ni mediciones comparables: calor, latencia y FPS **NO VERIFICADOS**.

## G. Verificación y entorno

Análisis estático: `build/nano-whatsapp-connected-analysis.log`.
Compilación y disponibilidad de instalación: `CONEXION_ACTUAL_VERIFICACION.json`.
No confundir instalación con verificación funcional de extremos.
El bloqueo ADB se diagnosticó con ARTEMIS, sin exploración ni tareas de UI.
Tras reiniciar el servidor identificado, ADB respondió. En la instalación posterior
el OPPO CPH2557 volvió a conectarse y `adb install -r` confirmó `Success`.
No se solicita crear un emulador ni instalar software ajeno para simular evidencia.

## H. Aprendizaje y skill

Se reutiliza `nano-owl-assistant-integrity` y se actualiza con preparación común,
contrato natural/@, voz con dueño, fin real de TTS, devolución del siguiente turno
y límites de geometría. Formato validado; no activa tareas periódicas o pruebas.
Separar responsabilidad permite compartir el caso de uso sin copiar layouts.
El token identifica una acción pendiente; un booleano genérico no la autoriza.
La revisión estática comprueba contratos, no la entrega de un mensaje externo.

## I. Restricciones y pendientes

La auditoría integral de todo Nano sigue abierta: restantes pantallas, contraste
medido, JNI/C++, modelos multimodales y rendimiento requieren ciclos con alcance
y evidencia propios. No se declaran auditados por haber leído este checklist.
No se ha demostrado automatización universal de cualquier formulario o aplicación.
Para ejecutar envíos hacen falta permisos, contexto inequívoco y destinatario autorizado.
Esta revisión está instalada conservando datos. Las comprobaciones funcionales
y visuales manuales siguen pendientes; la instalación no las acredita.

## J. Resultado del ciclo

Correcciones implementadas y revisadas estáticamente. Consultar el registro final
para APK, hash, compilación e instalación. Pruebas funcionales/visuales pendientes.
No se declara el sistema «100 % funcional» ni se inventan capturas o métricas.
