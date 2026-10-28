# Pruebas manuales — Búho con WhatsApp instalado

Fecha: 27/10/2026. Todas las filas están **pendientes** en el acabado final. Esta lista no ejecuta nada.

## Preparación

Usa tu propio contacto de prueba. Abre Nano una vez para conectar el motor. Comprueba permisos de superposición y Accesibilidad; no desactives el servicio para ocultar su atajo. En el búho selecciona **WhatsApp** para dar órdenes de esa app. **Conversar** es para consultas/análisis y **Leer pantalla** obtiene texto.

Para un solo acceso visual, desactiva únicamente el acceso directo/botón de Accesibilidad de Nano en los ajustes Android (el nombre exacto cambia según ColorOS). Conserva el servicio activo. La esfera se activa explícitamente desde Nano; no tiene que abrirse sola al iniciar.

Anota para cada caso: APK, tema, orientación, hora, esperado, observado y captura. Marca Aprobado/Fallido/No verificable. No marques aprobado solo porque el asistente lo diga.

## Matriz

| ID | Acción manual | Resultado que debe comprobarse |
| --- | --- | --- |
| V01 | Abrir Nano normalmente | No aparece automáticamente el panel del búho. Una sola presentación de Nano, sin doble marco ni doble X. |
| V02 | Activar esfera y salir a WhatsApp | Búho visible en lente circular, con movimiento original; no una pestaña vacía ni una segunda burbuja creada por Nano. |
| V03 | Arrastrar la esfera cerca de los bordes | Permanece alcanzable, no sale de pantalla ni tapa permanentemente el editor. |
| V04 | Abrir panel, pulsar − y reabrir | Panel compacto y esfera conservada. No se pierde el borrador. |
| V05 | Abrir teclado; pulsar Atrás dos veces | Primer Atrás cierra teclado; segundo contrae panel. WhatsApp sigue utilizable. |
| V06 | Pulsar X | Se cierran panel y esfera. No aparece otra ventana. El atajo Android, si aún está habilitado, es distinto y debe retirarse manualmente para tener uno. |
| V07 | Repetir en Claro, Oscuro y Gris espacial | Tema coherente, texto legible y sin mezcla con los mensajes de fondo. No cambiar los ajustes de accesibilidad solo para ocultar un fallo visual. |
| V08 | Girar a horizontal y abrir teclado; aumentar texto | Controles alcanzables, desplazamiento útil y ningún recorte de enviar/cerrar. |
| O01 | Seleccionar WhatsApp y escribir «Abre WhatsApp» | Se abre la aplicación instalada, no web. No se escribe ni envía un mensaje. |
| O02 | «Abre el chat de +número», usando tu número | Verificar manualmente cabecera y teléfono del perfil; apertura aceptada no acredita identidad final. |
| O03 | «Abre el chat de Nombre exacto»; repetir con nombre ambiguo | Exacto abre el correcto; ambiguo pide aclaración y no elige el primero. |
| O04 | Probar un @usuario real de prueba | Verificar perfil/usuario final. Si la versión no lo admite, debe informar el límite, no cambiarlo por un teléfono. |
| O05 | Pulsar Leer pantalla sobre el chat | Texto corresponde a la pantalla actual. Debe avisar que es lectura textual parcial, no el historial completo. |
| O06 | En Conversar: «Analiza esta conversación que está en pantalla» | Analiza solo lo observado, declara límites y no inventa mensajes fuera de pantalla. Requiere modelo/proveedor disponible. |
| O07 | Preguntar qué hay en una foto/vídeo sin adjuntarlo al modelo | No debe afirmar que vio su contenido. El texto accesible no acredita visión. |
| O08 | En WhatsApp: «Exporta esta conversación» | Abre el menú oficial de ese chat y llega a elegir multimedia. No debe decir que ya guardó el historial. |
| O09 | En el diálogo oficial, elegir Sin archivos y Guardar en Archivos | Se genera y guarda el archivo que WhatsApp exporta. Comprueba nombre, contenido y rango. No seleccionar ningún contacto de compartir por accidente. |
| O10 | Cambiar de chat durante preparación/confirmación de exportación | El siguiente paso debe detenerse si la identidad cambió, sin exportar otro chat ni pulsar por coordenadas. |
| O11 | Volver desde el avatar Abrir Nano | Nano vuelve al frente; no quedan paneles duplicados sobre la app. |
| P01 | Escribir borrador, minimizar, reabrir | Mismo texto y herramienta; no se ejecuta por haber reabierto. |
| P02 | Durante una consulta, minimizar y reabrir | Sigue ocupado en ese turno, no muestra una respuesta anterior como nueva. |
| P03 | Solicitar detener y luego minimizar/reabrir | No queda ocupado ficticiamente si falla la conexión. Un resultado incierto exige revisar la app antes de repetir. |
| P04 | Cerrar forzadamente Nano desde Android y abrir otra vez | Registrar qué se conserva y qué no. La versión actual no promete recuperar el borrador de servicio tras matar el proceso. |
| P05 | Consultar historial de acciones | Debe corresponder a las rutas/estados ejecutados; no filas inventadas ni una segunda conversación de WhatsApp. |

## Envíos: solo cuando tú decidas probarlos

Haz estas comprobaciones tú mismo con tu propia cuenta/destinatario de prueba. No autorizan al asistente de desarrollo a enviar nada.

| ID | Acción manual | Resultado que debe comprobarse |
| --- | --- | --- |
| E01 | Preparar un mensaje exacto y cancelar antes de ejecutar | No aparece ningún mensaje nuevo en WhatsApp. |
| E02 | En WhatsApp, enviar una única frase identificable a tu contacto | Destinatario correcto, una sola copia y texto exacto. Distinguir clic de envío, entrega y lectura. |
| E03 | Preparar un PDF real desde + → Archivos | Archivo correcto y destinatario explícito. Elegir archivo no lo envía automáticamente. |
| E04 | Repetir con una foto y vídeo pequeños | Previsualización, destinatario, caption y estado reales; no un enlace presentado como archivo local. |
| E05 | «Responde en este chat: frase de prueba» sobre un chat vacío de borrador | Misma conversación, sin resolver un homónimo. Si ya existe borrador, no sustituirlo silenciosamente. |
| E06 | Interrumpir una acción y revisar WhatsApp antes de repetir | No duplicar el envío si su resultado quedó incierto. |

## Criterio de cierre

No declarar esta parte completa hasta aprobar V/O/P/E relevantes con evidencia final. El envío manual no prueba comprensión de imágenes ni QA universal.

La exportación oficial y el análisis de TODO su archivo son dos capacidades diferentes. Hoy falta la importación estructurada de TXT/ZIP al contexto del búho.

Para QA automática posterior faltan escenarios y aserciones demostradas desde este punto de entrada. **@benchmark no sustituye estas pruebas**: el diagnóstico existente incluye entradas sintéticas.
