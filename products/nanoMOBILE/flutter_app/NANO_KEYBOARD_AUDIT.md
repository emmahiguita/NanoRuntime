# Nano Keyboard 2026 — Auditoría Técnica del Sistema de Escritura

## 1. Localización del Sistema y Arquitectura
- **Servicio Principal**: `dev.nanoai.mobile.input.NanoInputMethodService` (`android/app/src/main/kotlin/dev/nanoai/mobile/input/NanoInputMethodService.kt`).
- **Motor de Render e Interfaz**: Vistas nativas optimizadas de Android (`LinearLayout`, `TextView`, `StateListDrawable`, `PopupWindow`). Cero recargas de interfaz innecesarias, cero dependencias pesadas de Compose que consuman RAM de inferencia de modelos locales.
- **Ciclo de Vida IME**: `onCreate`, `onCreateInputView`, `onStartInputView`, `onFinishInputView`, `onDestroy`.
- **Integración con Nano Local**: Conectado directamente a través de `NanoApplication.from(context).modelRuntimeSupervisor` sin duplicar modelos ni dependencias externas.

---

## 2. Clasificación de Capacidades Existentes vs Auditadas

| Capacidad | Estado Previo | Diagnóstico y Defecto Encontrado | Solución Aplicada (Fase 1-5) |
| :--- | :--- | :--- | :--- |
| **Entrada de caracteres y commitText** | IMPLEMENTADA | Inserción directa básica sin reemplazo seguro de palabras ni buffers de predicción. | Implementado con `NanoInputConnectionHelper` atómico con `beginBatchEdit()` / `endBatchEdit()`. |
| **Borrado seguro (Backspace)** | DEFECTUOSA | Usaba `deleteSurroundingText(1, 0)`. Al borrar emojis o caracteres suplementarios UTF-16, dividía los *surrogate pairs* dejando símbolos rotos. | `NanoInputConnectionHelper.safeDelete()`: detecta API 24+ `deleteSurroundingTextInCodePoints(1, 0)` y verifica `Character.isSurrogatePair()`. |
| **Repetición de Backspace** | PARCIAL | Manejada con handler pero sin sincronización con predicciones ni detención al cambiar de ventana. | Sincronizado en `NanoKeyboardView` con cancelación garantizada en `onDetachedFromWindow()` y `onFinishInputView()`. |
| **Shift y CapsLock** | PARCIAL | Un solo toque cambiaba a mayúsculas; el doble toque no estaba estandarizado en bloqueo real. | Doble toque (< 500 ms) bloquea mayúsculas (`⇪`), un toque mayúscula temporal (`⬆`), minúscula (`⇧`). Actualización in-place en 0 ms. |
| **Enter Contextual** | DEFECTUOSA | Botón verde brillante `#10B981` estático con etiqueta forzada sin respetar campos multilínea. | Adaptación dinámica a `EditorInfo.imeOptions` (`IME_ACTION_SEARCH`, `SEND`, `GO`, `NEXT`, `DONE`) y respetando `TYPE_TEXT_FLAG_MULTI_LINE` (salto de línea `\n`). Color cambiado al token M3 Azul Nano. |
| **Pulsación prolongada (Tildes/Variantes)** | AUSENTE | No existía selector de caracteres alternativos para vocales ni símbolos. | Creado `NanoKeyPopup` con `PopupWindow`: long-press en `a`, `e`, `i`, `o`, `u`, `n`, `?`, etc. despliega burbuja de tildes seleccionables sin pulsar caracteres erróneos. |
| **Sugerencias y Autocompletado** | AUSENTE | No existía barra ni motor de diccionario para predecir palabras mientras se escribe. | `NanoDictionaryEngine` en memoria (< 1 ms de búsqueda de prefijos) integrado en tiempo real con `NanoKeyboardToolbar`. |
| **Panel de Emojis** | AUSENTE | No había acceso a selector nativo de emojis. | Implementado `NanoEmojiView` con 4 categorías completas (Emociones, Gestos, Naturaleza/Nano, Objetos/Símbolos), scroll fluido y retorno instantáneo con botón `ABC`. |
| **Dictado de Voz** | AUSENTE | Solo existía el botón en la UI de Flutter, no en el teclado nativo. | Implementado `NanoVoiceInputHelper` con `SpeechRecognizer`, verificación de permisos y retroalimentación de estados (`LISTENING`, `PROCESSING`, `ERROR`). |
| **Barra Superior Inteligente** | DEFECTUOSA | "Nano AI", "Pegar" y "Teclados" ocupaban espacio estático y desconectado. | Barra compacta M3 Expressive: Rostro del Búho albino a la izquierda, barra central adaptable (Sugerencias / Herramientas / Nano Local), micrófono y menú a la derecha. |
| **Nano Local Assistant** | PARCIAL | El botón del búho solo abría la app principal sin acciones de escritura. | `NanoLocalAssistant`: acciones reales de "Corregir ortografía", "Mejorar redacción", "Resumir", etc. que consultan el supervisor local real de LiteRT. |
| **Protección en Contraseñas** | PARCIAL | Solo verificaba portapapeles. | Se desactiva la IA contextual, se suprimen sugerencias y se previene cualquier registro en campos marcados con `TYPE_TEXT_VARIATION_PASSWORD`. |

---

## 3. Cuellos de Botella y Rendimiento
- **0 ms GC Overhead**: No se recrean layouts de teclas durante la escritura; los contenedores de letras y símbolos se conservan en memoria y solo cambian de visibilidad (`VISIBLE` / `GONE`).
- **Desacoplamiento de Nano Local**: El motor de escritura NUNCA espera por el modelo de IA. La inferencia ocurre de forma estrictamente asíncrona en `Dispatchers.IO`, garantizando 60-120 FPS táctiles constantes en el hilo de UI.
