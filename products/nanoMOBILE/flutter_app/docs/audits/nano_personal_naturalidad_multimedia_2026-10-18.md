# Auditoría de Nano Personal: naturalidad y comprensión multimedia

Fecha: 18 de octubre de 2026, America/Bogota.

Alcance: inspección del código actual y ejecución de pruebas existentes. No se modificó código de aplicación, no se instaló APK ni se enviaron mensajes a contactos. Este informe no demuestra recepción multimedia en dispositivo ni permite asignar un porcentaje de naturalidad.

## Conclusión

La ruta textual ya cuenta con identidad, memoria canónica, agenda, agrupación de mensajes y control de turnos superados. Falta conectar el contenido real de adjuntos y enlaces a esa misma ruta. Algunas reglas léxicas todavía producen silencios o rechazos de conversaciones normales. Quitar esas reglas indiscriminadamente tampoco proporciona visión, lectura de documentos ni continuidad.

## Flujo observado

1. Android captura mensajes de MessagingStyle y, cuando la aplicación origen expone una URI accesible, copia el archivo de ese mensaje a caché.
2. NotificationObject convierte los eventos; el historial canónico registra mensajes y procedencia. La memoria de prompt mantiene una ventana reciente y declara cobertura parcial.
3. BurstTurnGate agrupa fragmentos por conversación. RuleDispatcher solicita un borrador al compositor.
4. El compositor intenta enriquecer multimedia, resuelve memoria y aplica el analizador personal antes del modelo.
5. El writer construye persona, agenda e historial y elige inferencia local o nube.
6. Parser, política de idioma, validación semántica y motor de decisión revisan el candidato.
7. El dispatcher comprueba si llegó otro mensaje y si sigue autorizada la respuesta; después usa la capacidad RemoteInput. Despachar no demuestra entrega ni lectura.

## Hallazgos prioritarios

### P1. Los adjuntos reales se pierden antes de comprenderlos

Android conserva rutas individuales de imagen, audio, vídeo y PDF en NotificationAutomationService. NotificationObject tipa únicamente audioPath e imagePath. El enriquecedor no consume esos adjuntos ni las rutas extraídas por ParsedMediaMessage: llama a WhatsAppMediaLocator usando solo el tiempo. Ese localizador devuelve siempre un adjunto ambiguo, sin ruta. Por esta ruta, la transcripción no llega a ejecutarse aunque exista un archivo vinculado al evento.

Evidencia: NotificationMessageMedia.kt:37; NotificationAutomationService.kt:617; notification_object.dart, factoría fromMap; conversation_media_enricher.dart:62; whatsapp_media_locator.dart:9.

Corrección propuesta: usar primero los adjuntos explícitos del evento, conservar tipo, MIME, identidad y estado de procesamiento; no buscar archivos de otros chats por proximidad temporal. Conectar transcripción al archivo real y preservar el texto que acompañaba el adjunto.

### P1. Las fotos no pasan por comprensión visual en el flujo automático

conversation_media_enricher.dart:119 siempre marca photoUnprocessed=true. conversation_reply_flow.dart:67 retorna inmediatamente una pregunta fija sobre la foto; composeSuggestions retorna una lista vacía. No se invoca OCR ni un modelo visual en esa rama. Un pie de foto que ya explica la solicitud puede quedar sin responder por ese retorno temprano.

Corrección propuesta: extraer texto con OCR cuando corresponde y usar una ruta visual comprobada para escenas, objetos y relaciones. OCR por sí solo no permite comprender cualquier foto. Elegir el motor por capacidades reales y combinar la observación con el mensaje y la conversación. Consultar al contacto solo cuando falte información necesaria.

### P1. PDF y enlaces no tienen una lectura completa conectada a la respuesta automática

El enriquecedor contempla audio e imagen, pero no procesa parsed.pdfs ni parsed.links. LinkMetadataService obtiene título, descripción e imagen para una tarjeta de interfaz; sus consumidores encontrados son de presentación. El fallback de conocimiento externo no garantiza la lectura del cuerpo de cada URL recibida.

PdfTextExtractionService existe en la biblioteca comercial y utiliza PDFBox. No encontré su conexión al enriquecimiento del mensaje personal. El canal extrae texto embebido; no renderiza páginas ni ejecuta OCR para PDF escaneado. Poder abrir el visor no demuestra que el modelo haya leído el documento.

Corrección propuesta: lector compartido de documentos y enlaces que entregue evidencia al mismo turno: contenido, página o URL de origen, fecha de consulta y estado parcial/completo. Usar extracción textual en PDF digital, OCR por página cuando sea escaneado y selección de fragmentos relevantes para documentos largos. No prometer lectura de páginas que no se procesaron ni de sitios que no permiten acceso.

### P1. Bloqueos por vocabulario cortan conversación legítima

PersonalConversationAnalyzer aplica requireHuman si aparece cualquier coincidencia con nequi, banco, bancolombia u otras palabras, antes de inferencia. Una conversación como «¿nos vemos junto al banco?» o «¿tienes Nequi?» entra en esa categoría sin comprobar una operación o un código real.

PersonalLanguagePolicy rechaza parce y otros regionalismos. El parser la aplica antes de la excepción trustedPersonaStyle del compositor; por ello una respuesta generativa con vocabulario del dueño puede desaparecer aunque su contenido sea apropiado. El detector de actividad también busca palabras como comiendo sin verificar de quién se habla; una pregunta como «¿estás comiendo?» puede interpretarse como una afirmación sobre el dueño.

