# Nano Keyboard 2026 — Protocolo de Verificación Manual

Este documento detalla las comprobaciones directas que el usuario o el equipo de QA pueden reproducir en un dispositivo Android físico o emulador.

---

## 1. Verificación de Escritura y Edición
- [ ] **Letras y Números**: Abrir cualquier app con campo de texto (WhatsApp, Notas o Navegador) y escribir texto alfanumérico rápido. Verificar que no exista retraso táctil en `ACTION_DOWN`.
- [ ] **Shift y Bloqueo de Mayúsculas**:
  - Tocar `⇧` una vez: la siguiente letra debe ser mayúscula y el teclado volver inmediatamente a minúsculas.
  - Tocar `⇧` dos veces rápidamente (< 500 ms): el icono cambia a `⇪` y todas las letras permanecen en mayúsculas hasta volver a tocar la tecla.
- [ ] **Tildes y Acentos (Long Press)**:
  - Mantener pulsada la tecla `a`: debe desplegarse el popup con `á`, `à`, `ä`, `â`, `@`.
  - Al tocar `á`, debe insertarse exactamente esa vocal tildada en el cursor.
  - Probar lo mismo con `e`, `i`, `o`, `u`, `n` y `?`.
- [ ] **Borrado Seguro y Repetición**:
  - Insertar un emoji (ej. `🦉` o `❤️`) y pulsar `⌫`: el emoji debe borrarse completo en un solo paso sin dejar caracteres extraños o rombos con signo de interrogación.
  - Mantener pulsado `⌫`: debe borrar de forma continua a 45 ms por paso.

---

## 2. Sugerencias y Autocompletado
- [ ] Escribir `hol`: en la barra superior deben aparecer sugerencias como `hola`.
- [ ] Tocar la sugerencia `hola`: la palabra parcial debe completarse y agregarse un espacio automáticamente.

---

## 3. Panel de Emojis y Retorno
- [ ] Tocar la tecla `😊` junto a la barra espaciadora: el teclado debe cambiar al panel clasificado de emojis.
- [ ] Cambiar de categoría (Emociones, Gestos, Nano y Naturaleza, Objetos).
- [ ] Tocar el botón `ABC` en la esquina inferior izquierda: debe retornar instantáneamente al teclado de letras.

---

## 4. Enter Contextual y Privacidad
- [ ] **Campo de Búsqueda**: En la barra de búsqueda de WhatsApp o navegador, la tecla Enter debe mostrar "Buscar".
- [ ] **Campo Multilínea**: En un editor de mensajes largo, debe mostrar el símbolo de salto de línea `↵` y generar una nueva línea sin enviar el mensaje accidentalmente.
- [ ] **Campo de Contraseña**: Al enfocar un campo de clave, la IA contextual y el portapapeles se deshabilitan para proteger datos sensibles.

---

## 5. Dictado por Voz y Nano Local
- [ ] Tocar `🎤` en la barra superior: solicita permiso de micrófono si no lo tiene y muestra "Escuchando...".
- [ ] Tocar el rostro del Búho a la izquierda de la barra superior:
  - Si no hay modelo local cargado en memoria: informa "Sin modelo local activo. Abre 'Modelos' en Nano para cargar uno."
  - Al abrir Nano AI -> Modelos Locales y cargar Qwen o Gemma, las acciones de ortografía y redacción procesan el texto en segundo plano.
