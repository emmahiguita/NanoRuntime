# Auditoría Nano → WhatsApp → Nano
Fecha: 25 de octubre de 2026. Solo auditoría: no se modificó código de producción.

## Resultado
El flujo tiene implementaciones reales de apertura, escritura, gestos y compartir
archivos mediante Android, pero NO está acreditado como completo de extremo a extremo.
No se envió ningún mensaje ni documento en esta revisión.

## Estado observado del teléfono
- Único teléfono conectado y autorizado: CPH2557, Android 15.
- Servicio AgentAccessibilityService de Nano habilitado y conectado (Bound services).
- No se cambiaron permisos, autonomía, modelos ni ajustes.
- Se abrió Nano en /automation. La pantalla y su editor se verificaron con ARTEMIS
  mobile_get_device_state, XML de UIAutomator y una captura real.
- Las pulsaciones de exploración sobre el campo no produjeron foco/teclado ni texto.
  El XML posterior mantuvo el editor vacío y sin foco. Esto bloqueó ejecutar la orden;
  no demuestra por sí solo una causa concreta dentro del componente.
- Android informa DispatchEnabled=true y DispatchFrozen=false. No se atribuye el
  resultado a un ANR ni se afirma que el dispositivo esté bloqueado.
- El usuario autorizó el contacto Emm y el texto propuesto de prueba. No se utilizó
  otro contacto ni se seleccionó ninguno por aproximación.

## ARTEMIS
mobile_diagnose devuelve blocked: falta la credencial multimodal en
C:/Users/emman/artemis/.env (el archivo no existe según el diagnóstico).
La observación del dispositivo sí respondió. No se inició ningún mobile_run_task.
Para habilitar ejecución: agregar localmente la clave del proveedor admitido y
recargar el servidor MCP. Nunca pegar secretos en el chat.
El diagnóstico inicial indicó helper deshabilitado; la lectura posterior de
Android mostró helper y Nano habilitados/conectados. No se cambió ese estado.

## Hallazgos con evidencia de código (ver source-evidence.json)
1. P1 — Selección nominal no inequívoca. ContactMatcher.findBest devuelve la
   primera coincidencia que supera el umbral, sin rechazar empates o múltiples
   teléfonos. ShareChannelHandler.resolveContactPhone usa LIKE y el primer cursor.
   La aproximación puede ayudar a buscar, pero no debe autorizar el envío final.
2. P1 — El respaldo del verificador acepta un texto exacto en el 35% superior
   de la ventana sin demostrar que pertenece a la cabecera. Una burbuja puede
   ocupar esa región. Conservar comparación por cabecera/identidad comprobada.
3. P1 — La herramienta whatsapp.share_file pide autoSend=true, pero omite
   recipientName y recipientVerified. El backend exige ambos y acaba abriendo
   el selector manual. No es un envío documental automático completo.
4. P2 — El retorno manda GLOBAL_ACTION_BACK y solo trae MainActivity cuando
   Android rechaza esa acción. Que Atrás se acepte no prueba que Nano esté delante:
   puede abrir la lista de WhatsApp o cerrar el teclado. Falta verificar paquete
   final y preservar la tarea/ruta original. El retraso de 350 ms no verifica envío.
5. P2 — El canal de UI devuelve apertura inmediatamente y arma 5 segundos por
   defecto; el backend programado usa 12 segundos y multimedia 25. No hay contrato
   uniforme que espere preparación, clic, cancelación y retorno. La fachada Dart
   informa apertura no verificada, no entrega; conservar esa distinción.
6. P2 — El benchmark usa rectángulos/resource IDs prefijados y acciones de memoria.
   Su etiqueta de Nivel 6 y porcentajes no acreditan una navegación real de WhatsApp.
   whatsapp_e2e_automation_test reemplaza agenda y canal con dobles que devuelven
   true: es una prueba de lógica, no una ejecución en WhatsApp instalado.

## Elementos reales que deben conservarse
- Intent ACTION_VIEW con texto codificado para abrir chats.
- ACTION_SEND, MIME y FileProvider con permiso temporal para compartir archivos.
- Puente de accesibilidad para acciones ligadas a identidad/bounds del nodo.
- Autoenvío condicionado por variante: Google Play lo bloquea explícitamente.
- Cancelación del runnable de autoenvío al desconectar el servicio, y timeout acotado.
- Estados locales no verificados separados de ID aceptado por Meta Cloud.
No puede afirmarse soporte universal para cualquier app a partir de estas piezas.

## Verificación de aceptación pendiente
- Comprobar identidad única de Emm; abortar si hay ambigüedad.
- Ejecutar la orden desde Nano, observar el chat correcto y texto exacto.
- Un único envío autorizado, con observación del estado disponible en WhatsApp.
- Regreso automático a la misma ruta de Nano y estado de tarea limpio.
- Repetir con un PDF de prueba explícito, incluida cancelación del selector.
- WhatsApp frío/caliente, fallo de permiso y regreso con teclado abierto.
- Medir tiempos reales por fase; el tiempo del agente ARTEMIS no equivale a latencia
  del producto. No se publican cifras de fluidez o éxito no medidas.
- Para otras apps: explorar previamente cada pantalla e identificar sus controles.

No se añadieron ni ejecutaron nuevos tests automatizados: ARTEMIS no pudo iniciar
su exploración ejecutora. No se presenta una prueba con mocks como evidencia real.
