# Auditoría del Búho: apertura y trabajo fuera de Nano
Fecha: 27 de octubre de 2026.

## Resultado del ciclo

Se corrigieron causas demostrables de apertura automática y de propiedad de
ventanas, preservando sprites y tiempos de la animación. Análisis estático sin
incidencias. Compilación fullSideloadDebug exitosa. **34 pruebas aprobadas**:
5 nuevas de visibilidad/entradas y 29 existentes de contratos WhatsApp.

Una versión de comprobación se instaló con `adb install -r` (Success), conservando
datos. Después se detectó un retorno rápido que Android no comunicaba aún como
pausa completa; ese último ajuste también compiló y pasó las pruebas, pero el
**APK final no pudo instalarse** porque el OPPO pasó a offline y luego dejó de
aparecer por USB. No se afirma que el binario final esté instalado.

## Hallazgos y correcciones

| ID | Causa | Corrección |
| --- | --- | --- |
| OWL-01 | NanoAiController arrancaba con isVisible=true | Inicia oculto; un resultado o un motor preparado no abre su UI |
| OWL-02 | La marca de la cabecera no tenía entrada al panel al quitar el orbe automático | La marca existente abre Búho AI mediante callback explícito, sin nuevo botón redundante |
| OWL-03 | Wrapper no invalidaba presentación al salir | Oculta en inactive/hidden/paused; una salida rápida también queda cubierta |
| OWL-04 | Servicio externo podía seguir dibujándose sobre MainActivity | NanoOverlayHostVisibility observa Activity por eventos, aparta ventanas en Nano y deja burbuja compacta fuera |
| OWL-05 | Flutter no dibujaba su panel cuando el servicio externo estaba activo | Servicio activo y ventana visible se separan; ambos paneles no compiten en Nano |
| OWL-06 | Acceso explícito en arranque frío sin prompt se perdía | takePendingEntry consume open_assistant/open_owl_hub una vez y devuelve open=true |
| OWL-07 | Un callback tardío podía reabrir después de hide | Revisión de lifecycle, borrador reveal:false y sincronización que no hace visible un borrador oculto |

La extracción NanoOverlayWindowLayout conserva geometría y flags públicos
existentes. No crea otro ejecutor, modelo, base de datos o servicio periódico.
Ocultar la presentación **no cancela ni duplica una acción externa**.
El servicio externo se activa únicamente por la acción existente del usuario:
Ajustes → Asistente superpuesto → Asistente flotante.

## Mapa de responsabilidades

- `nano_ai_controller.dart` / `nano_ai_panel_state.dart`: visibilidad y borrador.
- `nano_floating_wrapper.dart` / `nano_floating_wrapper_entry.dart`: lifecycle,
  entrada explícita y revisión tras esperas Android.
- `nano_floating_assistant.dart`: actualiza editor oculto sin expandirlo.
- `automation_header_identity.dart`, `automation_agent_header.dart`,
  `automation_dashboard_content.dart`: entrada explícita con el icono existente.
- `NanoFloatingChannel.kt`: consume los extras de apertura una sola vez.
- `NanoFloatingService.kt`: dueño de ventanas, panel, burbuja y observadores.
- `NanoOverlayHostVisibility.kt`: visibilidad de la Activity, sin polling.
- `NanoOverlayWindowLayout.kt`: medidas y flags de ambas ventanas.
- Tres archivos de tests contienen casos de regresión y dobles explícitos.

Rutas y hashes exactos de las 15 fuentes en [VERIFICACION.json](VERIFICACION.json).
Todas están por debajo de 200 líneas. Se documentaron los contratos modificados.
La revisión independiente encontró OWL-06/07; se corrigieron y revisaron sus
dependencias inmediatas sin hallazgos adicionales demostrados.

## Pruebas locales ejecutadas

[Salida completa](pruebas-regresion.log), exit code 0:

