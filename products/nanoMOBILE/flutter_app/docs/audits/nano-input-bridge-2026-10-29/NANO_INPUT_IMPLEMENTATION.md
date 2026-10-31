# Implementación de entrada

El servicio solicita `flagInputMethodEditor`. `NanoAccessibleInputConnection` consulta la conexión de Android 13 o posterior y exige WhatsApp Personal o Business, editor enfocado, campo no sensible, paquete e identificador del editor coincidentes y borrador vacío. No conserva la conexión ni modifica el teclado seleccionado.

`NanoAccessibilityInput` reutiliza la estrategia previa `ACTION_SET_TEXT` cuando la conexión accesible no está disponible. Tras intentar `commitText`, incluso si la llamada produce una excepción, no vuelve a insertar por otra estrategia: el consumidor debe observar el editor. La aceptación del canal no demuestra escritura ni entrega. El canal booleano actual no distingue una excepción con resultado incierto de un rechazo; este contrato debe ampliarse antes de presentar un diagnóstico preciso o permitir reintentos.

El teclado opcional `NanoInputMethodService` se registra por variante y ofrece entrada manual, borrado, cambio de teclado y pegado explícito del portapapeles en WhatsApp. No verifica identidad del chat ni pulsa Enviar. Búho copia al portapapeles únicamente el texto literal de una orden al chat actual cuando Accesibilidad no responde; indica que el usuario debe elegir chat, pegar y enviar. El portapapeles pertenece al sistema.

`NanoInputStatus` consulta por separado la habilitación de Accesibilidad, la instancia conectada y la selección del teclado. El panel abre los ajustes oficiales de teclado; no activa servicios ni cambia el teclado por cuenta propia. El estado operativo de las estrategias, las transiciones de foco y el envío permanecen pendientes de observación.
