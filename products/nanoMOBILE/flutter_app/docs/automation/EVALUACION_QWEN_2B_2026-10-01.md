# Qwen3.5-2B: evaluación real en Nano Mobile

Fecha: 1 de octubre de 2026 (Colombia). Dispositivo: Oppo CPH2557, 8 GB físicos aproximados.

## Resultado

El modelo quedó descargado, verificado, reconocido por Nano y cargado realmente.
No quedó aprobado para respuesta automática: falló la continuidad en los casos observados.
No se ejecutaron suites de tests ni se enviaron mensajes a contactos.
Las consultas manuales se hicieron al runtime del teléfono por ADB/HTTP.
Esto evalúa motor e instrucciones; no acredita el envío final ni todo el flujo de WhatsApp.

## Artefacto e instalación

Archivo: Qwen3.5-2B-Q4_K_M.gguf, 1.280.835.840 bytes.
Origen: https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/blob/main/Qwen3.5-2B-Q4_K_M.gguf
SHA-256 publicado y calculado, igual en PC y teléfono:
aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223

Ubicación Android:
/data/user/0/dev.nanoai.mobile/files/nano/models/Qwen3.5-2B-Q4_K_M.gguf

El catálogo creó su propio manifiesto de integridad y mostró el modelo instalado.
Había una descarga simultánea en la app: se canceló para evitar otra copia completa.
Se reinició únicamente Nano para cerrar esa descarga y refrescar el catálogo.
Se conservaron modelos, datos y conversaciones; no se instaló otra APK.

El runtime confirmó model_loaded=true, model_size_mb=1221 y context_size=4096.
PID del motor durante Qwen: 6512; worker: 5294; app: 5207.
Se observó un solo motor, sin hijos zombis persistentes.

## Condiciones de las consultas

Se usaron los contratos y prompts actuales de Personal, no respuestas prefabricadas.
Los mensajes de continuidad y corrección se pasaron con roles user/assistant.
Temperatura explícita: 0,3. Máximos: 128 tokens de identidad, 320 en los otros casos.
SSE registró el primer texto recibido por el cliente y la respuesta completa.
Cada petición tuvo identificadores distintos; el runtime sí reutilizó prefijos de sistema.

Llama tenía caché caliente; Qwen tuvo prefijos fríos y calientes.
Había reproducción de YouTube en el teléfono; no se aisló toda la carga del sistema.
Temperatura de batería observada: 39,9–40,0 °C, no una medición de temperatura de CPU.
Son muestras puntuales, no una comparación estadística ni una garantía de velocidad.
Llama produjo respuestas mucho más cortas: comparar tiempo total no mide calidad equivalente.

## Medidas del cliente

| Consulta | Llama 3.2 1B: primer texto / total | Qwen 3.5 2B: primer texto / total |
| --- | --- | --- |
| Identidad de Nano | 2,228 s / 4,155 s | 25,063 s / 42,284 s |
| Continuidad | 7,037 s / 8,486 s | 38,998 s / 41,966 s |
| Corrección | 5,463 s / 6,911 s | 5,713 s / 27,992 s |

El TTFT interno de Qwen fue 1,621 s, 7,459 s y 5,489 s respectivamente.
No equivale al tiempo completo del cliente: la preparación del prefijo ocurre antes.
No se debe presentar ese TTFT interno como latencia total de respuesta.

## Calidad observada

Identidad: Qwen explicó Nano como aplicación Android, asistente, chat y agentes.
Añadió redundancia sobre conexiones externas; una ruta local no acredita la ausencia
de cualquier otra conexión de la app. Llama respondió de forma más genérica.

Continuidad recibida:
- Usuario: Ayer terminé el catálogo y hoy voy a ordenar las fotos.
- Asistente: ¿Cuántas fotos te faltan?
- Usuario: Solo tres. Después las mando. ¿Qué voy a hacer primero y qué ya terminé?

Lo confirmado era catálogo terminado, ordenar fotos primero y enviarlas después.
Llama preguntó «¿Qué fotos vas a tomar?».
Qwen preguntó «¿Qué ya terminaste ayer?», aunque el dato estaba en el historial.
Ninguno respondió ambas preguntas correctamente.

Corrección recibida:
- Asistente: Entonces ya enviaste las fotos.
- Usuario: No, las fotos no las he enviado todavía. Primero tengo que ordenarlas.

Llama respondió «No puedo ayudarte con eso.».
Qwen reconoció ordenar las fotos, pero añadió explicación y una pregunta innecesaria.
No se aprobó como respuesta completa y directa.

Todas las respuestas observadas de Qwen empezaron con un bloque think vacío.
No hubo razonamiento no vacío en esas cinco muestras. No se debe ocultar razonamiento
incompleto o no vacío para simular una respuesta válida.
El ajuste de parser de think vacío del informe anterior sigue pendiente de APK final.

## Aislamiento adicional

Con instrucciones mínimas (156 caracteres), mismo historial y temperatura:
Qwen tardó 11,189 s al primer texto y 17,442 s total.
Dio por terminado «Ordenar las fotos», que estaba pendiente.

Con historial escrito dentro del mensaje, sin roles separados:
Qwen tardó 7,816 s al primer texto y 13,969 s total.
Afirmó «Las has enviado ya», contradiciendo el contexto.
Reducir las instrucciones o aplanar el historial no resolvió estos casos.

## Diferencias con la configuración oficial

Fuente oficial del formato:
https://huggingface.co/Qwen/Qwen3.5-2B/raw/main/chat_template.jinja

La plantilla oficial, al abrir la respuesta sin thinking, añade después de
la cabecera assistant el bloque completo y vacío <think>\n\n</think>\n\n.
La rama genérica de Nano termina en la cabecera assistant y omite ese bloque.
El servidor /completion acepta temperatura, contexto e historial, pero no
enable_thinking ni chat_template_kwargs: enviar esos campos no configura ese modo.

Fuente oficial de muestreo:
https://huggingface.co/Qwen/Qwen3.5-2B#best-practices

La receta oficial de texto sin thinking usa temperatura=1,0, top_p=1,0,
top_k=20, min_p=0, presence_penalty=2 y repetition_penalty=1.
Las muestras usaron temperatura=0,3 del diagnóstico, no la receta oficial completa.
No se ha demostrado que cambiar solo temperatura resuelva la continuidad.
Tampoco se ha comparado este GGUF en un backend de referencia independiente.

Conclusión: falla esta combinación de Nano, parámetros y modelo. No corresponde
afirmar que Qwen 2B es incapaz de conversar en todos los runtimes.
Debe corregirse y comprobarse el formato oficial antes de decidir adoptar otro modelo.
Esa corrección aún no está implementada ni instalada.

## Estado al terminar las consultas

Llama fue restaurado como modelo activo, sin declararlo ideal.
Su motor PID 8588 quedó vivo; el recolector confirmó reaped detached pid=6512.
Qwen 2B permanece instalado, pero no se habilitó como fallback automático.
No se tocaron funciones del otro chat ni código de producción durante esta evaluación.

