# Menú compacto de Automatización

## Alcance

Se ajusta únicamente el menú +/WhatsApp y su formulario de destinatario.
Las cuatro acciones siguen conectadas a sus funciones existentes; no se añaden
herramientas ni botones de QA sin una implementación real.

| Elemento | Antes | Ahora |
| --- | --- | --- |
| Ancho máximo de este menú | 320 dp | 280 dp |
| Alto mínimo de fila | 52 dp | 48 dp, ampliable por el texto |
| Iconos de acción | 22 dp | 18 dp |
| Logo de WhatsApp | 24 dp | 20 dp |
| Título de fila | Denso, dos líneas con recorte | bodyMedium del tema, sin recorte forzado |
| Formulario | Botón a todo el ancho | Campo denso y botón alineado al final |

Los demás consumidores del presentador conservan su ancho máximo de 320 dp.
Se mantiene GlassSurface, el contraste del tema, movimiento reducido y scroll
dentro del espacio disponible sobre el teclado. Reducir el tamaño visual no
reduce la zona táctil de las filas ni el botón de regreso por debajo de 48 dp.

## Flujo conservado

- WhatsApp abre la lista de sus funciones.
- Abrir chat y redactar preparan una orden con el destinatario literal.
- Adjuntar conserva selector y copia de archivo existentes.
- Abrir WhatsApp prepara la misma orden que antes.
- El usuario ejecuta el borrador desde el editor existente. Elegir una función
  no dispara automáticamente envíos ni acciones de otra app.

## Revisión

Se trazaron los callbacks en los archivos actuales porque el grafo no indexa
estos componentes recientes. La revisión independiente no encontró defectos
concretos en layout, semántica o preservación de acciones. Fue una revisión
estática: no acredita aspecto final en el teléfono ni ejecución de WhatsApp.

No se ejecutaron pruebas ni recorridos de dispositivo. El análisis estático
terminó sin incidencias. La compilación e instalación se registran aparte.

## Archivos e instalación

- `lib/core/widgets/nano_anchored_popover.dart`: 170 líneas.
- `lib/features/automation/presentation/widgets/whatsapp_automation_menu.dart`: 36 líneas.
- `lib/features/automation/presentation/widgets/whatsapp_automation_menu_view.dart`: 168 líneas.

Compilación `fullSideloadDebug` completada en 37,6 segundos. Android confirmó
`Success` al actualizar el CPH2557 mediante `adb install -r`. Versión, huella
del APK y estado del paquete: `COMPACT_INSTALLATION.json`. La revisión visual
posterior queda pendiente: no se automatizó la interfaz.
