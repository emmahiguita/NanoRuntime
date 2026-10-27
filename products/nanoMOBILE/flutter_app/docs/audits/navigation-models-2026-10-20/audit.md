# Auditoría de navegación y modelos de Nano

Fecha: 20 de octubre de 2026. Alcance: dock compartido, catálogo, ficha realmente abierta por el catálogo, selección/importación y trazado de capacidades hasta el chat.

## Cómo se obtuvo la evidencia

- Inspección visual del Nano instalado en el CPH2557 conectado, no de una maqueta.
- Grafo del proyecto seguido de lectura de las implementaciones actuales. El grafo conserva símbolos antiguos; las llamadas e importaciones actuales se comprobaron antes de retirar archivos.
- Consulta de metadatos públicos de los 33 registros del catálogo, sin descargar sus pesos. Se guardan resultados anteriores y posteriores en JSON.
- Lectura del enrutamiento Dart, los adaptadores y el contrato de adjuntos. No se ejecutaron tests automatizados ni conversaciones de prueba.
- La comprobación de un hash valida identidad del archivo. No valida precisión, memoria real, compatibilidad con todos los teléfonos ni velocidad.

## Defectos encontrados y correcciones

| Hallazgo | Corrección aplicada | Evidencia |
|---|---|---|
| El tirador de escritura ocupaba una franja superpuesta a los destinos. | Franja separada de los cuatro botones. | `nano_multi_use_nav_bar.dart` |
| Selección con escalado, sombras y un BackdropFilter adicional dentro de cada destino. | Una superficie estable de selección; se mantiene el cristal exterior compartido. | `nano_nav_destination_item.dart` |
| Cuatro destinos sin nombres visibles. | Nombres breves visibles y etiquetas semánticas completas. | `nano_nav_destination_item.dart` |
| La píldora compacta parecía tener área segura, pero el callback estaba en su interior de 44×28. | El callback cubre el área exterior de 56×48; la pieza visible sigue siendo pequeña. | `nano_nav_mini_pill.dart` |
| Entrada con curva que sobrepasaba su escala final. | Desvanecimiento/escala acotados y respeto al ajuste del sistema para reducir movimiento. | `nano_bottom_dock.dart` |
| El dock desaparecía tras 2,4 segundos. | Reposo de cinco segundos; escritura conserva su estado sin cierre automático. | `nano_nav_constants.dart`, `nano_navigation_panel.dart` |
| OCR figuraba en la clasificación, pero faltaba en el orden de la cuadrícula. | Categoría OCR visible y separada de comprensión visual. | `models_category_grid.dart` |
| Títulos de categorías truncados en una línea. | Dos líneas, altura ajustada a escala de texto y columnas según el ancho local del panel. | `models_category_grid.dart` |
| Gemma/Omni parecían simples modelos de texto sin explicar sus modalidades originales. | Grupo multimodal con distinción explícita entre capacidad publicada y texto conectado en Nano. | `model_item_categories.part.dart`, `model_item_narrative.part.dart` |
| La ficha abierta no mostraba los límites de cada tarea y no observaba el progreso. | Ventana reactiva por ID con propósito, disponibilidad, límites, fuente y progreso real. | `model_floating_window.dart`, `model_usage_information.dart` |
| La acción de favoritos llegaba a la ventana sin control visible. | Botón conectado al callback persistente y estado visual inmediato. | `model_window_actions.dart` |
| La ventana permitía intentar cargar recursos sin adaptador que la lista bloqueaba. | La ventana y su callback respetan la misma disponibilidad que la lista. | `model_window_actions.dart`, `models_screen_actions.part.dart` |
| Dos variantes podían figurar activas por coincidencia parcial del nombre. | Igualdad del identificador visible; el estado activo también requiere motor listo. | `models_list_section.dart`, `models_screen.dart` |
| Comparación escogía el primer archivo GGUF, incluso Whisper. | Solo archivos instalados de tipo LLM para comparar inferencia de texto. | `models_screen_actions.part.dart` |
| Comparar desde la ficha entregaba DTO de interfaz a una función dinámica que esperaba modelos del repositorio. | Firma tipada y lectura de modelos del estado real. | `models_screen_actions.part.dart` |
| Una ficha abierta conservaba una acción de uso condicionada por su estado inicial. | Cargar y liberar son callbacks separados; la ventana calcula el estado actual. | `models_screen_actions.part.dart`, `model_window_actions.dart` |
| Salir del editor cancelaba el stream Dart de dictado, pero no el reconocedor nativo. | Cancelación del reconocedor propio al salir, tras fallo y al cambiar de controlador. | `nano_nav_search_panel.dart` |
| Importación consultaba hashes de main aunque el enlace indicara otra revisión. | Metadatos consultados en la revisión solicitada y descarga fijada al commit resuelto. | `hugging_face_gguf_import_service.dart` |
| Seis hashes no coincidían con la fuente, varios de ellos con longitud incorrecta. | Valores comprobados contra LFS y URLs fijadas a revisión. La verificación SHA permanece obligatoria. | JSON antes/después y `catalog_entries_*.dart` |
| Paquetes Whisper completos se rotulaban Q5_1. | Corregidos a F16 para los archivos ggml-tiny.bin y ggml-base.bin. | `catalog_entries_2.dart` |
| Documentos, archivos, analíticas, modelos, nube, red, cámara y visión compartían dibujos. | Siluetas propias para significados distintos y recursos FeatherCore sin fondo. | `feather_core_symbol.dart`, `feather_core_icon.dart` |
| Título superior redundante y truncado; PC GPU sugería hardware y conexión no medidos. | Título corto, cabecera orientada a tareas y etiqueta de destino PC sin afirmar conexión ni GPU activa. | `models_screen.dart`, `models_catalog_header.dart` |

