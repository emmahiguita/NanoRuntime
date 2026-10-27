# WhatsApp: edición de presentación

- El botón + y el logo pasan su contexto real a un menú anclado; no se usan claves globales duplicadas durante las transiciones del dock.
- Solo se muestra el componente WhatsApp. Lista y formulario comparten una ruta y una superficie GlassSurface, con aparición breve y adaptación al teclado/área segura.
- Se conservan abrir chat, redactar, elegir archivo y abrir WhatsApp. Las opciones devuelven borradores al mismo editor; no ejecutan un envío por selección.
- El formulario mantiene nombre, número o @usuario literales y delega la resolución al ejecutor existente.
- El estado de WhatsApp ocupa una línea; el detalle y la confirmación ya existente se consultan bajo demanda. El historial continúa fuera de la barra.
- Animaciones finitas, movimiento reducido respetado, filas salientes sin interacción y protección de doble toque al cerrar. No se incorporan cámaras, catálogos de complementos ni nuevas funciones.
- Retirado automation_input_options.dart: ya no tenía consumidores y mantenía el antiguo panel de ajustes mezclados.
- No se editaron el motor de envío, la verificación del destinatario, los controladores nativos de apertura/retorno ni la animación del búho.

Por solicitud del usuario no se ejecutaron pruebas, ARTEMIS, comandos del teléfono ni envíos en esta edición. No se compiló ni instaló. La revisión realizada es estática; no acredita mediciones nuevas de rendimiento ni verificación visual en el dispositivo.
