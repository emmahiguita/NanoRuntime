# Calidad de respuesta de Nano Personal

## Evidencia y alcance

En el teléfono se observaron ecos adornados con emojis, una salida con caracteres
repetidos, rechazo de formato y errores de persistencia `burst-shadow`.
Se mantiene el modelo elegido por el usuario. No se modifica su muestreo ni se
atribuyen estos defectos exclusivamente a la familia Qwen.

## Cambios

- Política textual común: eco léxico ignorando emojis/puntuación y bucles largos
  de letras o palabras. Conserva negaciones y números al comparar.
- Un saludo breve generado puede coincidir con el saludo recibido: no se trata
  como eco defectuoso ni se sustituye por una frase estática.
- Validación tanto en el parser como en la decisión final, incluidos fallbacks.
- Un único reintento generativo para charla local con calidad rechazada, dentro
  del presupuesto existente. No usa respuestas prefabricadas ni elimina permisos.
- Ventanas canónica y de respaldo omiten salidas textuales defectuosas antes de
  formar el contexto. SQLite y el panel conservan los mensajes observados.
- La presencia aislada «¿estás ahí?» deja de clasificarse como ubicación física;
  las preguntas con lugar o estado físico mantienen sus barreras.
- El prompt breve incorpora relación, estilo del rol y nombre del dueño cuando
  existen, sin fabricar perfil ni ejemplos.
- El sistema nativo recuerda distinguir el autor de una corrección y no copiar
  el mensaje añadiendo emojis.
- Se admite `burst_shadow_v1` en Android: antes cada escritura era rechazada por
  la lista de secciones permitidas y provocaba los StateError observados.
- No se relajan los controles de estado vivo, pausa ni autoridad humana.

## Límites

Estos filtros detectan defectos textuales, no certifican corrección semántica,
naturalidad ni comprensión de todos los modelos. Una respuesta incoherente que
no sea un eco/bucle puede requerir revisión adicional. No se borra memoria ni se
reinicia la identidad. Los modelos y cuentas requieren comprobación manual.

## Validación

- Análisis estático focalizado sin incidencias.
- No se ejecutaron tests automáticos.
- APK `fullSideloadProfile`: compilado correctamente (129 MB).
- Instalación mediante actualización conservando datos: `Success`.
- Fecha del paquete instalado: 2026-10-16 11:19:35, teléfono VGL7MVFMDYQG8T55.
- Arranque: `Status: ok`, PID 5013. Modelo seleccionado conservado:
  `Qwen3-0.6B-Instruct (LiteRT)`.
- Consulta inicial del PID nuevo: sin FATAL EXCEPTION, E/flutter,
  SQLiteException ni MissingPluginException en las líneas consultadas.
- Guía de validación actualizada con las regresiones comprobadas; metadatos válidos.
- Evento real posterior a la instalación: 11:20:07 `burst-shadow persistidos=1`;
  11:20:08 `source=canonical entries=50`. A las 11:20:18 la preparación local
  utilizó 12 turnos desde la ventana canónica con el modelo listo.
- Estos registros prueban lectura/persistencia, no naturalidad del texto generado.
- En esa revisión se detectó un saludo coincidente retenido como eco; se añadió
  una excepción de validación para saludos breves, sin generar respuestas fijas.
- APK final con esa excepción: recompilado e instalado a las 11:23:16,
  `Status: ok`, PID 6967; Qwen3 seleccionado conservado. Lectura inicial del
  nuevo proceso sin las excepciones de arranque consultadas. No se envió un
  mensaje de prueba desde las herramientas ni se verificaron todos los modelos.
- Pendiente prueba manual de saludo, corrección, párrafo con varias preguntas,
  emoji, repetición legítima y cambio entre modelos instalados.
