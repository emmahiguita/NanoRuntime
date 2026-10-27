# Botón +: fallo real del menú

## Causa registrada

Tras la pulsación manual del usuario, Nano registró:

```text
explicitChildNodes must be set to true if scopes route is true
SemanticsAnnotationsMixin.describeSemanticsConfiguration
```

La ventana anclada de `lib/core/widgets/nano_anchored_popover.dart` declaraba
`scopesRoute: true` sin `explicitChildNodes: true`. Flutter rechazaba el árbol
semántico al montarlo. El botón recibía el toque y creaba la ruta, pero sus
acciones quedaban reemplazadas por el componente de error.

## Corrección

- Declarar explícitamente los hijos de la ruta semántica. Se conservan el
  nombre accesible, GlassSurface, posición, cancelación y animaciones finitas.
- Registrar causa y pila en compilaciones de desarrollo cuando se sustituye un
  componente por el aviso. Los errores consecutivos iguales no repiten el log.
- Revisar las demás declaraciones `scopesRoute: true` del código de la app:
  solo se encontró esta declaración.

## Flujo conservado

El + y el logo abren la misma función `_openWhatsAppMenu`. Una sola tarea
`_inputMenu` evita apilar rutas y se libera mediante `finally`. El menú contiene
WhatsApp y sus acciones de abrir chat, redactar, adjuntar y abrir la aplicación.
Preparar devuelve el borrador al controlador existente; ejecutar sigue pasando
por `_runTask`, con sus permisos y verificaciones. Elegir una opción no envía
información automáticamente.

## Evidencia y límites

`plus-build-error.log` contiene el error capturado después de la pulsación del
usuario. Las capturas previas muestran el componente de error en lugar del menú.
La corrección se comprueba mediante revisión y análisis estático; la compilación
e instalación se registrarán por separado. No se ejecutaron pruebas, recorridos
automáticos, envíos ni acciones de WhatsApp. El almacenamiento seguro también
emitió un aviso de migración al inicio; no se modifica ni borra para corregir el +.

## Actualización instalada

Gradle completó `fullSideloadDebug` en 50,6 segundos. Android respondió `Success`
a la actualización con `adb install -r`. El análisis estático de los seis
archivos del flujo terminó sin incidencias. Los dos archivos fuente editados
tienen 157 y 85 líneas. Huella y estado del paquete en
`PLUS_FIX_INSTALLATION.json`. La apertura posterior a la corrección no se ha
comprobado en pantalla: no se automatizó la interfaz.