## Capacidad real del flujo actual

| Recurso | Qué está conectado | Qué falta o no debe inferirse |
|---|---|---|
| 21 registros LLM | Ruta de generación de texto a llama.cpp, LiteRT-LM o MNN según el archivo. | No se ejecutaron los 21: existencia de adaptador no certifica cada artefacto. |
| Gemma 4 y Qwen Omni | Se ofrecen como multimodales de origen, con ruta actual de texto. | Seleccionarlos no envía automáticamente imágenes, audio o vídeo. |
| Qwen3.5-VL | Artefacto visual identificado. | Falta la entrada directa de imagen desde el chat al VLM. |
| PaddleOCR-VL | Especialista OCR identificado; no es chat general. | Falta su adaptador de tarea. El OCR existente usa Android. |
| Whisper Tiny/Base | Archivo GGML enlazado a WhisperSttService. | La calidad y latencia no se midieron en esta auditoría. |
| Moonshine y Qwen ASR | Tipo STT identificado. | Adaptadores propios pendientes; no deben enviarse a whisper.cpp. |
| Audio8 y Nemotron | Síntesis y diarización separadas. | Sus adaptadores no están conectados al flujo auditado. |
| EmbeddingGemma | Recursos de vectores identificados, incluido el multimodal. | No hay cadena de embeddings/índice/recuperación conectada que pruebe RAG documental. |
| GGUF importado | Selector local valida firma GGUF; enlace de Hub resuelve un archivo con checksum. | La firma no identifica su tarea. Los desconocidos no se presentan como chat o visión verificados. |
| Fotos del chat | OCR y etiquetas generales locales se convierten en evidencia textual. | No equivale a interpretación visual completa del modelo seleccionado. |
| PDF adjunto | Extracción de texto y OCR acotados, hasta ocho páginas y quince segundos. | No demuestra búsqueda automática de toda la biblioteca por carpetas, título o contenido. |
| Vídeo adjunto | Referencia explícita del archivo. | No hay análisis de fotogramas/audio de vídeo en esta ruta. |

El criterio funcional está basado en `ModelKind`, `NeuralCatalog`, `ModelsLifecycleDelegate`, `RuntimeEngineNotifier`, `RoutedLlmEngineClient`, `ChatVisionAdapter` y la preparación de adjuntos. En particular, la rama LiteRT del cliente recibe prompt/historial/contexto, sin reenviar `mediaInputs` a su adaptador.

## Integridad de fuentes

Se detectaron seis discrepancias: Whisper Tiny, Whisper Base, Qwen3.5-0.8B LiteRT texto, Qwen3.5-0.8B-VL LiteRT, LFM2.5-1.2B GPU y MiniCPM5-2B. Algunas fuentes publicaron cambios; otras cadenas del catálogo no tenían 64 caracteres. Se contrastaron los archivos exactos con sus metadatos públicos y se fijaron revisiones; no se sustituyeron por hashes inventados ni se desactivó la comprobación.

Resultado posterior: **32 archivos individuales con SHA-256 coincidente**. El registro adicional es un paquete MNN de varios archivos cuyo verificador propio se conserva; esta consulta de metadatos no lo certifica como conjunto. Revisar `models-evidence.md` y los dos JSON para cada registro.

Fuentes consultadas:

- https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm
- https://huggingface.co/litert-community/Qwen3.5-0.8B
- https://huggingface.co/litert-community/PaddleOCR-VL-1.6
- https://huggingface.co/litert-community/embeddinggemma-2-740m-litert-lm
- https://huggingface.co/taobao-mnn/Qwen2.5-Omni-3B-MNN
- API pública de metadatos por repositorio/revisión para los 33 registros.

## Componentes retirados

Sin importaciones ni llamadas desde el flujo actual: `ModelDetailSheet`, sus tres componentes de casos de uso, acciones y especificaciones, y `ModelItemCard`. El catálogo usa `ModelPerspectiveCard` y abre `ModelFloatingDialogRoute` → `ModelFloatingWindow`. Se retiran esos cinco archivos para no conservar una segunda ficha con casos de uso genéricos y etiquetas contradictorias.

## Mantenimiento y límites

- Separación de DTO, clasificación, disponibilidad, identidad y narrativa en archivos pequeños comentados. No se añaden controladores o tareas periódicas para los nuevos iconos.
- La animación del dock conserva un solo estado y cancela el timer en dispose. Se mantiene el editor en su jerarquía existente para no perder foco/texto al abrir el teclado.
- No se modificaron C++, llama.cpp, prompts personales, historial ni el comportamiento de envío de mensajes.
- Cinco PNG originales generados con la herramienta integrada: automatización, modelos, terminal, ajustes y OCR. Se comprobó canal RGBA con alfa 0–255. Los prompts completos y el origen están en `icon-generation.json`; los archivos usados por la app están en `assets/nano/feather_*.png`.
- La auditoría no certifica ausencia absoluta de bugs, fugas o lentitud en toda la app. Deben medirse por modelo y dispositivo.
- Próximas integraciones: entrada visual real al VLM, lectura de metadatos de GGUF importados, RAG documental y adaptadores especializados de audio. Son implementaciones independientes del diseño y no se simulan como disponibles.

## Validación de esta revisión

El resultado de compilación, instalación y recorrido manual se registra en `validation.md`. No se ejecutan pruebas automatizadas por indicación del usuario.

El usuario indicó continuar solo con código y compilación mientras usa el teléfono. La revisión visual final de los nuevos iconos, los temas y la orientación horizontal queda expresamente pendiente; no se presenta como realizada.