Evidencia: personal_conversation_analyzer.dart:38 y :80; personal_language_policy.dart; notification_draft_writer_response.part.dart:81; conversation_decision_guards.dart:41.

Corrección propuesta: retirar prohibiciones léxicas generales y distinguir intención, sujeto, pregunta, negación y acción solicitada. Permitir el estilo autorizado por el dueño de manera coherente en todas las capas. Conservar control de destinatario, duplicados y toma de control manual.

### P1. Tener agenda activa no valida cualquier afirmación sobre el dueño

conversation_decision_live_state.part.dart:21 retorna sin revisar actividad si hasOwnerLiveAgenda=true. Ese booleano indica que el día tiene contenido habilitado, no que una frase corresponda al tramo actual. La agenda podría contener solo una nota o una actividad futura.

Corrección propuesta: comparar la afirmación concreta con la fecha y el tramo efectivos, incluyendo las pausas de comida. Distinguir horario declarado, estado confirmado y ubicación observada. La agenda informa un plan; no prueba que la actividad se ejecutó ni que existe dinero o intención para aceptar una invitación.

### P1. El rescate con nube puede perder continuidad

Cuando el prompt se preparó para inferencia local, el historial se transporta aparte en prepared.history y el sistema en prepared.systemContext. Si el resultado local se rechaza, notification_draft_writer_draft.part.dart:137 llama a cloudPort.generate con solo prepared.prompt. El contrato de GenerativeInferencePort tampoco tiene historial o contexto de sistema separados. La nube de rescate no recibe los mismos turnos que el modelo local.

Corrección propuesta: reconstruir una solicitud equivalente para el proveedor de rescate, con historial, persona y evidencia del mismo turno, sin alterar la caché del motor local. El fallback conversacional adicional también recibe un mensaje aislado: su parámetro memory no se incorpora a la consulta.

### P2. La revisión de redundancia es limitada

conversation_decision_guards.dart:95 detecta algunas preguntas de gustos o del día mediante frases fijas y principalmente con el mensaje actual. No demuestra una revisión general de preguntas ya contestadas, datos aportados en otro fragmento, referencias a adjuntos ni pertinencia de pedir lugar/hora ante una invitación.

Para el caso «o nos vamos de fiesta», acortar «¿a dónde vamos?» a «¿a dónde?» no resuelve la interpretación de la invitación ni la posible aceptación implícita. Hay que combinar intención, relación, disponibilidad declarada y datos presentes; formular una aclaración solo si hace falta para continuar. No convertir cada turno en una pregunta.

### P2. Lecturas y cachés necesitan ajustes para no degradar la experiencia

LinkMetadataService limita el tiempo de obtener cabeceras, pero la lectura posterior del cuerpo no tiene su propio plazo; client.close no está en finally. La caché estática no tiene TTL ni límite, y un fallo queda cacheado como fallback durante el proceso. Puede persistir una vista previa fallida o quedar una operación en vuelo.

PdfTextExtractionChannelHandler hace la extracción de hasta 200 páginas sin delegar explícitamente el trabajo fuera del manejador del canal. Si se conecta directamente a la mensajería, esa operación puede afectar la interfaz; verificar su ejecución en segundo plano y cancelación antes de reutilizarla.

Estas observaciones son de código, no una medición de fuga, bloqueo o latencia en dispositivo.

## Orden de corrección propuesto

1. Conectar adjunto real → extracción/transcripción/visión → evidencia del turno → respuesta.
2. Integrar PDF digital, PDF escaneado y lectura de URL, compartiendo servicios existentes.
3. Dar al rescate local/nube la misma conversación y evidencia.
4. Sustituir bloqueos de palabras por interpretación contextual y estilo del dueño.
5. Revisar preguntas repetidas y compromisos implícitos con conversaciones completas.
6. Comprobar en teléfono la latencia, cancelación, reinicio y estados de envío.

Para preservar rapidez: no descargar ni analizar de nuevo el mismo archivo; cachear por identidad del adjunto/contenido; usar extracción local sencilla primero; reservar visión y nube para solicitudes que las necesiten. Medir antes de afirmar mejora de velocidad.

## Validación realizada y pendiente

Se ejecutaron cinco archivos existentes: whatsapp_personal_agent_test.dart, personal_conversation_resolver_test.dart, personal_conversation_language_understanding_test.dart, notification_canonical_mapper_test.dart y canonical_context_order_test.dart.

Resultado: 78 pruebas aprobadas y 5 fallidas. Hay desacuerdos previos entre pruebas y comportamiento vigente, incluyendo expectativas de reparaciones o respuestas deterministas que ahora se delegan al modelo. No se corrigieron ni se consideraron todas inocuas. Las pruebas revisadas no demuestran comprensión visual ni entrega real.

Antes de declarar una experiencia completa, comprobar en un contacto de prueba autorizado: foto con pregunta y pie de foto, captura con texto, foto sin texto, audio con URI, PDF digital, PDF escaneado, consulta sobre un enlace, referencia posterior al mismo adjunto, interrupción por mensaje nuevo, reinicio de aplicación y rescate en nube conservando el historial. Evaluar pertinencia, ausencia de preguntas redundantes, fidelidad a la evidencia y tiempo real de respuesta. No se enviaron estos mensajes durante la auditoría.
