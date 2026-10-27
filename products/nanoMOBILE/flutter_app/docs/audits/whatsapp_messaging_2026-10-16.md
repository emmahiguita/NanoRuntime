# Auditoría de WhatsApp Personal y Negocio — 2026-10-16

Estado: correcciones instaladas y verificadas parcialmente. Aún no se acredita
producción completa, ausencia total de lags ni entrega E2E de todos los medios.

## Correcciones aplicadas

- Arranque: `audio_service` podía crear y ejecutar un motor UI al registrar sus
  plugins desde el servicio headless, antes de registrar canales de Nano.
  `NanoUiFlutterEngine` reserva el motor sin ejecutar Dart. La Activity configura
  canales y ruta antes de main. Se comprobó la apertura directa de WhatsApp.
- El runtime headless implementa las consultas reales de archivos que faltaban:
  permisos de ejecución y comprobación del bootstrap, dentro de `files/nano`.
- Android: cada mensaje de MessagingStyle conserva identidad, fecha, autor y
  dirección. La clave reutilizable de notificación ya no se toma como ID de mensaje.
- El prefijo de presentación `live:` no se persiste como identidad conversacional.
- La huella usa tiempo exacto: no borra dos mensajes legítimos iguales en 5 segundos.
- Se suprime la doble observación exacta de entrantes Android entre panel y memoria
  nativa. No se hace merge aproximado entre cuentas o contactos por su nombre.
- La paginación canónica compara y ordena el mismo ID efectivo, con fallback
  para mensajes que no tienen identificador del proveedor.
- Contexto: conserva orden cronológico y reserva el presupuesto para mensajes
  recientes. Un historial canónico existente se usa aunque la memoria antigua esté vacía.
- Los previews Web se persisten con un solo recorrido activo, un snapshot pendiente
  y caché de 200 chats. Solo un cambio real genera escritura; errores se capturan.
- Abrir un chat no recarga su historial por notificaciones de otros chats.
- Negocio: catálogo, perfil y frases se guardan en serie sobre el estado ya hidratado;
  dos operaciones simultáneas no se sobrescriben con snapshots antiguos.
- El editor local espera los textos guardados y bloquea guardados repetidos.
- Plantillas Meta: campo legible para cuerpo, vista previa y modo JSON avanzado;
  conserva ejemplos de variables, encabezados, botones y pie. Las operaciones
  remotas se serializan y se comprueba el ciclo de vida después de los diálogos.
- Diseño: filtros Material «Personal» y «Negocio» legibles, altura adaptable y
  contador Web «chats observados». Los previews no prueban historial completo.

## Evidencia

Compilación `fullSideloadProfile` e instalación en `VGL7MVFMDYQG8T55`: correctas.
Proceso final observado: 23234, sin errores de canales, SQLite o excepciones Flutter
en la lectura de arranque realizada. No se enviaron mensajes de prueba a terceros.

50 pruebas unitarias y de widgets aprobadas. Cubren identidad/replay, separación de
chats, orden/presupuesto de contexto, escrituras comerciales concurrentes, editor
vertical/horizontal con texto ampliado, integridad comercial y retención Web.
Los dobles de prueba no se presentan como una verificación de la API de Meta.
Análisis estático de las áreas modificadas: sin incidencias.

### Rendimiento real: OPPO CPH2557, compilación de perfilado

- Android `am start -W`: 1.079 s para apertura de Activity. No equivale al tiempo
  de sincronización completa de mensajes ni al tiempo de inferencia.
- Panel visual: sesión vinculada con 40 chats Web observados y lista local cargada.
- Captura Flutter VM durante cinco desplazamientos; 113 frames retenidos:

| Evento | Mediana | P95 | Máximo |
|---|---:|---:|---:|
| Frame de interfaz | 5.205 ms | 17.307 ms | 32.297 ms |
| GPURasterizer::Draw | 16.122 ms | 25.748 ms | 35.818 ms |
| Rasterizer::DrawToSurfaces | 8.216 ms | 17.766 ms | 28.607 ms |

7 de 113 frames de interfaz y 50 de 113 eventos GPURasterizer superaron 16.67 ms.
Son duraciones de eventos Flutter, no un porcentaje universal de jank de Android.
Persisten picos gráficos: no se acredita «sin lags».

- Heap Dart inicial: 34,806,176 bytes; después de scroll y GC: 31,940,384;
  después de tres ciclos de navegación y GC: 30,794,832 bytes.
- Un isolate visible, una Activity y un WebView después de los ciclos.
- PSS del proceso: 516,399 → 552,249 KiB. Heap nativo: 71,660 → 92,568 KiB;
  gráficos: 215,508 → 205,084 KiB. La navegación también carga recursos de inicio.
  La muestra corta no distingue toda caché nativa de una posible fuga; hace falta
  una prueba prolongada y comparable, con el modelo cargado y bajo tráfico real.

## Pendientes que impiden acreditar el 100 %

1. E2E con notificación WhatsApp real: recepción, respuesta, pausa y reanudación.
2. Correlación Android + Web con identidad técnica para probar duplicados de ambos
   proveedores. El fix exacto Android no demuestra por sí solo ese caso completo.
3. Cerrar la lectura única del detalle: aún conviven memoria, archivo Android y Web;
   tener persistencia canónica no significa que todos los consumidores ya la usen.
4. Historial y medios completos: solo están disponibles si el proveedor los expone.
   Notificaciones aisladas no reconstruyen el historial privado antiguo.
5. Biblioteca/Tienda: verificar envío del archivo real al destinatario exacto y
   confirmación del proveedor, incluidos foto, video, audio y PDF.
6. Meta: probar con gateway, WABA, número, webhook y credenciales reales. El editor
   prepara y tramita payloads; aprobación y entrega requieren evidencia remota.
7. `NanoBusinessRuntime.outboxQueue` es una dependencia de compatibilidad;
   `getPendingMessages` no tiene consumidor conectado. El despacho actual no
   acredita recuperación de esta outbox tras reinicios. No se conectó un segundo
   emisor sin resolver idempotencia y estados desconocidos de la entrega.
8. Optimizar y volver a medir los picos de rasterización. La prueba actual no
   acredita límites de chats/minuto, ausencia total de fugas ni estabilidad sostenida.

Los componentes nuevos se mantienen bajo 200 líneas y documentan invariantes.
La guía `nano-canonical-messaging-integrity` incorpora estas regresiones para
reutilizar sus comprobaciones en futuras modificaciones.
