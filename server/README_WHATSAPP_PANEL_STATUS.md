# Estados visibles del servidor de WhatsApp

Actualización del 13 de octubre de 2026. Cambia únicamente presentación y resultados
de comprobaciones; no activa envíos, cambia números o modifica permisos.

## Indicadores permanentes

- Servidor local: verde Encendido solo si su hilo está vivo y Uvicorn inició.
  Ámbar durante inicio/cierre, gris detenido y rojo ante fallo de arranque.
- Meta · lectura: verde únicamente después de consultar plantillas reales con
  éxito. Sin comprobar antes de la consulta; error rojo y explicación en el aviso.
- MCP · herramientas: verde después del handshake autenticado, catálogo de cuatro
  lecturas y comprobación de que su llave no permite envío ni administración.
- Webhook · recepción: ámbar si falta App Secret o sigue pendiente verificar
  suscripción/recepción real. Tener App Secret guardado NO lo convierte en verde.
  Error de conexión del diagnóstico se muestra rojo, no como recepción validada.

El color siempre tiene texto equivalente. Servidor encendido no significa Meta
validada, HTTPS disponible, webhook suscrito o mensaje entregado.
Meta/MCP muestran la última comprobación de la sesión: no consultan proveedores
periódicamente. Detener, reiniciar o guardar configuración invalida esos éxitos.

## Vista y comportamiento

Los cuatro indicadores permanecen arriba y las acciones/alertas abajo. Solo el
formulario se desplaza; no hace falta agrandar la ventana para alcanzar botones.
El tamaño inicial se limita al tamaño de pantalla. Rueda/trackpad solo desplazan
el formulario cuando el puntero está sobre él; no cambian otras aplicaciones.

Las acciones incompatibles se deshabilitan: Iniciar/Guardar con el servidor vivo,
Detener cuando está apagado y comprobar servicios antes de iniciar. Un worker
mantiene el guardado y la red fuera del hilo visual. Los estados y botones se
repintan únicamente al cambiar, reutilizando el temporizador existente.

Resultados tipados con éxito/pendiente/error evitan inferir colores por frases.
Los consumidores textuales anteriores conservan sus funciones compatibles.
Los resultados contienen solo mensajes seguros y booleanos de configuración,
nunca claves, tokens, App Secret o contenido de chats.

## Mantenimiento y evidencia

- whatsapp_panel_view.py: composición, desplazamiento y habilitación de acciones.
- whatsapp_panel_status.py: indicadores y aviso semántico.
- whatsapp_check_result.py: contrato público de evidencia, sin Tk ni secretos.
- whatsapp_local_panel.py: ciclo de vida y aplicación de resultados en el hilo UI.
- Los helpers de Meta/MCP/webhook retornan resultados reales y conservan wrappers
  textuales para consumidores existentes.

Ruff, sintaxis e importación correctos. Todos los archivos modificados menores de
200 líneas. El panel nuevo PID 45736 responde y su gateway real devuelve 200.
La configuración observada del webhook sigue false: el indicador debe advertirlo.
La revisión visual se solicita al propietario; no se capturaron campos privados
ni se usaron eventos ficticios, suites de tests o automatización de mensajes.

Para repetir: observar encendido/detenido y pulsar Comprobar Meta/MCP. Su éxito
debe poner únicamente el indicador correspondiente en verde. Detener debe quitar
el verde del servidor y restablecer Meta/MCP, sin inventar una caída de Meta.
