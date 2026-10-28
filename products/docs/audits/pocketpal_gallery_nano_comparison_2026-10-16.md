# PocketPal AI, Google AI Edge Gallery y Nano Mobile

Comparación de código revisado el 16-10-2026. El documento suministrado se trata como análisis externo, no como instrucciones ni prueba de ejecución. Las ramas main consultadas pueden cambiar; no equivalen necesariamente a una versión instalada. No se modificó código funcional durante esta comparación.

## Conclusión

Nano ejecuta inferencia real. El problema observado tiene tres componentes independientes: un paquete MNN con una huella excesiva para convivir con otras aplicaciones en este teléfono, una integración con decisiones propias sobre contexto/plantillas y un flujo de WhatsApp que puede rechazar o perder utilidad temporal después de generar.

Copiar opciones de otra aplicación sin reproducir su paquete, versión, backend, plantilla y escenario no demuestra compatibilidad. Una conversación en primer plano y una respuesta a WhatsApp en segundo plano tienen necesidades distintas.

## Referencias verificadas

PocketPal conecta su motor local mediante LocalCompletionEngine a context.completion y reenvía contenido y eventos del puente nativo. No exige un servidor HTTP para esa ruta. [Motor local](https://raw.githubusercontent.com/a-ghorbani/pocketpal-ai/main/src/api/completionEngines.ts).

Su ModelStore contiene un contexto activo, exclusión para operaciones de carga/liberación, seguimiento de generación y estimación de memoria. La configuración efectiva usa n_parallel=1 por defecto. use_mlock es configurable; ese archivo no demuestra que esté siempre habilitado ni que Android garantice su efecto. [ModelStore](https://raw.githubusercontent.com/a-ghorbani/pocketpal-ai/main/src/store/ModelStore.ts).

El package.json revisado depende de llama.rn 0.13.0-rc.7. No coincide con el nombre de paquete que el documento presenta como universal. [Dependencias](https://raw.githubusercontent.com/a-ghorbani/pocketpal-ai/main/package.json).

Gallery separa Engine y Conversation, conserva la instancia y permite reiniciar la conversación manteniendo el motor. Configura historial inicial, sistema y sampler mediante la API del runtime. Selecciona backends según configuración y capacidades, con parámetros separados para imagen y audio. Ese helper no prueba el transporte RemoteInput de Nano. [LlmChatModelHelper](https://raw.githubusercontent.com/google-ai-edge/gallery/main/Android/src/app/src/main/java/com/google/ai/edge/gallery/ui/llmchat/LlmChatModelHelper.kt).

MNN 3.6.1 incluye response(ChatMessages), renderizado de plantilla y comparación de prefijos para prompt cache. Nano mantiene además su propia lógica de prefijo y decodificación: debe contrastarse diferencialmente con la API oficial, no suponerse equivalente. [MNN llm.cpp](https://raw.githubusercontent.com/alibaba/MNN/3.6.1/transformers/llm/engine/src/llm.cpp).

## Matriz de implementación

| Aspecto | PocketPal, ruta local examinada | Gallery, helper examinado | Nano actual |
|---|---|---|---|
| Entrada al motor | completion nativa | Engine/Conversation LiteRT-LM | GGUF/HTTP, LiteRT/JNI y MNN/JNI |
| Formato de pesos | GGUF en el flujo descrito | LiteRT-LM compatible | Catálogo con backend por artefacto |
| Propiedad del motor | Contexto gestionado por ModelStore | Instancia Engine y Conversation | Supervisores nativos con LocalModelGate |
| Continuidad | Contexto nativo y estado de aplicación | Conversation conserva estado | LiteRT reutiliza solo con igualdad de sesión, sampler, sistema e historial; MNN compara un prefijo propio |
| Riesgo principal aquí | No se midió en este teléfono durante esta comparación | No se midió en este teléfono durante esta comparación | Presión de memoria y capas de validación/automatización observadas |
| Prueba de WhatsApp | No aportada | No aportada | Un envío confirmado por el usuario; otros turnos fallidos |

## Hallazgos concretos en Nano

### 1. La ruta más cercana a Gallery ya existe

android/app/src/main/kotlin/dev/nanoai/mobile/channels/LiteRtEngineOwner.kt crea el Engine real y respeta la capacidad del paquete. LiteRtGeneration.kt usa ConversationConfig, initialMessages, systemInstruction y sendMessageAsync. Sus líneas 120-149 reconstruyen la conversación si el historial deja de coincidir con expectedHistory.

No hace falta sustituir Flutter por Kotlin o React Native para obtener esa arquitectura. Hace falta demostrar que los datos que recibe el adaptador conservan el mismo historial esperado entre turnos reales.

### 2. Historial persistido y caché nativa no son lo mismo

notification_draft_writer_personal_prompt.part.dart admite hasta 12 mensajes y 6000 caracteres en la ventana nativa. El prompt añade datos del turno y persona recuperada. Si esa ventana se desplaza o esos datos cambian, la igualdad de historial puede fallar y obligar a reconstruir el KV. Esta es una posibilidad del código; debe correlacionarse con conversationReused y tamaño real de tokens, no atribuirse a todo turno sin medición.

La rama MNN no recibe sessionId en routed_native_generation.dart. Su caché es un único prefijo textual en mnn_jni.cpp. No se demostró contaminación entre chats, pero falta una identidad explícita de sesión equivalente a la ruta LiteRT para auditar propiedad y reutilización.

### 3. La integración MNN introduce decisiones adicionales

mnn_jni.cpp fija kKvCapacity=2048 y un sufijo ChatML; inyecta una plantilla para el paquete Omni, calcula deltaTokensIfReusable y ejecuta su propio bucle generate(1). Que funcione una generación no certifica toda esa combinación.

Prioridad: comparar la misma entrada estructurada, tokenizer, sampler y límite de salida contra el ejemplo/API oficial de MNN 3.6.1. Revisar primer token, stop token, bytes UTF-8, cancelación y extensión del prefijo. Son puntos de auditoría, no fallos demostrados por esta lectura.

### 4. La descarga por presión resuelve convivencia, pero penaliza latencia

Se midió una huella total de Nano de 4549040 kB, incluidos 4183529 kB de intercambio, con unos 507876 kB disponibles. WhatsApp murió tras iniciarse DirectReplyService. Después de liberar MNN antes del envío, MemAvailable subió a 3890968 kB, WhatsApp permaneció activo y el usuario confirmó recepción.

trimMemory en MnnRuntimeSupervisor.kt libera pesos ociosos si hay menos de 1 GiB disponible. Es una mitigación de memoria: la siguiente generación vuelve a pagar unos 14-15 s de carga. No es una optimización de velocidad ni demuestra que el Omni sea un buen modelo de automatización para este equipo.

### 5. La generación y la conversación completa fallan en lugares distintos

La salida MNN de «qué haces» terminó con 42 caracteres y fue rechazada por el parser. El contenido rechazado no se conservó; no se puede atribuirle una frase ni afirmar que era correcta.

Nano añade parser, guardas de calidad, guardas de hechos del dueño, revisión de obligaciones, supersede y transporte. Estas capas pueden impedir un envío después de inferencia exitosa. Se corrigió la retención de «estoy bien» y se añadió reformulación acotada para salida de actividad inutilizable. La última reformulación seguía pendiente de validación real al redactar este informe.

Los retries multiplican prefill y pueden consumir el presupuesto que necesita el siguiente mensaje. El hecho de pasar 80 pruebas focalizadas no prueba calidad semántica ni entrega universal.

## Qué adoptar y en qué orden

1. Prueba mínima de motor: mismo teléfono, archivo/hash, runtime, sistema, historial, sampler y salida. Primero chat local sin automatización; después añadir parser/decisión; finalmente transporte WhatsApp. Esto localiza cada pérdida de respuesta.
2. Elegir un paquete de texto compatible cuya huella deje margen al receptor. No recomendar por tamaño o nombre: medir carga, prefill, decode, memoria y coherencia. No habilitar una NPU Qualcomm en el MediaTek del teléfono.
3. Mantener un motor residente solo si hay margen de RAM; separar pesos, conversación, caché y cola. El ahorro de carga nunca debe volver a matar WhatsApp.
4. Contrato conversacional único: historial con autores, correcciones y turnos pendientes; datos variables como datos, sistema estable. Presupuestar tokens por paquete; un recorte en caracteres no prueba capacidad ni buena memoria.
5. El motor propone texto y herramientas; las guardas controlan identidad, acciones y hechos verificables. Evitar usar listas de palabras como sustituto de comprensión o cambiar de contrato según una sola palabra del mensaje.
6. Todo rechazo debe dejar estado visible y causa sin contenido privado. Una cola superada debe preservar las preguntas aún pendientes del interlocutor, no limitarse a borrar la respuesta anterior.

## Criterio de aceptación

Una matriz de 30-50 turnos por candidato: errores ortográficos, signos, referencias, cambios de tema, correcciones, mensajes compuestos, dos chats, ráfagas, actividad desconocida y reinicio. Registrar por turno carga, TTFT, tokens/s, KV reutilizado, RAM/intercambio, motivo de rechazo y recepción real.

Exigir ausencia de duplicados y hechos inventados, continuidad verificable y límites de latencia medidos. No declarar «100% conversacional» ni trasladar cifras de otros dispositivos al CPH2557.