1. Arranque/recreación no muestran Búho.
2. Apertura explícita y ocultación sin reapertura por notificaciones.
3. Ocultar durante acción no cancela ni repite al dueño de ejecución.
4. Wrapper inicia oculto, funciona con servicio externo activo, sale sin reabrir,
   y conserva un borrador tardío oculto; también verifica inactive.
5. Entrada explícita sin texto abre una vez y no se repite al volver.
6. Las 29 pruebas existentes de destinatarios, adjuntos y herramientas WhatsApp.

Los casos de canal y puertos usan **dobles explícitos**, no ventanas Android reales.
Los primeros intentos del harness requirieron transiciones Flutter legales y
respuesta de plugin de Accesibilidad identificada; no se ocultaron excepciones ni
se desactivaron verificaciones de timers para obtener aprobación.

## Observado en el OPPO CPH2557

| Caso real | Observado | Estado |
| --- | --- | --- |
| Instalar primera corrección | Streamed Install / Success | Comprobado |
| Inicio limpio tras force-stop/start | Sin panel y sin orbe automático | Comprobado, primera compilación |
| Pulsar icono de cabecera | Panel Búho AI visible | Comprobado |
| Salida completa a launcher y regreso | Panel y orbe ausentes | Comprobado |
| Salida rápida de 500 ms | El panel podía conservarse antes de paused | Detectado y corregido; revisión final de teléfono pendiente |
| Arranque explícito Android sin texto | Contrato comprobado en widget test | Prueba de Intent real pendiente |
| Búho externo sobre WhatsApp | No se llegó a activar/probar por desconexión | NO VERIFICADO en este ciclo |
| Lectura de pantalla/control de WhatsApp desde el overlay | Sin ejecución real en esta revisión | NO VERIFICADO |
| Envíos desde Búho | Ninguno realizado | No probado ni autorizado otro envío |

La prueba real de envío desde la barra de Automatización del ciclo anterior es
independiente y está en `../qa-whatsapp-2026-10-27/INFORME.md`; no demuestra por sí
sola funcionamiento del Búho externo.

Capturas de la primera compilación:
[inicio limpio](01-inicio-limpio.jpg),
[apertura explícita](02-apertura-explicita.jpg).

## Bloqueo de dispositivo y permisos

Android anunció SYSTEM_ALERT_WINDOW allow. Tras la actualización, la lectura de
Accesibilidad mostraba el servicio de Nano sin conectar y solo el helper activo.
Se abrió la pantalla visible de Android para restablecer el servicio de Nano;
no se concedieron permisos de Nano mediante comandos ocultos. La lectura de esa
pantalla dejó de estar disponible y luego se confirmó pérdida de la conexión.
El usuario indicó haberlo activado, pero no fue posible comprobar el estado final.

Se diagnosticó con ARTEMIS, recuperó el helper de inspección y se intentó recuperar
ADB de forma acotada. Después del aviso del usuario y de reconectar el transporte,
el dispositivo siguió offline y finalmente no apareció. No se repitieron acciones
de WhatsApp ni se enviaron mensajes para intentar demostrar éxito.

## Verificación pendiente y límites

Con teléfono autorizado como device:
1. Instalar el APK final conservando datos.
2. Repetir inicio normal, acceso explícito y retorno rápido.
3. Verificar Accesibilidad de Nano activa.
4. Activar el asistente externo desde el ajuste existente.
5. Abrir WhatsApp instalado, expandir burbuja y comprobar Leer pantalla.
6. Desde WhatsApp, ejecutar una orden de solo abrir el chat de prueba por número.
7. Volver a Nano y comprobar que la ventana externa se aparta y no se abre un panel.

No se certifican recepción de mensajes, comprensión de imágenes, modelo de voz,
temperatura, FPS o ausencia de bugs generales. No se tocaron temas ni sprites.
La skill existente nano-owl-assistant-integrity recoge los patrones y validó su
formato; no inicia tareas periódicas ni pruebas adicionales.

