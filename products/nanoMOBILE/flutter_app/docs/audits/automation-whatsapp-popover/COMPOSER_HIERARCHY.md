# Adjuntos y componente WhatsApp

## Jerarquía aplicada

```text
+
├─ Cámara
├─ Fotos
├─ Archivos
└─ Complementos
   └─ WhatsApp (selección visible)

Icono WhatsApp activo
├─ Abrir chat
├─ Redactar mensaje
├─ Enviar adjunto (solo cuando hay uno preparado)
└─ Abrir WhatsApp
```

El + permanece separado del icono de WhatsApp en el editor y en su estado
reducido. El catálogo de Complementos solo contiene WhatsApp. Seleccionarlo
activa o desactiva su contexto; no abre otra app ni envía información.

## Conexiones reales

- Cámara reutiliza `AndroidCameraCaptureBackend` y la cámara del sistema.
- Fotos utiliza el selector de imágenes; Archivos permite elegir un archivo,
  incluidos vídeos. No se cargan sus bytes completos en Dart.
- El archivo se copia al catálogo privado existente y se muestra por nombre
  en el editor. Cancelar una selección conserva el archivo anterior.
- Quitar un adjunto revoca también el borrador generado que contiene su ruta.
  Reemplazarlo invalida el borrador de la selección anterior.
- Con WhatsApp seleccionado, «Envía el adjunto a (contacto)» se transforma en
  la gramática de archivo y destinatario del ejecutor existente. También puede
  prepararse desde el icono WhatsApp → Enviar adjunto.
- La selección de archivo no activa WhatsApp automáticamente. Ejecutar una
  orden de compartir sin componente seleccionado muestra qué selección falta.
- El flujo de ejecución, permisos, confirmación e identificación nativa del
  contacto permanece en su propietario actual. La selección de menú no ejecuta.

## Depuración adicional del mismo flujo

La revisión independiente encontró y se corrigieron tres problemas:

1. Un borrador generado podía conservar una ruta después de quitar el adjunto.
   Se reconoce y revoca usando la misma normalización `trim` de Ejecutar.
2. Los nombres con dos puntos o paréntesis podían reinterpretarse al preparar
   texto libre. Los formularios delimitan la identidad mediante JSON y el
   adaptador la procesa antes del parser general. Un borrador vacío no se envía.
3. Un comando WhatsApp en mayúsculas podía omitir la advertencia del adjunto.
   Su reconocimiento ahora tiene la misma insensibilidad a mayúsculas.

## Diseño y límites

Se conserva el presentador GlassSurface, ancho máximo de 280 dp, filas con
objetivo táctil mínimo de 48 dp, desplazamiento sobre teclado y adaptación a
texto ampliado. El menú general cambia de contenido en la misma ruta; el cierre
tiene protección contra doble toque. No se crean timers ni bucles de renderizado.

No se añadieron botones de QA ni promesas de navegación o comprensión universal.
Este cambio organiza y conecta los proveedores y el ejecutor que ya existen;
no demuestra que Nano pueda probar por completo cualquier aplicación.

No se ejecutaron pruebas ni automatización de dispositivo. La revisión fue
estática; la comprobación visual de cámara, selectores y menú queda pendiente.
Los archivos, sus tamaños y los resultados de compilación e instalación se
registran en `COMPOSER_HIERARCHY_INSTALLATION.json` cuando terminen.

## Estado de entrega

Análisis estático: sin incidencias. Compilación `fullSideloadDebug`: correcta
en 52,6 segundos. Instalación confirmada por Android con `Success` mediante `adb install -r`
en el CPH2557. Se recuperó la conexión de depuración antes de instalar; se
conservó la fecha de instalación original del paquete. No se abrió Nano ni se ejecutaron acciones desde el teléfono.

### Archivos fuente

- `lib/features/automation/presentation/widgets/automation_input_menu.dart` (63 líneas).
- `lib/features/automation/presentation/widgets/automation_input_menu_view.dart` (132 líneas).
- `lib/features/automation/presentation/widgets/automation_input_attachment.dart` (76 líneas).
- `lib/features/automation/presentation/widgets/automation_attachment_picker.dart` (59 líneas).
- `lib/features/automation/presentation/widgets/automation_dashboard.dart` (196 líneas).
- `lib/features/automation/presentation/widgets/automation_dashboard_input.dart` (116 líneas).
- `lib/features/automation/presentation/widgets/automation_dashboard_lifecycle.dart` (35 líneas).
- `lib/features/automation/presentation/widgets/automation_dashboard_execution.dart` (150 líneas).
- `lib/features/automation/presentation/widgets/whatsapp_automation_menu.dart` (36 líneas).
- `lib/features/automation/presentation/widgets/whatsapp_automation_menu_state.dart` (74 líneas).
- `lib/features/automation/presentation/widgets/whatsapp_automation_menu_view.dart` (144 líneas).
- `lib/core/widgets/navigation/nano_input_tool_controls.dart` (76 líneas).
- `lib/core/widgets/navigation/nano_input_context_bar.dart` (64 líneas).
- `lib/core/widgets/navigation/nano_command_launcher.dart` (62 líneas).
- `lib/core/widgets/navigation/nano_nav_search_input_row.dart` (152 líneas).
- `lib/features/automation/engine/planning/whatsapp_automation_input.dart` (131 líneas).

## Archivos fuente de esta revisión

- `lib/features/automation/presentation/widgets/automation_input_menu.dart` (63 líneas).
- `lib/features/automation/presentation/widgets/automation_input_menu_view.dart` (132 líneas).
- `lib/features/automation/presentation/widgets/automation_input_attachment.dart` (76 líneas).
- `lib/features/automation/presentation/widgets/automation_attachment_picker.dart` (59 líneas).
- `lib/features/automation/presentation/widgets/automation_dashboard.dart` (196 líneas).
- `lib/features/automation/presentation/widgets/automation_dashboard_input.dart` (116 líneas).
- `lib/features/automation/presentation/widgets/automation_dashboard_lifecycle.dart` (35 líneas).
- `lib/features/automation/presentation/widgets/automation_dashboard_execution.dart` (150 líneas).
- `lib/features/automation/presentation/widgets/whatsapp_automation_menu.dart` (36 líneas).
- `lib/features/automation/presentation/widgets/whatsapp_automation_menu_state.dart` (74 líneas).
- `lib/features/automation/presentation/widgets/whatsapp_automation_menu_view.dart` (144 líneas).
- `lib/core/widgets/navigation/nano_input_tool_controls.dart` (76 líneas).
- `lib/core/widgets/navigation/nano_input_context_bar.dart` (64 líneas).
- `lib/core/widgets/navigation/nano_command_launcher.dart` (62 líneas).
- `lib/core/widgets/navigation/nano_nav_search_input_row.dart` (152 líneas).
- `lib/features/automation/engine/planning/whatsapp_automation_input.dart` (131 líneas).
