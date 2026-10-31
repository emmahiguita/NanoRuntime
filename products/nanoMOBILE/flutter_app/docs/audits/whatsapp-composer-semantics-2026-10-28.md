# Revision del informe: compositor WhatsApp y superposicion

## Evidencia en el codigo

- NanoAccessibilityText inferia vacio mediante Mensaje/Message y una etiqueta localizada del microfono.
- WhatsAppUiGoalPreparer y WhatsAppCurrentChatSender usaban texto no vacio como prueba de borrador.
- El panel externo ya se retiraba antes de submit, pero collapse volvia a mostrar la esfera.
- El envio actual ya usa setText, relee la ventana y protege el clic con CommitGuard; no se reemplazo ese flujo.

## Implementado

- Snapshot nativo conserva rawText, showingHint y supportsSetText junto con hint, identidad y estado existentes.
- Clasificador compartido: vacio literal, showingHint explicito o evidencia nativa de compositor vacio. Esa evidencia estructural exige entry, cursor 0/0, ancestro edit_layout, un voice_note_btn visible/habilitado en la fila y ningun send visible. El texto literal se conserva en rawText. El resto sigue protegido como contenido o ambiguo.
- Texto igual a hint sin showingHint sigue siendo ambiguo para proteger contenido legitimo.
- Sin etiquetas de microfono ni diccionario de placeholders.
- La esfera queda oculta durante la tarea del buho y se restaura en finally, con estado independiente de las capturas temporales.
- Guard nativo final exige un unico editor habilitado, visible, no password y no hint en la ventana actual.
- Modelos Dart y serializacion Kotlin extraidos por responsabilidad, manteniendo los imports publicos anteriores.

## Limites

La ayuda publicada como contenido sin showingHint se resuelve mediante los controles estructurales observados. Si faltan esos controles o las senales se contradicen, la escritura sigue bloqueada. La deteccion estructural es una inferencia corroborada, no una garantia sobre toda version futura de WhatsApp.
No se implementaron Nano Access, TYPE_ACCESSIBILITY_OVERLAY, vision, Cloud API ni una nueva modalidad de producto.
No se atribuye el dialogo de ColorOS a InputDispatcher sin registros del telefono.
No se crearon ni ejecutaron pruebas, benchmarks, compilaciones, instalaciones o acciones en dispositivo.

## Verificacion realizada

- dart analyze en los diez archivos Dart afectados: No issues found. La CLI termino con codigo 1 al intentar escribir telemetria fuera del espacio autorizado, despues de completar el analisis.
- Revision estatica de serializer Kotlin, guard de envio y estados de visibilidad.
- git diff --check sin errores en los archivos versionados revisados.
- Kotlin no compilado; comportamiento OPPO/ColorOS no observado.

## Correccion adicional: lectura y escritura

- Evidencia existente consultada (sin ejecutar recorridos): automation-module-composer/open-observed.xml y automation-compact-history/open-result.xml. Ambos muestran entry con Mensaje y voice_note_btn; el ancestro comun observado es edit_layout. No se usa la descripcion localizada del microfono ni una lista de palabras placeholder.
- NanoAccessibilityText normaliza el texto semantico solo con las senales anteriores; NanoAccessibilityNodeSnapshot conserva rawText, emptyEditor y seleccion por separado. Dart consume emptyEditor tanto al preparar como antes de enviar.
- NanoAccessibilityInput extrae la escritura del servicio. Adquiere la ventana del destino, exige un editor unico, refresh, foco, capacidad SET_TEXT y bounds coherentes. Inmediatamente antes de escribir en entry de WhatsApp vuelve a exigir vacio. Un borrador creado despues de preparar la tarea bloquea la escritura.
- No hay fallback de borrado, pegado ni pulsaciones del microfono. No se reintenta SET_TEXT.
- dart --suppress-analytics analyze sobre los cinco archivos Dart afectados y consumidores: No issues found; salida 0. Kotlin revisado estaticamente, no compilado. Sin pruebas ni acciones nuevas en dispositivo.

- Tras SET_TEXT se observan hasta cinco lecturas separadas por 150 ms para comprobar texto literal y control Enviar en el mismo chat antes de CommitGuard. Solo se repiten lecturas, nunca la escritura ni el envio.

- Actualizacion del grafo: graphify update . --no-cluster completo la extraccion AST de 201 archivos pendientes, pero se interrumpio antes de confirmar el guardado final. El grafo no se considera actualizado.
