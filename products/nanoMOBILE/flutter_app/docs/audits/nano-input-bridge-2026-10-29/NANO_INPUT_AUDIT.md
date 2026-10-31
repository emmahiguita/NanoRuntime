# Auditoría de entrada de Nano

## Evidencia inicial

El OPPO CPH2557 informa Android API 35. Android informó habilitado y conectado únicamente el servicio Artemis; Nano no figuraba habilitado, vinculado ni en proceso de conexión. Esto acredita el estado observado, no la causa por la que cambió. Están instalados WhatsApp Personal y Business.

| Componente | Función y conclusión | Acción |
| --- | --- | --- |
| `AgentAccessibilityService` / `AgentAccessibilityBridge` | Servicio y referencia limpiada al desconectar. | Reutilizar; el estado de Android no se sustituye por la referencia. |
| `NanoAccessibilityInput` | Revalida foco, editor, bounds y borrador; usa `ACTION_SET_TEXT`. | Integrar estrategia adicional sin duplicar el ejecutor. |
| `WhatsAppUiGoalPreparer` / `WhatsAppCurrentChatSender` | Identifican ventana y chat, protegen borrador y verifican el resultado. | Reutilizar sin alterar el envío. |
| `NanoOwlWindowService` / `NanoOverlayWindowLayout` | El panel toma foco al editar; se contrae antes de ejecutar. | Mantener diseño y flags. |
| `ShareChannelHandler` / `AutomationAccessController` | El estado existente usa la referencia de servicio como conexión. | Pendiente diagnóstico tipado que distinga habilitación y conexión. |

No se ha demostrado una causa interna de la deshabilitación ni una reconexión real. El ejecutor Dart existente contiene un motivo de error que incorpora el texto de entrada; requiere una corrección separada para evitar exponer contenido sensible en diagnósticos.

Después de instalar la versión con Nano Input, Android informó el servicio de Nano habilitado pero sin vínculo, sin intento de conexión en curso y sin fallo declarado. Nano Input aparece instalado, pero no habilitado; Gboard sigue seleccionado. Los registros disponibles no explican por qué no se vincula el servicio.
