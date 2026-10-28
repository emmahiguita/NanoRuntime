# Presupuesto de contexto del Qwen3 LiteRT instalado

## Evidencia

- Paquete: `qwen3_0.6b_nothink_q4_block32_ekv1280.litertlm`.
- SHA-256 comprobado en el dispositivo, coincide con el catálogo:
  `2df6821ec12702dafd33915e7a1a1adc7c4b053f3672fd9555dfaf3a114c4139`.
- Ficha del paquete: KV 1280, firmas prefill hasta 1024, tokenizer byte-BPE.
- Fuente: https://huggingface.co/litert-community/Qwen3-0.6B-int4
- Kotlin API fijada: LiteRT-LM 0.17.1. Conversation aplica su plantilla;
  no se añade una segunda plantilla al payload de inferencia.

## Corrección

- Guard nativo en la frontera real de generación; alcanza chat y automatización
  y se vuelve a aplicar al reintento de calidad con su sistema modificado.
- Solo el nombre exacto del paquete auditado activa este presupuesto.
- Reserva salida solicitada y margen de tokens especiales antes de historial.
- Cota conservadora con bytes UTF-8 de contenido y envoltorios ChatML. Para el
  tokenizer byte-BPE, esta cota evita la regla incorrecta de caracteres/4.
  NO se presenta como conteo exacto del tokenizer ni medición de velocidad.
- Retira primero turnos históricos antiguos completos, sin modificar SQLite.
- No recorta sistema ni mensaje actual para aparentar que caben. Si no entran,
  rechaza con `CONTEXT_CAPACITY_EXCEEDED`, clasificado también en Logcat Dart.
- Instrucciones personales más breves solo para ese paquete, conservando
  distinción de autores, hechos desconocidos y contrato de seguridad/JSON.
- Métricas separadas: capacidad, reserva, cota de entrada, turnos retirados y
  conteo real del KV después de inferencia (`getTokenCount`).
- Gemma y MNN no heredan el límite 1280. No se cambia modelo, muestreo ni motor.

## Límites y validación

- Un límite conservador puede retirar más historial del estrictamente necesario.
- Este cambio evita solicitudes sobredimensionadas; no garantiza calidad semántica.
- Mensajes obligatorios demasiado grandes requieren un paquete con más capacidad;
  no se cortan ni se resumen por intuición.
- Los paquetes desconocidos siguen con su política actual: no tienen un límite
  inventado ni se declaran corregidos por esta intervención.
- No se ejecutan tests automáticos, por petición del usuario.
- Análisis estático del writer: sin incidencias.
- APK `fullSideloadProfile`: compilado (129 MB), incluida compatibilidad Kotlin
  de `Conversation.getTokenCount()` en LiteRT-LM 0.17.1.
- Instalación con datos conservados: `Success`, 2026-10-16 11:49:32.
- Arranque: `Status: ok`, PID 24307; selección conservada:
  `Qwen2.5-Omni-3B (MNN)`.
- En la consulta inicial no aparecieron FATAL EXCEPTION, E/flutter,
  MissingPluginException ni SQLiteException del PID nuevo.
- No se cambió el modelo ni se generaron mensajes de prueba. Sigue pendiente
  la revisión manual del presupuesto con Qwen3 cuando el usuario lo seleccione.
