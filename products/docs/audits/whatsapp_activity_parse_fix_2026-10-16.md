# «Qué haces» sin respuesta — 2026-10-16

## Fallo observado

16:14:40: MNN terminó 15 tokens, TTFT 35471 ms y prefill 34703 ms. El parser registró «sin reply parseable; rawChars=42». El compositor terminó sin candidato y la regla quedó failed a las 16:14:47. No hubo despacho en este intento.

El cuerpo descartado no está en el log revisado; no se atribuye una frase concreta al modelo.

## Corrección

La pregunta de actividad forzaba salida estructurada en la ruta local personal. Esa ruta ahora usa el contrato natural, igual que el resto de la conversación personal. El sistema exige reconocer el desconocimiento si no existe actividad actual verificada del dueño.

El parser admite expresiones naturales adicionales de incertidumbre (incluida «no estoy seguro») que las guardas de decisión ya reconocían, sin convertir cualquier texto plano en permiso para afirmar actividad. Las guardas posteriores permanecen activas.

## Verificación

- Cinco pruebas nuevas pasan del parser a la decisión: tres incertidumbres naturales permitidas, actividad inventada rechazada y desconocimiento mezclado con actividad retenido.
- Total de pruebas focalizadas: 80, todas pasan.
- Análisis estático: sin incidencias.
- fullSideload debug arm64: compilación correcta.
- Primera prueba real: la salida natural volvió a ser rechazada (42 caracteres). El contrato natural por sí solo no resolvió el fallo. El cuerpo descartado no se conserva y no se inventa su contenido.
- Se añadió una única reformulación de actividad tras salida inutilizable, dentro del presupuesto original y antes de liberar MNN. La reformulación pide incertidumbre natural y pasa de nuevo parser y decisión. No dispara otro retry de estilo.
- Se añadieron flags diagnósticos del rechazo (permiso de texto plano, incertidumbre, reciprocidad, actividad y tono de operador), sin cuerpos privados.
- Segundo intento de aquella prueba: cancelación nativa y PlatformException; también se observó un turno posterior sin motor listo. No se declara resuelta esa secuencia por el cambio de parser.
- Tras los cambios adicionales: 80 pruebas focalizadas pasan; compilación fullSideload debug correcta. Validación real de la reformulación pendiente.

No se cambia memoria, modelo ni tiempo de espera. Esta corrección elimina una discrepancia de contrato; no garantiza calidad universal ni respuesta correcta de cualquier generación.
