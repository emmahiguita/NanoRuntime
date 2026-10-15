# Nano Desktop · mensajería y conexión oficial

Revisión del 14 de octubre de 2026. Diseño sobre la interfaz existente, sin
reescribir navegación, modificar modelos ni copiar credenciales al navegador.

## Cambios visuales y responsabilidades

- `ui/css/desktop_messaging.css`: tokens locales que reutilizan el tema Nano,
  tipografía, lista continua, burbujas, compositor y panel contextual sin tarjetas
  repetidas. La fila `minmax(0, 1fr)` impide que contenido largo fuerce la altura.
- `ui/css/desktop_messaging_adaptive.css`: oculta detalles bajo 1440 px y los
  ofrece bajo demanda; menú compacto bajo 1200 px; lista/chat alternan bajo
  900 px o cuando el contenedor dispone de menos de 650 px. Misma instancia.
- `whatsapp_view.js`: estado «Meta sin conectar» abre la guía existente.
- `whatsapp_chat_list.js`: conserva scroll, selección y búsqueda; vacío sin datos
  no se convierte en contactos inventados ni se elimina almacenamiento previo.
- `whatsapp_chat_conversation.js`: vacío breve con logo original; animación
  únicamente al seleccionar hilo; actualizaciones conservan el punto de lectura.
- `whatsapp_context_panel.js`: pestañas Información/Asistencia con ARIA y flechas
  del teclado; identidad, etiquetas y política salen del repositorio existente.
- `whatsapp_composer.js`: sugerencia junto al texto, altura definida por CSS (34–120 px), borrador por
  hilo y envío deshabilitado mientras no exista transporte. Cancela solo su espera
  de IA al navegar; una sugerencia tardía no sobrescribe una edición manual.
- `whatsapp_pairing_modal.js`: guía explícita para servidor, Meta, bandeja y modelo.
  Foco de teclado contenido en la guía y restaurado al cerrarla.

La única capa iOS/glass es `nano_glass.css` (119 líneas); importa
`nano_glass_list.css` (43) y `nano_glass_controls.css` (37). Los comentarios
explican cada responsabilidad. Sustituye la capa previa extensa; no agrega una
segunda vista ni otro enlace en HTML. Sus tokens `--ng-*` pertenecen solo a
Mensajería y cambian juntos en oscuro. No alteran colores de otros módulos.

Tokens específicos: `--wa-list-width`, `--wa-details-width`, `--wa-toolbar-height`,
`--wa-motion`, `--wa-ease`, `--wa-caption`. Se reutilizan colores, radios, espacios,
sombras y fuentes existentes; los ajustes glass tienen ámbito local.

No se agregan llamadas, carga de adjuntos, presencia, typing de contactos ni
confirmaciones de entrega sin un proveedor real. No se fabrican notas o archivos.
Las burbujas salientes usan azul grisáceo claro con texto oscuro, no azul saturado.
El tema oscuro y la preferencia de movimiento reducido siguen siendo compatibles.

## Qué está conectado y qué no

La pantalla actual lee `WhatsAppStorage` (registros locales del navegador).
`WhatsAppAiAgent` usa el transporte real del modelo seleccionado para sugerencias.
`WhatsAppDispatcher` devuelve explícitamente «envío no disponible»; no manda nada.
`WhatsAppSessionManager` no simula vinculación ni crea códigos QR.
Que el gateway o MCP del PC estén encendidos NO conecta automáticamente esta vista.
Tampoco basta con seleccionar un modelo para tener recepción oficial.

El gateway independiente ya tiene estas rutas autenticadas:

| Operación | Ruta real | Permiso |
| --- | --- | --- |
| Conversaciones | GET `/api/v1/whatsapp/conversations` | Lectura |
| Historial | GET `/api/v1/whatsapp/conversations/{peer_id}/messages` | Lectura |
| Cambios | GET `/api/v1/whatsapp/changes` | Lectura |
| Enviar texto | POST `/api/v1/whatsapp/messages` | Envío |
| Plantillas | `/api/v1/whatsapp/templates` | Lectura o administración según método |

La llave Nano va en `X-Nano-API-Key`, nunca en una URL. El navegador no debe guardar
el token Meta, el App Secret ni llaves de envío/administración en localStorage.
MCP mantiene cuatro herramientas de lectura sobre el gateway; no es un MCP
publicado por Meta, no importa el historial personal y no autoriza envíos.

## Orden seguro para completar la integración

1. En el panel privado del PC, verificar lectura de Meta con un token vigente y
   autorizado para esa WABA/número. Detener antes de guardar o renovar valores.
