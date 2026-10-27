# WhatsApp instalado: respuesta, formulario y ventana

## Alcance y comprobación

Implementación para el Búho sobre el mismo AutomationEngine. No se hicieron
pruebas, envíos, capturas ni recorridos del dispositivo. Se leyó únicamente
la lista de capacidades Android: el CPH2557 publica picture_in_picture y no
freeform_window_management. PiP no acredita mini-ventanas de aplicaciones.
Análisis estático de los archivos afectados: sin incidencias.
Compilación/instalación e inventario exacto: WHATSAPP_REAL_VERIFICACION.json.

## Responder dentro del chat visible

Con el chat abierto en WhatsApp instalado y el búho disponible:
`Responde en este chat: Hola, recibí el documento. Gracias.`

Esta forma usa el texto indicado por el usuario. No infiere qué contestar ni
inicia una conversación autónoma permanente. La preparación observa cabecera,
editor y ventana de WhatsApp personal o Business. Exige editor vacío y contexto
completo; nunca convierte el título de un grupo en un contacto de la agenda.

La herramienta whatsapp.send_message conserva las políticas del coordinador.
La variante replyInPlace escribe y envía en la ventana observada; no usa agenda,
notificación RemoteInput, Web ni enlaces para reabrir otro destinatario.

La huella del contenido visible queda en los argumentos firmados del plan.
Tras una pausa, antes de escribir y antes del único tap se revalida el contexto.
El teclado puede cambiar los bounds: la raíz se compara estructuralmente.
CommitGuard comprueba editor, conversación, acción de envío y eco local después.
El token de cancelación atraviesa también el claim irreversible y el handler.
Si se detiene antes del tap, no se envía; puede quedar el borrador visible.
Tras el tap no hay reintento automático. Eco local no prueba entrega ni lectura.
El retorno solicita abrir Nano una vez y exige una ventana APP enfocada de Nano.

Límites: la huella es evidencia visible, no JID. Chats visualmente indistinguibles
no pueden distinguirse con accesibilidad sola. Cambios legítimos del historial o
del estado de pantalla pueden detener la petición. Requieren una nueva orden,
no un reintento automático. IDs ausentes o snapshots parciales piden aclaración.

## Compartir un formulario

- PDF de la biblioteca configurada:
  `Comparte el formulario PDF "Solicitud.pdf" con "Emm"`
- Enlace exacto como mensaje:
  `Comparte el formulario "https://ejemplo.com/formulario" con "Emm"`
- PDF elegido mediante + → Archivos:
  `Envía el formulario adjunto a Emm`

El PDF por nombre exige un documento real, exacto y único. Si no existe, se
pide aclaración. El enlace debe ser HTTP/HTTPS, tener host y no incluir credenciales.
No se descarga ni rellena el formulario. Un adjunto preparado no se ignora para
mandar solo texto; responder texto exige retirarlo primero.

## Ventana flotante real

Orden: `Abre WhatsApp en ventana flotante` (o WhatsApp Business).
La orden llega como launch_app con windowMode=floating, bajo el motor común.
El adaptador nativo comprueba la capacidad pública freeform antes de lanzar.
Pasa ActivityOptions a startActivity(intent, options); no como extras del Intent.
Se retiraron los flags privados OEM que no demostraban soporte real.

Solo se declara una ventana reducida observada si hay una ventana APP activa o
enfocada del paquete exacto, con bounds reducidos en ambos ejes. La observación
está acotada y la apertura ocurre una sola vez. Sin evidencia se informa solicitud
no verificada. Al destruir el canal se retiran callbacks y se completa la espera.

Este OPPO no anuncia la capacidad pública requerida. Nano devuelve soporte no
disponible, sin abrir silenciosamente otra modalidad ni prometer forzar ColorOS.
Puede usarse WhatsApp normalmente con el búho; una mini-ventana OEM requiere el
control que ofrezca el fabricante y no se certificó en esta revisión.

Referencias oficiales:
- https://developer.android.com/reference/android/app/ActivityOptions#setLaunchBounds(android.graphics.Rect)
- https://developer.android.com/reference/android/content/Context#startActivity(android.content.Intent,%20android.os.Bundle)

## Correcciones del flujo existente

- El envío tipado Business conserva com.whatsapp.w4b; antes se hardcodeaba
  com.whatsapp o se podía consultar Cloud. Un paquete explícito excluye Cloud.
- El backend de texto ya no cambia silenciosamente de cuenta como fallback.
  Si el paquete solicitado falta, se pide elegir la app instalada.
- La apertura simple publica solicitud de lanzamiento, sin inventar chat verificado.
- El callback OwnedToolReport conserva el token original; los callbacks anteriores
  mantienen compatibilidad. Cancelar durante claim no despacha el efecto.
- Se extrajeron transporte de texto y lanzamiento de medios por responsabilidad.
  Las fuentes nuevas/modificadas quedan bajo 200 líneas, sin comprimir código.

## Pendiente manual

Comprobar respuesta con chat vacío/borrador/cambio de chat/pausa/cancelación,
PDF y enlace con destinatario real, cuenta personal/Business y retorno a Nano.
En dispositivo que anuncie freeform, verificar mini-ventana real y fallo de soporte.
No hay evidencia nueva de entrega o de ausencia universal de bugs.

## Entrega

fullSideloadDebug compiló e instaló mediante actualización `install -r`: ADB
confirmó `Success`. Se conservaron datos. Las 30 fuentes afectadas tienen menos
de 200 líneas (máximo 196). No se abrió WhatsApp ni se ejecutaron envíos o tests.
