# Carga de historial: segunda revisión del 16 de octubre

## Causas encontradas y cambios

1. El detalle reconsultaba hasta 50 notificaciones por cada cambio global del
   hub. Ahora consume el evento correspondiente al chat sin otra extracción
   completa; conserva la lectura inicial y las verificaciones previas al envío.
2. La primera página pedía 200 filas. Ahora pide 60 y mantiene páginas anteriores
   de 200, cursor compuesto y acceso al resto del archivo observado.
3. Reaperturas esperaban SQLite sin snapshot inmediato. El cliente retiene solo
   la última página de hasta diez chats y siempre la revalida; no archiva archivos.
4. Ráfagas SQLite provocaban consultas seguidas. Se agrupan durante 180 ms sin
   aplazamiento indefinido; dispose cancela el temporizador.
5. El historial visual comparaba todos los mensajes por parejas y fusionaba
   textos iguales con dos segundos de tolerancia. Se sustituyó por un índice
   de ID/instante exacto/dirección/texto/autor compatible. No se fusionan dos IDs
   explícitos distintos únicamente por parecido.
6. Las burbujas no dibujaban su timestamp. Ahora muestran fecha y hora local
   del instante registrado. Cero/ausente no se reemplaza por la hora actual.
7. Web aguardaba onLoadStop aunque el panel podía estar utilizable antes. Un
   sondeo ligero al progresar la carga permite iniciar la apertura anticipada;
   el guard de cuenta y la confirmación del encabezado siguen obligatorios.
8. La cabecera del detalle refleja la fuente elegida: Web o instalado.
9. Captura física en horizontal mostró controles consumiendo casi toda la
   altura. Con menos de 500 dp, Web/Meta quedan en un desplegable accesible.
10. Captura posterior mostró varias tarjetas con la hora de captura. El decoder
    usaba «ahora» si faltaba una etiqueta interpretable. Ahora conserva la etiqueta
    observada, devuelve cero si no conoce la hora e invalida timestamps de la
    caché anterior sin borrar chats. También corrige «Ayer» por día de calendario.
11. Retirada la fusión de Web/Android por título único. Una etiqueta móvil + Web
    exige evidencia técnica compatible; nombres iguales pueden ser chats distintos.

## Evidencia y límites

- Análisis estático de ocho unidades del historial y dos de distribución:
  sin incidencias tras corregir avisos de estilo.
- No se ejecutaron pruebas automatizadas, por instrucción del usuario.
- Nuevos componentes: menos de 200 líneas, con comentarios sobre invariantes.
- Diagnóstico de tiempos: `[wa-history-page]` y `[wa-web-open]`, sin contenido
  personal en esos registros. La compilación sola no demuestra mejora temporal.
- PID 24425, versión instalada con las optimizaciones de carga: páginas locales
  observadas de 417, 113, 110, 289 y 320 ms (3–17 filas); aperturas Web verificadas
  de 1379 y 704 ms. Son muestras, no un percentil ni una garantía. La medición
  Web empieza en la solicitud de apertura; no incluye arranque/sincronización
  previa del proveedor, descarga multimedia ni carga de todo el historial.
- En ese registro consultado no aparecen excepciones Flutter no manejadas,
  `FATAL EXCEPTION`, `No Overlay` ni `MissingPluginException`.
- Corrección temporal y retirada de fusión por nombre: siete unidades analizadas
  sin incidencias y APK `fullSideloadProfile` recompilado correctamente (136,8 s).
- Zona horaria del teléfono observada: `America/Bogota` (UTC−05). No se cambió
  el reloj del sistema para acomodar las horas de Nano.
- Último APK instalado conservando datos: `Success`; arranque `Status: ok`,
  PID 25774. Registro consultado sin las excepciones anteriores. Las métricas
  de chat son de la instalación previa inmediata, no del arranque de este PID.
- La caché es visual, provisional y se revalida; no garantiza mensajes nuevos
  hasta finalizar la lectura del origen. No se eliminan datos guardados.
- No se certifica ausencia total de duplicados históricos, fugas o jank.
- Android muestra lo observado en notificaciones, no todos los chats privados
  ni historial antiguo completo. Web sigue sujeto a vinculación y sincronización.

## Cierre pendiente

- Medir primera apertura y reapertura en Web/Android con uso físico real.
- Verificar emisor, hora, multimedia y replay simultáneo en la cuenta vinculada.
- Reconciliar registros históricos erróneos con evidencia, sin borrar por similitud.
- Completar lectura canónica única del panel y multimedia saliente verificada.
- Dev Emm AI: falta configurar recursos reales del negocio, Gateway/webhook,
  autorización y número de WhatsApp; no se declara conexión comercial realizada.
