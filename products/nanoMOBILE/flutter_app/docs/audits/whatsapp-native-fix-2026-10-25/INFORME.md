# Nano y WhatsApp instalado: corrección y evidencia

Fecha: 25 de octubre de 2026 (America/Bogota). Dispositivo: OPPO CPH2557, Android 15. Destino autorizado: Emm, confirmado por el usuario. No se usa WhatsApp Web.

## Resultado verificable

| Recorrido | Resultado | Evidencia |
|---|---|---|
| Nombre desde Automatización | Abre Emm en com.whatsapp | `open-final.xml` |
| Número desde Automatización | Orden escrita y ejecutada en la barra; abre Emm | `phone-command.xml`, `phone-open.xml` |
| Mensaje de prueba | Una burbuja con el texto exacto; clic y regreso observados | `text-result.xml`, `message-proof.xml` |
| PDF neutro | Archivo visible en la conversación; clic y regreso observados | `document-live.log`, `phone-open.xml` |
| Usuario exacto | Desde Nano llega al perfil @AIemmaDev | `username-before.xml`, `username-actual-profile.xml` |
| Burbuja → Auto | Abre WhatsApp real sin proveedor web | `float-command.xml`, `float-open-result.xml` |
| Burbuja → Abrir Nano completo | Regresa a la app | `float-return-main.xml` |

El mensaje autorizado se ejecutó una vez. El primer intento del PDF se detuvo sin autorización de clic: su vista previa no tenía cabecera de chat. Después de corregirlo, se observó el clic a las 18:01:49.223 y el retorno a las 18:01:49.874 en el reloj del teléfono. La captura posterior muestra el PDF en la conversación.

Apertura, clic de envío, presencia en el historial, entrega y lectura son señales diferentes. Los mensajes de Nano siguen indicando **entrega no confirmada**. Los registros de accesibilidad no sustituyen un comprobante del servidor de WhatsApp.

## Qué se corrigió y por qué

- El scope de foco del dock impedía escribir. Ahora permite enfocar sus campos y seguir visibles con el teclado.
- El destinatario de envío exige identidad exacta y única. La búsqueda conserva sugerencias; estas no autorizan un envío. Nombres duplicados con números distintos se rechazan.
- Los nombres completos pueden ir entre comillas o paréntesis; se conservan los espacios del mensaje. Un usuario con dígitos no se transforma en teléfono.
- El comando `@whatsapp` exige la app instalada. No selecciona Meta Cloud ni abre un navegador como sustituto.
- UI y alarmas usan el mismo backend nativo de texto. Se selecciona el paquete instalado antes de armar la acción.
- Antes del clic se comprueban cabecera y texto exacto del editor. No se aceptan nombres encontrados en una burbuja.
- Los documentos conservan los metadatos de destinatario. El PDF se valida por nombre real y por el contenedor de un único destinatario de su vista previa.
- Hay un propietario del intento, contador de operación y observación acotada. Se agrupan eventos para no crear una cola creciente en el hilo principal.
- El regreso activa la tarea existente de Nano y exige una ventana de aplicación enfocada; la burbuja no cuenta como MainActivity.
- Una instancia vieja de Accesibilidad no puede desconectar a la nueva durante un cambio de servicio.
- La cancelación del comando conserva el identificador del módulo y solo cancela su propia operación. Un resultado incierto no se reintenta desde este handler.
- `Auto` del panel flotante estaba conectado al modo consulta. Ahora usa el ejecutor local, aparta el panel y conserva el resultado para reabrirlo. Los errores y estados inciertos no devuelven `ok=true`.

## Cómo se hicieron las comprobaciones

Se escribió y pulsó la orden de apertura en la barra real de Automatización para nombre y número. Para el mensaje con acento y el PDF se usó la entrada de producción `nano.entry.prompt` de Nano, que llega al chat y al mismo handler. ADB no pulsó Enviar dentro de WhatsApp. Esta diferencia de entrada queda registrada: no se afirma haber probado cada combinación de interfaz y acción.

