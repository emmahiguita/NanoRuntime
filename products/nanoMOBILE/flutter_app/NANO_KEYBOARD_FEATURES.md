# Nano Keyboard 2026 — Matriz de Capacidades y Comparativa

## 1. Matriz de Estado de Capacidades

| Capacidad / Función | Estado en Nano Keyboard | Nivel de Implementación | Notas de Arquitectura |
| :--- | :--- | :--- | :--- |
| **Escritura Letras (QWERTY con Ñ)** | IMPLEMENTADA Y CONECTADA | 100% Nativo | Latencia de 0 ms en `ACTION_DOWN` con retroalimentación háptica. |
| **Shift y CapsLock** | IMPLEMENTADA Y CONECTADA | 100% Nativo | Toque simple: mayúscula temporal. Doble toque (< 500 ms): bloqueo CapsLock. |
| **Borrado seguro (Backspace)** | IMPLEMENTADA Y CONECTADA | 100% Nativo | Compatible con secuencias UTF-16 y pares sustitutos. Repetición continua fluida (45 ms). |
| **Tildes y Acentos (Long Press)** | IMPLEMENTADA Y CONECTADA | 100% Nativo | Selector flotante `NanoKeyPopup` para á, é, í, ó, ú, ü, ñ, ¿, ¡, divisas. |
| **Enter Contextual (IME Action)** | IMPLEMENTADA Y CONECTADA | 100% Nativo | Respeta `imeOptions` (Enviar, Buscar, Ir, Siguiente, Listo) y `TYPE_TEXT_FLAG_MULTI_LINE` (`\n`). |
| **Predicción y Autocompletado** | IMPLEMENTADA Y CONECTADA | 100% Nativo | `NanoDictionaryEngine` asíncrono con palabras frecuentes en español e inglés. |
| **Panel de Emojis Completo** | IMPLEMENTADA Y CONECTADA | 100% Nativo | `NanoEmojiView` con 4 categorías Unicode válidas y botón de retorno inmediato `ABC`. |
| **Portapapeles y Pegado Seguro** | IMPLEMENTADA Y CONECTADA | 100% Nativo | Pegado directo con `commitText()`. Protección activa en campos de contraseña. |
| **Dictado de Voz** | IMPLEMENTADA Y CONECTADA | 100% Nativo | `NanoVoiceInputHelper` con `SpeechRecognizer`, verificación de micrófono y estados claros. |
| **Nano Local Assistant** | IMPLEMENTADA Y CONECTADA | 100% Nativo | Consulta `NanoModelRuntimeSupervisor` para tareas de ortografía, redacción y resumen. |
| **Protección de Privacidad** | IMPLEMENTADA Y CONECTADA | 100% Nativo | En campos de contraseña se apagan sugerencias, IA contextual y portapapeles. |
| **Escritura Deslizando (Glide Typing)**| PARCIAL / PENDIENTE | Mapeo de trazo preparado | El decodificador basado en modelos de lenguaje abiertos se evalúa para evitar dependencias cerradas. |

---

## 2. Comparativa Funcional con Gboard y Teclados Libres

| Función | Gboard | HeliBoard | FlorisBoard | Nano Keyboard 2026 |
| :--- | :--- | :--- | :--- | :--- |
| **Identidad Visual** | Material You estándar | AOSP clásico | Personalizable | **Material 3 Expressive + Búho Nano** |
| **Asistente IA en Dispositivo** | Google Gemini (Pixel) | No disponible | No disponible | **Nano Local (LiteRT en dispositivo)** |
| **Rendimiento / Latencia** | Alta (60/120 Hz) | Alta | Media (Compose) | **Extrema (Views pre-instanciadas, 0 ms GC)** |
| **Privacidad de Escritura** | Requiere confiar en nube | 100% Offline | 100% Offline | **100% Offline en memoria local** |
| **Acceso a Emojis** | Panel integrado | Panel integrado | Panel integrado | **Panel clasificado con 4 categorías y retorno ABC** |
| **Gestión de Tildes** | Long press popup | Long press popup | Long press popup | **`NanoKeyPopup` adaptativo al centro óptico** |
