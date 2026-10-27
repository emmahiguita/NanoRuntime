# Barra contextual de Automatización

## Aplicado

- Un único editor reutiliza `NanoInputScope`, `NanoUniversalInputConfig` y el dock existente.
- Cabecera WhatsApp con recurso Nano existente, acción y destinatario identificado como contacto, número o usuario.
- Seleccionar una intención no certifica que la app esté instalada ni conectada. La vista previa lo indica como pendiente.
- El monitor nativo existente publica únicamente cambios observados, vinculados al executionId del coordinator y al operationId del intento.
- Clic observado, comprobación del regreso y resultado incierto tienen estados separados. Nunca se muestran como entrega o lectura confirmada.
- La barra reducida conserva marca y resultado y permite volver al editor. El botón de ejecución se denomina «Ejecutar»; durante el trabajo conserva «Detener ejecución» y su cancelación propietaria.
- Los temas y el cristal proceden de los componentes existentes. Se adapta la información en horizontal con teclado y respeta movimiento reducido.
- La suscripción de presentación se libera al desmontar el dashboard; no agrega consultas periódicas ni ejecutores.

## Comprobación realizada

- Análisis de los componentes modificados: sin problemas (`analysis.log`).
- Compilación fullSideloadDebug: correcta (`build.log`).
- Instalación con conservación de datos: confirmada por `Success` (`install.log`, huella en `installation.json`).
- Inspección manual del editor en teléfono físico: borrador `@whatsapp Emm`, cabecera y botón Ejecutar (`whatsapp-draft.png`, `final-draft.png`).
- Se observó un recibo de apertura de Emm conservado en la barra reducida entre capturas. No se atribuye esa apertura a una nueva prueba controlada de envío (`readonly-result.png`, `before-readonly.xml`).
- La secuencia prevista de consulta `--estado` no llegó a ejecutarse: al observar el teléfono el editor ya estaba reducido. Sus archivos con prefijo `readonly` son capturas, no evidencia de esa consulta.
- No se enviaron mensajes ni documentos durante la revisión. No se crearon pruebas nuevas: la revisión automática de permisos rechazó esa ampliación por la restricción previa del usuario.

## Límites

La observación detallada está conectada a los envíos nativos que pasan por WhatsAppSendMonitor con identidad de ejecución (comando instalado y archivos con destinatario verificado). Otras rutas conservan la vista previa y el resultado del motor; no se inventan fases intermedias. Este cambio no acredita una nueva prueba completa de envío, recepción, entrega o de todos los temas y orientaciones.

## Mantenimiento

`files.json` contiene los archivos y huellas de este cambio. El controlador adapta estados a presentación; no cambia las políticas ni vuelve a intentar acciones. `WhatsAppExecutionActivity` es una observación efímera, sin mensaje ni archivo. La persistencia y el ejecutor existentes siguen siendo responsables del trabajo.