2. Guardar el App Secret de ESA aplicación; iniciar y revisar estado del webhook.
3. Elegir HTTPS autorizado y accesible desde Meta. El callback termina en
   `/api/v1/whatsapp/webhook`; configurar verificación, `messages` y suscripción WABA.
   No usar la URL antigua de un túnel detenido ni desactivar la validación TLS.
4. Confirmar un mensaje nuevo real al número Cloud de prueba y su persistencia.
   La API de Nano muestra lo recibido desde la activación, no todo WhatsApp previo.
5. Implementar un adaptador/repository de escritorio para esas lecturas, con ámbito
   WABA/número/peer, WAMID, cursores, errores visibles y cancelación al salir.
   Separar caché oficial de registros locales no verificados; no unir por nombres.
6. El proxy actual de `dev_server.py` apunta al runtime de IA en 8080, NO al gateway
   WhatsApp en 8010. Requiere un encaminamiento específico y autenticado para esta
   integración; el runtime no debe recibir tokens Meta ni llaves de WhatsApp.
7. En web, guardar credenciales solo mediante un backend privado controlado; en
   el ejecutable, reutilizar almacenamiento nativo seguro y un puente limitado.
   No habilitar CORS genérico ni publicar el frontend como solución improvisada.
8. Conectar escritorio y móvil al MISMO gateway empresarial. El móvil usa HTTPS y
   su almacenamiento seguro. Su agente personal/Web/notificaciones sigue aparte.
9. Usar el historial oficial para el borrador IA. Primero revisión humana; luego
   implementar cola saliente duradera, permisos y estados reales antes de autonomía.
   Un timeout de envío no prueba fallo: no reintentar a ciegas ni duplicar mensajes.
10. Validar entrada, historial, sugerencia, envío autorizado y entrega. En producción
    faltan HTTPS estable, supervisión, backup, retención y autorización por cliente.

Esta revisión NO activa nuevos permisos, túneles, envíos ni cambios en Meta.
La disponibilidad del servidor del PC depende de que permanezca encendido.

## Verificación realizada

- Sintaxis JavaScript correcta; ocho archivos de código modificados/nuevos por
  debajo de 200 líneas. No se ejecutaron suites de tests.
- Revisión manual en navegador: cuatro zonas a ~1441 px, detalles bajo demanda
  a 1300 px, menú compacto a 1100 px y lista/chat alternados a 800 px.
- Sin overflow horizontal en esos tamaños; compositor dentro de la ventana.
- Pestañas Información/Asistencia y filtro vacío revisados con registros previos,
  sin generar fixtures ni borrar almacenamiento. No equivalen a recepción Meta.
- La IA queda deshabilitada sin un modelo seleccionado; envío deshabilitado sin
  adaptador. No se realizó inferencia, envío, entrega ni conexión oficial nueva.
- La captura muestra registros locales existentes, no mensajes certificados de Meta.
- Revisión iOS manual: búsqueda de 32 px, filtros de 28 px, filas de 60 px,
  cabecera de chat de 54 px y compositor vacío de unos 50 px. Detalles alinea
  exactamente con la cabecera de 52 px; lista compacta ocupa todo el ancho útil.
- Claro y oscuro revisados; sin overflow horizontal a 1910, 1299 y 800 px.
  Un borrador local de siete líneas crece hasta 120 px y desplaza internamente;
  se restauró vacío, sin enviar. No se ejecutaron suites de tests.
- Se retiraron selectores sin componentes actuales, typing/presencia decorativos,
  textura SVG y blur por mensaje. La señal IA usa el aria-busy del generador real.
- Compilación release sin conexión correcta; ejecutable instalado en
  `%LOCALAPPDATA%/Programs/NanoAI Desktop/NanoAI Desktop.exe` con SHA-256 idéntico.
  Respaldo anterior `NanoAI Desktop.pre-ios-20261014.exe`; perfiles intactos.
  Se comprobó la mensajería en oscuro dentro de la aplicación instalada.
- Edición durante generación y recepción oficial requieren validación adicional;
  no se afirma disponibilidad 24/7 ni cumplimiento total WCAG.

## Fuentes y documentación existente

- `server/README_WHATSAPP_HISTORY.md`: cursores y alcance real del historial.
- `server/README_WHATSAPP_PERMISSIONS.md`: lectura/envío/administración separados.
- `server/README_WHATSAPP_WEBHOOK.md`: firma, almacenamiento y suscripción.
- [Referencia de Meta: firma y verificación del webhook](https://whatsapp.github.io/WhatsApp-Nodejs-SDK/api-reference/webhooks/start/).
  El SDK de esa referencia está archivado; aquí solo se cita el mecanismo,
  no se incorpora una dependencia de ese SDK.
