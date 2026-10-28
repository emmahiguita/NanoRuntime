# Nano Personal: fuente canónica para inferencia

## Fallo observado en código

El writer consultaba el bloque canónico, pero la ruta local generaba sus roles
desde `historyEntries`/`socialEntries` procedentes del respaldo SQL/RAM.
Además, `ConversationDurableContext` prefería SQL legacy y podía incorporar
filas Web que el constructor canónico había puesto en cuarentena.

## Corrección

- `ConversationDurableContext` consulta primero `CanonicalPromptMemory`.
- El adaptador usa el constructor canónico y su verificación Web.
- Proyecta únicamente mensajes de la conversación técnica exacta, con fecha y
  dirección utilizables; no atribuye entrega a un despacho o efecto desconocido.
- Excluye el mensaje actual por instante y contenido exactos, más autor en grupos.
  No borra repeticiones legítimas próximas por compartir texto.
- Si hay filas rechazadas, devuelve una ventana canónica vacía y autoritativa;
  no la rellena desde la memoria antigua.
- Ante fallo, timeout o ausencia de filas, conserva el respaldo local y declara
  expresamente que es parcial. El fallo del respaldo SQL conserva la RAM.
- El writer utiliza las mismas entradas seleccionadas en prompts locales y
  estructurados. Incluye aviso de cobertura en las rutas local y cloud.
- La ruta local canónica conserva hasta 12 mensajes y 6.000 caracteres,
  cronológicos y priorizando los recientes. El mensaje actual entra aparte.
- Los adjuntos son metadatos observados, no contenido interpretado por el modelo.
- Las banderas de origen de la lectura no se persisten como hechos durables.
- No cambia la pausa, autorización de envío, proveedor ni parámetros del modelo.

## Límites que se conservan

No completa historial nunca observado, no une Android y Web por nombre, no añade
resúmenes históricos ni embeddings y no demuestra comprensión del modelo.
La lectura conserva un máximo de 60 filas canónicas antes de formar la ventana.
Los registros recientes rechazados pueden reducir la ventana útil disponible.
La persistencia de nuevos mensajes de cada proveedor sigue siendo responsabilidad
de su ingesta: este cambio corrige el consumidor, no inventa filas ausentes.

## Validación

- Análisis estático focalizado, incluido el filtro final de IDs Web: sin incidencias.
- Análisis ampliado: dos avisos informativos en archivos no modificados.
- No se ejecutaron tests automáticos, conforme a la petición del usuario.
- APK `fullSideloadProfile`: compilado (129 MB); grafo actualizado.
- No se instaló este cambio ni se enviaron mensajes a contactos en esta sesión.
- Actualización posterior: incluido en el APK instalado a las 11:19:35 con las
  correcciones de calidad; véase `personal_reply_quality_2026-10-16.md`.
- Pendiente comprobación manual: conversación con mensajes canónicos que no estén
  en RAM, corrección de un mensaje anterior, pausa, replay del turno actual,
  dos textos idénticos con fechas distintas y fallo de almacenamiento.

Compilar no prueba que un modelo haya utilizado correctamente el contexto ni
que todos los mensajes del proveedor hayan sido ingeridos.