El controlador `input text` de Android rechazó el acento de «envío»; esto pertenece al mecanismo de entrada de ADB, no prueba un fallo del teclado de Nano. El texto exacto sí se verificó en la conversación.

Las 25 comprobaciones automatizadas de regresión pasaron: parseo, identidad, handler con dobles explícitos y foco del editor. **Son comprobaciones de software, no sustituyen los recorridos físicos anteriores.** Dos aserciones antiguas permitían enviar por parecido fonético; se actualizaron para exigir rechazo sin efectos.

Build final: `build-handoff.log`. Instalación y SHA-256: `installation-final.json`. Inventario de esta intervención: `files.json`. Matriz estructurada: `results.json`.

## Uso desde Android

1. Habilitar el servicio de Accesibilidad de Nano. Para la burbuja, activar «Asistente flotante» en Ajustes y el permiso de superposición.
2. Desde Automatización, escribir `@whatsapp Emm` o `@whatsapp +<número internacional>` para abrir. Para un nombre completo, `@whatsapp "Nombre completo"`.
3. Para enviar texto: `@whatsapp "Nombre completo" Texto exacto`.
4. Para adjuntar: `@whatsapp "Nombre completo" --archivo <ruta local real>`; puede usarse una ruta del catálogo privado importado en Nano. No confundir un enlace remoto con un archivo local.
5. Para usuario: `@whatsapp @usuario`. Su apertura usa el enlace documentado de WhatsApp fijado al paquete instalado. El autoenvío exige verificar el perfil exacto; si no puede verificarse, se detiene.
6. En la burbuja seleccionar **Auto** y escribir la orden. Durante la acción el panel se aparta. Al reabrirlo se muestra el resultado; «Abrir Nano completo» vuelve a la app.
7. `@whatsapp --estado` consulta conexión, operación, clic y regreso sin iniciar envíos. «Detener» solicita cancelar la ejecución propietaria; no puede deshacer un clic ya realizado.

## Límites y trabajo que no se declara terminado

- No se probó envío por usuario con clave, grupos, contactos desconocidos ni todos los formatos multimedia. La apertura de @AIemmaDev no acredita todas esas combinaciones.
- Los usuarios dependen del despliegue de WhatsApp y pueden exigir una clave. Referencias oficiales: [contactar por usuario](https://faq.whatsapp.com/1561101675623754/) y [usuarios](https://faq.whatsapp.com/658755553162769/).
- El envío de archivos sin metadatos verificables de cuenta conserva un flujo manual; no se fabrica un JID. La búsqueda por nombre no equivale a un directorio de usuarios de WhatsApp.
- Si Android mata el proceso, desconecta Accesibilidad o el usuario cambia de pantalla durante una acción, se necesita revisar el resultado. El registro de operación es efímero; no sustituye una cola durable para todos los comandos.
- La burbuja nativa usa un servicio no persistente; tras actualizar el APK o detener el proceso puede ser necesario activarla de nuevo.
- ColorOS puede mantener WhatsApp como ventana flotante. Nano no cambia globalmente la política de ventanas del sistema.
- Se observaron arranques tibios de Nano de aproximadamente 8,5 s. No se declara resuelto el rendimiento global ni auditadas todas las apps.
- La pantalla de perfil de WhatsApp bloqueó la captura mediante `SECURE`; se respetó la restricción. La identidad se leyó mediante los elementos accesibles autorizados.
- Esta intervención no completa el sistema QA general, sus informes persistentes ni todas las fases A–F. Tampoco acredita que Nano pueda controlar cualquier app instalada.

## Alcance corregido del plan aportado

SmartAttendance y su puente IPC no son requisitos de Nano. Ver `PLAN_NANO_SIN_SMARTATTENDANCE.md` para el contraste entre el documento propuesto y el código real.
