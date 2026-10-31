# Correcciones del Búho y modo oscuro — 28 de octubre de 2026

Este documento sucede a AUDITORIA.md; conserva el diagnóstico inicial como
evidencia histórica. No presenta las comprobaciones de ejecución pendientes
como aprobadas.

## Aplicado

| Área | Cambio real |
| --- | --- |
| Oscuro | Fondo #000000, superficies #121212/#1C1C1E, texto claro; sin tinte azul de elevación |
| Otros temas | Claro blanco/verde y Gris espacial permanecen diferenciados |
| Cristal | Mayor absorción oscura para evitar que un fondo blanco lave el panel |
| Panel externo | NanoFloatingService delega al host Flutter; mismo engine, controlador, voz y editor |
| Ciclo de vida | Attach/detach con revisión, plazo de apertura, Back, minimizar y cierre separados |
| Animación | Se conservan sprites y reloj del búho; se retira la antigua UI Android sin consumidores |
| Arranque y cierre | Arranca oculto; la X detiene voz y cierra el acceso externo, Minimizar conserva la sesión |
| Apertura WhatsApp | Verifica perfil y retorno; estado no verificado cuando no hay evidencia suficiente |
| Destinatario | Sin sustitución de teléfonos por coincidencias parciales de sufijo |
| Cancelación | Se propaga hasta apertura/verificación; no repite acciones inciertas |
| Adjuntos | Conserva borrador y archivo; no cambia de personal a Business silenciosamente |
| Lectura | Captura Android real, OCR y etiquetas locales; sin fingir un VLM |
| Importación | Destino de compartir registrado, TXT/ZIP acotado, original y JSON sobre mismos bytes |
| Cola | Un inválido se conserva aparte con diagnóstico y no impide procesar los siguientes |
| Concurrencia | Los eventos de importación durante otro trabajo provocan un drenado adicional acotado |
| Persistencia | Índices en SQLite existente; lecturas estrictas antes de escribir |
| Análisis | Fragmentos completos, checkpoints ligados a archivo/modelo; bloqueo si inferencia es remota |
| QA | Contratos de navegación persistentes, aserciones, esperado/observado, PNG/hash e informes JSON/HTML/ZIP |
| Recursos | Un dueño por turno; limpieza acotada de temporales, sin sondeos nuevos permanentes |

También se repararon bloqueos de compilación en dependencias: enum de backend,
comandos públicos, campos duplicados, copias de componentes de perfil, cierres de
widgets/notificadores e imports inválidos. Se conservaron los contratos existentes
y se retiraron implementaciones duplicadas o sin consumidores.

## Estado comprobado

- Análisis de `lib`: **0 errores y 0 advertencias**. Quedan 93 observaciones de
  estilo/deprecaciones; no se declara que el analizador esté completamente limpio.
- La compilación `fullSideloadDebug` se registra en REPARACION_BUILD.txt.
- No se crearon ni ejecutaron pruebas automáticas, benchmarks o recorridos de
  teléfono durante esta corrección. No se enviaron mensajes.
- La revisión visual física y las aserciones de WhatsApp siguen pendientes.
- La revisión independiente identificó y se corrigieron la pérdida del adjunto
  al desmontar su selector externo, los eventos de importación concurrentes y
  los gradientes nativos que conservaban el tema anterior.
- El diagnóstico de conexión no detectó el OPPO; no se instaló esta actualización.
- No se prometen menor temperatura ni una tasa de frames sin medición.

## Comprobación manual desde Android

1. Abrir Nano, activar explícitamente el acceso flotante y comprobar permisos
   de superposición y Accesibilidad. Salir a WhatsApp instalado y tocar el búho.
   Debe abrir el mismo panel sin una segunda conversación.
2. Escribir un borrador, minimizar y reabrir. Debe conservar el texto. Atrás
   debe cerrar primero el teclado/menú; la X debe cerrar el acceso del búho.
3. Seleccionar WhatsApp en Complementos. Su icono abre funciones; cada fila
   solo prepara el editor. Solo Enviar inicia el turno.
4. Pedir abrir un chat por nombre exacto, número internacional y usuario. Usar
   además un nombre ambiguo. Debe aclarar o informar «sin verificar» cuando el
   perfil no exponga identidad; nunca presentar solo startActivity como prueba.
5. Probar un envío autorizado de texto y luego un PDF/foto/vídeo de prueba.
   Confirmar visualmente destinatario, contenido, clic y retorno. No repetir
   un envío cuyo resultado sea incierto.
6. En Leer pantalla, comprobar texto accesible y OCR contra la pantalla real.
   Si Android impide la captura, debe indicarlo. En Conversar puede pedirse
   «Analiza la pantalla» con un modelo realmente local cargado.
7. Pedir «Exporta esta conversación de WhatsApp». Completar el flujo oficial,
   elegir exportar sin multimedia y compartir con «Importar chat en Nano».
   Alternativa: «Importa historial de WhatsApp» y elegir su TXT/ZIP.
8. Importar también un archivo inválido seguido de uno válido: el válido debe
   procesarse. Reiniciar Nano y comprobar que el historial válido permanece.
9. Pedir «Analiza el historial importado». Requiere modelo local y guarda
   resultados por fragmento. Cancelar y reanudar no debe mezclar otro modelo.
10. Pedir «Prepara QA de WhatsApp con "Nombre exacto"» y revisar el contrato.
    «Ejecuta QA de WhatsApp» es una orden aparte. Solo comprueba navegación,
    identidad y retorno; no envía mensajes. «Exporta informe QA» prepara un ZIP
    y deja al usuario elegir el destino de compartir.
11. Repetir la inspección visual en Oscuro, Claro, Gris espacial, horizontal,
    teclado abierto y texto grande. Revisar contraste y ausencia de solapes.

## Límites que permanecen

- OCR/etiquetas no equivalen a comprensión multimodal completa ni a leer vídeos.
- El historial completo es el que WhatsApp entregue en su exportación oficial;
  no se accede a su base privada ni se inventan mensajes omitidos/multimedia.
- Las ventanas freeform dependen del soporte real del Android/OEM. El búho sobre
  otra app y abrir WhatsApp en ventana reducida son capacidades distintas.
- La sesión compartida requiere el proceso y engine de Nano vivos; no se añade
  un reinicio automático tras forzar detención o matar el proceso.
- Las aserciones QA actuales cubren navegación; no acreditan envío, entrega,
  lectura del mensaje ni cobertura completa de WhatsApp.
- Las fachadas heredadas MainActivity y AutomationStoreDb mantienen su tamaño;
  se modificaron solo los puntos de registro necesarios. Los componentes nuevos
  se separaron por responsabilidad y se comprobaron por debajo de 200 líneas.

No debe calificarse «100 % funcional» hasta ejecutar y guardar las evidencias
de estos casos manuales sobre la versión instalada de WhatsApp y el teléfono.
