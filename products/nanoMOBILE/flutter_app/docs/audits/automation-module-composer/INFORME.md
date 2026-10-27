# Automatización: editor, menú y asistente flotante

## Cambio de diseño solicitado

El historial queda fuera del editor, como acceso pequeño en el contenido del módulo. La barra conserva una entrada adaptable. El menú de funciones abre WhatsApp instalado, destinatario y opciones de abrir chat, redactar o seleccionar un archivo real. Elegir una opción prepara el borrador; Ejecutar despacha la orden. No se añadió una segunda tarjeta de escritura.

El asistente Android reemplaza al búho de Flutter cuando está activo. Se conserva respiración, parpadeo y poses de actividad: el reposo usa una cadencia acotada y los relojes se detienen por visibilidad, suspensión o movimiento reducido. Una animación no acredita que una acción se haya realizado.

## Correcciones lógicas

- Comprobación de accesibilidad antes del envío y causa nativa visible. Se conserva el borrador ante fallo.
- Se retiró la reasignación redundante de serviceInfo desde onServiceConnected: el flag del botón de accesibilidad ya está en XML. Esta reasignación contradecía la protección del propio servicio contra rebinds.
- Cancelación cooperativa del propietario del flotante y del módulo; la interfaz no afirma que pueda deshacer un clic externo ya realizado.
- Copia al catálogo en un trabajador con cola limitada. El hilo UI no copia vídeos grandes. El temporal queda fuera del catálogo; no se publica como documento terminado.
- El adaptador LocalLlamaProvider heredado devolvía el prompt como respuesta. Ahora requiere el cliente local real inyectado, comprueba modelo cargado y transmite sus tokens. Cancelar el flujo solicita cancelar el cálculo y cierra su conexión. No se encontró uso activo de ese adaptador en el recorrido de WhatsApp.

## Evidencias actuales

- `analysis-final.log`: análisis de los componentes afectados.
- `build.log`: compilación FullSideloadDebug.
- `install.log` y `receipt.json`: instalación conservando datos y SHA-256.
- `open-draft.xml` → `open-observed.xml`: se ejecutó «Abre el chat de Emm» desde el editor de Automatización y se observó el encabezado Emm en com.whatsapp. No fue un envío.
- `returned.xml`: al regresar manualmente, Nano conservó selección y resultado.
- `send-draft.xml` y `send-attempt.json`: texto exacto de la prueba autorizada. `send-observed.xml`: el intento anterior a la corrección del servicio falló antes de abrir WhatsApp, sin iniciar envío. No se considera éxito.
- ARTEMIS Flash `0254cd73-df71-4ea2-8c74-b86ced2c632a`: inspección interrumpida por 503/504 y timeout del proveedor. No es prueba aprobada.
- ARTEMIS Pro `ff738f95-1143-46fb-9aed-bb2d8fd5967a`: verificación final en curso; sus resultados se añadirán cuando terminen.

## Cobertura real y límites

| Función | Implementación y cobertura |
|---|---|
| Nombre de contacto | Resolución exacta y única en la agenda. Apertura real de Emm observada. |
| Teléfono | Ruta internacional y apertura de WhatsApp existente. No confundir número con identidad verificada por WhatsApp. |
| @usuario | Se conserva como usuario; el deep link depende de WhatsApp y la verificación del perfil. No convertir sus dígitos a teléfono. |
| Mensaje | Texto exacto + comprobaciones del ejecutor. Pendiente del resultado final de ARTEMIS. |
| Archivos, fotos y vídeos | Selector real, copia estable, ruta de adjuntos existente. No se han enviado todos los tipos en esta revisión. |
| Otras aplicaciones y formularios | Hay herramientas de lectura, abrir, tocar y escribir sobre accesibilidad. No se ha demostrado navegación universal ni todos los formularios. |
| Regreso a Nano | Ruta y comprobación nativa existentes; regreso manual observado, retorno tras envío pendiente. |
| WhatsApp dentro de Nano | No se implementó una ventana que embeba la app instalada. El asistente de Nano se superpone a WhatsApp; son dos aplicaciones. |

WhatsApp documenta enlaces por [usuario](https://faq.whatsapp.com/1561101675623754/) y [teléfono](https://faq.whatsapp.com/5913398998672934). La integración de actividades de otras apps requiere cooperación de la app embebida según [Android](https://developer.android.com/develop/ui/views/layout/activity-embedding). Estas capacidades de plataforma no sustituyen una prueba del dispositivo.

## C++ / llama.cpp y rendimiento

La orden determinista de WhatsApp no necesita inferencia: no debe cargar un GGUF para abrir un chat. Se revisó el cliente SSE existente: dispone de cancelación correlacionada por request_id. La cabecera del llama.cpp incluido en vendor expone abort_callback y llama_set_abort_callback; esto por sí solo no demuestra que todos los backends lo utilicen correctamente. No se modificó código de terceros ni se ejecutó un benchmark de inferencia. Esta revisión no es una certificación integral de C++.

Las mediciones anteriores están en `../automation-compact-history/`: el consumo de la interfaz era alto. No permiten prometer ausencia de calentamiento ni una mejora porcentual controlada. La copia fuera del hilo UI y la eliminación del orbe duplicado tienen alcance concreto; falta medición final bajo carga sostenida.

## Mantenimiento y tamaño

`files.json` inventaría archivos, líneas y huellas. Los nuevos componentes de esta entrega son pequeños y comentan responsabilidades, parámetros relevantes y límites. Persisten archivos heredados extensos, entre ellos AgentAccessibilityService y ShareChannelHandler: se realizaron cambios puntuales; no se afirma que todo el repositorio cumpla menos de 200 líneas. Dividir servicios completos sin revisar sus dependencias introduciría un alcance y riesgo distintos.

## Uso

1. En Automatización, pulsa + y elige WhatsApp instalado.
2. Escribe nombre exacto, teléfono o @usuario. Elige abrir, redactar o seleccionar archivo.
3. Revisa el borrador y pulsa Ejecutar. No repitas si el resultado es incierto.
4. Revisa el Historial desde su botón fuera de la barra.
5. Para continuar sobre otra app, activa Asistente superpuesto en las opciones. Requiere permiso Android y que el motor de Nano siga disponible.

No se añadieron pruebas automatizadas al repositorio. Las comprobaciones del teléfono se documentan por observación real.
