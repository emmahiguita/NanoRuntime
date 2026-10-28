# Búho: cierre, minimización y WhatsApp — 27/10/2026

## Corrección

La X antes contraía la superficie y dejaba vivo el acceso flotante. Ahora tiene
una responsabilidad distinta de «−»: cerrar oculta panel/orbe Flutter o detiene
el servicio nativo; minimizar conserva la burbuja y el borrador. No se cambiaron
sprites ni tiempos de la animación aprobada. Cerrar la interfaz no equivale a
cancelar una acción externa ya comprometida; esa acción conserva su cancelación
explícita y sus resultados.

En Android 15, `KEYCODE_BACK` por sí solo no contrajo la ventana durante la
primera comprobación. Se conectó `OnBackInvokedDispatcher` desde API 33 con
prioridad normal, liberado al desmontar. En Android anterior se conserva la
ruta KeyEvent. La conexión moderna no se instancia antes de API 33.

Se conservan los dos accesos por decisión del usuario: burbuja de Nano y atajo
de Accesibilidad de Android. La X no elimina ese atajo del sistema.

## Evidencia real

Dispositivo físico: OPPO CPH2557, Android 15, VGL7MVFMDYQG8T55. Observación con
ARTEMIS y acciones ADB. No se usó UiAutomation para suprimir el servicio de Nano.

| Comprobación | Resultado observado |
| --- | --- |
| Minimizar sobre WhatsApp | Panel retirado, burbuja visible, WhatsApp Conversation conserva foco. |
| X sobre WhatsApp | Sin panel, sin burbuja y sin NanoFloatingService; atajo Android conservado. |
| Atrás, sin teclado | Contrae a burbuja con la corrección instalada. |
| Primer Atrás con teclado | IME deja de mostrarse; el panel sigue abierto. |
| Leer pantalla | Devuelve texto accesible de com.whatsapp y el nombre Emm; no analiza imágenes. |
| Abrir chat desde Búho | Desde HomeActivity, orden por número; después Conversation con cabecera Emm. |
| Abrir Nano desde avatar | MainActivity al frente, sin panel expandido ni burbuja externa sobre Nano. |

La orden ejecutada desde el editor nativo fue «Abre el chat de +573203527283».
El operador preparó primero la lista de chats; no abrió el destino en lugar del
motor durante esta comprobación. El recibo fue honesto:

> [completedUnverified] Android aceptó abrir el chat de "Emm" (573203527283); destino final sin verificar.

La observación independiente acredita el cambio de pantalla y la cabecera Emm.
No convierte el recibo del motor en una verificación automática del número de
perfil. Esa comprobación interna queda pendiente y no se modificó su contrato
para aparentar éxito. No se enviaron mensajes ni archivos nuevos en este ciclo.

## Validación y archivos

- Análisis estático del módulo Flutter: sin incidencias (`analisis.log`).
- Regresión de visibilidad, entrada y WhatsApp: 34 pruebas aprobadas
  (`regresion.log`). Usan dobles identificados; no acreditan acciones externas.
- Compilación final fullSideloadDebug arm64: correcta (`compilacion.log`).
- Instalación final `adb install -r`: Success; sin borrado de datos.
- Revisión independiente del cambio de Atrás: sin defecto adicional demostrado.
- Los diez archivos de código afectados tienen entre 52 y 179 líneas.
  Inventario y hashes: [INVENTARIO.json](INVENTARIO.json).
- APK SHA-256: `10136F3FD5D101FC82E75D00044E2CC27C8C070EC899E20ADBE3913AEF1D5821`.

Detalle estructurado: [VERIFICACION.json](VERIFICACION.json). Capturas:
[panel externo](01-panel-externo.jpg),
[cerrado con atajo conservado](02-cerrado-con-atajo-conservado.jpg),
[chat abierto por el búho](03-chat-abierto-desde-buho.jpg),
[recibo del motor](04-recibo-real.jpg).

## Límites

No se comprobaron nuevas entregas de mensajes/documentos, voz, orientación
horizontal, todos los proveedores ni versiones antiguas de Android. No se midió
temperatura, consumo o FPS. No se declara automatización universal al 100 % ni
se confunde el overlay de Nano con una ventana flotante de WhatsApp.
